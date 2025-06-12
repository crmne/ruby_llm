# frozen_string_literal: true

module RubyLLM
  # Parameter object for LLM completion requests.
  # Encapsulates all the parameters needed for chat completion to avoid
  # long parameter lists and provide better maintainability.
  class CompletionParams
    attr_reader :messages, :tools, :temperature, :model, :connection, :cache_prompts, :stream

    def initialize(options = {})
      @messages = options[:messages]
      @tools = options[:tools]
      @temperature = options[:temperature]
      @model = options[:model]
      @connection = options[:connection]
      @cache_prompts = options[:cache_prompts] || { system: false, user: false, tools: false }
      @stream = options[:stream] || false
    end

    def streaming?
      @stream
    end
  end
end
