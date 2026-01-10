# feat: Ruby Agent SDK - Complete Port of Claude Agent SDK

**Created:** 2026-01-10
**Branch:** `feature/agent-sdk`
**Status:** In Progress
**Deepened:** 2026-01-10

## Enhancement Summary

**Research agents used:** 9 parallel agents
- best-practices-researcher (subprocess, enumerator, hooks)
- architecture-strategist
- security-sentinel
- performance-oracle
- code-simplicity-reviewer
- pattern-recognition-specialist
- agent-native-reviewer

### Key Improvements
1. **Gem-ready architecture** - Designed as standalone module extractable to separate gem
2. **Simplified file structure** - Reduced from 30+ files to ~15 files
3. **Security hardening** - Array-based subprocess spawning, path jailing, input validation
4. **Performance optimizations** - Oj for JSON, process pooling, hook caching
5. **Agent-native introspection** - BUILTIN_TOOLS, HookEvent::ALL, AgentOptions.schema

### Architecture Decision: Gem-Ready Module

The SDK is structured as `RubyLLM::AgentSDK` module that:
- Has zero dependencies on RubyLLM internals (only uses public API)
- Can be extracted to `ruby_llm-agent_sdk` gem later
- Uses its own autoloading configuration
- Declares `ruby_llm` as optional peer dependency

---

## Overview

Build a complete Ruby port of the Claude Agent SDK on top of RubyLLM with 100% feature parity to the Python/TypeScript Agent SDK. This SDK enables programmatic control of Claude Code CLI, allowing Ruby applications to spawn autonomous agents, manage permissions, define custom tools, and handle streaming responses.

## Problem Statement / Motivation

RubyLLM provides excellent primitives for interacting with LLMs, but lacks the higher-level agent orchestration capabilities available in Anthropic's official Agent SDK. Ruby developers building AI-powered applications need:

- **Autonomous agent execution** with file system access and tool use
- **Permission control** for safe automated workflows
- **Streaming responses** for real-time feedback
- **Subagent orchestration** for complex multi-step tasks
- **MCP server integration** for extensibility
- **Session management** for multi-turn conversations

---

## Technical Approach

### Architecture

The Ruby Agent SDK wraps Claude Code CLI, communicating via JSON-LD streaming over subprocess stdout. Designed as an independent module for future gem extraction.

```
┌─────────────────────────────────────────────────────────────┐
│                    Ruby Application                          │
├─────────────────────────────────────────────────────────────┤
│  RubyLLM::AgentSDK (standalone, gem-extractable)            │
│  ├── query()           - One-off queries (returns Enumerator)│
│  ├── Client            - Multi-turn conversations            │
│  ├── tool()            - Define custom tools                 │
│  └── create_sdk_mcp_server() - Create MCP servers           │
├─────────────────────────────────────────────────────────────┤
│  Core Components                                             │
│  ├── Options           - Simplified config with builder      │
│  ├── Message           - Single dynamic message class        │
│  ├── Hooks             - Single-file hook system             │
│  ├── Permissions       - Mode constants + callback           │
│  ├── MCP              - Server configurations                │
│  └── Tool             - Custom tool definitions              │
├─────────────────────────────────────────────────────────────┤
│  Infrastructure                                              │
│  ├── CLI              - Subprocess management + pooling      │
│  ├── Stream           - JSON-LD parsing with Oj              │
│  └── Session          - Resume/fork sessions                 │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    Claude Code CLI                           │
│  claude --print-only --output-format json-ld ...            │
└─────────────────────────────────────────────────────────────┘
```

### Research Insights: Subprocess Management

**Best Practices (from research):**
- Use `Open3.popen3` with threads for robust stdout/stderr handling
- Non-blocking IO with `IO.select` for cancellation support
- Always use array-based process spawning (NEVER string interpolation)
- Proper cleanup in `ensure` blocks to prevent zombies

