# frozen_string_literal: true

require 'json'

module RubyLLM
  # Represents a conversation with an AI model. Handles message history,
  # streaming responses, and tool integration with a simple, conversational API.
  #
  # Example:
  #   chat = RubyLLM.chat
  #   chat.ask "What's the best way to learn Ruby?"
  #   chat.ask "Can you elaborate on that?"
  class Chat # rubocop:disable Metrics/ClassLength
    include Enumerable

    attr_reader :model, :messages, :tools, :output_schema

    def initialize(model: nil, provider: nil, assume_model_exists: false) # rubocop:disable Metrics/MethodLength
      if assume_model_exists && !provider
        raise ArgumentError, 'Provider must be specified if assume_model_exists is true'
      end

      model_id = model || RubyLLM.config.default_model
      with_model(model_id, provider: provider, assume_exists: assume_model_exists)
      @temperature = 0.7
      @messages = []
      @tools = {}
      @on = {
        new_message: nil,
        end_message: nil
      }
    end

    def ask(message = nil, with: {}, &block)
      add_message role: :user, content: Content.new(message, with)
      complete(&block)
    end

    alias say ask

    def with_instructions(instructions, replace: false)
      @messages = @messages.reject! { |msg| msg.role == :system } if replace

      add_message role: :system, content: instructions
      self
    end

    def with_tool(tool)
      unless @model.supports_functions
        raise UnsupportedFunctionsError, "Model #{@model.id} doesn't support function calling"
      end

      tool_instance = tool.is_a?(Class) ? tool.new : tool
      @tools[tool_instance.name.to_sym] = tool_instance
      self
    end

    def with_tools(*tools)
      tools.each { |tool| with_tool tool }
      self
    end

    def with_model(model_id, provider: nil, assume_exists: false) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
      if assume_exists
        raise ArgumentError, 'Provider must be specified if assume_exists is true' unless provider

        @provider = Provider.providers[provider.to_sym] || raise(Error, "Unknown provider: #{provider.to_sym}")
        @model = Struct.new(:id, :provider, :supports_functions, :supports_vision).new(model_id, provider, true, true)
        RubyLLM.logger.warn "Assuming model '#{model_id}' exists for provider '#{provider}'. " \
                            'Capabilities may not be accurately reflected.'
      else
        @model = Models.find model_id, provider
        @provider = Provider.providers[@model.provider.to_sym] || raise(Error, "Unknown provider: #{@model.provider}")
      end
      self
    end

    def with_temperature(temperature)
      @temperature = temperature
      self
    end

    # Specifies a JSON schema for structured output from the model
    # @param schema [Hash, String] JSON schema as a Hash or JSON string
    # @return [self] Returns self for method chaining
    # @raise [ArgumentError] If the schema is not a Hash or valid JSON string
    # @raise [UnsupportedStructuredOutputError] If the model doesn't support structured output
    def with_output_schema(schema, strict: true)
      schema = JSON.parse(schema) if schema.is_a?(String)
      raise ArgumentError, 'Schema must be a Hash' unless schema.is_a?(Hash)

      # Check if model supports structured output
      provider_module = Provider.providers[@model.provider.to_sym]
      if strict && !provider_module.supports_structured_output?(@model.id)
        raise UnsupportedStructuredOutputError, "Model #{@model.id} doesn't support structured output. \nUse with_output_schema(schema, strict:false) for less stict, more risky mode."
      end

      @output_schema = schema

      # Always add schema guidance - it will be appended if there's an existing system message
      add_system_schema_guidance(schema)

      self
    end

    # Adds a system message with guidance for JSON output based on the schema
    # If a system message already exists, it appends to it rather than replacing
    def add_system_schema_guidance(schema)
      # Create a more generalized prompt that works well across all providers
      # This is particularly helpful for OpenAI which requires "json" in the prompt
      guidance = <<~GUIDANCE
        You must format your output as a JSON value that adheres to the following schema:
        #{JSON.pretty_generate(schema)}

        Format your entire response as valid JSON that follows this schema exactly.
        Do not include explanations, markdown formatting, or any text outside the JSON.
      GUIDANCE

      # Check if we already have a system message
      system_message = messages.find { |msg| msg.role == :system }

      if system_message
        # Append to existing system message
        updated_content = "#{system_message.content}\n\n#{guidance}"
        # Remove the old system message
        @messages.delete(system_message)
        # Add the updated system message
        add_message(role: :system, content: updated_content)
      else
        # No system message exists, create a new one
        with_instructions(guidance)
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

    def each(&)
      messages.each(&)
    end

    def complete(&)
      @on[:new_message]&.call
      response = @provider.complete(messages, tools: @tools, temperature: @temperature, model: @model.id, chat: self, &)
      @on[:end_message]&.call(response)

      add_message response
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

    private

    def handle_tool_calls(response, &)
      response.tool_calls.each_value do |tool_call|
        @on[:new_message]&.call
        result = execute_tool tool_call
        message = add_tool_result tool_call.id, result
        @on[:end_message]&.call(message)
      end

      complete(&)
    end

    def execute_tool(tool_call)
      tool = tools[tool_call.name.to_sym]
      args = tool_call.arguments
      tool.call(args)
    end

    def add_tool_result(tool_use_id, result)
      add_message(
        role: :tool,
        content: result.is_a?(Hash) && result[:error] ? result[:error] : result.to_s,
        tool_call_id: tool_use_id
      )
    end
  end
end
