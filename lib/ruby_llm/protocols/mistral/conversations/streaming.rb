# frozen_string_literal: true

module RubyLLM
  module Protocols
    module Mistral
      class Conversations
        module Streaming # :nodoc:
          module_function

          def stream_response(payload, additional_headers = {})
            @conversation_output = {}
            @conversation_response = { 'object' => 'conversation.response' }
            @conversation_done = false
            response = stream_events(completion_url, payload, additional_headers) { |data| yield build_chunk(data) }
            raise Error.new('Mistral conversation stream ended before completion', response:) unless @conversation_done

            parse_completion_body(streamed_conversation_response, raw: response)
          end

          def build_chunk(data)
            @conversation_output ||= {}
            @conversation_response ||= { 'object' => 'conversation.response' }
            case data['type']
            when 'conversation.response.done'
              @conversation_done = true
              @conversation_response['usage'] = data['usage']
              return final_conversation_chunk
            when 'conversation.response.error'
              raise Error, data['message'] || data.dig('error', 'message') || 'Mistral conversation failed'
            when 'message.output.delta'
              return conversation_text_chunk(data)
            when 'function.call.delta', 'tool.execution.started', 'tool.execution.delta', 'tool.execution.done'
              accumulate_conversation_entry(data)
            end
            Chunk.new(role: :assistant, content: nil)
          end

          def streamed_conversation_response
            @conversation_response.merge('outputs' => @conversation_output.sort.map(&:last))
          end

          def accumulate_conversation_entry(data)
            type = data['type'].delete_suffix('.delta').delete_suffix('.started').delete_suffix('.done')
            entry = @conversation_output[data.fetch('output_index', 0)] ||= { 'type' => type, 'arguments' => +'' }
            entry.merge!(data.slice('id', 'model', 'name', 'tool_call_id', 'confirmation_status', 'function', 'info'))
            entry['arguments'] << data['arguments'].to_s
          end

          def conversation_text_chunk(data)
            entry = @conversation_output[data.fetch('output_index',
                                                    0)] ||= { 'type' => 'message.output', 'content' => [] }
            entry.merge!(data.slice('id', 'model', 'role'))
            part = data['content'].is_a?(String) ? { 'type' => 'text', 'text' => data['content'] } : data['content']
            merge_conversation_part(entry['content'], data.fetch('content_index', 0), part)
            content = { text: +'', thinking: +'', attachments: [], citations: [] }
            parse_conversation_parts([part], content)
            Chunk.new(role: :assistant, content: content[:text], model: data['model'],
                      thinking: Thinking.build(text: content[:thinking].empty? ? nil : content[:thinking]))
          end

          def merge_conversation_part(parts, index, part)
            existing = parts[index]
            if existing && part['type'] == 'text'
              existing['text'] << part['text'].to_s
            elsif existing && part['type'] == 'thinking'
              existing['thinking'].concat(Array(part['thinking']))
            else
              parts[index] = Support::Utils.deep_dup(part)
            end
          end

          def final_conversation_chunk
            message = parse_completion_body(streamed_conversation_response, raw: nil)
            Chunk.new(role: :assistant, content: nil, model: message.model, tokens: message.tokens,
                      citations: message.citations, tool_calls: message.tool_calls,
                      server_tool_calls: message.server_tool_calls, raw_content: message.raw_content,
                      attachments: message.attachments, finish_reason: message.finish_reason)
          end
        end
      end
    end
  end
end
