# frozen_string_literal: true

module RubyLLM
  module Providers
    class Bedrock
      module Streaming
        # Instance-method mixin for streaming tool call accumulation/handling
        module ToolCalls
          def initialize_tool_call_accumulator
            @current_tool_use_id = nil
            @current_tool_name = nil
            @current_tool_input = +''
            @accumulated_tool_calls = {}
            @token_usage = {}
          end

          def process_tool_call_event(data)
            if tool_use_start?(data)
              process_tool_use_start(data)
            elsif tool_use_delta?(data)
              process_tool_use_delta(data)
            elsif tool_use_stop?(data)
              process_tool_use_stop(data)
            elsif metadata_event?(data)
              process_metadata_event(data)
            end
          end

          def accumulated_tool_calls
            @accumulated_tool_calls.values
          end

          def token_usage
            @token_usage
          end

          def active_tool_call?
            !@current_tool_use_id.nil?
          end

          private

          def process_tool_use_start(data)
            tool_info = extract_tool_use_start(data)
            return unless tool_info

            @current_tool_use_id = tool_info[:tool_use_id]
            @current_tool_name = tool_info[:name]
            @current_tool_input = +''
          end

          def process_tool_use_delta(data)
            return unless @current_tool_use_id

            tool_delta = extract_tool_use_delta(data)
            return unless tool_delta

            @current_tool_input << tool_delta[:input]
          end

          def process_tool_use_stop(_data)
            return unless @current_tool_use_id

            # Parse the accumulated input as JSON
            begin
              arguments = JSON.parse(@current_tool_input)
            rescue JSON::ParserError
              arguments = {}
            end

            # Create the tool call
            tool_call = RubyLLM::ToolCall.new(
              id: @current_tool_use_id,
              name: @current_tool_name,
              arguments: arguments
            )

            @accumulated_tool_calls[@current_tool_use_id] = tool_call

            # Reset for next tool call
            @current_tool_use_id = nil
            @current_tool_name = nil
            @current_tool_input = +''
          end

          def process_metadata_event(data)
            usage = extract_metadata_usage(data)
            return if usage.empty?

            @token_usage = usage
          end
        end
      end
    end
  end
end
