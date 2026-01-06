# frozen_string_literal: true

require 'singleton'

module RubyLLM
  # OpenTelemetry instrumentation for RubyLLM
  # Provides tracing capabilities when enabled and OpenTelemetry is available
  module Instrumentation
    # Span kind constants (matches OpenTelemetry::Trace::SpanKind)
    module SpanKind
      CLIENT = :client
      INTERNAL = :internal
    end
    class << self
      def enabled?(config = RubyLLM.config)
        return false unless config.tracing_enabled

        unless otel_available?
          warn_otel_missing unless @otel_warning_issued
          @otel_warning_issued = true
          return false
        end

        true
      end

      def tracer(config = RubyLLM.config)
        return NullTracer.instance unless enabled?(config)

        # Don't memoize - tracer_provider can be reconfigured after initial load
        OpenTelemetry.tracer_provider.tracer('ruby_llm', RubyLLM::VERSION)
      end

      def reset!
        @otel_warning_issued = false
      end

      private

      def otel_available?
        return false unless defined?(OpenTelemetry)

        !!OpenTelemetry.tracer_provider
      end

      def warn_otel_missing
        RubyLLM.logger.warn <<~MSG.strip
          [RubyLLM] Tracing is enabled but OpenTelemetry is not available.
          Tracing will be disabled. To enable, add to your Gemfile:

            gem 'opentelemetry-sdk'
            gem 'opentelemetry-exporter-otlp'

          See https://rubyllm.com/advanced/observability for setup instructions.
        MSG
      end
    end

    # No-op tracer used when tracing is disabled or OpenTelemetry is not available
    class NullTracer
      include Singleton

      def in_span(_name, **_options)
        yield NullSpan.instance
      end
    end

    # No-op span that responds to all span methods but does nothing
    class NullSpan
      include Singleton

      def recording?
        false
      end

      def set_attribute(_key, _value)
        self
      end

      def add_attributes(_attributes)
        self
      end

      def record_exception(_exception, _attributes = {})
        self
      end

      def status=(_status)
        # no-op
      end

      def finish
        self
      end
    end

    # Helper for building span attributes
    module SpanBuilder
      class << self
        def truncate_content(content, max_length)
          return nil if content.nil?

          content_str = content.to_s
          return content_str if content_str.length <= max_length

          "#{content_str[0, max_length]}... [truncated]"
        end

        def extract_content_text(content)
          case content
          when String
            content
          when RubyLLM::Content
            content.text || describe_attachments(content.attachments)
          else
            content.to_s
          end
        end

        def describe_attachments(attachments)
          return '[no content]' if attachments.empty?

          descriptions = attachments.map { |a| "#{a.type}: #{a.filename}" }
          "[#{descriptions.join(', ')}]"
        end

        def build_message_attributes(messages, max_length:, langsmith_compat: false)
          attrs = {}
          messages.each_with_index do |msg, idx|
            attrs["gen_ai.prompt.#{idx}.role"] = msg.role.to_s
            content = extract_content_text(msg.content)
            attrs["gen_ai.prompt.#{idx}.content"] = truncate_content(content, max_length)
          end
          # Set input.value for LangSmith Input panel (last user message)
          if langsmith_compat
            last_user_msg = messages.reverse.find { |m| m.role.to_s == 'user' }
            if last_user_msg
              content = extract_content_text(last_user_msg.content)
              attrs['input.value'] = truncate_content(content, max_length)
            end
          end
          attrs
        end

        def build_completion_attributes(message, max_length:, langsmith_compat: false)
          attrs = {}
          attrs['gen_ai.completion.0.role'] = message.role.to_s
          content = extract_content_text(message.content)
          truncated = truncate_content(content, max_length)
          attrs['gen_ai.completion.0.content'] = truncated
          # Set output.value for LangSmith Output panel
          attrs['output.value'] = truncated if langsmith_compat
          attrs
        end

        def build_request_attributes(model:, provider:, session_id:, temperature: nil, metadata: nil,
                                     langsmith_compat: false, metadata_prefix: 'metadata')
          attrs = {
            'gen_ai.system' => provider.to_s,
            'gen_ai.operation.name' => 'chat',
            'gen_ai.request.model' => model.id,
            'gen_ai.conversation.id' => session_id
          }
          attrs['langsmith.span.kind'] = 'LLM' if langsmith_compat
          attrs['gen_ai.request.temperature'] = temperature if temperature
          build_metadata_attributes(attrs, metadata, prefix: metadata_prefix) if metadata
          attrs
        end

        def build_metadata_attributes(attrs, metadata, prefix: 'metadata')
          metadata.each do |key, value|
            next if value.nil?

            # Preserve native types that OTel supports (string, int, float, bool)
            # Only stringify complex objects
            attrs["#{prefix}.#{key}"] = otel_safe_value(value)
          end
        end

        def otel_safe_value(value)
          case value
          when String, Integer, Float, TrueClass, FalseClass
            value
          when Hash, Array
            JSON.generate(value)
          else
            value.to_s
          end
        end

        def build_response_attributes(response)
          attrs = {}
          attrs['gen_ai.response.model'] = response.model_id if response.model_id
          attrs['gen_ai.usage.input_tokens'] = response.input_tokens if response.input_tokens
          attrs['gen_ai.usage.output_tokens'] = response.output_tokens if response.output_tokens
          attrs
        end

        def build_tool_attributes(tool_call:, session_id:, langsmith_compat: false)
          attrs = {
            'gen_ai.operation.name' => 'tool',
            'gen_ai.tool.name' => tool_call.name.to_s,
            'gen_ai.tool.call.id' => tool_call.id,
            'gen_ai.conversation.id' => session_id
          }
          attrs['langsmith.span.kind'] = 'TOOL' if langsmith_compat
          attrs
        end

        def build_tool_input_attributes(tool_call:, max_length:, langsmith_compat: false)
          args = tool_call.arguments
          input = args.is_a?(String) ? args : JSON.generate(args)
          truncated = truncate_content(input, max_length)
          attrs = { 'gen_ai.tool.input' => truncated }
          attrs['input.value'] = truncated if langsmith_compat
          attrs
        end

        def build_tool_output_attributes(result:, max_length:, langsmith_compat: false)
          output = result.is_a?(String) ? result : result.to_s
          truncated = truncate_content(output, max_length)
          attrs = { 'gen_ai.tool.output' => truncated }
          attrs['output.value'] = truncated if langsmith_compat
          attrs
        end
      end
    end
  end
end
