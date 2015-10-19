require 'curb'
require 'byebug'

module OrientdbClient
  module HttpAdapters
    class CurbAdapter < Base

      # def initialize
        # super
        # @curl = Curl::Easy.new
      # end

      def request(method, url, options = {})
        req = prepare_request(method, url, options)
        run_request(req, method)
        req
      end

      private
      
      def prepare_request(method, url, options)
        username = options[:username] || @username
        password = options[:password] || @password
        r = Curl::Easy.new(url) do |curl|
          curl.http_auth_types = :basic
          curl.username = username
          curl.password = password
        end
        r
      end

      def run_request(request, method)
        request.public_send(method)
      end
    end
  end
end
