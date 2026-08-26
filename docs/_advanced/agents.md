---
layout: default
title: Agents
nav_order: 2
has_children: true
description: Define reusable AI assistants with class-based configuration, runtime context, and prompt conventions
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* How to define agents with a class-based DSL
* How to use agents with plain Ruby chats and Rails-backed chats
* How runtime context works (`chat`, `inputs`, and lazy evaluation)
* How prompt conventions work in `app/prompts`
* Which methods are available on agent instances
* How to handle errors for a whole agent with `rescue_from`

## What Are Agents?

Agents are a class-based way to define a chat setup once and reuse it everywhere.

For example, instead of re-adding the same instructions and tools in every controller, job, or service, you define them once in an agent class and call that agent wherever you need it.

```ruby
class SupportAgent < RubyLLM::Agent
  model "{{ site.models.default_chat }}"
  instructions "You are a concise support assistant."
  tools SearchDocs, LookupAccount
end

response = SupportAgent.new.ask "How do I reset my API key?"
```

In other words, an agent is a named wrapper around the same configuration you would otherwise apply progressively with `chat.with_*` calls (`with_instructions`, `with_tools`, `with_provider_options`, and so on).

Agents work in two modes:

* Plain Ruby mode via `.chat` (returns `RubyLLM::Chat`)
* Rails mode via `.create/.create!/.find` when `chat_model` is configured (returns your ActiveRecord chat model)

Example of Rails mode:

```ruby
class WorkAssistant < RubyLLM::Agent
  chat_model Chat  # this activates the Rails integration
  model "{{ site.models.default_chat }}"
  instructions "You are a helpful assistant."
  tools SearchDocs, LookupAccount
end

chat = WorkAssistant.create!(user: current_user)
same_chat = WorkAssistant.find(chat.id)
```

## Defining an Agent

Create a class that inherits from `RubyLLM::Agent` and declare its configuration:

```ruby
# app/agents/work_assistant.rb
class WorkAssistant < RubyLLM::Agent
  model "{{ site.models.default_chat }}"
  instructions "You are a helpful assistant."
  tools SearchDocs, LookupAccount
  temperature 0.2
  max_output_tokens 256
end
```

Supported class macros:

These macros use the same arguments you already know from `RubyLLM.chat(...)` and `Chat#with_*` methods.
For example, `model` maps to `RubyLLM.chat(model:, provider:, ...)`, `tools` maps to `with_tools`, `tool_options` maps to `with_tool_options`, `instructions` maps to `with_instructions`, and so on.

