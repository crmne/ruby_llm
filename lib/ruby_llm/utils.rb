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

    def to_time(value)
      return unless value

      value.is_a?(Time) ? value : Time.parse(value.to_s)
    end

    def to_date(value)
      return unless value

      value.is_a?(Date) ? value : Date.parse(value.to_s)
    end

    def deep_merge(params, payload)
      params.merge(payload) do |_key, params_value, payload_value|
        if params_value.is_a?(Hash) && payload_value.is_a?(Hash)
          deep_merge(params_value, payload_value)
        else
          payload_value
        end
      end
    end
  end
end
