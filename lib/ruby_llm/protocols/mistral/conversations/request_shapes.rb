# frozen_string_literal: true

module RubyLLM
  module Protocols
    module Mistral
      class Conversations
        # Describes Conversations requests as RequestShape objects. Each
        # input entry is a turn, messages carry Chat Completions content, and
        # a function result answers its call by id.
        module RequestShapes
          def parse_request_shape(payload)
            inputs = payload['inputs']
            return unless inputs.is_a?(Array)

            turns = inputs.each_with_index.map { |entry, index| shape_conversation_turn(shape_hash(entry), index) }
            shape_request(turns, payload:, instructions: shape_instructions(payload['instructions']),
                                 tool_names: shape_list(payload['tools']).map { |tool| shape_function_name(tool) },
                                 thinking_settings: shape_settings(payload['completion_args'], 'reasoning_effort'))
          end

          private

          def shape_conversation_turn(entry, index)
            role = entry['role'] || entry['type']
            case entry['type']
            when 'message.input'
              speaker = ChatCompletions::RequestShapes::SPEAKERS.fetch(entry['role'], :user)
              shape_turn(index, role, speaker, shape_content(entry['content']))
            when 'message.output' then shape_turn(index, role, :model, shape_content(entry['content']))
            when 'function.result'
              shape_turn(index, role, :tool, shape_tool_result(entry['result'], id: entry['tool_call_id']))
            else shape_turn(index, role, :model, [shape_conversation_step(entry)])
            end
          end

          def shape_conversation_step(entry)
            return shape_other(entry['type']) unless entry['type'] == 'function.call'

            shape_tool_call(entry['name'], entry['arguments'], id: entry['tool_call_id'])
          end
        end
      end
    end
  end
end
