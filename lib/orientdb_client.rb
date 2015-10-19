require "orientdb_client/version"
require "orientdb_client/errors"
require "orientdb_client/http_adapters"
require "orientdb_client/http_adapters/typhoeus_adapter"

require 'oj'
require 'cgi'

module OrientdbClient
  class << self
    def client(options = {})
      Client.new(options)
    end

    attr_accessor :logger
  end

  DATABASE_TYPES = ['document', 'graph']

  class Client
    attr_reader :http_client

    def initialize(options)
      options = {
        host: 'localhost',
        port: '2480'
      }.merge(options)
      @host = options[:host]
      @port = options[:port]
      adapter_klass = if options[:adapter]
                        HttpAdapters.const_get(options[:adapter])
                      else
                        HttpAdapters::TyphoeusAdapter
                      end
      @http_client = adapter_klass.new
      @node = Node.new(host: @host, port: @port, http_client: @http_client)
      @connected = false
      self
    end

    def connect(username:, password:, db:)
      raise ClientError.new('Already connected') if connected?
      @username = username
      @password = password
      @db = db
      @http_client.username = @username
      @http_client.password = @password
      @node.connect(@db)
    end

    def disconnect
      raise ClientError.new('Not connected') unless connected?
      @username = nil
      @password = nil
      @db = nil
      @http_client.reset_credentials
      @node.disconnect
    end

    def create_database(name, storage, type, options = {})
      raise ArgumentError, "Invalid database type: #{type}" unless DATABASE_TYPES.include?(type)
      @node.create_database(name, storage, type, options)
    end

    def delete_database(name, options = {})
      @node.delete_database(name, options)
    end

    def create_class(name, options = {})
      @node.create_class(name, options)
    end

    def get_class(name)
      @node.get_class(name)
    end

    def has_class?(name)
      @node.has_class?(name)
    end

    def drop_class(name)
      @node.drop_class(name)
    end

    def get_database(name)
      @node.get_database(name)
    end

    def database_exists?(name)
      list_databases.include?(name)
    end

    def list_databases
      @node.list_databases
    end

    def query(sql, options = {})
      @node.query(sql, options)
    end

    def query_unparsed(sql, options = {})
      @node.query_unparsed(sql, options)
    end

    def command(sql)
      @node.command(sql)
    end

    def connected?
      @node.connected?
    end

    def database
      @node.database
    end

    def debug=(val)
      @node.debug = val
    end
  end

  class Node

    attr_reader :database
    attr_writer :debug

    def initialize(host:, port:, http_client: http_client)
      @host = host
      @port = port
      @http_client = http_client
      @connected = false
      @database = nil
      @debug = false
    end

    def connect(database)
      request(:get, "connect/#{database}")
      @connected = true
      @database = database
      true
    end

    def disconnect
      request(:get, 'disconnect') rescue UnauthorizedError
      @connected = false
      true
    end

    def create_database(name, storage, type, options)
      r = request(:post, "database/#{name}/#{storage}/#{type}", options)
      parse_response(r)
    end

    def delete_database(name, options)
      r = request(:delete, "database/#{name}", options)
      parse_response(r)
    end

    def get_database(name)
      r = request(:get, "database/#{name}")
      parse_response(r)
    rescue UnauthorizedError
      raise NotFoundError.new("Database #{name} not found", 401)
    end

    def list_databases
      r = request(:get, 'listDatabases')
      parse_response(r)['databases']
    end

    def create_class(name, options)
      sql = "CREATE CLASS #{name}"
      sql << " EXTENDS #{options[:extends]}" if options.key?(:extends)
      sql << " CLUSTER #{options[:cluster]}" if options.key?(:cluster)
      sql << ' ABSTRACT' if options.key?(:abstract)
      command(sql)
    end

    def drop_class(name)
      command("DROP CLASS #{name}")
    end

    def query(sql, options)
      parse_response(query_unparsed(sql, options))['result']
    end

    def query_unparsed(sql, options)
      limit = limit_string(options)
      request(:get, "query/#{@database}/sql/#{CGI::escape(sql)}#{limit}")
    end

    def command(sql)
      r = request(:post, "command/#{@database}/sql/#{CGI::escape(sql)}")
      parse_response(r)
    end

    def get_class(name)
      r = request(:get, "class/#{@database}/#{name}")
      parse_response(r)
    end

    def has_class?(name)
      if get_class(name)
        return true
      end
    rescue NotFoundError
      return false
    end

    def connected?
      @connected == true
    end

    private

    def request(method, path, options = {})
      url = build_url(path)
      t1 = Time.now
      response = @http_client.request(method, url, options)
      time = Time.now - t1
      r = handle_response(response)
      OrientdbClient::logger.info("request (#{time}), #{response.response_code}: #{method} #{url}")
      r
    end

    def build_url(path)
      "http://#{@host}:#{@port}/#{path}"
    end

    def handle_response(response)
      return response if @debug
      case response.response_code
      when 0
        raise ConnectionError.new("No server at #{@host}:#{@port}", 0, nil)
      when 200, 201, 204
        return response
      when 401
        raise UnauthorizedError.new('Unauthorized', response.response_code, response.body)
      when 404
        raise NotFoundError.new('Not found', response.response_code, response.body)
      when 409
        raise ConflictError.new('Conflict', response.response_code, response.body)
      when 500
        translate_500(response)
      else
        raise ServerError.new("Unexpected HTTP status code: #{response.response_code}", response.response_code, response.body)
      end
    end

    def parse_response(response)
      @debug ? response : Oj.load(response.body)
    end

    def limit_string(options)
      options[:limit] ? "/#{options[:limit]}" : ''
    end

    def translate_500(response)
      code = response.response_code
      body = response.body
      odb_error_class, odb_error_message = extract_odb_error(response)
      case odb_error_class
      when /OCommandSQLParsingException/
        raise ClientError.new("#{odb_error_class}: #{odb_error_message}", code, body)
      when /OQueryParsingException/
        raise ClientError.new("#{odb_error_class}: #{odb_error_message}", code, body)
      when /OCommandExecutorNotFoundException/
        raise ClientError.new("#{odb_error_class}: #{odb_error_message}", code, body)
      when /IllegalArgumentException/
        raise ClientError.new("#{odb_error_class}: #{odb_error_message}", code, body)
      when /OConfigurationException/
        raise ClientError.new("#{odb_error_class}: #{odb_error_message}", code, body)
      when /OCommandExecutionException/
        raise ClientError.new("#{odb_error_class}: #{odb_error_message}", code, body)
      when /OSchemaException/
        raise ClientError.new("#{odb_error_class}: #{odb_error_message}", code, body)
      end
    end

    def extract_odb_error(response)
      json = Oj.load(response.body)
      matches = json['errors'].first['content'].match(/\A([^:]+):\s?(.+)/m)
      [matches[1], matches[2]]
    rescue
      raise OrientdbError.new("Could not parse Orientdb server error: #{json}", response.response_code, response.body)
    end

  end
end

OrientdbClient::logger = Logger.new(STDOUT)
