# frozen_string_literal: true

module RubyLLM
  class Judge
    class Question # :nodoc:
      CRITERIA_KEYS = { probability: :criteria, choice: :options, score: :levels }.freeze

      attr_reader :name, :type, :instructions, :criteria

      def initialize(name, type:, instructions: nil, criteria: nil, &block)
        validate_name!(name)
        raise ArgumentError, "Unknown judgment type: #{type.inspect}" unless CRITERIA_KEYS.key?(type)
        raise ArgumentError, 'Pass question criteria or a block, not both' if !criteria.nil? && block

        @name = name.is_a?(String) ? name.dup.freeze : name
        @type = type
        @instructions = Data.copy(instructions)
        @criteria = Data.copy(block || criteria)
        freeze
      end

      def self.from_h(name, definition)
        raise ArgumentError, 'Each question must be a Hash' unless definition.is_a?(Hash)

        definition = definition.transform_keys(&:to_sym)
        type = definition[:type]
        type = type.to_sym if type.is_a?(String)
        key = CRITERIA_KEYS.fetch(type) { raise ArgumentError, "Unknown judgment type: #{type.inspect}" }
        extra = definition.keys - [:type, :instructions, key]
        raise ArgumentError, "Unknown question options: #{extra.join(', ')}" unless extra.empty?

        new(name, type:, instructions: definition[:instructions], criteria: definition[key])
      end

      def resolve(scope)
        resolver = ->(value) { Builder.resolve(value, scope:) }
        resolved = self.class.new(name, type:, instructions: Data.copy(instructions, &resolver),
                                        criteria: Data.copy(criteria, &resolver))
        resolved.validate!
        resolved
      end

      def validate!
        unless Data.description?(instructions)
          raise ArgumentError,
                'Question instructions must be text, a Hash, an Array, or nil'
        end

        case type
        when :probability then validate_probability!
        when :choice then validate_choice!
        when :score then validate_score!
        end
      end

      private

      def validate_name!(name)
        unless name.is_a?(String) || name.is_a?(Symbol)
          raise ArgumentError, 'A question name must be a String or Symbol'
        end
        raise ArgumentError, 'A question name cannot be empty' if name.to_s.empty?
      end

      def validate_probability!
        return if criteria.nil?

        unless criteria.is_a?(Hash) && (criteria.keys.map(&:to_s) - %w[yes no true false]).empty?
          raise ArgumentError, 'Probability criteria must describe yes and no'
        end

        positive = %w[yes true]
        aliases = criteria.keys.map { |key| positive.include?(key.to_s) }
        raise ArgumentError, 'Probability criteria contain duplicate outcomes' unless aliases.uniq.size == aliases.size

        validate_descriptions!(criteria.values)
      end

      def validate_choice!
        raise ArgumentError, 'A choice needs a nonempty Hash of options' unless criteria.is_a?(Hash) && !criteria.empty?
        unless criteria.keys.all? { |key| (key.is_a?(String) || key.is_a?(Symbol)) && !key.to_s.empty? }
          raise ArgumentError, 'Choice options must have nonempty String or Symbol names'
        end

        validate_descriptions!(criteria.values)
      end

      def validate_score!
        raise ArgumentError, 'A score needs a nonempty Array of levels' unless criteria.is_a?(Array) && !criteria.empty?

        validate_descriptions!(criteria)
      end

      def validate_descriptions!(values)
        return if values.all? { |value| Data.description?(value) }

        raise ArgumentError, 'Descriptions must be text, a Hash, an Array, or nil'
      end
    end
  end
end
