# Prompt Caching

RubyLLM supports Anthropic's prompt caching feature, which allows you to cache parts of your prompts to reduce token usage and costs when making similar requests.

## What is Prompt Caching?

Prompt caching is a feature that allows you to mark specific parts of your prompt as cacheable. When you make a request with a cached prompt, Anthropic will:

1. Check if the prompt prefix (up to the cache breakpoint) is already cached
2. If found, use the cached version, reducing processing time and costs
3. Otherwise, process the full prompt and cache the prefix

This is especially useful for:

- Prompts with many examples
- Large amounts of context or background information
- Repetitive tasks with consistent instructions
- Long multi-turn conversations

## Supported Models

Prompt caching is currently supported on the following Anthropic Claude models:

- Claude 3.7 Sonnet
- Claude 3.5 Sonnet
- Claude 3.5 Haiku
- Claude 3 Haiku
- Claude 3 Opus

## How to Use Prompt Caching

To use prompt caching in RubyLLM, you can mark content as cacheable using the `cache_control` parameter:

```ruby
# Create a chat with a Claude model
chat = RubyLLM.chat(model: 'claude-3-5-sonnet')

# Add a system message with cache control
chat.with_instructions("You are an AI assistant tasked with analyzing literary works.",
                      cache_control: true)

# Add a large document with cache control
chat.ask("Here's the entire text of Pride and Prejudice: [long text...]",
         with: { cache_control: true })

# Now you can ask questions about the document without reprocessing it
chat.ask("Analyze the major themes in Pride and Prejudice.")
```

## Pricing

Prompt caching introduces a different pricing structure:

| Model             | Base Input Tokens | Cache Writes  | Cache Hits   | Output Tokens |
| ----------------- | ----------------- | ------------- | ------------ | ------------- |
| Claude 3.7 Sonnet | $3 / MTok         | $3.75 / MTok  | $0.30 / MTok | $15 / MTok    |
| Claude 3.5 Sonnet | $3 / MTok         | $3.75 / MTok  | $0.30 / MTok | $15 / MTok    |
| Claude 3.5 Haiku  | $0.80 / MTok      | $1 / MTok     | $0.08 / MTok | $4 / MTok     |
| Claude 3 Haiku    | $0.25 / MTok      | $0.30 / MTok  | $0.03 / MTok | $1.25 / MTok  |
| Claude 3 Opus     | $15 / MTok        | $18.75 / MTok | $1.50 / MTok | $75 / MTok    |

Note:

- Cache write tokens are 25% more expensive than base input tokens
- Cache read tokens are 90% cheaper than base input tokens
- Regular input and output tokens are priced at standard rates

## Tracking Cache Performance

When using prompt caching, you can track the cache performance using the following fields in the response:

```ruby
response = chat.ask("What are the main characters in Pride and Prejudice?")

puts "Cache creation tokens: #{response.cache_creation_input_tokens}"
puts "Cache read tokens: #{response.cache_read_input_tokens}"
puts "Regular input tokens: #{response.input_tokens}"
puts "Output tokens: #{response.output_tokens}"
```

## Cache Limitations

- The minimum cacheable prompt length is:
  - 1024 tokens for Claude 3.7 Sonnet, Claude 3.5 Sonnet, and Claude 3 Opus
  - 2048 tokens for Claude 3.5 Haiku and Claude 3 Haiku
- Shorter prompts cannot be cached, even if marked with `cache_control`
- The cache has a minimum 5-minute lifetime
- Cache hits require 100% identical prompt segments

## Best Practices

- Place static content (system instructions, context, examples) at the beginning of your prompt
- Mark the end of the reusable content for caching using the `cache_control` parameter
- Use cache breakpoints strategically to separate different cacheable prefix sections
- Regularly analyze cache hit rates and adjust your strategy as needed

## Example: Document Analysis

```ruby
# Create a chat with Claude
chat = RubyLLM.chat(model: 'claude-3-5-sonnet')

# Add system instructions with cache control
chat.with_instructions("You are an AI assistant tasked with analyzing documents.",
                      cache_control: true)

# Add a PDF document with cache control
chat.ask("Please analyze this document:",
         with: { pdf: "large_document.pdf", cache_control: true })

# First query - will create a cache
response1 = chat.ask("What are the main points in the executive summary?")
puts "Cache creation tokens: #{response1.cache_creation_input_tokens}"

# Second query - will use the cache
response2 = chat.ask("Who are the key stakeholders mentioned?")
puts "Cache read tokens: #{response2.cache_read_input_tokens}"
```

## Example: Multi-turn Conversation

```ruby
# Create a chat with Claude
chat = RubyLLM.chat(model: 'claude-3-5-sonnet')

# Add system instructions with cache control
chat.with_instructions("You are a helpful coding assistant. Use these coding conventions: [long list of conventions]",
                      cache_control: true)

# First query - will create a cache
response1 = chat.ask("How do I write a Ruby class for a bank account?")
puts "Cache creation tokens: #{response1.cache_creation_input_tokens}"

# Second query - will use the cache
response2 = chat.ask("Can you show me how to add a transfer method to that class?")
puts "Cache read tokens: #{response2.cache_read_input_tokens}"
```
