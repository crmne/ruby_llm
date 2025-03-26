# frozen_string_literal: true

module RubyLLM
  module Providers
    module Bedrock
      module Streaming
        # Module for handling content extraction from AWS Bedrock streaming responses.
        # Provides methods to extract and process various types of content from the response data.
        #
        # Responsibilities:
        # - Extracting content from different response formats
        # - Processing JSON deltas and content blocks
        # - Extracting metadata (tokens, model IDs, tool calls)
        # - Handling different content structures (arrays, blocks, completions)
        #
        # @example Content extraction from a response
        #   content = extract_content(response_data)
        #   streaming_content = extract_streaming_content(delta_data)
        #   tool_calls = extract_tool_calls(message_data)
        module ContentExtraction
          def json_delta?(data)
            data['type'] == 'content_block_delta' && data.dig('delta', 'type') == 'input_json_delta'
          end

          def extract_streaming_content(data)
            return '' unless data.is_a?(Hash)

            extract_content_by_type(data)
          end

          def extract_content(data)
            return unless data.is_a?(Hash)

            try_content_extractors(data)
          end

          def extract_completion_content(data)
            data['completion'] if data.key?('completion')
          end

          def extract_output_text_content(data)
            data.dig('results', 0, 'outputText')
          end

          def extract_array_content(data)
            return unless data.key?('content')

            content = data['content']
            content.is_a?(Array) ? join_array_content(content) : content
          end

          def extract_content_block_text(data)
            return unless data.key?('content_block') && data['content_block'].key?('text')

            data['content_block']['text']
          end

          def extract_tool_calls(data)
            data.dig('message', 'tool_calls') || data['tool_calls']
          end

          def extract_model_id(data)
            data.dig('message', 'model') || @model_id
          end

          def extract_input_tokens(data)
            data.dig('message', 'usage', 'input_tokens')
          end

          def extract_output_tokens(data)
            data.dig('message', 'usage', 'output_tokens') || data.dig('usage', 'output_tokens')
          end

          private

          def extract_content_by_type(data)
            case data['type']
            when 'content_block_start' then extract_block_start_content(data)
            when 'content_block_delta' then extract_delta_content(data)
            else ''
            end
          end

          def extract_block_start_content(data)
            data.dig('content_block', 'text').to_s
          end

          def extract_delta_content(data)
            data.dig('delta', 'text').to_s
          end

          def try_content_extractors(data)
            content_extractors.each do |extractor|
              content = send(extractor, data)
              return content if content
            end
            nil
          end

          def content_extractors
            %i[
              extract_completion_content
              extract_output_text_content
              extract_array_content
              extract_content_block_text
            ]
          end

          def join_array_content(content_array)
            content_array.map { |item| item['text'] }.join
          end
        end
      end
    end
  end
end
