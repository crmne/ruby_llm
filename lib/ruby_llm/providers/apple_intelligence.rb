# frozen_string_literal: true

module RubyLLM
  module Providers
    # Apple Intelligence provider — pipes requests through the osx-ai-inloop
    # binary via stdin/stdout, completely bypassing HTTP/Faraday.
    class AppleIntelligence < Provider
      include AppleIntelligence::Chat
      include AppleIntelligence::Models

      def initialize(config)
        @config = config
        @connection = nil
      end

      def api_base
        nil
      end

      def complete(messages, tools: nil, temperature: nil, model: nil, params: {}, headers: {}, schema: nil,
                   thinking: nil, tool_prefs: nil, &)
        payload = build_payload(messages, tools: tools)
        execute_binary(payload, @config)
      end

      class << self
        def configuration_options
          %i[apple_intelligence_binary_path]
        end

        def configuration_requirements
          []
        end

        def local?
          true
        end

        def assume_models_exist?
          true
        end

        def capabilities
          AppleIntelligence::Capabilities
        end
      end
    end
  end
end
