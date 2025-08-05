# frozen_string_literal: true

module RubyLLM
  module Providers
    module OpenAI
      # Chat methods of the OpenAI API integration
      module Chat
        def completion_url
          'chat/completions'
        end

        def responses_url
          'responses'
        end

        module_function

        def render_payload(messages, tools:, temperature:, model:, stream: false, schema: nil) # rubocop:disable Metrics/ParameterLists
          payload = {
            model: model,
            messages: format_messages(messages),
            stream: stream
          }

          # Only include temperature if it's not nil (some models don't accept it)
          payload[:temperature] = temperature unless temperature.nil?

          if tools.any?
            payload[:tools] = tools.map { |_, tool| chat_tool_for(tool) }
            payload[:tool_choice] = 'auto'
          end

          payload[:stream_options] = { include_usage: true } if stream
          payload
        end

        def render_response_payload(messages, tools:, temperature:, model:, stream: false)
          payload = {
            model: model,
            input: format_input(messages),
            stream: stream
          }

          # Only include temperature if it's not nil (some models don't accept it)
          payload[:temperature] = temperature unless temperature.nil?

          if tools.any?
            payload[:tools] = tools.map { |_, tool| response_tool_for(tool) }
            payload[:tool_choice] = 'auto'
          end

          if schema
            # Use strict mode from schema if specified, default to true
            strict = schema[:strict] != false

            payload[:response_format] = {
              type: 'json_schema',
              json_schema: {
                name: 'response',
                schema: schema,
                strict: strict
              }
            }
          end

          payload[:stream_options] = { include_usage: true } if stream
          payload
        end

        def parse_completion_response(response)
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
            model_id: data['model'],
            raw: response
          )
        end

        def parse_respond_response(response)
          data = response.body
          return if data.empty?

          raise Error.new(response, data.dig('error', 'message')) if data.dig('error', 'message')

          outputs = data['output']
          return unless outputs.any?

          Message.new(
            role: :assistant,
            content: all_output_text(outputs),
            tool_calls: parse_response_tool_calls(outputs),
            input_tokens: data['usage']['input_tokens'],
            output_tokens: data['usage']['output_tokens'],
            model_id: data['model']
          )
        end

        def all_output_text(outputs)
          outputs.select { |o| o['type'] == 'message' }.flat_map do |o|
            output_texts = o['content'].select { |c| c['type'] == 'output_text' }
            output_texts.map { |c| c['text'] }.join("\n")
          end
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

        def format_input(messages) # rubocop:disable Metrics/PerceivedComplexity
          all_tool_calls = messages.flat_map do |m|
            m.tool_calls&.values || []
          end
          messages.flat_map do |msg|
            if msg.tool_call?
              msg.tool_calls.map do |_, tc|
                {
                  type: 'function_call',
                  call_id: tc.id,
                  name: tc.name,
                  arguments: JSON.generate(tc.arguments),
                  status: 'completed'
                }
              end
            elsif msg.role == :tool
              {
                type: 'function_call_output',
                call_id: all_tool_calls.detect { |tc| tc.id == msg.tool_call_id }&.id,
                output: msg.content,
                status: 'completed'
              }
            else
              {
                type: 'message',
                role: format_role(msg.role),
                content: Media.format_content(msg.content),
                status: 'completed'
              }.compact
            end
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
