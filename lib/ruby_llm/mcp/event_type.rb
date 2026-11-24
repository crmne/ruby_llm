# frozen_string_literal: true

module RubyLLM
  class MCP
    # A kind of event an MCP server announces, as the Events extension
    # describes: an issue created, an email received. MCP#event_types lists
    # them, and MCP#event_type fills one in with the arguments that say
    # which events you want.
    #
    #   issues = linear.event_type("issue.created", team: "ENG")
    #   issues.delivery  # => [:poll, :webhook]
    #
    # Ask for what happened since a cursor with #poll, or have the server
    # post events to your app with #subscribe. The server keeps no
    # subscription for polling, so store the cursor with your own records.
    class EventType
      include Support::Inspectable

      EXTENSION = 'io.modelcontextprotocol/events' # :nodoc:

      # The event type's name, such as <tt>"issue.created"</tt>.
      attr_reader :name

      # What the event is, or +nil+.
      attr_reader :description

      # How the server delivers the events: any of +:poll+, +:push+, and
      # +:webhook+.
      attr_reader :delivery

      # The JSON Schema of the arguments the event type takes.
      attr_reader :parameters_schema

      # The JSON Schema of an event's data.
      attr_reader :payload_schema

      # The arguments that say which events you want, as MCP#event_type
      # received them.
      attr_reader :arguments

      # The event types +client+'s server lists. Servers declare events as
      # an extension, or as a capability of their own in the form that
      # predates it.
      def self.offered(client) # :nodoc:
        capabilities = client.server['capabilities'] || {}
        return [] unless capabilities.dig('extensions', EXTENSION) || capabilities['events']

        listed = client.list('events/list', 'events').select { |data| ParamHeaders.valid?(data, 'event') }
        listed.map { |data| new(client, data) }
      end

      def self.named(types, name, server) # :nodoc:
        types.find { |type| type.name == name.to_s } || raise(Error, "#{server} does not announce #{name} events")
      end

      def initialize(client, data, arguments = {}) # :nodoc:
        @client = client
        @data = data
        @name = data['name']
        @description = data['description']
        @delivery = Array(data['delivery']).map(&:to_sym)
        @parameters_schema = data['inputSchema']
        @payload_schema = data['payloadSchema']
        @arguments = arguments
      end

      def with(arguments) # :nodoc:
        self.class.new(@client, @data, arguments)
      end

      # Asks the server what happened since +cursor+ and returns an
      # MCP::EventPage. Without a cursor, the page is empty and carries the
      # cursor to poll from next. +max_age+, in seconds, skips events older
      # than that, and +limit+ caps how many come back.
      #
      #   page = issues.poll(cursor: trigger.cursor)
      #   page.each { |event| trigger.fire(event) }
      #   trigger.update!(cursor: page.cursor)
      #
      def poll(cursor: nil, max_age: nil, limit: nil)
        EventPage.new(request('events/poll', cursor:, **{ maxAgeMs: milliseconds(max_age), maxEvents: limit }.compact))
      end

      # Has the server post the events to +url+, an +https+ address of your
      # app, signed with +secret+. Returns an MCP::EventSubscription.
      # Subscribe again with the same +url+ before its +refresh_before+ to
      # keep it, passing the last cursor you stored, and a new +secret+ to
      # rotate it.
      #
      # The server may check the address before it answers, so store the
      # secret where the app that receives the events reads it before you
      # subscribe; see MCP::EventDelivery. +secret+ is +whsec_+ followed by
      # 24 to 64 random bytes in base64:
      #
      #   secret = "whsec_#{SecureRandom.base64(32)}"
      #   subscription = issues.subscribe(url: linear_events_url, secret:)
      #
      # +ttl+, in seconds, suggests how long the subscription lasts, and
      # +Float::INFINITY+ asks for one that never expires.
      def subscribe(url:, secret:, cursor: nil, max_age: nil, ttl: nil)
        lifetime = ttl == Float::INFINITY ? { ttlMs: nil } : { ttlMs: milliseconds(ttl) }.compact
        delivery = { mode: 'webhook', url:, secret: }
        EventSubscription.new(
          request('events/subscribe', delivery:, cursor:, **{ maxAgeMs: milliseconds(max_age) }.compact, **lifetime)
        )
      end

      # Ends the subscription that posts these events to +url+. Returns
      # +self+.
      def unsubscribe(url:)
        request('events/unsubscribe', delivery: { mode: 'webhook', url: })
        self
      end

      private

      def request(method, **params)
        @client.request(method, { name:, arguments: }.merge(params), headers: ParamHeaders.for(@data, arguments))
      end

      def milliseconds(seconds)
        (seconds.to_f * 1000).round if seconds
      end

      def inspect_attributes
        { name:, delivery:, arguments: }
      end
    end
  end
end
