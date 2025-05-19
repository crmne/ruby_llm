# frozen_string_literal: true

module RubyLLM
  # Provides utility functions for data manipulation within the RubyLLM library
  module Utils
    module_function

    def format_text_file_for_llm(text_file)
      "<file name='#{File.basename(text_file.source)}'>#{text_file.content}</file>"
    end

    def hash_get(hash, key)
      hash[key.to_sym] || hash[key.to_s]
    end

    def to_safe_array(item)
      case item
      when Array
        item
      when Hash
        [item]
      else
        Array(item)
      end
    end
  end
end
