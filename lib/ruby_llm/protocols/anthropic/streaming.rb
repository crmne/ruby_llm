# frozen_string_literal: true

require 'json'

module RubyLLM
  module Protocols
    class Anthropic
      # Streaming methods of the Anthropic API integration
      module Streaming
        private

        def stream_response(payload, additional_headers = {}, &)
          # Avoid Net::HTTP's auto-inflate: Cloudflare's gzip flushes
          # infrequently for SSE, batching chunks until each flush.
          super(payload, additional_headers.merge('Accept-Encoding' => 'identity'), &)
        end

        def stream_url
          completion_url
        end

        def build_chunk(data)
          delta_type = data.dig('delta', 'type')
          track_stream_blocks(data, delta_type)

          Chunk.new(
            role: :assistant,
            model: extract_model_id(data),
            content: extract_content_delta(data, delta_type),
            citations: extract_citations_delta(data, delta_type),
            thinking: Thinking.build(
              text: extract_thinking_delta(data, delta_type),
              signature: extract_signature_delta(data, delta_type)
            ),
            input_tokens: extract_input_tokens(data),
            output_tokens: extract_output_tokens(data),
            cache_read_tokens: extract_cache_read_tokens(data),
            cache_write_tokens: extract_cache_write_tokens(data),
            server_tool_use: extract_server_tool_use(data),
            tool_calls: extract_tool_calls(data),
            finish_reason: data.dig('delta', 'stop_reason'),
            **stream_end_fields(data)
          )
        end

        def extract_server_tool_use(data)
          data.dig('message', 'usage', 'server_tool_use') || data.dig('usage', 'server_tool_use')
        end

        # Reconstructs the response's content blocks from stream events so
        # turns that used server tools can be replayed verbatim, exactly as
        # the non-streaming path does with the response body.
        def track_stream_blocks(data, delta_type)
          case data['type']
          when 'content_block_start' then track_stream_block_start(data)
          when 'content_block_delta' then track_stream_block_delta(data, delta_type)
          when 'content_block_stop' then finalize_stream_block(data['index'])
          end
        end

        def track_stream_block_start(data)
          block = Utils.deep_dup(data['content_block'] || {})
          @stream_blocks ||= {}
          @stream_blocks[data['index']] = block
          @saw_server_block = true if server_tool_block?(block)
          return unless block['type'].to_s.end_with?('tool_use')

          @stream_block_json ||= {}
          @stream_block_json[data['index']] = +''
        end

        def track_stream_block_delta(data, delta_type)
          block = @stream_blocks&.dig(data['index'])
          return unless block

          case delta_type
          when 'text_delta' then block['text'] = block['text'].to_s + data.dig('delta', 'text').to_s
          when 'thinking_delta' then block['thinking'] = block['thinking'].to_s + data.dig('delta', 'thinking').to_s
          when 'signature_delta' then block['signature'] = data.dig('delta', 'signature')
          when 'input_json_delta' then @stream_block_json&.dig(data['index'])&.<< data.dig('delta', 'partial_json').to_s
          when 'citations_delta' then (block['citations'] ||= []) << data.dig('delta', 'citation')
          end
        end

        def finalize_stream_block(index)
          json = @stream_block_json&.dig(index)
          block = @stream_blocks&.dig(index)
          return unless json && block

          block['input'] = json.empty? ? block['input'] || {} : parse_stream_block_input(json, block)
        end

        def parse_stream_block_input(json, block)
          JSON.parse(json)
        rescue JSON::ParserError
          block['input'] || {}
        end

        def stream_end_fields(data)
          return {} unless data['type'] == 'message_stop' && @saw_server_block

          blocks = @stream_blocks.sort.map { |_index, block| block }
          {
            server_tool_calls: extract_server_tool_calls(blocks),
            raw_content: blocks
          }
        end

        def extract_content_delta(data, delta_type)
          return data.dig('delta', 'text') if delta_type == 'text_delta'

          nil
        end

        def extract_citations_delta(data, delta_type)
          return nil unless delta_type == 'citations_delta'

          citation = data.dig('delta', 'citation')
          citation ? [Chat.parse_citation(citation)] : nil
        end

        def extract_thinking_delta(data, delta_type)
          return data.dig('delta', 'thinking') if delta_type == 'thinking_delta'

          nil
        end

        def extract_signature_delta(data, delta_type)
          return data.dig('delta', 'signature') if delta_type == 'signature_delta'

          nil
        end

        def json_delta?(data)
          data['type'] == 'content_block_delta' && data.dig('delta', 'type') == 'input_json_delta'
        end

        def parse_streaming_error(data)
          error_data = JSON.parse(data)
          return unless error_data.is_a?(Hash) && error_data['type'] == 'error'

          error = error_data['error']
          return [500, error.to_s] unless error.is_a?(Hash)

          case error['type']
          when 'overloaded_error'
            [529, error['message']]
          else
            [500, error['message']]
          end
        end
      end
    end
  end
end
