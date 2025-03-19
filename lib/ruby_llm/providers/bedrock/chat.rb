# frozen_string_literal: true

module RubyLLM
  module Providers
    module Bedrock
      # Chat methods for the AWS Bedrock API implementation
      module Chat
        module_function

        def completion_url
          "model/#{model_id}/invoke-with-response-stream"
        end

        def model_id
          @model_id
        end

        def render_payload(messages, tools:, temperature:, model:, stream: false)
          @model_id = model
          case model
          when /anthropic\.claude/
            build_claude_request(messages, temperature, model)
          when /amazon\.titan/
            build_titan_request(messages, temperature, model)
          else
            raise Error, "Unsupported model: #{model}"
          end
        end

        def parse_completion_response(response)
          data = response.body
          data = JSON.parse(data) if data.is_a?(String)
          return if data.nil? || data.empty?

          Message.new(
            role: :assistant,
            content: extract_content(data),
            input_tokens: data.dig('usage', 'prompt_tokens'),
            output_tokens: data.dig('usage', 'completion_tokens'),
            model_id: data['model']
          )
        end

        private

        def build_claude_request(messages, temperature, model_id)
          formatted = messages.map do |msg|
            role = msg.role == :assistant ? 'Assistant' : 'Human'
            content = msg.content
            "\n\n#{role}: #{content}"
          end.join

          {
            anthropic_version: "bedrock-2023-05-31",
            messages: [
              {
                role: "user",
                content: formatted
              }
            ],
            temperature: temperature,
            max_tokens: max_tokens_for(model_id)
          }
        end

        def build_titan_request(messages, temperature, model_id)
          {
            inputText: messages.map { |msg| msg.content }.join("\n"),
            textGenerationConfig: {
              temperature: temperature,
              maxTokenCount: max_tokens_for(model_id)
            }
          }
        end

        def extract_content(data)
          case data
          when Hash
            if data.key?('completion')
              data['completion']
            elsif data.dig('results', 0, 'outputText')
              data.dig('results', 0, 'outputText')
            else
              raise Error, "Unexpected response format: #{data.keys}"
            end
          else
            raise Error, "Unexpected response type: #{data.class}"
          end
        end

        def max_tokens_for(model_id)
          RubyLLM.models.find(model_id)&.max_tokens
        end

      end
    end
  end
end 