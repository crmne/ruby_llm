# frozen_string_literal: true

module RubyLLM
  class Protocol
    # Prompt cache APIs spell lifetimes as short strings such as "5m" and
    # "1h". A string column stores a Duration as its digits, so digits in a
    # String count as seconds.
    module CacheLifetime # :nodoc:
      UNITS = { 'h' => 3600, 'm' => 60 }.freeze

      module_function

      def render(ttl)
        seconds = ttl.is_a?(String) ? Float(ttl, exception: false)&.to_i : ttl.to_i
        return ttl unless seconds

        unit, size = UNITS.find { |_unit, length| (seconds % length).zero? }
        unit ? "#{seconds / size}#{unit}" : "#{seconds}s"
      end
    end
  end
end
