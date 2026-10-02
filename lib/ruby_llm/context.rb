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
  #     config.openai_api_key = ENV.fetch('TENANT_OPENAI_API_KEY')
  #     config.request_timeout = 180
  #   end
  #
  #   ctx.chat.ask "Explain Ruby blocks."
  #   ctx.paint("A paper boat in the rain").save("boat.png")
  #   ctx.transcribe("meeting.wav").text
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
    def chat(*, **, &)
      Chat.new(*, **, context: self, &)
    end

    # Counts tokens using this context's configuration.
    # Accepts the same arguments as RubyLLM.count_tokens.
    def count_tokens(text, model: nil, provider: nil)
      chat(model:, provider:).count_tokens(text)
    end

    # Tokenizes plain text using this context's configuration.
    # Accepts the same arguments as RubyLLM.tokenize.
    def tokenize(*, **)
      Tokenization.tokenize(*, **, context: self)
    end

    # Runs a named workflow using this context's instrumenter. Accepts the same
    # arguments as RubyLLM.workflow.
    def workflow(name, id: nil, metadata: nil, &)
      Workflow.new(name, id:, metadata:, config: config).run(&)
    end

    # Generates embeddings using this context's configuration.
    # Accepts the same arguments as RubyLLM.embed.
    def embed(*, **, &)
      Embedding.embed(*, **, context: self, &)
    end

    # Stages an embedding request using this context's configuration.
    # Accepts the same arguments as RubyLLM.embed_later.
    def embed_later(text, model: nil, provider: nil, dimensions: nil)
      EmbeddingRequest.new(text, model:, provider:, dimensions:, context: self)
    end

    # Generates an image using this context's configuration.
    # Accepts the same arguments as RubyLLM.paint.
    def paint(*, **, &)
      Image.paint(*, **, context: self, &)
    end

    # Generates a video using this context's configuration, blocking
    # until it is ready. Accepts the same arguments as RubyLLM.animate.
    def animate(*, **, &)
      Video.animate(*, **, context: self, &)
    end

    # Submits a video generation job using this context's configuration.
    # Accepts the same arguments as RubyLLM.animate_later.
    def animate_later(*, **, &)
      VideoJob.animate_later(*, **, context: self, &)
    end

    # Runs content moderation using this context's configuration.
    # Accepts the same arguments as RubyLLM.moderate.
    def moderate(*, **, &)
      Moderation.moderate(*, **, context: self, &)
    end

    # Judges text, structured data, or images using this context's configuration.
    # Accepts the same arguments as RubyLLM.judge.
    def judge(*, **, &)
      Judge.judge(*, **, context: self, &)
    end

    # Runs hosted research using this context's configuration.
    # Accepts the same arguments as RubyLLM.research.
    def research(*, **)
      ResearchJob.research(*, **, context: self)
    end

    # Submits hosted research using this context's configuration.
    # Accepts the same arguments as RubyLLM.research_later.
    def research_later(*, **)
      ResearchJob.research_later(*, **, context: self)
    end

    # Generates speech audio using this context's configuration. Given a
    # block, yields SpeechChunk objects and returns the complete Speech.
    # Accepts the same arguments as RubyLLM.speak.
    def speak(*, **, &)
      Speech.speak(*, **, context: self, &)
    end

    # Transcribes audio using this context's configuration.
    # Accepts the same arguments as RubyLLM.transcribe.
    def transcribe(*, **, &)
      Transcription.transcribe(*, **, context: self, &)
    end

    # Extracts document text using this context's configuration.
    # Accepts the same arguments as RubyLLM.ocr.
    def ocr(*, **, &)
      OCR.ocr(*, **, context: self, &)
    end

    # Ranks documents using this context's configuration.
    # Accepts the same arguments as RubyLLM.rerank.
    def rerank(*, **, &)
      Rerank.rerank(*, **, context: self, &)
    end

    # Uploads a file to a provider using this context's configuration.
    # Accepts the same arguments as RubyLLM.upload.
    def upload(*, **, &)
      UploadedFile.upload(*, **, context: self, &)
    end

    # Downloads a provider-hosted file using this context's configuration.
    # Accepts the same arguments as RubyLLM.download.
    def download(*, **, &)
      UploadedFile.download(*, **, context: self, &)
    end

    # Creates a provider-side prompt cache using this context's
    # configuration. Accepts the same arguments as RubyLLM.cache.
    def cache(*, **, &)
      CachedContent.create(*, **, context: self, &)
    end

    # Connects to an MCP server using this context's configuration, so its
    # connection settings apply to the server's requests and to its OAuth
    # requests. Accepts the same arguments as RubyLLM.mcp.
    def mcp(...)
      MCP.define(...).new(context: self)
    end
  end
end
