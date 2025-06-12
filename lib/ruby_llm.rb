# frozen_string_literal: true

require 'base64'
require 'event_stream_parser'
require 'faraday'
require 'faraday/retry'
require 'json'
require 'logger'
require 'securerandom'
require 'zeitwerk'

loader = Zeitwerk::Loader.for_gem
loader.inflector.inflect(
  'ruby_llm' => 'RubyLLM',
  'llm' => 'LLM',
  'openai' => 'OpenAI',
  'api' => 'API',
  'deepseek' => 'DeepSeek',
  'bedrock' => 'Bedrock',
  'openrouter' => 'OpenRouter',
  'pdf' => 'PDF'
)
loader.ignore("#{__dir__}/tasks")
loader.ignore("#{__dir__}/ruby_llm/railtie")
loader.ignore("#{__dir__}/ruby_llm/active_record")
loader.setup

# A delightful Ruby interface to modern AI language models.
# Provides a unified way to interact with models from OpenAI, Anthropic and others
# with a focus on developer happiness and convention over configuration.
module RubyLLM
  class Error < StandardError; end

  class << self
    def context
      context_config = config.dup
      yield context_config if block_given?
      Context.new(context_config)
    end

    def chat(...)
      Chat.new(...)
    end

    def ask(message = nil, **options, &)
      chat_options = options.slice(:model, :provider, :assume_model_exists, :context)
      @ask_chat = Chat.new(**chat_options)

      @ask_chat.with_tools(*options[:tools]) if options.key?(:tools)
      @ask_chat.with_temperature(options[:temperature]) if options.key?(:temperature)
      @ask_chat.with_instructions(options[:instructions]) if options.key?(:instructions)
      @ask_chat.with_context(options[:context]) if options.key?(:context)
      @ask_chat.on_new_message(&options[:on_new_message]) if options.key?(:on_new_message)
      @ask_chat.on_end_message(&options[:on_end_message]) if options.key?(:on_end_message)

      @ask_chat.ask(message, with: options[:with], &)
    end

    alias say ask

    def embed(...)
      Embedding.embed(...)
    end

    def paint(...)
      Image.paint(...)
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

RubyLLM::Provider.register :openai, RubyLLM::Providers::OpenAI
RubyLLM::Provider.register :anthropic, RubyLLM::Providers::Anthropic
RubyLLM::Provider.register :gemini, RubyLLM::Providers::Gemini
RubyLLM::Provider.register :deepseek, RubyLLM::Providers::DeepSeek
RubyLLM::Provider.register :bedrock, RubyLLM::Providers::Bedrock
RubyLLM::Provider.register :openrouter, RubyLLM::Providers::OpenRouter
RubyLLM::Provider.register :ollama, RubyLLM::Providers::Ollama

if defined?(Rails::Railtie)
  require 'ruby_llm/railtie'
  require 'ruby_llm/active_record/acts_as'
end
