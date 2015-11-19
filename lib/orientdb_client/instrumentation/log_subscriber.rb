require 'active_support/notifications'
require 'active_support/log_subscriber'

module OrientdbClient
  module Instrumentation
    class LogSubscriber < ::ActiveSupport::LogSubscriber
      def request(event)
        return unless logger.debug?

        method = event.payload[:method]
        response_code = event.payload[:response_code]
        url = event.payload[:url]
        request = "#{method} #{url}: #{response_code}"

        name = '%s (%.1fms)' % ["OrientdbClient request", event.duration]
        debug "  #{color(name, YELLOW, true)}  [ #{request} ]"
      end
    end
  end
end

OrientdbClient::Instrumentation::LogSubscriber.attach_to :orientdb_client
