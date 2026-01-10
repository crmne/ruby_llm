# frozen_string_literal: true

module RubyLLM
  class Agent
    # Hook system for intercepting tool executions
    #
    # Example:
    #   agent.before_tool('Bash') do |ctx|
    #     if ctx.arguments[:command]&.include?('rm -rf')
    #       ctx.block!
    #     end
    #   end
    class Hooks
      def initialize
        @hooks = { before: [], after: [] }
      end

      # Add a hook
      #
      # @param phase [Symbol] :before or :after
      # @param pattern [String, Regexp, nil] Tool name pattern (nil matches all)
      # @yield [HookContext]
      def add(phase, pattern = nil, &block)
        @hooks[phase] << { pattern: pattern, handler: block }
      end

      # Run hooks for a phase
      #
      # @param phase [Symbol] :before or :after
      # @param context [HookContext]
      def run(phase, context)
        @hooks[phase].each do |hook|
          next unless matches?(hook[:pattern], context.tool_name)

          hook[:handler].call(context)
          break if context.blocked?
        end
      end

      private

      def matches?(pattern, tool_name)
        case pattern
        when nil then true
        when String then pattern == tool_name
        when Regexp then pattern.match?(tool_name)
        when Array then pattern.include?(tool_name)
        else pattern === tool_name
        end
      end
    end
  end
end
