# frozen_string_literal: true

module RubyLLM
  # Base class for simple, class-configured agents.
  class Agent
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
      end

      def model(model_id = nil, **options)
        options[:model] = model_id unless model_id.nil?
        @chat_kwargs = options
      end

      def tools(*tools)
        return @tools || [] if tools.empty?

        @tools = tools.flatten
      end

      def instructions(text = nil)
        return @instructions if text.nil?

        @instructions = text
      end

      def temperature(value = nil)
        return @temperature if value.nil?

        @temperature = value
      end

      def thinking(effort: nil, budget: nil)
        return @thinking if effort.nil? && budget.nil?

        @thinking = { effort: effort, budget: budget }
      end

      def params(**params)
        return @params || {} if params.empty?

        @params = params
      end

      def headers(**headers)
        return @headers || {} if headers.empty?

        @headers = headers
      end

      def schema(value = nil)
        return @schema if value.nil?

        @schema = value
      end

      def context(value = nil)
        return @context if value.nil?

        @context = value
      end

      def chat_kwargs
        @chat_kwargs || {}
      end
    end

    def initialize(**chat_kwargs) # rubocop:disable Metrics/PerceivedComplexity
      @chat = RubyLLM.chat(**self.class.chat_kwargs, **chat_kwargs)
      @chat.with_context(self.class.context) if self.class.context
      @chat.with_instructions(self.class.instructions) if self.class.instructions
      @chat.with_tools(*self.class.tools) unless self.class.tools.empty?
      @chat.with_temperature(self.class.temperature) unless self.class.temperature.nil?
      if (thinking = self.class.thinking)
        @chat.with_thinking(**thinking)
      end
      @chat.with_params(**self.class.params) unless self.class.params.empty?
      @chat.with_headers(**self.class.headers) unless self.class.headers.empty?
      @chat.with_schema(self.class.schema) if self.class.schema
    end

    def ask(message = nil, with: nil, &block)
      @chat.ask(message, with: with, &block)
    end

    alias say ask

    attr_reader :chat
  end
end
