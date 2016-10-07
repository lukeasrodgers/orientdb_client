module OrientdbClient
  module Instrumenters
    # Instrumentor that is useful for tests as it stores each of the events that
    # are instrumented.
    class Memory
      Event = Struct.new(:name, :payload, :result)

      attr_reader :events

      def initialize
        @events = []
      end

      def instrument(name, payload = {})
        result = nil
        begin
          result = yield payload
        rescue Exception => e
          payload[:exception] = [e.class.name, e.message]
          raise e
        ensure
          @events << Event.new(name, payload, result)
          result
        end
      end
    end
  end
end
