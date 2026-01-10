# frozen_string_literal: true

module RubyLLM
  module AgentSDK
    # Hook system for intercepting and modifying agent behavior
    #
    # Hooks allow you to:
    # - Block dangerous tool executions
    # - Modify tool inputs before execution
    # - Log tool usage for auditing
    # - Implement custom permission logic
    #
    # @example Block dangerous commands
    #   hooks = {
    #     pre_tool_use: [
    #       {
    #         matcher: 'Bash',
    #         handler: ->(ctx) {
    #           if ctx.tool_input[:command]&.include?('rm -rf')
    #             Hooks::Result.block("Dangerous command blocked")
    #           else
    #             Hooks::Result.approve
    #           end
    #         }
    #       }
    #     ]
    #   }
    module Hooks
      # All supported hook events (agent-native introspection)
      EVENTS = %i[
        pre_tool_use
        post_tool_use
        stop
        subagent_stop
        session_start
        session_end
        user_prompt_submit
        pre_compact
        notification
      ].freeze

      # Hook result decisions
      DECISIONS = %i[approve block modify skip].freeze

      # Result from a hook execution
      #
      # @example Approve tool use
      #   Result.approve
      #
      # @example Block with reason
      #   Result.block("Security policy violation")
      #
      # @example Modify input
      #   Result.modify(sanitized_input)
      Result = Struct.new(:decision, :payload, :reason, keyword_init: true) do
        def approved? = decision == :approve
        def blocked? = decision == :block
        def modified? = decision == :modify
        def skipped? = decision == :skip

        def self.approve(payload = nil)
          new(decision: :approve, payload: payload)
        end

        def self.block(reason)
          new(decision: :block, reason: reason)
        end

        def self.modify(payload)
          new(decision: :modify, payload: payload)
        end

        def self.skip
          new(decision: :skip)
        end
      end

      # Context passed through hook chain
      #
      # Provides access to tool information and allows hooks to
      # share data via the metadata hash.
      Context = Struct.new(:event, :tool_name, :tool_input, :original_input, :metadata, keyword_init: true) do
        def [](key)
          metadata[key]
        end

        def []=(key, value)
          metadata[key] = value
        end
      end

      # Executes hooks in chain, supporting early termination
      #
      # The runner evaluates hooks in order, stopping if any hook
      # returns a :block decision. Modified inputs are passed through
      # the chain.
      class Runner
        def initialize(hooks = {})
          @hooks = hooks || {}
          @matcher_cache = {} # Cache compiled matchers for O(1) lookup
        end

        # Run all hooks for an event
        #
        # @param event [Symbol] The hook event type
        # @param tool_name [String, nil] Name of the tool (for tool events)
        # @param tool_input [Hash, nil] Tool input parameters
        # @param metadata [Hash] Additional context data
        # @return [Result] The final hook result
        def run(event, tool_name: nil, tool_input: nil, metadata: {})
          hooks = @hooks[event] || []
          return Result.approve(tool_input) if hooks.empty?

          context = Context.new(
            event: event,
            tool_name: tool_name,
            tool_input: tool_input&.dup,
            original_input: tool_input&.freeze,
            metadata: metadata || {}
          )

          hooks.each do |hook|
            next unless matches?(hook, tool_name)

            result = execute_hook(hook, context)

            case result.decision
            when :block
              return result
            when :modify
              context.tool_input = result.payload
            when :skip
              next
            end
          end

          Result.approve(context.tool_input)
        end

        private

        def matches?(hook, tool_name)
          return true unless hook[:matcher]

          matcher = hook[:matcher]
          cache_key = [matcher, tool_name]

          @matcher_cache[cache_key] ||= compute_match(matcher, tool_name)
        end

        def compute_match(matcher, tool_name)
          case matcher
          when Regexp
            matcher.match?(tool_name.to_s)
          when String
            matcher == tool_name.to_s
          when Array
            matcher.include?(tool_name.to_s)
          when Proc
            matcher.call(tool_name)
          else
            matcher === tool_name
          end
        end

        def execute_hook(hook, context)
          handler = hook[:handler] || hook[:hook]
          result = handler.call(context)
          normalize_result(result, context)
        rescue StandardError => e
          # Log error but don't halt chain for non-critical hooks
          warn "[AgentSDK] Hook error: #{e.message}" if $VERBOSE
          Result.approve(context.tool_input)
        end

        def normalize_result(result, context)
          case result
          when Result
            result
          when true, nil
            Result.approve(context.tool_input)
          when false
            Result.block('Hook returned false')
          when Hash
            if result[:decision]
              Result.new(**result)
            else
              Result.modify(context.tool_input.merge(result))
            end
          else
            Result.approve(context.tool_input)
          end
        end
      end
    end
  end
end
