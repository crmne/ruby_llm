---
layout: default
title: Available Models
nav_order: 2
llms: false
description: Browse 1535 AI models across 15 remote providers. Updated 2026-08-20.
redirect_from:
  - /guides/available-models
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

_Updated 2026-08-20. This page lists the latest refreshed registry, also available as raw JSON at [rubyllm.com/models.json](https://rubyllm.com/models.json). It covers remote providers only; models on local providers (Ollama, GPUStack) are discovered from your own servers when you refresh._

Your installed gem may bundle an older snapshot of the registry. Refresh it to get the latest models in your app too:

```ruby
RubyLLM.models.refresh!
```

See [the models guide]({{ "/models/" | relative_url }}) for how refreshing works in plain Ruby and Rails.

## Models by Provider

### Anthropic (13)

| Model | Provider | I/O | Capabilities | Context | Max Output | Standard Pricing (per 1M tokens) |
| :-- | :-- | :-- | :-- | --: | --: | :-- |
| claude-fable-5 | anthropic | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, citations, tool_choice, parallel_tool_calls, batch | 1000000 | 128000 | In: $10.00, Out: $50.00, Cache Read: $1.00, Cache Write: $12.50 |
| claude-haiku-4-5-20251001 | anthropic | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, citations, tool_choice, parallel_tool_calls, batch | 200000 | 64000 | In: $1.00, Out: $5.00, Cache Read: $0.10, Cache Write: $1.25 |
| claude-haiku-4-5 | anthropic | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 200000 | 64000 | In: $1.00, Out: $5.00, Cache Read: $0.10, Cache Write: $1.25 |
| claude-opus-4-5-20251101 | anthropic | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, citations, tool_choice, parallel_tool_calls, batch | 200000 | 64000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| claude-opus-4-5 | anthropic | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 200000 | 64000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| claude-opus-4-6 | anthropic | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, citations, tool_choice, parallel_tool_calls, batch | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| claude-opus-4-7 | anthropic | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, citations, tool_choice, parallel_tool_calls, batch | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| claude-opus-4-8 | anthropic | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, citations, tool_choice, parallel_tool_calls, batch | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| claude-opus-5 | anthropic | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, citations, tool_choice, parallel_tool_calls, batch | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| claude-sonnet-4-5-20250929 | anthropic | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, citations, tool_choice, parallel_tool_calls, batch | 1000000 | 64000 | In: $3.00, Out: $15.00, Cache Read: $0.30, Cache Write: $3.75 |
| claude-sonnet-4-5 | anthropic | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1000000 | 64000 | In: $3.00, Out: $15.00, Cache Read: $0.30, Cache Write: $3.75 |
| claude-sonnet-4-6 | anthropic | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, citations, tool_choice, parallel_tool_calls, batch | 1000000 | 128000 | In: $3.00, Out: $15.00, Cache Read: $0.30, Cache Write: $3.75 |
| claude-sonnet-5 | anthropic | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, citations, tool_choice, parallel_tool_calls, batch | 1000000 | 128000 | In: $2.00, Out: $10.00, Cache Read: $0.20, Cache Write: $2.50 |


### Azure (209)

| Model | Provider | I/O | Capabilities | Context | Max Output | Standard Pricing (per 1M tokens) |
| :-- | :-- | :-- | :-- | --: | --: | :-- |
| Codestral-2501 | azure | In: text; Out: text | - | - | - | - |
| Codestral-2501-2 | azure | In: text; Out: text | - | - | - | - |
| Cohere-command-a-plus-05-2026 | azure | In: text; Out: text | - | - | - | - |
| Cohere-embed-v3-english | azure | In: text; Out: text | - | - | - | - |
| Cohere-embed-v3-multilingual | azure | In: text; Out: text | - | - | - | - |
| Cohere-rerank-v4.0-fast | azure | In: text; Out: text | - | - | - | - |
| Cohere-rerank-v4.0-pro | azure | In: text; Out: text | - | - | - | - |
| DeepSeek-V3.2 | azure | In: text; Out: text | - | - | - | - |
| DeepSeek-V3.2-Speciale | azure | In: text; Out: text | - | - | - | - |
| DeepSeek-V4-Flash | azure | In: text; Out: text | - | - | - | - |
| DeepSeek-V4-Flash-0731 | azure | In: text; Out: text | - | - | - | - |
| DeepSeek-V4-Flash-0731-2026-07-31 | azure | In: text; Out: text | - | - | - | - |
| DeepSeek-V4-Flash-2026-04-23 | azure | In: text; Out: text | - | - | - | - |
| DeepSeek-V4-Pro | azure | In: text; Out: text | - | - | - | - |
| DeepSeek-V4-Pro-2026-04-23 | azure | In: text; Out: text | - | - | - | - |
| FLUX-1.1-pro | azure | In: text; Out: text | - | - | - | - |
| FLUX.1-Kontext-pro | azure | In: text; Out: text | - | - | - | - |
| FLUX.2-flex | azure | In: text; Out: text | - | - | - | - |
| FLUX.2-pro | azure | In: text; Out: text | - | - | - | - |
| Kimi-K2.5 | azure | In: text; Out: text | - | - | - | - |
| Kimi-K2.6-2026-04-20 | azure | In: text; Out: text | - | - | - | - |
| Kimi-K2.7-Code-2026-06-12 | azure | In: text; Out: text | - | - | - | - |
| Llama-3.3-70B-Instruct | azure | In: text; Out: text | - | - | - | - |
| Llama-3.3-70B-Instruct-2 | azure | In: text; Out: text | - | - | - | - |
| Llama-3.3-70B-Instruct-3 | azure | In: text; Out: text | - | - | - | - |
| Llama-3.3-70B-Instruct-4 | azure | In: text; Out: text | - | - | - | - |
| Llama-3.3-70B-Instruct-5 | azure | In: text; Out: text | - | - | - | - |
| Llama-3.3-70B-Instruct-9 | azure | In: text; Out: text | - | - | - | - |
| Llama-4-Maverick-17B-128E-Instruct-FP8 | azure | In: text; Out: text | - | - | - | - |
| Llama-4-Scout-17B-16E-Instruct | azure | In: text; Out: text | - | - | - | - |
| MAI-Image-2.5-2026-06-02 | azure | In: text; Out: text | - | - | - | - |
| MAI-Image-2.5-Flash-2026-06-02 | azure | In: text; Out: text | - | - | - | - |
| MAI-Image-2.5-Pro-2026-06-19 | azure | In: text; Out: text | - | - | - | - |
| MAI-Image-2e | azure | In: text; Out: text | - | - | - | - |
| MAI-Image-2e-2026-04-09 | azure | In: text; Out: text | - | - | - | - |
| MAI-Thinking-1 | azure | In: text; Out: text | - | - | - | - |
| MAI-Thinking-1-2026-06-01 | azure | In: text; Out: text | - | - | - | - |
| Ministral-3B | azure | In: text; Out: text | - | - | - | - |
| Mistral-Large-3 | azure | In: text; Out: text | - | - | - | - |
| Mistral-large | azure | In: text; Out: text | - | - | - | - |
| Phi-4 | azure | In: text; Out: text | - | - | - | - |
| Phi-4-2 | azure | In: text; Out: text | - | - | - | - |
| Phi-4-3 | azure | In: text; Out: text | - | - | - | - |
| Phi-4-4 | azure | In: text; Out: text | - | - | - | - |
| Phi-4-5 | azure | In: text; Out: text | - | - | - | - |
| Phi-4-6 | azure | In: text; Out: text | - | - | - | - |
| Phi-4-7 | azure | In: text; Out: text | - | - | - | - |
| Phi-4-mini-instruct | azure | In: text; Out: text | - | - | - | - |
| Phi-4-mini-reasoning | azure | In: text; Out: text | - | - | - | - |
| Phi-4-multimodal-instruct | azure | In: text; Out: text | - | - | - | - |
| Phi-4-reasoning | azure | In: text; Out: text | - | - | - | - |
| claude-fable-5 | azure | In: text; Out: text | - | - | - | - |
| claude-haiku-4-5 | azure | In: text; Out: text | - | - | - | - |
| claude-haiku-4-5-2 | azure | In: text; Out: text | - | - | - | - |
| claude-haiku-4-5-20251001 | azure | In: text; Out: text | - | - | - | - |
| claude-opus-4-5 | azure | In: text; Out: text | - | - | - | - |
| claude-opus-4-5-20251101 | azure | In: text; Out: text | - | - | - | - |
| claude-opus-4-6 | azure | In: text; Out: text | - | - | - | - |
| claude-opus-4-7 | azure | In: text; Out: text | - | - | - | - |
| claude-opus-4-8 | azure | In: text; Out: text | - | - | - | - |
| claude-opus-4-8-2 | azure | In: text; Out: text | - | - | - | - |
| claude-opus-5 | azure | In: text; Out: text | - | - | - | - |
| claude-opus-5-2 | azure | In: text; Out: text | - | - | - | - |
| claude-sonnet-4-5 | azure | In: text; Out: text | - | - | - | - |
| claude-sonnet-4-5-20250929 | azure | In: text; Out: text | - | - | - | - |
| claude-sonnet-4-6 | azure | In: text; Out: text | - | - | - | - |
| claude-sonnet-5 | azure | In: text; Out: text | - | - | - | - |
| claude-sonnet-5-2 | azure | In: text; Out: text | - | - | - | - |
| codex-mini-2025-05-16 | azure | In: text; Out: text | - | - | - | - |
| cohere-command-a | azure | In: text; Out: text | - | - | - | - |
| computer-use-preview-2025-04-15 | azure | In: text; Out: text | - | - | - | - |
| embed-v-4-0 | azure | In: text; Out: text | - | - | - | - |
| gpt-4.1 | azure | In: text; Out: text | - | - | - | - |
| gpt-4.1-2025-04-14 | azure | In: text; Out: text | - | - | - | - |
| gpt-4.1-mini | azure | In: text; Out: text | - | - | - | - |
| gpt-4.1-mini-2025-04-14 | azure | In: text; Out: text | - | - | - | - |
| gpt-4.1-nano | azure | In: text; Out: text | - | - | - | - |
| gpt-4.1-nano-2025-04-14 | azure | In: text; Out: text | - | - | - | - |
| gpt-4o | azure | In: text; Out: text | - | - | - | - |
| gpt-4o-2024-05-13 | azure | In: text; Out: text | - | - | - | - |
| gpt-4o-2024-08-06 | azure | In: text; Out: text | - | - | - | - |
| gpt-4o-2024-11-20 | azure | In: text; Out: text | - | - | - | - |
| gpt-4o-audio-mai | azure | In: text; Out: text | - | - | - | - |
| gpt-4o-mini | azure | In: text; Out: text | - | - | - | - |
| gpt-4o-mini-2024-07-18 | azure | In: text; Out: text | - | - | - | - |
| gpt-4o-mini-transcribe | azure | In: text; Out: text | - | - | - | - |
| gpt-4o-mini-transcribe-2025-03-20 | azure | In: text; Out: text | - | - | - | - |
| gpt-4o-mini-transcribe-2025-12-15 | azure | In: text; Out: text | - | - | - | - |
| gpt-4o-mini-tts | azure | In: text; Out: text | - | - | - | - |
| gpt-4o-mini-tts-2025-03-20 | azure | In: text; Out: text | - | - | - | - |
| gpt-4o-mini-tts-2025-12-15 | azure | In: text; Out: text | - | - | - | - |
| gpt-4o-transcribe | azure | In: text; Out: text | - | - | - | - |
| gpt-4o-transcribe-2025-03-20 | azure | In: text; Out: text | - | - | - | - |
| gpt-4o-transcribe-diarize | azure | In: text; Out: text | - | - | - | - |
| gpt-4o-transcribe-diarize-2025-10-15 | azure | In: text; Out: text | - | - | - | - |
| gpt-5 | azure | In: text; Out: text | - | - | - | - |
| gpt-5-2025-08-07 | azure | In: text; Out: text | - | - | - | - |
| gpt-5-codex-2025-09-15 | azure | In: text; Out: text | - | - | - | - |
| gpt-5-mini | azure | In: text; Out: text | - | - | - | - |
| gpt-5-mini-2025-08-07 | azure | In: text; Out: text | - | - | - | - |
| gpt-5-nano | azure | In: text; Out: text | - | - | - | - |
| gpt-5-nano-2025-08-07 | azure | In: text; Out: text | - | - | - | - |
| gpt-5-pro-2025-10-06 | azure | In: text; Out: text | - | - | - | - |
| gpt-5.1 | azure | In: text; Out: text | - | - | - | - |
| gpt-5.1-2025-11-13 | azure | In: text; Out: text | - | - | - | - |
| gpt-5.1-codex-2025-11-13 | azure | In: text; Out: text | - | - | - | - |
| gpt-5.1-codex-max | azure | In: text; Out: text | - | - | - | - |
| gpt-5.1-codex-max-2025-12-04 | azure | In: text; Out: text | - | - | - | - |
| gpt-5.1-codex-mini-2025-11-13 | azure | In: text; Out: text | - | - | - | - |
| gpt-5.2 | azure | In: text; Out: text | - | - | - | - |
| gpt-5.2-2025-12-11 | azure | In: text; Out: text | - | - | - | - |
| gpt-5.2-codex | azure | In: text; Out: text | - | - | - | - |
| gpt-5.2-codex-2026-01-14 | azure | In: text; Out: text | - | - | - | - |
| gpt-5.3-codex | azure | In: text; Out: text | - | - | - | - |
| gpt-5.3-codex-2026-02-24 | azure | In: text; Out: text | - | - | - | - |
| gpt-5.4 | azure | In: text; Out: text | - | - | - | - |
| gpt-5.4-2026-03-05 | azure | In: text; Out: text | - | - | - | - |
| gpt-5.4-mini | azure | In: text; Out: text | - | - | - | - |
| gpt-5.4-mini-2026-03-17 | azure | In: text; Out: text | - | - | - | - |
| gpt-5.4-nano | azure | In: text; Out: text | - | - | - | - |
| gpt-5.4-nano-2026-03-17 | azure | In: text; Out: text | - | - | - | - |
| gpt-5.4-pro | azure | In: text; Out: text | - | - | - | - |
| gpt-5.4-pro-2026-03-05 | azure | In: text; Out: text | - | - | - | - |
| gpt-5.5 | azure | In: text; Out: text | - | - | - | - |
| gpt-5.5-2026-04-24 | azure | In: text; Out: text | - | - | - | - |
| gpt-5.6-luna | azure | In: text; Out: text | - | - | - | - |
| gpt-5.6-luna-2026-07-09 | azure | In: text; Out: text | - | - | - | - |
| gpt-5.6-sol | azure | In: text; Out: text | - | - | - | - |
| gpt-5.6-sol-2026-07-09 | azure | In: text; Out: text | - | - | - | - |
| gpt-5.6-terra | azure | In: text; Out: text | - | - | - | - |
| gpt-5.6-terra-2026-07-09 | azure | In: text; Out: text | - | - | - | - |
| gpt-audio | azure | In: text; Out: text | - | - | - | - |
| gpt-audio-1.5 | azure | In: text; Out: text | - | - | - | - |
| gpt-audio-1.5-2026-02-23 | azure | In: text; Out: text | - | - | - | - |
| gpt-audio-2025-08-28 | azure | In: text; Out: text | - | - | - | - |
| gpt-audio-mini | azure | In: text; Out: text | - | - | - | - |
| gpt-audio-mini-2025-10-06 | azure | In: text; Out: text | - | - | - | - |
| gpt-audio-mini-2025-12-15 | azure | In: text; Out: text | - | - | - | - |
| gpt-chat-latest-2026-05-05 | azure | In: text; Out: text | - | - | - | - |
| gpt-chat-latest-2026-05-28 | azure | In: text; Out: text | - | - | - | - |
| gpt-chat-latest-2026-06-24 | azure | In: text; Out: text | - | - | - | - |
| gpt-chat-latest-2026-08-06 | azure | In: text; Out: text | - | - | - | - |
| gpt-image-1 | azure | In: text; Out: text | - | - | - | - |
| gpt-image-1-2025-04-15 | azure | In: text; Out: text | - | - | - | - |
| gpt-image-1-mini | azure | In: text; Out: text | - | - | - | - |
| gpt-image-1-mini-2025-10-06 | azure | In: text; Out: text | - | - | - | - |
| gpt-image-1.5 | azure | In: text; Out: text | - | - | - | - |
| gpt-image-1.5-2025-12-16 | azure | In: text; Out: text | - | - | - | - |
| gpt-image-2 | azure | In: text; Out: text | - | - | - | - |
| gpt-image-2-2026-04-21 | azure | In: text; Out: text | - | - | - | - |
| gpt-live-transcribe | azure | In: text; Out: text | - | - | - | - |
| gpt-live-transcribe-2026-07-28 | azure | In: text; Out: text | - | - | - | - |
| gpt-offline-whisper-1 | azure | In: text; Out: text | - | - | - | - |
| gpt-offline-whisper-1-2026-07-27 | azure | In: text; Out: text | - | - | - | - |
| gpt-oss-120b | azure | In: text; Out: text | - | - | - | - |
| gpt-oss-20b | azure | In: text; Out: text | - | - | - | - |
| gpt-oss-20b-11 | azure | In: text; Out: text | - | - | - | - |
| gpt-realtime | azure | In: text; Out: text | - | - | - | - |
| gpt-realtime-1.5 | azure | In: text; Out: text | - | - | - | - |
| gpt-realtime-1.5-2026-02-23 | azure | In: text; Out: text | - | - | - | - |
| gpt-realtime-2 | azure | In: text; Out: text | - | - | - | - |
| gpt-realtime-2-2026-05-06 | azure | In: text; Out: text | - | - | - | - |
| gpt-realtime-2.1 | azure | In: text; Out: text | - | - | - | - |
| gpt-realtime-2.1-2026-07-07 | azure | In: text; Out: text | - | - | - | - |
| gpt-realtime-2.1-mini-2026-07-07 | azure | In: text; Out: text | - | - | - | - |
| gpt-realtime-2025-08-28 | azure | In: text; Out: text | - | - | - | - |
| gpt-realtime-mini | azure | In: text; Out: text | - | - | - | - |
| gpt-realtime-mini-2025-10-06 | azure | In: text; Out: text | - | - | - | - |
| gpt-realtime-mini-2025-12-15 | azure | In: text; Out: text | - | - | - | - |
| gpt-realtime-translate-2026-05-06 | azure | In: text; Out: text | - | - | - | - |
| gpt-realtime-whisper-2026-05-06 | azure | In: text; Out: text | - | - | - | - |
| grok-4-1-fast-non-reasoning | azure | In: text; Out: text | - | - | - | - |
| grok-4-1-fast-reasoning | azure | In: text; Out: text | - | - | - | - |
| grok-4-20-non-reasoning | azure | In: text; Out: text | - | - | - | - |
| grok-4-20-reasoning | azure | In: text; Out: text | - | - | - | - |
| grok-4.3 | azure | In: text; Out: text | - | - | - | - |
| mai-m365 | azure | In: text; Out: text | - | - | - | - |
| mai-m365-2026-04-27 | azure | In: text; Out: text | - | - | - | - |
| mistral-document-ai-2512 | azure | In: text; Out: text | - | - | - | - |
| mistral-medium-2505 | azure | In: text; Out: text | - | - | - | - |
| mistral-medium-3-5 | azure | In: text; Out: text | - | - | - | - |
| mistral-ocr-4-0 | azure | In: text; Out: text | - | - | - | - |
| mistral-small-2503 | azure | In: text; Out: text | - | - | - | - |
| model-router | azure | In: text; Out: text | - | - | - | - |
| model-router-2025-05-19 | azure | In: text; Out: text | - | - | - | - |
| model-router-2025-08-07 | azure | In: text; Out: text | - | - | - | - |
| model-router-2025-11-18 | azure | In: text; Out: text | - | - | - | - |
| o1 | azure | In: text; Out: text | - | - | - | - |
| o1-2024-12-17 | azure | In: text; Out: text | - | - | - | - |
| o1-pro | azure | In: text; Out: text | - | - | - | - |
| o1-pro-2025-03-19 | azure | In: text; Out: text | - | - | - | - |
| o3 | azure | In: text; Out: text | - | - | - | - |
| o3-2025-04-16 | azure | In: text; Out: text | - | - | - | - |
| o3-deep-research-2025-06-26 | azure | In: text; Out: text | - | - | - | - |
| o3-deep-research-2025-06-26-ev3 | azure | In: text; Out: text | - | - | - | - |
| o3-mini | azure | In: text; Out: text | - | - | - | - |
| o3-mini-2025-01-31 | azure | In: text; Out: text | - | - | - | - |
| o4-mini | azure | In: text; Out: text | - | - | - | - |
| o4-mini-2025-04-16 | azure | In: text; Out: text | - | - | - | - |
| qwen-3-32b | azure | In: text; Out: text | - | - | - | - |
| qwen3-32b | azure | In: text; Out: text | - | - | - | - |
| qwen3-32b-v2 | azure | In: text; Out: text | - | - | - | - |
| sora-2-2025-12-08 | azure | In: text; Out: text | - | - | - | - |
| text-embedding-3-large | azure | In: text; Out: embeddings | - | - | - | - |
| text-embedding-3-small | azure | In: text; Out: embeddings | - | - | - | - |
| text-embedding-ada-002 | azure | In: text; Out: embeddings | - | - | - | - |
| text-embedding-ada-002-2 | azure | In: text; Out: embeddings | - | - | - | - |
| whisper | azure | In: text; Out: text | - | - | - | - |
| whisper-001 | azure | In: text; Out: text | - | - | - | - |


### Bedrock (196)

| Model | Provider | I/O | Capabilities | Context | Max Output | Standard Pricing (per 1M tokens) |
| :-- | :-- | :-- | :-- | --: | --: | :-- |
| au.anthropic.claude-opus-4-6-v1 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1000000 | 128000 | In: $16.50, Out: $82.50, Cache Read: $1.65, Cache Write: $20.62 |
| au.anthropic.claude-sonnet-4-6 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1000000 | 128000 | In: $3.30, Out: $16.50, Cache Read: $0.33, Cache Write: $4.12 |
| anthropic.claude-3-haiku-20240307-v1:0 | bedrock | In: text, image; Out: text | streaming, function_calling | - | - | - |
| anthropic.claude-3-haiku-20240307-v1:0:200k | bedrock | In: text, image; Out: text | streaming, function_calling | - | - | - |
| anthropic.claude-3-haiku-20240307-v1:0:48k | bedrock | In: text, image; Out: text | streaming, function_calling | - | - | - |
| anthropic.claude-fable-5 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 1000000 | 128000 | In: $10.00, Out: $50.00, Cache Read: $1.00, Cache Write: $12.50 |
| eu.anthropic.claude-fable-5 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 1000000 | 128000 | In: $11.00, Out: $55.00, Cache Read: $1.10, Cache Write: $13.75 |
| global.anthropic.claude-fable-5 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 1000000 | 128000 | In: $10.00, Out: $50.00, Cache Read: $1.00, Cache Write: $12.50 |
| us.anthropic.claude-fable-5 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 1000000 | 128000 | In: $10.00, Out: $50.00, Cache Read: $1.00, Cache Write: $12.50 |
| anthropic.claude-haiku-4-5-20251001-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 200000 | 64000 | In: $1.00, Out: $5.00, Cache Read: $0.10, Cache Write: $1.25 |
| au.anthropic.claude-haiku-4-5-20251001-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 200000 | 64000 | In: $1.00, Out: $5.00, Cache Read: $0.10, Cache Write: $1.25 |
| eu.anthropic.claude-haiku-4-5-20251001-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 200000 | 64000 | In: $1.10, Out: $5.50, Cache Read: $0.11, Cache Write: $1.38 |
| global.anthropic.claude-haiku-4-5-20251001-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 200000 | 64000 | In: $1.00, Out: $5.00, Cache Read: $0.10, Cache Write: $1.25 |
| jp.anthropic.claude-haiku-4-5-20251001-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 200000 | 64000 | In: $1.00, Out: $5.00, Cache Read: $0.10, Cache Write: $1.25 |
| us.anthropic.claude-haiku-4-5-20251001-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 64000 | In: $1.00, Out: $5.00, Cache Read: $0.10, Cache Write: $1.25 |
| anthropic.claude-opus-4-1-20250805-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 200000 | 32000 | In: $15.00, Out: $75.00, Cache Read: $1.50, Cache Write: $18.75 |
| us.anthropic.claude-opus-4-1-20250805-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 32000 | In: $15.00, Out: $75.00, Cache Read: $1.50, Cache Write: $18.75 |
| anthropic.claude-opus-4-5-20251101-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 200000 | 64000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| eu.anthropic.claude-opus-4-5-20251101-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 200000 | 64000 | In: $5.50, Out: $27.50, Cache Read: $0.55, Cache Write: $6.88 |
| global.anthropic.claude-opus-4-5-20251101-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 200000 | 64000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| us.anthropic.claude-opus-4-5-20251101-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 64000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| anthropic.claude-opus-4-6-v1 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| eu.anthropic.claude-opus-4-6-v1 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1000000 | 128000 | In: $5.50, Out: $27.50, Cache Read: $0.55, Cache Write: $6.88 |
| global.anthropic.claude-opus-4-6-v1 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| us.anthropic.claude-opus-4-6-v1 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| anthropic.claude-opus-4-7 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| eu.anthropic.claude-opus-4-7 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 1000000 | 128000 | In: $5.50, Out: $27.50, Cache Read: $0.55, Cache Write: $6.88 |
| global.anthropic.claude-opus-4-7 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| jp.anthropic.claude-opus-4-7 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| us.anthropic.claude-opus-4-7 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming, structured_output | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| anthropic.claude-opus-4-8 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| au.anthropic.claude-opus-4-8 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| eu.anthropic.claude-opus-4-8 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 1000000 | 128000 | In: $5.50, Out: $27.50, Cache Read: $0.55, Cache Write: $6.88 |
| global.anthropic.claude-opus-4-8 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| jp.anthropic.claude-opus-4-8 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| us.anthropic.claude-opus-4-8 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming, structured_output | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| anthropic.claude-opus-5 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| au.anthropic.claude-opus-5 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| eu.anthropic.claude-opus-5 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 1000000 | 128000 | In: $5.50, Out: $27.50, Cache Read: $0.55, Cache Write: $6.88 |
| global.anthropic.claude-opus-5 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| jp.anthropic.claude-opus-5 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| us.anthropic.claude-opus-5 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| us.anthropic.claude-sonnet-4-20250514-v1:0 | bedrock | In: text, image; Out: text | streaming, function_calling, reasoning | 200000 | 65536 | - |
| anthropic.claude-sonnet-4-5-20250929-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 200000 | 64000 | In: $3.00, Out: $15.00, Cache Read: $0.30, Cache Write: $3.75 |
| au.anthropic.claude-sonnet-4-5-20250929-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 200000 | 64000 | In: $3.00, Out: $15.00, Cache Read: $0.30, Cache Write: $3.75 |
| eu.anthropic.claude-sonnet-4-5-20250929-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 200000 | 64000 | In: $3.30, Out: $16.50, Cache Read: $0.33, Cache Write: $4.12 |
| global.anthropic.claude-sonnet-4-5-20250929-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 200000 | 64000 | In: $3.00, Out: $15.00, Cache Read: $0.30, Cache Write: $3.75 |
| jp.anthropic.claude-sonnet-4-5-20250929-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 200000 | 64000 | In: $3.00, Out: $15.00, Cache Read: $0.30, Cache Write: $3.75 |
| us.anthropic.claude-sonnet-4-5-20250929-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 64000 | In: $3.00, Out: $15.00, Cache Read: $0.30, Cache Write: $3.75 |
| anthropic.claude-sonnet-4-6 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1000000 | 64000 | In: $3.00, Out: $15.00, Cache Read: $0.30, Cache Write: $3.75 |
| eu.anthropic.claude-sonnet-4-6 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1000000 | 64000 | In: $3.30, Out: $16.50, Cache Read: $0.33, Cache Write: $4.12 |
| global.anthropic.claude-sonnet-4-6 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1000000 | 64000 | In: $3.00, Out: $15.00, Cache Read: $0.30, Cache Write: $3.75 |
| jp.anthropic.claude-sonnet-4-6 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1000000 | 64000 | In: $3.00, Out: $15.00, Cache Read: $0.30, Cache Write: $3.75 |
| us.anthropic.claude-sonnet-4-6 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 64000 | In: $3.00, Out: $15.00, Cache Read: $0.30, Cache Write: $3.75 |
| anthropic.claude-sonnet-5 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1000000 | 128000 | In: $2.00, Out: $10.00, Cache Read: $0.20, Cache Write: $2.50 |
| au.anthropic.claude-sonnet-5 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1000000 | 128000 | In: $2.00, Out: $10.00, Cache Read: $0.20, Cache Write: $2.50 |
| eu.anthropic.claude-sonnet-5 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1000000 | 128000 | In: $2.20, Out: $11.00, Cache Read: $0.22, Cache Write: $2.75 |
| global.anthropic.claude-sonnet-5 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1000000 | 128000 | In: $2.00, Out: $10.00, Cache Read: $0.20, Cache Write: $2.50 |
| jp.anthropic.claude-sonnet-5 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1000000 | 128000 | In: $2.00, Out: $10.00, Cache Read: $0.20, Cache Write: $2.50 |
| us.anthropic.claude-sonnet-5 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 128000 | In: $2.00, Out: $10.00, Cache Read: $0.20, Cache Write: $2.50 |
| deepseek.r1-v1:0 | bedrock | In: text; Out: text | function_calling, reasoning | 128000 | 32768 | In: $1.35, Out: $5.40 |
| us.deepseek.r1-v1:0 | bedrock | In: text; Out: text | function_calling, reasoning, streaming | 128000 | 32768 | In: $1.35, Out: $5.40 |
| deepseek.v3-v1:0 | bedrock | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 163840 | 81920 | In: $0.58, Out: $1.68 |
| deepseek.v3.2 | bedrock | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 163840 | 81920 | In: $0.62, Out: $1.85 |
| mistral.devstral-2-123b | bedrock | In: text; Out: text | function_calling, structured_output, streaming | 256000 | 8192 | In: $0.40, Out: $2.00 |
| cohere.embed-english-v3 | bedrock | In: text; Out: embeddings | - | - | - | - |
| cohere.embed-english-v3:0:512 | bedrock | In: text; Out: embeddings | - | - | - | - |
| cohere.embed-multilingual-v3 | bedrock | In: text; Out: embeddings | - | - | - | - |
| cohere.embed-multilingual-v3:0:512 | bedrock | In: text; Out: embeddings | - | - | - | - |
| us.cohere.embed-v4:0 | bedrock | In: text, image; Out: embeddings | - | 128000 | - | - |
| zai.glm-4.7 | bedrock | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 204800 | 131072 | In: $0.60, Out: $2.20 |
| zai.glm-4.7-flash | bedrock | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 200000 | 131072 | In: $0.07, Out: $0.40 |
| zai.glm-5 | bedrock | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 202752 | 101376 | In: $1.00, Out: $3.20 |
| openai.gpt-oss-safeguard-120b | bedrock | In: text; Out: text | function_calling, structured_output, streaming | 128000 | 16384 | In: $0.15, Out: $0.60 |
| openai.gpt-oss-safeguard-20b | bedrock | In: text; Out: text | function_calling, structured_output, streaming | 128000 | 16384 | In: $0.07, Out: $0.20 |
| openai.gpt-5.4 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 272000 | 128000 | In: $2.75, Out: $16.50, Cache Read: $0.28 |
| openai.gpt-5.5 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 272000 | 128000 | In: $5.50, Out: $33.00, Cache Read: $0.55 |
| openai.gpt-5.6-luna | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1050000 | 128000 | In: $0.22, Out: $1.32, Cache Read: $0.02, Cache Write: $0.28 |
| us.openai.gpt-5.6-luna | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1050000 | 128000 | In: $0.22, Out: $1.32, Cache Read: $0.02, Cache Write: $0.28 |
| global.openai.gpt-5.6-luna | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1050000 | 128000 | In: $0.22, Out: $1.32, Cache Read: $0.02, Cache Write: $0.28 |
| openai.gpt-5.6-sol | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1050000 | 128000 | In: $5.50, Out: $33.00, Cache Read: $0.55, Cache Write: $6.88 |
| us.openai.gpt-5.6-sol | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1050000 | 128000 | In: $5.50, Out: $33.00, Cache Read: $0.55, Cache Write: $6.88 |
| global.openai.gpt-5.6-sol | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1050000 | 128000 | In: $5.50, Out: $33.00, Cache Read: $0.55, Cache Write: $6.88 |
| openai.gpt-5.6-terra | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1050000 | 128000 | In: $2.20, Out: $13.20, Cache Read: $0.22, Cache Write: $2.75 |
| us.openai.gpt-5.6-terra | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1050000 | 128000 | In: $2.20, Out: $13.20, Cache Read: $0.22, Cache Write: $2.75 |
| global.openai.gpt-5.6-terra | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1050000 | 128000 | In: $2.20, Out: $13.20, Cache Read: $0.22, Cache Write: $2.75 |
| google.gemma-3-4b-it | bedrock | In: text, image; Out: text | function_calling, vision, streaming | 128000 | 4096 | In: $0.04, Out: $0.08 |
| google.gemma-3-12b-it | bedrock | In: text, image; Out: text | structured_output, vision, streaming | 131072 | 8192 | In: $0.05, Out: $0.10 |
| google.gemma-3-27b-it | bedrock | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 202752 | 8192 | In: $0.12, Out: $0.20 |
| xai.grok-4.3 | bedrock | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 131072 | In: $1.25, Out: $2.50, Cache Read: $0.20 |
| us.xai.grok-4.6 | bedrock | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 500000 | 500000 | In: $2.20, Out: $6.60, Cache Read: $0.55 |
| xai.grok-4.6 | bedrock | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 500000 | 500000 | In: $2.20, Out: $6.60, Cache Read: $0.55 |
| moonshot.kimi-k2-thinking | bedrock | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 262143 | 16000 | In: $0.60, Out: $2.50 |
| moonshotai.kimi-k2.5 | bedrock | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 262143 | 16000 | In: $0.60, Out: $3.00 |
| meta.llama3-70b-instruct-v1:0 | bedrock | In: text; Out: text | streaming, function_calling | - | - | - |
| meta.llama3-8b-instruct-v1:0 | bedrock | In: text; Out: text | streaming, function_calling | - | - | - |
| meta.llama3-1-70b-instruct-v1:0 | bedrock | In: text; Out: text | function_calling, streaming | 128000 | 4096 | In: $0.72, Out: $0.72 |
| meta.llama3-1-70b-instruct-v1:0:128k | bedrock | In: text; Out: text | function_calling, streaming | 128000 | 4096 | In: $0.72, Out: $0.72 |
| meta.llama3-1-8b-instruct-v1:0 | bedrock | In: text; Out: text | function_calling, streaming | 128000 | 4096 | In: $0.22, Out: $0.22 |
| meta.llama3-1-8b-instruct-v1:0:128k | bedrock | In: text; Out: text | function_calling, streaming | 128000 | 4096 | In: $0.22, Out: $0.22 |
| meta.llama3-3-70b-instruct-v1:0 | bedrock | In: text; Out: text | function_calling | 128000 | 4096 | In: $0.72, Out: $0.72 |
| meta.llama3-3-70b-instruct-v1:0:128k | bedrock | In: text; Out: text | function_calling, streaming | 128000 | 4096 | In: $0.72, Out: $0.72 |
| us.meta.llama3-3-70b-instruct-v1:0 | bedrock | In: text; Out: text | function_calling, streaming | 128000 | 4096 | In: $0.72, Out: $0.72 |
| meta.llama4-maverick-17b-instruct-v1:0 | bedrock | In: text, image; Out: text | function_calling, vision | 1000000 | 16384 | In: $0.24, Out: $0.97 |
| us.meta.llama4-maverick-17b-instruct-v1:0 | bedrock | In: text, image; Out: text | function_calling, vision, streaming | 1000000 | 16384 | In: $0.24, Out: $0.97 |
| meta.llama4-scout-17b-instruct-v1:0 | bedrock | In: text, image; Out: text | function_calling, vision | 3500000 | 16384 | In: $0.17, Out: $0.66 |
| us.meta.llama4-scout-17b-instruct-v1:0 | bedrock | In: text, image; Out: text | function_calling, vision, streaming | 3500000 | 16384 | In: $0.17, Out: $0.66 |
| mistral.magistral-small-2509 | bedrock | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 128000 | 40000 | In: $0.50, Out: $1.50 |
| minimax.minimax-m2 | bedrock | In: text; Out: text | function_calling, reasoning, streaming | 204608 | 128000 | In: $0.30, Out: $1.20 |
| minimax.minimax-m2.1 | bedrock | In: text; Out: text | function_calling, reasoning, streaming | 204800 | 131072 | In: $0.30, Out: $1.20 |
| minimax.minimax-m2.5 | bedrock | In: text; Out: text | function_calling, reasoning, streaming | 196608 | 98304 | In: $0.30, Out: $1.20 |
| mistral.ministral-3-14b-instruct | bedrock | In: text; Out: text | function_calling, structured_output, streaming | 128000 | 4096 | In: $0.20, Out: $0.20 |
| mistral.ministral-3-3b-instruct | bedrock | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 256000 | 8192 | In: $0.10, Out: $0.10 |
| mistral.ministral-3-8b-instruct | bedrock | In: text; Out: text | function_calling, structured_output, streaming | 128000 | 4096 | In: $0.15, Out: $0.15 |
| mistral.mistral-7b-instruct-v0:2 | bedrock | In: text; Out: text | streaming, function_calling | - | - | - |
| mistral.mistral-large-2402-v1:0 | bedrock | In: text; Out: text | streaming, function_calling | - | - | - |
| mistral.mistral-large-2407-v1:0 | bedrock | In: text; Out: text | streaming, function_calling | - | - | - |
| mistral.mistral-large-3-675b-instruct | bedrock | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 256000 | 8192 | In: $0.50, Out: $1.50 |
| mistral.mixtral-8x7b-instruct-v0:1 | bedrock | In: text; Out: text | streaming, function_calling | - | - | - |
| nvidia.nemotron-super-3-120b | bedrock | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 262144 | 131072 | In: $0.15, Out: $0.65 |
| nvidia.nemotron-nano-12b-v2 | bedrock | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 128000 | 4096 | In: $0.20, Out: $0.60 |
| nvidia.nemotron-nano-3-30b | bedrock | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 128000 | 4096 | In: $0.06, Out: $0.24 |
| nvidia.nemotron-nano-9b-v2 | bedrock | In: text; Out: text | function_calling, structured_output, streaming | 128000 | 4096 | In: $0.06, Out: $0.23 |
| amazon.nova-2-lite-v1:0 | bedrock | In: text, image, video; Out: text | function_calling, reasoning, vision, video | 128000 | 4096 | In: $0.33, Out: $2.75 |
| us.amazon.nova-2-lite-v1:0 | bedrock | In: text, image, video; Out: text | function_calling, reasoning, vision, video, streaming | 128000 | 4096 | In: $0.33, Out: $2.75 |
| amazon.nova-2-sonic-v1:0 | bedrock | In: audio; Out: audio, text | streaming | - | - | - |
| amazon.nova-lite-v1:0 | bedrock | In: text, image, video; Out: text | function_calling, vision, video, streaming | 300000 | 8192 | In: $0.06, Out: $0.24, Cache Read: $0.02 |
| amazon.nova-micro-v1:0 | bedrock | In: text; Out: text | function_calling | 128000 | 8192 | In: $0.04, Out: $0.14, Cache Read: $0.01 |
| us.amazon.nova-micro-v1:0 | bedrock | In: text; Out: text | function_calling, streaming | 128000 | 8192 | In: $0.04, Out: $0.14, Cache Read: $0.01 |
| amazon.nova-premier-v1:0:1000k | bedrock | In: text, image, video; Out: text | streaming, function_calling | - | - | - |
| amazon.nova-premier-v1:0:20k | bedrock | In: text, image, video; Out: text | streaming, function_calling | - | - | - |
| amazon.nova-premier-v1:0:8k | bedrock | In: text, image, video; Out: text | streaming, function_calling | - | - | - |
| amazon.nova-premier-v1:0:mm | bedrock | In: text, image, video; Out: text | streaming, function_calling | - | - | - |
| us.amazon.nova-premier-v1:0 | bedrock | In: text, image, video; Out: text | streaming, function_calling | - | - | - |
| amazon.nova-pro-v1:0 | bedrock | In: text, image, video; Out: text | function_calling, vision, video | 300000 | 8192 | In: $0.80, Out: $3.20, Cache Read: $0.20 |
| us.amazon.nova-pro-v1:0 | bedrock | In: text, image, video; Out: text | function_calling, vision, video, streaming | 300000 | 8192 | In: $0.80, Out: $3.20, Cache Read: $0.20 |
| us.writer.palmyra-x4-v1:0 | bedrock | In: text; Out: text | function_calling, reasoning, streaming | 122880 | 8192 | In: $2.50, Out: $10.00 |
| writer.palmyra-x4-v1:0 | bedrock | In: text; Out: text | function_calling, reasoning | 122880 | 8192 | In: $2.50, Out: $10.00 |
| us.writer.palmyra-x5-v1:0 | bedrock | In: text; Out: text | function_calling, reasoning, streaming | 1040000 | 8192 | In: $0.60, Out: $6.00 |
| writer.palmyra-x5-v1:0 | bedrock | In: text; Out: text | function_calling, reasoning | 1040000 | 8192 | In: $0.60, Out: $6.00 |
| us.twelvelabs.pegasus-1-2-v1:0 | bedrock | In: text, video; Out: text | streaming | - | - | - |
| mistral.pixtral-large-2502-v1:0 | bedrock | In: text, image; Out: text | function_calling, vision | 128000 | 8192 | In: $2.00, Out: $6.00 |
| us.mistral.pixtral-large-2502-v1:0 | bedrock | In: text, image; Out: text | function_calling, vision, streaming | 128000 | 8192 | In: $2.00, Out: $6.00 |
| qwen.qwen3-next-80b-a3b | bedrock | In: text; Out: text | function_calling, structured_output, streaming | 262000 | 262000 | In: $0.14, Out: $1.40 |
| qwen.qwen3-vl-235b-a22b | bedrock | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 262000 | 262000 | In: $0.30, Out: $1.50 |
| qwen.qwen3-235b-a22b-2507-v1:0 | bedrock | In: text; Out: text | function_calling, structured_output, streaming | 262144 | 131072 | In: $0.22, Out: $0.88 |
| qwen.qwen3-32b-v1:0 | bedrock | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 16384 | 16384 | In: $0.15, Out: $0.60 |
| qwen.qwen3-coder-30b-a3b-v1:0 | bedrock | In: text; Out: text | function_calling, structured_output, streaming | 262144 | 131072 | In: $0.15, Out: $0.60 |
| qwen.qwen3-coder-480b-a35b-v1:0 | bedrock | In: text; Out: text | function_calling, structured_output, streaming | 131072 | 65536 | In: $0.22, Out: $1.80 |
| qwen.qwen3-coder-next | bedrock | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 131072 | 65536 | In: $0.22, Out: $1.80 |
| luma.ray-v2:0 | bedrock | In: text; Out: video | - | - | - | - |
| amazon.rerank-v1:0 | bedrock | In: text; Out: text | - | - | - | - |
| cohere.rerank-v3-5:0 | bedrock | In: text; Out: text | - | - | - | - |
| stability.sd3-5-large-v1:0 | bedrock | In: text, image; Out: image | - | - | - | - |
| us.stability.stable-conservative-upscale-v1:0 | bedrock | In: text, image; Out: image | - | - | - | - |
| us.stability.stable-image-control-sketch-v1:0 | bedrock | In: text, image; Out: image | - | - | - | - |
| us.stability.stable-image-control-structure-v1:0 | bedrock | In: text, image; Out: image | - | - | - | - |
| stability.stable-image-core-v1:1 | bedrock | In: text; Out: image | - | - | - | - |
| us.stability.stable-creative-upscale-v1:0 | bedrock | In: text, image; Out: image | - | - | - | - |
| us.stability.stable-image-erase-object-v1:0 | bedrock | In: text, image; Out: image | - | - | - | - |
| us.stability.stable-fast-upscale-v1:0 | bedrock | In: text, image; Out: image | - | - | - | - |
| us.stability.stable-image-inpaint-v1:0 | bedrock | In: text, image; Out: image | - | - | - | - |
| us.stability.stable-outpaint-v1:0 | bedrock | In: text, image; Out: image | - | - | - | - |
| us.stability.stable-image-remove-background-v1:0 | bedrock | In: text, image; Out: image | - | - | - | - |
| us.stability.stable-image-search-recolor-v1:0 | bedrock | In: text, image; Out: image | - | - | - | - |
| us.stability.stable-image-search-replace-v1:0 | bedrock | In: text, image; Out: image | - | - | - | - |
| us.stability.stable-image-style-guide-v1:0 | bedrock | In: text, image; Out: image | - | - | - | - |
| us.stability.stable-style-transfer-v1:0 | bedrock | In: text, image; Out: image | - | - | - | - |
| stability.stable-image-ultra-v1:1 | bedrock | In: text; Out: image | - | - | - | - |
| amazon.titan-embed-text-v1 | bedrock | In: text; Out: embeddings | - | - | - | - |
| amazon.titan-embed-text-v1:2:8k | bedrock | In: text; Out: embeddings | - | - | - | - |
| amazon.titan-embed-image-v1 | bedrock | In: text, image; Out: embeddings | - | - | - | - |
| amazon.titan-embed-image-v1:0 | bedrock | In: text, image; Out: embeddings | - | - | - | - |
| amazon.titan-embed-text-v2:0 | bedrock | In: text; Out: embeddings | - | - | - | - |
| amazon.titan-embed-g1-text-02 | bedrock | In: text; Out: embeddings | - | - | - | - |
| mistral.voxtral-mini-3b-2507 | bedrock | In: audio, text; Out: text | function_calling, structured_output, streaming | 128000 | 4096 | In: $0.04, Out: $0.04 |
| mistral.voxtral-small-24b-2507 | bedrock | In: text, audio; Out: text | function_calling, structured_output, streaming | 32000 | 8192 | In: $0.15, Out: $0.35 |
| writer.palmyra-vision-7b | bedrock | In: text, image; Out: text | streaming, function_calling | - | 4096 | - |
| anthropic.claude-haiku-4-5 | bedrock | In: text; Out: text | streaming | - | - | - |
| deepseek.v3.1 | bedrock | In: text; Out: text | streaming | - | - | - |
| google.gemma-4-26b-a4b | bedrock | In: text; Out: text | streaming | - | - | - |
| google.gemma-4-31b | bedrock | In: text; Out: text | streaming | - | - | - |
| google.gemma-4-e2b | bedrock | In: text; Out: text | streaming | - | - | - |
| openai.gpt-oss-120b | bedrock | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 128000 | 16384 | In: $0.15, Out: $0.60 |
| openai.gpt-oss-120b-1:0 | bedrock | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 128000 | 16384 | In: $0.15, Out: $0.60 |
| openai.gpt-oss-20b | bedrock | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 128000 | 16384 | In: $0.07, Out: $0.30 |
| openai.gpt-oss-20b-1:0 | bedrock | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 128000 | 16384 | In: $0.07, Out: $0.30 |
| moonshotai.kimi-k2-thinking | bedrock | In: text; Out: text | streaming | - | - | - |
| openai.gpt-5.4-2026-03-05 | bedrock | In: text; Out: text | streaming | - | - | - |
| qwen.qwen3-235b-a22b-2507 | bedrock | In: text; Out: text | streaming | - | - | - |
| qwen.qwen3-32b | bedrock | In: text; Out: text | streaming | - | - | - |
| qwen.qwen3-coder-30b-a3b-instruct | bedrock | In: text; Out: text | streaming | - | - | - |
| qwen.qwen3-coder-480b-a35b-instruct | bedrock | In: text; Out: text | streaming | - | - | - |
| qwen.qwen3-next-80b-a3b-instruct | bedrock | In: text; Out: text | streaming | - | - | - |
| qwen.qwen3-vl-235b-a22b-instruct | bedrock | In: text; Out: text | streaming | - | - | - |
| zai.glm-4.6 | bedrock | In: text; Out: text | streaming | - | - | - |


### Cohere (33)

| Model | Provider | I/O | Capabilities | Context | Max Output | Standard Pricing (per 1M tokens) |
| :-- | :-- | :-- | :-- | --: | --: | :-- |
| c4ai-aya-expanse-32b | cohere | In: text; Out: text | streaming | 128000 | 4000 | In: $0.50, Out: $1.50 |
| c4ai-aya-expanse-8b | cohere | In: text; Out: text | - | 8000 | 4000 | - |
| c4ai-aya-vision-32b | cohere | In: text, image; Out: text | vision, streaming | 16000 | 4000 | In: $0.50, Out: $1.50 |
| c4ai-aya-vision-8b | cohere | In: text, image; Out: text | vision | 16000 | 4000 | - |
| cohere-transcribe-03-2026 | cohere | In: audio; Out: text | transcription | 32768 | - | - |
| command-a-03-2025 | cohere | In: text; Out: text | function_calling, streaming, structured_output, citations, tool_choice | 256000 | 8000 | In: $2.50, Out: $10.00 |
| command-a-plus-05-2026 | cohere | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming, citations | 128000 | 64000 | In: $2.50, Out: $10.00 |
| command-a-reasoning-08-2025 | cohere | In: text; Out: text | function_calling, reasoning, streaming, structured_output, citations | 256000 | 32000 | In: $2.50, Out: $10.00 |
| command-a-translate-08-2025 | cohere | In: text; Out: text | function_calling, streaming | 8000 | 8000 | In: $2.50, Out: $10.00 |
| command-a-vision-07-2025 | cohere | In: text, image; Out: text | vision, streaming | 128000 | 8000 | In: $2.50, Out: $10.00 |
| command-r-08-2024 | cohere | In: text; Out: text | function_calling, streaming, structured_output, citations, tool_choice | 128000 | 4000 | In: $0.15, Out: $0.60 |
| command-r-plus-08-2024 | cohere | In: text; Out: text | function_calling, streaming, structured_output, citations, tool_choice | 128000 | 4000 | In: $2.50, Out: $10.00 |
| command-r7b-12-2024 | cohere | In: text; Out: text | function_calling, streaming, structured_output, citations, tool_choice | 128000 | 4000 | In: $0.04, Out: $0.15 |
| command-r7b-arabic-02-2025 | cohere | In: text; Out: text | function_calling, streaming, structured_output, citations | 128000 | 4000 | In: $0.04, Out: $0.15 |
| embed-english-light-v3.0 | cohere | In: text, image; Out: embeddings | - | 512 | - | - |
| embed-english-light-v3.0-image | cohere | In: text, image; Out: embeddings | - | 0 | - | - |
| embed-english-v3.0 | cohere | In: text, image; Out: embeddings | - | 512 | - | - |
| embed-english-v3.0-image | cohere | In: text, image; Out: embeddings | - | 0 | - | - |
| embed-multilingual-light-v3.0 | cohere | In: text, image; Out: embeddings | - | 512 | - | - |
| embed-multilingual-light-v3.0-image | cohere | In: text, image; Out: embeddings | - | 0 | - | - |
| embed-multilingual-v3.0 | cohere | In: text, image; Out: embeddings | - | 512 | - | - |
| embed-multilingual-v3.0-image | cohere | In: text, image; Out: embeddings | - | 0 | - | - |
| embed-v4.0 | cohere | In: text, image; Out: embeddings | - | 8192 | - | - |
| north-mini-code-1-0 | cohere | In: text; Out: text | function_calling, structured_output, reasoning, streaming, citations | 256000 | 64000 | In: $0.00, Out: $0.00 |
| rerank-english-v3.0 | cohere | In: text; Out: rerank | - | 4096 | - | - |
| rerank-multilingual-v3.0 | cohere | In: text; Out: rerank | - | 4096 | - | - |
| rerank-v3.5 | cohere | In: text; Out: rerank | - | 4096 | - | - |
| rerank-v4.0-fast | cohere | In: text; Out: rerank | - | 32768 | - | - |
| rerank-v4.0-pro | cohere | In: text; Out: rerank | - | 32768 | - | - |
| tiny-aya-earth | cohere | In: text; Out: text | streaming | 8192 | 4000 | - |
| tiny-aya-fire | cohere | In: text; Out: text | streaming | 8192 | 4000 | - |
| tiny-aya-global | cohere | In: text; Out: text | streaming | 8192 | 4000 | - |
| tiny-aya-water | cohere | In: text; Out: text | streaming | 8192 | 4000 | - |


### Deepgram (143)

| Model | Provider | I/O | Capabilities | Context | Max Output | Standard Pricing (per 1M tokens) |
| :-- | :-- | :-- | :-- | --: | --: | :-- |
| aura-2-agathe-fr | deepgram | In: text; Out: audio | - | - | - | - |
| aura-2-agustina-es | deepgram | In: text; Out: audio | - | - | - | - |
| aura-2-alvaro-es | deepgram | In: text; Out: audio | - | - | - | - |
| aura-2-ama-ja | deepgram | In: text; Out: audio | - | - | - | - |
| aura-2-amalthea-en | deepgram | In: text; Out: audio | - | - | - | - |
| aura-2-andromeda-en | deepgram | In: text; Out: audio | - | - | - | - |
| aura-2-antonia-es | deepgram | In: text; Out: audio | - | - | - | - |
| aura-2-apollo-en | deepgram | In: text; Out: audio | - | - | - | - |
| aura-2-aquila-es | deepgram | In: text; Out: audio | - | - | - | - |
| aura-2-arcas-en | deepgram | In: text; Out: audio | - | - | - | - |
| aura-2-aries-en | deepgram | In: text; Out: audio | - | - | - | - |
| aura-2-asteria-en | deepgram | In: text; Out: audio | - | - | - | - |
| aura-2-athena-en | deepgram | In: text; Out: audio | - | - | - | - |
| aura-2-atlas-en | deepgram | In: text; Out: audio | - | - | - | - |
| aura-2-aurelia-de | deepgram | In: text; Out: audio | - | - | - | - |
| aura-2-aurora-en | deepgram | In: text; Out: audio | - | - | - | - |
| aura-2-beatrix-nl | deepgram | In: text; Out: audio | - | - | - | - |
| aura-2-callista-en | deepgram | In: text; Out: audio | - | - | - | - |
| aura-2-carina-es | deepgram | In: text; Out: audio | - | - | - | - |
| aura-2-celeste-es | deepgram | In: text; Out: audio | - | - | - | - |
| aura-2-cesare-it | deepgram | In: text; Out: audio | - | - | - | - |
| aura-2-cinzia-it | deepgram | In: text; Out: audio | - | - | - | - |
| aura-2-cora-en | deepgram | In: text; Out: audio | - | - | - | - |
| aura-2-cordelia-en | deepgram | In: text; Out: audio | - | - | - | - |
| aura-2-cornelia-nl | deepgram | In: text; Out: audio | - | - | - | - |
| aura-2-daphne-nl | deepgram | In: text; Out: audio | - | - | - | - |
| aura-2-delia-en | deepgram | In: text; Out: audio | - | - | - | - |
| aura-2-demetra-it | deepgram | In: text; Out: audio | - | - | - | - |
| aura-2-diana-es | deepgram | In: text; Out: audio | - | - | - | - |
| aura-2-dionisio-it | deepgram | In: text; Out: audio | - | - | - | - |
| aura-2-draco-en | deepgram | In: text; Out: audio | - | - | - | - |
| aura-2-ebisu-ja | deepgram | In: text; Out: audio | - | - | - | - |
| aura-2-elara-de | deepgram | In: text; Out: audio | - | - | - | - |
| aura-2-electra-en | deepgram | In: text; Out: audio | - | - | - | - |
| aura-2-elio-it | deepgram | In: text; Out: audio | - | - | - | - |
| aura-2-estrella-es | deepgram | In: text; Out: audio | - | - | - | - |
| aura-2-fabian-de | deepgram | In: text; Out: audio | - | - | - | - |
| aura-2-flavio-it | deepgram | In: text; Out: audio | - | - | - | - |
| aura-2-fujin-ja | deepgram | In: text; Out: audio | - | - | - | - |
| aura-2-gloria-es | deepgram | In: text; Out: audio | - | - | - | - |
| aura-2-harmonia-en | deepgram | In: text; Out: audio | - | - | - | - |
| aura-2-hector-fr | deepgram | In: text; Out: audio | - | - | - | - |
| aura-2-helena-en | deepgram | In: text; Out: audio | - | - | - | - |
| aura-2-hera-en | deepgram | In: text; Out: audio | - | - | - | - |
| aura-2-hermes-en | deepgram | In: text; Out: audio | - | - | - | - |
| aura-2-hestia-nl | deepgram | In: text; Out: audio | - | - | - | - |
| aura-2-hyperion-en | deepgram | In: text; Out: audio | - | - | - | - |
| aura-2-iris-en | deepgram | In: text; Out: audio | - | - | - | - |
| aura-2-izanami-ja | deepgram | In: text; Out: audio | - | - | - | - |
| aura-2-janus-en | deepgram | In: text; Out: audio | - | - | - | - |
| aura-2-javier-es | deepgram | In: text; Out: audio | - | - | - | - |
| aura-2-julius-de | deepgram | In: text; Out: audio | - | - | - | - |
| aura-2-juno-en | deepgram | In: text; Out: audio | - | - | - | - |
| aura-2-jupiter-en | deepgram | In: text; Out: audio | - | - | - | - |
| aura-2-kara-de | deepgram | In: text; Out: audio | - | - | - | - |
| aura-2-lara-de | deepgram | In: text; Out: audio | - | - | - | - |
| aura-2-lars-nl | deepgram | In: text; Out: audio | - | - | - | - |
| aura-2-leda-nl | deepgram | In: text; Out: audio | - | - | - | - |
| aura-2-livia-it | deepgram | In: text; Out: audio | - | - | - | - |
| aura-2-luciano-es | deepgram | In: text; Out: audio | - | - | - | - |
| aura-2-luna-en | deepgram | In: text; Out: audio | - | - | - | - |
| aura-2-maia-it | deepgram | In: text; Out: audio | - | - | - | - |
| aura-2-mars-en | deepgram | In: text; Out: audio | - | - | - | - |
| aura-2-melia-it | deepgram | In: text; Out: audio | - | - | - | - |
| aura-2-minerva-en | deepgram | In: text; Out: audio | - | - | - | - |
| aura-2-neptune-en | deepgram | In: text; Out: audio | - | - | - | - |
| aura-2-nestor-es | deepgram | In: text; Out: audio | - | - | - | - |
| aura-2-odysseus-en | deepgram | In: text; Out: audio | - | - | - | - |
| aura-2-olivia-es | deepgram | In: text; Out: audio | - | - | - | - |
| aura-2-ophelia-en | deepgram | In: text; Out: audio | - | - | - | - |
| aura-2-orion-en | deepgram | In: text; Out: audio | - | - | - | - |
| aura-2-orpheus-en | deepgram | In: text; Out: audio | - | - | - | - |
| aura-2-pandora-en | deepgram | In: text; Out: audio | - | - | - | - |
| aura-2-phoebe-en | deepgram | In: text; Out: audio | - | - | - | - |
| aura-2-pluto-en | deepgram | In: text; Out: audio | - | - | - | - |
| aura-2-rhea-nl | deepgram | In: text; Out: audio | - | - | - | - |
| aura-2-roman-nl | deepgram | In: text; Out: audio | - | - | - | - |
| aura-2-sander-nl | deepgram | In: text; Out: audio | - | - | - | - |
| aura-2-saturn-en | deepgram | In: text; Out: audio | - | - | - | - |
| aura-2-selena-es | deepgram | In: text; Out: audio | - | - | - | - |
| aura-2-selene-en | deepgram | In: text; Out: audio | - | - | - | - |
| aura-2-silvia-es | deepgram | In: text; Out: audio | - | - | - | - |
| aura-2-sirio-es | deepgram | In: text; Out: audio | - | - | - | - |
| aura-2-thalia-en | deepgram | In: text; Out: audio | - | - | - | - |
| aura-2-theia-en | deepgram | In: text; Out: audio | - | - | - | - |
| aura-2-uzume-ja | deepgram | In: text; Out: audio | - | - | - | - |
| aura-2-valerio-es | deepgram | In: text; Out: audio | - | - | - | - |
| aura-2-vesta-en | deepgram | In: text; Out: audio | - | - | - | - |
| aura-2-viktoria-de | deepgram | In: text; Out: audio | - | - | - | - |
| aura-2-zeus-en | deepgram | In: text; Out: audio | - | - | - | - |
| aura-angus-en | deepgram | In: text; Out: audio | - | - | - | - |
| aura-arcas-en | deepgram | In: text; Out: audio | - | - | - | - |
| aura-asteria-en | deepgram | In: text; Out: audio | - | - | - | - |
| aura-athena-en | deepgram | In: text; Out: audio | - | - | - | - |
| aura-helios-en | deepgram | In: text; Out: audio | - | - | - | - |
| aura-hera-en | deepgram | In: text; Out: audio | - | - | - | - |
| aura-luna-en | deepgram | In: text; Out: audio | - | - | - | - |
| aura-orion-en | deepgram | In: text; Out: audio | - | - | - | - |
| aura-orpheus-en | deepgram | In: text; Out: audio | - | - | - | - |
| aura-perseus-en | deepgram | In: text; Out: audio | - | - | - | - |
| aura-stella-en | deepgram | In: text; Out: audio | - | - | - | - |
| aura-zeus-en | deepgram | In: text; Out: audio | - | - | - | - |
| conversationalai | deepgram | In: text; Out: audio | - | - | - | - |
| enhanced-automotive | deepgram | In: audio; Out: text | transcription | - | - | - |
| enhanced-drivethru | deepgram | In: audio; Out: text | transcription | - | - | - |
| enhanced-finance | deepgram | In: audio; Out: text | transcription | - | - | - |
| enhanced-general | deepgram | In: audio; Out: text | transcription | - | - | - |
| enhanced-meeting | deepgram | In: audio; Out: text | transcription | - | - | - |
| enhanced-phonecall | deepgram | In: audio; Out: text | transcription | - | - | - |
| finance | deepgram | In: text; Out: audio | - | - | - | - |
| general | deepgram | In: text; Out: audio | - | - | - | - |
| general-dQw4w9WgXcQ | deepgram | In: text; Out: audio | - | - | - | - |
| general-polaris | deepgram | In: text; Out: audio | - | - | - | - |
| meeting | deepgram | In: text; Out: audio | - | - | - | - |
| nova-2-atc | deepgram | In: audio; Out: text | transcription | - | - | - |
| nova-2-automotive | deepgram | In: audio; Out: text | transcription | - | - | - |
| nova-2-conversationalai | deepgram | In: audio; Out: text | transcription | - | - | - |
| nova-2-drivethru | deepgram | In: audio; Out: text | transcription | - | - | - |
| nova-2-ea | deepgram | In: audio; Out: text | transcription | - | - | - |
| nova-2-finance | deepgram | In: audio; Out: text | transcription | - | - | - |
| nova-2-general | deepgram | In: audio; Out: text | transcription | - | - | - |
| nova-2-medical | deepgram | In: audio; Out: text | transcription | - | - | - |
| nova-2-meeting | deepgram | In: audio; Out: text | transcription | - | - | - |
| nova-2-phonecall | deepgram | In: audio; Out: text | transcription | - | - | - |
| nova-2-video | deepgram | In: audio; Out: text | transcription | - | - | - |
| nova-2-voicemail | deepgram | In: audio; Out: text | transcription | - | - | - |
| nova-3-general | deepgram | In: audio; Out: text | transcription | - | - | - |
| nova-3-medical | deepgram | In: audio; Out: text | transcription | - | - | - |
| nova-drivethru | deepgram | In: audio; Out: text | transcription | - | - | - |
| nova-general | deepgram | In: audio; Out: text | transcription | - | - | - |
| nova-medical | deepgram | In: audio; Out: text | transcription | - | - | - |
| nova-phonecall | deepgram | In: audio; Out: text | transcription | - | - | - |
| nova-voicemail | deepgram | In: audio; Out: text | transcription | - | - | - |
| phonecall | deepgram | In: text; Out: audio | - | - | - | - |
| phonecall-dQw4w9WgXcQ | deepgram | In: text; Out: audio | - | - | - | - |
| phoneme | deepgram | In: text; Out: audio | - | - | - | - |
| video | deepgram | In: text; Out: audio | - | - | - | - |
| voicemail | deepgram | In: text; Out: audio | - | - | - | - |
| whisper-base | deepgram | In: audio; Out: text | transcription | - | - | - |
| whisper-large | deepgram | In: audio; Out: text | transcription | - | - | - |
| whisper-medium | deepgram | In: audio; Out: text | transcription | - | - | - |
| whisper-small | deepgram | In: audio; Out: text | transcription | - | - | - |
| whisper-tiny | deepgram | In: audio; Out: text | transcription | - | - | - |


### DeepSeek (4)

| Model | Provider | I/O | Capabilities | Context | Max Output | Standard Pricing (per 1M tokens) |
| :-- | :-- | :-- | :-- | --: | --: | :-- |
| deepseek-chat | deepseek | In: text; Out: text | function_calling | 1000000 | 384000 | In: $0.14, Out: $0.28, Cache Read: $0.00 |
| deepseek-reasoner | deepseek | In: text; Out: text | function_calling, reasoning | 1000000 | 384000 | In: $0.14, Out: $0.28, Cache Read: $0.00 |
| deepseek-v4-flash | deepseek | In: text; Out: text | function_calling, structured_output, reasoning, tool_choice | 1000000 | 384000 | In: $0.14, Out: $0.28, Cache Read: $0.00 |
| deepseek-v4-pro | deepseek | In: text; Out: text | function_calling, structured_output, reasoning, tool_choice | 1000000 | 384000 | In: $0.44, Out: $0.87, Cache Read: $0.00 |


### ElevenLabs (10)

| Model | Provider | I/O | Capabilities | Context | Max Output | Standard Pricing (per 1M tokens) |
| :-- | :-- | :-- | :-- | --: | --: | :-- |
| eleven_english_sts_v2 | elevenlabs | In: audio; Out: audio | - | - | - | - |
| eleven_flash_v2 | elevenlabs | In: text; Out: audio | - | - | - | - |
| eleven_flash_v2_5 | elevenlabs | In: text; Out: audio | - | - | - | - |
| eleven_multilingual_sts_v2 | elevenlabs | In: audio; Out: audio | - | - | - | - |
| eleven_multilingual_v2 | elevenlabs | In: text; Out: audio | - | - | - | - |
| eleven_turbo_v2 | elevenlabs | In: text; Out: audio | - | - | - | - |
| eleven_turbo_v2_5 | elevenlabs | In: text; Out: audio | - | - | - | - |
| eleven_v3 | elevenlabs | In: text; Out: audio | - | - | - | - |
| eleven_v3_conversational | elevenlabs | In: text; Out: audio | - | - | - | - |
| scribe_v2 | elevenlabs | In: audio; Out: text | transcription | - | - | - |


### Gemini (50)

| Model | Provider | I/O | Capabilities | Context | Max Output | Standard Pricing (per 1M tokens) |
| :-- | :-- | :-- | :-- | --: | --: | :-- |
| antigravity-preview-05-2026 | gemini | In: -; Out: - | - | 131072 | 65536 | In: $0.08, Out: $0.30 |
| deep-research-max-preview-04-2026 | gemini | In: text, image, video, audio, pdf; Out: text, image | function_calling, reasoning, vision, video, transcription | 131072 | 65536 | In: $2.00, Out: $12.00, Cache Read: $0.20 |
| deep-research-preview-04-2026 | gemini | In: text, image, video, audio, pdf; Out: text, image | function_calling, reasoning, vision, video, transcription | 131072 | 65536 | In: $2.00, Out: $12.00, Cache Read: $0.20 |
| deep-research-pro-preview-12-2025 | gemini | In: -; Out: - | function_calling, tool_choice, structured_output, vision | 131072 | 65536 | In: $0.08, Out: $0.30 |
| gemini-2.5-computer-use-preview-10-2025 | gemini | In: text, image; Out: text | function_calling, reasoning, vision, tool_choice, structured_output | 131072 | 65536 | In: $1.25, Out: $10.00 |
| gemini-2.5-flash | gemini | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription, tool_choice | 1048576 | 65536 | In: $0.30, Out: $2.50, Cache Read: $0.03 |
| gemini-2.5-flash-native-audio-latest | gemini | In: -; Out: - | function_calling, tool_choice, structured_output, vision | 131072 | 8192 | In: $0.08, Out: $0.30 |
| gemini-2.5-flash-native-audio-preview-09-2025 | gemini | In: -; Out: - | function_calling, tool_choice, structured_output, vision | 131072 | 8192 | In: $0.08, Out: $0.30 |
| gemini-2.5-flash-native-audio-preview-12-2025 | gemini | In: -; Out: - | function_calling, tool_choice, structured_output, vision | 131072 | 8192 | In: $0.08, Out: $0.30 |
| gemini-2.5-flash-preview-tts | gemini | In: text; Out: audio | tool_choice, structured_output | 8192 | 16384 | In: $0.50, Out: $10.00 |
| gemini-2.5-flash-lite | gemini | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription | 1048576 | 65536 | In: $0.10, Out: $0.40, Cache Read: $0.01 |
| gemini-2.5-pro | gemini | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription, tool_choice | 1048576 | 65536 | In: $1.25, Out: $10.00, Cache Read: $0.12 |
| gemini-2.5-pro-preview-tts | gemini | In: text; Out: audio | tool_choice, structured_output | 8192 | 16384 | In: $1.00, Out: $20.00 |
| gemini-3-flash-preview | gemini | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription, tool_choice | 1048576 | 65536 | In: $0.50, Out: $3.00, Cache Read: $0.05 |
| gemini-3.1-flash-lite | gemini | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription | 1048576 | 65536 | In: $0.25, Out: $1.50, Cache Read: $0.02 |
| gemini-3.1-flash-lite-preview | gemini | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription | 1048576 | 65536 | In: $0.25, Out: $1.50, Cache Read: $0.02 |
| gemini-3.1-flash-live-preview | gemini | In: text, image, video, audio; Out: text, audio | function_calling, reasoning, vision, video, transcription, tool_choice | 131072 | 65536 | In: $0.75, Out: $4.50 |
| gemini-3.1-flash-tts-preview | gemini | In: text; Out: audio | reasoning, tool_choice, structured_output | 8192 | 16384 | In: $1.00, Out: $20.00 |
| gemini-3.1-pro-preview | gemini | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription, tool_choice | 1048576 | 65536 | In: $2.00, Out: $12.00, Cache Read: $0.20 |
| gemini-3.1-pro-preview-customtools | gemini | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription, tool_choice | 1048576 | 65536 | In: $2.00, Out: $12.00, Cache Read: $0.20 |
| gemini-3.5-flash | gemini | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription, tool_choice | 1048576 | 65536 | In: $1.50, Out: $9.00, Cache Read: $0.15 |
| gemini-3.5-flash-lite | gemini | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription | 1048576 | 65536 | In: $0.30, Out: $2.50, Cache Read: $0.03 |
| gemini-3.5-live-translate-preview | gemini | In: audio; Out: audio, text | transcription, tool_choice, structured_output | 16384 | 32768 | In: $3.50, Out: $21.00 |
| gemini-3.6-flash | gemini | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription, tool_choice | 1048576 | 65536 | In: $1.50, Out: $7.50, Cache Read: $0.15 |
| gemini-3.7-flash | gemini | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription, tool_choice | 1048576 | 65536 | In: $0.75, Out: $3.75, Cache Read: $0.08 |
| gemini-embedding-001 | gemini | In: text; Out: embeddings | - | 2048 | 1 | In: $0.15, Out: $0.00 |
| gemini-embedding-2 | gemini | In: text, image, audio, video, pdf; Out: embeddings | vision, video, tool_choice, structured_output | 8192 | 1 | In: $0.20, Out: $0.00 |
| gemini-embedding-2-preview | gemini | In: -; Out: - | function_calling, tool_choice, structured_output, vision | 8192 | 1 | In: $0.00, Out: $0.00 |
| gemini-flash-latest | gemini | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription, tool_choice | 1048576 | 65536 | In: $1.50, Out: $9.00, Cache Read: $0.15 |
| gemini-flash-lite-latest | gemini | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription | 1048576 | 65536 | In: $0.25, Out: $1.50, Cache Read: $0.02 |
| gemini-omni-flash-preview | gemini | In: text, image, video; Out: video | reasoning, vision, video, tool_choice, structured_output | 131072 | 65536 | In: $1.50, Out: $17.50 |
| gemini-pro-latest | gemini | In: -; Out: - | function_calling, tool_choice, structured_output, vision | 1048576 | 65536 | In: $0.08, Out: $0.30 |
| gemini-robotics-er-1.6-preview | gemini | In: text, image, video, audio; Out: text | function_calling, structured_output, reasoning, vision, video, transcription, tool_choice | 131072 | 65536 | In: $1.00, Out: $5.00 |
| gemini-robotics-er-2-preview | gemini | In: -; Out: - | function_calling, tool_choice, structured_output, vision | 131072 | 65536 | In: $0.08, Out: $0.30 |
| gemini-robotics-er-2-streaming-preview | gemini | In: -; Out: - | function_calling, tool_choice, structured_output, vision | 131072 | 65536 | In: $0.08, Out: $0.30 |
| gemma-4-26b-a4b-it | gemini | In: text, image; Out: text | function_calling, structured_output, reasoning, vision | 262144 | 32768 | In: $0.08, Out: $0.30 |
| gemma-4-31b-it | gemini | In: text, image; Out: text | function_calling, structured_output, reasoning, vision | 262144 | 32768 | In: $0.08, Out: $0.30 |
| lyria-3-clip-preview | gemini | In: text, image; Out: text, audio | vision | 1048576 | 65536 | In: $0.00, Out: $0.00 |
| lyria-3-pro-preview | gemini | In: text, image; Out: text, audio | vision, tool_choice | 1048576 | 65536 | In: $0.00, Out: $0.00 |
| aqa | gemini | In: -; Out: - | - | 7168 | 1024 | In: $0.00, Out: $0.00 |
| gemini-2.5-flash-image | gemini | In: text, image; Out: text, image | reasoning, vision, tool_choice, structured_output | 32768 | 32768 | In: $0.30, Out: $30.00, Cache Read: $0.08 |
| gemini-3.1-flash-image | gemini | In: text, image, video, pdf; Out: text, image | reasoning, vision, video, tool_choice, structured_output | 65536 | 65536 | In: $0.50, Out: $60.00 |
| gemini-3.1-flash-image-preview | gemini | In: text, image, pdf; Out: text, image | reasoning, vision, tool_choice, structured_output | 65536 | 65536 | In: $0.50, Out: $60.00 |
| gemini-3.1-flash-lite-image | gemini | In: text, image; Out: text, image | function_calling, reasoning, vision | 65536 | 65536 | In: $0.25, Out: $30.00 |
| gemini-3-pro-image | gemini | In: text, image; Out: text, image | reasoning, vision, tool_choice, structured_output | 131072 | 32768 | In: $2.00, Out: $120.00 |
| gemini-3-pro-image-preview | gemini | In: text, image; Out: text, image | reasoning, vision, tool_choice, structured_output | 131072 | 32768 | In: $2.00, Out: $120.00 |
| nano-banana-pro-preview | gemini | In: -; Out: - | function_calling, tool_choice, structured_output, vision | 131072 | 32768 | In: $0.08, Out: $0.30 |
| veo-3.1-generate-preview | gemini | In: text, image; Out: video | vision | 480 | 8192 | In: $0.08, Out: $0.30 |
| veo-3.1-fast-generate-preview | gemini | In: text, image, video; Out: video | vision, video | 480 | 8192 | In: $0.08, Out: $0.30 |
| veo-3.1-lite-generate-preview | gemini | In: text, image; Out: video | vision | 480 | 8192 | In: $0.08, Out: $0.30 |


### Mistral (70)

| Model | Provider | I/O | Capabilities | Context | Max Output | Standard Pricing (per 1M tokens) |
| :-- | :-- | :-- | :-- | --: | --: | :-- |
| codestral-2508 | mistral | In: text; Out: text | streaming, function_calling, tool_choice, parallel_tool_calls, structured_output, batch, predicted_outputs | 256000 | 8192 | - |
| codestral-embed | mistral | In: text; Out: embeddings | predicted_outputs | 8192 | 8192 | - |
| codestral-embed-2505 | mistral | In: text; Out: embeddings | predicted_outputs | 8192 | 8192 | - |
| codestral-latest | mistral | In: text; Out: text | function_calling, streaming, tool_choice, parallel_tool_calls, structured_output, batch, predicted_outputs | 256000 | 4096 | In: $0.30, Out: $0.90 |
| devstral-2512 | mistral | In: text; Out: text | function_calling, streaming, tool_choice, parallel_tool_calls, structured_output, batch | 262144 | 262144 | In: $0.40, Out: $2.00 |
| devstral-latest | mistral | In: text; Out: text | function_calling, streaming, tool_choice, parallel_tool_calls, structured_output, batch | 262144 | 262144 | In: $0.40, Out: $2.00 |
| devstral-medium-latest | mistral | In: text; Out: text | function_calling, streaming, tool_choice, parallel_tool_calls, structured_output, batch | 262144 | 262144 | In: $0.40, Out: $2.00 |
| devstral-medium-2507 | mistral | In: text; Out: text | function_calling | 128000 | 128000 | In: $0.40, Out: $2.00 |
| devstral-small-2507 | mistral | In: text; Out: text | function_calling | 128000 | 128000 | In: $0.10, Out: $0.30 |
| labs-devstral-small-2512 | mistral | In: text, image; Out: text | function_calling, vision | 256000 | 256000 | In: $0.00, Out: $0.00 |
| devstral-small-2505 | mistral | In: text; Out: text | function_calling | 128000 | 128000 | In: $0.10, Out: $0.30 |
| glm-5-2 | mistral | In: text; Out: text | streaming, function_calling, tool_choice, parallel_tool_calls, structured_output, batch, reasoning | 1048576 | 8192 | - |
| labs-leanstral-1-5 | mistral | In: text, image; Out: text | streaming, function_calling, tool_choice, parallel_tool_calls, structured_output, batch, reasoning, vision | 262144 | 8192 | - |
| labs-leanstral-1-5-1 | mistral | In: text, image; Out: text | streaming, function_calling, tool_choice, parallel_tool_calls, structured_output, batch, reasoning, vision | 262144 | 8192 | - |
| magistral-medium-latest | mistral | In: text; Out: text | function_calling, reasoning, streaming, tool_choice, parallel_tool_calls, structured_output, batch | 128000 | 16384 | In: $2.00, Out: $5.00 |
| magistral-small | mistral | In: text; Out: text | function_calling, reasoning | 128000 | 128000 | In: $0.50, Out: $1.50 |
| magistral-small-latest | mistral | In: text, image; Out: text | streaming, function_calling, tool_choice, parallel_tool_calls, structured_output, reasoning, batch, vision | 262144 | 8192 | - |
| ministral-14b-2512 | mistral | In: text, image; Out: text | streaming, function_calling, tool_choice, parallel_tool_calls, structured_output, batch, distillation, fine_tuning, vision | 262144 | 8192 | - |
| ministral-14b-latest | mistral | In: text, image; Out: text | streaming, function_calling, tool_choice, parallel_tool_calls, structured_output, batch, distillation, fine_tuning, vision | 262144 | 8192 | - |
| ministral-3b-2512 | mistral | In: text, image; Out: text | streaming, function_calling, tool_choice, parallel_tool_calls, structured_output, batch, distillation, fine_tuning, vision | 131072 | 8192 | - |
| ministral-3b-latest | mistral | In: text; Out: text | function_calling, streaming, tool_choice, parallel_tool_calls, structured_output, batch, distillation, fine_tuning | 128000 | 128000 | In: $0.04, Out: $0.04 |
| ministral-8b-2512 | mistral | In: text, image; Out: text | streaming, function_calling, tool_choice, parallel_tool_calls, structured_output, batch, distillation, fine_tuning, vision | 262144 | 8192 | - |
| ministral-8b-latest | mistral | In: text; Out: text | function_calling, streaming, tool_choice, parallel_tool_calls, structured_output, batch, distillation, fine_tuning | 128000 | 128000 | In: $0.10, Out: $0.10 |
| open-mistral-7b | mistral | In: text; Out: text | function_calling | 8000 | 8000 | In: $0.25, Out: $0.25 |
| mistral-code-agent-latest | mistral | In: text; Out: text | streaming, function_calling, tool_choice, parallel_tool_calls, structured_output, batch | 262144 | 8192 | - |
| mistral-code-fim-latest | mistral | In: text; Out: text | streaming, function_calling, tool_choice, parallel_tool_calls, structured_output, batch | 256000 | 8192 | - |
| mistral-code-latest | mistral | In: text; Out: text | streaming, function_calling, tool_choice, parallel_tool_calls, structured_output, batch | 256000 | 8192 | - |
| mistral-embed | mistral | In: text; Out: text | - | 8000 | 3072 | In: $0.10, Out: $0.00 |
| mistral-embed-2312 | mistral | In: text; Out: embeddings | - | 8192 | 8192 | - |
| mistral-large-latest | mistral | In: text, image; Out: text | function_calling, vision, streaming, tool_choice, parallel_tool_calls, structured_output, batch, fine_tuning | 262144 | 262144 | In: $0.50, Out: $1.50 |
| mistral-large-2411 | mistral | In: text; Out: text | function_calling | 131072 | 16384 | In: $2.00, Out: $6.00 |
| mistral-large-2512 | mistral | In: text, image; Out: text | function_calling, vision, streaming, tool_choice, parallel_tool_calls, structured_output, batch, fine_tuning | 262144 | 262144 | In: $0.50, Out: $1.50 |
| mistral-medium | mistral | In: text, image; Out: text | streaming, function_calling, tool_choice, parallel_tool_calls, structured_output, batch, reasoning, vision | 262144 | 8192 | - |
| mistral-medium-3 | mistral | In: text, image; Out: text | streaming, function_calling, tool_choice, parallel_tool_calls, structured_output, reasoning, batch, vision | 262144 | 8192 | - |
| mistral-medium-3-5 | mistral | In: text, image; Out: text | streaming, function_calling, tool_choice, parallel_tool_calls, structured_output, reasoning, batch, vision | 262144 | 8192 | - |
| mistral-medium-3.5 | mistral | In: text, image; Out: text | streaming, function_calling, tool_choice, parallel_tool_calls, structured_output, reasoning, batch, vision | 262144 | 8192 | - |
| mistral-medium-latest | mistral | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming, tool_choice, parallel_tool_calls, batch | 262144 | 262144 | In: $1.50, Out: $7.50 |
| mistral-medium-2505 | mistral | In: text, image; Out: text | function_calling, vision, streaming, tool_choice, parallel_tool_calls, structured_output, batch, fine_tuning | 131072 | 131072 | In: $0.40, Out: $2.00 |
| mistral-medium-2508 | mistral | In: text, image; Out: text | function_calling, vision, streaming, tool_choice, parallel_tool_calls, structured_output, batch, fine_tuning | 262144 | 262144 | In: $0.40, Out: $2.00 |
| mistral-medium-2604 | mistral | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming, tool_choice, parallel_tool_calls, batch | 262144 | 262144 | In: $1.50, Out: $7.50 |
| mistral-moderation-2603 | mistral | In: text; Out: text | moderation | 131072 | 8192 | - |
| mistral-nemo | mistral | In: text; Out: text | function_calling | 128000 | 128000 | In: $0.15, Out: $0.15 |
| mistral-ocr-2512 | mistral | In: text, image; Out: text | vision, function_calling | 16384 | 8192 | - |
| mistral-ocr-3 | mistral | In: text, image; Out: text | vision, function_calling | 16384 | 8192 | - |
| mistral-ocr-3-0 | mistral | In: text, image; Out: text | vision, function_calling | 16384 | 8192 | - |
| mistral-ocr-4 | mistral | In: text, image; Out: text | vision, function_calling | 16384 | 8192 | - |
| mistral-ocr-4-0 | mistral | In: text, image; Out: text | vision, function_calling | 16384 | 8192 | - |
| mistral-ocr-4-1 | mistral | In: text, image; Out: text | vision, function_calling | 16384 | 8192 | - |
| mistral-ocr-latest | mistral | In: text, image; Out: text | vision, function_calling | 16384 | 8192 | - |
| mistral-small-latest | mistral | In: text, image; Out: text | function_calling, reasoning, vision, streaming, tool_choice, parallel_tool_calls, structured_output, batch | 256000 | 256000 | In: $0.15, Out: $0.60 |
| mistral-small-2506 | mistral | In: text, image; Out: text | function_calling, vision | 128000 | 16384 | In: $0.10, Out: $0.30 |
| mistral-small-2603 | mistral | In: text, image; Out: text | function_calling, reasoning, vision, streaming, tool_choice, parallel_tool_calls, structured_output, batch | 256000 | 256000 | In: $0.15, Out: $0.60 |
| mistral-vibe-cli-fast | mistral | In: text, image; Out: text | streaming, function_calling, tool_choice, parallel_tool_calls, structured_output, batch, reasoning, vision | 262144 | 8192 | - |
| mistral-vibe-cli-latest | mistral | In: text, image; Out: text | streaming, function_calling, tool_choice, parallel_tool_calls, structured_output, batch, reasoning, vision | 262144 | 8192 | - |
| mistral-vibe-cli-with-tools | mistral | In: text, image; Out: text | streaming, function_calling, tool_choice, parallel_tool_calls, structured_output, batch, reasoning, vision | 262144 | 8192 | - |
| open-mixtral-8x22b | mistral | In: text; Out: text | function_calling | 64000 | 64000 | In: $2.00, Out: $6.00 |
| open-mixtral-8x7b | mistral | In: text; Out: text | function_calling | 32000 | 32000 | In: $0.70, Out: $0.70 |
| open-mistral-nemo | mistral | In: text; Out: text | function_calling | 128000 | 128000 | In: $0.15, Out: $0.15 |
| pixtral-12b | mistral | In: text, image; Out: text | function_calling, vision | 128000 | 128000 | In: $0.15, Out: $0.15 |
| pixtral-large-latest | mistral | In: text, image; Out: text | function_calling, vision | 128000 | 128000 | In: $2.00, Out: $6.00 |
| voxtral-mini-latest | mistral | In: audio; Out: text | streaming, transcription | 0 | 0 | - |
| voxtral-mini-2602 | mistral | In: text, audio; Out: text | streaming, transcription | 16384 | 8192 | - |
| voxtral-mini-realtime-2602 | mistral | In: text, audio; Out: text | streaming, realtime | 32768 | 8192 | - |
| voxtral-mini-realtime-latest | mistral | In: text, audio; Out: text | streaming, realtime | 32768 | 8192 | - |
| voxtral-mini-tts-latest | mistral | In: text; Out: audio | streaming, fine_tuning, speech_generation | 0 | 0 | - |
| voxtral-mini-transcribe-realtime-2602 | mistral | In: audio; Out: text | realtime | 32768 | 8192 | - |
| voxtral-mini-tts-2603 | mistral | In: text; Out: audio | streaming, function_calling, fine_tuning, speech_generation | 4096 | 8192 | - |
| voxtral-small-latest | mistral | In: text, audio; Out: text | function_calling, streaming | 32000 | 32000 | In: $0.10, Out: $0.30 |
| voxtral-small-2507 | mistral | In: text, audio; Out: text | streaming, function_calling | 32768 | 8192 | - |
| zai-glm-5-2 | mistral | In: text; Out: text | streaming, function_calling, tool_choice, parallel_tool_calls, structured_output, batch, reasoning | 1048576 | 8192 | - |


### OllamaCloud (23)

| Model | Provider | I/O | Capabilities | Context | Max Output | Standard Pricing (per 1M tokens) |
| :-- | :-- | :-- | :-- | --: | --: | :-- |
| deepseek-v4-flash:0731 | ollama_cloud | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 1048576 | 1048576 | - |
| glm-5.2 | ollama_cloud | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 976000 | 131072 | - |
| deepseek-v4-flash | ollama_cloud | In: text; Out: text | function_calling, reasoning | 1048576 | 1048576 | - |
| deepseek-v4-flash:preview | ollama_cloud | In: text; Out: text | streaming, function_calling, reasoning | - | - | - |
| deepseek-v4-pro | ollama_cloud | In: text; Out: text | function_calling, reasoning | 1048576 | 1048576 | - |
| deepseek-v4-pro:0813 | ollama_cloud | In: text; Out: text | streaming, function_calling, reasoning | - | - | - |
| deepseek-v4-pro:preview | ollama_cloud | In: text; Out: text | streaming, function_calling, reasoning | - | - | - |
| gemma4:31b | ollama_cloud | In: text, image; Out: text | function_calling, reasoning, vision, streaming | 262144 | 262144 | - |
| glm-5.1 | ollama_cloud | In: text; Out: text | function_calling, reasoning, streaming | 202752 | 131072 | - |
| gpt-oss:120b | ollama_cloud | In: text; Out: text | function_calling, reasoning, streaming | 131072 | 32768 | - |
| gpt-oss:20b | ollama_cloud | In: text; Out: text | function_calling, reasoning, streaming | 131072 | 32768 | - |
| kimi-k2.5 | ollama_cloud | In: text, image; Out: text | function_calling, reasoning, vision | 262144 | 262144 | - |
| kimi-k2.6 | ollama_cloud | In: text, image; Out: text | function_calling, reasoning, vision, streaming | 262144 | 262144 | - |
| kimi-k2.7-code | ollama_cloud | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 262144 | 262144 | - |
| kimi-k3 | ollama_cloud | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1048576 | 131072 | - |
| minimax-m2.5 | ollama_cloud | In: text; Out: text | function_calling, reasoning | 204800 | 131072 | - |
| minimax-m2.7 | ollama_cloud | In: text; Out: text | function_calling, reasoning, streaming | 196608 | 196608 | - |
| minimax-m3 | ollama_cloud | In: text, image, video; Out: text | function_calling, reasoning, vision, video, streaming | 512000 | 131072 | - |
| mistral-large-3:675b | ollama_cloud | In: text, image; Out: text | function_calling, vision, streaming | 262144 | 262144 | - |
| nemotron-3-nano:30b | ollama_cloud | In: text; Out: text | function_calling, reasoning, streaming | 1048576 | 131072 | - |
| nemotron-3-super | ollama_cloud | In: text; Out: text | function_calling, reasoning, streaming | 262144 | 65536 | - |
| nemotron-3-ultra | ollama_cloud | In: text; Out: text | function_calling, reasoning, streaming | 262144 | 128000 | - |
| qwen3.5:397b | ollama_cloud | In: text, image; Out: text | function_calling, reasoning, vision, streaming | 262144 | 65536 | - |


### OpenAI (132)

| Model | Provider | I/O | Capabilities | Context | Max Output | Standard Pricing (per 1M tokens) |
| :-- | :-- | :-- | :-- | --: | --: | :-- |
| gpt-3.5-turbo | openai | In: text; Out: text | - | 16385 | 4096 | In: $0.50, Out: $1.50, Cache Read: $0.00 |
| gpt-4 | openai | In: text; Out: text | function_calling, tool_choice, parallel_tool_calls | 8192 | 8192 | In: $30.00, Out: $60.00 |
| gpt-4-turbo | openai | In: text, image; Out: text | function_calling, vision, tool_choice, parallel_tool_calls | 128000 | 4096 | In: $10.00, Out: $30.00 |
| gpt-4.1 | openai | In: text, image, pdf; Out: text | function_calling, structured_output, vision, tool_choice, parallel_tool_calls | 1047576 | 32768 | In: $2.00, Out: $8.00, Cache Read: $0.50 |
| gpt-4.1-mini | openai | In: text, image, pdf; Out: text | function_calling, structured_output, vision, tool_choice, parallel_tool_calls | 1047576 | 32768 | In: $0.40, Out: $1.60, Cache Read: $0.10 |
| gpt-4.1-nano | openai | In: text, image; Out: text | function_calling, structured_output, vision, tool_choice, parallel_tool_calls | 1047576 | 32768 | In: $0.10, Out: $0.40, Cache Read: $0.02 |
| gpt-4o | openai | In: text, image, pdf; Out: text | function_calling, structured_output, vision, tool_choice, parallel_tool_calls | 128000 | 16384 | In: $2.50, Out: $10.00, Cache Read: $1.25 |
| gpt-4o-2024-05-13 | openai | In: text, image; Out: text | function_calling, structured_output, vision, tool_choice, parallel_tool_calls | 128000 | 4096 | In: $5.00, Out: $15.00 |
| gpt-4o-2024-08-06 | openai | In: text, image; Out: text | function_calling, structured_output, vision, tool_choice, parallel_tool_calls | 128000 | 16384 | In: $2.50, Out: $10.00, Cache Read: $1.25 |
| gpt-4o-2024-11-20 | openai | In: text, image; Out: text | function_calling, structured_output, vision, tool_choice, parallel_tool_calls | 128000 | 16384 | In: $2.50, Out: $10.00, Cache Read: $1.25 |
| gpt-4o-mini | openai | In: text, image, pdf; Out: text | function_calling, structured_output, vision, tool_choice, parallel_tool_calls | 128000 | 16384 | In: $0.15, Out: $0.60, Cache Read: $0.08 |
| gpt-5 | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, tool_choice, parallel_tool_calls | 400000 | 128000 | In: $1.25, Out: $10.00, Cache Read: $0.12 |
| gpt-5-mini | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, tool_choice, parallel_tool_calls | 400000 | 128000 | In: $0.25, Out: $2.00, Cache Read: $0.02 |
| gpt-5-nano | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, tool_choice, parallel_tool_calls | 400000 | 128000 | In: $0.05, Out: $0.40, Cache Read: $0.01 |
| gpt-5-pro | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, tool_choice, parallel_tool_calls | 400000 | 272000 | In: $15.00, Out: $120.00 |
| gpt-5.1 | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, tool_choice, parallel_tool_calls | 400000 | 128000 | In: $1.25, Out: $10.00, Cache Read: $0.12 |
| gpt-5.2 | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, tool_choice, parallel_tool_calls | 400000 | 128000 | In: $1.75, Out: $14.00, Cache Read: $0.18 |
| gpt-5.2-chat-latest | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, tool_choice, parallel_tool_calls | 128000 | 16384 | In: $1.75, Out: $14.00, Cache Read: $0.18 |
| gpt-5.2-pro | openai | In: text, image; Out: text | function_calling, reasoning, vision, tool_choice, parallel_tool_calls | 400000 | 128000 | In: $21.00, Out: $168.00 |
| gpt-5.3-chat-latest | openai | In: text, image; Out: text | function_calling, structured_output, vision, tool_choice, parallel_tool_calls | 128000 | 16384 | In: $1.75, Out: $14.00, Cache Read: $0.18 |
| gpt-5.3-codex | openai | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, tool_choice, parallel_tool_calls | 400000 | 128000 | In: $1.75, Out: $14.00, Cache Read: $0.18 |
| gpt-5.3-codex-spark | openai | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 128000 | 32000 | In: $1.75, Out: $14.00, Cache Read: $0.18 |
| gpt-5.4 | openai | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, tool_choice, parallel_tool_calls | 1050000 | 128000 | In: $2.50, Out: $15.00, Cache Read: $0.25 |
| gpt-5.4-pro | openai | In: text, image; Out: text | function_calling, reasoning, vision, tool_choice, parallel_tool_calls | 1050000 | 128000 | In: $30.00, Out: $180.00 |
| gpt-5.4-mini | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, tool_choice, parallel_tool_calls | 400000 | 128000 | In: $0.75, Out: $4.50, Cache Read: $0.08 |
| gpt-5.4-nano | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, tool_choice, parallel_tool_calls | 400000 | 128000 | In: $0.20, Out: $1.25, Cache Read: $0.02 |
| gpt-5.5 | openai | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, tool_choice, parallel_tool_calls | 1050000 | 128000 | In: $5.00, Out: $30.00, Cache Read: $0.50 |
| gpt-5.5-pro | openai | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, tool_choice, parallel_tool_calls | 1050000 | 128000 | In: $30.00, Out: $180.00 |
| gpt-5.6 | openai | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1050000 | 128000 | In: $5.00, Out: $30.00, Cache Read: $0.50, Cache Write: $6.25 |
| gpt-5.6-luna | openai | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, tool_choice, parallel_tool_calls | 1050000 | 128000 | In: $0.20, Out: $1.20, Cache Read: $0.02, Cache Write: $0.25 |
| gpt-5.6-sol | openai | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, tool_choice, parallel_tool_calls | 1050000 | 128000 | In: $5.00, Out: $30.00, Cache Read: $0.50, Cache Write: $6.25 |
| gpt-5.6-terra | openai | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, tool_choice, parallel_tool_calls | 1050000 | 128000 | In: $2.00, Out: $12.00, Cache Read: $0.20, Cache Write: $2.50 |
| gpt-realtime-2.1 | openai | In: text, audio, image; Out: text, audio | function_calling, reasoning, vision | 128000 | 32000 | In: $4.00, Out: $24.00, Cache Read: $0.40 |
| babbage-002 | openai | In: -; Out: - | - | 4096 | 16384 | In: $0.40, Out: $0.40 |
| chat-latest | openai | In: -; Out: - | - | 4096 | 16384 | In: $0.50, Out: $1.50 |
| chatgpt-image-latest | openai | In: text, image; Out: text, image | vision | 0 | 0 | In: $0.50, Out: $1.50 |
| davinci-002 | openai | In: -; Out: - | - | 4096 | 16384 | In: $2.00, Out: $2.00 |
| gpt-3.5-turbo-0125 | openai | In: -; Out: - | - | 16385 | 4096 | In: $0.50, Out: $1.50 |
| gpt-3.5-turbo-1106 | openai | In: -; Out: - | - | 16385 | 4096 | In: $0.50, Out: $1.50 |
| gpt-3.5-turbo-16k | openai | In: -; Out: - | - | 16385 | 4096 | In: $0.50, Out: $1.50 |
| gpt-3.5-turbo-instruct | openai | In: -; Out: - | - | 16385 | 4096 | In: $0.50, Out: $1.50 |
| gpt-3.5-turbo-instruct-0914 | openai | In: -; Out: - | - | 16385 | 4096 | In: $0.50, Out: $1.50 |
| gpt-4-0613 | openai | In: -; Out: - | function_calling, tool_choice, parallel_tool_calls | 8192 | 8192 | In: $10.00, Out: $30.00 |
| gpt-4-turbo-2024-04-09 | openai | In: -; Out: - | function_calling, tool_choice, parallel_tool_calls, vision | 128000 | 16384 | In: $10.00, Out: $30.00 |
| gpt-4.1-2025-04-14 | openai | In: -; Out: - | function_calling, tool_choice, parallel_tool_calls, structured_output, vision | 1047576 | 32768 | In: $2.00, Out: $8.00, Cache Read: $0.50 |
| gpt-4.1-mini-2025-04-14 | openai | In: -; Out: - | function_calling, tool_choice, parallel_tool_calls, structured_output, vision | 1047576 | 32768 | In: $0.40, Out: $1.60, Cache Read: $0.10 |
| gpt-4.1-nano-2025-04-14 | openai | In: -; Out: - | function_calling, tool_choice, parallel_tool_calls, structured_output, vision | 1047576 | 32768 | In: $0.10, Out: $0.40 |
| gpt-4o-mini-2024-07-18 | openai | In: -; Out: - | function_calling, tool_choice, parallel_tool_calls, structured_output, vision | 128000 | 16384 | In: $0.15, Out: $0.60 |
| gpt-4o-mini-search-preview | openai | In: -; Out: - | citations | 4096 | 16384 | In: $0.50, Out: $1.50 |
| gpt-4o-mini-search-preview-2025-03-11 | openai | In: -; Out: - | citations | 4096 | 16384 | In: $0.50, Out: $1.50 |
| gpt-4o-mini-transcribe | openai | In: -; Out: - | transcription | 16000 | 2000 | In: $1.25, Out: $5.00 |
| gpt-4o-mini-transcribe-2025-03-20 | openai | In: -; Out: - | transcription | 16000 | 2000 | In: $1.25, Out: $5.00 |
| gpt-4o-mini-transcribe-2025-12-15 | openai | In: -; Out: - | transcription | 16000 | 2000 | In: $1.25, Out: $5.00 |
| gpt-4o-mini-tts | openai | In: -; Out: - | - | - | - | In: $0.60, Out: $12.00 |
| gpt-4o-mini-tts-2025-03-20 | openai | In: -; Out: - | - | - | - | In: $0.60, Out: $12.00 |
| gpt-4o-mini-tts-2025-12-15 | openai | In: -; Out: - | - | - | - | In: $0.60, Out: $12.00 |
| gpt-4o-search-preview | openai | In: -; Out: - | vision, citations | 128000 | 16384 | In: $2.50, Out: $10.00 |
| gpt-4o-search-preview-2025-03-11 | openai | In: -; Out: - | vision, citations | 128000 | 16384 | In: $2.50, Out: $10.00 |
| gpt-4o-transcribe | openai | In: -; Out: - | transcription | 128000 | 16384 | In: $2.50, Out: $10.00 |
| gpt-4o-transcribe-diarize | openai | In: -; Out: - | transcription | 128000 | 16384 | In: $2.50, Out: $10.00 |
| gpt-5-2025-08-07 | openai | In: -; Out: - | function_calling, tool_choice, parallel_tool_calls, structured_output, vision, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache Read: $0.12 |
| gpt-5-chat-latest | openai | In: -; Out: - | function_calling, tool_choice, parallel_tool_calls, structured_output, vision, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache Read: $0.12 |
| gpt-5-codex | openai | In: -; Out: - | function_calling, tool_choice, parallel_tool_calls, structured_output, vision, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache Read: $0.12 |
| gpt-5-mini-2025-08-07 | openai | In: -; Out: - | function_calling, tool_choice, parallel_tool_calls, structured_output, vision, reasoning | 128000 | 400000 | In: $0.25, Out: $2.00, Cache Read: $0.02 |
| gpt-5-nano-2025-08-07 | openai | In: -; Out: - | function_calling, tool_choice, parallel_tool_calls, structured_output, vision, reasoning | 128000 | 400000 | In: $0.05, Out: $0.40, Cache Read: $0.01 |
| gpt-5-pro-2025-10-06 | openai | In: -; Out: - | function_calling, tool_choice, parallel_tool_calls, structured_output, vision, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache Read: $0.12 |
| gpt-5-search-api | openai | In: -; Out: - | function_calling, tool_choice, parallel_tool_calls, structured_output, vision, reasoning, citations | 128000 | 400000 | In: $1.25, Out: $10.00, Cache Read: $0.12 |
| gpt-5-search-api-2025-10-14 | openai | In: -; Out: - | function_calling, tool_choice, parallel_tool_calls, structured_output, vision, reasoning, citations | 128000 | 400000 | In: $1.25, Out: $10.00, Cache Read: $0.12 |
| gpt-5.1-2025-11-13 | openai | In: -; Out: - | function_calling, tool_choice, parallel_tool_calls, structured_output, vision, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache Read: $0.12 |
| gpt-5.1-chat-latest | openai | In: -; Out: - | function_calling, tool_choice, parallel_tool_calls, structured_output, vision, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache Read: $0.12 |
| gpt-5.1-codex | openai | In: -; Out: - | function_calling, tool_choice, parallel_tool_calls, structured_output, vision, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache Read: $0.12 |
| gpt-5.1-codex-max | openai | In: -; Out: - | function_calling, tool_choice, parallel_tool_calls, structured_output, vision, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache Read: $0.12 |
| gpt-5.1-codex-mini | openai | In: -; Out: - | function_calling, tool_choice, parallel_tool_calls, structured_output, vision, reasoning | 128000 | 400000 | In: $0.25, Out: $2.00, Cache Read: $0.02 |
| gpt-5.2-2025-12-11 | openai | In: -; Out: - | function_calling, tool_choice, parallel_tool_calls, structured_output, vision, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache Read: $0.12 |
| gpt-5.2-codex | openai | In: -; Out: - | function_calling, tool_choice, parallel_tool_calls, structured_output, vision, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache Read: $0.12 |
| gpt-5.2-pro-2025-12-11 | openai | In: -; Out: - | function_calling, tool_choice, parallel_tool_calls, structured_output, vision, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache Read: $0.12 |
| gpt-5.4-2026-03-05 | openai | In: -; Out: - | function_calling, tool_choice, parallel_tool_calls, structured_output, vision, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache Read: $0.12 |
| gpt-5.4-mini-2026-03-17 | openai | In: -; Out: - | function_calling, tool_choice, parallel_tool_calls, structured_output, vision, reasoning | 128000 | 400000 | In: $0.25, Out: $2.00, Cache Read: $0.02 |
| gpt-5.4-nano-2026-03-17 | openai | In: -; Out: - | function_calling, tool_choice, parallel_tool_calls, structured_output, vision, reasoning | 128000 | 400000 | In: $0.05, Out: $0.40, Cache Read: $0.01 |
| gpt-5.4-pro-2026-03-05 | openai | In: -; Out: - | function_calling, tool_choice, parallel_tool_calls, structured_output, vision, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache Read: $0.12 |
| gpt-5.5-2026-04-23 | openai | In: -; Out: - | function_calling, tool_choice, parallel_tool_calls, structured_output, vision, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache Read: $0.12 |
| gpt-5.5-pro-2026-04-23 | openai | In: -; Out: - | function_calling, tool_choice, parallel_tool_calls, structured_output, vision, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache Read: $0.12 |
| gpt-audio | openai | In: -; Out: - | - | 4096 | 16384 | In: $0.50, Out: $1.50 |
| gpt-audio-1.5 | openai | In: -; Out: - | - | 4096 | 16384 | In: $0.50, Out: $1.50 |
| gpt-audio-2025-08-28 | openai | In: -; Out: - | - | 4096 | 16384 | In: $0.50, Out: $1.50 |
| gpt-audio-mini | openai | In: -; Out: - | - | 4096 | 16384 | In: $0.50, Out: $1.50 |
| gpt-audio-mini-2025-10-06 | openai | In: -; Out: - | - | 4096 | 16384 | In: $0.50, Out: $1.50 |
| gpt-audio-mini-2025-12-15 | openai | In: -; Out: - | - | 4096 | 16384 | In: $0.50, Out: $1.50 |
| gpt-image-1 | openai | In: text, image; Out: image | vision | 0 | 0 | In: $5.00, Cache Read: $1.25 |
| gpt-image-1-mini | openai | In: text, image; Out: text, image | vision | 0 | 0 | In: $2.00, Cache Read: $0.20 |
| gpt-image-1.5 | openai | In: text, image; Out: text, image | vision | 0 | 0 | In: $5.00, Cache Read: $1.25 |
| gpt-image-2 | openai | In: text, image; Out: image | vision | 0 | 0 | In: $5.00, Out: $30.00, Cache Read: $1.25 |
| gpt-image-2-2026-04-21 | openai | In: -; Out: - | - | 4096 | 16384 | In: $0.50, Out: $1.50 |
| gpt-live-transcribe | openai | In: -; Out: - | - | 4096 | 16384 | In: $0.50, Out: $1.50 |
| gpt-realtime | openai | In: -; Out: - | - | 4096 | 16384 | In: $0.50, Out: $1.50 |
| gpt-realtime-1.5 | openai | In: -; Out: - | - | 4096 | 16384 | In: $0.50, Out: $1.50 |
| gpt-realtime-2 | openai | In: -; Out: - | - | 4096 | 16384 | In: $0.50, Out: $1.50 |
| gpt-realtime-2.1-mini | openai | In: -; Out: - | - | 4096 | 16384 | In: $0.50, Out: $1.50 |
| gpt-realtime-2025-08-28 | openai | In: -; Out: - | - | 4096 | 16384 | In: $0.50, Out: $1.50 |
| gpt-realtime-mini | openai | In: -; Out: - | - | 4096 | 16384 | In: $0.50, Out: $1.50 |
| gpt-realtime-mini-2025-12-15 | openai | In: -; Out: - | - | 4096 | 16384 | In: $0.50, Out: $1.50 |
| gpt-realtime-translate | openai | In: -; Out: - | - | 4096 | 16384 | In: $0.50, Out: $1.50 |
| gpt-realtime-whisper | openai | In: -; Out: - | - | 4096 | 16384 | In: $0.50, Out: $1.50 |
| gpt-transcribe | openai | In: -; Out: - | - | 4096 | 16384 | In: $0.50, Out: $1.50 |
| o1 | openai | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, tool_choice, parallel_tool_calls | 200000 | 100000 | In: $15.00, Out: $60.00, Cache Read: $7.50 |
| o1-2024-12-17 | openai | In: -; Out: - | function_calling, tool_choice, parallel_tool_calls, structured_output, vision, reasoning | 200000 | 100000 | In: $15.00, Out: $60.00 |
| o1-pro | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, tool_choice, parallel_tool_calls | 200000 | 100000 | In: $150.00, Out: $600.00 |
| o1-pro-2025-03-19 | openai | In: -; Out: - | function_calling, tool_choice, parallel_tool_calls, structured_output, vision, reasoning | 200000 | 100000 | In: $150.00, Out: $600.00 |
| o3 | openai | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 200000 | 100000 | In: $2.00, Out: $8.00, Cache Read: $0.50 |
| o3-2025-04-16 | openai | In: -; Out: - | reasoning | 4096 | 16384 | In: $0.50, Out: $1.50 |
| o3-deep-research | openai | In: -; Out: - | reasoning | 4096 | 16384 | In: $0.50, Out: $1.50 |
| o3-deep-research-2025-06-26 | openai | In: -; Out: - | reasoning | 4096 | 16384 | In: $0.50, Out: $1.50 |
| o3-mini | openai | In: text; Out: text | function_calling, structured_output, reasoning, tool_choice, parallel_tool_calls | 200000 | 100000 | In: $1.10, Out: $4.40, Cache Read: $0.55 |
| o3-mini-2025-01-31 | openai | In: -; Out: - | function_calling, tool_choice, parallel_tool_calls, structured_output, reasoning | 200000 | 100000 | In: $1.10, Out: $4.40 |
| o3-pro | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision | 200000 | 100000 | In: $20.00, Out: $80.00 |
| o3-pro-2025-06-10 | openai | In: -; Out: - | reasoning | 4096 | 16384 | In: $0.50, Out: $1.50 |
| o4-mini | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision | 200000 | 100000 | In: $1.10, Out: $4.40, Cache Read: $0.28 |
| o4-mini-2025-04-16 | openai | In: -; Out: - | reasoning | 4096 | 16384 | In: $0.50, Out: $1.50 |
| o4-mini-deep-research | openai | In: -; Out: - | reasoning | 4096 | 16384 | In: $0.50, Out: $1.50 |
| o4-mini-deep-research-2025-06-26 | openai | In: -; Out: - | reasoning | 4096 | 16384 | In: $0.50, Out: $1.50 |
| omni-moderation-2024-09-26 | openai | In: -; Out: - | vision | - | - | In: $0.00, Out: $0.00 |
| omni-moderation-latest | openai | In: -; Out: - | vision | - | - | In: $0.00, Out: $0.00 |
| sora-2 | openai | In: -; Out: - | - | 4096 | 16384 | In: $0.50, Out: $1.50 |
| sora-2-pro | openai | In: -; Out: - | - | 4096 | 16384 | In: $0.50, Out: $1.50 |
| text-embedding-3-large | openai | In: text; Out: embeddings | - | 8191 | 3072 | In: $0.13, Out: $0.00 |
| text-embedding-3-small | openai | In: text; Out: embeddings | - | 8191 | 1536 | In: $0.02, Out: $0.00 |
| text-embedding-ada-002 | openai | In: text; Out: embeddings | - | 8192 | 1536 | In: $0.10, Out: $0.00 |
| tts-1 | openai | In: -; Out: - | - | - | - | In: $15.00, Out: $15.00 |
| tts-1-1106 | openai | In: -; Out: - | - | - | - | In: $15.00, Out: $15.00 |
| tts-1-hd | openai | In: -; Out: - | - | - | - | In: $30.00, Out: $30.00 |
| tts-1-hd-1106 | openai | In: -; Out: - | - | - | - | In: $30.00, Out: $30.00 |
| whisper-1 | openai | In: -; Out: - | transcription | - | - | In: $0.01, Out: $0.01 |


### OpenRouter (525)

| Model | Provider | I/O | Capabilities | Context | Max Output | Standard Pricing (per 1M tokens) |
| :-- | :-- | :-- | :-- | --: | --: | :-- |
| aion-labs/aion-2.0 | openrouter | In: text; Out: text | function_calling, reasoning, streaming | 131072 | 32768 | In: $0.80, Out: $1.60, Cache Read: $0.20 |
| aion-labs/aion-3.0 | openrouter | In: text; Out: text | function_calling, reasoning, streaming | 131072 | 32768 | In: $3.00, Out: $6.00, Cache Read: $0.75 |
| aion-labs/aion-3.0-mini | openrouter | In: text; Out: text | function_calling, reasoning, streaming | 131072 | 32768 | In: $0.70, Out: $1.40, Cache Read: $0.18 |
| aion-labs/aion-rp-llama-3.1-8b | openrouter | In: text; Out: text | streaming | 32768 | 32768 | In: $0.80, Out: $1.60 |
| ~anthropic/claude-haiku-latest | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 64000 | In: $1.00, Out: $5.00, Cache Read: $0.10, Cache Write: $1.25 |
| ~anthropic/claude-sonnet-latest | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 128000 | In: $2.00, Out: $10.00, Cache Read: $0.20, Cache Write: $2.50 |
| anthropic/claude-fable-5:batch | openrouter | In: text, image, file; Out: text | streaming, function_calling, structured_output | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| anthropic/claude-haiku-4.5:batch | openrouter | In: text, image, file; Out: text | streaming, function_calling, structured_output | 200000 | 64000 | In: $0.50, Out: $2.50, Cache Read: $0.05, Cache Write: $0.62 |
| anthropic/claude-opus-4.1:batch | openrouter | In: image, text, file; Out: text | streaming, function_calling, structured_output | 200000 | 32000 | In: $7.50, Out: $37.50, Cache Read: $0.75, Cache Write: $9.38 |
| anthropic/claude-opus-4.5:batch | openrouter | In: file, image, text; Out: text | streaming, function_calling, structured_output | 200000 | 64000 | In: $2.50, Out: $12.50, Cache Read: $0.25, Cache Write: $3.12 |
| anthropic/claude-opus-4.6:batch | openrouter | In: text, image, file; Out: text | streaming, function_calling, structured_output | 1000000 | 128000 | In: $2.50, Out: $12.50, Cache Read: $0.25, Cache Write: $3.12 |
| anthropic/claude-opus-4.7:batch | openrouter | In: text, image, file; Out: text | streaming, function_calling, structured_output | 1000000 | 128000 | In: $2.50, Out: $12.50, Cache Read: $0.25, Cache Write: $3.12 |
| anthropic/claude-opus-4.8:batch | openrouter | In: text, image, file; Out: text | streaming, function_calling, structured_output | 1000000 | 128000 | In: $2.50, Out: $12.50, Cache Read: $0.25, Cache Write: $3.12 |
| anthropic/claude-sonnet-4.5:batch | openrouter | In: text, image, file; Out: text | streaming, function_calling, structured_output | 1000000 | 64000 | In: $1.50, Out: $7.50, Cache Read: $0.15, Cache Write: $1.88 |
| anthropic/claude-sonnet-4.6:batch | openrouter | In: text, image, file; Out: text | streaming, function_calling, structured_output | 1000000 | 128000 | In: $1.50, Out: $7.50, Cache Read: $0.15, Cache Write: $1.88 |
| anthropic/claude-sonnet-5:batch | openrouter | In: text, image, file; Out: text | streaming, function_calling, structured_output | 1000000 | 128000 | In: $1.00, Out: $5.00, Cache Read: $0.10, Cache Write: $1.25 |
| openrouter/auto | openrouter | In: text, image, audio, pdf, video; Out: text, image | function_calling, structured_output, reasoning, vision, video, streaming, predicted_outputs, image_generation | 2000000 | 2000000 | - |
| openrouter/auto-beta | openrouter | In: text, image, audio, file, video; Out: text, image | streaming, function_calling, structured_output, predicted_outputs, image_generation | 2000000 | - | - |
| baai/bge-base-en-v1.5 | openrouter | In: text; Out: embeddings | streaming, structured_output | 512 | - | In: $0.01 |
| baai/bge-large-en-v1.5 | openrouter | In: text; Out: embeddings | streaming, structured_output | 512 | - | In: $0.01 |
| baai/bge-m3 | openrouter | In: text; Out: embeddings | streaming, structured_output, predicted_outputs | 8194 | - | In: $0.01 |
| black-forest-labs/flux.2-flex | openrouter | In: text, image; Out: image | streaming, image_generation | - | - | - |
| black-forest-labs/flux.2-klein-4b | openrouter | In: text, image; Out: image | streaming, image_generation | - | - | - |
| black-forest-labs/flux.2-max | openrouter | In: text, image; Out: image | streaming, image_generation | - | - | - |
| black-forest-labs/flux.2-pro | openrouter | In: text, image; Out: image | streaming, image_generation | - | - | - |
| openrouter/bodybuilder | openrouter | In: text; Out: text | streaming | 128000 | 128000 | - |
| bytedance-seed/seedream-4.5 | openrouter | In: image, text; Out: image | streaming, image_generation | - | - | - |
| bytedance-seed/seedream-5-0-lite | openrouter | In: text, image; Out: image | streaming, image_generation | - | - | - |
| bytedance-seed/seedream-5-0-pro | openrouter | In: text, image; Out: image | streaming, image_generation | - | - | - |
| canopylabs/orpheus-3b-0.1-ft | openrouter | In: text; Out: audio | streaming, structured_output, predicted_outputs, speech_generation | 4096 | - | In: $7.00 |
| anthropic/claude-3-haiku | openrouter | In: text, image; Out: text | function_calling, vision, streaming | 200000 | 4096 | In: $0.25, Out: $1.25, Cache Read: $0.03, Cache Write: $0.30 |
| anthropic/claude-fable-5 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 128000 | In: $10.00, Out: $50.00, Cache Read: $1.00, Cache Write: $12.50 |
| ~anthropic/claude-fable-latest | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 128000 | In: $10.00, Out: $50.00, Cache Read: $1.00, Cache Write: $12.50 |
| anthropic/claude-haiku-4.5 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 64000 | In: $1.00, Out: $5.00, Cache Read: $0.10, Cache Write: $1.25 |
| anthropic/claude-opus-4 | openrouter | In: image, text, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 32000 | In: $15.00, Out: $75.00, Cache Read: $1.50, Cache Write: $18.75 |
| anthropic/claude-opus-4.1 | openrouter | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 32000 | In: $15.00, Out: $75.00, Cache Read: $1.50, Cache Write: $18.75 |
| anthropic/claude-opus-4.5 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 64000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| anthropic/claude-opus-4.6 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| anthropic/claude-opus-4.7 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| anthropic/claude-opus-4.7-fast | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 128000 | In: $30.00, Out: $150.00, Cache Read: $3.00, Cache Write: $37.50 |
| anthropic/claude-opus-4.8 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| anthropic/claude-opus-4.8-fast | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 128000 | In: $10.00, Out: $50.00, Cache Read: $1.00, Cache Write: $12.50 |
| anthropic/claude-opus-5 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| anthropic/claude-opus-5-fast | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 128000 | In: $10.00, Out: $50.00, Cache Read: $1.00, Cache Write: $12.50 |
| anthropic/claude-opus-5:batch | openrouter | In: text, image, file; Out: text | streaming, function_calling, structured_output | 1000000 | 128000 | In: $2.50, Out: $12.50, Cache Read: $0.25, Cache Write: $3.12 |
| ~anthropic/claude-opus-latest | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| anthropic/claude-sonnet-4 | openrouter | In: image, text, pdf; Out: text | function_calling, reasoning, vision, streaming | 1000000 | 64000 | In: $3.00, Out: $15.00, Cache Read: $0.30, Cache Write: $3.75 |
| anthropic/claude-sonnet-4.5 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 64000 | In: $3.00, Out: $15.00, Cache Read: $0.30, Cache Write: $3.75 |
| anthropic/claude-sonnet-4.6 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 128000 | In: $3.00, Out: $15.00, Cache Read: $0.30, Cache Write: $3.75 |
| anthropic/claude-sonnet-5 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 128000 | In: $2.00, Out: $10.00, Cache Read: $0.20, Cache Write: $2.50 |
| mistralai/codestral-2508 | openrouter | In: text, pdf; Out: text | function_calling, structured_output, vision, streaming | 256000 | 256000 | In: $0.30, Out: $0.90, Cache Read: $0.03 |
| deepcogito/cogito-v2.1-671b | openrouter | In: text; Out: text | structured_output, reasoning, streaming, predicted_outputs | 128000 | 128000 | In: $1.25, Out: $1.25 |
| cohere/rerank-4-fast | openrouter | In: text; Out: rerank | streaming, structured_output | 32768 | - | - |
| cohere/rerank-4-pro | openrouter | In: text; Out: rerank | streaming, structured_output | 32768 | - | - |
| cohere/rerank-v3.5 | openrouter | In: text; Out: rerank | streaming, structured_output | 4096 | - | - |
| cohere/command-a | openrouter | In: text; Out: text | structured_output, streaming | 256000 | 8192 | In: $2.50, Out: $10.00 |
| cohere/command-r-08-2024 | openrouter | In: text; Out: text | function_calling, structured_output, streaming | 128000 | 4000 | In: $0.15, Out: $0.60 |
| cohere/command-r-plus-08-2024 | openrouter | In: text; Out: text | function_calling, structured_output, streaming | 128000 | 4000 | In: $2.50, Out: $10.00 |
| cohere/command-r7b-12-2024 | openrouter | In: text; Out: text | structured_output, streaming | 128000 | 4000 | In: $0.04, Out: $0.15 |
| thedrummer/cydonia-24b-v4.1 | openrouter | In: text; Out: text | structured_output, streaming, predicted_outputs | 131072 | 131072 | In: $0.30, Out: $0.50, Cache Read: $0.15 |
| deepseek/deepseek-chat | openrouter | In: text; Out: text | function_calling, structured_output, streaming, predicted_outputs | 163840 | 16000 | In: $0.26, Out: $1.03 |
| deepseek/deepseek-chat-v3-0324 | openrouter | In: text; Out: text | function_calling, structured_output, streaming, predicted_outputs | 163840 | 163840 | In: $0.25, Out: $1.00 |
| deepseek/deepseek-chat-v3.1 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 163840 | 32768 | In: $0.25, Out: $0.95, Cache Read: $0.13 |
| deepseek/deepseek-v3.1-terminus | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 163840 | 163840 | In: $0.27, Out: $1.00 |
| deepseek/deepseek-v3.2 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 163840 | 65536 | In: $0.27, Out: $0.40, Cache Read: $0.13 |
| deepseek/deepseek-v3.2-exp | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 163840 | 65536 | In: $0.27, Out: $0.41 |
| deepseek/deepseek-v4-flash | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 1048576 | 384000 | In: $0.09, Out: $0.18, Cache Read: $0.02 |
| deepseek/deepseek-v4-flash-0731 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 1310720 | 393216 | In: $0.14, Out: $0.28, Cache Read: $0.03 |
| ~deepseek/deepseek-v4-flash-latest | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 1310720 | 262144 | In: $0.06, Out: $0.14, Cache Read: $0.01 |
| deepseek/deepseek-v4-pro | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 1048576 | 393216 | In: $1.60, Out: $3.20, Cache Read: $0.14 |
| deepseek/deepseek-v4-pro-0813 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 1048576 | 384000 | In: $1.19, Out: $3.56, Cache Read: $0.04 |
| deepseek/deepseek-r1 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 64000 | 16000 | In: $0.70, Out: $2.50 |
| deepgram/aura-2 | openrouter | In: text; Out: audio | streaming, speech_generation | 0 | - | In: $30.00 |
| deepgram/flux-tts:free | openrouter | In: text; Out: audio | streaming, speech_generation | 0 | - | - |
| deepgram/nova-3 | openrouter | In: audio; Out: text | streaming, transcription | 0 | - | In: $4300.00 |
| dots-studio/dots-3-note-preview:free | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 512000 | 512000 | In: $0.00, Out: $0.00 |
| baidu/ernie-4.5-vl-424b-a47b | openrouter | In: image, text; Out: text | reasoning, vision, streaming | 123000 | 16000 | In: $0.42, Out: $1.25 |
| fish-audio/s1 | openrouter | In: text; Out: audio | streaming, speech_generation | 0 | - | In: $15.00 |
| fish-audio/s2-pro | openrouter | In: text; Out: audio | streaming, speech_generation | 0 | - | In: $15.00 |
| fish-audio/s2.1-pro | openrouter | In: text; Out: audio | streaming, speech_generation | 0 | - | In: $15.00 |
| fish-audio/s2.1-pro-free:free | openrouter | In: text; Out: audio | streaming, speech_generation | 0 | - | - |
| fish-audio/transcribe-1 | openrouter | In: audio; Out: text | streaming, transcription | 0 | - | In: $100.00 |
| openrouter/free | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 8000 | In: $0.00, Out: $0.00 |
| sakana/fugu-ultra | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 128000 | In: $5.00, Out: $30.00, Cache Read: $0.50 |
| openrouter/fusion | openrouter | In: text; Out: text | streaming | 1000000 | 128000 | - |
| z-ai/glm-5.2:free | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 256000 | 256000 | In: $0.00, Out: $0.00 |
| ~z-ai/glm-latest | openrouter | In: text; Out: text | function_calling, reasoning, streaming | 1048576 | 131072 | In: $1.40, Out: $4.40, Cache Read: $0.26 |
| z-ai/glm-4.5 | openrouter | In: text; Out: text | function_calling, reasoning, streaming | 131072 | 98304 | In: $0.60, Out: $2.20, Cache Read: $0.11 |
| z-ai/glm-4.5-air | openrouter | In: text; Out: text | function_calling, reasoning, streaming | 131072 | 98304 | In: $0.13, Out: $0.85, Cache Read: $0.02 |
| z-ai/glm-4.5v | openrouter | In: text, image; Out: text | function_calling, reasoning, vision, streaming | 65536 | 16384 | In: $0.60, Out: $1.80, Cache Read: $0.11 |
| z-ai/glm-4.6 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 204800 | 131072 | In: $0.50, Out: $2.00, Cache Read: $0.10 |
| z-ai/glm-4.6v | openrouter | In: text, image, video; Out: text | function_calling, reasoning, vision, video, streaming | 131072 | 32768 | In: $0.30, Out: $0.90, Cache Read: $0.06 |
| z-ai/glm-4.7 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 204800 | 131072 | In: $0.40, Out: $1.75, Cache Read: $0.08 |
| z-ai/glm-4.7-flash | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 202752 | 16384 | In: $0.06, Out: $0.40, Cache Read: $0.01 |
| z-ai/glm-5 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 204800 | 128000 | In: $0.60, Out: $1.92, Cache Read: $0.12 |
| z-ai/glm-5-turbo | openrouter | In: text; Out: text | function_calling, reasoning, streaming | 202752 | 131072 | In: $1.20, Out: $4.00, Cache Read: $0.24 |
| z-ai/glm-5.1 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 204800 | 128000 | In: $0.97, Out: $3.04, Cache Read: $0.18 |
| z-ai/glm-5.2 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 1048576 | 131072 | In: $0.97, Out: $3.04, Cache Read: $0.19 |
| z-ai/glm-5.3 | openrouter | In: text; Out: text | function_calling, reasoning, streaming | 1048576 | 131072 | In: $1.40, Out: $4.40, Cache Read: $0.26 |
| z-ai/glm-5v-turbo | openrouter | In: image, text, video; Out: text | function_calling, reasoning, vision, video, streaming | 202752 | 131072 | In: $1.20, Out: $4.00, Cache Read: $0.24 |
| openai/gpt-audio | openrouter | In: text, audio; Out: text, audio | function_calling, structured_output, streaming | 128000 | 16384 | In: $2.50, Out: $10.00 |
| openai/gpt-audio-mini | openrouter | In: text, audio; Out: text, audio | function_calling, structured_output, streaming | 128000 | 16384 | In: $0.60, Out: $2.40 |
| openai/gpt-chat-latest | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, vision, streaming | 400000 | 128000 | In: $5.00, Out: $30.00, Cache Read: $0.50 |
| openai/gpt-oss-120b | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 131072 | 131072 | In: $0.03, Out: $0.17, Cache Read: $0.03 |
| openai/gpt-oss-20b | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 131072 | 131072 | In: $0.03, Out: $0.13, Cache Read: $0.03 |
| openai/gpt-3.5-turbo-0613 | openrouter | In: text; Out: text | function_calling, structured_output, streaming | 4095 | 4096 | In: $1.00, Out: $2.00 |
| openai/gpt-3.5-turbo-16k | openrouter | In: text; Out: text | function_calling, structured_output, streaming | 16385 | 4096 | In: $3.00, Out: $4.00 |
| openai/gpt-3.5-turbo-instruct | openrouter | In: text; Out: text | structured_output, streaming | 4095 | 4096 | In: $1.50, Out: $2.00 |
| openai/gpt-3.5-turbo | openrouter | In: text; Out: text | function_calling, structured_output, streaming | 16385 | 4096 | In: $0.50, Out: $1.50 |
| openai/gpt-4 | openrouter | In: text; Out: text | function_calling, structured_output, streaming | 8191 | 4096 | In: $30.00, Out: $60.00 |
| openai/gpt-4-turbo | openrouter | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 128000 | 4096 | In: $10.00, Out: $30.00 |
| openai/gpt-4-turbo-preview | openrouter | In: text; Out: text | function_calling, structured_output, streaming | 128000 | 4096 | In: $10.00, Out: $30.00 |
| openai/gpt-4.1 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, vision, streaming | 1047576 | 32768 | In: $2.00, Out: $8.00, Cache Read: $0.50 |
| openai/gpt-4.1-mini | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, vision, streaming | 1047576 | 32768 | In: $0.40, Out: $1.60, Cache Read: $0.10 |
| openai/gpt-4.1-nano | openrouter | In: image, text, pdf; Out: text | function_calling, structured_output, vision, streaming | 1047576 | 32768 | In: $0.10, Out: $0.40, Cache Read: $0.02 |
| openai/gpt-4o | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, vision, streaming | 128000 | 16384 | In: $2.50, Out: $10.00, Cache Read: $1.25 |
| openai/gpt-4o-2024-05-13 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, vision, streaming | 128000 | 4096 | In: $5.00, Out: $15.00 |
| openai/gpt-4o-2024-08-06 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, vision, streaming | 128000 | 16384 | In: $2.50, Out: $10.00, Cache Read: $1.25 |
| openai/gpt-4o-2024-11-20 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, vision, streaming | 128000 | 16384 | In: $2.50, Out: $10.00, Cache Read: $1.25 |
| openai/gpt-4o-mini | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, vision, streaming | 128000 | 16384 | In: $0.15, Out: $0.60, Cache Read: $0.08 |
| openai/gpt-4o-mini-2024-07-18 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, vision, streaming | 128000 | 16384 | In: $0.15, Out: $0.60, Cache Read: $0.08 |
| openai/gpt-5 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $1.25, Out: $10.00, Cache Read: $0.12 |
| openai/gpt-5-image | openrouter | In: image, text, pdf; Out: image, text | structured_output, reasoning, vision, streaming, image_generation | 400000 | 128000 | In: $10.00, Out: $10.00, Cache Read: $1.25 |
| openai/gpt-5-image-mini | openrouter | In: pdf, image, text; Out: image, text | structured_output, reasoning, vision, streaming, image_generation | 400000 | 128000 | In: $2.50, Out: $2.00, Cache Read: $0.25 |
| openai/gpt-5-mini | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $0.25, Out: $2.00, Cache Read: $0.02 |
| openai/gpt-5-nano | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $0.05, Out: $0.40, Cache Read: $0.01 |
| openai/gpt-5-pro | openrouter | In: image, text, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $15.00, Out: $120.00 |
| openai/gpt-5.1 | openrouter | In: image, text, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $1.25, Out: $10.00, Cache Read: $0.12 |
| openai/gpt-5.1-codex | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $1.25, Out: $10.00, Cache Read: $0.13 |
| openai/gpt-5.1-codex-max | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $1.25, Out: $10.00, Cache Read: $0.12 |
| openai/gpt-5.1-codex-mini | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $0.25, Out: $2.00, Cache Read: $0.03 |
| openai/gpt-5.2 | openrouter | In: pdf, image, text; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $1.75, Out: $14.00, Cache Read: $0.18 |
| openai/gpt-5.2-chat | openrouter | In: pdf, image, text; Out: text | function_calling, structured_output, vision, streaming | 128000 | 32000 | In: $1.75, Out: $14.00, Cache Read: $0.18 |
| openai/gpt-5.2-codex | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $1.75, Out: $14.00, Cache Read: $0.18 |
| openai/gpt-5.2-pro | openrouter | In: image, text, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $21.00, Out: $168.00 |
| openai/gpt-5.3-codex | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $1.75, Out: $14.00, Cache Read: $0.18 |
| openai/gpt-5.4 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1050000 | 128000 | In: $2.50, Out: $15.00, Cache Read: $0.25 |
| openai/gpt-5.4-image-2 | openrouter | In: image, text, pdf; Out: image, text | structured_output, reasoning, vision, streaming, image_generation | 272000 | 128000 | In: $8.00, Out: $15.00, Cache Read: $2.00 |
| openai/gpt-5.4-pro | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1050000 | 128000 | In: $30.00, Out: $180.00 |
| openai/gpt-5.4-mini | openrouter | In: pdf, image, text; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $0.75, Out: $4.50, Cache Read: $0.08 |
| openai/gpt-5.4-nano | openrouter | In: pdf, image, text; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $0.20, Out: $1.25, Cache Read: $0.02 |
| openai/gpt-5.5 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1050000 | 128000 | In: $5.00, Out: $30.00, Cache Read: $0.50 |
| openai/gpt-5.5-pro | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1050000 | 128000 | In: $30.00, Out: $180.00 |
| openai/gpt-5.6-luna | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1050000 | 128000 | In: $0.20, Out: $1.20, Cache Read: $0.02, Cache Write: $0.25 |
| openai/gpt-5.6-luna-pro | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1050000 | 128000 | In: $0.20, Out: $1.20, Cache Read: $0.02, Cache Write: $0.25 |
| openai/gpt-5.6-sol | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1050000 | 128000 | In: $2.50, Out: $15.00, Cache Read: $0.25, Cache Write: $3.12 |
| openai/gpt-5.6-sol-pro | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1050000 | 128000 | In: $2.50, Out: $15.00, Cache Read: $0.25, Cache Write: $3.12 |
| openai/gpt-5.6-terra | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1050000 | 128000 | In: $2.00, Out: $12.00, Cache Read: $0.20, Cache Write: $2.50 |
| openai/gpt-5.6-terra-pro | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1050000 | 128000 | In: $2.00, Out: $12.00, Cache Read: $0.20, Cache Write: $2.50 |
| google/gemini-2.5-flash | openrouter | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1048576 | 65535 | In: $0.30, Out: $2.50, Cache Read: $0.03, Cache Write: $0.08 |
| google/gemini-2.5-flash-lite | openrouter | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1048576 | 65535 | In: $0.10, Out: $0.40, Cache Read: $0.01, Cache Write: $0.08 |
| google/gemini-2.5-pro | openrouter | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1048576 | 65536 | In: $1.25, Out: $10.00, Cache Read: $0.12, Cache Write: $0.38 |
| google/gemini-2.5-pro-preview-05-06 | openrouter | In: text, image, pdf, audio, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1048576 | 65535 | In: $1.25, Out: $10.00, Cache Read: $0.12, Cache Write: $0.38 |
| google/gemini-2.5-pro-preview | openrouter | In: pdf, image, text, audio; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1048576 | 65536 | In: $1.25, Out: $10.00, Cache Read: $0.12, Cache Write: $0.38 |
| google/gemini-3-flash-preview | openrouter | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1048576 | 65536 | In: $0.50, Out: $3.00, Cache Read: $0.05, Cache Write: $0.08 |
| google/gemini-3.1-flash-lite | openrouter | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1048576 | 65536 | In: $0.25, Out: $1.50, Cache Read: $0.02, Cache Write: $0.08 |
| google/gemini-3.1-flash-lite-preview | openrouter | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1048576 | 65536 | In: $0.25, Out: $1.50, Cache Read: $0.02, Cache Write: $0.08 |
| google/gemini-3.1-pro-preview | openrouter | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1048576 | 65536 | In: $2.00, Out: $12.00, Cache Read: $0.20, Cache Write: $0.38 |
| google/gemini-3.1-pro-preview-customtools | openrouter | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1048576 | 65536 | In: $2.00, Out: $12.00, Cache Read: $0.20, Cache Write: $0.38 |
| google/gemini-3.5-flash | openrouter | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1048576 | 65536 | In: $1.50, Out: $9.00, Cache Read: $0.15, Cache Write: $0.08 |
| google/gemini-3.5-flash-lite | openrouter | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1048576 | 65536 | In: $0.30, Out: $2.50, Cache Read: $0.03, Cache Write: $0.08 |
| google/gemini-3.6-flash | openrouter | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1048576 | 65536 | In: $0.75, Out: $3.75, Cache Read: $0.08, Cache Write: $0.04 |
| google/gemini-3.7-flash | openrouter | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1048576 | 65536 | In: $0.38, Out: $1.88, Cache Read: $0.04, Cache Write: $0.02 |
| google/gemma-2-27b-it | openrouter | In: text; Out: text | structured_output, streaming | 8192 | 2048 | In: $0.65, Out: $0.65 |
| google/gemma-3-12b-it | openrouter | In: text, image; Out: text | function_calling, structured_output, vision, streaming, predicted_outputs | 131072 | 16384 | In: $0.05, Out: $0.15 |
| google/gemma-3-27b-it | openrouter | In: text, image; Out: text | function_calling, structured_output, vision, streaming, predicted_outputs | 262144 | 131072 | In: $0.08, Out: $0.45, Cache Read: $0.04 |
| google/gemma-3-4b-it | openrouter | In: text, image; Out: text | structured_output, vision, streaming, predicted_outputs | 131072 | 16384 | In: $0.05, Out: $0.10 |
| google/gemma-3n-e4b-it | openrouter | In: text; Out: text | structured_output, streaming, predicted_outputs | 32768 | 32768 | In: $0.06, Out: $0.12 |
| google/gemma-4-26b-a4b-it:free | openrouter | In: image, text, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 262144 | 32768 | In: $0.00, Out: $0.00 |
| google/gemma-4-26b-a4b-it | openrouter | In: image, text, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming, predicted_outputs | 262144 | 16384 | In: $0.07, Out: $0.34 |
| google/gemma-4-31b-it:free | openrouter | In: image, text, video; Out: text | function_calling, reasoning, vision, video, streaming | 262144 | 32768 | In: $0.00, Out: $0.00 |
| google/gemma-4-31b-it | openrouter | In: image, text, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming, predicted_outputs | 262144 | 16384 | In: $0.09, Out: $0.34, Cache Read: $0.05 |
| ~google/gemini-flash-latest | openrouter | In: text, image, video, pdf, audio; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1048576 | 65536 | In: $0.38, Out: $1.88, Cache Read: $0.04, Cache Write: $0.02 |
| ~google/gemini-pro-latest | openrouter | In: audio, pdf, image, text, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1048576 | 65536 | In: $2.00, Out: $12.00, Cache Read: $0.20, Cache Write: $0.38 |
| google/chirp-3 | openrouter | In: audio; Out: text | streaming, structured_output, transcription | 0 | - | In: $16000.00 |
| google/gemini-2.5-flash:batch | openrouter | In: file, image, text, audio, video; Out: text | streaming, function_calling, structured_output | 1048576 | 65535 | In: $0.15, Out: $1.25, Cache Read: $0.03 |
| google/gemini-2.5-flash-lite:batch | openrouter | In: text, image, file, audio, video; Out: text | streaming, function_calling, structured_output | 1048576 | 65535 | In: $0.05, Out: $0.20, Cache Read: $0.01 |
| google/gemini-2.5-pro:batch | openrouter | In: text, image, file, audio, video; Out: text | streaming, function_calling, structured_output | 1048576 | 65536 | In: $0.62, Out: $5.00, Cache Read: $0.12 |
| google/gemini-3-flash-preview:batch | openrouter | In: text, image, file, audio, video; Out: text | streaming, function_calling, structured_output | 1048576 | 65536 | In: $0.25, Out: $1.50 |
| google/gemini-3.1-flash-lite:batch | openrouter | In: text, image, video, file, audio; Out: text | streaming, function_calling, structured_output | 1048576 | 65536 | In: $0.12, Out: $0.75, Cache Read: $0.01 |
| google/gemini-3.1-flash-tts-preview | openrouter | In: text; Out: audio | streaming, structured_output, speech_generation | 32768 | 16384 | In: $1.00, Out: $20.00 |
| google/gemini-3.1-pro-preview:batch | openrouter | In: audio, file, image, text, video; Out: text | streaming, function_calling, structured_output | 1048576 | 65536 | In: $1.00, Out: $6.00 |
| google/gemini-3.5-flash:batch | openrouter | In: text, image, video, file, audio; Out: text | streaming, function_calling, structured_output | 1048576 | 65536 | In: $0.75, Out: $4.50, Cache Read: $0.08 |
| google/gemini-3.5-flash-lite:batch | openrouter | In: text, image, video, file, audio; Out: text | streaming, function_calling, structured_output | 1048576 | 65536 | In: $0.15, Out: $1.25, Cache Read: $0.02 |
| google/gemini-3.6-flash:batch | openrouter | In: text, image, video, file, audio; Out: text | streaming, function_calling, structured_output | 1048576 | 65536 | In: $0.38, Out: $1.88, Cache Read: $0.04, Cache Write: $0.04 |
| google/gemini-3.7-flash:batch | openrouter | In: text, image, video, file, audio; Out: text | streaming, function_calling, structured_output | 1048576 | 65536 | In: $0.19, Out: $0.94, Cache Read: $0.02, Cache Write: $0.02 |
| google/gemini-embedding-001 | openrouter | In: text; Out: embeddings | streaming, structured_output | 20000 | - | In: $0.15 |
| google/gemini-embedding-2 | openrouter | In: text, image, file, audio, video; Out: embeddings | streaming, structured_output | 8192 | - | In: $0.20 |
| google/gemini-embedding-2-preview | openrouter | In: text, image, file, audio, video; Out: embeddings | streaming, structured_output | 8192 | - | In: $0.20 |
| ibm-granite/granite-4.0-h-micro | openrouter | In: text; Out: text | streaming, predicted_outputs | 131000 | 131000 | In: $0.02, Out: $0.11 |
| ibm-granite/granite-4.1-8b | openrouter | In: text; Out: text | function_calling, structured_output, streaming | 131072 | 131072 | In: $0.05, Out: $0.10, Cache Read: $0.05 |
| x-ai/grok-4.20 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 2000000 | 2000000 | In: $1.25, Out: $2.50, Cache Read: $0.20 |
| x-ai/grok-4.20-multi-agent | openrouter | In: text, image, pdf; Out: text | structured_output, reasoning, vision, streaming | 2000000 | 2000000 | In: $1.25, Out: $2.50, Cache Read: $0.20 |
| x-ai/grok-4.3 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 1000000 | In: $1.25, Out: $2.50, Cache Read: $0.20 |
| x-ai/grok-4.5 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 500000 | 500000 | In: $2.00, Out: $6.00, Cache Read: $0.30 |
| x-ai/grok-4.6 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 500000 | 500000 | In: $2.00, Out: $6.00, Cache Read: $0.50 |
| x-ai/grok-build-0.1 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 256000 | 256000 | In: $1.00, Out: $2.00, Cache Read: $0.20 |
| ~x-ai/grok-latest | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 500000 | 1000000 | In: $2.00, Out: $6.00, Cache Read: $0.50 |
| nousresearch/hermes-3-llama-3.1-405b | openrouter | In: text; Out: text | structured_output, streaming, predicted_outputs | 131072 | 16384 | In: $1.00, Out: $1.00 |
| nousresearch/hermes-3-llama-3.1-70b | openrouter | In: text; Out: text | structured_output, streaming, predicted_outputs | 131072 | 16384 | In: $0.70, Out: $0.70 |
| nousresearch/hermes-4-405b | openrouter | In: text; Out: text | reasoning, streaming | 131072 | 131072 | In: $1.00, Out: $3.00 |
| nousresearch/hermes-4-70b | openrouter | In: text; Out: text | reasoning, streaming | 131072 | 131072 | In: $0.13, Out: $0.40 |
| tencent/hunyuan-a13b-instruct | openrouter | In: text; Out: text | structured_output, reasoning, streaming | 131072 | 131072 | In: $0.14, Out: $0.57 |
| tencent/hy3 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 262144 | 128000 | In: $0.13, Out: $0.53, Cache Read: $0.03 |
| tencent/hy3-preview | openrouter | In: text; Out: text | function_calling, reasoning, streaming | 262144 | 262144 | In: $0.18, Out: $0.60, Cache Read: $0.06 |
| thinkingmachines/inkling | openrouter | In: text, image, audio; Out: text | function_calling, reasoning, vision, streaming, predicted_outputs | 1048576 | 262144 | In: $0.95, Out: $4.05, Cache Read: $0.16 |
| thinkingmachines/inkling-small | openrouter | In: text, image, audio; Out: text | function_calling, structured_output, reasoning, vision, streaming, predicted_outputs | 524288 | 262144 | In: $0.45, Out: $1.20, Cache Read: $0.10 |
| intfloat/e5-base-v2 | openrouter | In: text; Out: embeddings | streaming, structured_output | 512 | - | In: $0.01 |
| intfloat/e5-large-v2 | openrouter | In: text; Out: embeddings | streaming, structured_output | 512 | - | In: $0.01 |
| intfloat/multilingual-e5-large | openrouter | In: text; Out: embeddings | streaming, structured_output | 512 | - | In: $0.01 |
| kwaipilot/kat-coder-air-v2.5 | openrouter | In: text; Out: text | function_calling, structured_output, streaming | 256000 | 80000 | In: $0.15, Out: $0.60, Cache Read: $0.03 |
| kwaipilot/kat-coder-pro-v2 | openrouter | In: text; Out: text | function_calling, structured_output, streaming, predicted_outputs | 262144 | 80000 | In: $0.30, Out: $1.20, Cache Read: $0.06 |
| kwaipilot/kat-coder-pro-v2.5 | openrouter | In: text; Out: text | function_calling, structured_output, streaming | 256000 | 80000 | In: $0.74, Out: $2.96, Cache Read: $0.15 |
| moonshotai/kimi-k2 | openrouter | In: text; Out: text | function_calling, streaming | 131072 | 100352 | In: $0.57, Out: $2.30 |
| moonshotai/kimi-k2-0905 | openrouter | In: text; Out: text | function_calling, structured_output, streaming | 262144 | 100352 | In: $0.60, Out: $2.50 |
| moonshotai/kimi-k2-thinking | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 262144 | 100352 | In: $0.60, Out: $2.50, Cache Read: $0.15 |
| moonshotai/kimi-k2.5 | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming, predicted_outputs | 262144 | 262144 | In: $0.45, Out: $2.25, Cache Read: $0.07 |
| moonshotai/kimi-k2.6 | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming, predicted_outputs | 262144 | 262144 | In: $0.95, Out: $4.00, Cache Read: $0.16 |
| moonshotai/kimi-k2.7-code | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming, predicted_outputs | 262144 | 262144 | In: $0.71, Out: $3.50, Cache Read: $0.15 |
| moonshotai/kimi-k3 | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming, predicted_outputs | 1048576 | 1048576 | In: $3.00, Out: $15.00, Cache Read: $0.30 |
| krea/krea-2-large | openrouter | In: text, image; Out: image | streaming, image_generation | - | - | - |
| krea/krea-2-medium | openrouter | In: text, image; Out: image | streaming, image_generation | - | - | - |
| krea/krea-2-medium-turbo | openrouter | In: text, image; Out: image | streaming, image_generation | - | - | - |
| liquid/lfm-2.5-2.6b:free | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 128000 | 8192 | In: $0.00, Out: $0.00 |
| poolside/laguna-s-2.1 | openrouter | In: text; Out: text | function_calling, reasoning, streaming | 1048576 | 131072 | In: $0.09, Out: $0.18, Cache Read: $0.01 |
| poolside/laguna-s-2.1:free | openrouter | In: text; Out: text | function_calling, reasoning, streaming | 262144 | 32768 | In: $0.00, Out: $0.00 |
| poolside/laguna-xs-2.1 | openrouter | In: text; Out: text | function_calling, reasoning, streaming | 262144 | 32768 | In: $0.06, Out: $0.12, Cache Read: $0.03 |
| poolside/laguna-xs-2.1:free | openrouter | In: text; Out: text | function_calling, reasoning, streaming | 262144 | 32768 | In: $0.00, Out: $0.00 |
| inclusionai/ling-2.6-1t | openrouter | In: text; Out: text | function_calling, structured_output, streaming | 262144 | 32768 | In: $0.08, Out: $0.62, Cache Read: $0.02 |
| inclusionai/ling-2.6-flash | openrouter | In: text; Out: text | function_calling, structured_output, streaming | 262144 | 32768 | In: $0.01, Out: $0.03, Cache Read: $0.00 |
| inclusionai/ling-3.0-flash | openrouter | In: text; Out: text | function_calling, reasoning, streaming, predicted_outputs | 262144 | 32768 | In: $0.02, Out: $0.06, Cache Read: $0.00 |
| liquid/lfm-2.5-embedding-350m:free | openrouter | In: text; Out: embeddings | streaming | 512 | - | - |
| sao10k/l3-lunaris-8b | openrouter | In: text; Out: text | structured_output, streaming, predicted_outputs | 8192 | 16384 | In: $0.04, Out: $0.05 |
| meta-llama/llama-3.1-70b-instruct | openrouter | In: text; Out: text | function_calling, structured_output, streaming, predicted_outputs | 131072 | 16384 | In: $0.40, Out: $0.40 |
| sao10k/l3.1-euryale-70b | openrouter | In: text; Out: text | function_calling, structured_output, streaming, predicted_outputs | 131072 | 16384 | In: $0.85, Out: $0.85 |
| meta-llama/llama-3.2-1b-instruct | openrouter | In: text; Out: text | streaming, predicted_outputs | 60000 | 60000 | In: $0.03, Out: $0.20 |
| meta-llama/llama-3.2-3b-instruct | openrouter | In: text; Out: text | structured_output, streaming, predicted_outputs | 131072 | 131072 | In: $0.05, Out: $0.33 |
| sao10k/l3.3-euryale-70b | openrouter | In: text; Out: text | structured_output, streaming | 131072 | 16384 | In: $0.65, Out: $0.75 |
| meta-llama/llama-4-maverick | openrouter | In: text, image; Out: text | function_calling, structured_output, vision, streaming, predicted_outputs | 1048576 | 16384 | In: $0.20, Out: $0.80 |
| meta-llama/llama-4-scout | openrouter | In: text, image; Out: text | function_calling, structured_output, vision, streaming, predicted_outputs | 1310720 | 16384 | In: $0.10, Out: $0.30 |
| meta-llama/llama-guard-4-12b | openrouter | In: image, text; Out: text | vision, streaming, predicted_outputs | 1048576 | 16384 | In: $0.18, Out: $0.18 |
| meta-llama/llama-3.1-8b-instruct | openrouter | In: text; Out: text | function_calling, structured_output, streaming, predicted_outputs | 131072 | 131072 | In: $0.05, Out: $0.08, Cache Read: $0.02 |
| meta-llama/llama-3.3-70b-instruct | openrouter | In: text; Out: text | function_calling, structured_output, streaming, predicted_outputs | 131072 | 16384 | In: $0.10, Out: $0.32 |
| meituan/longcat-2.0 | openrouter | In: text; Out: text | function_calling, reasoning, streaming, predicted_outputs | 1048756 | 262144 | In: $0.30, Out: $1.20, Cache Read: $0.01 |
| google/lyria-3-clip-preview | openrouter | In: text, image; Out: text, audio | vision, streaming | 1048576 | 65536 | In: $0.00, Out: $0.00 |
| google/lyria-3-pro-preview | openrouter | In: text, image; Out: text, audio | vision, streaming | 1048576 | 65536 | In: $0.00, Out: $0.00 |
| anthracite-org/magnum-v4-72b | openrouter | In: text; Out: text | structured_output, streaming, predicted_outputs | 32768 | 4096 | In: $3.00, Out: $5.00 |
| inception/mercury-2 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 128000 | 50000 | In: $0.25, Out: $0.75, Cache Read: $0.02 |
| xiaomi/mimo-v2.5 | openrouter | In: text, image, audio, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming, predicted_outputs | 1050000 | 131072 | In: $0.14, Out: $0.28, Cache Read: $0.00 |
| xiaomi/mimo-v2.5-pro | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 1050000 | 131072 | In: $0.44, Out: $0.87, Cache Read: $0.00 |
| microsoft/mai-image-2.5 | openrouter | In: text, image; Out: image | streaming, image_generation | - | - | - |
| microsoft/mai-image-2.5-pro | openrouter | In: text, image; Out: image | streaming, image_generation | - | - | - |
| microsoft/mai-transcribe-1.5 | openrouter | In: audio; Out: text | streaming, transcription | 0 | - | In: $360000.00 |
| microsoft/mai-voice-2 | openrouter | In: text; Out: audio | streaming, speech_generation | 0 | - | In: $22.00 |
| microsoft/mai-voice-2-flash | openrouter | In: text; Out: audio | streaming, speech_generation | 0 | - | In: $15.00 |
| minimax/minimax-m1 | openrouter | In: text; Out: text | function_calling, reasoning, streaming | 1000000 | 40000 | In: $0.55, Out: $2.20 |
| minimax/minimax-01 | openrouter | In: text, image; Out: text | vision, streaming | 1000192 | 1000192 | In: $0.20, Out: $1.10 |
| minimax/minimax-m2 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 204800 | 131072 | In: $0.26, Out: $1.02 |
| minimax/minimax-m2-her | openrouter | In: text; Out: text | streaming | 65536 | 2048 | In: $0.30, Out: $1.20, Cache Read: $0.03 |
| minimax/minimax-m2.1 | openrouter | In: text; Out: text | function_calling, reasoning, streaming | 204800 | 131072 | In: $0.30, Out: $1.20, Cache Read: $0.03 |
| minimax/minimax-m2.5 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 204800 | 196608 | In: $0.22, Out: $0.90, Cache Read: $0.06 |
| minimax/minimax-m2.7 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 204800 | 131072 | In: $0.30, Out: $1.20, Cache Read: $0.06 |
| minimax/minimax-m3 | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming, predicted_outputs | 1048576 | 512000 | In: $0.30, Out: $1.20, Cache Read: $0.06 |
| minimax/minimax-m3:batch | openrouter | In: text, image, video; Out: text | streaming, function_calling, structured_output, predicted_outputs | 524288 | - | In: $0.30, Out: $1.20, Cache Read: $0.06 |
| minimax/speech-2.8-hd | openrouter | In: text; Out: audio | streaming, speech_generation | 0 | - | In: $100.00 |
| minimax/speech-2.8-turbo | openrouter | In: text; Out: audio | streaming, speech_generation | 0 | - | In: $60.00 |
| mistralai/ministral-14b-2512 | openrouter | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 262144 | 262144 | In: $0.20, Out: $0.20, Cache Read: $0.02 |
| mistralai/ministral-3b-2512 | openrouter | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 131072 | 131072 | In: $0.10, Out: $0.10, Cache Read: $0.01 |
| mistralai/ministral-8b-2512 | openrouter | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 262144 | 262144 | In: $0.15, Out: $0.15, Cache Read: $0.02 |
| mistralai/mistral-large | openrouter | In: text, pdf; Out: text | function_calling, structured_output, vision, streaming | 128000 | 128000 | In: $2.00, Out: $6.00, Cache Read: $0.20 |
| mistralai/mistral-large-2407 | openrouter | In: text, pdf; Out: text | function_calling, structured_output, vision, streaming | 131072 | 131072 | In: $2.00, Out: $6.00, Cache Read: $0.20 |
| mistralai/mistral-large-2512 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, vision, streaming | 262144 | 262144 | In: $0.50, Out: $1.50, Cache Read: $0.05 |
| mistralai/mistral-medium-3 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, vision, streaming | 131072 | 131072 | In: $0.40, Out: $2.00, Cache Read: $0.04 |
| mistralai/mistral-medium-3.1 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, vision, streaming | 131072 | 262144 | In: $0.40, Out: $2.00, Cache Read: $0.04 |
| mistralai/mistral-medium-3-5 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 262144 | 262144 | In: $1.50, Out: $7.50 |
| mistralai/mistral-nemo | openrouter | In: text; Out: text | function_calling, structured_output, streaming, predicted_outputs | 131072 | 16384 | In: $0.02, Out: $0.03 |
| mistralai/mistral-small-24b-instruct-2501 | openrouter | In: text; Out: text | structured_output, streaming, predicted_outputs | 32768 | 16384 | In: $0.05, Out: $0.08 |
| mistralai/mistral-small-3.1-24b-instruct | openrouter | In: text, image; Out: text | vision, streaming, predicted_outputs | 128000 | 128000 | In: $0.35, Out: $0.56 |
| mistralai/mistral-small-3.2-24b-instruct | openrouter | In: image, text; Out: text | function_calling, structured_output, vision, streaming, predicted_outputs | 256000 | 16384 | In: $0.09, Out: $0.25 |
| mistralai/mistral-small-2603 | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 262144 | 262144 | In: $0.15, Out: $0.60, Cache Read: $0.02 |
| mistralai/codestral-embed-2505 | openrouter | In: text; Out: embeddings | streaming, structured_output | 8192 | - | In: $0.15 |
| mistralai/mistral-embed-2312 | openrouter | In: text; Out: embeddings | streaming, structured_output | 8192 | - | In: $0.10 |
| mistralai/voxtral-mini-3b-2507 | openrouter | In: audio; Out: text | streaming, structured_output, transcription | 0 | - | In: $16.67 |
| mistralai/voxtral-mini-tts-2603 | openrouter | In: text; Out: audio | streaming, structured_output, speech_generation | 4096 | - | In: $16.00 |
| mistralai/voxtral-mini-transcribe | openrouter | In: audio; Out: text | streaming, structured_output, transcription | 0 | - | In: $3000.00 |
| mistralai/voxtral-small-24b-2507-stt | openrouter | In: audio; Out: text | streaming, structured_output, transcription | 0 | - | In: $50.00 |
| mistralai/mixtral-8x22b-instruct | openrouter | In: text, pdf; Out: text | function_calling, structured_output, vision, streaming | 65536 | 65536 | In: $2.00, Out: $6.00, Cache Read: $0.20 |
| ~moonshotai/kimi-latest | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming, predicted_outputs | 1048576 | 974842 | In: $2.60, Out: $13.00, Cache Read: $0.29 |
| moonshotai/kimi-k2.7-code:batch | openrouter | In: text, image; Out: text | streaming, function_calling, structured_output, predicted_outputs | 262144 | - | In: $0.95, Out: $4.00, Cache Read: $0.19 |
| morph/morph-v3-fast | openrouter | In: text; Out: text | streaming | 81920 | 38000 | In: $0.80, Out: $1.20 |
| morph/morph-v3-large | openrouter | In: text; Out: text | structured_output, streaming | 262144 | 131072 | In: $0.90, Out: $1.90 |
| meta/muse-glimmer-30b | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming, predicted_outputs | 131072 | 131072 | In: $0.35, Out: $1.50, Cache Read: $0.04 |
| meta/muse-spark-1.1 | openrouter | In: text, image, video, pdf, audio; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1048576 | 1048576 | In: $1.25, Out: $4.25, Cache Read: $0.15 |
| meta/muse-spark-1.2 | openrouter | In: text, image, video, pdf, audio; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1048576 | 1048576 | In: $1.25, Out: $4.25, Cache Read: $0.15 |
| gryphe/mythomax-l2-13b | openrouter | In: text; Out: text | structured_output, streaming, predicted_outputs | 8192 | 4096 | In: $0.06, Out: $0.06 |
| nvidia/llama-nemotron-embed-vl-1b-v2:free | openrouter | In: text, image; Out: embeddings | streaming | 131072 | - | - |
| nvidia/llama-nemotron-rerank-vl-1b-v2:free | openrouter | In: text, image; Out: rerank | streaming | 10240 | - | - |
| nvidia/nemotron-3-embed-1b:free | openrouter | In: text; Out: embeddings | streaming | 32768 | - | - |
| nvidia/nemotron-3-ultra-550b-a55b:batch | openrouter | In: text; Out: text | streaming, function_calling, structured_output, predicted_outputs | 512288 | - | In: $0.60, Out: $3.60, Cache Read: $0.20 |
| nvidia/nemotron-3.5-asr-streaming-multilingual-0.6b | openrouter | In: audio; Out: text | streaming, structured_output, transcription | 0 | - | In: $3.33 |
| nvidia/parakeet-tdt-0.6b-v3 | openrouter | In: audio; Out: text | streaming, predicted_outputs, transcription | 0 | - | In: $1500.00 |
| google/gemini-2.5-flash-image | openrouter | In: text, image; Out: text, image | structured_output, vision, streaming, image_generation | 32768 | 8192 | In: $0.30, Out: $2.50, Cache Read: $0.03, Cache Write: $0.08 |
| google/gemini-3.1-flash-image | openrouter | In: image, text; Out: text, image | structured_output, reasoning, vision, streaming, image_generation | 131072 | 32768 | In: $0.50, Out: $3.00 |
| google/gemini-3.1-flash-image-preview | openrouter | In: image, text; Out: text, image | structured_output, reasoning, vision, streaming, image_generation | 65536 | 65536 | In: $0.50, Out: $3.00 |
| google/gemini-3.1-flash-lite-image | openrouter | In: text, image; Out: text, image | reasoning, vision, streaming, image_generation | 65536 | 65536 | In: $0.25, Out: $1.50 |
| google/gemini-3-pro-image | openrouter | In: text, image; Out: text, image | function_calling, structured_output, reasoning, vision, streaming, image_generation | 131072 | 32768 | In: $2.00, Out: $12.00, Cache Read: $0.20, Cache Write: $0.38 |
| google/gemini-3-pro-image-preview | openrouter | In: text, image; Out: text, image | structured_output, reasoning, vision, streaming, image_generation | 65536 | 32768 | In: $2.00, Out: $12.00, Cache Read: $0.20, Cache Write: $0.38 |
| nvidia/nemotron-3-nano-30b-a3b | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 262144 | 262144 | In: $0.05, Out: $0.20, Cache Read: $0.03 |
| nvidia/nemotron-3-nano-30b-a3b:free | openrouter | In: text; Out: text | function_calling, reasoning, streaming | 256000 | 256000 | In: $0.00, Out: $0.00 |
| nvidia/nemotron-3-nano-omni-30b-a3b-reasoning:free | openrouter | In: text, image, video, audio; Out: text | function_calling, reasoning, vision, video, streaming | 256000 | 65536 | In: $0.00, Out: $0.00 |
| nvidia/nemotron-3-super-120b-a12b:free | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 262144 | 262144 | In: $0.00, Out: $0.00 |
| nvidia/nemotron-3-super-120b-a12b | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 1000000 | 16384 | In: $0.08, Out: $0.40 |
| nvidia/nemotron-3-ultra-550b-a55b:free | openrouter | In: text; Out: text | function_calling, reasoning, streaming | 1000000 | 65536 | In: $0.00, Out: $0.00 |
| nvidia/nemotron-3-ultra-550b-a55b | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 512288 | 16384 | In: $0.60, Out: $3.60, Cache Read: $0.20 |
| nvidia/nemotron-3.5-content-safety:free | openrouter | In: text, image; Out: text | reasoning, vision, streaming | 128000 | 8192 | In: $0.00, Out: $0.00 |
| nvidia/nemotron-3.5-lightning:free | openrouter | In: text; Out: text | function_calling, reasoning, streaming | 1000000 | 65536 | In: $0.00, Out: $0.00 |
| nvidia/nemotron-3.5-lightning | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 1000000 | 131072 | In: $0.08, Out: $0.20, Cache Read: $0.04 |
| nvidia/nemotron-nano-12b-v2-vl:free | openrouter | In: text, image, video; Out: text | function_calling, reasoning, vision, video, streaming | 128000 | 128000 | In: $0.00, Out: $0.00 |
| nvidia/nemotron-nano-9b-v2:free | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 128000 | 128000 | In: $0.00, Out: $0.00 |
| nex-agi/nex-n2-mini | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 262144 | 262144 | In: $0.02, Out: $0.10, Cache Read: $0.00 |
| nex-agi/nex-n2-pro | openrouter | In: text, image; Out: text | function_calling, reasoning, vision, streaming | 262144 | 262144 | In: $0.25, Out: $1.00, Cache Read: $0.02 |
| cohere/north-mini-code:free | openrouter | In: text; Out: text | function_calling, reasoning, streaming | 256000 | 64000 | In: $0.00, Out: $0.00 |
| amazon/nova-2-lite-v1 | openrouter | In: text, image, video, pdf; Out: text | function_calling, reasoning, vision, video, streaming | 1000000 | 65535 | In: $0.30, Out: $2.50 |
| amazon/nova-lite-v1 | openrouter | In: text, image; Out: text | function_calling, vision, streaming | 300000 | 5120 | In: $0.06, Out: $0.24 |
| amazon/nova-micro-v1 | openrouter | In: text; Out: text | function_calling, streaming | 128000 | 5120 | In: $0.04, Out: $0.14 |
| amazon/nova-premier-v1 | openrouter | In: text, image; Out: text | function_calling, vision, streaming | 1000000 | 32000 | In: $2.50, Out: $12.50, Cache Read: $0.62 |
| amazon/nova-pro-v1 | openrouter | In: text, image; Out: text | function_calling, vision, streaming | 300000 | 5120 | In: $0.80, Out: $3.20 |
| allenai/olmo-3-32b-think | openrouter | In: text; Out: text | structured_output, reasoning, streaming, predicted_outputs | 65536 | 65536 | In: $0.15, Out: $0.50 |
| ~openai/gpt-latest | openrouter | In: pdf, image, text; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1050000 | 128000 | In: $2.50, Out: $15.00, Cache Read: $0.25, Cache Write: $3.12 |
| ~openai/gpt-mini-latest | openrouter | In: pdf, image, text; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $0.75, Out: $4.50, Cache Read: $0.08 |
| openai/gpt-image-1 | openrouter | In: text, image; Out: image | streaming, image_generation | - | - | - |
| openai/gpt-image-1-mini | openrouter | In: text, image; Out: image | streaming, image_generation | - | - | - |
| openai/gpt-image-2 | openrouter | In: text, image; Out: image | streaming, image_generation | - | - | - |
| openai/gpt-transcribe | openrouter | In: audio; Out: text | streaming, structured_output, transcription | 0 | - | In: $4500.00 |
| openai/gpt-3.5-turbo:batch | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 16385 | 4096 | In: $0.25, Out: $0.75 |
| openai/gpt-4-turbo:batch | openrouter | In: text, image; Out: text | streaming, function_calling, structured_output | 128000 | 4096 | In: $5.00, Out: $15.00 |
| openai/gpt-4.1:batch | openrouter | In: image, text, file; Out: text | streaming, function_calling, structured_output | 1047576 | 32768 | In: $1.00, Out: $4.00, Cache Read: $0.25 |
| openai/gpt-4.1-mini:batch | openrouter | In: image, text, file; Out: text | streaming, function_calling, structured_output | 1047576 | 32768 | In: $0.20, Out: $0.80, Cache Read: $0.05 |
| openai/gpt-4.1-nano:batch | openrouter | In: image, text, file; Out: text | streaming, function_calling, structured_output | 1047576 | 32768 | In: $0.05, Out: $0.20, Cache Read: $0.01 |
| openai/gpt-4o:batch | openrouter | In: text, image, file; Out: text | streaming, function_calling, structured_output | 128000 | 16384 | In: $1.25, Out: $5.00, Cache Read: $0.62 |
| openai/gpt-4o-mini-transcribe | openrouter | In: audio; Out: text | streaming, structured_output, transcription | 128000 | - | In: $1.25, Out: $5.00 |
| openai/gpt-4o-transcribe | openrouter | In: audio; Out: text | streaming, structured_output, transcription | 128000 | - | In: $2.50, Out: $10.00 |
| openai/gpt-4o-mini:batch | openrouter | In: text, image, file; Out: text | streaming, function_calling, structured_output | 128000 | 16384 | In: $0.08, Out: $0.30, Cache Read: $0.04 |
| openai/gpt-5:batch | openrouter | In: text, image, file; Out: text | streaming, function_calling, structured_output | 400000 | 128000 | In: $0.62, Out: $5.00, Cache Read: $0.06 |
| openai/gpt-5-codex:batch | openrouter | In: text, image; Out: text | streaming, function_calling, structured_output | 400000 | 128000 | In: $0.62, Out: $5.00, Cache Read: $0.06 |
| openai/gpt-5-mini:batch | openrouter | In: text, image, file; Out: text | streaming, function_calling, structured_output | 400000 | 128000 | In: $0.12, Out: $1.00, Cache Read: $0.01 |
| openai/gpt-5-nano:batch | openrouter | In: text, image, file; Out: text | streaming, function_calling, structured_output | 400000 | 128000 | In: $0.02, Out: $0.20, Cache Read: $0.00 |
| openai/gpt-5-pro:batch | openrouter | In: image, text, file; Out: text | streaming, function_calling, structured_output | 400000 | 128000 | In: $7.50, Out: $60.00 |
| openai/gpt-5.1:batch | openrouter | In: image, text, file; Out: text | streaming, function_calling, structured_output | 400000 | 128000 | In: $0.62, Out: $5.00, Cache Read: $0.06 |
| openai/gpt-5.2:batch | openrouter | In: file, image, text; Out: text | streaming, function_calling, structured_output | 400000 | 128000 | In: $0.88, Out: $7.00, Cache Read: $0.09 |
| openai/gpt-5.2-pro:batch | openrouter | In: image, text, file; Out: text | streaming, function_calling, structured_output | 400000 | 128000 | In: $10.50, Out: $84.00 |
| openai/gpt-5.4:batch | openrouter | In: text, image, file; Out: text | streaming, function_calling, structured_output | 1050000 | 128000 | In: $1.25, Out: $7.50, Cache Read: $0.12 |
| openai/gpt-5.4-mini:batch | openrouter | In: file, image, text; Out: text | streaming, function_calling, structured_output | 400000 | 128000 | In: $0.38, Out: $2.25, Cache Read: $0.04 |
| openai/gpt-5.4-nano:batch | openrouter | In: file, image, text; Out: text | streaming, function_calling, structured_output | 400000 | 128000 | In: $0.10, Out: $0.62, Cache Read: $0.01 |
| openai/gpt-5.4-pro:batch | openrouter | In: text, image, file; Out: text | streaming, function_calling, structured_output | 1050000 | 128000 | In: $15.00, Out: $90.00 |
| openai/gpt-5.5:batch | openrouter | In: file, image, text; Out: text | streaming, function_calling, structured_output | 1050000 | 128000 | In: $2.50, Out: $15.00, Cache Read: $0.25 |
| openai/gpt-5.5-pro:batch | openrouter | In: file, image, text; Out: text | streaming, function_calling, structured_output | 1050000 | 128000 | In: $15.00, Out: $90.00 |
| openai/gpt-5.6-luna:batch | openrouter | In: file, image, text; Out: text | streaming, function_calling, structured_output | 1050000 | 128000 | In: $0.10, Out: $0.60, Cache Read: $0.01 |
| openai/gpt-5.6-luna-pro:batch | openrouter | In: file, image, text; Out: text | streaming, function_calling, structured_output | 1050000 | 128000 | In: $0.10, Out: $0.60, Cache Read: $0.01 |
| openai/gpt-5.6-sol:batch | openrouter | In: file, image, text; Out: text | streaming, function_calling, structured_output | 1050000 | 128000 | In: $1.25, Out: $7.50, Cache Read: $0.12 |
| openai/gpt-5.6-sol-pro:batch | openrouter | In: file, image, text; Out: text | streaming, function_calling, structured_output | 1050000 | 128000 | In: $1.25, Out: $7.50, Cache Read: $0.12 |
| openai/gpt-5.6-terra:batch | openrouter | In: file, image, text; Out: text | streaming, function_calling, structured_output | 1050000 | 128000 | In: $1.00, Out: $6.00, Cache Read: $0.10 |
| openai/gpt-5.6-terra-pro:batch | openrouter | In: file, image, text; Out: text | streaming, function_calling, structured_output | 1050000 | 128000 | In: $1.00, Out: $6.00, Cache Read: $0.10 |
| openai/text-embedding-3-large | openrouter | In: text; Out: embeddings | streaming, structured_output | 8192 | - | In: $0.13 |
| openai/text-embedding-3-small | openrouter | In: text; Out: embeddings | streaming, structured_output | 8192 | - | In: $0.02 |
| openai/text-embedding-ada-002 | openrouter | In: text; Out: embeddings | streaming, structured_output | 8192 | - | In: $0.10 |
| openai/whisper-1 | openrouter | In: audio; Out: text | streaming, structured_output, transcription | 0 | - | In: $6000.00 |
| openai/whisper-large-v3 | openrouter | In: audio; Out: text | streaming, structured_output, predicted_outputs, transcription | 0 | - | In: $7.50 |
| openai/whisper-large-v3-turbo | openrouter | In: audio; Out: text | streaming, structured_output, transcription | 0 | - | In: $3.33 |
| openai/o1:batch | openrouter | In: text, image, file; Out: text | streaming, function_calling, structured_output | 200000 | 100000 | In: $7.50, Out: $30.00, Cache Read: $3.75 |
| openai/o1-pro:batch | openrouter | In: text, image, file; Out: text | streaming, structured_output | 200000 | 100000 | In: $75.00, Out: $300.00 |
| openai/o3:batch | openrouter | In: image, text, file; Out: text | streaming, function_calling, structured_output | 200000 | 100000 | In: $1.00, Out: $4.00, Cache Read: $0.25 |
| openai/o3-mini:batch | openrouter | In: text, file; Out: text | streaming, function_calling, structured_output | 200000 | 100000 | In: $0.55, Out: $2.20, Cache Read: $0.28 |
| openai/o3-mini-high:batch | openrouter | In: text, file; Out: text | streaming, function_calling, structured_output | 200000 | 100000 | In: $0.55, Out: $2.20, Cache Read: $0.28 |
| openai/o3-pro:batch | openrouter | In: text, file, image; Out: text | streaming, function_calling, structured_output | 200000 | 100000 | In: $10.00, Out: $40.00 |
| openai/o4-mini:batch | openrouter | In: image, text, file; Out: text | streaming, function_calling, structured_output | 200000 | 100000 | In: $0.55, Out: $2.20, Cache Read: $0.14 |
| openai/o4-mini-high:batch | openrouter | In: image, text, file; Out: text | streaming, function_calling, structured_output | 200000 | 100000 | In: $0.55, Out: $2.20, Cache Read: $0.14 |
| writer/palmyra-x5 | openrouter | In: text; Out: text | streaming | 1040000 | 8192 | In: $0.60, Out: $6.00 |
| openrouter/pareto-code | openrouter | In: text; Out: text | streaming | 2000000 | 200000 | - |
| perceptron/perceptron-mk1 | openrouter | In: text, image, video; Out: text | structured_output, reasoning, vision, video, streaming | 32768 | 8192 | In: $0.15, Out: $1.50 |
| perplexity/pplx-embed-v1-0.6b | openrouter | In: text; Out: embeddings | streaming | 32000 | - | In: $0.00 |
| perplexity/pplx-embed-v1-4b | openrouter | In: text; Out: embeddings | streaming | 32000 | - | In: $0.03 |
| microsoft/phi-4 | openrouter | In: text; Out: text | structured_output, streaming, predicted_outputs | 16384 | 16384 | In: $0.07, Out: $0.14 |
| qwen/qwen-plus | openrouter | In: text; Out: text | function_calling, structured_output, streaming | 1000000 | 32768 | In: $0.26, Out: $0.78, Cache Read: $0.05, Cache Write: $0.32 |
| qwen/qwen-plus-2025-07-28 | openrouter | In: text; Out: text | function_calling, structured_output, streaming | 1000000 | 32768 | In: $0.26, Out: $0.78 |
| qwen/qwen-plus-2025-07-28:thinking | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 1000000 | 32768 | In: $0.26, Out: $0.78 |
| qwen/qwen-2.5-72b-instruct | openrouter | In: text; Out: text | function_calling, structured_output, streaming, predicted_outputs | 32768 | 16384 | In: $0.36, Out: $0.40 |
| qwen/qwen-2.5-7b-instruct | openrouter | In: text; Out: text | function_calling, structured_output, streaming, predicted_outputs | 32768 | 32768 | In: $0.10, Out: $0.20 |
| qwen/qwen-2.5-coder-32b-instruct | openrouter | In: text; Out: text | streaming, predicted_outputs | 32768 | 32768 | In: $0.66, Out: $1.00 |
| qwen/qwen2.5-vl-72b-instruct | openrouter | In: text, image; Out: text | structured_output, vision, streaming, predicted_outputs | 128000 | 128000 | In: $0.80, Out: $1.00, Cache Read: $0.40 |
| qwen/qwen3-14b | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 131072 | 16384 | In: $0.12, Out: $0.24 |
| qwen/qwen3-235b-a22b-2507 | openrouter | In: text; Out: text | function_calling, structured_output, streaming, predicted_outputs | 262144 | 16384 | In: $0.09, Out: $0.55 |
| qwen/qwen3-235b-a22b-thinking-2507 | openrouter | In: text; Out: text | function_calling, reasoning, streaming, predicted_outputs | 262144 | 32768 | In: $0.23, Out: $2.30 |
| qwen/qwen3-235b-a22b | openrouter | In: text; Out: text | function_calling, reasoning, streaming | 131072 | 8192 | In: $0.46, Out: $1.82 |
| qwen/qwen3-30b-a3b | openrouter | In: text; Out: text | function_calling, reasoning, streaming, predicted_outputs | 131072 | 8192 | In: $0.13, Out: $0.52 |
| qwen/qwen3-30b-a3b-instruct-2507 | openrouter | In: text; Out: text | function_calling, structured_output, streaming, predicted_outputs | 262144 | 32000 | In: $0.05, Out: $0.19 |
| qwen/qwen3-30b-a3b-thinking-2507 | openrouter | In: text; Out: text | function_calling, reasoning, streaming | 81920 | 32768 | In: $0.20, Out: $2.40 |
| qwen/qwen3-32b | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 131072 | 16384 | In: $0.08, Out: $0.28 |
| qwen/qwen3-8b | openrouter | In: text; Out: text | function_calling, reasoning, streaming | 131072 | 8192 | In: $0.12, Out: $0.46 |
| qwen/qwen3-coder | openrouter | In: text; Out: text | function_calling, structured_output, streaming, predicted_outputs | 262144 | 65536 | In: $0.30, Out: $1.00, Cache Read: $0.10 |
| qwen/qwen3-coder-flash | openrouter | In: text; Out: text | function_calling, streaming | 1000000 | 65536 | In: $0.20, Out: $0.98, Cache Read: $0.04, Cache Write: $0.24 |
| qwen/qwen3-coder-next | openrouter | In: text; Out: text | function_calling, structured_output, streaming, predicted_outputs | 262144 | 262144 | In: $0.12, Out: $0.80, Cache Read: $0.07 |
| qwen/qwen3-coder-plus | openrouter | In: text; Out: text | function_calling, structured_output, streaming | 1000000 | 65536 | In: $0.65, Out: $3.25, Cache Read: $0.13, Cache Write: $0.81 |
| qwen/qwen3-max | openrouter | In: text; Out: text | function_calling, structured_output, streaming | 262144 | 65536 | In: $0.78, Out: $3.90, Cache Read: $0.16, Cache Write: $0.98 |
| qwen/qwen3-max-thinking | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 262144 | 65536 | In: $0.78, Out: $3.90 |
| qwen/qwen3-reranker-8b | openrouter | In: text; Out: rerank | streaming, structured_output, predicted_outputs | 40960 | - | - |
| qwen/qwen3-vl-235b-a22b-instruct | openrouter | In: text, image; Out: text | function_calling, structured_output, vision, streaming, predicted_outputs | 262144 | 32768 | In: $0.21, Out: $1.90, Cache Read: $0.10 |
| qwen/qwen3-vl-235b-a22b-thinking | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 131072 | 32768 | In: $0.40, Out: $4.00 |
| qwen/qwen3-vl-30b-a3b-instruct | openrouter | In: text, image; Out: text | function_calling, structured_output, vision, streaming, predicted_outputs | 262144 | 32768 | In: $0.13, Out: $0.52 |
| qwen/qwen3-vl-30b-a3b-thinking | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 262144 | 32768 | In: $0.20, Out: $2.40 |
| qwen/qwen3-vl-32b-instruct | openrouter | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 131072 | 32768 | In: $0.10, Out: $0.42 |
| qwen/qwen3-vl-8b-instruct | openrouter | In: image, text; Out: text | function_calling, structured_output, vision, streaming, predicted_outputs | 262144 | 32768 | In: $0.12, Out: $0.46 |
| qwen/qwen3-vl-8b-thinking | openrouter | In: image, text; Out: text | function_calling, structured_output, reasoning, vision, streaming | 131072 | 32768 | In: $0.18, Out: $2.10 |
| qwen/qwen3-coder-30b-a3b-instruct | openrouter | In: text; Out: text | function_calling, structured_output, streaming | 262144 | 262144 | In: $0.07, Out: $0.28 |
| qwen/qwen3-next-80b-a3b-thinking | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 262144 | 32768 | In: $0.15, Out: $1.20 |
| qwen/qwen3-next-80b-a3b-instruct | openrouter | In: text; Out: text | function_calling, structured_output, streaming, predicted_outputs | 262144 | 16384 | In: $0.09, Out: $1.10 |
| qwen/qwen3.5-122b-a10b | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming, predicted_outputs | 262144 | 262144 | In: $0.26, Out: $2.08 |
| qwen/qwen3.5-27b | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming, predicted_outputs | 262144 | 65536 | In: $0.20, Out: $1.56 |
| qwen/qwen3.5-35b-a3b | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming, predicted_outputs | 262144 | 262144 | In: $0.25, Out: $1.25, Cache Read: $0.25 |
| qwen/qwen3.5-397b-a17b | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming, predicted_outputs | 262144 | 65536 | In: $0.39, Out: $2.34 |
| qwen/qwen3.5-9b | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming, predicted_outputs | 262144 | 262144 | In: $0.10, Out: $0.15 |
| qwen/qwen3.5-plus-02-15 | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1000000 | 65536 | In: $0.26, Out: $1.56 |
| qwen/qwen3.5-plus-20260420 | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1000000 | 65536 | In: $0.30, Out: $1.80, Cache Write: $0.38 |
| qwen/qwen3.5-flash-02-23 | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1000000 | 65536 | In: $0.06, Out: $0.26 |
| qwen/qwen3.6-27b | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming, predicted_outputs | 262144 | 262144 | In: $0.60, Out: $3.60, Cache Read: $0.12 |
| qwen/qwen3.6-35b-a3b | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming, predicted_outputs | 262144 | 262144 | In: $0.14, Out: $1.00, Cache Read: $0.05 |
| qwen/qwen3.6-flash | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1000000 | 65536 | In: $0.19, Out: $1.12, Cache Write: $0.23 |
| qwen/qwen3.6-max-preview | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 262144 | 65536 | In: $1.03, Out: $6.16, Cache Write: $1.28 |
| qwen/qwen3.6-plus | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1000000 | 65536 | In: $0.32, Out: $1.95, Cache Write: $0.41 |
| qwen/qwen3.7-flash | openrouter | In: text, image, video; Out: text | function_calling, reasoning, vision, video, streaming | 1000000 | 65536 | In: $0.03, Out: $0.13, Cache Read: $0.01, Cache Write: $0.04 |
| qwen/qwen3.7-max | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 1000000 | 131072 | In: $1.48, Out: $4.42, Cache Read: $0.30, Cache Write: $1.84 |
| qwen/qwen3.7-plus | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 131072 | In: $0.32, Out: $1.28, Cache Read: $0.06, Cache Write: $0.40 |
| qwen/qwen3.8-2.4t-a95b | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 1048576 | 262144 | In: $2.00, Out: $6.00, Cache Read: $0.25 |
| qwen/qwen3.8-27b | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming, predicted_outputs | 1000000 | 131072 | In: $0.45, Out: $3.20, Cache Read: $0.05 |
| qwen/qwen3.8-max | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1000000 | 131072 | In: $2.00, Out: $6.00, Cache Read: $0.25, Cache Write: $2.50 |
| qwen/qwen-image-3 | openrouter | In: text, image; Out: image | streaming, image_generation | - | - | - |
| qwen/qwen-image-3-pro | openrouter | In: text, image; Out: image | streaming, image_generation | - | - | - |
| qwen/qwen-audio-3.0-tts-flash | openrouter | In: text; Out: audio | streaming, structured_output, speech_generation | 0 | - | In: $15.00 |
| qwen/qwen-audio-3.0-tts-plus | openrouter | In: text; Out: audio | streaming, structured_output, speech_generation | 0 | - | In: $20.00 |
| qwen/qwen3-asr-0.6b | openrouter | In: audio; Out: text | streaming, structured_output, transcription | 0 | - | In: $3.33 |
| qwen/qwen3-asr-1.7b | openrouter | In: audio; Out: text | streaming, structured_output, transcription | 0 | - | In: $7.50 |
| qwen/qwen3-asr-flash-2026-02-10 | openrouter | In: audio; Out: text | streaming, structured_output, transcription | 0 | - | In: $35.00 |
| qwen/qwen3-embedding-4b | openrouter | In: text; Out: embeddings | streaming, structured_output | 32768 | - | In: $0.02 |
| qwen/qwen3-embedding-8b | openrouter | In: text; Out: embeddings | streaming, structured_output, predicted_outputs | 32768 | 32000 | In: $0.01 |
| deepseek/deepseek-r1-0528 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 163840 | 32768 | In: $0.50, Out: $2.15, Cache Read: $0.35 |
| deepseek/deepseek-r1-distill-llama-70b | openrouter | In: text; Out: text | reasoning, streaming | 8192 | 8192 | In: $0.80, Out: $0.80 |
| undi95/remm-slerp-l2-13b | openrouter | In: text; Out: text | structured_output, streaming, predicted_outputs | 6144 | 6144 | In: $0.45, Out: $0.65 |
| recraft/recraft-v3 | openrouter | In: text, image; Out: image | streaming, image_generation | - | - | - |
| recraft/recraft-v4 | openrouter | In: text, image; Out: image | streaming, image_generation | - | - | - |
| recraft/recraft-v4-pro | openrouter | In: text, image; Out: image | streaming, image_generation | - | - | - |
| recraft/recraft-v4-pro-vector | openrouter | In: text, image; Out: image | streaming, image_generation | - | - | - |
| recraft/recraft-v4-vector | openrouter | In: text, image; Out: image | streaming, image_generation | - | - | - |
| recraft/recraft-v4.1 | openrouter | In: text, image; Out: image | streaming, image_generation | - | - | - |
| recraft/recraft-v4.1-pro | openrouter | In: text, image; Out: image | streaming, image_generation | - | - | - |
| recraft/recraft-v4.1-pro-vector | openrouter | In: text, image; Out: image | streaming, image_generation | - | - | - |
| recraft/recraft-v4.1-utility | openrouter | In: text, image; Out: image | streaming, image_generation | - | - | - |
| recraft/recraft-v4.1-utility-pro | openrouter | In: text, image; Out: image | streaming, image_generation | - | - | - |
| recraft/recraft-v4.1-vector | openrouter | In: text, image; Out: image | streaming, image_generation | - | - | - |
| rekaai/reka-edge | openrouter | In: image, text, video; Out: text | function_calling, structured_output, vision, video, streaming | 16384 | 16384 | In: $0.10, Out: $0.10 |
| rekaai/reka-flash-3 | openrouter | In: text; Out: text | structured_output, reasoning, streaming | 65536 | 65536 | In: $0.10, Out: $0.20 |
| relace/relace-apply-3 | openrouter | In: text; Out: text | streaming | 256000 | 128000 | In: $0.85, Out: $1.25 |
| relace/relace-search | openrouter | In: text; Out: text | function_calling, streaming | 256000 | 128000 | In: $1.00, Out: $3.00 |
| inclusionai/ring-2.6-1t | openrouter | In: text; Out: text | function_calling, reasoning, streaming | 262144 | 65536 | In: $0.08, Out: $0.62, Cache Read: $0.02 |
| thedrummer/rocinante-12b | openrouter | In: text; Out: text | structured_output, streaming, predicted_outputs | 65536 | 65536 | In: $0.25, Out: $0.50 |
| mistralai/mistral-saba | openrouter | In: text, pdf; Out: text | function_calling, structured_output, vision, streaming | 32768 | 32768 | In: $0.20, Out: $0.60, Cache Read: $0.02 |
| sakana/sakana-namazu | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 262144 | 65536 | In: $0.95, Out: $4.00, Cache Read: $0.15 |
| bytedance-seed/seed-1.6 | openrouter | In: image, text, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 262144 | 32768 | In: $0.25, Out: $2.00 |
| bytedance-seed/seed-1.6-flash | openrouter | In: image, text, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 262144 | 32768 | In: $0.08, Out: $0.30 |
| bytedance-seed/seed-2.0-code | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 262144 | 131072 | In: $0.50, Out: $3.00 |
| bytedance-seed/seed-2.0-lite | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 262144 | 131072 | In: $0.25, Out: $2.00 |
| bytedance-seed/seed-2.0-mini | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 262144 | 131072 | In: $0.10, Out: $0.40 |
| bytedance-seed/seed-2-1-turbo | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 262144 | 262144 | In: $0.50, Out: $2.50 |
| sentence-transformers/all-minilm-l12-v2 | openrouter | In: text; Out: embeddings | streaming, structured_output | 512 | - | In: $0.01 |
| sentence-transformers/all-minilm-l6-v2 | openrouter | In: text; Out: embeddings | streaming, structured_output | 512 | - | In: $0.01 |
| sentence-transformers/all-mpnet-base-v2 | openrouter | In: text; Out: embeddings | streaming, structured_output | 512 | - | In: $0.01 |
| sentence-transformers/multi-qa-mpnet-base-dot-v1 | openrouter | In: text; Out: embeddings | streaming, structured_output | 512 | - | In: $0.01 |
| sentence-transformers/paraphrase-minilm-l6-v2 | openrouter | In: text; Out: embeddings | streaming, structured_output | 512 | - | In: $0.01 |
| sesame/csm-1b | openrouter | In: text; Out: audio | streaming, structured_output, speech_generation | 4096 | - | In: $7.00 |
| thedrummer/skyfall-36b-v2 | openrouter | In: text; Out: text | structured_output, streaming, predicted_outputs | 32768 | 32768 | In: $0.55, Out: $0.80, Cache Read: $0.25 |
| upstage/solar-pro-3 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 131072 | 131072 | In: $0.15, Out: $0.60, Cache Read: $0.02 |
| upstage/solar-pro4 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 524288 | 131072 | In: $0.03, Out: $0.12, Cache Read: $0.01 |
| perplexity/sonar | openrouter | In: text, image; Out: text | vision, streaming | 127072 | 127072 | In: $1.00, Out: $1.00 |
| perplexity/sonar-deep-research | openrouter | In: text; Out: text | reasoning, streaming | 128000 | 128000 | In: $2.00, Out: $8.00 |
| perplexity/sonar-pro | openrouter | In: text, image; Out: text | vision, streaming | 200000 | 8000 | In: $3.00, Out: $15.00 |
| perplexity/sonar-pro-search | openrouter | In: text, image; Out: text | structured_output, reasoning, vision, streaming | 200000 | 8000 | In: $3.00, Out: $15.00 |
| perplexity/sonar-reasoning-pro | openrouter | In: text, image; Out: text | reasoning, vision, streaming | 128000 | 128000 | In: $2.00, Out: $8.00 |
| sourceful/riverflow-v2-fast | openrouter | In: text, image; Out: image | streaming, image_generation | - | - | - |
| sourceful/riverflow-v2-pro | openrouter | In: text, image; Out: image | streaming, image_generation | - | - | - |
| sourceful/riverflow-v2.5-fast | openrouter | In: text, image; Out: image | streaming, image_generation | - | - | - |
| sourceful/riverflow-v2.5-pro | openrouter | In: text, image; Out: image | streaming, image_generation | - | - | - |
| x-ai/grok-imagine-image-quality | openrouter | In: text, image; Out: image | streaming, image_generation | - | - | - |
| x-ai/grok-stt-1.0 | openrouter | In: audio; Out: text | streaming, structured_output, transcription | 0 | - | In: $100000.00 |
| x-ai/grok-voice-tts-1.0 | openrouter | In: text; Out: audio | streaming, structured_output, speech_generation | 15000 | - | In: $15.00 |
| stepfun/step-3.5-flash | openrouter | In: text; Out: text | function_calling, reasoning, streaming | 262144 | 65536 | In: $0.10, Out: $0.30 |
| stepfun/step-3.7-flash | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming, predicted_outputs | 262144 | 256000 | In: $0.20, Out: $1.15, Cache Read: $0.04 |
| thenlper/gte-base | openrouter | In: text; Out: embeddings | streaming, structured_output | 512 | - | In: $0.01 |
| thenlper/gte-large | openrouter | In: text; Out: embeddings | streaming, structured_output | 512 | - | In: $0.01 |
| thinkingmachines/inkling:batch | openrouter | In: text, image, audio; Out: text | streaming, function_calling, predicted_outputs | 524288 | - | In: $1.00, Out: $4.05, Cache Read: $0.17 |
| arcee-ai/trinity-large-thinking | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 262144 | 262144 | In: $0.22, Out: $0.85, Cache Read: $0.06 |
| bytedance/ui-tars-1.5-7b | openrouter | In: image, text; Out: text | structured_output, vision, streaming, predicted_outputs | 128000 | 2048 | In: $0.10, Out: $0.20, Cache Read: $0.10 |
| cognitivecomputations/dolphin-mistral-24b-venice-edition | openrouter | In: text; Out: text | streaming | 128000 | 8192 | In: $0.20, Out: $0.90 |
| thedrummer/unslopnemo-12b | openrouter | In: text; Out: text | function_calling, structured_output, streaming, predicted_outputs | 1024000 | 1024000 | In: $0.40, Out: $0.40 |
| arcee-ai/virtuoso-large | openrouter | In: text; Out: text | function_calling, streaming, predicted_outputs | 131072 | 64000 | In: $0.75, Out: $1.20 |
| mistralai/voxtral-small-24b-2507 | openrouter | In: text, audio, pdf; Out: text | function_calling, structured_output, vision, streaming | 32000 | 32000 | In: $0.10, Out: $0.30, Cache Read: $0.01 |
| voyageai/rerank-2.5 | openrouter | In: text; Out: rerank | streaming | 32000 | - | - |
| voyageai/rerank-2.5-lite | openrouter | In: text; Out: rerank | streaming | 32000 | - | - |
| voyageai/voyage-4 | openrouter | In: text; Out: embeddings | streaming | 32000 | - | In: $0.06 |
| voyageai/voyage-4-large | openrouter | In: text; Out: embeddings | streaming | 32000 | - | In: $0.12 |
| voyageai/voyage-4-lite | openrouter | In: text; Out: embeddings | streaming | 32000 | - | In: $0.02 |
| voyageai/voyage-code-4 | openrouter | In: text; Out: embeddings | streaming | 32000 | - | In: $0.12 |
| voyageai/voyage-multimodal-3.5 | openrouter | In: text, image; Out: embeddings | streaming | 32000 | - | In: $0.12 |
| microsoft/wizardlm-2-8x22b | openrouter | In: text; Out: text | streaming | 65535 | 8000 | In: $0.62, Out: $0.62 |
| z-ai/glm-5.2:batch | openrouter | In: text; Out: text | streaming, function_calling, structured_output, predicted_outputs | 512000 | - | In: $1.40, Out: $4.40, Cache Read: $0.26 |
| openai/gpt-oss-20b:free | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 131072 | 32768 | In: $0.00, Out: $0.00 |
| openai/gpt-oss-safeguard-20b | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 131072 | 65536 | In: $0.08, Out: $0.30, Cache Read: $0.04 |
| hexgrad/kokoro-82m | openrouter | In: text; Out: audio | streaming, structured_output, predicted_outputs, speech_generation | 4096 | - | In: $0.62 |
| openai/o1 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 100000 | In: $15.00, Out: $60.00, Cache Read: $7.50 |
| openai/o1-pro | openrouter | In: text, image, pdf; Out: text | structured_output, reasoning, vision, streaming | 200000 | 100000 | In: $150.00, Out: $600.00 |
| openai/o3 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 100000 | In: $2.00, Out: $8.00, Cache Read: $0.50 |
| openai/o3-mini-high | openrouter | In: text, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 100000 | In: $1.10, Out: $4.40, Cache Read: $0.55 |
| openai/o3-mini | openrouter | In: text, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 100000 | In: $1.10, Out: $4.40, Cache Read: $0.55 |
| openai/o3-pro | openrouter | In: text, pdf, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 100000 | In: $20.00, Out: $80.00 |
| openai/o4-mini-high | openrouter | In: image, text, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 100000 | In: $1.10, Out: $4.40, Cache Read: $0.28 |
| openai/o4-mini | openrouter | In: image, text, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 100000 | In: $1.10, Out: $4.40, Cache Read: $0.28 |
| x-ai/grok-imagine-image-2.0 | openrouter | In: text, image; Out: image | streaming, image_generation | - | - | - |


### Perplexity (51)

| Model | Provider | I/O | Capabilities | Context | Max Output | Standard Pricing (per 1M tokens) |
| :-- | :-- | :-- | :-- | --: | --: | :-- |
| sonar-deep-research | perplexity | In: text; Out: text | reasoning, citations | 128000 | 32768 | In: $2.00, Out: $8.00 |
| sonar | perplexity | In: text; Out: text | citations | 128000 | 4096 | In: $1.00, Out: $1.00 |
| sonar-pro | perplexity | In: text, image; Out: text | vision, citations | 200000 | 8192 | In: $3.00, Out: $15.00 |
| sonar-reasoning-pro | perplexity | In: text, image; Out: text | reasoning, vision, citations | 128000 | 4096 | In: $2.00, Out: $8.00 |
| anthropic/claude-fable-5 | perplexity | In: -; Out: - | citations | - | - | In: $10.00, Out: $50.00, Cache Read: $1.00, Cache Write: $12.50 |
| anthropic/claude-haiku-4-5 | perplexity | In: -; Out: - | citations | - | - | In: $1.00, Out: $5.00, Cache Read: $0.10, Cache Write: $1.25 |
| anthropic/claude-opus-4-5 | perplexity | In: -; Out: - | citations | - | - | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| anthropic/claude-opus-4-6 | perplexity | In: -; Out: - | citations | - | - | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| anthropic/claude-opus-4-7 | perplexity | In: -; Out: - | citations | - | - | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| anthropic/claude-opus-4-8 | perplexity | In: -; Out: - | citations | - | - | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| anthropic/claude-opus-5 | perplexity | In: -; Out: - | citations | - | - | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| anthropic/claude-sonnet-4-5 | perplexity | In: -; Out: - | citations | - | - | In: $3.00, Out: $15.00, Cache Read: $0.30, Cache Write: $3.75 |
| anthropic/claude-sonnet-4-6 | perplexity | In: -; Out: - | citations | - | - | In: $3.00, Out: $15.00, Cache Read: $0.30, Cache Write: $3.75 |
| anthropic/claude-sonnet-5 | perplexity | In: -; Out: - | citations | - | - | In: $2.00, Out: $10.00, Cache Read: $0.20, Cache Write: $2.50 |
| google/gemini-3-flash-preview | perplexity | In: -; Out: - | citations | - | - | In: $0.50, Out: $3.00, Cache Read: $0.05 |
| google/gemini-3.1-flash-lite | perplexity | In: -; Out: - | citations | - | - | In: $0.25, Out: $1.50, Cache Read: $0.02 |
| google/gemini-3.1-pro-preview | perplexity | In: -; Out: - | citations | - | - | In: $2.00, Out: $12.00, Cache Read: $0.20 |
| google/gemini-3.5-flash | perplexity | In: -; Out: - | citations | - | - | In: $1.50, Out: $9.00, Cache Read: $0.15 |
| google/gemini-3.5-flash-lite | perplexity | In: -; Out: - | citations | - | - | In: $0.30, Out: $2.50, Cache Read: $0.03 |
| google/gemini-3.6-flash | perplexity | In: -; Out: - | citations | - | - | In: $1.50, Out: $7.50, Cache Read: $0.15 |
| google/gemini-3.7-flash | perplexity | In: -; Out: - | citations | - | - | In: $0.38, Out: $1.88, Cache Read: $0.04 |
| openai/gpt-5 | perplexity | In: -; Out: - | citations | - | - | In: $1.25, Out: $10.00, Cache Read: $0.12 |
| openai/gpt-5-mini | perplexity | In: -; Out: - | citations | - | - | In: $0.25, Out: $2.00, Cache Read: $0.02 |
| openai/gpt-5-nano | perplexity | In: -; Out: - | citations | - | - | In: $0.05, Out: $0.40, Cache Read: $0.01 |
| openai/gpt-5.1 | perplexity | In: -; Out: - | citations | - | - | In: $1.25, Out: $10.00, Cache Read: $0.12 |
| openai/gpt-5.2 | perplexity | In: -; Out: - | citations | - | - | In: $1.75, Out: $14.00, Cache Read: $0.18 |
| openai/gpt-5.3-codex | perplexity | In: -; Out: - | citations | - | - | In: $3.50, Out: $28.00, Cache Read: $0.35 |
| openai/gpt-5.4 | perplexity | In: -; Out: - | citations | - | - | In: $2.50, Out: $15.00, Cache Read: $0.25 |
| openai/gpt-5.4-mini | perplexity | In: -; Out: - | citations | - | - | In: $0.75, Out: $4.50, Cache Read: $0.08 |
| openai/gpt-5.4-nano | perplexity | In: -; Out: - | citations | - | - | In: $0.20, Out: $1.25, Cache Read: $0.02 |
| openai/gpt-5.5 | perplexity | In: -; Out: - | citations | - | - | In: $5.00, Out: $30.00, Cache Read: $0.50 |
| openai/gpt-5.6-luna | perplexity | In: -; Out: - | citations | - | - | In: $0.20, Out: $1.20, Cache Read: $0.02, Cache Write: $0.25 |
| openai/gpt-5.6-sol | perplexity | In: -; Out: - | citations | - | - | In: $5.00, Out: $30.00, Cache Read: $0.50, Cache Write: $6.25 |
| openai/gpt-5.6-terra | perplexity | In: -; Out: - | citations | - | - | In: $2.00, Out: $12.00, Cache Read: $0.20, Cache Write: $2.50 |
| perplexity/deepseek-v4-flash-0731 | perplexity | In: -; Out: - | citations | - | - | In: $0.13, Out: $0.26, Cache Read: $0.03 |
| perplexity/deepseek-v4-pro-0813 | perplexity | In: -; Out: - | citations | - | - | In: $1.32, Out: $3.96, Cache Read: $0.04 |
| perplexity/glm-5.2 | perplexity | In: -; Out: - | citations | - | - | In: $1.40, Out: $4.40, Cache Read: $0.14 |
| perplexity/glm-5.3 | perplexity | In: -; Out: - | citations | - | - | In: $1.40, Out: $4.40, Cache Read: $0.26 |
| perplexity/kimi-k2.7-code | perplexity | In: -; Out: - | citations | - | - | In: $0.95, Out: $4.00, Cache Read: $0.19 |
| perplexity/kimi-k3 | perplexity | In: -; Out: - | citations | - | - | In: $3.00, Out: $15.00, Cache Read: $0.30 |
| perplexity/nemotron-3-ultra-550b-a55b | perplexity | In: -; Out: - | citations | - | - | In: $0.25, Out: $2.50, Cache Read: $0.25 |
| perplexity/nemotron-3.5-lightning-30b-a3b | perplexity | In: -; Out: - | citations | - | - | In: $0.01, Out: $0.17, Cache Read: $0.00 |
| perplexity/sonar | perplexity | In: -; Out: - | citations, vision | 128000 | 4096 | In: $0.25, Out: $2.50, Cache Read: $0.06 |
| pplx-embed-v1-0.6b | perplexity | In: text; Out: embeddings | - | 32768 | - | In: $0.00 |
| pplx-embed-v1-4b | perplexity | In: text; Out: embeddings | - | 32768 | - | In: $0.03 |
| xai/grok-4.20-multi-agent | perplexity | In: -; Out: - | citations | - | - | In: $1.25, Out: $2.50, Cache Read: $0.20 |
| xai/grok-4.20-non-reasoning | perplexity | In: -; Out: - | citations, reasoning | - | - | In: $1.25, Out: $2.50, Cache Read: $0.20 |
| xai/grok-4.20-reasoning | perplexity | In: -; Out: - | citations, reasoning | - | - | In: $1.25, Out: $2.50, Cache Read: $0.20 |
| xai/grok-4.3 | perplexity | In: -; Out: - | citations | - | - | In: $1.25, Out: $2.50, Cache Read: $0.20 |
| xai/grok-4.5 | perplexity | In: -; Out: - | citations | - | - | In: $2.00, Out: $6.00, Cache Read: $0.30 |
| xai/grok-4.6 | perplexity | In: -; Out: - | citations | - | - | In: $2.00, Out: $6.00, Cache Read: $0.50 |


### VertexAI (62)

| Model | Provider | I/O | Capabilities | Context | Max Output | Standard Pricing (per 1M tokens) |
| :-- | :-- | :-- | :-- | --: | --: | :-- |
| claude-haiku-4-5 | vertexai | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 64000 | In: $1.00, Out: $5.00, Cache Read: $0.10, Cache Write: $1.25 |
| claude-opus-4 | vertexai | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 200000 | 32000 | In: $15.00, Out: $75.00, Cache Read: $1.50, Cache Write: $18.75 |
| claude-opus-4-1 | vertexai | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 32000 | In: $15.00, Out: $75.00, Cache Read: $1.50, Cache Write: $18.75 |
| claude-opus-4-5 | vertexai | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 64000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| claude-opus-4-6 | vertexai | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| claude-opus-4-7 | vertexai | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| claude-opus-4-8 | vertexai | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| claude-opus-5 | vertexai | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| claude-sonnet-4 | vertexai | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 200000 | 64000 | In: $3.00, Out: $15.00, Cache Read: $0.30, Cache Write: $3.75 |
| claude-sonnet-4-5 | vertexai | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 64000 | In: $3.00, Out: $15.00, Cache Read: $0.30, Cache Write: $3.75 |
| claude-sonnet-4-6 | vertexai | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 1000000 | 128000 | In: $3.00, Out: $15.00, Cache Read: $0.30, Cache Write: $3.75 |
| claude-sonnet-5 | vertexai | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 1000000 | 128000 | In: $2.00, Out: $10.00, Cache Read: $0.20, Cache Write: $2.50 |
| deepseek-ai/deepseek-v3.1-maas | vertexai | In: text, pdf; Out: text | function_calling, structured_output, reasoning, vision | 163840 | 32768 | In: $0.60, Out: $1.70 |
| deepseek-ai/deepseek-v3.2-maas | vertexai | In: text, pdf; Out: text | function_calling, structured_output, reasoning, vision | 163840 | 65536 | In: $0.56, Out: $1.68, Cache Read: $0.06 |
| zai-org/glm-4.7-maas | vertexai | In: text, pdf; Out: text | function_calling, structured_output, reasoning, vision | 200000 | 128000 | In: $0.60, Out: $2.20 |
| zai-org/glm-5-maas | vertexai | In: text; Out: text | function_calling, reasoning | 202752 | 131072 | In: $1.00, Out: $3.20, Cache Read: $0.10 |
| openai/gpt-oss-120b-maas | vertexai | In: text; Out: text | function_calling, reasoning | 131072 | 32768 | In: $0.09, Out: $0.36 |
| openai/gpt-oss-20b-maas | vertexai | In: text; Out: text | function_calling, reasoning | 131072 | 32768 | In: $0.07, Out: $0.25 |
| gemini-2.5-flash | vertexai | In: text, image, audio, video, pdf; Out: text | function_calling, reasoning, vision, video, transcription, streaming | 1048576 | 65536 | In: $0.30, Out: $2.50, Cache Read: $0.08, Cache Write: $0.38 |
| gemini-2.5-flash-tts | vertexai | In: text; Out: audio | streaming | 32768 | 16384 | In: $0.50, Out: $10.00 |
| gemini-2.5-flash-lite | vertexai | In: text, image, audio, video, pdf; Out: text | function_calling, reasoning, vision, video, transcription, streaming | 1048576 | 65536 | In: $0.10, Out: $0.40, Cache Read: $0.01 |
| gemini-2.5-pro | vertexai | In: text, image, audio, video, pdf; Out: text | function_calling, reasoning, vision, video, transcription, streaming | 1048576 | 65536 | In: $1.25, Out: $10.00, Cache Read: $0.12 |
| gemini-2.5-pro-tts | vertexai | In: text; Out: audio | streaming | 32768 | 16384 | In: $1.00, Out: $20.00 |
| gemini-3-flash-preview | vertexai | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription, streaming | 1048576 | 65536 | In: $0.50, Out: $3.00, Cache Read: $0.05 |
| gemini-3.1-flash-lite | vertexai | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription, streaming | 1048576 | 65536 | In: $0.25, Out: $1.50, Cache Read: $0.02 |
| gemini-3.1-flash-lite-preview | vertexai | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription | 1048576 | 65536 | In: $0.25, Out: $1.50, Cache Read: $0.02 |
| gemini-3.1-pro-preview | vertexai | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription, streaming | 1048576 | 65536 | In: $2.00, Out: $12.00, Cache Read: $0.20 |
| gemini-3.1-pro-preview-customtools | vertexai | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription | 1048576 | 65536 | In: $2.00, Out: $12.00, Cache Read: $0.20 |
| gemini-3.5-flash | vertexai | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription, streaming | 1048576 | 65536 | In: $1.50, Out: $9.00, Cache Read: $0.15 |
| gemini-3.5-flash-lite | vertexai | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription, streaming | 1048576 | 65536 | In: $0.30, Out: $2.50, Cache Read: $0.03 |
| gemini-3.6-flash | vertexai | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription, streaming | 1048576 | 65536 | In: $1.50, Out: $7.50, Cache Read: $0.15 |
| gemini-3.7-flash | vertexai | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription, streaming | 1048576 | 65536 | In: $0.75, Out: $3.75, Cache Read: $0.08 |
| gemini-embedding-001 | vertexai | In: text; Out: embeddings | streaming | 2048 | 1 | In: $0.15, Out: $0.00 |
| gemini-embedding-2 | vertexai | In: text, image, audio, video, pdf; Out: embeddings | vision, video, streaming | 8192 | 1 | In: $0.20, Out: $0.00 |
| gemini-flash-latest | vertexai | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription | 1048576 | 65536 | In: $1.50, Out: $9.00, Cache Read: $0.15 |
| gemini-flash-lite-latest | vertexai | In: text, image, video, audio, pdf; Out: text | function_calling, reasoning, vision, video, transcription | 1048576 | 65536 | In: $0.25, Out: $1.50, Cache Read: $0.02 |
| moonshotai/kimi-k2-thinking-maas | vertexai | In: text; Out: text | function_calling, structured_output, reasoning | 262144 | 262144 | In: $0.60, Out: $2.50 |
| meta/llama-3.3-70b-instruct-maas | vertexai | In: text; Out: text | function_calling, structured_output | 128000 | 8192 | In: $0.72, Out: $0.72 |
| meta/llama-4-maverick-17b-128e-instruct-maas | vertexai | In: text, image; Out: text | function_calling, structured_output, vision | 524288 | 8192 | In: $0.35, Out: $1.15 |
| gemini-2.5-flash-image | vertexai | In: text, image; Out: text, image | vision | 32768 | 32768 | In: $0.30, Out: $30.00 |
| gemini-3.1-flash-image | vertexai | In: text, image, video, pdf; Out: text, image | reasoning, vision, video, streaming | 131072 | 32768 | In: $0.50, Out: $60.00 |
| gemini-3.1-flash-image-preview | vertexai | In: text, image, pdf; Out: text, image | reasoning, vision, streaming | 65536 | 65536 | In: $0.50, Out: $60.00 |
| gemini-3.1-flash-lite-image | vertexai | In: text, image; Out: text, image | function_calling, reasoning, vision, streaming | 65536 | 65536 | In: $0.25, Out: $30.00 |
| gemini-3-pro-image | vertexai | In: text, image; Out: text, image | reasoning, vision, streaming | 65536 | 32768 | In: $2.00, Out: $120.00 |
| qwen/qwen3-235b-a22b-instruct-2507-maas | vertexai | In: text; Out: text | function_calling, structured_output, reasoning | 262144 | 16384 | In: $0.22, Out: $0.88 |
| claude-fable-5 | vertexai | In: -; Out: - | streaming, function_calling | - | - | - |
| codestral-2 | vertexai | In: -; Out: - | streaming, function_calling | - | - | - |
| gemini-1.5-pro | vertexai | In: -; Out: - | streaming, function_calling | - | - | - |
| gemini-1.5-pro-002 | vertexai | In: -; Out: - | streaming, function_calling | - | - | - |
| gemini-2.0-flash-001 | vertexai | In: -; Out: - | streaming, function_calling | - | - | - |
| gemini-2.0-flash-lite-001 | vertexai | In: -; Out: - | streaming, function_calling | - | - | - |
| gemini-2.5-flash-preview-04-17 | vertexai | In: -; Out: - | streaming, function_calling | - | - | - |
| gemini-2.5-pro-exp-03-25 | vertexai | In: -; Out: - | streaming, function_calling | - | - | - |
| gemini-live-2.5-flash-native-audio | vertexai | In: -; Out: - | streaming, function_calling | - | - | - |
| gemini-pro | vertexai | In: -; Out: - | streaming, function_calling | - | - | - |
| gemini-pro-vision | vertexai | In: -; Out: - | streaming, function_calling | - | - | - |
| mistral-medium-3 | vertexai | In: -; Out: - | streaming, function_calling | - | - | - |
| mistral-ocr-2505 | vertexai | In: -; Out: - | streaming | - | - | - |
| mistral-small-2503 | vertexai | In: -; Out: - | streaming, function_calling | - | - | - |
| text-embedding-004 | vertexai | In: -; Out: - | streaming | - | - | - |
| text-embedding-005 | vertexai | In: -; Out: - | streaming | - | - | - |
| text-multilingual-embedding-002 | vertexai | In: -; Out: - | streaming | - | - | - |


### XAI (14)

| Model | Provider | I/O | Capabilities | Context | Max Output | Standard Pricing (per 1M tokens) |
| :-- | :-- | :-- | :-- | --: | --: | :-- |
| grok-4.20-0309-non-reasoning | xai | In: text, image, pdf; Out: text | function_calling, structured_output, vision, streaming | 1000000 | 30000 | In: $1.25, Out: $2.50, Cache Read: $0.20 |
| grok-4.20-0309-reasoning | xai | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 30000 | In: $1.25, Out: $2.50, Cache Read: $0.20 |
| grok-4.20-multi-agent-0309 | xai | In: text, image, pdf; Out: text | structured_output, reasoning, vision, streaming | 1000000 | 30000 | In: $1.25, Out: $2.50, Cache Read: $0.20 |
| grok-4.3 | xai | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 30000 | In: $1.25, Out: $2.50, Cache Read: $0.20 |
| grok-4.5 | xai | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 500000 | 500000 | In: $2.00, Out: $6.00, Cache Read: $0.30 |
| grok-4.6 | xai | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 500000 | 500000 | In: $2.00, Out: $6.00, Cache Read: $0.50 |
| grok-build-0.1 | xai | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 256000 | 256000 | In: $1.00, Out: $2.00, Cache Read: $0.20 |
| grok-imagine-image | xai | In: text, image, pdf; Out: image | vision | 8000 | 0 | - |
| grok-imagine-image-2.0 | xai | In: text, image, pdf; Out: image | vision | 8000 | 0 | - |
| grok-imagine-image-quality | xai | In: text, image, pdf; Out: image | vision | 8000 | 0 | - |
| grok-imagine-video | xai | In: text, image, video, pdf; Out: video | vision, video | 1024 | 0 | - |
| grok-imagine-video-1.5 | xai | In: text, image, audio, pdf; Out: video | vision | 1024 | 0 | - |
| grok-stt | xai | In: audio; Out: text | transcription | - | - | - |
| grok-tts | xai | In: text; Out: audio | - | - | - | - |


## Models by Capability

### Function Calling (761)

| Model | Provider | I/O | Capabilities | Context | Max Output | Standard Pricing (per 1M tokens) |
| :-- | :-- | :-- | :-- | --: | --: | :-- |
| claude-fable-5 | anthropic | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, citations, tool_choice, parallel_tool_calls, batch | 1000000 | 128000 | In: $10.00, Out: $50.00, Cache Read: $1.00, Cache Write: $12.50 |
| claude-haiku-4-5-20251001 | anthropic | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, citations, tool_choice, parallel_tool_calls, batch | 200000 | 64000 | In: $1.00, Out: $5.00, Cache Read: $0.10, Cache Write: $1.25 |
| claude-haiku-4-5 | anthropic | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 200000 | 64000 | In: $1.00, Out: $5.00, Cache Read: $0.10, Cache Write: $1.25 |
| claude-opus-4-5-20251101 | anthropic | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, citations, tool_choice, parallel_tool_calls, batch | 200000 | 64000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| claude-opus-4-5 | anthropic | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 200000 | 64000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| claude-opus-4-6 | anthropic | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, citations, tool_choice, parallel_tool_calls, batch | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| claude-opus-4-7 | anthropic | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, citations, tool_choice, parallel_tool_calls, batch | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| claude-opus-4-8 | anthropic | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, citations, tool_choice, parallel_tool_calls, batch | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| claude-opus-5 | anthropic | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, citations, tool_choice, parallel_tool_calls, batch | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| claude-sonnet-4-5-20250929 | anthropic | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, citations, tool_choice, parallel_tool_calls, batch | 1000000 | 64000 | In: $3.00, Out: $15.00, Cache Read: $0.30, Cache Write: $3.75 |
| claude-sonnet-4-5 | anthropic | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1000000 | 64000 | In: $3.00, Out: $15.00, Cache Read: $0.30, Cache Write: $3.75 |
| claude-sonnet-4-6 | anthropic | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, citations, tool_choice, parallel_tool_calls, batch | 1000000 | 128000 | In: $3.00, Out: $15.00, Cache Read: $0.30, Cache Write: $3.75 |
| claude-sonnet-5 | anthropic | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, citations, tool_choice, parallel_tool_calls, batch | 1000000 | 128000 | In: $2.00, Out: $10.00, Cache Read: $0.20, Cache Write: $2.50 |
| au.anthropic.claude-opus-4-6-v1 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1000000 | 128000 | In: $16.50, Out: $82.50, Cache Read: $1.65, Cache Write: $20.62 |
| au.anthropic.claude-sonnet-4-6 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1000000 | 128000 | In: $3.30, Out: $16.50, Cache Read: $0.33, Cache Write: $4.12 |
| anthropic.claude-3-haiku-20240307-v1:0 | bedrock | In: text, image; Out: text | streaming, function_calling | - | - | - |
| anthropic.claude-3-haiku-20240307-v1:0:200k | bedrock | In: text, image; Out: text | streaming, function_calling | - | - | - |
| anthropic.claude-3-haiku-20240307-v1:0:48k | bedrock | In: text, image; Out: text | streaming, function_calling | - | - | - |
| anthropic.claude-fable-5 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 1000000 | 128000 | In: $10.00, Out: $50.00, Cache Read: $1.00, Cache Write: $12.50 |
| eu.anthropic.claude-fable-5 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 1000000 | 128000 | In: $11.00, Out: $55.00, Cache Read: $1.10, Cache Write: $13.75 |
| global.anthropic.claude-fable-5 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 1000000 | 128000 | In: $10.00, Out: $50.00, Cache Read: $1.00, Cache Write: $12.50 |
| us.anthropic.claude-fable-5 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 1000000 | 128000 | In: $10.00, Out: $50.00, Cache Read: $1.00, Cache Write: $12.50 |
| anthropic.claude-haiku-4-5-20251001-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 200000 | 64000 | In: $1.00, Out: $5.00, Cache Read: $0.10, Cache Write: $1.25 |
| au.anthropic.claude-haiku-4-5-20251001-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 200000 | 64000 | In: $1.00, Out: $5.00, Cache Read: $0.10, Cache Write: $1.25 |
| eu.anthropic.claude-haiku-4-5-20251001-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 200000 | 64000 | In: $1.10, Out: $5.50, Cache Read: $0.11, Cache Write: $1.38 |
| global.anthropic.claude-haiku-4-5-20251001-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 200000 | 64000 | In: $1.00, Out: $5.00, Cache Read: $0.10, Cache Write: $1.25 |
| jp.anthropic.claude-haiku-4-5-20251001-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 200000 | 64000 | In: $1.00, Out: $5.00, Cache Read: $0.10, Cache Write: $1.25 |
| us.anthropic.claude-haiku-4-5-20251001-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 64000 | In: $1.00, Out: $5.00, Cache Read: $0.10, Cache Write: $1.25 |
| anthropic.claude-opus-4-1-20250805-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 200000 | 32000 | In: $15.00, Out: $75.00, Cache Read: $1.50, Cache Write: $18.75 |
| us.anthropic.claude-opus-4-1-20250805-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 32000 | In: $15.00, Out: $75.00, Cache Read: $1.50, Cache Write: $18.75 |
| anthropic.claude-opus-4-5-20251101-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 200000 | 64000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| eu.anthropic.claude-opus-4-5-20251101-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 200000 | 64000 | In: $5.50, Out: $27.50, Cache Read: $0.55, Cache Write: $6.88 |
| global.anthropic.claude-opus-4-5-20251101-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 200000 | 64000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| us.anthropic.claude-opus-4-5-20251101-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 64000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| anthropic.claude-opus-4-6-v1 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| eu.anthropic.claude-opus-4-6-v1 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1000000 | 128000 | In: $5.50, Out: $27.50, Cache Read: $0.55, Cache Write: $6.88 |
| global.anthropic.claude-opus-4-6-v1 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| us.anthropic.claude-opus-4-6-v1 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| anthropic.claude-opus-4-7 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| eu.anthropic.claude-opus-4-7 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 1000000 | 128000 | In: $5.50, Out: $27.50, Cache Read: $0.55, Cache Write: $6.88 |
| global.anthropic.claude-opus-4-7 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| jp.anthropic.claude-opus-4-7 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| us.anthropic.claude-opus-4-7 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming, structured_output | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| anthropic.claude-opus-4-8 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| au.anthropic.claude-opus-4-8 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| eu.anthropic.claude-opus-4-8 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 1000000 | 128000 | In: $5.50, Out: $27.50, Cache Read: $0.55, Cache Write: $6.88 |
| global.anthropic.claude-opus-4-8 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| jp.anthropic.claude-opus-4-8 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| us.anthropic.claude-opus-4-8 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming, structured_output | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| anthropic.claude-opus-5 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| au.anthropic.claude-opus-5 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| eu.anthropic.claude-opus-5 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 1000000 | 128000 | In: $5.50, Out: $27.50, Cache Read: $0.55, Cache Write: $6.88 |
| global.anthropic.claude-opus-5 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| jp.anthropic.claude-opus-5 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| us.anthropic.claude-opus-5 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| us.anthropic.claude-sonnet-4-20250514-v1:0 | bedrock | In: text, image; Out: text | streaming, function_calling, reasoning | 200000 | 65536 | - |
| anthropic.claude-sonnet-4-5-20250929-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 200000 | 64000 | In: $3.00, Out: $15.00, Cache Read: $0.30, Cache Write: $3.75 |
| au.anthropic.claude-sonnet-4-5-20250929-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 200000 | 64000 | In: $3.00, Out: $15.00, Cache Read: $0.30, Cache Write: $3.75 |
| eu.anthropic.claude-sonnet-4-5-20250929-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 200000 | 64000 | In: $3.30, Out: $16.50, Cache Read: $0.33, Cache Write: $4.12 |
| global.anthropic.claude-sonnet-4-5-20250929-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 200000 | 64000 | In: $3.00, Out: $15.00, Cache Read: $0.30, Cache Write: $3.75 |
| jp.anthropic.claude-sonnet-4-5-20250929-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 200000 | 64000 | In: $3.00, Out: $15.00, Cache Read: $0.30, Cache Write: $3.75 |
| us.anthropic.claude-sonnet-4-5-20250929-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 64000 | In: $3.00, Out: $15.00, Cache Read: $0.30, Cache Write: $3.75 |
| anthropic.claude-sonnet-4-6 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1000000 | 64000 | In: $3.00, Out: $15.00, Cache Read: $0.30, Cache Write: $3.75 |
| eu.anthropic.claude-sonnet-4-6 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1000000 | 64000 | In: $3.30, Out: $16.50, Cache Read: $0.33, Cache Write: $4.12 |
| global.anthropic.claude-sonnet-4-6 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1000000 | 64000 | In: $3.00, Out: $15.00, Cache Read: $0.30, Cache Write: $3.75 |
| jp.anthropic.claude-sonnet-4-6 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1000000 | 64000 | In: $3.00, Out: $15.00, Cache Read: $0.30, Cache Write: $3.75 |
| us.anthropic.claude-sonnet-4-6 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 64000 | In: $3.00, Out: $15.00, Cache Read: $0.30, Cache Write: $3.75 |
| anthropic.claude-sonnet-5 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1000000 | 128000 | In: $2.00, Out: $10.00, Cache Read: $0.20, Cache Write: $2.50 |
| au.anthropic.claude-sonnet-5 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1000000 | 128000 | In: $2.00, Out: $10.00, Cache Read: $0.20, Cache Write: $2.50 |
| eu.anthropic.claude-sonnet-5 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1000000 | 128000 | In: $2.20, Out: $11.00, Cache Read: $0.22, Cache Write: $2.75 |
| global.anthropic.claude-sonnet-5 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1000000 | 128000 | In: $2.00, Out: $10.00, Cache Read: $0.20, Cache Write: $2.50 |
| jp.anthropic.claude-sonnet-5 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1000000 | 128000 | In: $2.00, Out: $10.00, Cache Read: $0.20, Cache Write: $2.50 |
| us.anthropic.claude-sonnet-5 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 128000 | In: $2.00, Out: $10.00, Cache Read: $0.20, Cache Write: $2.50 |
| deepseek.r1-v1:0 | bedrock | In: text; Out: text | function_calling, reasoning | 128000 | 32768 | In: $1.35, Out: $5.40 |
| us.deepseek.r1-v1:0 | bedrock | In: text; Out: text | function_calling, reasoning, streaming | 128000 | 32768 | In: $1.35, Out: $5.40 |
| deepseek.v3-v1:0 | bedrock | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 163840 | 81920 | In: $0.58, Out: $1.68 |
| deepseek.v3.2 | bedrock | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 163840 | 81920 | In: $0.62, Out: $1.85 |
| mistral.devstral-2-123b | bedrock | In: text; Out: text | function_calling, structured_output, streaming | 256000 | 8192 | In: $0.40, Out: $2.00 |
| zai.glm-4.7 | bedrock | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 204800 | 131072 | In: $0.60, Out: $2.20 |
| zai.glm-4.7-flash | bedrock | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 200000 | 131072 | In: $0.07, Out: $0.40 |
| zai.glm-5 | bedrock | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 202752 | 101376 | In: $1.00, Out: $3.20 |
| openai.gpt-oss-safeguard-120b | bedrock | In: text; Out: text | function_calling, structured_output, streaming | 128000 | 16384 | In: $0.15, Out: $0.60 |
| openai.gpt-oss-safeguard-20b | bedrock | In: text; Out: text | function_calling, structured_output, streaming | 128000 | 16384 | In: $0.07, Out: $0.20 |
| openai.gpt-5.4 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 272000 | 128000 | In: $2.75, Out: $16.50, Cache Read: $0.28 |
| openai.gpt-5.5 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 272000 | 128000 | In: $5.50, Out: $33.00, Cache Read: $0.55 |
| openai.gpt-5.6-luna | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1050000 | 128000 | In: $0.22, Out: $1.32, Cache Read: $0.02, Cache Write: $0.28 |
| us.openai.gpt-5.6-luna | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1050000 | 128000 | In: $0.22, Out: $1.32, Cache Read: $0.02, Cache Write: $0.28 |
| global.openai.gpt-5.6-luna | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1050000 | 128000 | In: $0.22, Out: $1.32, Cache Read: $0.02, Cache Write: $0.28 |
| openai.gpt-5.6-sol | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1050000 | 128000 | In: $5.50, Out: $33.00, Cache Read: $0.55, Cache Write: $6.88 |
| us.openai.gpt-5.6-sol | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1050000 | 128000 | In: $5.50, Out: $33.00, Cache Read: $0.55, Cache Write: $6.88 |
| global.openai.gpt-5.6-sol | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1050000 | 128000 | In: $5.50, Out: $33.00, Cache Read: $0.55, Cache Write: $6.88 |
| openai.gpt-5.6-terra | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1050000 | 128000 | In: $2.20, Out: $13.20, Cache Read: $0.22, Cache Write: $2.75 |
| us.openai.gpt-5.6-terra | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1050000 | 128000 | In: $2.20, Out: $13.20, Cache Read: $0.22, Cache Write: $2.75 |
| global.openai.gpt-5.6-terra | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1050000 | 128000 | In: $2.20, Out: $13.20, Cache Read: $0.22, Cache Write: $2.75 |
| google.gemma-3-4b-it | bedrock | In: text, image; Out: text | function_calling, vision, streaming | 128000 | 4096 | In: $0.04, Out: $0.08 |
| google.gemma-3-27b-it | bedrock | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 202752 | 8192 | In: $0.12, Out: $0.20 |
| xai.grok-4.3 | bedrock | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 131072 | In: $1.25, Out: $2.50, Cache Read: $0.20 |
| us.xai.grok-4.6 | bedrock | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 500000 | 500000 | In: $2.20, Out: $6.60, Cache Read: $0.55 |
| xai.grok-4.6 | bedrock | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 500000 | 500000 | In: $2.20, Out: $6.60, Cache Read: $0.55 |
| moonshot.kimi-k2-thinking | bedrock | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 262143 | 16000 | In: $0.60, Out: $2.50 |
| moonshotai.kimi-k2.5 | bedrock | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 262143 | 16000 | In: $0.60, Out: $3.00 |
| meta.llama3-70b-instruct-v1:0 | bedrock | In: text; Out: text | streaming, function_calling | - | - | - |
| meta.llama3-8b-instruct-v1:0 | bedrock | In: text; Out: text | streaming, function_calling | - | - | - |
| meta.llama3-1-70b-instruct-v1:0 | bedrock | In: text; Out: text | function_calling, streaming | 128000 | 4096 | In: $0.72, Out: $0.72 |
| meta.llama3-1-70b-instruct-v1:0:128k | bedrock | In: text; Out: text | function_calling, streaming | 128000 | 4096 | In: $0.72, Out: $0.72 |
| meta.llama3-1-8b-instruct-v1:0 | bedrock | In: text; Out: text | function_calling, streaming | 128000 | 4096 | In: $0.22, Out: $0.22 |
| meta.llama3-1-8b-instruct-v1:0:128k | bedrock | In: text; Out: text | function_calling, streaming | 128000 | 4096 | In: $0.22, Out: $0.22 |
| meta.llama3-3-70b-instruct-v1:0 | bedrock | In: text; Out: text | function_calling | 128000 | 4096 | In: $0.72, Out: $0.72 |
| meta.llama3-3-70b-instruct-v1:0:128k | bedrock | In: text; Out: text | function_calling, streaming | 128000 | 4096 | In: $0.72, Out: $0.72 |
| us.meta.llama3-3-70b-instruct-v1:0 | bedrock | In: text; Out: text | function_calling, streaming | 128000 | 4096 | In: $0.72, Out: $0.72 |
| meta.llama4-maverick-17b-instruct-v1:0 | bedrock | In: text, image; Out: text | function_calling, vision | 1000000 | 16384 | In: $0.24, Out: $0.97 |
| us.meta.llama4-maverick-17b-instruct-v1:0 | bedrock | In: text, image; Out: text | function_calling, vision, streaming | 1000000 | 16384 | In: $0.24, Out: $0.97 |
| meta.llama4-scout-17b-instruct-v1:0 | bedrock | In: text, image; Out: text | function_calling, vision | 3500000 | 16384 | In: $0.17, Out: $0.66 |
| us.meta.llama4-scout-17b-instruct-v1:0 | bedrock | In: text, image; Out: text | function_calling, vision, streaming | 3500000 | 16384 | In: $0.17, Out: $0.66 |
| mistral.magistral-small-2509 | bedrock | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 128000 | 40000 | In: $0.50, Out: $1.50 |
| minimax.minimax-m2 | bedrock | In: text; Out: text | function_calling, reasoning, streaming | 204608 | 128000 | In: $0.30, Out: $1.20 |
| minimax.minimax-m2.1 | bedrock | In: text; Out: text | function_calling, reasoning, streaming | 204800 | 131072 | In: $0.30, Out: $1.20 |
| minimax.minimax-m2.5 | bedrock | In: text; Out: text | function_calling, reasoning, streaming | 196608 | 98304 | In: $0.30, Out: $1.20 |
| mistral.ministral-3-14b-instruct | bedrock | In: text; Out: text | function_calling, structured_output, streaming | 128000 | 4096 | In: $0.20, Out: $0.20 |
| mistral.ministral-3-3b-instruct | bedrock | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 256000 | 8192 | In: $0.10, Out: $0.10 |
| mistral.ministral-3-8b-instruct | bedrock | In: text; Out: text | function_calling, structured_output, streaming | 128000 | 4096 | In: $0.15, Out: $0.15 |
| mistral.mistral-7b-instruct-v0:2 | bedrock | In: text; Out: text | streaming, function_calling | - | - | - |
| mistral.mistral-large-2402-v1:0 | bedrock | In: text; Out: text | streaming, function_calling | - | - | - |
| mistral.mistral-large-2407-v1:0 | bedrock | In: text; Out: text | streaming, function_calling | - | - | - |
| mistral.mistral-large-3-675b-instruct | bedrock | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 256000 | 8192 | In: $0.50, Out: $1.50 |
| mistral.mixtral-8x7b-instruct-v0:1 | bedrock | In: text; Out: text | streaming, function_calling | - | - | - |
| nvidia.nemotron-super-3-120b | bedrock | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 262144 | 131072 | In: $0.15, Out: $0.65 |
| nvidia.nemotron-nano-12b-v2 | bedrock | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 128000 | 4096 | In: $0.20, Out: $0.60 |
| nvidia.nemotron-nano-3-30b | bedrock | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 128000 | 4096 | In: $0.06, Out: $0.24 |
| nvidia.nemotron-nano-9b-v2 | bedrock | In: text; Out: text | function_calling, structured_output, streaming | 128000 | 4096 | In: $0.06, Out: $0.23 |
| amazon.nova-2-lite-v1:0 | bedrock | In: text, image, video; Out: text | function_calling, reasoning, vision, video | 128000 | 4096 | In: $0.33, Out: $2.75 |
| us.amazon.nova-2-lite-v1:0 | bedrock | In: text, image, video; Out: text | function_calling, reasoning, vision, video, streaming | 128000 | 4096 | In: $0.33, Out: $2.75 |
| amazon.nova-lite-v1:0 | bedrock | In: text, image, video; Out: text | function_calling, vision, video, streaming | 300000 | 8192 | In: $0.06, Out: $0.24, Cache Read: $0.02 |
| amazon.nova-micro-v1:0 | bedrock | In: text; Out: text | function_calling | 128000 | 8192 | In: $0.04, Out: $0.14, Cache Read: $0.01 |
| us.amazon.nova-micro-v1:0 | bedrock | In: text; Out: text | function_calling, streaming | 128000 | 8192 | In: $0.04, Out: $0.14, Cache Read: $0.01 |
| amazon.nova-premier-v1:0:1000k | bedrock | In: text, image, video; Out: text | streaming, function_calling | - | - | - |
| amazon.nova-premier-v1:0:20k | bedrock | In: text, image, video; Out: text | streaming, function_calling | - | - | - |
| amazon.nova-premier-v1:0:8k | bedrock | In: text, image, video; Out: text | streaming, function_calling | - | - | - |
| amazon.nova-premier-v1:0:mm | bedrock | In: text, image, video; Out: text | streaming, function_calling | - | - | - |
| us.amazon.nova-premier-v1:0 | bedrock | In: text, image, video; Out: text | streaming, function_calling | - | - | - |
| amazon.nova-pro-v1:0 | bedrock | In: text, image, video; Out: text | function_calling, vision, video | 300000 | 8192 | In: $0.80, Out: $3.20, Cache Read: $0.20 |
| us.amazon.nova-pro-v1:0 | bedrock | In: text, image, video; Out: text | function_calling, vision, video, streaming | 300000 | 8192 | In: $0.80, Out: $3.20, Cache Read: $0.20 |
| us.writer.palmyra-x4-v1:0 | bedrock | In: text; Out: text | function_calling, reasoning, streaming | 122880 | 8192 | In: $2.50, Out: $10.00 |
| writer.palmyra-x4-v1:0 | bedrock | In: text; Out: text | function_calling, reasoning | 122880 | 8192 | In: $2.50, Out: $10.00 |
| us.writer.palmyra-x5-v1:0 | bedrock | In: text; Out: text | function_calling, reasoning, streaming | 1040000 | 8192 | In: $0.60, Out: $6.00 |
| writer.palmyra-x5-v1:0 | bedrock | In: text; Out: text | function_calling, reasoning | 1040000 | 8192 | In: $0.60, Out: $6.00 |
| mistral.pixtral-large-2502-v1:0 | bedrock | In: text, image; Out: text | function_calling, vision | 128000 | 8192 | In: $2.00, Out: $6.00 |
| us.mistral.pixtral-large-2502-v1:0 | bedrock | In: text, image; Out: text | function_calling, vision, streaming | 128000 | 8192 | In: $2.00, Out: $6.00 |
| qwen.qwen3-next-80b-a3b | bedrock | In: text; Out: text | function_calling, structured_output, streaming | 262000 | 262000 | In: $0.14, Out: $1.40 |
| qwen.qwen3-vl-235b-a22b | bedrock | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 262000 | 262000 | In: $0.30, Out: $1.50 |
| qwen.qwen3-235b-a22b-2507-v1:0 | bedrock | In: text; Out: text | function_calling, structured_output, streaming | 262144 | 131072 | In: $0.22, Out: $0.88 |
| qwen.qwen3-32b-v1:0 | bedrock | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 16384 | 16384 | In: $0.15, Out: $0.60 |
| qwen.qwen3-coder-30b-a3b-v1:0 | bedrock | In: text; Out: text | function_calling, structured_output, streaming | 262144 | 131072 | In: $0.15, Out: $0.60 |
| qwen.qwen3-coder-480b-a35b-v1:0 | bedrock | In: text; Out: text | function_calling, structured_output, streaming | 131072 | 65536 | In: $0.22, Out: $1.80 |
| qwen.qwen3-coder-next | bedrock | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 131072 | 65536 | In: $0.22, Out: $1.80 |
| mistral.voxtral-mini-3b-2507 | bedrock | In: audio, text; Out: text | function_calling, structured_output, streaming | 128000 | 4096 | In: $0.04, Out: $0.04 |
| mistral.voxtral-small-24b-2507 | bedrock | In: text, audio; Out: text | function_calling, structured_output, streaming | 32000 | 8192 | In: $0.15, Out: $0.35 |
| writer.palmyra-vision-7b | bedrock | In: text, image; Out: text | streaming, function_calling | - | 4096 | - |
| openai.gpt-oss-120b | bedrock | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 128000 | 16384 | In: $0.15, Out: $0.60 |
| openai.gpt-oss-120b-1:0 | bedrock | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 128000 | 16384 | In: $0.15, Out: $0.60 |
| openai.gpt-oss-20b | bedrock | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 128000 | 16384 | In: $0.07, Out: $0.30 |
| openai.gpt-oss-20b-1:0 | bedrock | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 128000 | 16384 | In: $0.07, Out: $0.30 |
| command-a-03-2025 | cohere | In: text; Out: text | function_calling, streaming, structured_output, citations, tool_choice | 256000 | 8000 | In: $2.50, Out: $10.00 |
| command-a-plus-05-2026 | cohere | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming, citations | 128000 | 64000 | In: $2.50, Out: $10.00 |
| command-a-reasoning-08-2025 | cohere | In: text; Out: text | function_calling, reasoning, streaming, structured_output, citations | 256000 | 32000 | In: $2.50, Out: $10.00 |
| command-a-translate-08-2025 | cohere | In: text; Out: text | function_calling, streaming | 8000 | 8000 | In: $2.50, Out: $10.00 |
| command-r-08-2024 | cohere | In: text; Out: text | function_calling, streaming, structured_output, citations, tool_choice | 128000 | 4000 | In: $0.15, Out: $0.60 |
| command-r-plus-08-2024 | cohere | In: text; Out: text | function_calling, streaming, structured_output, citations, tool_choice | 128000 | 4000 | In: $2.50, Out: $10.00 |
| command-r7b-12-2024 | cohere | In: text; Out: text | function_calling, streaming, structured_output, citations, tool_choice | 128000 | 4000 | In: $0.04, Out: $0.15 |
| command-r7b-arabic-02-2025 | cohere | In: text; Out: text | function_calling, streaming, structured_output, citations | 128000 | 4000 | In: $0.04, Out: $0.15 |
| north-mini-code-1-0 | cohere | In: text; Out: text | function_calling, structured_output, reasoning, streaming, citations | 256000 | 64000 | In: $0.00, Out: $0.00 |
| deepseek-chat | deepseek | In: text; Out: text | function_calling | 1000000 | 384000 | In: $0.14, Out: $0.28, Cache Read: $0.00 |
| deepseek-reasoner | deepseek | In: text; Out: text | function_calling, reasoning | 1000000 | 384000 | In: $0.14, Out: $0.28, Cache Read: $0.00 |
| deepseek-v4-flash | deepseek | In: text; Out: text | function_calling, structured_output, reasoning, tool_choice | 1000000 | 384000 | In: $0.14, Out: $0.28, Cache Read: $0.00 |
| deepseek-v4-pro | deepseek | In: text; Out: text | function_calling, structured_output, reasoning, tool_choice | 1000000 | 384000 | In: $0.44, Out: $0.87, Cache Read: $0.00 |
| deep-research-max-preview-04-2026 | gemini | In: text, image, video, audio, pdf; Out: text, image | function_calling, reasoning, vision, video, transcription | 131072 | 65536 | In: $2.00, Out: $12.00, Cache Read: $0.20 |
| deep-research-preview-04-2026 | gemini | In: text, image, video, audio, pdf; Out: text, image | function_calling, reasoning, vision, video, transcription | 131072 | 65536 | In: $2.00, Out: $12.00, Cache Read: $0.20 |
| deep-research-pro-preview-12-2025 | gemini | In: -; Out: - | function_calling, tool_choice, structured_output, vision | 131072 | 65536 | In: $0.08, Out: $0.30 |
| gemini-2.5-computer-use-preview-10-2025 | gemini | In: text, image; Out: text | function_calling, reasoning, vision, tool_choice, structured_output | 131072 | 65536 | In: $1.25, Out: $10.00 |
| gemini-2.5-flash | gemini | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription, tool_choice | 1048576 | 65536 | In: $0.30, Out: $2.50, Cache Read: $0.03 |
| gemini-2.5-flash-native-audio-latest | gemini | In: -; Out: - | function_calling, tool_choice, structured_output, vision | 131072 | 8192 | In: $0.08, Out: $0.30 |
| gemini-2.5-flash-native-audio-preview-09-2025 | gemini | In: -; Out: - | function_calling, tool_choice, structured_output, vision | 131072 | 8192 | In: $0.08, Out: $0.30 |
| gemini-2.5-flash-native-audio-preview-12-2025 | gemini | In: -; Out: - | function_calling, tool_choice, structured_output, vision | 131072 | 8192 | In: $0.08, Out: $0.30 |
| gemini-2.5-flash-lite | gemini | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription | 1048576 | 65536 | In: $0.10, Out: $0.40, Cache Read: $0.01 |
| gemini-2.5-pro | gemini | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription, tool_choice | 1048576 | 65536 | In: $1.25, Out: $10.00, Cache Read: $0.12 |
| gemini-3-flash-preview | gemini | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription, tool_choice | 1048576 | 65536 | In: $0.50, Out: $3.00, Cache Read: $0.05 |
| gemini-3.1-flash-lite | gemini | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription | 1048576 | 65536 | In: $0.25, Out: $1.50, Cache Read: $0.02 |
| gemini-3.1-flash-lite-preview | gemini | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription | 1048576 | 65536 | In: $0.25, Out: $1.50, Cache Read: $0.02 |
| gemini-3.1-flash-live-preview | gemini | In: text, image, video, audio; Out: text, audio | function_calling, reasoning, vision, video, transcription, tool_choice | 131072 | 65536 | In: $0.75, Out: $4.50 |
| gemini-3.1-pro-preview | gemini | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription, tool_choice | 1048576 | 65536 | In: $2.00, Out: $12.00, Cache Read: $0.20 |
| gemini-3.1-pro-preview-customtools | gemini | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription, tool_choice | 1048576 | 65536 | In: $2.00, Out: $12.00, Cache Read: $0.20 |
| gemini-3.5-flash | gemini | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription, tool_choice | 1048576 | 65536 | In: $1.50, Out: $9.00, Cache Read: $0.15 |
| gemini-3.5-flash-lite | gemini | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription | 1048576 | 65536 | In: $0.30, Out: $2.50, Cache Read: $0.03 |
| gemini-3.6-flash | gemini | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription, tool_choice | 1048576 | 65536 | In: $1.50, Out: $7.50, Cache Read: $0.15 |
| gemini-3.7-flash | gemini | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription, tool_choice | 1048576 | 65536 | In: $0.75, Out: $3.75, Cache Read: $0.08 |
| gemini-embedding-2-preview | gemini | In: -; Out: - | function_calling, tool_choice, structured_output, vision | 8192 | 1 | In: $0.00, Out: $0.00 |
| gemini-flash-latest | gemini | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription, tool_choice | 1048576 | 65536 | In: $1.50, Out: $9.00, Cache Read: $0.15 |
| gemini-flash-lite-latest | gemini | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription | 1048576 | 65536 | In: $0.25, Out: $1.50, Cache Read: $0.02 |
| gemini-pro-latest | gemini | In: -; Out: - | function_calling, tool_choice, structured_output, vision | 1048576 | 65536 | In: $0.08, Out: $0.30 |
| gemini-robotics-er-1.6-preview | gemini | In: text, image, video, audio; Out: text | function_calling, structured_output, reasoning, vision, video, transcription, tool_choice | 131072 | 65536 | In: $1.00, Out: $5.00 |
| gemini-robotics-er-2-preview | gemini | In: -; Out: - | function_calling, tool_choice, structured_output, vision | 131072 | 65536 | In: $0.08, Out: $0.30 |
| gemini-robotics-er-2-streaming-preview | gemini | In: -; Out: - | function_calling, tool_choice, structured_output, vision | 131072 | 65536 | In: $0.08, Out: $0.30 |
| gemma-4-26b-a4b-it | gemini | In: text, image; Out: text | function_calling, structured_output, reasoning, vision | 262144 | 32768 | In: $0.08, Out: $0.30 |
| gemma-4-31b-it | gemini | In: text, image; Out: text | function_calling, structured_output, reasoning, vision | 262144 | 32768 | In: $0.08, Out: $0.30 |
| gemini-3.1-flash-lite-image | gemini | In: text, image; Out: text, image | function_calling, reasoning, vision | 65536 | 65536 | In: $0.25, Out: $30.00 |
| nano-banana-pro-preview | gemini | In: -; Out: - | function_calling, tool_choice, structured_output, vision | 131072 | 32768 | In: $0.08, Out: $0.30 |
| codestral-2508 | mistral | In: text; Out: text | streaming, function_calling, tool_choice, parallel_tool_calls, structured_output, batch, predicted_outputs | 256000 | 8192 | - |
| codestral-latest | mistral | In: text; Out: text | function_calling, streaming, tool_choice, parallel_tool_calls, structured_output, batch, predicted_outputs | 256000 | 4096 | In: $0.30, Out: $0.90 |
| devstral-2512 | mistral | In: text; Out: text | function_calling, streaming, tool_choice, parallel_tool_calls, structured_output, batch | 262144 | 262144 | In: $0.40, Out: $2.00 |
| devstral-latest | mistral | In: text; Out: text | function_calling, streaming, tool_choice, parallel_tool_calls, structured_output, batch | 262144 | 262144 | In: $0.40, Out: $2.00 |
| devstral-medium-latest | mistral | In: text; Out: text | function_calling, streaming, tool_choice, parallel_tool_calls, structured_output, batch | 262144 | 262144 | In: $0.40, Out: $2.00 |
| devstral-medium-2507 | mistral | In: text; Out: text | function_calling | 128000 | 128000 | In: $0.40, Out: $2.00 |
| devstral-small-2507 | mistral | In: text; Out: text | function_calling | 128000 | 128000 | In: $0.10, Out: $0.30 |
| labs-devstral-small-2512 | mistral | In: text, image; Out: text | function_calling, vision | 256000 | 256000 | In: $0.00, Out: $0.00 |
| devstral-small-2505 | mistral | In: text; Out: text | function_calling | 128000 | 128000 | In: $0.10, Out: $0.30 |
| glm-5-2 | mistral | In: text; Out: text | streaming, function_calling, tool_choice, parallel_tool_calls, structured_output, batch, reasoning | 1048576 | 8192 | - |
| labs-leanstral-1-5 | mistral | In: text, image; Out: text | streaming, function_calling, tool_choice, parallel_tool_calls, structured_output, batch, reasoning, vision | 262144 | 8192 | - |
| labs-leanstral-1-5-1 | mistral | In: text, image; Out: text | streaming, function_calling, tool_choice, parallel_tool_calls, structured_output, batch, reasoning, vision | 262144 | 8192 | - |
| magistral-medium-latest | mistral | In: text; Out: text | function_calling, reasoning, streaming, tool_choice, parallel_tool_calls, structured_output, batch | 128000 | 16384 | In: $2.00, Out: $5.00 |
| magistral-small | mistral | In: text; Out: text | function_calling, reasoning | 128000 | 128000 | In: $0.50, Out: $1.50 |
| magistral-small-latest | mistral | In: text, image; Out: text | streaming, function_calling, tool_choice, parallel_tool_calls, structured_output, reasoning, batch, vision | 262144 | 8192 | - |
| ministral-14b-2512 | mistral | In: text, image; Out: text | streaming, function_calling, tool_choice, parallel_tool_calls, structured_output, batch, distillation, fine_tuning, vision | 262144 | 8192 | - |
| ministral-14b-latest | mistral | In: text, image; Out: text | streaming, function_calling, tool_choice, parallel_tool_calls, structured_output, batch, distillation, fine_tuning, vision | 262144 | 8192 | - |
| ministral-3b-2512 | mistral | In: text, image; Out: text | streaming, function_calling, tool_choice, parallel_tool_calls, structured_output, batch, distillation, fine_tuning, vision | 131072 | 8192 | - |
| ministral-3b-latest | mistral | In: text; Out: text | function_calling, streaming, tool_choice, parallel_tool_calls, structured_output, batch, distillation, fine_tuning | 128000 | 128000 | In: $0.04, Out: $0.04 |
| ministral-8b-2512 | mistral | In: text, image; Out: text | streaming, function_calling, tool_choice, parallel_tool_calls, structured_output, batch, distillation, fine_tuning, vision | 262144 | 8192 | - |
| ministral-8b-latest | mistral | In: text; Out: text | function_calling, streaming, tool_choice, parallel_tool_calls, structured_output, batch, distillation, fine_tuning | 128000 | 128000 | In: $0.10, Out: $0.10 |
| open-mistral-7b | mistral | In: text; Out: text | function_calling | 8000 | 8000 | In: $0.25, Out: $0.25 |
| mistral-code-agent-latest | mistral | In: text; Out: text | streaming, function_calling, tool_choice, parallel_tool_calls, structured_output, batch | 262144 | 8192 | - |
| mistral-code-fim-latest | mistral | In: text; Out: text | streaming, function_calling, tool_choice, parallel_tool_calls, structured_output, batch | 256000 | 8192 | - |
| mistral-code-latest | mistral | In: text; Out: text | streaming, function_calling, tool_choice, parallel_tool_calls, structured_output, batch | 256000 | 8192 | - |
| mistral-large-latest | mistral | In: text, image; Out: text | function_calling, vision, streaming, tool_choice, parallel_tool_calls, structured_output, batch, fine_tuning | 262144 | 262144 | In: $0.50, Out: $1.50 |
| mistral-large-2411 | mistral | In: text; Out: text | function_calling | 131072 | 16384 | In: $2.00, Out: $6.00 |
| mistral-large-2512 | mistral | In: text, image; Out: text | function_calling, vision, streaming, tool_choice, parallel_tool_calls, structured_output, batch, fine_tuning | 262144 | 262144 | In: $0.50, Out: $1.50 |
| mistral-medium | mistral | In: text, image; Out: text | streaming, function_calling, tool_choice, parallel_tool_calls, structured_output, batch, reasoning, vision | 262144 | 8192 | - |
| mistral-medium-3 | mistral | In: text, image; Out: text | streaming, function_calling, tool_choice, parallel_tool_calls, structured_output, reasoning, batch, vision | 262144 | 8192 | - |
| mistral-medium-3-5 | mistral | In: text, image; Out: text | streaming, function_calling, tool_choice, parallel_tool_calls, structured_output, reasoning, batch, vision | 262144 | 8192 | - |
| mistral-medium-3.5 | mistral | In: text, image; Out: text | streaming, function_calling, tool_choice, parallel_tool_calls, structured_output, reasoning, batch, vision | 262144 | 8192 | - |
| mistral-medium-latest | mistral | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming, tool_choice, parallel_tool_calls, batch | 262144 | 262144 | In: $1.50, Out: $7.50 |
| mistral-medium-2505 | mistral | In: text, image; Out: text | function_calling, vision, streaming, tool_choice, parallel_tool_calls, structured_output, batch, fine_tuning | 131072 | 131072 | In: $0.40, Out: $2.00 |
| mistral-medium-2508 | mistral | In: text, image; Out: text | function_calling, vision, streaming, tool_choice, parallel_tool_calls, structured_output, batch, fine_tuning | 262144 | 262144 | In: $0.40, Out: $2.00 |
| mistral-medium-2604 | mistral | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming, tool_choice, parallel_tool_calls, batch | 262144 | 262144 | In: $1.50, Out: $7.50 |
| mistral-nemo | mistral | In: text; Out: text | function_calling | 128000 | 128000 | In: $0.15, Out: $0.15 |
| mistral-ocr-2512 | mistral | In: text, image; Out: text | vision, function_calling | 16384 | 8192 | - |
| mistral-ocr-3 | mistral | In: text, image; Out: text | vision, function_calling | 16384 | 8192 | - |
| mistral-ocr-3-0 | mistral | In: text, image; Out: text | vision, function_calling | 16384 | 8192 | - |
| mistral-ocr-4 | mistral | In: text, image; Out: text | vision, function_calling | 16384 | 8192 | - |
| mistral-ocr-4-0 | mistral | In: text, image; Out: text | vision, function_calling | 16384 | 8192 | - |
| mistral-ocr-4-1 | mistral | In: text, image; Out: text | vision, function_calling | 16384 | 8192 | - |
| mistral-ocr-latest | mistral | In: text, image; Out: text | vision, function_calling | 16384 | 8192 | - |
| mistral-small-latest | mistral | In: text, image; Out: text | function_calling, reasoning, vision, streaming, tool_choice, parallel_tool_calls, structured_output, batch | 256000 | 256000 | In: $0.15, Out: $0.60 |
| mistral-small-2506 | mistral | In: text, image; Out: text | function_calling, vision | 128000 | 16384 | In: $0.10, Out: $0.30 |
| mistral-small-2603 | mistral | In: text, image; Out: text | function_calling, reasoning, vision, streaming, tool_choice, parallel_tool_calls, structured_output, batch | 256000 | 256000 | In: $0.15, Out: $0.60 |
| mistral-vibe-cli-fast | mistral | In: text, image; Out: text | streaming, function_calling, tool_choice, parallel_tool_calls, structured_output, batch, reasoning, vision | 262144 | 8192 | - |
| mistral-vibe-cli-latest | mistral | In: text, image; Out: text | streaming, function_calling, tool_choice, parallel_tool_calls, structured_output, batch, reasoning, vision | 262144 | 8192 | - |
| mistral-vibe-cli-with-tools | mistral | In: text, image; Out: text | streaming, function_calling, tool_choice, parallel_tool_calls, structured_output, batch, reasoning, vision | 262144 | 8192 | - |
| open-mixtral-8x22b | mistral | In: text; Out: text | function_calling | 64000 | 64000 | In: $2.00, Out: $6.00 |
| open-mixtral-8x7b | mistral | In: text; Out: text | function_calling | 32000 | 32000 | In: $0.70, Out: $0.70 |
| open-mistral-nemo | mistral | In: text; Out: text | function_calling | 128000 | 128000 | In: $0.15, Out: $0.15 |
| pixtral-12b | mistral | In: text, image; Out: text | function_calling, vision | 128000 | 128000 | In: $0.15, Out: $0.15 |
| pixtral-large-latest | mistral | In: text, image; Out: text | function_calling, vision | 128000 | 128000 | In: $2.00, Out: $6.00 |
| voxtral-mini-tts-2603 | mistral | In: text; Out: audio | streaming, function_calling, fine_tuning, speech_generation | 4096 | 8192 | - |
| voxtral-small-latest | mistral | In: text, audio; Out: text | function_calling, streaming | 32000 | 32000 | In: $0.10, Out: $0.30 |
| voxtral-small-2507 | mistral | In: text, audio; Out: text | streaming, function_calling | 32768 | 8192 | - |
| zai-glm-5-2 | mistral | In: text; Out: text | streaming, function_calling, tool_choice, parallel_tool_calls, structured_output, batch, reasoning | 1048576 | 8192 | - |
| deepseek-v4-flash:0731 | ollama_cloud | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 1048576 | 1048576 | - |
| glm-5.2 | ollama_cloud | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 976000 | 131072 | - |
| deepseek-v4-flash | ollama_cloud | In: text; Out: text | function_calling, reasoning | 1048576 | 1048576 | - |
| deepseek-v4-flash:preview | ollama_cloud | In: text; Out: text | streaming, function_calling, reasoning | - | - | - |
| deepseek-v4-pro | ollama_cloud | In: text; Out: text | function_calling, reasoning | 1048576 | 1048576 | - |
| deepseek-v4-pro:0813 | ollama_cloud | In: text; Out: text | streaming, function_calling, reasoning | - | - | - |
| deepseek-v4-pro:preview | ollama_cloud | In: text; Out: text | streaming, function_calling, reasoning | - | - | - |
| gemma4:31b | ollama_cloud | In: text, image; Out: text | function_calling, reasoning, vision, streaming | 262144 | 262144 | - |
| glm-5.1 | ollama_cloud | In: text; Out: text | function_calling, reasoning, streaming | 202752 | 131072 | - |
| gpt-oss:120b | ollama_cloud | In: text; Out: text | function_calling, reasoning, streaming | 131072 | 32768 | - |
| gpt-oss:20b | ollama_cloud | In: text; Out: text | function_calling, reasoning, streaming | 131072 | 32768 | - |
| kimi-k2.5 | ollama_cloud | In: text, image; Out: text | function_calling, reasoning, vision | 262144 | 262144 | - |
| kimi-k2.6 | ollama_cloud | In: text, image; Out: text | function_calling, reasoning, vision, streaming | 262144 | 262144 | - |
| kimi-k2.7-code | ollama_cloud | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 262144 | 262144 | - |
| kimi-k3 | ollama_cloud | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1048576 | 131072 | - |
| minimax-m2.5 | ollama_cloud | In: text; Out: text | function_calling, reasoning | 204800 | 131072 | - |
| minimax-m2.7 | ollama_cloud | In: text; Out: text | function_calling, reasoning, streaming | 196608 | 196608 | - |
| minimax-m3 | ollama_cloud | In: text, image, video; Out: text | function_calling, reasoning, vision, video, streaming | 512000 | 131072 | - |
| mistral-large-3:675b | ollama_cloud | In: text, image; Out: text | function_calling, vision, streaming | 262144 | 262144 | - |
| nemotron-3-nano:30b | ollama_cloud | In: text; Out: text | function_calling, reasoning, streaming | 1048576 | 131072 | - |
| nemotron-3-super | ollama_cloud | In: text; Out: text | function_calling, reasoning, streaming | 262144 | 65536 | - |
| nemotron-3-ultra | ollama_cloud | In: text; Out: text | function_calling, reasoning, streaming | 262144 | 128000 | - |
| qwen3.5:397b | ollama_cloud | In: text, image; Out: text | function_calling, reasoning, vision, streaming | 262144 | 65536 | - |
| gpt-4 | openai | In: text; Out: text | function_calling, tool_choice, parallel_tool_calls | 8192 | 8192 | In: $30.00, Out: $60.00 |
| gpt-4-turbo | openai | In: text, image; Out: text | function_calling, vision, tool_choice, parallel_tool_calls | 128000 | 4096 | In: $10.00, Out: $30.00 |
| gpt-4.1 | openai | In: text, image, pdf; Out: text | function_calling, structured_output, vision, tool_choice, parallel_tool_calls | 1047576 | 32768 | In: $2.00, Out: $8.00, Cache Read: $0.50 |
| gpt-4.1-mini | openai | In: text, image, pdf; Out: text | function_calling, structured_output, vision, tool_choice, parallel_tool_calls | 1047576 | 32768 | In: $0.40, Out: $1.60, Cache Read: $0.10 |
| gpt-4.1-nano | openai | In: text, image; Out: text | function_calling, structured_output, vision, tool_choice, parallel_tool_calls | 1047576 | 32768 | In: $0.10, Out: $0.40, Cache Read: $0.02 |
| gpt-4o | openai | In: text, image, pdf; Out: text | function_calling, structured_output, vision, tool_choice, parallel_tool_calls | 128000 | 16384 | In: $2.50, Out: $10.00, Cache Read: $1.25 |
| gpt-4o-2024-05-13 | openai | In: text, image; Out: text | function_calling, structured_output, vision, tool_choice, parallel_tool_calls | 128000 | 4096 | In: $5.00, Out: $15.00 |
| gpt-4o-2024-08-06 | openai | In: text, image; Out: text | function_calling, structured_output, vision, tool_choice, parallel_tool_calls | 128000 | 16384 | In: $2.50, Out: $10.00, Cache Read: $1.25 |
| gpt-4o-2024-11-20 | openai | In: text, image; Out: text | function_calling, structured_output, vision, tool_choice, parallel_tool_calls | 128000 | 16384 | In: $2.50, Out: $10.00, Cache Read: $1.25 |
| gpt-4o-mini | openai | In: text, image, pdf; Out: text | function_calling, structured_output, vision, tool_choice, parallel_tool_calls | 128000 | 16384 | In: $0.15, Out: $0.60, Cache Read: $0.08 |
| gpt-5 | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, tool_choice, parallel_tool_calls | 400000 | 128000 | In: $1.25, Out: $10.00, Cache Read: $0.12 |
| gpt-5-mini | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, tool_choice, parallel_tool_calls | 400000 | 128000 | In: $0.25, Out: $2.00, Cache Read: $0.02 |
| gpt-5-nano | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, tool_choice, parallel_tool_calls | 400000 | 128000 | In: $0.05, Out: $0.40, Cache Read: $0.01 |
| gpt-5-pro | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, tool_choice, parallel_tool_calls | 400000 | 272000 | In: $15.00, Out: $120.00 |
| gpt-5.1 | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, tool_choice, parallel_tool_calls | 400000 | 128000 | In: $1.25, Out: $10.00, Cache Read: $0.12 |
| gpt-5.2 | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, tool_choice, parallel_tool_calls | 400000 | 128000 | In: $1.75, Out: $14.00, Cache Read: $0.18 |
| gpt-5.2-chat-latest | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, tool_choice, parallel_tool_calls | 128000 | 16384 | In: $1.75, Out: $14.00, Cache Read: $0.18 |
| gpt-5.2-pro | openai | In: text, image; Out: text | function_calling, reasoning, vision, tool_choice, parallel_tool_calls | 400000 | 128000 | In: $21.00, Out: $168.00 |
| gpt-5.3-chat-latest | openai | In: text, image; Out: text | function_calling, structured_output, vision, tool_choice, parallel_tool_calls | 128000 | 16384 | In: $1.75, Out: $14.00, Cache Read: $0.18 |
| gpt-5.3-codex | openai | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, tool_choice, parallel_tool_calls | 400000 | 128000 | In: $1.75, Out: $14.00, Cache Read: $0.18 |
| gpt-5.3-codex-spark | openai | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 128000 | 32000 | In: $1.75, Out: $14.00, Cache Read: $0.18 |
| gpt-5.4 | openai | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, tool_choice, parallel_tool_calls | 1050000 | 128000 | In: $2.50, Out: $15.00, Cache Read: $0.25 |
| gpt-5.4-pro | openai | In: text, image; Out: text | function_calling, reasoning, vision, tool_choice, parallel_tool_calls | 1050000 | 128000 | In: $30.00, Out: $180.00 |
| gpt-5.4-mini | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, tool_choice, parallel_tool_calls | 400000 | 128000 | In: $0.75, Out: $4.50, Cache Read: $0.08 |
| gpt-5.4-nano | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, tool_choice, parallel_tool_calls | 400000 | 128000 | In: $0.20, Out: $1.25, Cache Read: $0.02 |
| gpt-5.5 | openai | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, tool_choice, parallel_tool_calls | 1050000 | 128000 | In: $5.00, Out: $30.00, Cache Read: $0.50 |
| gpt-5.5-pro | openai | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, tool_choice, parallel_tool_calls | 1050000 | 128000 | In: $30.00, Out: $180.00 |
| gpt-5.6 | openai | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1050000 | 128000 | In: $5.00, Out: $30.00, Cache Read: $0.50, Cache Write: $6.25 |
| gpt-5.6-luna | openai | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, tool_choice, parallel_tool_calls | 1050000 | 128000 | In: $0.20, Out: $1.20, Cache Read: $0.02, Cache Write: $0.25 |
| gpt-5.6-sol | openai | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, tool_choice, parallel_tool_calls | 1050000 | 128000 | In: $5.00, Out: $30.00, Cache Read: $0.50, Cache Write: $6.25 |
| gpt-5.6-terra | openai | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, tool_choice, parallel_tool_calls | 1050000 | 128000 | In: $2.00, Out: $12.00, Cache Read: $0.20, Cache Write: $2.50 |
| gpt-realtime-2.1 | openai | In: text, audio, image; Out: text, audio | function_calling, reasoning, vision | 128000 | 32000 | In: $4.00, Out: $24.00, Cache Read: $0.40 |
| gpt-4-0613 | openai | In: -; Out: - | function_calling, tool_choice, parallel_tool_calls | 8192 | 8192 | In: $10.00, Out: $30.00 |
| gpt-4-turbo-2024-04-09 | openai | In: -; Out: - | function_calling, tool_choice, parallel_tool_calls, vision | 128000 | 16384 | In: $10.00, Out: $30.00 |
| gpt-4.1-2025-04-14 | openai | In: -; Out: - | function_calling, tool_choice, parallel_tool_calls, structured_output, vision | 1047576 | 32768 | In: $2.00, Out: $8.00, Cache Read: $0.50 |
| gpt-4.1-mini-2025-04-14 | openai | In: -; Out: - | function_calling, tool_choice, parallel_tool_calls, structured_output, vision | 1047576 | 32768 | In: $0.40, Out: $1.60, Cache Read: $0.10 |
| gpt-4.1-nano-2025-04-14 | openai | In: -; Out: - | function_calling, tool_choice, parallel_tool_calls, structured_output, vision | 1047576 | 32768 | In: $0.10, Out: $0.40 |
| gpt-4o-mini-2024-07-18 | openai | In: -; Out: - | function_calling, tool_choice, parallel_tool_calls, structured_output, vision | 128000 | 16384 | In: $0.15, Out: $0.60 |
| gpt-5-2025-08-07 | openai | In: -; Out: - | function_calling, tool_choice, parallel_tool_calls, structured_output, vision, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache Read: $0.12 |
| gpt-5-chat-latest | openai | In: -; Out: - | function_calling, tool_choice, parallel_tool_calls, structured_output, vision, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache Read: $0.12 |
| gpt-5-codex | openai | In: -; Out: - | function_calling, tool_choice, parallel_tool_calls, structured_output, vision, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache Read: $0.12 |
| gpt-5-mini-2025-08-07 | openai | In: -; Out: - | function_calling, tool_choice, parallel_tool_calls, structured_output, vision, reasoning | 128000 | 400000 | In: $0.25, Out: $2.00, Cache Read: $0.02 |
| gpt-5-nano-2025-08-07 | openai | In: -; Out: - | function_calling, tool_choice, parallel_tool_calls, structured_output, vision, reasoning | 128000 | 400000 | In: $0.05, Out: $0.40, Cache Read: $0.01 |
| gpt-5-pro-2025-10-06 | openai | In: -; Out: - | function_calling, tool_choice, parallel_tool_calls, structured_output, vision, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache Read: $0.12 |
| gpt-5-search-api | openai | In: -; Out: - | function_calling, tool_choice, parallel_tool_calls, structured_output, vision, reasoning, citations | 128000 | 400000 | In: $1.25, Out: $10.00, Cache Read: $0.12 |
| gpt-5-search-api-2025-10-14 | openai | In: -; Out: - | function_calling, tool_choice, parallel_tool_calls, structured_output, vision, reasoning, citations | 128000 | 400000 | In: $1.25, Out: $10.00, Cache Read: $0.12 |
| gpt-5.1-2025-11-13 | openai | In: -; Out: - | function_calling, tool_choice, parallel_tool_calls, structured_output, vision, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache Read: $0.12 |
| gpt-5.1-chat-latest | openai | In: -; Out: - | function_calling, tool_choice, parallel_tool_calls, structured_output, vision, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache Read: $0.12 |
| gpt-5.1-codex | openai | In: -; Out: - | function_calling, tool_choice, parallel_tool_calls, structured_output, vision, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache Read: $0.12 |
| gpt-5.1-codex-max | openai | In: -; Out: - | function_calling, tool_choice, parallel_tool_calls, structured_output, vision, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache Read: $0.12 |
| gpt-5.1-codex-mini | openai | In: -; Out: - | function_calling, tool_choice, parallel_tool_calls, structured_output, vision, reasoning | 128000 | 400000 | In: $0.25, Out: $2.00, Cache Read: $0.02 |
| gpt-5.2-2025-12-11 | openai | In: -; Out: - | function_calling, tool_choice, parallel_tool_calls, structured_output, vision, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache Read: $0.12 |
| gpt-5.2-codex | openai | In: -; Out: - | function_calling, tool_choice, parallel_tool_calls, structured_output, vision, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache Read: $0.12 |
| gpt-5.2-pro-2025-12-11 | openai | In: -; Out: - | function_calling, tool_choice, parallel_tool_calls, structured_output, vision, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache Read: $0.12 |
| gpt-5.4-2026-03-05 | openai | In: -; Out: - | function_calling, tool_choice, parallel_tool_calls, structured_output, vision, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache Read: $0.12 |
| gpt-5.4-mini-2026-03-17 | openai | In: -; Out: - | function_calling, tool_choice, parallel_tool_calls, structured_output, vision, reasoning | 128000 | 400000 | In: $0.25, Out: $2.00, Cache Read: $0.02 |
| gpt-5.4-nano-2026-03-17 | openai | In: -; Out: - | function_calling, tool_choice, parallel_tool_calls, structured_output, vision, reasoning | 128000 | 400000 | In: $0.05, Out: $0.40, Cache Read: $0.01 |
| gpt-5.4-pro-2026-03-05 | openai | In: -; Out: - | function_calling, tool_choice, parallel_tool_calls, structured_output, vision, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache Read: $0.12 |
| gpt-5.5-2026-04-23 | openai | In: -; Out: - | function_calling, tool_choice, parallel_tool_calls, structured_output, vision, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache Read: $0.12 |
| gpt-5.5-pro-2026-04-23 | openai | In: -; Out: - | function_calling, tool_choice, parallel_tool_calls, structured_output, vision, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache Read: $0.12 |
| o1 | openai | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, tool_choice, parallel_tool_calls | 200000 | 100000 | In: $15.00, Out: $60.00, Cache Read: $7.50 |
| o1-2024-12-17 | openai | In: -; Out: - | function_calling, tool_choice, parallel_tool_calls, structured_output, vision, reasoning | 200000 | 100000 | In: $15.00, Out: $60.00 |
| o1-pro | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, tool_choice, parallel_tool_calls | 200000 | 100000 | In: $150.00, Out: $600.00 |
| o1-pro-2025-03-19 | openai | In: -; Out: - | function_calling, tool_choice, parallel_tool_calls, structured_output, vision, reasoning | 200000 | 100000 | In: $150.00, Out: $600.00 |
| o3 | openai | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 200000 | 100000 | In: $2.00, Out: $8.00, Cache Read: $0.50 |
| o3-mini | openai | In: text; Out: text | function_calling, structured_output, reasoning, tool_choice, parallel_tool_calls | 200000 | 100000 | In: $1.10, Out: $4.40, Cache Read: $0.55 |
| o3-mini-2025-01-31 | openai | In: -; Out: - | function_calling, tool_choice, parallel_tool_calls, structured_output, reasoning | 200000 | 100000 | In: $1.10, Out: $4.40 |
| o3-pro | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision | 200000 | 100000 | In: $20.00, Out: $80.00 |
| o4-mini | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision | 200000 | 100000 | In: $1.10, Out: $4.40, Cache Read: $0.28 |
| aion-labs/aion-2.0 | openrouter | In: text; Out: text | function_calling, reasoning, streaming | 131072 | 32768 | In: $0.80, Out: $1.60, Cache Read: $0.20 |
| aion-labs/aion-3.0 | openrouter | In: text; Out: text | function_calling, reasoning, streaming | 131072 | 32768 | In: $3.00, Out: $6.00, Cache Read: $0.75 |
| aion-labs/aion-3.0-mini | openrouter | In: text; Out: text | function_calling, reasoning, streaming | 131072 | 32768 | In: $0.70, Out: $1.40, Cache Read: $0.18 |
| ~anthropic/claude-haiku-latest | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 64000 | In: $1.00, Out: $5.00, Cache Read: $0.10, Cache Write: $1.25 |
| ~anthropic/claude-sonnet-latest | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 128000 | In: $2.00, Out: $10.00, Cache Read: $0.20, Cache Write: $2.50 |
| anthropic/claude-fable-5:batch | openrouter | In: text, image, file; Out: text | streaming, function_calling, structured_output | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| anthropic/claude-haiku-4.5:batch | openrouter | In: text, image, file; Out: text | streaming, function_calling, structured_output | 200000 | 64000 | In: $0.50, Out: $2.50, Cache Read: $0.05, Cache Write: $0.62 |
| anthropic/claude-opus-4.1:batch | openrouter | In: image, text, file; Out: text | streaming, function_calling, structured_output | 200000 | 32000 | In: $7.50, Out: $37.50, Cache Read: $0.75, Cache Write: $9.38 |
| anthropic/claude-opus-4.5:batch | openrouter | In: file, image, text; Out: text | streaming, function_calling, structured_output | 200000 | 64000 | In: $2.50, Out: $12.50, Cache Read: $0.25, Cache Write: $3.12 |
| anthropic/claude-opus-4.6:batch | openrouter | In: text, image, file; Out: text | streaming, function_calling, structured_output | 1000000 | 128000 | In: $2.50, Out: $12.50, Cache Read: $0.25, Cache Write: $3.12 |
| anthropic/claude-opus-4.7:batch | openrouter | In: text, image, file; Out: text | streaming, function_calling, structured_output | 1000000 | 128000 | In: $2.50, Out: $12.50, Cache Read: $0.25, Cache Write: $3.12 |
| anthropic/claude-opus-4.8:batch | openrouter | In: text, image, file; Out: text | streaming, function_calling, structured_output | 1000000 | 128000 | In: $2.50, Out: $12.50, Cache Read: $0.25, Cache Write: $3.12 |
| anthropic/claude-sonnet-4.5:batch | openrouter | In: text, image, file; Out: text | streaming, function_calling, structured_output | 1000000 | 64000 | In: $1.50, Out: $7.50, Cache Read: $0.15, Cache Write: $1.88 |
| anthropic/claude-sonnet-4.6:batch | openrouter | In: text, image, file; Out: text | streaming, function_calling, structured_output | 1000000 | 128000 | In: $1.50, Out: $7.50, Cache Read: $0.15, Cache Write: $1.88 |
| anthropic/claude-sonnet-5:batch | openrouter | In: text, image, file; Out: text | streaming, function_calling, structured_output | 1000000 | 128000 | In: $1.00, Out: $5.00, Cache Read: $0.10, Cache Write: $1.25 |
| openrouter/auto | openrouter | In: text, image, audio, pdf, video; Out: text, image | function_calling, structured_output, reasoning, vision, video, streaming, predicted_outputs, image_generation | 2000000 | 2000000 | - |
| openrouter/auto-beta | openrouter | In: text, image, audio, file, video; Out: text, image | streaming, function_calling, structured_output, predicted_outputs, image_generation | 2000000 | - | - |
| anthropic/claude-3-haiku | openrouter | In: text, image; Out: text | function_calling, vision, streaming | 200000 | 4096 | In: $0.25, Out: $1.25, Cache Read: $0.03, Cache Write: $0.30 |
| anthropic/claude-fable-5 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 128000 | In: $10.00, Out: $50.00, Cache Read: $1.00, Cache Write: $12.50 |
| ~anthropic/claude-fable-latest | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 128000 | In: $10.00, Out: $50.00, Cache Read: $1.00, Cache Write: $12.50 |
| anthropic/claude-haiku-4.5 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 64000 | In: $1.00, Out: $5.00, Cache Read: $0.10, Cache Write: $1.25 |
| anthropic/claude-opus-4 | openrouter | In: image, text, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 32000 | In: $15.00, Out: $75.00, Cache Read: $1.50, Cache Write: $18.75 |
| anthropic/claude-opus-4.1 | openrouter | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 32000 | In: $15.00, Out: $75.00, Cache Read: $1.50, Cache Write: $18.75 |
| anthropic/claude-opus-4.5 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 64000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| anthropic/claude-opus-4.6 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| anthropic/claude-opus-4.7 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| anthropic/claude-opus-4.7-fast | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 128000 | In: $30.00, Out: $150.00, Cache Read: $3.00, Cache Write: $37.50 |
| anthropic/claude-opus-4.8 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| anthropic/claude-opus-4.8-fast | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 128000 | In: $10.00, Out: $50.00, Cache Read: $1.00, Cache Write: $12.50 |
| anthropic/claude-opus-5 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| anthropic/claude-opus-5-fast | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 128000 | In: $10.00, Out: $50.00, Cache Read: $1.00, Cache Write: $12.50 |
| anthropic/claude-opus-5:batch | openrouter | In: text, image, file; Out: text | streaming, function_calling, structured_output | 1000000 | 128000 | In: $2.50, Out: $12.50, Cache Read: $0.25, Cache Write: $3.12 |
| ~anthropic/claude-opus-latest | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| anthropic/claude-sonnet-4 | openrouter | In: image, text, pdf; Out: text | function_calling, reasoning, vision, streaming | 1000000 | 64000 | In: $3.00, Out: $15.00, Cache Read: $0.30, Cache Write: $3.75 |
| anthropic/claude-sonnet-4.5 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 64000 | In: $3.00, Out: $15.00, Cache Read: $0.30, Cache Write: $3.75 |
| anthropic/claude-sonnet-4.6 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 128000 | In: $3.00, Out: $15.00, Cache Read: $0.30, Cache Write: $3.75 |
| anthropic/claude-sonnet-5 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 128000 | In: $2.00, Out: $10.00, Cache Read: $0.20, Cache Write: $2.50 |
| mistralai/codestral-2508 | openrouter | In: text, pdf; Out: text | function_calling, structured_output, vision, streaming | 256000 | 256000 | In: $0.30, Out: $0.90, Cache Read: $0.03 |
| cohere/command-r-08-2024 | openrouter | In: text; Out: text | function_calling, structured_output, streaming | 128000 | 4000 | In: $0.15, Out: $0.60 |
| cohere/command-r-plus-08-2024 | openrouter | In: text; Out: text | function_calling, structured_output, streaming | 128000 | 4000 | In: $2.50, Out: $10.00 |
| deepseek/deepseek-chat | openrouter | In: text; Out: text | function_calling, structured_output, streaming, predicted_outputs | 163840 | 16000 | In: $0.26, Out: $1.03 |
| deepseek/deepseek-chat-v3-0324 | openrouter | In: text; Out: text | function_calling, structured_output, streaming, predicted_outputs | 163840 | 163840 | In: $0.25, Out: $1.00 |
| deepseek/deepseek-chat-v3.1 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 163840 | 32768 | In: $0.25, Out: $0.95, Cache Read: $0.13 |
| deepseek/deepseek-v3.1-terminus | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 163840 | 163840 | In: $0.27, Out: $1.00 |
| deepseek/deepseek-v3.2 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 163840 | 65536 | In: $0.27, Out: $0.40, Cache Read: $0.13 |
| deepseek/deepseek-v3.2-exp | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 163840 | 65536 | In: $0.27, Out: $0.41 |
| deepseek/deepseek-v4-flash | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 1048576 | 384000 | In: $0.09, Out: $0.18, Cache Read: $0.02 |
| deepseek/deepseek-v4-flash-0731 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 1310720 | 393216 | In: $0.14, Out: $0.28, Cache Read: $0.03 |
| ~deepseek/deepseek-v4-flash-latest | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 1310720 | 262144 | In: $0.06, Out: $0.14, Cache Read: $0.01 |
| deepseek/deepseek-v4-pro | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 1048576 | 393216 | In: $1.60, Out: $3.20, Cache Read: $0.14 |
| deepseek/deepseek-v4-pro-0813 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 1048576 | 384000 | In: $1.19, Out: $3.56, Cache Read: $0.04 |
| deepseek/deepseek-r1 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 64000 | 16000 | In: $0.70, Out: $2.50 |
| dots-studio/dots-3-note-preview:free | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 512000 | 512000 | In: $0.00, Out: $0.00 |
| openrouter/free | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 8000 | In: $0.00, Out: $0.00 |
| sakana/fugu-ultra | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 128000 | In: $5.00, Out: $30.00, Cache Read: $0.50 |
| z-ai/glm-5.2:free | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 256000 | 256000 | In: $0.00, Out: $0.00 |
| ~z-ai/glm-latest | openrouter | In: text; Out: text | function_calling, reasoning, streaming | 1048576 | 131072 | In: $1.40, Out: $4.40, Cache Read: $0.26 |
| z-ai/glm-4.5 | openrouter | In: text; Out: text | function_calling, reasoning, streaming | 131072 | 98304 | In: $0.60, Out: $2.20, Cache Read: $0.11 |
| z-ai/glm-4.5-air | openrouter | In: text; Out: text | function_calling, reasoning, streaming | 131072 | 98304 | In: $0.13, Out: $0.85, Cache Read: $0.02 |
| z-ai/glm-4.5v | openrouter | In: text, image; Out: text | function_calling, reasoning, vision, streaming | 65536 | 16384 | In: $0.60, Out: $1.80, Cache Read: $0.11 |
| z-ai/glm-4.6 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 204800 | 131072 | In: $0.50, Out: $2.00, Cache Read: $0.10 |
| z-ai/glm-4.6v | openrouter | In: text, image, video; Out: text | function_calling, reasoning, vision, video, streaming | 131072 | 32768 | In: $0.30, Out: $0.90, Cache Read: $0.06 |
| z-ai/glm-4.7 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 204800 | 131072 | In: $0.40, Out: $1.75, Cache Read: $0.08 |
| z-ai/glm-4.7-flash | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 202752 | 16384 | In: $0.06, Out: $0.40, Cache Read: $0.01 |
| z-ai/glm-5 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 204800 | 128000 | In: $0.60, Out: $1.92, Cache Read: $0.12 |
| z-ai/glm-5-turbo | openrouter | In: text; Out: text | function_calling, reasoning, streaming | 202752 | 131072 | In: $1.20, Out: $4.00, Cache Read: $0.24 |
| z-ai/glm-5.1 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 204800 | 128000 | In: $0.97, Out: $3.04, Cache Read: $0.18 |
| z-ai/glm-5.2 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 1048576 | 131072 | In: $0.97, Out: $3.04, Cache Read: $0.19 |
| z-ai/glm-5.3 | openrouter | In: text; Out: text | function_calling, reasoning, streaming | 1048576 | 131072 | In: $1.40, Out: $4.40, Cache Read: $0.26 |
| z-ai/glm-5v-turbo | openrouter | In: image, text, video; Out: text | function_calling, reasoning, vision, video, streaming | 202752 | 131072 | In: $1.20, Out: $4.00, Cache Read: $0.24 |
| openai/gpt-audio | openrouter | In: text, audio; Out: text, audio | function_calling, structured_output, streaming | 128000 | 16384 | In: $2.50, Out: $10.00 |
| openai/gpt-audio-mini | openrouter | In: text, audio; Out: text, audio | function_calling, structured_output, streaming | 128000 | 16384 | In: $0.60, Out: $2.40 |
| openai/gpt-chat-latest | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, vision, streaming | 400000 | 128000 | In: $5.00, Out: $30.00, Cache Read: $0.50 |
| openai/gpt-oss-120b | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 131072 | 131072 | In: $0.03, Out: $0.17, Cache Read: $0.03 |
| openai/gpt-oss-20b | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 131072 | 131072 | In: $0.03, Out: $0.13, Cache Read: $0.03 |
| openai/gpt-3.5-turbo-0613 | openrouter | In: text; Out: text | function_calling, structured_output, streaming | 4095 | 4096 | In: $1.00, Out: $2.00 |
| openai/gpt-3.5-turbo-16k | openrouter | In: text; Out: text | function_calling, structured_output, streaming | 16385 | 4096 | In: $3.00, Out: $4.00 |
| openai/gpt-3.5-turbo | openrouter | In: text; Out: text | function_calling, structured_output, streaming | 16385 | 4096 | In: $0.50, Out: $1.50 |
| openai/gpt-4 | openrouter | In: text; Out: text | function_calling, structured_output, streaming | 8191 | 4096 | In: $30.00, Out: $60.00 |
| openai/gpt-4-turbo | openrouter | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 128000 | 4096 | In: $10.00, Out: $30.00 |
| openai/gpt-4-turbo-preview | openrouter | In: text; Out: text | function_calling, structured_output, streaming | 128000 | 4096 | In: $10.00, Out: $30.00 |
| openai/gpt-4.1 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, vision, streaming | 1047576 | 32768 | In: $2.00, Out: $8.00, Cache Read: $0.50 |
| openai/gpt-4.1-mini | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, vision, streaming | 1047576 | 32768 | In: $0.40, Out: $1.60, Cache Read: $0.10 |
| openai/gpt-4.1-nano | openrouter | In: image, text, pdf; Out: text | function_calling, structured_output, vision, streaming | 1047576 | 32768 | In: $0.10, Out: $0.40, Cache Read: $0.02 |
| openai/gpt-4o | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, vision, streaming | 128000 | 16384 | In: $2.50, Out: $10.00, Cache Read: $1.25 |
| openai/gpt-4o-2024-05-13 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, vision, streaming | 128000 | 4096 | In: $5.00, Out: $15.00 |
| openai/gpt-4o-2024-08-06 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, vision, streaming | 128000 | 16384 | In: $2.50, Out: $10.00, Cache Read: $1.25 |
| openai/gpt-4o-2024-11-20 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, vision, streaming | 128000 | 16384 | In: $2.50, Out: $10.00, Cache Read: $1.25 |
| openai/gpt-4o-mini | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, vision, streaming | 128000 | 16384 | In: $0.15, Out: $0.60, Cache Read: $0.08 |
| openai/gpt-4o-mini-2024-07-18 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, vision, streaming | 128000 | 16384 | In: $0.15, Out: $0.60, Cache Read: $0.08 |
| openai/gpt-5 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $1.25, Out: $10.00, Cache Read: $0.12 |
| openai/gpt-5-mini | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $0.25, Out: $2.00, Cache Read: $0.02 |
| openai/gpt-5-nano | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $0.05, Out: $0.40, Cache Read: $0.01 |
| openai/gpt-5-pro | openrouter | In: image, text, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $15.00, Out: $120.00 |
| openai/gpt-5.1 | openrouter | In: image, text, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $1.25, Out: $10.00, Cache Read: $0.12 |
| openai/gpt-5.1-codex | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $1.25, Out: $10.00, Cache Read: $0.13 |
| openai/gpt-5.1-codex-max | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $1.25, Out: $10.00, Cache Read: $0.12 |
| openai/gpt-5.1-codex-mini | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $0.25, Out: $2.00, Cache Read: $0.03 |
| openai/gpt-5.2 | openrouter | In: pdf, image, text; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $1.75, Out: $14.00, Cache Read: $0.18 |
| openai/gpt-5.2-chat | openrouter | In: pdf, image, text; Out: text | function_calling, structured_output, vision, streaming | 128000 | 32000 | In: $1.75, Out: $14.00, Cache Read: $0.18 |
| openai/gpt-5.2-codex | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $1.75, Out: $14.00, Cache Read: $0.18 |
| openai/gpt-5.2-pro | openrouter | In: image, text, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $21.00, Out: $168.00 |
| openai/gpt-5.3-codex | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $1.75, Out: $14.00, Cache Read: $0.18 |
| openai/gpt-5.4 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1050000 | 128000 | In: $2.50, Out: $15.00, Cache Read: $0.25 |
| openai/gpt-5.4-pro | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1050000 | 128000 | In: $30.00, Out: $180.00 |
| openai/gpt-5.4-mini | openrouter | In: pdf, image, text; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $0.75, Out: $4.50, Cache Read: $0.08 |
| openai/gpt-5.4-nano | openrouter | In: pdf, image, text; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $0.20, Out: $1.25, Cache Read: $0.02 |
| openai/gpt-5.5 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1050000 | 128000 | In: $5.00, Out: $30.00, Cache Read: $0.50 |
| openai/gpt-5.5-pro | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1050000 | 128000 | In: $30.00, Out: $180.00 |
| openai/gpt-5.6-luna | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1050000 | 128000 | In: $0.20, Out: $1.20, Cache Read: $0.02, Cache Write: $0.25 |
| openai/gpt-5.6-luna-pro | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1050000 | 128000 | In: $0.20, Out: $1.20, Cache Read: $0.02, Cache Write: $0.25 |
| openai/gpt-5.6-sol | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1050000 | 128000 | In: $2.50, Out: $15.00, Cache Read: $0.25, Cache Write: $3.12 |
| openai/gpt-5.6-sol-pro | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1050000 | 128000 | In: $2.50, Out: $15.00, Cache Read: $0.25, Cache Write: $3.12 |
| openai/gpt-5.6-terra | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1050000 | 128000 | In: $2.00, Out: $12.00, Cache Read: $0.20, Cache Write: $2.50 |
| openai/gpt-5.6-terra-pro | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1050000 | 128000 | In: $2.00, Out: $12.00, Cache Read: $0.20, Cache Write: $2.50 |
| google/gemini-2.5-flash | openrouter | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1048576 | 65535 | In: $0.30, Out: $2.50, Cache Read: $0.03, Cache Write: $0.08 |
| google/gemini-2.5-flash-lite | openrouter | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1048576 | 65535 | In: $0.10, Out: $0.40, Cache Read: $0.01, Cache Write: $0.08 |
| google/gemini-2.5-pro | openrouter | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1048576 | 65536 | In: $1.25, Out: $10.00, Cache Read: $0.12, Cache Write: $0.38 |
| google/gemini-2.5-pro-preview-05-06 | openrouter | In: text, image, pdf, audio, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1048576 | 65535 | In: $1.25, Out: $10.00, Cache Read: $0.12, Cache Write: $0.38 |
| google/gemini-2.5-pro-preview | openrouter | In: pdf, image, text, audio; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1048576 | 65536 | In: $1.25, Out: $10.00, Cache Read: $0.12, Cache Write: $0.38 |
| google/gemini-3-flash-preview | openrouter | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1048576 | 65536 | In: $0.50, Out: $3.00, Cache Read: $0.05, Cache Write: $0.08 |
| google/gemini-3.1-flash-lite | openrouter | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1048576 | 65536 | In: $0.25, Out: $1.50, Cache Read: $0.02, Cache Write: $0.08 |
| google/gemini-3.1-flash-lite-preview | openrouter | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1048576 | 65536 | In: $0.25, Out: $1.50, Cache Read: $0.02, Cache Write: $0.08 |
| google/gemini-3.1-pro-preview | openrouter | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1048576 | 65536 | In: $2.00, Out: $12.00, Cache Read: $0.20, Cache Write: $0.38 |
| google/gemini-3.1-pro-preview-customtools | openrouter | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1048576 | 65536 | In: $2.00, Out: $12.00, Cache Read: $0.20, Cache Write: $0.38 |
| google/gemini-3.5-flash | openrouter | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1048576 | 65536 | In: $1.50, Out: $9.00, Cache Read: $0.15, Cache Write: $0.08 |
| google/gemini-3.5-flash-lite | openrouter | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1048576 | 65536 | In: $0.30, Out: $2.50, Cache Read: $0.03, Cache Write: $0.08 |
| google/gemini-3.6-flash | openrouter | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1048576 | 65536 | In: $0.75, Out: $3.75, Cache Read: $0.08, Cache Write: $0.04 |
| google/gemini-3.7-flash | openrouter | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1048576 | 65536 | In: $0.38, Out: $1.88, Cache Read: $0.04, Cache Write: $0.02 |
| google/gemma-3-12b-it | openrouter | In: text, image; Out: text | function_calling, structured_output, vision, streaming, predicted_outputs | 131072 | 16384 | In: $0.05, Out: $0.15 |
| google/gemma-3-27b-it | openrouter | In: text, image; Out: text | function_calling, structured_output, vision, streaming, predicted_outputs | 262144 | 131072 | In: $0.08, Out: $0.45, Cache Read: $0.04 |
| google/gemma-4-26b-a4b-it:free | openrouter | In: image, text, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 262144 | 32768 | In: $0.00, Out: $0.00 |
| google/gemma-4-26b-a4b-it | openrouter | In: image, text, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming, predicted_outputs | 262144 | 16384 | In: $0.07, Out: $0.34 |
| google/gemma-4-31b-it:free | openrouter | In: image, text, video; Out: text | function_calling, reasoning, vision, video, streaming | 262144 | 32768 | In: $0.00, Out: $0.00 |
| google/gemma-4-31b-it | openrouter | In: image, text, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming, predicted_outputs | 262144 | 16384 | In: $0.09, Out: $0.34, Cache Read: $0.05 |
| ~google/gemini-flash-latest | openrouter | In: text, image, video, pdf, audio; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1048576 | 65536 | In: $0.38, Out: $1.88, Cache Read: $0.04, Cache Write: $0.02 |
| ~google/gemini-pro-latest | openrouter | In: audio, pdf, image, text, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1048576 | 65536 | In: $2.00, Out: $12.00, Cache Read: $0.20, Cache Write: $0.38 |
| google/gemini-2.5-flash:batch | openrouter | In: file, image, text, audio, video; Out: text | streaming, function_calling, structured_output | 1048576 | 65535 | In: $0.15, Out: $1.25, Cache Read: $0.03 |
| google/gemini-2.5-flash-lite:batch | openrouter | In: text, image, file, audio, video; Out: text | streaming, function_calling, structured_output | 1048576 | 65535 | In: $0.05, Out: $0.20, Cache Read: $0.01 |
| google/gemini-2.5-pro:batch | openrouter | In: text, image, file, audio, video; Out: text | streaming, function_calling, structured_output | 1048576 | 65536 | In: $0.62, Out: $5.00, Cache Read: $0.12 |
| google/gemini-3-flash-preview:batch | openrouter | In: text, image, file, audio, video; Out: text | streaming, function_calling, structured_output | 1048576 | 65536 | In: $0.25, Out: $1.50 |
| google/gemini-3.1-flash-lite:batch | openrouter | In: text, image, video, file, audio; Out: text | streaming, function_calling, structured_output | 1048576 | 65536 | In: $0.12, Out: $0.75, Cache Read: $0.01 |
| google/gemini-3.1-pro-preview:batch | openrouter | In: audio, file, image, text, video; Out: text | streaming, function_calling, structured_output | 1048576 | 65536 | In: $1.00, Out: $6.00 |
| google/gemini-3.5-flash:batch | openrouter | In: text, image, video, file, audio; Out: text | streaming, function_calling, structured_output | 1048576 | 65536 | In: $0.75, Out: $4.50, Cache Read: $0.08 |
| google/gemini-3.5-flash-lite:batch | openrouter | In: text, image, video, file, audio; Out: text | streaming, function_calling, structured_output | 1048576 | 65536 | In: $0.15, Out: $1.25, Cache Read: $0.02 |
| google/gemini-3.6-flash:batch | openrouter | In: text, image, video, file, audio; Out: text | streaming, function_calling, structured_output | 1048576 | 65536 | In: $0.38, Out: $1.88, Cache Read: $0.04, Cache Write: $0.04 |
| google/gemini-3.7-flash:batch | openrouter | In: text, image, video, file, audio; Out: text | streaming, function_calling, structured_output | 1048576 | 65536 | In: $0.19, Out: $0.94, Cache Read: $0.02, Cache Write: $0.02 |
| ibm-granite/granite-4.1-8b | openrouter | In: text; Out: text | function_calling, structured_output, streaming | 131072 | 131072 | In: $0.05, Out: $0.10, Cache Read: $0.05 |
| x-ai/grok-4.20 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 2000000 | 2000000 | In: $1.25, Out: $2.50, Cache Read: $0.20 |
| x-ai/grok-4.3 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 1000000 | In: $1.25, Out: $2.50, Cache Read: $0.20 |
| x-ai/grok-4.5 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 500000 | 500000 | In: $2.00, Out: $6.00, Cache Read: $0.30 |
| x-ai/grok-4.6 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 500000 | 500000 | In: $2.00, Out: $6.00, Cache Read: $0.50 |
| x-ai/grok-build-0.1 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 256000 | 256000 | In: $1.00, Out: $2.00, Cache Read: $0.20 |
| ~x-ai/grok-latest | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 500000 | 1000000 | In: $2.00, Out: $6.00, Cache Read: $0.50 |
| tencent/hy3 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 262144 | 128000 | In: $0.13, Out: $0.53, Cache Read: $0.03 |
| tencent/hy3-preview | openrouter | In: text; Out: text | function_calling, reasoning, streaming | 262144 | 262144 | In: $0.18, Out: $0.60, Cache Read: $0.06 |
| thinkingmachines/inkling | openrouter | In: text, image, audio; Out: text | function_calling, reasoning, vision, streaming, predicted_outputs | 1048576 | 262144 | In: $0.95, Out: $4.05, Cache Read: $0.16 |
| thinkingmachines/inkling-small | openrouter | In: text, image, audio; Out: text | function_calling, structured_output, reasoning, vision, streaming, predicted_outputs | 524288 | 262144 | In: $0.45, Out: $1.20, Cache Read: $0.10 |
| kwaipilot/kat-coder-air-v2.5 | openrouter | In: text; Out: text | function_calling, structured_output, streaming | 256000 | 80000 | In: $0.15, Out: $0.60, Cache Read: $0.03 |
| kwaipilot/kat-coder-pro-v2 | openrouter | In: text; Out: text | function_calling, structured_output, streaming, predicted_outputs | 262144 | 80000 | In: $0.30, Out: $1.20, Cache Read: $0.06 |
| kwaipilot/kat-coder-pro-v2.5 | openrouter | In: text; Out: text | function_calling, structured_output, streaming | 256000 | 80000 | In: $0.74, Out: $2.96, Cache Read: $0.15 |
| moonshotai/kimi-k2 | openrouter | In: text; Out: text | function_calling, streaming | 131072 | 100352 | In: $0.57, Out: $2.30 |
| moonshotai/kimi-k2-0905 | openrouter | In: text; Out: text | function_calling, structured_output, streaming | 262144 | 100352 | In: $0.60, Out: $2.50 |
| moonshotai/kimi-k2-thinking | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 262144 | 100352 | In: $0.60, Out: $2.50, Cache Read: $0.15 |
| moonshotai/kimi-k2.5 | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming, predicted_outputs | 262144 | 262144 | In: $0.45, Out: $2.25, Cache Read: $0.07 |
| moonshotai/kimi-k2.6 | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming, predicted_outputs | 262144 | 262144 | In: $0.95, Out: $4.00, Cache Read: $0.16 |
| moonshotai/kimi-k2.7-code | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming, predicted_outputs | 262144 | 262144 | In: $0.71, Out: $3.50, Cache Read: $0.15 |
| moonshotai/kimi-k3 | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming, predicted_outputs | 1048576 | 1048576 | In: $3.00, Out: $15.00, Cache Read: $0.30 |
| liquid/lfm-2.5-2.6b:free | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 128000 | 8192 | In: $0.00, Out: $0.00 |
| poolside/laguna-s-2.1 | openrouter | In: text; Out: text | function_calling, reasoning, streaming | 1048576 | 131072 | In: $0.09, Out: $0.18, Cache Read: $0.01 |
| poolside/laguna-s-2.1:free | openrouter | In: text; Out: text | function_calling, reasoning, streaming | 262144 | 32768 | In: $0.00, Out: $0.00 |
| poolside/laguna-xs-2.1 | openrouter | In: text; Out: text | function_calling, reasoning, streaming | 262144 | 32768 | In: $0.06, Out: $0.12, Cache Read: $0.03 |
| poolside/laguna-xs-2.1:free | openrouter | In: text; Out: text | function_calling, reasoning, streaming | 262144 | 32768 | In: $0.00, Out: $0.00 |
| inclusionai/ling-2.6-1t | openrouter | In: text; Out: text | function_calling, structured_output, streaming | 262144 | 32768 | In: $0.08, Out: $0.62, Cache Read: $0.02 |
| inclusionai/ling-2.6-flash | openrouter | In: text; Out: text | function_calling, structured_output, streaming | 262144 | 32768 | In: $0.01, Out: $0.03, Cache Read: $0.00 |
| inclusionai/ling-3.0-flash | openrouter | In: text; Out: text | function_calling, reasoning, streaming, predicted_outputs | 262144 | 32768 | In: $0.02, Out: $0.06, Cache Read: $0.00 |
| meta-llama/llama-3.1-70b-instruct | openrouter | In: text; Out: text | function_calling, structured_output, streaming, predicted_outputs | 131072 | 16384 | In: $0.40, Out: $0.40 |
| sao10k/l3.1-euryale-70b | openrouter | In: text; Out: text | function_calling, structured_output, streaming, predicted_outputs | 131072 | 16384 | In: $0.85, Out: $0.85 |
| meta-llama/llama-4-maverick | openrouter | In: text, image; Out: text | function_calling, structured_output, vision, streaming, predicted_outputs | 1048576 | 16384 | In: $0.20, Out: $0.80 |
| meta-llama/llama-4-scout | openrouter | In: text, image; Out: text | function_calling, structured_output, vision, streaming, predicted_outputs | 1310720 | 16384 | In: $0.10, Out: $0.30 |
| meta-llama/llama-3.1-8b-instruct | openrouter | In: text; Out: text | function_calling, structured_output, streaming, predicted_outputs | 131072 | 131072 | In: $0.05, Out: $0.08, Cache Read: $0.02 |
| meta-llama/llama-3.3-70b-instruct | openrouter | In: text; Out: text | function_calling, structured_output, streaming, predicted_outputs | 131072 | 16384 | In: $0.10, Out: $0.32 |
| meituan/longcat-2.0 | openrouter | In: text; Out: text | function_calling, reasoning, streaming, predicted_outputs | 1048756 | 262144 | In: $0.30, Out: $1.20, Cache Read: $0.01 |
| inception/mercury-2 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 128000 | 50000 | In: $0.25, Out: $0.75, Cache Read: $0.02 |
| xiaomi/mimo-v2.5 | openrouter | In: text, image, audio, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming, predicted_outputs | 1050000 | 131072 | In: $0.14, Out: $0.28, Cache Read: $0.00 |
| xiaomi/mimo-v2.5-pro | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 1050000 | 131072 | In: $0.44, Out: $0.87, Cache Read: $0.00 |
| minimax/minimax-m1 | openrouter | In: text; Out: text | function_calling, reasoning, streaming | 1000000 | 40000 | In: $0.55, Out: $2.20 |
| minimax/minimax-m2 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 204800 | 131072 | In: $0.26, Out: $1.02 |
| minimax/minimax-m2.1 | openrouter | In: text; Out: text | function_calling, reasoning, streaming | 204800 | 131072 | In: $0.30, Out: $1.20, Cache Read: $0.03 |
| minimax/minimax-m2.5 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 204800 | 196608 | In: $0.22, Out: $0.90, Cache Read: $0.06 |
| minimax/minimax-m2.7 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 204800 | 131072 | In: $0.30, Out: $1.20, Cache Read: $0.06 |
| minimax/minimax-m3 | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming, predicted_outputs | 1048576 | 512000 | In: $0.30, Out: $1.20, Cache Read: $0.06 |
| minimax/minimax-m3:batch | openrouter | In: text, image, video; Out: text | streaming, function_calling, structured_output, predicted_outputs | 524288 | - | In: $0.30, Out: $1.20, Cache Read: $0.06 |
| mistralai/ministral-14b-2512 | openrouter | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 262144 | 262144 | In: $0.20, Out: $0.20, Cache Read: $0.02 |
| mistralai/ministral-3b-2512 | openrouter | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 131072 | 131072 | In: $0.10, Out: $0.10, Cache Read: $0.01 |
| mistralai/ministral-8b-2512 | openrouter | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 262144 | 262144 | In: $0.15, Out: $0.15, Cache Read: $0.02 |
| mistralai/mistral-large | openrouter | In: text, pdf; Out: text | function_calling, structured_output, vision, streaming | 128000 | 128000 | In: $2.00, Out: $6.00, Cache Read: $0.20 |
| mistralai/mistral-large-2407 | openrouter | In: text, pdf; Out: text | function_calling, structured_output, vision, streaming | 131072 | 131072 | In: $2.00, Out: $6.00, Cache Read: $0.20 |
| mistralai/mistral-large-2512 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, vision, streaming | 262144 | 262144 | In: $0.50, Out: $1.50, Cache Read: $0.05 |
| mistralai/mistral-medium-3 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, vision, streaming | 131072 | 131072 | In: $0.40, Out: $2.00, Cache Read: $0.04 |
| mistralai/mistral-medium-3.1 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, vision, streaming | 131072 | 262144 | In: $0.40, Out: $2.00, Cache Read: $0.04 |
| mistralai/mistral-medium-3-5 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 262144 | 262144 | In: $1.50, Out: $7.50 |
| mistralai/mistral-nemo | openrouter | In: text; Out: text | function_calling, structured_output, streaming, predicted_outputs | 131072 | 16384 | In: $0.02, Out: $0.03 |
| mistralai/mistral-small-3.2-24b-instruct | openrouter | In: image, text; Out: text | function_calling, structured_output, vision, streaming, predicted_outputs | 256000 | 16384 | In: $0.09, Out: $0.25 |
| mistralai/mistral-small-2603 | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 262144 | 262144 | In: $0.15, Out: $0.60, Cache Read: $0.02 |
| mistralai/mixtral-8x22b-instruct | openrouter | In: text, pdf; Out: text | function_calling, structured_output, vision, streaming | 65536 | 65536 | In: $2.00, Out: $6.00, Cache Read: $0.20 |
| ~moonshotai/kimi-latest | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming, predicted_outputs | 1048576 | 974842 | In: $2.60, Out: $13.00, Cache Read: $0.29 |
| moonshotai/kimi-k2.7-code:batch | openrouter | In: text, image; Out: text | streaming, function_calling, structured_output, predicted_outputs | 262144 | - | In: $0.95, Out: $4.00, Cache Read: $0.19 |
| meta/muse-glimmer-30b | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming, predicted_outputs | 131072 | 131072 | In: $0.35, Out: $1.50, Cache Read: $0.04 |
| meta/muse-spark-1.1 | openrouter | In: text, image, video, pdf, audio; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1048576 | 1048576 | In: $1.25, Out: $4.25, Cache Read: $0.15 |
| meta/muse-spark-1.2 | openrouter | In: text, image, video, pdf, audio; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1048576 | 1048576 | In: $1.25, Out: $4.25, Cache Read: $0.15 |
| nvidia/nemotron-3-ultra-550b-a55b:batch | openrouter | In: text; Out: text | streaming, function_calling, structured_output, predicted_outputs | 512288 | - | In: $0.60, Out: $3.60, Cache Read: $0.20 |
| google/gemini-3-pro-image | openrouter | In: text, image; Out: text, image | function_calling, structured_output, reasoning, vision, streaming, image_generation | 131072 | 32768 | In: $2.00, Out: $12.00, Cache Read: $0.20, Cache Write: $0.38 |
| nvidia/nemotron-3-nano-30b-a3b | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 262144 | 262144 | In: $0.05, Out: $0.20, Cache Read: $0.03 |
| nvidia/nemotron-3-nano-30b-a3b:free | openrouter | In: text; Out: text | function_calling, reasoning, streaming | 256000 | 256000 | In: $0.00, Out: $0.00 |
| nvidia/nemotron-3-nano-omni-30b-a3b-reasoning:free | openrouter | In: text, image, video, audio; Out: text | function_calling, reasoning, vision, video, streaming | 256000 | 65536 | In: $0.00, Out: $0.00 |
| nvidia/nemotron-3-super-120b-a12b:free | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 262144 | 262144 | In: $0.00, Out: $0.00 |
| nvidia/nemotron-3-super-120b-a12b | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 1000000 | 16384 | In: $0.08, Out: $0.40 |
| nvidia/nemotron-3-ultra-550b-a55b:free | openrouter | In: text; Out: text | function_calling, reasoning, streaming | 1000000 | 65536 | In: $0.00, Out: $0.00 |
| nvidia/nemotron-3-ultra-550b-a55b | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 512288 | 16384 | In: $0.60, Out: $3.60, Cache Read: $0.20 |
| nvidia/nemotron-3.5-lightning:free | openrouter | In: text; Out: text | function_calling, reasoning, streaming | 1000000 | 65536 | In: $0.00, Out: $0.00 |
| nvidia/nemotron-3.5-lightning | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 1000000 | 131072 | In: $0.08, Out: $0.20, Cache Read: $0.04 |
| nvidia/nemotron-nano-12b-v2-vl:free | openrouter | In: text, image, video; Out: text | function_calling, reasoning, vision, video, streaming | 128000 | 128000 | In: $0.00, Out: $0.00 |
| nvidia/nemotron-nano-9b-v2:free | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 128000 | 128000 | In: $0.00, Out: $0.00 |
| nex-agi/nex-n2-mini | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 262144 | 262144 | In: $0.02, Out: $0.10, Cache Read: $0.00 |
| nex-agi/nex-n2-pro | openrouter | In: text, image; Out: text | function_calling, reasoning, vision, streaming | 262144 | 262144 | In: $0.25, Out: $1.00, Cache Read: $0.02 |
| cohere/north-mini-code:free | openrouter | In: text; Out: text | function_calling, reasoning, streaming | 256000 | 64000 | In: $0.00, Out: $0.00 |
| amazon/nova-2-lite-v1 | openrouter | In: text, image, video, pdf; Out: text | function_calling, reasoning, vision, video, streaming | 1000000 | 65535 | In: $0.30, Out: $2.50 |
| amazon/nova-lite-v1 | openrouter | In: text, image; Out: text | function_calling, vision, streaming | 300000 | 5120 | In: $0.06, Out: $0.24 |
| amazon/nova-micro-v1 | openrouter | In: text; Out: text | function_calling, streaming | 128000 | 5120 | In: $0.04, Out: $0.14 |
| amazon/nova-premier-v1 | openrouter | In: text, image; Out: text | function_calling, vision, streaming | 1000000 | 32000 | In: $2.50, Out: $12.50, Cache Read: $0.62 |
| amazon/nova-pro-v1 | openrouter | In: text, image; Out: text | function_calling, vision, streaming | 300000 | 5120 | In: $0.80, Out: $3.20 |
| ~openai/gpt-latest | openrouter | In: pdf, image, text; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1050000 | 128000 | In: $2.50, Out: $15.00, Cache Read: $0.25, Cache Write: $3.12 |
| ~openai/gpt-mini-latest | openrouter | In: pdf, image, text; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $0.75, Out: $4.50, Cache Read: $0.08 |
| openai/gpt-3.5-turbo:batch | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 16385 | 4096 | In: $0.25, Out: $0.75 |
| openai/gpt-4-turbo:batch | openrouter | In: text, image; Out: text | streaming, function_calling, structured_output | 128000 | 4096 | In: $5.00, Out: $15.00 |
| openai/gpt-4.1:batch | openrouter | In: image, text, file; Out: text | streaming, function_calling, structured_output | 1047576 | 32768 | In: $1.00, Out: $4.00, Cache Read: $0.25 |
| openai/gpt-4.1-mini:batch | openrouter | In: image, text, file; Out: text | streaming, function_calling, structured_output | 1047576 | 32768 | In: $0.20, Out: $0.80, Cache Read: $0.05 |
| openai/gpt-4.1-nano:batch | openrouter | In: image, text, file; Out: text | streaming, function_calling, structured_output | 1047576 | 32768 | In: $0.05, Out: $0.20, Cache Read: $0.01 |
| openai/gpt-4o:batch | openrouter | In: text, image, file; Out: text | streaming, function_calling, structured_output | 128000 | 16384 | In: $1.25, Out: $5.00, Cache Read: $0.62 |
| openai/gpt-4o-mini:batch | openrouter | In: text, image, file; Out: text | streaming, function_calling, structured_output | 128000 | 16384 | In: $0.08, Out: $0.30, Cache Read: $0.04 |
| openai/gpt-5:batch | openrouter | In: text, image, file; Out: text | streaming, function_calling, structured_output | 400000 | 128000 | In: $0.62, Out: $5.00, Cache Read: $0.06 |
| openai/gpt-5-codex:batch | openrouter | In: text, image; Out: text | streaming, function_calling, structured_output | 400000 | 128000 | In: $0.62, Out: $5.00, Cache Read: $0.06 |
| openai/gpt-5-mini:batch | openrouter | In: text, image, file; Out: text | streaming, function_calling, structured_output | 400000 | 128000 | In: $0.12, Out: $1.00, Cache Read: $0.01 |
| openai/gpt-5-nano:batch | openrouter | In: text, image, file; Out: text | streaming, function_calling, structured_output | 400000 | 128000 | In: $0.02, Out: $0.20, Cache Read: $0.00 |
| openai/gpt-5-pro:batch | openrouter | In: image, text, file; Out: text | streaming, function_calling, structured_output | 400000 | 128000 | In: $7.50, Out: $60.00 |
| openai/gpt-5.1:batch | openrouter | In: image, text, file; Out: text | streaming, function_calling, structured_output | 400000 | 128000 | In: $0.62, Out: $5.00, Cache Read: $0.06 |
| openai/gpt-5.2:batch | openrouter | In: file, image, text; Out: text | streaming, function_calling, structured_output | 400000 | 128000 | In: $0.88, Out: $7.00, Cache Read: $0.09 |
| openai/gpt-5.2-pro:batch | openrouter | In: image, text, file; Out: text | streaming, function_calling, structured_output | 400000 | 128000 | In: $10.50, Out: $84.00 |
| openai/gpt-5.4:batch | openrouter | In: text, image, file; Out: text | streaming, function_calling, structured_output | 1050000 | 128000 | In: $1.25, Out: $7.50, Cache Read: $0.12 |
| openai/gpt-5.4-mini:batch | openrouter | In: file, image, text; Out: text | streaming, function_calling, structured_output | 400000 | 128000 | In: $0.38, Out: $2.25, Cache Read: $0.04 |
| openai/gpt-5.4-nano:batch | openrouter | In: file, image, text; Out: text | streaming, function_calling, structured_output | 400000 | 128000 | In: $0.10, Out: $0.62, Cache Read: $0.01 |
| openai/gpt-5.4-pro:batch | openrouter | In: text, image, file; Out: text | streaming, function_calling, structured_output | 1050000 | 128000 | In: $15.00, Out: $90.00 |
| openai/gpt-5.5:batch | openrouter | In: file, image, text; Out: text | streaming, function_calling, structured_output | 1050000 | 128000 | In: $2.50, Out: $15.00, Cache Read: $0.25 |
| openai/gpt-5.5-pro:batch | openrouter | In: file, image, text; Out: text | streaming, function_calling, structured_output | 1050000 | 128000 | In: $15.00, Out: $90.00 |
| openai/gpt-5.6-luna:batch | openrouter | In: file, image, text; Out: text | streaming, function_calling, structured_output | 1050000 | 128000 | In: $0.10, Out: $0.60, Cache Read: $0.01 |
| openai/gpt-5.6-luna-pro:batch | openrouter | In: file, image, text; Out: text | streaming, function_calling, structured_output | 1050000 | 128000 | In: $0.10, Out: $0.60, Cache Read: $0.01 |
| openai/gpt-5.6-sol:batch | openrouter | In: file, image, text; Out: text | streaming, function_calling, structured_output | 1050000 | 128000 | In: $1.25, Out: $7.50, Cache Read: $0.12 |
| openai/gpt-5.6-sol-pro:batch | openrouter | In: file, image, text; Out: text | streaming, function_calling, structured_output | 1050000 | 128000 | In: $1.25, Out: $7.50, Cache Read: $0.12 |
| openai/gpt-5.6-terra:batch | openrouter | In: file, image, text; Out: text | streaming, function_calling, structured_output | 1050000 | 128000 | In: $1.00, Out: $6.00, Cache Read: $0.10 |
| openai/gpt-5.6-terra-pro:batch | openrouter | In: file, image, text; Out: text | streaming, function_calling, structured_output | 1050000 | 128000 | In: $1.00, Out: $6.00, Cache Read: $0.10 |
| openai/o1:batch | openrouter | In: text, image, file; Out: text | streaming, function_calling, structured_output | 200000 | 100000 | In: $7.50, Out: $30.00, Cache Read: $3.75 |
| openai/o3:batch | openrouter | In: image, text, file; Out: text | streaming, function_calling, structured_output | 200000 | 100000 | In: $1.00, Out: $4.00, Cache Read: $0.25 |
| openai/o3-mini:batch | openrouter | In: text, file; Out: text | streaming, function_calling, structured_output | 200000 | 100000 | In: $0.55, Out: $2.20, Cache Read: $0.28 |
| openai/o3-mini-high:batch | openrouter | In: text, file; Out: text | streaming, function_calling, structured_output | 200000 | 100000 | In: $0.55, Out: $2.20, Cache Read: $0.28 |
| openai/o3-pro:batch | openrouter | In: text, file, image; Out: text | streaming, function_calling, structured_output | 200000 | 100000 | In: $10.00, Out: $40.00 |
| openai/o4-mini:batch | openrouter | In: image, text, file; Out: text | streaming, function_calling, structured_output | 200000 | 100000 | In: $0.55, Out: $2.20, Cache Read: $0.14 |
| openai/o4-mini-high:batch | openrouter | In: image, text, file; Out: text | streaming, function_calling, structured_output | 200000 | 100000 | In: $0.55, Out: $2.20, Cache Read: $0.14 |
| qwen/qwen-plus | openrouter | In: text; Out: text | function_calling, structured_output, streaming | 1000000 | 32768 | In: $0.26, Out: $0.78, Cache Read: $0.05, Cache Write: $0.32 |
| qwen/qwen-plus-2025-07-28 | openrouter | In: text; Out: text | function_calling, structured_output, streaming | 1000000 | 32768 | In: $0.26, Out: $0.78 |
| qwen/qwen-plus-2025-07-28:thinking | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 1000000 | 32768 | In: $0.26, Out: $0.78 |
| qwen/qwen-2.5-72b-instruct | openrouter | In: text; Out: text | function_calling, structured_output, streaming, predicted_outputs | 32768 | 16384 | In: $0.36, Out: $0.40 |
| qwen/qwen-2.5-7b-instruct | openrouter | In: text; Out: text | function_calling, structured_output, streaming, predicted_outputs | 32768 | 32768 | In: $0.10, Out: $0.20 |
| qwen/qwen3-14b | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 131072 | 16384 | In: $0.12, Out: $0.24 |
| qwen/qwen3-235b-a22b-2507 | openrouter | In: text; Out: text | function_calling, structured_output, streaming, predicted_outputs | 262144 | 16384 | In: $0.09, Out: $0.55 |
| qwen/qwen3-235b-a22b-thinking-2507 | openrouter | In: text; Out: text | function_calling, reasoning, streaming, predicted_outputs | 262144 | 32768 | In: $0.23, Out: $2.30 |
| qwen/qwen3-235b-a22b | openrouter | In: text; Out: text | function_calling, reasoning, streaming | 131072 | 8192 | In: $0.46, Out: $1.82 |
| qwen/qwen3-30b-a3b | openrouter | In: text; Out: text | function_calling, reasoning, streaming, predicted_outputs | 131072 | 8192 | In: $0.13, Out: $0.52 |
| qwen/qwen3-30b-a3b-instruct-2507 | openrouter | In: text; Out: text | function_calling, structured_output, streaming, predicted_outputs | 262144 | 32000 | In: $0.05, Out: $0.19 |
| qwen/qwen3-30b-a3b-thinking-2507 | openrouter | In: text; Out: text | function_calling, reasoning, streaming | 81920 | 32768 | In: $0.20, Out: $2.40 |
| qwen/qwen3-32b | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 131072 | 16384 | In: $0.08, Out: $0.28 |
| qwen/qwen3-8b | openrouter | In: text; Out: text | function_calling, reasoning, streaming | 131072 | 8192 | In: $0.12, Out: $0.46 |
| qwen/qwen3-coder | openrouter | In: text; Out: text | function_calling, structured_output, streaming, predicted_outputs | 262144 | 65536 | In: $0.30, Out: $1.00, Cache Read: $0.10 |
| qwen/qwen3-coder-flash | openrouter | In: text; Out: text | function_calling, streaming | 1000000 | 65536 | In: $0.20, Out: $0.98, Cache Read: $0.04, Cache Write: $0.24 |
| qwen/qwen3-coder-next | openrouter | In: text; Out: text | function_calling, structured_output, streaming, predicted_outputs | 262144 | 262144 | In: $0.12, Out: $0.80, Cache Read: $0.07 |
| qwen/qwen3-coder-plus | openrouter | In: text; Out: text | function_calling, structured_output, streaming | 1000000 | 65536 | In: $0.65, Out: $3.25, Cache Read: $0.13, Cache Write: $0.81 |
| qwen/qwen3-max | openrouter | In: text; Out: text | function_calling, structured_output, streaming | 262144 | 65536 | In: $0.78, Out: $3.90, Cache Read: $0.16, Cache Write: $0.98 |
| qwen/qwen3-max-thinking | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 262144 | 65536 | In: $0.78, Out: $3.90 |
| qwen/qwen3-vl-235b-a22b-instruct | openrouter | In: text, image; Out: text | function_calling, structured_output, vision, streaming, predicted_outputs | 262144 | 32768 | In: $0.21, Out: $1.90, Cache Read: $0.10 |
| qwen/qwen3-vl-235b-a22b-thinking | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 131072 | 32768 | In: $0.40, Out: $4.00 |
| qwen/qwen3-vl-30b-a3b-instruct | openrouter | In: text, image; Out: text | function_calling, structured_output, vision, streaming, predicted_outputs | 262144 | 32768 | In: $0.13, Out: $0.52 |
| qwen/qwen3-vl-30b-a3b-thinking | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 262144 | 32768 | In: $0.20, Out: $2.40 |
| qwen/qwen3-vl-32b-instruct | openrouter | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 131072 | 32768 | In: $0.10, Out: $0.42 |
| qwen/qwen3-vl-8b-instruct | openrouter | In: image, text; Out: text | function_calling, structured_output, vision, streaming, predicted_outputs | 262144 | 32768 | In: $0.12, Out: $0.46 |
| qwen/qwen3-vl-8b-thinking | openrouter | In: image, text; Out: text | function_calling, structured_output, reasoning, vision, streaming | 131072 | 32768 | In: $0.18, Out: $2.10 |
| qwen/qwen3-coder-30b-a3b-instruct | openrouter | In: text; Out: text | function_calling, structured_output, streaming | 262144 | 262144 | In: $0.07, Out: $0.28 |
| qwen/qwen3-next-80b-a3b-thinking | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 262144 | 32768 | In: $0.15, Out: $1.20 |
| qwen/qwen3-next-80b-a3b-instruct | openrouter | In: text; Out: text | function_calling, structured_output, streaming, predicted_outputs | 262144 | 16384 | In: $0.09, Out: $1.10 |
| qwen/qwen3.5-122b-a10b | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming, predicted_outputs | 262144 | 262144 | In: $0.26, Out: $2.08 |
| qwen/qwen3.5-27b | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming, predicted_outputs | 262144 | 65536 | In: $0.20, Out: $1.56 |
| qwen/qwen3.5-35b-a3b | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming, predicted_outputs | 262144 | 262144 | In: $0.25, Out: $1.25, Cache Read: $0.25 |
| qwen/qwen3.5-397b-a17b | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming, predicted_outputs | 262144 | 65536 | In: $0.39, Out: $2.34 |
| qwen/qwen3.5-9b | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming, predicted_outputs | 262144 | 262144 | In: $0.10, Out: $0.15 |
| qwen/qwen3.5-plus-02-15 | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1000000 | 65536 | In: $0.26, Out: $1.56 |
| qwen/qwen3.5-plus-20260420 | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1000000 | 65536 | In: $0.30, Out: $1.80, Cache Write: $0.38 |
| qwen/qwen3.5-flash-02-23 | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1000000 | 65536 | In: $0.06, Out: $0.26 |
| qwen/qwen3.6-27b | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming, predicted_outputs | 262144 | 262144 | In: $0.60, Out: $3.60, Cache Read: $0.12 |
| qwen/qwen3.6-35b-a3b | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming, predicted_outputs | 262144 | 262144 | In: $0.14, Out: $1.00, Cache Read: $0.05 |
| qwen/qwen3.6-flash | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1000000 | 65536 | In: $0.19, Out: $1.12, Cache Write: $0.23 |
| qwen/qwen3.6-max-preview | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 262144 | 65536 | In: $1.03, Out: $6.16, Cache Write: $1.28 |
| qwen/qwen3.6-plus | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1000000 | 65536 | In: $0.32, Out: $1.95, Cache Write: $0.41 |
| qwen/qwen3.7-flash | openrouter | In: text, image, video; Out: text | function_calling, reasoning, vision, video, streaming | 1000000 | 65536 | In: $0.03, Out: $0.13, Cache Read: $0.01, Cache Write: $0.04 |
| qwen/qwen3.7-max | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 1000000 | 131072 | In: $1.48, Out: $4.42, Cache Read: $0.30, Cache Write: $1.84 |
| qwen/qwen3.7-plus | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 131072 | In: $0.32, Out: $1.28, Cache Read: $0.06, Cache Write: $0.40 |
| qwen/qwen3.8-2.4t-a95b | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 1048576 | 262144 | In: $2.00, Out: $6.00, Cache Read: $0.25 |
| qwen/qwen3.8-27b | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming, predicted_outputs | 1000000 | 131072 | In: $0.45, Out: $3.20, Cache Read: $0.05 |
| qwen/qwen3.8-max | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1000000 | 131072 | In: $2.00, Out: $6.00, Cache Read: $0.25, Cache Write: $2.50 |
| deepseek/deepseek-r1-0528 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 163840 | 32768 | In: $0.50, Out: $2.15, Cache Read: $0.35 |
| rekaai/reka-edge | openrouter | In: image, text, video; Out: text | function_calling, structured_output, vision, video, streaming | 16384 | 16384 | In: $0.10, Out: $0.10 |
| relace/relace-search | openrouter | In: text; Out: text | function_calling, streaming | 256000 | 128000 | In: $1.00, Out: $3.00 |
| inclusionai/ring-2.6-1t | openrouter | In: text; Out: text | function_calling, reasoning, streaming | 262144 | 65536 | In: $0.08, Out: $0.62, Cache Read: $0.02 |
| mistralai/mistral-saba | openrouter | In: text, pdf; Out: text | function_calling, structured_output, vision, streaming | 32768 | 32768 | In: $0.20, Out: $0.60, Cache Read: $0.02 |
| sakana/sakana-namazu | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 262144 | 65536 | In: $0.95, Out: $4.00, Cache Read: $0.15 |
| bytedance-seed/seed-1.6 | openrouter | In: image, text, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 262144 | 32768 | In: $0.25, Out: $2.00 |
| bytedance-seed/seed-1.6-flash | openrouter | In: image, text, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 262144 | 32768 | In: $0.08, Out: $0.30 |
| bytedance-seed/seed-2.0-code | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 262144 | 131072 | In: $0.50, Out: $3.00 |
| bytedance-seed/seed-2.0-lite | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 262144 | 131072 | In: $0.25, Out: $2.00 |
| bytedance-seed/seed-2.0-mini | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 262144 | 131072 | In: $0.10, Out: $0.40 |
| bytedance-seed/seed-2-1-turbo | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 262144 | 262144 | In: $0.50, Out: $2.50 |
| upstage/solar-pro-3 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 131072 | 131072 | In: $0.15, Out: $0.60, Cache Read: $0.02 |
| upstage/solar-pro4 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 524288 | 131072 | In: $0.03, Out: $0.12, Cache Read: $0.01 |
| stepfun/step-3.5-flash | openrouter | In: text; Out: text | function_calling, reasoning, streaming | 262144 | 65536 | In: $0.10, Out: $0.30 |
| stepfun/step-3.7-flash | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming, predicted_outputs | 262144 | 256000 | In: $0.20, Out: $1.15, Cache Read: $0.04 |
| thinkingmachines/inkling:batch | openrouter | In: text, image, audio; Out: text | streaming, function_calling, predicted_outputs | 524288 | - | In: $1.00, Out: $4.05, Cache Read: $0.17 |
| arcee-ai/trinity-large-thinking | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 262144 | 262144 | In: $0.22, Out: $0.85, Cache Read: $0.06 |
| thedrummer/unslopnemo-12b | openrouter | In: text; Out: text | function_calling, structured_output, streaming, predicted_outputs | 1024000 | 1024000 | In: $0.40, Out: $0.40 |
| arcee-ai/virtuoso-large | openrouter | In: text; Out: text | function_calling, streaming, predicted_outputs | 131072 | 64000 | In: $0.75, Out: $1.20 |
| mistralai/voxtral-small-24b-2507 | openrouter | In: text, audio, pdf; Out: text | function_calling, structured_output, vision, streaming | 32000 | 32000 | In: $0.10, Out: $0.30, Cache Read: $0.01 |
| z-ai/glm-5.2:batch | openrouter | In: text; Out: text | streaming, function_calling, structured_output, predicted_outputs | 512000 | - | In: $1.40, Out: $4.40, Cache Read: $0.26 |
| openai/gpt-oss-20b:free | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 131072 | 32768 | In: $0.00, Out: $0.00 |
| openai/gpt-oss-safeguard-20b | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 131072 | 65536 | In: $0.08, Out: $0.30, Cache Read: $0.04 |
| openai/o1 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 100000 | In: $15.00, Out: $60.00, Cache Read: $7.50 |
| openai/o3 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 100000 | In: $2.00, Out: $8.00, Cache Read: $0.50 |
| openai/o3-mini-high | openrouter | In: text, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 100000 | In: $1.10, Out: $4.40, Cache Read: $0.55 |
| openai/o3-mini | openrouter | In: text, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 100000 | In: $1.10, Out: $4.40, Cache Read: $0.55 |
| openai/o3-pro | openrouter | In: text, pdf, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 100000 | In: $20.00, Out: $80.00 |
| openai/o4-mini-high | openrouter | In: image, text, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 100000 | In: $1.10, Out: $4.40, Cache Read: $0.28 |
| openai/o4-mini | openrouter | In: image, text, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 100000 | In: $1.10, Out: $4.40, Cache Read: $0.28 |
| claude-haiku-4-5 | vertexai | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 64000 | In: $1.00, Out: $5.00, Cache Read: $0.10, Cache Write: $1.25 |
| claude-opus-4 | vertexai | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 200000 | 32000 | In: $15.00, Out: $75.00, Cache Read: $1.50, Cache Write: $18.75 |
| claude-opus-4-1 | vertexai | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 32000 | In: $15.00, Out: $75.00, Cache Read: $1.50, Cache Write: $18.75 |
| claude-opus-4-5 | vertexai | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 64000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| claude-opus-4-6 | vertexai | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| claude-opus-4-7 | vertexai | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| claude-opus-4-8 | vertexai | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| claude-opus-5 | vertexai | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| claude-sonnet-4 | vertexai | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 200000 | 64000 | In: $3.00, Out: $15.00, Cache Read: $0.30, Cache Write: $3.75 |
| claude-sonnet-4-5 | vertexai | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 64000 | In: $3.00, Out: $15.00, Cache Read: $0.30, Cache Write: $3.75 |
| claude-sonnet-4-6 | vertexai | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 1000000 | 128000 | In: $3.00, Out: $15.00, Cache Read: $0.30, Cache Write: $3.75 |
| claude-sonnet-5 | vertexai | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 1000000 | 128000 | In: $2.00, Out: $10.00, Cache Read: $0.20, Cache Write: $2.50 |
| deepseek-ai/deepseek-v3.1-maas | vertexai | In: text, pdf; Out: text | function_calling, structured_output, reasoning, vision | 163840 | 32768 | In: $0.60, Out: $1.70 |
| deepseek-ai/deepseek-v3.2-maas | vertexai | In: text, pdf; Out: text | function_calling, structured_output, reasoning, vision | 163840 | 65536 | In: $0.56, Out: $1.68, Cache Read: $0.06 |
| zai-org/glm-4.7-maas | vertexai | In: text, pdf; Out: text | function_calling, structured_output, reasoning, vision | 200000 | 128000 | In: $0.60, Out: $2.20 |
| zai-org/glm-5-maas | vertexai | In: text; Out: text | function_calling, reasoning | 202752 | 131072 | In: $1.00, Out: $3.20, Cache Read: $0.10 |
| openai/gpt-oss-120b-maas | vertexai | In: text; Out: text | function_calling, reasoning | 131072 | 32768 | In: $0.09, Out: $0.36 |
| openai/gpt-oss-20b-maas | vertexai | In: text; Out: text | function_calling, reasoning | 131072 | 32768 | In: $0.07, Out: $0.25 |
| gemini-2.5-flash | vertexai | In: text, image, audio, video, pdf; Out: text | function_calling, reasoning, vision, video, transcription, streaming | 1048576 | 65536 | In: $0.30, Out: $2.50, Cache Read: $0.08, Cache Write: $0.38 |
| gemini-2.5-flash-lite | vertexai | In: text, image, audio, video, pdf; Out: text | function_calling, reasoning, vision, video, transcription, streaming | 1048576 | 65536 | In: $0.10, Out: $0.40, Cache Read: $0.01 |
| gemini-2.5-pro | vertexai | In: text, image, audio, video, pdf; Out: text | function_calling, reasoning, vision, video, transcription, streaming | 1048576 | 65536 | In: $1.25, Out: $10.00, Cache Read: $0.12 |
| gemini-3-flash-preview | vertexai | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription, streaming | 1048576 | 65536 | In: $0.50, Out: $3.00, Cache Read: $0.05 |
| gemini-3.1-flash-lite | vertexai | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription, streaming | 1048576 | 65536 | In: $0.25, Out: $1.50, Cache Read: $0.02 |
| gemini-3.1-flash-lite-preview | vertexai | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription | 1048576 | 65536 | In: $0.25, Out: $1.50, Cache Read: $0.02 |
| gemini-3.1-pro-preview | vertexai | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription, streaming | 1048576 | 65536 | In: $2.00, Out: $12.00, Cache Read: $0.20 |
| gemini-3.1-pro-preview-customtools | vertexai | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription | 1048576 | 65536 | In: $2.00, Out: $12.00, Cache Read: $0.20 |
| gemini-3.5-flash | vertexai | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription, streaming | 1048576 | 65536 | In: $1.50, Out: $9.00, Cache Read: $0.15 |
| gemini-3.5-flash-lite | vertexai | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription, streaming | 1048576 | 65536 | In: $0.30, Out: $2.50, Cache Read: $0.03 |
| gemini-3.6-flash | vertexai | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription, streaming | 1048576 | 65536 | In: $1.50, Out: $7.50, Cache Read: $0.15 |
| gemini-3.7-flash | vertexai | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription, streaming | 1048576 | 65536 | In: $0.75, Out: $3.75, Cache Read: $0.08 |
| gemini-flash-latest | vertexai | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription | 1048576 | 65536 | In: $1.50, Out: $9.00, Cache Read: $0.15 |
| gemini-flash-lite-latest | vertexai | In: text, image, video, audio, pdf; Out: text | function_calling, reasoning, vision, video, transcription | 1048576 | 65536 | In: $0.25, Out: $1.50, Cache Read: $0.02 |
| moonshotai/kimi-k2-thinking-maas | vertexai | In: text; Out: text | function_calling, structured_output, reasoning | 262144 | 262144 | In: $0.60, Out: $2.50 |
| meta/llama-3.3-70b-instruct-maas | vertexai | In: text; Out: text | function_calling, structured_output | 128000 | 8192 | In: $0.72, Out: $0.72 |
| meta/llama-4-maverick-17b-128e-instruct-maas | vertexai | In: text, image; Out: text | function_calling, structured_output, vision | 524288 | 8192 | In: $0.35, Out: $1.15 |
| gemini-3.1-flash-lite-image | vertexai | In: text, image; Out: text, image | function_calling, reasoning, vision, streaming | 65536 | 65536 | In: $0.25, Out: $30.00 |
| qwen/qwen3-235b-a22b-instruct-2507-maas | vertexai | In: text; Out: text | function_calling, structured_output, reasoning | 262144 | 16384 | In: $0.22, Out: $0.88 |
| claude-fable-5 | vertexai | In: -; Out: - | streaming, function_calling | - | - | - |
| codestral-2 | vertexai | In: -; Out: - | streaming, function_calling | - | - | - |
| gemini-1.5-pro | vertexai | In: -; Out: - | streaming, function_calling | - | - | - |
| gemini-1.5-pro-002 | vertexai | In: -; Out: - | streaming, function_calling | - | - | - |
| gemini-2.0-flash-001 | vertexai | In: -; Out: - | streaming, function_calling | - | - | - |
| gemini-2.0-flash-lite-001 | vertexai | In: -; Out: - | streaming, function_calling | - | - | - |
| gemini-2.5-flash-preview-04-17 | vertexai | In: -; Out: - | streaming, function_calling | - | - | - |
| gemini-2.5-pro-exp-03-25 | vertexai | In: -; Out: - | streaming, function_calling | - | - | - |
| gemini-live-2.5-flash-native-audio | vertexai | In: -; Out: - | streaming, function_calling | - | - | - |
| gemini-pro | vertexai | In: -; Out: - | streaming, function_calling | - | - | - |
| gemini-pro-vision | vertexai | In: -; Out: - | streaming, function_calling | - | - | - |
| mistral-medium-3 | vertexai | In: -; Out: - | streaming, function_calling | - | - | - |
| mistral-small-2503 | vertexai | In: -; Out: - | streaming, function_calling | - | - | - |
| grok-4.20-0309-non-reasoning | xai | In: text, image, pdf; Out: text | function_calling, structured_output, vision, streaming | 1000000 | 30000 | In: $1.25, Out: $2.50, Cache Read: $0.20 |
| grok-4.20-0309-reasoning | xai | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 30000 | In: $1.25, Out: $2.50, Cache Read: $0.20 |
| grok-4.3 | xai | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 30000 | In: $1.25, Out: $2.50, Cache Read: $0.20 |
| grok-4.5 | xai | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 500000 | 500000 | In: $2.00, Out: $6.00, Cache Read: $0.30 |
| grok-4.6 | xai | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 500000 | 500000 | In: $2.00, Out: $6.00, Cache Read: $0.50 |
| grok-build-0.1 | xai | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 256000 | 256000 | In: $1.00, Out: $2.00, Cache Read: $0.20 |


### Structured Output (654)

| Model | Provider | I/O | Capabilities | Context | Max Output | Standard Pricing (per 1M tokens) |
| :-- | :-- | :-- | :-- | --: | --: | :-- |
| claude-fable-5 | anthropic | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, citations, tool_choice, parallel_tool_calls, batch | 1000000 | 128000 | In: $10.00, Out: $50.00, Cache Read: $1.00, Cache Write: $12.50 |
| claude-haiku-4-5-20251001 | anthropic | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, citations, tool_choice, parallel_tool_calls, batch | 200000 | 64000 | In: $1.00, Out: $5.00, Cache Read: $0.10, Cache Write: $1.25 |
| claude-haiku-4-5 | anthropic | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 200000 | 64000 | In: $1.00, Out: $5.00, Cache Read: $0.10, Cache Write: $1.25 |
| claude-opus-4-5-20251101 | anthropic | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, citations, tool_choice, parallel_tool_calls, batch | 200000 | 64000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| claude-opus-4-5 | anthropic | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 200000 | 64000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| claude-opus-4-6 | anthropic | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, citations, tool_choice, parallel_tool_calls, batch | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| claude-opus-4-7 | anthropic | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, citations, tool_choice, parallel_tool_calls, batch | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| claude-opus-4-8 | anthropic | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, citations, tool_choice, parallel_tool_calls, batch | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| claude-opus-5 | anthropic | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, citations, tool_choice, parallel_tool_calls, batch | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| claude-sonnet-4-5-20250929 | anthropic | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, citations, tool_choice, parallel_tool_calls, batch | 1000000 | 64000 | In: $3.00, Out: $15.00, Cache Read: $0.30, Cache Write: $3.75 |
| claude-sonnet-4-5 | anthropic | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1000000 | 64000 | In: $3.00, Out: $15.00, Cache Read: $0.30, Cache Write: $3.75 |
| claude-sonnet-4-6 | anthropic | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, citations, tool_choice, parallel_tool_calls, batch | 1000000 | 128000 | In: $3.00, Out: $15.00, Cache Read: $0.30, Cache Write: $3.75 |
| claude-sonnet-5 | anthropic | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, citations, tool_choice, parallel_tool_calls, batch | 1000000 | 128000 | In: $2.00, Out: $10.00, Cache Read: $0.20, Cache Write: $2.50 |
| au.anthropic.claude-opus-4-6-v1 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1000000 | 128000 | In: $16.50, Out: $82.50, Cache Read: $1.65, Cache Write: $20.62 |
| au.anthropic.claude-sonnet-4-6 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1000000 | 128000 | In: $3.30, Out: $16.50, Cache Read: $0.33, Cache Write: $4.12 |
| anthropic.claude-haiku-4-5-20251001-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 200000 | 64000 | In: $1.00, Out: $5.00, Cache Read: $0.10, Cache Write: $1.25 |
| au.anthropic.claude-haiku-4-5-20251001-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 200000 | 64000 | In: $1.00, Out: $5.00, Cache Read: $0.10, Cache Write: $1.25 |
| eu.anthropic.claude-haiku-4-5-20251001-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 200000 | 64000 | In: $1.10, Out: $5.50, Cache Read: $0.11, Cache Write: $1.38 |
| global.anthropic.claude-haiku-4-5-20251001-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 200000 | 64000 | In: $1.00, Out: $5.00, Cache Read: $0.10, Cache Write: $1.25 |
| jp.anthropic.claude-haiku-4-5-20251001-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 200000 | 64000 | In: $1.00, Out: $5.00, Cache Read: $0.10, Cache Write: $1.25 |
| us.anthropic.claude-haiku-4-5-20251001-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 64000 | In: $1.00, Out: $5.00, Cache Read: $0.10, Cache Write: $1.25 |
| anthropic.claude-opus-4-5-20251101-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 200000 | 64000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| eu.anthropic.claude-opus-4-5-20251101-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 200000 | 64000 | In: $5.50, Out: $27.50, Cache Read: $0.55, Cache Write: $6.88 |
| global.anthropic.claude-opus-4-5-20251101-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 200000 | 64000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| us.anthropic.claude-opus-4-5-20251101-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 64000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| anthropic.claude-opus-4-6-v1 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| eu.anthropic.claude-opus-4-6-v1 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1000000 | 128000 | In: $5.50, Out: $27.50, Cache Read: $0.55, Cache Write: $6.88 |
| global.anthropic.claude-opus-4-6-v1 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| us.anthropic.claude-opus-4-6-v1 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| us.anthropic.claude-opus-4-7 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming, structured_output | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| us.anthropic.claude-opus-4-8 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming, structured_output | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| anthropic.claude-sonnet-4-5-20250929-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 200000 | 64000 | In: $3.00, Out: $15.00, Cache Read: $0.30, Cache Write: $3.75 |
| au.anthropic.claude-sonnet-4-5-20250929-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 200000 | 64000 | In: $3.00, Out: $15.00, Cache Read: $0.30, Cache Write: $3.75 |
| eu.anthropic.claude-sonnet-4-5-20250929-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 200000 | 64000 | In: $3.30, Out: $16.50, Cache Read: $0.33, Cache Write: $4.12 |
| global.anthropic.claude-sonnet-4-5-20250929-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 200000 | 64000 | In: $3.00, Out: $15.00, Cache Read: $0.30, Cache Write: $3.75 |
| jp.anthropic.claude-sonnet-4-5-20250929-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 200000 | 64000 | In: $3.00, Out: $15.00, Cache Read: $0.30, Cache Write: $3.75 |
| us.anthropic.claude-sonnet-4-5-20250929-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 64000 | In: $3.00, Out: $15.00, Cache Read: $0.30, Cache Write: $3.75 |
| anthropic.claude-sonnet-4-6 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1000000 | 64000 | In: $3.00, Out: $15.00, Cache Read: $0.30, Cache Write: $3.75 |
| eu.anthropic.claude-sonnet-4-6 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1000000 | 64000 | In: $3.30, Out: $16.50, Cache Read: $0.33, Cache Write: $4.12 |
| global.anthropic.claude-sonnet-4-6 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1000000 | 64000 | In: $3.00, Out: $15.00, Cache Read: $0.30, Cache Write: $3.75 |
| jp.anthropic.claude-sonnet-4-6 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1000000 | 64000 | In: $3.00, Out: $15.00, Cache Read: $0.30, Cache Write: $3.75 |
| us.anthropic.claude-sonnet-4-6 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 64000 | In: $3.00, Out: $15.00, Cache Read: $0.30, Cache Write: $3.75 |
| anthropic.claude-sonnet-5 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1000000 | 128000 | In: $2.00, Out: $10.00, Cache Read: $0.20, Cache Write: $2.50 |
| au.anthropic.claude-sonnet-5 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1000000 | 128000 | In: $2.00, Out: $10.00, Cache Read: $0.20, Cache Write: $2.50 |
| eu.anthropic.claude-sonnet-5 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1000000 | 128000 | In: $2.20, Out: $11.00, Cache Read: $0.22, Cache Write: $2.75 |
| global.anthropic.claude-sonnet-5 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1000000 | 128000 | In: $2.00, Out: $10.00, Cache Read: $0.20, Cache Write: $2.50 |
| jp.anthropic.claude-sonnet-5 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1000000 | 128000 | In: $2.00, Out: $10.00, Cache Read: $0.20, Cache Write: $2.50 |
| us.anthropic.claude-sonnet-5 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 128000 | In: $2.00, Out: $10.00, Cache Read: $0.20, Cache Write: $2.50 |
| deepseek.v3-v1:0 | bedrock | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 163840 | 81920 | In: $0.58, Out: $1.68 |
| deepseek.v3.2 | bedrock | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 163840 | 81920 | In: $0.62, Out: $1.85 |
| mistral.devstral-2-123b | bedrock | In: text; Out: text | function_calling, structured_output, streaming | 256000 | 8192 | In: $0.40, Out: $2.00 |
| zai.glm-4.7 | bedrock | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 204800 | 131072 | In: $0.60, Out: $2.20 |
| zai.glm-4.7-flash | bedrock | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 200000 | 131072 | In: $0.07, Out: $0.40 |
| zai.glm-5 | bedrock | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 202752 | 101376 | In: $1.00, Out: $3.20 |
| openai.gpt-oss-safeguard-120b | bedrock | In: text; Out: text | function_calling, structured_output, streaming | 128000 | 16384 | In: $0.15, Out: $0.60 |
| openai.gpt-oss-safeguard-20b | bedrock | In: text; Out: text | function_calling, structured_output, streaming | 128000 | 16384 | In: $0.07, Out: $0.20 |
| openai.gpt-5.4 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 272000 | 128000 | In: $2.75, Out: $16.50, Cache Read: $0.28 |
| openai.gpt-5.5 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 272000 | 128000 | In: $5.50, Out: $33.00, Cache Read: $0.55 |
| openai.gpt-5.6-luna | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1050000 | 128000 | In: $0.22, Out: $1.32, Cache Read: $0.02, Cache Write: $0.28 |
| us.openai.gpt-5.6-luna | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1050000 | 128000 | In: $0.22, Out: $1.32, Cache Read: $0.02, Cache Write: $0.28 |
| global.openai.gpt-5.6-luna | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1050000 | 128000 | In: $0.22, Out: $1.32, Cache Read: $0.02, Cache Write: $0.28 |
| openai.gpt-5.6-sol | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1050000 | 128000 | In: $5.50, Out: $33.00, Cache Read: $0.55, Cache Write: $6.88 |
| us.openai.gpt-5.6-sol | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1050000 | 128000 | In: $5.50, Out: $33.00, Cache Read: $0.55, Cache Write: $6.88 |
| global.openai.gpt-5.6-sol | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1050000 | 128000 | In: $5.50, Out: $33.00, Cache Read: $0.55, Cache Write: $6.88 |
| openai.gpt-5.6-terra | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1050000 | 128000 | In: $2.20, Out: $13.20, Cache Read: $0.22, Cache Write: $2.75 |
| us.openai.gpt-5.6-terra | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1050000 | 128000 | In: $2.20, Out: $13.20, Cache Read: $0.22, Cache Write: $2.75 |
| global.openai.gpt-5.6-terra | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1050000 | 128000 | In: $2.20, Out: $13.20, Cache Read: $0.22, Cache Write: $2.75 |
| google.gemma-3-12b-it | bedrock | In: text, image; Out: text | structured_output, vision, streaming | 131072 | 8192 | In: $0.05, Out: $0.10 |
| google.gemma-3-27b-it | bedrock | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 202752 | 8192 | In: $0.12, Out: $0.20 |
| xai.grok-4.3 | bedrock | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 131072 | In: $1.25, Out: $2.50, Cache Read: $0.20 |
| us.xai.grok-4.6 | bedrock | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 500000 | 500000 | In: $2.20, Out: $6.60, Cache Read: $0.55 |
| xai.grok-4.6 | bedrock | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 500000 | 500000 | In: $2.20, Out: $6.60, Cache Read: $0.55 |
| moonshot.kimi-k2-thinking | bedrock | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 262143 | 16000 | In: $0.60, Out: $2.50 |
| moonshotai.kimi-k2.5 | bedrock | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 262143 | 16000 | In: $0.60, Out: $3.00 |
| mistral.magistral-small-2509 | bedrock | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 128000 | 40000 | In: $0.50, Out: $1.50 |
| mistral.ministral-3-14b-instruct | bedrock | In: text; Out: text | function_calling, structured_output, streaming | 128000 | 4096 | In: $0.20, Out: $0.20 |
| mistral.ministral-3-3b-instruct | bedrock | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 256000 | 8192 | In: $0.10, Out: $0.10 |
| mistral.ministral-3-8b-instruct | bedrock | In: text; Out: text | function_calling, structured_output, streaming | 128000 | 4096 | In: $0.15, Out: $0.15 |
| mistral.mistral-large-3-675b-instruct | bedrock | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 256000 | 8192 | In: $0.50, Out: $1.50 |
| nvidia.nemotron-super-3-120b | bedrock | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 262144 | 131072 | In: $0.15, Out: $0.65 |
| nvidia.nemotron-nano-12b-v2 | bedrock | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 128000 | 4096 | In: $0.20, Out: $0.60 |
| nvidia.nemotron-nano-3-30b | bedrock | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 128000 | 4096 | In: $0.06, Out: $0.24 |
| nvidia.nemotron-nano-9b-v2 | bedrock | In: text; Out: text | function_calling, structured_output, streaming | 128000 | 4096 | In: $0.06, Out: $0.23 |
| qwen.qwen3-next-80b-a3b | bedrock | In: text; Out: text | function_calling, structured_output, streaming | 262000 | 262000 | In: $0.14, Out: $1.40 |
| qwen.qwen3-vl-235b-a22b | bedrock | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 262000 | 262000 | In: $0.30, Out: $1.50 |
| qwen.qwen3-235b-a22b-2507-v1:0 | bedrock | In: text; Out: text | function_calling, structured_output, streaming | 262144 | 131072 | In: $0.22, Out: $0.88 |
| qwen.qwen3-32b-v1:0 | bedrock | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 16384 | 16384 | In: $0.15, Out: $0.60 |
| qwen.qwen3-coder-30b-a3b-v1:0 | bedrock | In: text; Out: text | function_calling, structured_output, streaming | 262144 | 131072 | In: $0.15, Out: $0.60 |
| qwen.qwen3-coder-480b-a35b-v1:0 | bedrock | In: text; Out: text | function_calling, structured_output, streaming | 131072 | 65536 | In: $0.22, Out: $1.80 |
| qwen.qwen3-coder-next | bedrock | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 131072 | 65536 | In: $0.22, Out: $1.80 |
| mistral.voxtral-mini-3b-2507 | bedrock | In: audio, text; Out: text | function_calling, structured_output, streaming | 128000 | 4096 | In: $0.04, Out: $0.04 |
| mistral.voxtral-small-24b-2507 | bedrock | In: text, audio; Out: text | function_calling, structured_output, streaming | 32000 | 8192 | In: $0.15, Out: $0.35 |
| openai.gpt-oss-120b | bedrock | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 128000 | 16384 | In: $0.15, Out: $0.60 |
| openai.gpt-oss-120b-1:0 | bedrock | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 128000 | 16384 | In: $0.15, Out: $0.60 |
| openai.gpt-oss-20b | bedrock | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 128000 | 16384 | In: $0.07, Out: $0.30 |
| openai.gpt-oss-20b-1:0 | bedrock | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 128000 | 16384 | In: $0.07, Out: $0.30 |
| command-a-03-2025 | cohere | In: text; Out: text | function_calling, streaming, structured_output, citations, tool_choice | 256000 | 8000 | In: $2.50, Out: $10.00 |
| command-a-plus-05-2026 | cohere | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming, citations | 128000 | 64000 | In: $2.50, Out: $10.00 |
| command-a-reasoning-08-2025 | cohere | In: text; Out: text | function_calling, reasoning, streaming, structured_output, citations | 256000 | 32000 | In: $2.50, Out: $10.00 |
| command-r-08-2024 | cohere | In: text; Out: text | function_calling, streaming, structured_output, citations, tool_choice | 128000 | 4000 | In: $0.15, Out: $0.60 |
| command-r-plus-08-2024 | cohere | In: text; Out: text | function_calling, streaming, structured_output, citations, tool_choice | 128000 | 4000 | In: $2.50, Out: $10.00 |
| command-r7b-12-2024 | cohere | In: text; Out: text | function_calling, streaming, structured_output, citations, tool_choice | 128000 | 4000 | In: $0.04, Out: $0.15 |
| command-r7b-arabic-02-2025 | cohere | In: text; Out: text | function_calling, streaming, structured_output, citations | 128000 | 4000 | In: $0.04, Out: $0.15 |
| north-mini-code-1-0 | cohere | In: text; Out: text | function_calling, structured_output, reasoning, streaming, citations | 256000 | 64000 | In: $0.00, Out: $0.00 |
| deepseek-v4-flash | deepseek | In: text; Out: text | function_calling, structured_output, reasoning, tool_choice | 1000000 | 384000 | In: $0.14, Out: $0.28, Cache Read: $0.00 |
| deepseek-v4-pro | deepseek | In: text; Out: text | function_calling, structured_output, reasoning, tool_choice | 1000000 | 384000 | In: $0.44, Out: $0.87, Cache Read: $0.00 |
| deep-research-pro-preview-12-2025 | gemini | In: -; Out: - | function_calling, tool_choice, structured_output, vision | 131072 | 65536 | In: $0.08, Out: $0.30 |
| gemini-2.5-computer-use-preview-10-2025 | gemini | In: text, image; Out: text | function_calling, reasoning, vision, tool_choice, structured_output | 131072 | 65536 | In: $1.25, Out: $10.00 |
| gemini-2.5-flash | gemini | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription, tool_choice | 1048576 | 65536 | In: $0.30, Out: $2.50, Cache Read: $0.03 |
| gemini-2.5-flash-native-audio-latest | gemini | In: -; Out: - | function_calling, tool_choice, structured_output, vision | 131072 | 8192 | In: $0.08, Out: $0.30 |
| gemini-2.5-flash-native-audio-preview-09-2025 | gemini | In: -; Out: - | function_calling, tool_choice, structured_output, vision | 131072 | 8192 | In: $0.08, Out: $0.30 |
| gemini-2.5-flash-native-audio-preview-12-2025 | gemini | In: -; Out: - | function_calling, tool_choice, structured_output, vision | 131072 | 8192 | In: $0.08, Out: $0.30 |
| gemini-2.5-flash-preview-tts | gemini | In: text; Out: audio | tool_choice, structured_output | 8192 | 16384 | In: $0.50, Out: $10.00 |
| gemini-2.5-flash-lite | gemini | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription | 1048576 | 65536 | In: $0.10, Out: $0.40, Cache Read: $0.01 |
| gemini-2.5-pro | gemini | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription, tool_choice | 1048576 | 65536 | In: $1.25, Out: $10.00, Cache Read: $0.12 |
| gemini-2.5-pro-preview-tts | gemini | In: text; Out: audio | tool_choice, structured_output | 8192 | 16384 | In: $1.00, Out: $20.00 |
| gemini-3-flash-preview | gemini | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription, tool_choice | 1048576 | 65536 | In: $0.50, Out: $3.00, Cache Read: $0.05 |
| gemini-3.1-flash-lite | gemini | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription | 1048576 | 65536 | In: $0.25, Out: $1.50, Cache Read: $0.02 |
| gemini-3.1-flash-lite-preview | gemini | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription | 1048576 | 65536 | In: $0.25, Out: $1.50, Cache Read: $0.02 |
| gemini-3.1-flash-tts-preview | gemini | In: text; Out: audio | reasoning, tool_choice, structured_output | 8192 | 16384 | In: $1.00, Out: $20.00 |
| gemini-3.1-pro-preview | gemini | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription, tool_choice | 1048576 | 65536 | In: $2.00, Out: $12.00, Cache Read: $0.20 |
| gemini-3.1-pro-preview-customtools | gemini | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription, tool_choice | 1048576 | 65536 | In: $2.00, Out: $12.00, Cache Read: $0.20 |
| gemini-3.5-flash | gemini | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription, tool_choice | 1048576 | 65536 | In: $1.50, Out: $9.00, Cache Read: $0.15 |
| gemini-3.5-flash-lite | gemini | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription | 1048576 | 65536 | In: $0.30, Out: $2.50, Cache Read: $0.03 |
| gemini-3.5-live-translate-preview | gemini | In: audio; Out: audio, text | transcription, tool_choice, structured_output | 16384 | 32768 | In: $3.50, Out: $21.00 |
| gemini-3.6-flash | gemini | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription, tool_choice | 1048576 | 65536 | In: $1.50, Out: $7.50, Cache Read: $0.15 |
| gemini-3.7-flash | gemini | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription, tool_choice | 1048576 | 65536 | In: $0.75, Out: $3.75, Cache Read: $0.08 |
| gemini-embedding-2 | gemini | In: text, image, audio, video, pdf; Out: embeddings | vision, video, tool_choice, structured_output | 8192 | 1 | In: $0.20, Out: $0.00 |
| gemini-embedding-2-preview | gemini | In: -; Out: - | function_calling, tool_choice, structured_output, vision | 8192 | 1 | In: $0.00, Out: $0.00 |
| gemini-flash-latest | gemini | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription, tool_choice | 1048576 | 65536 | In: $1.50, Out: $9.00, Cache Read: $0.15 |
| gemini-flash-lite-latest | gemini | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription | 1048576 | 65536 | In: $0.25, Out: $1.50, Cache Read: $0.02 |
| gemini-omni-flash-preview | gemini | In: text, image, video; Out: video | reasoning, vision, video, tool_choice, structured_output | 131072 | 65536 | In: $1.50, Out: $17.50 |
| gemini-pro-latest | gemini | In: -; Out: - | function_calling, tool_choice, structured_output, vision | 1048576 | 65536 | In: $0.08, Out: $0.30 |
| gemini-robotics-er-1.6-preview | gemini | In: text, image, video, audio; Out: text | function_calling, structured_output, reasoning, vision, video, transcription, tool_choice | 131072 | 65536 | In: $1.00, Out: $5.00 |
| gemini-robotics-er-2-preview | gemini | In: -; Out: - | function_calling, tool_choice, structured_output, vision | 131072 | 65536 | In: $0.08, Out: $0.30 |
| gemini-robotics-er-2-streaming-preview | gemini | In: -; Out: - | function_calling, tool_choice, structured_output, vision | 131072 | 65536 | In: $0.08, Out: $0.30 |
| gemma-4-26b-a4b-it | gemini | In: text, image; Out: text | function_calling, structured_output, reasoning, vision | 262144 | 32768 | In: $0.08, Out: $0.30 |
| gemma-4-31b-it | gemini | In: text, image; Out: text | function_calling, structured_output, reasoning, vision | 262144 | 32768 | In: $0.08, Out: $0.30 |
| gemini-2.5-flash-image | gemini | In: text, image; Out: text, image | reasoning, vision, tool_choice, structured_output | 32768 | 32768 | In: $0.30, Out: $30.00, Cache Read: $0.08 |
| gemini-3.1-flash-image | gemini | In: text, image, video, pdf; Out: text, image | reasoning, vision, video, tool_choice, structured_output | 65536 | 65536 | In: $0.50, Out: $60.00 |
| gemini-3.1-flash-image-preview | gemini | In: text, image, pdf; Out: text, image | reasoning, vision, tool_choice, structured_output | 65536 | 65536 | In: $0.50, Out: $60.00 |
| gemini-3-pro-image | gemini | In: text, image; Out: text, image | reasoning, vision, tool_choice, structured_output | 131072 | 32768 | In: $2.00, Out: $120.00 |
| gemini-3-pro-image-preview | gemini | In: text, image; Out: text, image | reasoning, vision, tool_choice, structured_output | 131072 | 32768 | In: $2.00, Out: $120.00 |
| nano-banana-pro-preview | gemini | In: -; Out: - | function_calling, tool_choice, structured_output, vision | 131072 | 32768 | In: $0.08, Out: $0.30 |
| codestral-2508 | mistral | In: text; Out: text | streaming, function_calling, tool_choice, parallel_tool_calls, structured_output, batch, predicted_outputs | 256000 | 8192 | - |
| codestral-latest | mistral | In: text; Out: text | function_calling, streaming, tool_choice, parallel_tool_calls, structured_output, batch, predicted_outputs | 256000 | 4096 | In: $0.30, Out: $0.90 |
| devstral-2512 | mistral | In: text; Out: text | function_calling, streaming, tool_choice, parallel_tool_calls, structured_output, batch | 262144 | 262144 | In: $0.40, Out: $2.00 |
| devstral-latest | mistral | In: text; Out: text | function_calling, streaming, tool_choice, parallel_tool_calls, structured_output, batch | 262144 | 262144 | In: $0.40, Out: $2.00 |
| devstral-medium-latest | mistral | In: text; Out: text | function_calling, streaming, tool_choice, parallel_tool_calls, structured_output, batch | 262144 | 262144 | In: $0.40, Out: $2.00 |
| glm-5-2 | mistral | In: text; Out: text | streaming, function_calling, tool_choice, parallel_tool_calls, structured_output, batch, reasoning | 1048576 | 8192 | - |
| labs-leanstral-1-5 | mistral | In: text, image; Out: text | streaming, function_calling, tool_choice, parallel_tool_calls, structured_output, batch, reasoning, vision | 262144 | 8192 | - |
| labs-leanstral-1-5-1 | mistral | In: text, image; Out: text | streaming, function_calling, tool_choice, parallel_tool_calls, structured_output, batch, reasoning, vision | 262144 | 8192 | - |
| magistral-medium-latest | mistral | In: text; Out: text | function_calling, reasoning, streaming, tool_choice, parallel_tool_calls, structured_output, batch | 128000 | 16384 | In: $2.00, Out: $5.00 |
| magistral-small-latest | mistral | In: text, image; Out: text | streaming, function_calling, tool_choice, parallel_tool_calls, structured_output, reasoning, batch, vision | 262144 | 8192 | - |
| ministral-14b-2512 | mistral | In: text, image; Out: text | streaming, function_calling, tool_choice, parallel_tool_calls, structured_output, batch, distillation, fine_tuning, vision | 262144 | 8192 | - |
| ministral-14b-latest | mistral | In: text, image; Out: text | streaming, function_calling, tool_choice, parallel_tool_calls, structured_output, batch, distillation, fine_tuning, vision | 262144 | 8192 | - |
| ministral-3b-2512 | mistral | In: text, image; Out: text | streaming, function_calling, tool_choice, parallel_tool_calls, structured_output, batch, distillation, fine_tuning, vision | 131072 | 8192 | - |
| ministral-3b-latest | mistral | In: text; Out: text | function_calling, streaming, tool_choice, parallel_tool_calls, structured_output, batch, distillation, fine_tuning | 128000 | 128000 | In: $0.04, Out: $0.04 |
| ministral-8b-2512 | mistral | In: text, image; Out: text | streaming, function_calling, tool_choice, parallel_tool_calls, structured_output, batch, distillation, fine_tuning, vision | 262144 | 8192 | - |
| ministral-8b-latest | mistral | In: text; Out: text | function_calling, streaming, tool_choice, parallel_tool_calls, structured_output, batch, distillation, fine_tuning | 128000 | 128000 | In: $0.10, Out: $0.10 |
| mistral-code-agent-latest | mistral | In: text; Out: text | streaming, function_calling, tool_choice, parallel_tool_calls, structured_output, batch | 262144 | 8192 | - |
| mistral-code-fim-latest | mistral | In: text; Out: text | streaming, function_calling, tool_choice, parallel_tool_calls, structured_output, batch | 256000 | 8192 | - |
| mistral-code-latest | mistral | In: text; Out: text | streaming, function_calling, tool_choice, parallel_tool_calls, structured_output, batch | 256000 | 8192 | - |
| mistral-large-latest | mistral | In: text, image; Out: text | function_calling, vision, streaming, tool_choice, parallel_tool_calls, structured_output, batch, fine_tuning | 262144 | 262144 | In: $0.50, Out: $1.50 |
| mistral-large-2512 | mistral | In: text, image; Out: text | function_calling, vision, streaming, tool_choice, parallel_tool_calls, structured_output, batch, fine_tuning | 262144 | 262144 | In: $0.50, Out: $1.50 |
| mistral-medium | mistral | In: text, image; Out: text | streaming, function_calling, tool_choice, parallel_tool_calls, structured_output, batch, reasoning, vision | 262144 | 8192 | - |
| mistral-medium-3 | mistral | In: text, image; Out: text | streaming, function_calling, tool_choice, parallel_tool_calls, structured_output, reasoning, batch, vision | 262144 | 8192 | - |
| mistral-medium-3-5 | mistral | In: text, image; Out: text | streaming, function_calling, tool_choice, parallel_tool_calls, structured_output, reasoning, batch, vision | 262144 | 8192 | - |
| mistral-medium-3.5 | mistral | In: text, image; Out: text | streaming, function_calling, tool_choice, parallel_tool_calls, structured_output, reasoning, batch, vision | 262144 | 8192 | - |
| mistral-medium-latest | mistral | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming, tool_choice, parallel_tool_calls, batch | 262144 | 262144 | In: $1.50, Out: $7.50 |
| mistral-medium-2505 | mistral | In: text, image; Out: text | function_calling, vision, streaming, tool_choice, parallel_tool_calls, structured_output, batch, fine_tuning | 131072 | 131072 | In: $0.40, Out: $2.00 |
| mistral-medium-2508 | mistral | In: text, image; Out: text | function_calling, vision, streaming, tool_choice, parallel_tool_calls, structured_output, batch, fine_tuning | 262144 | 262144 | In: $0.40, Out: $2.00 |
| mistral-medium-2604 | mistral | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming, tool_choice, parallel_tool_calls, batch | 262144 | 262144 | In: $1.50, Out: $7.50 |
| mistral-small-latest | mistral | In: text, image; Out: text | function_calling, reasoning, vision, streaming, tool_choice, parallel_tool_calls, structured_output, batch | 256000 | 256000 | In: $0.15, Out: $0.60 |
| mistral-small-2603 | mistral | In: text, image; Out: text | function_calling, reasoning, vision, streaming, tool_choice, parallel_tool_calls, structured_output, batch | 256000 | 256000 | In: $0.15, Out: $0.60 |
| mistral-vibe-cli-fast | mistral | In: text, image; Out: text | streaming, function_calling, tool_choice, parallel_tool_calls, structured_output, batch, reasoning, vision | 262144 | 8192 | - |
| mistral-vibe-cli-latest | mistral | In: text, image; Out: text | streaming, function_calling, tool_choice, parallel_tool_calls, structured_output, batch, reasoning, vision | 262144 | 8192 | - |
| mistral-vibe-cli-with-tools | mistral | In: text, image; Out: text | streaming, function_calling, tool_choice, parallel_tool_calls, structured_output, batch, reasoning, vision | 262144 | 8192 | - |
| zai-glm-5-2 | mistral | In: text; Out: text | streaming, function_calling, tool_choice, parallel_tool_calls, structured_output, batch, reasoning | 1048576 | 8192 | - |
| deepseek-v4-flash:0731 | ollama_cloud | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 1048576 | 1048576 | - |
| glm-5.2 | ollama_cloud | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 976000 | 131072 | - |
| kimi-k2.7-code | ollama_cloud | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 262144 | 262144 | - |
| kimi-k3 | ollama_cloud | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1048576 | 131072 | - |
| gpt-4.1 | openai | In: text, image, pdf; Out: text | function_calling, structured_output, vision, tool_choice, parallel_tool_calls | 1047576 | 32768 | In: $2.00, Out: $8.00, Cache Read: $0.50 |
| gpt-4.1-mini | openai | In: text, image, pdf; Out: text | function_calling, structured_output, vision, tool_choice, parallel_tool_calls | 1047576 | 32768 | In: $0.40, Out: $1.60, Cache Read: $0.10 |
| gpt-4.1-nano | openai | In: text, image; Out: text | function_calling, structured_output, vision, tool_choice, parallel_tool_calls | 1047576 | 32768 | In: $0.10, Out: $0.40, Cache Read: $0.02 |
| gpt-4o | openai | In: text, image, pdf; Out: text | function_calling, structured_output, vision, tool_choice, parallel_tool_calls | 128000 | 16384 | In: $2.50, Out: $10.00, Cache Read: $1.25 |
| gpt-4o-2024-05-13 | openai | In: text, image; Out: text | function_calling, structured_output, vision, tool_choice, parallel_tool_calls | 128000 | 4096 | In: $5.00, Out: $15.00 |
| gpt-4o-2024-08-06 | openai | In: text, image; Out: text | function_calling, structured_output, vision, tool_choice, parallel_tool_calls | 128000 | 16384 | In: $2.50, Out: $10.00, Cache Read: $1.25 |
| gpt-4o-2024-11-20 | openai | In: text, image; Out: text | function_calling, structured_output, vision, tool_choice, parallel_tool_calls | 128000 | 16384 | In: $2.50, Out: $10.00, Cache Read: $1.25 |
| gpt-4o-mini | openai | In: text, image, pdf; Out: text | function_calling, structured_output, vision, tool_choice, parallel_tool_calls | 128000 | 16384 | In: $0.15, Out: $0.60, Cache Read: $0.08 |
| gpt-5 | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, tool_choice, parallel_tool_calls | 400000 | 128000 | In: $1.25, Out: $10.00, Cache Read: $0.12 |
| gpt-5-mini | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, tool_choice, parallel_tool_calls | 400000 | 128000 | In: $0.25, Out: $2.00, Cache Read: $0.02 |
| gpt-5-nano | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, tool_choice, parallel_tool_calls | 400000 | 128000 | In: $0.05, Out: $0.40, Cache Read: $0.01 |
| gpt-5-pro | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, tool_choice, parallel_tool_calls | 400000 | 272000 | In: $15.00, Out: $120.00 |
| gpt-5.1 | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, tool_choice, parallel_tool_calls | 400000 | 128000 | In: $1.25, Out: $10.00, Cache Read: $0.12 |
| gpt-5.2 | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, tool_choice, parallel_tool_calls | 400000 | 128000 | In: $1.75, Out: $14.00, Cache Read: $0.18 |
| gpt-5.2-chat-latest | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, tool_choice, parallel_tool_calls | 128000 | 16384 | In: $1.75, Out: $14.00, Cache Read: $0.18 |
| gpt-5.3-chat-latest | openai | In: text, image; Out: text | function_calling, structured_output, vision, tool_choice, parallel_tool_calls | 128000 | 16384 | In: $1.75, Out: $14.00, Cache Read: $0.18 |
| gpt-5.3-codex | openai | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, tool_choice, parallel_tool_calls | 400000 | 128000 | In: $1.75, Out: $14.00, Cache Read: $0.18 |
| gpt-5.3-codex-spark | openai | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 128000 | 32000 | In: $1.75, Out: $14.00, Cache Read: $0.18 |
| gpt-5.4 | openai | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, tool_choice, parallel_tool_calls | 1050000 | 128000 | In: $2.50, Out: $15.00, Cache Read: $0.25 |
| gpt-5.4-mini | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, tool_choice, parallel_tool_calls | 400000 | 128000 | In: $0.75, Out: $4.50, Cache Read: $0.08 |
| gpt-5.4-nano | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, tool_choice, parallel_tool_calls | 400000 | 128000 | In: $0.20, Out: $1.25, Cache Read: $0.02 |
| gpt-5.5 | openai | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, tool_choice, parallel_tool_calls | 1050000 | 128000 | In: $5.00, Out: $30.00, Cache Read: $0.50 |
| gpt-5.5-pro | openai | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, tool_choice, parallel_tool_calls | 1050000 | 128000 | In: $30.00, Out: $180.00 |
| gpt-5.6 | openai | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1050000 | 128000 | In: $5.00, Out: $30.00, Cache Read: $0.50, Cache Write: $6.25 |
| gpt-5.6-luna | openai | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, tool_choice, parallel_tool_calls | 1050000 | 128000 | In: $0.20, Out: $1.20, Cache Read: $0.02, Cache Write: $0.25 |
| gpt-5.6-sol | openai | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, tool_choice, parallel_tool_calls | 1050000 | 128000 | In: $5.00, Out: $30.00, Cache Read: $0.50, Cache Write: $6.25 |
| gpt-5.6-terra | openai | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, tool_choice, parallel_tool_calls | 1050000 | 128000 | In: $2.00, Out: $12.00, Cache Read: $0.20, Cache Write: $2.50 |
| gpt-4.1-2025-04-14 | openai | In: -; Out: - | function_calling, tool_choice, parallel_tool_calls, structured_output, vision | 1047576 | 32768 | In: $2.00, Out: $8.00, Cache Read: $0.50 |
| gpt-4.1-mini-2025-04-14 | openai | In: -; Out: - | function_calling, tool_choice, parallel_tool_calls, structured_output, vision | 1047576 | 32768 | In: $0.40, Out: $1.60, Cache Read: $0.10 |
| gpt-4.1-nano-2025-04-14 | openai | In: -; Out: - | function_calling, tool_choice, parallel_tool_calls, structured_output, vision | 1047576 | 32768 | In: $0.10, Out: $0.40 |
| gpt-4o-mini-2024-07-18 | openai | In: -; Out: - | function_calling, tool_choice, parallel_tool_calls, structured_output, vision | 128000 | 16384 | In: $0.15, Out: $0.60 |
| gpt-5-2025-08-07 | openai | In: -; Out: - | function_calling, tool_choice, parallel_tool_calls, structured_output, vision, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache Read: $0.12 |
| gpt-5-chat-latest | openai | In: -; Out: - | function_calling, tool_choice, parallel_tool_calls, structured_output, vision, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache Read: $0.12 |
| gpt-5-codex | openai | In: -; Out: - | function_calling, tool_choice, parallel_tool_calls, structured_output, vision, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache Read: $0.12 |
| gpt-5-mini-2025-08-07 | openai | In: -; Out: - | function_calling, tool_choice, parallel_tool_calls, structured_output, vision, reasoning | 128000 | 400000 | In: $0.25, Out: $2.00, Cache Read: $0.02 |
| gpt-5-nano-2025-08-07 | openai | In: -; Out: - | function_calling, tool_choice, parallel_tool_calls, structured_output, vision, reasoning | 128000 | 400000 | In: $0.05, Out: $0.40, Cache Read: $0.01 |
| gpt-5-pro-2025-10-06 | openai | In: -; Out: - | function_calling, tool_choice, parallel_tool_calls, structured_output, vision, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache Read: $0.12 |
| gpt-5-search-api | openai | In: -; Out: - | function_calling, tool_choice, parallel_tool_calls, structured_output, vision, reasoning, citations | 128000 | 400000 | In: $1.25, Out: $10.00, Cache Read: $0.12 |
| gpt-5-search-api-2025-10-14 | openai | In: -; Out: - | function_calling, tool_choice, parallel_tool_calls, structured_output, vision, reasoning, citations | 128000 | 400000 | In: $1.25, Out: $10.00, Cache Read: $0.12 |
| gpt-5.1-2025-11-13 | openai | In: -; Out: - | function_calling, tool_choice, parallel_tool_calls, structured_output, vision, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache Read: $0.12 |
| gpt-5.1-chat-latest | openai | In: -; Out: - | function_calling, tool_choice, parallel_tool_calls, structured_output, vision, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache Read: $0.12 |
| gpt-5.1-codex | openai | In: -; Out: - | function_calling, tool_choice, parallel_tool_calls, structured_output, vision, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache Read: $0.12 |
| gpt-5.1-codex-max | openai | In: -; Out: - | function_calling, tool_choice, parallel_tool_calls, structured_output, vision, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache Read: $0.12 |
| gpt-5.1-codex-mini | openai | In: -; Out: - | function_calling, tool_choice, parallel_tool_calls, structured_output, vision, reasoning | 128000 | 400000 | In: $0.25, Out: $2.00, Cache Read: $0.02 |
| gpt-5.2-2025-12-11 | openai | In: -; Out: - | function_calling, tool_choice, parallel_tool_calls, structured_output, vision, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache Read: $0.12 |
| gpt-5.2-codex | openai | In: -; Out: - | function_calling, tool_choice, parallel_tool_calls, structured_output, vision, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache Read: $0.12 |
| gpt-5.2-pro-2025-12-11 | openai | In: -; Out: - | function_calling, tool_choice, parallel_tool_calls, structured_output, vision, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache Read: $0.12 |
| gpt-5.4-2026-03-05 | openai | In: -; Out: - | function_calling, tool_choice, parallel_tool_calls, structured_output, vision, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache Read: $0.12 |
| gpt-5.4-mini-2026-03-17 | openai | In: -; Out: - | function_calling, tool_choice, parallel_tool_calls, structured_output, vision, reasoning | 128000 | 400000 | In: $0.25, Out: $2.00, Cache Read: $0.02 |
| gpt-5.4-nano-2026-03-17 | openai | In: -; Out: - | function_calling, tool_choice, parallel_tool_calls, structured_output, vision, reasoning | 128000 | 400000 | In: $0.05, Out: $0.40, Cache Read: $0.01 |
| gpt-5.4-pro-2026-03-05 | openai | In: -; Out: - | function_calling, tool_choice, parallel_tool_calls, structured_output, vision, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache Read: $0.12 |
| gpt-5.5-2026-04-23 | openai | In: -; Out: - | function_calling, tool_choice, parallel_tool_calls, structured_output, vision, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache Read: $0.12 |
| gpt-5.5-pro-2026-04-23 | openai | In: -; Out: - | function_calling, tool_choice, parallel_tool_calls, structured_output, vision, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache Read: $0.12 |
| o1 | openai | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, tool_choice, parallel_tool_calls | 200000 | 100000 | In: $15.00, Out: $60.00, Cache Read: $7.50 |
| o1-2024-12-17 | openai | In: -; Out: - | function_calling, tool_choice, parallel_tool_calls, structured_output, vision, reasoning | 200000 | 100000 | In: $15.00, Out: $60.00 |
| o1-pro | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, tool_choice, parallel_tool_calls | 200000 | 100000 | In: $150.00, Out: $600.00 |
| o1-pro-2025-03-19 | openai | In: -; Out: - | function_calling, tool_choice, parallel_tool_calls, structured_output, vision, reasoning | 200000 | 100000 | In: $150.00, Out: $600.00 |
| o3 | openai | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 200000 | 100000 | In: $2.00, Out: $8.00, Cache Read: $0.50 |
| o3-mini | openai | In: text; Out: text | function_calling, structured_output, reasoning, tool_choice, parallel_tool_calls | 200000 | 100000 | In: $1.10, Out: $4.40, Cache Read: $0.55 |
| o3-mini-2025-01-31 | openai | In: -; Out: - | function_calling, tool_choice, parallel_tool_calls, structured_output, reasoning | 200000 | 100000 | In: $1.10, Out: $4.40 |
| o3-pro | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision | 200000 | 100000 | In: $20.00, Out: $80.00 |
| o4-mini | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision | 200000 | 100000 | In: $1.10, Out: $4.40, Cache Read: $0.28 |
| ~anthropic/claude-haiku-latest | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 64000 | In: $1.00, Out: $5.00, Cache Read: $0.10, Cache Write: $1.25 |
| ~anthropic/claude-sonnet-latest | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 128000 | In: $2.00, Out: $10.00, Cache Read: $0.20, Cache Write: $2.50 |
| anthropic/claude-fable-5:batch | openrouter | In: text, image, file; Out: text | streaming, function_calling, structured_output | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| anthropic/claude-haiku-4.5:batch | openrouter | In: text, image, file; Out: text | streaming, function_calling, structured_output | 200000 | 64000 | In: $0.50, Out: $2.50, Cache Read: $0.05, Cache Write: $0.62 |
| anthropic/claude-opus-4.1:batch | openrouter | In: image, text, file; Out: text | streaming, function_calling, structured_output | 200000 | 32000 | In: $7.50, Out: $37.50, Cache Read: $0.75, Cache Write: $9.38 |
| anthropic/claude-opus-4.5:batch | openrouter | In: file, image, text; Out: text | streaming, function_calling, structured_output | 200000 | 64000 | In: $2.50, Out: $12.50, Cache Read: $0.25, Cache Write: $3.12 |
| anthropic/claude-opus-4.6:batch | openrouter | In: text, image, file; Out: text | streaming, function_calling, structured_output | 1000000 | 128000 | In: $2.50, Out: $12.50, Cache Read: $0.25, Cache Write: $3.12 |
| anthropic/claude-opus-4.7:batch | openrouter | In: text, image, file; Out: text | streaming, function_calling, structured_output | 1000000 | 128000 | In: $2.50, Out: $12.50, Cache Read: $0.25, Cache Write: $3.12 |
| anthropic/claude-opus-4.8:batch | openrouter | In: text, image, file; Out: text | streaming, function_calling, structured_output | 1000000 | 128000 | In: $2.50, Out: $12.50, Cache Read: $0.25, Cache Write: $3.12 |
| anthropic/claude-sonnet-4.5:batch | openrouter | In: text, image, file; Out: text | streaming, function_calling, structured_output | 1000000 | 64000 | In: $1.50, Out: $7.50, Cache Read: $0.15, Cache Write: $1.88 |
| anthropic/claude-sonnet-4.6:batch | openrouter | In: text, image, file; Out: text | streaming, function_calling, structured_output | 1000000 | 128000 | In: $1.50, Out: $7.50, Cache Read: $0.15, Cache Write: $1.88 |
| anthropic/claude-sonnet-5:batch | openrouter | In: text, image, file; Out: text | streaming, function_calling, structured_output | 1000000 | 128000 | In: $1.00, Out: $5.00, Cache Read: $0.10, Cache Write: $1.25 |
| openrouter/auto | openrouter | In: text, image, audio, pdf, video; Out: text, image | function_calling, structured_output, reasoning, vision, video, streaming, predicted_outputs, image_generation | 2000000 | 2000000 | - |
| openrouter/auto-beta | openrouter | In: text, image, audio, file, video; Out: text, image | streaming, function_calling, structured_output, predicted_outputs, image_generation | 2000000 | - | - |
| baai/bge-base-en-v1.5 | openrouter | In: text; Out: embeddings | streaming, structured_output | 512 | - | In: $0.01 |
| baai/bge-large-en-v1.5 | openrouter | In: text; Out: embeddings | streaming, structured_output | 512 | - | In: $0.01 |
| baai/bge-m3 | openrouter | In: text; Out: embeddings | streaming, structured_output, predicted_outputs | 8194 | - | In: $0.01 |
| canopylabs/orpheus-3b-0.1-ft | openrouter | In: text; Out: audio | streaming, structured_output, predicted_outputs, speech_generation | 4096 | - | In: $7.00 |
| anthropic/claude-fable-5 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 128000 | In: $10.00, Out: $50.00, Cache Read: $1.00, Cache Write: $12.50 |
| ~anthropic/claude-fable-latest | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 128000 | In: $10.00, Out: $50.00, Cache Read: $1.00, Cache Write: $12.50 |
| anthropic/claude-haiku-4.5 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 64000 | In: $1.00, Out: $5.00, Cache Read: $0.10, Cache Write: $1.25 |
| anthropic/claude-opus-4.5 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 64000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| anthropic/claude-opus-4.6 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| anthropic/claude-opus-4.7 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| anthropic/claude-opus-4.7-fast | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 128000 | In: $30.00, Out: $150.00, Cache Read: $3.00, Cache Write: $37.50 |
| anthropic/claude-opus-4.8 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| anthropic/claude-opus-4.8-fast | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 128000 | In: $10.00, Out: $50.00, Cache Read: $1.00, Cache Write: $12.50 |
| anthropic/claude-opus-5 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| anthropic/claude-opus-5-fast | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 128000 | In: $10.00, Out: $50.00, Cache Read: $1.00, Cache Write: $12.50 |
| anthropic/claude-opus-5:batch | openrouter | In: text, image, file; Out: text | streaming, function_calling, structured_output | 1000000 | 128000 | In: $2.50, Out: $12.50, Cache Read: $0.25, Cache Write: $3.12 |
| ~anthropic/claude-opus-latest | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| anthropic/claude-sonnet-4.5 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 64000 | In: $3.00, Out: $15.00, Cache Read: $0.30, Cache Write: $3.75 |
| anthropic/claude-sonnet-4.6 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 128000 | In: $3.00, Out: $15.00, Cache Read: $0.30, Cache Write: $3.75 |
| anthropic/claude-sonnet-5 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 128000 | In: $2.00, Out: $10.00, Cache Read: $0.20, Cache Write: $2.50 |
| mistralai/codestral-2508 | openrouter | In: text, pdf; Out: text | function_calling, structured_output, vision, streaming | 256000 | 256000 | In: $0.30, Out: $0.90, Cache Read: $0.03 |
| deepcogito/cogito-v2.1-671b | openrouter | In: text; Out: text | structured_output, reasoning, streaming, predicted_outputs | 128000 | 128000 | In: $1.25, Out: $1.25 |
| cohere/rerank-4-fast | openrouter | In: text; Out: rerank | streaming, structured_output | 32768 | - | - |
| cohere/rerank-4-pro | openrouter | In: text; Out: rerank | streaming, structured_output | 32768 | - | - |
| cohere/rerank-v3.5 | openrouter | In: text; Out: rerank | streaming, structured_output | 4096 | - | - |
| cohere/command-a | openrouter | In: text; Out: text | structured_output, streaming | 256000 | 8192 | In: $2.50, Out: $10.00 |
| cohere/command-r-08-2024 | openrouter | In: text; Out: text | function_calling, structured_output, streaming | 128000 | 4000 | In: $0.15, Out: $0.60 |
| cohere/command-r-plus-08-2024 | openrouter | In: text; Out: text | function_calling, structured_output, streaming | 128000 | 4000 | In: $2.50, Out: $10.00 |
| cohere/command-r7b-12-2024 | openrouter | In: text; Out: text | structured_output, streaming | 128000 | 4000 | In: $0.04, Out: $0.15 |
| thedrummer/cydonia-24b-v4.1 | openrouter | In: text; Out: text | structured_output, streaming, predicted_outputs | 131072 | 131072 | In: $0.30, Out: $0.50, Cache Read: $0.15 |
| deepseek/deepseek-chat | openrouter | In: text; Out: text | function_calling, structured_output, streaming, predicted_outputs | 163840 | 16000 | In: $0.26, Out: $1.03 |
| deepseek/deepseek-chat-v3-0324 | openrouter | In: text; Out: text | function_calling, structured_output, streaming, predicted_outputs | 163840 | 163840 | In: $0.25, Out: $1.00 |
| deepseek/deepseek-chat-v3.1 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 163840 | 32768 | In: $0.25, Out: $0.95, Cache Read: $0.13 |
| deepseek/deepseek-v3.1-terminus | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 163840 | 163840 | In: $0.27, Out: $1.00 |
| deepseek/deepseek-v3.2 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 163840 | 65536 | In: $0.27, Out: $0.40, Cache Read: $0.13 |
| deepseek/deepseek-v3.2-exp | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 163840 | 65536 | In: $0.27, Out: $0.41 |
| deepseek/deepseek-v4-flash | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 1048576 | 384000 | In: $0.09, Out: $0.18, Cache Read: $0.02 |
| deepseek/deepseek-v4-flash-0731 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 1310720 | 393216 | In: $0.14, Out: $0.28, Cache Read: $0.03 |
| ~deepseek/deepseek-v4-flash-latest | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 1310720 | 262144 | In: $0.06, Out: $0.14, Cache Read: $0.01 |
| deepseek/deepseek-v4-pro | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 1048576 | 393216 | In: $1.60, Out: $3.20, Cache Read: $0.14 |
| deepseek/deepseek-v4-pro-0813 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 1048576 | 384000 | In: $1.19, Out: $3.56, Cache Read: $0.04 |
| deepseek/deepseek-r1 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 64000 | 16000 | In: $0.70, Out: $2.50 |
| dots-studio/dots-3-note-preview:free | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 512000 | 512000 | In: $0.00, Out: $0.00 |
| openrouter/free | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 8000 | In: $0.00, Out: $0.00 |
| sakana/fugu-ultra | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 128000 | In: $5.00, Out: $30.00, Cache Read: $0.50 |
| z-ai/glm-5.2:free | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 256000 | 256000 | In: $0.00, Out: $0.00 |
| z-ai/glm-4.6 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 204800 | 131072 | In: $0.50, Out: $2.00, Cache Read: $0.10 |
| z-ai/glm-4.7 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 204800 | 131072 | In: $0.40, Out: $1.75, Cache Read: $0.08 |
| z-ai/glm-4.7-flash | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 202752 | 16384 | In: $0.06, Out: $0.40, Cache Read: $0.01 |
| z-ai/glm-5 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 204800 | 128000 | In: $0.60, Out: $1.92, Cache Read: $0.12 |
| z-ai/glm-5.1 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 204800 | 128000 | In: $0.97, Out: $3.04, Cache Read: $0.18 |
| z-ai/glm-5.2 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 1048576 | 131072 | In: $0.97, Out: $3.04, Cache Read: $0.19 |
| openai/gpt-audio | openrouter | In: text, audio; Out: text, audio | function_calling, structured_output, streaming | 128000 | 16384 | In: $2.50, Out: $10.00 |
| openai/gpt-audio-mini | openrouter | In: text, audio; Out: text, audio | function_calling, structured_output, streaming | 128000 | 16384 | In: $0.60, Out: $2.40 |
| openai/gpt-chat-latest | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, vision, streaming | 400000 | 128000 | In: $5.00, Out: $30.00, Cache Read: $0.50 |
| openai/gpt-oss-120b | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 131072 | 131072 | In: $0.03, Out: $0.17, Cache Read: $0.03 |
| openai/gpt-oss-20b | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 131072 | 131072 | In: $0.03, Out: $0.13, Cache Read: $0.03 |
| openai/gpt-3.5-turbo-0613 | openrouter | In: text; Out: text | function_calling, structured_output, streaming | 4095 | 4096 | In: $1.00, Out: $2.00 |
| openai/gpt-3.5-turbo-16k | openrouter | In: text; Out: text | function_calling, structured_output, streaming | 16385 | 4096 | In: $3.00, Out: $4.00 |
| openai/gpt-3.5-turbo-instruct | openrouter | In: text; Out: text | structured_output, streaming | 4095 | 4096 | In: $1.50, Out: $2.00 |
| openai/gpt-3.5-turbo | openrouter | In: text; Out: text | function_calling, structured_output, streaming | 16385 | 4096 | In: $0.50, Out: $1.50 |
| openai/gpt-4 | openrouter | In: text; Out: text | function_calling, structured_output, streaming | 8191 | 4096 | In: $30.00, Out: $60.00 |
| openai/gpt-4-turbo | openrouter | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 128000 | 4096 | In: $10.00, Out: $30.00 |
| openai/gpt-4-turbo-preview | openrouter | In: text; Out: text | function_calling, structured_output, streaming | 128000 | 4096 | In: $10.00, Out: $30.00 |
| openai/gpt-4.1 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, vision, streaming | 1047576 | 32768 | In: $2.00, Out: $8.00, Cache Read: $0.50 |
| openai/gpt-4.1-mini | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, vision, streaming | 1047576 | 32768 | In: $0.40, Out: $1.60, Cache Read: $0.10 |
| openai/gpt-4.1-nano | openrouter | In: image, text, pdf; Out: text | function_calling, structured_output, vision, streaming | 1047576 | 32768 | In: $0.10, Out: $0.40, Cache Read: $0.02 |
| openai/gpt-4o | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, vision, streaming | 128000 | 16384 | In: $2.50, Out: $10.00, Cache Read: $1.25 |
| openai/gpt-4o-2024-05-13 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, vision, streaming | 128000 | 4096 | In: $5.00, Out: $15.00 |
| openai/gpt-4o-2024-08-06 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, vision, streaming | 128000 | 16384 | In: $2.50, Out: $10.00, Cache Read: $1.25 |
| openai/gpt-4o-2024-11-20 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, vision, streaming | 128000 | 16384 | In: $2.50, Out: $10.00, Cache Read: $1.25 |
| openai/gpt-4o-mini | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, vision, streaming | 128000 | 16384 | In: $0.15, Out: $0.60, Cache Read: $0.08 |
| openai/gpt-4o-mini-2024-07-18 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, vision, streaming | 128000 | 16384 | In: $0.15, Out: $0.60, Cache Read: $0.08 |
| openai/gpt-5 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $1.25, Out: $10.00, Cache Read: $0.12 |
| openai/gpt-5-image | openrouter | In: image, text, pdf; Out: image, text | structured_output, reasoning, vision, streaming, image_generation | 400000 | 128000 | In: $10.00, Out: $10.00, Cache Read: $1.25 |
| openai/gpt-5-image-mini | openrouter | In: pdf, image, text; Out: image, text | structured_output, reasoning, vision, streaming, image_generation | 400000 | 128000 | In: $2.50, Out: $2.00, Cache Read: $0.25 |
| openai/gpt-5-mini | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $0.25, Out: $2.00, Cache Read: $0.02 |
| openai/gpt-5-nano | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $0.05, Out: $0.40, Cache Read: $0.01 |
| openai/gpt-5-pro | openrouter | In: image, text, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $15.00, Out: $120.00 |
| openai/gpt-5.1 | openrouter | In: image, text, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $1.25, Out: $10.00, Cache Read: $0.12 |
| openai/gpt-5.1-codex | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $1.25, Out: $10.00, Cache Read: $0.13 |
| openai/gpt-5.1-codex-max | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $1.25, Out: $10.00, Cache Read: $0.12 |
| openai/gpt-5.1-codex-mini | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $0.25, Out: $2.00, Cache Read: $0.03 |
| openai/gpt-5.2 | openrouter | In: pdf, image, text; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $1.75, Out: $14.00, Cache Read: $0.18 |
| openai/gpt-5.2-chat | openrouter | In: pdf, image, text; Out: text | function_calling, structured_output, vision, streaming | 128000 | 32000 | In: $1.75, Out: $14.00, Cache Read: $0.18 |
| openai/gpt-5.2-codex | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $1.75, Out: $14.00, Cache Read: $0.18 |
| openai/gpt-5.2-pro | openrouter | In: image, text, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $21.00, Out: $168.00 |
| openai/gpt-5.3-codex | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $1.75, Out: $14.00, Cache Read: $0.18 |
| openai/gpt-5.4 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1050000 | 128000 | In: $2.50, Out: $15.00, Cache Read: $0.25 |
| openai/gpt-5.4-image-2 | openrouter | In: image, text, pdf; Out: image, text | structured_output, reasoning, vision, streaming, image_generation | 272000 | 128000 | In: $8.00, Out: $15.00, Cache Read: $2.00 |
| openai/gpt-5.4-pro | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1050000 | 128000 | In: $30.00, Out: $180.00 |
| openai/gpt-5.4-mini | openrouter | In: pdf, image, text; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $0.75, Out: $4.50, Cache Read: $0.08 |
| openai/gpt-5.4-nano | openrouter | In: pdf, image, text; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $0.20, Out: $1.25, Cache Read: $0.02 |
| openai/gpt-5.5 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1050000 | 128000 | In: $5.00, Out: $30.00, Cache Read: $0.50 |
| openai/gpt-5.5-pro | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1050000 | 128000 | In: $30.00, Out: $180.00 |
| openai/gpt-5.6-luna | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1050000 | 128000 | In: $0.20, Out: $1.20, Cache Read: $0.02, Cache Write: $0.25 |
| openai/gpt-5.6-luna-pro | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1050000 | 128000 | In: $0.20, Out: $1.20, Cache Read: $0.02, Cache Write: $0.25 |
| openai/gpt-5.6-sol | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1050000 | 128000 | In: $2.50, Out: $15.00, Cache Read: $0.25, Cache Write: $3.12 |
| openai/gpt-5.6-sol-pro | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1050000 | 128000 | In: $2.50, Out: $15.00, Cache Read: $0.25, Cache Write: $3.12 |
| openai/gpt-5.6-terra | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1050000 | 128000 | In: $2.00, Out: $12.00, Cache Read: $0.20, Cache Write: $2.50 |
| openai/gpt-5.6-terra-pro | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1050000 | 128000 | In: $2.00, Out: $12.00, Cache Read: $0.20, Cache Write: $2.50 |
| google/gemini-2.5-flash | openrouter | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1048576 | 65535 | In: $0.30, Out: $2.50, Cache Read: $0.03, Cache Write: $0.08 |
| google/gemini-2.5-flash-lite | openrouter | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1048576 | 65535 | In: $0.10, Out: $0.40, Cache Read: $0.01, Cache Write: $0.08 |
| google/gemini-2.5-pro | openrouter | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1048576 | 65536 | In: $1.25, Out: $10.00, Cache Read: $0.12, Cache Write: $0.38 |
| google/gemini-2.5-pro-preview-05-06 | openrouter | In: text, image, pdf, audio, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1048576 | 65535 | In: $1.25, Out: $10.00, Cache Read: $0.12, Cache Write: $0.38 |
| google/gemini-2.5-pro-preview | openrouter | In: pdf, image, text, audio; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1048576 | 65536 | In: $1.25, Out: $10.00, Cache Read: $0.12, Cache Write: $0.38 |
| google/gemini-3-flash-preview | openrouter | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1048576 | 65536 | In: $0.50, Out: $3.00, Cache Read: $0.05, Cache Write: $0.08 |
| google/gemini-3.1-flash-lite | openrouter | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1048576 | 65536 | In: $0.25, Out: $1.50, Cache Read: $0.02, Cache Write: $0.08 |
| google/gemini-3.1-flash-lite-preview | openrouter | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1048576 | 65536 | In: $0.25, Out: $1.50, Cache Read: $0.02, Cache Write: $0.08 |
| google/gemini-3.1-pro-preview | openrouter | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1048576 | 65536 | In: $2.00, Out: $12.00, Cache Read: $0.20, Cache Write: $0.38 |
| google/gemini-3.1-pro-preview-customtools | openrouter | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1048576 | 65536 | In: $2.00, Out: $12.00, Cache Read: $0.20, Cache Write: $0.38 |
| google/gemini-3.5-flash | openrouter | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1048576 | 65536 | In: $1.50, Out: $9.00, Cache Read: $0.15, Cache Write: $0.08 |
| google/gemini-3.5-flash-lite | openrouter | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1048576 | 65536 | In: $0.30, Out: $2.50, Cache Read: $0.03, Cache Write: $0.08 |
| google/gemini-3.6-flash | openrouter | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1048576 | 65536 | In: $0.75, Out: $3.75, Cache Read: $0.08, Cache Write: $0.04 |
| google/gemini-3.7-flash | openrouter | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1048576 | 65536 | In: $0.38, Out: $1.88, Cache Read: $0.04, Cache Write: $0.02 |
| google/gemma-2-27b-it | openrouter | In: text; Out: text | structured_output, streaming | 8192 | 2048 | In: $0.65, Out: $0.65 |
| google/gemma-3-12b-it | openrouter | In: text, image; Out: text | function_calling, structured_output, vision, streaming, predicted_outputs | 131072 | 16384 | In: $0.05, Out: $0.15 |
| google/gemma-3-27b-it | openrouter | In: text, image; Out: text | function_calling, structured_output, vision, streaming, predicted_outputs | 262144 | 131072 | In: $0.08, Out: $0.45, Cache Read: $0.04 |
| google/gemma-3-4b-it | openrouter | In: text, image; Out: text | structured_output, vision, streaming, predicted_outputs | 131072 | 16384 | In: $0.05, Out: $0.10 |
| google/gemma-3n-e4b-it | openrouter | In: text; Out: text | structured_output, streaming, predicted_outputs | 32768 | 32768 | In: $0.06, Out: $0.12 |
| google/gemma-4-26b-a4b-it:free | openrouter | In: image, text, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 262144 | 32768 | In: $0.00, Out: $0.00 |
| google/gemma-4-26b-a4b-it | openrouter | In: image, text, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming, predicted_outputs | 262144 | 16384 | In: $0.07, Out: $0.34 |
| google/gemma-4-31b-it | openrouter | In: image, text, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming, predicted_outputs | 262144 | 16384 | In: $0.09, Out: $0.34, Cache Read: $0.05 |
| ~google/gemini-flash-latest | openrouter | In: text, image, video, pdf, audio; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1048576 | 65536 | In: $0.38, Out: $1.88, Cache Read: $0.04, Cache Write: $0.02 |
| ~google/gemini-pro-latest | openrouter | In: audio, pdf, image, text, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1048576 | 65536 | In: $2.00, Out: $12.00, Cache Read: $0.20, Cache Write: $0.38 |
| google/chirp-3 | openrouter | In: audio; Out: text | streaming, structured_output, transcription | 0 | - | In: $16000.00 |
| google/gemini-2.5-flash:batch | openrouter | In: file, image, text, audio, video; Out: text | streaming, function_calling, structured_output | 1048576 | 65535 | In: $0.15, Out: $1.25, Cache Read: $0.03 |
| google/gemini-2.5-flash-lite:batch | openrouter | In: text, image, file, audio, video; Out: text | streaming, function_calling, structured_output | 1048576 | 65535 | In: $0.05, Out: $0.20, Cache Read: $0.01 |
| google/gemini-2.5-pro:batch | openrouter | In: text, image, file, audio, video; Out: text | streaming, function_calling, structured_output | 1048576 | 65536 | In: $0.62, Out: $5.00, Cache Read: $0.12 |
| google/gemini-3-flash-preview:batch | openrouter | In: text, image, file, audio, video; Out: text | streaming, function_calling, structured_output | 1048576 | 65536 | In: $0.25, Out: $1.50 |
| google/gemini-3.1-flash-lite:batch | openrouter | In: text, image, video, file, audio; Out: text | streaming, function_calling, structured_output | 1048576 | 65536 | In: $0.12, Out: $0.75, Cache Read: $0.01 |
| google/gemini-3.1-flash-tts-preview | openrouter | In: text; Out: audio | streaming, structured_output, speech_generation | 32768 | 16384 | In: $1.00, Out: $20.00 |
| google/gemini-3.1-pro-preview:batch | openrouter | In: audio, file, image, text, video; Out: text | streaming, function_calling, structured_output | 1048576 | 65536 | In: $1.00, Out: $6.00 |
| google/gemini-3.5-flash:batch | openrouter | In: text, image, video, file, audio; Out: text | streaming, function_calling, structured_output | 1048576 | 65536 | In: $0.75, Out: $4.50, Cache Read: $0.08 |
| google/gemini-3.5-flash-lite:batch | openrouter | In: text, image, video, file, audio; Out: text | streaming, function_calling, structured_output | 1048576 | 65536 | In: $0.15, Out: $1.25, Cache Read: $0.02 |
| google/gemini-3.6-flash:batch | openrouter | In: text, image, video, file, audio; Out: text | streaming, function_calling, structured_output | 1048576 | 65536 | In: $0.38, Out: $1.88, Cache Read: $0.04, Cache Write: $0.04 |
| google/gemini-3.7-flash:batch | openrouter | In: text, image, video, file, audio; Out: text | streaming, function_calling, structured_output | 1048576 | 65536 | In: $0.19, Out: $0.94, Cache Read: $0.02, Cache Write: $0.02 |
| google/gemini-embedding-001 | openrouter | In: text; Out: embeddings | streaming, structured_output | 20000 | - | In: $0.15 |
| google/gemini-embedding-2 | openrouter | In: text, image, file, audio, video; Out: embeddings | streaming, structured_output | 8192 | - | In: $0.20 |
| google/gemini-embedding-2-preview | openrouter | In: text, image, file, audio, video; Out: embeddings | streaming, structured_output | 8192 | - | In: $0.20 |
| ibm-granite/granite-4.1-8b | openrouter | In: text; Out: text | function_calling, structured_output, streaming | 131072 | 131072 | In: $0.05, Out: $0.10, Cache Read: $0.05 |
| x-ai/grok-4.20 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 2000000 | 2000000 | In: $1.25, Out: $2.50, Cache Read: $0.20 |
| x-ai/grok-4.20-multi-agent | openrouter | In: text, image, pdf; Out: text | structured_output, reasoning, vision, streaming | 2000000 | 2000000 | In: $1.25, Out: $2.50, Cache Read: $0.20 |
| x-ai/grok-4.3 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 1000000 | In: $1.25, Out: $2.50, Cache Read: $0.20 |
| x-ai/grok-4.5 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 500000 | 500000 | In: $2.00, Out: $6.00, Cache Read: $0.30 |
| x-ai/grok-4.6 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 500000 | 500000 | In: $2.00, Out: $6.00, Cache Read: $0.50 |
| x-ai/grok-build-0.1 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 256000 | 256000 | In: $1.00, Out: $2.00, Cache Read: $0.20 |
| ~x-ai/grok-latest | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 500000 | 1000000 | In: $2.00, Out: $6.00, Cache Read: $0.50 |
| nousresearch/hermes-3-llama-3.1-405b | openrouter | In: text; Out: text | structured_output, streaming, predicted_outputs | 131072 | 16384 | In: $1.00, Out: $1.00 |
| nousresearch/hermes-3-llama-3.1-70b | openrouter | In: text; Out: text | structured_output, streaming, predicted_outputs | 131072 | 16384 | In: $0.70, Out: $0.70 |
| tencent/hunyuan-a13b-instruct | openrouter | In: text; Out: text | structured_output, reasoning, streaming | 131072 | 131072 | In: $0.14, Out: $0.57 |
| tencent/hy3 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 262144 | 128000 | In: $0.13, Out: $0.53, Cache Read: $0.03 |
| thinkingmachines/inkling-small | openrouter | In: text, image, audio; Out: text | function_calling, structured_output, reasoning, vision, streaming, predicted_outputs | 524288 | 262144 | In: $0.45, Out: $1.20, Cache Read: $0.10 |
| intfloat/e5-base-v2 | openrouter | In: text; Out: embeddings | streaming, structured_output | 512 | - | In: $0.01 |
| intfloat/e5-large-v2 | openrouter | In: text; Out: embeddings | streaming, structured_output | 512 | - | In: $0.01 |
| intfloat/multilingual-e5-large | openrouter | In: text; Out: embeddings | streaming, structured_output | 512 | - | In: $0.01 |
| kwaipilot/kat-coder-air-v2.5 | openrouter | In: text; Out: text | function_calling, structured_output, streaming | 256000 | 80000 | In: $0.15, Out: $0.60, Cache Read: $0.03 |
| kwaipilot/kat-coder-pro-v2 | openrouter | In: text; Out: text | function_calling, structured_output, streaming, predicted_outputs | 262144 | 80000 | In: $0.30, Out: $1.20, Cache Read: $0.06 |
| kwaipilot/kat-coder-pro-v2.5 | openrouter | In: text; Out: text | function_calling, structured_output, streaming | 256000 | 80000 | In: $0.74, Out: $2.96, Cache Read: $0.15 |
| moonshotai/kimi-k2-0905 | openrouter | In: text; Out: text | function_calling, structured_output, streaming | 262144 | 100352 | In: $0.60, Out: $2.50 |
| moonshotai/kimi-k2-thinking | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 262144 | 100352 | In: $0.60, Out: $2.50, Cache Read: $0.15 |
| moonshotai/kimi-k2.5 | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming, predicted_outputs | 262144 | 262144 | In: $0.45, Out: $2.25, Cache Read: $0.07 |
| moonshotai/kimi-k2.6 | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming, predicted_outputs | 262144 | 262144 | In: $0.95, Out: $4.00, Cache Read: $0.16 |
| moonshotai/kimi-k2.7-code | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming, predicted_outputs | 262144 | 262144 | In: $0.71, Out: $3.50, Cache Read: $0.15 |
| moonshotai/kimi-k3 | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming, predicted_outputs | 1048576 | 1048576 | In: $3.00, Out: $15.00, Cache Read: $0.30 |
| liquid/lfm-2.5-2.6b:free | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 128000 | 8192 | In: $0.00, Out: $0.00 |
| inclusionai/ling-2.6-1t | openrouter | In: text; Out: text | function_calling, structured_output, streaming | 262144 | 32768 | In: $0.08, Out: $0.62, Cache Read: $0.02 |
| inclusionai/ling-2.6-flash | openrouter | In: text; Out: text | function_calling, structured_output, streaming | 262144 | 32768 | In: $0.01, Out: $0.03, Cache Read: $0.00 |
| sao10k/l3-lunaris-8b | openrouter | In: text; Out: text | structured_output, streaming, predicted_outputs | 8192 | 16384 | In: $0.04, Out: $0.05 |
| meta-llama/llama-3.1-70b-instruct | openrouter | In: text; Out: text | function_calling, structured_output, streaming, predicted_outputs | 131072 | 16384 | In: $0.40, Out: $0.40 |
| sao10k/l3.1-euryale-70b | openrouter | In: text; Out: text | function_calling, structured_output, streaming, predicted_outputs | 131072 | 16384 | In: $0.85, Out: $0.85 |
| meta-llama/llama-3.2-3b-instruct | openrouter | In: text; Out: text | structured_output, streaming, predicted_outputs | 131072 | 131072 | In: $0.05, Out: $0.33 |
| sao10k/l3.3-euryale-70b | openrouter | In: text; Out: text | structured_output, streaming | 131072 | 16384 | In: $0.65, Out: $0.75 |
| meta-llama/llama-4-maverick | openrouter | In: text, image; Out: text | function_calling, structured_output, vision, streaming, predicted_outputs | 1048576 | 16384 | In: $0.20, Out: $0.80 |
| meta-llama/llama-4-scout | openrouter | In: text, image; Out: text | function_calling, structured_output, vision, streaming, predicted_outputs | 1310720 | 16384 | In: $0.10, Out: $0.30 |
| meta-llama/llama-3.1-8b-instruct | openrouter | In: text; Out: text | function_calling, structured_output, streaming, predicted_outputs | 131072 | 131072 | In: $0.05, Out: $0.08, Cache Read: $0.02 |
| meta-llama/llama-3.3-70b-instruct | openrouter | In: text; Out: text | function_calling, structured_output, streaming, predicted_outputs | 131072 | 16384 | In: $0.10, Out: $0.32 |
| anthracite-org/magnum-v4-72b | openrouter | In: text; Out: text | structured_output, streaming, predicted_outputs | 32768 | 4096 | In: $3.00, Out: $5.00 |
| inception/mercury-2 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 128000 | 50000 | In: $0.25, Out: $0.75, Cache Read: $0.02 |
| xiaomi/mimo-v2.5 | openrouter | In: text, image, audio, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming, predicted_outputs | 1050000 | 131072 | In: $0.14, Out: $0.28, Cache Read: $0.00 |
| xiaomi/mimo-v2.5-pro | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 1050000 | 131072 | In: $0.44, Out: $0.87, Cache Read: $0.00 |
| minimax/minimax-m2 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 204800 | 131072 | In: $0.26, Out: $1.02 |
| minimax/minimax-m2.5 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 204800 | 196608 | In: $0.22, Out: $0.90, Cache Read: $0.06 |
| minimax/minimax-m2.7 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 204800 | 131072 | In: $0.30, Out: $1.20, Cache Read: $0.06 |
| minimax/minimax-m3 | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming, predicted_outputs | 1048576 | 512000 | In: $0.30, Out: $1.20, Cache Read: $0.06 |
| minimax/minimax-m3:batch | openrouter | In: text, image, video; Out: text | streaming, function_calling, structured_output, predicted_outputs | 524288 | - | In: $0.30, Out: $1.20, Cache Read: $0.06 |
| mistralai/ministral-14b-2512 | openrouter | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 262144 | 262144 | In: $0.20, Out: $0.20, Cache Read: $0.02 |
| mistralai/ministral-3b-2512 | openrouter | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 131072 | 131072 | In: $0.10, Out: $0.10, Cache Read: $0.01 |
| mistralai/ministral-8b-2512 | openrouter | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 262144 | 262144 | In: $0.15, Out: $0.15, Cache Read: $0.02 |
| mistralai/mistral-large | openrouter | In: text, pdf; Out: text | function_calling, structured_output, vision, streaming | 128000 | 128000 | In: $2.00, Out: $6.00, Cache Read: $0.20 |
| mistralai/mistral-large-2407 | openrouter | In: text, pdf; Out: text | function_calling, structured_output, vision, streaming | 131072 | 131072 | In: $2.00, Out: $6.00, Cache Read: $0.20 |
| mistralai/mistral-large-2512 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, vision, streaming | 262144 | 262144 | In: $0.50, Out: $1.50, Cache Read: $0.05 |
| mistralai/mistral-medium-3 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, vision, streaming | 131072 | 131072 | In: $0.40, Out: $2.00, Cache Read: $0.04 |
| mistralai/mistral-medium-3.1 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, vision, streaming | 131072 | 262144 | In: $0.40, Out: $2.00, Cache Read: $0.04 |
| mistralai/mistral-medium-3-5 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 262144 | 262144 | In: $1.50, Out: $7.50 |
| mistralai/mistral-nemo | openrouter | In: text; Out: text | function_calling, structured_output, streaming, predicted_outputs | 131072 | 16384 | In: $0.02, Out: $0.03 |
| mistralai/mistral-small-24b-instruct-2501 | openrouter | In: text; Out: text | structured_output, streaming, predicted_outputs | 32768 | 16384 | In: $0.05, Out: $0.08 |
| mistralai/mistral-small-3.2-24b-instruct | openrouter | In: image, text; Out: text | function_calling, structured_output, vision, streaming, predicted_outputs | 256000 | 16384 | In: $0.09, Out: $0.25 |
| mistralai/mistral-small-2603 | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 262144 | 262144 | In: $0.15, Out: $0.60, Cache Read: $0.02 |
| mistralai/codestral-embed-2505 | openrouter | In: text; Out: embeddings | streaming, structured_output | 8192 | - | In: $0.15 |
| mistralai/mistral-embed-2312 | openrouter | In: text; Out: embeddings | streaming, structured_output | 8192 | - | In: $0.10 |
| mistralai/voxtral-mini-3b-2507 | openrouter | In: audio; Out: text | streaming, structured_output, transcription | 0 | - | In: $16.67 |
| mistralai/voxtral-mini-tts-2603 | openrouter | In: text; Out: audio | streaming, structured_output, speech_generation | 4096 | - | In: $16.00 |
| mistralai/voxtral-mini-transcribe | openrouter | In: audio; Out: text | streaming, structured_output, transcription | 0 | - | In: $3000.00 |
| mistralai/voxtral-small-24b-2507-stt | openrouter | In: audio; Out: text | streaming, structured_output, transcription | 0 | - | In: $50.00 |
| mistralai/mixtral-8x22b-instruct | openrouter | In: text, pdf; Out: text | function_calling, structured_output, vision, streaming | 65536 | 65536 | In: $2.00, Out: $6.00, Cache Read: $0.20 |
| ~moonshotai/kimi-latest | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming, predicted_outputs | 1048576 | 974842 | In: $2.60, Out: $13.00, Cache Read: $0.29 |
| moonshotai/kimi-k2.7-code:batch | openrouter | In: text, image; Out: text | streaming, function_calling, structured_output, predicted_outputs | 262144 | - | In: $0.95, Out: $4.00, Cache Read: $0.19 |
| morph/morph-v3-large | openrouter | In: text; Out: text | structured_output, streaming | 262144 | 131072 | In: $0.90, Out: $1.90 |
| meta/muse-glimmer-30b | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming, predicted_outputs | 131072 | 131072 | In: $0.35, Out: $1.50, Cache Read: $0.04 |
| meta/muse-spark-1.1 | openrouter | In: text, image, video, pdf, audio; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1048576 | 1048576 | In: $1.25, Out: $4.25, Cache Read: $0.15 |
| meta/muse-spark-1.2 | openrouter | In: text, image, video, pdf, audio; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1048576 | 1048576 | In: $1.25, Out: $4.25, Cache Read: $0.15 |
| gryphe/mythomax-l2-13b | openrouter | In: text; Out: text | structured_output, streaming, predicted_outputs | 8192 | 4096 | In: $0.06, Out: $0.06 |
| nvidia/nemotron-3-ultra-550b-a55b:batch | openrouter | In: text; Out: text | streaming, function_calling, structured_output, predicted_outputs | 512288 | - | In: $0.60, Out: $3.60, Cache Read: $0.20 |
| nvidia/nemotron-3.5-asr-streaming-multilingual-0.6b | openrouter | In: audio; Out: text | streaming, structured_output, transcription | 0 | - | In: $3.33 |
| google/gemini-2.5-flash-image | openrouter | In: text, image; Out: text, image | structured_output, vision, streaming, image_generation | 32768 | 8192 | In: $0.30, Out: $2.50, Cache Read: $0.03, Cache Write: $0.08 |
| google/gemini-3.1-flash-image | openrouter | In: image, text; Out: text, image | structured_output, reasoning, vision, streaming, image_generation | 131072 | 32768 | In: $0.50, Out: $3.00 |
| google/gemini-3.1-flash-image-preview | openrouter | In: image, text; Out: text, image | structured_output, reasoning, vision, streaming, image_generation | 65536 | 65536 | In: $0.50, Out: $3.00 |
| google/gemini-3-pro-image | openrouter | In: text, image; Out: text, image | function_calling, structured_output, reasoning, vision, streaming, image_generation | 131072 | 32768 | In: $2.00, Out: $12.00, Cache Read: $0.20, Cache Write: $0.38 |
| google/gemini-3-pro-image-preview | openrouter | In: text, image; Out: text, image | structured_output, reasoning, vision, streaming, image_generation | 65536 | 32768 | In: $2.00, Out: $12.00, Cache Read: $0.20, Cache Write: $0.38 |
| nvidia/nemotron-3-nano-30b-a3b | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 262144 | 262144 | In: $0.05, Out: $0.20, Cache Read: $0.03 |
| nvidia/nemotron-3-super-120b-a12b:free | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 262144 | 262144 | In: $0.00, Out: $0.00 |
| nvidia/nemotron-3-super-120b-a12b | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 1000000 | 16384 | In: $0.08, Out: $0.40 |
| nvidia/nemotron-3-ultra-550b-a55b | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 512288 | 16384 | In: $0.60, Out: $3.60, Cache Read: $0.20 |
| nvidia/nemotron-3.5-lightning | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 1000000 | 131072 | In: $0.08, Out: $0.20, Cache Read: $0.04 |
| nvidia/nemotron-nano-9b-v2:free | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 128000 | 128000 | In: $0.00, Out: $0.00 |
| nex-agi/nex-n2-mini | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 262144 | 262144 | In: $0.02, Out: $0.10, Cache Read: $0.00 |
| allenai/olmo-3-32b-think | openrouter | In: text; Out: text | structured_output, reasoning, streaming, predicted_outputs | 65536 | 65536 | In: $0.15, Out: $0.50 |
| ~openai/gpt-latest | openrouter | In: pdf, image, text; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1050000 | 128000 | In: $2.50, Out: $15.00, Cache Read: $0.25, Cache Write: $3.12 |
| ~openai/gpt-mini-latest | openrouter | In: pdf, image, text; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $0.75, Out: $4.50, Cache Read: $0.08 |
| openai/gpt-transcribe | openrouter | In: audio; Out: text | streaming, structured_output, transcription | 0 | - | In: $4500.00 |
| openai/gpt-3.5-turbo:batch | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 16385 | 4096 | In: $0.25, Out: $0.75 |
| openai/gpt-4-turbo:batch | openrouter | In: text, image; Out: text | streaming, function_calling, structured_output | 128000 | 4096 | In: $5.00, Out: $15.00 |
| openai/gpt-4.1:batch | openrouter | In: image, text, file; Out: text | streaming, function_calling, structured_output | 1047576 | 32768 | In: $1.00, Out: $4.00, Cache Read: $0.25 |
| openai/gpt-4.1-mini:batch | openrouter | In: image, text, file; Out: text | streaming, function_calling, structured_output | 1047576 | 32768 | In: $0.20, Out: $0.80, Cache Read: $0.05 |
| openai/gpt-4.1-nano:batch | openrouter | In: image, text, file; Out: text | streaming, function_calling, structured_output | 1047576 | 32768 | In: $0.05, Out: $0.20, Cache Read: $0.01 |
| openai/gpt-4o:batch | openrouter | In: text, image, file; Out: text | streaming, function_calling, structured_output | 128000 | 16384 | In: $1.25, Out: $5.00, Cache Read: $0.62 |
| openai/gpt-4o-mini-transcribe | openrouter | In: audio; Out: text | streaming, structured_output, transcription | 128000 | - | In: $1.25, Out: $5.00 |
| openai/gpt-4o-transcribe | openrouter | In: audio; Out: text | streaming, structured_output, transcription | 128000 | - | In: $2.50, Out: $10.00 |
| openai/gpt-4o-mini:batch | openrouter | In: text, image, file; Out: text | streaming, function_calling, structured_output | 128000 | 16384 | In: $0.08, Out: $0.30, Cache Read: $0.04 |
| openai/gpt-5:batch | openrouter | In: text, image, file; Out: text | streaming, function_calling, structured_output | 400000 | 128000 | In: $0.62, Out: $5.00, Cache Read: $0.06 |
| openai/gpt-5-codex:batch | openrouter | In: text, image; Out: text | streaming, function_calling, structured_output | 400000 | 128000 | In: $0.62, Out: $5.00, Cache Read: $0.06 |
| openai/gpt-5-mini:batch | openrouter | In: text, image, file; Out: text | streaming, function_calling, structured_output | 400000 | 128000 | In: $0.12, Out: $1.00, Cache Read: $0.01 |
| openai/gpt-5-nano:batch | openrouter | In: text, image, file; Out: text | streaming, function_calling, structured_output | 400000 | 128000 | In: $0.02, Out: $0.20, Cache Read: $0.00 |
| openai/gpt-5-pro:batch | openrouter | In: image, text, file; Out: text | streaming, function_calling, structured_output | 400000 | 128000 | In: $7.50, Out: $60.00 |
| openai/gpt-5.1:batch | openrouter | In: image, text, file; Out: text | streaming, function_calling, structured_output | 400000 | 128000 | In: $0.62, Out: $5.00, Cache Read: $0.06 |
| openai/gpt-5.2:batch | openrouter | In: file, image, text; Out: text | streaming, function_calling, structured_output | 400000 | 128000 | In: $0.88, Out: $7.00, Cache Read: $0.09 |
| openai/gpt-5.2-pro:batch | openrouter | In: image, text, file; Out: text | streaming, function_calling, structured_output | 400000 | 128000 | In: $10.50, Out: $84.00 |
| openai/gpt-5.4:batch | openrouter | In: text, image, file; Out: text | streaming, function_calling, structured_output | 1050000 | 128000 | In: $1.25, Out: $7.50, Cache Read: $0.12 |
| openai/gpt-5.4-mini:batch | openrouter | In: file, image, text; Out: text | streaming, function_calling, structured_output | 400000 | 128000 | In: $0.38, Out: $2.25, Cache Read: $0.04 |
| openai/gpt-5.4-nano:batch | openrouter | In: file, image, text; Out: text | streaming, function_calling, structured_output | 400000 | 128000 | In: $0.10, Out: $0.62, Cache Read: $0.01 |
| openai/gpt-5.4-pro:batch | openrouter | In: text, image, file; Out: text | streaming, function_calling, structured_output | 1050000 | 128000 | In: $15.00, Out: $90.00 |
| openai/gpt-5.5:batch | openrouter | In: file, image, text; Out: text | streaming, function_calling, structured_output | 1050000 | 128000 | In: $2.50, Out: $15.00, Cache Read: $0.25 |
| openai/gpt-5.5-pro:batch | openrouter | In: file, image, text; Out: text | streaming, function_calling, structured_output | 1050000 | 128000 | In: $15.00, Out: $90.00 |
| openai/gpt-5.6-luna:batch | openrouter | In: file, image, text; Out: text | streaming, function_calling, structured_output | 1050000 | 128000 | In: $0.10, Out: $0.60, Cache Read: $0.01 |
| openai/gpt-5.6-luna-pro:batch | openrouter | In: file, image, text; Out: text | streaming, function_calling, structured_output | 1050000 | 128000 | In: $0.10, Out: $0.60, Cache Read: $0.01 |
| openai/gpt-5.6-sol:batch | openrouter | In: file, image, text; Out: text | streaming, function_calling, structured_output | 1050000 | 128000 | In: $1.25, Out: $7.50, Cache Read: $0.12 |
| openai/gpt-5.6-sol-pro:batch | openrouter | In: file, image, text; Out: text | streaming, function_calling, structured_output | 1050000 | 128000 | In: $1.25, Out: $7.50, Cache Read: $0.12 |
| openai/gpt-5.6-terra:batch | openrouter | In: file, image, text; Out: text | streaming, function_calling, structured_output | 1050000 | 128000 | In: $1.00, Out: $6.00, Cache Read: $0.10 |
| openai/gpt-5.6-terra-pro:batch | openrouter | In: file, image, text; Out: text | streaming, function_calling, structured_output | 1050000 | 128000 | In: $1.00, Out: $6.00, Cache Read: $0.10 |
| openai/text-embedding-3-large | openrouter | In: text; Out: embeddings | streaming, structured_output | 8192 | - | In: $0.13 |
| openai/text-embedding-3-small | openrouter | In: text; Out: embeddings | streaming, structured_output | 8192 | - | In: $0.02 |
| openai/text-embedding-ada-002 | openrouter | In: text; Out: embeddings | streaming, structured_output | 8192 | - | In: $0.10 |
| openai/whisper-1 | openrouter | In: audio; Out: text | streaming, structured_output, transcription | 0 | - | In: $6000.00 |
| openai/whisper-large-v3 | openrouter | In: audio; Out: text | streaming, structured_output, predicted_outputs, transcription | 0 | - | In: $7.50 |
| openai/whisper-large-v3-turbo | openrouter | In: audio; Out: text | streaming, structured_output, transcription | 0 | - | In: $3.33 |
| openai/o1:batch | openrouter | In: text, image, file; Out: text | streaming, function_calling, structured_output | 200000 | 100000 | In: $7.50, Out: $30.00, Cache Read: $3.75 |
| openai/o1-pro:batch | openrouter | In: text, image, file; Out: text | streaming, structured_output | 200000 | 100000 | In: $75.00, Out: $300.00 |
| openai/o3:batch | openrouter | In: image, text, file; Out: text | streaming, function_calling, structured_output | 200000 | 100000 | In: $1.00, Out: $4.00, Cache Read: $0.25 |
| openai/o3-mini:batch | openrouter | In: text, file; Out: text | streaming, function_calling, structured_output | 200000 | 100000 | In: $0.55, Out: $2.20, Cache Read: $0.28 |
| openai/o3-mini-high:batch | openrouter | In: text, file; Out: text | streaming, function_calling, structured_output | 200000 | 100000 | In: $0.55, Out: $2.20, Cache Read: $0.28 |
| openai/o3-pro:batch | openrouter | In: text, file, image; Out: text | streaming, function_calling, structured_output | 200000 | 100000 | In: $10.00, Out: $40.00 |
| openai/o4-mini:batch | openrouter | In: image, text, file; Out: text | streaming, function_calling, structured_output | 200000 | 100000 | In: $0.55, Out: $2.20, Cache Read: $0.14 |
| openai/o4-mini-high:batch | openrouter | In: image, text, file; Out: text | streaming, function_calling, structured_output | 200000 | 100000 | In: $0.55, Out: $2.20, Cache Read: $0.14 |
| perceptron/perceptron-mk1 | openrouter | In: text, image, video; Out: text | structured_output, reasoning, vision, video, streaming | 32768 | 8192 | In: $0.15, Out: $1.50 |
| microsoft/phi-4 | openrouter | In: text; Out: text | structured_output, streaming, predicted_outputs | 16384 | 16384 | In: $0.07, Out: $0.14 |
| qwen/qwen-plus | openrouter | In: text; Out: text | function_calling, structured_output, streaming | 1000000 | 32768 | In: $0.26, Out: $0.78, Cache Read: $0.05, Cache Write: $0.32 |
| qwen/qwen-plus-2025-07-28 | openrouter | In: text; Out: text | function_calling, structured_output, streaming | 1000000 | 32768 | In: $0.26, Out: $0.78 |
| qwen/qwen-plus-2025-07-28:thinking | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 1000000 | 32768 | In: $0.26, Out: $0.78 |
| qwen/qwen-2.5-72b-instruct | openrouter | In: text; Out: text | function_calling, structured_output, streaming, predicted_outputs | 32768 | 16384 | In: $0.36, Out: $0.40 |
| qwen/qwen-2.5-7b-instruct | openrouter | In: text; Out: text | function_calling, structured_output, streaming, predicted_outputs | 32768 | 32768 | In: $0.10, Out: $0.20 |
| qwen/qwen2.5-vl-72b-instruct | openrouter | In: text, image; Out: text | structured_output, vision, streaming, predicted_outputs | 128000 | 128000 | In: $0.80, Out: $1.00, Cache Read: $0.40 |
| qwen/qwen3-14b | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 131072 | 16384 | In: $0.12, Out: $0.24 |
| qwen/qwen3-235b-a22b-2507 | openrouter | In: text; Out: text | function_calling, structured_output, streaming, predicted_outputs | 262144 | 16384 | In: $0.09, Out: $0.55 |
| qwen/qwen3-30b-a3b-instruct-2507 | openrouter | In: text; Out: text | function_calling, structured_output, streaming, predicted_outputs | 262144 | 32000 | In: $0.05, Out: $0.19 |
| qwen/qwen3-32b | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 131072 | 16384 | In: $0.08, Out: $0.28 |
| qwen/qwen3-coder | openrouter | In: text; Out: text | function_calling, structured_output, streaming, predicted_outputs | 262144 | 65536 | In: $0.30, Out: $1.00, Cache Read: $0.10 |
| qwen/qwen3-coder-next | openrouter | In: text; Out: text | function_calling, structured_output, streaming, predicted_outputs | 262144 | 262144 | In: $0.12, Out: $0.80, Cache Read: $0.07 |
| qwen/qwen3-coder-plus | openrouter | In: text; Out: text | function_calling, structured_output, streaming | 1000000 | 65536 | In: $0.65, Out: $3.25, Cache Read: $0.13, Cache Write: $0.81 |
| qwen/qwen3-max | openrouter | In: text; Out: text | function_calling, structured_output, streaming | 262144 | 65536 | In: $0.78, Out: $3.90, Cache Read: $0.16, Cache Write: $0.98 |
| qwen/qwen3-max-thinking | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 262144 | 65536 | In: $0.78, Out: $3.90 |
| qwen/qwen3-reranker-8b | openrouter | In: text; Out: rerank | streaming, structured_output, predicted_outputs | 40960 | - | - |
| qwen/qwen3-vl-235b-a22b-instruct | openrouter | In: text, image; Out: text | function_calling, structured_output, vision, streaming, predicted_outputs | 262144 | 32768 | In: $0.21, Out: $1.90, Cache Read: $0.10 |
| qwen/qwen3-vl-235b-a22b-thinking | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 131072 | 32768 | In: $0.40, Out: $4.00 |
| qwen/qwen3-vl-30b-a3b-instruct | openrouter | In: text, image; Out: text | function_calling, structured_output, vision, streaming, predicted_outputs | 262144 | 32768 | In: $0.13, Out: $0.52 |
| qwen/qwen3-vl-30b-a3b-thinking | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 262144 | 32768 | In: $0.20, Out: $2.40 |
| qwen/qwen3-vl-32b-instruct | openrouter | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 131072 | 32768 | In: $0.10, Out: $0.42 |
| qwen/qwen3-vl-8b-instruct | openrouter | In: image, text; Out: text | function_calling, structured_output, vision, streaming, predicted_outputs | 262144 | 32768 | In: $0.12, Out: $0.46 |
| qwen/qwen3-vl-8b-thinking | openrouter | In: image, text; Out: text | function_calling, structured_output, reasoning, vision, streaming | 131072 | 32768 | In: $0.18, Out: $2.10 |
| qwen/qwen3-coder-30b-a3b-instruct | openrouter | In: text; Out: text | function_calling, structured_output, streaming | 262144 | 262144 | In: $0.07, Out: $0.28 |
| qwen/qwen3-next-80b-a3b-thinking | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 262144 | 32768 | In: $0.15, Out: $1.20 |
| qwen/qwen3-next-80b-a3b-instruct | openrouter | In: text; Out: text | function_calling, structured_output, streaming, predicted_outputs | 262144 | 16384 | In: $0.09, Out: $1.10 |
| qwen/qwen3.5-122b-a10b | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming, predicted_outputs | 262144 | 262144 | In: $0.26, Out: $2.08 |
| qwen/qwen3.5-27b | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming, predicted_outputs | 262144 | 65536 | In: $0.20, Out: $1.56 |
| qwen/qwen3.5-35b-a3b | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming, predicted_outputs | 262144 | 262144 | In: $0.25, Out: $1.25, Cache Read: $0.25 |
| qwen/qwen3.5-397b-a17b | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming, predicted_outputs | 262144 | 65536 | In: $0.39, Out: $2.34 |
| qwen/qwen3.5-9b | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming, predicted_outputs | 262144 | 262144 | In: $0.10, Out: $0.15 |
| qwen/qwen3.5-plus-02-15 | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1000000 | 65536 | In: $0.26, Out: $1.56 |
| qwen/qwen3.5-plus-20260420 | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1000000 | 65536 | In: $0.30, Out: $1.80, Cache Write: $0.38 |
| qwen/qwen3.5-flash-02-23 | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1000000 | 65536 | In: $0.06, Out: $0.26 |
| qwen/qwen3.6-27b | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming, predicted_outputs | 262144 | 262144 | In: $0.60, Out: $3.60, Cache Read: $0.12 |
| qwen/qwen3.6-35b-a3b | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming, predicted_outputs | 262144 | 262144 | In: $0.14, Out: $1.00, Cache Read: $0.05 |
| qwen/qwen3.6-flash | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1000000 | 65536 | In: $0.19, Out: $1.12, Cache Write: $0.23 |
| qwen/qwen3.6-max-preview | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 262144 | 65536 | In: $1.03, Out: $6.16, Cache Write: $1.28 |
| qwen/qwen3.6-plus | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1000000 | 65536 | In: $0.32, Out: $1.95, Cache Write: $0.41 |
| qwen/qwen3.7-max | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 1000000 | 131072 | In: $1.48, Out: $4.42, Cache Read: $0.30, Cache Write: $1.84 |
| qwen/qwen3.7-plus | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 131072 | In: $0.32, Out: $1.28, Cache Read: $0.06, Cache Write: $0.40 |
| qwen/qwen3.8-2.4t-a95b | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 1048576 | 262144 | In: $2.00, Out: $6.00, Cache Read: $0.25 |
| qwen/qwen3.8-27b | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming, predicted_outputs | 1000000 | 131072 | In: $0.45, Out: $3.20, Cache Read: $0.05 |
| qwen/qwen3.8-max | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1000000 | 131072 | In: $2.00, Out: $6.00, Cache Read: $0.25, Cache Write: $2.50 |
| qwen/qwen-audio-3.0-tts-flash | openrouter | In: text; Out: audio | streaming, structured_output, speech_generation | 0 | - | In: $15.00 |
| qwen/qwen-audio-3.0-tts-plus | openrouter | In: text; Out: audio | streaming, structured_output, speech_generation | 0 | - | In: $20.00 |
| qwen/qwen3-asr-0.6b | openrouter | In: audio; Out: text | streaming, structured_output, transcription | 0 | - | In: $3.33 |
| qwen/qwen3-asr-1.7b | openrouter | In: audio; Out: text | streaming, structured_output, transcription | 0 | - | In: $7.50 |
| qwen/qwen3-asr-flash-2026-02-10 | openrouter | In: audio; Out: text | streaming, structured_output, transcription | 0 | - | In: $35.00 |
| qwen/qwen3-embedding-4b | openrouter | In: text; Out: embeddings | streaming, structured_output | 32768 | - | In: $0.02 |
| qwen/qwen3-embedding-8b | openrouter | In: text; Out: embeddings | streaming, structured_output, predicted_outputs | 32768 | 32000 | In: $0.01 |
| deepseek/deepseek-r1-0528 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 163840 | 32768 | In: $0.50, Out: $2.15, Cache Read: $0.35 |
| undi95/remm-slerp-l2-13b | openrouter | In: text; Out: text | structured_output, streaming, predicted_outputs | 6144 | 6144 | In: $0.45, Out: $0.65 |
| rekaai/reka-edge | openrouter | In: image, text, video; Out: text | function_calling, structured_output, vision, video, streaming | 16384 | 16384 | In: $0.10, Out: $0.10 |
| rekaai/reka-flash-3 | openrouter | In: text; Out: text | structured_output, reasoning, streaming | 65536 | 65536 | In: $0.10, Out: $0.20 |
| thedrummer/rocinante-12b | openrouter | In: text; Out: text | structured_output, streaming, predicted_outputs | 65536 | 65536 | In: $0.25, Out: $0.50 |
| mistralai/mistral-saba | openrouter | In: text, pdf; Out: text | function_calling, structured_output, vision, streaming | 32768 | 32768 | In: $0.20, Out: $0.60, Cache Read: $0.02 |
| sakana/sakana-namazu | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 262144 | 65536 | In: $0.95, Out: $4.00, Cache Read: $0.15 |
| bytedance-seed/seed-1.6 | openrouter | In: image, text, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 262144 | 32768 | In: $0.25, Out: $2.00 |
| bytedance-seed/seed-1.6-flash | openrouter | In: image, text, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 262144 | 32768 | In: $0.08, Out: $0.30 |
| bytedance-seed/seed-2.0-code | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 262144 | 131072 | In: $0.50, Out: $3.00 |
| bytedance-seed/seed-2.0-lite | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 262144 | 131072 | In: $0.25, Out: $2.00 |
| bytedance-seed/seed-2.0-mini | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 262144 | 131072 | In: $0.10, Out: $0.40 |
| bytedance-seed/seed-2-1-turbo | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 262144 | 262144 | In: $0.50, Out: $2.50 |
| sentence-transformers/all-minilm-l12-v2 | openrouter | In: text; Out: embeddings | streaming, structured_output | 512 | - | In: $0.01 |
| sentence-transformers/all-minilm-l6-v2 | openrouter | In: text; Out: embeddings | streaming, structured_output | 512 | - | In: $0.01 |
| sentence-transformers/all-mpnet-base-v2 | openrouter | In: text; Out: embeddings | streaming, structured_output | 512 | - | In: $0.01 |
| sentence-transformers/multi-qa-mpnet-base-dot-v1 | openrouter | In: text; Out: embeddings | streaming, structured_output | 512 | - | In: $0.01 |
| sentence-transformers/paraphrase-minilm-l6-v2 | openrouter | In: text; Out: embeddings | streaming, structured_output | 512 | - | In: $0.01 |
| sesame/csm-1b | openrouter | In: text; Out: audio | streaming, structured_output, speech_generation | 4096 | - | In: $7.00 |
| thedrummer/skyfall-36b-v2 | openrouter | In: text; Out: text | structured_output, streaming, predicted_outputs | 32768 | 32768 | In: $0.55, Out: $0.80, Cache Read: $0.25 |
| upstage/solar-pro-3 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 131072 | 131072 | In: $0.15, Out: $0.60, Cache Read: $0.02 |
| upstage/solar-pro4 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 524288 | 131072 | In: $0.03, Out: $0.12, Cache Read: $0.01 |
| perplexity/sonar-pro-search | openrouter | In: text, image; Out: text | structured_output, reasoning, vision, streaming | 200000 | 8000 | In: $3.00, Out: $15.00 |
| x-ai/grok-stt-1.0 | openrouter | In: audio; Out: text | streaming, structured_output, transcription | 0 | - | In: $100000.00 |
| x-ai/grok-voice-tts-1.0 | openrouter | In: text; Out: audio | streaming, structured_output, speech_generation | 15000 | - | In: $15.00 |
| stepfun/step-3.7-flash | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming, predicted_outputs | 262144 | 256000 | In: $0.20, Out: $1.15, Cache Read: $0.04 |
| thenlper/gte-base | openrouter | In: text; Out: embeddings | streaming, structured_output | 512 | - | In: $0.01 |
| thenlper/gte-large | openrouter | In: text; Out: embeddings | streaming, structured_output | 512 | - | In: $0.01 |
| arcee-ai/trinity-large-thinking | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 262144 | 262144 | In: $0.22, Out: $0.85, Cache Read: $0.06 |
| bytedance/ui-tars-1.5-7b | openrouter | In: image, text; Out: text | structured_output, vision, streaming, predicted_outputs | 128000 | 2048 | In: $0.10, Out: $0.20, Cache Read: $0.10 |
| thedrummer/unslopnemo-12b | openrouter | In: text; Out: text | function_calling, structured_output, streaming, predicted_outputs | 1024000 | 1024000 | In: $0.40, Out: $0.40 |
| mistralai/voxtral-small-24b-2507 | openrouter | In: text, audio, pdf; Out: text | function_calling, structured_output, vision, streaming | 32000 | 32000 | In: $0.10, Out: $0.30, Cache Read: $0.01 |
| z-ai/glm-5.2:batch | openrouter | In: text; Out: text | streaming, function_calling, structured_output, predicted_outputs | 512000 | - | In: $1.40, Out: $4.40, Cache Read: $0.26 |
| openai/gpt-oss-20b:free | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 131072 | 32768 | In: $0.00, Out: $0.00 |
| openai/gpt-oss-safeguard-20b | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 131072 | 65536 | In: $0.08, Out: $0.30, Cache Read: $0.04 |
| hexgrad/kokoro-82m | openrouter | In: text; Out: audio | streaming, structured_output, predicted_outputs, speech_generation | 4096 | - | In: $0.62 |
| openai/o1 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 100000 | In: $15.00, Out: $60.00, Cache Read: $7.50 |
| openai/o1-pro | openrouter | In: text, image, pdf; Out: text | structured_output, reasoning, vision, streaming | 200000 | 100000 | In: $150.00, Out: $600.00 |
| openai/o3 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 100000 | In: $2.00, Out: $8.00, Cache Read: $0.50 |
| openai/o3-mini-high | openrouter | In: text, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 100000 | In: $1.10, Out: $4.40, Cache Read: $0.55 |
| openai/o3-mini | openrouter | In: text, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 100000 | In: $1.10, Out: $4.40, Cache Read: $0.55 |
| openai/o3-pro | openrouter | In: text, pdf, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 100000 | In: $20.00, Out: $80.00 |
| openai/o4-mini-high | openrouter | In: image, text, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 100000 | In: $1.10, Out: $4.40, Cache Read: $0.28 |
| openai/o4-mini | openrouter | In: image, text, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 100000 | In: $1.10, Out: $4.40, Cache Read: $0.28 |
| deepseek-ai/deepseek-v3.1-maas | vertexai | In: text, pdf; Out: text | function_calling, structured_output, reasoning, vision | 163840 | 32768 | In: $0.60, Out: $1.70 |
| deepseek-ai/deepseek-v3.2-maas | vertexai | In: text, pdf; Out: text | function_calling, structured_output, reasoning, vision | 163840 | 65536 | In: $0.56, Out: $1.68, Cache Read: $0.06 |
| zai-org/glm-4.7-maas | vertexai | In: text, pdf; Out: text | function_calling, structured_output, reasoning, vision | 200000 | 128000 | In: $0.60, Out: $2.20 |
| gemini-3-flash-preview | vertexai | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription, streaming | 1048576 | 65536 | In: $0.50, Out: $3.00, Cache Read: $0.05 |
| gemini-3.1-flash-lite | vertexai | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription, streaming | 1048576 | 65536 | In: $0.25, Out: $1.50, Cache Read: $0.02 |
| gemini-3.1-flash-lite-preview | vertexai | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription | 1048576 | 65536 | In: $0.25, Out: $1.50, Cache Read: $0.02 |
| gemini-3.1-pro-preview | vertexai | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription, streaming | 1048576 | 65536 | In: $2.00, Out: $12.00, Cache Read: $0.20 |
| gemini-3.1-pro-preview-customtools | vertexai | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription | 1048576 | 65536 | In: $2.00, Out: $12.00, Cache Read: $0.20 |
| gemini-3.5-flash | vertexai | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription, streaming | 1048576 | 65536 | In: $1.50, Out: $9.00, Cache Read: $0.15 |
| gemini-3.5-flash-lite | vertexai | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription, streaming | 1048576 | 65536 | In: $0.30, Out: $2.50, Cache Read: $0.03 |
| gemini-3.6-flash | vertexai | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription, streaming | 1048576 | 65536 | In: $1.50, Out: $7.50, Cache Read: $0.15 |
| gemini-3.7-flash | vertexai | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription, streaming | 1048576 | 65536 | In: $0.75, Out: $3.75, Cache Read: $0.08 |
| gemini-flash-latest | vertexai | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription | 1048576 | 65536 | In: $1.50, Out: $9.00, Cache Read: $0.15 |
| moonshotai/kimi-k2-thinking-maas | vertexai | In: text; Out: text | function_calling, structured_output, reasoning | 262144 | 262144 | In: $0.60, Out: $2.50 |
| meta/llama-3.3-70b-instruct-maas | vertexai | In: text; Out: text | function_calling, structured_output | 128000 | 8192 | In: $0.72, Out: $0.72 |
| meta/llama-4-maverick-17b-128e-instruct-maas | vertexai | In: text, image; Out: text | function_calling, structured_output, vision | 524288 | 8192 | In: $0.35, Out: $1.15 |
| qwen/qwen3-235b-a22b-instruct-2507-maas | vertexai | In: text; Out: text | function_calling, structured_output, reasoning | 262144 | 16384 | In: $0.22, Out: $0.88 |
| grok-4.20-0309-non-reasoning | xai | In: text, image, pdf; Out: text | function_calling, structured_output, vision, streaming | 1000000 | 30000 | In: $1.25, Out: $2.50, Cache Read: $0.20 |
| grok-4.20-0309-reasoning | xai | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 30000 | In: $1.25, Out: $2.50, Cache Read: $0.20 |
| grok-4.20-multi-agent-0309 | xai | In: text, image, pdf; Out: text | structured_output, reasoning, vision, streaming | 1000000 | 30000 | In: $1.25, Out: $2.50, Cache Read: $0.20 |
| grok-4.3 | xai | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 30000 | In: $1.25, Out: $2.50, Cache Read: $0.20 |
| grok-4.5 | xai | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 500000 | 500000 | In: $2.00, Out: $6.00, Cache Read: $0.30 |
| grok-4.6 | xai | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 500000 | 500000 | In: $2.00, Out: $6.00, Cache Read: $0.50 |
| grok-build-0.1 | xai | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 256000 | 256000 | In: $1.00, Out: $2.00, Cache Read: $0.20 |


### Streaming (761)

| Model | Provider | I/O | Capabilities | Context | Max Output | Standard Pricing (per 1M tokens) |
| :-- | :-- | :-- | :-- | --: | --: | :-- |
| anthropic.claude-3-haiku-20240307-v1:0 | bedrock | In: text, image; Out: text | streaming, function_calling | - | - | - |
| anthropic.claude-3-haiku-20240307-v1:0:200k | bedrock | In: text, image; Out: text | streaming, function_calling | - | - | - |
| anthropic.claude-3-haiku-20240307-v1:0:48k | bedrock | In: text, image; Out: text | streaming, function_calling | - | - | - |
| us.anthropic.claude-fable-5 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 1000000 | 128000 | In: $10.00, Out: $50.00, Cache Read: $1.00, Cache Write: $12.50 |
| us.anthropic.claude-haiku-4-5-20251001-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 64000 | In: $1.00, Out: $5.00, Cache Read: $0.10, Cache Write: $1.25 |
| us.anthropic.claude-opus-4-1-20250805-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 32000 | In: $15.00, Out: $75.00, Cache Read: $1.50, Cache Write: $18.75 |
| us.anthropic.claude-opus-4-5-20251101-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 64000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| us.anthropic.claude-opus-4-6-v1 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| us.anthropic.claude-opus-4-7 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming, structured_output | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| us.anthropic.claude-opus-4-8 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming, structured_output | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| us.anthropic.claude-opus-5 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| us.anthropic.claude-sonnet-4-20250514-v1:0 | bedrock | In: text, image; Out: text | streaming, function_calling, reasoning | 200000 | 65536 | - |
| us.anthropic.claude-sonnet-4-5-20250929-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 64000 | In: $3.00, Out: $15.00, Cache Read: $0.30, Cache Write: $3.75 |
| us.anthropic.claude-sonnet-4-6 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 64000 | In: $3.00, Out: $15.00, Cache Read: $0.30, Cache Write: $3.75 |
| us.anthropic.claude-sonnet-5 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 128000 | In: $2.00, Out: $10.00, Cache Read: $0.20, Cache Write: $2.50 |
| us.deepseek.r1-v1:0 | bedrock | In: text; Out: text | function_calling, reasoning, streaming | 128000 | 32768 | In: $1.35, Out: $5.40 |
| deepseek.v3-v1:0 | bedrock | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 163840 | 81920 | In: $0.58, Out: $1.68 |
| deepseek.v3.2 | bedrock | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 163840 | 81920 | In: $0.62, Out: $1.85 |
| mistral.devstral-2-123b | bedrock | In: text; Out: text | function_calling, structured_output, streaming | 256000 | 8192 | In: $0.40, Out: $2.00 |
| zai.glm-4.7 | bedrock | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 204800 | 131072 | In: $0.60, Out: $2.20 |
| zai.glm-4.7-flash | bedrock | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 200000 | 131072 | In: $0.07, Out: $0.40 |
| zai.glm-5 | bedrock | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 202752 | 101376 | In: $1.00, Out: $3.20 |
| openai.gpt-oss-safeguard-120b | bedrock | In: text; Out: text | function_calling, structured_output, streaming | 128000 | 16384 | In: $0.15, Out: $0.60 |
| openai.gpt-oss-safeguard-20b | bedrock | In: text; Out: text | function_calling, structured_output, streaming | 128000 | 16384 | In: $0.07, Out: $0.20 |
| openai.gpt-5.4 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 272000 | 128000 | In: $2.75, Out: $16.50, Cache Read: $0.28 |
| openai.gpt-5.6-luna | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1050000 | 128000 | In: $0.22, Out: $1.32, Cache Read: $0.02, Cache Write: $0.28 |
| us.openai.gpt-5.6-luna | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1050000 | 128000 | In: $0.22, Out: $1.32, Cache Read: $0.02, Cache Write: $0.28 |
| us.openai.gpt-5.6-sol | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1050000 | 128000 | In: $5.50, Out: $33.00, Cache Read: $0.55, Cache Write: $6.88 |
| openai.gpt-5.6-terra | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1050000 | 128000 | In: $2.20, Out: $13.20, Cache Read: $0.22, Cache Write: $2.75 |
| us.openai.gpt-5.6-terra | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1050000 | 128000 | In: $2.20, Out: $13.20, Cache Read: $0.22, Cache Write: $2.75 |
| google.gemma-3-4b-it | bedrock | In: text, image; Out: text | function_calling, vision, streaming | 128000 | 4096 | In: $0.04, Out: $0.08 |
| google.gemma-3-12b-it | bedrock | In: text, image; Out: text | structured_output, vision, streaming | 131072 | 8192 | In: $0.05, Out: $0.10 |
| google.gemma-3-27b-it | bedrock | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 202752 | 8192 | In: $0.12, Out: $0.20 |
| xai.grok-4.3 | bedrock | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 131072 | In: $1.25, Out: $2.50, Cache Read: $0.20 |
| us.xai.grok-4.6 | bedrock | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 500000 | 500000 | In: $2.20, Out: $6.60, Cache Read: $0.55 |
| xai.grok-4.6 | bedrock | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 500000 | 500000 | In: $2.20, Out: $6.60, Cache Read: $0.55 |
| moonshot.kimi-k2-thinking | bedrock | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 262143 | 16000 | In: $0.60, Out: $2.50 |
| moonshotai.kimi-k2.5 | bedrock | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 262143 | 16000 | In: $0.60, Out: $3.00 |
| meta.llama3-70b-instruct-v1:0 | bedrock | In: text; Out: text | streaming, function_calling | - | - | - |
| meta.llama3-8b-instruct-v1:0 | bedrock | In: text; Out: text | streaming, function_calling | - | - | - |
| meta.llama3-1-70b-instruct-v1:0 | bedrock | In: text; Out: text | function_calling, streaming | 128000 | 4096 | In: $0.72, Out: $0.72 |
| meta.llama3-1-70b-instruct-v1:0:128k | bedrock | In: text; Out: text | function_calling, streaming | 128000 | 4096 | In: $0.72, Out: $0.72 |
| meta.llama3-1-8b-instruct-v1:0 | bedrock | In: text; Out: text | function_calling, streaming | 128000 | 4096 | In: $0.22, Out: $0.22 |
| meta.llama3-1-8b-instruct-v1:0:128k | bedrock | In: text; Out: text | function_calling, streaming | 128000 | 4096 | In: $0.22, Out: $0.22 |
| meta.llama3-3-70b-instruct-v1:0:128k | bedrock | In: text; Out: text | function_calling, streaming | 128000 | 4096 | In: $0.72, Out: $0.72 |
| us.meta.llama3-3-70b-instruct-v1:0 | bedrock | In: text; Out: text | function_calling, streaming | 128000 | 4096 | In: $0.72, Out: $0.72 |
| us.meta.llama4-maverick-17b-instruct-v1:0 | bedrock | In: text, image; Out: text | function_calling, vision, streaming | 1000000 | 16384 | In: $0.24, Out: $0.97 |
| us.meta.llama4-scout-17b-instruct-v1:0 | bedrock | In: text, image; Out: text | function_calling, vision, streaming | 3500000 | 16384 | In: $0.17, Out: $0.66 |
| mistral.magistral-small-2509 | bedrock | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 128000 | 40000 | In: $0.50, Out: $1.50 |
| minimax.minimax-m2 | bedrock | In: text; Out: text | function_calling, reasoning, streaming | 204608 | 128000 | In: $0.30, Out: $1.20 |
| minimax.minimax-m2.1 | bedrock | In: text; Out: text | function_calling, reasoning, streaming | 204800 | 131072 | In: $0.30, Out: $1.20 |
| minimax.minimax-m2.5 | bedrock | In: text; Out: text | function_calling, reasoning, streaming | 196608 | 98304 | In: $0.30, Out: $1.20 |
| mistral.ministral-3-14b-instruct | bedrock | In: text; Out: text | function_calling, structured_output, streaming | 128000 | 4096 | In: $0.20, Out: $0.20 |
| mistral.ministral-3-3b-instruct | bedrock | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 256000 | 8192 | In: $0.10, Out: $0.10 |
| mistral.ministral-3-8b-instruct | bedrock | In: text; Out: text | function_calling, structured_output, streaming | 128000 | 4096 | In: $0.15, Out: $0.15 |
| mistral.mistral-7b-instruct-v0:2 | bedrock | In: text; Out: text | streaming, function_calling | - | - | - |
| mistral.mistral-large-2402-v1:0 | bedrock | In: text; Out: text | streaming, function_calling | - | - | - |
| mistral.mistral-large-2407-v1:0 | bedrock | In: text; Out: text | streaming, function_calling | - | - | - |
| mistral.mistral-large-3-675b-instruct | bedrock | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 256000 | 8192 | In: $0.50, Out: $1.50 |
| mistral.mixtral-8x7b-instruct-v0:1 | bedrock | In: text; Out: text | streaming, function_calling | - | - | - |
| nvidia.nemotron-super-3-120b | bedrock | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 262144 | 131072 | In: $0.15, Out: $0.65 |
| nvidia.nemotron-nano-12b-v2 | bedrock | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 128000 | 4096 | In: $0.20, Out: $0.60 |
| nvidia.nemotron-nano-3-30b | bedrock | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 128000 | 4096 | In: $0.06, Out: $0.24 |
| nvidia.nemotron-nano-9b-v2 | bedrock | In: text; Out: text | function_calling, structured_output, streaming | 128000 | 4096 | In: $0.06, Out: $0.23 |
| us.amazon.nova-2-lite-v1:0 | bedrock | In: text, image, video; Out: text | function_calling, reasoning, vision, video, streaming | 128000 | 4096 | In: $0.33, Out: $2.75 |
| amazon.nova-2-sonic-v1:0 | bedrock | In: audio; Out: audio, text | streaming | - | - | - |
| amazon.nova-lite-v1:0 | bedrock | In: text, image, video; Out: text | function_calling, vision, video, streaming | 300000 | 8192 | In: $0.06, Out: $0.24, Cache Read: $0.02 |
| us.amazon.nova-micro-v1:0 | bedrock | In: text; Out: text | function_calling, streaming | 128000 | 8192 | In: $0.04, Out: $0.14, Cache Read: $0.01 |
| amazon.nova-premier-v1:0:1000k | bedrock | In: text, image, video; Out: text | streaming, function_calling | - | - | - |
| amazon.nova-premier-v1:0:20k | bedrock | In: text, image, video; Out: text | streaming, function_calling | - | - | - |
| amazon.nova-premier-v1:0:8k | bedrock | In: text, image, video; Out: text | streaming, function_calling | - | - | - |
| amazon.nova-premier-v1:0:mm | bedrock | In: text, image, video; Out: text | streaming, function_calling | - | - | - |
| us.amazon.nova-premier-v1:0 | bedrock | In: text, image, video; Out: text | streaming, function_calling | - | - | - |
| us.amazon.nova-pro-v1:0 | bedrock | In: text, image, video; Out: text | function_calling, vision, video, streaming | 300000 | 8192 | In: $0.80, Out: $3.20, Cache Read: $0.20 |
| us.writer.palmyra-x4-v1:0 | bedrock | In: text; Out: text | function_calling, reasoning, streaming | 122880 | 8192 | In: $2.50, Out: $10.00 |
| us.writer.palmyra-x5-v1:0 | bedrock | In: text; Out: text | function_calling, reasoning, streaming | 1040000 | 8192 | In: $0.60, Out: $6.00 |
| us.twelvelabs.pegasus-1-2-v1:0 | bedrock | In: text, video; Out: text | streaming | - | - | - |
| us.mistral.pixtral-large-2502-v1:0 | bedrock | In: text, image; Out: text | function_calling, vision, streaming | 128000 | 8192 | In: $2.00, Out: $6.00 |
| qwen.qwen3-next-80b-a3b | bedrock | In: text; Out: text | function_calling, structured_output, streaming | 262000 | 262000 | In: $0.14, Out: $1.40 |
| qwen.qwen3-vl-235b-a22b | bedrock | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 262000 | 262000 | In: $0.30, Out: $1.50 |
| qwen.qwen3-235b-a22b-2507-v1:0 | bedrock | In: text; Out: text | function_calling, structured_output, streaming | 262144 | 131072 | In: $0.22, Out: $0.88 |
| qwen.qwen3-32b-v1:0 | bedrock | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 16384 | 16384 | In: $0.15, Out: $0.60 |
| qwen.qwen3-coder-30b-a3b-v1:0 | bedrock | In: text; Out: text | function_calling, structured_output, streaming | 262144 | 131072 | In: $0.15, Out: $0.60 |
| qwen.qwen3-coder-480b-a35b-v1:0 | bedrock | In: text; Out: text | function_calling, structured_output, streaming | 131072 | 65536 | In: $0.22, Out: $1.80 |
| qwen.qwen3-coder-next | bedrock | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 131072 | 65536 | In: $0.22, Out: $1.80 |
| mistral.voxtral-mini-3b-2507 | bedrock | In: audio, text; Out: text | function_calling, structured_output, streaming | 128000 | 4096 | In: $0.04, Out: $0.04 |
| mistral.voxtral-small-24b-2507 | bedrock | In: text, audio; Out: text | function_calling, structured_output, streaming | 32000 | 8192 | In: $0.15, Out: $0.35 |
| writer.palmyra-vision-7b | bedrock | In: text, image; Out: text | streaming, function_calling | - | 4096 | - |
| anthropic.claude-haiku-4-5 | bedrock | In: text; Out: text | streaming | - | - | - |
| deepseek.v3.1 | bedrock | In: text; Out: text | streaming | - | - | - |
| google.gemma-4-26b-a4b | bedrock | In: text; Out: text | streaming | - | - | - |
| google.gemma-4-31b | bedrock | In: text; Out: text | streaming | - | - | - |
| google.gemma-4-e2b | bedrock | In: text; Out: text | streaming | - | - | - |
| openai.gpt-oss-120b | bedrock | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 128000 | 16384 | In: $0.15, Out: $0.60 |
| openai.gpt-oss-120b-1:0 | bedrock | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 128000 | 16384 | In: $0.15, Out: $0.60 |
| openai.gpt-oss-20b | bedrock | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 128000 | 16384 | In: $0.07, Out: $0.30 |
| openai.gpt-oss-20b-1:0 | bedrock | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 128000 | 16384 | In: $0.07, Out: $0.30 |
| moonshotai.kimi-k2-thinking | bedrock | In: text; Out: text | streaming | - | - | - |
| openai.gpt-5.4-2026-03-05 | bedrock | In: text; Out: text | streaming | - | - | - |
| qwen.qwen3-235b-a22b-2507 | bedrock | In: text; Out: text | streaming | - | - | - |
| qwen.qwen3-32b | bedrock | In: text; Out: text | streaming | - | - | - |
| qwen.qwen3-coder-30b-a3b-instruct | bedrock | In: text; Out: text | streaming | - | - | - |
| qwen.qwen3-coder-480b-a35b-instruct | bedrock | In: text; Out: text | streaming | - | - | - |
| qwen.qwen3-next-80b-a3b-instruct | bedrock | In: text; Out: text | streaming | - | - | - |
| qwen.qwen3-vl-235b-a22b-instruct | bedrock | In: text; Out: text | streaming | - | - | - |
| zai.glm-4.6 | bedrock | In: text; Out: text | streaming | - | - | - |
| c4ai-aya-expanse-32b | cohere | In: text; Out: text | streaming | 128000 | 4000 | In: $0.50, Out: $1.50 |
| c4ai-aya-vision-32b | cohere | In: text, image; Out: text | vision, streaming | 16000 | 4000 | In: $0.50, Out: $1.50 |
| command-a-03-2025 | cohere | In: text; Out: text | function_calling, streaming, structured_output, citations, tool_choice | 256000 | 8000 | In: $2.50, Out: $10.00 |
| command-a-plus-05-2026 | cohere | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming, citations | 128000 | 64000 | In: $2.50, Out: $10.00 |
| command-a-reasoning-08-2025 | cohere | In: text; Out: text | function_calling, reasoning, streaming, structured_output, citations | 256000 | 32000 | In: $2.50, Out: $10.00 |
| command-a-translate-08-2025 | cohere | In: text; Out: text | function_calling, streaming | 8000 | 8000 | In: $2.50, Out: $10.00 |
| command-a-vision-07-2025 | cohere | In: text, image; Out: text | vision, streaming | 128000 | 8000 | In: $2.50, Out: $10.00 |
| command-r-08-2024 | cohere | In: text; Out: text | function_calling, streaming, structured_output, citations, tool_choice | 128000 | 4000 | In: $0.15, Out: $0.60 |
| command-r-plus-08-2024 | cohere | In: text; Out: text | function_calling, streaming, structured_output, citations, tool_choice | 128000 | 4000 | In: $2.50, Out: $10.00 |
| command-r7b-12-2024 | cohere | In: text; Out: text | function_calling, streaming, structured_output, citations, tool_choice | 128000 | 4000 | In: $0.04, Out: $0.15 |
| command-r7b-arabic-02-2025 | cohere | In: text; Out: text | function_calling, streaming, structured_output, citations | 128000 | 4000 | In: $0.04, Out: $0.15 |
| north-mini-code-1-0 | cohere | In: text; Out: text | function_calling, structured_output, reasoning, streaming, citations | 256000 | 64000 | In: $0.00, Out: $0.00 |
| tiny-aya-earth | cohere | In: text; Out: text | streaming | 8192 | 4000 | - |
| tiny-aya-fire | cohere | In: text; Out: text | streaming | 8192 | 4000 | - |
| tiny-aya-global | cohere | In: text; Out: text | streaming | 8192 | 4000 | - |
| tiny-aya-water | cohere | In: text; Out: text | streaming | 8192 | 4000 | - |
| codestral-2508 | mistral | In: text; Out: text | streaming, function_calling, tool_choice, parallel_tool_calls, structured_output, batch, predicted_outputs | 256000 | 8192 | - |
| codestral-latest | mistral | In: text; Out: text | function_calling, streaming, tool_choice, parallel_tool_calls, structured_output, batch, predicted_outputs | 256000 | 4096 | In: $0.30, Out: $0.90 |
| devstral-2512 | mistral | In: text; Out: text | function_calling, streaming, tool_choice, parallel_tool_calls, structured_output, batch | 262144 | 262144 | In: $0.40, Out: $2.00 |
| devstral-latest | mistral | In: text; Out: text | function_calling, streaming, tool_choice, parallel_tool_calls, structured_output, batch | 262144 | 262144 | In: $0.40, Out: $2.00 |
| devstral-medium-latest | mistral | In: text; Out: text | function_calling, streaming, tool_choice, parallel_tool_calls, structured_output, batch | 262144 | 262144 | In: $0.40, Out: $2.00 |
| glm-5-2 | mistral | In: text; Out: text | streaming, function_calling, tool_choice, parallel_tool_calls, structured_output, batch, reasoning | 1048576 | 8192 | - |
| labs-leanstral-1-5 | mistral | In: text, image; Out: text | streaming, function_calling, tool_choice, parallel_tool_calls, structured_output, batch, reasoning, vision | 262144 | 8192 | - |
| labs-leanstral-1-5-1 | mistral | In: text, image; Out: text | streaming, function_calling, tool_choice, parallel_tool_calls, structured_output, batch, reasoning, vision | 262144 | 8192 | - |
| magistral-medium-latest | mistral | In: text; Out: text | function_calling, reasoning, streaming, tool_choice, parallel_tool_calls, structured_output, batch | 128000 | 16384 | In: $2.00, Out: $5.00 |
| magistral-small-latest | mistral | In: text, image; Out: text | streaming, function_calling, tool_choice, parallel_tool_calls, structured_output, reasoning, batch, vision | 262144 | 8192 | - |
| ministral-14b-2512 | mistral | In: text, image; Out: text | streaming, function_calling, tool_choice, parallel_tool_calls, structured_output, batch, distillation, fine_tuning, vision | 262144 | 8192 | - |
| ministral-14b-latest | mistral | In: text, image; Out: text | streaming, function_calling, tool_choice, parallel_tool_calls, structured_output, batch, distillation, fine_tuning, vision | 262144 | 8192 | - |
| ministral-3b-2512 | mistral | In: text, image; Out: text | streaming, function_calling, tool_choice, parallel_tool_calls, structured_output, batch, distillation, fine_tuning, vision | 131072 | 8192 | - |
| ministral-3b-latest | mistral | In: text; Out: text | function_calling, streaming, tool_choice, parallel_tool_calls, structured_output, batch, distillation, fine_tuning | 128000 | 128000 | In: $0.04, Out: $0.04 |
| ministral-8b-2512 | mistral | In: text, image; Out: text | streaming, function_calling, tool_choice, parallel_tool_calls, structured_output, batch, distillation, fine_tuning, vision | 262144 | 8192 | - |
| ministral-8b-latest | mistral | In: text; Out: text | function_calling, streaming, tool_choice, parallel_tool_calls, structured_output, batch, distillation, fine_tuning | 128000 | 128000 | In: $0.10, Out: $0.10 |
| mistral-code-agent-latest | mistral | In: text; Out: text | streaming, function_calling, tool_choice, parallel_tool_calls, structured_output, batch | 262144 | 8192 | - |
| mistral-code-fim-latest | mistral | In: text; Out: text | streaming, function_calling, tool_choice, parallel_tool_calls, structured_output, batch | 256000 | 8192 | - |
| mistral-code-latest | mistral | In: text; Out: text | streaming, function_calling, tool_choice, parallel_tool_calls, structured_output, batch | 256000 | 8192 | - |
| mistral-large-latest | mistral | In: text, image; Out: text | function_calling, vision, streaming, tool_choice, parallel_tool_calls, structured_output, batch, fine_tuning | 262144 | 262144 | In: $0.50, Out: $1.50 |
| mistral-large-2512 | mistral | In: text, image; Out: text | function_calling, vision, streaming, tool_choice, parallel_tool_calls, structured_output, batch, fine_tuning | 262144 | 262144 | In: $0.50, Out: $1.50 |
| mistral-medium | mistral | In: text, image; Out: text | streaming, function_calling, tool_choice, parallel_tool_calls, structured_output, batch, reasoning, vision | 262144 | 8192 | - |
| mistral-medium-3 | mistral | In: text, image; Out: text | streaming, function_calling, tool_choice, parallel_tool_calls, structured_output, reasoning, batch, vision | 262144 | 8192 | - |
| mistral-medium-3-5 | mistral | In: text, image; Out: text | streaming, function_calling, tool_choice, parallel_tool_calls, structured_output, reasoning, batch, vision | 262144 | 8192 | - |
| mistral-medium-3.5 | mistral | In: text, image; Out: text | streaming, function_calling, tool_choice, parallel_tool_calls, structured_output, reasoning, batch, vision | 262144 | 8192 | - |
| mistral-medium-latest | mistral | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming, tool_choice, parallel_tool_calls, batch | 262144 | 262144 | In: $1.50, Out: $7.50 |
| mistral-medium-2505 | mistral | In: text, image; Out: text | function_calling, vision, streaming, tool_choice, parallel_tool_calls, structured_output, batch, fine_tuning | 131072 | 131072 | In: $0.40, Out: $2.00 |
| mistral-medium-2508 | mistral | In: text, image; Out: text | function_calling, vision, streaming, tool_choice, parallel_tool_calls, structured_output, batch, fine_tuning | 262144 | 262144 | In: $0.40, Out: $2.00 |
| mistral-medium-2604 | mistral | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming, tool_choice, parallel_tool_calls, batch | 262144 | 262144 | In: $1.50, Out: $7.50 |
| mistral-small-latest | mistral | In: text, image; Out: text | function_calling, reasoning, vision, streaming, tool_choice, parallel_tool_calls, structured_output, batch | 256000 | 256000 | In: $0.15, Out: $0.60 |
| mistral-small-2603 | mistral | In: text, image; Out: text | function_calling, reasoning, vision, streaming, tool_choice, parallel_tool_calls, structured_output, batch | 256000 | 256000 | In: $0.15, Out: $0.60 |
| mistral-vibe-cli-fast | mistral | In: text, image; Out: text | streaming, function_calling, tool_choice, parallel_tool_calls, structured_output, batch, reasoning, vision | 262144 | 8192 | - |
| mistral-vibe-cli-latest | mistral | In: text, image; Out: text | streaming, function_calling, tool_choice, parallel_tool_calls, structured_output, batch, reasoning, vision | 262144 | 8192 | - |
| mistral-vibe-cli-with-tools | mistral | In: text, image; Out: text | streaming, function_calling, tool_choice, parallel_tool_calls, structured_output, batch, reasoning, vision | 262144 | 8192 | - |
| voxtral-mini-latest | mistral | In: audio; Out: text | streaming, transcription | 0 | 0 | - |
| voxtral-mini-2602 | mistral | In: text, audio; Out: text | streaming, transcription | 16384 | 8192 | - |
| voxtral-mini-realtime-2602 | mistral | In: text, audio; Out: text | streaming, realtime | 32768 | 8192 | - |
| voxtral-mini-realtime-latest | mistral | In: text, audio; Out: text | streaming, realtime | 32768 | 8192 | - |
| voxtral-mini-tts-latest | mistral | In: text; Out: audio | streaming, fine_tuning, speech_generation | 0 | 0 | - |
| voxtral-mini-tts-2603 | mistral | In: text; Out: audio | streaming, function_calling, fine_tuning, speech_generation | 4096 | 8192 | - |
| voxtral-small-latest | mistral | In: text, audio; Out: text | function_calling, streaming | 32000 | 32000 | In: $0.10, Out: $0.30 |
| voxtral-small-2507 | mistral | In: text, audio; Out: text | streaming, function_calling | 32768 | 8192 | - |
| zai-glm-5-2 | mistral | In: text; Out: text | streaming, function_calling, tool_choice, parallel_tool_calls, structured_output, batch, reasoning | 1048576 | 8192 | - |
| deepseek-v4-flash:0731 | ollama_cloud | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 1048576 | 1048576 | - |
| glm-5.2 | ollama_cloud | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 976000 | 131072 | - |
| deepseek-v4-flash:preview | ollama_cloud | In: text; Out: text | streaming, function_calling, reasoning | - | - | - |
| deepseek-v4-pro:0813 | ollama_cloud | In: text; Out: text | streaming, function_calling, reasoning | - | - | - |
| deepseek-v4-pro:preview | ollama_cloud | In: text; Out: text | streaming, function_calling, reasoning | - | - | - |
| gemma4:31b | ollama_cloud | In: text, image; Out: text | function_calling, reasoning, vision, streaming | 262144 | 262144 | - |
| glm-5.1 | ollama_cloud | In: text; Out: text | function_calling, reasoning, streaming | 202752 | 131072 | - |
| gpt-oss:120b | ollama_cloud | In: text; Out: text | function_calling, reasoning, streaming | 131072 | 32768 | - |
| gpt-oss:20b | ollama_cloud | In: text; Out: text | function_calling, reasoning, streaming | 131072 | 32768 | - |
| kimi-k2.6 | ollama_cloud | In: text, image; Out: text | function_calling, reasoning, vision, streaming | 262144 | 262144 | - |
| kimi-k2.7-code | ollama_cloud | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 262144 | 262144 | - |
| kimi-k3 | ollama_cloud | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1048576 | 131072 | - |
| minimax-m2.7 | ollama_cloud | In: text; Out: text | function_calling, reasoning, streaming | 196608 | 196608 | - |
| minimax-m3 | ollama_cloud | In: text, image, video; Out: text | function_calling, reasoning, vision, video, streaming | 512000 | 131072 | - |
| mistral-large-3:675b | ollama_cloud | In: text, image; Out: text | function_calling, vision, streaming | 262144 | 262144 | - |
| nemotron-3-nano:30b | ollama_cloud | In: text; Out: text | function_calling, reasoning, streaming | 1048576 | 131072 | - |
| nemotron-3-super | ollama_cloud | In: text; Out: text | function_calling, reasoning, streaming | 262144 | 65536 | - |
| nemotron-3-ultra | ollama_cloud | In: text; Out: text | function_calling, reasoning, streaming | 262144 | 128000 | - |
| qwen3.5:397b | ollama_cloud | In: text, image; Out: text | function_calling, reasoning, vision, streaming | 262144 | 65536 | - |
| aion-labs/aion-2.0 | openrouter | In: text; Out: text | function_calling, reasoning, streaming | 131072 | 32768 | In: $0.80, Out: $1.60, Cache Read: $0.20 |
| aion-labs/aion-3.0 | openrouter | In: text; Out: text | function_calling, reasoning, streaming | 131072 | 32768 | In: $3.00, Out: $6.00, Cache Read: $0.75 |
| aion-labs/aion-3.0-mini | openrouter | In: text; Out: text | function_calling, reasoning, streaming | 131072 | 32768 | In: $0.70, Out: $1.40, Cache Read: $0.18 |
| aion-labs/aion-rp-llama-3.1-8b | openrouter | In: text; Out: text | streaming | 32768 | 32768 | In: $0.80, Out: $1.60 |
| ~anthropic/claude-haiku-latest | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 64000 | In: $1.00, Out: $5.00, Cache Read: $0.10, Cache Write: $1.25 |
| ~anthropic/claude-sonnet-latest | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 128000 | In: $2.00, Out: $10.00, Cache Read: $0.20, Cache Write: $2.50 |
| anthropic/claude-fable-5:batch | openrouter | In: text, image, file; Out: text | streaming, function_calling, structured_output | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| anthropic/claude-haiku-4.5:batch | openrouter | In: text, image, file; Out: text | streaming, function_calling, structured_output | 200000 | 64000 | In: $0.50, Out: $2.50, Cache Read: $0.05, Cache Write: $0.62 |
| anthropic/claude-opus-4.1:batch | openrouter | In: image, text, file; Out: text | streaming, function_calling, structured_output | 200000 | 32000 | In: $7.50, Out: $37.50, Cache Read: $0.75, Cache Write: $9.38 |
| anthropic/claude-opus-4.5:batch | openrouter | In: file, image, text; Out: text | streaming, function_calling, structured_output | 200000 | 64000 | In: $2.50, Out: $12.50, Cache Read: $0.25, Cache Write: $3.12 |
| anthropic/claude-opus-4.6:batch | openrouter | In: text, image, file; Out: text | streaming, function_calling, structured_output | 1000000 | 128000 | In: $2.50, Out: $12.50, Cache Read: $0.25, Cache Write: $3.12 |
| anthropic/claude-opus-4.7:batch | openrouter | In: text, image, file; Out: text | streaming, function_calling, structured_output | 1000000 | 128000 | In: $2.50, Out: $12.50, Cache Read: $0.25, Cache Write: $3.12 |
| anthropic/claude-opus-4.8:batch | openrouter | In: text, image, file; Out: text | streaming, function_calling, structured_output | 1000000 | 128000 | In: $2.50, Out: $12.50, Cache Read: $0.25, Cache Write: $3.12 |
| anthropic/claude-sonnet-4.5:batch | openrouter | In: text, image, file; Out: text | streaming, function_calling, structured_output | 1000000 | 64000 | In: $1.50, Out: $7.50, Cache Read: $0.15, Cache Write: $1.88 |
| anthropic/claude-sonnet-4.6:batch | openrouter | In: text, image, file; Out: text | streaming, function_calling, structured_output | 1000000 | 128000 | In: $1.50, Out: $7.50, Cache Read: $0.15, Cache Write: $1.88 |
| anthropic/claude-sonnet-5:batch | openrouter | In: text, image, file; Out: text | streaming, function_calling, structured_output | 1000000 | 128000 | In: $1.00, Out: $5.00, Cache Read: $0.10, Cache Write: $1.25 |
| openrouter/auto | openrouter | In: text, image, audio, pdf, video; Out: text, image | function_calling, structured_output, reasoning, vision, video, streaming, predicted_outputs, image_generation | 2000000 | 2000000 | - |
| openrouter/auto-beta | openrouter | In: text, image, audio, file, video; Out: text, image | streaming, function_calling, structured_output, predicted_outputs, image_generation | 2000000 | - | - |
| baai/bge-base-en-v1.5 | openrouter | In: text; Out: embeddings | streaming, structured_output | 512 | - | In: $0.01 |
| baai/bge-large-en-v1.5 | openrouter | In: text; Out: embeddings | streaming, structured_output | 512 | - | In: $0.01 |
| baai/bge-m3 | openrouter | In: text; Out: embeddings | streaming, structured_output, predicted_outputs | 8194 | - | In: $0.01 |
| black-forest-labs/flux.2-flex | openrouter | In: text, image; Out: image | streaming, image_generation | - | - | - |
| black-forest-labs/flux.2-klein-4b | openrouter | In: text, image; Out: image | streaming, image_generation | - | - | - |
| black-forest-labs/flux.2-max | openrouter | In: text, image; Out: image | streaming, image_generation | - | - | - |
| black-forest-labs/flux.2-pro | openrouter | In: text, image; Out: image | streaming, image_generation | - | - | - |
| openrouter/bodybuilder | openrouter | In: text; Out: text | streaming | 128000 | 128000 | - |
| bytedance-seed/seedream-4.5 | openrouter | In: image, text; Out: image | streaming, image_generation | - | - | - |
| bytedance-seed/seedream-5-0-lite | openrouter | In: text, image; Out: image | streaming, image_generation | - | - | - |
| bytedance-seed/seedream-5-0-pro | openrouter | In: text, image; Out: image | streaming, image_generation | - | - | - |
| canopylabs/orpheus-3b-0.1-ft | openrouter | In: text; Out: audio | streaming, structured_output, predicted_outputs, speech_generation | 4096 | - | In: $7.00 |
| anthropic/claude-3-haiku | openrouter | In: text, image; Out: text | function_calling, vision, streaming | 200000 | 4096 | In: $0.25, Out: $1.25, Cache Read: $0.03, Cache Write: $0.30 |
| anthropic/claude-fable-5 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 128000 | In: $10.00, Out: $50.00, Cache Read: $1.00, Cache Write: $12.50 |
| ~anthropic/claude-fable-latest | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 128000 | In: $10.00, Out: $50.00, Cache Read: $1.00, Cache Write: $12.50 |
| anthropic/claude-haiku-4.5 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 64000 | In: $1.00, Out: $5.00, Cache Read: $0.10, Cache Write: $1.25 |
| anthropic/claude-opus-4 | openrouter | In: image, text, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 32000 | In: $15.00, Out: $75.00, Cache Read: $1.50, Cache Write: $18.75 |
| anthropic/claude-opus-4.1 | openrouter | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 32000 | In: $15.00, Out: $75.00, Cache Read: $1.50, Cache Write: $18.75 |
| anthropic/claude-opus-4.5 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 64000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| anthropic/claude-opus-4.6 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| anthropic/claude-opus-4.7 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| anthropic/claude-opus-4.7-fast | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 128000 | In: $30.00, Out: $150.00, Cache Read: $3.00, Cache Write: $37.50 |
| anthropic/claude-opus-4.8 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| anthropic/claude-opus-4.8-fast | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 128000 | In: $10.00, Out: $50.00, Cache Read: $1.00, Cache Write: $12.50 |
| anthropic/claude-opus-5 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| anthropic/claude-opus-5-fast | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 128000 | In: $10.00, Out: $50.00, Cache Read: $1.00, Cache Write: $12.50 |
| anthropic/claude-opus-5:batch | openrouter | In: text, image, file; Out: text | streaming, function_calling, structured_output | 1000000 | 128000 | In: $2.50, Out: $12.50, Cache Read: $0.25, Cache Write: $3.12 |
| ~anthropic/claude-opus-latest | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| anthropic/claude-sonnet-4 | openrouter | In: image, text, pdf; Out: text | function_calling, reasoning, vision, streaming | 1000000 | 64000 | In: $3.00, Out: $15.00, Cache Read: $0.30, Cache Write: $3.75 |
| anthropic/claude-sonnet-4.5 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 64000 | In: $3.00, Out: $15.00, Cache Read: $0.30, Cache Write: $3.75 |
| anthropic/claude-sonnet-4.6 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 128000 | In: $3.00, Out: $15.00, Cache Read: $0.30, Cache Write: $3.75 |
| anthropic/claude-sonnet-5 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 128000 | In: $2.00, Out: $10.00, Cache Read: $0.20, Cache Write: $2.50 |
| mistralai/codestral-2508 | openrouter | In: text, pdf; Out: text | function_calling, structured_output, vision, streaming | 256000 | 256000 | In: $0.30, Out: $0.90, Cache Read: $0.03 |
| deepcogito/cogito-v2.1-671b | openrouter | In: text; Out: text | structured_output, reasoning, streaming, predicted_outputs | 128000 | 128000 | In: $1.25, Out: $1.25 |
| cohere/rerank-4-fast | openrouter | In: text; Out: rerank | streaming, structured_output | 32768 | - | - |
| cohere/rerank-4-pro | openrouter | In: text; Out: rerank | streaming, structured_output | 32768 | - | - |
| cohere/rerank-v3.5 | openrouter | In: text; Out: rerank | streaming, structured_output | 4096 | - | - |
| cohere/command-a | openrouter | In: text; Out: text | structured_output, streaming | 256000 | 8192 | In: $2.50, Out: $10.00 |
| cohere/command-r-08-2024 | openrouter | In: text; Out: text | function_calling, structured_output, streaming | 128000 | 4000 | In: $0.15, Out: $0.60 |
| cohere/command-r-plus-08-2024 | openrouter | In: text; Out: text | function_calling, structured_output, streaming | 128000 | 4000 | In: $2.50, Out: $10.00 |
| cohere/command-r7b-12-2024 | openrouter | In: text; Out: text | structured_output, streaming | 128000 | 4000 | In: $0.04, Out: $0.15 |
| thedrummer/cydonia-24b-v4.1 | openrouter | In: text; Out: text | structured_output, streaming, predicted_outputs | 131072 | 131072 | In: $0.30, Out: $0.50, Cache Read: $0.15 |
| deepseek/deepseek-chat | openrouter | In: text; Out: text | function_calling, structured_output, streaming, predicted_outputs | 163840 | 16000 | In: $0.26, Out: $1.03 |
| deepseek/deepseek-chat-v3-0324 | openrouter | In: text; Out: text | function_calling, structured_output, streaming, predicted_outputs | 163840 | 163840 | In: $0.25, Out: $1.00 |
| deepseek/deepseek-chat-v3.1 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 163840 | 32768 | In: $0.25, Out: $0.95, Cache Read: $0.13 |
| deepseek/deepseek-v3.1-terminus | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 163840 | 163840 | In: $0.27, Out: $1.00 |
| deepseek/deepseek-v3.2 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 163840 | 65536 | In: $0.27, Out: $0.40, Cache Read: $0.13 |
| deepseek/deepseek-v3.2-exp | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 163840 | 65536 | In: $0.27, Out: $0.41 |
| deepseek/deepseek-v4-flash | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 1048576 | 384000 | In: $0.09, Out: $0.18, Cache Read: $0.02 |
| deepseek/deepseek-v4-flash-0731 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 1310720 | 393216 | In: $0.14, Out: $0.28, Cache Read: $0.03 |
| ~deepseek/deepseek-v4-flash-latest | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 1310720 | 262144 | In: $0.06, Out: $0.14, Cache Read: $0.01 |
| deepseek/deepseek-v4-pro | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 1048576 | 393216 | In: $1.60, Out: $3.20, Cache Read: $0.14 |
| deepseek/deepseek-v4-pro-0813 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 1048576 | 384000 | In: $1.19, Out: $3.56, Cache Read: $0.04 |
| deepseek/deepseek-r1 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 64000 | 16000 | In: $0.70, Out: $2.50 |
| deepgram/aura-2 | openrouter | In: text; Out: audio | streaming, speech_generation | 0 | - | In: $30.00 |
| deepgram/flux-tts:free | openrouter | In: text; Out: audio | streaming, speech_generation | 0 | - | - |
| deepgram/nova-3 | openrouter | In: audio; Out: text | streaming, transcription | 0 | - | In: $4300.00 |
| dots-studio/dots-3-note-preview:free | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 512000 | 512000 | In: $0.00, Out: $0.00 |
| baidu/ernie-4.5-vl-424b-a47b | openrouter | In: image, text; Out: text | reasoning, vision, streaming | 123000 | 16000 | In: $0.42, Out: $1.25 |
| fish-audio/s1 | openrouter | In: text; Out: audio | streaming, speech_generation | 0 | - | In: $15.00 |
| fish-audio/s2-pro | openrouter | In: text; Out: audio | streaming, speech_generation | 0 | - | In: $15.00 |
| fish-audio/s2.1-pro | openrouter | In: text; Out: audio | streaming, speech_generation | 0 | - | In: $15.00 |
| fish-audio/s2.1-pro-free:free | openrouter | In: text; Out: audio | streaming, speech_generation | 0 | - | - |
| fish-audio/transcribe-1 | openrouter | In: audio; Out: text | streaming, transcription | 0 | - | In: $100.00 |
| openrouter/free | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 8000 | In: $0.00, Out: $0.00 |
| sakana/fugu-ultra | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 128000 | In: $5.00, Out: $30.00, Cache Read: $0.50 |
| openrouter/fusion | openrouter | In: text; Out: text | streaming | 1000000 | 128000 | - |
| z-ai/glm-5.2:free | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 256000 | 256000 | In: $0.00, Out: $0.00 |
| ~z-ai/glm-latest | openrouter | In: text; Out: text | function_calling, reasoning, streaming | 1048576 | 131072 | In: $1.40, Out: $4.40, Cache Read: $0.26 |
| z-ai/glm-4.5 | openrouter | In: text; Out: text | function_calling, reasoning, streaming | 131072 | 98304 | In: $0.60, Out: $2.20, Cache Read: $0.11 |
| z-ai/glm-4.5-air | openrouter | In: text; Out: text | function_calling, reasoning, streaming | 131072 | 98304 | In: $0.13, Out: $0.85, Cache Read: $0.02 |
| z-ai/glm-4.5v | openrouter | In: text, image; Out: text | function_calling, reasoning, vision, streaming | 65536 | 16384 | In: $0.60, Out: $1.80, Cache Read: $0.11 |
| z-ai/glm-4.6 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 204800 | 131072 | In: $0.50, Out: $2.00, Cache Read: $0.10 |
| z-ai/glm-4.6v | openrouter | In: text, image, video; Out: text | function_calling, reasoning, vision, video, streaming | 131072 | 32768 | In: $0.30, Out: $0.90, Cache Read: $0.06 |
| z-ai/glm-4.7 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 204800 | 131072 | In: $0.40, Out: $1.75, Cache Read: $0.08 |
| z-ai/glm-4.7-flash | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 202752 | 16384 | In: $0.06, Out: $0.40, Cache Read: $0.01 |
| z-ai/glm-5 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 204800 | 128000 | In: $0.60, Out: $1.92, Cache Read: $0.12 |
| z-ai/glm-5-turbo | openrouter | In: text; Out: text | function_calling, reasoning, streaming | 202752 | 131072 | In: $1.20, Out: $4.00, Cache Read: $0.24 |
| z-ai/glm-5.1 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 204800 | 128000 | In: $0.97, Out: $3.04, Cache Read: $0.18 |
| z-ai/glm-5.2 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 1048576 | 131072 | In: $0.97, Out: $3.04, Cache Read: $0.19 |
| z-ai/glm-5.3 | openrouter | In: text; Out: text | function_calling, reasoning, streaming | 1048576 | 131072 | In: $1.40, Out: $4.40, Cache Read: $0.26 |
| z-ai/glm-5v-turbo | openrouter | In: image, text, video; Out: text | function_calling, reasoning, vision, video, streaming | 202752 | 131072 | In: $1.20, Out: $4.00, Cache Read: $0.24 |
| openai/gpt-audio | openrouter | In: text, audio; Out: text, audio | function_calling, structured_output, streaming | 128000 | 16384 | In: $2.50, Out: $10.00 |
| openai/gpt-audio-mini | openrouter | In: text, audio; Out: text, audio | function_calling, structured_output, streaming | 128000 | 16384 | In: $0.60, Out: $2.40 |
| openai/gpt-chat-latest | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, vision, streaming | 400000 | 128000 | In: $5.00, Out: $30.00, Cache Read: $0.50 |
| openai/gpt-oss-120b | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 131072 | 131072 | In: $0.03, Out: $0.17, Cache Read: $0.03 |
| openai/gpt-oss-20b | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 131072 | 131072 | In: $0.03, Out: $0.13, Cache Read: $0.03 |
| openai/gpt-3.5-turbo-0613 | openrouter | In: text; Out: text | function_calling, structured_output, streaming | 4095 | 4096 | In: $1.00, Out: $2.00 |
| openai/gpt-3.5-turbo-16k | openrouter | In: text; Out: text | function_calling, structured_output, streaming | 16385 | 4096 | In: $3.00, Out: $4.00 |
| openai/gpt-3.5-turbo-instruct | openrouter | In: text; Out: text | structured_output, streaming | 4095 | 4096 | In: $1.50, Out: $2.00 |
| openai/gpt-3.5-turbo | openrouter | In: text; Out: text | function_calling, structured_output, streaming | 16385 | 4096 | In: $0.50, Out: $1.50 |
| openai/gpt-4 | openrouter | In: text; Out: text | function_calling, structured_output, streaming | 8191 | 4096 | In: $30.00, Out: $60.00 |
| openai/gpt-4-turbo | openrouter | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 128000 | 4096 | In: $10.00, Out: $30.00 |
| openai/gpt-4-turbo-preview | openrouter | In: text; Out: text | function_calling, structured_output, streaming | 128000 | 4096 | In: $10.00, Out: $30.00 |
| openai/gpt-4.1 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, vision, streaming | 1047576 | 32768 | In: $2.00, Out: $8.00, Cache Read: $0.50 |
| openai/gpt-4.1-mini | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, vision, streaming | 1047576 | 32768 | In: $0.40, Out: $1.60, Cache Read: $0.10 |
| openai/gpt-4.1-nano | openrouter | In: image, text, pdf; Out: text | function_calling, structured_output, vision, streaming | 1047576 | 32768 | In: $0.10, Out: $0.40, Cache Read: $0.02 |
| openai/gpt-4o | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, vision, streaming | 128000 | 16384 | In: $2.50, Out: $10.00, Cache Read: $1.25 |
| openai/gpt-4o-2024-05-13 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, vision, streaming | 128000 | 4096 | In: $5.00, Out: $15.00 |
| openai/gpt-4o-2024-08-06 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, vision, streaming | 128000 | 16384 | In: $2.50, Out: $10.00, Cache Read: $1.25 |
| openai/gpt-4o-2024-11-20 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, vision, streaming | 128000 | 16384 | In: $2.50, Out: $10.00, Cache Read: $1.25 |
| openai/gpt-4o-mini | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, vision, streaming | 128000 | 16384 | In: $0.15, Out: $0.60, Cache Read: $0.08 |
| openai/gpt-4o-mini-2024-07-18 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, vision, streaming | 128000 | 16384 | In: $0.15, Out: $0.60, Cache Read: $0.08 |
| openai/gpt-5 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $1.25, Out: $10.00, Cache Read: $0.12 |
| openai/gpt-5-image | openrouter | In: image, text, pdf; Out: image, text | structured_output, reasoning, vision, streaming, image_generation | 400000 | 128000 | In: $10.00, Out: $10.00, Cache Read: $1.25 |
| openai/gpt-5-image-mini | openrouter | In: pdf, image, text; Out: image, text | structured_output, reasoning, vision, streaming, image_generation | 400000 | 128000 | In: $2.50, Out: $2.00, Cache Read: $0.25 |
| openai/gpt-5-mini | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $0.25, Out: $2.00, Cache Read: $0.02 |
| openai/gpt-5-nano | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $0.05, Out: $0.40, Cache Read: $0.01 |
| openai/gpt-5-pro | openrouter | In: image, text, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $15.00, Out: $120.00 |
| openai/gpt-5.1 | openrouter | In: image, text, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $1.25, Out: $10.00, Cache Read: $0.12 |
| openai/gpt-5.1-codex | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $1.25, Out: $10.00, Cache Read: $0.13 |
| openai/gpt-5.1-codex-max | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $1.25, Out: $10.00, Cache Read: $0.12 |
| openai/gpt-5.1-codex-mini | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $0.25, Out: $2.00, Cache Read: $0.03 |
| openai/gpt-5.2 | openrouter | In: pdf, image, text; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $1.75, Out: $14.00, Cache Read: $0.18 |
| openai/gpt-5.2-chat | openrouter | In: pdf, image, text; Out: text | function_calling, structured_output, vision, streaming | 128000 | 32000 | In: $1.75, Out: $14.00, Cache Read: $0.18 |
| openai/gpt-5.2-codex | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $1.75, Out: $14.00, Cache Read: $0.18 |
| openai/gpt-5.2-pro | openrouter | In: image, text, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $21.00, Out: $168.00 |
| openai/gpt-5.3-codex | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $1.75, Out: $14.00, Cache Read: $0.18 |
| openai/gpt-5.4 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1050000 | 128000 | In: $2.50, Out: $15.00, Cache Read: $0.25 |
| openai/gpt-5.4-image-2 | openrouter | In: image, text, pdf; Out: image, text | structured_output, reasoning, vision, streaming, image_generation | 272000 | 128000 | In: $8.00, Out: $15.00, Cache Read: $2.00 |
| openai/gpt-5.4-pro | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1050000 | 128000 | In: $30.00, Out: $180.00 |
| openai/gpt-5.4-mini | openrouter | In: pdf, image, text; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $0.75, Out: $4.50, Cache Read: $0.08 |
| openai/gpt-5.4-nano | openrouter | In: pdf, image, text; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $0.20, Out: $1.25, Cache Read: $0.02 |
| openai/gpt-5.5 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1050000 | 128000 | In: $5.00, Out: $30.00, Cache Read: $0.50 |
| openai/gpt-5.5-pro | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1050000 | 128000 | In: $30.00, Out: $180.00 |
| openai/gpt-5.6-luna | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1050000 | 128000 | In: $0.20, Out: $1.20, Cache Read: $0.02, Cache Write: $0.25 |
| openai/gpt-5.6-luna-pro | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1050000 | 128000 | In: $0.20, Out: $1.20, Cache Read: $0.02, Cache Write: $0.25 |
| openai/gpt-5.6-sol | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1050000 | 128000 | In: $2.50, Out: $15.00, Cache Read: $0.25, Cache Write: $3.12 |
| openai/gpt-5.6-sol-pro | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1050000 | 128000 | In: $2.50, Out: $15.00, Cache Read: $0.25, Cache Write: $3.12 |
| openai/gpt-5.6-terra | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1050000 | 128000 | In: $2.00, Out: $12.00, Cache Read: $0.20, Cache Write: $2.50 |
| openai/gpt-5.6-terra-pro | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1050000 | 128000 | In: $2.00, Out: $12.00, Cache Read: $0.20, Cache Write: $2.50 |
| google/gemini-2.5-flash | openrouter | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1048576 | 65535 | In: $0.30, Out: $2.50, Cache Read: $0.03, Cache Write: $0.08 |
| google/gemini-2.5-flash-lite | openrouter | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1048576 | 65535 | In: $0.10, Out: $0.40, Cache Read: $0.01, Cache Write: $0.08 |
| google/gemini-2.5-pro | openrouter | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1048576 | 65536 | In: $1.25, Out: $10.00, Cache Read: $0.12, Cache Write: $0.38 |
| google/gemini-2.5-pro-preview-05-06 | openrouter | In: text, image, pdf, audio, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1048576 | 65535 | In: $1.25, Out: $10.00, Cache Read: $0.12, Cache Write: $0.38 |
| google/gemini-2.5-pro-preview | openrouter | In: pdf, image, text, audio; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1048576 | 65536 | In: $1.25, Out: $10.00, Cache Read: $0.12, Cache Write: $0.38 |
| google/gemini-3-flash-preview | openrouter | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1048576 | 65536 | In: $0.50, Out: $3.00, Cache Read: $0.05, Cache Write: $0.08 |
| google/gemini-3.1-flash-lite | openrouter | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1048576 | 65536 | In: $0.25, Out: $1.50, Cache Read: $0.02, Cache Write: $0.08 |
| google/gemini-3.1-flash-lite-preview | openrouter | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1048576 | 65536 | In: $0.25, Out: $1.50, Cache Read: $0.02, Cache Write: $0.08 |
| google/gemini-3.1-pro-preview | openrouter | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1048576 | 65536 | In: $2.00, Out: $12.00, Cache Read: $0.20, Cache Write: $0.38 |
| google/gemini-3.1-pro-preview-customtools | openrouter | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1048576 | 65536 | In: $2.00, Out: $12.00, Cache Read: $0.20, Cache Write: $0.38 |
| google/gemini-3.5-flash | openrouter | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1048576 | 65536 | In: $1.50, Out: $9.00, Cache Read: $0.15, Cache Write: $0.08 |
| google/gemini-3.5-flash-lite | openrouter | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1048576 | 65536 | In: $0.30, Out: $2.50, Cache Read: $0.03, Cache Write: $0.08 |
| google/gemini-3.6-flash | openrouter | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1048576 | 65536 | In: $0.75, Out: $3.75, Cache Read: $0.08, Cache Write: $0.04 |
| google/gemini-3.7-flash | openrouter | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1048576 | 65536 | In: $0.38, Out: $1.88, Cache Read: $0.04, Cache Write: $0.02 |
| google/gemma-2-27b-it | openrouter | In: text; Out: text | structured_output, streaming | 8192 | 2048 | In: $0.65, Out: $0.65 |
| google/gemma-3-12b-it | openrouter | In: text, image; Out: text | function_calling, structured_output, vision, streaming, predicted_outputs | 131072 | 16384 | In: $0.05, Out: $0.15 |
| google/gemma-3-27b-it | openrouter | In: text, image; Out: text | function_calling, structured_output, vision, streaming, predicted_outputs | 262144 | 131072 | In: $0.08, Out: $0.45, Cache Read: $0.04 |
| google/gemma-3-4b-it | openrouter | In: text, image; Out: text | structured_output, vision, streaming, predicted_outputs | 131072 | 16384 | In: $0.05, Out: $0.10 |
| google/gemma-3n-e4b-it | openrouter | In: text; Out: text | structured_output, streaming, predicted_outputs | 32768 | 32768 | In: $0.06, Out: $0.12 |
| google/gemma-4-26b-a4b-it:free | openrouter | In: image, text, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 262144 | 32768 | In: $0.00, Out: $0.00 |
| google/gemma-4-26b-a4b-it | openrouter | In: image, text, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming, predicted_outputs | 262144 | 16384 | In: $0.07, Out: $0.34 |
| google/gemma-4-31b-it:free | openrouter | In: image, text, video; Out: text | function_calling, reasoning, vision, video, streaming | 262144 | 32768 | In: $0.00, Out: $0.00 |
| google/gemma-4-31b-it | openrouter | In: image, text, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming, predicted_outputs | 262144 | 16384 | In: $0.09, Out: $0.34, Cache Read: $0.05 |
| ~google/gemini-flash-latest | openrouter | In: text, image, video, pdf, audio; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1048576 | 65536 | In: $0.38, Out: $1.88, Cache Read: $0.04, Cache Write: $0.02 |
| ~google/gemini-pro-latest | openrouter | In: audio, pdf, image, text, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1048576 | 65536 | In: $2.00, Out: $12.00, Cache Read: $0.20, Cache Write: $0.38 |
| google/chirp-3 | openrouter | In: audio; Out: text | streaming, structured_output, transcription | 0 | - | In: $16000.00 |
| google/gemini-2.5-flash:batch | openrouter | In: file, image, text, audio, video; Out: text | streaming, function_calling, structured_output | 1048576 | 65535 | In: $0.15, Out: $1.25, Cache Read: $0.03 |
| google/gemini-2.5-flash-lite:batch | openrouter | In: text, image, file, audio, video; Out: text | streaming, function_calling, structured_output | 1048576 | 65535 | In: $0.05, Out: $0.20, Cache Read: $0.01 |
| google/gemini-2.5-pro:batch | openrouter | In: text, image, file, audio, video; Out: text | streaming, function_calling, structured_output | 1048576 | 65536 | In: $0.62, Out: $5.00, Cache Read: $0.12 |
| google/gemini-3-flash-preview:batch | openrouter | In: text, image, file, audio, video; Out: text | streaming, function_calling, structured_output | 1048576 | 65536 | In: $0.25, Out: $1.50 |
| google/gemini-3.1-flash-lite:batch | openrouter | In: text, image, video, file, audio; Out: text | streaming, function_calling, structured_output | 1048576 | 65536 | In: $0.12, Out: $0.75, Cache Read: $0.01 |
| google/gemini-3.1-flash-tts-preview | openrouter | In: text; Out: audio | streaming, structured_output, speech_generation | 32768 | 16384 | In: $1.00, Out: $20.00 |
| google/gemini-3.1-pro-preview:batch | openrouter | In: audio, file, image, text, video; Out: text | streaming, function_calling, structured_output | 1048576 | 65536 | In: $1.00, Out: $6.00 |
| google/gemini-3.5-flash:batch | openrouter | In: text, image, video, file, audio; Out: text | streaming, function_calling, structured_output | 1048576 | 65536 | In: $0.75, Out: $4.50, Cache Read: $0.08 |
| google/gemini-3.5-flash-lite:batch | openrouter | In: text, image, video, file, audio; Out: text | streaming, function_calling, structured_output | 1048576 | 65536 | In: $0.15, Out: $1.25, Cache Read: $0.02 |
| google/gemini-3.6-flash:batch | openrouter | In: text, image, video, file, audio; Out: text | streaming, function_calling, structured_output | 1048576 | 65536 | In: $0.38, Out: $1.88, Cache Read: $0.04, Cache Write: $0.04 |
| google/gemini-3.7-flash:batch | openrouter | In: text, image, video, file, audio; Out: text | streaming, function_calling, structured_output | 1048576 | 65536 | In: $0.19, Out: $0.94, Cache Read: $0.02, Cache Write: $0.02 |
| google/gemini-embedding-001 | openrouter | In: text; Out: embeddings | streaming, structured_output | 20000 | - | In: $0.15 |
| google/gemini-embedding-2 | openrouter | In: text, image, file, audio, video; Out: embeddings | streaming, structured_output | 8192 | - | In: $0.20 |
| google/gemini-embedding-2-preview | openrouter | In: text, image, file, audio, video; Out: embeddings | streaming, structured_output | 8192 | - | In: $0.20 |
| ibm-granite/granite-4.0-h-micro | openrouter | In: text; Out: text | streaming, predicted_outputs | 131000 | 131000 | In: $0.02, Out: $0.11 |
| ibm-granite/granite-4.1-8b | openrouter | In: text; Out: text | function_calling, structured_output, streaming | 131072 | 131072 | In: $0.05, Out: $0.10, Cache Read: $0.05 |
| x-ai/grok-4.20 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 2000000 | 2000000 | In: $1.25, Out: $2.50, Cache Read: $0.20 |
| x-ai/grok-4.20-multi-agent | openrouter | In: text, image, pdf; Out: text | structured_output, reasoning, vision, streaming | 2000000 | 2000000 | In: $1.25, Out: $2.50, Cache Read: $0.20 |
| x-ai/grok-4.3 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 1000000 | In: $1.25, Out: $2.50, Cache Read: $0.20 |
| x-ai/grok-4.5 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 500000 | 500000 | In: $2.00, Out: $6.00, Cache Read: $0.30 |
| x-ai/grok-4.6 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 500000 | 500000 | In: $2.00, Out: $6.00, Cache Read: $0.50 |
| x-ai/grok-build-0.1 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 256000 | 256000 | In: $1.00, Out: $2.00, Cache Read: $0.20 |
| ~x-ai/grok-latest | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 500000 | 1000000 | In: $2.00, Out: $6.00, Cache Read: $0.50 |
| nousresearch/hermes-3-llama-3.1-405b | openrouter | In: text; Out: text | structured_output, streaming, predicted_outputs | 131072 | 16384 | In: $1.00, Out: $1.00 |
| nousresearch/hermes-3-llama-3.1-70b | openrouter | In: text; Out: text | structured_output, streaming, predicted_outputs | 131072 | 16384 | In: $0.70, Out: $0.70 |
| nousresearch/hermes-4-405b | openrouter | In: text; Out: text | reasoning, streaming | 131072 | 131072 | In: $1.00, Out: $3.00 |
| nousresearch/hermes-4-70b | openrouter | In: text; Out: text | reasoning, streaming | 131072 | 131072 | In: $0.13, Out: $0.40 |
| tencent/hunyuan-a13b-instruct | openrouter | In: text; Out: text | structured_output, reasoning, streaming | 131072 | 131072 | In: $0.14, Out: $0.57 |
| tencent/hy3 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 262144 | 128000 | In: $0.13, Out: $0.53, Cache Read: $0.03 |
| tencent/hy3-preview | openrouter | In: text; Out: text | function_calling, reasoning, streaming | 262144 | 262144 | In: $0.18, Out: $0.60, Cache Read: $0.06 |
| thinkingmachines/inkling | openrouter | In: text, image, audio; Out: text | function_calling, reasoning, vision, streaming, predicted_outputs | 1048576 | 262144 | In: $0.95, Out: $4.05, Cache Read: $0.16 |
| thinkingmachines/inkling-small | openrouter | In: text, image, audio; Out: text | function_calling, structured_output, reasoning, vision, streaming, predicted_outputs | 524288 | 262144 | In: $0.45, Out: $1.20, Cache Read: $0.10 |
| intfloat/e5-base-v2 | openrouter | In: text; Out: embeddings | streaming, structured_output | 512 | - | In: $0.01 |
| intfloat/e5-large-v2 | openrouter | In: text; Out: embeddings | streaming, structured_output | 512 | - | In: $0.01 |
| intfloat/multilingual-e5-large | openrouter | In: text; Out: embeddings | streaming, structured_output | 512 | - | In: $0.01 |
| kwaipilot/kat-coder-air-v2.5 | openrouter | In: text; Out: text | function_calling, structured_output, streaming | 256000 | 80000 | In: $0.15, Out: $0.60, Cache Read: $0.03 |
| kwaipilot/kat-coder-pro-v2 | openrouter | In: text; Out: text | function_calling, structured_output, streaming, predicted_outputs | 262144 | 80000 | In: $0.30, Out: $1.20, Cache Read: $0.06 |
| kwaipilot/kat-coder-pro-v2.5 | openrouter | In: text; Out: text | function_calling, structured_output, streaming | 256000 | 80000 | In: $0.74, Out: $2.96, Cache Read: $0.15 |
| moonshotai/kimi-k2 | openrouter | In: text; Out: text | function_calling, streaming | 131072 | 100352 | In: $0.57, Out: $2.30 |
| moonshotai/kimi-k2-0905 | openrouter | In: text; Out: text | function_calling, structured_output, streaming | 262144 | 100352 | In: $0.60, Out: $2.50 |
| moonshotai/kimi-k2-thinking | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 262144 | 100352 | In: $0.60, Out: $2.50, Cache Read: $0.15 |
| moonshotai/kimi-k2.5 | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming, predicted_outputs | 262144 | 262144 | In: $0.45, Out: $2.25, Cache Read: $0.07 |
| moonshotai/kimi-k2.6 | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming, predicted_outputs | 262144 | 262144 | In: $0.95, Out: $4.00, Cache Read: $0.16 |
| moonshotai/kimi-k2.7-code | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming, predicted_outputs | 262144 | 262144 | In: $0.71, Out: $3.50, Cache Read: $0.15 |
| moonshotai/kimi-k3 | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming, predicted_outputs | 1048576 | 1048576 | In: $3.00, Out: $15.00, Cache Read: $0.30 |
| krea/krea-2-large | openrouter | In: text, image; Out: image | streaming, image_generation | - | - | - |
| krea/krea-2-medium | openrouter | In: text, image; Out: image | streaming, image_generation | - | - | - |
| krea/krea-2-medium-turbo | openrouter | In: text, image; Out: image | streaming, image_generation | - | - | - |
| liquid/lfm-2.5-2.6b:free | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 128000 | 8192 | In: $0.00, Out: $0.00 |
| poolside/laguna-s-2.1 | openrouter | In: text; Out: text | function_calling, reasoning, streaming | 1048576 | 131072 | In: $0.09, Out: $0.18, Cache Read: $0.01 |
| poolside/laguna-s-2.1:free | openrouter | In: text; Out: text | function_calling, reasoning, streaming | 262144 | 32768 | In: $0.00, Out: $0.00 |
| poolside/laguna-xs-2.1 | openrouter | In: text; Out: text | function_calling, reasoning, streaming | 262144 | 32768 | In: $0.06, Out: $0.12, Cache Read: $0.03 |
| poolside/laguna-xs-2.1:free | openrouter | In: text; Out: text | function_calling, reasoning, streaming | 262144 | 32768 | In: $0.00, Out: $0.00 |
| inclusionai/ling-2.6-1t | openrouter | In: text; Out: text | function_calling, structured_output, streaming | 262144 | 32768 | In: $0.08, Out: $0.62, Cache Read: $0.02 |
| inclusionai/ling-2.6-flash | openrouter | In: text; Out: text | function_calling, structured_output, streaming | 262144 | 32768 | In: $0.01, Out: $0.03, Cache Read: $0.00 |
| inclusionai/ling-3.0-flash | openrouter | In: text; Out: text | function_calling, reasoning, streaming, predicted_outputs | 262144 | 32768 | In: $0.02, Out: $0.06, Cache Read: $0.00 |
| liquid/lfm-2.5-embedding-350m:free | openrouter | In: text; Out: embeddings | streaming | 512 | - | - |
| sao10k/l3-lunaris-8b | openrouter | In: text; Out: text | structured_output, streaming, predicted_outputs | 8192 | 16384 | In: $0.04, Out: $0.05 |
| meta-llama/llama-3.1-70b-instruct | openrouter | In: text; Out: text | function_calling, structured_output, streaming, predicted_outputs | 131072 | 16384 | In: $0.40, Out: $0.40 |
| sao10k/l3.1-euryale-70b | openrouter | In: text; Out: text | function_calling, structured_output, streaming, predicted_outputs | 131072 | 16384 | In: $0.85, Out: $0.85 |
| meta-llama/llama-3.2-1b-instruct | openrouter | In: text; Out: text | streaming, predicted_outputs | 60000 | 60000 | In: $0.03, Out: $0.20 |
| meta-llama/llama-3.2-3b-instruct | openrouter | In: text; Out: text | structured_output, streaming, predicted_outputs | 131072 | 131072 | In: $0.05, Out: $0.33 |
| sao10k/l3.3-euryale-70b | openrouter | In: text; Out: text | structured_output, streaming | 131072 | 16384 | In: $0.65, Out: $0.75 |
| meta-llama/llama-4-maverick | openrouter | In: text, image; Out: text | function_calling, structured_output, vision, streaming, predicted_outputs | 1048576 | 16384 | In: $0.20, Out: $0.80 |
| meta-llama/llama-4-scout | openrouter | In: text, image; Out: text | function_calling, structured_output, vision, streaming, predicted_outputs | 1310720 | 16384 | In: $0.10, Out: $0.30 |
| meta-llama/llama-guard-4-12b | openrouter | In: image, text; Out: text | vision, streaming, predicted_outputs | 1048576 | 16384 | In: $0.18, Out: $0.18 |
| meta-llama/llama-3.1-8b-instruct | openrouter | In: text; Out: text | function_calling, structured_output, streaming, predicted_outputs | 131072 | 131072 | In: $0.05, Out: $0.08, Cache Read: $0.02 |
| meta-llama/llama-3.3-70b-instruct | openrouter | In: text; Out: text | function_calling, structured_output, streaming, predicted_outputs | 131072 | 16384 | In: $0.10, Out: $0.32 |
| meituan/longcat-2.0 | openrouter | In: text; Out: text | function_calling, reasoning, streaming, predicted_outputs | 1048756 | 262144 | In: $0.30, Out: $1.20, Cache Read: $0.01 |
| google/lyria-3-clip-preview | openrouter | In: text, image; Out: text, audio | vision, streaming | 1048576 | 65536 | In: $0.00, Out: $0.00 |
| google/lyria-3-pro-preview | openrouter | In: text, image; Out: text, audio | vision, streaming | 1048576 | 65536 | In: $0.00, Out: $0.00 |
| anthracite-org/magnum-v4-72b | openrouter | In: text; Out: text | structured_output, streaming, predicted_outputs | 32768 | 4096 | In: $3.00, Out: $5.00 |
| inception/mercury-2 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 128000 | 50000 | In: $0.25, Out: $0.75, Cache Read: $0.02 |
| xiaomi/mimo-v2.5 | openrouter | In: text, image, audio, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming, predicted_outputs | 1050000 | 131072 | In: $0.14, Out: $0.28, Cache Read: $0.00 |
| xiaomi/mimo-v2.5-pro | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 1050000 | 131072 | In: $0.44, Out: $0.87, Cache Read: $0.00 |
| microsoft/mai-image-2.5 | openrouter | In: text, image; Out: image | streaming, image_generation | - | - | - |
| microsoft/mai-image-2.5-pro | openrouter | In: text, image; Out: image | streaming, image_generation | - | - | - |
| microsoft/mai-transcribe-1.5 | openrouter | In: audio; Out: text | streaming, transcription | 0 | - | In: $360000.00 |
| microsoft/mai-voice-2 | openrouter | In: text; Out: audio | streaming, speech_generation | 0 | - | In: $22.00 |
| microsoft/mai-voice-2-flash | openrouter | In: text; Out: audio | streaming, speech_generation | 0 | - | In: $15.00 |
| minimax/minimax-m1 | openrouter | In: text; Out: text | function_calling, reasoning, streaming | 1000000 | 40000 | In: $0.55, Out: $2.20 |
| minimax/minimax-01 | openrouter | In: text, image; Out: text | vision, streaming | 1000192 | 1000192 | In: $0.20, Out: $1.10 |
| minimax/minimax-m2 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 204800 | 131072 | In: $0.26, Out: $1.02 |
| minimax/minimax-m2-her | openrouter | In: text; Out: text | streaming | 65536 | 2048 | In: $0.30, Out: $1.20, Cache Read: $0.03 |
| minimax/minimax-m2.1 | openrouter | In: text; Out: text | function_calling, reasoning, streaming | 204800 | 131072 | In: $0.30, Out: $1.20, Cache Read: $0.03 |
| minimax/minimax-m2.5 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 204800 | 196608 | In: $0.22, Out: $0.90, Cache Read: $0.06 |
| minimax/minimax-m2.7 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 204800 | 131072 | In: $0.30, Out: $1.20, Cache Read: $0.06 |
| minimax/minimax-m3 | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming, predicted_outputs | 1048576 | 512000 | In: $0.30, Out: $1.20, Cache Read: $0.06 |
| minimax/minimax-m3:batch | openrouter | In: text, image, video; Out: text | streaming, function_calling, structured_output, predicted_outputs | 524288 | - | In: $0.30, Out: $1.20, Cache Read: $0.06 |
| minimax/speech-2.8-hd | openrouter | In: text; Out: audio | streaming, speech_generation | 0 | - | In: $100.00 |
| minimax/speech-2.8-turbo | openrouter | In: text; Out: audio | streaming, speech_generation | 0 | - | In: $60.00 |
| mistralai/ministral-14b-2512 | openrouter | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 262144 | 262144 | In: $0.20, Out: $0.20, Cache Read: $0.02 |
| mistralai/ministral-3b-2512 | openrouter | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 131072 | 131072 | In: $0.10, Out: $0.10, Cache Read: $0.01 |
| mistralai/ministral-8b-2512 | openrouter | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 262144 | 262144 | In: $0.15, Out: $0.15, Cache Read: $0.02 |
| mistralai/mistral-large | openrouter | In: text, pdf; Out: text | function_calling, structured_output, vision, streaming | 128000 | 128000 | In: $2.00, Out: $6.00, Cache Read: $0.20 |
| mistralai/mistral-large-2407 | openrouter | In: text, pdf; Out: text | function_calling, structured_output, vision, streaming | 131072 | 131072 | In: $2.00, Out: $6.00, Cache Read: $0.20 |
| mistralai/mistral-large-2512 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, vision, streaming | 262144 | 262144 | In: $0.50, Out: $1.50, Cache Read: $0.05 |
| mistralai/mistral-medium-3 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, vision, streaming | 131072 | 131072 | In: $0.40, Out: $2.00, Cache Read: $0.04 |
| mistralai/mistral-medium-3.1 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, vision, streaming | 131072 | 262144 | In: $0.40, Out: $2.00, Cache Read: $0.04 |
| mistralai/mistral-medium-3-5 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 262144 | 262144 | In: $1.50, Out: $7.50 |
| mistralai/mistral-nemo | openrouter | In: text; Out: text | function_calling, structured_output, streaming, predicted_outputs | 131072 | 16384 | In: $0.02, Out: $0.03 |
| mistralai/mistral-small-24b-instruct-2501 | openrouter | In: text; Out: text | structured_output, streaming, predicted_outputs | 32768 | 16384 | In: $0.05, Out: $0.08 |
| mistralai/mistral-small-3.1-24b-instruct | openrouter | In: text, image; Out: text | vision, streaming, predicted_outputs | 128000 | 128000 | In: $0.35, Out: $0.56 |
| mistralai/mistral-small-3.2-24b-instruct | openrouter | In: image, text; Out: text | function_calling, structured_output, vision, streaming, predicted_outputs | 256000 | 16384 | In: $0.09, Out: $0.25 |
| mistralai/mistral-small-2603 | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 262144 | 262144 | In: $0.15, Out: $0.60, Cache Read: $0.02 |
| mistralai/codestral-embed-2505 | openrouter | In: text; Out: embeddings | streaming, structured_output | 8192 | - | In: $0.15 |
| mistralai/mistral-embed-2312 | openrouter | In: text; Out: embeddings | streaming, structured_output | 8192 | - | In: $0.10 |
| mistralai/voxtral-mini-3b-2507 | openrouter | In: audio; Out: text | streaming, structured_output, transcription | 0 | - | In: $16.67 |
| mistralai/voxtral-mini-tts-2603 | openrouter | In: text; Out: audio | streaming, structured_output, speech_generation | 4096 | - | In: $16.00 |
| mistralai/voxtral-mini-transcribe | openrouter | In: audio; Out: text | streaming, structured_output, transcription | 0 | - | In: $3000.00 |
| mistralai/voxtral-small-24b-2507-stt | openrouter | In: audio; Out: text | streaming, structured_output, transcription | 0 | - | In: $50.00 |
| mistralai/mixtral-8x22b-instruct | openrouter | In: text, pdf; Out: text | function_calling, structured_output, vision, streaming | 65536 | 65536 | In: $2.00, Out: $6.00, Cache Read: $0.20 |
| ~moonshotai/kimi-latest | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming, predicted_outputs | 1048576 | 974842 | In: $2.60, Out: $13.00, Cache Read: $0.29 |
| moonshotai/kimi-k2.7-code:batch | openrouter | In: text, image; Out: text | streaming, function_calling, structured_output, predicted_outputs | 262144 | - | In: $0.95, Out: $4.00, Cache Read: $0.19 |
| morph/morph-v3-fast | openrouter | In: text; Out: text | streaming | 81920 | 38000 | In: $0.80, Out: $1.20 |
| morph/morph-v3-large | openrouter | In: text; Out: text | structured_output, streaming | 262144 | 131072 | In: $0.90, Out: $1.90 |
| meta/muse-glimmer-30b | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming, predicted_outputs | 131072 | 131072 | In: $0.35, Out: $1.50, Cache Read: $0.04 |
| meta/muse-spark-1.1 | openrouter | In: text, image, video, pdf, audio; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1048576 | 1048576 | In: $1.25, Out: $4.25, Cache Read: $0.15 |
| meta/muse-spark-1.2 | openrouter | In: text, image, video, pdf, audio; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1048576 | 1048576 | In: $1.25, Out: $4.25, Cache Read: $0.15 |
| gryphe/mythomax-l2-13b | openrouter | In: text; Out: text | structured_output, streaming, predicted_outputs | 8192 | 4096 | In: $0.06, Out: $0.06 |
| nvidia/llama-nemotron-embed-vl-1b-v2:free | openrouter | In: text, image; Out: embeddings | streaming | 131072 | - | - |
| nvidia/llama-nemotron-rerank-vl-1b-v2:free | openrouter | In: text, image; Out: rerank | streaming | 10240 | - | - |
| nvidia/nemotron-3-embed-1b:free | openrouter | In: text; Out: embeddings | streaming | 32768 | - | - |
| nvidia/nemotron-3-ultra-550b-a55b:batch | openrouter | In: text; Out: text | streaming, function_calling, structured_output, predicted_outputs | 512288 | - | In: $0.60, Out: $3.60, Cache Read: $0.20 |
| nvidia/nemotron-3.5-asr-streaming-multilingual-0.6b | openrouter | In: audio; Out: text | streaming, structured_output, transcription | 0 | - | In: $3.33 |
| nvidia/parakeet-tdt-0.6b-v3 | openrouter | In: audio; Out: text | streaming, predicted_outputs, transcription | 0 | - | In: $1500.00 |
| google/gemini-2.5-flash-image | openrouter | In: text, image; Out: text, image | structured_output, vision, streaming, image_generation | 32768 | 8192 | In: $0.30, Out: $2.50, Cache Read: $0.03, Cache Write: $0.08 |
| google/gemini-3.1-flash-image | openrouter | In: image, text; Out: text, image | structured_output, reasoning, vision, streaming, image_generation | 131072 | 32768 | In: $0.50, Out: $3.00 |
| google/gemini-3.1-flash-image-preview | openrouter | In: image, text; Out: text, image | structured_output, reasoning, vision, streaming, image_generation | 65536 | 65536 | In: $0.50, Out: $3.00 |
| google/gemini-3.1-flash-lite-image | openrouter | In: text, image; Out: text, image | reasoning, vision, streaming, image_generation | 65536 | 65536 | In: $0.25, Out: $1.50 |
| google/gemini-3-pro-image | openrouter | In: text, image; Out: text, image | function_calling, structured_output, reasoning, vision, streaming, image_generation | 131072 | 32768 | In: $2.00, Out: $12.00, Cache Read: $0.20, Cache Write: $0.38 |
| google/gemini-3-pro-image-preview | openrouter | In: text, image; Out: text, image | structured_output, reasoning, vision, streaming, image_generation | 65536 | 32768 | In: $2.00, Out: $12.00, Cache Read: $0.20, Cache Write: $0.38 |
| nvidia/nemotron-3-nano-30b-a3b | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 262144 | 262144 | In: $0.05, Out: $0.20, Cache Read: $0.03 |
| nvidia/nemotron-3-nano-30b-a3b:free | openrouter | In: text; Out: text | function_calling, reasoning, streaming | 256000 | 256000 | In: $0.00, Out: $0.00 |
| nvidia/nemotron-3-nano-omni-30b-a3b-reasoning:free | openrouter | In: text, image, video, audio; Out: text | function_calling, reasoning, vision, video, streaming | 256000 | 65536 | In: $0.00, Out: $0.00 |
| nvidia/nemotron-3-super-120b-a12b:free | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 262144 | 262144 | In: $0.00, Out: $0.00 |
| nvidia/nemotron-3-super-120b-a12b | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 1000000 | 16384 | In: $0.08, Out: $0.40 |
| nvidia/nemotron-3-ultra-550b-a55b:free | openrouter | In: text; Out: text | function_calling, reasoning, streaming | 1000000 | 65536 | In: $0.00, Out: $0.00 |
| nvidia/nemotron-3-ultra-550b-a55b | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 512288 | 16384 | In: $0.60, Out: $3.60, Cache Read: $0.20 |
| nvidia/nemotron-3.5-content-safety:free | openrouter | In: text, image; Out: text | reasoning, vision, streaming | 128000 | 8192 | In: $0.00, Out: $0.00 |
| nvidia/nemotron-3.5-lightning:free | openrouter | In: text; Out: text | function_calling, reasoning, streaming | 1000000 | 65536 | In: $0.00, Out: $0.00 |
| nvidia/nemotron-3.5-lightning | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 1000000 | 131072 | In: $0.08, Out: $0.20, Cache Read: $0.04 |
| nvidia/nemotron-nano-12b-v2-vl:free | openrouter | In: text, image, video; Out: text | function_calling, reasoning, vision, video, streaming | 128000 | 128000 | In: $0.00, Out: $0.00 |
| nvidia/nemotron-nano-9b-v2:free | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 128000 | 128000 | In: $0.00, Out: $0.00 |
| nex-agi/nex-n2-mini | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 262144 | 262144 | In: $0.02, Out: $0.10, Cache Read: $0.00 |
| nex-agi/nex-n2-pro | openrouter | In: text, image; Out: text | function_calling, reasoning, vision, streaming | 262144 | 262144 | In: $0.25, Out: $1.00, Cache Read: $0.02 |
| cohere/north-mini-code:free | openrouter | In: text; Out: text | function_calling, reasoning, streaming | 256000 | 64000 | In: $0.00, Out: $0.00 |
| amazon/nova-2-lite-v1 | openrouter | In: text, image, video, pdf; Out: text | function_calling, reasoning, vision, video, streaming | 1000000 | 65535 | In: $0.30, Out: $2.50 |
| amazon/nova-lite-v1 | openrouter | In: text, image; Out: text | function_calling, vision, streaming | 300000 | 5120 | In: $0.06, Out: $0.24 |
| amazon/nova-micro-v1 | openrouter | In: text; Out: text | function_calling, streaming | 128000 | 5120 | In: $0.04, Out: $0.14 |
| amazon/nova-premier-v1 | openrouter | In: text, image; Out: text | function_calling, vision, streaming | 1000000 | 32000 | In: $2.50, Out: $12.50, Cache Read: $0.62 |
| amazon/nova-pro-v1 | openrouter | In: text, image; Out: text | function_calling, vision, streaming | 300000 | 5120 | In: $0.80, Out: $3.20 |
| allenai/olmo-3-32b-think | openrouter | In: text; Out: text | structured_output, reasoning, streaming, predicted_outputs | 65536 | 65536 | In: $0.15, Out: $0.50 |
| ~openai/gpt-latest | openrouter | In: pdf, image, text; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1050000 | 128000 | In: $2.50, Out: $15.00, Cache Read: $0.25, Cache Write: $3.12 |
| ~openai/gpt-mini-latest | openrouter | In: pdf, image, text; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $0.75, Out: $4.50, Cache Read: $0.08 |
| openai/gpt-image-1 | openrouter | In: text, image; Out: image | streaming, image_generation | - | - | - |
| openai/gpt-image-1-mini | openrouter | In: text, image; Out: image | streaming, image_generation | - | - | - |
| openai/gpt-image-2 | openrouter | In: text, image; Out: image | streaming, image_generation | - | - | - |
| openai/gpt-transcribe | openrouter | In: audio; Out: text | streaming, structured_output, transcription | 0 | - | In: $4500.00 |
| openai/gpt-3.5-turbo:batch | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 16385 | 4096 | In: $0.25, Out: $0.75 |
| openai/gpt-4-turbo:batch | openrouter | In: text, image; Out: text | streaming, function_calling, structured_output | 128000 | 4096 | In: $5.00, Out: $15.00 |
| openai/gpt-4.1:batch | openrouter | In: image, text, file; Out: text | streaming, function_calling, structured_output | 1047576 | 32768 | In: $1.00, Out: $4.00, Cache Read: $0.25 |
| openai/gpt-4.1-mini:batch | openrouter | In: image, text, file; Out: text | streaming, function_calling, structured_output | 1047576 | 32768 | In: $0.20, Out: $0.80, Cache Read: $0.05 |
| openai/gpt-4.1-nano:batch | openrouter | In: image, text, file; Out: text | streaming, function_calling, structured_output | 1047576 | 32768 | In: $0.05, Out: $0.20, Cache Read: $0.01 |
| openai/gpt-4o:batch | openrouter | In: text, image, file; Out: text | streaming, function_calling, structured_output | 128000 | 16384 | In: $1.25, Out: $5.00, Cache Read: $0.62 |
| openai/gpt-4o-mini-transcribe | openrouter | In: audio; Out: text | streaming, structured_output, transcription | 128000 | - | In: $1.25, Out: $5.00 |
| openai/gpt-4o-transcribe | openrouter | In: audio; Out: text | streaming, structured_output, transcription | 128000 | - | In: $2.50, Out: $10.00 |
| openai/gpt-4o-mini:batch | openrouter | In: text, image, file; Out: text | streaming, function_calling, structured_output | 128000 | 16384 | In: $0.08, Out: $0.30, Cache Read: $0.04 |
| openai/gpt-5:batch | openrouter | In: text, image, file; Out: text | streaming, function_calling, structured_output | 400000 | 128000 | In: $0.62, Out: $5.00, Cache Read: $0.06 |
| openai/gpt-5-codex:batch | openrouter | In: text, image; Out: text | streaming, function_calling, structured_output | 400000 | 128000 | In: $0.62, Out: $5.00, Cache Read: $0.06 |
| openai/gpt-5-mini:batch | openrouter | In: text, image, file; Out: text | streaming, function_calling, structured_output | 400000 | 128000 | In: $0.12, Out: $1.00, Cache Read: $0.01 |
| openai/gpt-5-nano:batch | openrouter | In: text, image, file; Out: text | streaming, function_calling, structured_output | 400000 | 128000 | In: $0.02, Out: $0.20, Cache Read: $0.00 |
| openai/gpt-5-pro:batch | openrouter | In: image, text, file; Out: text | streaming, function_calling, structured_output | 400000 | 128000 | In: $7.50, Out: $60.00 |
| openai/gpt-5.1:batch | openrouter | In: image, text, file; Out: text | streaming, function_calling, structured_output | 400000 | 128000 | In: $0.62, Out: $5.00, Cache Read: $0.06 |
| openai/gpt-5.2:batch | openrouter | In: file, image, text; Out: text | streaming, function_calling, structured_output | 400000 | 128000 | In: $0.88, Out: $7.00, Cache Read: $0.09 |
| openai/gpt-5.2-pro:batch | openrouter | In: image, text, file; Out: text | streaming, function_calling, structured_output | 400000 | 128000 | In: $10.50, Out: $84.00 |
| openai/gpt-5.4:batch | openrouter | In: text, image, file; Out: text | streaming, function_calling, structured_output | 1050000 | 128000 | In: $1.25, Out: $7.50, Cache Read: $0.12 |
| openai/gpt-5.4-mini:batch | openrouter | In: file, image, text; Out: text | streaming, function_calling, structured_output | 400000 | 128000 | In: $0.38, Out: $2.25, Cache Read: $0.04 |
| openai/gpt-5.4-nano:batch | openrouter | In: file, image, text; Out: text | streaming, function_calling, structured_output | 400000 | 128000 | In: $0.10, Out: $0.62, Cache Read: $0.01 |
| openai/gpt-5.4-pro:batch | openrouter | In: text, image, file; Out: text | streaming, function_calling, structured_output | 1050000 | 128000 | In: $15.00, Out: $90.00 |
| openai/gpt-5.5:batch | openrouter | In: file, image, text; Out: text | streaming, function_calling, structured_output | 1050000 | 128000 | In: $2.50, Out: $15.00, Cache Read: $0.25 |
| openai/gpt-5.5-pro:batch | openrouter | In: file, image, text; Out: text | streaming, function_calling, structured_output | 1050000 | 128000 | In: $15.00, Out: $90.00 |
| openai/gpt-5.6-luna:batch | openrouter | In: file, image, text; Out: text | streaming, function_calling, structured_output | 1050000 | 128000 | In: $0.10, Out: $0.60, Cache Read: $0.01 |
| openai/gpt-5.6-luna-pro:batch | openrouter | In: file, image, text; Out: text | streaming, function_calling, structured_output | 1050000 | 128000 | In: $0.10, Out: $0.60, Cache Read: $0.01 |
| openai/gpt-5.6-sol:batch | openrouter | In: file, image, text; Out: text | streaming, function_calling, structured_output | 1050000 | 128000 | In: $1.25, Out: $7.50, Cache Read: $0.12 |
| openai/gpt-5.6-sol-pro:batch | openrouter | In: file, image, text; Out: text | streaming, function_calling, structured_output | 1050000 | 128000 | In: $1.25, Out: $7.50, Cache Read: $0.12 |
| openai/gpt-5.6-terra:batch | openrouter | In: file, image, text; Out: text | streaming, function_calling, structured_output | 1050000 | 128000 | In: $1.00, Out: $6.00, Cache Read: $0.10 |
| openai/gpt-5.6-terra-pro:batch | openrouter | In: file, image, text; Out: text | streaming, function_calling, structured_output | 1050000 | 128000 | In: $1.00, Out: $6.00, Cache Read: $0.10 |
| openai/text-embedding-3-large | openrouter | In: text; Out: embeddings | streaming, structured_output | 8192 | - | In: $0.13 |
| openai/text-embedding-3-small | openrouter | In: text; Out: embeddings | streaming, structured_output | 8192 | - | In: $0.02 |
| openai/text-embedding-ada-002 | openrouter | In: text; Out: embeddings | streaming, structured_output | 8192 | - | In: $0.10 |
| openai/whisper-1 | openrouter | In: audio; Out: text | streaming, structured_output, transcription | 0 | - | In: $6000.00 |
| openai/whisper-large-v3 | openrouter | In: audio; Out: text | streaming, structured_output, predicted_outputs, transcription | 0 | - | In: $7.50 |
| openai/whisper-large-v3-turbo | openrouter | In: audio; Out: text | streaming, structured_output, transcription | 0 | - | In: $3.33 |
| openai/o1:batch | openrouter | In: text, image, file; Out: text | streaming, function_calling, structured_output | 200000 | 100000 | In: $7.50, Out: $30.00, Cache Read: $3.75 |
| openai/o1-pro:batch | openrouter | In: text, image, file; Out: text | streaming, structured_output | 200000 | 100000 | In: $75.00, Out: $300.00 |
| openai/o3:batch | openrouter | In: image, text, file; Out: text | streaming, function_calling, structured_output | 200000 | 100000 | In: $1.00, Out: $4.00, Cache Read: $0.25 |
| openai/o3-mini:batch | openrouter | In: text, file; Out: text | streaming, function_calling, structured_output | 200000 | 100000 | In: $0.55, Out: $2.20, Cache Read: $0.28 |
| openai/o3-mini-high:batch | openrouter | In: text, file; Out: text | streaming, function_calling, structured_output | 200000 | 100000 | In: $0.55, Out: $2.20, Cache Read: $0.28 |
| openai/o3-pro:batch | openrouter | In: text, file, image; Out: text | streaming, function_calling, structured_output | 200000 | 100000 | In: $10.00, Out: $40.00 |
| openai/o4-mini:batch | openrouter | In: image, text, file; Out: text | streaming, function_calling, structured_output | 200000 | 100000 | In: $0.55, Out: $2.20, Cache Read: $0.14 |
| openai/o4-mini-high:batch | openrouter | In: image, text, file; Out: text | streaming, function_calling, structured_output | 200000 | 100000 | In: $0.55, Out: $2.20, Cache Read: $0.14 |
| writer/palmyra-x5 | openrouter | In: text; Out: text | streaming | 1040000 | 8192 | In: $0.60, Out: $6.00 |
| openrouter/pareto-code | openrouter | In: text; Out: text | streaming | 2000000 | 200000 | - |
| perceptron/perceptron-mk1 | openrouter | In: text, image, video; Out: text | structured_output, reasoning, vision, video, streaming | 32768 | 8192 | In: $0.15, Out: $1.50 |
| perplexity/pplx-embed-v1-0.6b | openrouter | In: text; Out: embeddings | streaming | 32000 | - | In: $0.00 |
| perplexity/pplx-embed-v1-4b | openrouter | In: text; Out: embeddings | streaming | 32000 | - | In: $0.03 |
| microsoft/phi-4 | openrouter | In: text; Out: text | structured_output, streaming, predicted_outputs | 16384 | 16384 | In: $0.07, Out: $0.14 |
| qwen/qwen-plus | openrouter | In: text; Out: text | function_calling, structured_output, streaming | 1000000 | 32768 | In: $0.26, Out: $0.78, Cache Read: $0.05, Cache Write: $0.32 |
| qwen/qwen-plus-2025-07-28 | openrouter | In: text; Out: text | function_calling, structured_output, streaming | 1000000 | 32768 | In: $0.26, Out: $0.78 |
| qwen/qwen-plus-2025-07-28:thinking | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 1000000 | 32768 | In: $0.26, Out: $0.78 |
| qwen/qwen-2.5-72b-instruct | openrouter | In: text; Out: text | function_calling, structured_output, streaming, predicted_outputs | 32768 | 16384 | In: $0.36, Out: $0.40 |
| qwen/qwen-2.5-7b-instruct | openrouter | In: text; Out: text | function_calling, structured_output, streaming, predicted_outputs | 32768 | 32768 | In: $0.10, Out: $0.20 |
| qwen/qwen-2.5-coder-32b-instruct | openrouter | In: text; Out: text | streaming, predicted_outputs | 32768 | 32768 | In: $0.66, Out: $1.00 |
| qwen/qwen2.5-vl-72b-instruct | openrouter | In: text, image; Out: text | structured_output, vision, streaming, predicted_outputs | 128000 | 128000 | In: $0.80, Out: $1.00, Cache Read: $0.40 |
| qwen/qwen3-14b | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 131072 | 16384 | In: $0.12, Out: $0.24 |
| qwen/qwen3-235b-a22b-2507 | openrouter | In: text; Out: text | function_calling, structured_output, streaming, predicted_outputs | 262144 | 16384 | In: $0.09, Out: $0.55 |
| qwen/qwen3-235b-a22b-thinking-2507 | openrouter | In: text; Out: text | function_calling, reasoning, streaming, predicted_outputs | 262144 | 32768 | In: $0.23, Out: $2.30 |
| qwen/qwen3-235b-a22b | openrouter | In: text; Out: text | function_calling, reasoning, streaming | 131072 | 8192 | In: $0.46, Out: $1.82 |
| qwen/qwen3-30b-a3b | openrouter | In: text; Out: text | function_calling, reasoning, streaming, predicted_outputs | 131072 | 8192 | In: $0.13, Out: $0.52 |
| qwen/qwen3-30b-a3b-instruct-2507 | openrouter | In: text; Out: text | function_calling, structured_output, streaming, predicted_outputs | 262144 | 32000 | In: $0.05, Out: $0.19 |
| qwen/qwen3-30b-a3b-thinking-2507 | openrouter | In: text; Out: text | function_calling, reasoning, streaming | 81920 | 32768 | In: $0.20, Out: $2.40 |
| qwen/qwen3-32b | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 131072 | 16384 | In: $0.08, Out: $0.28 |
| qwen/qwen3-8b | openrouter | In: text; Out: text | function_calling, reasoning, streaming | 131072 | 8192 | In: $0.12, Out: $0.46 |
| qwen/qwen3-coder | openrouter | In: text; Out: text | function_calling, structured_output, streaming, predicted_outputs | 262144 | 65536 | In: $0.30, Out: $1.00, Cache Read: $0.10 |
| qwen/qwen3-coder-flash | openrouter | In: text; Out: text | function_calling, streaming | 1000000 | 65536 | In: $0.20, Out: $0.98, Cache Read: $0.04, Cache Write: $0.24 |
| qwen/qwen3-coder-next | openrouter | In: text; Out: text | function_calling, structured_output, streaming, predicted_outputs | 262144 | 262144 | In: $0.12, Out: $0.80, Cache Read: $0.07 |
| qwen/qwen3-coder-plus | openrouter | In: text; Out: text | function_calling, structured_output, streaming | 1000000 | 65536 | In: $0.65, Out: $3.25, Cache Read: $0.13, Cache Write: $0.81 |
| qwen/qwen3-max | openrouter | In: text; Out: text | function_calling, structured_output, streaming | 262144 | 65536 | In: $0.78, Out: $3.90, Cache Read: $0.16, Cache Write: $0.98 |
| qwen/qwen3-max-thinking | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 262144 | 65536 | In: $0.78, Out: $3.90 |
| qwen/qwen3-reranker-8b | openrouter | In: text; Out: rerank | streaming, structured_output, predicted_outputs | 40960 | - | - |
| qwen/qwen3-vl-235b-a22b-instruct | openrouter | In: text, image; Out: text | function_calling, structured_output, vision, streaming, predicted_outputs | 262144 | 32768 | In: $0.21, Out: $1.90, Cache Read: $0.10 |
| qwen/qwen3-vl-235b-a22b-thinking | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 131072 | 32768 | In: $0.40, Out: $4.00 |
| qwen/qwen3-vl-30b-a3b-instruct | openrouter | In: text, image; Out: text | function_calling, structured_output, vision, streaming, predicted_outputs | 262144 | 32768 | In: $0.13, Out: $0.52 |
| qwen/qwen3-vl-30b-a3b-thinking | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 262144 | 32768 | In: $0.20, Out: $2.40 |
| qwen/qwen3-vl-32b-instruct | openrouter | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 131072 | 32768 | In: $0.10, Out: $0.42 |
| qwen/qwen3-vl-8b-instruct | openrouter | In: image, text; Out: text | function_calling, structured_output, vision, streaming, predicted_outputs | 262144 | 32768 | In: $0.12, Out: $0.46 |
| qwen/qwen3-vl-8b-thinking | openrouter | In: image, text; Out: text | function_calling, structured_output, reasoning, vision, streaming | 131072 | 32768 | In: $0.18, Out: $2.10 |
| qwen/qwen3-coder-30b-a3b-instruct | openrouter | In: text; Out: text | function_calling, structured_output, streaming | 262144 | 262144 | In: $0.07, Out: $0.28 |
| qwen/qwen3-next-80b-a3b-thinking | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 262144 | 32768 | In: $0.15, Out: $1.20 |
| qwen/qwen3-next-80b-a3b-instruct | openrouter | In: text; Out: text | function_calling, structured_output, streaming, predicted_outputs | 262144 | 16384 | In: $0.09, Out: $1.10 |
| qwen/qwen3.5-122b-a10b | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming, predicted_outputs | 262144 | 262144 | In: $0.26, Out: $2.08 |
| qwen/qwen3.5-27b | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming, predicted_outputs | 262144 | 65536 | In: $0.20, Out: $1.56 |
| qwen/qwen3.5-35b-a3b | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming, predicted_outputs | 262144 | 262144 | In: $0.25, Out: $1.25, Cache Read: $0.25 |
| qwen/qwen3.5-397b-a17b | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming, predicted_outputs | 262144 | 65536 | In: $0.39, Out: $2.34 |
| qwen/qwen3.5-9b | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming, predicted_outputs | 262144 | 262144 | In: $0.10, Out: $0.15 |
| qwen/qwen3.5-plus-02-15 | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1000000 | 65536 | In: $0.26, Out: $1.56 |
| qwen/qwen3.5-plus-20260420 | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1000000 | 65536 | In: $0.30, Out: $1.80, Cache Write: $0.38 |
| qwen/qwen3.5-flash-02-23 | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1000000 | 65536 | In: $0.06, Out: $0.26 |
| qwen/qwen3.6-27b | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming, predicted_outputs | 262144 | 262144 | In: $0.60, Out: $3.60, Cache Read: $0.12 |
| qwen/qwen3.6-35b-a3b | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming, predicted_outputs | 262144 | 262144 | In: $0.14, Out: $1.00, Cache Read: $0.05 |
| qwen/qwen3.6-flash | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1000000 | 65536 | In: $0.19, Out: $1.12, Cache Write: $0.23 |
| qwen/qwen3.6-max-preview | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 262144 | 65536 | In: $1.03, Out: $6.16, Cache Write: $1.28 |
| qwen/qwen3.6-plus | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1000000 | 65536 | In: $0.32, Out: $1.95, Cache Write: $0.41 |
| qwen/qwen3.7-flash | openrouter | In: text, image, video; Out: text | function_calling, reasoning, vision, video, streaming | 1000000 | 65536 | In: $0.03, Out: $0.13, Cache Read: $0.01, Cache Write: $0.04 |
| qwen/qwen3.7-max | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 1000000 | 131072 | In: $1.48, Out: $4.42, Cache Read: $0.30, Cache Write: $1.84 |
| qwen/qwen3.7-plus | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 131072 | In: $0.32, Out: $1.28, Cache Read: $0.06, Cache Write: $0.40 |
| qwen/qwen3.8-2.4t-a95b | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 1048576 | 262144 | In: $2.00, Out: $6.00, Cache Read: $0.25 |
| qwen/qwen3.8-27b | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming, predicted_outputs | 1000000 | 131072 | In: $0.45, Out: $3.20, Cache Read: $0.05 |
| qwen/qwen3.8-max | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1000000 | 131072 | In: $2.00, Out: $6.00, Cache Read: $0.25, Cache Write: $2.50 |
| qwen/qwen-image-3 | openrouter | In: text, image; Out: image | streaming, image_generation | - | - | - |
| qwen/qwen-image-3-pro | openrouter | In: text, image; Out: image | streaming, image_generation | - | - | - |
| qwen/qwen-audio-3.0-tts-flash | openrouter | In: text; Out: audio | streaming, structured_output, speech_generation | 0 | - | In: $15.00 |
| qwen/qwen-audio-3.0-tts-plus | openrouter | In: text; Out: audio | streaming, structured_output, speech_generation | 0 | - | In: $20.00 |
| qwen/qwen3-asr-0.6b | openrouter | In: audio; Out: text | streaming, structured_output, transcription | 0 | - | In: $3.33 |
| qwen/qwen3-asr-1.7b | openrouter | In: audio; Out: text | streaming, structured_output, transcription | 0 | - | In: $7.50 |
| qwen/qwen3-asr-flash-2026-02-10 | openrouter | In: audio; Out: text | streaming, structured_output, transcription | 0 | - | In: $35.00 |
| qwen/qwen3-embedding-4b | openrouter | In: text; Out: embeddings | streaming, structured_output | 32768 | - | In: $0.02 |
| qwen/qwen3-embedding-8b | openrouter | In: text; Out: embeddings | streaming, structured_output, predicted_outputs | 32768 | 32000 | In: $0.01 |
| deepseek/deepseek-r1-0528 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 163840 | 32768 | In: $0.50, Out: $2.15, Cache Read: $0.35 |
| deepseek/deepseek-r1-distill-llama-70b | openrouter | In: text; Out: text | reasoning, streaming | 8192 | 8192 | In: $0.80, Out: $0.80 |
| undi95/remm-slerp-l2-13b | openrouter | In: text; Out: text | structured_output, streaming, predicted_outputs | 6144 | 6144 | In: $0.45, Out: $0.65 |
| recraft/recraft-v3 | openrouter | In: text, image; Out: image | streaming, image_generation | - | - | - |
| recraft/recraft-v4 | openrouter | In: text, image; Out: image | streaming, image_generation | - | - | - |
| recraft/recraft-v4-pro | openrouter | In: text, image; Out: image | streaming, image_generation | - | - | - |
| recraft/recraft-v4-pro-vector | openrouter | In: text, image; Out: image | streaming, image_generation | - | - | - |
| recraft/recraft-v4-vector | openrouter | In: text, image; Out: image | streaming, image_generation | - | - | - |
| recraft/recraft-v4.1 | openrouter | In: text, image; Out: image | streaming, image_generation | - | - | - |
| recraft/recraft-v4.1-pro | openrouter | In: text, image; Out: image | streaming, image_generation | - | - | - |
| recraft/recraft-v4.1-pro-vector | openrouter | In: text, image; Out: image | streaming, image_generation | - | - | - |
| recraft/recraft-v4.1-utility | openrouter | In: text, image; Out: image | streaming, image_generation | - | - | - |
| recraft/recraft-v4.1-utility-pro | openrouter | In: text, image; Out: image | streaming, image_generation | - | - | - |
| recraft/recraft-v4.1-vector | openrouter | In: text, image; Out: image | streaming, image_generation | - | - | - |
| rekaai/reka-edge | openrouter | In: image, text, video; Out: text | function_calling, structured_output, vision, video, streaming | 16384 | 16384 | In: $0.10, Out: $0.10 |
| rekaai/reka-flash-3 | openrouter | In: text; Out: text | structured_output, reasoning, streaming | 65536 | 65536 | In: $0.10, Out: $0.20 |
| relace/relace-apply-3 | openrouter | In: text; Out: text | streaming | 256000 | 128000 | In: $0.85, Out: $1.25 |
| relace/relace-search | openrouter | In: text; Out: text | function_calling, streaming | 256000 | 128000 | In: $1.00, Out: $3.00 |
| inclusionai/ring-2.6-1t | openrouter | In: text; Out: text | function_calling, reasoning, streaming | 262144 | 65536 | In: $0.08, Out: $0.62, Cache Read: $0.02 |
| thedrummer/rocinante-12b | openrouter | In: text; Out: text | structured_output, streaming, predicted_outputs | 65536 | 65536 | In: $0.25, Out: $0.50 |
| mistralai/mistral-saba | openrouter | In: text, pdf; Out: text | function_calling, structured_output, vision, streaming | 32768 | 32768 | In: $0.20, Out: $0.60, Cache Read: $0.02 |
| sakana/sakana-namazu | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 262144 | 65536 | In: $0.95, Out: $4.00, Cache Read: $0.15 |
| bytedance-seed/seed-1.6 | openrouter | In: image, text, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 262144 | 32768 | In: $0.25, Out: $2.00 |
| bytedance-seed/seed-1.6-flash | openrouter | In: image, text, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 262144 | 32768 | In: $0.08, Out: $0.30 |
| bytedance-seed/seed-2.0-code | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 262144 | 131072 | In: $0.50, Out: $3.00 |
| bytedance-seed/seed-2.0-lite | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 262144 | 131072 | In: $0.25, Out: $2.00 |
| bytedance-seed/seed-2.0-mini | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 262144 | 131072 | In: $0.10, Out: $0.40 |
| bytedance-seed/seed-2-1-turbo | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 262144 | 262144 | In: $0.50, Out: $2.50 |
| sentence-transformers/all-minilm-l12-v2 | openrouter | In: text; Out: embeddings | streaming, structured_output | 512 | - | In: $0.01 |
| sentence-transformers/all-minilm-l6-v2 | openrouter | In: text; Out: embeddings | streaming, structured_output | 512 | - | In: $0.01 |
| sentence-transformers/all-mpnet-base-v2 | openrouter | In: text; Out: embeddings | streaming, structured_output | 512 | - | In: $0.01 |
| sentence-transformers/multi-qa-mpnet-base-dot-v1 | openrouter | In: text; Out: embeddings | streaming, structured_output | 512 | - | In: $0.01 |
| sentence-transformers/paraphrase-minilm-l6-v2 | openrouter | In: text; Out: embeddings | streaming, structured_output | 512 | - | In: $0.01 |
| sesame/csm-1b | openrouter | In: text; Out: audio | streaming, structured_output, speech_generation | 4096 | - | In: $7.00 |
| thedrummer/skyfall-36b-v2 | openrouter | In: text; Out: text | structured_output, streaming, predicted_outputs | 32768 | 32768 | In: $0.55, Out: $0.80, Cache Read: $0.25 |
| upstage/solar-pro-3 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 131072 | 131072 | In: $0.15, Out: $0.60, Cache Read: $0.02 |
| upstage/solar-pro4 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 524288 | 131072 | In: $0.03, Out: $0.12, Cache Read: $0.01 |
| perplexity/sonar | openrouter | In: text, image; Out: text | vision, streaming | 127072 | 127072 | In: $1.00, Out: $1.00 |
| perplexity/sonar-deep-research | openrouter | In: text; Out: text | reasoning, streaming | 128000 | 128000 | In: $2.00, Out: $8.00 |
| perplexity/sonar-pro | openrouter | In: text, image; Out: text | vision, streaming | 200000 | 8000 | In: $3.00, Out: $15.00 |
| perplexity/sonar-pro-search | openrouter | In: text, image; Out: text | structured_output, reasoning, vision, streaming | 200000 | 8000 | In: $3.00, Out: $15.00 |
| perplexity/sonar-reasoning-pro | openrouter | In: text, image; Out: text | reasoning, vision, streaming | 128000 | 128000 | In: $2.00, Out: $8.00 |
| sourceful/riverflow-v2-fast | openrouter | In: text, image; Out: image | streaming, image_generation | - | - | - |
| sourceful/riverflow-v2-pro | openrouter | In: text, image; Out: image | streaming, image_generation | - | - | - |
| sourceful/riverflow-v2.5-fast | openrouter | In: text, image; Out: image | streaming, image_generation | - | - | - |
| sourceful/riverflow-v2.5-pro | openrouter | In: text, image; Out: image | streaming, image_generation | - | - | - |
| x-ai/grok-imagine-image-quality | openrouter | In: text, image; Out: image | streaming, image_generation | - | - | - |
| x-ai/grok-stt-1.0 | openrouter | In: audio; Out: text | streaming, structured_output, transcription | 0 | - | In: $100000.00 |
| x-ai/grok-voice-tts-1.0 | openrouter | In: text; Out: audio | streaming, structured_output, speech_generation | 15000 | - | In: $15.00 |
| stepfun/step-3.5-flash | openrouter | In: text; Out: text | function_calling, reasoning, streaming | 262144 | 65536 | In: $0.10, Out: $0.30 |
| stepfun/step-3.7-flash | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming, predicted_outputs | 262144 | 256000 | In: $0.20, Out: $1.15, Cache Read: $0.04 |
| thenlper/gte-base | openrouter | In: text; Out: embeddings | streaming, structured_output | 512 | - | In: $0.01 |
| thenlper/gte-large | openrouter | In: text; Out: embeddings | streaming, structured_output | 512 | - | In: $0.01 |
| thinkingmachines/inkling:batch | openrouter | In: text, image, audio; Out: text | streaming, function_calling, predicted_outputs | 524288 | - | In: $1.00, Out: $4.05, Cache Read: $0.17 |
| arcee-ai/trinity-large-thinking | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 262144 | 262144 | In: $0.22, Out: $0.85, Cache Read: $0.06 |
| bytedance/ui-tars-1.5-7b | openrouter | In: image, text; Out: text | structured_output, vision, streaming, predicted_outputs | 128000 | 2048 | In: $0.10, Out: $0.20, Cache Read: $0.10 |
| cognitivecomputations/dolphin-mistral-24b-venice-edition | openrouter | In: text; Out: text | streaming | 128000 | 8192 | In: $0.20, Out: $0.90 |
| thedrummer/unslopnemo-12b | openrouter | In: text; Out: text | function_calling, structured_output, streaming, predicted_outputs | 1024000 | 1024000 | In: $0.40, Out: $0.40 |
| arcee-ai/virtuoso-large | openrouter | In: text; Out: text | function_calling, streaming, predicted_outputs | 131072 | 64000 | In: $0.75, Out: $1.20 |
| mistralai/voxtral-small-24b-2507 | openrouter | In: text, audio, pdf; Out: text | function_calling, structured_output, vision, streaming | 32000 | 32000 | In: $0.10, Out: $0.30, Cache Read: $0.01 |
| voyageai/rerank-2.5 | openrouter | In: text; Out: rerank | streaming | 32000 | - | - |
| voyageai/rerank-2.5-lite | openrouter | In: text; Out: rerank | streaming | 32000 | - | - |
| voyageai/voyage-4 | openrouter | In: text; Out: embeddings | streaming | 32000 | - | In: $0.06 |
| voyageai/voyage-4-large | openrouter | In: text; Out: embeddings | streaming | 32000 | - | In: $0.12 |
| voyageai/voyage-4-lite | openrouter | In: text; Out: embeddings | streaming | 32000 | - | In: $0.02 |
| voyageai/voyage-code-4 | openrouter | In: text; Out: embeddings | streaming | 32000 | - | In: $0.12 |
| voyageai/voyage-multimodal-3.5 | openrouter | In: text, image; Out: embeddings | streaming | 32000 | - | In: $0.12 |
| microsoft/wizardlm-2-8x22b | openrouter | In: text; Out: text | streaming | 65535 | 8000 | In: $0.62, Out: $0.62 |
| z-ai/glm-5.2:batch | openrouter | In: text; Out: text | streaming, function_calling, structured_output, predicted_outputs | 512000 | - | In: $1.40, Out: $4.40, Cache Read: $0.26 |
| openai/gpt-oss-20b:free | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 131072 | 32768 | In: $0.00, Out: $0.00 |
| openai/gpt-oss-safeguard-20b | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 131072 | 65536 | In: $0.08, Out: $0.30, Cache Read: $0.04 |
| hexgrad/kokoro-82m | openrouter | In: text; Out: audio | streaming, structured_output, predicted_outputs, speech_generation | 4096 | - | In: $0.62 |
| openai/o1 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 100000 | In: $15.00, Out: $60.00, Cache Read: $7.50 |
| openai/o1-pro | openrouter | In: text, image, pdf; Out: text | structured_output, reasoning, vision, streaming | 200000 | 100000 | In: $150.00, Out: $600.00 |
| openai/o3 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 100000 | In: $2.00, Out: $8.00, Cache Read: $0.50 |
| openai/o3-mini-high | openrouter | In: text, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 100000 | In: $1.10, Out: $4.40, Cache Read: $0.55 |
| openai/o3-mini | openrouter | In: text, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 100000 | In: $1.10, Out: $4.40, Cache Read: $0.55 |
| openai/o3-pro | openrouter | In: text, pdf, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 100000 | In: $20.00, Out: $80.00 |
| openai/o4-mini-high | openrouter | In: image, text, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 100000 | In: $1.10, Out: $4.40, Cache Read: $0.28 |
| openai/o4-mini | openrouter | In: image, text, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 100000 | In: $1.10, Out: $4.40, Cache Read: $0.28 |
| x-ai/grok-imagine-image-2.0 | openrouter | In: text, image; Out: image | streaming, image_generation | - | - | - |
| claude-haiku-4-5 | vertexai | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 64000 | In: $1.00, Out: $5.00, Cache Read: $0.10, Cache Write: $1.25 |
| claude-opus-4-1 | vertexai | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 32000 | In: $15.00, Out: $75.00, Cache Read: $1.50, Cache Write: $18.75 |
| claude-opus-4-5 | vertexai | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 64000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| claude-opus-4-6 | vertexai | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| claude-opus-4-7 | vertexai | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| claude-opus-4-8 | vertexai | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| claude-opus-5 | vertexai | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| claude-sonnet-4-5 | vertexai | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 64000 | In: $3.00, Out: $15.00, Cache Read: $0.30, Cache Write: $3.75 |
| claude-sonnet-4-6 | vertexai | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 1000000 | 128000 | In: $3.00, Out: $15.00, Cache Read: $0.30, Cache Write: $3.75 |
| claude-sonnet-5 | vertexai | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 1000000 | 128000 | In: $2.00, Out: $10.00, Cache Read: $0.20, Cache Write: $2.50 |
| gemini-2.5-flash | vertexai | In: text, image, audio, video, pdf; Out: text | function_calling, reasoning, vision, video, transcription, streaming | 1048576 | 65536 | In: $0.30, Out: $2.50, Cache Read: $0.08, Cache Write: $0.38 |
| gemini-2.5-flash-tts | vertexai | In: text; Out: audio | streaming | 32768 | 16384 | In: $0.50, Out: $10.00 |
| gemini-2.5-flash-lite | vertexai | In: text, image, audio, video, pdf; Out: text | function_calling, reasoning, vision, video, transcription, streaming | 1048576 | 65536 | In: $0.10, Out: $0.40, Cache Read: $0.01 |
| gemini-2.5-pro | vertexai | In: text, image, audio, video, pdf; Out: text | function_calling, reasoning, vision, video, transcription, streaming | 1048576 | 65536 | In: $1.25, Out: $10.00, Cache Read: $0.12 |
| gemini-2.5-pro-tts | vertexai | In: text; Out: audio | streaming | 32768 | 16384 | In: $1.00, Out: $20.00 |
| gemini-3-flash-preview | vertexai | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription, streaming | 1048576 | 65536 | In: $0.50, Out: $3.00, Cache Read: $0.05 |
| gemini-3.1-flash-lite | vertexai | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription, streaming | 1048576 | 65536 | In: $0.25, Out: $1.50, Cache Read: $0.02 |
| gemini-3.1-pro-preview | vertexai | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription, streaming | 1048576 | 65536 | In: $2.00, Out: $12.00, Cache Read: $0.20 |
| gemini-3.5-flash | vertexai | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription, streaming | 1048576 | 65536 | In: $1.50, Out: $9.00, Cache Read: $0.15 |
| gemini-3.5-flash-lite | vertexai | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription, streaming | 1048576 | 65536 | In: $0.30, Out: $2.50, Cache Read: $0.03 |
| gemini-3.6-flash | vertexai | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription, streaming | 1048576 | 65536 | In: $1.50, Out: $7.50, Cache Read: $0.15 |
| gemini-3.7-flash | vertexai | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription, streaming | 1048576 | 65536 | In: $0.75, Out: $3.75, Cache Read: $0.08 |
| gemini-embedding-001 | vertexai | In: text; Out: embeddings | streaming | 2048 | 1 | In: $0.15, Out: $0.00 |
| gemini-embedding-2 | vertexai | In: text, image, audio, video, pdf; Out: embeddings | vision, video, streaming | 8192 | 1 | In: $0.20, Out: $0.00 |
| gemini-3.1-flash-image | vertexai | In: text, image, video, pdf; Out: text, image | reasoning, vision, video, streaming | 131072 | 32768 | In: $0.50, Out: $60.00 |
| gemini-3.1-flash-image-preview | vertexai | In: text, image, pdf; Out: text, image | reasoning, vision, streaming | 65536 | 65536 | In: $0.50, Out: $60.00 |
| gemini-3.1-flash-lite-image | vertexai | In: text, image; Out: text, image | function_calling, reasoning, vision, streaming | 65536 | 65536 | In: $0.25, Out: $30.00 |
| gemini-3-pro-image | vertexai | In: text, image; Out: text, image | reasoning, vision, streaming | 65536 | 32768 | In: $2.00, Out: $120.00 |
| claude-fable-5 | vertexai | In: -; Out: - | streaming, function_calling | - | - | - |
| codestral-2 | vertexai | In: -; Out: - | streaming, function_calling | - | - | - |
| gemini-1.5-pro | vertexai | In: -; Out: - | streaming, function_calling | - | - | - |
| gemini-1.5-pro-002 | vertexai | In: -; Out: - | streaming, function_calling | - | - | - |
| gemini-2.0-flash-001 | vertexai | In: -; Out: - | streaming, function_calling | - | - | - |
| gemini-2.0-flash-lite-001 | vertexai | In: -; Out: - | streaming, function_calling | - | - | - |
| gemini-2.5-flash-preview-04-17 | vertexai | In: -; Out: - | streaming, function_calling | - | - | - |
| gemini-2.5-pro-exp-03-25 | vertexai | In: -; Out: - | streaming, function_calling | - | - | - |
| gemini-live-2.5-flash-native-audio | vertexai | In: -; Out: - | streaming, function_calling | - | - | - |
| gemini-pro | vertexai | In: -; Out: - | streaming, function_calling | - | - | - |
| gemini-pro-vision | vertexai | In: -; Out: - | streaming, function_calling | - | - | - |
| mistral-medium-3 | vertexai | In: -; Out: - | streaming, function_calling | - | - | - |
| mistral-ocr-2505 | vertexai | In: -; Out: - | streaming | - | - | - |
| mistral-small-2503 | vertexai | In: -; Out: - | streaming, function_calling | - | - | - |
| text-embedding-004 | vertexai | In: -; Out: - | streaming | - | - | - |
| text-embedding-005 | vertexai | In: -; Out: - | streaming | - | - | - |
| text-multilingual-embedding-002 | vertexai | In: -; Out: - | streaming | - | - | - |
| grok-4.20-0309-non-reasoning | xai | In: text, image, pdf; Out: text | function_calling, structured_output, vision, streaming | 1000000 | 30000 | In: $1.25, Out: $2.50, Cache Read: $0.20 |
| grok-4.20-0309-reasoning | xai | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 30000 | In: $1.25, Out: $2.50, Cache Read: $0.20 |
| grok-4.20-multi-agent-0309 | xai | In: text, image, pdf; Out: text | structured_output, reasoning, vision, streaming | 1000000 | 30000 | In: $1.25, Out: $2.50, Cache Read: $0.20 |
| grok-4.3 | xai | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 30000 | In: $1.25, Out: $2.50, Cache Read: $0.20 |
| grok-4.5 | xai | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 500000 | 500000 | In: $2.00, Out: $6.00, Cache Read: $0.30 |
| grok-4.6 | xai | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 500000 | 500000 | In: $2.00, Out: $6.00, Cache Read: $0.50 |
| grok-build-0.1 | xai | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 256000 | 256000 | In: $1.00, Out: $2.00, Cache Read: $0.20 |


### Batch Processing (45)

| Model | Provider | I/O | Capabilities | Context | Max Output | Standard Pricing (per 1M tokens) |
| :-- | :-- | :-- | :-- | --: | --: | :-- |
| claude-fable-5 | anthropic | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, citations, tool_choice, parallel_tool_calls, batch | 1000000 | 128000 | In: $10.00, Out: $50.00, Cache Read: $1.00, Cache Write: $12.50 |
| claude-haiku-4-5-20251001 | anthropic | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, citations, tool_choice, parallel_tool_calls, batch | 200000 | 64000 | In: $1.00, Out: $5.00, Cache Read: $0.10, Cache Write: $1.25 |
| claude-opus-4-5-20251101 | anthropic | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, citations, tool_choice, parallel_tool_calls, batch | 200000 | 64000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| claude-opus-4-6 | anthropic | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, citations, tool_choice, parallel_tool_calls, batch | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| claude-opus-4-7 | anthropic | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, citations, tool_choice, parallel_tool_calls, batch | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| claude-opus-4-8 | anthropic | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, citations, tool_choice, parallel_tool_calls, batch | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| claude-opus-5 | anthropic | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, citations, tool_choice, parallel_tool_calls, batch | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| claude-sonnet-4-5-20250929 | anthropic | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, citations, tool_choice, parallel_tool_calls, batch | 1000000 | 64000 | In: $3.00, Out: $15.00, Cache Read: $0.30, Cache Write: $3.75 |
| claude-sonnet-4-6 | anthropic | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, citations, tool_choice, parallel_tool_calls, batch | 1000000 | 128000 | In: $3.00, Out: $15.00, Cache Read: $0.30, Cache Write: $3.75 |
| claude-sonnet-5 | anthropic | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, citations, tool_choice, parallel_tool_calls, batch | 1000000 | 128000 | In: $2.00, Out: $10.00, Cache Read: $0.20, Cache Write: $2.50 |
| codestral-2508 | mistral | In: text; Out: text | streaming, function_calling, tool_choice, parallel_tool_calls, structured_output, batch, predicted_outputs | 256000 | 8192 | - |
| codestral-latest | mistral | In: text; Out: text | function_calling, streaming, tool_choice, parallel_tool_calls, structured_output, batch, predicted_outputs | 256000 | 4096 | In: $0.30, Out: $0.90 |
| devstral-2512 | mistral | In: text; Out: text | function_calling, streaming, tool_choice, parallel_tool_calls, structured_output, batch | 262144 | 262144 | In: $0.40, Out: $2.00 |
| devstral-latest | mistral | In: text; Out: text | function_calling, streaming, tool_choice, parallel_tool_calls, structured_output, batch | 262144 | 262144 | In: $0.40, Out: $2.00 |
| devstral-medium-latest | mistral | In: text; Out: text | function_calling, streaming, tool_choice, parallel_tool_calls, structured_output, batch | 262144 | 262144 | In: $0.40, Out: $2.00 |
| glm-5-2 | mistral | In: text; Out: text | streaming, function_calling, tool_choice, parallel_tool_calls, structured_output, batch, reasoning | 1048576 | 8192 | - |
| labs-leanstral-1-5 | mistral | In: text, image; Out: text | streaming, function_calling, tool_choice, parallel_tool_calls, structured_output, batch, reasoning, vision | 262144 | 8192 | - |
| labs-leanstral-1-5-1 | mistral | In: text, image; Out: text | streaming, function_calling, tool_choice, parallel_tool_calls, structured_output, batch, reasoning, vision | 262144 | 8192 | - |
| magistral-medium-latest | mistral | In: text; Out: text | function_calling, reasoning, streaming, tool_choice, parallel_tool_calls, structured_output, batch | 128000 | 16384 | In: $2.00, Out: $5.00 |
| magistral-small-latest | mistral | In: text, image; Out: text | streaming, function_calling, tool_choice, parallel_tool_calls, structured_output, reasoning, batch, vision | 262144 | 8192 | - |
| ministral-14b-2512 | mistral | In: text, image; Out: text | streaming, function_calling, tool_choice, parallel_tool_calls, structured_output, batch, distillation, fine_tuning, vision | 262144 | 8192 | - |
| ministral-14b-latest | mistral | In: text, image; Out: text | streaming, function_calling, tool_choice, parallel_tool_calls, structured_output, batch, distillation, fine_tuning, vision | 262144 | 8192 | - |
| ministral-3b-2512 | mistral | In: text, image; Out: text | streaming, function_calling, tool_choice, parallel_tool_calls, structured_output, batch, distillation, fine_tuning, vision | 131072 | 8192 | - |
| ministral-3b-latest | mistral | In: text; Out: text | function_calling, streaming, tool_choice, parallel_tool_calls, structured_output, batch, distillation, fine_tuning | 128000 | 128000 | In: $0.04, Out: $0.04 |
| ministral-8b-2512 | mistral | In: text, image; Out: text | streaming, function_calling, tool_choice, parallel_tool_calls, structured_output, batch, distillation, fine_tuning, vision | 262144 | 8192 | - |
| ministral-8b-latest | mistral | In: text; Out: text | function_calling, streaming, tool_choice, parallel_tool_calls, structured_output, batch, distillation, fine_tuning | 128000 | 128000 | In: $0.10, Out: $0.10 |
| mistral-code-agent-latest | mistral | In: text; Out: text | streaming, function_calling, tool_choice, parallel_tool_calls, structured_output, batch | 262144 | 8192 | - |
| mistral-code-fim-latest | mistral | In: text; Out: text | streaming, function_calling, tool_choice, parallel_tool_calls, structured_output, batch | 256000 | 8192 | - |
| mistral-code-latest | mistral | In: text; Out: text | streaming, function_calling, tool_choice, parallel_tool_calls, structured_output, batch | 256000 | 8192 | - |
| mistral-large-latest | mistral | In: text, image; Out: text | function_calling, vision, streaming, tool_choice, parallel_tool_calls, structured_output, batch, fine_tuning | 262144 | 262144 | In: $0.50, Out: $1.50 |
| mistral-large-2512 | mistral | In: text, image; Out: text | function_calling, vision, streaming, tool_choice, parallel_tool_calls, structured_output, batch, fine_tuning | 262144 | 262144 | In: $0.50, Out: $1.50 |
| mistral-medium | mistral | In: text, image; Out: text | streaming, function_calling, tool_choice, parallel_tool_calls, structured_output, batch, reasoning, vision | 262144 | 8192 | - |
| mistral-medium-3 | mistral | In: text, image; Out: text | streaming, function_calling, tool_choice, parallel_tool_calls, structured_output, reasoning, batch, vision | 262144 | 8192 | - |
| mistral-medium-3-5 | mistral | In: text, image; Out: text | streaming, function_calling, tool_choice, parallel_tool_calls, structured_output, reasoning, batch, vision | 262144 | 8192 | - |
| mistral-medium-3.5 | mistral | In: text, image; Out: text | streaming, function_calling, tool_choice, parallel_tool_calls, structured_output, reasoning, batch, vision | 262144 | 8192 | - |
| mistral-medium-latest | mistral | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming, tool_choice, parallel_tool_calls, batch | 262144 | 262144 | In: $1.50, Out: $7.50 |
| mistral-medium-2505 | mistral | In: text, image; Out: text | function_calling, vision, streaming, tool_choice, parallel_tool_calls, structured_output, batch, fine_tuning | 131072 | 131072 | In: $0.40, Out: $2.00 |
| mistral-medium-2508 | mistral | In: text, image; Out: text | function_calling, vision, streaming, tool_choice, parallel_tool_calls, structured_output, batch, fine_tuning | 262144 | 262144 | In: $0.40, Out: $2.00 |
| mistral-medium-2604 | mistral | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming, tool_choice, parallel_tool_calls, batch | 262144 | 262144 | In: $1.50, Out: $7.50 |
| mistral-small-latest | mistral | In: text, image; Out: text | function_calling, reasoning, vision, streaming, tool_choice, parallel_tool_calls, structured_output, batch | 256000 | 256000 | In: $0.15, Out: $0.60 |
| mistral-small-2603 | mistral | In: text, image; Out: text | function_calling, reasoning, vision, streaming, tool_choice, parallel_tool_calls, structured_output, batch | 256000 | 256000 | In: $0.15, Out: $0.60 |
| mistral-vibe-cli-fast | mistral | In: text, image; Out: text | streaming, function_calling, tool_choice, parallel_tool_calls, structured_output, batch, reasoning, vision | 262144 | 8192 | - |
| mistral-vibe-cli-latest | mistral | In: text, image; Out: text | streaming, function_calling, tool_choice, parallel_tool_calls, structured_output, batch, reasoning, vision | 262144 | 8192 | - |
| mistral-vibe-cli-with-tools | mistral | In: text, image; Out: text | streaming, function_calling, tool_choice, parallel_tool_calls, structured_output, batch, reasoning, vision | 262144 | 8192 | - |
| zai-glm-5-2 | mistral | In: text; Out: text | streaming, function_calling, tool_choice, parallel_tool_calls, structured_output, batch, reasoning | 1048576 | 8192 | - |


## Models by Modality

### Vision Models (590)

Models that can process images:

| Model | Provider | I/O | Capabilities | Context | Max Output | Standard Pricing (per 1M tokens) |
| :-- | :-- | :-- | :-- | --: | --: | :-- |
| claude-fable-5 | anthropic | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, citations, tool_choice, parallel_tool_calls, batch | 1000000 | 128000 | In: $10.00, Out: $50.00, Cache Read: $1.00, Cache Write: $12.50 |
| claude-haiku-4-5-20251001 | anthropic | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, citations, tool_choice, parallel_tool_calls, batch | 200000 | 64000 | In: $1.00, Out: $5.00, Cache Read: $0.10, Cache Write: $1.25 |
| claude-haiku-4-5 | anthropic | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 200000 | 64000 | In: $1.00, Out: $5.00, Cache Read: $0.10, Cache Write: $1.25 |
| claude-opus-4-5-20251101 | anthropic | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, citations, tool_choice, parallel_tool_calls, batch | 200000 | 64000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| claude-opus-4-5 | anthropic | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 200000 | 64000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| claude-opus-4-6 | anthropic | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, citations, tool_choice, parallel_tool_calls, batch | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| claude-opus-4-7 | anthropic | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, citations, tool_choice, parallel_tool_calls, batch | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| claude-opus-4-8 | anthropic | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, citations, tool_choice, parallel_tool_calls, batch | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| claude-opus-5 | anthropic | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, citations, tool_choice, parallel_tool_calls, batch | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| claude-sonnet-4-5-20250929 | anthropic | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, citations, tool_choice, parallel_tool_calls, batch | 1000000 | 64000 | In: $3.00, Out: $15.00, Cache Read: $0.30, Cache Write: $3.75 |
| claude-sonnet-4-5 | anthropic | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1000000 | 64000 | In: $3.00, Out: $15.00, Cache Read: $0.30, Cache Write: $3.75 |
| claude-sonnet-4-6 | anthropic | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, citations, tool_choice, parallel_tool_calls, batch | 1000000 | 128000 | In: $3.00, Out: $15.00, Cache Read: $0.30, Cache Write: $3.75 |
| claude-sonnet-5 | anthropic | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, citations, tool_choice, parallel_tool_calls, batch | 1000000 | 128000 | In: $2.00, Out: $10.00, Cache Read: $0.20, Cache Write: $2.50 |
| au.anthropic.claude-opus-4-6-v1 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1000000 | 128000 | In: $16.50, Out: $82.50, Cache Read: $1.65, Cache Write: $20.62 |
| au.anthropic.claude-sonnet-4-6 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1000000 | 128000 | In: $3.30, Out: $16.50, Cache Read: $0.33, Cache Write: $4.12 |
| anthropic.claude-3-haiku-20240307-v1:0 | bedrock | In: text, image; Out: text | streaming, function_calling | - | - | - |
| anthropic.claude-3-haiku-20240307-v1:0:200k | bedrock | In: text, image; Out: text | streaming, function_calling | - | - | - |
| anthropic.claude-3-haiku-20240307-v1:0:48k | bedrock | In: text, image; Out: text | streaming, function_calling | - | - | - |
| anthropic.claude-fable-5 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 1000000 | 128000 | In: $10.00, Out: $50.00, Cache Read: $1.00, Cache Write: $12.50 |
| eu.anthropic.claude-fable-5 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 1000000 | 128000 | In: $11.00, Out: $55.00, Cache Read: $1.10, Cache Write: $13.75 |
| global.anthropic.claude-fable-5 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 1000000 | 128000 | In: $10.00, Out: $50.00, Cache Read: $1.00, Cache Write: $12.50 |
| us.anthropic.claude-fable-5 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 1000000 | 128000 | In: $10.00, Out: $50.00, Cache Read: $1.00, Cache Write: $12.50 |
| anthropic.claude-haiku-4-5-20251001-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 200000 | 64000 | In: $1.00, Out: $5.00, Cache Read: $0.10, Cache Write: $1.25 |
| au.anthropic.claude-haiku-4-5-20251001-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 200000 | 64000 | In: $1.00, Out: $5.00, Cache Read: $0.10, Cache Write: $1.25 |
| eu.anthropic.claude-haiku-4-5-20251001-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 200000 | 64000 | In: $1.10, Out: $5.50, Cache Read: $0.11, Cache Write: $1.38 |
| global.anthropic.claude-haiku-4-5-20251001-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 200000 | 64000 | In: $1.00, Out: $5.00, Cache Read: $0.10, Cache Write: $1.25 |
| jp.anthropic.claude-haiku-4-5-20251001-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 200000 | 64000 | In: $1.00, Out: $5.00, Cache Read: $0.10, Cache Write: $1.25 |
| us.anthropic.claude-haiku-4-5-20251001-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 64000 | In: $1.00, Out: $5.00, Cache Read: $0.10, Cache Write: $1.25 |
| anthropic.claude-opus-4-1-20250805-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 200000 | 32000 | In: $15.00, Out: $75.00, Cache Read: $1.50, Cache Write: $18.75 |
| us.anthropic.claude-opus-4-1-20250805-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 32000 | In: $15.00, Out: $75.00, Cache Read: $1.50, Cache Write: $18.75 |
| anthropic.claude-opus-4-5-20251101-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 200000 | 64000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| eu.anthropic.claude-opus-4-5-20251101-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 200000 | 64000 | In: $5.50, Out: $27.50, Cache Read: $0.55, Cache Write: $6.88 |
| global.anthropic.claude-opus-4-5-20251101-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 200000 | 64000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| us.anthropic.claude-opus-4-5-20251101-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 64000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| anthropic.claude-opus-4-6-v1 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| eu.anthropic.claude-opus-4-6-v1 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1000000 | 128000 | In: $5.50, Out: $27.50, Cache Read: $0.55, Cache Write: $6.88 |
| global.anthropic.claude-opus-4-6-v1 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| us.anthropic.claude-opus-4-6-v1 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| anthropic.claude-opus-4-7 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| eu.anthropic.claude-opus-4-7 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 1000000 | 128000 | In: $5.50, Out: $27.50, Cache Read: $0.55, Cache Write: $6.88 |
| global.anthropic.claude-opus-4-7 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| jp.anthropic.claude-opus-4-7 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| us.anthropic.claude-opus-4-7 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming, structured_output | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| anthropic.claude-opus-4-8 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| au.anthropic.claude-opus-4-8 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| eu.anthropic.claude-opus-4-8 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 1000000 | 128000 | In: $5.50, Out: $27.50, Cache Read: $0.55, Cache Write: $6.88 |
| global.anthropic.claude-opus-4-8 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| jp.anthropic.claude-opus-4-8 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| us.anthropic.claude-opus-4-8 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming, structured_output | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| anthropic.claude-opus-5 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| au.anthropic.claude-opus-5 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| eu.anthropic.claude-opus-5 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 1000000 | 128000 | In: $5.50, Out: $27.50, Cache Read: $0.55, Cache Write: $6.88 |
| global.anthropic.claude-opus-5 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| jp.anthropic.claude-opus-5 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| us.anthropic.claude-opus-5 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| us.anthropic.claude-sonnet-4-20250514-v1:0 | bedrock | In: text, image; Out: text | streaming, function_calling, reasoning | 200000 | 65536 | - |
| anthropic.claude-sonnet-4-5-20250929-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 200000 | 64000 | In: $3.00, Out: $15.00, Cache Read: $0.30, Cache Write: $3.75 |
| au.anthropic.claude-sonnet-4-5-20250929-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 200000 | 64000 | In: $3.00, Out: $15.00, Cache Read: $0.30, Cache Write: $3.75 |
| eu.anthropic.claude-sonnet-4-5-20250929-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 200000 | 64000 | In: $3.30, Out: $16.50, Cache Read: $0.33, Cache Write: $4.12 |
| global.anthropic.claude-sonnet-4-5-20250929-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 200000 | 64000 | In: $3.00, Out: $15.00, Cache Read: $0.30, Cache Write: $3.75 |
| jp.anthropic.claude-sonnet-4-5-20250929-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 200000 | 64000 | In: $3.00, Out: $15.00, Cache Read: $0.30, Cache Write: $3.75 |
| us.anthropic.claude-sonnet-4-5-20250929-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 64000 | In: $3.00, Out: $15.00, Cache Read: $0.30, Cache Write: $3.75 |
| anthropic.claude-sonnet-4-6 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1000000 | 64000 | In: $3.00, Out: $15.00, Cache Read: $0.30, Cache Write: $3.75 |
| eu.anthropic.claude-sonnet-4-6 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1000000 | 64000 | In: $3.30, Out: $16.50, Cache Read: $0.33, Cache Write: $4.12 |
| global.anthropic.claude-sonnet-4-6 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1000000 | 64000 | In: $3.00, Out: $15.00, Cache Read: $0.30, Cache Write: $3.75 |
| jp.anthropic.claude-sonnet-4-6 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1000000 | 64000 | In: $3.00, Out: $15.00, Cache Read: $0.30, Cache Write: $3.75 |
| us.anthropic.claude-sonnet-4-6 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 64000 | In: $3.00, Out: $15.00, Cache Read: $0.30, Cache Write: $3.75 |
| anthropic.claude-sonnet-5 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1000000 | 128000 | In: $2.00, Out: $10.00, Cache Read: $0.20, Cache Write: $2.50 |
| au.anthropic.claude-sonnet-5 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1000000 | 128000 | In: $2.00, Out: $10.00, Cache Read: $0.20, Cache Write: $2.50 |
| eu.anthropic.claude-sonnet-5 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1000000 | 128000 | In: $2.20, Out: $11.00, Cache Read: $0.22, Cache Write: $2.75 |
| global.anthropic.claude-sonnet-5 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1000000 | 128000 | In: $2.00, Out: $10.00, Cache Read: $0.20, Cache Write: $2.50 |
| jp.anthropic.claude-sonnet-5 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1000000 | 128000 | In: $2.00, Out: $10.00, Cache Read: $0.20, Cache Write: $2.50 |
| us.anthropic.claude-sonnet-5 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 128000 | In: $2.00, Out: $10.00, Cache Read: $0.20, Cache Write: $2.50 |
| us.cohere.embed-v4:0 | bedrock | In: text, image; Out: embeddings | - | 128000 | - | - |
| openai.gpt-5.4 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 272000 | 128000 | In: $2.75, Out: $16.50, Cache Read: $0.28 |
| openai.gpt-5.5 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 272000 | 128000 | In: $5.50, Out: $33.00, Cache Read: $0.55 |
| openai.gpt-5.6-luna | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1050000 | 128000 | In: $0.22, Out: $1.32, Cache Read: $0.02, Cache Write: $0.28 |
| us.openai.gpt-5.6-luna | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1050000 | 128000 | In: $0.22, Out: $1.32, Cache Read: $0.02, Cache Write: $0.28 |
| global.openai.gpt-5.6-luna | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1050000 | 128000 | In: $0.22, Out: $1.32, Cache Read: $0.02, Cache Write: $0.28 |
| openai.gpt-5.6-sol | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1050000 | 128000 | In: $5.50, Out: $33.00, Cache Read: $0.55, Cache Write: $6.88 |
| us.openai.gpt-5.6-sol | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1050000 | 128000 | In: $5.50, Out: $33.00, Cache Read: $0.55, Cache Write: $6.88 |
| global.openai.gpt-5.6-sol | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1050000 | 128000 | In: $5.50, Out: $33.00, Cache Read: $0.55, Cache Write: $6.88 |
| openai.gpt-5.6-terra | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1050000 | 128000 | In: $2.20, Out: $13.20, Cache Read: $0.22, Cache Write: $2.75 |
| us.openai.gpt-5.6-terra | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1050000 | 128000 | In: $2.20, Out: $13.20, Cache Read: $0.22, Cache Write: $2.75 |
| global.openai.gpt-5.6-terra | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1050000 | 128000 | In: $2.20, Out: $13.20, Cache Read: $0.22, Cache Write: $2.75 |
| google.gemma-3-4b-it | bedrock | In: text, image; Out: text | function_calling, vision, streaming | 128000 | 4096 | In: $0.04, Out: $0.08 |
| google.gemma-3-12b-it | bedrock | In: text, image; Out: text | structured_output, vision, streaming | 131072 | 8192 | In: $0.05, Out: $0.10 |
| google.gemma-3-27b-it | bedrock | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 202752 | 8192 | In: $0.12, Out: $0.20 |
| xai.grok-4.3 | bedrock | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 131072 | In: $1.25, Out: $2.50, Cache Read: $0.20 |
| us.xai.grok-4.6 | bedrock | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 500000 | 500000 | In: $2.20, Out: $6.60, Cache Read: $0.55 |
| xai.grok-4.6 | bedrock | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 500000 | 500000 | In: $2.20, Out: $6.60, Cache Read: $0.55 |
| moonshotai.kimi-k2.5 | bedrock | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 262143 | 16000 | In: $0.60, Out: $3.00 |
| meta.llama4-maverick-17b-instruct-v1:0 | bedrock | In: text, image; Out: text | function_calling, vision | 1000000 | 16384 | In: $0.24, Out: $0.97 |
| us.meta.llama4-maverick-17b-instruct-v1:0 | bedrock | In: text, image; Out: text | function_calling, vision, streaming | 1000000 | 16384 | In: $0.24, Out: $0.97 |
| meta.llama4-scout-17b-instruct-v1:0 | bedrock | In: text, image; Out: text | function_calling, vision | 3500000 | 16384 | In: $0.17, Out: $0.66 |
| us.meta.llama4-scout-17b-instruct-v1:0 | bedrock | In: text, image; Out: text | function_calling, vision, streaming | 3500000 | 16384 | In: $0.17, Out: $0.66 |
| mistral.magistral-small-2509 | bedrock | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 128000 | 40000 | In: $0.50, Out: $1.50 |
| mistral.ministral-3-3b-instruct | bedrock | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 256000 | 8192 | In: $0.10, Out: $0.10 |
| mistral.mistral-large-3-675b-instruct | bedrock | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 256000 | 8192 | In: $0.50, Out: $1.50 |
| nvidia.nemotron-nano-12b-v2 | bedrock | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 128000 | 4096 | In: $0.20, Out: $0.60 |
| amazon.nova-2-lite-v1:0 | bedrock | In: text, image, video; Out: text | function_calling, reasoning, vision, video | 128000 | 4096 | In: $0.33, Out: $2.75 |
| us.amazon.nova-2-lite-v1:0 | bedrock | In: text, image, video; Out: text | function_calling, reasoning, vision, video, streaming | 128000 | 4096 | In: $0.33, Out: $2.75 |
| amazon.nova-lite-v1:0 | bedrock | In: text, image, video; Out: text | function_calling, vision, video, streaming | 300000 | 8192 | In: $0.06, Out: $0.24, Cache Read: $0.02 |
| amazon.nova-premier-v1:0:1000k | bedrock | In: text, image, video; Out: text | streaming, function_calling | - | - | - |
| amazon.nova-premier-v1:0:20k | bedrock | In: text, image, video; Out: text | streaming, function_calling | - | - | - |
| amazon.nova-premier-v1:0:8k | bedrock | In: text, image, video; Out: text | streaming, function_calling | - | - | - |
| amazon.nova-premier-v1:0:mm | bedrock | In: text, image, video; Out: text | streaming, function_calling | - | - | - |
| us.amazon.nova-premier-v1:0 | bedrock | In: text, image, video; Out: text | streaming, function_calling | - | - | - |
| amazon.nova-pro-v1:0 | bedrock | In: text, image, video; Out: text | function_calling, vision, video | 300000 | 8192 | In: $0.80, Out: $3.20, Cache Read: $0.20 |
| us.amazon.nova-pro-v1:0 | bedrock | In: text, image, video; Out: text | function_calling, vision, video, streaming | 300000 | 8192 | In: $0.80, Out: $3.20, Cache Read: $0.20 |
| mistral.pixtral-large-2502-v1:0 | bedrock | In: text, image; Out: text | function_calling, vision | 128000 | 8192 | In: $2.00, Out: $6.00 |
| us.mistral.pixtral-large-2502-v1:0 | bedrock | In: text, image; Out: text | function_calling, vision, streaming | 128000 | 8192 | In: $2.00, Out: $6.00 |
| qwen.qwen3-vl-235b-a22b | bedrock | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 262000 | 262000 | In: $0.30, Out: $1.50 |
| stability.sd3-5-large-v1:0 | bedrock | In: text, image; Out: image | - | - | - | - |
| us.stability.stable-conservative-upscale-v1:0 | bedrock | In: text, image; Out: image | - | - | - | - |
| us.stability.stable-image-control-sketch-v1:0 | bedrock | In: text, image; Out: image | - | - | - | - |
| us.stability.stable-image-control-structure-v1:0 | bedrock | In: text, image; Out: image | - | - | - | - |
| us.stability.stable-creative-upscale-v1:0 | bedrock | In: text, image; Out: image | - | - | - | - |
| us.stability.stable-image-erase-object-v1:0 | bedrock | In: text, image; Out: image | - | - | - | - |
| us.stability.stable-fast-upscale-v1:0 | bedrock | In: text, image; Out: image | - | - | - | - |
| us.stability.stable-image-inpaint-v1:0 | bedrock | In: text, image; Out: image | - | - | - | - |
| us.stability.stable-outpaint-v1:0 | bedrock | In: text, image; Out: image | - | - | - | - |
| us.stability.stable-image-remove-background-v1:0 | bedrock | In: text, image; Out: image | - | - | - | - |
| us.stability.stable-image-search-recolor-v1:0 | bedrock | In: text, image; Out: image | - | - | - | - |
| us.stability.stable-image-search-replace-v1:0 | bedrock | In: text, image; Out: image | - | - | - | - |
| us.stability.stable-image-style-guide-v1:0 | bedrock | In: text, image; Out: image | - | - | - | - |
| us.stability.stable-style-transfer-v1:0 | bedrock | In: text, image; Out: image | - | - | - | - |
| amazon.titan-embed-image-v1 | bedrock | In: text, image; Out: embeddings | - | - | - | - |
| amazon.titan-embed-image-v1:0 | bedrock | In: text, image; Out: embeddings | - | - | - | - |
| writer.palmyra-vision-7b | bedrock | In: text, image; Out: text | streaming, function_calling | - | 4096 | - |
| c4ai-aya-vision-32b | cohere | In: text, image; Out: text | vision, streaming | 16000 | 4000 | In: $0.50, Out: $1.50 |
| c4ai-aya-vision-8b | cohere | In: text, image; Out: text | vision | 16000 | 4000 | - |
| command-a-plus-05-2026 | cohere | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming, citations | 128000 | 64000 | In: $2.50, Out: $10.00 |
| command-a-vision-07-2025 | cohere | In: text, image; Out: text | vision, streaming | 128000 | 8000 | In: $2.50, Out: $10.00 |
| embed-english-light-v3.0 | cohere | In: text, image; Out: embeddings | - | 512 | - | - |
| embed-english-light-v3.0-image | cohere | In: text, image; Out: embeddings | - | 0 | - | - |
| embed-english-v3.0 | cohere | In: text, image; Out: embeddings | - | 512 | - | - |
| embed-english-v3.0-image | cohere | In: text, image; Out: embeddings | - | 0 | - | - |
| embed-multilingual-light-v3.0 | cohere | In: text, image; Out: embeddings | - | 512 | - | - |
| embed-multilingual-light-v3.0-image | cohere | In: text, image; Out: embeddings | - | 0 | - | - |
| embed-multilingual-v3.0 | cohere | In: text, image; Out: embeddings | - | 512 | - | - |
| embed-multilingual-v3.0-image | cohere | In: text, image; Out: embeddings | - | 0 | - | - |
| embed-v4.0 | cohere | In: text, image; Out: embeddings | - | 8192 | - | - |
| deep-research-max-preview-04-2026 | gemini | In: text, image, video, audio, pdf; Out: text, image | function_calling, reasoning, vision, video, transcription | 131072 | 65536 | In: $2.00, Out: $12.00, Cache Read: $0.20 |
| deep-research-preview-04-2026 | gemini | In: text, image, video, audio, pdf; Out: text, image | function_calling, reasoning, vision, video, transcription | 131072 | 65536 | In: $2.00, Out: $12.00, Cache Read: $0.20 |
| gemini-2.5-computer-use-preview-10-2025 | gemini | In: text, image; Out: text | function_calling, reasoning, vision, tool_choice, structured_output | 131072 | 65536 | In: $1.25, Out: $10.00 |
| gemini-2.5-flash | gemini | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription, tool_choice | 1048576 | 65536 | In: $0.30, Out: $2.50, Cache Read: $0.03 |
| gemini-2.5-flash-lite | gemini | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription | 1048576 | 65536 | In: $0.10, Out: $0.40, Cache Read: $0.01 |
| gemini-2.5-pro | gemini | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription, tool_choice | 1048576 | 65536 | In: $1.25, Out: $10.00, Cache Read: $0.12 |
| gemini-3-flash-preview | gemini | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription, tool_choice | 1048576 | 65536 | In: $0.50, Out: $3.00, Cache Read: $0.05 |
| gemini-3.1-flash-lite | gemini | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription | 1048576 | 65536 | In: $0.25, Out: $1.50, Cache Read: $0.02 |
| gemini-3.1-flash-lite-preview | gemini | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription | 1048576 | 65536 | In: $0.25, Out: $1.50, Cache Read: $0.02 |
| gemini-3.1-flash-live-preview | gemini | In: text, image, video, audio; Out: text, audio | function_calling, reasoning, vision, video, transcription, tool_choice | 131072 | 65536 | In: $0.75, Out: $4.50 |
| gemini-3.1-pro-preview | gemini | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription, tool_choice | 1048576 | 65536 | In: $2.00, Out: $12.00, Cache Read: $0.20 |
| gemini-3.1-pro-preview-customtools | gemini | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription, tool_choice | 1048576 | 65536 | In: $2.00, Out: $12.00, Cache Read: $0.20 |
| gemini-3.5-flash | gemini | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription, tool_choice | 1048576 | 65536 | In: $1.50, Out: $9.00, Cache Read: $0.15 |
| gemini-3.5-flash-lite | gemini | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription | 1048576 | 65536 | In: $0.30, Out: $2.50, Cache Read: $0.03 |
| gemini-3.6-flash | gemini | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription, tool_choice | 1048576 | 65536 | In: $1.50, Out: $7.50, Cache Read: $0.15 |
| gemini-3.7-flash | gemini | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription, tool_choice | 1048576 | 65536 | In: $0.75, Out: $3.75, Cache Read: $0.08 |
| gemini-embedding-2 | gemini | In: text, image, audio, video, pdf; Out: embeddings | vision, video, tool_choice, structured_output | 8192 | 1 | In: $0.20, Out: $0.00 |
| gemini-flash-latest | gemini | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription, tool_choice | 1048576 | 65536 | In: $1.50, Out: $9.00, Cache Read: $0.15 |
| gemini-flash-lite-latest | gemini | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription | 1048576 | 65536 | In: $0.25, Out: $1.50, Cache Read: $0.02 |
| gemini-omni-flash-preview | gemini | In: text, image, video; Out: video | reasoning, vision, video, tool_choice, structured_output | 131072 | 65536 | In: $1.50, Out: $17.50 |
| gemini-robotics-er-1.6-preview | gemini | In: text, image, video, audio; Out: text | function_calling, structured_output, reasoning, vision, video, transcription, tool_choice | 131072 | 65536 | In: $1.00, Out: $5.00 |
| gemma-4-26b-a4b-it | gemini | In: text, image; Out: text | function_calling, structured_output, reasoning, vision | 262144 | 32768 | In: $0.08, Out: $0.30 |
| gemma-4-31b-it | gemini | In: text, image; Out: text | function_calling, structured_output, reasoning, vision | 262144 | 32768 | In: $0.08, Out: $0.30 |
| lyria-3-clip-preview | gemini | In: text, image; Out: text, audio | vision | 1048576 | 65536 | In: $0.00, Out: $0.00 |
| lyria-3-pro-preview | gemini | In: text, image; Out: text, audio | vision, tool_choice | 1048576 | 65536 | In: $0.00, Out: $0.00 |
| gemini-2.5-flash-image | gemini | In: text, image; Out: text, image | reasoning, vision, tool_choice, structured_output | 32768 | 32768 | In: $0.30, Out: $30.00, Cache Read: $0.08 |
| gemini-3.1-flash-image | gemini | In: text, image, video, pdf; Out: text, image | reasoning, vision, video, tool_choice, structured_output | 65536 | 65536 | In: $0.50, Out: $60.00 |
| gemini-3.1-flash-image-preview | gemini | In: text, image, pdf; Out: text, image | reasoning, vision, tool_choice, structured_output | 65536 | 65536 | In: $0.50, Out: $60.00 |
| gemini-3.1-flash-lite-image | gemini | In: text, image; Out: text, image | function_calling, reasoning, vision | 65536 | 65536 | In: $0.25, Out: $30.00 |
| gemini-3-pro-image | gemini | In: text, image; Out: text, image | reasoning, vision, tool_choice, structured_output | 131072 | 32768 | In: $2.00, Out: $120.00 |
| gemini-3-pro-image-preview | gemini | In: text, image; Out: text, image | reasoning, vision, tool_choice, structured_output | 131072 | 32768 | In: $2.00, Out: $120.00 |
| veo-3.1-generate-preview | gemini | In: text, image; Out: video | vision | 480 | 8192 | In: $0.08, Out: $0.30 |
| veo-3.1-fast-generate-preview | gemini | In: text, image, video; Out: video | vision, video | 480 | 8192 | In: $0.08, Out: $0.30 |
| veo-3.1-lite-generate-preview | gemini | In: text, image; Out: video | vision | 480 | 8192 | In: $0.08, Out: $0.30 |
| labs-devstral-small-2512 | mistral | In: text, image; Out: text | function_calling, vision | 256000 | 256000 | In: $0.00, Out: $0.00 |
| labs-leanstral-1-5 | mistral | In: text, image; Out: text | streaming, function_calling, tool_choice, parallel_tool_calls, structured_output, batch, reasoning, vision | 262144 | 8192 | - |
| labs-leanstral-1-5-1 | mistral | In: text, image; Out: text | streaming, function_calling, tool_choice, parallel_tool_calls, structured_output, batch, reasoning, vision | 262144 | 8192 | - |
| magistral-small-latest | mistral | In: text, image; Out: text | streaming, function_calling, tool_choice, parallel_tool_calls, structured_output, reasoning, batch, vision | 262144 | 8192 | - |
| ministral-14b-2512 | mistral | In: text, image; Out: text | streaming, function_calling, tool_choice, parallel_tool_calls, structured_output, batch, distillation, fine_tuning, vision | 262144 | 8192 | - |
| ministral-14b-latest | mistral | In: text, image; Out: text | streaming, function_calling, tool_choice, parallel_tool_calls, structured_output, batch, distillation, fine_tuning, vision | 262144 | 8192 | - |
| ministral-3b-2512 | mistral | In: text, image; Out: text | streaming, function_calling, tool_choice, parallel_tool_calls, structured_output, batch, distillation, fine_tuning, vision | 131072 | 8192 | - |
| ministral-8b-2512 | mistral | In: text, image; Out: text | streaming, function_calling, tool_choice, parallel_tool_calls, structured_output, batch, distillation, fine_tuning, vision | 262144 | 8192 | - |
| mistral-large-latest | mistral | In: text, image; Out: text | function_calling, vision, streaming, tool_choice, parallel_tool_calls, structured_output, batch, fine_tuning | 262144 | 262144 | In: $0.50, Out: $1.50 |
| mistral-large-2512 | mistral | In: text, image; Out: text | function_calling, vision, streaming, tool_choice, parallel_tool_calls, structured_output, batch, fine_tuning | 262144 | 262144 | In: $0.50, Out: $1.50 |
| mistral-medium | mistral | In: text, image; Out: text | streaming, function_calling, tool_choice, parallel_tool_calls, structured_output, batch, reasoning, vision | 262144 | 8192 | - |
| mistral-medium-3 | mistral | In: text, image; Out: text | streaming, function_calling, tool_choice, parallel_tool_calls, structured_output, reasoning, batch, vision | 262144 | 8192 | - |
| mistral-medium-3-5 | mistral | In: text, image; Out: text | streaming, function_calling, tool_choice, parallel_tool_calls, structured_output, reasoning, batch, vision | 262144 | 8192 | - |
| mistral-medium-3.5 | mistral | In: text, image; Out: text | streaming, function_calling, tool_choice, parallel_tool_calls, structured_output, reasoning, batch, vision | 262144 | 8192 | - |
| mistral-medium-latest | mistral | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming, tool_choice, parallel_tool_calls, batch | 262144 | 262144 | In: $1.50, Out: $7.50 |
| mistral-medium-2505 | mistral | In: text, image; Out: text | function_calling, vision, streaming, tool_choice, parallel_tool_calls, structured_output, batch, fine_tuning | 131072 | 131072 | In: $0.40, Out: $2.00 |
| mistral-medium-2508 | mistral | In: text, image; Out: text | function_calling, vision, streaming, tool_choice, parallel_tool_calls, structured_output, batch, fine_tuning | 262144 | 262144 | In: $0.40, Out: $2.00 |
| mistral-medium-2604 | mistral | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming, tool_choice, parallel_tool_calls, batch | 262144 | 262144 | In: $1.50, Out: $7.50 |
| mistral-ocr-2512 | mistral | In: text, image; Out: text | vision, function_calling | 16384 | 8192 | - |
| mistral-ocr-3 | mistral | In: text, image; Out: text | vision, function_calling | 16384 | 8192 | - |
| mistral-ocr-3-0 | mistral | In: text, image; Out: text | vision, function_calling | 16384 | 8192 | - |
| mistral-ocr-4 | mistral | In: text, image; Out: text | vision, function_calling | 16384 | 8192 | - |
| mistral-ocr-4-0 | mistral | In: text, image; Out: text | vision, function_calling | 16384 | 8192 | - |
| mistral-ocr-4-1 | mistral | In: text, image; Out: text | vision, function_calling | 16384 | 8192 | - |
| mistral-ocr-latest | mistral | In: text, image; Out: text | vision, function_calling | 16384 | 8192 | - |
| mistral-small-latest | mistral | In: text, image; Out: text | function_calling, reasoning, vision, streaming, tool_choice, parallel_tool_calls, structured_output, batch | 256000 | 256000 | In: $0.15, Out: $0.60 |
| mistral-small-2506 | mistral | In: text, image; Out: text | function_calling, vision | 128000 | 16384 | In: $0.10, Out: $0.30 |
| mistral-small-2603 | mistral | In: text, image; Out: text | function_calling, reasoning, vision, streaming, tool_choice, parallel_tool_calls, structured_output, batch | 256000 | 256000 | In: $0.15, Out: $0.60 |
| mistral-vibe-cli-fast | mistral | In: text, image; Out: text | streaming, function_calling, tool_choice, parallel_tool_calls, structured_output, batch, reasoning, vision | 262144 | 8192 | - |
| mistral-vibe-cli-latest | mistral | In: text, image; Out: text | streaming, function_calling, tool_choice, parallel_tool_calls, structured_output, batch, reasoning, vision | 262144 | 8192 | - |
| mistral-vibe-cli-with-tools | mistral | In: text, image; Out: text | streaming, function_calling, tool_choice, parallel_tool_calls, structured_output, batch, reasoning, vision | 262144 | 8192 | - |
| pixtral-12b | mistral | In: text, image; Out: text | function_calling, vision | 128000 | 128000 | In: $0.15, Out: $0.15 |
| pixtral-large-latest | mistral | In: text, image; Out: text | function_calling, vision | 128000 | 128000 | In: $2.00, Out: $6.00 |
| gemma4:31b | ollama_cloud | In: text, image; Out: text | function_calling, reasoning, vision, streaming | 262144 | 262144 | - |
| kimi-k2.5 | ollama_cloud | In: text, image; Out: text | function_calling, reasoning, vision | 262144 | 262144 | - |
| kimi-k2.6 | ollama_cloud | In: text, image; Out: text | function_calling, reasoning, vision, streaming | 262144 | 262144 | - |
| kimi-k2.7-code | ollama_cloud | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 262144 | 262144 | - |
| kimi-k3 | ollama_cloud | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1048576 | 131072 | - |
| minimax-m3 | ollama_cloud | In: text, image, video; Out: text | function_calling, reasoning, vision, video, streaming | 512000 | 131072 | - |
| mistral-large-3:675b | ollama_cloud | In: text, image; Out: text | function_calling, vision, streaming | 262144 | 262144 | - |
| qwen3.5:397b | ollama_cloud | In: text, image; Out: text | function_calling, reasoning, vision, streaming | 262144 | 65536 | - |
| gpt-4-turbo | openai | In: text, image; Out: text | function_calling, vision, tool_choice, parallel_tool_calls | 128000 | 4096 | In: $10.00, Out: $30.00 |
| gpt-4.1 | openai | In: text, image, pdf; Out: text | function_calling, structured_output, vision, tool_choice, parallel_tool_calls | 1047576 | 32768 | In: $2.00, Out: $8.00, Cache Read: $0.50 |
| gpt-4.1-mini | openai | In: text, image, pdf; Out: text | function_calling, structured_output, vision, tool_choice, parallel_tool_calls | 1047576 | 32768 | In: $0.40, Out: $1.60, Cache Read: $0.10 |
| gpt-4.1-nano | openai | In: text, image; Out: text | function_calling, structured_output, vision, tool_choice, parallel_tool_calls | 1047576 | 32768 | In: $0.10, Out: $0.40, Cache Read: $0.02 |
| gpt-4o | openai | In: text, image, pdf; Out: text | function_calling, structured_output, vision, tool_choice, parallel_tool_calls | 128000 | 16384 | In: $2.50, Out: $10.00, Cache Read: $1.25 |
| gpt-4o-2024-05-13 | openai | In: text, image; Out: text | function_calling, structured_output, vision, tool_choice, parallel_tool_calls | 128000 | 4096 | In: $5.00, Out: $15.00 |
| gpt-4o-2024-08-06 | openai | In: text, image; Out: text | function_calling, structured_output, vision, tool_choice, parallel_tool_calls | 128000 | 16384 | In: $2.50, Out: $10.00, Cache Read: $1.25 |
| gpt-4o-2024-11-20 | openai | In: text, image; Out: text | function_calling, structured_output, vision, tool_choice, parallel_tool_calls | 128000 | 16384 | In: $2.50, Out: $10.00, Cache Read: $1.25 |
| gpt-4o-mini | openai | In: text, image, pdf; Out: text | function_calling, structured_output, vision, tool_choice, parallel_tool_calls | 128000 | 16384 | In: $0.15, Out: $0.60, Cache Read: $0.08 |
| gpt-5 | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, tool_choice, parallel_tool_calls | 400000 | 128000 | In: $1.25, Out: $10.00, Cache Read: $0.12 |
| gpt-5-mini | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, tool_choice, parallel_tool_calls | 400000 | 128000 | In: $0.25, Out: $2.00, Cache Read: $0.02 |
| gpt-5-nano | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, tool_choice, parallel_tool_calls | 400000 | 128000 | In: $0.05, Out: $0.40, Cache Read: $0.01 |
| gpt-5-pro | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, tool_choice, parallel_tool_calls | 400000 | 272000 | In: $15.00, Out: $120.00 |
| gpt-5.1 | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, tool_choice, parallel_tool_calls | 400000 | 128000 | In: $1.25, Out: $10.00, Cache Read: $0.12 |
| gpt-5.2 | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, tool_choice, parallel_tool_calls | 400000 | 128000 | In: $1.75, Out: $14.00, Cache Read: $0.18 |
| gpt-5.2-chat-latest | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, tool_choice, parallel_tool_calls | 128000 | 16384 | In: $1.75, Out: $14.00, Cache Read: $0.18 |
| gpt-5.2-pro | openai | In: text, image; Out: text | function_calling, reasoning, vision, tool_choice, parallel_tool_calls | 400000 | 128000 | In: $21.00, Out: $168.00 |
| gpt-5.3-chat-latest | openai | In: text, image; Out: text | function_calling, structured_output, vision, tool_choice, parallel_tool_calls | 128000 | 16384 | In: $1.75, Out: $14.00, Cache Read: $0.18 |
| gpt-5.3-codex | openai | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, tool_choice, parallel_tool_calls | 400000 | 128000 | In: $1.75, Out: $14.00, Cache Read: $0.18 |
| gpt-5.3-codex-spark | openai | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 128000 | 32000 | In: $1.75, Out: $14.00, Cache Read: $0.18 |
| gpt-5.4 | openai | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, tool_choice, parallel_tool_calls | 1050000 | 128000 | In: $2.50, Out: $15.00, Cache Read: $0.25 |
| gpt-5.4-pro | openai | In: text, image; Out: text | function_calling, reasoning, vision, tool_choice, parallel_tool_calls | 1050000 | 128000 | In: $30.00, Out: $180.00 |
| gpt-5.4-mini | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, tool_choice, parallel_tool_calls | 400000 | 128000 | In: $0.75, Out: $4.50, Cache Read: $0.08 |
| gpt-5.4-nano | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, tool_choice, parallel_tool_calls | 400000 | 128000 | In: $0.20, Out: $1.25, Cache Read: $0.02 |
| gpt-5.5 | openai | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, tool_choice, parallel_tool_calls | 1050000 | 128000 | In: $5.00, Out: $30.00, Cache Read: $0.50 |
| gpt-5.5-pro | openai | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, tool_choice, parallel_tool_calls | 1050000 | 128000 | In: $30.00, Out: $180.00 |
| gpt-5.6 | openai | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1050000 | 128000 | In: $5.00, Out: $30.00, Cache Read: $0.50, Cache Write: $6.25 |
| gpt-5.6-luna | openai | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, tool_choice, parallel_tool_calls | 1050000 | 128000 | In: $0.20, Out: $1.20, Cache Read: $0.02, Cache Write: $0.25 |
| gpt-5.6-sol | openai | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, tool_choice, parallel_tool_calls | 1050000 | 128000 | In: $5.00, Out: $30.00, Cache Read: $0.50, Cache Write: $6.25 |
| gpt-5.6-terra | openai | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, tool_choice, parallel_tool_calls | 1050000 | 128000 | In: $2.00, Out: $12.00, Cache Read: $0.20, Cache Write: $2.50 |
| gpt-realtime-2.1 | openai | In: text, audio, image; Out: text, audio | function_calling, reasoning, vision | 128000 | 32000 | In: $4.00, Out: $24.00, Cache Read: $0.40 |
| chatgpt-image-latest | openai | In: text, image; Out: text, image | vision | 0 | 0 | In: $0.50, Out: $1.50 |
| gpt-image-1 | openai | In: text, image; Out: image | vision | 0 | 0 | In: $5.00, Cache Read: $1.25 |
| gpt-image-1-mini | openai | In: text, image; Out: text, image | vision | 0 | 0 | In: $2.00, Cache Read: $0.20 |
| gpt-image-1.5 | openai | In: text, image; Out: text, image | vision | 0 | 0 | In: $5.00, Cache Read: $1.25 |
| gpt-image-2 | openai | In: text, image; Out: image | vision | 0 | 0 | In: $5.00, Out: $30.00, Cache Read: $1.25 |
| o1 | openai | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, tool_choice, parallel_tool_calls | 200000 | 100000 | In: $15.00, Out: $60.00, Cache Read: $7.50 |
| o1-pro | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, tool_choice, parallel_tool_calls | 200000 | 100000 | In: $150.00, Out: $600.00 |
| o3 | openai | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 200000 | 100000 | In: $2.00, Out: $8.00, Cache Read: $0.50 |
| o3-pro | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision | 200000 | 100000 | In: $20.00, Out: $80.00 |
| o4-mini | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision | 200000 | 100000 | In: $1.10, Out: $4.40, Cache Read: $0.28 |
| ~anthropic/claude-haiku-latest | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 64000 | In: $1.00, Out: $5.00, Cache Read: $0.10, Cache Write: $1.25 |
| ~anthropic/claude-sonnet-latest | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 128000 | In: $2.00, Out: $10.00, Cache Read: $0.20, Cache Write: $2.50 |
| anthropic/claude-fable-5:batch | openrouter | In: text, image, file; Out: text | streaming, function_calling, structured_output | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| anthropic/claude-haiku-4.5:batch | openrouter | In: text, image, file; Out: text | streaming, function_calling, structured_output | 200000 | 64000 | In: $0.50, Out: $2.50, Cache Read: $0.05, Cache Write: $0.62 |
| anthropic/claude-opus-4.1:batch | openrouter | In: image, text, file; Out: text | streaming, function_calling, structured_output | 200000 | 32000 | In: $7.50, Out: $37.50, Cache Read: $0.75, Cache Write: $9.38 |
| anthropic/claude-opus-4.5:batch | openrouter | In: file, image, text; Out: text | streaming, function_calling, structured_output | 200000 | 64000 | In: $2.50, Out: $12.50, Cache Read: $0.25, Cache Write: $3.12 |
| anthropic/claude-opus-4.6:batch | openrouter | In: text, image, file; Out: text | streaming, function_calling, structured_output | 1000000 | 128000 | In: $2.50, Out: $12.50, Cache Read: $0.25, Cache Write: $3.12 |
| anthropic/claude-opus-4.7:batch | openrouter | In: text, image, file; Out: text | streaming, function_calling, structured_output | 1000000 | 128000 | In: $2.50, Out: $12.50, Cache Read: $0.25, Cache Write: $3.12 |
| anthropic/claude-opus-4.8:batch | openrouter | In: text, image, file; Out: text | streaming, function_calling, structured_output | 1000000 | 128000 | In: $2.50, Out: $12.50, Cache Read: $0.25, Cache Write: $3.12 |
| anthropic/claude-sonnet-4.5:batch | openrouter | In: text, image, file; Out: text | streaming, function_calling, structured_output | 1000000 | 64000 | In: $1.50, Out: $7.50, Cache Read: $0.15, Cache Write: $1.88 |
| anthropic/claude-sonnet-4.6:batch | openrouter | In: text, image, file; Out: text | streaming, function_calling, structured_output | 1000000 | 128000 | In: $1.50, Out: $7.50, Cache Read: $0.15, Cache Write: $1.88 |
| anthropic/claude-sonnet-5:batch | openrouter | In: text, image, file; Out: text | streaming, function_calling, structured_output | 1000000 | 128000 | In: $1.00, Out: $5.00, Cache Read: $0.10, Cache Write: $1.25 |
| openrouter/auto | openrouter | In: text, image, audio, pdf, video; Out: text, image | function_calling, structured_output, reasoning, vision, video, streaming, predicted_outputs, image_generation | 2000000 | 2000000 | - |
| openrouter/auto-beta | openrouter | In: text, image, audio, file, video; Out: text, image | streaming, function_calling, structured_output, predicted_outputs, image_generation | 2000000 | - | - |
| black-forest-labs/flux.2-flex | openrouter | In: text, image; Out: image | streaming, image_generation | - | - | - |
| black-forest-labs/flux.2-klein-4b | openrouter | In: text, image; Out: image | streaming, image_generation | - | - | - |
| black-forest-labs/flux.2-max | openrouter | In: text, image; Out: image | streaming, image_generation | - | - | - |
| black-forest-labs/flux.2-pro | openrouter | In: text, image; Out: image | streaming, image_generation | - | - | - |
| bytedance-seed/seedream-4.5 | openrouter | In: image, text; Out: image | streaming, image_generation | - | - | - |
| bytedance-seed/seedream-5-0-lite | openrouter | In: text, image; Out: image | streaming, image_generation | - | - | - |
| bytedance-seed/seedream-5-0-pro | openrouter | In: text, image; Out: image | streaming, image_generation | - | - | - |
| anthropic/claude-3-haiku | openrouter | In: text, image; Out: text | function_calling, vision, streaming | 200000 | 4096 | In: $0.25, Out: $1.25, Cache Read: $0.03, Cache Write: $0.30 |
| anthropic/claude-fable-5 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 128000 | In: $10.00, Out: $50.00, Cache Read: $1.00, Cache Write: $12.50 |
| ~anthropic/claude-fable-latest | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 128000 | In: $10.00, Out: $50.00, Cache Read: $1.00, Cache Write: $12.50 |
| anthropic/claude-haiku-4.5 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 64000 | In: $1.00, Out: $5.00, Cache Read: $0.10, Cache Write: $1.25 |
| anthropic/claude-opus-4 | openrouter | In: image, text, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 32000 | In: $15.00, Out: $75.00, Cache Read: $1.50, Cache Write: $18.75 |
| anthropic/claude-opus-4.1 | openrouter | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 32000 | In: $15.00, Out: $75.00, Cache Read: $1.50, Cache Write: $18.75 |
| anthropic/claude-opus-4.5 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 64000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| anthropic/claude-opus-4.6 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| anthropic/claude-opus-4.7 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| anthropic/claude-opus-4.7-fast | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 128000 | In: $30.00, Out: $150.00, Cache Read: $3.00, Cache Write: $37.50 |
| anthropic/claude-opus-4.8 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| anthropic/claude-opus-4.8-fast | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 128000 | In: $10.00, Out: $50.00, Cache Read: $1.00, Cache Write: $12.50 |
| anthropic/claude-opus-5 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| anthropic/claude-opus-5-fast | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 128000 | In: $10.00, Out: $50.00, Cache Read: $1.00, Cache Write: $12.50 |
| anthropic/claude-opus-5:batch | openrouter | In: text, image, file; Out: text | streaming, function_calling, structured_output | 1000000 | 128000 | In: $2.50, Out: $12.50, Cache Read: $0.25, Cache Write: $3.12 |
| ~anthropic/claude-opus-latest | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| anthropic/claude-sonnet-4 | openrouter | In: image, text, pdf; Out: text | function_calling, reasoning, vision, streaming | 1000000 | 64000 | In: $3.00, Out: $15.00, Cache Read: $0.30, Cache Write: $3.75 |
| anthropic/claude-sonnet-4.5 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 64000 | In: $3.00, Out: $15.00, Cache Read: $0.30, Cache Write: $3.75 |
| anthropic/claude-sonnet-4.6 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 128000 | In: $3.00, Out: $15.00, Cache Read: $0.30, Cache Write: $3.75 |
| anthropic/claude-sonnet-5 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 128000 | In: $2.00, Out: $10.00, Cache Read: $0.20, Cache Write: $2.50 |
| dots-studio/dots-3-note-preview:free | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 512000 | 512000 | In: $0.00, Out: $0.00 |
| baidu/ernie-4.5-vl-424b-a47b | openrouter | In: image, text; Out: text | reasoning, vision, streaming | 123000 | 16000 | In: $0.42, Out: $1.25 |
| openrouter/free | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 8000 | In: $0.00, Out: $0.00 |
| sakana/fugu-ultra | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 128000 | In: $5.00, Out: $30.00, Cache Read: $0.50 |
| z-ai/glm-4.5v | openrouter | In: text, image; Out: text | function_calling, reasoning, vision, streaming | 65536 | 16384 | In: $0.60, Out: $1.80, Cache Read: $0.11 |
| z-ai/glm-4.6v | openrouter | In: text, image, video; Out: text | function_calling, reasoning, vision, video, streaming | 131072 | 32768 | In: $0.30, Out: $0.90, Cache Read: $0.06 |
| z-ai/glm-5v-turbo | openrouter | In: image, text, video; Out: text | function_calling, reasoning, vision, video, streaming | 202752 | 131072 | In: $1.20, Out: $4.00, Cache Read: $0.24 |
| openai/gpt-chat-latest | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, vision, streaming | 400000 | 128000 | In: $5.00, Out: $30.00, Cache Read: $0.50 |
| openai/gpt-4-turbo | openrouter | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 128000 | 4096 | In: $10.00, Out: $30.00 |
| openai/gpt-4.1 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, vision, streaming | 1047576 | 32768 | In: $2.00, Out: $8.00, Cache Read: $0.50 |
| openai/gpt-4.1-mini | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, vision, streaming | 1047576 | 32768 | In: $0.40, Out: $1.60, Cache Read: $0.10 |
| openai/gpt-4.1-nano | openrouter | In: image, text, pdf; Out: text | function_calling, structured_output, vision, streaming | 1047576 | 32768 | In: $0.10, Out: $0.40, Cache Read: $0.02 |
| openai/gpt-4o | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, vision, streaming | 128000 | 16384 | In: $2.50, Out: $10.00, Cache Read: $1.25 |
| openai/gpt-4o-2024-05-13 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, vision, streaming | 128000 | 4096 | In: $5.00, Out: $15.00 |
| openai/gpt-4o-2024-08-06 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, vision, streaming | 128000 | 16384 | In: $2.50, Out: $10.00, Cache Read: $1.25 |
| openai/gpt-4o-2024-11-20 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, vision, streaming | 128000 | 16384 | In: $2.50, Out: $10.00, Cache Read: $1.25 |
| openai/gpt-4o-mini | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, vision, streaming | 128000 | 16384 | In: $0.15, Out: $0.60, Cache Read: $0.08 |
| openai/gpt-4o-mini-2024-07-18 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, vision, streaming | 128000 | 16384 | In: $0.15, Out: $0.60, Cache Read: $0.08 |
| openai/gpt-5 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $1.25, Out: $10.00, Cache Read: $0.12 |
| openai/gpt-5-image | openrouter | In: image, text, pdf; Out: image, text | structured_output, reasoning, vision, streaming, image_generation | 400000 | 128000 | In: $10.00, Out: $10.00, Cache Read: $1.25 |
| openai/gpt-5-image-mini | openrouter | In: pdf, image, text; Out: image, text | structured_output, reasoning, vision, streaming, image_generation | 400000 | 128000 | In: $2.50, Out: $2.00, Cache Read: $0.25 |
| openai/gpt-5-mini | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $0.25, Out: $2.00, Cache Read: $0.02 |
| openai/gpt-5-nano | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $0.05, Out: $0.40, Cache Read: $0.01 |
| openai/gpt-5-pro | openrouter | In: image, text, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $15.00, Out: $120.00 |
| openai/gpt-5.1 | openrouter | In: image, text, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $1.25, Out: $10.00, Cache Read: $0.12 |
| openai/gpt-5.1-codex | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $1.25, Out: $10.00, Cache Read: $0.13 |
| openai/gpt-5.1-codex-max | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $1.25, Out: $10.00, Cache Read: $0.12 |
| openai/gpt-5.1-codex-mini | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $0.25, Out: $2.00, Cache Read: $0.03 |
| openai/gpt-5.2 | openrouter | In: pdf, image, text; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $1.75, Out: $14.00, Cache Read: $0.18 |
| openai/gpt-5.2-chat | openrouter | In: pdf, image, text; Out: text | function_calling, structured_output, vision, streaming | 128000 | 32000 | In: $1.75, Out: $14.00, Cache Read: $0.18 |
| openai/gpt-5.2-codex | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $1.75, Out: $14.00, Cache Read: $0.18 |
| openai/gpt-5.2-pro | openrouter | In: image, text, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $21.00, Out: $168.00 |
| openai/gpt-5.3-codex | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $1.75, Out: $14.00, Cache Read: $0.18 |
| openai/gpt-5.4 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1050000 | 128000 | In: $2.50, Out: $15.00, Cache Read: $0.25 |
| openai/gpt-5.4-image-2 | openrouter | In: image, text, pdf; Out: image, text | structured_output, reasoning, vision, streaming, image_generation | 272000 | 128000 | In: $8.00, Out: $15.00, Cache Read: $2.00 |
| openai/gpt-5.4-pro | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1050000 | 128000 | In: $30.00, Out: $180.00 |
| openai/gpt-5.4-mini | openrouter | In: pdf, image, text; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $0.75, Out: $4.50, Cache Read: $0.08 |
| openai/gpt-5.4-nano | openrouter | In: pdf, image, text; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $0.20, Out: $1.25, Cache Read: $0.02 |
| openai/gpt-5.5 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1050000 | 128000 | In: $5.00, Out: $30.00, Cache Read: $0.50 |
| openai/gpt-5.5-pro | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1050000 | 128000 | In: $30.00, Out: $180.00 |
| openai/gpt-5.6-luna | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1050000 | 128000 | In: $0.20, Out: $1.20, Cache Read: $0.02, Cache Write: $0.25 |
| openai/gpt-5.6-luna-pro | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1050000 | 128000 | In: $0.20, Out: $1.20, Cache Read: $0.02, Cache Write: $0.25 |
| openai/gpt-5.6-sol | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1050000 | 128000 | In: $2.50, Out: $15.00, Cache Read: $0.25, Cache Write: $3.12 |
| openai/gpt-5.6-sol-pro | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1050000 | 128000 | In: $2.50, Out: $15.00, Cache Read: $0.25, Cache Write: $3.12 |
| openai/gpt-5.6-terra | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1050000 | 128000 | In: $2.00, Out: $12.00, Cache Read: $0.20, Cache Write: $2.50 |
| openai/gpt-5.6-terra-pro | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1050000 | 128000 | In: $2.00, Out: $12.00, Cache Read: $0.20, Cache Write: $2.50 |
| google/gemini-2.5-flash | openrouter | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1048576 | 65535 | In: $0.30, Out: $2.50, Cache Read: $0.03, Cache Write: $0.08 |
| google/gemini-2.5-flash-lite | openrouter | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1048576 | 65535 | In: $0.10, Out: $0.40, Cache Read: $0.01, Cache Write: $0.08 |
| google/gemini-2.5-pro | openrouter | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1048576 | 65536 | In: $1.25, Out: $10.00, Cache Read: $0.12, Cache Write: $0.38 |
| google/gemini-2.5-pro-preview-05-06 | openrouter | In: text, image, pdf, audio, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1048576 | 65535 | In: $1.25, Out: $10.00, Cache Read: $0.12, Cache Write: $0.38 |
| google/gemini-2.5-pro-preview | openrouter | In: pdf, image, text, audio; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1048576 | 65536 | In: $1.25, Out: $10.00, Cache Read: $0.12, Cache Write: $0.38 |
| google/gemini-3-flash-preview | openrouter | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1048576 | 65536 | In: $0.50, Out: $3.00, Cache Read: $0.05, Cache Write: $0.08 |
| google/gemini-3.1-flash-lite | openrouter | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1048576 | 65536 | In: $0.25, Out: $1.50, Cache Read: $0.02, Cache Write: $0.08 |
| google/gemini-3.1-flash-lite-preview | openrouter | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1048576 | 65536 | In: $0.25, Out: $1.50, Cache Read: $0.02, Cache Write: $0.08 |
| google/gemini-3.1-pro-preview | openrouter | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1048576 | 65536 | In: $2.00, Out: $12.00, Cache Read: $0.20, Cache Write: $0.38 |
| google/gemini-3.1-pro-preview-customtools | openrouter | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1048576 | 65536 | In: $2.00, Out: $12.00, Cache Read: $0.20, Cache Write: $0.38 |
| google/gemini-3.5-flash | openrouter | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1048576 | 65536 | In: $1.50, Out: $9.00, Cache Read: $0.15, Cache Write: $0.08 |
| google/gemini-3.5-flash-lite | openrouter | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1048576 | 65536 | In: $0.30, Out: $2.50, Cache Read: $0.03, Cache Write: $0.08 |
| google/gemini-3.6-flash | openrouter | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1048576 | 65536 | In: $0.75, Out: $3.75, Cache Read: $0.08, Cache Write: $0.04 |
| google/gemini-3.7-flash | openrouter | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1048576 | 65536 | In: $0.38, Out: $1.88, Cache Read: $0.04, Cache Write: $0.02 |
| google/gemma-3-12b-it | openrouter | In: text, image; Out: text | function_calling, structured_output, vision, streaming, predicted_outputs | 131072 | 16384 | In: $0.05, Out: $0.15 |
| google/gemma-3-27b-it | openrouter | In: text, image; Out: text | function_calling, structured_output, vision, streaming, predicted_outputs | 262144 | 131072 | In: $0.08, Out: $0.45, Cache Read: $0.04 |
| google/gemma-3-4b-it | openrouter | In: text, image; Out: text | structured_output, vision, streaming, predicted_outputs | 131072 | 16384 | In: $0.05, Out: $0.10 |
| google/gemma-4-26b-a4b-it:free | openrouter | In: image, text, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 262144 | 32768 | In: $0.00, Out: $0.00 |
| google/gemma-4-26b-a4b-it | openrouter | In: image, text, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming, predicted_outputs | 262144 | 16384 | In: $0.07, Out: $0.34 |
| google/gemma-4-31b-it:free | openrouter | In: image, text, video; Out: text | function_calling, reasoning, vision, video, streaming | 262144 | 32768 | In: $0.00, Out: $0.00 |
| google/gemma-4-31b-it | openrouter | In: image, text, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming, predicted_outputs | 262144 | 16384 | In: $0.09, Out: $0.34, Cache Read: $0.05 |
| ~google/gemini-flash-latest | openrouter | In: text, image, video, pdf, audio; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1048576 | 65536 | In: $0.38, Out: $1.88, Cache Read: $0.04, Cache Write: $0.02 |
| ~google/gemini-pro-latest | openrouter | In: audio, pdf, image, text, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1048576 | 65536 | In: $2.00, Out: $12.00, Cache Read: $0.20, Cache Write: $0.38 |
| google/gemini-2.5-flash:batch | openrouter | In: file, image, text, audio, video; Out: text | streaming, function_calling, structured_output | 1048576 | 65535 | In: $0.15, Out: $1.25, Cache Read: $0.03 |
| google/gemini-2.5-flash-lite:batch | openrouter | In: text, image, file, audio, video; Out: text | streaming, function_calling, structured_output | 1048576 | 65535 | In: $0.05, Out: $0.20, Cache Read: $0.01 |
| google/gemini-2.5-pro:batch | openrouter | In: text, image, file, audio, video; Out: text | streaming, function_calling, structured_output | 1048576 | 65536 | In: $0.62, Out: $5.00, Cache Read: $0.12 |
| google/gemini-3-flash-preview:batch | openrouter | In: text, image, file, audio, video; Out: text | streaming, function_calling, structured_output | 1048576 | 65536 | In: $0.25, Out: $1.50 |
| google/gemini-3.1-flash-lite:batch | openrouter | In: text, image, video, file, audio; Out: text | streaming, function_calling, structured_output | 1048576 | 65536 | In: $0.12, Out: $0.75, Cache Read: $0.01 |
| google/gemini-3.1-pro-preview:batch | openrouter | In: audio, file, image, text, video; Out: text | streaming, function_calling, structured_output | 1048576 | 65536 | In: $1.00, Out: $6.00 |
| google/gemini-3.5-flash:batch | openrouter | In: text, image, video, file, audio; Out: text | streaming, function_calling, structured_output | 1048576 | 65536 | In: $0.75, Out: $4.50, Cache Read: $0.08 |
| google/gemini-3.5-flash-lite:batch | openrouter | In: text, image, video, file, audio; Out: text | streaming, function_calling, structured_output | 1048576 | 65536 | In: $0.15, Out: $1.25, Cache Read: $0.02 |
| google/gemini-3.6-flash:batch | openrouter | In: text, image, video, file, audio; Out: text | streaming, function_calling, structured_output | 1048576 | 65536 | In: $0.38, Out: $1.88, Cache Read: $0.04, Cache Write: $0.04 |
| google/gemini-3.7-flash:batch | openrouter | In: text, image, video, file, audio; Out: text | streaming, function_calling, structured_output | 1048576 | 65536 | In: $0.19, Out: $0.94, Cache Read: $0.02, Cache Write: $0.02 |
| google/gemini-embedding-2 | openrouter | In: text, image, file, audio, video; Out: embeddings | streaming, structured_output | 8192 | - | In: $0.20 |
| google/gemini-embedding-2-preview | openrouter | In: text, image, file, audio, video; Out: embeddings | streaming, structured_output | 8192 | - | In: $0.20 |
| x-ai/grok-4.20 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 2000000 | 2000000 | In: $1.25, Out: $2.50, Cache Read: $0.20 |
| x-ai/grok-4.20-multi-agent | openrouter | In: text, image, pdf; Out: text | structured_output, reasoning, vision, streaming | 2000000 | 2000000 | In: $1.25, Out: $2.50, Cache Read: $0.20 |
| x-ai/grok-4.3 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 1000000 | In: $1.25, Out: $2.50, Cache Read: $0.20 |
| x-ai/grok-4.5 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 500000 | 500000 | In: $2.00, Out: $6.00, Cache Read: $0.30 |
| x-ai/grok-4.6 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 500000 | 500000 | In: $2.00, Out: $6.00, Cache Read: $0.50 |
| x-ai/grok-build-0.1 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 256000 | 256000 | In: $1.00, Out: $2.00, Cache Read: $0.20 |
| ~x-ai/grok-latest | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 500000 | 1000000 | In: $2.00, Out: $6.00, Cache Read: $0.50 |
| thinkingmachines/inkling | openrouter | In: text, image, audio; Out: text | function_calling, reasoning, vision, streaming, predicted_outputs | 1048576 | 262144 | In: $0.95, Out: $4.05, Cache Read: $0.16 |
| thinkingmachines/inkling-small | openrouter | In: text, image, audio; Out: text | function_calling, structured_output, reasoning, vision, streaming, predicted_outputs | 524288 | 262144 | In: $0.45, Out: $1.20, Cache Read: $0.10 |
| moonshotai/kimi-k2.5 | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming, predicted_outputs | 262144 | 262144 | In: $0.45, Out: $2.25, Cache Read: $0.07 |
| moonshotai/kimi-k2.6 | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming, predicted_outputs | 262144 | 262144 | In: $0.95, Out: $4.00, Cache Read: $0.16 |
| moonshotai/kimi-k2.7-code | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming, predicted_outputs | 262144 | 262144 | In: $0.71, Out: $3.50, Cache Read: $0.15 |
| moonshotai/kimi-k3 | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming, predicted_outputs | 1048576 | 1048576 | In: $3.00, Out: $15.00, Cache Read: $0.30 |
| krea/krea-2-large | openrouter | In: text, image; Out: image | streaming, image_generation | - | - | - |
| krea/krea-2-medium | openrouter | In: text, image; Out: image | streaming, image_generation | - | - | - |
| krea/krea-2-medium-turbo | openrouter | In: text, image; Out: image | streaming, image_generation | - | - | - |
| meta-llama/llama-4-maverick | openrouter | In: text, image; Out: text | function_calling, structured_output, vision, streaming, predicted_outputs | 1048576 | 16384 | In: $0.20, Out: $0.80 |
| meta-llama/llama-4-scout | openrouter | In: text, image; Out: text | function_calling, structured_output, vision, streaming, predicted_outputs | 1310720 | 16384 | In: $0.10, Out: $0.30 |
| meta-llama/llama-guard-4-12b | openrouter | In: image, text; Out: text | vision, streaming, predicted_outputs | 1048576 | 16384 | In: $0.18, Out: $0.18 |
| google/lyria-3-clip-preview | openrouter | In: text, image; Out: text, audio | vision, streaming | 1048576 | 65536 | In: $0.00, Out: $0.00 |
| google/lyria-3-pro-preview | openrouter | In: text, image; Out: text, audio | vision, streaming | 1048576 | 65536 | In: $0.00, Out: $0.00 |
| xiaomi/mimo-v2.5 | openrouter | In: text, image, audio, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming, predicted_outputs | 1050000 | 131072 | In: $0.14, Out: $0.28, Cache Read: $0.00 |
| microsoft/mai-image-2.5 | openrouter | In: text, image; Out: image | streaming, image_generation | - | - | - |
| microsoft/mai-image-2.5-pro | openrouter | In: text, image; Out: image | streaming, image_generation | - | - | - |
| minimax/minimax-01 | openrouter | In: text, image; Out: text | vision, streaming | 1000192 | 1000192 | In: $0.20, Out: $1.10 |
| minimax/minimax-m3 | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming, predicted_outputs | 1048576 | 512000 | In: $0.30, Out: $1.20, Cache Read: $0.06 |
| minimax/minimax-m3:batch | openrouter | In: text, image, video; Out: text | streaming, function_calling, structured_output, predicted_outputs | 524288 | - | In: $0.30, Out: $1.20, Cache Read: $0.06 |
| mistralai/ministral-14b-2512 | openrouter | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 262144 | 262144 | In: $0.20, Out: $0.20, Cache Read: $0.02 |
| mistralai/ministral-3b-2512 | openrouter | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 131072 | 131072 | In: $0.10, Out: $0.10, Cache Read: $0.01 |
| mistralai/ministral-8b-2512 | openrouter | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 262144 | 262144 | In: $0.15, Out: $0.15, Cache Read: $0.02 |
| mistralai/mistral-large-2512 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, vision, streaming | 262144 | 262144 | In: $0.50, Out: $1.50, Cache Read: $0.05 |
| mistralai/mistral-medium-3 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, vision, streaming | 131072 | 131072 | In: $0.40, Out: $2.00, Cache Read: $0.04 |
| mistralai/mistral-medium-3.1 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, vision, streaming | 131072 | 262144 | In: $0.40, Out: $2.00, Cache Read: $0.04 |
| mistralai/mistral-medium-3-5 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 262144 | 262144 | In: $1.50, Out: $7.50 |
| mistralai/mistral-small-3.1-24b-instruct | openrouter | In: text, image; Out: text | vision, streaming, predicted_outputs | 128000 | 128000 | In: $0.35, Out: $0.56 |
| mistralai/mistral-small-3.2-24b-instruct | openrouter | In: image, text; Out: text | function_calling, structured_output, vision, streaming, predicted_outputs | 256000 | 16384 | In: $0.09, Out: $0.25 |
| mistralai/mistral-small-2603 | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 262144 | 262144 | In: $0.15, Out: $0.60, Cache Read: $0.02 |
| ~moonshotai/kimi-latest | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming, predicted_outputs | 1048576 | 974842 | In: $2.60, Out: $13.00, Cache Read: $0.29 |
| moonshotai/kimi-k2.7-code:batch | openrouter | In: text, image; Out: text | streaming, function_calling, structured_output, predicted_outputs | 262144 | - | In: $0.95, Out: $4.00, Cache Read: $0.19 |
| meta/muse-glimmer-30b | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming, predicted_outputs | 131072 | 131072 | In: $0.35, Out: $1.50, Cache Read: $0.04 |
| meta/muse-spark-1.1 | openrouter | In: text, image, video, pdf, audio; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1048576 | 1048576 | In: $1.25, Out: $4.25, Cache Read: $0.15 |
| meta/muse-spark-1.2 | openrouter | In: text, image, video, pdf, audio; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1048576 | 1048576 | In: $1.25, Out: $4.25, Cache Read: $0.15 |
| nvidia/llama-nemotron-embed-vl-1b-v2:free | openrouter | In: text, image; Out: embeddings | streaming | 131072 | - | - |
| nvidia/llama-nemotron-rerank-vl-1b-v2:free | openrouter | In: text, image; Out: rerank | streaming | 10240 | - | - |
| google/gemini-2.5-flash-image | openrouter | In: text, image; Out: text, image | structured_output, vision, streaming, image_generation | 32768 | 8192 | In: $0.30, Out: $2.50, Cache Read: $0.03, Cache Write: $0.08 |
| google/gemini-3.1-flash-image | openrouter | In: image, text; Out: text, image | structured_output, reasoning, vision, streaming, image_generation | 131072 | 32768 | In: $0.50, Out: $3.00 |
| google/gemini-3.1-flash-image-preview | openrouter | In: image, text; Out: text, image | structured_output, reasoning, vision, streaming, image_generation | 65536 | 65536 | In: $0.50, Out: $3.00 |
| google/gemini-3.1-flash-lite-image | openrouter | In: text, image; Out: text, image | reasoning, vision, streaming, image_generation | 65536 | 65536 | In: $0.25, Out: $1.50 |
| google/gemini-3-pro-image | openrouter | In: text, image; Out: text, image | function_calling, structured_output, reasoning, vision, streaming, image_generation | 131072 | 32768 | In: $2.00, Out: $12.00, Cache Read: $0.20, Cache Write: $0.38 |
| google/gemini-3-pro-image-preview | openrouter | In: text, image; Out: text, image | structured_output, reasoning, vision, streaming, image_generation | 65536 | 32768 | In: $2.00, Out: $12.00, Cache Read: $0.20, Cache Write: $0.38 |
| nvidia/nemotron-3-nano-omni-30b-a3b-reasoning:free | openrouter | In: text, image, video, audio; Out: text | function_calling, reasoning, vision, video, streaming | 256000 | 65536 | In: $0.00, Out: $0.00 |
| nvidia/nemotron-3.5-content-safety:free | openrouter | In: text, image; Out: text | reasoning, vision, streaming | 128000 | 8192 | In: $0.00, Out: $0.00 |
| nvidia/nemotron-nano-12b-v2-vl:free | openrouter | In: text, image, video; Out: text | function_calling, reasoning, vision, video, streaming | 128000 | 128000 | In: $0.00, Out: $0.00 |
| nex-agi/nex-n2-mini | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 262144 | 262144 | In: $0.02, Out: $0.10, Cache Read: $0.00 |
| nex-agi/nex-n2-pro | openrouter | In: text, image; Out: text | function_calling, reasoning, vision, streaming | 262144 | 262144 | In: $0.25, Out: $1.00, Cache Read: $0.02 |
| amazon/nova-2-lite-v1 | openrouter | In: text, image, video, pdf; Out: text | function_calling, reasoning, vision, video, streaming | 1000000 | 65535 | In: $0.30, Out: $2.50 |
| amazon/nova-lite-v1 | openrouter | In: text, image; Out: text | function_calling, vision, streaming | 300000 | 5120 | In: $0.06, Out: $0.24 |
| amazon/nova-premier-v1 | openrouter | In: text, image; Out: text | function_calling, vision, streaming | 1000000 | 32000 | In: $2.50, Out: $12.50, Cache Read: $0.62 |
| amazon/nova-pro-v1 | openrouter | In: text, image; Out: text | function_calling, vision, streaming | 300000 | 5120 | In: $0.80, Out: $3.20 |
| ~openai/gpt-latest | openrouter | In: pdf, image, text; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1050000 | 128000 | In: $2.50, Out: $15.00, Cache Read: $0.25, Cache Write: $3.12 |
| ~openai/gpt-mini-latest | openrouter | In: pdf, image, text; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $0.75, Out: $4.50, Cache Read: $0.08 |
| openai/gpt-image-1 | openrouter | In: text, image; Out: image | streaming, image_generation | - | - | - |
| openai/gpt-image-1-mini | openrouter | In: text, image; Out: image | streaming, image_generation | - | - | - |
| openai/gpt-image-2 | openrouter | In: text, image; Out: image | streaming, image_generation | - | - | - |
| openai/gpt-4-turbo:batch | openrouter | In: text, image; Out: text | streaming, function_calling, structured_output | 128000 | 4096 | In: $5.00, Out: $15.00 |
| openai/gpt-4.1:batch | openrouter | In: image, text, file; Out: text | streaming, function_calling, structured_output | 1047576 | 32768 | In: $1.00, Out: $4.00, Cache Read: $0.25 |
| openai/gpt-4.1-mini:batch | openrouter | In: image, text, file; Out: text | streaming, function_calling, structured_output | 1047576 | 32768 | In: $0.20, Out: $0.80, Cache Read: $0.05 |
| openai/gpt-4.1-nano:batch | openrouter | In: image, text, file; Out: text | streaming, function_calling, structured_output | 1047576 | 32768 | In: $0.05, Out: $0.20, Cache Read: $0.01 |
| openai/gpt-4o:batch | openrouter | In: text, image, file; Out: text | streaming, function_calling, structured_output | 128000 | 16384 | In: $1.25, Out: $5.00, Cache Read: $0.62 |
| openai/gpt-4o-mini:batch | openrouter | In: text, image, file; Out: text | streaming, function_calling, structured_output | 128000 | 16384 | In: $0.08, Out: $0.30, Cache Read: $0.04 |
| openai/gpt-5:batch | openrouter | In: text, image, file; Out: text | streaming, function_calling, structured_output | 400000 | 128000 | In: $0.62, Out: $5.00, Cache Read: $0.06 |
| openai/gpt-5-codex:batch | openrouter | In: text, image; Out: text | streaming, function_calling, structured_output | 400000 | 128000 | In: $0.62, Out: $5.00, Cache Read: $0.06 |
| openai/gpt-5-mini:batch | openrouter | In: text, image, file; Out: text | streaming, function_calling, structured_output | 400000 | 128000 | In: $0.12, Out: $1.00, Cache Read: $0.01 |
| openai/gpt-5-nano:batch | openrouter | In: text, image, file; Out: text | streaming, function_calling, structured_output | 400000 | 128000 | In: $0.02, Out: $0.20, Cache Read: $0.00 |
| openai/gpt-5-pro:batch | openrouter | In: image, text, file; Out: text | streaming, function_calling, structured_output | 400000 | 128000 | In: $7.50, Out: $60.00 |
| openai/gpt-5.1:batch | openrouter | In: image, text, file; Out: text | streaming, function_calling, structured_output | 400000 | 128000 | In: $0.62, Out: $5.00, Cache Read: $0.06 |
| openai/gpt-5.2:batch | openrouter | In: file, image, text; Out: text | streaming, function_calling, structured_output | 400000 | 128000 | In: $0.88, Out: $7.00, Cache Read: $0.09 |
| openai/gpt-5.2-pro:batch | openrouter | In: image, text, file; Out: text | streaming, function_calling, structured_output | 400000 | 128000 | In: $10.50, Out: $84.00 |
| openai/gpt-5.4:batch | openrouter | In: text, image, file; Out: text | streaming, function_calling, structured_output | 1050000 | 128000 | In: $1.25, Out: $7.50, Cache Read: $0.12 |
| openai/gpt-5.4-mini:batch | openrouter | In: file, image, text; Out: text | streaming, function_calling, structured_output | 400000 | 128000 | In: $0.38, Out: $2.25, Cache Read: $0.04 |
| openai/gpt-5.4-nano:batch | openrouter | In: file, image, text; Out: text | streaming, function_calling, structured_output | 400000 | 128000 | In: $0.10, Out: $0.62, Cache Read: $0.01 |
| openai/gpt-5.4-pro:batch | openrouter | In: text, image, file; Out: text | streaming, function_calling, structured_output | 1050000 | 128000 | In: $15.00, Out: $90.00 |
| openai/gpt-5.5:batch | openrouter | In: file, image, text; Out: text | streaming, function_calling, structured_output | 1050000 | 128000 | In: $2.50, Out: $15.00, Cache Read: $0.25 |
| openai/gpt-5.5-pro:batch | openrouter | In: file, image, text; Out: text | streaming, function_calling, structured_output | 1050000 | 128000 | In: $15.00, Out: $90.00 |
| openai/gpt-5.6-luna:batch | openrouter | In: file, image, text; Out: text | streaming, function_calling, structured_output | 1050000 | 128000 | In: $0.10, Out: $0.60, Cache Read: $0.01 |
| openai/gpt-5.6-luna-pro:batch | openrouter | In: file, image, text; Out: text | streaming, function_calling, structured_output | 1050000 | 128000 | In: $0.10, Out: $0.60, Cache Read: $0.01 |
| openai/gpt-5.6-sol:batch | openrouter | In: file, image, text; Out: text | streaming, function_calling, structured_output | 1050000 | 128000 | In: $1.25, Out: $7.50, Cache Read: $0.12 |
| openai/gpt-5.6-sol-pro:batch | openrouter | In: file, image, text; Out: text | streaming, function_calling, structured_output | 1050000 | 128000 | In: $1.25, Out: $7.50, Cache Read: $0.12 |
| openai/gpt-5.6-terra:batch | openrouter | In: file, image, text; Out: text | streaming, function_calling, structured_output | 1050000 | 128000 | In: $1.00, Out: $6.00, Cache Read: $0.10 |
| openai/gpt-5.6-terra-pro:batch | openrouter | In: file, image, text; Out: text | streaming, function_calling, structured_output | 1050000 | 128000 | In: $1.00, Out: $6.00, Cache Read: $0.10 |
| openai/o1:batch | openrouter | In: text, image, file; Out: text | streaming, function_calling, structured_output | 200000 | 100000 | In: $7.50, Out: $30.00, Cache Read: $3.75 |
| openai/o1-pro:batch | openrouter | In: text, image, file; Out: text | streaming, structured_output | 200000 | 100000 | In: $75.00, Out: $300.00 |
| openai/o3:batch | openrouter | In: image, text, file; Out: text | streaming, function_calling, structured_output | 200000 | 100000 | In: $1.00, Out: $4.00, Cache Read: $0.25 |
| openai/o3-pro:batch | openrouter | In: text, file, image; Out: text | streaming, function_calling, structured_output | 200000 | 100000 | In: $10.00, Out: $40.00 |
| openai/o4-mini:batch | openrouter | In: image, text, file; Out: text | streaming, function_calling, structured_output | 200000 | 100000 | In: $0.55, Out: $2.20, Cache Read: $0.14 |
| openai/o4-mini-high:batch | openrouter | In: image, text, file; Out: text | streaming, function_calling, structured_output | 200000 | 100000 | In: $0.55, Out: $2.20, Cache Read: $0.14 |
| perceptron/perceptron-mk1 | openrouter | In: text, image, video; Out: text | structured_output, reasoning, vision, video, streaming | 32768 | 8192 | In: $0.15, Out: $1.50 |
| qwen/qwen2.5-vl-72b-instruct | openrouter | In: text, image; Out: text | structured_output, vision, streaming, predicted_outputs | 128000 | 128000 | In: $0.80, Out: $1.00, Cache Read: $0.40 |
| qwen/qwen3-vl-235b-a22b-instruct | openrouter | In: text, image; Out: text | function_calling, structured_output, vision, streaming, predicted_outputs | 262144 | 32768 | In: $0.21, Out: $1.90, Cache Read: $0.10 |
| qwen/qwen3-vl-235b-a22b-thinking | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 131072 | 32768 | In: $0.40, Out: $4.00 |
| qwen/qwen3-vl-30b-a3b-instruct | openrouter | In: text, image; Out: text | function_calling, structured_output, vision, streaming, predicted_outputs | 262144 | 32768 | In: $0.13, Out: $0.52 |
| qwen/qwen3-vl-30b-a3b-thinking | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 262144 | 32768 | In: $0.20, Out: $2.40 |
| qwen/qwen3-vl-32b-instruct | openrouter | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 131072 | 32768 | In: $0.10, Out: $0.42 |
| qwen/qwen3-vl-8b-instruct | openrouter | In: image, text; Out: text | function_calling, structured_output, vision, streaming, predicted_outputs | 262144 | 32768 | In: $0.12, Out: $0.46 |
| qwen/qwen3-vl-8b-thinking | openrouter | In: image, text; Out: text | function_calling, structured_output, reasoning, vision, streaming | 131072 | 32768 | In: $0.18, Out: $2.10 |
| qwen/qwen3.5-122b-a10b | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming, predicted_outputs | 262144 | 262144 | In: $0.26, Out: $2.08 |
| qwen/qwen3.5-27b | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming, predicted_outputs | 262144 | 65536 | In: $0.20, Out: $1.56 |
| qwen/qwen3.5-35b-a3b | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming, predicted_outputs | 262144 | 262144 | In: $0.25, Out: $1.25, Cache Read: $0.25 |
| qwen/qwen3.5-397b-a17b | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming, predicted_outputs | 262144 | 65536 | In: $0.39, Out: $2.34 |
| qwen/qwen3.5-9b | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming, predicted_outputs | 262144 | 262144 | In: $0.10, Out: $0.15 |
| qwen/qwen3.5-plus-02-15 | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1000000 | 65536 | In: $0.26, Out: $1.56 |
| qwen/qwen3.5-plus-20260420 | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1000000 | 65536 | In: $0.30, Out: $1.80, Cache Write: $0.38 |
| qwen/qwen3.5-flash-02-23 | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1000000 | 65536 | In: $0.06, Out: $0.26 |
| qwen/qwen3.6-27b | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming, predicted_outputs | 262144 | 262144 | In: $0.60, Out: $3.60, Cache Read: $0.12 |
| qwen/qwen3.6-35b-a3b | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming, predicted_outputs | 262144 | 262144 | In: $0.14, Out: $1.00, Cache Read: $0.05 |
| qwen/qwen3.6-flash | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1000000 | 65536 | In: $0.19, Out: $1.12, Cache Write: $0.23 |
| qwen/qwen3.6-plus | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1000000 | 65536 | In: $0.32, Out: $1.95, Cache Write: $0.41 |
| qwen/qwen3.7-flash | openrouter | In: text, image, video; Out: text | function_calling, reasoning, vision, video, streaming | 1000000 | 65536 | In: $0.03, Out: $0.13, Cache Read: $0.01, Cache Write: $0.04 |
| qwen/qwen3.7-plus | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 131072 | In: $0.32, Out: $1.28, Cache Read: $0.06, Cache Write: $0.40 |
| qwen/qwen3.8-27b | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming, predicted_outputs | 1000000 | 131072 | In: $0.45, Out: $3.20, Cache Read: $0.05 |
| qwen/qwen3.8-max | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1000000 | 131072 | In: $2.00, Out: $6.00, Cache Read: $0.25, Cache Write: $2.50 |
| qwen/qwen-image-3 | openrouter | In: text, image; Out: image | streaming, image_generation | - | - | - |
| qwen/qwen-image-3-pro | openrouter | In: text, image; Out: image | streaming, image_generation | - | - | - |
| recraft/recraft-v3 | openrouter | In: text, image; Out: image | streaming, image_generation | - | - | - |
| recraft/recraft-v4 | openrouter | In: text, image; Out: image | streaming, image_generation | - | - | - |
| recraft/recraft-v4-pro | openrouter | In: text, image; Out: image | streaming, image_generation | - | - | - |
| recraft/recraft-v4-pro-vector | openrouter | In: text, image; Out: image | streaming, image_generation | - | - | - |
| recraft/recraft-v4-vector | openrouter | In: text, image; Out: image | streaming, image_generation | - | - | - |
| recraft/recraft-v4.1 | openrouter | In: text, image; Out: image | streaming, image_generation | - | - | - |
| recraft/recraft-v4.1-pro | openrouter | In: text, image; Out: image | streaming, image_generation | - | - | - |
| recraft/recraft-v4.1-pro-vector | openrouter | In: text, image; Out: image | streaming, image_generation | - | - | - |
| recraft/recraft-v4.1-utility | openrouter | In: text, image; Out: image | streaming, image_generation | - | - | - |
| recraft/recraft-v4.1-utility-pro | openrouter | In: text, image; Out: image | streaming, image_generation | - | - | - |
| recraft/recraft-v4.1-vector | openrouter | In: text, image; Out: image | streaming, image_generation | - | - | - |
| rekaai/reka-edge | openrouter | In: image, text, video; Out: text | function_calling, structured_output, vision, video, streaming | 16384 | 16384 | In: $0.10, Out: $0.10 |
| sakana/sakana-namazu | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 262144 | 65536 | In: $0.95, Out: $4.00, Cache Read: $0.15 |
| bytedance-seed/seed-1.6 | openrouter | In: image, text, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 262144 | 32768 | In: $0.25, Out: $2.00 |
| bytedance-seed/seed-1.6-flash | openrouter | In: image, text, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 262144 | 32768 | In: $0.08, Out: $0.30 |
| bytedance-seed/seed-2.0-code | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 262144 | 131072 | In: $0.50, Out: $3.00 |
| bytedance-seed/seed-2.0-lite | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 262144 | 131072 | In: $0.25, Out: $2.00 |
| bytedance-seed/seed-2.0-mini | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 262144 | 131072 | In: $0.10, Out: $0.40 |
| bytedance-seed/seed-2-1-turbo | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 262144 | 262144 | In: $0.50, Out: $2.50 |
| perplexity/sonar | openrouter | In: text, image; Out: text | vision, streaming | 127072 | 127072 | In: $1.00, Out: $1.00 |
| perplexity/sonar-pro | openrouter | In: text, image; Out: text | vision, streaming | 200000 | 8000 | In: $3.00, Out: $15.00 |
| perplexity/sonar-pro-search | openrouter | In: text, image; Out: text | structured_output, reasoning, vision, streaming | 200000 | 8000 | In: $3.00, Out: $15.00 |
| perplexity/sonar-reasoning-pro | openrouter | In: text, image; Out: text | reasoning, vision, streaming | 128000 | 128000 | In: $2.00, Out: $8.00 |
| sourceful/riverflow-v2-fast | openrouter | In: text, image; Out: image | streaming, image_generation | - | - | - |
| sourceful/riverflow-v2-pro | openrouter | In: text, image; Out: image | streaming, image_generation | - | - | - |
| sourceful/riverflow-v2.5-fast | openrouter | In: text, image; Out: image | streaming, image_generation | - | - | - |
| sourceful/riverflow-v2.5-pro | openrouter | In: text, image; Out: image | streaming, image_generation | - | - | - |
| x-ai/grok-imagine-image-quality | openrouter | In: text, image; Out: image | streaming, image_generation | - | - | - |
| stepfun/step-3.7-flash | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming, predicted_outputs | 262144 | 256000 | In: $0.20, Out: $1.15, Cache Read: $0.04 |
| thinkingmachines/inkling:batch | openrouter | In: text, image, audio; Out: text | streaming, function_calling, predicted_outputs | 524288 | - | In: $1.00, Out: $4.05, Cache Read: $0.17 |
| bytedance/ui-tars-1.5-7b | openrouter | In: image, text; Out: text | structured_output, vision, streaming, predicted_outputs | 128000 | 2048 | In: $0.10, Out: $0.20, Cache Read: $0.10 |
| voyageai/voyage-multimodal-3.5 | openrouter | In: text, image; Out: embeddings | streaming | 32000 | - | In: $0.12 |
| openai/o1 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 100000 | In: $15.00, Out: $60.00, Cache Read: $7.50 |
| openai/o1-pro | openrouter | In: text, image, pdf; Out: text | structured_output, reasoning, vision, streaming | 200000 | 100000 | In: $150.00, Out: $600.00 |
| openai/o3 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 100000 | In: $2.00, Out: $8.00, Cache Read: $0.50 |
| openai/o3-pro | openrouter | In: text, pdf, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 100000 | In: $20.00, Out: $80.00 |
| openai/o4-mini-high | openrouter | In: image, text, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 100000 | In: $1.10, Out: $4.40, Cache Read: $0.28 |
| openai/o4-mini | openrouter | In: image, text, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 100000 | In: $1.10, Out: $4.40, Cache Read: $0.28 |
| x-ai/grok-imagine-image-2.0 | openrouter | In: text, image; Out: image | streaming, image_generation | - | - | - |
| sonar-pro | perplexity | In: text, image; Out: text | vision, citations | 200000 | 8192 | In: $3.00, Out: $15.00 |
| sonar-reasoning-pro | perplexity | In: text, image; Out: text | reasoning, vision, citations | 128000 | 4096 | In: $2.00, Out: $8.00 |
| claude-haiku-4-5 | vertexai | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 64000 | In: $1.00, Out: $5.00, Cache Read: $0.10, Cache Write: $1.25 |
| claude-opus-4 | vertexai | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 200000 | 32000 | In: $15.00, Out: $75.00, Cache Read: $1.50, Cache Write: $18.75 |
| claude-opus-4-1 | vertexai | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 32000 | In: $15.00, Out: $75.00, Cache Read: $1.50, Cache Write: $18.75 |
| claude-opus-4-5 | vertexai | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 64000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| claude-opus-4-6 | vertexai | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| claude-opus-4-7 | vertexai | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| claude-opus-4-8 | vertexai | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| claude-opus-5 | vertexai | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| claude-sonnet-4 | vertexai | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 200000 | 64000 | In: $3.00, Out: $15.00, Cache Read: $0.30, Cache Write: $3.75 |
| claude-sonnet-4-5 | vertexai | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 64000 | In: $3.00, Out: $15.00, Cache Read: $0.30, Cache Write: $3.75 |
| claude-sonnet-4-6 | vertexai | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 1000000 | 128000 | In: $3.00, Out: $15.00, Cache Read: $0.30, Cache Write: $3.75 |
| claude-sonnet-5 | vertexai | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 1000000 | 128000 | In: $2.00, Out: $10.00, Cache Read: $0.20, Cache Write: $2.50 |
| gemini-2.5-flash | vertexai | In: text, image, audio, video, pdf; Out: text | function_calling, reasoning, vision, video, transcription, streaming | 1048576 | 65536 | In: $0.30, Out: $2.50, Cache Read: $0.08, Cache Write: $0.38 |
| gemini-2.5-flash-lite | vertexai | In: text, image, audio, video, pdf; Out: text | function_calling, reasoning, vision, video, transcription, streaming | 1048576 | 65536 | In: $0.10, Out: $0.40, Cache Read: $0.01 |
| gemini-2.5-pro | vertexai | In: text, image, audio, video, pdf; Out: text | function_calling, reasoning, vision, video, transcription, streaming | 1048576 | 65536 | In: $1.25, Out: $10.00, Cache Read: $0.12 |
| gemini-3-flash-preview | vertexai | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription, streaming | 1048576 | 65536 | In: $0.50, Out: $3.00, Cache Read: $0.05 |
| gemini-3.1-flash-lite | vertexai | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription, streaming | 1048576 | 65536 | In: $0.25, Out: $1.50, Cache Read: $0.02 |
| gemini-3.1-flash-lite-preview | vertexai | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription | 1048576 | 65536 | In: $0.25, Out: $1.50, Cache Read: $0.02 |
| gemini-3.1-pro-preview | vertexai | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription, streaming | 1048576 | 65536 | In: $2.00, Out: $12.00, Cache Read: $0.20 |
| gemini-3.1-pro-preview-customtools | vertexai | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription | 1048576 | 65536 | In: $2.00, Out: $12.00, Cache Read: $0.20 |
| gemini-3.5-flash | vertexai | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription, streaming | 1048576 | 65536 | In: $1.50, Out: $9.00, Cache Read: $0.15 |
| gemini-3.5-flash-lite | vertexai | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription, streaming | 1048576 | 65536 | In: $0.30, Out: $2.50, Cache Read: $0.03 |
| gemini-3.6-flash | vertexai | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription, streaming | 1048576 | 65536 | In: $1.50, Out: $7.50, Cache Read: $0.15 |
| gemini-3.7-flash | vertexai | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription, streaming | 1048576 | 65536 | In: $0.75, Out: $3.75, Cache Read: $0.08 |
| gemini-embedding-2 | vertexai | In: text, image, audio, video, pdf; Out: embeddings | vision, video, streaming | 8192 | 1 | In: $0.20, Out: $0.00 |
| gemini-flash-latest | vertexai | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription | 1048576 | 65536 | In: $1.50, Out: $9.00, Cache Read: $0.15 |
| gemini-flash-lite-latest | vertexai | In: text, image, video, audio, pdf; Out: text | function_calling, reasoning, vision, video, transcription | 1048576 | 65536 | In: $0.25, Out: $1.50, Cache Read: $0.02 |
| meta/llama-4-maverick-17b-128e-instruct-maas | vertexai | In: text, image; Out: text | function_calling, structured_output, vision | 524288 | 8192 | In: $0.35, Out: $1.15 |
| gemini-2.5-flash-image | vertexai | In: text, image; Out: text, image | vision | 32768 | 32768 | In: $0.30, Out: $30.00 |
| gemini-3.1-flash-image | vertexai | In: text, image, video, pdf; Out: text, image | reasoning, vision, video, streaming | 131072 | 32768 | In: $0.50, Out: $60.00 |
| gemini-3.1-flash-image-preview | vertexai | In: text, image, pdf; Out: text, image | reasoning, vision, streaming | 65536 | 65536 | In: $0.50, Out: $60.00 |
| gemini-3.1-flash-lite-image | vertexai | In: text, image; Out: text, image | function_calling, reasoning, vision, streaming | 65536 | 65536 | In: $0.25, Out: $30.00 |
| gemini-3-pro-image | vertexai | In: text, image; Out: text, image | reasoning, vision, streaming | 65536 | 32768 | In: $2.00, Out: $120.00 |
| grok-4.20-0309-non-reasoning | xai | In: text, image, pdf; Out: text | function_calling, structured_output, vision, streaming | 1000000 | 30000 | In: $1.25, Out: $2.50, Cache Read: $0.20 |
| grok-4.20-0309-reasoning | xai | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 30000 | In: $1.25, Out: $2.50, Cache Read: $0.20 |
| grok-4.20-multi-agent-0309 | xai | In: text, image, pdf; Out: text | structured_output, reasoning, vision, streaming | 1000000 | 30000 | In: $1.25, Out: $2.50, Cache Read: $0.20 |
| grok-4.3 | xai | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 30000 | In: $1.25, Out: $2.50, Cache Read: $0.20 |
| grok-4.5 | xai | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 500000 | 500000 | In: $2.00, Out: $6.00, Cache Read: $0.30 |
| grok-4.6 | xai | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 500000 | 500000 | In: $2.00, Out: $6.00, Cache Read: $0.50 |
| grok-build-0.1 | xai | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 256000 | 256000 | In: $1.00, Out: $2.00, Cache Read: $0.20 |
| grok-imagine-image | xai | In: text, image, pdf; Out: image | vision | 8000 | 0 | - |
| grok-imagine-image-2.0 | xai | In: text, image, pdf; Out: image | vision | 8000 | 0 | - |
| grok-imagine-image-quality | xai | In: text, image, pdf; Out: image | vision | 8000 | 0 | - |
| grok-imagine-video | xai | In: text, image, video, pdf; Out: video | vision, video | 1024 | 0 | - |
| grok-imagine-video-1.5 | xai | In: text, image, audio, pdf; Out: video | vision | 1024 | 0 | - |


### Audio Input Models (141)

Models that can process audio:

| Model | Provider | I/O | Capabilities | Context | Max Output | Standard Pricing (per 1M tokens) |
| :-- | :-- | :-- | :-- | --: | --: | :-- |
| amazon.nova-2-sonic-v1:0 | bedrock | In: audio; Out: audio, text | streaming | - | - | - |
| mistral.voxtral-mini-3b-2507 | bedrock | In: audio, text; Out: text | function_calling, structured_output, streaming | 128000 | 4096 | In: $0.04, Out: $0.04 |
| mistral.voxtral-small-24b-2507 | bedrock | In: text, audio; Out: text | function_calling, structured_output, streaming | 32000 | 8192 | In: $0.15, Out: $0.35 |
| cohere-transcribe-03-2026 | cohere | In: audio; Out: text | transcription | 32768 | - | - |
| enhanced-automotive | deepgram | In: audio; Out: text | transcription | - | - | - |
| enhanced-drivethru | deepgram | In: audio; Out: text | transcription | - | - | - |
| enhanced-finance | deepgram | In: audio; Out: text | transcription | - | - | - |
| enhanced-general | deepgram | In: audio; Out: text | transcription | - | - | - |
| enhanced-meeting | deepgram | In: audio; Out: text | transcription | - | - | - |
| enhanced-phonecall | deepgram | In: audio; Out: text | transcription | - | - | - |
| nova-2-atc | deepgram | In: audio; Out: text | transcription | - | - | - |
| nova-2-automotive | deepgram | In: audio; Out: text | transcription | - | - | - |
| nova-2-conversationalai | deepgram | In: audio; Out: text | transcription | - | - | - |
| nova-2-drivethru | deepgram | In: audio; Out: text | transcription | - | - | - |
| nova-2-ea | deepgram | In: audio; Out: text | transcription | - | - | - |
| nova-2-finance | deepgram | In: audio; Out: text | transcription | - | - | - |
| nova-2-general | deepgram | In: audio; Out: text | transcription | - | - | - |
| nova-2-medical | deepgram | In: audio; Out: text | transcription | - | - | - |
| nova-2-meeting | deepgram | In: audio; Out: text | transcription | - | - | - |
| nova-2-phonecall | deepgram | In: audio; Out: text | transcription | - | - | - |
| nova-2-video | deepgram | In: audio; Out: text | transcription | - | - | - |
| nova-2-voicemail | deepgram | In: audio; Out: text | transcription | - | - | - |
| nova-3-general | deepgram | In: audio; Out: text | transcription | - | - | - |
| nova-3-medical | deepgram | In: audio; Out: text | transcription | - | - | - |
| nova-drivethru | deepgram | In: audio; Out: text | transcription | - | - | - |
| nova-general | deepgram | In: audio; Out: text | transcription | - | - | - |
| nova-medical | deepgram | In: audio; Out: text | transcription | - | - | - |
| nova-phonecall | deepgram | In: audio; Out: text | transcription | - | - | - |
| nova-voicemail | deepgram | In: audio; Out: text | transcription | - | - | - |
| whisper-base | deepgram | In: audio; Out: text | transcription | - | - | - |
| whisper-large | deepgram | In: audio; Out: text | transcription | - | - | - |
| whisper-medium | deepgram | In: audio; Out: text | transcription | - | - | - |
| whisper-small | deepgram | In: audio; Out: text | transcription | - | - | - |
| whisper-tiny | deepgram | In: audio; Out: text | transcription | - | - | - |
| eleven_english_sts_v2 | elevenlabs | In: audio; Out: audio | - | - | - | - |
| eleven_multilingual_sts_v2 | elevenlabs | In: audio; Out: audio | - | - | - | - |
| scribe_v2 | elevenlabs | In: audio; Out: text | transcription | - | - | - |
| deep-research-max-preview-04-2026 | gemini | In: text, image, video, audio, pdf; Out: text, image | function_calling, reasoning, vision, video, transcription | 131072 | 65536 | In: $2.00, Out: $12.00, Cache Read: $0.20 |
| deep-research-preview-04-2026 | gemini | In: text, image, video, audio, pdf; Out: text, image | function_calling, reasoning, vision, video, transcription | 131072 | 65536 | In: $2.00, Out: $12.00, Cache Read: $0.20 |
| gemini-2.5-flash | gemini | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription, tool_choice | 1048576 | 65536 | In: $0.30, Out: $2.50, Cache Read: $0.03 |
| gemini-2.5-flash-lite | gemini | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription | 1048576 | 65536 | In: $0.10, Out: $0.40, Cache Read: $0.01 |
| gemini-2.5-pro | gemini | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription, tool_choice | 1048576 | 65536 | In: $1.25, Out: $10.00, Cache Read: $0.12 |
| gemini-3-flash-preview | gemini | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription, tool_choice | 1048576 | 65536 | In: $0.50, Out: $3.00, Cache Read: $0.05 |
| gemini-3.1-flash-lite | gemini | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription | 1048576 | 65536 | In: $0.25, Out: $1.50, Cache Read: $0.02 |
| gemini-3.1-flash-lite-preview | gemini | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription | 1048576 | 65536 | In: $0.25, Out: $1.50, Cache Read: $0.02 |
| gemini-3.1-flash-live-preview | gemini | In: text, image, video, audio; Out: text, audio | function_calling, reasoning, vision, video, transcription, tool_choice | 131072 | 65536 | In: $0.75, Out: $4.50 |
| gemini-3.1-pro-preview | gemini | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription, tool_choice | 1048576 | 65536 | In: $2.00, Out: $12.00, Cache Read: $0.20 |
| gemini-3.1-pro-preview-customtools | gemini | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription, tool_choice | 1048576 | 65536 | In: $2.00, Out: $12.00, Cache Read: $0.20 |
| gemini-3.5-flash | gemini | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription, tool_choice | 1048576 | 65536 | In: $1.50, Out: $9.00, Cache Read: $0.15 |
| gemini-3.5-flash-lite | gemini | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription | 1048576 | 65536 | In: $0.30, Out: $2.50, Cache Read: $0.03 |
| gemini-3.5-live-translate-preview | gemini | In: audio; Out: audio, text | transcription, tool_choice, structured_output | 16384 | 32768 | In: $3.50, Out: $21.00 |
| gemini-3.6-flash | gemini | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription, tool_choice | 1048576 | 65536 | In: $1.50, Out: $7.50, Cache Read: $0.15 |
| gemini-3.7-flash | gemini | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription, tool_choice | 1048576 | 65536 | In: $0.75, Out: $3.75, Cache Read: $0.08 |
| gemini-embedding-2 | gemini | In: text, image, audio, video, pdf; Out: embeddings | vision, video, tool_choice, structured_output | 8192 | 1 | In: $0.20, Out: $0.00 |
| gemini-flash-latest | gemini | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription, tool_choice | 1048576 | 65536 | In: $1.50, Out: $9.00, Cache Read: $0.15 |
| gemini-flash-lite-latest | gemini | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription | 1048576 | 65536 | In: $0.25, Out: $1.50, Cache Read: $0.02 |
| gemini-robotics-er-1.6-preview | gemini | In: text, image, video, audio; Out: text | function_calling, structured_output, reasoning, vision, video, transcription, tool_choice | 131072 | 65536 | In: $1.00, Out: $5.00 |
| voxtral-mini-latest | mistral | In: audio; Out: text | streaming, transcription | 0 | 0 | - |
| voxtral-mini-2602 | mistral | In: text, audio; Out: text | streaming, transcription | 16384 | 8192 | - |
| voxtral-mini-realtime-2602 | mistral | In: text, audio; Out: text | streaming, realtime | 32768 | 8192 | - |
| voxtral-mini-realtime-latest | mistral | In: text, audio; Out: text | streaming, realtime | 32768 | 8192 | - |
| voxtral-mini-transcribe-realtime-2602 | mistral | In: audio; Out: text | realtime | 32768 | 8192 | - |
| voxtral-small-latest | mistral | In: text, audio; Out: text | function_calling, streaming | 32000 | 32000 | In: $0.10, Out: $0.30 |
| voxtral-small-2507 | mistral | In: text, audio; Out: text | streaming, function_calling | 32768 | 8192 | - |
| gpt-realtime-2.1 | openai | In: text, audio, image; Out: text, audio | function_calling, reasoning, vision | 128000 | 32000 | In: $4.00, Out: $24.00, Cache Read: $0.40 |
| openrouter/auto | openrouter | In: text, image, audio, pdf, video; Out: text, image | function_calling, structured_output, reasoning, vision, video, streaming, predicted_outputs, image_generation | 2000000 | 2000000 | - |
| openrouter/auto-beta | openrouter | In: text, image, audio, file, video; Out: text, image | streaming, function_calling, structured_output, predicted_outputs, image_generation | 2000000 | - | - |
| deepgram/nova-3 | openrouter | In: audio; Out: text | streaming, transcription | 0 | - | In: $4300.00 |
| fish-audio/transcribe-1 | openrouter | In: audio; Out: text | streaming, transcription | 0 | - | In: $100.00 |
| openai/gpt-audio | openrouter | In: text, audio; Out: text, audio | function_calling, structured_output, streaming | 128000 | 16384 | In: $2.50, Out: $10.00 |
| openai/gpt-audio-mini | openrouter | In: text, audio; Out: text, audio | function_calling, structured_output, streaming | 128000 | 16384 | In: $0.60, Out: $2.40 |
| google/gemini-2.5-flash | openrouter | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1048576 | 65535 | In: $0.30, Out: $2.50, Cache Read: $0.03, Cache Write: $0.08 |
| google/gemini-2.5-flash-lite | openrouter | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1048576 | 65535 | In: $0.10, Out: $0.40, Cache Read: $0.01, Cache Write: $0.08 |
| google/gemini-2.5-pro | openrouter | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1048576 | 65536 | In: $1.25, Out: $10.00, Cache Read: $0.12, Cache Write: $0.38 |
| google/gemini-2.5-pro-preview-05-06 | openrouter | In: text, image, pdf, audio, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1048576 | 65535 | In: $1.25, Out: $10.00, Cache Read: $0.12, Cache Write: $0.38 |
| google/gemini-2.5-pro-preview | openrouter | In: pdf, image, text, audio; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1048576 | 65536 | In: $1.25, Out: $10.00, Cache Read: $0.12, Cache Write: $0.38 |
| google/gemini-3-flash-preview | openrouter | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1048576 | 65536 | In: $0.50, Out: $3.00, Cache Read: $0.05, Cache Write: $0.08 |
| google/gemini-3.1-flash-lite | openrouter | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1048576 | 65536 | In: $0.25, Out: $1.50, Cache Read: $0.02, Cache Write: $0.08 |
| google/gemini-3.1-flash-lite-preview | openrouter | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1048576 | 65536 | In: $0.25, Out: $1.50, Cache Read: $0.02, Cache Write: $0.08 |
| google/gemini-3.1-pro-preview | openrouter | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1048576 | 65536 | In: $2.00, Out: $12.00, Cache Read: $0.20, Cache Write: $0.38 |
| google/gemini-3.1-pro-preview-customtools | openrouter | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1048576 | 65536 | In: $2.00, Out: $12.00, Cache Read: $0.20, Cache Write: $0.38 |
| google/gemini-3.5-flash | openrouter | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1048576 | 65536 | In: $1.50, Out: $9.00, Cache Read: $0.15, Cache Write: $0.08 |
| google/gemini-3.5-flash-lite | openrouter | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1048576 | 65536 | In: $0.30, Out: $2.50, Cache Read: $0.03, Cache Write: $0.08 |
| google/gemini-3.6-flash | openrouter | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1048576 | 65536 | In: $0.75, Out: $3.75, Cache Read: $0.08, Cache Write: $0.04 |
| google/gemini-3.7-flash | openrouter | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1048576 | 65536 | In: $0.38, Out: $1.88, Cache Read: $0.04, Cache Write: $0.02 |
| ~google/gemini-flash-latest | openrouter | In: text, image, video, pdf, audio; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1048576 | 65536 | In: $0.38, Out: $1.88, Cache Read: $0.04, Cache Write: $0.02 |
| ~google/gemini-pro-latest | openrouter | In: audio, pdf, image, text, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1048576 | 65536 | In: $2.00, Out: $12.00, Cache Read: $0.20, Cache Write: $0.38 |
| google/chirp-3 | openrouter | In: audio; Out: text | streaming, structured_output, transcription | 0 | - | In: $16000.00 |
| google/gemini-2.5-flash:batch | openrouter | In: file, image, text, audio, video; Out: text | streaming, function_calling, structured_output | 1048576 | 65535 | In: $0.15, Out: $1.25, Cache Read: $0.03 |
| google/gemini-2.5-flash-lite:batch | openrouter | In: text, image, file, audio, video; Out: text | streaming, function_calling, structured_output | 1048576 | 65535 | In: $0.05, Out: $0.20, Cache Read: $0.01 |
| google/gemini-2.5-pro:batch | openrouter | In: text, image, file, audio, video; Out: text | streaming, function_calling, structured_output | 1048576 | 65536 | In: $0.62, Out: $5.00, Cache Read: $0.12 |
| google/gemini-3-flash-preview:batch | openrouter | In: text, image, file, audio, video; Out: text | streaming, function_calling, structured_output | 1048576 | 65536 | In: $0.25, Out: $1.50 |
| google/gemini-3.1-flash-lite:batch | openrouter | In: text, image, video, file, audio; Out: text | streaming, function_calling, structured_output | 1048576 | 65536 | In: $0.12, Out: $0.75, Cache Read: $0.01 |
| google/gemini-3.1-pro-preview:batch | openrouter | In: audio, file, image, text, video; Out: text | streaming, function_calling, structured_output | 1048576 | 65536 | In: $1.00, Out: $6.00 |
| google/gemini-3.5-flash:batch | openrouter | In: text, image, video, file, audio; Out: text | streaming, function_calling, structured_output | 1048576 | 65536 | In: $0.75, Out: $4.50, Cache Read: $0.08 |
| google/gemini-3.5-flash-lite:batch | openrouter | In: text, image, video, file, audio; Out: text | streaming, function_calling, structured_output | 1048576 | 65536 | In: $0.15, Out: $1.25, Cache Read: $0.02 |
| google/gemini-3.6-flash:batch | openrouter | In: text, image, video, file, audio; Out: text | streaming, function_calling, structured_output | 1048576 | 65536 | In: $0.38, Out: $1.88, Cache Read: $0.04, Cache Write: $0.04 |
| google/gemini-3.7-flash:batch | openrouter | In: text, image, video, file, audio; Out: text | streaming, function_calling, structured_output | 1048576 | 65536 | In: $0.19, Out: $0.94, Cache Read: $0.02, Cache Write: $0.02 |
| google/gemini-embedding-2 | openrouter | In: text, image, file, audio, video; Out: embeddings | streaming, structured_output | 8192 | - | In: $0.20 |
| google/gemini-embedding-2-preview | openrouter | In: text, image, file, audio, video; Out: embeddings | streaming, structured_output | 8192 | - | In: $0.20 |
| thinkingmachines/inkling | openrouter | In: text, image, audio; Out: text | function_calling, reasoning, vision, streaming, predicted_outputs | 1048576 | 262144 | In: $0.95, Out: $4.05, Cache Read: $0.16 |
| thinkingmachines/inkling-small | openrouter | In: text, image, audio; Out: text | function_calling, structured_output, reasoning, vision, streaming, predicted_outputs | 524288 | 262144 | In: $0.45, Out: $1.20, Cache Read: $0.10 |
| xiaomi/mimo-v2.5 | openrouter | In: text, image, audio, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming, predicted_outputs | 1050000 | 131072 | In: $0.14, Out: $0.28, Cache Read: $0.00 |
| microsoft/mai-transcribe-1.5 | openrouter | In: audio; Out: text | streaming, transcription | 0 | - | In: $360000.00 |
| mistralai/voxtral-mini-3b-2507 | openrouter | In: audio; Out: text | streaming, structured_output, transcription | 0 | - | In: $16.67 |
| mistralai/voxtral-mini-transcribe | openrouter | In: audio; Out: text | streaming, structured_output, transcription | 0 | - | In: $3000.00 |
| mistralai/voxtral-small-24b-2507-stt | openrouter | In: audio; Out: text | streaming, structured_output, transcription | 0 | - | In: $50.00 |
| meta/muse-spark-1.1 | openrouter | In: text, image, video, pdf, audio; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1048576 | 1048576 | In: $1.25, Out: $4.25, Cache Read: $0.15 |
| meta/muse-spark-1.2 | openrouter | In: text, image, video, pdf, audio; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1048576 | 1048576 | In: $1.25, Out: $4.25, Cache Read: $0.15 |
| nvidia/nemotron-3.5-asr-streaming-multilingual-0.6b | openrouter | In: audio; Out: text | streaming, structured_output, transcription | 0 | - | In: $3.33 |
| nvidia/parakeet-tdt-0.6b-v3 | openrouter | In: audio; Out: text | streaming, predicted_outputs, transcription | 0 | - | In: $1500.00 |
| nvidia/nemotron-3-nano-omni-30b-a3b-reasoning:free | openrouter | In: text, image, video, audio; Out: text | function_calling, reasoning, vision, video, streaming | 256000 | 65536 | In: $0.00, Out: $0.00 |
| openai/gpt-transcribe | openrouter | In: audio; Out: text | streaming, structured_output, transcription | 0 | - | In: $4500.00 |
| openai/gpt-4o-mini-transcribe | openrouter | In: audio; Out: text | streaming, structured_output, transcription | 128000 | - | In: $1.25, Out: $5.00 |
| openai/gpt-4o-transcribe | openrouter | In: audio; Out: text | streaming, structured_output, transcription | 128000 | - | In: $2.50, Out: $10.00 |
| openai/whisper-1 | openrouter | In: audio; Out: text | streaming, structured_output, transcription | 0 | - | In: $6000.00 |
| openai/whisper-large-v3 | openrouter | In: audio; Out: text | streaming, structured_output, predicted_outputs, transcription | 0 | - | In: $7.50 |
| openai/whisper-large-v3-turbo | openrouter | In: audio; Out: text | streaming, structured_output, transcription | 0 | - | In: $3.33 |
| qwen/qwen3-asr-0.6b | openrouter | In: audio; Out: text | streaming, structured_output, transcription | 0 | - | In: $3.33 |
| qwen/qwen3-asr-1.7b | openrouter | In: audio; Out: text | streaming, structured_output, transcription | 0 | - | In: $7.50 |
| qwen/qwen3-asr-flash-2026-02-10 | openrouter | In: audio; Out: text | streaming, structured_output, transcription | 0 | - | In: $35.00 |
| x-ai/grok-stt-1.0 | openrouter | In: audio; Out: text | streaming, structured_output, transcription | 0 | - | In: $100000.00 |
| thinkingmachines/inkling:batch | openrouter | In: text, image, audio; Out: text | streaming, function_calling, predicted_outputs | 524288 | - | In: $1.00, Out: $4.05, Cache Read: $0.17 |
| mistralai/voxtral-small-24b-2507 | openrouter | In: text, audio, pdf; Out: text | function_calling, structured_output, vision, streaming | 32000 | 32000 | In: $0.10, Out: $0.30, Cache Read: $0.01 |
| gemini-2.5-flash | vertexai | In: text, image, audio, video, pdf; Out: text | function_calling, reasoning, vision, video, transcription, streaming | 1048576 | 65536 | In: $0.30, Out: $2.50, Cache Read: $0.08, Cache Write: $0.38 |
| gemini-2.5-flash-lite | vertexai | In: text, image, audio, video, pdf; Out: text | function_calling, reasoning, vision, video, transcription, streaming | 1048576 | 65536 | In: $0.10, Out: $0.40, Cache Read: $0.01 |
| gemini-2.5-pro | vertexai | In: text, image, audio, video, pdf; Out: text | function_calling, reasoning, vision, video, transcription, streaming | 1048576 | 65536 | In: $1.25, Out: $10.00, Cache Read: $0.12 |
| gemini-3-flash-preview | vertexai | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription, streaming | 1048576 | 65536 | In: $0.50, Out: $3.00, Cache Read: $0.05 |
| gemini-3.1-flash-lite | vertexai | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription, streaming | 1048576 | 65536 | In: $0.25, Out: $1.50, Cache Read: $0.02 |
| gemini-3.1-flash-lite-preview | vertexai | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription | 1048576 | 65536 | In: $0.25, Out: $1.50, Cache Read: $0.02 |
| gemini-3.1-pro-preview | vertexai | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription, streaming | 1048576 | 65536 | In: $2.00, Out: $12.00, Cache Read: $0.20 |
| gemini-3.1-pro-preview-customtools | vertexai | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription | 1048576 | 65536 | In: $2.00, Out: $12.00, Cache Read: $0.20 |
| gemini-3.5-flash | vertexai | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription, streaming | 1048576 | 65536 | In: $1.50, Out: $9.00, Cache Read: $0.15 |
| gemini-3.5-flash-lite | vertexai | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription, streaming | 1048576 | 65536 | In: $0.30, Out: $2.50, Cache Read: $0.03 |
| gemini-3.6-flash | vertexai | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription, streaming | 1048576 | 65536 | In: $1.50, Out: $7.50, Cache Read: $0.15 |
| gemini-3.7-flash | vertexai | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription, streaming | 1048576 | 65536 | In: $0.75, Out: $3.75, Cache Read: $0.08 |
| gemini-embedding-2 | vertexai | In: text, image, audio, video, pdf; Out: embeddings | vision, video, streaming | 8192 | 1 | In: $0.20, Out: $0.00 |
| gemini-flash-latest | vertexai | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription | 1048576 | 65536 | In: $1.50, Out: $9.00, Cache Read: $0.15 |
| gemini-flash-lite-latest | vertexai | In: text, image, video, audio, pdf; Out: text | function_calling, reasoning, vision, video, transcription | 1048576 | 65536 | In: $0.25, Out: $1.50, Cache Read: $0.02 |
| grok-imagine-video-1.5 | xai | In: text, image, audio, pdf; Out: video | vision | 1024 | 0 | - |
| grok-stt | xai | In: audio; Out: text | transcription | - | - | - |


### PDF Models (260)

Models that can process PDF documents:

| Model | Provider | I/O | Capabilities | Context | Max Output | Standard Pricing (per 1M tokens) |
| :-- | :-- | :-- | :-- | --: | --: | :-- |
| claude-fable-5 | anthropic | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, citations, tool_choice, parallel_tool_calls, batch | 1000000 | 128000 | In: $10.00, Out: $50.00, Cache Read: $1.00, Cache Write: $12.50 |
| claude-haiku-4-5-20251001 | anthropic | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, citations, tool_choice, parallel_tool_calls, batch | 200000 | 64000 | In: $1.00, Out: $5.00, Cache Read: $0.10, Cache Write: $1.25 |
| claude-haiku-4-5 | anthropic | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 200000 | 64000 | In: $1.00, Out: $5.00, Cache Read: $0.10, Cache Write: $1.25 |
| claude-opus-4-5-20251101 | anthropic | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, citations, tool_choice, parallel_tool_calls, batch | 200000 | 64000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| claude-opus-4-5 | anthropic | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 200000 | 64000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| claude-opus-4-6 | anthropic | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, citations, tool_choice, parallel_tool_calls, batch | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| claude-opus-4-7 | anthropic | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, citations, tool_choice, parallel_tool_calls, batch | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| claude-opus-4-8 | anthropic | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, citations, tool_choice, parallel_tool_calls, batch | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| claude-opus-5 | anthropic | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, citations, tool_choice, parallel_tool_calls, batch | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| claude-sonnet-4-5-20250929 | anthropic | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, citations, tool_choice, parallel_tool_calls, batch | 1000000 | 64000 | In: $3.00, Out: $15.00, Cache Read: $0.30, Cache Write: $3.75 |
| claude-sonnet-4-5 | anthropic | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1000000 | 64000 | In: $3.00, Out: $15.00, Cache Read: $0.30, Cache Write: $3.75 |
| claude-sonnet-4-6 | anthropic | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, citations, tool_choice, parallel_tool_calls, batch | 1000000 | 128000 | In: $3.00, Out: $15.00, Cache Read: $0.30, Cache Write: $3.75 |
| claude-sonnet-5 | anthropic | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, citations, tool_choice, parallel_tool_calls, batch | 1000000 | 128000 | In: $2.00, Out: $10.00, Cache Read: $0.20, Cache Write: $2.50 |
| au.anthropic.claude-opus-4-6-v1 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1000000 | 128000 | In: $16.50, Out: $82.50, Cache Read: $1.65, Cache Write: $20.62 |
| au.anthropic.claude-sonnet-4-6 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1000000 | 128000 | In: $3.30, Out: $16.50, Cache Read: $0.33, Cache Write: $4.12 |
| anthropic.claude-fable-5 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 1000000 | 128000 | In: $10.00, Out: $50.00, Cache Read: $1.00, Cache Write: $12.50 |
| eu.anthropic.claude-fable-5 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 1000000 | 128000 | In: $11.00, Out: $55.00, Cache Read: $1.10, Cache Write: $13.75 |
| global.anthropic.claude-fable-5 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 1000000 | 128000 | In: $10.00, Out: $50.00, Cache Read: $1.00, Cache Write: $12.50 |
| us.anthropic.claude-fable-5 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 1000000 | 128000 | In: $10.00, Out: $50.00, Cache Read: $1.00, Cache Write: $12.50 |
| anthropic.claude-haiku-4-5-20251001-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 200000 | 64000 | In: $1.00, Out: $5.00, Cache Read: $0.10, Cache Write: $1.25 |
| au.anthropic.claude-haiku-4-5-20251001-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 200000 | 64000 | In: $1.00, Out: $5.00, Cache Read: $0.10, Cache Write: $1.25 |
| eu.anthropic.claude-haiku-4-5-20251001-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 200000 | 64000 | In: $1.10, Out: $5.50, Cache Read: $0.11, Cache Write: $1.38 |
| global.anthropic.claude-haiku-4-5-20251001-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 200000 | 64000 | In: $1.00, Out: $5.00, Cache Read: $0.10, Cache Write: $1.25 |
| jp.anthropic.claude-haiku-4-5-20251001-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 200000 | 64000 | In: $1.00, Out: $5.00, Cache Read: $0.10, Cache Write: $1.25 |
| us.anthropic.claude-haiku-4-5-20251001-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 64000 | In: $1.00, Out: $5.00, Cache Read: $0.10, Cache Write: $1.25 |
| anthropic.claude-opus-4-1-20250805-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 200000 | 32000 | In: $15.00, Out: $75.00, Cache Read: $1.50, Cache Write: $18.75 |
| us.anthropic.claude-opus-4-1-20250805-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 32000 | In: $15.00, Out: $75.00, Cache Read: $1.50, Cache Write: $18.75 |
| anthropic.claude-opus-4-5-20251101-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 200000 | 64000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| eu.anthropic.claude-opus-4-5-20251101-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 200000 | 64000 | In: $5.50, Out: $27.50, Cache Read: $0.55, Cache Write: $6.88 |
| global.anthropic.claude-opus-4-5-20251101-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 200000 | 64000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| us.anthropic.claude-opus-4-5-20251101-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 64000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| anthropic.claude-opus-4-6-v1 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| eu.anthropic.claude-opus-4-6-v1 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1000000 | 128000 | In: $5.50, Out: $27.50, Cache Read: $0.55, Cache Write: $6.88 |
| global.anthropic.claude-opus-4-6-v1 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| us.anthropic.claude-opus-4-6-v1 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| anthropic.claude-opus-4-7 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| eu.anthropic.claude-opus-4-7 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 1000000 | 128000 | In: $5.50, Out: $27.50, Cache Read: $0.55, Cache Write: $6.88 |
| global.anthropic.claude-opus-4-7 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| jp.anthropic.claude-opus-4-7 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| us.anthropic.claude-opus-4-7 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming, structured_output | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| anthropic.claude-opus-4-8 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| au.anthropic.claude-opus-4-8 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| eu.anthropic.claude-opus-4-8 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 1000000 | 128000 | In: $5.50, Out: $27.50, Cache Read: $0.55, Cache Write: $6.88 |
| global.anthropic.claude-opus-4-8 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| jp.anthropic.claude-opus-4-8 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| us.anthropic.claude-opus-4-8 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming, structured_output | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| anthropic.claude-opus-5 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| au.anthropic.claude-opus-5 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| eu.anthropic.claude-opus-5 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 1000000 | 128000 | In: $5.50, Out: $27.50, Cache Read: $0.55, Cache Write: $6.88 |
| global.anthropic.claude-opus-5 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| jp.anthropic.claude-opus-5 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| us.anthropic.claude-opus-5 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| anthropic.claude-sonnet-4-5-20250929-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 200000 | 64000 | In: $3.00, Out: $15.00, Cache Read: $0.30, Cache Write: $3.75 |
| au.anthropic.claude-sonnet-4-5-20250929-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 200000 | 64000 | In: $3.00, Out: $15.00, Cache Read: $0.30, Cache Write: $3.75 |
| eu.anthropic.claude-sonnet-4-5-20250929-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 200000 | 64000 | In: $3.30, Out: $16.50, Cache Read: $0.33, Cache Write: $4.12 |
| global.anthropic.claude-sonnet-4-5-20250929-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 200000 | 64000 | In: $3.00, Out: $15.00, Cache Read: $0.30, Cache Write: $3.75 |
| jp.anthropic.claude-sonnet-4-5-20250929-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 200000 | 64000 | In: $3.00, Out: $15.00, Cache Read: $0.30, Cache Write: $3.75 |
| us.anthropic.claude-sonnet-4-5-20250929-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 64000 | In: $3.00, Out: $15.00, Cache Read: $0.30, Cache Write: $3.75 |
| anthropic.claude-sonnet-4-6 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1000000 | 64000 | In: $3.00, Out: $15.00, Cache Read: $0.30, Cache Write: $3.75 |
| eu.anthropic.claude-sonnet-4-6 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1000000 | 64000 | In: $3.30, Out: $16.50, Cache Read: $0.33, Cache Write: $4.12 |
| global.anthropic.claude-sonnet-4-6 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1000000 | 64000 | In: $3.00, Out: $15.00, Cache Read: $0.30, Cache Write: $3.75 |
| jp.anthropic.claude-sonnet-4-6 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1000000 | 64000 | In: $3.00, Out: $15.00, Cache Read: $0.30, Cache Write: $3.75 |
| us.anthropic.claude-sonnet-4-6 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 64000 | In: $3.00, Out: $15.00, Cache Read: $0.30, Cache Write: $3.75 |
| anthropic.claude-sonnet-5 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1000000 | 128000 | In: $2.00, Out: $10.00, Cache Read: $0.20, Cache Write: $2.50 |
| au.anthropic.claude-sonnet-5 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1000000 | 128000 | In: $2.00, Out: $10.00, Cache Read: $0.20, Cache Write: $2.50 |
| eu.anthropic.claude-sonnet-5 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1000000 | 128000 | In: $2.20, Out: $11.00, Cache Read: $0.22, Cache Write: $2.75 |
| global.anthropic.claude-sonnet-5 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1000000 | 128000 | In: $2.00, Out: $10.00, Cache Read: $0.20, Cache Write: $2.50 |
| jp.anthropic.claude-sonnet-5 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1000000 | 128000 | In: $2.00, Out: $10.00, Cache Read: $0.20, Cache Write: $2.50 |
| us.anthropic.claude-sonnet-5 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 128000 | In: $2.00, Out: $10.00, Cache Read: $0.20, Cache Write: $2.50 |
| openai.gpt-5.4 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 272000 | 128000 | In: $2.75, Out: $16.50, Cache Read: $0.28 |
| openai.gpt-5.5 | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 272000 | 128000 | In: $5.50, Out: $33.00, Cache Read: $0.55 |
| openai.gpt-5.6-luna | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1050000 | 128000 | In: $0.22, Out: $1.32, Cache Read: $0.02, Cache Write: $0.28 |
| us.openai.gpt-5.6-luna | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1050000 | 128000 | In: $0.22, Out: $1.32, Cache Read: $0.02, Cache Write: $0.28 |
| global.openai.gpt-5.6-luna | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1050000 | 128000 | In: $0.22, Out: $1.32, Cache Read: $0.02, Cache Write: $0.28 |
| openai.gpt-5.6-sol | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1050000 | 128000 | In: $5.50, Out: $33.00, Cache Read: $0.55, Cache Write: $6.88 |
| us.openai.gpt-5.6-sol | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1050000 | 128000 | In: $5.50, Out: $33.00, Cache Read: $0.55, Cache Write: $6.88 |
| global.openai.gpt-5.6-sol | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1050000 | 128000 | In: $5.50, Out: $33.00, Cache Read: $0.55, Cache Write: $6.88 |
| openai.gpt-5.6-terra | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1050000 | 128000 | In: $2.20, Out: $13.20, Cache Read: $0.22, Cache Write: $2.75 |
| us.openai.gpt-5.6-terra | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1050000 | 128000 | In: $2.20, Out: $13.20, Cache Read: $0.22, Cache Write: $2.75 |
| global.openai.gpt-5.6-terra | bedrock | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1050000 | 128000 | In: $2.20, Out: $13.20, Cache Read: $0.22, Cache Write: $2.75 |
| deep-research-max-preview-04-2026 | gemini | In: text, image, video, audio, pdf; Out: text, image | function_calling, reasoning, vision, video, transcription | 131072 | 65536 | In: $2.00, Out: $12.00, Cache Read: $0.20 |
| deep-research-preview-04-2026 | gemini | In: text, image, video, audio, pdf; Out: text, image | function_calling, reasoning, vision, video, transcription | 131072 | 65536 | In: $2.00, Out: $12.00, Cache Read: $0.20 |
| gemini-2.5-flash | gemini | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription, tool_choice | 1048576 | 65536 | In: $0.30, Out: $2.50, Cache Read: $0.03 |
| gemini-2.5-flash-lite | gemini | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription | 1048576 | 65536 | In: $0.10, Out: $0.40, Cache Read: $0.01 |
| gemini-2.5-pro | gemini | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription, tool_choice | 1048576 | 65536 | In: $1.25, Out: $10.00, Cache Read: $0.12 |
| gemini-3-flash-preview | gemini | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription, tool_choice | 1048576 | 65536 | In: $0.50, Out: $3.00, Cache Read: $0.05 |
| gemini-3.1-flash-lite | gemini | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription | 1048576 | 65536 | In: $0.25, Out: $1.50, Cache Read: $0.02 |
| gemini-3.1-flash-lite-preview | gemini | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription | 1048576 | 65536 | In: $0.25, Out: $1.50, Cache Read: $0.02 |
| gemini-3.1-pro-preview | gemini | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription, tool_choice | 1048576 | 65536 | In: $2.00, Out: $12.00, Cache Read: $0.20 |
| gemini-3.1-pro-preview-customtools | gemini | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription, tool_choice | 1048576 | 65536 | In: $2.00, Out: $12.00, Cache Read: $0.20 |
| gemini-3.5-flash | gemini | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription, tool_choice | 1048576 | 65536 | In: $1.50, Out: $9.00, Cache Read: $0.15 |
| gemini-3.5-flash-lite | gemini | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription | 1048576 | 65536 | In: $0.30, Out: $2.50, Cache Read: $0.03 |
| gemini-3.6-flash | gemini | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription, tool_choice | 1048576 | 65536 | In: $1.50, Out: $7.50, Cache Read: $0.15 |
| gemini-3.7-flash | gemini | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription, tool_choice | 1048576 | 65536 | In: $0.75, Out: $3.75, Cache Read: $0.08 |
| gemini-embedding-2 | gemini | In: text, image, audio, video, pdf; Out: embeddings | vision, video, tool_choice, structured_output | 8192 | 1 | In: $0.20, Out: $0.00 |
| gemini-flash-latest | gemini | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription, tool_choice | 1048576 | 65536 | In: $1.50, Out: $9.00, Cache Read: $0.15 |
| gemini-flash-lite-latest | gemini | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription | 1048576 | 65536 | In: $0.25, Out: $1.50, Cache Read: $0.02 |
| gemini-3.1-flash-image | gemini | In: text, image, video, pdf; Out: text, image | reasoning, vision, video, tool_choice, structured_output | 65536 | 65536 | In: $0.50, Out: $60.00 |
| gemini-3.1-flash-image-preview | gemini | In: text, image, pdf; Out: text, image | reasoning, vision, tool_choice, structured_output | 65536 | 65536 | In: $0.50, Out: $60.00 |
| gpt-4.1 | openai | In: text, image, pdf; Out: text | function_calling, structured_output, vision, tool_choice, parallel_tool_calls | 1047576 | 32768 | In: $2.00, Out: $8.00, Cache Read: $0.50 |
| gpt-4.1-mini | openai | In: text, image, pdf; Out: text | function_calling, structured_output, vision, tool_choice, parallel_tool_calls | 1047576 | 32768 | In: $0.40, Out: $1.60, Cache Read: $0.10 |
| gpt-4o | openai | In: text, image, pdf; Out: text | function_calling, structured_output, vision, tool_choice, parallel_tool_calls | 128000 | 16384 | In: $2.50, Out: $10.00, Cache Read: $1.25 |
| gpt-4o-mini | openai | In: text, image, pdf; Out: text | function_calling, structured_output, vision, tool_choice, parallel_tool_calls | 128000 | 16384 | In: $0.15, Out: $0.60, Cache Read: $0.08 |
| gpt-5.3-codex | openai | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, tool_choice, parallel_tool_calls | 400000 | 128000 | In: $1.75, Out: $14.00, Cache Read: $0.18 |
| gpt-5.3-codex-spark | openai | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 128000 | 32000 | In: $1.75, Out: $14.00, Cache Read: $0.18 |
| gpt-5.4 | openai | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, tool_choice, parallel_tool_calls | 1050000 | 128000 | In: $2.50, Out: $15.00, Cache Read: $0.25 |
| gpt-5.5 | openai | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, tool_choice, parallel_tool_calls | 1050000 | 128000 | In: $5.00, Out: $30.00, Cache Read: $0.50 |
| gpt-5.5-pro | openai | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, tool_choice, parallel_tool_calls | 1050000 | 128000 | In: $30.00, Out: $180.00 |
| gpt-5.6 | openai | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1050000 | 128000 | In: $5.00, Out: $30.00, Cache Read: $0.50, Cache Write: $6.25 |
| gpt-5.6-luna | openai | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, tool_choice, parallel_tool_calls | 1050000 | 128000 | In: $0.20, Out: $1.20, Cache Read: $0.02, Cache Write: $0.25 |
| gpt-5.6-sol | openai | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, tool_choice, parallel_tool_calls | 1050000 | 128000 | In: $5.00, Out: $30.00, Cache Read: $0.50, Cache Write: $6.25 |
| gpt-5.6-terra | openai | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, tool_choice, parallel_tool_calls | 1050000 | 128000 | In: $2.00, Out: $12.00, Cache Read: $0.20, Cache Write: $2.50 |
| o1 | openai | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, tool_choice, parallel_tool_calls | 200000 | 100000 | In: $15.00, Out: $60.00, Cache Read: $7.50 |
| o3 | openai | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 200000 | 100000 | In: $2.00, Out: $8.00, Cache Read: $0.50 |
| ~anthropic/claude-haiku-latest | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 64000 | In: $1.00, Out: $5.00, Cache Read: $0.10, Cache Write: $1.25 |
| ~anthropic/claude-sonnet-latest | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 128000 | In: $2.00, Out: $10.00, Cache Read: $0.20, Cache Write: $2.50 |
| openrouter/auto | openrouter | In: text, image, audio, pdf, video; Out: text, image | function_calling, structured_output, reasoning, vision, video, streaming, predicted_outputs, image_generation | 2000000 | 2000000 | - |
| anthropic/claude-fable-5 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 128000 | In: $10.00, Out: $50.00, Cache Read: $1.00, Cache Write: $12.50 |
| ~anthropic/claude-fable-latest | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 128000 | In: $10.00, Out: $50.00, Cache Read: $1.00, Cache Write: $12.50 |
| anthropic/claude-haiku-4.5 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 64000 | In: $1.00, Out: $5.00, Cache Read: $0.10, Cache Write: $1.25 |
| anthropic/claude-opus-4 | openrouter | In: image, text, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 32000 | In: $15.00, Out: $75.00, Cache Read: $1.50, Cache Write: $18.75 |
| anthropic/claude-opus-4.1 | openrouter | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 32000 | In: $15.00, Out: $75.00, Cache Read: $1.50, Cache Write: $18.75 |
| anthropic/claude-opus-4.5 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 64000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| anthropic/claude-opus-4.6 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| anthropic/claude-opus-4.7 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| anthropic/claude-opus-4.7-fast | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 128000 | In: $30.00, Out: $150.00, Cache Read: $3.00, Cache Write: $37.50 |
| anthropic/claude-opus-4.8 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| anthropic/claude-opus-4.8-fast | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 128000 | In: $10.00, Out: $50.00, Cache Read: $1.00, Cache Write: $12.50 |
| anthropic/claude-opus-5 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| anthropic/claude-opus-5-fast | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 128000 | In: $10.00, Out: $50.00, Cache Read: $1.00, Cache Write: $12.50 |
| ~anthropic/claude-opus-latest | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| anthropic/claude-sonnet-4 | openrouter | In: image, text, pdf; Out: text | function_calling, reasoning, vision, streaming | 1000000 | 64000 | In: $3.00, Out: $15.00, Cache Read: $0.30, Cache Write: $3.75 |
| anthropic/claude-sonnet-4.5 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 64000 | In: $3.00, Out: $15.00, Cache Read: $0.30, Cache Write: $3.75 |
| anthropic/claude-sonnet-4.6 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 128000 | In: $3.00, Out: $15.00, Cache Read: $0.30, Cache Write: $3.75 |
| anthropic/claude-sonnet-5 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 128000 | In: $2.00, Out: $10.00, Cache Read: $0.20, Cache Write: $2.50 |
| mistralai/codestral-2508 | openrouter | In: text, pdf; Out: text | function_calling, structured_output, vision, streaming | 256000 | 256000 | In: $0.30, Out: $0.90, Cache Read: $0.03 |
| openai/gpt-chat-latest | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, vision, streaming | 400000 | 128000 | In: $5.00, Out: $30.00, Cache Read: $0.50 |
| openai/gpt-4.1 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, vision, streaming | 1047576 | 32768 | In: $2.00, Out: $8.00, Cache Read: $0.50 |
| openai/gpt-4.1-mini | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, vision, streaming | 1047576 | 32768 | In: $0.40, Out: $1.60, Cache Read: $0.10 |
| openai/gpt-4.1-nano | openrouter | In: image, text, pdf; Out: text | function_calling, structured_output, vision, streaming | 1047576 | 32768 | In: $0.10, Out: $0.40, Cache Read: $0.02 |
| openai/gpt-4o | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, vision, streaming | 128000 | 16384 | In: $2.50, Out: $10.00, Cache Read: $1.25 |
| openai/gpt-4o-2024-05-13 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, vision, streaming | 128000 | 4096 | In: $5.00, Out: $15.00 |
| openai/gpt-4o-2024-08-06 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, vision, streaming | 128000 | 16384 | In: $2.50, Out: $10.00, Cache Read: $1.25 |
| openai/gpt-4o-2024-11-20 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, vision, streaming | 128000 | 16384 | In: $2.50, Out: $10.00, Cache Read: $1.25 |
| openai/gpt-4o-mini | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, vision, streaming | 128000 | 16384 | In: $0.15, Out: $0.60, Cache Read: $0.08 |
| openai/gpt-4o-mini-2024-07-18 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, vision, streaming | 128000 | 16384 | In: $0.15, Out: $0.60, Cache Read: $0.08 |
| openai/gpt-5 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $1.25, Out: $10.00, Cache Read: $0.12 |
| openai/gpt-5-image | openrouter | In: image, text, pdf; Out: image, text | structured_output, reasoning, vision, streaming, image_generation | 400000 | 128000 | In: $10.00, Out: $10.00, Cache Read: $1.25 |
| openai/gpt-5-image-mini | openrouter | In: pdf, image, text; Out: image, text | structured_output, reasoning, vision, streaming, image_generation | 400000 | 128000 | In: $2.50, Out: $2.00, Cache Read: $0.25 |
| openai/gpt-5-mini | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $0.25, Out: $2.00, Cache Read: $0.02 |
| openai/gpt-5-nano | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $0.05, Out: $0.40, Cache Read: $0.01 |
| openai/gpt-5-pro | openrouter | In: image, text, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $15.00, Out: $120.00 |
| openai/gpt-5.1 | openrouter | In: image, text, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $1.25, Out: $10.00, Cache Read: $0.12 |
| openai/gpt-5.2 | openrouter | In: pdf, image, text; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $1.75, Out: $14.00, Cache Read: $0.18 |
| openai/gpt-5.2-chat | openrouter | In: pdf, image, text; Out: text | function_calling, structured_output, vision, streaming | 128000 | 32000 | In: $1.75, Out: $14.00, Cache Read: $0.18 |
| openai/gpt-5.2-pro | openrouter | In: image, text, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $21.00, Out: $168.00 |
| openai/gpt-5.3-codex | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $1.75, Out: $14.00, Cache Read: $0.18 |
| openai/gpt-5.4 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1050000 | 128000 | In: $2.50, Out: $15.00, Cache Read: $0.25 |
| openai/gpt-5.4-image-2 | openrouter | In: image, text, pdf; Out: image, text | structured_output, reasoning, vision, streaming, image_generation | 272000 | 128000 | In: $8.00, Out: $15.00, Cache Read: $2.00 |
| openai/gpt-5.4-pro | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1050000 | 128000 | In: $30.00, Out: $180.00 |
| openai/gpt-5.4-mini | openrouter | In: pdf, image, text; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $0.75, Out: $4.50, Cache Read: $0.08 |
| openai/gpt-5.4-nano | openrouter | In: pdf, image, text; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $0.20, Out: $1.25, Cache Read: $0.02 |
| openai/gpt-5.5 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1050000 | 128000 | In: $5.00, Out: $30.00, Cache Read: $0.50 |
| openai/gpt-5.5-pro | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1050000 | 128000 | In: $30.00, Out: $180.00 |
| openai/gpt-5.6-luna | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1050000 | 128000 | In: $0.20, Out: $1.20, Cache Read: $0.02, Cache Write: $0.25 |
| openai/gpt-5.6-luna-pro | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1050000 | 128000 | In: $0.20, Out: $1.20, Cache Read: $0.02, Cache Write: $0.25 |
| openai/gpt-5.6-sol | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1050000 | 128000 | In: $2.50, Out: $15.00, Cache Read: $0.25, Cache Write: $3.12 |
| openai/gpt-5.6-sol-pro | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1050000 | 128000 | In: $2.50, Out: $15.00, Cache Read: $0.25, Cache Write: $3.12 |
| openai/gpt-5.6-terra | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1050000 | 128000 | In: $2.00, Out: $12.00, Cache Read: $0.20, Cache Write: $2.50 |
| openai/gpt-5.6-terra-pro | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1050000 | 128000 | In: $2.00, Out: $12.00, Cache Read: $0.20, Cache Write: $2.50 |
| google/gemini-2.5-flash | openrouter | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1048576 | 65535 | In: $0.30, Out: $2.50, Cache Read: $0.03, Cache Write: $0.08 |
| google/gemini-2.5-flash-lite | openrouter | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1048576 | 65535 | In: $0.10, Out: $0.40, Cache Read: $0.01, Cache Write: $0.08 |
| google/gemini-2.5-pro | openrouter | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1048576 | 65536 | In: $1.25, Out: $10.00, Cache Read: $0.12, Cache Write: $0.38 |
| google/gemini-2.5-pro-preview-05-06 | openrouter | In: text, image, pdf, audio, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1048576 | 65535 | In: $1.25, Out: $10.00, Cache Read: $0.12, Cache Write: $0.38 |
| google/gemini-2.5-pro-preview | openrouter | In: pdf, image, text, audio; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1048576 | 65536 | In: $1.25, Out: $10.00, Cache Read: $0.12, Cache Write: $0.38 |
| google/gemini-3-flash-preview | openrouter | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1048576 | 65536 | In: $0.50, Out: $3.00, Cache Read: $0.05, Cache Write: $0.08 |
| google/gemini-3.1-flash-lite | openrouter | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1048576 | 65536 | In: $0.25, Out: $1.50, Cache Read: $0.02, Cache Write: $0.08 |
| google/gemini-3.1-flash-lite-preview | openrouter | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1048576 | 65536 | In: $0.25, Out: $1.50, Cache Read: $0.02, Cache Write: $0.08 |
| google/gemini-3.1-pro-preview | openrouter | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1048576 | 65536 | In: $2.00, Out: $12.00, Cache Read: $0.20, Cache Write: $0.38 |
| google/gemini-3.1-pro-preview-customtools | openrouter | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1048576 | 65536 | In: $2.00, Out: $12.00, Cache Read: $0.20, Cache Write: $0.38 |
| google/gemini-3.5-flash | openrouter | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1048576 | 65536 | In: $1.50, Out: $9.00, Cache Read: $0.15, Cache Write: $0.08 |
| google/gemini-3.5-flash-lite | openrouter | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1048576 | 65536 | In: $0.30, Out: $2.50, Cache Read: $0.03, Cache Write: $0.08 |
| google/gemini-3.6-flash | openrouter | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1048576 | 65536 | In: $0.75, Out: $3.75, Cache Read: $0.08, Cache Write: $0.04 |
| google/gemini-3.7-flash | openrouter | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1048576 | 65536 | In: $0.38, Out: $1.88, Cache Read: $0.04, Cache Write: $0.02 |
| ~google/gemini-flash-latest | openrouter | In: text, image, video, pdf, audio; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1048576 | 65536 | In: $0.38, Out: $1.88, Cache Read: $0.04, Cache Write: $0.02 |
| ~google/gemini-pro-latest | openrouter | In: audio, pdf, image, text, video; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1048576 | 65536 | In: $2.00, Out: $12.00, Cache Read: $0.20, Cache Write: $0.38 |
| x-ai/grok-4.20 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 2000000 | 2000000 | In: $1.25, Out: $2.50, Cache Read: $0.20 |
| x-ai/grok-4.20-multi-agent | openrouter | In: text, image, pdf; Out: text | structured_output, reasoning, vision, streaming | 2000000 | 2000000 | In: $1.25, Out: $2.50, Cache Read: $0.20 |
| x-ai/grok-4.3 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 1000000 | In: $1.25, Out: $2.50, Cache Read: $0.20 |
| x-ai/grok-4.5 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 500000 | 500000 | In: $2.00, Out: $6.00, Cache Read: $0.30 |
| x-ai/grok-4.6 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 500000 | 500000 | In: $2.00, Out: $6.00, Cache Read: $0.50 |
| x-ai/grok-build-0.1 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 256000 | 256000 | In: $1.00, Out: $2.00, Cache Read: $0.20 |
| ~x-ai/grok-latest | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 500000 | 1000000 | In: $2.00, Out: $6.00, Cache Read: $0.50 |
| mistralai/mistral-large | openrouter | In: text, pdf; Out: text | function_calling, structured_output, vision, streaming | 128000 | 128000 | In: $2.00, Out: $6.00, Cache Read: $0.20 |
| mistralai/mistral-large-2407 | openrouter | In: text, pdf; Out: text | function_calling, structured_output, vision, streaming | 131072 | 131072 | In: $2.00, Out: $6.00, Cache Read: $0.20 |
| mistralai/mistral-large-2512 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, vision, streaming | 262144 | 262144 | In: $0.50, Out: $1.50, Cache Read: $0.05 |
| mistralai/mistral-medium-3 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, vision, streaming | 131072 | 131072 | In: $0.40, Out: $2.00, Cache Read: $0.04 |
| mistralai/mistral-medium-3.1 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, vision, streaming | 131072 | 262144 | In: $0.40, Out: $2.00, Cache Read: $0.04 |
| mistralai/mistral-medium-3-5 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 262144 | 262144 | In: $1.50, Out: $7.50 |
| mistralai/mixtral-8x22b-instruct | openrouter | In: text, pdf; Out: text | function_calling, structured_output, vision, streaming | 65536 | 65536 | In: $2.00, Out: $6.00, Cache Read: $0.20 |
| meta/muse-spark-1.1 | openrouter | In: text, image, video, pdf, audio; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1048576 | 1048576 | In: $1.25, Out: $4.25, Cache Read: $0.15 |
| meta/muse-spark-1.2 | openrouter | In: text, image, video, pdf, audio; Out: text | function_calling, structured_output, reasoning, vision, video, streaming | 1048576 | 1048576 | In: $1.25, Out: $4.25, Cache Read: $0.15 |
| amazon/nova-2-lite-v1 | openrouter | In: text, image, video, pdf; Out: text | function_calling, reasoning, vision, video, streaming | 1000000 | 65535 | In: $0.30, Out: $2.50 |
| ~openai/gpt-latest | openrouter | In: pdf, image, text; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1050000 | 128000 | In: $2.50, Out: $15.00, Cache Read: $0.25, Cache Write: $3.12 |
| ~openai/gpt-mini-latest | openrouter | In: pdf, image, text; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $0.75, Out: $4.50, Cache Read: $0.08 |
| mistralai/mistral-saba | openrouter | In: text, pdf; Out: text | function_calling, structured_output, vision, streaming | 32768 | 32768 | In: $0.20, Out: $0.60, Cache Read: $0.02 |
| sakana/sakana-namazu | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 262144 | 65536 | In: $0.95, Out: $4.00, Cache Read: $0.15 |
| mistralai/voxtral-small-24b-2507 | openrouter | In: text, audio, pdf; Out: text | function_calling, structured_output, vision, streaming | 32000 | 32000 | In: $0.10, Out: $0.30, Cache Read: $0.01 |
| openai/o1 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 100000 | In: $15.00, Out: $60.00, Cache Read: $7.50 |
| openai/o1-pro | openrouter | In: text, image, pdf; Out: text | structured_output, reasoning, vision, streaming | 200000 | 100000 | In: $150.00, Out: $600.00 |
| openai/o3 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 100000 | In: $2.00, Out: $8.00, Cache Read: $0.50 |
| openai/o3-mini-high | openrouter | In: text, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 100000 | In: $1.10, Out: $4.40, Cache Read: $0.55 |
| openai/o3-mini | openrouter | In: text, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 100000 | In: $1.10, Out: $4.40, Cache Read: $0.55 |
| openai/o3-pro | openrouter | In: text, pdf, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 100000 | In: $20.00, Out: $80.00 |
| openai/o4-mini-high | openrouter | In: image, text, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 100000 | In: $1.10, Out: $4.40, Cache Read: $0.28 |
| openai/o4-mini | openrouter | In: image, text, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 100000 | In: $1.10, Out: $4.40, Cache Read: $0.28 |
| claude-haiku-4-5 | vertexai | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 64000 | In: $1.00, Out: $5.00, Cache Read: $0.10, Cache Write: $1.25 |
| claude-opus-4 | vertexai | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 200000 | 32000 | In: $15.00, Out: $75.00, Cache Read: $1.50, Cache Write: $18.75 |
| claude-opus-4-1 | vertexai | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 32000 | In: $15.00, Out: $75.00, Cache Read: $1.50, Cache Write: $18.75 |
| claude-opus-4-5 | vertexai | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 64000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| claude-opus-4-6 | vertexai | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| claude-opus-4-7 | vertexai | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| claude-opus-4-8 | vertexai | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| claude-opus-5 | vertexai | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache Read: $0.50, Cache Write: $6.25 |
| claude-sonnet-4 | vertexai | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 200000 | 64000 | In: $3.00, Out: $15.00, Cache Read: $0.30, Cache Write: $3.75 |
| claude-sonnet-4-5 | vertexai | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 64000 | In: $3.00, Out: $15.00, Cache Read: $0.30, Cache Write: $3.75 |
| claude-sonnet-4-6 | vertexai | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 1000000 | 128000 | In: $3.00, Out: $15.00, Cache Read: $0.30, Cache Write: $3.75 |
| claude-sonnet-5 | vertexai | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 1000000 | 128000 | In: $2.00, Out: $10.00, Cache Read: $0.20, Cache Write: $2.50 |
| deepseek-ai/deepseek-v3.1-maas | vertexai | In: text, pdf; Out: text | function_calling, structured_output, reasoning, vision | 163840 | 32768 | In: $0.60, Out: $1.70 |
| deepseek-ai/deepseek-v3.2-maas | vertexai | In: text, pdf; Out: text | function_calling, structured_output, reasoning, vision | 163840 | 65536 | In: $0.56, Out: $1.68, Cache Read: $0.06 |
| zai-org/glm-4.7-maas | vertexai | In: text, pdf; Out: text | function_calling, structured_output, reasoning, vision | 200000 | 128000 | In: $0.60, Out: $2.20 |
| gemini-2.5-flash | vertexai | In: text, image, audio, video, pdf; Out: text | function_calling, reasoning, vision, video, transcription, streaming | 1048576 | 65536 | In: $0.30, Out: $2.50, Cache Read: $0.08, Cache Write: $0.38 |
| gemini-2.5-flash-lite | vertexai | In: text, image, audio, video, pdf; Out: text | function_calling, reasoning, vision, video, transcription, streaming | 1048576 | 65536 | In: $0.10, Out: $0.40, Cache Read: $0.01 |
| gemini-2.5-pro | vertexai | In: text, image, audio, video, pdf; Out: text | function_calling, reasoning, vision, video, transcription, streaming | 1048576 | 65536 | In: $1.25, Out: $10.00, Cache Read: $0.12 |
| gemini-3-flash-preview | vertexai | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription, streaming | 1048576 | 65536 | In: $0.50, Out: $3.00, Cache Read: $0.05 |
| gemini-3.1-flash-lite | vertexai | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription, streaming | 1048576 | 65536 | In: $0.25, Out: $1.50, Cache Read: $0.02 |
| gemini-3.1-flash-lite-preview | vertexai | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription | 1048576 | 65536 | In: $0.25, Out: $1.50, Cache Read: $0.02 |
| gemini-3.1-pro-preview | vertexai | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription, streaming | 1048576 | 65536 | In: $2.00, Out: $12.00, Cache Read: $0.20 |
| gemini-3.1-pro-preview-customtools | vertexai | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription | 1048576 | 65536 | In: $2.00, Out: $12.00, Cache Read: $0.20 |
| gemini-3.5-flash | vertexai | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription, streaming | 1048576 | 65536 | In: $1.50, Out: $9.00, Cache Read: $0.15 |
| gemini-3.5-flash-lite | vertexai | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription, streaming | 1048576 | 65536 | In: $0.30, Out: $2.50, Cache Read: $0.03 |
| gemini-3.6-flash | vertexai | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription, streaming | 1048576 | 65536 | In: $1.50, Out: $7.50, Cache Read: $0.15 |
| gemini-3.7-flash | vertexai | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription, streaming | 1048576 | 65536 | In: $0.75, Out: $3.75, Cache Read: $0.08 |
| gemini-embedding-2 | vertexai | In: text, image, audio, video, pdf; Out: embeddings | vision, video, streaming | 8192 | 1 | In: $0.20, Out: $0.00 |
| gemini-flash-latest | vertexai | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, video, transcription | 1048576 | 65536 | In: $1.50, Out: $9.00, Cache Read: $0.15 |
| gemini-flash-lite-latest | vertexai | In: text, image, video, audio, pdf; Out: text | function_calling, reasoning, vision, video, transcription | 1048576 | 65536 | In: $0.25, Out: $1.50, Cache Read: $0.02 |
| gemini-3.1-flash-image | vertexai | In: text, image, video, pdf; Out: text, image | reasoning, vision, video, streaming | 131072 | 32768 | In: $0.50, Out: $60.00 |
| gemini-3.1-flash-image-preview | vertexai | In: text, image, pdf; Out: text, image | reasoning, vision, streaming | 65536 | 65536 | In: $0.50, Out: $60.00 |
| grok-4.20-0309-non-reasoning | xai | In: text, image, pdf; Out: text | function_calling, structured_output, vision, streaming | 1000000 | 30000 | In: $1.25, Out: $2.50, Cache Read: $0.20 |
| grok-4.20-0309-reasoning | xai | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 30000 | In: $1.25, Out: $2.50, Cache Read: $0.20 |
| grok-4.20-multi-agent-0309 | xai | In: text, image, pdf; Out: text | structured_output, reasoning, vision, streaming | 1000000 | 30000 | In: $1.25, Out: $2.50, Cache Read: $0.20 |
| grok-4.3 | xai | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 30000 | In: $1.25, Out: $2.50, Cache Read: $0.20 |
| grok-4.5 | xai | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 500000 | 500000 | In: $2.00, Out: $6.00, Cache Read: $0.30 |
| grok-4.6 | xai | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 500000 | 500000 | In: $2.00, Out: $6.00, Cache Read: $0.50 |
| grok-build-0.1 | xai | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 256000 | 256000 | In: $1.00, Out: $2.00, Cache Read: $0.20 |
| grok-imagine-image | xai | In: text, image, pdf; Out: image | vision | 8000 | 0 | - |
| grok-imagine-image-2.0 | xai | In: text, image, pdf; Out: image | vision | 8000 | 0 | - |
| grok-imagine-image-quality | xai | In: text, image, pdf; Out: image | vision | 8000 | 0 | - |
| grok-imagine-video | xai | In: text, image, video, pdf; Out: video | vision, video | 1024 | 0 | - |
| grok-imagine-video-1.5 | xai | In: text, image, audio, pdf; Out: video | vision | 1024 | 0 | - |


### Embedding Models (69)

Models that generate embeddings:

| Model | Provider | I/O | Capabilities | Context | Max Output | Standard Pricing (per 1M tokens) |
| :-- | :-- | :-- | :-- | --: | --: | :-- |
| text-embedding-3-large | azure | In: text; Out: embeddings | - | - | - | - |
| text-embedding-3-small | azure | In: text; Out: embeddings | - | - | - | - |
| text-embedding-ada-002 | azure | In: text; Out: embeddings | - | - | - | - |
| text-embedding-ada-002-2 | azure | In: text; Out: embeddings | - | - | - | - |
| cohere.embed-english-v3 | bedrock | In: text; Out: embeddings | - | - | - | - |
| cohere.embed-english-v3:0:512 | bedrock | In: text; Out: embeddings | - | - | - | - |
| cohere.embed-multilingual-v3 | bedrock | In: text; Out: embeddings | - | - | - | - |
| cohere.embed-multilingual-v3:0:512 | bedrock | In: text; Out: embeddings | - | - | - | - |
| us.cohere.embed-v4:0 | bedrock | In: text, image; Out: embeddings | - | 128000 | - | - |
| amazon.titan-embed-text-v1 | bedrock | In: text; Out: embeddings | - | - | - | - |
| amazon.titan-embed-text-v1:2:8k | bedrock | In: text; Out: embeddings | - | - | - | - |
| amazon.titan-embed-image-v1 | bedrock | In: text, image; Out: embeddings | - | - | - | - |
| amazon.titan-embed-image-v1:0 | bedrock | In: text, image; Out: embeddings | - | - | - | - |
| amazon.titan-embed-text-v2:0 | bedrock | In: text; Out: embeddings | - | - | - | - |
| amazon.titan-embed-g1-text-02 | bedrock | In: text; Out: embeddings | - | - | - | - |
| embed-english-light-v3.0 | cohere | In: text, image; Out: embeddings | - | 512 | - | - |
| embed-english-light-v3.0-image | cohere | In: text, image; Out: embeddings | - | 0 | - | - |
| embed-english-v3.0 | cohere | In: text, image; Out: embeddings | - | 512 | - | - |
| embed-english-v3.0-image | cohere | In: text, image; Out: embeddings | - | 0 | - | - |
| embed-multilingual-light-v3.0 | cohere | In: text, image; Out: embeddings | - | 512 | - | - |
| embed-multilingual-light-v3.0-image | cohere | In: text, image; Out: embeddings | - | 0 | - | - |
| embed-multilingual-v3.0 | cohere | In: text, image; Out: embeddings | - | 512 | - | - |
| embed-multilingual-v3.0-image | cohere | In: text, image; Out: embeddings | - | 0 | - | - |
| embed-v4.0 | cohere | In: text, image; Out: embeddings | - | 8192 | - | - |
| gemini-embedding-001 | gemini | In: text; Out: embeddings | - | 2048 | 1 | In: $0.15, Out: $0.00 |
| gemini-embedding-2 | gemini | In: text, image, audio, video, pdf; Out: embeddings | vision, video, tool_choice, structured_output | 8192 | 1 | In: $0.20, Out: $0.00 |
| codestral-embed | mistral | In: text; Out: embeddings | predicted_outputs | 8192 | 8192 | - |
| codestral-embed-2505 | mistral | In: text; Out: embeddings | predicted_outputs | 8192 | 8192 | - |
| mistral-embed-2312 | mistral | In: text; Out: embeddings | - | 8192 | 8192 | - |
| text-embedding-3-large | openai | In: text; Out: embeddings | - | 8191 | 3072 | In: $0.13, Out: $0.00 |
| text-embedding-3-small | openai | In: text; Out: embeddings | - | 8191 | 1536 | In: $0.02, Out: $0.00 |
| text-embedding-ada-002 | openai | In: text; Out: embeddings | - | 8192 | 1536 | In: $0.10, Out: $0.00 |
| baai/bge-base-en-v1.5 | openrouter | In: text; Out: embeddings | streaming, structured_output | 512 | - | In: $0.01 |
| baai/bge-large-en-v1.5 | openrouter | In: text; Out: embeddings | streaming, structured_output | 512 | - | In: $0.01 |
| baai/bge-m3 | openrouter | In: text; Out: embeddings | streaming, structured_output, predicted_outputs | 8194 | - | In: $0.01 |
| google/gemini-embedding-001 | openrouter | In: text; Out: embeddings | streaming, structured_output | 20000 | - | In: $0.15 |
| google/gemini-embedding-2 | openrouter | In: text, image, file, audio, video; Out: embeddings | streaming, structured_output | 8192 | - | In: $0.20 |
| google/gemini-embedding-2-preview | openrouter | In: text, image, file, audio, video; Out: embeddings | streaming, structured_output | 8192 | - | In: $0.20 |
| intfloat/e5-base-v2 | openrouter | In: text; Out: embeddings | streaming, structured_output | 512 | - | In: $0.01 |
| intfloat/e5-large-v2 | openrouter | In: text; Out: embeddings | streaming, structured_output | 512 | - | In: $0.01 |
| intfloat/multilingual-e5-large | openrouter | In: text; Out: embeddings | streaming, structured_output | 512 | - | In: $0.01 |
| liquid/lfm-2.5-embedding-350m:free | openrouter | In: text; Out: embeddings | streaming | 512 | - | - |
| mistralai/codestral-embed-2505 | openrouter | In: text; Out: embeddings | streaming, structured_output | 8192 | - | In: $0.15 |
| mistralai/mistral-embed-2312 | openrouter | In: text; Out: embeddings | streaming, structured_output | 8192 | - | In: $0.10 |
| nvidia/llama-nemotron-embed-vl-1b-v2:free | openrouter | In: text, image; Out: embeddings | streaming | 131072 | - | - |
| nvidia/nemotron-3-embed-1b:free | openrouter | In: text; Out: embeddings | streaming | 32768 | - | - |
| openai/text-embedding-3-large | openrouter | In: text; Out: embeddings | streaming, structured_output | 8192 | - | In: $0.13 |
| openai/text-embedding-3-small | openrouter | In: text; Out: embeddings | streaming, structured_output | 8192 | - | In: $0.02 |
| openai/text-embedding-ada-002 | openrouter | In: text; Out: embeddings | streaming, structured_output | 8192 | - | In: $0.10 |
| perplexity/pplx-embed-v1-0.6b | openrouter | In: text; Out: embeddings | streaming | 32000 | - | In: $0.00 |
| perplexity/pplx-embed-v1-4b | openrouter | In: text; Out: embeddings | streaming | 32000 | - | In: $0.03 |
| qwen/qwen3-embedding-4b | openrouter | In: text; Out: embeddings | streaming, structured_output | 32768 | - | In: $0.02 |
| qwen/qwen3-embedding-8b | openrouter | In: text; Out: embeddings | streaming, structured_output, predicted_outputs | 32768 | 32000 | In: $0.01 |
| sentence-transformers/all-minilm-l12-v2 | openrouter | In: text; Out: embeddings | streaming, structured_output | 512 | - | In: $0.01 |
| sentence-transformers/all-minilm-l6-v2 | openrouter | In: text; Out: embeddings | streaming, structured_output | 512 | - | In: $0.01 |
| sentence-transformers/all-mpnet-base-v2 | openrouter | In: text; Out: embeddings | streaming, structured_output | 512 | - | In: $0.01 |
| sentence-transformers/multi-qa-mpnet-base-dot-v1 | openrouter | In: text; Out: embeddings | streaming, structured_output | 512 | - | In: $0.01 |
| sentence-transformers/paraphrase-minilm-l6-v2 | openrouter | In: text; Out: embeddings | streaming, structured_output | 512 | - | In: $0.01 |
| thenlper/gte-base | openrouter | In: text; Out: embeddings | streaming, structured_output | 512 | - | In: $0.01 |
| thenlper/gte-large | openrouter | In: text; Out: embeddings | streaming, structured_output | 512 | - | In: $0.01 |
| voyageai/voyage-4 | openrouter | In: text; Out: embeddings | streaming | 32000 | - | In: $0.06 |
| voyageai/voyage-4-large | openrouter | In: text; Out: embeddings | streaming | 32000 | - | In: $0.12 |
| voyageai/voyage-4-lite | openrouter | In: text; Out: embeddings | streaming | 32000 | - | In: $0.02 |
| voyageai/voyage-code-4 | openrouter | In: text; Out: embeddings | streaming | 32000 | - | In: $0.12 |
| voyageai/voyage-multimodal-3.5 | openrouter | In: text, image; Out: embeddings | streaming | 32000 | - | In: $0.12 |
| pplx-embed-v1-0.6b | perplexity | In: text; Out: embeddings | - | 32768 | - | In: $0.00 |
| pplx-embed-v1-4b | perplexity | In: text; Out: embeddings | - | 32768 | - | In: $0.03 |
| gemini-embedding-001 | vertexai | In: text; Out: embeddings | streaming | 2048 | 1 | In: $0.15, Out: $0.00 |
| gemini-embedding-2 | vertexai | In: text, image, audio, video, pdf; Out: embeddings | vision, video, streaming | 8192 | 1 | In: $0.20, Out: $0.00 |


---

_Provider availability can vary by account and region. Model information is enriched by [models.dev](https://models.dev) and RubyLLM's provider integrations._
