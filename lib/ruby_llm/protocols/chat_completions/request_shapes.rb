# frozen_string_literal: true

module RubyLLM
  module Protocols
    class ChatCompletions
      # Describes Chat Completions requests as RequestShape objects. Cohere
      # v2 sends messages in the same shape. Tool messages answer calls by id.
      module RequestShapes
        SPEAKERS = {
          'system' => :system, 'developer' => :system, 'assistant' => :model, 'tool' => :tool, 'function' => :tool
        }.freeze

        def parse_request_shape(payload)
          messages = payload['messages']
          return unless messages.is_a?(Array)

          turns = messages.each_with_index.map { |message, index| shape_message(shape_hash(message), index) }
          tool_names = shape_list(payload['tools']).map { |tool| shape_function_name(tool) }
          shape_request(turns, payload:, tool_names:, thinking_settings: shape_reasoning_settings(payload))
        end

        private

        def shape_message(message, index)
          speaker = SPEAKERS.fetch(message['role'], :user)
          content = message['content']
          parts = shape_message_thinking(message)
          if speaker == :tool
            parts.concat(shape_tool_result(content, name: message['name'], id: message['tool_call_id']) do |block|
              shape_content_part(block)
            end)
          else
            parts.concat(shape_content(content))
          end
          parts.concat(shape_list(message['tool_calls']).map { |call| shape_function_call(shape_hash(call)) })
          shape_turn(index, message['role'], speaker, parts)
        end

        def shape_reasoning_settings(payload)
          shape_settings(payload, 'reasoning_effort')
            .merge(shape_settings(payload['reasoning'], 'effort', 'max_tokens', 'enabled', 'exclude'))
            .merge(shape_settings(payload['thinking'], 'type', 'token_budget', 'budget_tokens'))
        end

        def shape_message_thinking(message)
          details = message['reasoning_details']
          return details.map { |detail| shape_reasoning_detail(shape_hash(detail)) } if details.is_a?(Array)

          text = message['reasoning_content'] || message['reasoning']
          signed = shape_signature?(message['reasoning_signature'])
          text || signed ? [shape_text(text, kind: :thinking, signed:)] : []
        end

        def shape_reasoning_detail(detail)
          case detail['type']
          when 'reasoning.encrypted' then shape_text(nil, kind: :thinking, signed: shape_signature?(detail['data']))
          when 'reasoning.summary' then shape_text(detail['summary'], kind: :thinking)
          else shape_text(detail['text'], kind: :thinking, signed: shape_signature?(detail['signature']))
          end
        end

        def shape_content(content)
          return [shape_text(content)] if content.is_a?(String)

          shape_list(content).map { |part| shape_content_part(shape_hash(part)) }
        end

        def shape_content_part(part)
          case part['type']
          when 'text' then shape_text(part['text'])
          when 'image_url' then shape_url(shape_url_field(part['image_url']), kind: :image)
          when 'video_url' then shape_url(shape_url_field(part['video_url']), kind: :video)
          when 'input_audio' then shape_inline(shape_hash(part['input_audio'])['data'], kind: :audio)
          when 'file' then shape_content_file(shape_hash(part['file']))
          when 'document_url' then shape_url(shape_url_field(part['document_url']), kind: :document)
          when 'file_url' then shape_file_url(shape_url_field(part['file_url']))
          when 'thinking' then shape_content_thinking(part)
          else shape_other(part['type'])
          end
        end

        def shape_url_field(value)
          value.is_a?(Hash) ? value['url'] : value
        end

        def shape_content_file(file)
          return shape_file(kind: :document) if file.key?('file_id')

          shape_url(file['file_data'], kind: :document)
        end

        # Perplexity sends a document's bytes as bare base64 where its link
        # would go, and base64 never holds the colon that starts a scheme.
        def shape_file_url(url)
          return shape_inline(url, kind: :document) if url.is_a?(String) && !url.include?(':')

          shape_url(url, kind: :document)
        end

        def shape_content_thinking(part)
          thinking = part['thinking']
          signed = shape_signature?(part['signature'])
          return shape_summary(thinking, signed:) if thinking.is_a?(Array)

          shape_text(thinking, kind: :thinking, signed:)
        end

        def shape_function_call(call)
          function = shape_hash(call['function'])
          signature = shape_hash(shape_hash(call['extra_content'])['google'])['thought_signature']
          shape_tool_call(function['name'], function['arguments'], id: call['id'], signed: shape_signature?(signature))
        end

        def shape_function_name(tool)
          tool = shape_hash(tool)
          shape_hash(tool['function'])['name'] || tool['type']
        end
      end
    end
  end
end
