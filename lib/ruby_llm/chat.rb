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

    attr_reader :model, :messages, :tools, :response_format

    def initialize(model: nil, provider: nil, assume_model_exists: false, context: nil) # rubocop:disable Metrics/MethodLength
      if assume_model_exists && !provider
        raise ArgumentError, 'Provider must be specified if assume_model_exists is true'
      end

      @config = context&.config || RubyLLM.config
      model_id = model || @config.default_model
      with_model(model_id, provider: provider, assume_exists: assume_model_exists)
      @connection = context ? context.connection_for(@provider) : @provider.connection(@config)
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

    # Specifies the response format for the model
    # @param response_format [Hash, String, Symbol] Either:
    #   - :json symbol for JSON mode (model outputs valid JSON object)
    #   - JSON schema as a Hash or JSON string for schema-based output (model follows the schema)
    # @param assume_supported [Boolean] Whether to assume the model supports the requested format
    # @return [self] Returns self for method chaining
    # @raise [ArgumentError] If the response_format is not a Hash, valid JSON string, or :json symbol
    # @raise [UnsupportedJSONModeError] If :json is requested without model support
    # @raise [UnsupportedStructuredOutputError] If schema output is requested without model support
    def with_response_format(response_format, assume_supported: false)
      unless assume_supported
        if response_format == :json
          ensure_json_mode_support
        else
          ensure_response_format_support
        end
      end

      @response_format = response_format == :json ? :json : normalize_response_format(response_format)

      # Add appropriate guidance based on format
      if response_format == :json
        add_json_guidance
      elsif assume_supported
        # Needed for models that don't support structured output
        add_system_format_guidance
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

    def complete(&) # rubocop:disable Metrics/MethodLength
      @on[:new_message]&.call
      response = @provider.complete(
        messages,
        tools: @tools,
        temperature: @temperature,
        model: @model.id,
        response_format: @response_format,
        connection: @connection,
        &
      )
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

    # Normalizes the response format to a standard format
    # @param response_format [Hash, String] JSON schema as a Hash or JSON string
    # @return [Hash] Normalized schema as a Hash
    # @raise [ArgumentError] If the response_format is not a Hash or valid JSON string
    def normalize_response_format(response_format)
      schema_obj = response_format.is_a?(String) ? JSON.parse(response_format) : response_format
      schema_obj = schema_obj.json_schema if schema_obj.respond_to?(:json_schema)

      raise ArgumentError, 'Response format must be a Hash' unless schema_obj.is_a?(Hash)

      schema_obj
    end

    # Checks if the model supports JSON mode
    # @raise [UnsupportedJSONModeError] If JSON mode is not supported by the model
    def ensure_json_mode_support
      provider_module = Provider.providers[@model.provider.to_sym]
      return if provider_module.supports_json_mode?(@model.id)

      raise UnsupportedJSONModeError,
            "Model #{@model.id} doesn't support JSON mode. \n" \
            'Use with_response_format(:json, assume_supported: true) to skip compatibility check.'
    end

    # Checks if the model supports structured output with JSON schema
    # @raise [UnsupportedStructuredOutputError] If structured output is not supported by the model
    def ensure_response_format_support
      provider_module = Provider.providers[@model.provider.to_sym]
      return if provider_module.supports_structured_output?(@model.id)

      raise UnsupportedStructuredOutputError,
            "Model #{@model.id} doesn't support structured output. \n" \
            'Use with_response_format(schema, assume_supported: true) to skip compatibility check.'
    end

    # Adds system message guidance for schema-based JSON output
    # If a system message already exists, it appends to it rather than replacing
    # @return [self] Returns self for method chaining
    def add_system_format_guidance
      guidance = <<~GUIDANCE
        You must format your output as a JSON value that adheres to the following schema:
        #{JSON.pretty_generate(@response_format)}

        Format your entire response as valid JSON that follows this schema exactly.
        Do not include explanations, markdown formatting, or any text outside the JSON.
      GUIDANCE

      update_or_create_system_message(guidance)
      self
    end

    # Adds guidance for simple JSON output format
    # @return [self] Returns self for method chaining
    def add_json_guidance
      guidance = <<~GUIDANCE
        You must format your output as a valid JSON object.
        Format your entire response as valid JSON.
        Do not include explanations, markdown formatting, or any text outside the JSON.
      GUIDANCE

      update_or_create_system_message(guidance)
      self
    end

    # Updates existing system message or creates a new one with the guidance
    # @param guidance [String] Guidance text to add to system message
    def update_or_create_system_message(guidance)
      system_message = messages.find { |msg| msg.role == :system }

      if system_message
        # Append to existing system message
        updated_content = "#{system_message.content}\n\n#{guidance}"
        @messages.delete(system_message)
        add_message(role: :system, content: updated_content)
      elsif
        # No system message exists, create a new one
        with_instructions(guidance)
      end
    end

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
