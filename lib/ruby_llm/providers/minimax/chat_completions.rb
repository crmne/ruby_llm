# frozen_string_literal: true

module RubyLLM
  module Providers
    class MiniMax
      # MiniMax's own Chat Completion v2 route, used only for structured
      # output on the one model that applies response_format. That model
      # nests its answer under the schema name, so parsing removes the
      # wrapper, which cannot be done part by part on a stream.
      class ChatCompletions < Protocols::ChatCompletions
        def completion_url
          "#{@provider.media_base}/v1/text/chatcompletion_v2"
        end

        def render_payload(messages, schema: nil, stream: false, **)
          raise ArgumentError, "#{@model.id} does not stream structured output" if schema && stream

          @schema_name = schema&.dig(:name)
          super
        end

        def parse_completion_body(data, raw:)
          super(unwrap_schema_result(data), raw: raw)
        end

        private

        def unwrap_schema_result(data)
          content = data.dig('choices', 0, 'message', 'content')
          return data unless @schema_name && content.is_a?(String)

          parsed = parse_json(content)
          return data unless parsed.is_a?(Hash) && parsed.keys == [@schema_name]

          choice = data['choices'][0]
          message = choice['message'].merge('content' => JSON.generate(parsed[@schema_name]))
          data.merge('choices' => [choice.merge('message' => message), *data['choices'][1..]])
        end

        def parse_json(content)
          JSON.parse(content)
        rescue JSON::ParserError
          nil
        end
      end
    end
  end
end
