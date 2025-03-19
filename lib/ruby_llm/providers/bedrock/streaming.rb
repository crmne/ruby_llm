# frozen_string_literal: true

module RubyLLM
  module Providers
    module Bedrock
      # Streaming methods for the AWS Bedrock API implementation
      module Streaming
        module_function

        def stream_url
          'model'
        end

        def handle_stream(&block)
          to_json_stream do |data|
            block.call(
              Chunk.new(
                role: :assistant,
                model_id: data['model'],
                content: extract_content(data),
                input_tokens: data.dig('usage', 'prompt_tokens'),
                output_tokens: data.dig('usage', 'completion_tokens')
              )
            )
          end
        end

        private

        def extract_content(data)
          case data
          when /anthropic\.claude/
            data[:completion]
          when /amazon\.titan/
            data.dig(:results, 0, :outputText)
          else
            raise Error, "Unsupported model: #{data['model']}"
          end
        end
      end
    end
  end
end 