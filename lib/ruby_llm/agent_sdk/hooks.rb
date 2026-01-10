# frozen_string_literal: true

require 'timeout'

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

      # Hook result value object with advanced output fields
      Result = Struct.new(
        :decision, :payload, :reason,
        :additional_context, :system_message,
        :continue, :stop_reason,
        keyword_init: true
      ) do
        def approved? = decision == :approve
        def blocked? = decision == :block
        def modified? = decision == :modify

        def self.approve(payload = nil)
          new(decision: :approve, payload: payload, continue: true)
        end

        def self.block(reason)
          new(decision: :block, reason: reason, continue: true)
        end

        def self.modify(payload)
          new(decision: :modify, payload: payload, continue: true)
        end

        def self.skip
          new(decision: :skip, continue: true)
        end

        # Stop the agent with a reason
        def self.stop(reason)
          new(decision: :approve, continue: false, stop_reason: reason)
        end

        # Approve with additional context for Claude
        def self.with_context(context)
          new(decision: :approve, additional_context: context, continue: true)
        end

        # Approve with system message injection
        def self.with_system_message(message)
          new(decision: :approve, system_message: message, continue: true)
        end
      end

      # Context passed through hook chain
      Context = Struct.new(:event, :tool_name, :tool_input, :original_input, :metadata, keyword_init: true) do
        def [](key) = metadata&.[](key)
        def []=(key, value)
          self.metadata ||= {}
          metadata[key] = value
        end
      end

      # Matcher for filtering which tools trigger hooks
      class Matcher
        attr_reader :pattern, :handlers, :timeout

        DEFAULT_TIMEOUT = 60

        def initialize(pattern: nil, handlers: [], timeout: DEFAULT_TIMEOUT)
          @pattern = pattern
          @handlers = handlers
          @timeout = timeout
        end

        def matches?(tool_name)
          return true if @pattern.nil?

          case @pattern
          when Regexp then @pattern.match?(tool_name.to_s)
          when String then @pattern == tool_name.to_s
          when Array then @pattern.include?(tool_name.to_s)
          when Proc then @pattern.call(tool_name)
          else @pattern === tool_name
          end
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

          # Accumulate context and messages across hooks
          accumulated_context = nil
          accumulated_message = nil

          hooks.each do |hook|
            next unless matches?(hook, tool_name)

            result = execute_hook(hook, context)

            # Accumulate additional context and system messages
            accumulated_context = result.additional_context if result.additional_context
            accumulated_message = result.system_message if result.system_message

            case result.decision
            when :block then return result
            when :modify then context.tool_input = result.payload
            when :skip then next
            end

            # Handle continue=false (stop agent)
            return result unless result.continue
          end

          Result.new(
            decision: :approve,
            payload: context.tool_input,
            continue: true,
            additional_context: accumulated_context,
            system_message: accumulated_message
          )
        end

        private

        def matches?(hook, tool_name)
          matcher = hook[:matcher]
          return true if matcher.nil?

          case matcher
          when Matcher then matcher.matches?(tool_name)
          when Regexp then matcher.match?(tool_name.to_s)
          when String then matcher == tool_name.to_s
          when Array then matcher.include?(tool_name.to_s)
          when Proc then matcher.call(tool_name)
          else matcher === tool_name
          end
        end

        def execute_hook(hook, context)
          timeout_seconds = hook[:timeout] || Matcher::DEFAULT_TIMEOUT

          result = Timeout.timeout(timeout_seconds) do
            hook[:handler].call(context)
          end

          normalize_result(result, context)
        rescue Timeout::Error
          # Timeout - approve by default
          Result.approve(context.tool_input)
        rescue StandardError
          # Log error but don't halt chain
          Result.approve(context.tool_input)
        end

        def normalize_result(result, context)
          case result
          when Result then result
          when true, nil then Result.approve(context.tool_input)
          when false then Result.block('Hook returned false')
          when Hash
            if result[:decision]
              Result.new(**result)
            else
              Result.modify(context.tool_input.merge(result))
            end
          else Result.approve(context.tool_input)
          end
        end
      end
    end
  end
end