```ruby
# SAFE: Array-based spawning (no shell interpretation)
Process.spawn("claude", "--session-id", session_id, "--prompt", user_input)

# DANGEROUS: String interpolation (command injection risk)
system("claude --session-id #{session_id}")  # NEVER DO THIS
```

### Research Insights: Enumerator Streaming

**Best Practices (from research):**
- Use `Enumerator.new` with yielder block
- Enable lazy enumeration for memory efficiency
- Handle cleanup via `ensure` in the Enumerator block
- TypeScript `AsyncIterable` maps directly to Ruby `Enumerator`

```ruby
def query(prompt, **options)
  Enumerator.new do |yielder|
    cli = CLI.new(options)
    begin
      cli.stream(prompt) do |line|
        message = Stream.parse(line)
        yielder << message
      end
    ensure
      cli.cleanup
    end
  end.lazy  # Enable lazy evaluation
end
```

---

## Simplified File Structure (Gem-Ready)

Based on simplicity review, reduced from 30+ to ~15 files:

```
lib/ruby_llm/agent_sdk/
├── agent_sdk.rb           # Entry point, facade methods
├── version.rb             # VERSION constant
├── errors.rb              # Error hierarchy with codes
├── options.rb             # Configuration with builder pattern
├── cli.rb                 # Subprocess management (Open3)
├── stream.rb              # JSON-LD parsing (Oj)
├── message.rb             # Single dynamic message class
├── hooks.rb               # Hook system (single file)
├── permissions.rb         # Permission modes + handler
├── mcp.rb                 # MCP server configs (stdio, sdk only)
├── tool.rb                # Custom tool definition
├── client.rb              # Multi-turn Client class
├── session.rb             # Session management
└── introspection.rb       # BUILTIN_TOOLS, schemas, cli_version
```

**Key simplifications:**
- 8 message classes → 1 dynamic `Message` class
- 4 hook files → 1 `hooks.rb` file
- 6 MCP files → 1 `mcp.rb` file (defer SSE/HTTP to v2)
- 3 permission files → 1 `permissions.rb` file
- Delete `builtin_tools.rb` (CLI knows them)

---

## Implementation Phases

### Phase 1: Core Infrastructure (MVP)

**Goal:** End-to-end `query()` working with streaming

**Files:**
- `lib/ruby_llm/agent_sdk.rb`
- `lib/ruby_llm/agent_sdk/version.rb`
- `lib/ruby_llm/agent_sdk/errors.rb`
- `lib/ruby_llm/agent_sdk/cli.rb`
- `lib/ruby_llm/agent_sdk/stream.rb`
- `lib/ruby_llm/agent_sdk/message.rb`
- `lib/ruby_llm/agent_sdk/options.rb`

#### cli.rb - Subprocess Management

**Research insights applied:**

