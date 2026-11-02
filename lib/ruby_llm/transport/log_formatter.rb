# frozen_string_literal: true

require 'faraday'
require 'faraday/logging/formatter'

module RubyLLM
  module Transport
    # A request that succeeded and was billed must not fail because a debug
    # log filter ran out of time on a large body.
    class LogFormatter < Faraday::Logging::Formatter # :nodoc:
      private

      def apply_filters(output)
        super
      rescue Regexp::TimeoutError
        '[NOT LOGGED: FILTER TIMED OUT]'
      end
    end
  end
end
