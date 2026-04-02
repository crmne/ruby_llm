# Implementation Plan: Prompt Caching

## Overview

Add prompt caching support to ruby_llm for Anthropic and Gemini providers. The implementation
touches a small surface area: `Message` gains a `cache_point` boolean, `Chat` forwards it through
`with_instructions` and `ask`, `Anthropic::Chat` injects `cache_control` blocks, and `Gemini::Chat`
manages the Context Caching API lifecycle. Token usage reporting already works — it just needs the
`Message` attribute wiring confirmed.

## Tasks

- [x] 1. Add `cache_point` attribute to `Message`
  - Add `attr_reader :cache_point` and `alias cache_point? cache_point` to `lib/ruby_llm/message.rb`
  - Initialize `@cache_point = options.fetch(:cache_point, false)` in `Message#initialize`
  - Include `cache_point: true` in `Message#to_h` only when `@cache_point` is truthy (use `.compact`)
  - _Requirements: 1.2, 1.3, 1.4_

  - [ ]* 1.1 Write property test for `cache_point?` reflects construction flag
    - **Property 1: cache_point? reflects construction flag**
    - For all `(role, content, flag)` combinations, `Message.new(role:, content:, cache_point: flag).cache_point?` must equal `flag`
    - Also verify `to_h` includes `cache_point: true` only when set
    - **Validates: Requirements 1.2, 1.3, 1.4**

  - [ ]* 1.2 Write unit tests for `Message` cache_point attribute
    - Test `cache_point?` returns `false` by default
    - Test `cache_point?` returns `true` when constructed with `cache_point: true`
    - Test `to_h` omits `cache_point` key when false, includes it when true
    - _Requirements: 1.2, 1.3, 1.4_

- [x] 2. Extend `Chat` to accept and forward `cache_point:`
  - Add `cache_point: false` keyword to `Chat#with_instructions` signature in `lib/ruby_llm/chat.rb`
  - Pass `cache_point:` through to `append_system_instruction` and `replace_system_instruction`
  - Update both private helpers to accept `cache_point:` and pass it when constructing `Message.new`
  - Add `cache_point: false` keyword to `Chat#ask` and pass it to `add_message`
  - Add `@cached_content_name = nil` instance variable in `Chat#initialize` (Gemini session handle)
  - _Requirements: 1.1, 3.3_

  - [ ]* 2.1 Write unit tests for `Chat` cache_point forwarding
    - Test that `with_instructions(..., cache_point: true)` produces a system `Message` with `cache_point? == true`
    - Test that `ask(..., cache_point: true)` produces a user `Message` with `cache_point? == true`
    - Test that omitting `cache_point:` leaves messages with `cache_point? == false`
    - _Requirements: 1.1, 1.5_

- [x] 3. Checkpoint — ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 4. Implement Anthropic `cache_control` injection
  - Add private `inject_cache_control(blocks)` helper to `Anthropic::Chat` in `lib/ruby_llm/providers/anthropic/chat.rb`
    - Returns `blocks` unchanged if empty
    - Skips injection if `blocks.last` already has a `:cache_control` key (no duplication for `Content::Raw`)
    - Otherwise merges `cache_control: { type: 'ephemeral' }` onto `blocks.last`
  - Call `inject_cache_control(blocks)` in `build_system_content` when `msg.cache_point?`
  - Call `inject_cache_control(content_blocks)` in `format_basic_message_with_thinking` when `msg.cache_point?`
  - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5_

  - [ ]* 4.1 Write property test for Anthropic `cache_control` injection (single message)
    - **Property 3: Anthropic cache_control injection**
    - For any message with `cache_point: true`, the last content block in the formatted output has `cache_control: { type: 'ephemeral' }` and no other block has `cache_control` added
    - **Validates: Requirements 2.1, 2.2**

  - [ ]* 4.2 Write property test for Anthropic multiple cache points
    - **Property 4: Anthropic multiple cache points**
    - For any list of N messages (1 ≤ N ≤ 4) with `cache_point: true`, the payload contains exactly N blocks with `cache_control: { type: 'ephemeral' }`
    - **Validates: Requirements 2.3**

  - [ ]* 4.3 Write unit tests for Anthropic `cache_control` injection
    - Test single system message with `cache_point: true` → last block has `cache_control`
    - Test single user message with `cache_point: true` → last block has `cache_control`
    - Test `Content::Raw` block already containing `cache_control` is not duplicated
    - Test message without `cache_point: true` → no `cache_control` added anywhere
    - _Requirements: 2.1, 2.2, 2.4, 2.5_

