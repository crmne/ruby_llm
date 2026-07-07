# frozen_string_literal: true

require 'json'

module RubyLLM
  # A Chat is a conversation with an AI model. It holds the messages
  # exchanged so far, the tools the model may call, and the settings applied
  # to each request. RubyLLM.chat is the usual way to create one.
  #
  #   chat = RubyLLM.chat
  #   chat.ask "What's the best way to learn Ruby?"
  #
  # Configuration methods return +self+, so calls chain:
  #
  #   chat = RubyLLM.chat(model: 'claude-sonnet-4-5')
  #   chat.with_instructions("Be terse.").with_tools(Weather)
  #
  # #ask runs the agentic loop to completion, executing tool calls until the
  # model produces a final answer. #ask_later, #generate, #run_tools, and
  # #step expose the individual moves of that loop.
  #
  # A Chat is Enumerable over its messages.
  class Chat
    include Enumerable

    # The Model the chat sends requests to.
    attr_reader :model

    # The Provider instance handling requests for the current model.
    attr_reader :provider

    # The Message objects exchanged so far, including system instructions.
    attr_reader :messages

    # The registered tools, as a Hash of tool name Symbols to Tool instances.
    attr_reader :tools

    # Extra request options set with #with_provider_options, expressed in
    # the provider's request vocabulary.
    attr_reader :provider_options

    # Extra HTTP headers set with #with_headers.
    attr_reader :headers

    # The normalized structured output schema set with #with_schema, or +nil+.
    attr_reader :schema

    # The tool concurrency mode, or +nil+ when tools run sequentially.
    attr_reader :concurrency

    # The prompt caching options set with #with_caching, or +nil+.
    attr_reader :caching

    # The Fallback models tried in order when generation fails.
    attr_reader :fallbacks

    attr_reader :tool_prefs, :fallback_errors # :nodoc:

    # Creates a chat with +model:+, or with the configured default model
    # when +model:+ is +nil+. Most code calls RubyLLM.chat instead.
    #
    # A model is identified by its name, an optional +provider:+, and an
    # optional +protocol:+. Pass +provider:+ to disambiguate models
    # available from several providers, and +protocol:+ to override the wire
    # protocol the provider would otherwise pick for the model. With
    # <tt>assume_model_exists: true</tt> the registry lookup is skipped,
    # which requires +provider:+. Pass a Context as +context:+ to use its
    # configuration instead of the global one.
    def initialize(model: nil, provider: nil, protocol: nil, assume_model_exists: false, context: nil)
      if assume_model_exists && !provider
        raise ArgumentError, 'Provider must be specified if assume_model_exists is true'
      end

      @context = context
      @config = context&.config || RubyLLM.config
      with_model(model, provider: provider, protocol: protocol, assume_model_exists: assume_model_exists)
      @temperature = nil
      @max_output_tokens = nil
      @messages = []
      @tools = {}
      reset_tools
      @provider_options = {}
      @headers = {}
      @schema = nil
      @thinking = nil
      @citations = false
      @caching = nil
      @fallbacks = []
      @fallback_errors = Fallback::DEFAULT_ERRORS
      @callbacks = Hash.new { |callbacks, name| callbacks[name] = [] }
    end

    # Adds +message+ to the conversation as a user message and runs the
    # agentic loop to completion, executing tool calls along the way.
    # Returns the final assistant Message. Attach files with +with:+.
    # A given block receives streamed Chunk objects as they arrive.
    #
    #   chat.ask "What's the best way to learn Ruby?"
    #   chat.ask "What's in this image?", with: "ruby_conf.jpg"
    #   chat.ask "Analyze these files", with: ["diagram.png", "report.pdf"]
    #   chat.ask("Tell me a story") { |chunk| print chunk.content }
    #
    def ask(message = nil, with: nil, &)
      ask_later(message, with: with)
      complete(&)
    end

    alias say ask

    # Stages +message+ as a user message without requesting a completion,
    # leaving the chat ready for #complete, a single #step, or a
    # provider-side batch via RubyLLM.batch. Accepts attachments with
    # +with:+ like #ask. Returns +self+.
    #
    #   chats = tickets.map { |t| RubyLLM.chat.ask_later(t.body) }
    #   RubyLLM.batch(chats)
    #
    def ask_later(message = nil, with: nil)
      add_message role: :user, content: message, attachments: with
      self
    end

    # Requests one completion from the model, appends the response to the
    # conversation, and returns it as a Message. Honors the fallbacks
    # configured with #with_fallbacks. A given block receives streamed
    # Chunk objects. Tool calls in the response are not executed; that is
    # #run_tools.
    def generate(&)
      return generate_once(&) if fallbacks.empty?

      with_model_restored { generate_with_fallbacks(&) }
    end

    # Executes the tool calls pending in the latest response and appends
    # their result messages, without asking the model to respond. Does
    # nothing when no tool calls are pending. The chat is then ready for
    # the next #generate, or the next batch round. Returns +self+.
    def run_tools
      message = last_non_system_message
      execute_pending_tool_calls(message) if message&.tool_call?
      self
    end

    # Advances the conversation by one move: runs the pending tool calls if
    # the model asked for them, otherwise generates the next response.
    # Returns +nil+ once there is nothing left to do.
    def step(&)
      return if complete?

      last_non_system_message&.tool_call? ? run_tools : generate(&)
    end

    # Runs the agentic loop until #complete? is +true+ and returns the last
    # non-system Message. Used after #ask_later; #ask stages a message and
    # calls #complete for you.
    def complete(&)
      step(&) until complete?
      last_non_system_message || messages.last
    end

    # Returns whether the model owes this chat nothing more: nothing is
    # staged, or the model answered without calling a tool.
    def complete?
      last = last_non_system_message
      case last&.role
      when nil then true
      when :user, :tool then false
      else !last.tool_call?
      end
    end

    # Sets the system instructions for the conversation, replacing any
    # existing system messages. With <tt>append: true</tt> the instructions
    # are added alongside the existing ones. Returns +self+.
    #
    #   chat.with_instructions "You are a helpful Ruby tutor."
    #   chat.with_instructions "Use exactly one short paragraph.", append: true
    #
    def with_instructions(instructions, append: false)
      raise ArgumentError, 'To remove instructions, use without_instructions' if instructions.nil?

      without_instructions unless append
      @messages << Message.new(role: :system, content: instructions)
      self
    end

    # Removes all system instructions from the conversation. Returns +self+.
    def without_instructions
      @messages.reject! { |message| message.role == :system }
      self
    end

    # Registers +tools+, each a Tool class or instance, for the model to
    # call. Configure how the model uses them with #with_tool_options.
    # Returns +self+.
    #
    #   chat.with_tools(Weather, Search)
    #   chat.with_tools(Weather).with_tool_options(choice: :required)
    #
    # To replace the registered tools, clear them first with #without_tools.
    #
    #   chat.without_tools.with_tools(NewTool)
    #
    def with_tools(*tools)
      raise ArgumentError, 'To remove all tools, use without_tools' if tools == [nil]

      tools.flatten.compact.each do |tool|
        tool_instance = tool.is_a?(Class) ? tool.new : tool
        @tools[tool_instance.name.to_sym] = tool_instance
      end
      self
    end

    # Removes all registered tools, leaving the options set with
    # #with_tool_options unchanged. Returns +self+.
    def without_tools
      @tools.clear
      self
    end

    # Configures how the model uses the registered tools. +choice:+
    # constrains tool use to +:auto+, +:none+, +:required+, a tool name, or
    # a Tool class. +calls:+ limits how many tool calls one response may
    # contain (+:many+ or +:one+). +concurrency:+ runs tool calls
    # concurrently: +true+ or +:threads+ for threads, +:fibers+ for fibers.
    # A +nil+ option is left unchanged. Returns +self+.
    #
    #   chat.with_tools(Weather, Search).with_tool_options(choice: :required)
    #   chat.with_tool_options(calls: :one, concurrency: :threads)
    #
    def with_tool_options(choice: nil, calls: nil, concurrency: nil)
      update_tool_options(choice:, calls:)
      @concurrency = normalize_tool_concurrency(concurrency) unless concurrency.nil?
      self
    end

    # Resets the options set with #with_tool_options: +choice:+ and +calls:+
    # return to unset, +concurrency:+ to the configured default. Returns
    # +self+.
    def without_tool_options
      @tool_prefs = { choice: nil, calls: nil }
      @concurrency = normalize_tool_concurrency(@config.tool_concurrency)
      self
    end

    # Switches the chat to +model_id+ and its provider. Pass +provider:+ to
    # disambiguate, and <tt>assume_model_exists: true</tt> to skip registry
    # validation for custom or private models. Pass +nil+ to return to the
    # configured default model. Returns +self+.
    #
    # +protocol:+ overrides the wire protocol the provider would pick for the
    # model, such as +:responses+ or +:chat_completions+ for OpenAI. It stays
    # +nil+ by default, meaning the provider chooses the protocol for each
    # request. A bare #with_model resets the override to +nil+, just as it
    # re-resolves the provider from the model.
    #
    # Raises ModelNotFoundError if +model_id+ is not in the registry and
    # +assume_model_exists:+ is false.
    #
    #   chat.with_model('claude-sonnet-4-5')
    #   chat.with_model('gpt-5.4', protocol: :chat_completions)
    #
    def with_model(model_id, provider: nil, protocol: nil, assume_model_exists: false)
      model_id ||= @config.default_model
      @model, @provider = Models.resolve(model_id, provider:, assume_model_exists:, config: @config)
      @connection = @provider.connection
      @protocol = protocol
      self
    end

    # Sets fallback models to try, in order, when generation fails. +on:+
    # selects the error classes that trigger a fallback; the default covers
    # transient provider and network errors. Returns +self+.
    #
    #   chat.with_fallbacks("gpt-4.1-mini", "claude-haiku-4-5")
    #
    def with_fallbacks(*models, on: Fallback::DEFAULT_ERRORS)
      fallback_models = models.flatten.compact
      raise ArgumentError, 'To remove fallbacks, use without_fallbacks' if fallback_models.empty?

      @fallbacks = fallback_models.map { |model| Fallback.build(model) }
      @fallback_errors = Array(on).flatten.compact
      self
    end

    # Removes all fallback models and restores the default fallback error
    # classes. Returns +self+.
    def without_fallbacks
      @fallbacks = []
      @fallback_errors = Fallback::DEFAULT_ERRORS
      self
    end

    # Sets the sampling temperature for subsequent requests. Returns +self+.
    #
    #   chat.with_temperature(0.2)
    #
    def with_temperature(temperature)
      raise ArgumentError, 'To clear the temperature, use without_temperature' if temperature.nil?

      @temperature = temperature
      self
    end

    # Removes the temperature override, returning the chat to the model's
    # default sampling behavior. Returns +self+.
    def without_temperature
      @temperature = nil
      self
    end

    # Caps the number of tokens the model may generate, mapping to each
    # provider's request field (+max_tokens+, +max_output_tokens+,
    # +maxOutputTokens+, and so on). Returns +self+.
    #
    #   chat.with_max_output_tokens(1000)
    #
    def with_max_output_tokens(max_output_tokens)
      raise ArgumentError, 'To clear the limit, use without_max_output_tokens' if max_output_tokens.nil?

      @max_output_tokens = max_output_tokens
      self
    end

    # Removes the output token limit, letting the provider use its default.
    # Returns +self+.
    def without_max_output_tokens
      @max_output_tokens = nil
      self
    end

    # Configures extended thinking for models that support it, with
    # +effort:+ (+:low+, +:medium+, +:high+, or +:none+) and/or +budget:+
    # (a token count). Returns +self+.
    #
    # Raises ArgumentError unless +effort:+ or +budget:+ is given.
    #
    #   chat.with_thinking(effort: :high, budget: 8000)
    #   chat.with_thinking(budget: 10_000)
    #
    def with_thinking(*args, effort: nil, budget: nil)
      raise ArgumentError, 'To clear the thinking configuration, use without_thinking' if args == [nil]
      raise ArgumentError, 'with_thinking accepts keyword options' unless args.empty?
      raise ArgumentError, 'with_thinking requires :effort or :budget' unless effort || budget

      @thinking = Thinking::Config.new(effort: effort, budget: budget)
      self
    end

    # Clears the thinking configuration, returning to the model's default
    # behavior. Returns +self+.
    def without_thinking
      @thinking = nil
      self
    end

    # Enables document citations, so the model backs its claims with quotes
    # from attached files. Returns +self+.
    #
    #   chat.with_citations
    #   response = chat.ask "Who created Ruby?", with: "facts.txt"
    #   response.citations.each { |citation| puts citation.cited_text }
    #
    def with_citations
      @citations = true
      self
    end

    # Disables document citations. Returns +self+.
    def without_citations
      @citations = false
      self
    end

    # Enables provider prompt caching. With no arguments the provider's
    # default behavior applies; options such as +ttl:+ are passed through
    # to providers that support them. Returns +self+.
    #
    #   chat.with_caching
    #   chat.with_caching(ttl: "1h")
    #
    def with_caching(options = {})
      raise ArgumentError, 'To disable caching, use without_caching' if options.nil?

      @caching = options.transform_keys(&:to_sym).freeze
      self
    end

    # Disables prompt caching. Returns +self+.
    def without_caching
      @caching = nil
      self
    end

    # Rebinds the chat to +context+, a Context built with RubyLLM.context,
    # so subsequent requests use its configuration. Returns +self+.
    def with_context(context)
      raise ArgumentError, 'To return to the global configuration, use without_context' if context.nil?

      @context = context
      @config = context.config
      with_model(@model.id, provider: @provider.slug, protocol: @protocol, assume_model_exists: true)
      self
    end

    # Removes the Context, returning the chat to the global RubyLLM.config.
    # Returns +self+.
    def without_context
      @context = nil
      @config = RubyLLM.config
      with_model(@model.id, provider: @provider.slug, protocol: @protocol, assume_model_exists: true)
      self
    end

    # Sets options in the provider's request vocabulary, merged into the
    # request payload as-is and overriding RubyLLM's defaults. Replaces any
    # previously set provider options. Returns +self+.
    #
    #   chat.with_provider_options(max_output_tokens: 200)
    #
    def with_provider_options(provider_options)
      raise ArgumentError, 'To clear provider options, use without_provider_options' if provider_options.nil?

      @provider_options = provider_options.to_h
      self
    end

    # Removes all provider request options. Returns +self+.
    def without_provider_options
      @provider_options = {}
      self
    end

    # Sets extra HTTP headers sent with completion requests, replacing any
    # previously set headers. Returns +self+.
    #
    #   chat.with_headers('anthropic-beta' => 'fine-grained-tool-streaming-2025-05-14')
    #
    def with_headers(headers)
      raise ArgumentError, 'To clear headers, use without_headers' if headers.nil?

      @headers = headers.to_h
      self
    end

    # Removes all extra HTTP headers. Returns +self+.
    def without_headers
      @headers = {}
      self
    end

    # Sets the schema for structured output. Accepts a JSON Schema Hash, a
    # RubyLLM::Schema class or instance, or any object responding to
    # +to_json_schema+. Returns +self+.
    #
    #   class PersonSchema < RubyLLM::Schema
    #     string :name
    #     integer :age
    #   end
    #
    #   chat.with_schema(PersonSchema)
    #   response = chat.ask("Generate a person named Alice who is 30 years old")
    #   response.parsed # => {"name" => "Alice", "age" => 30}
    #
    def with_schema(schema)
      raise ArgumentError, 'To remove the schema, use without_schema' if schema.nil?

      schema_instance = schema.is_a?(Class) ? schema.new : schema

      @schema = normalize_schema_payload(
        schema_instance.respond_to?(:to_json_schema) ? schema_instance.to_json_schema : schema_instance
      )

      self
    end

    # Removes the structured output schema, returning the chat to plain
    # text responses. Returns +self+.
    def without_schema
      @schema = nil
      self
    end

    # Registers a callback that runs before each assistant response or tool
    # result is appended to the conversation. Callbacks are additive: every
    # registered block runs. Returns +self+.
    def before_message(&)
      add_callback(:before_message, &)
    end

    # Registers a callback that receives each assistant response and each
    # tool result message once it has been appended. Returns +self+.
    #
    #   chat.after_message { |message| puts message.content }
    #
    def after_message(&)
      add_callback(:after_message, &)
    end

    # Registers a callback that receives each ToolCall before the tool
    # executes. Returns +self+.
    #
    #   chat.before_tool_call { |tool_call| puts tool_call.name }
    #
    def before_tool_call(&)
      add_callback(:before_tool_call, &)
    end

    # Registers a callback that receives each tool's result after
    # execution. Returns +self+.
    def after_tool_result(&)
      add_callback(:after_tool_result, &)
    end

    # Registers a callback that receives the Fallback attempt after the
    # current model fails and before the fallback model is tried. Returns
    # +self+.
    def before_fallback(&)
      add_callback(:before_fallback, &)
    end

    # Registers a callback that receives the Fallback attempt once it has
    # succeeded or failed. Returns +self+.
    def after_fallback(&)
      add_callback(:after_fallback, &)
    end

    # Registers a callback that receives the fully rendered request payload
    # before it is sent and may mutate it in place. Runs after all RubyLLM
    # formatting and #with_provider_options merging. Returns +self+.
    #
    #   chat.before_request { |payload| logger.debug payload }
    #
    def before_request(&)
      add_callback(:before_request, &)
    end

    # Yields each Message in the conversation. Returns an Enumerator when
    # no block is given. Chat includes Enumerable, so the usual collection
    # methods are available.
    def each(&)
      messages.each(&)
    end

    # Returns a Cost aggregating the cost of every message in the
    # conversation, priced by each message's own model.
    #
    #   chat.cost.total
    #
    def cost
      Cost.aggregate(messages.map { |message| message.cost(model: message.model_info || model) })
    end

    # Replaces the conversation with +new_messages+, coercing each element
    # into a Message. Accepts Message objects, attribute Hashes, and
    # records responding to +to_llm+.
    def messages=(new_messages)
      @messages = message_list(new_messages).map { |message| coerce_message(message) }
    end

    # Appends a message to the conversation and returns it as a Message.
    # Accepts a Message, an attribute Hash, or a record responding to
    # +to_llm+.
    #
    #   chat.add_message(role: :user, content: "What's the capital of France?")
    #
    def add_message(message_or_attributes)
      message = coerce_message(message_or_attributes)
      message = @provider.preprocess_message(message, model: @model, protocol: @protocol) if @provider
      messages << message
      message
    end

    # Marks the latest message as an explicit prompt cache boundary, asking
    # the provider to cache everything up to this point. Returns +self+.
    #
    # Raises ArgumentError if the chat has no messages.
    def cache_until_here!
      message = messages.last
      raise ArgumentError, 'No messages to cache' unless message

      message.cache_until_here!
      self
    end

    # Receives a completion produced out-of-band (e.g. by a batch), running the
    # same callbacks as a synchronous completion so persistence works unchanged.
    def add_completion(response) # :nodoc:
      run_callbacks(:before_message)
      add_message response
      run_callbacks(:after_message, response)
      response
    end

    # Returns the request payload this chat would send to the provider for
    # its next completion, with #before_request hooks applied. Useful for
    # inspecting and testing request output.
    def render
      @provider.render(
        messages,
        tools: @tools,
        tool_prefs: @tool_prefs,
        temperature: @temperature,
        max_output_tokens: @max_output_tokens,
        model: @model,
        provider_options: @provider_options,
        schema: @schema,
        thinking: @thinking,
        citations: @citations,
        caching: @caching,
        protocol: @protocol,
        before_request: @callbacks[:before_request]
      )
    end

    # Keeps the connection and config dumps out of pretty-printed output.
    def pretty_print_instance_variables # :nodoc:
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

      message = Message.new(message) unless message.is_a?(Message)
      message.conversation = self
      message
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
        max_output_tokens: @max_output_tokens,
        provider_options: provider_options,
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

      event[:response_model] = result.model
      event[:tool_call] = result.tool_call?
      event[:tool_calls] = result.tool_calls
      event[:input_tokens] = result.input_tokens
      event[:output_tokens] = result.output_tokens
      event[:cache_read_tokens] = result.cache_read_tokens
      event[:cache_write_tokens] = result.cache_write_tokens
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

      with_model(fallback.id, provider: fallback.provider, protocol: @protocol)
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
        max_output_tokens: @max_output_tokens,
        model: @model,
        provider_options: @provider_options,
        headers: @headers,
        schema: @schema,
        thinking: @thinking,
        citations: @citations,
        caching: @caching,
        protocol: @protocol,
        before_request: @callbacks[:before_request],
        &wrap_streaming_block(stream_tracker:, &)
      )
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

      @tool_prefs[:choice] = nil if forced_tool_choice?
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
      content, attachments = Tool.split_result(result)
      message = add_message role: :tool, content:, attachments:, tool_call_id: tool_call.id
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

    def reset_tools
      @tools.clear
      @tool_prefs = { choice: nil, calls: nil }
      @concurrency = normalize_tool_concurrency(@config.tool_concurrency)
      self
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

    def last_non_system_message
      messages.reverse.find { |message| message.role != :system }
    end
  end
end