```ruby
# lib/ruby_llm/agent_sdk/cli.rb
# frozen_string_literal: true

require 'open3'
require 'timeout'

module RubyLLM
  module AgentSDK
    class CLI
      COMMAND = 'claude'
      DEFAULT_ARGS = ['--print-only', '--output-format', 'stream-json'].freeze

      def initialize(options = {})
        @options = options
        @pid = nil
        @mutex = Mutex.new
        @shutdown = false
      end

      # Stream messages from CLI - SAFE array-based spawning
      def stream(prompt, &block)
        args = build_args(prompt)
        stderr_lines = []

        # CRITICAL: Use array form to prevent command injection
        Open3.popen3(COMMAND, *args) do |stdin, stdout, stderr, wait_thread|
          @mutex.synchronize { @pid = wait_thread.pid }
          stdin.close

          # Collect stderr in background thread
          stderr_thread = Thread.new do
            stderr.each_line { |line| stderr_lines << line.strip }
          end

          # Stream stdout with cancellation support
          stream_with_cancellation(stdout, &block)

          stderr_thread.join
          handle_exit(wait_thread.value, stderr_lines)
        end
      rescue Errno::ENOENT
        raise CLINotFoundError, "Claude CLI not found. Install from: npm install -g @anthropic-ai/claude-code"
      ensure
        @mutex.synchronize { @pid = nil }
      end

      def abort
        @shutdown = true
        kill_process
      end

      private

      def stream_with_cancellation(stdout, &block)
        buffer = String.new(capacity: 16_384)  # Pre-allocate buffer

        until stdout.eof? || @shutdown
          ready = IO.select([stdout], nil, nil, 0.1)
          next unless ready

          begin
            data = stdout.read_nonblock(4096)
            buffer << data

            while (idx = buffer.index("\n"))
              line = buffer.slice!(0, idx + 1).strip
              block.call(line) unless line.empty?
            end
          rescue IO::WaitReadable
            # No data yet
          rescue EOFError
            break
          end
        end

        # Process remaining buffer
        block.call(buffer.strip) unless buffer.strip.empty?
      end

      def build_args(prompt)
        args = DEFAULT_ARGS.dup

        # Add options - all validated, no shell interpolation
        args.push('--cwd', @options[:cwd]) if @options[:cwd]
        args.push('--model', @options[:model].to_s) if @options[:model]
        args.push('--max-turns', @options[:max_turns].to_s) if @options[:max_turns]
        args.push('--permission-mode', @options[:permission_mode].to_s) if @options[:permission_mode]
        args.push('--resume', @options[:resume]) if @options[:resume]

        # Prompt is passed as final argument (safe - no shell expansion)
        args.push('--prompt', prompt)

        args
      end

      def kill_process
        pid = @mutex.synchronize { @pid }
        return unless pid

        begin
          Process.kill('TERM', pid)
          Timeout.timeout(5) { Process.wait(pid) }
        rescue Timeout::Error
          Process.kill('KILL', pid) rescue nil
          Process.wait(pid) rescue nil
        rescue Errno::ESRCH, Errno::ECHILD
          # Already gone
        end
      end

      def handle_exit(status, stderr_lines)
        return if status.success?

        raise ProcessError.new(
          "CLI exited with code #{status.exitstatus}",
          exit_code: status.exitstatus,
          stderr: stderr_lines.join("\n"),
          error_code: :cli_error
        )
      end
    end
  end
end
```

#### stream.rb - JSON Parsing with Oj

**Performance insight:** Oj is 5-6x faster than stdlib JSON

```ruby
# lib/ruby_llm/agent_sdk/stream.rb
# frozen_string_literal: true

begin
  require 'oj'
  OJ_AVAILABLE = true
rescue LoadError
  OJ_AVAILABLE = false
end

module RubyLLM
  module AgentSDK
    class Stream
      JSON_OPTIONS = OJ_AVAILABLE ?
        { mode: :compat, symbol_keys: true }.freeze :
        { symbolize_names: true }.freeze

      def self.parse(line)
        return nil if line.nil? || line.empty?

        json = OJ_AVAILABLE ?
          Oj.load(line, JSON_OPTIONS) :
          JSON.parse(line, JSON_OPTIONS)

        Message.new(json)
      rescue (OJ_AVAILABLE ? Oj::ParseError : JSON::ParserError) => e
        raise JSONDecodeError.new("Failed to parse JSON", line: line, original_error: e)
      end
    end
  end
end
```

#### message.rb - Single Dynamic Message Class

**Simplicity insight:** One class handles all message types via duck typing

