---
layout: default
title: Prompt Caching
parent: "Chat"
nav_order: 7
description: Reuse stable prompt prefixes with automatic or explicit prompt caching
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* How to turn on provider prompt caching with `with_caching`.
* How to mark an exact prompt prefix with `cache_until_here`.
* How to choose cache lifetimes and read cache usage.
* How to create, reuse, and expire an explicit cache with `RubyLLM.cache`.
* How Rails persists explicit cache boundaries.

## Automatic Prompt Caching

Use `with_caching` when the provider should cache the stable prompt prefix automatically. Calling it with no arguments enables provider-default prompt caching:

```ruby
chat = RubyLLM.chat(model: '{{ site.models.anthropic_latest }}').with_caching

chat.with_instructions("You are a careful code reviewer.")
response = chat.ask("Summarize the public API changes.", with: "large_diff.patch")
```

Keep reusable instructions and documents at the beginning of the conversation. Changing that prefix can prevent a cache hit. Read the result through `response.tokens.cache_read` and `response.tokens.cache_write`.

Use options when you need a cache key or lifetime:

```ruby
chat.with_caching(ttl: "1h")
```

Options depend on the provider and model:

| Setting | Availability |
| --- | --- |
| `key:` | OpenAI-compatible protocols and Mistral |
| `ttl:` | Supported OpenAI models, Anthropic, OpenRouter, and Bedrock Converse; accepted lifetimes vary |
| `mode:` | Supported OpenAI-compatible models, using `"implicit"` or `"explicit"` |
| `id:` | An explicit Gemini or Vertex AI cache, described below |

Leave options unset to use provider defaults. Some models support automatic caching but reject explicit lifetimes or boundaries.

Both `with_caching` and the Agent `caching` macro accept keyword options or a Hash. Calling either again replaces the previous cache policy.

To stop RubyLLM from sending cache controls or rendering marked boundaries for later requests, pass `false`:

```ruby
chat.with_caching(false)
```

Some providers cache repeated prompts implicitly and do not expose an off switch. `false` disables RubyLLM's caching instructions, not caching performed independently by the provider.

## Explicit Cache Boundaries

Use `cache_until_here` when you know the exact prefix that should be cached:

```ruby
chat = RubyLLM.chat(model: '{{ site.models.anthropic_latest }}')

chat.with_instructions(
  "You are a release-notes assistant. Always group changes by subsystem."
).cache_until_here

response = chat.ask("Summarize the API changes in this diff.", with: "large_diff.patch")
```

`cache_until_here` marks the latest message. That means these two forms are equivalent:

```ruby
message = chat.add_message(role: :user, content: long_context)
message.cache_until_here

chat.add_message(role: :user, content: long_context)
chat.cache_until_here
```

A marked boundary takes precedence over automatic boundary placement. You can combine it with a lifetime:

```ruby
chat.with_caching(ttl: "1h")
chat.with_instructions(large_policy_prompt).cache_until_here
chat.ask("Apply the policy to this request: #{request_text}")
```

Boundaries are supported by Anthropic, OpenRouter, Bedrock Converse, and selected OpenAI-compatible models. Perplexity requires its [Router protocol]({% link _core_features/chat-request-control.md %}#perplexity-router). Providers without boundary support continue to use their own caching behavior.

## Creating an Explicit Cache

On Gemini and Vertex AI, create an explicit cache to reuse the same documents across requests or conversations. The provider stores the content until its expiry, and chats reference it by name.

`RubyLLM.cache` creates the resource and returns a `RubyLLM::CachedContent`:

```ruby
cache = RubyLLM.cache(
  File.read("handbook.md"),
  model: 'gemini-2.5-flash',
  instructions: "You are a meticulous release engineer.",
  ttl: 3600
)

cache.name       # => "cachedContents/abc123"
cache.tokens     # => 7809
cache.expires_at # => 2026-08-11 12:34:56 UTC
```

Pass file attachments with `with:`, the same way `ask` accepts them:

```ruby
cache = RubyLLM.cache("Reference material:", model: 'gemini-2.5-flash', with: "manual.pdf")
```

The content must meet the model's minimum cacheable size. `ttl:` accepts seconds or a duration string such as `"300s"` and defaults to one hour.

Attach the cache with `with_caching(id:)`, passing the `CachedContent` or its name:

```ruby
chat = RubyLLM.chat(model: 'gemini-2.5-flash').with_caching(id: cache)
response = chat.ask("What does the handbook say about cassette hygiene?")
response.tokens.cache_read # => 7809
```

The cache is the conversation's prefix. RubyLLM sends the chat's own messages unchanged, so compose them knowing the model already sees the cached content first. Gemini rejects requests that combine a cache with request-level system instructions or tools, so put instructions in the cache with `instructions:` and leave `with_instructions` and `with_tools` off the chat.

`CachedContent` manages the rest of the lifecycle:

```ruby
cache.renew(ttl: 7200) # sets expiry to two hours from now
cache.delete           # removes the cache before its TTL

cache = RubyLLM::CachedContent.find("cachedContents/abc123", provider: :gemini)
```

Use the same model and provider when creating and using a cache.

## Rails Persistence

For persisted Rails chats, explicit cache boundaries are stored on messages with `cache_until_here` and replayed with conversation history:

```ruby
chat = Chat.create!(model: '{{ site.models.anthropic_current }}')
chat.with_caching(ttl: "1h")
chat.with_instructions('Reusable analysis prompt').cache_until_here
chat.add_message(role: :user, content: long_context).cache_until_here
chat.ask("Today's request: #{summary}")
```

Existing apps should run the latest upgrade generator after updating RubyLLM so message tables include `cache_until_here`. New apps get the column from the install generator.
