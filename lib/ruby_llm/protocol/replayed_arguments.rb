# frozen_string_literal: true

module RubyLLM
  class Protocol
    # Replayed provider content keeps the argument text of calls that were
    # not a JSON object, and some providers reject such a request. These
    # helpers swap that text for empty arguments.
    module ReplayedArguments # :nodoc:
      module_function

      def malformed_call_ids(message)
        message.tool_calls.filter_map { |call| call.provider_call_id if call.malformed_arguments? }
      end

      def blank(entries, message, id:, arguments:, empty:)
        ids = malformed_call_ids(message)
        return entries if ids.empty? || !entries.is_a?(Array)

        entries.map do |entry|
          next entry unless entry.is_a?(Hash) && entry.key?(arguments) && ids.include?(entry[id])

          entry.merge(arguments => empty)
        end
      end
    end
  end
end
