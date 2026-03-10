# frozen_string_literal: true

module RubyLLM
  module Providers
    class Novita
      # Chat methods of the Novita API integration
      module Chat
        module_function

        # Render the chat completion payload for Novita API
        def render_payload(messages, tools:, temperature:, model:, stream: false, schema: nil,
                           thinking: nil, tool_prefs: nil)
          payload = OpenAI::Chat.render_payload(messages, tools:, temperature:,
                                                model:, stream:, schema:, thinking:, tool_prefs:)

          payload
        end

        # Parse the completion response from Novita API
        def parse_completion_response(response)
          OpenAI::Chat.parse_completion_response(response)
        end

        # Format messages for Novita API
        def format_messages(messages)
          OpenAI::Chat.format_messages(messages)
        end

        # Format the role in messages
        def format_role(role)
          OpenAI::Chat.format_role(role)
        end
      end
    end
  end
end
