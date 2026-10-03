# frozen_string_literal: true

module RubyLLM
  module Protocols
    class Interactions
      # Describes Interactions requests as RequestShape objects. Each input
      # step is a turn. A function result answers its call by id, and like
      # Gemini, the first call of each step in the current turn needs a
      # signature.
      module RequestShapes
        SPEAKERS = { 'user_input' => :user, 'function_result' => :tool }.freeze
        MEDIA_KINDS = { 'image' => :image, 'audio' => :audio, 'video' => :video, 'document' => :document }.freeze

        def parse_request_shape(payload)
          input = payload['input']
          return unless input.is_a?(Array)

          turns = input.each_with_index.map do |entry, index|
            entry = shape_hash(entry)
            shape_turn(index, entry['type'], SPEAKERS.fetch(entry['type'], :model), shape_interaction_entry(entry))
          end
          shape_request(turns, payload:, rules: %i[signed_steps],
                               instructions: shape_instructions(payload['system_instruction']),
                               tool_names: shape_list(payload['tools']).map { |tool| shape_tool_name(tool) },
                               thinking_settings: shape_settings(payload['generation_config'], 'thinking_level',
                                                                 'thinking_summaries'))
        end

        private

        def shape_interaction_entry(entry)
          signed = shape_signature?(entry['signature'])
          case entry['type']
          when 'user_input', 'model_output' then shape_interaction_content(entry['content'])
          when 'function_call' then [shape_tool_call(entry['name'], entry['arguments'], id: entry['id'], signed:)]
          when 'function_result'
            shape_tool_result(entry['result'], name: entry['name'], id: entry['call_id']) do |part|
              shape_interaction_part(part)
            end
          when 'thought' then [shape_summary(entry['summary'], signed:)]
          else [shape_other(entry['type'], signed:)]
          end
        end

        def shape_interaction_content(content)
          return [shape_text(content)] if content.is_a?(String)

          shape_list(content).map { |part| shape_interaction_part(shape_hash(part)) }
        end

        def shape_interaction_part(part)
          kind = MEDIA_KINDS[part['type']]
          return shape_text(part['text']) if part['type'] == 'text'
          return shape_other(part['type']) unless kind
          return shape_inline(part['data'], kind:, mime_type: part['mime_type']) if part.key?('data')

          shape_url(part['uri'], kind:, mime_type: part['mime_type'])
        end
      end
    end
  end
end
