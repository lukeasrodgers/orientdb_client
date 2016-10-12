# From Skylight spec/support/tracing.rb

module SpecHelper
  class MockTrace
    attr_accessor :endpoint

    def initialize
      @endpoint = "Rack"
    end
  end

  def trace
    @trace ||= MockTrace.new
  end
end
