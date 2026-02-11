---
layout: default
title: Agents
nav_order: 6
description: Define reusable agent configurations once and use them anywhere
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

* Why agents exist and when to use them
* How to define an agent with a class-based DSL
* How to instantiate and use agents in your app
* How to keep tools and instructions centralized

## What Are Agents?

Agents are a DSL that lets you define a chat configuration once and reuse it everywhere. They make agent definitions feel like first-class objects in your app: readable, discoverable, and easy to instantiate.

This is especially helpful in Rails apps where you keep agent classes in `app/agents` and want to avoid re-specifying the same model, tools, and instructions every time you load a chat from the database. But it also works great in scripts, services, and background jobs—anywhere you want a clean, named place to put the “shape” of an agent.

Instead of rebuilding configuration for each chat instance, you define it once on the agent class and instantiate it when needed.

## Defining an Agent

Create a class that inherits from `RubyLLM::Agent` and declare its configuration:

```ruby
# app/agents/chat_agent.rb
class ChatAgent < RubyLLM::Agent
  model "gpt-5", provider: :azure, assume_model_exists: true
  tools MyTool, ThatTool
  instructions "Be awesome"
  temperature 0.2
  thinking effort: :none
  params max_output_tokens: 256
  headers "X-Request-Id" => "chat-agent"
  schema MySchema
end
```

Each class macro maps to the equivalent `RubyLLM.chat` or `Chat#with_*` setting. The values are applied when you instantiate the agent.

## Using an Agent

Instantiate the class and ask questions just like a normal chat:

```ruby
agent = ChatAgent.new
response = agent.ask "hello"

puts response.content
```

You can also override any `RubyLLM.chat` arguments per instance:

```ruby
agent = ChatAgent.new(model: "gpt-5-mini")
agent.ask "Use the faster model for this request."
```

## Why This Helps in Rails

When you load a chat from the database, you often need to reapply instructions and tools to get consistent behavior. Agents let you keep that configuration in one place:

```ruby
# app/agents/support_agent.rb
class SupportAgent < RubyLLM::Agent
  model "{{ site.models.default_chat }}"
  instructions "You are a helpful support agent."
  tools SearchDocs, LookupAccount
end
```

That way, every part of your app uses the same settings without duplicating logic in controllers, jobs, or model callbacks.

## When to Use Agents vs `RubyLLM.chat`

Use `RubyLLM.chat` when you want a one-off conversation or quick, inline configuration:

```ruby
chat = RubyLLM.chat(model: "{{ site.models.default_chat }}")
chat.with_instructions "Explain this clearly."
```

Use agents when you want a named, reusable definition that you can instantiate consistently across your app:

```ruby
class SupportAgent < RubyLLM::Agent
  model "{{ site.models.default_chat }}"
  instructions "You are a helpful support agent."
  tools SearchDocs, LookupAccount
end
```

Think of `RubyLLM.chat` as the ad-hoc interface and agents as the reusable, shareable interface.

## Next Steps

* Learn about [Chat Basics]({% link _core_features/chat.md %})
* Explore [Tools]({% link _core_features/tools.md %})
* Review [Rails Integration]({% link _advanced/rails.md %})
