# frozen_string_literal: true

module RubyLLM
  module Protocols
    class Interactions
      module Chat # :nodoc:
        FINISH_REASONS = { 'completed' => :stop, 'requires_action' => :tool_calls, 'incomplete' => :max_tokens }.freeze

        module_function

        def finish_reasons = FINISH_REASONS

        def completion_url
          'interactions'
        end

        def render_payload(messages, tools:, temperature:, model:, stream: false, max_output_tokens: nil,
                           schema: nil, thinking: nil, tool_prefs: nil, **)
          config = { temperature: temperature, max_output_tokens: max_output_tokens }.compact
          config.merge!(render_interaction_thinking(thinking)) if thinking
          choice = tool_prefs&.dig(:choice)
          config[:tool_choice] = render_interaction_choice(choice) if choice
          payload = {
            model: model.id, input: format_interaction_input(messages), stream: stream, store: false,
            system_instruction: messages.select { |message| message.role == :system }.map(&:content).join("\n\n"),
            generation_config: config, tools: render_interaction_tools(tools)
          }
          payload[:response_format] = { type: 'text', mime_type: 'application/json', schema: schema[:schema] } if schema
          payload
        end

        def render_interaction_thinking(thinking)
          if thinking.disabled? || thinking.budget&.zero?
            raise ArgumentError, 'Gemini Interactions does not expose a thinking-off control'
          end
          raise ArgumentError, 'Gemini Interactions accepts thinking effort, not a token budget' if thinking.budget
          if thinking.effort && !%i[minimal low medium high].include?(thinking.effort)
            raise ArgumentError, 'Gemini Interactions thinking effort must be minimal, low, medium, or high'
          end

          { thinking_level: thinking.effort&.to_s,
            thinking_summaries: render_interaction_summaries(thinking.display) }.compact
        end

        def render_interaction_summaries(display)
          unless [nil, :summarized, :omitted].include?(display)
            raise ArgumentError, 'Gemini Interactions thinking display must be summarized or omitted'
          end

          display == :omitted ? 'none' : 'auto'
        end

        def format_interaction_input(messages)
          calls = messages.flat_map { |message| message.tool_calls.to_h.values }.to_h { |call| [call.id, call] }
          messages.reject { |message| message.role == :system }.flat_map do |message|
            render_interaction_turn(message, calls)
          end
        end

        def render_interaction_turn(message, calls)
          if interaction_state?(message.raw_content)
            render_interaction_history(message.raw_content.dig('response', 'steps') || [])
          elsif message.tool_result?
            [render_interaction_result(message, calls)]
          else
            render_interaction_message(message)
          end
        end

        def render_interaction_result(message, calls)
          { type: 'function_result', call_id: message.tool_call_id, name: calls[message.tool_call_id]&.name,
            result: render_interaction_content(message.content, message.attachments) }.compact
        end

        def render_interaction_history(steps)
          steps.map do |step|
            step['type'].to_s.start_with?('mcp_server_') ? step.except('signature') : step
          end
        end

        def render_interaction_message(message)
          steps = []
          if message.content || message.attachments.any?
            steps << { type: message.role == :assistant ? 'model_output' : 'user_input',
                       content: render_interaction_content(message.content, message.attachments) }
          end
          message.tool_calls&.each_value do |call|
            steps << { type: 'function_call', id: call.id, name: call.name, arguments: call.arguments }
          end
          steps
        end

        def interaction_state?(content)
          content.is_a?(Hash) && content.dig('response', 'object') == 'interaction'
        end

        def parse_completion_body(data, raw:, model: data['model'] || @model&.id, cost: nil)
          unless %w[completed requires_action incomplete].include?(data['status'])
            message = Array(data['errors']).filter_map { |error| error['message'] }.join('; ')
            raise Error.new(message.empty? ? "Gemini interaction ended with status #{data['status']}" : message,
                            response: raw)
          end

          steps = data.fetch('steps', [])
          content = parse_interaction_content(steps)
          calls = parse_interaction_calls(steps)
          if data['status'] == 'requires_action' && calls.empty?
            raise Error.new('Gemini interaction requires an unsupported action', response: raw)
          end

          Message.new(role: :assistant, content: content[:text], attachments: content[:attachments],
                      citations: content[:citations], thinking: parse_interaction_thinking(steps),
                      tool_calls: calls, server_tool_calls: parse_interaction_server_calls(steps),
                      raw_content: { 'response' => data },
                      model: model, raw: raw, cost: cost,
                      finish_reason: interaction_finish_reason(data['status'], calls),
                      **parse_interaction_usage(data['usage'] || {}))
        end

        def interaction_finish_reason(status, calls)
          return :tool_calls unless calls.empty?

          finish_reasons.fetch(status)
        end

        def parse_interaction_thinking(steps)
          thoughts = steps.select { |step| step['type'] == 'thought' }
          text = thoughts.flat_map { |step| Array(step['summary']) }.filter_map { |part| part['text'] }.join
          Thinking.build(text: text.empty? ? nil : text, signature: thoughts.last&.dig('signature'))
        end

        def parse_interaction_usage(usage)
          prompt = usage['total_input_tokens']
          cached = usage['total_cached_tokens'].to_i
          thoughts = usage['total_thought_tokens'].to_i
          {
            input_tokens: prompt && [prompt + usage['total_tool_use_tokens'].to_i - cached, 0].max,
            output_tokens: usage['total_output_tokens'] && (usage['total_output_tokens'] + thoughts),
            cache_read_tokens: usage['total_cached_tokens'], thinking_tokens: usage['total_thought_tokens']
          }
        end
      end
    end
  end
end
