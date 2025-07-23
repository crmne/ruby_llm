# frozen_string_literal: true

module RubyLLM
  module Providers
    module OpenAI
      # Response methods of the OpenAI API integration
      module Response
        def responses_url
          'responses'
        end

        module_function

        def parse_respond_response(response)
          data = response.body
          return if data.empty?

          raise Error.new(response, data.dig('error', 'message')) if data.dig('error', 'message')

          outputs = data['output']
          return unless outputs.any?

          Message.new(
            role: :assistant,
            content: all_output_text(outputs),
            tool_calls: parse_response_tool_calls(outputs),
            input_tokens: data['usage']['input_tokens'],
            output_tokens: data['usage']['output_tokens'],
            model_id: data['model']
          )
        end

        def all_output_text(outputs)
          outputs.select { |o| o['type'] == 'message' }.flat_map do |o|
            o['content'].filter_map do |c|
              c['type'] == 'output_text' && c['text']
            end
          end.join("\n")
        end
      end
    end
  end
end
