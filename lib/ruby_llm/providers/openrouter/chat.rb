# frozen_string_literal: true

module RubyLLM
  module Providers
    class OpenRouter
      # Chat methods of the OpenRouter API integration
      module Chat
        module_function

        def render_payload(messages, tools:, temperature:, model:, stream: false, schema: nil, thinking: nil) # rubocop:disable Metrics/ParameterLists
          payload = {
            model: model.id,
            messages: format_messages(messages),
            stream: stream
          }

          payload[:temperature] = temperature unless temperature.nil?
          payload[:tools] = tools.map { |_, tool| OpenAI::Tools.tool_for(tool) } if tools.any?

          if schema
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

          reasoning = build_reasoning(thinking)
          payload[:reasoning] = reasoning if reasoning

          payload[:stream_options] = { include_usage: true } if stream
          payload
        end

        def parse_completion_response(response)
          data = response.body
          return if data.empty?

          raise Error.new(response, data.dig('error', 'message')) if data.dig('error', 'message')

          message_data = data.dig('choices', 0, 'message')
          return unless message_data

          usage = data['usage'] || {}
          cached_tokens = usage.dig('prompt_tokens_details', 'cached_tokens')
          thinking_tokens = usage.dig('completion_tokens_details', 'reasoning_tokens')
          thinking_text = extract_thinking_text(message_data)
          thinking_signature = extract_thinking_signature(message_data)

          Message.new(
            role: :assistant,
            content: message_data['content'],
            thinking: Thinking.build(text: thinking_text, signature: thinking_signature),
            tool_calls: OpenAI::Tools.parse_tool_calls(message_data['tool_calls']),
            input_tokens: usage['prompt_tokens'],
            output_tokens: usage['completion_tokens'],
            cached_tokens: cached_tokens,
            cache_creation_tokens: 0,
            thinking_tokens: thinking_tokens,
            model_id: data['model'],
            raw: response
          )
        end

        def format_messages(messages)
          messages.map do |msg|
            {
              role: format_role(msg.role),
              content: OpenAI::Media.format_content(msg.content),
              tool_calls: OpenAI::Tools.format_tool_calls(msg.tool_calls),
              tool_call_id: msg.tool_call_id
            }.compact.merge(format_thinking(msg))
          end
        end

        def format_role(role)
          case role
          when :system
            @config.openai_use_system_role ? 'system' : 'developer'
          else
            role.to_s
          end
        end

        def build_reasoning(thinking)
          return nil unless thinking&.enabled?

          reasoning = {}
          reasoning[:effort] = thinking.effort if thinking.respond_to?(:effort) && thinking.effort
          reasoning[:max_tokens] = thinking.budget if thinking.respond_to?(:budget) && thinking.budget
          reasoning[:enabled] = true if reasoning.empty?
          reasoning
        end

        def format_thinking(msg)
          thinking = msg.thinking
          return {} unless thinking && msg.role == :assistant

          details = []
          if thinking.text
            details << {
              type: 'reasoning.text',
              text: thinking.text,
              signature: thinking.signature
            }.compact
          elsif thinking.signature
            details << {
              type: 'reasoning.encrypted',
              data: thinking.signature
            }
          end

          details.empty? ? {} : { reasoning_details: details }
        end

        def extract_thinking_text(message_data)
          candidate = message_data['reasoning']
          return candidate if candidate.is_a?(String)

          details = message_data['reasoning_details']
          return nil unless details.is_a?(Array)

          text = details.filter_map do |detail|
            case detail['type']
            when 'reasoning.text'
              detail['text']
            when 'reasoning.summary'
              detail['summary']
            end
          end.join

          text.empty? ? nil : text
        end

        def extract_thinking_signature(message_data)
          details = message_data['reasoning_details']
          return nil unless details.is_a?(Array)

          signature = details.filter_map do |detail|
            detail['signature'] if detail['signature'].is_a?(String)
          end.first
          return signature if signature

          encrypted = details.find { |detail| detail['type'] == 'reasoning.encrypted' && detail['data'].is_a?(String) }
          encrypted&.dig('data')
        end
      end
    end
  end
end
