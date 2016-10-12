require 'skylight'
require 'uri'

module Skylight
  module Normalizers
    module OrientdbClient
      class Query < Normalizer
        register "request.orientdb_client"

        CAT = "db.orientdb.query".freeze
        QUERY_REGEX = /\/([^\/]+)/
        SUPPORTED_QUERY_TYPES = ["query".freeze, "command".freeze]

        def normalize(trace, name, payload)
          url = payload[:url]
          query_type = nil
          begin
            uri = URI.parse(url)
            match = uri.path.match(QUERY_REGEX)
            if match
              query_type = match[1]
            end
          rescue URI::Error
            return :skip
          end

          return :skip unless SUPPORTED_QUERY_TYPES.include?(query_type)

          [ CAT, "orientdb: #{query_type}", nil ]
        end
      end
    end
  end
end
