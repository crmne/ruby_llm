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

# A delightful Ruby interface to modern AI language models.
module RubyLLM
  class << self
    def deprecator
      @deprecator ||= Deprecator.new
    end

    def instrument(...)
      Instrumentation.instrument(...)
    end

    def context
      context_config = config.dup
      yield context_config if block_given?
      Context.new(context_config)
    end

    def chat(...)
      Chat.new(...)
    end

    def batch(chats_or_id, provider: nil, context: nil)
      if chats_or_id.is_a?(String)
        Batch.find(chats_or_id, provider:, context:)
      else
        Batch.submit(chats_or_id)
      end
    end

    def embed(...)
      Embedding.embed(...)
    end

    def moderate(...)
      Moderation.moderate(...)
    end

    def paint(...)
      Image.paint(...)
    end

    def transcribe(...)
      Transcription.transcribe(...)
    end

    def models
      Models.instance
    end

    def providers
      Provider.providers.values
    end

    def configure
      yield config
    end

    def config
      @config ||= Configuration.new
    end

    def logger
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
RubyLLM::Provider.register :requesty, RubyLLM::Providers::Requesty
RubyLLM::Provider.register :perplexity, RubyLLM::Providers::Perplexity
RubyLLM::Provider.register :vertexai, RubyLLM::Providers::VertexAI
RubyLLM::Provider.register :xai, RubyLLM::Providers::XAI

require 'ruby_llm/railtie' if defined?(Rails::Railtie)
