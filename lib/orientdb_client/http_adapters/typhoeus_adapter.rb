require 'typhoeus'

module OrientdbClient
  module HttpAdapters
    class TyphoeusAdapter < Base

      def request(method, url, options = {})
        req = prepare_request(method, url, options)
        run_request(req)
      end

      private

      def prepare_request(method, url, options)
        options = {
          userpwd: authentication_string(options),
          method: method
        }.merge(options)
        Typhoeus::Request.new(url, options)
      end

      def run_request(request)
        request.run
        response = request.response
        if cookies = response.headers['Set-Cookie']
          @session_id = extract_session_id(cookies)
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
