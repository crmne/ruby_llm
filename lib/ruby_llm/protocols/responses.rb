# frozen_string_literal: true

module RubyLLM
  module Protocols
    # The OpenAI Responses API. Overrides the chat surface of Chat Completions;
    # embeddings, images, moderation, and transcription are inherited. Runs
    # stateless (store: false) and replays encrypted reasoning so multi-turn
    # tool calls work without server-side state.
    class Responses < ChatCompletions
      include Responses::Chat
      include Responses::Media
      include Responses::Streaming
      include Responses::Tools

      # Reasoning models reject the temperature parameter on this API.
      def maybe_normalize_temperature(temperature, model)
        return super unless reasoning_model?(model.id)

        unless temperature.nil?
          RubyLLM.logger.debug { "Model #{model.id} does not accept temperature on the Responses API, removing" }
        end
        nil
      end
    end
  end
end
