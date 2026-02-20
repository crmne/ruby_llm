---
layout: default
title: Agents
nav_order: 6
description: Define reusable AI assistants with class-based configuration, runtime context, and prompt conventions
---

# {{ page.title }}
{: .d-inline-block .no_toc }

New in 1.12
{: .label .label-green }

{{ page.description }}
{: .fs-6 .fw-300 }

## Table of contents
{: .no_toc .text-delta }

1. TOC
{:toc}

---

After reading this guide, you will know:

* How to define agents with a class-based DSL
* How to use agents with plain Ruby chats and Rails-backed chats
* How runtime context works (`chat`, `inputs`, and lazy evaluation)
* How prompt conventions work in `app/prompts`
* Which methods are available on agent instances

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

In other words, an agent is a named wrapper around the same configuration you would otherwise apply progressively with `chat.with_*` calls (`with_instructions`, `with_tools`, `with_params`, and so on).

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
  params max_output_tokens: 256
end
```

Supported class macros:

These macros use the same arguments you already know from `RubyLLM.chat(...)` and `Chat#with_*` methods.
For example, `model` maps to `RubyLLM.chat(model:, provider:, ...)`, `tools` maps to `with_tools`, `instructions` maps to `with_instructions`, and so on.

* `model` (see [Chat Basics]({% link _core_features/chat.md %}))
* `tools` (see [Tools]({% link _core_features/tools.md %}))
* `instructions` (see [Chat Basics]({% link _core_features/chat.md %}))
* `temperature` (see [Chat Basics]({% link _core_features/chat.md %}))
* `thinking` (see [Thinking]({% link _core_features/thinking.md %}))
* `params` (see [Chat Basics]({% link _core_features/chat.md %}))
* `headers` (see [Chat Basics]({% link _core_features/chat.md %}))
* `schema` (see [Chat Basics]({% link _core_features/chat.md %}))
* `context` (see [Configuration]({% link _getting_started/configuration.md %}))
* `chat_model` (Rails-backed mode)
* `inputs` (declared runtime inputs)

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

Important: values that depend on runtime `chat` must be lazy (blocks/lambdas), not eager class-load expressions.

## Prompt Management and Conventions

Agents have prompt conventions built in.

### Default instructions prompt

Calling `instructions` with no arguments enables default prompt lookup:

```ruby
class WorkAssistant < RubyLLM::Agent
  chat_model Chat
  instructions
end
```

RubyLLM looks for:

* `app/prompts/work_assistant/instructions.txt.erb`

If the file exists, it is rendered and used as instructions. If it does not exist, instructions are simply omitted.

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
agent.ask("Hello")
```

Agent instances delegate the full `RubyLLM::Chat` instance API to the underlying chat object
(or to `to_llm` when using a Rails-backed chat model).

Delegated methods include:

* `model`, `messages`, `tools`, `params`, `headers`, `schema`
* `ask`, `say`, `complete`
* `add_message`, `reset_messages!`, `each`
* `with_tool`, `with_tools`
* `with_model`, `with_temperature`, `with_thinking`, `with_context`
* `with_params`, `with_headers`, `with_schema`
* `on_new_message`, `on_end_message`, `on_tool_call`, `on_tool_result`

You can always access the wrapped chat object directly via `agent.chat`.

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
# Create persisted chat with agent configuration applied
chat = WorkAssistant.create!(user: current_user)

# Load existing persisted chat with runtime config applied (no DB write)
chat = WorkAssistant.find(params[:id])

# Explicitly persist/sync the current agent instructions if you've modified them
WorkAssistant.sync_instructions!(chat)
```

`create/create!/find` require `chat_model`. Calling them without it raises an error.

Instruction persistence contract in Rails mode:

* `create/create!` applies and persists instructions
* `find` applies instructions at runtime only (no persistence side effects)
* `sync_instructions!` explicitly persists the current agent instructions

## When to Use Agents vs `RubyLLM.chat`

Use `RubyLLM.chat` for one-off, inline conversations:

```ruby
chat = RubyLLM.chat(model: "{{ site.models.default_chat }}")
chat.with_instructions "Explain this clearly."
```

Use agents when you want named, reusable behavior:

```ruby
class WorkAssistant < RubyLLM::Agent
  model "{{ site.models.default_chat }}"
  instructions "You are a helpful assistant."
  tools SearchDocs, LookupAccount
end
```

Think of `RubyLLM.chat` as ad-hoc and `RubyLLM::Agent` as reusable application architecture.

## Agent vs `Chat#with_*`

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

* Learn about [Chat Basics]({% link _core_features/chat.md %})
* Explore [Tools]({% link _core_features/tools.md %})
* Review [Rails Integration]({% link _advanced/rails.md %})
