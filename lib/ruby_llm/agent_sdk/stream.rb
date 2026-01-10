# frozen_string_literal: true

begin
  require 'oj'
  OJ_AVAILABLE = true
rescue LoadError
  OJ_AVAILABLE = false
end

require 'json'

module RubyLLM
  module AgentSDK
    class Stream
      JSON_OPTIONS = if OJ_AVAILABLE
                       { mode: :compat, symbol_keys: true }.freeze
                     else
                       { symbolize_names: true }.freeze
                     end

      def self.parse(line)
        return nil if line.nil? || line.empty?

        json = if OJ_AVAILABLE
                 Oj.load(line, JSON_OPTIONS)
               else
                 JSON.parse(line, **JSON_OPTIONS)
               end

        Message.new(json)
      rescue OJ_AVAILABLE ? Oj::ParseError : JSON::ParserError => e
        raise JSONDecodeError.new('Failed to parse JSON', line: line, original_error: e)
      end

      def self.oj_available?
        OJ_AVAILABLE
      end
    end
  end
end
