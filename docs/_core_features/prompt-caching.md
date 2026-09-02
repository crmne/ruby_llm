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
* How RubyLLM renders provider-native caching options.
* How to create and attach a Gemini explicit cache with `RubyLLM.cache`.
* How Rails persists explicit cache boundaries.

## Automatic Prompt Caching

Use `with_caching` when the provider should cache the stable prompt prefix automatically. Calling it with no arguments enables provider-default prompt caching:

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
| OpenAI-compatible Chat Completions and Responses | Uses the provider's automatic prompt cache; `key:` becomes `prompt_cache_key`, and `ttl:` and `mode:` become `prompt_cache_options`. |
| Mistral | Uses `key:` as the provider's `prompt_cache_key`. |
| Bedrock Converse | Adds a `cachePoint` to the last cacheable message. |
| Gemini and Vertex AI | Cache automatically; `id:` attaches an explicit cache created with `RubyLLM.cache` (see below). |
| Other providers | Sends no extra caching fields unless the provider already caches automatically. |

Prompt cache durations do not line up cleanly across providers, so RubyLLM does not alias them. Use the provider's own option name and value:

```ruby
chat = RubyLLM.chat(model: 'gpt-5.6').with_caching(
  key: "repo:#{repository.cache_key}",
  ttl: "30m"
)

chat = RubyLLM.chat(model: '{{ site.models.anthropic_latest }}').with_caching(ttl: "1h")
```

OpenAI-compatible Chat Completions and Responses accept `key:`, `ttl:`, and `mode:` (`"implicit"` or `"explicit"`). The old `retention:` option is deprecated; RubyLLM translates it into `prompt_cache_options` and logs a warning. OpenAI accepts `prompt_cache_options` and explicit boundaries only on models that support prompt cache controls: `gpt-5.6` does, while `gpt-5.4-nano` and `gpt-4.1-nano` reject them with a 400, so keep these options on chats pinned to a model that takes them. Mistral accepts `key:`. Anthropic, OpenRouter, and Bedrock Converse accept `ttl:`.

If you switch to a provider that needs different caching options, call `with_caching` again. It replaces the previous cache policy:

```ruby
chat.with_caching(ttl: "1h")
```

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

When a chat has explicit boundaries, RubyLLM does not also add automatic `cache_control` for Anthropic or OpenRouter. The boundary is the source of truth.

## Provider Mapping

RubyLLM translates message boundaries at render time:

| Provider | Boundary rendering |
| --- | --- |
| Anthropic | Adds `cache_control` to the final content block. |
| OpenRouter | Adds `cache_control` to the final content block. |
| Bedrock Converse | Appends a `cachePoint` block. |
| OpenAI and Azure OpenAI | Add `prompt_cache_breakpoint` to the final content part and set `prompt_cache_options` mode to `explicit`. |
| Others | Ignore explicit boundaries when the provider has no boundary concept. |

Configure the TTL once and use explicit boundaries for the stable chunks:

```ruby
chat = RubyLLM.chat(model: '{{ site.models.anthropic_latest }}').with_caching(ttl: "1h")
chat.with_instructions(large_policy_prompt).cache_until_here
chat.ask("Apply the policy to this request: #{request_text}")
```

## Gemini Explicit Caching

Gemini caches repeated prompt prefixes on its own, so most chats need no caching calls at all. When you want control over what is cached and how long it lives, create the cache yourself. Gemini models it as a resource: you store the stable content once, the API keeps it for a TTL, and each request references it by name.

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

The content must exceed the model's minimum cacheable size, 2,048 tokens for the gemini-2.5 family and 4,096 for newer Flash models, or Gemini rejects the cache. `ttl:` accepts seconds or a duration string such as `"300s"` and defaults to one hour.

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

Vertex AI supports the same lifecycle; pass `provider: :vertexai` to `RubyLLM.cache` and cache names become full `projects/.../cachedContents/...` resource paths.

On Gemini, `with_caching` without `id:` and `cache_until_here` boundaries change nothing on the wire. Implicit caching is already on, so RubyLLM logs a debug note pointing to `RubyLLM.cache` and sends the request as usual.

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

## Dropping Down

`with_caching`, `cache_until_here`, and `RubyLLM.cache` cover RubyLLM's prompt-caching API. Use `with_provider_options` only when you need another provider request option, and use a [`before_request` hook]({% link _core_features/chat-request-control.md %}#request-hooks) only when the rendered payload itself must be adjusted.
