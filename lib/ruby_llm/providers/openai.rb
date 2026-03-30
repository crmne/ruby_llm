# frozen_string_literal: true

module RubyLLM
  module Providers
    # OpenAI API integration.
    class OpenAI < Provider
      include OpenAI::Chat
      include OpenAI::Embeddings
      include OpenAI::Models
      include OpenAI::Moderation
      include OpenAI::Streaming
      include OpenAI::Tools
      include OpenAI::Images
      include OpenAI::Media
      include OpenAI::Transcription

      def api_base
        @config.openai_api_base || 'https://api.openai.com/v1'
      end

      def headers
        {
          'Authorization' => "Bearer #{@config.openai_api_key}",
          'OpenAI-Organization' => @config.openai_organization_id,
          'OpenAI-Project' => @config.openai_project_id
        }.compact
      end

      def maybe_normalize_temperature(temperature, model)
        OpenAI::Temperature.normalize(temperature, model.id)
      end

      # rubocop:disable Metrics/ParameterLists
      def complete(messages, tools:, temperature:, model:, params: {}, headers: {}, schema: nil, thinking: nil,
                   tool_prefs: nil, &)
        super(
          messages,
          tools: tools,
          tool_prefs: tool_prefs,
          temperature: temperature,
          model: model,
          params: normalize_params(params),
          headers: headers,
          schema: schema,
          thinking: thinking,
          &
        )
      end
      # rubocop:enable Metrics/ParameterLists

      class << self
        def capabilities
          OpenAI::Capabilities
        end

        def configuration_options
          %i[
            openai_api_key
            openai_api_base
            openai_organization_id
            openai_project_id
            openai_use_system_role
          ]
        end

        def configuration_requirements
          %i[openai_api_key]
        end
      end

      private

      def normalize_params(params)
        normalized = RubyLLM::Utils.deep_symbolize_keys(params || {})
        max_tokens = normalized[:max_tokens]

        return normalized if max_tokens.nil? || normalized.key?(:max_completion_tokens)

        normalized.merge(max_completion_tokens: max_tokens)
      end
    end
  end
end
