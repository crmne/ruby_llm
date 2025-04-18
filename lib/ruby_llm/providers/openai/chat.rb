# frozen_string_literal: true

module RubyLLM
  module Providers
    module OpenAI
      # Chat methods of the OpenAI API integration
      module Chat
        module_function

        def completion_url
          'chat/completions'
        end

        def render_payload(messages, tools:, temperature:, model:, stream: false, chat: nil) # rubocop:disable Metrics/MethodLength,Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity,Metrics/ParameterLists
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
            if chat&.output_schema
              payload[:response_format] = { type: 'json_object' }
            end
          end
        end

        def parse_completion_response(response, chat: nil) # rubocop:disable Metrics/MethodLength,Metrics/AbcSize
          data = response.body
          return if data.empty?

          message_data = data.dig('choices', 0, 'message')
          return unless message_data

          content = message_data['content']

          # Parse JSON content if schema was provided
          if chat&.output_schema && content
            begin
              parsed_json = JSON.parse(content)
              content = parsed_json
            rescue JSON::ParserError => e
              raise InvalidStructuredOutput, "Failed to parse JSON from model response: #{e.message}"
            end
          end

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
      end
    end
  end
end
