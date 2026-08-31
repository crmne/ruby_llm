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
  #   chat = RubyLLM.chat(model: 'claude-sonnet-5')
  #   chat.with_instructions("Be terse.").with_tools(Weather)
  #
  # #ask runs the agentic loop to completion, executing tool calls until the
  # model produces a final answer. #ask_later, #generate, #run_tools, and
  # #step expose the individual moves of that loop.
  #
  # A Chat is Enumerable over its messages.
  class Chat # rubocop:disable Metrics/ClassLength
    include Enumerable
    include Inspectable

    # The provider-neutral options #with_compaction accepts.
    COMPACTION_OPTIONS = %i[at instructions pause_after].freeze
    THINKING_OPTIONS = %i[effort budget display].freeze
    private_constant :THINKING_OPTIONS

    # The Model the chat sends requests to.
    attr_reader :model

    # The Provider instance handling requests for the current model.
    attr_reader :provider

    # The Message objects exchanged so far, including system instructions.
    attr_reader :messages

    # The registered tools, as a Hash of tool name Symbols to Tool instances.
    attr_reader :tools

    # The server tools enabled with #with_server_tools, as an array of
    # normalized entry Hashes.
    attr_reader :server_tools

    # Extra request options set with #with_provider_options, expressed in
    # the provider's request vocabulary.
    attr_reader :provider_options

    # Extra HTTP headers set with #with_headers.
    attr_reader :headers

    # The normalized structured output schema set with #with_schema, or +nil+.
    attr_reader :schema

    # The tool concurrency mode, or +nil+ when tools run sequentially.
    attr_reader :concurrency

    # The prompt caching options set with #with_caching, +false+ when
    # explicitly disabled, or +nil+ when not configured.
    attr_reader :caching

    # The context compaction options set with #with_compaction, +false+ when
    # explicitly disabled, or +nil+ when not configured.
    attr_reader :compaction

    # The opaque per-user identifier set with #with_end_user, or
    # +nil+.
    attr_reader :end_user

    # The Fallback models tried in order when generation fails.
    attr_reader :fallbacks

    attr_reader :tool_prefs, :fallback_errors, :usage_entries # :nodoc:

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
      @usage_entries = []
      @tools = {}
      @server_tools = []
      @tool_prefs = { choice: nil, calls: nil }
      @concurrency = normalize_tool_concurrency(@config.tool_concurrency)
      @provider_options = {}
      @headers = {}
      @schema = nil
      @thinking = nil
      @citations = false
      @caching = nil
      @compaction = nil
      @end_user = nil
      @fallbacks = []
      @fallback_errors = Fallback::DEFAULT_ERRORS
      @callbacks = Hash.new { |callbacks, name| callbacks[name] = [] }
      @cancelled = false
      @cancellation_checker = nil
      @tool_call_decisions = {}
      @approval_checker = nil
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
    # Raises PendingToolCallsError while the last response has unanswered
    # tool calls: finish the round first, recording #approve or #deny
    # decisions for calls that require approval.
    def ask_later(message = nil, with: nil)
      raise_if_pending_tool_calls!
      add_message role: :user, content: message, attachments: with
      self
    end

    # Requests one completion from the model, appends the response to the
    # conversation, and returns it as a Message. Honors the fallbacks
    # configured with #with_fallbacks. A given block receives streamed
    # Chunk objects. Tool calls in the response are not executed; that is
    # #run_tools.
    def generate(&)
      raise_if_cancelled!

      return generate_once(&) if fallbacks.empty?

      with_model_restored { generate_with_fallbacks(&) }
    end

    # Executes the tool calls pending in the latest response and appends
    # their result messages, without asking the model to respond. Tool
    # calls that already have results are skipped, so a chat reloaded
    # mid-round resumes with only the remaining tools. Calls whose tool
    # was declared with Tool.requires_approval only execute once #approve
    # records a decision; denied calls receive a structured denial result,
    # and undecided calls stay pending. Does nothing when no tool calls
    # are pending. The chat is then ready for the next #generate, or the
    # next batch round. Returns +self+.
    def run_tools
      raise_if_cancelled!

      message = pending_tool_response
      execute_pending_tool_calls(message) if message
      self
    end

    # Advances the conversation by one move: runs the pending tool calls
    # if any are unanswered, otherwise generates the next response.
    # Returns +nil+ once there is nothing left to do.
    def step(&)
      return if complete?

      raise_if_cancelled!
      pending_tool_response ? run_tools : generate(&)
    end

    # Runs the agentic loop until #complete? is +true+ and returns the last
    # non-system Message. Used after #ask_later; #ask stages a message and
    # calls #complete for you.
    #
    # When a pending tool call requires approval and no decision has been
    # recorded, the loop parks instead of finishing: #complete returns
    # cleanly with #awaiting_approval? true, and calling it again after
    # #approve or #deny picks up exactly where it stopped.
    def complete(&)
      step(&) until complete? || awaiting_approval?
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

    # Records approval for +tool_call+, a ToolCall or its id, so the next
    # #complete or #run_tools executes it. Returns +self+.
    #
    #   chat.approve(tool_call)
    #   chat.complete
    #
    def approve(tool_call)
      record_tool_call_decision(tool_call, true)
    end

    # Records denial for +tool_call+, a ToolCall or its id. The next
    # #complete or #run_tools appends a structured denial result instead
    # of executing the tool, and the model continues from there. Returns
    # +self+.
    def deny(tool_call)
      record_tool_call_decision(tool_call, false)
    end

    # Returns whether the conversation can make no progress without an
    # approval decision: every remaining pending tool call requires
    # approval and has none recorded. While +true+, #complete returns
    # without executing them; record decisions with #approve or #deny,
    # then call #complete again. Tool calls that need no approval still
    # execute before the loop parks.
    #
    # Consults each pending tool's approval resolver when one is declared,
    # so resolvers must be idempotent reads.
    def awaiting_approval?
      response = pending_tool_response
      return false unless response

      pending = pending_tool_calls(response)
      pending.any? && pending.all? { |_, tool_call| approval_pending?(tool_call) }
    end

    # Returns the tool calls from the latest response that require approval
    # and have no recorded decision, as an array of ToolCall objects. Pairs
    # with #approve and #deny.
    #
    #   chat.pending_approvals.each { |tool_call| puts tool_call.name }
    #   chat.approve(chat.pending_approvals.first)
    #
    def pending_approvals
      response = pending_tool_response
      return [] unless response

      pending_tool_calls(response).values.select { |tool_call| approval_pending?(tool_call) }
    end

    # Cancels the current in-flight chat operation. The next cancellation
    # checkpoint raises CancelledError and clears the flag so the chat can be
    # reused.
    def cancel
      @cancelled = true
      self
    end

    # Returns whether this in-memory chat has been marked for cancellation.
    def cancelled?
      @cancelled
    end

    # Sets the system instructions for the conversation, replacing any
    # existing system messages. With <tt>append: true</tt> the instructions
    # are added alongside the existing ones. With <tt>cache_until_here:
    # true</tt> the instruction becomes an explicit prompt cache boundary.
    # Pass +nil+ to remove all system instructions. Returns +self+.
    #
    #   chat.with_instructions "You are a helpful Ruby tutor."
    #   chat.with_instructions "Use exactly one short paragraph.", append: true
    #   chat.with_instructions nil
    #
    def with_instructions(instructions, append: false, cache_until_here: false)
      @messages.reject! { |message| message.role == :system } unless append
      @messages << Message.new(role: :system, content: instructions) unless instructions.nil?
      @messages.last.cache_until_here if instructions && cache_until_here
      self
    end

    # Registers +tools+, each a Tool class or instance, for the model to
    # call. Configure how the model uses them with #with_tool_options.
    # Pass +nil+ to remove all registered tools. Returns +self+.
    #
    #   chat.with_tools(Weather, Search)
    #   chat.with_tools(Weather).with_tool_options(choice: :required)
    #
    # To replace the registered tools, clear them first:
    #
    #   chat.with_tools(nil).with_tools(NewTool)
    #
    def with_tools(*tools)
      @tools.clear if tools == [nil]
      tools.flatten.compact.each do |tool|
        tool_instance = tool.is_a?(Class) ? tool.new : tool
        @tools[tool_instance.name.to_sym] = tool_instance
      end
      self
    end

    # Enables tools that run on the provider's servers, such as web search
    # or code execution. Accepts portable alias Symbols, alias-with-options
    # keywords whose options use the provider's own vocabulary, and raw
    # Hashes passed to the provider verbatim, so provider tools RubyLLM has
    # no alias for yet work without a gem update. Entries add to any tools
    # enabled earlier; pass +nil+ to clear them all. Returns +self+.
    #
    #   chat.with_server_tools(:web_search)
    #   chat.with_server_tools(:web_search, :code_execution)
    #   chat.with_server_tools(web_search: { allowed_domains: ["ruby-lang.org"] })
    #   chat.with_server_tools({ type: "web_search_20260318", name: "web_search" })
    #
    # The tool steps the model ran come back on
    # Message#server_tool_calls, citations from search tools on
    # Message#citations, and per-use billing counters on
    # <tt>message.tokens.server_tool_use</tt>.
    #
    # Raises UnsupportedServerToolError at request time when the provider
    # has no server-tool support or does not define a requested alias.
    def with_server_tools(*tools, **tools_with_options)
      if tools == [nil] && tools_with_options.empty?
        @server_tools = []
        return self
      end

      @server_tools += ServerTools.normalize(tools, tools_with_options)
      self
    end

    # Configures how the model uses the registered tools. +choice:+
    # constrains tool use to +:auto+, +:none+, +:required+, a tool name, or
    # a Tool class. +calls:+ limits how many tool calls one response may
    # contain (+:many+ or +:one+). +concurrency:+ runs tool calls
    # concurrently: +true+ or +:threads+ for threads, +:fibers+ for fibers.
    # An omitted option is left unchanged; passing +nil+ explicitly resets
    # that option (+concurrency: nil+ returns to the configured default).
    # Returns +self+.
    #
    #   chat.with_tools(Weather, Search).with_tool_options(choice: :required)
    #   chat.with_tool_options(calls: :one, concurrency: :threads)
    #   chat.with_tool_options(choice: nil)
    #
    def with_tool_options(**options)
      options.each do |option, value|
        case option
        when :choice then apply_tool_choice(value)
        when :calls then @tool_prefs[:calls] = value.nil? ? nil : normalize_calls(value)
        when :concurrency then @concurrency = normalize_tool_concurrency(value.nil? ? @config.tool_concurrency : value)
        else raise ArgumentError, "Unknown tool option: #{option}. Valid options are: choice, calls, concurrency"
        end
      end
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
    #   chat.with_model('claude-sonnet-5')
    #   chat.with_model('gpt-5.6', protocol: :chat_completions)
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
    # transient provider and network errors. Pass +nil+ to remove all
    # fallbacks and restore the default error classes. Returns +self+.
    #
    #   chat.with_fallbacks("gpt-4.1-mini", "claude-haiku-4-5")
    #   chat.with_fallbacks(nil)
    #
    def with_fallbacks(*models, on: Fallback::DEFAULT_ERRORS)
      fallback_models = models.flatten.compact
      @fallbacks = fallback_models.map { |model| Fallback.build(model) }
      @fallback_errors = fallback_models.empty? ? Fallback::DEFAULT_ERRORS : Array(on).flatten.compact
      self
    end

    # Sets the sampling temperature for subsequent requests. Pass +nil+ to
    # return to the model's default sampling behavior. Returns +self+.
    #
    #   chat.with_temperature(0.2)
    #
    def with_temperature(temperature)
      @temperature = temperature
      self
    end

    # Caps the number of tokens the model may generate, mapping to each
    # provider's request field (+max_tokens+, +max_output_tokens+,
    # +maxOutputTokens+, and so on). Pass +nil+ to remove the limit.
    # Returns +self+.
    #
    #   chat.with_max_output_tokens(1000)
    #
    def with_max_output_tokens(max_output_tokens)
      @max_output_tokens = max_output_tokens
      self
    end

    # Configures extended thinking for models that support it. With no
    # arguments, RubyLLM uses the current model's registered default. Pass
    # +false+ to disable thinking, or tune it with
    # +effort:+ (+:low+, +:medium+, +:high+, +:none+, or a
    # provider-specific tier such as +:minimal+, +:xhigh+, or +:max+,
    # passed through as-is), +budget:+ (a token count), and +display:+
    # (+:summarized+ or +:omitted+, controlling whether providers that
    # support it return readable thinking text). Returns +self+.
    #
    #   chat.with_thinking
    #   chat.with_thinking(false)
    #   chat.with_thinking(effort: :high, budget: 8000)
    #   chat.with_thinking(budget: 10_000)
    #   chat.with_thinking(display: :summarized)
    #
    def with_thinking(enabled = true, **options) # rubocop:disable Metrics/PerceivedComplexity, Style/OptionalBooleanParameter
      raise ArgumentError, 'with_thinking accepts false or thinking options' unless [true, false].include?(enabled)
      raise ArgumentError, 'with_thinking(false) does not accept options' if !enabled && options.any?
      raise ArgumentError, 'thinking options cannot be nil; pass false to disable' if options.value?(nil)
      if (unsupported = options.keys - THINKING_OPTIONS).any?
        raise ArgumentError,
              "with_thinking accepts #{format_option_keys(THINKING_OPTIONS)}, " \
              "got #{format_option_keys(unsupported)}"
      end

      @thinking = if enabled
                    options.empty? ? Thinking::Config.default : Thinking::Config.new(**options)
                  else
                    Thinking::Config.disabled
                  end
      self
    end

    # Returns the thinking options resolved for the current model, or +nil+
    # when thinking was not configured or needs no provider control.
    def thinking
      config = resolved_thinking
      return unless config

      {
        effort: config.effort,
        budget: config.budget,
        display: config.display,
        enabled: config.enabled
      }.compact
    end

    # Enables document citations, so the model backs its claims with quotes
    # from attached files. Pass +false+ to disable. Returns +self+.
    #
    #   chat.with_citations
    #   response = chat.ask "Who created Ruby?", with: "facts.txt"
    #   response.citations.each { |citation| puts citation.cited_text }
    #
    def with_citations(enabled = true)
      raise ArgumentError, 'with_citations accepts true or false' unless [true, false].include?(enabled)

      @citations = enabled
      self
    end

    # Enables provider prompt caching. With no arguments the provider's
    # default behavior applies; options such as +ttl:+ are passed through
    # to providers that support them. On Gemini, pass +id:+ with a
    # CachedContent (or its name) from RubyLLM.cache to attach an explicit
    # content cache. Pass +false+ to stop RubyLLM from sending cache
    # controls or rendering explicit cache boundaries. A provider may still
    # cache prompts implicitly. Returns +self+.
    #
    #   chat.with_caching
    #   chat.with_caching(ttl: "1h")
    #   chat.with_caching(id: cache)
    #   chat.with_caching(false)
    #
    def with_caching(options = {})
      unless options == false || options.is_a?(Hash)
        raise ArgumentError, 'with_caching accepts false or caching options'
      end

      @caching = options == false ? false : options.transform_keys(&:to_sym).freeze
      self
    end

    # Enables provider-side context compaction, so a long conversation keeps
    # going instead of overflowing the context window. The provider condenses
    # the earlier turns itself and returns a block that RubyLLM replays on
    # later requests. With no arguments the provider's own defaults apply.
    # The options are provider-neutral:
    #
    # +at+:: the input-token count that triggers compaction.
    # +instructions+:: a custom prompt for the summary the provider writes.
    # +pause_after+:: end the turn once compaction runs, instead of
    #                 continuing straight into the answer.
    #
    # Each provider maps what it supports and drops the rest with a debug
    # log, so the same call works everywhere. Pass +false+ to disable.
    # Returns +self+.
    #
    #   chat.with_compaction
    #   chat.with_compaction(at: 50_000)
    #   chat.with_compaction(at: 100_000, instructions: "Keep every decision.")
    #   chat.with_compaction(false)
    #
    # What a provider does when the threshold is crossed differs. Anthropic
    # and OpenAI summarize the compacted span into an opaque block that
    # replaces it; OpenRouter drops messages from the middle of the
    # conversation instead, and has no threshold of its own.
    def with_compaction(options = {})
      unless options == false || options.is_a?(Hash)
        raise ArgumentError, 'with_compaction accepts false or compaction options'
      end

      @compaction = options == false ? false : normalize_compaction(options)
      self
    end

    # Identifies the end user behind the conversation for the provider's
    # abuse tooling, mapping to each provider's own field
    # (+safety_identifier+ on OpenAI, <tt>metadata.user_id</tt> on
    # Anthropic, +user_id+ on DeepSeek, +user+ on OpenRouter). Providers
    # without an equivalent field omit it. Pass +nil+ to remove it.
    # Returns +self+.
    #
    #   chat.with_end_user("user-123").ask "Hello"
    #
    # The value is sent as given, so use an opaque id such as a hash of
    # your user id, never personal data.
    def with_end_user(end_user)
      @end_user = end_user
      self
    end

    # Rebinds the chat to +context+, a Context built with RubyLLM.context,
    # so subsequent requests use its configuration. Pass +nil+ to return to
    # the global RubyLLM.config. Returns +self+.
    def with_context(context)
      @context = context
      @config = context&.config || RubyLLM.config
      with_model(@model.id, provider: @provider.slug, protocol: @protocol, assume_model_exists: true)
      self
    end

    # Sets options in the provider's request vocabulary, merged into the
    # request payload as-is and overriding RubyLLM's defaults. Replaces any
    # previously set provider options; +nil+ clears them. Returns +self+.
    #
    #   chat.with_provider_options(max_output_tokens: 200)
    #
    def with_provider_options(provider_options)
      @provider_options = provider_options.to_h
      self
    end

    # Sets extra HTTP headers sent with completion requests, replacing any
    # previously set headers; +nil+ clears them. Returns +self+.
    #
    #   chat.with_headers('anthropic-beta' => 'fine-grained-tool-streaming-2025-05-14')
    #
    def with_headers(headers)
      @headers = headers.to_h
      self
    end

    # Sets the schema for structured output. Accepts a JSON Schema Hash, a
    # Schematist::Schema class or instance, or any object responding to
    # +to_json_schema+. Returns +self+.
    #
    #   class PersonSchema < Schematist::Schema
    #     string :name
    #     integer :age
    #   end
    #
    #   chat.with_schema(PersonSchema)
    #   response = chat.ask("Generate a person named Alice who is 30 years old")
    #   response.parsed # => {"name" => "Alice", "age" => 30}
    #
    # Pass +nil+ to remove the schema, returning the chat to plain text
    # responses.
    def with_schema(schema)
      schema_instance = schema.is_a?(Class) ? schema.new : schema

      @schema = normalize_schema_payload(
        schema_instance.respond_to?(:to_json_schema) ? schema_instance.to_json_schema : schema_instance
      )

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

    # Returns token usage aggregated across every provider attempt this chat
    # has made, including retries and attempts that produced no message.
    #
    #   chat.tokens.input
    #
    def tokens
      Tokens.aggregate(usage_entries.map(&:tokens))
    end

    # Returns a Cost aggregating every provider attempt this chat has made,
    # including retries and attempts that produced no message.
    #
    #   chat.cost.total
    #
    def cost
      Cost.aggregate(usage_entries.map(&:cost), complete: usage_entries.all?(&:cost_available?))
    end

    # Counts the tokens the chat's next request would consume as currently
    # configured, including instructions, tools, thinking, and attachments.
    # Pass +message+ to include it as a staged user message without
    # mutating the chat. Returns an Integer.
    #
    #   chat.with_instructions("Be terse.").with_tools(Weather)
    #   chat.count_tokens("What's the weather in Berlin?")
    #
    # Raises Error when the provider has no token counting endpoint.
    def count_tokens(message = nil)
      request_messages = messages.dup
      request_messages << coerce_message(role: :user, content: message) unless message.nil?
      @provider.count_tokens(
        preprocessed_messages(request_messages),
        model: @model,
        tools: @tools,
        tool_prefs: @tool_prefs,
        thinking: resolved_thinking,
        schema: @schema,
        citations: @citations,
        caching: @caching,
        protocol: @protocol
      )
    end

    # Replaces the conversation with +new_messages+, coercing each element
    # into a Message. Accepts Message objects, attribute Hashes, and
    # records responding to +to_llm+.
    def messages=(new_messages)
      @messages = message_list(new_messages).map { |message| coerce_message(message) }
    end

    # Replaces the usage ledger. Used by the Rails integration when
    # rebuilding a persisted chat.
    def usage_entries=(entries) # :nodoc:
      @usage_entries = Array(entries)
    end

    # Hooks installed by the Rails integration.
    attr_writer :cancellation_checker, :usage_recorder, :approval_checker # :nodoc:

    # Appends a message to the conversation and returns it as a Message.
    # Accepts a Message, an attribute Hash, or a record responding to
    # +to_llm+.
    #
    #   chat.add_message(role: :user, content: "What's the capital of France?")
    #
    def add_message(message_or_attributes)
      message = coerce_message(message_or_attributes)
      messages << message
      message
    end

    # Marks the latest message as an explicit prompt cache boundary, asking
    # the provider to cache everything up to this point. Returns +self+.
    #
    # Raises ArgumentError if the chat has no messages.
    def cache_until_here
      message = messages.last
      raise ArgumentError, 'No messages to cache' unless message

      message.cache_until_here
      self
    end

    # Receives a completion produced out-of-band (e.g. by a batch), running the
    # same callbacks as a synchronous completion so persistence works unchanged.
    def add_completion(response, record_usage: false) # :nodoc:
      if response.ruby_llm_usage_entries.empty?
        record_out_of_band_usage(response)
      elsif record_usage
        response.ruby_llm_usage_entries.each { |entry| record_usage_entry(entry) }
      end
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
        preprocessed_messages,
        tools: @tools,
        server_tools: @server_tools,
        tool_prefs: @tool_prefs,
        temperature: @temperature,
        max_output_tokens: @max_output_tokens,
        model: @model,
        provider_options: Utils.deep_dup(@provider_options),
        schema: @schema,
        thinking: resolved_thinking,
        citations: @citations,
        caching: @caching,
        compaction: @compaction,
        end_user: @end_user,
        protocol: @protocol,
        before_request: @callbacks[:before_request]
      )
    end

    # Refuses to stage a user message onto an unfinished tool round, which
    # providers reject. Called by #ask_later here and in the Rails
    # integration before it persists anything.
    def raise_if_pending_tool_calls! # :nodoc:
      response = pending_tool_response
      return unless response

      names = pending_tool_calls(response).values.map(&:name).uniq
      raise PendingToolCallsError,
            "The last response has unanswered tool calls (#{names.join(', ')}). " \
            'Run complete, recording approve or deny decisions for calls that ' \
            'require approval, before asking again.'
    end

    private

    def resolved_thinking
      @thinking&.resolve(@model)
    end

    def normalize_compaction(options)
      compaction = options.to_h.transform_keys(&:to_sym)
      unsupported = compaction.keys - COMPACTION_OPTIONS
      return compaction.freeze if unsupported.empty?

      raise ArgumentError,
            "with_compaction accepts #{format_option_keys(COMPACTION_OPTIONS)}, " \
            "got #{format_option_keys(unsupported)}. Provider-specific settings " \
            'go through with_provider_options.'
    end

    def format_option_keys(keys)
      keys.map { |key| ":#{key}" }.join(', ')
    end

    def message_list(new_messages)
      return [] if new_messages.nil?
      if new_messages.is_a?(Hash) || new_messages.is_a?(Message) || new_messages.respond_to?(:to_llm)
        return [new_messages]
      end

      new_messages.respond_to?(:to_a) ? new_messages.to_a : [new_messages]
    end

    def coerce_message(message_or_attributes)
      raise ArgumentError, 'Message cannot be nil' if message_or_attributes.nil?

      message = if message_or_attributes.respond_to?(:to_llm)
                  message_or_attributes.to_llm
                else
                  message_or_attributes
                end

      message = Message.new(message.merge(config: @config)) unless message.is_a?(Message)
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
      definition = RubyLLM::Utils.deep_dup(schema[:schema] || schema)
      RubyLLM::Utils.strip_schema_metadata(definition)
    end

    def extract_schema_strict(schema, schema_def)
      return schema[:strict] if schema.key?(:strict)
      return schema_def.delete(:strict) if schema_def.is_a?(Hash)

      nil
    end

    def build_schema_payload(schema, schema_def, strict)
      {
        name: sanitize_schema_name(schema[:name] || schema[:title] || 'response'),
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

    def raise_if_cancelled!
      external_cancelled = @cancellation_checker&.call
      return unless @cancelled || external_cancelled

      @cancelled = false
      raise CancelledError
    end

    def generate_once(stream_tracker: nil, usage_start: nil, &block)
      raise_if_cancelled!

      result = nil
      entries_before = usage_entries.length
      usage_start ||= entries_before
      payload = instrumentation_payload(streaming: block_given?)

      RubyLLM.instrument('chat.ruby_llm', payload, config: @config) do |event|
        result = provider_completion(usage_recorder: method(:record_usage_entry), stream_tracker:, &block)
        record_out_of_band_usage(result) if usage_entries.length == entries_before
        raise_if_cancelled!
        link_completion_usage(result, usage_start)
        run_callbacks(:before_message) unless block_given?
        add_message result
        run_callbacks(:after_message, result)
        record_completion_event(event, result)
      end
      result
    end

    def instrumentation_payload(streaming:)
      empty_tokens = Tokens.new
      {
        chat: self,
        provider: @provider.slug,
        provider_class: @provider.class.display_name,
        model: @model.id,
        model_info: @model,
        input_messages: messages.dup,
        message_count: messages.size,
        tools: tools.keys,
        server_tools: server_tools,
        tool_choice: tool_prefs[:choice],
        tool_call_limit: tool_prefs[:calls],
        temperature: @temperature,
        max_output_tokens: @max_output_tokens,
        provider_options: provider_options,
        schema: schema,
        thinking: resolved_thinking,
        citations: @citations,
        caching: @caching,
        streaming: streaming,
        tokens: empty_tokens,
        cost: Cost.new(tokens: empty_tokens, model: @model)
      }
    end

    def record_completion_event(event, result)
      event[:response] = result
      event[:messages_after] = messages.dup
      event[:response_role] = result.role if result.respond_to?(:role)
      event[:tokens] = result.tokens
      event[:cost] = result.cost
      return unless result.respond_to?(:tool_call?)

      event[:response_model] = result.model
      event[:tool_call] = result.tool_call?
      event[:tool_calls] = result.tool_calls
    end

    def generate_with_fallbacks(&block)
      fallback_queue = fallbacks.dup
      attempt = 0
      active_fallback = nil
      streaming = block_given?
      usage_start = usage_entries.length

      loop do
        chunks_yielded = false

        begin
          result = generate_once(stream_tracker: proc { chunks_yielded = true }, usage_start:, &block)
          finish_fallback(active_fallback, response: result)
          return result
        rescue StandardError => e
          finish_fallback(active_fallback, fallback_error: e)
          raise e unless fallback_error?(e)

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
      original_protocol = @protocol

      yield
    ensure
      @model = original_model
      @provider = original_provider
      @connection = original_connection
      @protocol = original_protocol
    end

    def switch_to_fallback_model(fallback)
      from_provider = @provider.slug
      if fallback.model
        with_resolved_model(fallback.model)
      else
        with_model(fallback.id, provider: fallback.provider, protocol: @protocol)
      end
      @protocol = nil unless @provider.slug == from_provider
      self
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

    # Preprocessing builds a per-request view of the conversation: the
    # provider can change through fallbacks or with_model, so history keeps
    # the original attachments while each provider's upload is memoized on
    # them. Reloaded Rails chats rebuild history from rows and upload again.
    def preprocessed_messages(list = messages)
      return list unless @provider

      list.map { |message| @provider.preprocess_message(message, model: @model, protocol: @protocol) }
    end

    def provider_completion(usage_recorder:, stream_tracker: nil, &)
      raise_if_cancelled!

      @provider.complete(
        preprocessed_messages,
        tools: @tools,
        server_tools: @server_tools,
        tool_prefs: @tool_prefs,
        temperature: @temperature,
        max_output_tokens: @max_output_tokens,
        model: @model,
        provider_options: Utils.deep_dup(@provider_options),
        headers: @headers,
        schema: @schema,
        thinking: resolved_thinking,
        citations: @citations,
        caching: @caching,
        compaction: @compaction,
        end_user: @end_user,
        protocol: @protocol,
        before_request: @callbacks[:before_request],
        usage_recorder: usage_recorder,
        &wrap_streaming_block(stream_tracker:, &)
      )
    end

    def record_usage_entry(entry)
      usage_entries << entry
      @usage_recorder&.call(entry)
      entry
    end

    def link_completion_usage(response, usage_start)
      response.ruby_llm_usage_entries = usage_entries.drop(usage_start)
    end

    def record_out_of_band_usage(response)
      entry = Usage::Entry.new(
        operation: :chat,
        provider: @provider.slug,
        model: response.model || @model.id,
        status: :succeeded,
        tokens: response.tokens,
        cost: response.cost,
        message: response
      )
      response.ruby_llm_usage_entries = [entry]
      Usage.instrument(entry, config: @config)
      record_usage_entry(entry)
    end

    def run_callbacks(name, *args)
      @callbacks[name].each { |callback| callback.call(*args) }
    end

    def wrap_streaming_block(stream_tracker: nil, &block)
      return nil unless block

      run_callbacks(:before_message)

      proc do |chunk|
        raise_if_cancelled!
        stream_tracker&.call(chunk)
        block.call(chunk)
        raise_if_cancelled!
      end
    end

    def execute_pending_tool_calls(response)
      raise_if_cancelled!

      executable, denied = partition_pending_tool_calls(pending_tool_calls(response))
      deny_tool_calls(denied)
      if concurrency
        handle_concurrent_tool_calls(executable)
      else
        handle_sequential_tool_calls(executable)
      end

      @tool_prefs[:choice] = nil if forced_tool_choice?
    end

    def partition_pending_tool_calls(pending)
      executable = {}
      denied = {}
      pending.each do |id, tool_call|
        tool = tools[tool_call.name.to_sym]
        if tool&.requires_approval?
          decision = tool_call_approval(tool, tool_call)
          next if decision.nil?

          (decision ? executable : denied)[id] = tool_call
        elsif @tool_call_decisions[tool_call.id] == false
          denied[id] = tool_call
        else
          executable[id] = tool_call
        end
      end
      [executable, denied]
    end

    def deny_tool_calls(tool_calls)
      tool_calls.each_value do |tool_call|
        raise_if_cancelled!
        run_callbacks(:before_message)
        add_tool_result_message(tool_call, { error: "The user denied the #{tool_call.name} tool call." })
      end
    end

    def record_tool_call_decision(tool_call, decision)
      id = tool_call.respond_to?(:id) ? tool_call.id : tool_call
      @tool_call_decisions[id] = decision
      self
    end

    def approval_pending?(tool_call)
      tool = tools[tool_call.name.to_sym]
      return false unless tool&.requires_approval?

      tool_call_approval(tool, tool_call).nil?
    end

    def tool_call_approval(tool, tool_call)
      return tool.approval_resolver.call(tool_call) if tool.approval_resolver
      return @tool_call_decisions[tool_call.id] if @tool_call_decisions.key?(tool_call.id)

      @approval_checker&.call(tool_call)
    end

    def handle_sequential_tool_calls(tool_calls)
      tool_calls.each_value do |tool_call|
        raise_if_cancelled!
        run_callbacks(:before_message)
        result = execute_tool_with_callbacks(tool_call)
        add_tool_result_message(tool_call, result)
      end
    end

    def handle_concurrent_tool_calls(tool_calls)
      execute_tools_concurrently(tool_calls) do |tool_call, result|
        raise_if_cancelled!
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
      raise_if_cancelled!
      run_callbacks(:before_tool_call, tool_call)
      result = execute_tool tool_call
      raise_if_cancelled!
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
        result = tool.call(**args, tool_call: tool_call)
        event[:result] = result
        event[:result_content] = result
        event[:result_class] = result.class.name
        result
      end
    end

    def apply_tool_choice(choice)
      if choice.nil?
        @tool_prefs[:choice] = nil
      else
        normalized_choice = normalize_tool_choice(choice)
        valid_tool_choices = %i[auto none required] + tools.keys
        unless valid_tool_choices.include?(normalized_choice)
          raise InvalidToolChoiceError,
                "Invalid tool choice: #{choice}. Valid choices are: #{valid_tool_choices.join(', ')}"
        end

        @tool_prefs[:choice] = normalized_choice
      end
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
      return tool_class.tool_name.to_sym if tool_class.respond_to?(:tool_name)

      tool_class.name.to_s.to_sym
    end

    def forced_tool_choice?
      @tool_prefs[:choice] && !%i[auto none].include?(@tool_prefs[:choice])
    end

    def last_non_system_message
      messages.reverse.find { |message| message.role != :system }
    end

    def pending_tool_response
      response = messages.reverse.find { |message| message.role != :system && !message.tool_result? }
      response if response&.tool_call? && pending_tool_calls(response).any?
    end

    def pending_tool_calls(response)
      answered = messages.filter_map { |message| message.tool_call_id if message.tool_result? }
      response.tool_calls.except(*answered)
    end

    def inspect_attributes # :nodoc:
      {
        model: model.id,
        provider: provider.slug,
        messages: messages.count,
        tools: tools.keys,
        awaiting_approval: awaiting_approval_names
      }
    end

    def awaiting_approval_names
      pending_approvals.map(&:name).uniq
    end
  end
end
