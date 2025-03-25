# frozen_string_literal: true

require 'base64'

module RubyLLM
  module Providers
    module Bedrock
      # Streaming methods for the AWS Bedrock API implementation
      module Streaming
        module_function

        def stream_url
          "model/#{@model_id}/invoke-with-response-stream"
        end

        def handle_stream(&block)

          proc do |chunk, _bytes, env|
            if env && env.status != 200
              # Accumulate error chunks
              buffer = String.new
              buffer << chunk
              begin
                error_data = JSON.parse(buffer)
                error_response = env.merge(body: error_data)
                ErrorMiddleware.parse_error(provider: self, response: error_response)
              rescue JSON::ParserError
                # Keep accumulating if we don't have complete JSON yet
                RubyLLM.logger.debug "Accumulating error chunk: #{chunk}"
              end
            else
              begin
                # Process each event stream message in the chunk
                offset = 0
                while offset < chunk.bytesize
                  # Read the prelude (total length + headers length)
                  break if chunk.bytesize - offset < 12  # Need at least prelude size
                  
                  total_length = chunk[offset...offset + 4].unpack('N').first
                  headers_length = chunk[offset + 4...offset + 8].unpack('N').first
                  
                  # Validate lengths to ensure they're reasonable
                  if total_length.nil? || headers_length.nil? || 
                     total_length <= 0 || total_length > 1_000_000 ||  # Sanity check for message size
                     headers_length <= 0 || headers_length > total_length
                    RubyLLM.logger.debug "Invalid lengths detected, trying next potential message"
                    # Try to find the next message prelude marker
                    next_prelude = find_next_prelude(chunk, offset + 4)
                    offset = next_prelude || chunk.bytesize
                    next
                  end
                  
                  # Verify we have the complete message
                  message_end = offset + total_length
                  break if chunk.bytesize < message_end
                  
                  # Extract headers and payload
                  headers_end = offset + 12 + headers_length
                  payload_end = message_end - 4  # Subtract 4 bytes for message CRC
                  
                  # Safety check for valid positions
                  if headers_end >= payload_end || headers_end >= chunk.bytesize || payload_end > chunk.bytesize
                    RubyLLM.logger.debug "Invalid positions detected, trying next potential message"
                    # Try to find the next message prelude marker
                    next_prelude = find_next_prelude(chunk, offset + 4)
                    offset = next_prelude || chunk.bytesize
                    next
                  end
                  
                  # Get payload
                  payload = chunk[headers_end...payload_end]
                  
                  # Safety check for payload
                  if payload.nil? || payload.empty?
                    RubyLLM.logger.debug "Empty or nil payload detected, skipping chunk"
                    offset = message_end
                    next
                  end
                  
                  # Find valid JSON in the payload
                  json_start = payload.index('{')
                  json_end = payload.rindex('}')
                  
                  if json_start.nil? || json_end.nil? || json_start >= json_end
                    RubyLLM.logger.debug "No valid JSON found in payload, skipping chunk"
                    offset = message_end
                    next
                  end
                  
                  # Extract just the JSON portion
                  json_payload = payload[json_start..json_end]
                  
                  begin
                    # Parse the JSON payload
                    json_data = JSON.parse(json_payload)
                    
                    # Handle Base64 encoded bytes
                    if json_data['bytes']
                      decoded_bytes = Base64.strict_decode64(json_data['bytes'])
                      data = JSON.parse(decoded_bytes)

                      block.call(
                        Chunk.new(
                          role: :assistant,
                          model_id: data.dig('message', 'model') || @model_id,
                          content: extract_streaming_content(data),
                          input_tokens: extract_input_tokens(data),
                          output_tokens: extract_output_tokens(data),
                          tool_calls: extract_tool_calls(data)
                        )
                      )
                    end

                  rescue JSON::ParserError => e
                    RubyLLM.logger.debug "Failed to parse payload as JSON: #{e.message}"
                    RubyLLM.logger.debug "Attempted JSON payload: #{json_payload.inspect}"
                  rescue StandardError => e
                    RubyLLM.logger.debug "Error processing payload: #{e.message}"
                  end
                  
                  # Move to next message
                  offset = message_end
                end
              rescue StandardError => e
                RubyLLM.logger.debug "Error processing chunk: #{e.message}"
                RubyLLM.logger.debug "Chunk size: #{chunk.bytesize}"
              end
            end
          end
        end

        def json_delta?(data)
          data['type'] == 'content_block_delta' && data.dig('delta', 'type') == 'input_json_delta'
        end

        def extract_streaming_content(data)
          if data.is_a?(Hash)
            case data['type']
            when 'message_start'
              # No content yet in message_start
              ''
            when 'content_block_start'
              # Initial content block, might have some text
              data.dig('content_block', 'text').to_s
            when 'content_block_delta'
              # Incremental content updates
              data.dig('delta', 'text').to_s
            when 'message_delta'
              # Might contain updates to usage stats, but no new content
              ''
            else
              # Fall back to the existing extract_content method for other formats
              extract_content(data)
            end
          else
            extract_content(data)
          end
        end

        private

        def extract_input_tokens(data)
          data.dig('message', 'usage', 'input_tokens')
        end

        def extract_output_tokens(data)
          data.dig('message', 'usage', 'output_tokens') || data.dig('usage', 'output_tokens')
        end

        def extract_content(data)
          case data
          when Hash
            if data.key?('completion')
              data['completion']
            elsif data.dig('results', 0, 'outputText')
              data.dig('results', 0, 'outputText')
            elsif data.key?('content')
              data['content'].is_a?(Array) ? data['content'].map { |item| item['text'] }.join : data['content']
            elsif data.key?('content_block') && data['content_block'].key?('text')
              # Handle the newly decoded JSON structure
              data['content_block']['text']
            end
          end
        end

        def split_event_stream_chunk(chunk)
          # Find the position of the first '{' character which indicates start of JSON
          json_start = chunk.index('{')
          return [nil, nil] unless json_start

          header = chunk[0...json_start].strip
          payload = chunk[json_start..-1]
          
          [header, payload]
        end

        def find_next_prelude(chunk, start_offset)
          # Look for potential message prelude by scanning for reasonable length values
          (start_offset...(chunk.bytesize - 8)).each do |pos|
            potential_total_length = chunk[pos...pos + 4].unpack('N').first
            potential_headers_length = chunk[pos + 4...pos + 8].unpack('N').first
            
            # Check if these look like valid lengths
            if potential_total_length && potential_headers_length &&
               potential_total_length > 0 && potential_total_length < 1_000_000 &&
               potential_headers_length > 0 && potential_headers_length < potential_total_length
              return pos
            end
          end
          nil
        end
      end
    end
  end
end