```ruby
# lib/ruby_llm/agent_sdk/message.rb
# frozen_string_literal: true

module RubyLLM
  module AgentSDK
    class Message
      attr_reader :type, :data

      MESSAGE_TYPES = %i[
        system user assistant result partial init
        tool_use tool_result error
      ].freeze

      def initialize(json)
        @data = json.freeze
        @type = json[:type]&.to_sym || infer_type(json)
      end

      # Type predicates
      MESSAGE_TYPES.each do |t|
        define_method(:"#{t}?") { type == t }
      end

      # Dynamic attribute access
      def method_missing(name, *args)
        return @data[name] if @data.key?(name)
        return @data[name.to_s] if @data.key?(name.to_s)
        super
      end

      def respond_to_missing?(name, include_private = false)
        @data.key?(name) || @data.key?(name.to_s) || super
      end

      # Common accessors
      def content
        @data[:content] || @data[:text] || @data[:message]
      end

      def role
        @data[:role]&.to_sym
      end

      def tool_calls
        @data[:tool_use] || @data[:tool_calls] || []
      end

      def session_id
        @data[:session_id] || @data[:sessionId]
      end

      def cost_usd
        @data[:cost_usd] || @data[:costUsd]
      end

      def to_h
        @data
      end

      private

      def infer_type(json)
        return :assistant if json[:role] == 'assistant'
        return :user if json[:role] == 'user'
        return :system if json[:role] == 'system'
        return :tool_use if json[:tool_use] || json[:tool_calls]
        return :tool_result if json[:tool_result]
        :unknown
      end
    end
  end
end
```

#### options.rb - Builder Pattern Configuration

**Pattern insight:** Match RubyLLM's fluent `with_*` interface

```ruby
# lib/ruby_llm/agent_sdk/options.rb
# frozen_string_literal: true

module RubyLLM
  module AgentSDK
    class Options
      # Schema for introspection (agent-native)
      SCHEMA = {
        prompt: { type: String, required: true },
        allowed_tools: { type: Array, default: [] },
        disallowed_tools: { type: Array, default: [] },
        permission_mode: { type: Symbol, default: :default, enum: Permissions::MODES },
        model: { type: Symbol, default: nil },
        max_turns: { type: Integer, default: nil },
        cwd: { type: String, default: nil },
        resume: { type: String, default: nil },
        system_prompt: { type: String, default: nil },
        mcp_servers: { type: Hash, default: {} },
        hooks: { type: Hash, default: {} },
        can_use_tool: { type: Proc, default: nil },
        env: { type: Hash, default: {} },
        timeout: { type: Integer, default: nil }
      }.freeze

      attr_accessor(*SCHEMA.keys)

      def initialize(**attrs)
        SCHEMA.each do |key, config|
          instance_variable_set(:"@#{key}", attrs.fetch(key, config[:default]))
        end
      end

      # Fluent builder methods (match Chat's with_* pattern)
      def with_tools(*tools)
        @allowed_tools = tools.flatten
        self
      end

      def with_model(model)
        @model = model.to_sym
        self
      end

      def with_permission_mode(mode)
        @permission_mode = mode.to_sym
        self
      end

      def with_cwd(path)
        @cwd = File.expand_path(path)
        self
      end

      def with_hooks(hooks)
        @hooks = hooks
        self
      end

      def with_mcp_server(name, server)
        @mcp_servers[name.to_sym] = server
        self
      end

      # Class methods for introspection (agent-native)
      class << self
        def schema
          SCHEMA
        end

        def attribute_names
          SCHEMA.keys
        end

        def build
          new
        end
      end

      def to_h
        SCHEMA.keys.each_with_object({}) do |key, hash|
          value = send(key)
          hash[key] = value unless value.nil? || (value.respond_to?(:empty?) && value.empty?)
        end
      end

      def to_cli_args
        # Convert to CLI arguments
        {
          cwd: @cwd,
          model: @model,
          max_turns: @max_turns,
          permission_mode: @permission_mode,
          resume: @resume
        }.compact
      end
    end
  end
end
```

#### errors.rb - Error Hierarchy with Codes

**Agent-native insight:** Add error codes for programmatic handling

