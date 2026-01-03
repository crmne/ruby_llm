---
layout: default
title: Extended Thinking
nav_order: 8
description: Access the model's internal reasoning process with Extended Thinking
redirect_from:
  - /guides/thinking
  - /guides/reasoning
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

*   How to enable Extended Thinking for supported models.
*   How to access thinking content in responses.
*   How to stream thinking content in real-time.
*   How thinking works across different providers.
*   How to persist thinking content with ActiveRecord.

## What is Extended Thinking?

Extended Thinking (also known as "reasoning") is a feature that exposes the model's internal reasoning process. When enabled, models will "think through" problems step-by-step before providing their final response. This is particularly useful for:

*   Complex mathematical or logical problems
*   Multi-step reasoning tasks
*   Debugging and understanding model behavior
*   Applications where transparency in reasoning is valuable

## Enabling Extended Thinking

Use the `with_thinking` method to enable Extended Thinking on a chat:

```ruby
chat = RubyLLM.chat(model: 'claude-opus-4-5-20251101')
  .with_thinking(budget: :medium)

response = chat.ask("What is 15 * 23? Show your reasoning.")

puts "Thinking: #{response.thinking}"
# => "Let me break this down step by step. 15 * 23 = 15 * 20 + 15 * 3..."

puts "Answer: #{response.content}"
# => "The answer is 345."
```

### Budget Options

The `budget` parameter controls how much "thinking" the model should do:

| Budget | Description |
|--------|-------------|
| `:low` | Minimal thinking, faster responses |
| `:medium` | Balanced thinking (default) |
| `:high` | Maximum thinking, most thorough |
| Integer | Specific token budget (provider-dependent) |

```ruby
# Symbol budgets
chat.with_thinking(budget: :low)
chat.with_thinking(budget: :medium)
chat.with_thinking(budget: :high)

# Integer budget (tokens)
chat.with_thinking(budget: 10_000)
```

### Checking if Thinking is Enabled

```ruby
chat = RubyLLM.chat(model: 'claude-opus-4-5-20251101')

chat.thinking_enabled?  # => false

chat.with_thinking(budget: :medium)

chat.thinking_enabled?  # => true
```

## Streaming with Thinking

When streaming, thinking content is available on each chunk:

```ruby
chat = RubyLLM.chat(model: 'claude-opus-4-5-20251101')
  .with_thinking(budget: :medium)

chat.ask("Solve this step by step: What is 127 * 43?") do |chunk|
  # Print thinking content as it streams
  if chunk.thinking
    print "[Thinking] #{chunk.thinking}"
  end

  # Print response content
  if chunk.content
    print chunk.content
  end
end
```

### Separating Thinking from Response

For UI applications, you may want to display thinking separately:

```ruby
thinking_content = ""
response_content = ""

chat.ask("Complex question here...") do |chunk|
  thinking_content << chunk.thinking if chunk.thinking
  response_content << chunk.content if chunk.content

  # Update UI with separated content
  update_thinking_panel(thinking_content)
  update_response_panel(response_content)
end
```

## Supported Models

Extended Thinking requires models with the `reasoning` capability. Use `with_thinking` only on supported models:

```ruby
# Check if a model supports thinking
model = RubyLLM::Models.find('claude-opus-4-5-20251101')
model.supports?('reasoning')  # => true

# Using with_thinking on unsupported models raises an error
chat = RubyLLM.chat(model: 'gpt-4o')
chat.with_thinking(budget: :medium)
# => raises RubyLLM::UnsupportedFeatureError
```

### Provider-Specific Behavior

| Provider | Models | Implementation |
|----------|--------|----------------|
| Anthropic | claude-opus-4-*, claude-sonnet-4-* | `thinking` block with `budget_tokens` |
| Gemini | gemini-2.5-*, gemini-3-* | `thinkingConfig` with budget or effort level |
| OpenAI/Grok | grok-* models | `reasoning_effort` parameter |

Budget symbols are automatically translated to provider-specific values:

| Symbol | Anthropic | Gemini 2.5 | Gemini 3 | Grok |
|--------|-----------|------------|----------|------|
| `:low` | 1,024 tokens | 1,024 tokens | "low" | "low" |
| `:medium` | 10,000 tokens | 8,192 tokens | "medium" | "high" |
| `:high` | 32,000 tokens | 24,576 tokens | "high" | "high" |

## Multi-Turn Conversations

Extended Thinking works seamlessly in multi-turn conversations. The model maintains context of its previous reasoning:

```ruby
chat = RubyLLM.chat(model: 'claude-opus-4-5-20251101')
  .with_thinking(budget: :medium)

response1 = chat.ask("What is 15 * 23?")
puts response1.thinking  # Shows step-by-step calculation

response2 = chat.ask("Now multiply that result by 2")
puts response2.thinking  # References previous calculation
puts response2.content   # => "690"
```

## ActiveRecord Integration

When using `acts_as_chat` and `acts_as_message`, thinking content is automatically persisted:

```ruby
# Migration (generated automatically with new installs)
# t.text :thinking
# t.text :thinking_signature

# Using thinking with persisted chats
chat_record = Chat.create!
chat_record.with_thinking(budget: :medium)

response = chat_record.ask("Explain quantum entanglement")

# Thinking is saved to the message record
last_message = chat_record.messages.last
last_message.thinking  # => "Let me break down quantum entanglement..."
```

### Upgrading Existing Installations

If you have an existing RubyLLM installation, add the thinking columns:

```ruby
class AddThinkingToMessages < ActiveRecord::Migration[7.0]
  def change
    add_column :messages, :thinking, :text
    add_column :messages, :thinking_signature, :text
  end
end
```

## Error Handling

```ruby
begin
  chat = RubyLLM.chat(model: 'gpt-4o')  # Doesn't support thinking
  chat.with_thinking(budget: :medium)
rescue RubyLLM::UnsupportedFeatureError => e
  puts "This model doesn't support Extended Thinking"
  puts e.message  # => "Model 'gpt-4o' does not support extended thinking"
end
```

## Best Practices

1. **Choose appropriate budgets**: Use `:low` for simple tasks, `:high` for complex reasoning
2. **Stream for long responses**: Thinking can be lengthy; streaming provides better UX
3. **Don't always display thinking**: Consider whether users need to see the reasoning
4. **Handle gracefully**: Check `thinking_enabled?` before relying on thinking content

## Next Steps

*   [Streaming Responses]({% link _core_features/streaming.md %})
*   [Rails Integration]({% link _advanced/rails.md %})
*   [Error Handling]({% link _advanced/error-handling.md %})
