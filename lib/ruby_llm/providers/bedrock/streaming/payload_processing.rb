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
          end

          def process_payload_with_headers(payload, headers, &)
            json_payload = extract_json_payload(payload)
            parse_and_process_json_with_headers(json_payload, headers, &)
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
            # Handle tool call events for converse-stream
            if tool_call_event?(json_data) || metadata_event?(json_data)
              process_tool_call_event(json_data)
            else
              # Always create and yield chunks for non-tool-call, non-metadata events
              create_and_yield_chunk(json_data, &)
            end
          end

          def tool_call_event?(data)
            tool_use_start?(data) || tool_use_delta?(data) || tool_use_stop?(data)
          end

          def decode_and_parse_data(json_data)
            decoded_bytes = Base64.strict_decode64(json_data['bytes'])
            JSON.parse(decoded_bytes)
          end

          def create_and_yield_chunk(data, &block)
            chunk = build_chunk(data)
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
        end
      end
    end
  end
end
