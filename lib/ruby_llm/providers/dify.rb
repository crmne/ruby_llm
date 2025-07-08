# frozen_string_literal: true

module RubyLLM
  module Providers
    module Dify
      extend Provider
      extend Dify::Media
      extend Dify::Chat
      extend Dify::Streaming

      module_function

      def api_base(config)
        config.dify_api_base
      end

      def parse_error(response)
        return if response.body.empty?

        body = try_parse_json(response.body)
        case body
        when Hash
          body['message']
        else
          body
        end
      end

      def headers(config)
        {
          'Authorization' => "Bearer #{config.dify_api_key}"
        }
      end

      def capabilities
        Dify::Capabilities
      end

      def slug
        'dify'
      end

      def configuration_requirements
        %i[dify_api_base dify_api_key]
      end

      def local?
        true
      end
    end
  end
end
