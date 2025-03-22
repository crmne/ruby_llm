# frozen_string_literal: true
require 'base64'

module RubyLLM
  module Providers
    module Bedrock
      # Streaming methods for the AWS Bedrock API implementation
      module Streaming
        module_function

        def stream_url
          "model/#{model_id}/invoke-with-response-stream"
        end

        def handle_stream(&block)
          decoder = Decoder.new
          buffer = String.new
          accumulated_content = ""

          proc do |chunk, _bytes, env|
            if env && env.status != 200
              # Accumulate error chunks
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
              # Process the chunk using the AWS EventStream decoder
              begin
                message, is_complete = decoder.decode_chunk(chunk)
                
                if message
                  payload = message.payload.read
                  parsed_data = nil
                  
                  begin
                    if payload.is_a?(String)
                      # Try parsing as JSON
                      json_data = JSON.parse(payload)
                      
                      # Handle Base64 encoded bytes
                      if json_data.is_a?(Hash) && json_data["bytes"]
                        # Decode the Base64 string
                        decoded_bytes = Base64.strict_decode64(json_data["bytes"])
                        # Parse the decoded JSON
                        parsed_data = JSON.parse(decoded_bytes)
                      else
                        # Handle normal JSON data
                        parsed_data = json_data
                      end
                    end
                  rescue JSON::ParserError => e
                    RubyLLM.logger.debug "Failed to parse payload as JSON: #{e.message}"
                    next
                  rescue StandardError => e
                    RubyLLM.logger.debug "Error processing payload: #{e.message}"
                    next
                  end

                  next if parsed_data.nil?

                  # Extract content based on the event type
                  content = extract_streaming_content(parsed_data)
                  
                  # Only emit a chunk if there's content to emit
                  unless content.nil? || content.empty?
                    accumulated_content += content
                    
                    block.call(
                      Chunk.new(
                        role: :assistant,
                        model_id: parsed_data.dig('message', 'model') || @model_id,
                        content: content,
                        input_tokens: parsed_data.dig('message', 'usage', 'input_tokens'),
                        output_tokens: parsed_data.dig('message', 'usage', 'output_tokens')
                      )
                    )
                  end
                end
              rescue StandardError => e
                RubyLLM.logger.debug "Error processing chunk: #{e.message}"
                next
              end
            end
          end
        end

        def extract_streaming_content(data)
          if data.is_a?(Hash)
            case data['type']
            when 'message_start'
              # No content yet in message_start
              ""
            when 'content_block_start'
              # Initial content block, might have some text
              data.dig('content_block', 'text').to_s
            when 'content_block_delta'
              # Incremental content updates
              data.dig('delta', 'text').to_s
            when 'message_delta'
              # Might contain updates to usage stats, but no new content
              ""
            else
              # Fall back to the existing extract_content method for other formats
              extract_content(data)
            end
          else
            extract_content(data)
          end
        end

        private

        def extract_content(data)
          case data
          when Hash
            if data.key?('completion')
              data['completion']
            elsif data.dig('results', 0, 'outputText')
              data.dig('results', 0, 'outputText')
            elsif data.key?('content')
              data['content'].is_a?(Array) ? data['content'].map { |item| item['text'] }.join('') : data['content']
            elsif data.key?('content_block') && data['content_block'].key?('text')
              # Handle the newly decoded JSON structure
              data['content_block']['text']
            else
              nil
            end
          else
            nil
          end
        end
      end
    end
  end
end
