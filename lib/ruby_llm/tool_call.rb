# frozen_string_literal: true

module RubyLLM
  # Represents a function call from an AI model to a Tool.
  class ToolCall
    attr_reader :id, :name, :arguments
    attr_accessor :thought_signature

    def initialize(id:, name:, arguments: {}, thought_signature: nil)
      @id = id
      @name = name
      @arguments = arguments
      @thought_signature = thought_signature
    end

    def to_h
      {
        id: @id,
        name: @name,
        arguments: @arguments,
        thought_signature: @thought_signature
      }.compact
    end
  end
end
