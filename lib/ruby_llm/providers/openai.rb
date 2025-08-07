# frozen_string_literal: true

module RubyLLM
  module Providers
    # OpenAI API integration using the new Responses API. Handles response generation,
    # function calling, and OpenAI's unique streaming format. Supports GPT-4, GPT-3.5,
    # and other OpenAI models.
    class OpenAI < OpenAIBase
      include OpenAI::Response
      include OpenAI::ResponseMedia

      def audio_input?(messages)
        messages.any? do |message|
          next false unless message.respond_to?(:content) && message.content.respond_to?(:attachments)

          message.content.attachments.any? { |attachment| attachment.type == :audio }
        end
      end

      def render_payload(messages, tools:, temperature:, model:, stream: false, schema: nil) # rubocop:disable Metrics/ParameterLists
        @using_responses_api = !audio_input?(messages)

        if @using_responses_api
          render_response_payload(messages, tools: tools, temperature: temperature, model: model, stream: stream,
                                            schema: schema)
        else
          super
        end
      end

      def completion_url
        @using_responses_api ? responses_url : super
      end

      def parse_completion_response(response)
        if @using_responses_api
          parse_respond_response(response)
        else
          super
        end
      end
    end
  end
end