```ruby
# lib/ruby_llm/agent_sdk/errors.rb
# frozen_string_literal: true

module RubyLLM
  module AgentSDK
    class Error < StandardError
      attr_reader :error_code

      def initialize(message, error_code: :unknown)
        @error_code = error_code
        super(message)
      end

      def to_h
        { code: error_code, message: message }
      end
    end

    class CLINotFoundError < Error
      def initialize(message = "Claude CLI not found")
        super(message, error_code: :cli_not_found)
      end
    end

    class ProcessError < Error
      attr_reader :exit_code, :stderr

      def initialize(message, exit_code: nil, stderr: nil, error_code: :process_error)
        @exit_code = exit_code
        @stderr = stderr
        super(message, error_code: error_code)
      end

      def to_h
        super.merge(exit_code: exit_code, stderr: stderr)
      end
    end

    class JSONDecodeError < Error
      attr_reader :line, :original_error

      def initialize(message, line: nil, original_error: nil)
        @line = line
        @original_error = original_error
        super(message, error_code: :json_decode_error)
      end

      def to_h
        super.merge(line: line&.slice(0, 200))
      end
    end

    class TimeoutError < Error
      def initialize(message = "Operation timed out")
        super(message, error_code: :timeout)
      end
    end

    class AbortError < Error
      def initialize(message = "Operation aborted")
        super(message, error_code: :aborted)
      end
    end

    class PermissionDeniedError < Error
      attr_reader :tool_name, :reason

      def initialize(message, tool_name: nil, reason: nil)
        @tool_name = tool_name
        @reason = reason
        super(message, error_code: :permission_denied)
      end
    end

    class SecurityError < Error
      def initialize(message)
        super(message, error_code: :security_error)
      end
    end
  end
end
```

**Acceptance Criteria Phase 1:**
- [ ] Can spawn Claude CLI with correct arguments
- [ ] Streams messages as Enumerator
- [ ] Properly handles process termination
- [ ] Raises appropriate errors for missing CLI
- [ ] JSON parsing uses Oj when available

---

### Phase 2: Hooks, Permissions, Tools

**Files:**
- `lib/ruby_llm/agent_sdk/hooks.rb`
- `lib/ruby_llm/agent_sdk/permissions.rb`
- `lib/ruby_llm/agent_sdk/tool.rb`
- `lib/ruby_llm/agent_sdk/mcp.rb`

#### hooks.rb - Single-File Hook System

**Research insights applied:**

```ruby
# lib/ruby_llm/agent_sdk/hooks.rb
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
        def [](key) = metadata[key]
        def []=(key, value) = metadata[key] = value
      end

      class Runner
        def initialize(hooks = {})
          @hooks = hooks
          @cache = {}  # Cache compiled matchers for O(1) lookup
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
        rescue => e
          # Log error but don't halt chain
          Result.approve(context.tool_input)
        end

        def normalize_result(result, context)
          case result
          when Result then result
          when true, nil then Result.approve(context.tool_input)
          when false then Result.block("Hook returned false")
          when Hash then Result.modify(context.tool_input.merge(result))
          else Result.approve(context.tool_input)
          end
        end
      end
    end
  end
end
```

#### permissions.rb - Permission Modes

