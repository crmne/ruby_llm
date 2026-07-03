---
layout: default
title: Prompt Caching
parent: "Chat"
nav_order: 6
description: Reuse stable prompt prefixes with automatic or explicit prompt caching
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

* How to turn on provider prompt caching with `with_caching`.
* How to mark an exact prompt prefix with `cache_until_here!`.
* How RubyLLM renders provider-native caching options.
* How Rails persists explicit cache boundaries.

## Automatic Prompt Caching

Use `with_caching` when the provider should cache the stable prompt prefix automatically:

```ruby
chat = RubyLLM.chat(model: '{{ site.models.anthropic_latest }}').with_caching

chat.with_instructions("You are a careful code reviewer.")
response = chat.ask("Summarize the public API changes.", with: "large_diff.patch")
```

RubyLLM renders the closest provider-native request:

| Provider | Rendering |
| --- | --- |
| Anthropic | Adds top-level `cache_control`. |
| OpenRouter | Adds top-level `cache_control` when no explicit boundary is marked. |
| OpenAI-compatible Chat Completions and Responses | Uses the provider's automatic prompt cache; `key:` and `retention:` become request parameters when supported. |
| Mistral | Uses `key:` as the provider's `prompt_cache_key`. |
| Bedrock Converse | Adds a `cachePoint` to the last cacheable message. |
| Other providers | Sends no extra caching fields unless the provider already caches automatically. |

Prompt cache durations do not line up cleanly across providers, so RubyLLM does not alias them. Use the provider's own option name and value:

```ruby
chat = RubyLLM.chat(model: 'gpt-5.4').with_caching(
  key: "repo:#{repository.cache_key}",
  retention: "24h"
)

chat = RubyLLM.chat(model: '{{ site.models.anthropic_latest }}').with_caching(ttl: "1h")
```

OpenAI-compatible Chat Completions and Responses accept `key:` and `retention:` when the provider supports those request fields. Mistral accepts `key:`. Anthropic, OpenRouter, and Bedrock Converse accept `ttl:`.

If you switch to a provider that needs different caching options, call `with_caching` again. It replaces the previous cache policy:

```ruby
chat.with_caching(ttl: "1h")
```

To disable caching for later requests, clear the policy explicitly:

```ruby
chat.without_caching
```

## Explicit Cache Boundaries

Use `cache_until_here!` when you know the exact prefix that should be cached:

```ruby
chat = RubyLLM.chat(model: '{{ site.models.anthropic_latest }}')

chat.with_instructions(
  "You are a release-notes assistant. Always group changes by subsystem."
).cache_until_here!

response = chat.ask("Summarize the API changes in this diff.", with: "large_diff.patch")
```

`cache_until_here!` marks the latest message. That means these two forms are equivalent:

```ruby
message = chat.add_message(role: :user, content: long_context)
message.cache_until_here!

chat.add_message(role: :user, content: long_context)
chat.cache_until_here!
```

When a chat has explicit boundaries, RubyLLM does not also add automatic `cache_control` for Anthropic or OpenRouter. The boundary is the source of truth.

## Provider Mapping

RubyLLM translates message boundaries at render time:

| Provider | Boundary rendering |
| --- | --- |
| Anthropic | Adds `cache_control` to the final content block. |
| OpenRouter | Adds `cache_control` to the final content block. |
| Bedrock Converse | Appends a `cachePoint` block. |
| OpenAI, Azure OpenAI, and others | Ignore explicit boundaries when the provider has no boundary concept. |

Configure the TTL once and use explicit boundaries for the stable chunks:

```ruby
chat = RubyLLM.chat(model: '{{ site.models.anthropic_latest }}').with_caching(ttl: "1h")
chat.with_instructions(large_policy_prompt).cache_until_here!
chat.ask("Apply the policy to this request: #{request_text}")
```

## Rails Persistence

For persisted Rails chats, explicit cache boundaries are stored on messages with `cache_until_here` and replayed with conversation history:

```ruby
chat = Chat.create!(model: '{{ site.models.anthropic_current }}')
chat.with_caching(ttl: "1h")
chat.with_instructions('Reusable analysis prompt').cache_until_here!
chat.add_message(role: :user, content: long_context).cache_until_here!
chat.ask("Today's request: #{summary}")
```

Existing apps should run the latest upgrade generator after updating RubyLLM so message tables include `cache_until_here`. New apps get the column from the install generator.

## Dropping Down

`with_caching` and `cache_until_here!` cover RubyLLM's prompt-caching API. Use `with_params` only when you need another provider request option, and use `Content::Raw` only when the content block itself must be provider-specific.
