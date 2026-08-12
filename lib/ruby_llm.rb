# frozen_string_literal: true

require 'base64'
require 'event_stream_parser'
require 'faraday'
require 'faraday/multipart'
require 'faraday/retry'
require 'json'
require 'logger'
require 'marcel'
require 'securerandom'
require 'date'
require 'time'
require 'zeitwerk'
require 'ruby_llm/error'

loader = Zeitwerk::Loader.for_gem
loader.inflector.inflect(
  'azure' => 'Azure',
  'UI' => 'UI',
  'api' => 'API',
  'bedrock' => 'Bedrock',
  'deepseek' => 'DeepSeek',
  'gpustack' => 'GPUStack',
  'llm' => 'LLM',
  'mistral' => 'Mistral',
  'ocr' => 'OCR',
  'openai' => 'OpenAI',
  'openrouter' => 'OpenRouter',
  'pdf' => 'PDF',
  'perplexity' => 'Perplexity',
  'provider_generator_cli' => 'ProviderGeneratorCLI',
  'ruby_llm' => 'RubyLLM',
  'vertexai' => 'VertexAI',
  'xai' => 'XAI'
)
loader.ignore("#{__dir__}/tasks")
loader.ignore("#{__dir__}/generators")
loader.ignore("#{__dir__}/ruby_llm/active_record")
loader.ignore("#{__dir__}/ruby_llm/railtie.rb")
loader.setup

