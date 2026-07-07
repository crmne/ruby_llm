# frozen_string_literal: true

module RubyLLM
  module Protocols
    class ChatCompletions
      # Moderation methods of the OpenAI API integration
      module Moderation
        module_function

        def moderation_url
          'moderations'
        end

        def render_moderation_payload(input, model:, provider_options: {})
          {
            model: model,
            input: input
          }.merge(provider_options)
        end

        def parse_moderation_response(response, model:)
          data = response.body
          raise Error.new(data.dig('error', 'message'), response:) if data.dig('error', 'message')

          RubyLLM::Moderation.new(
            id: data['id'],
            model: model,
            results: Array(data['results']).map { |result| RubyLLM::Moderation::Result.from_h(result) }
          )
        end
      end
    end
  end
end