- [x] 5. Add `supports_prompt_caching?` to `Anthropic::Capabilities`
  - Add `def supports_prompt_caching?(model_id) = !model_id.match?(/claude-[12]/)` to `lib/ruby_llm/providers/anthropic/capabilities.rb`
  - _Requirements: 5.3_

  - [ ]* 5.1 Write property test for Anthropic capability detection
    - **Property 10 (Anthropic): Capability detection correctness**
    - For all known Anthropic model IDs, `supports_prompt_caching?` returns `true` only for claude-3+ models
    - **Validates: Requirements 5.3**

- [x] 6. Checkpoint — ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 7. Implement Gemini static prefix extraction
  - Add private `split_messages_at_cache_point(messages)` helper to `Gemini::Chat` in `lib/ruby_llm/providers/gemini/chat.rb`
    - Returns `[static_prefix, dynamic_suffix]` where `static_prefix` is all messages up to and including the last `cache_point?` message
    - Returns `[[], messages]` when no message has `cache_point?`
  - _Requirements: 3.1_

  - [ ]* 7.1 Write property test for Gemini static prefix identification
    - **Property 5: Gemini static prefix identification**
    - For any message list with at least one `cache_point?` message, `static_prefix == messages[0..last_cache_point_index]` and `dynamic_suffix == messages[(last_cache_point_index+1)..]`
    - **Validates: Requirements 3.1**

  - [ ]* 7.2 Write unit tests for Gemini prefix extraction
    - Test list with one cache-pointed message at the end → full list is static, empty dynamic
    - Test list with cache-pointed message in the middle → correct split
    - Test list with no cache-pointed messages → empty static, full dynamic
    - _Requirements: 3.1_

- [x] 8. Implement Gemini `create_cached_content` and `render_payload` caching support
  - Add private `create_cached_content(static_messages, model, ttl)` method to `Gemini::Chat`
    - POSTs to `v1beta/cachedContents` with `{ model: "models/#{model.id}", contents: format_messages(static_messages), ttl: "#{ttl}s" }`
    - Returns the `name` field from the response (e.g. `"cachedContents/abc123"`)
  - Modify `render_payload` to accept `cached_content_name:` keyword (default `nil`)
    - When `cached_content_name` is present: set `payload[:cachedContent] = cached_content_name` and use only the dynamic suffix in `contents`
    - When absent: format all messages inline as today
  - Add warning log in `render_payload` when any message has `cache_point?` but the model does not support caching (`Capabilities.supports_caching?(model.id)` is false)
  - _Requirements: 3.2, 3.3, 3.5, 3.6_

  - [ ]* 8.1 Write property test for Gemini cached payload structure
    - **Property 6: Gemini cached payload uses cachedContent field**
    - For any non-nil `cached_content_name` and dynamic message list, `payload[:cachedContent] == cached_content_name` and static messages are absent from `payload[:contents]`
    - **Validates: Requirements 3.3**

  - [ ]* 8.2 Write property test for Gemini TTL configuration
    - **Property 7: Gemini TTL configuration**
    - For any positive integer TTL value T, the cache creation request body includes `ttl: "#{T}s"`; when no TTL is configured the default is `"3600s"`
    - **Validates: Requirements 3.5**

  - [ ]* 8.3 Write property test for Gemini unsupported model degrades gracefully
    - **Property 8: Gemini unsupported model degrades gracefully**
    - For all unsupported Gemini model IDs and any message list, `render_payload` output does not contain `:cachedContent`
    - **Validates: Requirements 3.6, 5.2**

  - [ ]* 8.4 Write unit tests for Gemini caching payload
    - Test `render_payload` with `cached_content_name:` set → payload has `:cachedContent`, static messages absent from `:contents`
    - Test `render_payload` without `cached_content_name:` → no `:cachedContent` key, all messages inline
    - Test unsupported model with `cache_point?` messages → no `:cachedContent`, warning logged
    - _Requirements: 3.3, 3.5, 3.6_

