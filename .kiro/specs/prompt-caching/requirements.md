# Requirements Document

## Introduction

This feature adds prompt caching (token caching) support to the ruby_llm gem, starting with Anthropic and Gemini providers. When calling RubyLLM chat with an input prompt, users can mark specific messages or content blocks as cache points. The static portion of the prompt is cached by the provider, reducing input token costs on repeated calls while leaving the dynamic portion of the prompt unchanged and not affecting the output.

Anthropic implements caching via `cache_control` headers on message content blocks. Gemini implements caching via its Context Caching API, where static content is uploaded separately and referenced by name in subsequent requests.

## Glossary

- **Cache_Point**: A marker applied to a message or content block indicating that the content up to and including that point should be cached by the provider.
- **Cache_Control**: The Anthropic-specific JSON field (`{ type: 'ephemeral' }`) added to a content block to signal a cache breakpoint.
- **Cached_Content**: The Gemini-specific resource created via the Context Caching API that stores static prompt content for reuse.
- **Static_Content**: The portion of a prompt that remains constant across multiple requests and is eligible for caching.
- **Dynamic_Content**: The portion of a prompt that changes between requests and is not cached.
- **Provider**: An LLM API integration within ruby_llm (e.g., Anthropic, Gemini).
- **Chat**: The `RubyLLM::Chat` object representing a conversation with an LLM.
- **Message**: A single turn in a `Chat` conversation, with a role (system, user, assistant, tool) and content.
- **Content_Block**: A discrete unit of content within a message (text, image, document, etc.) as formatted for a specific provider's API.
- **Token_Usage**: The `RubyLLM::Tokens` object tracking input, output, cached, and cache_creation token counts for a response.

---

## Requirements

### Requirement 1: Cache Point API on Messages

**User Story:** As a developer, I want to mark a message as a cache point, so that the provider caches the prompt up to that message and I save on input tokens for repeated calls.

#### Acceptance Criteria

1. THE `Chat` SHALL provide a method to add a message with a cache point flag (e.g., `with_cache_point: true` on `ask` or `with_instructions`).
2. THE `Message` SHALL store a boolean `cache_point` attribute indicating whether the message is marked as a cache breakpoint.
3. WHEN a `Message` is created with `cache_point: true`, THE `Message` SHALL expose `cache_point?` returning `true`.
4. WHEN a `Message` is created without a cache point flag, THE `Message` SHALL expose `cache_point?` returning `false`.
5. FOR ALL messages without a cache point flag, THE `Chat` SHALL produce provider payloads identical to the current behavior (invariant: caching feature must not alter non-cached request payloads).

### Requirement 2: Anthropic Cache Control Formatting

**User Story:** As a developer using Anthropic models, I want cache points to be translated into `cache_control` headers on content blocks, so that Anthropic caches the static portion of my prompt.

#### Acceptance Criteria

1. WHEN a `Message` with `cache_point: true` is formatted for the Anthropic provider, THE `Anthropic::Chat` formatter SHALL add `cache_control: { type: 'ephemeral' }` to the last content block of that message.
2. WHEN a system `Message` with `cache_point: true` is formatted for the Anthropic provider, THE `Anthropic::Chat` formatter SHALL add `cache_control: { type: 'ephemeral' }` to the last block of the system content array.
3. WHEN multiple `Message` objects have `cache_point: true`, THE `Anthropic::Chat` formatter SHALL add `cache_control` to the last content block of each such message, up to the provider limit of 4 cache breakpoints.
4. IF a `Message` has `cache_point: true` but its content is a `Content::Raw` block already containing `cache_control`, THEN THE `Anthropic::Chat` formatter SHALL preserve the existing `cache_control` without duplication.
5. WHEN a `Message` does not have `cache_point: true`, THE `Anthropic::Chat` formatter SHALL NOT add `cache_control` to any of its content blocks.

### Requirement 3: Gemini Context Caching Integration

**User Story:** As a developer using Gemini models, I want cache points to use Gemini's Context Caching API, so that large static context is uploaded once and reused across requests.

#### Acceptance Criteria

1. WHEN a `Chat` request is made with at least one `Message` marked `cache_point: true` and the model supports context caching, THE `Gemini::Chat` formatter SHALL identify the contiguous static prefix of messages up to and including the last cache-pointed message.
2. WHEN static content has not yet been cached for the current session, THE `Gemini` provider SHALL create a `cachedContent` resource via the Gemini Context Caching API containing the static messages.
3. WHEN a `cachedContent` resource exists for the current session, THE `Gemini` provider SHALL reference it by name in the `generateContent` request payload using the `cachedContent` field instead of re-sending the static messages inline.
4. WHEN the `cachedContent` resource has expired or is invalid, THE `Gemini` provider SHALL recreate the cache and retry the request.
5. THE `Gemini` provider SHALL set a configurable TTL (time-to-live) on created `cachedContent` resources, defaulting to 3600 seconds (1 hour).
6. WHEN a model does not support Gemini context caching, THE `Gemini` provider SHALL send the full message list without a `cachedContent` reference and SHALL log a warning.

### Requirement 4: Cache Token Usage Reporting

**User Story:** As a developer, I want to see how many tokens were served from cache, so that I can verify caching is working and understand my cost savings.

#### Acceptance Criteria

1. WHEN an Anthropic response includes `cache_read_input_tokens` in its usage data, THE `Anthropic::Chat` parser SHALL populate `Message#cached_tokens` with that value.
2. WHEN an Anthropic response includes `cache_creation_input_tokens` in its usage data, THE `Anthropic::Chat` parser SHALL populate `Message#cache_creation_tokens` with that value.
3. WHEN a Gemini response includes `cachedContentTokenCount` in its `usageMetadata`, THE `Gemini::Chat` parser SHALL populate `Message#cached_tokens` with that value.
4. THE `Token_Usage` object SHALL expose `cached` and `cache_creation` attributes accessible via `Message#cached_tokens` and `Message#cache_creation_tokens`.
5. WHEN no cache tokens are present in the response, THE `Token_Usage` object SHALL return `nil` for `cached` and `cache_creation` (not zero), preserving existing behavior.

### Requirement 5: Provider Capability Detection

**User Story:** As a developer, I want the gem to handle cache points gracefully on providers or models that do not support caching, so that my code does not break when switching providers.

#### Acceptance Criteria

1. WHEN a `Message` with `cache_point: true` is sent to a provider that does not implement cache point formatting (e.g., OpenAI), THE provider SHALL silently ignore the cache point flag and send the message without any cache-related fields.
2. WHEN a Gemini model does not support context caching, THE `Gemini` provider SHALL log a warning at the `warn` level indicating the model does not support caching and SHALL proceed with the full inline payload.
3. THE `Model` capability data SHALL include a `supports_prompt_caching` boolean field for each model that supports it, so that providers can check support before attempting to use caching APIs.
