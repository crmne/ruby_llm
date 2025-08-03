# frozen_string_literal: true

module RubyLLM
  module Providers
    module Mistral
      # Chat methods for Mistral API
      module Chat
        module_function

        def format_role(role)
          # Mistral doesn't use the new OpenAI convention for system prompts
          role.to_s
        end

        # rubocop:disable Metrics/ParameterLists
        def render_payload(messages, tools:, temperature:, model:, stream: false, schema: nil)
          payload = super
          # Mistral doesn't support stream_options
          payload.delete(:stream_options)
          payload
        end
        # rubocop:enable Metrics/ParameterLists
      end
    end
  end
end
