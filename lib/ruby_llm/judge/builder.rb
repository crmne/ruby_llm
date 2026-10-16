# frozen_string_literal: true

module RubyLLM
  class Judge
    class Builder < BasicObject # :nodoc:
      def self.resolve(value, scope:)
        return value unless value.is_a?(::Proc)

        new(scope).evaluate(value)
      end

      def initialize(scope)
        @scope = scope
        @data = {}
      end

      def evaluate(block)
        result = block.arity.zero? ? instance_exec(&block) : instance_exec(self, &block)
        return result if @data.empty?

        unless result.equal?(self) || result.nil?
          ::Kernel.raise ::ArgumentError, 'A judgment block must declare fields or return a value, not both'
        end

        @data
      end

      def method_missing(name, *values, &block)
        return @scope.public_send(name) if runtime_input?(name, values, block)

        if values.size > 1 || (!values.empty? && block)
          ::Kernel.raise ::ArgumentError, "#{name} accepts one value or a block"
        end
        ::Kernel.raise ::ArgumentError, "Duplicate judgment field: #{name}" if @data.key?(name)

        @data[name] = block ? ::RubyLLM::Judge::Builder.resolve(block, scope: @scope) : values.first
        self
      end

      def respond_to_missing?(_name, _include_private = nil)
        true
      end

      private

      def proc(&block)
        block
      end
      alias lambda proc

      def runtime_input?(name, values, block)
        values.empty? && !block && @scope.respond_to?(name)
      end
    end
  end
end
