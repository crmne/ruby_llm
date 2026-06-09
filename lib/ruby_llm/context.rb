# frozen_string_literal: true

module RubyLLM
  # Holds per-call configs
  class Context
    attr_reader :config

    def initialize(config)
      @config = config
    end

    def chat(*args, **kwargs, &)
      Chat.new(*args, **kwargs, context: self, &)
    end

    def embed(*args, **kwargs, &)
      Embedding.embed(*args, **kwargs, context: self, &)
    end

    def paint(*args, **kwargs, &)
      Image.paint(*args, **kwargs, context: self, &)
    end

    def moderate(*args, **kwargs, &)
      Moderation.moderate(*args, **kwargs, context: self, &)
    end

    def transcribe(*args, **kwargs, &)
      Transcription.transcribe(*args, **kwargs, context: self, &)
    end
  end
end
