# frozen_string_literal: true

module RubyLLM
  # Represents a conversation with an AI model
  class Chat
    include Enumerable

    attr_reader :model, :messages, :tools, :tool_prefs, :params, :headers, :schema

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
      @messages_scope = nil
      @tools = {}
      @tool_prefs = { choice: nil, parallel: nil }
      @params = {}
      @headers = {}
      @schema = nil
      @thinking = nil
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

    def with_instructions(instructions, append: false, replace: nil)
      append ||= (replace == false) unless replace.nil?

      if append
        append_system_instruction(instructions)
      else
        replace_system_instruction(instructions)
      end

      self
    end

    def with_tool(tool, choice: nil, parallel: nil)
      unless tool.nil?
        tool_instance = tool.is_a?(Class) ? tool.new : tool
        @tools[tool_instance.name.to_sym] = tool_instance
      end
      update_tool_options(choice:, parallel:)
      self
    end

    def with_tools(*tools, replace: false, choice: nil, parallel: nil)
      @tools.clear if replace
      tools.compact.each { |tool| with_tool tool }
      update_tool_options(choice:, parallel:)
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

    def with_thinking(effort: nil, budget: nil)
      raise ArgumentError, 'with_thinking requires :effort or :budget' if effort.nil? && budget.nil?

      @thinking = Thinking::Config.new(effort: effort, budget: budget)
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

    def with_messages(&block)
      if block.nil?
        @messages_scope = nil
        return self
      end

      @messages_scope = block
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
      response = @provider.complete(
        scoped_messages,
        tools: @tools,
        tool_prefs: @tool_prefs,
        temperature: @temperature,
        model: @model,
        params: @params,
        headers: @headers,
        schema: @schema,
        thinking: @thinking,
        &wrap_streaming_block(&)
      )

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

    def scoped_messages
       @messages_scope ? @messages_scope.call(messages) : messages
    end

    def wrap_streaming_block(&block)
      return nil unless block_given?

      @on[:new_message]&.call

      proc do |chunk|
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

      reset_tool_choice if forced_tool_choice?
      halt_result || complete(&)
    end

    def execute_tool(tool_call)
      tool = tools[tool_call.name.to_sym]
      if tool.nil?
        return {
          error: "Model tried to call unavailable tool `#{tool_call.name}`. " \
                 "Available tools: #{tools.keys.to_json}."
        }
      end

      args = tool_call.arguments
      tool.call(args)
    end

    def update_tool_options(choice:, parallel:)
      unless choice.nil?
        normalized_choice = normalize_tool_choice(choice)
        valid_tool_choices = %i[auto none required] + tools.keys
        unless valid_tool_choices.include?(normalized_choice)
          raise InvalidToolChoiceError,
                "Invalid tool choice: #{choice}. Valid choices are: #{valid_tool_choices.join(', ')}"
        end

        @tool_prefs[:choice] = normalized_choice
      end

      @tool_prefs[:parallel] = !!parallel unless parallel.nil?
    end

    def normalize_tool_choice(choice)
      return choice.to_sym if choice.is_a?(String) || choice.is_a?(Symbol)
      return tool_name_for_choice_class(choice) if choice.is_a?(Class)

      choice.respond_to?(:name) ? choice.name.to_sym : choice.to_sym
    end

    def tool_name_for_choice_class(tool_class)
      matched_tool_name = tools.find { |_name, tool| tool.is_a?(tool_class) }&.first
      return matched_tool_name if matched_tool_name

      classify_tool_name(tool_class.name)
    end

    def classify_tool_name(class_name)
      class_name.split('::').last
                .gsub(/([a-z\d])([A-Z])/, '\1_\2')
                .downcase
                .to_sym
    end

    def forced_tool_choice?
      @tool_prefs[:choice] && !%i[auto none].include?(@tool_prefs[:choice])
    end

    def reset_tool_choice
      @tool_prefs[:choice] = nil
    end

    def build_content(message, attachments)
      return message if content_like?(message)

      Content.new(message, attachments)
    end

    def content_like?(object)
      object.is_a?(Content) || object.is_a?(Content::Raw)
    end

    def append_system_instruction(instructions)
      system_messages, non_system_messages = @messages.partition { |msg| msg.role == :system }
      system_messages << Message.new(role: :system, content: instructions)
      @messages = system_messages + non_system_messages
    end

    def replace_system_instruction(instructions)
      system_messages, non_system_messages = @messages.partition { |msg| msg.role == :system }

      if system_messages.empty?
        system_messages = [Message.new(role: :system, content: instructions)]
      else
        system_messages.first.content = instructions
        system_messages = [system_messages.first]
      end

      @messages = system_messages + non_system_messages
    end
  end
end
