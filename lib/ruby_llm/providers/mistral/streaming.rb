# frozen_string_literal: true

module RubyLLM
  module Providers
    module Mistral
      # Handles streaming responses for Mistral models (Simplified)
      module Streaming
        module_function

        # Assumes base module's stream_response/handle_stream/to_json_stream work correctly
        # and yield parsed JSON data for each SSE event.

        def build_chunk(data)
          # Directly build a chunk from the already parsed JSON data yielded by the base streamer
          delta = data.dig('choices', 0, 'delta')
          return nil unless delta # Skip if delta is missing or choices structure absent

          # Extract content and tool calls
          content = delta['content']
          # Ensure Mistral::Tools is available
          require_relative 'tools' unless defined?(RubyLLM::Providers::Mistral::Tools)
          tool_calls = Mistral::Tools.parse_tool_calls(delta['tool_calls'])

          # Skip chunks that contain neither content, nor tool calls, nor a role update
          if content.nil? && (tool_calls.nil? || tool_calls.empty?) && delta['role'].nil?
             return nil
          end

          # Extract usage if available (often only in the last chunk for some APIs)
          usage = data.dig('usage')
          input_tokens = usage&.dig('prompt_tokens')
          output_tokens = usage&.dig('completion_tokens')

          chunk = Chunk.new(
            role: delta['role']&.to_sym || :assistant, # Default role if missing
            content: content,
            tool_calls: tool_calls,
            model_id: data['model'],
            input_tokens: input_tokens,
            output_tokens: output_tokens
          )
          chunk
        end

        # No custom handle_stream or parse_stream_data needed.
        # Rely on the included RubyLLM::Streaming module's defaults
        # which should call this build_chunk method.

      end
    end
  end
end
