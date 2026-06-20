# frozen_string_literal: true

module RubyLLM
  module Providers
    class Requesty
      # Chat methods of the Requesty API integration
      module Chat
        module_function

        # rubocop:disable Metrics/ParameterLists
        def render_payload(messages, tools:, temperature:, model:, stream: false, schema: nil,
                           thinking: nil, citations: false, tool_prefs: nil)
          payload = super
          payload.delete(:reasoning_effort)
          strip_schema_strict(payload)

          reasoning = build_reasoning(thinking)
          payload[:reasoning] = reasoning if reasoning
          payload
        end
        # rubocop:enable Metrics/ParameterLists

        def strip_schema_strict(payload)
          schema_def = payload.dig(:response_format, :json_schema, :schema)
          return unless schema_def.is_a?(Hash)

          schema_def = RubyLLM::Utils.deep_dup(schema_def)
          schema_def.delete(:strict)
          schema_def.delete('strict')
          payload[:response_format][:json_schema][:schema] = schema_def
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
