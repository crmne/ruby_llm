# frozen_string_literal: true

module RubyLLM
  module Providers
    module Bedrock
      # Chat methods for the AWS Bedrock API implementation
      module Chat
        module_function

        def completion_url
          'model'
        end

        def render_payload(messages, tools:, temperature:, model:, stream: false)
          # Format depends on the specific model being used
          case model_id_for(model)
          when /anthropic\.claude/
            build_claude_request(messages, temperature)
          when /amazon\.titan/
            build_titan_request(messages, temperature)
          else
            raise Error, "Unsupported model: #{model}"
          end
        end

        def parse_completion_response(response)
          data = response.body
          return if data.empty?

          Message.new(
            role: :assistant,
            content: extract_content(data),
            input_tokens: data.dig('usage', 'prompt_tokens'),
            output_tokens: data.dig('usage', 'completion_tokens'),
            model_id: data['model']
          )
        end

        private

        def build_claude_request(messages, temperature)
          formatted = messages.map do |msg|
            role = msg.role == :assistant ? 'Assistant' : 'Human'
            content = msg.content
            "\n\n#{role}: #{content}"
          end.join

          {
            prompt: formatted + "\n\nAssistant:",
            temperature: temperature,
            max_tokens: max_tokens_for(messages.first&.model_id)
          }
        end

        def build_titan_request(messages, temperature)
          {
            inputText: messages.map { |msg| msg.content }.join("\n"),
            textGenerationConfig: {
              temperature: temperature,
              maxTokenCount: max_tokens_for(messages.first&.model_id)
            }
          }
        end

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

        def model_id_for(model)
          case model
          when 'claude-3-sonnet'
            'anthropic.claude-3-sonnet-20240229-v1:0'
          when 'claude-2'
            'anthropic.claude-v2'
          when 'claude-instant'
            'anthropic.claude-instant-v1'
          when 'titan'
            'amazon.titan-text-express-v1'
          else
            model # assume it's a full model ID
          end
        end

        def max_tokens_for(model_id)
          Models.find(model_id)&.max_tokens
        end
      end
    end
  end
end 