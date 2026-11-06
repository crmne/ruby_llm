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
      TOO_LONG = '[This tool result was left out to fit the context window. ' \
                 'Ask for less, such as a narrower query or the next page.]'
      NOTE_ROOM = 200

      def self.normalize(budget, **shares)
        return if budget.nil?

        budget = budget.to_h.transform_keys(&:to_sym).merge(shares)
        unknown = budget.keys - SHARES - [:window]
        raise ArgumentError, "Unknown context budget option: #{unknown.join(', ')}" if unknown.any?
        unless budget.keys.intersect?(SHARES)
          raise ArgumentError, 'with_context_budget takes per_result:, per_request:, or both'
        end

        budget.slice(*SHARES).each { |name, share| validate_share(name, share) }
        validate_window(budget[:window]) if budget.key?(:window)
        budget.freeze
      end

      def self.validate_share(name, share)
        return if share.is_a?(Numeric) && share.positive? && share <= 1

        raise ArgumentError, "#{name} must be a share of the context window above 0 and at most 1"
      end

      def self.validate_window(window)
        return if window.is_a?(Integer) && window.positive?

        raise ArgumentError, 'window must be a positive whole number of tokens'
      end
      private_class_method :validate_share, :validate_window

      def initialize(budget, context_window)
        @budget = budget
        window = budget[:window] || context_window
        @window = window.to_i if window.to_i.positive?
      end

      def window?
        !@window.nil?
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

        excess = size_of_all(list) - limit
        return list unless excess.positive?

        step = limit * STEP
        latest = list.rindex { |message| message.role == :assistant } || -1
        fitted = leave_out(list, (excess / step).ceil * step, LEFT_OUT) { |index| index < latest }
        over = size_of_all(fitted) - limit
        return fitted unless over.positive?

        leave_out(fitted, over, TOO_LONG) { |index| index > latest }
      end

      private

      # Replaces the oldest results the block picks by index with +note+,
      # until +characters+ are freed. A request stops here for older rounds,
      # in steps. The latest round's results, which the model has not seen
      # yet, are cut only as far as the request needs: left whole, a round
      # over the budget would fail this request and every one after it.
      def leave_out(list, characters, note)
        list.each_with_index.map do |message, index|
          next message unless characters.positive? && yield(index) && leavable?(message, note)

          characters -= message.content.length - note.length
          message.with(content: note)
        end
      end

      def characters(share)
        return unless @window && @budget[share]

        (@window * @budget[share] * CHARACTERS_PER_TOKEN).to_i
      end

      def leavable?(message, note)
        message.tool_result? && message.content.is_a?(String) && message.content.length > note.length
      end

      def size_of_all(list)
        list.sum { |message| size_of(message) }
      end

      def size_of(message)
        message.content.to_s.length + message.tool_calls.to_h.sum { |_id, call| call.arguments.to_json.length }
      end
    end
  end
end