- [x] 9. Implement Gemini cache lifecycle in provider `complete` flow
  - Override or extend the provider `complete` method (or add a pre-complete hook) in `Gemini::Chat` to:
    - Check if any message has `cache_point?` and `Capabilities.supports_caching?(model.id)`
    - If yes and `@cached_content_name` is nil: call `create_cached_content` with the static prefix and TTL from `params[:cache_ttl] || 3600`, store result in `@cached_content_name`
    - Pass `cached_content_name: @cached_content_name` to `render_payload`
    - On 404 response: clear `@cached_content_name`, recreate cache, retry once; propagate error on second failure
  - _Requirements: 3.2, 3.3, 3.4, 3.5_

  - [ ]* 9.1 Write unit tests for Gemini cache lifecycle
    - Test first call creates `cachedContent` and stores name on chat
    - Test second call reuses stored name without re-creating
    - Test 404 response clears name, recreates, and retries
    - _Requirements: 3.2, 3.3, 3.4_

- [x] 10. Checkpoint — ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 11. Verify token usage reporting wiring
  - Confirm `Anthropic::Chat#build_message` already reads `cache_read_input_tokens` → `cached_tokens` and `cache_creation_input_tokens` → `cache_creation_tokens` (already implemented; verify no changes needed)
  - Confirm `Gemini::Chat#parse_completion_response` already reads `cachedContentTokenCount` → `cached_tokens` (already implemented; verify no changes needed)
  - Add any missing wiring if found during review
  - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5_

  - [ ]* 11.1 Write property test for cache token parsing round-trip
    - **Property 9: Cache token parsing round-trip**
    - For any non-negative integers `(cached, cache_creation)`, the parsed `Message` exposes those exact values via `cached_tokens` and `cache_creation_tokens`; for responses without those fields both are `nil`
    - **Validates: Requirements 4.1, 4.2, 4.3, 4.4, 4.5**

- [ ] 12. Write property test for non-cached payload invariant
  - **Property 2: Non-cached payloads are unchanged (invariant)**
  - For any message list where no message has `cache_point: true`, the Anthropic and Gemini `render_payload` outputs are identical to the output produced without this feature
  - **Validates: Requirements 1.5, 2.5, 5.1**

- [ ] 13. Add VCR integration tests for Anthropic caching round-trip
  - Create `spec/ruby_llm/providers/anthropic/caching_spec.rb` with VCR cassettes
  - Test: first call with `cache_point: true` on system message → response has `cache_creation_tokens > 0`
  - Test: second call to same chat → response has `cached_tokens > 0`
  - Record cassettes with `rake vcr:record[anthropic]` (requires API key)
  - _Requirements: 2.1, 4.1, 4.2_

- [ ] 14. Add VCR integration tests for Gemini caching round-trip
  - Create `spec/ruby_llm/providers/gemini/caching_spec.rb` with VCR cassettes
  - Test: first call creates `cachedContent`, `@cached_content_name` is set on the chat object
  - Test: second call reuses `cachedContent` name in payload, response has `cached_tokens > 0`
  - Test: expired cache (simulate 404) triggers recreation and retry
  - Record cassettes with `rake vcr:record[gemini]` (requires API key)
  - _Requirements: 3.2, 3.3, 3.4, 4.3_

- [x] 15. Final checkpoint — ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for a faster MVP
- Property tests should use `rantly` or `propcheck` with a minimum of 100 iterations each
- Never edit `models.json` or `aliases.json`
- VCR cassettes must be checked for leaked API keys before committing
- Run `overcommit --install` and `overcommit --run` before opening a PR
- The Gemini Context Caching API requires a minimum of ~32,768 tokens in the static prefix; shorter content will return an API error that propagates as `RubyLLM::Error`
- Anthropic supports up to 4 `cache_control` breakpoints per request; exceeding this limit returns a 400 that propagates as `RubyLLM::Error`
