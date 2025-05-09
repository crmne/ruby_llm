# frozen_string_literal: true

module RubyLLM
  # Provides utility functions for data manipulation within the RubyLLM library
  module Utils
    module_function

    def deep_symbolize_keys(value)
      case value
      when Hash
        value.each_with_object({}) do |(k, v), new_hash|
          new_key = k.is_a?(String) ? k.to_sym : k
          new_hash[new_key] = deep_symbolize_keys(v)
        end
      when Array
        value.map { |v| deep_symbolize_keys(v) }
      else
        value
      end
    end
  end
end
