# frozen_string_literal: true

module RubyLLM
  # Provides utility functions for data manipulation within the RubyLLM library
  module Utils
    module_function

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

    def safe_constantize(name)
      parts = name.to_s.split('::').reject(&:empty?)
      return if parts.empty?

      namespace = Object
      until parts.empty?
        const_name = parts.shift
        return unless namespace.const_defined?(const_name, false)

        namespace = namespace.const_get(const_name, false)
      end
      namespace
    rescue NameError
      nil
    end

    def parse_iso_date_prefix(value)
      return value if value.is_a?(Date)

      date = value.to_s.strip
      return if date.empty?

      case date
      when /\A\d{4}-\d{2}-\d{2}\z/
        Date.iso8601(date)
      when /\A\d{4}-\d{2}\z/
        Date.iso8601("#{date}-01")
      when /\A\d{4}\z/
        Date.iso8601("#{date}-01-01")
      end
    rescue ArgumentError
      nil
    end

    def iso_date_prefix_to_utc_midnight_string(value)
      date = parse_iso_date_prefix(value)
      "#{date.strftime('%Y-%m-%d')} 00:00:00 UTC" if date
    end

    def deep_merge(original, overrides)
      original.merge(overrides) do |_key, original_value, overrides_value|
        if original_value.is_a?(Hash) && overrides_value.is_a?(Hash)
          deep_merge(original_value, overrides_value)
        else
          overrides_value
        end
      end
    end

    def deep_dup(value)
      case value
      when Hash
        value.each_with_object({}) do |(key, val), duped|
          duped[deep_dup(key)] = deep_dup(val)
        end
      when Array
        value.map { |item| deep_dup(item) }
      else
        begin
          value.dup
        rescue TypeError
          value
        end
      end
    end

    def deep_stringify_keys(value)
      case value
      when Hash
        value.each_with_object({}) do |(key, val), result|
          result[key.to_s] = deep_stringify_keys(val)
        end
      when Array
        value.map { |item| deep_stringify_keys(item) }
      when Symbol
        value.to_s
      else
        value
      end
    end

    def deep_symbolize_keys(value)
      case value
      when Hash
        value.each_with_object({}) do |(key, val), result|
          symbolized_key = key.respond_to?(:to_sym) ? key.to_sym : key
          result[symbolized_key] = deep_symbolize_keys(val)
        end
      when Array
        value.map { |item| deep_symbolize_keys(item) }
      else
        value
      end
    end
  end
end
