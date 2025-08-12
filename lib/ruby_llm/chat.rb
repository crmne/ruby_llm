# frozen_string_literal: true

module RubyLLM
  # Represents a conversation with an AI model. Handles message history,
  # streaming responses, and tool integration with a simple, conversational API.
  #
  # Example:
  #   chat = RubyLLM.chat
  #   chat.ask "What's the best way to learn Ruby?"
  #   chat.ask "Can you elaborate on that?"
  class Chat
    include Enumerable

    attr_reader :model, :messages, :tools, :params, :headers, :schema

    def initialize(model: nil, provider: nil, assume_model_exists: false, context: nil)
      if assume_model_exists && !provider
        raise ArgumentError, 'Provider must be specified if assume_model_exists is true'
      end

      @context = context
      @config = context&.config || RubyLLM.config
      model_id = model || @config.default_model
      with_model(model_id, provider: provider, assume_exists: assume_model_exists)
      @temperature = 0.7
      @messages = []
      @tools = {}
      @params = {}
      @headers = {}
      @schema = nil
      @batch_request = false
      @on = {
        new_message: nil,
        end_message: nil,
        tool_call: nil,
        tool_result: nil
      }
    end

    def ask(message = nil, with: nil, &)
      add_message role: :user, content: Content.new(message, with)
      complete(&)
    end

    alias say ask

    def with_instructions(instructions, replace: false)
      @messages = @messages.reject { |msg| msg.role == :system } if replace

      add_message role: :system, content: instructions
      self
    end

    def with_tool(tool)
      unless @model.supports_functions?
        raise UnsupportedFunctionsError, "Model #{@model.id} doesn't support function calling"
      end

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

    def with_schema(schema, force: false)
      unless force || @model.structured_output?
        raise UnsupportedStructuredOutputError, "Model #{@model.id} doesn't support structured output"
      end

      schema_instance = schema.is_a?(Class) ? schema.new : schema

      # Accept both RubyLLM::Schema instances and plain JSON schemas
      @schema = if schema_instance.respond_to?(:to_json_schema)
                  schema_instance.to_json_schema[:schema]
                else
                  schema_instance
                end

      self
    end

    def for_batch_request
      @batch_request = true
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

    def complete(&) # rubocop:disable Metrics/PerceivedComplexity
      # If batch_request mode is enabled, render and return the payload
      if @batch_request
        raise ArgumentError, 'Streaming is not supported for batch requests' if block_given?

        return @provider.render_payload_for_batch_request(
          messages,
          tools: @tools,
          temperature: @temperature,
          model: @model.id,
          params: @params,
          schema: @schema
        )
      end

      response = @provider.complete(
        messages,
        tools: @tools,
        temperature: @temperature,
        model: @model.id,
        params: @params,
        headers: @headers,
        schema: @schema,
        &wrap_streaming_block(&)
      )

      @on[:new_message]&.call unless block_given?

      # Parse JSON if schema was set
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

    def add_message(message_or_attributes)
      message = message_or_attributes.is_a?(Message) ? message_or_attributes : Message.new(message_or_attributes)
      messages << message
      message
    end

    def reset_messages!
      @messages.clear
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

        # Pass chunk to user's block
        block.call chunk
      end
    end

    def handle_tool_calls(response, &)
      halt_result = nil

      response.tool_calls.each_value do |tool_call|
        @on[:new_message]&.call
        @on[:tool_call]&.call(tool_call)
        result = execute_tool tool_call
        @on[:tool_result]&.call(result)
        message = add_message role: :tool, content: result.to_s, tool_call_id: tool_call.id
        @on[:end_message]&.call(message)

        halt_result = result if result.is_a?(Tool::Halt)
      end

      halt_result || complete(&)
    end

    def execute_tool(tool_call)
      tool = tools[tool_call.name.to_sym]
      args = tool_call.arguments
      tool.call(args)
    end

    def instance_variables
      super - %i[@connection @config]
    end
  end
end
