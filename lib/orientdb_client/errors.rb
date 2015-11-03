module OrientdbClient
  class OrientdbError < StandardError
    attr_reader :http_code, :response_body

    def initialize(message = nil, http_code = nil, response_body = nil)
      super(message)
      @http_code = http_code
      @response_body = response_body
    end
  end

  class ConnectionError < OrientdbError; end

  class ServerError < OrientdbError; end

  class ClientError < OrientdbError; end
  class UnauthorizedError < ClientError; end
  class IllegalArgumentException < ClientError; end
  class CommandExecutionException < ClientError; end

  class ConflictError < ClientError; end
  class MVCCError < ConflictError; end

  class NotFoundError < OrientdbError; end
end
