# frozen_string_literal: true

module RubyLLM
  # A Context is an isolated configuration scope. It offers the same entry
  # points as the top-level RubyLLM module but reads from its own
  # Configuration copy instead of the global one, which suits multi-tenant
  # applications and per-request overrides.
  #
  # Contexts are created with RubyLLM.context:
  #
  #   ctx = RubyLLM.context do |config|
  #     config.openai_api_key = ENV['ANOTHER_PROVIDER_KEY']
  #     config.request_timeout = 180
  #   end
  #
  #   chat = ctx.chat(model: 'gpt-5.4')
  #   chat.ask "Process this with another provider..."
  #
  # The global configuration is left untouched.
  #
  # Batch submission uses each chat's own configuration (a chat carries
  # the config it was built with), so there is no context entry point for
  # it. To look up an existing batch, where no chats carry the config,
  # pass a context to Batch.find:
  #
  #   RubyLLM::Batch.find(id, provider: :anthropic, context: ctx)
  #
  class Context
    attr_reader :config # :nodoc:

    def initialize(config) # :nodoc:
      @config = config
    end

    # Creates a new Chat that uses this context's configuration.
    # Accepts the same arguments as RubyLLM.chat.
    def chat(*args, **kwargs, &)
      Chat.new(*args, **kwargs, context: self, &)
    end

    # Generates embeddings using this context's configuration.
    # Accepts the same arguments as RubyLLM.embed.
    def embed(*args, **kwargs, &)
      Embedding.embed(*args, **kwargs, context: self, &)
    end

    # Generates an image using this context's configuration.
    # Accepts the same arguments as RubyLLM.paint.
    def paint(*args, **kwargs, &)
      Image.paint(*args, **kwargs, context: self, &)
    end

    # Runs content moderation using this context's configuration.
    # Accepts the same arguments as RubyLLM.moderate.
    def moderate(*args, **kwargs, &)
      Moderation.moderate(*args, **kwargs, context: self, &)
    end

    # Generates speech audio using this context's configuration.
    # Accepts the same arguments as RubyLLM.speak.
    def speak(*args, **kwargs, &)
      Speech.speak(*args, **kwargs, context: self, &)
    end

    # Transcribes audio using this context's configuration.
    # Accepts the same arguments as RubyLLM.transcribe.
    def transcribe(*args, **kwargs, &)
      Transcription.transcribe(*args, **kwargs, context: self, &)
    end

    # Uploads a file to a provider using this context's configuration.
    # Accepts the same arguments as RubyLLM.upload.
    def upload(*args, **kwargs, &)
      UploadedFile.upload(*args, **kwargs, context: self, &)
    end

    # Downloads a provider-hosted file using this context's configuration.
    # Accepts the same arguments as RubyLLM.download.
    def download(*args, **kwargs, &)
      UploadedFile.download(*args, **kwargs, context: self, &)
    end
  end
end
