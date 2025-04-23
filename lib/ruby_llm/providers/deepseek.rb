# frozen_string_literal: true

module RubyLLM
  module Providers
    # DeepSeek API integration.
    module DeepSeek
      extend OpenAI
      extend DeepSeek::Chat

      module_function

      def api_base(_config)
        'https://api.deepseek.com'
      end

      def headers(config)
        {
          'Authorization' => "Bearer #{config.deepseek_api_key}"
        }
      end

      def capabilities
        DeepSeek::Capabilities
      end

      def slug
        'deepseek'
      end

      def configuration_requirements
        %i[deepseek_api_key]
      end
    end
  end
end
