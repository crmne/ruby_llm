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
      # via Chat#with_citations or Chat#without_citations. Called with no
      # argument, returns the configured value.
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

      def apply_configuration(chat_object, input_values:, persist_instructions:) # :nodoc:
        runtime = runtime_context(chat: chat_object, inputs: input_values)
        llm_chat = llm_chat_for(chat_object)

        apply_context(llm_chat)
        apply_instructions(chat_object, runtime, inputs: input_values, persist: persist_instructions)
        apply_tools(llm_chat, runtime)
        apply_passthrough_options(llm_chat)
        apply_thinking(llm_chat)
        apply_citations(llm_chat)
        apply_caching(llm_chat, runtime)
        apply_provider_options(llm_chat, runtime)
        apply_headers(llm_chat, runtime)
        apply_schema(llm_chat, runtime)
        apply_fallbacks(llm_chat)
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

      def apply_context(llm_chat)
        llm_chat.with_context(context) if context
      end

      def apply_instructions(chat_object, runtime, inputs:, persist:)
        value = resolved_instructions_value(chat_object, runtime, inputs:)
        return if value.nil?

        target = instruction_target(chat_object, persist:)
        return target.with_runtime_instructions(value) if use_runtime_instructions?(target, persist:)

        target.with_instructions(value)
      end

      def apply_tools(llm_chat, runtime)
        tools_to_apply = Array(evaluate(tools, runtime)).compact
        llm_chat.with_tools(*tools_to_apply) if tools_to_apply.any?

        options = evaluate(tool_options, runtime)
        llm_chat.with_tool_options(**options) if options && !options.empty?
      end

      def apply_passthrough_options(llm_chat)
        PASSTHROUGH_OPTIONS.each do |option|
          value = instance_variable_get(:"@#{option}")
          llm_chat.public_send(:"with_#{option}", value) unless value.nil?
        end
      end

      def apply_thinking(llm_chat)
        llm_chat.with_thinking(**thinking) if thinking
      end

      def apply_citations(llm_chat)
        return if citations.nil?

        citations ? llm_chat.with_citations : llm_chat.without_citations
      end

      def apply_caching(llm_chat, runtime)
        value = evaluate(caching, runtime)
        llm_chat.with_caching(**value) if value
      end

      def apply_provider_options(llm_chat, runtime)
        value = evaluate(provider_options, runtime)
        llm_chat.with_provider_options(**value) if value && !value.empty?
      end

      def apply_headers(llm_chat, runtime)
        value = evaluate(headers, runtime)
        llm_chat.with_headers(**value) if value && !value.empty?
      end

      def apply_schema(llm_chat, runtime)
        value = resolved_schema_value(runtime)
        llm_chat.with_schema(value) if value
      end

      def apply_fallbacks(llm_chat)
        llm_chat.with_fallbacks(*fallbacks, **fallback_options) if fallbacks.any?
      end

      def resolved_schema_value(runtime)
        value = schema
        return value unless value.is_a?(Proc)
        return evaluate(value, runtime) if value.lambda?

        RubyLLM::Schema.create(&value)
      end

      def llm_chat_for(chat_object)
        apply_assume_model_exists(chat_object)
        apply_protocol(chat_object)
        chat_object.respond_to?(:to_llm) ? chat_object.to_llm : chat_object
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

      def instruction_target(chat_object, persist:)
        if persist || !chat_object.respond_to?(:to_llm)
          chat_object
        else
          runtime_instruction_target(chat_object)
        end
      end

      def runtime_instruction_target(chat_object)
        return chat_object if chat_object.respond_to?(:with_runtime_instructions)

        chat_object.to_llm
      end

      def use_runtime_instructions?(target, persist:)
        !persist && target.respond_to?(:with_runtime_instructions)
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

    ##
    # :method: model
    #
    # Returns the Model::Info of the chat's model. See Chat#model.

    ##
    # :method: messages
    #
    # Returns the messages exchanged so far. See Chat#messages.

    ##
    # :method: tools
    #
    # Returns the tools registered on the chat. See Chat#tools.

    ##
    # :method: provider_options
    #
    # Returns the provider request options set on the chat. See
    # Chat#provider_options.

    ##
    # :method: headers
    #
    # Returns the custom HTTP headers set on the chat. See Chat#headers.

    ##
    # :method: schema
    #
    # Returns the structured output schema set on the chat. See Chat#schema.

    ##
    # :method: caching
    #
    # Returns the prompt caching configuration. See Chat#caching.

    ##
    # :method: ask
    #
    # Sends a user message and returns the model's final response. See Chat#ask.

    ##
    # :method: say
    #
    # Same as #ask. See Chat#say.

    ##
    # :method: with_tools
    #
    # Registers tools on the chat. See Chat#with_tools.

    ##
    # :method: without_tools
    #
    # Removes all tools from the chat. See Chat#without_tools.

    ##
    # :method: with_tool_options
    #
    # Configures how the model uses its tools. See Chat#with_tool_options.

    ##
    # :method: without_tool_options
    #
    # Resets the tool options. See Chat#without_tool_options.

    ##
    # :method: with_model
    #
    # Switches the chat to a different model. See Chat#with_model.

    ##
    # :method: with_temperature
    #
    # Sets the sampling temperature. See Chat#with_temperature.

    ##
    # :method: without_temperature
    #
    # Removes the temperature override. See Chat#without_temperature.

    ##
    # :method: with_thinking
    #
    # Adjusts thinking effort or budget. See Chat#with_thinking.

    ##
    # :method: without_thinking
    #
    # Clears the thinking configuration. See Chat#without_thinking.

    ##
    # :method: with_citations
    #
    # Enables citations. See Chat#with_citations.

    ##
    # :method: without_citations
    #
    # Disables citations. See Chat#without_citations.

    ##
    # :method: with_caching
    #
    # Configures prompt caching. See Chat#with_caching.

    ##
    # :method: without_caching
    #
    # Disables prompt caching. See Chat#without_caching.

    ##
    # :method: with_context
    #
    # Applies a configuration Context. See Chat#with_context.

    ##
    # :method: without_context
    #
    # Returns the chat to the global configuration. See Chat#without_context.

    ##
    # :method: with_provider_options
    #
    # Sets options in the provider's request vocabulary. See
    # Chat#with_provider_options.

    ##
    # :method: without_provider_options
    #
    # Removes all provider request options. See Chat#without_provider_options.

    ##
    # :method: with_headers
    #
    # Sets custom HTTP headers. See Chat#with_headers.

    ##
    # :method: without_headers
    #
    # Removes all custom HTTP headers. See Chat#without_headers.

    ##
    # :method: with_schema
    #
    # Sets a structured output schema. See Chat#with_schema.

    ##
    # :method: without_schema
    #
    # Removes the structured output schema. See Chat#without_schema.

    ##
    # :method: with_fallbacks
    #
    # Configures fallback models. See Chat#with_fallbacks.

    ##
    # :method: without_fallbacks
    #
    # Removes all fallback models. See Chat#without_fallbacks.

    ##
    # :method: before_message
    #
    # Registers a callback run before each assistant message. See Chat#before_message.

    ##
    # :method: after_message
    #
    # Registers a callback run after each assistant message. See Chat#after_message.

    ##
    # :method: before_tool_call
    #
    # Registers a callback run before each tool call. See Chat#before_tool_call.

    ##
    # :method: after_tool_result
    #
    # Registers a callback run after each tool result. See Chat#after_tool_result.

    ##
    # :method: before_fallback
    #
    # Registers a callback run before trying a fallback model. See Chat#before_fallback.

    ##
    # :method: after_fallback
    #
    # Registers a callback run after a fallback attempt. See Chat#after_fallback.

    ##
    # :method: each
    #
    # Yields each message in the conversation. See Chat#each.

    ##
    # :method: complete
    #
    # Runs the agentic loop until nothing is left to do. See Chat#complete.

    ##
    # :method: complete?
    #
    # Returns whether the conversation needs no further work. See Chat#complete?.

    ##
    # :method: ask_later
    #
    # Stages a question without asking it. See Chat#ask_later.

    ##
    # :method: generate
    #
    # Calls the model once and appends its response. See Chat#generate.

    ##
    # :method: run_tools
    #
    # Executes the pending tool calls and appends their results. See Chat#run_tools.

    ##
    # :method: step
    #
    # Advances the conversation by one move. See Chat#step.

    ##
    # :method: add_message
    #
    # Appends a message to the conversation. See Chat#add_message.

    ##
    # :method: add_completion
    #
    # Appends a completed response to the conversation. See Chat#add_completion.

    ##
    # :method: cost
    #
    # Returns the accumulated cost of the conversation. See Chat#cost.

    def_delegators :chat, :model, :messages, :tools, :provider_options, :headers, :schema, :caching, :ask, :say,
                   :with_tools, :without_tools, :with_tool_options, :without_tool_options, :with_model,
                   :with_temperature, :without_temperature, :with_max_output_tokens, :without_max_output_tokens,
                   :with_thinking, :without_thinking, :with_citations, :without_citations, :with_caching,
                   :without_caching, :with_context, :without_context, :with_provider_options,
                   :without_provider_options, :with_headers, :without_headers, :with_schema, :without_schema,
                   :with_fallbacks, :without_fallbacks, :before_message, :after_message, :before_tool_call,
                   :after_tool_result, :before_fallback, :after_fallback, :each, :complete, :complete?, :ask_later,
                   :generate, :run_tools, :step, :add_message, :add_completion, :cost
  end
end
