# frozen_string_literal: true

module RubyLLM
  module Providers
    # OpenAI API integration.
    class OpenAI < OpenAIBase
      include OpenAI::Response
      include OpenAI::ResponseMedia

      def audio_input?(messages)
        messages.any? do |message|
          next false unless message.respond_to?(:content) && message.content.respond_to?(:attachments)

          message.content.attachments.any? { |attachment| attachment.type == :audio }
        end
      end

      def render_payload(messages, tools:, temperature:, model:, stream: false, schema: nil, thinking: nil) # rubocop:disable Metrics/ParameterLists
        @using_responses_api = !audio_input?(messages)

        if @using_responses_api
          render_response_payload(messages, tools: tools, temperature: temperature, model: model, stream: stream,
                                            schema: schema, thinking: thinking)
        else
          super
        end
      end

      def completion_url
        @using_responses_api ? responses_url : super
      end

      def parse_completion_response(response)
        if @using_responses_api
          parse_response_response(response)
        else
          super
        end
      end
    end
  end
end
