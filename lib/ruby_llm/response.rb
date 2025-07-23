# frozen_string_literal: true

module RubyLLM
  # Represents a response from an AI model. Handles tool integration.
  #
  # Example:
  #   response = RubyLLM.response
  #   response.ask "What's the best way to learn Ruby?"
  class Response < Conversation
    def get_response(&)
      @provider.respond(
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
