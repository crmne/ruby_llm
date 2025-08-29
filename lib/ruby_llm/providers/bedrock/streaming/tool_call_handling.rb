# frozen_string_literal: true

require 'json'

module RubyLLM
  module Providers
    class Bedrock
      module Streaming
        # Module for handling tool call accumulation in converse-stream format.
        module ToolCallHandling
          def initialize_tool_call_accumulator
            @current_tool_use_id = nil
            @current_tool_name = nil
            @current_tool_input = +''
            @accumulated_tool_calls = {}
            @token_usage = {}
          end

          def process_tool_call_event(data)
            if is_tool_use_start?(data)
              process_tool_use_start(data)
            elsif is_tool_use_delta?(data)
              process_tool_use_delta(data)
            elsif is_tool_use_stop?(data)
              process_tool_use_stop(data)
            elsif is_metadata_event?(data)
              process_metadata_event(data)
            end
          end

          def get_accumulated_tool_calls
            @accumulated_tool_calls.values
          end

          def get_token_usage
            @token_usage
          end

          def has_active_tool_call?
            !@current_tool_use_id.nil?
          end

          private

          def process_tool_use_start(data)
            tool_info = extract_tool_use_start(data)
            return unless tool_info

            @current_tool_use_id = tool_info[:tool_use_id]
            @current_tool_name = tool_info[:name]
            @current_tool_input = +''

            RubyLLM.logger.debug "Started tool use: #{@current_tool_name} (#{@current_tool_use_id})" if RubyLLM.config.log_stream_debug
          end

          def process_tool_use_delta(data)
            return unless @current_tool_use_id

            tool_delta = extract_tool_use_delta(data)
            return unless tool_delta

            @current_tool_input << tool_delta[:input]
            RubyLLM.logger.debug "Accumulating tool input: #{tool_delta[:input]}" if RubyLLM.config.log_stream_debug
          end

          def process_tool_use_stop(data)
            return unless @current_tool_use_id

            # Parse the accumulated input as JSON
            begin
              arguments = JSON.parse(@current_tool_input)
            rescue JSON::ParserError => e
              RubyLLM.logger.warn "Failed to parse tool call arguments: #{e.message}"
              arguments = {}
            end

            # Create the tool call
            tool_call = RubyLLM::ToolCall.new(
              id: @current_tool_use_id,
              name: @current_tool_name,
              arguments: arguments
            )

            @accumulated_tool_calls[@current_tool_use_id] = tool_call

            RubyLLM.logger.debug "Completed tool call: #{@current_tool_name} (#{@current_tool_use_id})" if RubyLLM.config.log_stream_debug

            # Reset for next tool call
            @current_tool_use_id = nil
            @current_tool_name = nil
            @current_tool_input = +''
          end

          def process_metadata_event(data)
            usage = extract_metadata_usage(data)
            return if usage.empty?

            @token_usage = usage
            RubyLLM.logger.debug "Received token usage: #{usage}" if RubyLLM.config.log_stream_debug
          end
        end
      end
    end
  end
end
