# frozen_string_literal: true

module RubyLLM
  # Provides utility functions for data manipulation within the RubyLLM library
  module Utils
    module_function

    def format_text_file_for_llm(text_file)
      "<file name='#{text_file.filename}' mime_type='#{text_file.mime_type}'>#{text_file.content}</file>"
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

    def deep_merge(hash1, hash2)
      hash1.merge(hash2) do |_key, value1, value2|
        if value1.is_a?(Hash) && value2.is_a?(Hash)
          deep_merge(value1, value2)
        else
          value2
        end
      end
    end
  end
end
