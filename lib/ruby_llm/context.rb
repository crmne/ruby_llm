# frozen_string_literal: true

module RubyLLM
  # Holds per-call configs
  class Context
    attr_reader :config

    def initialize(config)
      @config = config
      @connections = {}
    end

    def chat(*, **, &)
      Chat.new(*, **, context: self, &)
    end

    def embed(*, **, &)
      Embedding.embed(*, **, context: self, &)
    end

    def paint(*, **, &)
      Image.paint(*, **, context: self, &)
    end

    def connection_for(provider_module)
      slug = provider_module.slug.to_sym
      @connections[slug] ||= Connection.new(provider_module, @config)
    end
  end
end
