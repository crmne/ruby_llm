# frozen_string_literal: true

require 'openssl'

module RubyLLM
  class MCP
    # What an MCP server posts to the address you gave
    # MCP::EventType#subscribe. Build one from the request's headers and
    # its raw body, with the secret you subscribed with, and it checks the
    # signature first:
    #
    #   delivery = RubyLLM::MCP::EventDelivery.new(request.headers, request.raw_post, secret: trigger.secret)
    #   case delivery.kind
    #   when :event then trigger.fire(delivery.event)
    #   when :verification then return render(json: { challenge: delivery.challenge })
    #   when :gap then trigger.update!(cursor: delivery.cursor)
    #   when :terminated then trigger.stopped(delivery.error)
    #   end
    #   head :ok
    #
    # Answer a delivery that raises MCP::Error with a 401.
    #
    # A server checks a new address with a +:verification+ delivery while
    # MCP::EventType#subscribe waits, before your app knows the
    # subscription's ID. Pass +secret+ every secret that has no ID yet, as
    # an Array, and #secret returns the one that signed the delivery.
    #
    # Servers deliver again after a failure, so skip a delivery whose #id
    # you have seen.
    class EventDelivery
      include Support::Inspectable

      TOLERANCE = 300
      private_constant :TOLERANCE

      # The delivery's ID, the same each time the server retries it.
      attr_reader :id

      # The ID of the MCP::EventSubscription the delivery belongs to.
      attr_reader :subscription_id

      # The secret that signed the delivery.
      attr_reader :secret

      # Reads the delivery from the request's +headers+ and raw +body+,
      # and checks its signature against +secret+, one secret or several.
      #
      # Raises MCP::Error when none matches, when the delivery is more than
      # five minutes old, or when the body is not JSON.
      def initialize(headers, body, secret:)
        @id = header(headers, 'webhook-id')
        @subscription_id = header(headers, 'X-MCP-Subscription-Id')
        @secret = signer(headers, body, Array(secret))
        @data = JSON.parse(body)
      rescue JSON::ParserError
        raise Error, 'The MCP event delivery is not JSON'
      end

      # What the delivery is: +:event+ for something that happened,
      # +:verification+ when the server checks your address, +:gap+ when
      # events were lost, and +:terminated+ when the subscription ended.
      def kind
        (@data['type'] || 'event').to_sym
      end

      # The MCP::Event of an +:event+ delivery, or +nil+.
      def event
        Event.new(@data) if kind == :event
      end

      # The value a +:verification+ delivery asks you to send back, as
      # <tt>{ challenge: }</tt> in a successful JSON response, or +nil+.
      def challenge
        @data['challenge']
      end

      # Where the server's events stand, to store and subscribe again
      # with: after the event of an +:event+ delivery, and after the lost
      # events of a +:gap+ one. +nil+ when the server keeps no history.
      def cursor
        @data['cursor']
      end

      # Why a +:terminated+ subscription ended, as an MCP::Error with the
      # server's code, or +nil+.
      def error
        reason = @data['error'] or return
        Error.new(provider_message: reason['message'], code: reason['code'], data: reason['data'])
      end

      private

      def header(headers, name)
        value = headers[name]
        value ||= headers.find { |key, _| key.to_s.casecmp?(name) }&.last if headers.is_a?(Hash)
        value.to_s
      end

      def signer(headers, body, secrets)
        timestamp = header(headers, 'webhook-timestamp')
        raise Error, 'The MCP event delivery is too old' if (Time.now.to_i - timestamp.to_i).abs > TOLERANCE

        signatures = header(headers, 'webhook-signature').split.filter_map { |entry| entry.delete_prefix!('v1,') }
        secrets.find { |secret| signed?(signatures, secret, "#{id}.#{timestamp}.#{body}") } ||
          raise(Error, 'The signature of the MCP event delivery does not match')
      end

      def signed?(signatures, secret, content)
        key = secret.to_s.delete_prefix('whsec_').unpack1('m')
        expected = [OpenSSL::HMAC.digest('SHA256', key, content)].pack('m0')
        signatures.any? do |signature|
          signature.bytesize == expected.bytesize && OpenSSL.fixed_length_secure_compare(signature, expected)
        end
      end

      def inspect_attributes
        { kind:, id:, subscription_id: }
      end
    end
  end
end
