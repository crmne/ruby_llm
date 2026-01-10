# frozen_string_literal: true

require 'json'

# Try to load Oj for better performance (5-6x faster than stdlib JSON)
begin
  require 'oj'
  OJ_AVAILABLE = true
rescue LoadError
  OJ_AVAILABLE = false
end

module RubyLLM
  module AgentSDK
    # JSON-LD stream parser for Claude CLI output
    #
    # Uses Oj gem when available for 5-6x better performance,
    # falls back to stdlib JSON otherwise.
    #
    # @example Parse a single line
    #   message = Stream.parse('{"type":"assistant","content":"Hello"}')
    #   message.type # => :assistant
    #   message.content # => "Hello"
    class Stream
      # JSON parsing options optimized for each parser
      OJ_OPTIONS = { mode: :compat, symbol_keys: true }.freeze
      JSON_OPTIONS = { symbolize_names: true }.freeze

      class << self
        # Parse a JSON-LD line into a Message object
        #
        # @param line [String] JSON string to parse
        # @return [Message, nil] Parsed message or nil for empty input
        # @raise [JSONDecodeError] If JSON parsing fails
        def parse(line)
          return nil if line.nil? || line.empty?

          json = parse_json(line)
          Message.new(json)
        rescue StandardError => e
          error_class = defined?(Oj::ParseError) && e.is_a?(Oj::ParseError) ? e.class : JSON::ParserError
          raise JSONDecodeError.new(
            "Failed to parse JSON: #{e.message}",
            line: line,
            original_error: e
          )
        end

        # Check if Oj is available for faster parsing
        #
        # @return [Boolean]
        def oj_available?
          OJ_AVAILABLE
        end

        private

        def parse_json(line)
          if OJ_AVAILABLE
            Oj.load(line, OJ_OPTIONS)
          else
            JSON.parse(line, **JSON_OPTIONS)
          end
        end
      end
    end
  end
end
