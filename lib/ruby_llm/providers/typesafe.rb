# frozen_string_literal: true

module RubyLLM
  module Providers
    # Connects TypeSafe's judgment models to RubyLLM.
    class TypeSafe < Provider
      protocol :system_one, Protocols::SystemOne

      def api_base
        configured_api_base(:typesafe_api_base, 'https://api.typesafe.ai', endpoints: %r{/v1/systemone\z})
      end

      def headers
        { 'Authorization' => "Bearer #{@config.typesafe_api_key}" }
      end

      def parse_error(response)
        protocols.fetch(:system_one).new(self).parse_error_response(response) || super
      end

      class << self
        def configuration_options
          %i[typesafe_api_key typesafe_api_base]
        end

        def configuration_requirements
          %i[typesafe_api_key]
        end
      end
    end
  end
end
