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
          {
            model: model,
            messages: Media.format_messages(messages),
            options: {
              temperature: temperature
            },
            stream: stream
          }.tap { |h| h.merge!(tools: tools.map { |_, t| tool_for(t) }) if tools.any? }
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
