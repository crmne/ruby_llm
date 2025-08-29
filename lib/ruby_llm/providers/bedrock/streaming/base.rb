# frozen_string_literal: true

module RubyLLM
  module Providers
    class Bedrock
      module Streaming
        # Base module for AWS Bedrock streaming functionality.
        module Base
          def self.included(base)
            base.include ContentExtraction
            base.include MessageProcessing
            base.include PayloadProcessing
            base.include PreludeHandling
            base.include ToolCallHandling
          end

          def stream_url
            "model/#{@model_id}/converse-stream"
          end

          def stream_response(connection, payload, additional_headers = {}, &block)
            signature = sign_request("#{connection.connection.url_prefix}#{stream_url}", payload:)
            accumulator = StreamAccumulator.new

            # Initialize tool call accumulator for converse-stream
            initialize_tool_call_accumulator

            RubyLLM.logger.debug "Bedrock streaming to URL: #{stream_url}" if RubyLLM.config.log_stream_debug
            RubyLLM.logger.debug "Bedrock streaming payload: #{payload}" if RubyLLM.config.log_stream_debug

            response = connection.post stream_url, payload do |req|
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

            if RubyLLM.config.log_stream_debug
              RubyLLM.logger.debug "Bedrock streaming response status: #{response.status}"
            end
            if RubyLLM.config.log_stream_debug
              RubyLLM.logger.debug "Bedrock streaming response headers: #{response.headers}"
            end

            # Add accumulated tool calls and token usage to the final message
            final_message = accumulator.to_message(response)
            if RubyLLM.config.log_stream_debug
              RubyLLM.logger.debug "Bedrock accumulator message: #{final_message.inspect}"
            end

            if get_accumulated_tool_calls.any?
              if RubyLLM.config.log_stream_debug
                RubyLLM.logger.debug "Bedrock accumulated tool calls: #{get_accumulated_tool_calls}"
              end
              final_message.instance_variable_set(:@tool_calls, get_accumulated_tool_calls)
            end

            # Add token usage from metadata event
            token_usage = get_token_usage
            if token_usage.any?
              RubyLLM.logger.debug "Bedrock token usage: #{token_usage}" if RubyLLM.config.log_stream_debug
              final_message.instance_variable_set(:@input_tokens, token_usage['inputTokens'])
              final_message.instance_variable_set(:@output_tokens, token_usage['outputTokens'])
            end

            # Set model_id if it's missing
            if final_message.model_id.nil?
              RubyLLM.logger.debug "Setting model_id to: #{@model_id}" if RubyLLM.config.log_stream_debug
              final_message.instance_variable_set(:@model_id, @model_id)
            end

            RubyLLM.logger.debug "Bedrock final message: #{final_message.inspect}" if RubyLLM.config.log_stream_debug

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
        end
      end
    end
  end
end
