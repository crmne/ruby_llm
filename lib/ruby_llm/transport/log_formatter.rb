# frozen_string_literal: true

require 'faraday'
require 'faraday/logging/formatter'

module RubyLLM
  module Transport
    # A request that succeeded and was billed must not fail because a debug
    # log filter ran out of time on a large body.
    #
    # The formatter is shared by every context that uses the connection, so
    # the configuration whose credentials it filters arrives with each
    # request, and its response or exception is logged on the same fiber.
    class LogFormatter < Faraday::Logging::Formatter # :nodoc:
      CONFIG_KEY = :ruby_llm_log_config
      FILTERED = '[FILTERED]'

      # Writes a debug line to +config+'s logger with its credentials
      # replaced. The block runs only when the logger is at debug level.
      def self.debug(config, &message)
        (config.logger || RubyLLM.logger).debug { redact(message.call, config.secret_values) }
      end

      def self.redact(text, secrets)
        secrets.reduce(text.to_s) { |output, secret| output.gsub(secret, FILTERED) }
      end

      def request(env)
        Fiber[CONFIG_KEY] = env.request.context.to_h[CONFIG_KEY]
        super
      end

      private

      def apply_filters(output)
        config = Fiber[CONFIG_KEY]
        super(config ? self.class.redact(output, config.secret_values) : output)
      rescue Regexp::TimeoutError
        '[NOT LOGGED: FILTER TIMED OUT]'
      end
    end
  end
end
