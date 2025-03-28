# frozen_string_literal: true

module RubyLLM
  module Providers
    module Ollama
      # Tools methods of the Ollama API integration
      module Tools
        module_function

        def tool_for(tool) # rubocop:disable Metrics/MethodLength
          {
            type: 'function',
            function: {
              name: tool.name,
              description: tool.description,
              parameters: {
                type: 'object',
                properties: tool.parameters.transform_values { |param| param_schema(param) },
                required: tool.parameters.select { |_, p| p.required }.keys
              }
            }
          }
        end

        def param_schema(param)
          {
            type: param.type,
            description: param.description
          }.compact
        end

        def parse_tool_calls(tool_calls)
          (tool_calls || []).to_h do |tc|
            tc = tc['function'] if tc['function']
            name = tc['name']
            next [nil, nil] unless name =~ /\S/

            [
              name,
              ToolCall.new(id: name, name: name, arguments: tc['arguments'])
            ]
          end.compact
        end

        # HACK: Llama3.x yields this in the proper tool_calls response field,
        # but some other models return it as markup inside the text response.
        #
        # Unfortunately said other models are all over the place when it comes
        # to sticking to a format so this doesn't cover all edge cases.
        def preprocess_tool_calls(response_data)
          # Move <toolcall>JSON</toolcall> markup from inside the text to its
          # specific field in the response where it should be.
          # https://github.com/ollama/ollama/blob/main/docs/api.md#chat-request-with-tools

          tc = response_data['message']['tool_calls'] ||= []
          response_data['message']['content']&.gsub!(%r{<tool_?call>(.*)</tool_?call>}mi) do
            capture = ::Regexp.last_match(1)
            tc << JSON.parse(capture) if capture =~ /^\s*{/
            ''
          end
          tc.flatten!
          response_data
        end
      end
    end
  end
end
