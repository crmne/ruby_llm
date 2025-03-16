# frozen_string_literal: true

module RubyLLM
  # Base class for content chunking strategies
  class Chunker
    def self.chunk(content, chunker: :character, **options)
      chunker_class = Chunker.for(chunker)
      raise ArgumentError, "Unknown chunker type: #{chunker}" unless chunker_class

      chunker_instance = chunker_class.new(**options)
      chunker_instance.chunk(content)
    end

    def self.for(type)
      case type
      when :character
        Chunkers::CharacterChunker
      when :paragraph
        Chunkers::ParagraphChunker
      when :sentence
        Chunkers::SentenceChunker
      when :markdown
        Chunkers::MarkdownChunker
      when :semantic
        Chunkers::SemanticChunker
      when :recursive
        Chunkers::RecursiveChunker
      else
        raise ArgumentError, "Unknown chunker type: #{type}"
      end
    end

    def initialize(**options)
      @options = options
    end

    def chunk(content)
      raise NotImplementedError, "#{self.class} must implement #chunk"
    end
  end
end
