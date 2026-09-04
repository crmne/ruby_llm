# frozen_string_literal: true

require 'forwardable'
require 'schematist'

module RubyLLM
  # An Agent is a reusable chat configuration defined as a class. Subclasses
  # declare a model, instructions, tools, and other settings once, then build
  # configured chats wherever they are needed.
  #
  #   class SupportAgent < RubyLLM::Agent
  #     model "gpt-5.6-luna"
  #     instructions "You are a concise support assistant."
  #     tools SearchDocs, LookupAccount
  #   end
  #
  #   SupportAgent.new.ask "How do I reset my API key?"
  #
  # ::chat returns a configured Chat. When ::chat_model names an ActiveRecord
  # chat class, ::create, ::create!, and ::find return configured records of
  # that class instead.
  #
  # Configuration that depends on runtime state goes in blocks or lambdas.
  # They are evaluated when a chat is built, with +chat+ and any declared
  # ::inputs available as methods:
  #
  #   class WorkAssistant < RubyLLM::Agent
  #     inputs :workspace
  #
  #     instructions { "You are helping #{workspace.name}" }
  #   end
  #
  #   WorkAssistant.chat(workspace: workspace)
  #
  # Agent instances delegate Chat's conversation API (#ask, #complete,
  # #with_tools, and so on) to the wrapped chat, which is available via
  # #chat. Direct transcript replacement stays on the wrapped chat because
  # Rails-backed chat models own their message association. Agents are
  # enumerable over their messages.
  class Agent
    extend Forwardable
    include Enumerable

    DUPED_INHERITED_CONFIG = {
      :@chat_kwargs => {},
      :@tools => [],
      :@server_tools => [],
      :@tool_options => {},
      :@caching => nil,
      :@compaction => nil,
      :@provider_options => {},
      :@headers => {},
      :@input_names => [],
      :@fallbacks => [],
      :@fallback_options => {},
      :@rescue_handlers => [],
      :@instructions => []
    }.freeze
    # Simple value options: a class-level getter/setter macro whose value the
    # agent forwards to the matching Chat#with_* when it builds its chat.
    PASSTHROUGH_OPTIONS = %i[temperature max_output_tokens].freeze
    THINKING_OPTIONS = %i[effort budget display].freeze
    UNRESOLVED_CONTEXT = Object.new.freeze
    private_constant :UNRESOLVED_CONTEXT

    # The chat operations an agent instance runs through its ::rescue_from
    # handlers. Remaining delegated methods pass through untouched.
    GUARDED_OPERATIONS = %i[ask say ask_later complete generate run_tools step count_tokens].freeze

    # Chat methods that return the wrapped chat so calls can be chained there.
    CHAINABLE_CHAT_DELEGATES = %i[
      with_instructions with_tools with_server_tools with_tool_options with_model
      with_temperature with_max_output_tokens with_thinking with_citations
      with_end_user with_compaction with_caching with_context with_provider_options
      with_headers with_schema with_fallbacks
      before_request before_message after_message before_tool_call after_tool_result
      before_fallback after_fallback
      cancel approve deny cache_until_here
    ].freeze

    # Chat values and operations whose return values pass through unchanged.
    PASSTHROUGH_CHAT_DELEGATES = %i[
      model provider messages tools server_tools provider_options headers schema concurrency
      caching compaction end_user fallbacks thinking
      each complete? cancelled? awaiting_approval? pending_approvals
      add_message add_completion tokens cost render
    ].freeze

    COPIED_INHERITED_CONFIG = (%i[
      @thinking
      @citations
      @end_user
      @schema
      @context
      @chat_model
    ] + PASSTHROUGH_OPTIONS.map { |option| :"@#{option}" }).freeze
    private_constant :DUPED_INHERITED_CONFIG, :COPIED_INHERITED_CONFIG,
                     :PASSTHROUGH_OPTIONS, :THINKING_OPTIONS, :GUARDED_OPERATIONS,
                     :CHAINABLE_CHAT_DELEGATES, :PASSTHROUGH_CHAT_DELEGATES

    class << self
      def inherited(subclass) # :nodoc:
        super
        copy_inherited_config_to(subclass)
      end

      # Sets the model used by chats this agent builds. Extra +options+ are
      # forwarded to RubyLLM.chat, including +provider:+ to disambiguate the
      # model and +protocol:+ to override its wire protocol. A block picks
      # the model when the chat is built, with the declared ::inputs
      # available as methods. Called with no arguments, returns the
      # configured chat keywords.
      #
      #   model "gpt-5.6-luna"
      #   model "gpt-5.6", provider: :openai, protocol: :responses
      #   model { quality == :high ? "gpt-5.6" : "gpt-5.6-luna" }
      #
      # The block runs before the chat exists, so it can read inputs but not
      # +chat+.
      def model(model_id = nil, **options, &block)
        return @chat_kwargs || {} if model_id.nil? && options.empty? && !block_given?

        model_value = block || model_id
        options[:model] = model_value unless model_value.nil?
        @chat_kwargs = options
      end

      # Declares the tools for chats this agent builds. A block defers
      # construction until the chat is built. Configure how the model uses
      # them with ::tool_options. Called with no arguments, returns the
      # declared tools.
      #
      #   tools SearchDocs, LookupAccount
      #   tools { [TodoTool.new(chat: chat)] }
      #
      def tools(*tools, &block)
        return @tools || [] if tools.empty? && !block_given?

        @tools = block_given? ? block : tools.flatten
      end

      # Sets how chats this agent builds use their tools, applied via
      # Chat#with_tool_options. Accepts +choice:+, +calls:+, and
      # +concurrency:+. A block defers evaluation until the chat is built.
      # Called with no arguments, returns the configured options.
      #
      #   tool_options choice: :required, calls: :one
      #
      def tool_options(**options, &block)
        return @tool_options || {} if options.empty? && !block_given?

        @tool_options = block_given? ? block : options
      end

      # Enables provider-executed tools for chats this agent builds, applied
      # via Chat#with_server_tools. Accepts the same aliases, options, and
      # raw Hashes; a block defers evaluation until the chat is built.
      # Called with no arguments, returns the declared entries.
      #
      #   server_tools :web_search
      #   server_tools web_search: { allowed_domains: ["ruby-lang.org"] }
      #
      def server_tools(*tools, **tools_with_options, &block)
        return @server_tools || [] if tools.empty? && tools_with_options.empty? && !block_given?

        @server_tools = block_given? ? block : ServerTools.normalize(tools, tools_with_options)
      end

      # Adds system instructions for chats this agent builds. Accepts a string,
      # a block evaluated when the chat is built, or keyword locals for the
      # agent's conventional prompt template (for a WorkAssistant agent,
      # <tt>app/prompts/work_assistant/instructions.txt.erb</tt>). Multiple
      # declarations are applied in order.
      #
      #   instructions "You are a helpful assistant."
      #   instructions { "You are helping #{workspace.name}" }
      #   instructions display_name: -> { chat.user.display_name_or_email }
      #   instructions append: true, persist: false do
      #     "Today is #{Date.current}"
      #   end
      #
      # A named agent uses its conventional template automatically when it
      # exists, even without calling this method. In Rails mode, declarations
      # persist when the record is created unless <tt>persist: false</tt>;
      # ::find always reapplies them without rewriting history. Called with no
      # arguments, returns the declarations.
      def instructions(text = nil, append: false, persist: true, cache_until_here: false, **prompt_locals, &block)
        return instruction_declarations if text.nil? && prompt_locals.empty? && !block_given?

        instruction_declarations << {
          value: block || text || { prompt: 'instructions', locals: prompt_locals },
          append: append,
          persist: persist,
          cache_until_here: cache_until_here
        }
      end

      ##
      # :method: temperature
      # :call-seq: temperature(value = nil)
      #
      # Sets the sampling temperature for chats this agent builds. Called
      # with no argument, returns the configured value.
      #
      #   temperature 0.2

      ##
      # :method: max_output_tokens
      # :call-seq: max_output_tokens(value = nil)
      #
      # Caps the number of tokens chats this agent builds may generate.
      # Called with no argument, returns the configured value.
      #
      #   max_output_tokens 1000

      PASSTHROUGH_OPTIONS.each do |option|
        define_method(option) do |value = nil|
          return instance_variable_get(:"@#{option}") if value.nil?

          instance_variable_set(:"@#{option}", value)
        end
      end

      # Enables thinking for chats this agent builds, applied via
      # Chat#with_thinking. With no options, RubyLLM chooses from the model's
      # registered controls. Pass +false+ to disable it.
      #
      #   thinking
      #   thinking false
      #   thinking effort: :low
      #   thinking budget: 10_000
      #   thinking display: :summarized
      #
      def thinking(enabled = true, **options) # rubocop:disable Style/OptionalBooleanParameter
        raise ArgumentError, 'thinking accepts false or thinking options' unless [true, false].include?(enabled)
        raise ArgumentError, 'thinking false does not accept options' if !enabled && options.any?
        raise ArgumentError, 'thinking options cannot be nil; use thinking false to disable' if options.value?(nil)

        if (unsupported = options.keys - THINKING_OPTIONS).any?
          raise ArgumentError, "thinking accepts #{THINKING_OPTIONS.join(', ')}, got #{unsupported.join(', ')}"
        end

        @thinking = enabled ? options : false
      end

      # Enables context compaction for chats this agent builds, applied via
      # Chat#with_compaction. With no options, the provider's own defaults
      # apply. Pass +false+ to disable it.
      #
      #   compaction
      #   compaction false
      #   compaction at: 50_000
      #
      def compaction(options = {})
        unless options == false || options.is_a?(Hash)
          raise ArgumentError, 'compaction accepts false or compaction options'
        end

        @compaction = options
      end

      # Sets the safety identifier for chats this agent builds, applied via
      # Chat#with_end_user. A block defers evaluation until the
      # chat is built, so the id can come from the agent's inputs. Called
      # with no arguments, returns the configured value.
      #
      #   end_user "tenant-42"
      #   end_user { workspace.public_id }
      #
      def end_user(value = nil, &block)
        return @end_user if value.nil? && !block_given?

        @end_user = block || value
      end

      # Enables citations for chats this agent builds, applied via
      # Chat#with_citations. Pass +false+ to disable them.
      #
      #   citations
      #   citations false
      #
      def citations(value = true) # rubocop:disable Style/OptionalBooleanParameter
        raise ArgumentError, 'citations accepts true or false' unless [true, false].include?(value)

        @citations = value
      end

      # Enables prompt caching for chats this agent builds, applied via
      # Chat#with_caching. With no options, the provider's default behavior
      # applies. Pass +false+ to stop RubyLLM from sending cache controls. A
      # provider may still cache prompts implicitly. A block defers evaluation
      # until the chat is built.
      #
      #   caching
      #   caching false
      #   caching ttl: "1h"
      #   caching { { ttl: workspace.cache_ttl } }
      #
      def caching(enabled = true, **options, &block) # rubocop:disable Metrics/PerceivedComplexity, Style/OptionalBooleanParameter
        raise ArgumentError, 'caching accepts false or caching options' unless [true, false].include?(enabled)
        raise ArgumentError, 'caching accepts options or a block, not both' if options.any? && block
        raise ArgumentError, 'caching false does not accept options or a block' if !enabled && (options.any? || block)

        @caching = block || (enabled ? options : false)
      end

      # Sets options in the provider's request vocabulary for chats this
      # agent builds, applied via Chat#with_provider_options. A block
      # defers evaluation until the chat is built. Called with no
      # arguments, returns the configured value.
      #
      #   provider_options max_output_tokens: 256
      #
      def provider_options(**provider_options, &block)
        return @provider_options || {} if provider_options.empty? && !block_given?

        @provider_options = block_given? ? block : provider_options
      end

      # Sets custom HTTP headers for chats this agent builds, applied via
      # Chat#with_headers. A block defers evaluation until the chat is
      # built. Called with no arguments, returns the configured value.
      def headers(**headers, &block)
        return @headers || {} if headers.empty? && !block_given?

        @headers = block_given? ? block : headers
      end

      # Sets the structured output schema for chats this agent builds,
      # applied via Chat#with_schema. Accepts a schema class, a JSON schema
      # hash, or a block. A plain block is built with the Schematist::Schema
      # DSL; a lambda is evaluated when the chat is built. Called with no
      # arguments, returns the configured value.
      #
      #   schema PersonSchema
      #   schema do
      #     string :verdict, enum: ["pass", "revise"]
      #     string :feedback
      #   end
      #
      def schema(value = nil, &block)
        return @schema if value.nil? && !block_given?

        @schema = block_given? ? block : value
      end

      # Sets fallback models for chats this agent builds, applied via
      # Chat#with_fallbacks. Called with no arguments, returns the
      # configured models.
      #
      #   fallbacks "gpt-4.1-mini", "claude-haiku-4-5"
      #   fallbacks "gpt-4.1-mini", on: [RubyLLM::RateLimitError]
      #
      def fallbacks(*models, **options)
        return @fallbacks || [] if models.empty? && options.empty?
        raise ArgumentError, 'To set fallback options, provide at least one fallback model' if models.empty?

        @fallbacks = models.flatten.compact
        @fallback_options = options
      end

      def fallback_options
        @fallback_options || {}
      end

      private :fallback_options

      # Sets a Context whose configuration chats this agent builds should
      # use, applied via Chat#with_context. A block defers evaluation until a
      # chat is built, with declared ::inputs available as methods. Called
      # with no argument, returns the configured Context, deferred Proc, or nil.
      #
      #   context RubyLLM.context { |config| config.request_timeout = 10 }
      #   context { RubyLLM.context { |config| config.openai_api_key = api_key } }
      def context(value = nil, &block)
        return @context if value.nil? && !block_given?

        @context = block || value
      end

      # Sets the ActiveRecord chat class this agent creates and finds,
      # activating Rails mode (::create, ::create!, ::find, and
      # ::sync_instructions). Accepts the class or its name as a string.
      # Called with no argument, returns the configured value.
      #
      #   chat_model Chat
      #
      def chat_model(value = nil)
        return @chat_model if value.nil?

        @chat_model = value
        remove_instance_variable(:@resolved_chat_model) if instance_variable_defined?(:@resolved_chat_model)
      end

      # Declares named runtime inputs. Matching keyword arguments passed to
      # ::chat, ::create, ::create!, ::find, or ::new become methods inside
      # lazy configuration blocks. Called with no arguments, returns the
      # declared names.
      #
      #   inputs :workspace
      #
      def inputs(*names)
        return @input_names || [] if names.empty?

        @input_names = names.flatten.map(&:to_sym)
      end

      # Registers a handler for exceptions raised by the chat operations of
      # this agent's instances: #ask, #say, #ask_later, #complete,
      # #generate, #run_tools, and #step. Name the handler with +with:+ or
      # pass a block; either runs on the agent instance, so the agent's
      # #chat, inputs, and class name are available for instrumentation.
      #
      #   class ApplicationAgent < RubyLLM::Agent
      #     rescue_from RubyLLM::RateLimitError, Faraday::TimeoutError, with: :handle_transient
      #     rescue_from RubyLLM::BadRequestError do |error|
      #       error_tracker.notify(error)
      #       raise
      #     end
      #
      #     private
      #
      #     def handle_transient(error)
      #       metrics.increment("llm.api_error", type: "transient")
      #       raise
      #     end
      #   end
      #
      # Handlers are searched in reverse declaration order, so the last
      # matching one wins. Re-raise inside a handler to let the caller see
      # the exception; otherwise the handler's return value becomes the
      # operation's return value. Exceptions no handler matches are
      # re-raised. Subclasses inherit the handlers declared when they are
      # defined.
      #
      # Exception classes may be named as Strings, which defers constant
      # lookup until an exception is raised.
      def rescue_from(*exception_classes, with: nil, &block)
        raise ArgumentError, 'rescue_from needs a handler: pass with: or a block' unless with || block
        raise ArgumentError, 'rescue_from takes with: or a block, not both' if with && block

        exception_classes.flatten.each do |exception_class|
          rescue_handlers << [rescue_handler_key(exception_class), with || block]
        end
      end

      def rescue_handlers # :nodoc:
        @rescue_handlers ||= []
      end

      def rescue_handler_for(exception) # :nodoc:
        rescue_handlers.reverse_each do |class_name, handler|
          exception_class = rescue_handler_class(class_name)
          return handler if exception_class && exception.is_a?(exception_class)
        end
        nil
      end

      def chat_kwargs # :nodoc:
        @chat_kwargs || {}
      end

      def resolved_context(inputs:) # :nodoc:
        evaluate(context, runtime_context(chat: nil, inputs:))
      end

      def resolved_chat_kwargs(inputs: {}) # :nodoc:
        kwargs = chat_kwargs
        return kwargs unless kwargs[:model].is_a?(Proc)

        kwargs.merge(model: evaluate(kwargs[:model], runtime_context(chat: nil, inputs: inputs)))
      end

      def build_chat(inputs:, options:, resolved_context: UNRESOLVED_CONTEXT) # :nodoc:
        context_value = resolved_context.equal?(UNRESOLVED_CONTEXT) ? self.resolved_context(inputs:) : resolved_context
        (context_value || RubyLLM).chat(**resolved_chat_kwargs(inputs:), **options)
      end

      # Builds a Chat configured with this agent's declarations and returns
      # it. Keywords matching declared ::inputs become runtime inputs; the
      # rest are forwarded to RubyLLM.chat.
      #
      #   chat = WorkAssistant.chat
      #   chat.ask "Hello"
      #
      def chat(**kwargs)
        input_values, chat_options = partition_inputs(kwargs)
        context_value = resolved_context(inputs: input_values)
        chat = build_chat(inputs: input_values, options: chat_options, resolved_context: context_value)
        apply_configuration(chat, input_values:, persist_instructions: true, resolved_context: context_value)
        chat
      end

      # Creates a ::chat_model record, applies this agent's configuration to
      # it, and returns it. Keywords matching declared ::inputs become
      # runtime inputs; the rest are forwarded to the model's +create+.
      #
      #   chat = WorkAssistant.create(user: current_user)
      #
      # Raises ArgumentError if ::chat_model is not configured.
      def create(**kwargs)
        with_rails_chat_record(:create, **kwargs)
      end

      # Like ::create, but calls the model's <tt>create!</tt>, raising if
      # the record is invalid.
      #
      #   chat = WorkAssistant.create!(user: current_user)
      #
      def create!(**kwargs)
        with_rails_chat_record(:create!, **kwargs)
      end

      # Finds the ::chat_model record with +id+ and applies this agent's
      # configuration at runtime, without persisting instructions. Returns
      # the record.
      #
      #   chat = WorkAssistant.find(params[:id])
      #
      # Raises ArgumentError if ::chat_model is not configured.
      def find(id, **kwargs)
        raise ArgumentError, 'chat_model must be configured to use find' unless resolved_chat_model

        input_values, = partition_inputs(kwargs)
        record = resolved_chat_model.find(id)
        apply_configuration(record, input_values:, persist_instructions: false)

        record
      end

      # Re-renders this agent's instructions and persists them on the given
      # ::chat_model record (or the record found by that id). Keywords
      # matching declared ::inputs become runtime inputs. Returns the
      # record.
      #
      #   WorkAssistant.sync_instructions(chat)
      #
      # Raises ArgumentError if ::chat_model is not configured.
      def sync_instructions(chat_or_id, **kwargs)
        raise ArgumentError, 'chat_model must be configured to use sync_instructions' unless resolved_chat_model

        input_values, = partition_inputs(kwargs)
        record = chat_or_id.is_a?(resolved_chat_model) ? chat_or_id : resolved_chat_model.find(chat_or_id)
        apply_assume_model_exists(record)
        apply_protocol(record)
        runtime = runtime_context(chat: record, inputs: input_values)
        apply_context(record, runtime)
        apply_instructions(
          record,
          runtime,
          inputs: input_values,
          persist: true,
          persistent_only: true
        )
        record
      end

      def render_prompt(name, chat:, inputs:, locals:) # :nodoc:
        resolved_locals = resolve_prompt_locals(locals, runtime: runtime_context(chat:, inputs:), chat:, inputs:)
        RubyLLM.render_prompt("#{prompt_agent_path}/#{name}", **resolved_locals)
      end

      def partition_inputs(kwargs) # :nodoc:
        input_values = {}
        chat_options = {}

        kwargs.each do |key, value|
          symbolized_key = key.to_sym
          if inputs.include?(symbolized_key)
            input_values[symbolized_key] = value
          else
            chat_options[symbolized_key] = value
          end
        end

        [input_values, chat_options]
      end

      def apply_configuration(
        chat,
        input_values:,
        persist_instructions:,
        resolved_context: UNRESOLVED_CONTEXT
      ) # :nodoc:
        runtime = runtime_context(chat:, inputs: input_values)
        apply_chat_options(chat)
        apply_context(chat, runtime, resolved_context:)
        apply_instructions(chat, runtime, inputs: input_values, persist: persist_instructions)
        apply_tools(chat, runtime)
        apply_passthrough_options(chat)
        apply_thinking(chat)
        apply_citations(chat)
        apply_end_user(chat, runtime)
        apply_caching(chat, runtime)
        apply_compaction(chat)
        apply_provider_options(chat, runtime)
        apply_headers(chat, runtime)
        apply_schema(chat, runtime)
        apply_fallbacks(chat)
      end

      private

      def rescue_handler_key(exception_class)
        case exception_class
        when Module then exception_class.name || exception_class
        when String then exception_class
        else raise ArgumentError, "#{exception_class.inspect} is not an exception class or its name"
        end
      end

      def rescue_handler_class(class_name)
        return class_name if class_name.is_a?(Module)

        Object.const_get(class_name)
      rescue NameError
        nil
      end

      def copy_inherited_config_to(subclass)
        DUPED_INHERITED_CONFIG.each do |ivar, default|
          value = instance_variable_defined?(ivar) ? instance_variable_get(ivar) : default
          subclass.instance_variable_set(ivar, value.respond_to?(:dup) ? value.dup : value)
        end

        COPIED_INHERITED_CONFIG.each do |ivar|
          subclass.instance_variable_set(ivar, instance_variable_get(ivar))
        end
      end

      def with_rails_chat_record(method_name, **kwargs)
        raise ArgumentError, 'chat_model must be configured to use create/create!' unless resolved_chat_model

        input_values, chat_options = partition_inputs(kwargs)
        record = resolved_chat_model.public_send(
          method_name, **resolved_chat_kwargs(inputs: input_values), **chat_options
        )
        apply_configuration(record, input_values:, persist_instructions: true) if record
        record
      end

      def apply_context(chat, runtime, resolved_context: UNRESOLVED_CONTEXT)
        value = resolved_context.equal?(UNRESOLVED_CONTEXT) ? evaluate(context, runtime) : resolved_context
        chat.with_context(value) if value
      end

      def apply_instructions(chat, runtime, inputs:, persist:, persistent_only: false)
        instructions_config.each do |declaration|
          next if persistent_only && !declaration[:persist]

          value = resolved_instruction_value(declaration, chat, runtime, inputs:)
          next if value.nil?

          options = {
            append: declaration[:append],
            cache_until_here: declaration[:cache_until_here]
          }
          options[:persist] = persist && declaration[:persist] if rails_chat_record?(chat)
          chat.with_instructions(value, **options)
        end
      end

      def apply_tools(chat, runtime)
        tools_to_apply = Array(evaluate(tools, runtime)).compact
        chat.with_tools(*tools_to_apply) if tools_to_apply.any?

        options = evaluate(tool_options, runtime)
        chat.with_tool_options(**options) if options && !options.empty?

        server_tools_to_apply = Array(evaluate(server_tools, runtime)).compact
        chat.with_server_tools(*server_tools_to_apply) if server_tools_to_apply.any?
      end

      def apply_passthrough_options(chat)
        PASSTHROUGH_OPTIONS.each do |option|
          value = instance_variable_get(:"@#{option}")
          chat.public_send(:"with_#{option}", value) unless value.nil?
        end
      end

      def apply_thinking(chat)
        return if @thinking.nil?

        @thinking == false ? chat.with_thinking(false) : chat.with_thinking(**@thinking)
      end

      def apply_citations(chat)
        chat.with_citations(@citations) unless @citations.nil?
      end

      def apply_end_user(chat, runtime)
        value = evaluate(end_user, runtime)
        chat.with_end_user(value) unless value.nil?
      end

      def apply_caching(chat, runtime)
        value = evaluate(@caching, runtime)
        return if value.nil?

        value == false ? chat.with_caching(false) : chat.with_caching(**value)
      end

      def apply_compaction(chat)
        return if @compaction.nil?

        @compaction == false ? chat.with_compaction(false) : chat.with_compaction(**@compaction)
      end

      def apply_provider_options(chat, runtime)
        value = evaluate(provider_options, runtime)
        chat.with_provider_options(**value) if value && !value.empty?
      end

      def apply_headers(chat, runtime)
        value = evaluate(headers, runtime)
        chat.with_headers(**value) if value && !value.empty?
      end

      def apply_schema(chat, runtime)
        value = resolved_schema_value(runtime)
        chat.with_schema(value) if value
      end

      def apply_fallbacks(chat)
        chat.with_fallbacks(*fallbacks, **fallback_options) if fallbacks.any?
      end

      def resolved_schema_value(runtime)
        value = schema
        return value unless value.is_a?(Proc)
        return evaluate(value, runtime) if value.lambda?

        Schematist::Schema.create(&value)
      end

      def apply_chat_options(chat)
        apply_assume_model_exists(chat)
        apply_protocol(chat)
      end

      def apply_assume_model_exists(chat_object)
        return unless chat_kwargs.key?(:assume_model_exists) &&
                      resolved_chat_model &&
                      chat_object.is_a?(resolved_chat_model)

        chat_object.assume_model_exists = chat_kwargs[:assume_model_exists]
      end

      def apply_protocol(chat_object)
        return unless chat_kwargs.key?(:protocol) &&
                      resolved_chat_model &&
                      chat_object.is_a?(resolved_chat_model)

        chat_object.protocol = chat_kwargs[:protocol]
      end

      def evaluate(value, runtime)
        value.is_a?(Proc) ? runtime.instance_exec(&value) : value
      end

      def resolved_instruction_value(declaration, chat_object, runtime, inputs:)
        value = evaluate(declaration[:value], runtime)
        return value unless prompt_instruction?(value)

        runtime.prompt(
          value[:prompt],
          **resolve_prompt_locals(value[:locals] || {}, runtime:, chat: chat_object, inputs:)
        )
      end

      def instructions_config
        return instruction_declarations if instruction_declarations.any?
        return [] unless default_instructions_prompt_exists?

        [{
          value: { prompt: 'instructions', locals: {} },
          append: false,
          persist: true,
          cache_until_here: false
        }]
      end

      def instruction_declarations
        @instruction_declarations ||= []
      end

      def rails_chat_record?(chat)
        resolved_chat_model && chat.is_a?(resolved_chat_model)
      end

      def default_instructions_prompt_exists?
        name && File.exist?(Prompt.new("#{prompt_agent_path}/instructions").path)
      end

      def prompt_instruction?(value)
        value.is_a?(Hash) && value[:prompt]
      end

      def resolve_prompt_locals(locals, runtime:, chat:, inputs:)
        base = { chat: chat }.merge(inputs)
        evaluated = locals.each_with_object({}) do |(key, value), acc|
          acc[key.to_sym] = value.is_a?(Proc) ? runtime.instance_exec(&value) : value
        end
        base.merge(evaluated)
      end

      def runtime_context(chat:, inputs:)
        agent_class = self
        Object.new.tap do |runtime|
          runtime.define_singleton_method(:chat) { chat }
          runtime.define_singleton_method(:prompt) do |name, **locals|
            agent_class.render_prompt(name, chat:, inputs:, locals:)
          end

          inputs.each do |name, value|
            runtime.define_singleton_method(name) { value }
          end
        end
      end

      def prompt_agent_path
        class_name = name || 'agent'
        Utils.underscore(class_name.gsub('::', '/')).tr('-', '_')
      end

      def resolved_chat_model
        return @resolved_chat_model if defined?(@resolved_chat_model)

        @resolved_chat_model = case @chat_model
                               when String then Object.const_get(@chat_model)
                               else @chat_model
                               end
      end
    end

    # Returns a new agent wrapping +chat:+, or wrapping a newly built chat
    # when +chat:+ is +nil+. Applies the agent's configuration either way.
    # Keywords matching declared inputs (and the +inputs:+ hash) become
    # runtime inputs; the rest are forwarded to RubyLLM.chat when the agent
    # builds its own chat. Pass <tt>persist_instructions: false</tt> to
    # apply instructions at runtime only, without persisting them on a
    # Rails-backed record.
    #
    #   agent = WorkAssistant.new
    #   agent.ask "Hello"
    #
    #   record = Chat.find(params[:id])
    #   WorkAssistant.new(chat: record)
    #
    def initialize(chat: nil, inputs: nil, persist_instructions: true, **kwargs)
      input_values, chat_options = self.class.partition_inputs(kwargs)
      input_values = input_values.merge(inputs || {})

      if chat
        @chat = chat
        self.class.apply_configuration(@chat, input_values:, persist_instructions:)
        return
      end

      context_value = self.class.resolved_context(inputs: input_values)
      @chat = self.class.build_chat(
        inputs: input_values,
        options: chat_options,
        resolved_context: context_value
      )
      self.class.apply_configuration(
        @chat,
        input_values:,
        persist_instructions:,
        resolved_context: context_value
      )
    end

    # The wrapped Chat, or the chat record in Rails mode.
    attr_reader :chat

    # Agent instances delegate the Chat conversation API to the wrapped
    # #chat without adapting its return values.
    def_delegators :chat, *CHAINABLE_CHAT_DELEGATES, *PASSTHROUGH_CHAT_DELEGATES

    ##
    # :method: ask
    # :call-seq: ask(message = nil, with: nil, &block)
    #
    # Delegates to Chat#ask, routing exceptions through the handlers
    # declared with ::rescue_from.

    ##
    # :method: complete
    # :call-seq: complete(&block)
    #
    # Delegates to Chat#complete, routing exceptions through the handlers
    # declared with ::rescue_from.

    GUARDED_OPERATIONS.each do |operation|
      define_method(operation) do |*args, **kwargs, &block|
        chat.public_send(operation, *args, **kwargs, &block)
      rescue StandardError => e
        rescue_with_handler(e)
      end
    end

    # Runs the ::rescue_from handler matching +exception+ and returns its
    # value, or re-raises when no handler matches. The chat operations call
    # this for you.
    def rescue_with_handler(exception)
      handler = self.class.rescue_handler_for(exception)
      raise exception unless handler

      return instance_exec(exception, &handler) unless handler.is_a?(Symbol)

      handler_method = method(handler)
      handler_method.arity.zero? ? handler_method.call : handler_method.call(exception)
    end
  end
end
