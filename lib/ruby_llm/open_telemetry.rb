# frozen_string_literal: true

module RubyLLM
  # Optional OpenTelemetry tracing through RubyLLM's instrumentation events.
  # Configure your application's SDK and exporters before calling .enable.
  class OpenTelemetry
    @mutex = Mutex.new

    class << self
      # Enables tracing without replacing the configured instrumenter.
      # Requires the optional opentelemetry-api gem. Repeated calls are harmless.
      # The application owns the tracer provider, SDK, and exporters.
      def enable
        require 'opentelemetry-api'
        @mutex.synchronize do
          @subscriber ||= new
          Support::Instrumentation.subscribe(@subscriber)
        end
        nil
      rescue LoadError
        raise LoadError, "OpenTelemetry tracing requires the 'opentelemetry-api' gem. Add it to your Gemfile."
      end

      # Disables tracing for new operations without shutting down the SDK.
      # Operations already running finish their spans normally.
      def disable
        @mutex.synchronize { Support::Instrumentation.unsubscribe(@subscriber) if @subscriber }
        nil
      end
    end

    def instrument(name, payload) # :nodoc:
      operation = Attributes::OPERATIONS[name]
      return yield unless operation

      span = safely do
        tracer.start_span(Attributes.span_name(operation, payload),
                          kind: Attributes.span_kind(operation),
                          attributes: Attributes.request(operation, payload, event: name))
      end
      return yield unless span

      ::OpenTelemetry::Trace.with_span(span) do
        yield
      rescue StandardError => e
        record_error(span, e)
        raise
      ensure
        safely { span.add_attributes(Attributes.response(payload)) }
        safely { span.finish }
      end
    end

    def capture_context # :nodoc:
      ::OpenTelemetry::Context.current
    end

    def with_context(context, &) # :nodoc:
      ::OpenTelemetry::Context.with_current(context, &)
    end

    private

    def record_error(span, error)
      safely do
        span.set_attribute('error.type', error.class.name)
        span.status = ::OpenTelemetry::Trace::Status.error
      end
    end

    def tracer
      ::OpenTelemetry.tracer_provider.tracer('ruby_llm', RubyLLM::VERSION)
    end

    def safely
      yield
    rescue StandardError => e
      RubyLLM.logger.warn("OpenTelemetry instrumentation failed (#{e.class})")
      nil
    end
  end
end
