# frozen_string_literal: true

module RubyLLM
  module Providers
    module Ollama
      # Chat methods for the Ollama API implementation
      module Chat
        module_function

        def completion_url
          'api/chat'
        end

        def render_payload(messages, tools:, temperature:, model:, stream: false)
          # Heuristic: if temperature is set to default and tools are in play,
          # use a low temperature to reduce risk of small models ignoring available
          # tools in favor of making up imaginary API calls
          temperature = 0.1 if tools.any? && temperature == RubyLLM::Chat::DEFAULT_TEMPERATURE

          {
            model: model,
            messages: Media.format_messages(messages),
            options: {
              temperature: temperature
            },
            stream: stream,
            tools: tools.map { |_, tool| tool_for(tool) }
          }
        end

        def parse_completion_response(response)
          data = Tools.preprocess_tool_calls(response.body)

          Message.new(
            role: :assistant,
            content: data.dig('message', 'content'),
            input_tokens: data['prompt_eval_count'].to_i,
            output_tokens: data['eval_count'].to_i,
            model_id: data['model'],
            tool_calls: parse_tool_calls(data.dig('message', 'tool_calls'))
          )
        end
      end
    end
  end
end
