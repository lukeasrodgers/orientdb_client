require "orientdb_client/version"
require "orientdb_client/errors"
require "orientdb_client/http_adapters"
require "orientdb_client/http_adapters/typhoeus_adapter"
require "orientdb_client/class_configurator"

require 'oj'
require 'cgi'
require 'logger'
require 'rainbow'

module OrientdbClient
  class << self
    def client(options = {})
      Client.new(options)
    end
  end

  DATABASE_TYPES = ['document', 'graph']

  class Client
    attr_reader :http_client
    attr_accessor :logger

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
      @node = Node.new(host: @host, port: @port, http_client: @http_client, client: self)
      @connected = false
      @logger = Logger.new(STDOUT)
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
      response = @node.create_class(name, options)
      if block_given?
        yield ClassConfigurator.new(name, @node)
      end
      response
    end

    def create_property(class_name, property_name, type, options = {})
      @node.create_property(class_name, property_name, type, options)
    end

    def alter_property(class_name, property_name, field, value)
      @node.alter_property(class_name, property_name, field, value)
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

    def get_database(name, options = {})
      @node.get_database(name, options)
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

    def initialize(host:, port:, http_client: http_client, client: client)
      @host = host
      @port = port
      @http_client = http_client
      @client = client
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

    def get_database(name, options)
      r = request(:get, "database/#{name}", options)
      r = parse_response(r)
    rescue UnauthorizedError => e
      # Attempt to get not-found db, when connected, will return 401 error.
      if connected?
        raise NotFoundError.new("Database #{name} not found, or you are not authorized to access it.", 401)
      else
        raise e
      end
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

    def create_property(class_name, property_name, type, options)
      command("CREATE PROPERTY #{class_name}.#{property_name} #{type}")
      options.each do |k, v|
        alter_property(class_name, property_name, k, v)
      end
    end

    def alter_property(class_name, property_name, field, value)
      command("ALTER PROPERTY #{class_name}.#{property_name} #{field} #{value}")
    end

    def query(sql, options)
      parse_response(query_unparsed(sql, options))['result']
    end

    def query_unparsed(sql, options)
      limit = limit_string(options)
      request(:get, "query/#{@database}/sql/#{CGI::escape(sql)}#{limit}")
    rescue NegativeArraySizeException
      raise NotFoundError
    end

    def command(sql)
      r = request(:post, "command/#{@database}/sql/#{CGI::escape(sql)}")
      parse_response(r)
    end

    def get_class(name)
      r = request(:get, "class/#{@database}/#{name}")
      parse_response(r)
    rescue IllegalArgumentException
      raise NotFoundError
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
      info("request (#{time}), #{response.response_code}: #{method} #{url}")
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
        translate_error(response)
      when 500
        translate_error(response)
      else
        raise ServerError.new("Unexpected HTTP status code: #{response.response_code}", response.response_code, response.body)
      end
    end

    def parse_response(response)
      return nil if response.body.empty?
      @debug ? response : Oj.load(response.body)
    end

    def limit_string(options)
      options[:limit] ? "/#{options[:limit]}" : ''
    end

    def translate_error(response)
      odb_error_class, odb_error_message = if response.content_type.start_with?('application/json')
         extract_odb_error_from_json(response)
      else
        extract_odb_error_from_text(response)
      end
      code = response.response_code
      body = response.body
      case odb_error_class
      when /OCommandSQLParsingException/
        raise ClientError.new("#{odb_error_class}: #{odb_error_message}", code, body)
      when /OQueryParsingException/
        raise ClientError.new("#{odb_error_class}: #{odb_error_message}", code, body)
      when /OCommandExecutorNotFoundException/
        raise ClientError.new("#{odb_error_class}: #{odb_error_message}", code, body)
      when /IllegalArgumentException/
        raise IllegalArgumentException.new("#{odb_error_class}: #{odb_error_message}", code, body)
      when /OConfigurationException/
        raise ClientError.new("#{odb_error_class}: #{odb_error_message}", code, body)
      when /OCommandExecutionException/
        raise CommandExecutionException.new("#{odb_error_class}: #{odb_error_message}", code, body)
      when /OSchemaException|OIndexException/
        raise ClientError.new("#{odb_error_class}: #{odb_error_message}", code, body)
      when /OConcurrentModification/
        raise MVCCError.new("#{odb_error_class}: #{odb_error_message}", response.response_code, response.body)
      when /IllegalStateException/
        raise ServerError.new("#{odb_error_class}: #{odb_error_message}", response.response_code, response.body)
      when /ORecordDuplicate/
        raise DuplicateRecordError.new("#{odb_error_class}: #{odb_error_message}", response.response_code, response.body)
      when /OTransactionException/
        if odb_error_message.match(/ORecordDuplicate/)
          raise DistributedDuplicateRecordError.new("#{odb_error_class}: #{odb_error_message}", response.response_code, response.body)
        elsif odb_error_message.match(/distributed/)
          raise DistributedTransactionException.new("#{odb_error_class}: #{odb_error_message}", response.response_code, response.body)
        else
          raise TransactionException.new("#{odb_error_class}: #{odb_error_message}", response.response_code, response.body)
        end
      when /ODatabaseException/
        if odb_error_message.match(/already exists/)
          klass = ConflictError
        else
          klass = ServerError
        end
        raise klass.new("#{odb_error_class}: #{odb_error_message}", response.response_code, response.body)
      when /ODistributedRecordLockedException/
        raise DistributedRecordLockedException.new("#{odb_error_class}: #{odb_error_message}", response.response_code, response.body)
      when /OSerializationException/
        raise SerializationException.new("#{odb_error_class}: #{odb_error_message}", response.response_code, response.body)
      end
    end

    def extract_odb_error_from_json(response)
      body = response.body
      json = Oj.load(body)
      # odb > 2.1 (?) errors are in JSON format
      matches = json['errors'].first['content'].match(/\A([^:]+):?\s?(.*)/m)
      [matches[1], matches[2]]
    rescue => e
      if (response.body.match(/Database.*already exists/))
        raise ConflictError.new(e.message, response.response_code, response.body)
      elsif (response.body.match(/NegativeArraySizeException/))
        raise NegativeArraySizeException.new(e.message, response.response_code, response.body)
      else
        raise OrientdbError.new("Could not parse Orientdb server error", response.response_code, response.body)
      end
    end

    def extract_odb_error_from_text(response)
      body = response.body
      matches = body.match(/\A([^:]+):\s(.*)$/)
      [matches[1], matches[2]]
    rescue => e
      if (response.body.match(/Database.*already exists/))
        raise ConflictError.new(e.message, response.response_code, response.body)
      elsif (response.body.match(/NegativeArraySizeException/))
        raise NegativeArraySizeException.new(e.message, response.response_code, response.body)
      else
        raise OrientdbError.new("Could not parse Orientdb server error", response.response_code, response.body)
      end
    end

    def info(message)
      wrapped_message = "#{Rainbow('OrientdbClient:').yellow} #{message}"
      @client.logger.info(wrapped_message)
    end

  end
end
