# frozen_string_literal: true

module RubyLLM
  module Protocols
    class Responses
      # Describes Responses API requests, including token counting and
      # compaction, as RequestShape objects. Each input item is a turn, and a
      # call's output answers the call by id.
      module RequestShapes
        def parse_request_shape(payload)
          input = payload['input']
          return unless input.is_a?(Array)

          turns = input.each_with_index.map do |item, index|
            item = shape_hash(item)
            shape_turn(index, item['role'] || item['type'], shape_input_speaker(item), shape_input_item(item))
          end
          shape_request(turns, payload:, instructions: shape_instructions(payload['instructions']),
                               tool_names: shape_list(payload['tools']).map { |tool| shape_tool_name(tool) },
                               thinking_settings: shape_settings(payload['reasoning'], 'effort', 'summary'))
        end

        private

        def shape_input_speaker(item)
          case item['type']
          when nil, 'message' then ChatCompletions::RequestShapes::SPEAKERS.fetch(item['role'], :user)
          when /_output\z|_response\z/ then :tool
          else :model
          end
        end

        def shape_input_item(item)
          case item['type']
          when nil, 'message' then shape_input_content(item['content'])
          when 'function_call' then [shape_tool_call(item['name'], item['arguments'], id: item['call_id'])]
          when 'function_call_output'
            shape_tool_result(item['output'], id: item['call_id']) { |part| shape_input_part(part) }
          when 'reasoning' then [shape_summary(item['summary'], signed: shape_signature?(item['encrypted_content']))]
          else [shape_other(item['type'])]
          end
        end

        def shape_input_content(content)
          return [shape_text(content)] if content.is_a?(String)

          shape_list(content).map { |part| shape_input_part(shape_hash(part)) }
        end

        def shape_input_part(part)
          case part['type']
          when 'input_text', 'output_text' then shape_text(part['text'])
          when 'input_image'
            part.key?('file_id') ? shape_file(kind: :image) : shape_url(part['image_url'], kind: :image)
          when 'input_file' then shape_input_file(part)
          when 'input_audio' then shape_inline(shape_hash(part['input_audio'])['data'], kind: :audio)
          else shape_other(part['type'])
          end
        end

        def shape_input_file(part)
          return shape_file(kind: :document) if part.key?('file_id')
          return shape_url(part['file_url'], kind: :document) if part.key?('file_url')

          shape_url(part['file_data'], kind: :document)
        end
      end
    end
  end
end
