# frozen_string_literal: true

module RubyLLM
  class Evaluation
    # One dataset example, with application inputs and optional reference evidence.
    class Case
      include Support::Inspectable

      # Returns the stable case name used to compare runs.
      attr_reader :name
      # Returns the value passed to Evaluation#perform.
      attr_reader :inputs
      # Returns the reference answer, or nil when none was supplied.
      attr_reader :expected_output
      # Returns application-defined reference evidence and category labels.
      attr_reader :metadata

      # Creates a case. Inputs and reference evidence must be JSON-compatible.
      def initialize(name:, inputs:, metadata: {}, **reference)
        unless (reference.keys - [:expected_output]).empty?
          raise ArgumentError,
                "Unknown case fields: #{reference.keys - [:expected_output]}"
        end
        raise ArgumentError, 'A case name cannot be empty' if name.to_s.empty?
        raise ArgumentError, 'Case metadata must be a Hash' unless metadata.is_a?(Hash)

        @name = name.to_s.dup.freeze
        @inputs = Judge::Data.copy(inputs)
        @metadata = Judge::Data.copy(metadata)
        @expected_output = Judge::Data.copy(reference[:expected_output])
        @reference_supplied = reference.key?(:expected_output)
        freeze
      end

      # Returns whether a reference was supplied, including an explicit nil.
      def expected_output?
        @reference_supplied
      end

      # Returns the portable dataset representation of this case.
      def to_h
        data = { name:, inputs:, metadata: }
        data[:expected_output] = expected_output if expected_output?
        data
      end

      def inspect_attributes # :nodoc:
        { name: }
      end
    end
  end
end
