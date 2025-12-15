# frozen_string_literal: true

module RubyLLM
  # Represents a conversation with an AI model
  class Chat
    include Enumerable

    attr_reader :model, :messages, :tools, :params, :headers, :schema

    # Stores multiple callbacks per key and invokes all of them.
    #
    # Internally we keep a callable per event (via `callback_for`) so higher
    # level code can safely chain callbacks without overwriting persistence.
    class CallbackFanout
      def initialize
        @callbacks = Hash.new { |h, k| h[k] = [] }
      end

      def add(key, callable)
        return unless callable

        @callbacks[key] << callable
      end

      def callback_for(key)
        callbacks = @callbacks[key]
        return if callbacks.empty?

        ->(*args) { callbacks.each { |cb| cb.call(*args) } }
      end
    end

    def initialize(model: nil, provider: nil, assume_model_exists: false, context: nil)
      if assume_model_exists && !provider
        raise ArgumentError, 'Provider must be specified if assume_model_exists is true'
      end

      @context = context
      @config = context&.config || RubyLLM.config
      model_id = model || @config.default_model
      with_model(model_id, provider: provider, assume_exists: assume_model_exists)
      @temperature = nil
      @messages = []
      @tools = {}
      @params = {}
      @headers = {}
      @schema = nil
      @on = CallbackFanout.new
    end

    def ask(message = nil, with: nil, &block)
      add_message role: :user, content: Content.new(message, with)
      complete(&block)
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
      @model, @provider = Models.resolve(model_id, provider: provider, assume_exists: assume_exists, config: @config)
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
      @on.add(:new_message, block)
      self
    end

    def on_end_message(&block)
      @on.add(:end_message, block)
      self
    end

    def on_tool_call(&block)
      @on.add(:tool_call, block)
      self
    end

    def on_tool_result(&block)
      @on.add(:tool_result, block)
      self
    end

    def each(&block)
      messages.each(&block)
    end

    def complete(&block) # rubocop:disable Metrics/PerceivedComplexity
      response = @provider.complete(
        messages,
        tools: @tools,
        temperature: @temperature,
        model: @model,
        params: @params,
        headers: @headers,
        schema: @schema,
        &wrap_streaming_block(&block)
      )

      callback_for(:new_message)&.call unless block

      if @schema && response.content.is_a?(String)
        begin
          response.content = JSON.parse(response.content)
        rescue JSON::ParserError
          # If parsing fails, keep content as string
        end
      end

      add_message response
      callback_for(:end_message)&.call(response)

      if response.tool_call?
        handle_tool_calls(response, &block)
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

    def instance_variables
      super - %i[@connection @config]
    end

    private

    def callback_for(key)
      @on.callback_for(key)
    end

    def wrap_streaming_block(&block)
      return nil unless block_given?

      first_chunk_received = false

      proc do |chunk|
        # Create message on first content chunk
        unless first_chunk_received
          first_chunk_received = true
          callback_for(:new_message)&.call
        end

        block.call chunk
      end
    end

    def handle_tool_calls(response, &block) # rubocop:disable Metrics/PerceivedComplexity
      halt_result = nil

      response.tool_calls.each_value do |tool_call|
        callback_for(:new_message)&.call
        callback_for(:tool_call)&.call(tool_call)
        result = execute_tool tool_call
        callback_for(:tool_result)&.call(result)
        content = result.is_a?(Content) ? result : result.to_s
        message = add_message role: :tool, content: content, tool_call_id: tool_call.id
        callback_for(:end_message)&.call(message)

        halt_result = result if result.is_a?(Tool::Halt)
      end

      halt_result || complete(&block)
    end

    def execute_tool(tool_call)
      tool = tools[tool_call.name.to_sym]
      args = tool_call.arguments
      tool.call(args)
    end
  end
end
