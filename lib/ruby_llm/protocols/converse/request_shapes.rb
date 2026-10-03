# frozen_string_literal: true

module RubyLLM
  module Protocols
    class Converse
      # Describes Converse requests, and the token counting requests that
      # wrap them, as RequestShape objects. A content block is a union keyed
      # by its kind, and media names a format instead of a MIME type.
      # Converse wants user and assistant messages to alternate, pairs tool
      # results with uses by id, and takes reasoning back only with its
      # signature.
      module RequestShapes
        MEDIA_KINDS = { 'image' => :image, 'audio' => :audio, 'video' => :video, 'document' => :document }.freeze

        def parse_request_shape(payload)
          request = shape_hash(shape_hash(payload['input'])['converse'])
          request = payload if request.empty?
          messages = request['messages']
          return unless messages.is_a?(Array)

          turns = messages.each_with_index.map { |message, index| shape_converse_turn(shape_hash(message), index) }
          tools = shape_list(shape_hash(request['toolConfig'])['tools'])
          shape_request(turns, payload:, rules: %i[alternating_roles signed_thinking],
                               instructions: shape_converse_blocks(request['system']),
                               tool_names: tools.map { |tool| shape_converse_tool_name(shape_hash(tool)) },
                               thinking_settings: shape_converse_thinking(request))
        end

        private

        def shape_converse_turn(message, index)
          parts = shape_converse_blocks(message['content'])
          shape_turn(index, message['role'], message['role'] == 'assistant' ? :model : shape_answer(parts), parts)
        end

        def shape_converse_blocks(blocks)
          shape_list(blocks).flat_map { |block| shape_converse_block(shape_hash(block)) }
        end

        def shape_converse_block(block)
          type, value = block.first
          return shape_text(value) if %w[text json].include?(type)

          value = shape_hash(value)
          case type
          when 'toolUse' then shape_tool_call(value['name'], value['input'], id: value['toolUseId'])
          when 'toolResult'
            shape_tool_result(value['content'], id: value['toolUseId']) { |inner| shape_converse_block(inner) }
          when 'reasoningContent' then shape_converse_reasoning(value)
          when *MEDIA_KINDS.keys then shape_converse_media(MEDIA_KINDS[type], value)
          else shape_other(type)
          end
        end

        def shape_converse_reasoning(reasoning)
          unless reasoning.key?('reasoningText')
            return shape_text(nil, kind: :thinking, signed: shape_signature?(reasoning['redactedContent']))
          end

          text = shape_hash(reasoning['reasoningText'])
          shape_text(text['text'], kind: :thinking, signed: shape_signature?(text['signature']))
        end

        def shape_converse_media(kind, media)
          source = shape_hash(media['source'])
          mime_type = shape_converse_mime_type(kind, media['format'])
          return shape_inline(source['bytes'], kind:, mime_type:) if source.key?('bytes')
          return shape_file(kind:, mime_type:) unless source.key?('text')

          shape_media(kind, source: :inline, size: shape_length(source['text']), mime_type:)
        end

        # A format can name a container that holds either sound or video,
        # such as mp4, so its MIME type counts only when it agrees.
        def shape_converse_mime_type(kind, format)
          return unless format.is_a?(String)

          mime_type = RubyLLM::Files::MimeType.for(name: "file.#{format}")
          mime_type if mime_type != 'application/octet-stream' && shape_media_kind(mime_type) == kind
        end

        def shape_converse_tool_name(tool)
          shape_hash(tool['toolSpec'])['name'] || shape_hash(tool['systemTool'])['name']
        end

        # Each model family takes its reasoning settings in a field of its
        # own, and some name an effort with a bare reasoning_config.
        def shape_converse_thinking(request)
          fields = shape_hash(request['additionalModelRequestFields'])
          shape_settings(fields, 'reasoning_config', 'reasoning_effort')
            .merge(shape_settings(fields['reasoning_config'], 'type', 'budget_tokens'))
            .merge(shape_settings(fields['reasoningConfig'], 'type', 'maxReasoningEffort'))
            .merge(shape_settings(fields['thinking'], 'type'))
            .merge(shape_settings(fields['output_config'], 'effort'))
        end
      end
    end
  end
end
