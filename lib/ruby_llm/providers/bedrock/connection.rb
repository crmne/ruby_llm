# frozen_string_literal: true

module RubyLLM
  module Providers
    class Bedrock
      # Keeps Bedrock's API paths under the configured endpoint. Faraday
      # resolves a leading slash against the host, which would drop the path of
      # an endpoint mounted behind a gateway.
      class Connection < Transport::Connection # :nodoc:
        private

        def prepare(request)
          super
          request.path = request.path.delete_prefix('/')
        end
      end
    end
  end
end
