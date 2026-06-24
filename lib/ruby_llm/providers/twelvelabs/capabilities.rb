# frozen_string_literal: true

module RubyLLM
  module Providers
    class TwelveLabs
      # Provider-level capability checks for TwelveLabs models.
      #
      # TwelveLabs models are not listed in the models.dev registry, so the
      # provider assumes models exist and falls back to these defaults.
      module Capabilities
        module_function

        # Marengo returns a fixed 512-dimensional embedding vector.
        EMBEDDING_DIMENSIONS = 512

        def context_window_for(_model_id)
          nil
        end

        def max_tokens_for(_model_id)
          nil
        end

        def supports_vision?(_model_id)
          true
        end

        def pricing_for(_model_id)
          {}
        end
      end
    end
  end
end
