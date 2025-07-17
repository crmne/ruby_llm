# frozen_string_literal: true

module RubyLLM
  module Providers
    module OpenRouter
      # Chat methods of the OpenRouter API integration
      module Chat
        def completion_url
          'chat/completions'
        end

        module_function

        def render_payload(messages, tools:, temperature:, model:, stream: false) # rubocop:disable Metrics/MethodLength
          {
            model: model,
            messages: format_messages(messages),
            temperature: temperature,
            stream: stream,
            provider: format_provider_options # @todo Allow for assistant overriding
          }.tap do |payload|
            if tools.any?
              payload[:tools] = tools.map { |_, tool| tool_for(tool) }
              payload[:tool_choice] = 'auto'
            end
            payload[:stream_options] = { include_usage: true } if stream
          end
        end

        def parse_completion_response(response) # rubocop:disable Metrics/MethodLength
          data = response.body
          return if data.empty?

          raise Error.new(response, data.dig('error', 'message')) if data.dig('error', 'message')

          message_data = data.dig('choices', 0, 'message')
          return unless message_data

          Message.new(
            role: :assistant,
            content: message_data['content'],
            tool_calls: parse_tool_calls(message_data['tool_calls']),
            input_tokens: data['usage']['prompt_tokens'],
            output_tokens: data['usage']['completion_tokens'],
            model_id: data['model']
          )
        end

        def format_messages(messages)
          messages.map do |msg|
            {
              role: format_role(msg.role),
              content: self::Media.format_content(msg.content),
              tool_calls: format_tool_calls(msg.tool_calls),
              tool_call_id: msg.tool_call_id
            }.compact
          end
        end

        def format_role(role)
          case role
          when :system
            'developer'
          else
            role.to_s
          end
        end

        def format_provider_options
          {
            order: @connection.config.openrouter_provider_order,
            allow_fallbacks: @connection.config.openrouter_provider_allow_fallbacks,
            require_parameters: @connection.config.openrouter_provider_require_parameters,
            data_collection: @connection.config.openrouter_provider_data_collection,
            ignore: @connection.config.openrouter_provider_ignore,
            quantizations: @connection.config.openrouter_provider_quantizations,
            sort: @connection.config.openrouter_provider_sort
          }.compact
        end
      end
    end
  end
end
