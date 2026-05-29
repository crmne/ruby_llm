# frozen_string_literal: true

module RubyLLM
  module Providers
    # OpenAI API integration.
    class OpenAI < Provider
      include OpenAI::Chat
      include OpenAI::Responses
      include OpenAI::Embeddings
      include OpenAI::Models
      include OpenAI::Moderation
      include OpenAI::Streaming
      include OpenAI::Tools
      include OpenAI::Images
      include OpenAI::Media
      include OpenAI::Transcription

      # reasoning_effort + function tools is unsupported on /v1/chat/completions
      # (OpenAI 400s, "use /v1/responses instead"). When a turn requests thinking
      # AND ships tools, render the Responses-API payload instead; the flag is read
      # back by completion_url / parse_completion_response within this same
      # Provider#complete call. Routing lives here (not in OpenAI::Chat) so the
      # module-function render_payload stays pure chat/completions, while the
      # OpenAI::Responses helpers resolve against this instance (which mixes both in).
      def render_payload(messages, tools:, temperature:, model:, stream: false, schema: nil, # rubocop:disable Metrics/ParameterLists
                         thinking: nil, tool_prefs: nil)
        # Only the genuine OpenAI provider has /v1/responses — subclasses
        # (Azure/OpenRouter/Mistral/Perplexity/xAI/GPUStack) keep chat/completions.
        @openai_responses_mode = instance_of?(RubyLLM::Providers::OpenAI) &&
                                 responses_api?(tools: tools, thinking: thinking)
        return super unless @openai_responses_mode

        render_responses_payload(messages, tools: tools, model: model, stream: stream,
                                           schema: schema, thinking: thinking, tool_prefs: tool_prefs)
      end

      # Streaming over the Responses API uses a different SSE event set than
      # chat/completions and is not implemented yet. Reasoning+tools turns route
      # to Responses (see OpenAI::Responses#responses_api?), so guard streaming
      # there explicitly instead of mis-parsing chat/completions events.
      def stream_response(connection, payload, additional_headers = {}, &)
        if @openai_responses_mode
          raise RubyLLM::Error.new(nil, 'OpenAI Responses streaming not implemented yet; call without a block')
        end

        super
      end

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
    end
  end
end
