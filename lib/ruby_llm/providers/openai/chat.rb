# frozen_string_literal: true

require_relative '../structured_output_parser'

module RubyLLM
  module Providers
    module OpenAI
      # Chat methods of the OpenAI API integration
      module Chat
        include RubyLLM::Providers::StructuredOutputParser

        module_function

        def completion_url
          'chat/completions'
        end

        def render_payload(messages, tools:, temperature:, model:, stream: false, response_format: nil) # rubocop:disable Metrics/MethodLength,Metrics/ParameterLists
          {
            model: model,
            messages: format_messages(messages),
            temperature: temperature,
            stream: stream
          }.tap do |payload|
            if tools.any?
              payload[:tools] = tools.map { |_, tool| tool_for(tool) }
              payload[:tool_choice] = 'auto'
            end
            payload[:stream_options] = { include_usage: true } if stream

            # Add structured output schema if provided
            payload[:response_format] = format_response_format(response_format) if response_format
          end
        end

        def parse_completion_response(response, response_format: nil)
          data = response.body
          return if data.empty?

          message_data = data.dig('choices', 0, 'message')
          return unless message_data

          content = message_data['content']

          # Parse JSON content if schema was provided
          content = parse_structured_output(content) if response_format && content

          Message.new(
            role: :assistant,
            content: content,
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
              content: Media.format_content(msg.content),
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

        # Formats the response format for OpenAI API
        # @param response_format [Hash, Symbol] The response format from the chat object
        # @return [Hash] The formatted response format for the OpenAI API
        def format_response_format(response_format)
          # Handle simple :json case
          return { type: 'json_object' } if response_format == :json

          # Handle schema case (a Hash)
          raise ArgumentError, "Invalid response format: #{response_format}" unless response_format.is_a?(Hash)

          # Support to provide full response format, must include type: json_schema and json_schema: { name: 'Name', schema: ... }
          return response_format if response_format.key?(:json_schema)

          {
            type: 'json_schema',
            json_schema: {
              name: 'extract',
              schema: response_format
            }
          }
        end
      end
    end
  end
end
