# frozen_string_literal: true

module RubyLLM
  class MCP
    # What MCP::EventType#subscribe returns: the server's subscription that
    # posts events to your app.
    #
    #   subscription = issues.subscribe(url: linear_events_url, secret:)
    #   subscription.id              # => "sub_a3f1c8e2b0d49f7e"
    #   subscription.refresh_before  # => 2026-11-25 09:30:00 UTC
    #
    # The server holds the subscription, so store what you need of it with
    # your own records: the ID, the secret, and the cursor.
    class EventSubscription
      include Support::Inspectable

      # The subscription's ID on its server, which each MCP::EventDelivery
      # carries. It stays the same when you subscribe again.
      attr_reader :id

      # Where the server's events stand, to store and subscribe again with,
      # or +nil+ when the server keeps no history.
      attr_reader :cursor

      # Why the server's last delivery failed, such as <tt>"timeout"</tt>
      # or <tt>"http_5xx"</tt>, when subscribing again says so, or +nil+.
      attr_reader :last_error

      def initialize(data) # :nodoc:
        @id = data['id']
        @refresh_before = data['refreshBefore']
        @cursor = data['cursor']
        @truncated = data['truncated'] == true
        @last_error = data.dig('deliveryStatus', 'lastError')
      end

      # When to subscribe again by, as a Time, or +nil+ for a subscription
      # that never expires.
      def refresh_before
        Time.iso8601(@refresh_before) if @refresh_before
      end

      # Returns whether the server no longer had every event since the
      # cursor you passed, so some are missing.
      def truncated?
        @truncated
      end

      private

      def inspect_attributes
        { id:, refresh_before: @refresh_before, last_error: }
      end
    end
  end
end