# RubyLLM is a Ruby interface to large language models. One API for
# OpenAI, Anthropic, Google, AWS, and every other major provider. These
# pages document every public class and method; the guides at
# https://rubyllm.com show how to build things with them.
#
#   RubyLLM.configure do |config|
#     config.openai_api_key = ENV['OPENAI_API_KEY']
#   end
#
#   chat = RubyLLM.chat
#   chat.ask "What is the capital of France?"
#
# == Start here
#
# Chat is the heart of the library. ::chat starts a conversation, and
# Chat#ask sends a message and returns a Message. Everything else builds
# on this: attachments, streaming, structured output, and tool calls.
#
# Tool gives the model abilities. Subclass it, declare parameters,
# implement +execute+, and pass it to Chat#with_tools. Agent packages a
# configured chat (model, instructions, tools, schema) into a reusable
# class. Internally, accounting follows provider attempts rather than the
# transcript so retries and cancellations remain visible in costs.
#
# == Beyond chat
#
# - ::paint generates images (Image)
# - ::animate generates videos (Video)
# - ::embed turns text into vectors (Embedding)
# - ::transcribe converts audio to text (Transcription)
# - ::ocr extracts text from documents (OCR)
# - ::speak converts text to audio (Speech)
# - ::moderate screens content (Moderation)
# - ::batch processes many chats at lower cost (Batch)
# - ::upload manages provider files (UploadedFile)
# - ::cache stores a reusable prompt prefix with a provider (CachedContent)
#
# == Rails
#
# +acts_as_chat+ and +acts_as_message+ keep application-owned conversation
# records while RubyLLM privately persists usage, tool calls, models, and
# batches. See ActiveRecord::ActsAs.
#
# == Configuration and models
#
# Configuration holds global settings, set through ::configure. Context
# scopes overrides to a group of calls. Models finds, filters, and
# prices every known model.
#
# Provider errors raise subclasses of Error, one per HTTP status family.
module RubyLLM
  class << self
    def deprecator # :nodoc:
      @deprecator ||= Deprecator.new
    end

    def instrument(...) # :nodoc:
      Instrumentation.instrument(...)
    end

    # Returns a Context, an isolated set of configuration overrides.
    # Duplicates the global configuration and yields the copy if a block is
    # given. The context offers the same entry points as the top-level
    # RubyLLM module (Context#chat, Context#embed, and so on) using its
    # own configuration.
    #
    #   context = RubyLLM.context do |config|
    #     config.openai_api_key = 'sk-customer-specific-key'
    #   end
    #   context.chat.ask "Hello"
    #
    def context
      context_config = config.dup
      yield context_config if block_given?
      Context.new(context_config)
    end

    # Runs ordinary Ruby code as a named, instrumented workflow. Every RubyLLM
    # event emitted inside the block includes the workflow ID and name. Wrap
    # meaningful regions with Workflow#step to add step correlation.
    #
    #   RubyLLM.workflow("Write article", id: "article-42") do |workflow|
    #     notes = workflow.step("Research") { researcher.ask(topic).content }
    #     workflow.step("Draft") { writer.ask(notes).content }
    #   end
    #
    # If +id:+ is omitted, RubyLLM generates one. Pass +metadata:+ to attach
    # application data to every nested event as +workflow_metadata+. Workflows
    # may nest; an inner workflow keeps its own identity and records its
    # parent as +workflow_parent_id+. The block's return value is returned
    # unchanged.
    def workflow(name, id: nil, metadata: nil, &)
      Workflow.new(name, id:, metadata:, config: config).run(&)
    end

    # Creates a Chat conversation. Arguments are forwarded to Chat.new:
    # +model:+, +provider:+, +assume_model_exists:+, and +context:+. With
    # no arguments, uses the configured default model.
    #
    #   chat = RubyLLM.chat
    #   chat.ask "What is the capital of France?"
    #
    #   chat = RubyLLM.chat(model: 'claude-sonnet-4-5')
    #
    def chat(...)
      Chat.new(...)
    end

    # Counts the tokens +text+ would consume as a single user message,
    # without requesting a completion. Builds a minimal Chat and delegates
    # to Chat#count_tokens. Returns an Integer.
    #
    #   RubyLLM.count_tokens("What is the capital of France?", model: 'claude-haiku-4-5')
    #
    def count_tokens(text, model: nil, provider: nil)
      chat(model: model, provider: provider).count_tokens(text)
    end

    # Submits requests staged with Chat#ask_later or ::embed_later as a
    # provider-side batch and returns a Batch. A batch takes chats or
    # embedding requests, not both. Look up an existing batch with
    # Batch.find.
    #
    #   chats = documents.map do |doc|
    #     RubyLLM.chat(model: 'claude-haiku-4-5').ask_later(doc.text)
    #   end
    #   batch = RubyLLM.batch(chats)
    #
    def batch(chats)
      Batch.submit(chats)
    end

    # Generates a vector embedding for a text, or one embedding per element
    # when given an array of strings. Returns an Embedding. Arguments are
    # forwarded to Embedding.embed.
    #
    #   embedding = RubyLLM.embed("Ruby is a programmer's best friend")
    #   embedding.vectors # => [0.018, -0.027, ...]
    #
    def embed(...)
      Embedding.embed(...)
    end

    # Stages a text for embedding without contacting the provider, and
    # returns an EmbeddingRequest. Submit an array of staged requests as a
    # provider-side batch with ::batch; once the batch completes, each
    # request's EmbeddingRequest#result holds its Embedding.
    #
    #   requests = texts.map { |text| RubyLLM.embed_later(text) }
    #   batch = RubyLLM.batch(requests)
    #
    def embed_later(text, model: nil, provider: nil, dimensions: nil)
      EmbeddingRequest.new(text, model:, provider:, dimensions:)
    end

    # Checks text or image attachments against the provider's moderation model and returns a
    # Moderation result. Arguments are forwarded to Moderation.moderate.
    #
    #   result = RubyLLM.moderate("Some user input text")
    #   result.flagged? # => false
    #
    def moderate(...)
      Moderation.moderate(...)
    end

    # Generates an image from a text prompt and returns an Image. Arguments
    # are forwarded to Image.paint.
    #
    #   image = RubyLLM.paint("a sunset over mountains in watercolor style")
    #   image.save("sunset.png")
    #
    def paint(...)
      Image.paint(...)
    end

    # Generates a video from a text prompt, blocks until the provider
    # finishes rendering it, and returns a Video. Arguments are forwarded
    # to Video.animate.
    #
    #   video = RubyLLM.animate("a paper boat sailing down a rainy gutter")
    #   video.save("boat.mp4")
    #
    def animate(...)
      Video.animate(...)
    end

    # Submits a video generation job and returns a VideoJob immediately,
    # without waiting for the result. Arguments are forwarded to
    # VideoJob.animate_later.
    #
    #   job = RubyLLM.animate_later("a paper boat sailing down a gutter")
    #   job.refresh! until job.done?
    #   job.video.save("boat.mp4")
    #
    def animate_later(...)
      VideoJob.animate_later(...)
    end

    # Synthesizes speech from text and returns a Speech. Arguments are
    # forwarded to Speech.speak.
    #
    #   speech = RubyLLM.speak "Hello, welcome to RubyLLM!"
    #   speech.save("welcome.mp3")
    #
    def speak(...)
      Speech.speak(...)
    end

    # Transcribes an audio file and returns a Transcription. Arguments are
    # forwarded to Transcription.transcribe. Given a block, the transcript
    # streams as TranscriptionChunk objects.
    #
    #   transcription = RubyLLM.transcribe("meeting.wav")
    #   transcription.text
    #
    #   RubyLLM.transcribe("meeting.wav", model: "gpt-4o-transcribe") do |chunk|
    #     print chunk.delta
    #   end
    #
    def transcribe(...)
      Transcription.transcribe(...)
    end

    # Extracts the text of a document or image and returns an OCR result.
    # Arguments are forwarded to OCR.ocr.
    #
    #   ocr = RubyLLM.ocr("contract.pdf")
    #   ocr.markdown
    #
    def ocr(...)
      OCR.ocr(...)
    end

    # Ranks documents by relevance to a query on providers with a rerank
    # endpoint. Arguments are forwarded to Rerank.rerank.
    #
    #   rerank = RubyLLM.rerank("what is ruby", docs,
    #                           model: "voyageai/rerank-2.5-lite", provider: :openrouter)
    #   rerank.results.first.document
    #
    def rerank(...)
      Rerank.rerank(...)
    end

    # Uploads a file to a provider and returns an UploadedFile that can be
    # reused across chats. Arguments are forwarded to UploadedFile.upload.
    #
    #   file = RubyLLM.upload("document.pdf", provider: :anthropic)
    #   chat.ask "Summarize this document", with: file
    #
    def upload(...)
      UploadedFile.upload(...)
    end

    # Downloads the content of a provider-managed file. Arguments are
    # forwarded to UploadedFile.download.
    #
    #   content = RubyLLM.download(file.id)
    #
    def download(...)
      UploadedFile.download(...)
    end

    # Creates a provider-side prompt cache and returns a CachedContent
    # that chats can attach with Chat#with_caching. Arguments are
    # forwarded to CachedContent.create.
    #
    #   cache = RubyLLM.cache(big_document, model: 'gemini-2.5-flash', ttl: 3600)
    #   chat = RubyLLM.chat(model: 'gemini-2.5-flash').with_caching(id: cache)
    #
    def cache(...)
      CachedContent.create(...)
    end

    # Renders the ERB prompt template +name+ and returns the result as a
    # String. The name resolves to a <tt>.txt.erb</tt> file under
    # app/prompts. Keyword arguments become locals in the template.
    #
    #   instructions = RubyLLM.render_prompt(
    #     "support/instructions",
    #     product_name: "BillingHub"
    #   )
    #   chat.with_instructions(instructions)
    #
    # Raises PromptNotFoundError if the template file does not exist.
    def render_prompt(name, **locals)
      Prompt.render(name, **locals)
    end

    # Returns the Models registry, used to browse, find, and refresh model
    # metadata.
    #
    #   RubyLLM.models.find("claude-haiku-4-5")
    #   RubyLLM.models.refresh!
    #
    def models
      Models.instance
    end

    # Returns the registered provider classes.
    #
    #   RubyLLM.providers.map(&:slug)
    #   # => ["anthropic", "azure", "bedrock", ...]
    #
    def providers
      Provider.providers.values
    end

    # Yields the global configuration for block-style setup. Call this once
    # at startup to set API keys and defaults.
    #
    #   RubyLLM.configure do |config|
    #     config.openai_api_key = ENV['OPENAI_API_KEY']
    #   end
    #
    def configure
      yield config
    end

    # Returns the global Configuration instance.
    def config
      @config ||= Configuration.new
    end

    def logger # :nodoc:
      @logger ||= config.logger || Logger.new(
        config.log_file,
        progname: 'RubyLLM',
        level: config.log_level
      )
    end
  end
end

RubyLLM::Provider.register :anthropic, RubyLLM::Providers::Anthropic
RubyLLM::Provider.register :azure, RubyLLM::Providers::Azure
RubyLLM::Provider.register :bedrock, RubyLLM::Providers::Bedrock
RubyLLM::Provider.register :deepseek, RubyLLM::Providers::DeepSeek
RubyLLM::Provider.register :gemini, RubyLLM::Providers::Gemini
RubyLLM::Provider.register :gpustack, RubyLLM::Providers::GPUStack
RubyLLM::Provider.register :mistral, RubyLLM::Providers::Mistral
RubyLLM::Provider.register :ollama, RubyLLM::Providers::Ollama
RubyLLM::Provider.register :openai, RubyLLM::Providers::OpenAI
RubyLLM::Provider.register :openrouter, RubyLLM::Providers::OpenRouter
RubyLLM::Provider.register :perplexity, RubyLLM::Providers::Perplexity
RubyLLM::Provider.register :vertexai, RubyLLM::Providers::VertexAI
RubyLLM::Provider.register :xai, RubyLLM::Providers::XAI

require 'ruby_llm/railtie' if defined?(Rails::Railtie)
