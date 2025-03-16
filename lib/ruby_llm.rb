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
  'deepseek' => 'DeepSeek'
)
loader.setup

# A delightful Ruby interface to modern AI language models.
# Provides a unified way to interact with models from OpenAI, Anthropic and others
# with a focus on developer happiness and convention over configuration.
module RubyLLM
  class Error < StandardError; end

  class << self
    def chat(model: nil)
      Chat.new(model: model)
    end

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
      @logger ||= Logger.new(
        $stdout,
        progname: 'RubyLLM',
        level: ENV['RUBYLLM_DEBUG'] ? Logger::DEBUG : Logger::INFO
      )
    end

    def chunk(content, chunker: :character, **options)
      return [] if content.nil? || content.empty?

      chunker_class = Chunker.for(chunker)
      raise ArgumentError, "Unknown chunker type: #{chunker}" unless chunker_class

      # Filter options to only include those accepted by the chunker
      filtered_options = filter_chunker_options(chunker_class, options)

      chunker_instance = chunker_class.new(**filtered_options)
      result = chunker_instance.chunk(content)

      # If content is short enough to be a single chunk, just return it as is
      result.empty? ? [content] : result
    end

    private

    def filter_chunker_options(chunker_class, options)
      # Get the parameters the chunker's initialize method accepts
      parameters = chunker_class.instance_method(:initialize).parameters
      allowed_keys = parameters.map { |_, name| name if name != :options }.compact

      # Only keep options that the chunker accepts
      options.slice(*allowed_keys)
    end
  end
end

RubyLLM::Provider.register :openai, RubyLLM::Providers::OpenAI
RubyLLM::Provider.register :anthropic, RubyLLM::Providers::Anthropic
RubyLLM::Provider.register :gemini, RubyLLM::Providers::Gemini
RubyLLM::Provider.register :deepseek, RubyLLM::Providers::DeepSeek

if defined?(Rails::Railtie)
  require 'ruby_llm/railtie'
  require 'ruby_llm/active_record/acts_as'
end
