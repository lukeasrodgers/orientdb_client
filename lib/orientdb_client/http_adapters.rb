module OrientdbClient
  module HttpAdapters
    SESSION_COOKIE_NAME = 'OSESSIONID'

    class Base
      attr_accessor :username, :password

      def initialize
        @username = nil
        @password = nil
        @session_id = nil
      end

      def reset_credentials
        @username = nil
        @password = nil
        @session_id = nil
      end

      def request
        raise NotImplementedError
      end
    end
  end
end
