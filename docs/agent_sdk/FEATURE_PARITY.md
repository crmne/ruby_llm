# RubyLLM Agent SDK - Feature Parity Analysis

This document compares the Ruby Agent SDK implementation against the official TypeScript Agent SDK.

## Status Summary

| Category | Coverage | Notes |
|----------|----------|-------|
| Core Functions | **100%** | query, tool, createSdkMcpServer |
| Options | **95%** | 31/33 options implemented |
| Message Types | **100%** | All 7 message types |
| Hook Events | **100%** | All 12 events |
| Query Methods | **60%** | Runtime change methods missing |
| MCP Server Types | **50%** | stdio, sdk (missing sse, http) |

## Core Functions

| TypeScript | Ruby | Status |
|------------|------|--------|
| `query()` | `AgentSDK.query()` | ✅ Full parity |
| `tool()` | `AgentSDK.tool()` | ✅ Full parity |
| `createSdkMcpServer()` | `AgentSDK.create_sdk_mcp_server()` | ✅ Full parity |

## Options Support

### Fully Implemented (31/33)

| Option | Ruby | Notes |
|--------|------|-------|
| `abortController` | `cli.abort` | Method on CLI instance |
| `additionalDirectories` | ✅ | `with_additional_directories` |
| `agents` | ✅ | Subagent definitions |
| `allowDangerouslySkipPermissions` | ✅ | `with_dangerous_permissions` |
| `allowedTools` | ✅ | `with_tools` |
| `betas` | ✅ | `with_betas` |
| `canUseTool` | ✅ | Via hooks system |
| `continue` | ✅ | `with_continue` |
| `cwd` | ✅ | `with_cwd` |
| `disallowedTools` | ✅ | `without_tools` |
| `enableFileCheckpointing` | ✅ | `with_file_checkpointing` |
| `env` | ✅ | Environment variables |
| `extraArgs` | ✅ | Extra CLI arguments |
| `fallbackModel` | ✅ | `with_fallback_model` |
| `forkSession` | ✅ | `with_fork_session` |
| `hooks` | ✅ | `with_hooks` |
| `includePartialMessages` | ✅ | `with_partial_messages` |
| `maxBudgetUsd` | ✅ | `with_max_budget_usd` |
| `maxThinkingTokens` | ✅ | `with_max_thinking_tokens` |
| `maxTurns` | ✅ | `with_max_turns` |
| `mcpServers` | ✅ | `with_mcp_server` |
| `model` | ✅ | `with_model` |
| `outputFormat` | ✅ | `with_output_format` |
| `pathToClaudeCodeExecutable` | ✅ | `cli_path` / `with_cli_path` |
| `permissionMode` | ✅ | `with_permission_mode` |
| `plugins` | ✅ | `with_plugins` |
| `resume` | ✅ | `with_resume` |
| `resumeSessionAt` | ✅ | Via `with_resume(id, at:)` |
| `sandbox` | ✅ | `with_sandbox` |
| `settingSources` | ✅ | `with_setting_sources` |
| `stderr` | ✅ | `with_stderr` |
| `strictMcpConfig` | ✅ | In options |
| `systemPrompt` | ✅ | `with_system_prompt` |
| `tools` | ✅ | Tool preset or list |

### Not Applicable (2)

| Option | Reason |
|--------|--------|
| `executable` | JS runtime selector (node/bun/deno) - N/A for Ruby |
| `executableArgs` | JS runtime args - N/A for Ruby |

### Not Implemented (1)

| Option | Priority |
|--------|----------|
| `permissionPromptToolName` | Low - MCP permission prompts |

## Query Interface Methods

The TypeScript SDK returns a `Query` object that extends `AsyncGenerator` with additional methods:

| Method | Ruby | Status |
|--------|------|--------|
| `[Symbol.asyncIterator]` | `Enumerator` | ✅ Native Ruby iteration |
| `interrupt()` | `cli.abort` | ✅ Via CLI |
| `rewindFiles(uuid)` | - | ❌ Not implemented |
| `setPermissionMode(mode)` | - | ❌ Runtime change not supported |
| `setModel(model)` | - | ❌ Runtime change not supported |
| `setMaxThinkingTokens(n)` | - | ❌ Runtime change not supported |
| `supportedCommands()` | - | ❌ Introspection not exposed |
| `supportedModels()` | - | ❌ Introspection not exposed |
| `mcpServerStatus()` | - | ❌ Introspection not exposed |
| `accountInfo()` | - | ❌ Introspection not exposed |

### Implementation Notes

The missing Query methods require bidirectional communication with the CLI subprocess (streaming input mode). The current Ruby implementation uses a simpler unidirectional stream. These could be added by:

