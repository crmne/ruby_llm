# frozen_string_literal: true

module RubyLLM
  module Protocols
    class Anthropic
      # Describes Messages API requests, and the token counting requests
      # that share their shape, as RequestShape objects. Claude pairs tool
      # results with calls by id and takes a thinking block back only with
      # its signature.
      module RequestShapes
        MEDIA_KINDS = { 'image' => :image, 'document' => :document }.freeze
        THINKING_SETTINGS = %w[type budget_tokens display].freeze

        def parse_request_shape(payload)
          messages = payload['messages']
          return unless messages.is_a?(Array)

          turns = messages.each_with_index.map { |message, index| shape_anthropic_turn(shape_hash(message), index) }
          shape_request(turns, payload:, rules: %i[signed_thinking],
                               instructions: shape_anthropic_content(payload['system']),
                               tool_names: shape_list(payload['tools']).map { |tool| shape_tool_name(tool) },
                               thinking_settings: shape_anthropic_thinking(payload))
        end

        private

        def shape_anthropic_thinking(payload)
          effort = shape_settings(payload['output_config'], 'effort')
          shape_settings(payload['thinking'], *THINKING_SETTINGS).merge(effort)
        end

        def shape_anthropic_turn(message, index)
          parts = shape_anthropic_content(message['content'])
          shape_turn(index, message['role'], message['role'] == 'assistant' ? :model : shape_answer(parts), parts)
        end

        def shape_anthropic_content(content)
          return [shape_text(content)] if content.is_a?(String)

          shape_list(content).flat_map { |block| shape_anthropic_block(shape_hash(block)) }
        end

        def shape_anthropic_block(block)
          case block['type']
          when 'text' then shape_text(block['text'])
          when 'thinking' then shape_text(block['thinking'], kind: :thinking,
                                                             signed: shape_signature?(block['signature']))
          when 'redacted_thinking' then shape_text(nil, kind: :thinking, signed: shape_signature?(block['data']))
          when 'tool_use' then shape_tool_call(block['name'], block['input'], id: block['id'])
          when 'tool_result'
            shape_tool_result(block['content'], id: block['tool_use_id']) { |inner| shape_anthropic_block(inner) }
          when *MEDIA_KINDS.keys then shape_anthropic_source(MEDIA_KINDS[block['type']], shape_hash(block['source']))
          else shape_other(block['type'])
          end
        end

        def shape_anthropic_source(kind, source)
          case source['type']
          when 'base64' then shape_inline(source['data'], kind:, mime_type: source['media_type'])
          when 'text' then shape_media(kind, source: :inline, size: shape_length(source['data']),
                                             mime_type: source['media_type'])
          when 'url' then shape_media(kind, source: :url)
          when 'file' then shape_file(kind:)
          else shape_media(kind, source: :inline, size: shape_length(source['content']))
          end
        end
      end
    end
  end
end
