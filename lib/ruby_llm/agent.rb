# frozen_string_literal: true

require 'erb'
require 'forwardable'
require 'pathname'

module RubyLLM
  # Base class for simple, class-configured agents.
  class Agent
    extend Forwardable
    include Enumerable

    class << self
      def inherited(subclass)
        super
        subclass.instance_variable_set(:@chat_kwargs, (@chat_kwargs || {}).dup)
        subclass.instance_variable_set(:@tools, (@tools || []).dup)
        subclass.instance_variable_set(:@instructions, @instructions)
        subclass.instance_variable_set(:@temperature, @temperature)
        subclass.instance_variable_set(:@thinking, @thinking)
        subclass.instance_variable_set(:@params, (@params || {}).dup)
        subclass.instance_variable_set(:@headers, (@headers || {}).dup)
        subclass.instance_variable_set(:@schema, @schema)
        subclass.instance_variable_set(:@context, @context)
        subclass.instance_variable_set(:@chat_model, @chat_model)
        subclass.instance_variable_set(:@input_names, (@input_names || []).dup)
      end

      def model(model_id = nil, **options)
        options[:model] = model_id unless model_id.nil?
        @chat_kwargs = options
      end

      def tools(*tools, &block)
        return @tools || [] if tools.empty? && !block_given?

        @tools = block_given? ? block : tools.flatten
      end

      def instructions(text = nil, **prompt_locals, &block)
        if text.nil? && prompt_locals.empty? && !block_given?
          @instructions ||= { prompt: 'instructions', locals: {} }
          return @instructions
        end

        @instructions = block || text || { prompt: 'instructions', locals: prompt_locals }
      end

      def temperature(value = nil)
        return @temperature if value.nil?

        @temperature = value
      end

      def thinking(effort: nil, budget: nil)
        return @thinking if effort.nil? && budget.nil?

        @thinking = { effort: effort, budget: budget }
      end

      def params(**params, &block)
        return @params || {} if params.empty? && !block_given?

        @params = block_given? ? block : params
      end

      def headers(**headers, &block)
        return @headers || {} if headers.empty? && !block_given?

        @headers = block_given? ? block : headers
      end

      def schema(value = nil, &block)
        return @schema if value.nil? && !block_given?

        @schema = block_given? ? block : value
      end

      def context(value = nil)
        return @context if value.nil?

        @context = value
      end

      def chat_model(value = nil)
        return @chat_model if value.nil?

        @chat_model = value
        remove_instance_variable(:@resolved_chat_model) if instance_variable_defined?(:@resolved_chat_model)
      end

      def inputs(*names)
        return @input_names || [] if names.empty?

        @input_names = names.flatten.map(&:to_sym)
      end

      def chat_kwargs
        @chat_kwargs || {}
      end

      def chat(**kwargs)
        input_values, chat_options = partition_inputs(kwargs)
        chat = RubyLLM.chat(**chat_kwargs, **chat_options)
        apply_configuration(chat, input_values:, persist_instructions: true)
        chat
      end

      def create(**kwargs)
        with_rails_chat_record(:create, **kwargs)
      end

      def create!(**kwargs)
        with_rails_chat_record(:create!, **kwargs)
      end

      def find(id, **kwargs)
        raise ArgumentError, 'chat_model must be configured to use find' unless resolved_chat_model

        input_values, = partition_inputs(kwargs)
        record = resolved_chat_model.find(id)
        apply_configuration(record, input_values:, persist_instructions: false)
        record
      end

      def sync_instructions!(chat_or_id, **kwargs)
        raise ArgumentError, 'chat_model must be configured to use sync_instructions!' unless resolved_chat_model

        input_values, = partition_inputs(kwargs)
        record = chat_or_id.is_a?(resolved_chat_model) ? chat_or_id : resolved_chat_model.find(chat_or_id)
        runtime = runtime_context(chat: record, inputs: input_values)
        instructions_value = resolved_instructions_value(record, runtime, inputs: input_values)
        return record if instructions_value.nil?

        record.with_instructions(instructions_value)
        record
      end

      def render_prompt(name, chat:, inputs:, locals:)
        path = prompt_path_for(name)
        return nil unless File.exist?(path)

        resolved_locals = resolve_prompt_locals(locals, runtime: runtime_context(chat:, inputs:), chat:, inputs:)
        ERB.new(File.read(path)).result_with_hash(resolved_locals)
      end

      private

      def with_rails_chat_record(method_name, **kwargs)
        raise ArgumentError, 'chat_model must be configured to use create/create!' unless resolved_chat_model

        input_values, chat_options = partition_inputs(kwargs)
        record = resolved_chat_model.public_send(method_name, **chat_kwargs, **chat_options)
        apply_configuration(record, input_values:, persist_instructions: true) if record
        record
      end

      def apply_configuration(chat_object, input_values:, persist_instructions:)
        runtime = runtime_context(chat: chat_object, inputs: input_values)
        llm_chat = llm_chat_for(chat_object)

        apply_context(llm_chat)
        apply_instructions(chat_object, runtime, inputs: input_values, persist: persist_instructions)
        apply_tools(llm_chat, runtime)
        apply_temperature(llm_chat)
        apply_thinking(llm_chat)
        apply_params(llm_chat, runtime)
        apply_headers(llm_chat, runtime)
        apply_schema(llm_chat, runtime)
      end

      def apply_context(llm_chat)
        llm_chat.with_context(context) if context
      end

      def apply_instructions(chat_object, runtime, inputs:, persist:)
        value = resolved_instructions_value(chat_object, runtime, inputs:)
        return if value.nil?

        instruction_target(chat_object, persist:).with_instructions(value)
      end

      def apply_tools(llm_chat, runtime)
        tools_to_apply = Array(evaluate(tools, runtime))
        llm_chat.with_tools(*tools_to_apply) unless tools_to_apply.empty?
      end

      def apply_temperature(llm_chat)
        llm_chat.with_temperature(temperature) unless temperature.nil?
      end

      def apply_thinking(llm_chat)
        llm_chat.with_thinking(**thinking) if thinking
      end

      def apply_params(llm_chat, runtime)
        value = evaluate(params, runtime)
        llm_chat.with_params(**value) if value && !value.empty?
      end

      def apply_headers(llm_chat, runtime)
        value = evaluate(headers, runtime)
        llm_chat.with_headers(**value) if value && !value.empty?
      end

      def apply_schema(llm_chat, runtime)
        value = evaluate(schema, runtime)
        llm_chat.with_schema(value) if value
      end

      def llm_chat_for(chat_object)
        chat_object.respond_to?(:to_llm) ? chat_object.to_llm : chat_object
      end

      def evaluate(value, runtime)
        value.is_a?(Proc) ? runtime.instance_exec(&value) : value
      end

      def resolved_instructions_value(chat_object, runtime, inputs:)
        value = evaluate(instructions, runtime)
        return value unless prompt_instruction?(value)

        runtime.prompt(
          value[:prompt],
          **resolve_prompt_locals(value[:locals] || {}, runtime:, chat: chat_object, inputs:)
        )
      end

      def prompt_instruction?(value)
        value.is_a?(Hash) && value[:prompt]
      end

      def instruction_target(chat_object, persist:)
        if persist || !chat_object.respond_to?(:to_llm)
          chat_object
        else
          chat_object.to_llm
        end
      end

      def resolve_prompt_locals(locals, runtime:, chat:, inputs:)
        base = { chat: chat }.merge(inputs)
        evaluated = locals.each_with_object({}) do |(key, value), acc|
          acc[key.to_sym] = value.is_a?(Proc) ? runtime.instance_exec(&value) : value
        end
        base.merge(evaluated)
      end

      def partition_inputs(kwargs)
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

      def prompt_path_for(name)
        filename = name.to_s
        filename += '.txt.erb' unless filename.end_with?('.txt.erb')
        prompt_root.join(prompt_agent_path, filename)
      end

      def prompt_agent_path
        class_name = name || 'agent'
        class_name.gsub('::', '/')
                  .gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
                  .gsub(/([a-z\d])([A-Z])/, '\1_\2')
                  .tr('-', '_')
                  .downcase
      end

      def prompt_root
        if defined?(Rails) && Rails.respond_to?(:root) && Rails.root
          Rails.root.join('app/prompts')
        else
          Pathname.new(Dir.pwd).join('app/prompts')
        end
      end

      def resolved_chat_model
        return @resolved_chat_model if defined?(@resolved_chat_model)

        @resolved_chat_model = case @chat_model
                               when String then Object.const_get(@chat_model)
                               else @chat_model
                               end
      end
    end

    def initialize(chat: nil, inputs: nil, persist_instructions: true, **kwargs)
      input_values, chat_options = self.class.send(:partition_inputs, kwargs)
      @chat = chat || RubyLLM.chat(**self.class.chat_kwargs, **chat_options)
      self.class.send(:apply_configuration, @chat, input_values: input_values.merge(inputs || {}),
                                                   persist_instructions:)
    end

    attr_reader :chat

    def_delegators :chat, :model, :messages, :tools, :params, :headers, :schema, :ask, :say, :with_tool, :with_tools,
                   :with_model, :with_temperature, :with_thinking, :with_context, :with_params, :with_headers,
                   :with_schema, :on_new_message, :on_end_message, :on_tool_call, :on_tool_result, :each, :complete,
                   :add_message, :reset_messages!
  end
end
