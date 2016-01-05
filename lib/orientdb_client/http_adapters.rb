module OrientdbClient
  module HttpAdapters
    SESSION_COOKIE_NAME = 'OSESSIONID'

    class Base
      attr_accessor :username, :password

      def initialize(timeout: nil)
        @username = nil
        @password = nil
        @session_id = nil
        @timeout = timeout
        after_initialize
      end

      def reset_credentials
        @username = nil
        @password = nil
        @session_id = nil
      end

      def request
        raise NotImplementedError
      end

      private

      def timed_out!(method, url)
        raise OrientdbClient::Timeout, "#{method}: #{url}"
      end

      def after_initialize
        # noop, override me as necessary
      end
    end
  end
end
