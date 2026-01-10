# frozen_string_literal: true

require 'timeout'

module RubyLLM
  module AgentSDK
    module Hooks
      # Event constants - mirrors TypeScript SDK HookEvent
      EVENTS = %i[
        pre_tool_use
        post_tool_use
        post_tool_use_failure
        notification
        user_prompt_submit
        session_start
        session_end
        stop
        subagent_start
        subagent_stop
        pre_compact
        permission_request
      ].freeze

      # Result decisions
      DECISIONS = %i[approve block modify skip].freeze

      # Permission decisions for PreToolUse hooks
      PERMISSION_DECISIONS = %i[allow deny ask].freeze

      # Hook result value object - mirrors TypeScript SDK HookJSONOutput
      Result = Struct.new(
        :decision, :payload, :reason,
        :additional_context, :system_message,
        :continue, :stop_reason, :suppress_output,
        :hook_specific_output, :async, :async_timeout,
        keyword_init: true
      ) do
        def approved? = decision == :approve
        def blocked? = decision == :block
        def modified? = decision == :modify
        def async? = async == true

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

        # Suppress output from being shown
        def self.suppress
          new(decision: :approve, continue: true, suppress_output: true)
        end

        # Async hook result
        def self.async(timeout: nil)
          new(async: true, async_timeout: timeout, continue: true)
        end

        # PreToolUse specific: allow/deny/ask permission
        def self.permission(decision, reason: nil, updated_input: nil)
          new(
            decision: :approve,
            continue: true,
            hook_specific_output: {
              hook_event_name: :pre_tool_use,
              permission_decision: decision,
              permission_decision_reason: reason,
              updated_input: updated_input
            }
          )
        end
      end

      # Base input for all hooks - mirrors TypeScript SDK BaseHookInput
      BaseInput = Struct.new(:session_id, :transcript_path, :cwd, :permission_mode, keyword_init: true)

      # PreToolUse hook input
      PreToolUseInput = Struct.new(
        :session_id, :transcript_path, :cwd, :permission_mode,
        :tool_name, :tool_input,
        keyword_init: true
      ) do
        def hook_event_name = :pre_tool_use
      end

      # PostToolUse hook input
      PostToolUseInput = Struct.new(
        :session_id, :transcript_path, :cwd, :permission_mode,
        :tool_name, :tool_input, :tool_response,
        keyword_init: true
      ) do
        def hook_event_name = :post_tool_use
      end

      # PostToolUseFailure hook input
      PostToolUseFailureInput = Struct.new(
        :session_id, :transcript_path, :cwd, :permission_mode,
        :tool_name, :tool_input, :error, :is_interrupt,
        keyword_init: true
      ) do
        def hook_event_name = :post_tool_use_failure
      end

      # Notification hook input
      NotificationInput = Struct.new(
        :session_id, :transcript_path, :cwd, :permission_mode,
        :message, :title,
        keyword_init: true
      ) do
        def hook_event_name = :notification
      end

      # UserPromptSubmit hook input
      UserPromptSubmitInput = Struct.new(
        :session_id, :transcript_path, :cwd, :permission_mode,
        :prompt,
        keyword_init: true
      ) do
        def hook_event_name = :user_prompt_submit
      end

      # SessionStart hook input
      SessionStartInput = Struct.new(
        :session_id, :transcript_path, :cwd, :permission_mode,
        :source, # 'startup' | 'resume' | 'clear' | 'compact'
        keyword_init: true
      ) do
        def hook_event_name = :session_start
      end

      # SessionEnd hook input
      SessionEndInput = Struct.new(
        :session_id, :transcript_path, :cwd, :permission_mode,
        :reason,
        keyword_init: true
      ) do
        def hook_event_name = :session_end
      end

      # Stop hook input
      StopInput = Struct.new(
        :session_id, :transcript_path, :cwd, :permission_mode,
        :stop_hook_active,
        keyword_init: true
      ) do
        def hook_event_name = :stop
      end

      # SubagentStart hook input
      SubagentStartInput = Struct.new(
        :session_id, :transcript_path, :cwd, :permission_mode,
        :agent_id, :agent_type,
        keyword_init: true
      ) do
        def hook_event_name = :subagent_start
      end

      # SubagentStop hook input
      SubagentStopInput = Struct.new(
        :session_id, :transcript_path, :cwd, :permission_mode,
        :stop_hook_active,
        keyword_init: true
      ) do
        def hook_event_name = :subagent_stop
      end

      # PreCompact hook input
      PreCompactInput = Struct.new(
        :session_id, :transcript_path, :cwd, :permission_mode,
        :trigger, :custom_instructions, # trigger: 'manual' | 'auto'
        keyword_init: true
      ) do
        def hook_event_name = :pre_compact
      end

      # PermissionRequest hook input
      PermissionRequestInput = Struct.new(
        :session_id, :transcript_path, :cwd, :permission_mode,
        :tool_name, :tool_input, :permission_suggestions,
        keyword_init: true
      ) do
        def hook_event_name = :permission_request
      end

      # Input type mapping
      INPUT_TYPES = {
        pre_tool_use: PreToolUseInput,
        post_tool_use: PostToolUseInput,
        post_tool_use_failure: PostToolUseFailureInput,
        notification: NotificationInput,
        user_prompt_submit: UserPromptSubmitInput,
        session_start: SessionStartInput,
        session_end: SessionEndInput,
        stop: StopInput,
        subagent_start: SubagentStartInput,
        subagent_stop: SubagentStopInput,
        pre_compact: PreCompactInput,
        permission_request: PermissionRequestInput
      }.freeze

      # Context passed through hook chain (legacy compatibility)
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

      # HookCallbackMatcher - mirrors TypeScript SDK
      class CallbackMatcher
        attr_reader :matcher, :hooks

        def initialize(matcher: nil, hooks: [])
          @matcher = matcher
          @hooks = hooks
        end
      end

      # Default fail mode for hook errors - :closed blocks operations, :open approves
      DEFAULT_FAIL_MODE = :closed

      # Logger for hook failures (can be configured)
      class << self
        attr_accessor :logger

        def log_hook_failure(error, hook, context)
          message = "Hook failed for #{context.event}/#{context.tool_name}: #{error.class.name}: #{error.message}"
          if logger
            logger.warn(message)
          else
            warn "[RubyLLM::AgentSDK::Hooks] #{message}"
          end
        end
      end

      class Runner
        def initialize(hooks = {}, fail_mode: DEFAULT_FAIL_MODE)
          @hooks = hooks
          @fail_mode = fail_mode
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
          when CallbackMatcher then matcher.matcher.nil? || matches_pattern?(matcher.matcher, tool_name)
          when Regexp then matcher.match?(tool_name.to_s)
          when String then matcher == tool_name.to_s
          when Array then matcher.include?(tool_name.to_s)
          when Proc then matcher.call(tool_name)
          else matcher === tool_name
          end
        end

        def matches_pattern?(pattern, tool_name)
          case pattern
          when Regexp then pattern.match?(tool_name.to_s)
          when String then pattern == tool_name.to_s
          when Array then pattern.include?(tool_name.to_s)
          when Proc then pattern.call(tool_name)
          else pattern === tool_name
          end
        end

        def execute_hook(hook, context)
          timeout_seconds = hook[:timeout] || Matcher::DEFAULT_TIMEOUT

          result = Timeout.timeout(timeout_seconds) do
            hook[:handler].call(context)
          end

          normalize_result(result, context)
        rescue Timeout::Error => e
          handle_hook_error(e, hook, context, 'Hook timed out')
        rescue StandardError => e
          handle_hook_error(e, hook, context, "Hook failed: #{e.class.name}")
        end

        def handle_hook_error(error, hook, context, reason)
          # Log the error
          Hooks.log_hook_failure(error, hook, context)

          # Determine fail mode: hook-specific > runner default
          fail_mode = hook[:fail_mode] || @fail_mode

          if fail_mode == :open
            # Backwards compatibility: approve on error (INSECURE - use with caution)
            Result.approve(context.tool_input)
          else
            # Fail-closed: block operation when hook errors (SECURE default)
            Result.block(reason)
          end
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
