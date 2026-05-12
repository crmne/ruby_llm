# frozen_string_literal: true

module RubyLLM
  module Providers
    # OpenAI API integration.
    class OpenAI < Provider
      RESPONSE_ONLY_PARAMS = %i[
        previous_response_id
        include
        background
        conversation
        max_tool_calls
        truncation
        text
      ].freeze

      RESPONSE_TOOL_TYPES = %w[
        code_interpreter
        computer_use_preview
        file_search
        image_generation
        local_shell
        mcp
        web_search
        web_search_preview
      ].freeze

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
        request_params = params.dup
        requested_mode = extract_openai_api_mode!(request_params)
        routing_context = { messages:, model:, params: request_params, tools:, thinking: }
        @using_responses_api = native_openai_provider? && use_responses_api?(requested_mode, routing_context)
        validate_responses_attachments!(messages, requested_mode)

        native_tools = @using_responses_api ? extract_native_response_tools!(request_params) : nil
        normalized_temperature = maybe_normalize_temperature(temperature, model)
        payload_options = {
          tools: tools,
          tool_prefs: tool_prefs,
          temperature: normalized_temperature,
          model: model,
          stream: block_given?,
          schema: schema,
          thinking: thinking
        }
        payload_options[:native_tools] = native_tools if @using_responses_api

        payload = Utils.deep_merge(
          render_payload(messages, **payload_options),
          request_params
        )

        if block_given?
          stream_response @connection, payload, headers, &
        else
          sync_response @connection, payload, headers
        end
      end
      # rubocop:enable Metrics/ParameterLists

      def completion_url
        @using_responses_api ? responses_url : chat_completions_url
      end

      # rubocop:disable Metrics/ParameterLists
      def render_payload(messages, tools:, temperature:, model:, stream: false, schema: nil, thinking: nil,
                         tool_prefs: nil, native_tools: nil)
        if @using_responses_api
          render_response_payload(
            messages,
            tools: tools,
            native_tools: native_tools,
            tool_prefs: tool_prefs,
            temperature: temperature,
            model: model,
            stream: stream,
            schema: schema,
            thinking: thinking
          )
        else
          render_chat_payload(
            messages,
            tools: tools,
            tool_prefs: tool_prefs,
            temperature: temperature,
            model: model,
            stream: stream,
            schema: schema,
            thinking: thinking
          )
        end
      end
      # rubocop:enable Metrics/ParameterLists

      def parse_completion_response(response)
        if @using_responses_api
          parse_response_response(response)
        else
          parse_chat_completion_response(response)
        end
      end

      class << self
        def capabilities
          OpenAI::Capabilities
        end

        def configuration_options
          %i[
            openai_api_key
            openai_api_base
            openai_api_mode
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

      def extract_openai_api_mode!(params)
        value = params.delete(:openai_api_mode) || params.delete('openai_api_mode') || @config.openai_api_mode
        normalize_openai_api_mode(value)
      end

      def normalize_openai_api_mode(value)
        mode = (value || :auto).to_sym
        return mode if Configuration::OPENAI_API_MODES.include?(mode)

        raise ArgumentError,
              "Invalid openai_api_mode: #{value.inspect}. " \
              "Valid values are: #{Configuration::OPENAI_API_MODES.join(', ')}"
      end

      def use_responses_api?(requested_mode, routing_context)
        return true if requested_mode == :responses
        return false if requested_mode == :chat_completions
        return false if audio_input?(routing_context[:messages])

        responses_model?(routing_context[:model]) ||
          native_response_tools?(routing_context[:params]) ||
          responses_only_params?(routing_context[:params]) ||
          responses_required_for_reasoning_tools?(
            routing_context[:model],
            routing_context[:tools],
            routing_context[:thinking]
          )
      end

      def native_openai_provider?
        instance_of?(OpenAI)
      end

      def responses_model?(model)
        model.id.to_s.include?('deep-research')
      end

      def responses_required_for_reasoning_tools?(model, tools, thinking)
        return false unless tools.any? && resolve_effort(thinking)

        model.id.to_s.start_with?('gpt-5')
      end

      def responses_only_params?(params)
        RESPONSE_ONLY_PARAMS.any? { |key| params.key?(key) || params.key?(key.to_s) }
      end

      def native_response_tools?(params)
        tools = params[:tools] || params['tools']
        Utils.to_safe_array(tools).any? { |tool| native_response_tool?(tool) }
      end

      def native_response_tool?(tool)
        return false unless tool.is_a?(Hash)

        type = (tool[:type] || tool['type']).to_s
        return true if RESPONSE_TOOL_TYPES.include?(type)

        type == 'function' &&
          (tool.key?(:name) || tool.key?('name')) &&
          !(tool.key?(:function) || tool.key?('function'))
      end

      def extract_native_response_tools!(params)
        tools = params.delete(:tools) || params.delete('tools')
        Utils.to_safe_array(tools).select { |tool| native_response_tool?(tool) }
      end

      def validate_responses_attachments!(messages, requested_mode)
        return unless @using_responses_api && audio_input?(messages)
        return unless requested_mode == :responses

        raise UnsupportedAttachmentError, 'OpenAI Responses API does not support audio inputs yet'
      end

      def audio_input?(messages)
        messages.any? do |message|
          content = message.content
          content.respond_to?(:attachments) && content.attachments.any? { |attachment| attachment.type == :audio }
        end
      end
    end
  end
end
