# frozen_string_literal: true

module RubyLLM
  module Protocols
    module Mistral
      class Conversations
        module Chat # :nodoc:
          module_function

          def completion_url
            'conversations'
          end

          def render(...)
            payload = super
            payload[:tools] = Support::Utils.deep_stringify_keys(payload[:tools]).uniq
            if payload[:tools].any? { |tool| Array(tool.dig('tool_configuration', 'requires_confirmation')).any? }
              raise ArgumentError, 'Mistral hosted tool confirmations require provider conversation storage'
            end

            payload
          end

          def render_payload(messages, tools:, temperature:, model:, stream: false, max_output_tokens: nil,
                             schema: nil, thinking: nil, tool_prefs: nil, **)
            options = super(messages, tools:, temperature:, model:, stream:, max_output_tokens:,
                                      schema:, thinking:, citations: false, caching: nil, tool_prefs:)
            normalize_conversation_choice(options)
            {
              model: model.id,
              inputs: format_entries(messages),
              instructions: messages.select { |message| message.role == :system }.map(&:content).join("\n\n"),
              completion_args: options.slice(:temperature, :max_tokens, :response_format, :reasoning_effort,
                                             :tool_choice),
              tools: options.fetch(:tools, []),
              store: false,
              stream: stream
            }
          end

          def normalize_conversation_choice(options)
            choice = options[:tool_choice]
            if choice.is_a?(Hash)
              raise ArgumentError, 'Mistral Conversations supports :auto, :none, or :required for tool choice'
            end

            options[:tool_choice] = 'any' if choice == 'required'
          end

          def format_entries(messages)
            entries = messages.reject { |message| message.role == :system }.flat_map do |message|
              if message.raw_content
                Array(message.raw_content)
              elsif message.tool_result?
                [{ type: 'function.result', tool_call_id: message.tool_call_id, result: message.content.to_s }]
              else
                format_conversation_message(message)
              end
            end
            entries.each_with_index.flat_map { |entry, index| replay_conversation_entry(entry, index) }
          end

          def replay_conversation_entry(entry, index)
            return replay_conversation_execution(entry, index) if entry['type'] == 'tool.execution'

            result = entry.except('id', 'object', 'created_at', 'completed_at')
            if entry['type'] == 'message.output' && entry['content'].is_a?(Array)
              result['content'] = entry['content'].map do |part|
                next part unless part['type'] == 'tool_reference'

                { 'type' => 'text', 'text' => "[#{part['title']}](#{part['url']})" }
              end
            end
            [result]
          end

          def replay_conversation_execution(entry, index)
            identity = entry['id'] || "#{index}:#{JSON.generate(entry)}"
            id = entry['tool_call_id'] || Digest::SHA256.hexdigest(identity)[0, 9]
            info = entry['info']
            result = info.is_a?(Hash) && info.key?('result') ? info['result'] : info
            [
              { 'type' => 'function.call', 'tool_call_id' => id,
                'name' => entry['function'] || entry['name'], 'arguments' => entry['arguments'] },
              { 'type' => 'function.result', 'tool_call_id' => id,
                'result' => result.is_a?(String) ? result : JSON.generate(result) }
            ]
          end

          def format_conversation_message(message)
            entries = []
            if message.content || message.attachments.any?
              entries << {
                type: 'message.input', role: message.role.to_s,
                content: format_message_content(message)
              }
            end
            message.tool_calls&.each_value do |call|
              entries << { type: 'function.call', tool_call_id: call.id, name: call.name,
                           arguments: JSON.generate(call.arguments) }
            end
            entries
          end

          def parse_completion_body(data, raw:)
            output = data.fetch('outputs')
            content = parse_conversation_content(output)
            calls = parse_conversation_calls(output, raw:)
            response_model = output.filter_map { |entry| entry['model'] }.last || @model&.id
            Message.new(
              role: :assistant, content: content[:text], attachments: content[:attachments],
              citations: content[:citations], thinking: Thinking.build(text: content[:thinking]),
              tool_calls: calls, server_tool_calls: parse_conversation_steps(output),
              raw_content: output, model: response_model,
              finish_reason: calls.empty? ? :stop : :tool_calls, raw: raw,
              **parse_conversation_usage(data['usage'] || {})
            )
          end

          def parse_conversation_calls(output, raw:)
            if output.any? { |entry| entry['type'] == 'function.call' && entry['confirmation_status'] == 'pending' }
              raise Error.new('Mistral returned a hosted tool confirmation that requires provider conversation storage',
                              response: raw)
            end

            output.select { |entry| pending_conversation_call?(entry) }.to_h do |entry|
              call = parse_tool_calls([
                                        { 'id' => entry['tool_call_id'], 'type' => 'function',
                                          'function' => entry.slice('name', 'arguments') }
                                      ], response: raw, finish_reason: :tool_calls).values.first
              [call.id, call]
            end
          end

          def pending_conversation_call?(entry)
            entry['type'] == 'function.call' && entry['confirmation_status'].nil?
          end

          def parse_conversation_steps(output)
            output.filter_map do |entry|
              next unless entry['type'] == 'tool.execution' ||
                          (entry['type'] == 'function.call' && !pending_conversation_call?(entry))

              ServerToolCall.new(type: entry['type'], name: entry['name'], id: entry['id'],
                                 input: entry['arguments'], result: entry['info'], raw: entry)
            end
          end

          def parse_conversation_usage(usage)
            input = usage['prompt_tokens'] && (usage['prompt_tokens'] + usage.fetch('connector_tokens', 0).to_i)
            {
              input_tokens: input,
              output_tokens: usage['completion_tokens'], server_tool_use: usage['connectors']
            }
          end
        end
      end
    end
  end
end
