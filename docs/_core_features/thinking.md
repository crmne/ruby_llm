---
layout: default
title: Extended Thinking
nav_order: 8
description: Give reasoning models more time and budget to deliberate, with optional access to thinking output
redirect_from:
  - /guides/thinking
  - /guides/reasoning
---

# {{ page.title }}
{: .d-inline-block .no_toc }

New in 1.10
{: .label .label-green }

{{ page.description }}
{: .fs-6 .fw-300 }

## Table of contents
{: .no_toc .text-delta }

1. TOC
{:toc}

---

After reading this guide, you will know:

* How to control extended thinking with `with_thinking`
* How effort and budget are sent to providers
* How to access thinking output in responses and streams
* How to persist thinking data with ActiveRecord

## What is Extended Thinking?

Extended Thinking gives supported models more time and a larger computation budget to deliberate before answering. It can improve results on multi-step tasks like coding, math, and logic, at the expense of latency and cost. Some providers can also return a thinking trace or signature alongside the final answer.

## Controlling Extended Thinking

Use `with_thinking` to control models that support thinking. Some models think by default, so `with_thinking` is for tuning (or disabling) rather than turning it on.

```ruby
chat = RubyLLM.chat(model: 'claude-opus-4.5')
  .with_thinking(effort: :high, budget: 8000)

response = chat.ask("What is 15 * 23?")

response.thinking&.text
response.thinking&.signature
response.content
```

`with_thinking` requires at least one of `effort` or `budget`:

```ruby
chat.with_thinking(effort: :low)
chat.with_thinking(budget: 10_000)
chat.with_thinking(effort: :none)
```

### Effort and Budget

Use `effort` to pick a qualitative depth (`:low`, `:medium`, `:high`) and `budget` for models that accept a token cap.

RubyLLM sends `effort` and `budget` exactly as provided. Check your provider's docs for supported values.

## Streaming with Thinking

Thinking content is delivered alongside normal content in streaming chunks:

```ruby
chat = RubyLLM.chat(model: 'claude-opus-4.5')
  .with_thinking(effort: :medium)

chat.ask("Solve this step by step: What is 127 * 43?") do |chunk|
  print chunk.thinking&.text
  print chunk.content
end
```

Some providers only expose thinking in the final response. In those cases, `response.thinking` is populated after the stream completes, and `chunk.thinking` stays empty.

## ActiveRecord Integration

When using `acts_as_chat` and `acts_as_message`, thinking output is persisted to the message table:

```ruby
# Migration (generated automatically with new installs)
# t.text :thinking_text
# t.text :thinking_signature
# t.integer :thinking_tokens

response = chat_record.ask("Explain quantum entanglement")
response.thinking&.text
response.thinking_tokens
```

### Upgrading Existing Installations

For 1.10 upgrades, consider using the [upgrade guide]({% link _advanced/upgrading.md %}#upgrade-to-1-10) to run the generator.
If you prefer manual migrations, add the columns to your message and tool calls tables:

```ruby
class AddThinkingToMessages < ActiveRecord::Migration[7.1]
  def change
    add_column :messages, :thinking_text, :text
    add_column :messages, :thinking_signature, :text
    add_column :messages, :thinking_tokens, :integer
    add_column :tool_calls, :thought_signature, :string
  end
end
```

## Provider Notes

- Claude uses a thinking budget and can return both text and signature.
- Anthropic and Bedrock require a thinking budget; effort is optional.
- Gemini 2.5 uses a token budget; Gemini 3 uses effort levels.
- OpenAI reasoning models accept `effort` but may not return thinking text or signatures.
- Perplexity sonar reasoning models stream `<think>` blocks inside content; RubyLLM extracts them after the response completes.
- Mistral Magistral models always think and ignore `with_thinking` params. Non-magistral models warn if you pass them.
- Ollama's Qwen3 models think by default and only accept `effort: :none` to disable thinking.
- Anthropic, Bedrock's Claude, and Ollama integrations currently do not report thinking token counts.

## Next Steps

* [Streaming Responses]({% link _core_features/streaming.md %})
* [Rails Integration]({% link _advanced/rails.md %})
* [Error Handling]({% link _advanced/error-handling.md %})
