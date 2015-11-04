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

  # ServerError: server has rejected your command/query because
  # processing it would violate some invariant
  class ServerError < OrientdbError; end
  class TransactionException < ServerError; end
  class DistributedTransactionException < TransactionException; end
  class MVCCError < ServerError; end

  # ClientError: you did something wrong
  class ClientError < OrientdbError; end
  class UnauthorizedError < ClientError; end
  class IllegalArgumentException < ClientError; end
  class CommandExecutionException < ClientError; end

  # ConflictError: you tried to create something that already exists
  class ConflictError < ClientError; end
  class DuplicateRecordError < ConflictError; end

  class NotFoundError < OrientdbError; end

  class NegativeArraySizeException < OrientdbError; end
end
