# frozen_string_literal: true

module RubyLLM
  module Providers
    # Apple Intelligence provider — pipes requests through the osx-ai-inloop
    # binary via stdin/stdout, completely bypassing HTTP/Faraday.
    class AppleIntelligence < Provider
      include AppleIntelligence::Chat
      include AppleIntelligence::Models

      def initialize(config)
        super
        @config = config
        @connection = nil
      end

      def api_base
        nil
      end

      # rubocop:disable Metrics/ParameterLists,Metrics/PerceivedComplexity
      def complete(messages, tools: nil, temperature: nil, model: nil, params: {}, headers: {}, schema: nil,
                   thinking: nil, tool_prefs: nil, &)
        _ = [temperature, model, params, headers, schema, thinking, tool_prefs] # not used for local provider

        # Two-pass tool calling: if tools are registered and we haven't already
        # executed a tool (no :tool messages yet), extract arguments and call.
        if tools&.any? && messages.none? { |m| m.role == :tool }
          last_user = messages.reverse.find { |m| m.role == :user }
          tool_msg = try_tool_call(tools, last_user, @config) if last_user
          return tool_msg if tool_msg
        end

        payload = build_payload(messages)
        execute_binary(payload, @config)
      end
      # rubocop:enable Metrics/ParameterLists,Metrics/PerceivedComplexity

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

      private

      def try_tool_call(tools, last_user, config)
        user_text = case last_user.content
                    when String then last_user.content
                    when Content then last_user.content.text || ''
                    else last_user.content.to_s
                    end
        tool_result = resolve_tool_call(tools, user_text, config)
        return unless tool_result

        Message.new(
          role: :assistant,
          content: '',
          tool_calls: tool_result,
          model_id: 'apple-intelligence',
          input_tokens: 0,
          output_tokens: 0
        )
      end
    end
  end
end