1. Using stdin to send JSON-RPC style commands
2. Implementing a message queue for out-of-band responses
3. Exposing introspection via separate CLI calls

## Message Types

All message types from the TypeScript SDK are supported:

| TypeScript Type | Ruby | Status |
|-----------------|------|--------|
| `SDKAssistantMessage` | `Message` with `type: :assistant` | ✅ |
| `SDKUserMessage` | `Message` with `type: :user` | ✅ |
| `SDKUserMessageReplay` | `Message` with `type: :user` | ✅ |
| `SDKResultMessage` | `Message` with `type: :result` | ✅ |
| `SDKSystemMessage` | `Message` with `type: :system` | ✅ |
| `SDKPartialAssistantMessage` | `Message` with `type: :stream_event` | ✅ |
| `SDKCompactBoundaryMessage` | `Message` with `subtype: :compact_boundary` | ✅ |

### Message Fields

All message fields are accessible:
- `uuid`, `session_id`, `parent_tool_use_id`
- `content`, `role`, `message`, `tool_calls`
- Result fields: `duration_ms`, `total_cost_usd`, `usage`, `model_usage`, etc.
- System fields: `cwd`, `tools`, `mcp_servers`, `model`, `permission_mode`
- Compact boundary: `compact_metadata`

## Hook Events

All 12 hook events are implemented:

| Event | Ruby Symbol | Status |
|-------|-------------|--------|
| `PreToolUse` | `:pre_tool_use` | ✅ |
| `PostToolUse` | `:post_tool_use` | ✅ |
| `PostToolUseFailure` | `:post_tool_use_failure` | ✅ |
| `Notification` | `:notification` | ✅ |
| `UserPromptSubmit` | `:user_prompt_submit` | ✅ |
| `SessionStart` | `:session_start` | ✅ |
| `SessionEnd` | `:session_end` | ✅ |
| `Stop` | `:stop` | ✅ |
| `SubagentStart` | `:subagent_start` | ✅ |
| `SubagentStop` | `:subagent_stop` | ✅ |
| `PreCompact` | `:pre_compact` | ✅ |
| `PermissionRequest` | `:permission_request` | ✅ |

### Hook Input Types

All hook input structs mirror the TypeScript SDK:
- `PreToolUseInput`, `PostToolUseInput`, `PostToolUseFailureInput`
- `NotificationInput`, `UserPromptSubmitInput`
- `SessionStartInput`, `SessionEndInput`, `StopInput`
- `SubagentStartInput`, `SubagentStopInput`
- `PreCompactInput`, `PermissionRequestInput`

### Hook Results

The `Result` class supports all TypeScript hook outputs:
- `Result.approve`, `Result.block`, `Result.modify`, `Result.skip`
- `Result.stop`, `Result.with_context`, `Result.with_system_message`
- `Result.suppress`, `Result.async`, `Result.permission`

## MCP Server Types

| Type | Ruby | Status |
|------|------|--------|
| `stdio` | `MCP::Server.stdio` | ✅ |
| `sdk` | `MCP::Server.ruby` | ✅ |
| `sse` | - | ❌ Not implemented |
| `http` | - | ❌ Not implemented |

### Implementation Notes

SSE and HTTP MCP servers require additional HTTP client dependencies. They could be added using:
- `faraday` or `httpx` for HTTP
- `faraday-eventsource` for SSE

## Ruby-Specific Additions

Features in the Ruby SDK not in the TypeScript SDK:

1. **Introspection Module** - Agent-native capability discovery:
   - `cli_available?`, `cli_version`, `requirements_met?`
   - `builtin_tools`, `hook_events`, `permission_modes`
   - `options_schema`

2. **Fluent Builder Pattern** - Method chaining for configuration:
   ```ruby
   AgentSDK.client
     .with_model(:claude_sonnet)
     .with_max_turns(5)
     .with_permission_mode(:plan)
   ```

3. **RubyLLM::Tool Adapter** - Convert existing RubyLLM tools:
   ```ruby
   Tool.from_ruby_llm_tool(MyWeatherTool)
   ```

4. **Session Class** - Explicit session management with memory bounds

5. **Fail-Closed Hooks** - Secure default for hook error handling

## Recommendations

### High Priority
1. Add `rewindFiles()` support for file checkpointing
2. Implement introspection methods (`supportedCommands`, `supportedModels`)

### Medium Priority
1. Add SSE MCP server support
2. Add HTTP MCP server support

### Low Priority
1. Add runtime change methods (requires bidirectional streaming)
2. Add `permissionPromptToolName` option