* `model`, and its `provider:` and `protocol:` options (see [Chat Basics]({% link _core_features/chat.md %}) and [Request Control]({% link _core_features/chat-request-control.md %}#choosing-the-wire-protocol))
* `tools` (see [Tools]({% link _core_features/tools.md %}))
* `tool_options` (see [Controlling Tool Execution]({% link _core_features/tool-execution.md %}))
* `instructions` (see [Chat Basics]({% link _core_features/chat.md %}))
* `temperature` (see [Chat Basics]({% link _core_features/chat.md %}))
* `max_output_tokens` (see [Request Control]({% link _core_features/chat-request-control.md %}))
* `thinking` (see [Thinking]({% link _core_features/thinking.md %}))
* `citations` (see [Citations]({% link _core_features/citations.md %}))
* `end_user` (see [Request Control]({% link _core_features/chat-request-control.md %}#identifying-end-users))
* `compaction` (see [Request Control]({% link _core_features/chat-request-control.md %}#compacting-long-conversations))
* `provider_options` (see [Request Control]({% link _core_features/chat-request-control.md %}))
* `headers` (see [Chat Basics]({% link _core_features/chat.md %}))
* `schema` (see [Chat Basics]({% link _core_features/chat.md %}))
* `fallbacks` (see [Model Fallbacks]({% link _advanced/error-handling.md %}#model-fallbacks))
* `context` (see [Configuration]({% link _getting_started/configuration.md %}))
* `chat_model` (Rails-backed mode)
* `inputs` (declared runtime inputs)

`tools` sets which tools the agent's chats may call. Use `tool_options` for `choice`, `calls`, and `concurrency`:

```ruby
class WorkAssistant < RubyLLM::Agent
  tools SearchDocs, LookupAccount
  tool_options choice: :auto, calls: :one
end
```

`schema` supports:

* A schema class (for example `PersonSchema`) - same as `with_schema`
* A JSON schema hash - same as `with_schema`
* An inline DSL block with `schema do ... end` - agent-specific convenience

Inline DSL example:

```ruby
class CriticAgent < RubyLLM::Agent
  schema do
    string :verdict, enum: ["pass", "revise"]
    string :feedback
  end
end
```

### Model Fallbacks

Use `fallbacks` to give every chat created by the agent the same ordered fallback models:

```ruby
class WorkAssistant < RubyLLM::Agent
  model "gpt-4.1"
  fallbacks "gpt-4.1-mini", "claude-haiku-4-5"
end
```

You can also customize which errors trigger fallback:

```ruby
class WorkAssistant < RubyLLM::Agent
  model "gpt-4.1"
  fallbacks "gpt-4.1-mini",
            on: [RubyLLM::RateLimitError, RubyLLM::ServiceUnavailableError]
end
```

Fallbacks can be model IDs or `RubyLLM::Model` objects:

```ruby
class WorkAssistant < RubyLLM::Agent
  model "gpt-4.1"
  fallbacks RubyLLM.models.find("claude-haiku-4-5", :anthropic)
end
```

This works for both `WorkAssistant.chat` and Rails-backed agents configured with `chat_model`.

## Runtime Context and Inputs

Agents support runtime-evaluated values using blocks and lambdas.

Declare additional runtime inputs with `inputs`:

```ruby
class WorkAssistant < RubyLLM::Agent
  chat_model Chat
  inputs :workspace

  instructions { "You are helping #{workspace.name}" }
end
```

`chat` is always available in execution context:

* In `.chat` mode, `chat` is a `RubyLLM::Chat`
* In `.create/.create!/.find` mode, `chat` is your `chat_model` record

This enables Rails-style usage:

```ruby
class WorkAssistant < RubyLLM::Agent
  chat_model Chat

  instructions current_date_time: -> { Time.current.strftime("%B %d, %Y") },
    display_name: -> { chat.user.display_name_or_email },
    full_name: -> { chat.user.full_name.presence || chat.user.display_name_or_email }

  tools do
    [
      TodoTool.new(chat: chat),
      GoogleDriveListTool.new(user: chat.user),
      GoogleDriveSearchTool.new(user: chat.user),
      GoogleDriveReadTool.new(user: chat.user)
    ]
  end
end
```

Values that depend on runtime `chat` must be lazy (blocks or lambdas), not eager class-load expressions.
{: .important }

### Choosing the model at runtime

`model` takes a block too, so an agent can route work to a cheaper or larger model based on its inputs:

```ruby
class CardAgent < RubyLLM::Agent
  inputs :card
  model { card.special_type? ? "gpt-4.1-mini" : "gpt-4.1-nano" }
  instructions "You are helpful."
end

CardAgent.chat(card: card)
```

Options stay alongside the block: `model(provider: :openai) { ... }`. The model block runs before the chat exists, so it reads `inputs` but not `chat`.

## Prompt Management and Conventions

Agents have prompt conventions built in. They use the same `app/prompts` templates as [Prompt Rendering]({% link _core_features/prompt-rendering.md %}), with class-based lookup layered on top.

### Default instructions prompt

Named agents automatically use their conventional instructions prompt when it exists:

```ruby
class WorkAssistant < RubyLLM::Agent
  chat_model Chat
end
```

RubyLLM looks for:

* `app/prompts/work_assistant/instructions.txt.erb`

If the file exists, it is rendered and used as instructions automatically. If it does not exist and you did not set `instructions`, the agent starts without system instructions. To require a prompt and fail loudly when it is missing, reference it explicitly:

```ruby
class WorkAssistant < RubyLLM::Agent
  chat_model Chat
  instructions { prompt("instructions") }
end
```

If that file does not exist, RubyLLM raises `RubyLLM::PromptNotFoundError`.

### Prompt shorthand with locals

You can pass locals directly:

```ruby
class WorkAssistant < RubyLLM::Agent
  chat_model Chat
  instructions display_name: -> { chat.user.display_name_or_email }
end
```

This also renders `instructions.txt.erb` for that agent path.

### Prompt helper in runtime blocks

Within execution context you can call:

```ruby
instructions { prompt("instructions", display_name: chat.user.display_name_or_email) }
```

### Naming conventions

Agent prompt path is derived from class name:

* `WorkAssistant` -> `app/prompts/work_assistant/...`
* `Admin::SupportAgent` -> `app/prompts/admin/support_agent/...`

Prompt extension defaults to `.txt.erb`.

For rendering a prompt directly outside an agent, use `RubyLLM.render_prompt`. See [Prompt Rendering]({% link _core_features/prompt-rendering.md %}).

## Using an Agent

### Plain Ruby chat

```ruby
chat = WorkAssistant.chat
response = chat.ask("Hello")

puts response.content
```

`WorkAssistant.chat(...)` returns a configured `RubyLLM::Chat`.

### Instance API

You can still instantiate and use an agent instance directly:

```ruby
agent = WorkAssistant.new
response = agent.ask("Hello")

response.cost.total
agent.cost.total
```

Agent instances delegate the conversation API from `RubyLLM::Chat` to the wrapped chat object.
Direct transcript replacement with `messages=` stays on the wrapped chat because Rails-backed chat
models own their message association.

Delegated methods include:

* `model`, `provider`, `messages`, `tools`, `server_tools`, `provider_options`, `headers`, `schema`
* `concurrency`, `caching`, `compaction`, `end_user`, `fallbacks`
* `tokens`, `cost`, `count_tokens`, `render`
* `ask`, `say`, `complete`, `complete?`, `ask_later`, `generate`, `run_tools`, `step`
* `cancel!`, `cancelled?`, `approve!`, `deny!`, `awaiting_approval?`, `pending_approvals`
* `add_message`, `each`
* `cache_until_here!`, `with_tools`, `with_server_tools`, `with_tool_options`
* `with_model`, `with_temperature`, `with_thinking`, `with_citations`, `with_end_user`, `with_compaction`, `with_context`
* `with_caching`, `with_provider_options`, `with_headers`, `with_schema`, `with_fallbacks`
* `before_request`, `before_message`, `after_message`, `before_tool_call`, `after_tool_result`, `before_fallback`, `after_fallback`

You can always access the wrapped chat object directly via `agent.chat`.

## Handling Errors with `rescue_from`

`rescue_from` declares how an agent handles exceptions raised by its chat operations: `ask`, `say`, `ask_later`, `complete`, `generate`, `run_tools`, `step`, and `count_tokens`.

```ruby
class ApplicationAgent < RubyLLM::Agent
  rescue_from RubyLLM::RateLimitError, RubyLLM::ServerError, with: :handle_transient
  rescue_from RubyLLM::BadRequestError, with: :handle_bad_request

  private

  def handle_transient(error)
    StatsD.increment("llm.api_error", tags: ["type:transient"])
    Rails.logger.error("#{error.class}: #{error.message}")
    raise # re-raise after instrumenting
  end

  def handle_bad_request(error)
    StatsD.increment("llm.api_error", tags: ["type:bad_request"])
    Sentry.capture_exception(error) # this one is a bug in our pipeline
    raise
  end
end
```

Handlers run on the agent instance, so `self`, the agent's inputs, and `agent.chat` are available for instrumentation. Pass a block instead of `with:` when the handler is a one-liner:

```ruby
class SummaryAgent < ApplicationAgent
  rescue_from RubyLLM::RateLimitError do |error|
    Rails.logger.warn("#{self.class.name} rate limited: #{error.message}")
    nil
  end
end
```

The semantics match `ActiveSupport::Rescuable`:

* Handlers are searched in reverse declaration order, so the last matching handler wins and a subclass can override an inherited one.
* Exception classes may be given as strings (`rescue_from "MyGem::Error"`), which defers constant lookup until an exception is raised.
* Re-raise inside the handler to let the caller see the exception. Without a `raise`, the exception is swallowed and the handler's return value becomes the operation's return value.
* Exceptions that no handler matches are re-raised with their original backtrace.

Subclasses inherit the handlers declared when they are defined, so an `ApplicationAgent` base class is the usual place for shared error policy.

Handlers apply to agent instances. `WorkAssistant.chat` returns a plain `RubyLLM::Chat`, which is not wrapped, so use `WorkAssistant.new` when you want the agent's error handling.

## Rails-Backed Agents

Set `chat_model` to use your ActiveRecord chat model:

```ruby
class WorkAssistant < RubyLLM::Agent
  chat_model Chat
  model "{{ site.models.default_chat }}"
  instructions "You are a helpful assistant."
  tools SearchDocs, LookupAccount
end
```

Then you can:

```ruby
chat = WorkAssistant.create!(user: current_user)

chat = WorkAssistant.find(params[:id])

WorkAssistant.sync_instructions!(chat)
```

`create/create!/find` require `chat_model`. Calling them without it raises an error.

Instruction persistence contract in Rails mode:

* `create/create!` applies and persists instructions
* `find` applies instructions at runtime only (no persistence side effects)
* `sync_instructions!` explicitly persists the current agent instructions

### Using an Existing Chat Record
If you already have a `Chat` record, pass it to `Agent.new(chat:)` instead of calling `Agent.find`. This applies all agent configuration (instructions, tools, etc.) without an extra database query:

```ruby
chat_record = Chat.find(params[:id])
chat = WorkAssistant.new(chat: chat_record)
chat.ask("Hello")
```

## When to Use an Agent

These two styles are equivalent in capability, but optimized for different contexts.

Use progressive `Chat#with_*` when configuration is local and one-off:

```ruby
chat = RubyLLM.chat(model: "{{ site.models.default_chat }}")
chat.with_instructions("You are a helpful assistant.")
chat.with_tools(SearchDocs, LookupAccount)
chat.ask("Help me find docs about callbacks.")
```

Use agents when that setup should be centralized and reused:

```ruby
class WorkAssistant < RubyLLM::Agent
  model "{{ site.models.default_chat }}"
  instructions "You are a helpful assistant."
  tools SearchDocs, LookupAccount
end

WorkAssistant.new.ask("Help me find docs about callbacks.")
```

## Next Steps

* Compose agents with [Agentic Workflows]({% link _advanced/agentic-workflows.md %})
* Run them as jobs that survive anything with [Durable Agents]({% link _advanced/durable-agents.md %})
* Coordinate several as one [Team]({% link _core_features/teams.md %}) the model can delegate to
* Give them [Memory]({% link _advanced/memory.md %}) across conversations
* Ground them in your documents with [RAG]({% link _advanced/rag.md %})
* Learn about [Chat Basics]({% link _core_features/chat.md %})
* Explore [Tools]({% link _core_features/tools.md %})
* Review [Rails Integration]({% link _advanced/rails.md %})