```ruby
# lib/ruby_llm/agent_sdk/permissions.rb
# frozen_string_literal: true

module RubyLLM
  module AgentSDK
    module Permissions
      # Permission mode constants
      DEFAULT = :default
      ACCEPT_EDITS = :accept_edits
      DONT_ASK = :dont_ask
      BYPASS = :bypass_permissions
      PLAN = :plan

      MODES = [DEFAULT, ACCEPT_EDITS, DONT_ASK, BYPASS, PLAN].freeze

      # Tools auto-approved in accept_edits mode
      ACCEPT_EDITS_TOOLS = %w[Edit Write].freeze
      ACCEPT_EDITS_COMMANDS = %w[mkdir touch rm mv cp].freeze

      class << self
        def valid?(mode)
          MODES.include?(mode.to_sym)
        end

        def auto_approve?(mode, tool_name, tool_input = {})
          case mode.to_sym
          when BYPASS then true
          when ACCEPT_EDITS then accept_edits_auto_approve?(tool_name, tool_input)
          when DONT_ASK then nil  # Defer to callback
          when PLAN then false    # Never auto-approve in plan mode
          else nil
          end
        end

        private

        def accept_edits_auto_approve?(tool_name, tool_input)
          return true if ACCEPT_EDITS_TOOLS.include?(tool_name)

          if tool_name == 'Bash'
            cmd = (tool_input[:command] || tool_input['command'] || '').split.first
            return true if cmd && ACCEPT_EDITS_COMMANDS.include?(cmd)
          end

          nil
        end
      end

      # Result from permission check
      Result = Struct.new(:behavior, :updated_input, :message, keyword_init: true) do
        def allow? = behavior == :allow
        def deny? = behavior == :deny
        def ask? = behavior == :ask

        def self.allow(input = nil) = new(behavior: :allow, updated_input: input)
        def self.deny(message = nil) = new(behavior: :deny, message: message)
        def self.ask = new(behavior: :ask)
      end
    end
  end
end
```

#### tool.rb - Custom Tool Definition

```ruby
# lib/ruby_llm/agent_sdk/tool.rb
# frozen_string_literal: true

module RubyLLM
  module AgentSDK
    class Tool
      attr_reader :name, :description, :input_schema, :handler

      def initialize(name:, description:, input_schema: {}, &handler)
        @name = name.to_s
        @description = description
        @input_schema = normalize_schema(input_schema)
        @handler = handler
      end

      def call(input)
        @handler.call(input)
      end

      def to_mcp_schema
        {
          name: @name,
          description: @description,
          inputSchema: @input_schema
        }
      end

      # Adapter from existing RubyLLM::Tool class
      def self.from_ruby_llm_tool(tool_class)
        instance = tool_class.new
        new(
          name: instance.name,
          description: tool_class.description,
          input_schema: convert_parameters(tool_class.parameters)
        ) { |args| instance.call(**args.transform_keys(&:to_sym)) }
      end

      private

      def normalize_schema(schema)
        return schema if schema[:type]

        {
          type: 'object',
          properties: schema,
          required: schema.keys.map(&:to_s)
        }
      end

      def self.convert_parameters(params)
        return {} unless params

        properties = {}
        required = []

        params.each do |name, param|
          properties[name.to_s] = {
            type: ruby_type_to_json(param.type),
            description: param.description
          }
          required << name.to_s if param.required
        end

        { type: 'object', properties: properties, required: required }
      end

      def self.ruby_type_to_json(type)
        case type.to_s.downcase
        when 'string' then 'string'
        when 'integer', 'int' then 'integer'
        when 'float', 'number' then 'number'
        when 'boolean', 'bool' then 'boolean'
        when 'array' then 'array'
        when 'hash', 'object' then 'object'
        else 'string'
        end
      end
    end
  end
end
```

#### mcp.rb - MCP Server Configurations

```ruby
# lib/ruby_llm/agent_sdk/mcp.rb
# frozen_string_literal: true

module RubyLLM
  module AgentSDK
    module MCP
      class Server
        attr_reader :type, :config

        def initialize(type, **config)
          @type = type.to_sym
          @config = config.freeze
        end

        # Factory for stdio MCP servers
        def self.stdio(command:, args: [], env: {})
          new(:stdio, command: command, args: args, env: env)
        end

        # Factory for Ruby-native tool servers (SDK type)
        def self.ruby(tools:)
          new(:sdk, tools: tools)
        end

        def to_cli_config
          case @type
          when :stdio
            { type: 'stdio', command: @config[:command], args: @config[:args], env: @config[:env] }
          when :sdk
            { type: 'sdk', tools: @config[:tools].map(&:to_mcp_schema) }
          else
            { type: @type.to_s, **@config }
          end
        end
      end
    end
  end
end
```

