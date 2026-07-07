# frozen_string_literal: true

module RubyLLM
  module Providers
    class OpenRouter
      # Chat methods of the OpenRouter API integration
      module Chat
        OPENROUTER_INLINE_FILE_THRESHOLD = 50 * 1024 * 1024
        OPENROUTER_FILE_UPLOAD_LIMIT = 100 * 1024 * 1024
        CACHE_CONTROL_TYPE = 'ephemeral'
        PROMPT_CACHE_OPTIONS = %i[ttl].freeze

        module_function

        # rubocop:disable Metrics/ParameterLists
        def render_payload(messages, tools:, temperature:, model:, stream: false, max_output_tokens: nil, schema: nil,
                           thinking: nil, citations: false, caching: nil, tool_prefs: nil)
          payload = super
          payload.delete(:reasoning_effort)
          strip_schema_strict(payload)

          reasoning = build_reasoning(thinking)
          payload[:reasoning] = reasoning if reasoning
          payload[:cache_control] = prompt_cache_control(caching) if caching && !cache_boundaries?(messages)
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

        def format_message_content(msg, caching: nil)
          content = super
          msg.cache_until_here? ? inject_cache_control(content, caching:) : content
        end

        def inject_cache_control(content, caching: nil)
          blocks = content.is_a?(Array) ? content.dup : [{ type: 'text', text: content }]
          return blocks if blocks.empty?

          last = blocks.last
          return blocks unless last.is_a?(Hash)
          return blocks if last[:cache_control] || last['cache_control']

          blocks[-1] = last.merge(cache_control: prompt_cache_control(caching))
          blocks
        end

        def prompt_cache_control(caching = nil)
          options = prompt_cache_options(caching)

          { type: CACHE_CONTROL_TYPE }.tap do |control|
            control[:ttl] = options[:ttl] if options[:ttl]
          end
        end

        def prompt_cache_options(caching)
          return {} unless caching

          options = caching.to_h.transform_keys(&:to_sym)
          unsupported = options.keys - PROMPT_CACHE_OPTIONS
          return options if unsupported.empty?

          raise ArgumentError,
                "OpenRouter prompt caching accepts :ttl, got #{format_cache_option_keys(unsupported)}"
        end

        def format_cache_option_keys(keys)
          keys.map { |key| ":#{key}" }.join(', ')
        end

        def cache_boundaries?(messages)
          messages.any?(&:cache_until_here?)
        end

        def supports_provider_file_references?
          true
        end

        def default_large_file_upload_threshold
          OPENROUTER_INLINE_FILE_THRESHOLD
        end

        def provider_file_upload_limit
          OPENROUTER_FILE_UPLOAD_LIMIT
        end

        def provider_file_attachable?(attachment)
          attachment.pdf?
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
