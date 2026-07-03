# frozen_string_literal: true

require 'json'

module RubyLLM
  # Represents a conversation with an AI model
  class Chat
    include Enumerable

    attr_reader :model, :provider, :messages, :tools, :tool_prefs, :params, :headers, :schema, :concurrency,
                :caching, :fallbacks, :fallback_errors

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
      @tool_prefs = { choice: nil, calls: nil }
      @concurrency = normalize_tool_concurrency(@config.tool_concurrency)
      @params = {}
      @headers = {}
      @schema = nil
      @thinking = nil
      @citations = false
      @caching = nil
      @protocol = nil
      @fallbacks = []
      @fallback_errors = Fallback::DEFAULT_ERRORS
      @callbacks = Hash.new { |callbacks, name| callbacks[name] = [] }
    end

    def ask(message = nil, with: nil, &)
      ask_later(message, with: with)
      complete(&)
    end

    alias say ask

    # Stages a question without asking it, leaving the chat for `complete`, a
    # single `step`, or a provider-side batch via RubyLLM.batch.
    def ask_later(message = nil, with: nil)
      add_message role: :user, content: build_content(message, with)
      self
    end

    # Calls the model once and appends its response. The model's move.
    def generate(&)
      return generate_once(&) if fallbacks.empty?

      with_model_restored { generate_with_fallbacks(&) }
    end

    # Executes the pending tool calls and appends their results, without asking
    # the model to respond. Our move; the chat is then ready for the next
    # `generate`, or the next batch round.
    def run_tools
      message = last_non_system_message
      execute_pending_tool_calls(message) if message&.tool_call?
      self
    end

    # Advances the conversation by one move: runs the pending tools if the model
    # asked for them, otherwise generates the next response. Returns nil once
    # there is nothing left to do.
    def step(&)
      return if complete?

      last_non_system_message&.tool_call? ? run_tools : generate(&)
    end

    # Runs the agentic loop to completion: step until nothing is left.
    def complete(&)
      step(&) until complete?
      last_non_system_message || messages.last
    end

    # Whether the model owes this chat nothing more: nothing is staged, or it
    # answered without calling a tool.
    def complete?
      last = last_non_system_message
      case last&.role
      when nil then true
      when :user, :tool then false
      else !last.tool_call?
      end
    end

    def with_instructions(instructions, append: false)
      append ? append_system_instruction(instructions) : replace_system_instruction(instructions)
      self
    end

    def with_tool(tool, choice: nil, calls: nil, concurrency: @concurrency)
      unless tool.nil?
        tool_instance = tool.is_a?(Class) ? tool.new : tool
        @tools[tool_instance.name.to_sym] = tool_instance
      end
      update_tool_options(choice:, calls:)
      update_tool_concurrency(concurrency)
      self
    end

    def with_tools(*tools, replace: false, choice: nil, calls: nil, concurrency: @concurrency)
      @tools.clear if replace
      tools.compact.each { |tool| with_tool tool }
      update_tool_options(choice:, calls:)
      update_tool_concurrency(concurrency)
      self
    end

    def with_model(model_id, provider: nil, assume_exists: false)
      @model, @provider = Models.resolve(model_id, provider:, assume_exists:, config: @config)
      @connection = @provider.connection
      self
    end

    def with_fallbacks(*models, on: Fallback::DEFAULT_ERRORS)
      @fallbacks = models.flatten.compact.map { |model| Fallback.build(model) }
      @fallback_errors = Array(on).flatten.compact
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

    def with_citations(enabled = true) # rubocop:disable Style/OptionalBooleanParameter
      @citations = enabled
      self
    end

    def with_caching(**options)
      @caching = options.transform_keys(&:to_sym).freeze
      self
    end

    def without_caching
      @caching = nil
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

    def with_protocol(protocol)
      @protocol = protocol
      self
    end

    def with_headers(**headers)
      @headers = headers
      self
    end

    def with_schema(schema)
      schema_instance = schema.is_a?(Class) ? schema.new : schema

      @schema = normalize_schema_payload(
        schema_instance.respond_to?(:to_json_schema) ? schema_instance.to_json_schema : schema_instance
      )

      self
    end

    def before_message(&)
      add_callback(:before_message, &)
    end

    def after_message(&)
      add_callback(:after_message, &)
    end

    def before_tool_call(&)
      add_callback(:before_tool_call, &)
    end

    def after_tool_result(&)
      add_callback(:after_tool_result, &)
    end

    def before_fallback(&)
      add_callback(:before_fallback, &)
    end

    def after_fallback(&)
      add_callback(:after_fallback, &)
    end

    def each(&)
      messages.each(&)
    end

    def cost
      Cost.aggregate(messages.map { |message| message.cost(model: message.model_info || model) })
    end

    def messages=(new_messages)
      @messages = message_list(new_messages).map { |message| coerce_message(message) }
    end

    def add_message(message_or_attributes)
      message = coerce_message(message_or_attributes)
      message = @provider.preprocess_message(message, model: @model, protocol: @protocol) if @provider
      messages << message
      message
    end

    def cache_until_here!
      message = messages.last
      raise ArgumentError, 'No messages to cache' unless message

      message.cache_until_here!
      self
    end

    # Receives a completion produced out-of-band (e.g. by a batch), running the
    # same callbacks as a synchronous completion so persistence works unchanged.
    def add_completion(response)
      run_callbacks(:before_message)
      normalize_schema_response(response)
      add_message response
      run_callbacks(:after_message, response)
      response
    end

    # The request this chat would send for its next completion.
    def render
      @provider.render(
        messages,
        tools: @tools,
        tool_prefs: @tool_prefs,
        temperature: @temperature,
        model: @model,
        params: @params,
        schema: @schema,
        thinking: @thinking,
        citations: @citations,
        caching: @caching,
        protocol: @protocol
      )
    end

    # Keeps the connection and config dumps out of pretty-printed output.
    def pretty_print_instance_variables
      super - %i[@connection @config]
    end

    private

    def message_list(new_messages)
      return [] if new_messages.nil?
      if new_messages.is_a?(Hash) || new_messages.is_a?(Message) || new_messages.respond_to?(:to_llm)
        return [new_messages]
      end

      new_messages.respond_to?(:to_a) ? new_messages.to_a : [new_messages]
    end

    def coerce_message(message_or_attributes)
      message = if message_or_attributes.respond_to?(:to_llm)
                  message_or_attributes.to_llm
                else
                  message_or_attributes
                end

      message.is_a?(Message) ? message : Message.new(message)
    end

    def normalize_schema_payload(raw_schema)
      return nil if raw_schema.nil?
      return raw_schema unless raw_schema.is_a?(Hash)

      schema = RubyLLM::Utils.deep_symbolize_keys(raw_schema)
      schema_def = extract_schema_definition(schema)
      strict = extract_schema_strict(schema, schema_def)
      build_schema_payload(schema, schema_def, strict)
    end

    def extract_schema_definition(schema)
      RubyLLM::Utils.deep_dup(schema[:schema] || schema)
    end

    def extract_schema_strict(schema, schema_def)
      return schema[:strict] if schema.key?(:strict)
      return schema_def.delete(:strict) if schema_def.is_a?(Hash)

      nil
    end

    def build_schema_payload(schema, schema_def, strict)
      {
        name: sanitize_schema_name(schema[:name] || 'response'),
        schema: schema_def,
        strict: strict.nil? || strict,
        description: schema[:description]
      }.compact
    end

    def sanitize_schema_name(name)
      sanitized = name.to_s.gsub(/[^a-zA-Z0-9_-]/, '_')
      sanitized.empty? ? 'response' : sanitized
    end

    def add_callback(name, &block)
      @callbacks[name] << block if block
      self
    end

    def generate_once(stream_tracker: nil, &block)
      result = nil
      payload = instrumentation_payload(streaming: block_given?)

      RubyLLM.instrument('chat.ruby_llm', payload, config: @config) do |event|
        result = provider_completion(stream_tracker:, &block)
        run_callbacks(:before_message) unless block_given?
        normalize_schema_response(result)
        add_message result
        run_callbacks(:after_message, result)
        record_completion_event(event, result)
      end
      result
    end

    def instrumentation_payload(streaming:)
      {
        chat: self,
        provider: @provider.slug,
        provider_class: @provider.class.display_name,
        model: @model.id,
        model_info: @model,
        input_messages: messages.dup,
        message_count: messages.size,
        tools: tools.keys,
        tool_choice: tool_prefs[:choice],
        tool_call_limit: tool_prefs[:calls],
        temperature: @temperature,
        params: params,
        schema: schema,
        thinking: @thinking,
        citations: @citations,
        caching: @caching,
        streaming: streaming
      }
    end

    def record_completion_event(event, result)
      event[:response] = result
      event[:messages_after] = messages.dup
      event[:response_role] = result.role if result.respond_to?(:role)
      return unless result.respond_to?(:tool_call?)

      event[:response_model] = result.model_id
      event[:tool_call] = result.tool_call?
      event[:tool_calls] = result.tool_calls
      event[:input_tokens] = result.input_tokens
      event[:output_tokens] = result.output_tokens
      event[:cached_tokens] = result.cached_tokens
      event[:cache_creation_tokens] = result.cache_creation_tokens
      event[:thinking_tokens] = result.thinking_tokens
    end

    def generate_with_fallbacks(&block)
      fallback_queue = fallbacks.dup
      attempt = 0
      active_fallback = nil
      streaming = block_given?

      loop do
        chunks_yielded = false

        begin
          result = generate_once(stream_tracker: proc { chunks_yielded = true }, &block)
          finish_fallback(active_fallback, response: result)
          return result
        rescue StandardError => e
          raise e unless fallback_error?(e)

          finish_fallback(active_fallback, fallback_error: e)
          active_fallback, attempt = fallback_to_next_model!(
            fallback_queue,
            error: e,
            attempt: attempt,
            streaming: streaming,
            chunks_yielded: chunks_yielded
          )
        end
      end
    end

    def with_model_restored
      original_model = @model
      original_provider = @provider
      original_connection = @connection

      yield
    ensure
      @model = original_model
      @provider = original_provider
      @connection = original_connection
    end

    def switch_to_fallback_model(fallback)
      return with_resolved_model(fallback.model) if fallback.model

      with_model(fallback.id, provider: fallback.provider)
    end

    def with_resolved_model(model)
      provider_class = Provider.resolve!(model.provider)
      @model = model
      @provider = provider_class.new(@config)
      @connection = @provider.connection
      self
    end

    def fallback_to_next_model!(fallback_queue, error:, attempt:, streaming:, chunks_yielded:)
      fallback = fallback_queue.shift
      raise error unless fallback

      attempt += 1
      from_model = @model
      switch_to_fallback_model(fallback)
      fallback = fallback.with_attempt(
        chat: self,
        error: error,
        from: from_model,
        to: @model,
        attempt: attempt,
        streaming: streaming,
        chunks_yielded: chunks_yielded
      )
      run_callbacks(:before_fallback, fallback)
      [fallback, attempt]
    end

    def finish_fallback(fallback, response: nil, fallback_error: nil)
      return unless fallback

      fallback.finish(response: response, fallback_error: fallback_error)
      run_callbacks(:after_fallback, fallback)
    end

    def fallback_error?(error)
      fallback_errors.any? { |error_class| error.is_a?(error_class) }
    end

    def provider_completion(stream_tracker: nil, &)
      @provider.complete(
        messages,
        tools: @tools,
        tool_prefs: @tool_prefs,
        temperature: @temperature,
        model: @model,
        params: @params,
        headers: @headers,
        schema: @schema,
        thinking: @thinking,
        citations: @citations,
        caching: @caching,
        protocol: @protocol,
        &wrap_streaming_block(stream_tracker:, &)
      )
    end

    def normalize_schema_response(response)
      return unless @schema && response.content.is_a?(String) && !response.tool_call?

      response.content = JSON.parse(response.content)
    rescue JSON::ParserError
      # If parsing fails, keep content as string.
    end

    def run_callbacks(name, *args)
      @callbacks[name].each { |callback| callback.call(*args) }
    end

    def wrap_streaming_block(stream_tracker: nil, &block)
      return nil unless block

      run_callbacks(:before_message)

      proc do |chunk|
        stream_tracker&.call(chunk)
        block.call(chunk)
      end
    end

    def execute_pending_tool_calls(response)
      if concurrency
        handle_concurrent_tool_calls(response.tool_calls)
      else
        handle_sequential_tool_calls(response.tool_calls)
      end

      reset_tool_choice if forced_tool_choice?
    end

    def handle_sequential_tool_calls(tool_calls)
      tool_calls.each_value do |tool_call|
        run_callbacks(:before_message)
        result = execute_tool_with_callbacks(tool_call)
        add_tool_result_message(tool_call, result)
      end
    end

    def handle_concurrent_tool_calls(tool_calls)
      execute_tools_concurrently(tool_calls) do |tool_call, result|
        run_callbacks(:before_message)
        add_tool_result_message(tool_call, result)
      end
    end

    def execute_tools_concurrently(tool_calls, &on_result)
      ToolConcurrency.run(concurrency, tool_calls, on_result:) do |tool_call|
        execute_tool_with_callbacks(tool_call)
      end
    end

    def execute_tool_with_callbacks(tool_call)
      run_callbacks(:before_tool_call, tool_call)
      result = execute_tool tool_call
      run_callbacks(:after_tool_result, result)
      result
    end

    def add_tool_result_message(tool_call, result)
      content = content_like?(result) ? result : result.to_s
      message = add_message role: :tool, content:, tool_call_id: tool_call.id
      run_callbacks(:after_message, message)
      message
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
      payload = {
        chat: self,
        provider: @provider.slug,
        provider_class: @provider.class.display_name,
        model: @model.id,
        model_info: @model,
        tool: tool,
        tool_call: tool_call,
        tool_name: tool.name,
        tool_arguments: args,
        tool_call_id: tool_call.id
      }

      RubyLLM.instrument('tool_call.ruby_llm', payload, config: @config) do |event|
        result = tool.call(args)
        event[:result] = result
        event[:result_content] = result
        event[:result_class] = result.class.name
        result
      end
    end

    def update_tool_options(choice:, calls:)
      unless choice.nil?
        normalized_choice = normalize_tool_choice(choice)
        valid_tool_choices = %i[auto none required] + tools.keys
        unless valid_tool_choices.include?(normalized_choice)
          raise InvalidToolChoiceError,
                "Invalid tool choice: #{choice}. Valid choices are: #{valid_tool_choices.join(', ')}"
        end

        @tool_prefs[:choice] = normalized_choice
      end

      @tool_prefs[:calls] = normalize_calls(calls) unless calls.nil?
    end

    def update_tool_concurrency(concurrency)
      @concurrency = normalize_tool_concurrency(concurrency)
    end

    def normalize_tool_concurrency(concurrency)
      return nil if concurrency.nil? || concurrency == false
      return :threads if concurrency == true

      normalized = concurrency.to_sym
      return normalized if ToolConcurrency::MODES.include?(normalized)

      raise ArgumentError,
            "Unknown tool concurrency: #{concurrency.inspect}. " \
            "Available modes: #{ToolConcurrency::MODES.join(', ')}"
    end

    def normalize_calls(calls)
      case calls
      when :many, 'many'
        :many
      when :one, 'one', 1
        :one
      else
        raise ArgumentError, "Invalid calls value: #{calls.inspect}. Valid values are: :many, :one, or 1"
      end
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
      Utils.underscore(class_name.split('::').last).delete_suffix('_tool').to_sym
    end

    def forced_tool_choice?
      @tool_prefs[:choice] && !%i[auto none].include?(@tool_prefs[:choice])
    end

    def reset_tool_choice
      @tool_prefs[:choice] = nil
    end

    def last_non_system_message
      messages.reverse.find { |message| message.role != :system }
    end

    def build_content(message, attachments)
      return message if content_like?(message)

      Content.new(message, attachments)
    end

    def content_like?(object)
      object.is_a?(Content) || object.is_a?(Content::Raw)
    end

    def append_system_instruction(instructions)
      message = Message.new(role: :system, content: instructions)
      @messages << message
      message
    end

    def replace_system_instruction(instructions)
      @messages.reject! { |msg| msg.role == :system }
      append_system_instruction(instructions)
    end
  end
end