**Acceptance Criteria Phase 2:**
- [ ] Hooks can block tool execution
- [ ] Hooks can modify tool input
- [ ] Multiple hooks chain correctly
- [ ] Permission modes work as expected
- [ ] Custom tools can be defined with blocks
- [ ] MCP servers can be configured

---

### Phase 3: Client, Session, Introspection

**Files:**
- `lib/ruby_llm/agent_sdk/client.rb`
- `lib/ruby_llm/agent_sdk/session.rb`
- `lib/ruby_llm/agent_sdk/introspection.rb`

#### introspection.rb - Agent-Native Discovery

```ruby
# lib/ruby_llm/agent_sdk/introspection.rb
# frozen_string_literal: true

module RubyLLM
  module AgentSDK
    module Introspection
      # All 17 built-in tools (agent-native discovery)
      BUILTIN_TOOLS = %w[
        Agent AskUserQuestion Bash Edit ExitPlanMode EnterPlanMode
        Glob Grep KillShell LS NotebookEdit Read TaskOutput
        TodoWrite WebFetch WebSearch Write
      ].freeze

      class << self
        def cli_available?
          system('which claude > /dev/null 2>&1')
        end

        def cli_version
          `claude --version 2>/dev/null`.strip.presence
        rescue
          nil
        end

        def requirements_met?
          {
            cli_available: cli_available?,
            cli_version: cli_version,
            oj_available: defined?(Oj) ? true : false
          }
        end

        def builtin_tools
          BUILTIN_TOOLS
        end

        def hook_events
          Hooks::EVENTS
        end

        def permission_modes
          Permissions::MODES
        end

        def options_schema
          Options::SCHEMA
        end
      end
    end
  end
end
```

#### client.rb - Multi-Turn Client

```ruby
# lib/ruby_llm/agent_sdk/client.rb
# frozen_string_literal: true

module RubyLLM
  module AgentSDK
    class Client
      attr_reader :session_id, :options

      def initialize(**options)
        @options = Options.new(**options)
        @session_id = nil
        @cli = nil
        @mutex = Mutex.new
      end

      def query(prompt)
        opts = @options.to_cli_args
        opts[:resume] = @session_id if @session_id

        Enumerator.new do |yielder|
          @cli = CLI.new(opts)

          @cli.stream(prompt) do |line|
            message = Stream.parse(line)

            # Capture session ID from result message
            @session_id ||= message.session_id if message.result?

            yielder << message
          end
        ensure
          @mutex.synchronize { @cli = nil }
        end.lazy
      end

      def abort
        @mutex.synchronize { @cli&.abort }
      end

      def close
        abort
        @session_id = nil
      end

      def capabilities
        {
          tools: @options.allowed_tools,
          permission_mode: @options.permission_mode,
          max_turns: @options.max_turns,
          model: @options.model
        }
      end
    end
  end
end
```

**Acceptance Criteria Phase 3:**
- [ ] Client maintains session across queries
- [ ] Can resume previous sessions
- [ ] Agent can introspect available tools
- [ ] Agent can check CLI availability
- [ ] Agent can discover hook events

---

## Main Entry Point

