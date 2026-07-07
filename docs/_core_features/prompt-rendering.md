---
layout: default
title: Prompt Rendering
parent: "Chat"
nav_order: 6
description: Render reusable ERB prompt templates from app/prompts with RubyLLM.render_prompt
---

# {{ page.title }}
{: .no_toc }

{{ page.description }}
{: .fs-6 .fw-300 }

## Table of contents
{: .no_toc .text-delta }

1. TOC
{:toc}

---

After reading this guide, you will know:

* How to store prompt templates in `app/prompts`.
* How to render templates with `RubyLLM.render_prompt`.
* How locals, nested paths, and `.txt.erb` filenames work.
* How rendered prompts fit into chats and agents.
* Which errors to expect when a prompt file is missing.

## Rendering a Prompt

`RubyLLM.render_prompt` renders a local ERB template and returns the rendered string. It does not call a model or add anything to a chat by itself.

Create a prompt file:

```erb
<!-- app/prompts/support/instructions.txt.erb -->
You are a support assistant for <%= product_name %>.

The current customer is <%= customer_name %>.
Answer with concise, practical steps.
```

Render it with keyword locals:

```ruby
instructions = RubyLLM.render_prompt(
  "support/instructions",
  product_name: "BillingHub",
  customer_name: current_user.name
)

chat = RubyLLM.chat
chat.with_instructions(instructions)
chat.ask("How do I update my invoice email?")
```

`RubyLLM.render_prompt("support/instructions")` resolves to:

```text
app/prompts/support/instructions.txt.erb
```

In Rails apps, the path is relative to `Rails.root`. Outside Rails, it is relative to the current working directory.

## Static Prompts

Prompts do not need locals:

```erb
<!-- app/prompts/reviewer.txt.erb -->
You are a careful code reviewer. Focus on correctness, security, and missing tests.
```

```ruby
instructions = RubyLLM.render_prompt("reviewer")
chat.with_instructions(instructions)
```

## Locals

Every keyword argument passed to `render_prompt` is available in the ERB template:

```erb
<!-- app/prompts/messages/welcome.txt.erb -->
Welcome <%= name %>.

Your plan is <%= plan_name %>.
```

```ruby
RubyLLM.render_prompt(
  "messages/welcome",
  name: "Ada",
  plan_name: "Pro"
)
# => "Welcome Ada.\n\nYour plan is Pro.\n"
```

If the template references a local you did not pass, ERB raises an error while rendering.

## Nested Paths and Extensions

Prompt names can include nested directories:

```ruby
RubyLLM.render_prompt("work_assistant/instructions", display_name: "Ada")
```

This renders:

```text
app/prompts/work_assistant/instructions.txt.erb
```

You can also pass the full filename:

```ruby
RubyLLM.render_prompt("work_assistant/instructions.txt.erb", display_name: "Ada")
```

RubyLLM prompt templates use `.txt.erb`.

## Missing Prompts

If RubyLLM cannot find the prompt file, it raises `RubyLLM::PromptNotFoundError`:

```ruby
begin
  RubyLLM.render_prompt("missing")
rescue RubyLLM::PromptNotFoundError => error
  Rails.logger.warn(error.message)
end
```

## Using Rendered Prompts in Chat

Use rendered prompts anywhere you would use a string:

```ruby
system_prompt = RubyLLM.render_prompt(
  "analysis/instructions",
  timezone: Time.zone.name,
  account_type: current_account.plan_name
)

chat = RubyLLM.chat(model: "{{ site.models.default_chat }}")
chat.with_instructions(system_prompt)

response = chat.ask(
  RubyLLM.render_prompt("analysis/question", topic: params[:topic])
)
```

Prompt rendering is local string templating. For provider-side reuse of large stable prompt prefixes, see [Prompt Caching]({% link _core_features/prompt-caching.md %}).

## Using Prompts with Agents

Agents build on the same prompt renderer. Named agents automatically render their conventional prompt when it exists:

```ruby
class WorkAssistant < RubyLLM::Agent
  chat_model Chat
end
```

For `WorkAssistant`, RubyLLM looks for:

```text
app/prompts/work_assistant/instructions.txt.erb
```

If the file exists, it is used as the agent's system instructions. If it does not exist and the agent has no `instructions` macro, the agent starts without system instructions.

Call `instructions` with no arguments when the file is required and should raise `RubyLLM::PromptNotFoundError` if missing:

```ruby
class WorkAssistant < RubyLLM::Agent
  chat_model Chat
  instructions
end
```

You can pass locals to the conventional prompt:

```ruby
class WorkAssistant < RubyLLM::Agent
  chat_model Chat

  instructions display_name: -> { chat.user.display_name_or_email }
end
```

For the full class-based conventions, see [Agents]({% link _advanced/agents.md %}#prompt-management-and-conventions).

## Safety Notes

ERB templates execute Ruby code, so prompt files should be trusted application code. Do not pass untrusted user input as the prompt name; keep prompt names as application-controlled constants or map user choices to known prompt names.

Locals are inserted exactly as rendered by ERB. If your prompt format needs escaping or quoting, do that before passing the local or inside the template.
