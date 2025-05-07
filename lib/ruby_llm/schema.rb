# frozen_string_literal: true

module RubyLLM
  ##
  # Schema class for defining the structure of data objects.
  # Wraps the #Hash class
  # @see #Hash
  class Schema
    delegate_missing_to :@schema

    ##
    # @param schema [Hash]
    def initialize(schema = {})
      @schema = deep_transform_keys_in_object(schema.to_h.dup, &:to_sym)
    end

    def [](key)
      @schema[key.to_sym]
    end

    def []=(key, new_value)
      @schema[key.to_sym] = deep_transform_keys_in_object(new_value, &:to_sym)
    end

    # Adds the new_value into the new_key key for every sub-schema that is of type: :object
    # @param new_key [Symbol] The key to add to each object type.
    # @param new_value [Boolean, String] The value to assign to the new key.
    def add_to_each_object_type!(new_key, new_value)
      add_to_each_object_type(new_key, new_value, @schema)
    end

    # @return [Boolean]
    def present?
      @schema.present? && @schema[:type].present?
    end

    private

    def add_to_each_object_type(new_key, new_value, schema)
      return schema unless schema.is_a?(Hash)

      if schema[:type].to_s == :object.to_s
        add_to_object_type(new_key, new_value, schema)
      elsif schema[:type].to_s == :array.to_s && schema[:items]
        schema[:items] = add_to_each_object_type(new_key, new_value, schema[:items])
      end

      schema
    end

    def add_to_object_type(new_key, new_value, schema)
      if schema[new_key.to_sym].nil?
        schema[new_key.to_sym] = new_value.is_a?(Proc) ? new_value.call(schema) : new_value
      end

      schema[:properties]&.transform_values! { |value| add_to_each_object_type(new_key, new_value, value) }
    end

    ##
    # Recursively transforms keys in a hash or array to symbols.
    # Borrowed from ActiveSupport's Hash#deep_transform_keys
    # @param object [Object] The object to transform.
    # @param block [Proc] The block to apply to each key.
    # @return [Object] The transformed object.
    def deep_transform_keys_in_object(object, &block)
      case object
      when Hash
        object.each_with_object({}) do |(key, value), result|
          result[yield(key)] = deep_transform_keys_in_object(value, &block)
        end
      when Array
        object.map { |e| deep_transform_keys_in_object(e, &block) }
      else
        object
      end
    end
  end
end
