# frozen_string_literal: true

require 'minitest'
require 'minitest/assertions'
require 'forwardable'

module RubyLLM
  class Evaluation
    class Assertions # :nodoc:
      include ::Minitest::Assertions

      attr_accessor :assertions

      def initialize
        @assertions = 0
      end
    end
  end
end