```ruby
# lib/ruby_llm/agent_sdk.rb
# frozen_string_literal: true

require_relative 'agent_sdk/version'
require_relative 'agent_sdk/errors'
require_relative 'agent_sdk/permissions'
require_relative 'agent_sdk/hooks'
require_relative 'agent_sdk/options'
require_relative 'agent_sdk/stream'
require_relative 'agent_sdk/message'
require_relative 'agent_sdk/cli'
require_relative 'agent_sdk/tool'
require_relative 'agent_sdk/mcp'
require_relative 'agent_sdk/client'
require_relative 'agent_sdk/session'
require_relative 'agent_sdk/introspection'

module RubyLLM
  module AgentSDK
    class << self
      # One-off query - returns Enumerator
      def query(prompt = nil, **options)
        opts = Options.new(**options)

        Enumerator.new do |yielder|
          cli = CLI.new(opts.to_cli_args)
          hook_runner = Hooks::Runner.new(opts.hooks)

          cli.stream(prompt || opts.prompt) do |line|
            message = Stream.parse(line)
            yielder << message
          end
        end.lazy
      end

      # Create multi-turn client
      def client(**options)
        Client.new(**options)
      end

      # Define custom tool
      def tool(name:, description:, input_schema: {}, &handler)
        Tool.new(name: name, description: description, input_schema: input_schema, &handler)
      end

      # Create MCP server for Ruby tools
      def create_sdk_mcp_server(tools:)
        MCP::Server.ruby(tools: tools)
      end

      # Introspection (agent-native)
      delegate :cli_available?, :cli_version, :requirements_met?,
               :builtin_tools, :hook_events, :permission_modes, :options_schema,
               to: Introspection
    end
  end
end
```

---

## Security Requirements (from Security Review)

| Requirement | Implementation |
|------------|----------------|
| **Array-based CLI spawning** | All `Process.spawn`/`Open3.popen3` use array form, never strings |
| **Input validation** | Options validated via schema before CLI invocation |
| **Path sanitization** | File paths expanded and validated against traversal |
| **Session ID security** | Use `SecureRandom.urlsafe_base64(32)` for IDs |
| **Environment filtering** | Only whitelisted env vars passed to subprocess |
| **Error message sanitization** | Secrets masked in error output |

---

## Performance Requirements (from Performance Review)

| Optimization | Implementation |
|--------------|----------------|
| **Oj for JSON** | Use Oj when available (5-6x faster) |
| **Pre-allocated buffers** | `String.new(capacity: 16_384)` in streaming |
| **Hook caching** | Cache compiled matchers for O(1) lookup |
| **Lazy enumeration** | Return `.lazy` Enumerators for memory efficiency |
| **Non-blocking IO** | Use `IO.select` with 100ms timeout for cancellation |

---

## Testing Strategy

```
spec/ruby_llm/agent_sdk/
├── agent_sdk_spec.rb         # Integration tests
├── cli_spec.rb               # Subprocess tests (mock Open3)
├── stream_spec.rb            # JSON parsing tests
├── message_spec.rb           # Message class tests
├── options_spec.rb           # Configuration tests
├── hooks_spec.rb             # Hook system tests
├── permissions_spec.rb       # Permission mode tests
├── tool_spec.rb              # Tool definition tests
├── mcp_spec.rb               # MCP config tests
├── client_spec.rb            # Client tests
├── introspection_spec.rb     # Discovery tests
└── fixtures/
    └── messages/             # Sample JSON-LD messages
```

---

## Dependencies

**Required:**
- Claude Code CLI (`npm install -g @anthropic-ai/claude-code`)
- Ruby 3.1+

**Optional (recommended):**
- `oj` gem for 5-6x faster JSON parsing

**Future gem extraction:**
```ruby
# ruby_llm-agent_sdk.gemspec
Gem::Specification.new do |spec|
  spec.name = 'ruby_llm-agent_sdk'
  spec.version = RubyLLM::AgentSDK::VERSION

  spec.add_dependency 'oj', '~> 3.16'
  spec.add_development_dependency 'ruby_llm'  # Optional peer
end
```

---

## Success Metrics

- [ ] 100% feature parity with TypeScript SDK
- [ ] All 17 built-in tools accessible
- [ ] All 9 hook events implemented
- [ ] All 5 permission modes working
- [ ] MCP stdio and SDK server types supported
- [ ] >90% test coverage
- [ ] Agent-native introspection complete
- [ ] Gem-ready structure (extractable)
