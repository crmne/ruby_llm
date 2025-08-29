# frozen_string_literal: true

require 'base64'

module RubyLLM
  module Providers
    class Bedrock
      module Streaming
        # Module for processing payloads from AWS Bedrock streaming responses.
        module PayloadProcessing
          def process_payload(payload, &)
            json_payload = extract_json_payload(payload)
            parse_and_process_json(json_payload, &)
          rescue JSON::ParserError => e
            log_json_parse_error(e, json_payload)
          rescue StandardError => e
            log_general_error(e)
          end

          def process_payload_with_headers(payload, headers, &)
            json_payload = extract_json_payload(payload)
            parse_and_process_json_with_headers(json_payload, headers, &)
          rescue JSON::ParserError => e
            log_json_parse_error(e, json_payload)
          rescue StandardError => e
            log_general_error(e)
          end

          private

          def extract_json_payload(payload)
            json_start = payload.index('{')
            json_end = payload.rindex('}')
            payload[json_start..json_end]
          end

          def parse_and_process_json(json_payload, &)
            json_data = JSON.parse(json_payload)
            process_json_data(json_data, &)
          end

          def parse_and_process_json_with_headers(json_payload, headers, &)
            json_data = JSON.parse(json_payload)
            # Extract event type from :event-type header as per AWS documentation
            json_data['type'] = headers[':event-type']
            process_json_data(json_data, &)
          end

          def process_json_data(json_data, &)
            # For converse-stream, the JSON data is the event directly, not wrapped in 'bytes'
            data = if json_data['bytes']
                     # Old invoke-with-response-stream format
                     decode_and_parse_data(json_data)
                   else
                     # New converse-stream format - JSON data is the event directly
                     json_data
                   end

            RubyLLM.logger.debug "Processing JSON data: #{data}" if RubyLLM.config.log_stream_debug
            RubyLLM.logger.debug "Event type: #{data['type']}" if RubyLLM.config.log_stream_debug

            # Handle tool call events for converse-stream
            if is_tool_call_event?(data)
              RubyLLM.logger.debug "Processing tool call event: #{data['type']}" if RubyLLM.config.log_stream_debug
              process_tool_call_event(data)
            elsif is_metadata_event?(data)
              RubyLLM.logger.debug 'Processing metadata event' if RubyLLM.config.log_stream_debug
              process_tool_call_event(data)
            else
              RubyLLM.logger.debug "Processing regular chunk event: #{data['type']}" if RubyLLM.config.log_stream_debug
              if (data['type'] == 'contentBlockDelta') && RubyLLM.config.log_stream_debug
                RubyLLM.logger.debug "Content block delta data: #{data}"
              end
              # Always create and yield chunks for non-tool-call, non-metadata events
              create_and_yield_chunk(data, &)
            end
          end

          def is_tool_call_event?(data)
            is_tool_use_start?(data) || is_tool_use_delta?(data) || is_tool_use_stop?(data)
          end

          def decode_and_parse_data(json_data)
            decoded_bytes = Base64.strict_decode64(json_data['bytes'])
            JSON.parse(decoded_bytes)
          end

          def create_and_yield_chunk(data, &block)
            RubyLLM.logger.debug "Creating chunk for data: #{data}" if RubyLLM.config.log_stream_debug
            chunk = build_chunk(data)
            RubyLLM.logger.debug "Built chunk: #{chunk.inspect}" if RubyLLM.config.log_stream_debug
            block.call(chunk)
          end

          def build_chunk(data)
            Chunk.new(
              **extract_chunk_attributes(data)
            )
          end

          def extract_chunk_attributes(data)
            {
              role: :assistant,
              model_id: extract_model_id(data),
              content: extract_streaming_content(data),
              input_tokens: nil, # Tokens come from metadata events, not individual chunks
              output_tokens: nil, # Tokens come from metadata events, not individual chunks
              tool_calls: extract_tool_calls(data)
            }
          end

          def log_json_parse_error(error, json_payload)
            RubyLLM.logger.debug "Failed to parse payload as JSON: #{error.message}"
            RubyLLM.logger.debug "Attempted JSON payload: #{json_payload.inspect}"
          end

          def log_general_error(error)
            RubyLLM.logger.debug "Error processing payload: #{error.message}"
          end
        end
      end
    end
  end
end
