# frozen_string_literal: true

require 'base64'
require 'event_stream_parser'
require 'faraday'
require 'faraday/multipart'
require 'faraday/retry'
require 'json'
require 'logger'
require 'marcel'
require 'schematist'
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
  'cli' => 'CLI',
  'deepseek' => 'DeepSeek',
  'elevenlabs' => 'ElevenLabs',
  'gpustack' => 'GPUStack',
  'llm' => 'LLM',
  'mistral' => 'Mistral',
  'ocr' => 'OCR',
  'openai' => 'OpenAI',
  'openrouter' => 'OpenRouter',
  'pdf' => 'PDF',
  'perplexity' => 'Perplexity',
  'ruby_llm' => 'RubyLLM',
  'vertexai' => 'VertexAI',
  'xai' => 'XAI'
)
loader.ignore("#{__dir__}/tasks")
loader.ignore("#{__dir__}/generators")
loader.ignore("#{__dir__}/ruby_llm/active_record")
loader.ignore("#{__dir__}/ruby_llm/railtie.rb")
loader.setup

# RubyLLM is an AI framework for Ruby and Rails. Build conversations and
# agents, generate media, process documents, and work with model providers
# through one Ruby API. The guides at https://rubyllm.com/next/ introduce
# each feature; this reference documents its classes, arguments, and results.
#
#   RubyLLM.configure do |config|
#     config.openai_api_key = ENV['OPENAI_API_KEY']
#   end
#
#   chat = RubyLLM.chat
#   chat.ask "What is the capital of France?"
#
# == Conversations, tools, and agents
#
# RubyLLM.chat returns a Chat that holds the conversation. Chat#ask accepts
# text and attachments, runs tools as needed, and returns a Message. Give
# it a block to receive Chunk objects as the response streams:
#
#   chat.ask("Summarize this report", with: "report.pdf") do |chunk|
#     print chunk.content
#   end
#
# Configure the request with chainable methods:
#
# - Chat#with_schema requests structured output; Message#parsed reads it.
# - Chat#with_thinking sets thinking effort, budget, or display preferences.
# - Chat#with_citations requests source citations, read through Message#citations.
# - Chat#with_fallbacks tries other models when a request fails.
# - Chat#with_caching enables prompt caching; Chat#cache_until_here marks
#   a reusable prefix. Chat#with_compaction manages long conversations.
#
# Subclass Tool and implement +execute+ to give the model an application
# action. Tool.requires_approval pauses execution for a human decision;
# Chat#approve and Chat#deny record it. Chat#with_server_tools enables
# provider-executed tools such as web search, code execution, and remote MCP.
# Their calls appear as ServerToolCall values, with Citation values for sources.
#
# Agent defines a reusable configuration with model, instructions, tools,
# schema, and runtime inputs. Chat#ask_later, Chat#generate, Chat#run_tools,
# and Chat#step expose the conversation loop for jobs and application logic.
#
# == Images, video, and speech
#
# Individual operations do not require a chat. Image, Video, and Speech
# results share +save(path)+ and +to_blob+:
#
#   RubyLLM.paint("A red panda coding Ruby, watercolor").save("panda.png")
#   RubyLLM.animate("A paper boat sailing down a gutter").save("boat.mp4")
#   RubyLLM.speak("Welcome to RubyLLM.").save("welcome.mp3")
#
# Image.paint accepts source images and masks for editing. Video.animate
# accepts reference media, video edits, and extensions on supported models.
# RubyLLM.animate waits for the clip; RubyLLM.animate_later returns a
# VideoJob that you can poll. Speech.speak also streams SpeechChunk objects
# while retaining the complete audio result.
#
# == Documents, audio, and retrieval
#
#   transcript = RubyLLM.transcribe("meeting.wav")
#   document = RubyLLM.ocr("report.pdf", pages: [0, 1])
#   embedding = RubyLLM.embed("Ruby is a programmer's best friend")
#
# Transcription provides text, timestamps, and speaker information when
# the model reports them; streaming yields TranscriptionChunk objects.
# OCR returns document pages and combined markdown. Embedding returns
# vectors for text or supported media, and RubyLLM.rerank returns a Rerank
# whose results order documents by relevance. SearchResults lets a Tool
# return source documents that the model can cite.
#
# RubyLLM.upload returns an UploadedFile for reuse across requests.
# RubyLLM.download returns a DownloadedFile with the same saving interface:
#
#   RubyLLM.download(file.id, provider: file.provider).save("report.pdf")
#
# == Tokenization, moderation, and research
#
# RubyLLM.count_tokens and Chat#count_tokens count a model request without
# generating a response. RubyLLM.tokenize returns plain-text token IDs and
# a count as a Tokenization, excluding chat formatting and attachments.
#
#   result = RubyLLM.tokenize("Hello Ruby", model: "grok-4.3", provider: :xai)
#   result.ids
#   result.count
#
# RubyLLM.moderate screens text and images, returning Moderation results
# with categories, scores, and +flagged?+. RubyLLM.research runs a hosted
# research task and returns its report as a Message; RubyLLM.research_later
# returns a ResearchJob for polling and cancellation. Hosted agent identities
# are selected separately from model IDs.
#
# == Batches, usage, and configuration
#
# RubyLLM.batch submits staged chats or EmbeddingRequest objects for
# provider-side processing. Batch exposes progress, results, token usage,
# and cost. RubyLLM.cache creates a managed CachedContent resource for
# reuse with Chat#with_caching.
#
# Tokens and Cost report usage and pricing. Chat totals include retries
# and attempts that produced no message. Provider-reported costs take
# precedence over estimates; unknown usage and prices remain +nil+.
# RubyLLM.workflow groups instrumentation from ordinary Ruby code into
# named Workflow steps.
#
# RubyLLM.configure sets global Configuration; RubyLLM.context creates
# isolated settings for a request or tenant. Models finds, filters, and
# describes the model catalog. Provider supplies endpoints, authentication,
# and protocol selection; Protocol implements request and response formats.
# Error subclasses normalize provider failures.
#
# == Rails integration
#
# ActiveRecord::ActsAs adds +acts_as_chat+ and +acts_as_message+ to your
# application's models. ActiveRecord::ChatMethods and
# ActiveRecord::MessageMethods provide the conversation API with persistence,
# Active Storage attachments, and support for Hotwire streaming and jobs.
# Approvals and cancellation survive requests and processes.
#
# Your application owns chats and messages; RubyLLM owns usage, tool calls,
# models, and batches. Agent can create and reload your chat records through
# Agent.chat_model. Individual operations also work directly in Rails
# services and jobs.
module RubyLLM
  class << self
    def deprecator # :nodoc:
      @deprecator ||= Support::Deprecator.new
    end

    def instrument(...) # :nodoc:
      Support::Instrumentation.instrument(...)
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
    # +model:+, +provider:+, +protocol:+, +assume_model_exists:+, and
    # +context:+. With no arguments, uses the configured default model.
    #
    #   chat = RubyLLM.chat
    #   chat.ask "What is the capital of France?"
    #
    #   chat = RubyLLM.chat(model: 'claude-sonnet-5')
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

    # Tokenizes plain text and returns a Tokenization with its token IDs
    # and count. Excludes chat formatting and billable generation usage.
    # See Tokenization.tokenize for options.
    def tokenize(...)
      Tokenization.tokenize(...)
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
    # An explicitly selected provider can use a configured moderation
    # resource without a model.
    #
    #   result = RubyLLM.moderate("Some user input text")
    #   result.flagged? # => false
    #
    def moderate(...)
      Moderation.moderate(...)
    end

    # Runs a hosted research task and returns its report as a Message.
    # Requires explicit +provider:+ and +agent:+. See ResearchJob.research.
    def research(...)
      ResearchJob.research(...)
    end

    # Submits a hosted research task and returns a ResearchJob immediately.
    # Requires explicit +provider:+ and +agent:+. See ResearchJob.research_later.
    def research_later(...)
      ResearchJob.research_later(...)
    end

    # Generates or edits an image and returns an Image, or an array when
    # the provider returns several images. Pass +with:+ for source images,
    # +mask:+ for a mask, and +count:+ for multiple results. See Image.paint.
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
    #   job.wait
    #   job.video.save("boat.mp4")
    #
    def animate_later(...)
      VideoJob.animate_later(...)
    end

    # Synthesizes speech from text and returns a Speech. Given a block,
    # yields SpeechChunk objects as audio arrives. Arguments are
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

    # Downloads a provider file and returns a DownloadedFile. Save it with
    # DownloadedFile#save or read its bytes with DownloadedFile#to_blob.
    # Arguments are forwarded to UploadedFile.download.
    #
    #   RubyLLM.download(file.id, provider: :openai).save("report.pdf")
    #
    def download(...)
      UploadedFile.download(...)
    end

    # Creates a provider-side prompt cache and returns a CachedContent
    # that chats can attach with Chat#with_caching. Arguments are
    # forwarded to CachedContent.create.
    #
    #   cache = RubyLLM.cache(big_document, model: 'gemini-3.7-flash', ttl: 3600)
    #   chat = RubyLLM.chat(model: 'gemini-3.7-flash').with_caching(id: cache)
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
    #   RubyLLM.models.refresh
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
RubyLLM::Provider.register :cohere, RubyLLM::Providers::Cohere
RubyLLM::Provider.register :deepgram, RubyLLM::Providers::Deepgram
RubyLLM::Provider.register :deepseek, RubyLLM::Providers::DeepSeek
RubyLLM::Provider.register :elevenlabs, RubyLLM::Providers::ElevenLabs
RubyLLM::Provider.register :gemini, RubyLLM::Providers::Gemini
RubyLLM::Provider.register :gpustack, RubyLLM::Providers::GPUStack
RubyLLM::Provider.register :mistral, RubyLLM::Providers::Mistral
RubyLLM::Provider.register :ollama, RubyLLM::Providers::Ollama
RubyLLM::Provider.register :ollama_cloud, RubyLLM::Providers::OllamaCloud
RubyLLM::Provider.register :openai, RubyLLM::Providers::OpenAI
RubyLLM::Provider.register :openrouter, RubyLLM::Providers::OpenRouter
RubyLLM::Provider.register :perplexity, RubyLLM::Providers::Perplexity
RubyLLM::Provider.register :vertexai, RubyLLM::Providers::VertexAI
RubyLLM::Provider.register :xai, RubyLLM::Providers::XAI

require 'ruby_llm/railtie' if defined?(Rails::Railtie)
