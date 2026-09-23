# frozen_string_literal: true

module RubyLLM
  class MCP
    # Progress a server reports while it works on a request, received by
    # MCP.after_progress callbacks.
    #
    #   after_progress { |progress| puts "#{(progress.fraction * 100).round}% #{progress.message}" }
    #
    class Progress
      include Support::Inspectable

      # How much work is done. It only grows, but its unit is the server's.
      attr_reader :value

      # How much work there is in total, or +nil+ when the server does not
      # know.
      attr_reader :total

      # What the server is doing, or +nil+.
      attr_reader :message

      def initialize(data) # :nodoc:
        @value = data['progress']
        @total = data['total']
        @message = data['message']
      end

      # Returns the share of work done, from 0.0 to 1.0, or +nil+ without a
      # total.
      def fraction
        value.to_f / total if total&.positive?
      end

      private

      def inspect_attributes
        { value:, total:, message: }
      end
    end
  end
end
