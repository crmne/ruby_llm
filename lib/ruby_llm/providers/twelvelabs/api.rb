# frozen_string_literal: true

module RubyLLM
  module Providers
    class TwelveLabs
      # TwelveLabs' embedding API protocol (Marengo).
      #
      # Only the embedding surface is implemented; chat/completion is not part
      # of the TwelveLabs API. Models are assumed to exist (see the provider's
      # `assume_models_exist?`), so `list_models` returns an empty set rather
      # than calling a non-existent listing endpoint.
      class API < Protocol
        include TwelveLabs::Embeddings

        def list_models
          []
        end
      end
    end
  end
end
