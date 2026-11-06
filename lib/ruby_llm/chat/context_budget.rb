# frozen_string_literal: true

module RubyLLM
  class Chat
    # Fits tool results to shares of the model's context window, as set with
    # Chat#with_context_budget. Counting tokens takes a request, so sizes go
    # by characters, at two a token: JSON and HTML, which most large tool
    # results are, run that dense.
    class ContextBudget # :nodoc:
      SHARES = %i[per_result per_request].freeze
      CHARACTERS_PER_TOKEN = 2
      # The cut moves in steps of this share of the request budget, so
      # the request prefix, and the prompt cache, hold for many rounds.
      STEP = 0.15
      LEFT_OUT = '[This earlier tool result was left out to fit the context window. ' \
                 'Call the tool again if you need it.]'
      NOTE_ROOM = 200

      def self.normalize(budget, **shares)
        return if budget.nil?

        budget = budget.to_h.transform_keys(&:to_sym).merge(shares)
        raise ArgumentError, 'with_context_budget takes per_result:, per_request:, or both' if budget.empty?

        unknown = budget.keys - SHARES
        raise ArgumentError, "Unknown context budget option: #{unknown.join(', ')}" if unknown.any?

        budget.each { |name, share| validate_share(name, share) }
        budget.freeze
      end

      def self.validate_share(name, share)
        return if share.is_a?(Numeric) && share.positive? && share <= 1

        raise ArgumentError, "#{name} must be a share of the context window above 0 and at most 1"
      end
      private_class_method :validate_share

      def initialize(budget, context_window)
        @budget = budget
        @window = context_window.to_i if context_window.to_i.positive?
      end

      def cap(content)
        limit = characters(:per_result)
        return content unless limit && content.is_a?(String) && content.length > limit

        shown = [limit - NOTE_ROOM, 0].max
        "#{content[0, shown]}\n\n[Result truncated: #{shown} of #{content.length} characters shown. " \
          'Ask for a narrower query or the next page.]'
      end

      def fit(list)
        limit = characters(:per_request)
        return list unless limit

        excess = list.sum { |message| size_of(message) } - limit
        return list unless excess.positive?

        step = limit * STEP
        leave_out(list, (excess / step).ceil * step)
      end

      private

      # Leaves out the oldest results until +characters+ are freed, keeping
      # the latest round's, which the model has not seen yet.
      def leave_out(list, characters)
        latest = list.rindex { |message| message.role == :assistant } || 0
        list.each_with_index.map do |message, index|
          next message unless characters.positive? && index < latest && leavable?(message)

          characters -= message.content.length - LEFT_OUT.length
          message.with(content: LEFT_OUT)
        end
      end

      def characters(share)
        return unless @window && @budget[share]

        (@window * @budget[share] * CHARACTERS_PER_TOKEN).to_i
      end

      def leavable?(message)
        message.tool_result? && message.content.is_a?(String) && message.content.length > LEFT_OUT.length
      end

      def size_of(message)
        message.content.to_s.length + message.tool_calls.to_h.sum { |_id, call| call.arguments.to_json.length }
      end
    end
  end
end
