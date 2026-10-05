# frozen_string_literal: true

module RubyLLM
  class Evaluation
    class Assertions # :nodoc:
      METHOD = /\A(?:assert|refute)(?:_|\z)/

      # Matches Minitest assertion failures without loading Minitest.
      module Failure
        def self.===(error)
          defined?(::Minitest::Assertion) && error.is_a?(::Minitest::Assertion)
        end
      end

      attr_accessor :assertions

      class << self
        def method?(name)
          METHOD.match?(name) && available? && ::Minitest::Assertions.method_defined?(name)
        end

        def available?
          require 'minitest'
          true
        rescue LoadError
          false
        end
      end

      def initialize
        raise LoadError, "Evaluation assertions require the 'minitest' gem. Add it to your Gemfile." unless
          self.class.available?

        extend ::Minitest::Assertions

        @assertions = 0
      end
    end
  end
end
