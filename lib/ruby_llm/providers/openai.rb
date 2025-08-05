# frozen_string_literal: true

module RubyLLM
  module Providers
    # OpenAI API integration using the new Responses API. Handles response generation,
    # function calling, and OpenAI's unique streaming format. Supports GPT-4, GPT-3.5,
    # and other OpenAI models.
    module OpenAI
      extend OpenAI::ChatCompletions
      extend OpenAI::Response
      extend OpenAI::ResponseMedia

      def self.extended(base)
        base.extend(OpenAI::ChatCompletions)
        base.extend(OpenAI::Response)
        base.extend(OpenAI::ResponseMedia)
      end

      module_function

      # Detect if messages contain audio attachments
      def has_audio_input?(messages)
        messages.any? do |message|
          next false unless message.respond_to?(:content) && message.content.respond_to?(:attachments)
          
          message.content.attachments.any? { |attachment| attachment.type == :audio }
        end
      end

      # Override render_payload to conditionally route to chat completions or responses API
      def render_payload(messages, tools:, temperature:, model:, stream: false, schema: nil)
        # Track which API we're using for later methods
        @using_responses_api = !has_audio_input?(messages)
        
        if @using_responses_api
          # Use responses API for everything else
          render_response_payload(messages, tools: tools, temperature: temperature, model: model, stream: stream, schema: schema)
        else
          # Use chat completions for audio - call the original method from ChatCompletions
          super(messages, tools: tools, temperature: temperature, model: model, stream: stream, schema: schema)
        end
      end

      # Override completion_url to conditionally route to the right endpoint  
      def completion_url
        @using_responses_api ? responses_url : super
      end

      # Override parse_completion_response to use the right parser
      def parse_completion_response(response)
        if @using_responses_api
          parse_respond_response(response)
        else
          super(response)
        end
      end
    end
  end
end
