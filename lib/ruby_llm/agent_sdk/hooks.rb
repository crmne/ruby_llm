# frozen_string_literal: true

module RubyLLM
  module AgentSDK
    module Hooks
      # Event constants (agent-native introspection)
      EVENTS = %i[
        pre_tool_use post_tool_use stop subagent_stop
        session_start session_end user_prompt_submit
        pre_compact notification
      ].freeze

      # Result decisions
      DECISIONS = %i[approve block modify skip].freeze

      # Hook result value object
      Result = Struct.new(:decision, :payload, :reason, keyword_init: true) do
        def approved? = decision == :approve
        def blocked? = decision == :block
        def modified? = decision == :modify

        def self.approve(payload = nil) = new(decision: :approve, payload: payload)
        def self.block(reason) = new(decision: :block, reason: reason)
        def self.modify(payload) = new(decision: :modify, payload: payload)
        def self.skip = new(decision: :skip)
      end

      # Context passed through hook chain
      Context = Struct.new(:event, :tool_name, :tool_input, :original_input, :metadata, keyword_init: true) do
        def [](key) = metadata&.[](key)
        def []=(key, value)
          self.metadata ||= {}
          metadata[key] = value
        end
      end

      class Runner
        def initialize(hooks = {})
          @hooks = hooks
          @cache = {} # Cache compiled matchers for O(1) lookup
        end

        def run(event, tool_name: nil, tool_input: nil, metadata: {})
          hooks = @hooks[event] || []
          return Result.approve(tool_input) if hooks.empty?

          context = Context.new(
            event: event,
            tool_name: tool_name,
            tool_input: tool_input&.dup,
            original_input: tool_input&.freeze,
            metadata: metadata
          )

          hooks.each do |hook|
            next unless matches?(hook, tool_name)

            result = execute_hook(hook, context)

            case result.decision
            when :block then return result
            when :modify then context.tool_input = result.payload
            when :skip then next
            end
          end

          Result.approve(context.tool_input)
        end

        private

        def matches?(hook, tool_name)
          return true unless hook[:matcher]

          matcher = hook[:matcher]
          case matcher
          when Regexp then matcher.match?(tool_name.to_s)
          when String then matcher == tool_name.to_s
          when Array then matcher.include?(tool_name.to_s)
          when Proc then matcher.call(tool_name)
          else matcher === tool_name
          end
        end

        def execute_hook(hook, context)
          result = hook[:handler].call(context)
          normalize_result(result, context)
        rescue StandardError
          # Log error but don't halt chain
          Result.approve(context.tool_input)
        end

        def normalize_result(result, context)
          case result
          when Result then result
          when true, nil then Result.approve(context.tool_input)
          when false then Result.block('Hook returned false')
          when Hash then Result.modify(context.tool_input.merge(result))
          else Result.approve(context.tool_input)
          end
        end
      end
    end
  end
end
