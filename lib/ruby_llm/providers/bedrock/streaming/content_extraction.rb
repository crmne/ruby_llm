# frozen_string_literal: true

module RubyLLM
  module Providers
    class Bedrock
      module Streaming
        # Module for handling content extraction from AWS Bedrock streaming responses.
        module ContentExtraction
          def json_delta?(data)
            data['type'] == 'contentBlockDelta' && data.dig('delta', 'type') == 'input_json_delta'
          end

          def extract_streaming_content(data)
            return '' unless data.is_a?(Hash)

            content = extract_content_by_type(data)

            if RubyLLM.config.log_stream_debug
              RubyLLM.logger.debug "extract_streaming_content: data=#{data}, content=#{content.inspect}"
            end

            content
          end

          def extract_tool_calls(_data)
            # Tool calls are handled separately in the tool call flow
            []
          end

          def extract_model_id(_data)
            @model_id
          end

          def extract_input_tokens(_data)
            # Tokens are not available in streaming chunks
            nil
          end

          def extract_output_tokens(_data)
            # Tokens are not available in streaming chunks
            nil
          end

          def extract_stop_reason(data)
            data['stopReason']
          end

          def is_tool_use_start?(data)
            data['type'] == 'contentBlockStart' && data.dig('start', 'toolUse')
          end

          def is_tool_use_delta?(data)
            data['type'] == 'contentBlockDelta' && data.dig('delta', 'toolUse')
          end

          def is_tool_use_stop?(data)
            data['type'] == 'contentBlockStop'
          end

          def is_metadata_event?(data)
            data['type'] == 'metadata'
          end

          def extract_metadata_usage(data)
            data.dig('usage') || {}
          end

          def extract_tool_use_start(data)
            tool_use = data.dig('start', 'toolUse')
            return nil unless tool_use

            {
              tool_use_id: tool_use['toolUseId'],
              name: tool_use['name']
            }
          end

          def extract_tool_use_delta(data)
            tool_use = data.dig('delta', 'toolUse')
            return nil unless tool_use

            {
              input: tool_use['input']
            }
          end

          private

          def extract_content_by_type(data)
            content = case data['type']
                      when 'messageStart' then extract_message_start_content(data)
                      when 'contentBlockStart' then extract_block_start_content(data)
                      when 'contentBlockDelta' then extract_delta_content(data)
                      when 'contentBlockStop' then extract_block_stop_content(data)
                      when 'messageDelta' then extract_message_delta_content(data)
                      when 'messageStop' then extract_message_stop_content(data)
                      when 'metadata' then extract_metadata_content(data)
                      else ''
                      end

            if RubyLLM.config.log_stream_debug
              RubyLLM.logger.debug "Extracted content for #{data['type']}: #{content.inspect}"
            end
            content
          end

          def extract_message_start_content(_data)
            # Message start doesn't contain content
            ''
          end

          def extract_block_start_content(data)
            # Content block start might contain tool use info
            if data.dig('start', 'toolUse')
              # This is a tool use start, no text content
              ''
            else
              # Regular content block start
              data.dig('start', 'text').to_s
            end
          end

          def extract_delta_content(data)
            if data.dig('delta', 'toolUse')
              # This is a tool use delta, no text content
              RubyLLM.logger.debug 'Tool use delta detected, no text content' if RubyLLM.config.log_stream_debug
              ''
            else
              # Regular text delta
              text_content = data.dig('delta', 'text').to_s
              RubyLLM.logger.debug "Text delta content: #{text_content.inspect}" if RubyLLM.config.log_stream_debug
              text_content
            end
          end

          def extract_block_stop_content(_data)
            # Block stop doesn't contain content
            ''
          end

          def extract_message_delta_content(_data)
            # Message delta might contain role changes or other metadata
            ''
          end

          def extract_message_stop_content(_data)
            # Message stop doesn't contain content
            ''
          end

          def extract_metadata_content(_data)
            # Metadata doesn't contain text content
            ''
          end
        end
      end
    end
  end
end
