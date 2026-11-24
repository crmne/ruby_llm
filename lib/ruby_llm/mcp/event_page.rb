# frozen_string_literal: true

module RubyLLM
  class MCP
    # What MCP::EventType#poll returns: the events since the cursor you
    # passed, and the cursor to pass next time.
    #
    #   page = issues.poll(cursor: trigger.cursor)
    #   page.map(&:id)      # => ["evt_1", "evt_2"]
    #   page.cursor         # => "history_99842"
    #   page.poll_interval  # => 30.0
    #
    class EventPage
      include Enumerable
      include Support::Inspectable

      # The cursor to poll with next, or +nil+ when the server keeps no
      # history.
      attr_reader :cursor

      def initialize(data) # :nodoc:
        @events = data.fetch('events', []).map { |event| Event.new(event) }
        @cursor = data['cursor']
        @more = data['hasMore'] == true
        @truncated = data['truncated'] == true
        @next_poll = data['nextPollMs']
      end

      # Yields each MCP::Event, oldest first.
      def each(&)
        @events.each(&)
      end

      # Returns whether nothing happened.
      def empty?
        @events.empty?
      end

      # Returns whether more events wait on the server. Poll again right
      # away with #cursor.
      def more?
        @more
      end

      # Returns whether the server no longer had every event since the
      # cursor you passed, so some are missing.
      def truncated?
        @truncated
      end

      # How many seconds the server asks you to wait before polling again,
      # or +nil+.
      def poll_interval
        @next_poll / 1000.0 if @next_poll
      end

      private

      def inspect_attributes
        { events: @events.size, cursor:, more: more? || nil, truncated: truncated? || nil }
      end
    end
  end
end
