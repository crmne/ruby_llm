# frozen_string_literal: true

require 'forwardable'
require 'ruby_llm/schema'

module RubyLLM
  # An Agent is a reusable chat configuration defined as a class. Subclasses
  # declare a model, instructions, tools, and other settings once, then build
  # configured chats wherever they are needed.
  #
  #   class SupportAgent < RubyLLM::Agent
  #     model "gpt-5-nano"
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
  # Agent instances delegate the Chat API (#ask, #complete, #with_tools, and
  # so on) to the wrapped chat, which is available via #chat. Agents are
  # enumerable over their messages.
  class Agent
    extend Forwardable
    include Enumerable

    DUPED_INHERITED_CONFIG = {
      :@chat_kwargs => {},
      :@tools => [],
      :@tool_options => {},
      :@caching => nil,
      :@provider_options => {},
      :@headers => {},
      :@input_names => [],
      :@fallbacks => [],
      :@fallback_options => {}
    }.freeze
    # Simple value options: a class-level getter/setter macro whose value the
    # agent forwards to the matching Chat#with_* when it builds its chat.
    PASSTHROUGH_OPTIONS = %i[temperature max_output_tokens].freeze

    COPIED_INHERITED_CONFIG = (%i[
      @instructions
      @thinking
      @citations
      @schema
      @context
      @chat_model
    ] + PASSTHROUGH_OPTIONS.map { |option| :"@#{option}" }).freeze
    private_constant :DUPED_INHERITED_CONFIG, :COPIED_INHERITED_CONFIG, :PASSTHROUGH_OPTIONS

    class << self
      def inherited(subclass) # :nodoc:
        super
        copy_inherited_config_to(subclass)
      end

      # Sets the model used by chats this agent builds. Extra +options+ are
      # forwarded to RubyLLM.chat, including +provider:+ to disambiguate the
      # model and +protocol:+ to override its wire protocol. Called with no
      # arguments, returns the configured chat keywords.
      #
      #   model "gpt-5-nano"
      #   model "gpt-5.4", provider: :openai, protocol: :responses
      #
      def model(model_id = nil, **options)
        return @chat_kwargs || {} if model_id.nil? && options.empty?

        options[:model] = model_id unless model_id.nil?
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

      # Sets system instructions for chats this agent builds. Accepts a
      # string, a block evaluated when the chat is built, or keyword locals
      # for the agent's conventional prompt template (for a WorkAssistant
      # agent, <tt>app/prompts/work_assistant/instructions.txt.erb</tt>).
      #
      #   instructions "You are a helpful assistant."
      #   instructions { "You are helping #{workspace.name}" }
      #   instructions display_name: -> { chat.user.display_name_or_email }
      #
      # A named agent uses its conventional template automatically when it
      # exists, even without calling this method. Called with no arguments,
      # returns the configured value.
      def instructions(text = nil, **prompt_locals, &block)
        return @instructions if text.nil? && prompt_locals.empty? && !block_given?

        @instructions = block || text || { prompt: 'instructions', locals: prompt_locals }
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

      # Sets the thinking effort or budget for chats this agent builds,
      # applied via Chat#with_thinking. Called with no arguments, returns
      # the configured value.
      #
      #   thinking effort: :low
      #   thinking budget: 10_000
      #
      def thinking(effort: nil, budget: nil)
        return @thinking if effort.nil? && budget.nil?

        @thinking = { effort: effort, budget: budget }
      end

      # Enables or disables citations for chats this agent builds, applied
      # via Chat#with_citations. Called with no argument, returns the
      # configured value.
      #
      #   citations true
      #
      def citations(value = nil)
        return @citations if value.nil?

        @citations = value
      end

      # Sets prompt caching options for chats this agent builds, applied via
      # Chat#with_caching. A block defers evaluation until the chat is
      # built. Called with no arguments, returns the configured value.
      #
      #   caching ttl: "1h"
      #
      def caching(**options, &block)
        return @caching if options.empty? && !block_given?

        @caching = block_given? ? block : options
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
      # hash, or a block. A plain block is built with the RubyLLM::Schema
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
      # use, applied via Chat#with_context. Called with no argument, returns
      # the configured context.
      def context(value = nil)
        return @context if value.nil?

        @context = value
      end

      # Sets the ActiveRecord chat class this agent creates and finds,
      # activating Rails mode (::create, ::create!, ::find, and
      # ::sync_instructions!). Accepts the class or its name as a string.
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

      def chat_kwargs # :nodoc:
        @chat_kwargs || {}
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
        chat = RubyLLM.chat(**chat_kwargs, **chat_options)
        apply_configuration(chat, input_values:, persist_instructions: true)
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
      #   WorkAssistant.sync_instructions!(chat)
      #
      # Raises ArgumentError if ::chat_model is not configured.
      def sync_instructions!(chat_or_id, **kwargs)
        raise ArgumentError, 'chat_model must be configured to use sync_instructions!' unless resolved_chat_model

        input_values, = partition_inputs(kwargs)
        record = chat_or_id.is_a?(resolved_chat_model) ? chat_or_id : resolved_chat_model.find(chat_or_id)
        apply_assume_model_exists(record)
        apply_protocol(record)
        runtime = runtime_context(chat: record, inputs: input_values)
        instructions_value = resolved_instructions_value(record, runtime, inputs: input_values)
        return record if instructions_value.nil?

        record.with_instructions(instructions_value)
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

      def apply_configuration(chat, input_values:, persist_instructions:) # :nodoc:
        runtime = runtime_context(chat:, inputs: input_values)
        apply_chat_options(chat)
        apply_context(chat)
        apply_instructions(chat, runtime, inputs: input_values, persist: persist_instructions)
        apply_tools(chat, runtime)
        apply_passthrough_options(chat)
        apply_thinking(chat)
        apply_citations(chat)
        apply_caching(chat, runtime)
        apply_provider_options(chat, runtime)
        apply_headers(chat, runtime)
        apply_schema(chat, runtime)
        apply_fallbacks(chat)
      end

      private

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
        record = resolved_chat_model.public_send(method_name, **chat_kwargs, **chat_options)
        apply_configuration(record, input_values:, persist_instructions: true) if record
        record
      end

      def apply_context(chat)
        chat.with_context(context) if context
      end

      def apply_instructions(chat, runtime, inputs:, persist:)
        value = resolved_instructions_value(chat, runtime, inputs:)
        return if value.nil?

        return chat.with_runtime_instructions(value) if !persist && chat.respond_to?(:with_runtime_instructions)

        chat.with_instructions(value)
      end

      def apply_tools(chat, runtime)
        tools_to_apply = Array(evaluate(tools, runtime)).compact
        chat.with_tools(*tools_to_apply) if tools_to_apply.any?

        options = evaluate(tool_options, runtime)
        chat.with_tool_options(**options) if options && !options.empty?
      end

      def apply_passthrough_options(chat)
        PASSTHROUGH_OPTIONS.each do |option|
          value = instance_variable_get(:"@#{option}")
          chat.public_send(:"with_#{option}", value) unless value.nil?
        end
      end

      def apply_thinking(chat)
        chat.with_thinking(**thinking) if thinking
      end

      def apply_citations(chat)
        chat.with_citations(citations) unless citations.nil?
      end

      def apply_caching(chat, runtime)
        value = evaluate(caching, runtime)
        chat.with_caching(**value) if value
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

        RubyLLM::Schema.create(&value)
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

      def resolved_instructions_value(chat_object, runtime, inputs:)
        value = evaluate(instructions_config, runtime)
        return value unless prompt_instruction?(value)

        runtime.prompt(
          value[:prompt],
          **resolve_prompt_locals(value[:locals] || {}, runtime:, chat: chat_object, inputs:)
        )
      end

      def instructions_config
        return @instructions unless @instructions.nil?
        return unless default_instructions_prompt_exists?

        { prompt: 'instructions', locals: {} }
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
      @chat = chat || RubyLLM.chat(**self.class.chat_kwargs, **chat_options)
      self.class.apply_configuration(@chat, input_values: input_values.merge(inputs || {}),
                                            persist_instructions:)
    end

    # The wrapped Chat, or the chat record in Rails mode.
    attr_reader :chat

    # Agent instances delegate the Chat API to the wrapped #chat. Each
    # delegated method behaves exactly as documented on Chat.
    def_delegators :chat, :model, :messages, :tools, :provider_options, :headers, :schema, :caching, :ask, :say,
                   :with_tools, :with_tool_options, :with_model, :with_temperature, :with_max_output_tokens,
                   :with_thinking, :with_citations, :with_caching, :with_context, :with_provider_options,
                   :with_headers, :with_schema, :with_fallbacks, :before_message, :after_message, :before_tool_call,
                   :after_tool_result, :before_fallback, :after_fallback, :each, :complete, :complete?, :ask_later,
                   :cancel!, :cancelled?, :generate, :run_tools, :step, :add_message, :add_completion, :tokens, :cost
  end
end
