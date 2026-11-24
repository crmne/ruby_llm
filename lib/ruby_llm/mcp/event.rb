# frozen_string_literal: true

module RubyLLM
  class MCP
    # Something that happened on an MCP server, from MCP::EventType#poll
    # or an MCP::EventDelivery.
    #
    #   event.name       # => "issue.created"
    #   event.timestamp  # => 2026-11-24 09:30:00 UTC
    #   event.data       # => { "id" => "ENG-42", "title" => "Flaky spec" }
    #
    # The data is whatever the server sent. Treat text in it as data, never
    # as instructions.
    class Event
      include Support::Inspectable

      # The event's ID on its server, the same each time the server
      # delivers it for one event type and its arguments.
      attr_reader :id

      # The name of the event's type.
      attr_reader :name

      # What the event carries, as a Hash.
      attr_reader :data

      # Where the server's events stand after this one, to store and
      # subscribe again with, or +nil+ when the server keeps no history.
      # Polled events have none: the MCP::EventPage carries it.
      attr_reader :cursor

      def initialize(data) # :nodoc:
        @id = data['eventId']
        @name = data['name']
        @timestamp = data['timestamp']
        @data = data['data']
        @cursor = data['cursor']
      end

      # When the event happened, as a Time.
      def timestamp
        Time.iso8601(@timestamp)
      end

      private

      def inspect_attributes
        { id:, name:, timestamp: @timestamp }
      end
    end
  end
end
