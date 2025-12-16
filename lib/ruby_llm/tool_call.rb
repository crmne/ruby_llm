# frozen_string_literal: true

module RubyLLM
  # Represents a function call from an AI model to a Tool.
  # @attr_reader thought_signature [String, nil] Gemini 3's encrypted reasoning context
  #   for preserving model state across multi-turn function calling conversations.
  #   See: https://ai.google.dev/gemini-api/docs/thought-signatures
  class ToolCall
    attr_reader :id, :name, :arguments, :thought_signature

    def initialize(id:, name:, arguments: {}, thought_signature: nil)
      @id = id
      @name = name
      @arguments = arguments
      @thought_signature = thought_signature
    end

    def to_h
      hash = {
        id: @id,
        name: @name,
        arguments: @arguments
      }
      hash[:thought_signature] = @thought_signature if @thought_signature
      hash
    end
  end
end
