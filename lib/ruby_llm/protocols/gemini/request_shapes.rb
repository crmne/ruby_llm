# frozen_string_literal: true

module RubyLLM
  module Protocols
    class Gemini
      # Describes generateContent requests, and the countTokens requests that
      # wrap them, as RequestShape objects. RubyLLM writes media parts in
      # snake case, and a model's own parts replay in camel case. Gemini pairs
      # function responses with calls by position and name, wants data in
      # every part, and from Gemini 3 needs a signature on the first call of
      # each step in the current turn.
      module RequestShapes
        PART_MODIFIERS = %w[thought thoughtSignature thought_signature mediaResolution media_resolution
                            videoMetadata video_metadata partMetadata part_metadata].freeze
        DATA_FIELDS = %w[text inlineData inline_data fileData file_data functionCall function_call functionResponse
                         function_response executableCode executable_code codeExecutionResult code_execution_result
                         toolCall tool_call toolResponse tool_response].freeze
        FUNCTION_DECLARATIONS = %w[functionDeclarations function_declarations].freeze
        THINKING_SETTINGS = %w[includeThoughts include_thoughts thinkingBudget thinking_budget thinkingLevel
                               thinking_level].freeze

        def parse_request_shape(payload)
          request = shape_hash(payload['generateContentRequest'])
          request = payload if request.empty?
          contents = request['contents']
          return unless contents.is_a?(Array)

          turns = contents.each_with_index.map { |content, index| shape_gemini_turn(shape_hash(content), index) }
          shape_request(turns, payload:, pairing: :position, rules: %i[signed_steps],
                               instructions: shape_gemini_parts(request['systemInstruction'] ||
                                                                request['system_instruction']),
                               tool_names: shape_list(request['tools']).flat_map { |tool| shape_gemini_tools(tool) },
                               thinking_settings: shape_gemini_thinking(request))
        end

        private

        def shape_gemini_turn(content, index)
          parts = shape_gemini_parts(content)
          shape_turn(index, content['role'], content['role'] == 'model' ? :model : shape_answer(parts), parts)
        end

        def shape_gemini_parts(content)
          shape_list(shape_hash(content)['parts']).flat_map { |part| shape_gemini_part(shape_hash(part)) }
        end

        def shape_gemini_part(part)
          signed = shape_signature?(part['thoughtSignature'] || part['thought_signature'])
          call = shape_gemini_field(part, 'functionCall', 'function_call')
          response = shape_gemini_field(part, 'functionResponse', 'function_response')

          if call
            shape_tool_call(call['name'], call['args'], id: call['id'], signed:)
          elsif response
            shape_gemini_tool_result(response)
          elsif part.key?('text')
            shape_text(part['text'], kind: part['thought'] ? :thinking : :text, signed:)
          else
            shape_gemini_data(part, signed)
          end
        end

        # RubyLLM wraps a result's text in content parts, and Gemini 3 sends
        # a result's media in parts beside it.
        def shape_gemini_tool_result(response)
          result = response['response']
          content = shape_hash(result)['content']
          content = result unless content.is_a?(Array)
          shape_tool_result(content, name: response['name']) { |part| shape_gemini_part(part) } +
            shape_gemini_parts(response)
        end

        # A thought or a signature alone is a part with no data, which
        # Gemini refuses.
        def shape_gemini_data(part, signed)
          if (data = shape_gemini_field(part, 'inlineData', 'inline_data'))
            return shape_inline(data['data'], mime_type: data['mimeType'] || data['mime_type'], signed:)
          end
          if (file = shape_gemini_field(part, 'fileData', 'file_data'))
            return shape_file(mime_type: file['mimeType'] || file['mime_type'])
          end

          spec = if part['thought']
                   shape_text(nil, kind: :thinking, signed:)
                 else
                   shape_other(part.keys.find { |key| !PART_MODIFIERS.include?(key) }, signed:)
                 end
          spec.without_data = !part.keys.intersect?(DATA_FIELDS)
          spec
        end

        def shape_gemini_field(part, *keys)
          keys.map { |key| part[key] }.find { |value| value.is_a?(Hash) }
        end

        def shape_gemini_tools(tool)
          shape_hash(tool).flat_map do |key, value|
            next [key] unless FUNCTION_DECLARATIONS.include?(key)

            shape_list(value).map { |declaration| shape_hash(declaration)['name'] }
          end
        end

        def shape_gemini_thinking(request)
          config = shape_hash(request['generationConfig'] || request['generation_config'])
          shape_settings(config['thinkingConfig'] || config['thinking_config'], *THINKING_SETTINGS)
        end
      end
    end
  end
end
