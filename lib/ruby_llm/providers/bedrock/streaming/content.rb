# frozen_string_literal: true

module RubyLLM
  module Providers
    class Bedrock
      module Streaming
        # Content helpers for AWS Bedrock streaming responses.
        module Content
          def extract_streaming_content(data)
            return '' unless data.is_a?(Hash)

            extract_content_by_type(data)
          end

          def extract_tool_calls(_data)
            # Tool calls are handled separately in the tool call flow
            []
          end

          def extract_model_id(_data)
            @model_id
          end

          def tool_use_start?(data)
            data['type'] == 'contentBlockStart' && data.dig('start', 'toolUse')
          end

          def tool_use_delta?(data)
            data['type'] == 'contentBlockDelta' && data.dig('delta', 'toolUse')
          end

          def tool_use_stop?(data)
            data['type'] == 'contentBlockStop'
          end

          def metadata_event?(data)
            data['type'] == 'metadata'
          end

          def extract_metadata_usage(data)
            data['usage'] || {}
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
                      when 'contentBlockStart' then extract_block_start_content(data)
                      when 'contentBlockDelta' then extract_delta_content(data)
                      else ''
                      end

            if RubyLLM.config.log_stream_debug
              RubyLLM.logger.debug "Extracted content for #{data['type']}: #{content.inspect}"
            end
            content
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
              ''
            else
              # Regular text delta
              data.dig('delta', 'text').to_s
            end
          end
        end
      end
    end
  end
end
