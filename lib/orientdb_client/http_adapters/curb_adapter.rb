require 'curb'

module OrientdbClient
  module HttpAdapters
    class CurbAdapter < Base

      def request(method, url, options = {})
        req = prepare_request(method, url, options)
        run_request(req, method)
        req
      rescue Curl::Err::TimeoutError
        timed_out!(method, url)
      end

      private

      def after_initialize
        @curl = Curl::Easy.new
      end
      
      def prepare_request(method, url, options)
        username = options[:username] || @username
        password = options[:password] || @password
        @curl.url = url
        @curl.http_auth_types = :basic
        @curl.username = username
        @curl.password = password
        if timeout = @timeout || options[:timeout]
          @curl.timeout = timeout
        end
        @curl
      end

      def run_request(request, method)
        request.public_send(method)
      end
    end
  end
end
