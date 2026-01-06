# frozen_string_literal: true

module RubyLLM
  # Represents a conversation with an AI model
  class Chat
    include Enumerable

    attr_reader :model, :messages, :tools, :params, :headers, :schema, :session_id, :metadata

    def initialize(model: nil, provider: nil, assume_model_exists: false, context: nil, session_id: nil)
      if assume_model_exists && !provider
        raise ArgumentError, 'Provider must be specified if assume_model_exists is true'
      end

      @context = context
      @config = context&.config || RubyLLM.config
      model_id = model || @config.default_model
      with_model(model_id, provider: provider, assume_exists: assume_model_exists)
      @session_id = session_id || SecureRandom.uuid
      @metadata = {}
      @temperature = nil
      @messages = []
      @tools = {}
      @params = {}
      @headers = {}
      @schema = nil
      @on = {
        new_message: nil,
        end_message: nil,
        tool_call: nil,
        tool_result: nil
      }
    end

    def ask(message = nil, with: nil, &)
      add_message role: :user, content: build_content(message, with)
      complete(&)
    end

    alias say ask

    def with_instructions(instructions, replace: false)
      @messages = @messages.reject { |msg| msg.role == :system } if replace

      add_message role: :system, content: instructions
      self
    end

    def with_tool(tool)
      tool_instance = tool.is_a?(Class) ? tool.new : tool
      @tools[tool_instance.name.to_sym] = tool_instance
      self
    end

    def with_tools(*tools, replace: false)
      @tools.clear if replace
      tools.compact.each { |tool| with_tool tool }
      self
    end

    def with_model(model_id, provider: nil, assume_exists: false)
      @model, @provider = Models.resolve(model_id, provider:, assume_exists:, config: @config)
      @connection = @provider.connection
      self
    end

    def with_temperature(temperature)
      @temperature = temperature
      self
    end

    def with_context(context)
      @context = context
      @config = context.config
      with_model(@model.id, provider: @provider.slug, assume_exists: true)
      self
    end

    def with_params(**params)
      @params = params
      self
    end

    def with_headers(**headers)
      @headers = headers
      self
    end

    def with_metadata(**metadata)
      @metadata = @metadata.merge(metadata)
      self
    end

    def with_schema(schema)
      schema_instance = schema.is_a?(Class) ? schema.new : schema

      # Accept both RubyLLM::Schema instances and plain JSON schemas
      @schema = if schema_instance.respond_to?(:to_json_schema)
                  schema_instance.to_json_schema[:schema]
                else
                  schema_instance
                end

      self
    end

    def on_new_message(&block)
      @on[:new_message] = block
      self
    end

    def on_end_message(&block)
      @on[:end_message] = block
      self
    end

    def on_tool_call(&block)
      @on[:tool_call] = block
      self
    end

    def on_tool_result(&block)
      @on[:tool_result] = block
      self
    end

    def each(&)
      messages.each(&)
    end

    def complete(&)
      # Skip instrumentation for streaming (not supported yet)
      return complete_without_instrumentation(&) if block_given?

      Instrumentation.tracer.in_span('ruby_llm.chat', kind: Instrumentation::SpanKind::CLIENT) do |span|
        complete_with_span(span, &)
      end
    end

    private

    def complete_without_instrumentation(&)
      response = @provider.complete(
        messages,
        tools: @tools,
        temperature: @temperature,
        model: @model,
        params: @params,
        headers: @headers,
        schema: @schema,
        &wrap_streaming_block(&)
      )

      finalize_response(response, &)
    end

    def complete_with_span(span, &)
      # Set request attributes
      if span.recording?
        span.add_attributes(
          Instrumentation::SpanBuilder.build_request_attributes(
            model: @model,
            provider: @provider.slug,
            session_id: @session_id,
            temperature: @temperature,
            metadata: @metadata
          )
        )

        # Log message content if enabled
        if @config.tracing_log_content
          span.add_attributes(
            Instrumentation::SpanBuilder.build_message_attributes(
              messages,
              max_length: @config.tracing_max_content_length
            )
          )
        end
      end

      response = @provider.complete(
        messages,
        tools: @tools,
        temperature: @temperature,
        model: @model,
        params: @params,
        headers: @headers,
        schema: @schema
      )

      # Add response attributes
      if span.recording?
        span.add_attributes(Instrumentation::SpanBuilder.build_response_attributes(response))

        if @config.tracing_log_content
          span.add_attributes(
            Instrumentation::SpanBuilder.build_completion_attributes(
              response,
              max_length: @config.tracing_max_content_length
            )
          )
        end
      end

      finalize_response(response, &)
    rescue StandardError => e
      record_span_error(span, e)
      raise
    end

    def record_span_error(span, exception)
      return unless span.recording?

      span.record_exception(exception)
      return unless defined?(OpenTelemetry::Trace::Status)

      span.status = OpenTelemetry::Trace::Status.error(exception.message)
    end

    def finalize_response(response, &) # rubocop:disable Metrics/PerceivedComplexity
      @on[:new_message]&.call unless block_given?

      if @schema && response.content.is_a?(String)
        begin
          response.content = JSON.parse(response.content)
        rescue JSON::ParserError
          # If parsing fails, keep content as string
        end
      end

      add_message response
      @on[:end_message]&.call(response)

      if response.tool_call?
        handle_tool_calls(response, &)
      else
        response
      end
    end

    public

    def add_message(message_or_attributes)
      message = message_or_attributes.is_a?(Message) ? message_or_attributes : Message.new(message_or_attributes)
      messages << message
      message
    end

    def reset_messages!
      @messages.clear
    end

    def instance_variables
      super - %i[@connection @config]
    end

    private

    def wrap_streaming_block(&block)
      return nil unless block_given?

      first_chunk_received = false

      proc do |chunk|
        # Create message on first content chunk
        unless first_chunk_received
          first_chunk_received = true
          @on[:new_message]&.call
        end

        block.call chunk
      end
    end

    def handle_tool_calls(response, &) # rubocop:disable Metrics/PerceivedComplexity
      halt_result = nil

      response.tool_calls.each_value do |tool_call|
        @on[:new_message]&.call
        @on[:tool_call]&.call(tool_call)
        result = execute_tool tool_call
        @on[:tool_result]&.call(result)
        tool_payload = result.is_a?(Tool::Halt) ? result.content : result
        content = content_like?(tool_payload) ? tool_payload : tool_payload.to_s
        message = add_message role: :tool, content:, tool_call_id: tool_call.id
        @on[:end_message]&.call(message)

        halt_result = result if result.is_a?(Tool::Halt)
      end

      halt_result || complete(&)
    end

    def execute_tool(tool_call)
      Instrumentation.tracer.in_span('ruby_llm.tool', kind: Instrumentation::SpanKind::INTERNAL) do |span|
        execute_tool_with_span(tool_call, span)
      end
    end

    def execute_tool_with_span(tool_call, span)
      tool = tools[tool_call.name.to_sym]
      args = tool_call.arguments

      if span.recording?
        span.add_attributes(
          Instrumentation::SpanBuilder.build_tool_attributes(
            tool_call: tool_call,
            session_id: @session_id
          )
        )

        if @config.tracing_log_content
          span.add_attributes(
            Instrumentation::SpanBuilder.build_tool_input_attributes(
              tool_call: tool_call,
              max_length: @config.tracing_max_content_length
            )
          )
        end
      end

      result = tool.call(args)

      if span.recording? && @config.tracing_log_content
        span.add_attributes(
          Instrumentation::SpanBuilder.build_tool_output_attributes(
            result: result,
            max_length: @config.tracing_max_content_length
          )
        )
      end

      result
    rescue StandardError => e
      record_span_error(span, e)
      raise
    end

    def build_content(message, attachments)
      return message if content_like?(message)

      Content.new(message, attachments)
    end

    def content_like?(object)
      object.is_a?(Content) || object.is_a?(Content::Raw)
    end
  end
end
