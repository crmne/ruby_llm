# frozen_string_literal: true

module RubyLLM
  # Represents a conversation with an AI model. Handles message history,
  # streaming responses, and tool integration with a simple, conversational API.
  #
  # Example:
  #   chat = RubyLLM.chat
  #   chat.ask "What's the best way to learn Ruby?"
  #   chat.ask "Can you elaborate on that?"
  class Chat < Conversation
    def get_response(&)
      @provider.complete(
        messages,
        tools: @tools,
        temperature: @temperature,
        model: @model.id,
        connection: @connection,
        params: @params,
        &
      )
    end
  end
end
