require 'typhoeus'

module OrientdbClient
  module HttpAdapters
    class TyphoeusAdapter < Base

      def request(method, url, options = {})
        req = prepare_request(method, url, options)
        response = run_request(req)
        if response.return_message == "Couldn't connect to server".freeze
          raise ConnectionError
        elsif response.timed_out?
          timed_out!(method, url)
        else
          return response
        end
      end

      private

      def prepare_request(method, url, options)
        options = {
          userpwd: authentication_string(options),
          method: method
        }.merge(options)
        if timeout = @timeout || options[:timeout]
          options[:timeout] = timeout
        end
        Typhoeus::Request.new(url, options)
      end

      def run_request(request)
        request.run
        response = request.response
        if cookies = response.headers['Set-Cookie']
          @session_id = extract_session_id(cookies)
        end
        # TODO hacky, replace with response adpater object probably
        def response.content_type
          headers['Content-Type']
        end
        response
      end

      def authentication_string(options)
        username = options[:username] || @username
        password = options[:password] || @password
        "#{username}:#{password}"
      end

      def extract_session_id(cookies)
        r = Regexp.new("#{SESSION_COOKIE_NAME}=([^\s;]+)")
        if cookies.is_a?(Array)
          return cookies.detect { |cookie| cookie.match(r) != nil }.
            match(r)[1]
        else
          return cookies.match(r)[1]
        end
      end

    end
  end
end
