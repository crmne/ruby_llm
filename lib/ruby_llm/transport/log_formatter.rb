# frozen_string_literal: true

require 'faraday'
require 'faraday/logging/formatter'

module RubyLLM
  module Transport
    # A request that succeeded and was billed must not fail because a debug
    # log filter ran out of time on a large body.
    #
    # The cached connection's formatter is shared by every context, so the
    # configuration whose credentials it filters is set in fiber storage for
    # the duration of each request. A Connection.basic formatter serves one
    # configuration and is given it directly.
    class LogFormatter < Faraday::Logging::Formatter # :nodoc:
      CONFIG_KEY = :ruby_llm_log_config
      FILTERED = '[FILTERED]'

      attr_writer :config

      def self.with_config(config)
        previous = Fiber[CONFIG_KEY]
        Fiber[CONFIG_KEY] = config
        yield
      ensure
        Fiber[CONFIG_KEY] = previous
      end

      # Writes a debug line to +config+'s logger with its credentials
      # replaced. The block runs only when the logger is at debug level.
      def self.log_debug(config, &message)
        (config.logger || RubyLLM.logger).debug { redact(message.call, config.secret_values) }
      end

      # Longer secrets go first, so a key that contains another key is
      # replaced whole instead of leaving its remainder in the line.
      def self.redact(text, secrets)
        secrets.uniq.sort_by { |secret| -secret.length }
               .reduce(text.to_s) { |output, secret| output.gsub(secret, FILTERED) }
      end

      # Faraday 2.12 and earlier write exception messages without
      # apply_filters, so credentials are replaced on the way out instead.
      # Connection.setup_logging logs every line at debug.
      def debug(progname = nil)
        config = @config || Fiber[CONFIG_KEY]
        @logger.debug(progname) { config ? self.class.redact(yield, config.secret_values) : yield }
      end

      private

      def apply_filters(output)
        super
      rescue Regexp::TimeoutError
        '[NOT LOGGED: FILTER TIMED OUT]'
      end
    end
  end
end
