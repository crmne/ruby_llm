# frozen_string_literal: true

module RubyLLM
  module Providers
    class Mistral
      # Chat methods for Mistral API
      module Chat
        PROMPT_CACHE_OPTIONS = %i[key].freeze

        module_function

        def format_role(role)
          role.to_s
        end

        def render_payload(messages, tools:, temperature:, model:, stream: false, max_output_tokens: nil,
                           schema: nil, thinking: nil, citations: false, caching: nil, tool_prefs: nil)
          payload = super
          payload.delete(:stream_options)
          configure_thinking_payload(payload, model, thinking)
          normalize_required_tool_choice(payload)
          payload.merge!(prompt_cache_params(caching)) if caching
          payload
        end

        def openai_prompt_caching?
          false
        end

        def prompt_cache_params(caching)
          options = prompt_cache_options(caching)

          {}.tap do |params|
            params[:prompt_cache_key] = options[:key] if options[:key]
          end
        end

        def prompt_cache_options(caching)
          options = caching.to_h.transform_keys(&:to_sym)
          unsupported = options.keys - PROMPT_CACHE_OPTIONS
          return options if unsupported.empty?

          raise ArgumentError, "Mistral prompt caching accepts :key, got #{format_cache_option_keys(unsupported)}"
        end

        def format_cache_option_keys(keys)
          keys.map { |key| ":#{key}" }.join(', ')
        end

        def build_tool_choice(tool_choice)
          return 'any' if tool_choice == :required

          Protocols::ChatCompletions::Tools.build_tool_choice(tool_choice)
        end

        def normalize_required_tool_choice(payload)
          return unless payload[:tool_choice] == 'any' && Array(payload[:tools]).one?

          function_name = payload.dig(:tools, 0, :function, :name)
          return unless function_name

          payload[:tool_choice] = {
            type: 'function',
            function: { name: function_name }
          }
        end

        # Mistral carries reasoning in content blocks, not in the top-level
        # reasoning fields the rest of the Chat Completions family uses.
        def format_message_content(msg, **)
          formatted_content = super
          return formatted_content unless msg.role == :assistant && msg.thinking

          content_blocks = build_thinking_blocks(msg.thinking)
          append_formatted_content(content_blocks, formatted_content)

          content_blocks
        end

        def format_thinking(_msg)
          {}
        end

        def warn_on_unsupported_thinking(model, thinking)
          return unless thinking&.enabled?
          return if native_reasoning_model?(model.id) || adjustable_reasoning_model?(model.id)

          RubyLLM.logger.warn(
            'Mistral thinking is only supported on Magistral and adjustable-reasoning models. ' \
            "Ignoring thinking settings for #{model.id}."
          )
        end

        def configure_thinking_payload(payload, model, thinking)
          return unless thinking&.enabled?

          if native_reasoning_model?(model.id)
            configure_native_reasoning_payload(payload, thinking)
          elsif adjustable_reasoning_model?(model.id)
            payload[:reasoning_effort] = reasoning_effort_for(thinking)
          else
            payload.delete(:reasoning_effort)
            warn_on_unsupported_thinking(model, thinking)
          end
        end

        def configure_native_reasoning_payload(payload, thinking)
          payload.delete(:reasoning_effort)
          payload[:prompt_mode] = thinking.effort == 'none' ? nil : 'reasoning'
        end

        def reasoning_effort_for(thinking)
          effort = thinking.respond_to?(:effort) ? thinking.effort : nil
          return effort if %w[high none].include?(effort)

          RubyLLM.logger.debug { "Mistral reasoning_effort accepts high or none; coercing #{effort} to high" } if effort
          'high'
        end

        def native_reasoning_model?(model_id)
          model_id.to_s.include?('magistral')
        end

        def adjustable_reasoning_model?(model_id)
          model_id.to_s.match?(/\Amistral-(?:small-latest|medium-(?:3(?:[.-]5)?|latest))\z/)
        end

        def build_thinking_blocks(thinking)
          return [] unless thinking

          if thinking.text
            [{
              type: 'thinking',
              thinking: [{ type: 'text', text: thinking.text }],
              signature: thinking.signature
            }.compact]
          elsif thinking.signature
            [{ type: 'thinking', signature: thinking.signature }]
          else
            []
          end
        end

        def append_formatted_content(content_blocks, formatted_content)
          if formatted_content.is_a?(Array)
            content_blocks.concat(formatted_content)
          elsif formatted_content && !formatted_content.empty?
            content_blocks << { type: 'text', text: formatted_content }
          end
        end
      end
    end
  end
end
