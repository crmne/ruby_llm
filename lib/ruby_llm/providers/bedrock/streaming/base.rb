# frozen_string_literal: true

module RubyLLM
  module Providers
    class Bedrock
      module Streaming
        # Base module for AWS Bedrock streaming functionality.
        module Base
          def self.included(base)
            base.include Content
            base.include Messages
            base.include Payload
            base.include Prelude
            base.include ToolCalls
          end

          def stream_url
            "model/#{@model_id}/converse-stream"
          end

          def stream_response(connection, payload, additional_headers = {}, &)
            signature = sign_request("#{connection.connection.url_prefix}#{stream_url}", payload:)
            accumulator = StreamAccumulator.new

            # Initialize tool call accumulator for converse-stream
            initialize_tool_call_accumulator

            response = post_stream(connection, payload, additional_headers, signature, accumulator, &)

            log_stream_response(response)

            final_message = accumulator.to_message(response)
            augment_message_with_streaming_data(final_message)
            final_message
          end

          def handle_stream(&block)
            buffer = +''
            chunk_count = 0
            proc do |chunk, _bytes, env|
              chunk_count += 1
              if RubyLLM.config.log_stream_debug
                RubyLLM.logger.debug "Received chunk #{chunk_count}: size=#{chunk.bytesize}"
              end

              if env && env.status != 200
                handle_failed_response(chunk, buffer, env)
              else
                process_chunk(chunk, &block)
              end
            end
          end

          def post_stream(connection, payload, additional_headers, signature, accumulator, &block)
            connection.post stream_url, payload do |req|
              req.headers.merge! build_headers(signature.headers, streaming: block_given?)
              # Merge additional headers, with existing headers taking precedence
              req.headers = additional_headers.merge(req.headers) unless additional_headers.empty?
              req.options.on_data = handle_stream do |chunk|
                RubyLLM.logger.debug "Bedrock streaming chunk: #{chunk.inspect}" if RubyLLM.config.log_stream_debug
                accumulator.add chunk
                # Call the block with the individual chunk for UI streaming
                block.call chunk if block_given?
              end
            end
          end

          def log_stream_response(response)
            return unless RubyLLM.config.log_stream_debug

            RubyLLM.logger.debug "Bedrock streaming response status: #{response.status}"
            RubyLLM.logger.debug "Bedrock streaming response headers: #{response.headers}"
          end

          def augment_message_with_streaming_data(final_message)
            if accumulated_tool_calls.any?
              tool_calls_hash = accumulated_tool_calls.each_with_object({}) do |tool_call, hash|
                hash[tool_call.id] = tool_call
              end
              final_message.instance_variable_set(:@tool_calls, tool_calls_hash)
            end

            if token_usage.any?
              final_message.instance_variable_set(:@input_tokens, token_usage['inputTokens'])
              final_message.instance_variable_set(:@output_tokens, token_usage['outputTokens'])
            end

            final_message.instance_variable_set(:@model_id, @model_id) if final_message.model_id.nil?
          end
        end
      end
    end
  end
end
