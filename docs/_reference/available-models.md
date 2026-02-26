---
layout: default
title: Available Models
nav_order: 1
description: Browse 1177 AI models across 12 providers (not including local providers). Updated 2026-02-26.
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

_Model information enriched by [models.dev](https://models.dev) and our custom code._

Can't find a newly released model? Refresh your registry:

```ruby
# Plain Ruby
RubyLLM.models.refresh!

# Rails
Model.refresh!
```

See [Model Registry: Refreshing the Registry]({% link _advanced/models.md %}#refreshing-the-registry).

## Models by Provider

### Anthropic (23)

| Model | Provider | I/O | Capabilities | Context | Max Output | Standard Pricing (per 1M tokens) |
| :-- | :-- | :-- | :-- | --: | --: | :-- |
| claude-3-haiku-20240307 | anthropic | In: text, image, pdf; Out: text | function_calling, vision, streaming, batch | 200000 | 4096 | In: $0.25, Out: $1.25, Cache: $0.03 |
| claude-3-5-haiku-20241022 | anthropic | In: text, image, pdf; Out: text | function_calling, vision | 200000 | 8192 | In: $0.80, Out: $4.00, Cache: $0.08 |
| claude-3-5-haiku-latest | anthropic | In: text, image, pdf; Out: text | function_calling, vision | 200000 | 8192 | In: $0.80, Out: $4.00, Cache: $0.08 |
| claude-haiku-4-5-20251001 | anthropic | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 64000 | In: $1.00, Out: $5.00, Cache: $0.10 |
| claude-haiku-4-5 | anthropic | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 200000 | 64000 | In: $1.00, Out: $5.00, Cache: $0.10 |
| claude-3-opus-20240229 | anthropic | In: text, image, pdf; Out: text | function_calling, vision | 200000 | 4096 | In: $15.00, Out: $75.00, Cache: $1.50 |
| claude-opus-4-20250514 | anthropic | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 32000 | In: $15.00, Out: $75.00, Cache: $1.50 |
| claude-opus-4-0 | anthropic | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 200000 | 32000 | In: $15.00, Out: $75.00, Cache: $1.50 |
| claude-opus-4-1-20250805 | anthropic | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 32000 | In: $15.00, Out: $75.00, Cache: $1.50 |
| claude-opus-4-1 | anthropic | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 200000 | 32000 | In: $15.00, Out: $75.00, Cache: $1.50 |
| claude-opus-4-5-20251101 | anthropic | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 64000 | In: $5.00, Out: $25.00, Cache: $0.50 |
| claude-opus-4-5 | anthropic | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 200000 | 64000 | In: $5.00, Out: $25.00, Cache: $0.50 |
| claude-opus-4-6 | anthropic | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 128000 | In: $5.00, Out: $25.00, Cache: $0.50 |
| claude-3-sonnet-20240229 | anthropic | In: text, image, pdf; Out: text | function_calling, vision | 200000 | 4096 | In: $3.00, Out: $15.00, Cache: $0.30 |
| claude-3-5-sonnet-20240620 | anthropic | In: text, image, pdf; Out: text | function_calling, vision | 200000 | 8192 | In: $3.00, Out: $15.00, Cache: $0.30 |
| claude-3-5-sonnet-20241022 | anthropic | In: text, image, pdf; Out: text | function_calling, vision | 200000 | 8192 | In: $3.00, Out: $15.00, Cache: $0.30 |
| claude-3-7-sonnet-20250219 | anthropic | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 200000 | 64000 | In: $3.00, Out: $15.00, Cache: $0.30 |
| claude-3-7-sonnet-latest | anthropic | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 200000 | 64000 | In: $3.00, Out: $15.00, Cache: $0.30 |
| claude-sonnet-4-20250514 | anthropic | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 64000 | In: $3.00, Out: $15.00, Cache: $0.30 |
| claude-sonnet-4-0 | anthropic | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 200000 | 64000 | In: $3.00, Out: $15.00, Cache: $0.30 |
| claude-sonnet-4-5-20250929 | anthropic | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 64000 | In: $3.00, Out: $15.00, Cache: $0.30 |
| claude-sonnet-4-5 | anthropic | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 200000 | 64000 | In: $3.00, Out: $15.00, Cache: $0.30 |
| claude-sonnet-4-6 | anthropic | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 64000 | In: $3.00, Out: $15.00, Cache: $0.30 |


### Azure (266)

| Model | Provider | I/O | Capabilities | Context | Max Output | Standard Pricing (per 1M tokens) |
| :-- | :-- | :-- | :-- | --: | --: | :-- |
| ada | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| AI21-Jamba-1.5-Large | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| AI21-Jamba-1.5-Mini | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| AI21-Jamba-Instruct | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| aoai-sora | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| aoai-sora-2025-02-28 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| babbage | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.40, Out: $0.40 |
| claude-haiku-4-5-20251001 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| claude-opus-4-1-20250805 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| claude-opus-4-5-20251101 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| claude-sonnet-4-5-20250929 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| code-cushman-001 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| code-cushman-fine-tune-002 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| code-davinci-002 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| code-davinci-fine-tune-002 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| code-search-ada-code-001 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| code-search-ada-text-001 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| code-search-babbage-code-001 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| code-search-babbage-text-001 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Codestral-2501-2 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| codex-mini-2025-05-16 | azure | In: text; Out: text | streaming, reasoning | 4096 | 16384 | In: $0.50, Out: $1.50 |
| cohere-command-a | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Cohere-command-r | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Cohere-command-r-08-2024 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Cohere-command-r-plus | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Cohere-command-r-plus-08-2024 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Cohere-embed-v3-english | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Cohere-embed-v3-multilingual | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Cohere-rerank-v4.0-fast | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Cohere-rerank-v4.0-pro | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| computer-use-preview-2025-04-15 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| curie | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| dall-e-2 | azure | In: text; Out: text, image | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| dall-e-2-2.0 | azure | In: text; Out: text, image | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| dall-e-3 | azure | In: text; Out: text, image | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| dall-e-3-3.0 | azure | In: text; Out: text, image | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| davinci | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $2.00, Out: $2.00 |
| DeepSeek-R1 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| DeepSeek-R1-0528 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| DeepSeek-V3 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| DeepSeek-V3-0324 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| DeepSeek-V3.1 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| DeepSeek-V3.2 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| DeepSeek-V3.2-Speciale | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| embed-v-4-0 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| FLUX-1.1-pro | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| FLUX.1-Kontext-pro | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| FLUX.2-pro | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| gpt-35-turbo | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| gpt-35-turbo-0125 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| gpt-35-turbo-0301 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| gpt-35-turbo-0613 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| gpt-35-turbo-1106 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| gpt-35-turbo-16k | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| gpt-35-turbo-16k-0613 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| gpt-35-turbo-instruct | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| gpt-35-turbo-instruct-0914 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| gpt-4 | azure | In: text, image, pdf; Out: text | streaming, function_calling | 8192 | 8192 | In: $10.00, Out: $30.00 |
| gpt-4-0125-Preview | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| gpt-4-0314 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| gpt-4-0613 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| gpt-4-1106-Preview | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| gpt-4-32k | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| gpt-4-32k-0314 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| gpt-4-32k-0613 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| gpt-4-turbo-2024-04-09 | azure | In: text, image, pdf; Out: text | streaming, function_calling | 128000 | 4096 | In: $10.00, Out: $30.00 |
| gpt-4-turbo-jp | azure | In: text, image, pdf; Out: text | streaming, function_calling | 128000 | 4096 | In: $10.00, Out: $30.00 |
| gpt-4-vision-preview | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| gpt-4.1 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output | 1047576 | 32768 | In: $2.00, Out: $8.00, Cache: $0.50 |
| gpt-4.1-2025-04-14 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output | 1047576 | 32768 | In: $2.00, Out: $8.00, Cache: $0.50 |
| gpt-4.1-2025-04-14-text | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output | 1047576 | 32768 | In: $2.00, Out: $8.00, Cache: $0.50 |
| gpt-4.1-mini | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output | 1047576 | 32768 | In: $0.40, Out: $1.60, Cache: $0.10 |
| gpt-4.1-mini-2025-04-14 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output | 1047576 | 32768 | In: $0.40, Out: $1.60, Cache: $0.10 |
| gpt-4.1-nano | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output | 1047576 | 32768 | In: $0.10, Out: $0.40 |
| gpt-4.1-nano-2025-04-14 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output | 1047576 | 32768 | In: $0.10, Out: $0.40 |
| gpt-4o | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output | 128000 | 16384 | In: $2.50, Out: $10.00 |
| gpt-4o-2024-05-13 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output | 128000 | 16384 | In: $2.50, Out: $10.00 |
| gpt-4o-2024-08-06 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output | 128000 | 16384 | In: $2.50, Out: $10.00 |
| gpt-4o-2024-11-20 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output | 128000 | 16384 | In: $2.50, Out: $10.00 |
| gpt-4o-canvas-2024-09-25 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output | 128000 | 16384 | In: $2.50, Out: $10.00 |
| gpt-4o-audio-mai | azure | In: text, audio; Out: text, audio | streaming, speech_generation, transcription | 128000 | 16384 | In: $2.50, Out: $10.00 |
| gpt-4o-audio-preview-2024-10-01 | azure | In: text, audio; Out: text, audio | streaming, speech_generation, transcription | 128000 | 16384 | In: $2.50, Out: $10.00 |
| gpt-4o-audio-preview-2024-12-17 | azure | In: text, audio; Out: text, audio | streaming, speech_generation, transcription | 128000 | 16384 | In: $2.50, Out: $10.00 |
| gpt-4o-audio-preview-2025-06-03 | azure | In: text, audio; Out: text, audio | streaming, speech_generation, transcription | 128000 | 16384 | In: $2.50, Out: $10.00 |
| gpt-4o-mini | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output | 128000 | 16384 | In: $0.15, Out: $0.60 |
| gpt-4o-mini-2024-07-18 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output | 128000 | 16384 | In: $0.15, Out: $0.60 |
| gpt-4o-mini-audio-preview-2024-12-17 | azure | In: text, audio; Out: text, audio | streaming, speech_generation, transcription | 128000 | 16384 | In: $0.15, Out: $0.60 |
| gpt-4o-mini-realtime-preview-2024-12-17 | azure | In: text; Out: text | streaming | 128000 | 4096 | In: $0.60, Out: $2.40 |
| gpt-4o-mini-transcribe | azure | In: text, audio; Out: text | streaming | 16000 | 2000 | In: $1.25, Out: $5.00 |
| gpt-4o-mini-transcribe-2025-03-20 | azure | In: text, audio; Out: text | streaming | 16000 | 2000 | In: $1.25, Out: $5.00 |
| gpt-4o-mini-transcribe-2025-12-15 | azure | In: text, audio; Out: text | streaming | 16000 | 2000 | In: $1.25, Out: $5.00 |
| gpt-4o-mini-tts | azure | In: text, audio; Out: text, audio | streaming | - | - | In: $0.60, Out: $12.00 |
| gpt-4o-mini-tts-2025-03-20 | azure | In: text, audio; Out: text, audio | streaming | - | - | In: $0.60, Out: $12.00 |
| gpt-4o-mini-tts-2025-12-15 | azure | In: text, audio; Out: text, audio | streaming | - | - | In: $0.60, Out: $12.00 |
| gpt-4o-realtime-preview | azure | In: text; Out: text | streaming | 128000 | 4096 | In: $5.00, Out: $20.00 |
| gpt-4o-realtime-preview-2024-12-17 | azure | In: text; Out: text | streaming | 128000 | 4096 | In: $5.00, Out: $20.00 |
| gpt-4o-realtime-preview-2025-06-03 | azure | In: text; Out: text | streaming | 128000 | 4096 | In: $5.00, Out: $20.00 |
| gpt-4o-transcribe | azure | In: text, audio; Out: text | streaming | 128000 | 16384 | In: $2.50, Out: $10.00 |
| gpt-4o-transcribe-2025-03-20 | azure | In: text, audio; Out: text | streaming | 128000 | 16384 | In: $2.50, Out: $10.00 |
| gpt-4o-transcribe-diarize | azure | In: text, audio; Out: text | streaming | 128000 | 16384 | In: $2.50, Out: $10.00 |
| gpt-4o-transcribe-diarize-2025-10-15 | azure | In: text, audio; Out: text | streaming | 128000 | 16384 | In: $2.50, Out: $10.00 |
| gpt-5-chat-2025-08-07 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5-chat-2025-08-15 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5-chat-2025-10-03 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5-codex-2025-09-15 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5-mini-2025-08-07 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5-mini-lite-2025-08-07 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5-nano-2025-08-07 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5.1-chat-2025-11-13 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5.1-codex-mini-2025-11-13 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5.2-chat-2025-12-11 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5.2-chat-2026-02-10 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5.3-codex-2026-02-20 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-audio-2025-08-28 | azure | In: text, audio; Out: text, audio | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| gpt-audio-mini-2025-10-06 | azure | In: text, audio; Out: text, audio | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| gpt-oss-120b | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| gpt-oss-20b-11 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| gpt-realtime-2025-08-28 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| gpt-realtime-mini | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| gpt-realtime-mini-2025-10-06 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| gpt-realtime-mini-2025-12-15 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| grok-3 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| grok-3-mini | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| grok-4-fast-non-reasoning | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| grok-4-fast-reasoning | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| jais-30b-chat | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| jais-30b-chat-2 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| jais-30b-chat-3 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Kimi-K2-Thinking | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Kimi-K2.5 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Llama-3.2-11B-Vision-Instruct | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Llama-3.2-11B-Vision-Instruct-2 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Llama-3.2-90B-Vision-Instruct | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Llama-3.2-90B-Vision-Instruct-2 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Llama-3.2-90B-Vision-Instruct-3 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Llama-3.3-70B-Instruct | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Llama-3.3-70B-Instruct-2 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Llama-3.3-70B-Instruct-3 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Llama-3.3-70B-Instruct-4 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Llama-3.3-70B-Instruct-5 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Llama-3.3-70B-Instruct-9 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Llama-4-Maverick-17B-128E-Instruct-FP8 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Llama-4-Scout-17B-16E-Instruct | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| MAI-DS-R1 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Meta-Llama-3-70B-Instruct-6 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Meta-Llama-3-70B-Instruct-7 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Meta-Llama-3-70B-Instruct-8 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Meta-Llama-3-70B-Instruct-9 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Meta-Llama-3-8B-Instruct-6 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Meta-Llama-3-8B-Instruct-7 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Meta-Llama-3-8B-Instruct-8 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Meta-Llama-3-8B-Instruct-9 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Meta-Llama-3.1-405B-Instruct | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Meta-Llama-3.1-70B-Instruct | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Meta-Llama-3.1-70B-Instruct-2 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Meta-Llama-3.1-70B-Instruct-3 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Meta-Llama-3.1-70B-Instruct-4 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Meta-Llama-3.1-8B-Instruct | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Meta-Llama-3.1-8B-Instruct-2 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Meta-Llama-3.1-8B-Instruct-3 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Meta-Llama-3.1-8B-Instruct-4 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Meta-Llama-3.1-8B-Instruct-5 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Ministral-3B | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| mistral-document-ai-2505 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| mistral-document-ai-2512 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Mistral-large | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Mistral-large-2407 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Mistral-Large-2411-2 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Mistral-Large-3 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| mistral-medium-2505 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Mistral-Nemo | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Mistral-small | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| mistral-small-2503 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| model-router | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| model-router-2025-05-19 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| model-router-2025-08-07 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| model-router-2025-11-18 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| o1-2024-12-17 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 200000 | 100000 | In: $15.00, Out: $60.00 |
| o1-mini-2024-09-12 | azure | In: text; Out: text | streaming, reasoning | 128000 | 65536 | In: $1.10, Out: $4.40 |
| o1-pro | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 200000 | 100000 | In: $150.00, Out: $600.00 |
| o1-pro-2025-03-19 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 200000 | 100000 | In: $150.00, Out: $600.00 |
| o3-deep-research-2025-06-26 | azure | In: text; Out: text | streaming, reasoning | 4096 | 16384 | In: $0.50, Out: $1.50 |
| o3-deep-research-2025-06-26-ev3 | azure | In: text; Out: text | streaming, reasoning | 4096 | 16384 | In: $0.50, Out: $1.50 |
| o3-mini | azure | In: text; Out: text | streaming, function_calling, structured_output, reasoning | 200000 | 100000 | In: $1.10, Out: $4.40 |
| o3-mini-2025-01-31 | azure | In: text; Out: text | streaming, function_calling, structured_output, reasoning | 200000 | 100000 | In: $1.10, Out: $4.40 |
| o3-mini-alpha | azure | In: text; Out: text | streaming, function_calling, structured_output, reasoning | 200000 | 100000 | In: $1.10, Out: $4.40 |
| o3-mini-alpha-2024-12-17 | azure | In: text; Out: text | streaming, function_calling, structured_output, reasoning | 200000 | 100000 | In: $1.10, Out: $4.40 |
| o4-mini | azure | In: text; Out: text | streaming, reasoning | 4096 | 16384 | In: $0.50, Out: $1.50 |
| o4-mini-2025-04-16 | azure | In: text; Out: text | streaming, reasoning | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Phi-3-medium-128k-instruct-3 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Phi-3-medium-128k-instruct-4 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Phi-3-medium-128k-instruct-5 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Phi-3-medium-128k-instruct-6 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Phi-3-medium-128k-instruct-7 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Phi-3-medium-4k-instruct-3 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Phi-3-medium-4k-instruct-4 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Phi-3-medium-4k-instruct-5 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Phi-3-medium-4k-instruct-6 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Phi-3-mini-128k-instruct-10 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Phi-3-mini-128k-instruct-11 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Phi-3-mini-128k-instruct-12 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Phi-3-mini-128k-instruct-13 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Phi-3-mini-4k-instruct-10 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Phi-3-mini-4k-instruct-11 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Phi-3-mini-4k-instruct-13 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Phi-3-mini-4k-instruct-14 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Phi-3-mini-4k-instruct-15 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Phi-3-small-128k-instruct-3 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Phi-3-small-128k-instruct-4 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Phi-3-small-128k-instruct-5 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Phi-3-small-8k-instruct-3 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Phi-3-small-8k-instruct-4 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Phi-3-small-8k-instruct-5 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Phi-3.5-mini-instruct | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Phi-3.5-mini-instruct-2 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Phi-3.5-mini-instruct-3 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Phi-3.5-mini-instruct-4 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Phi-3.5-mini-instruct-6 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Phi-3.5-MoE-instruct-2 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Phi-3.5-MoE-instruct-3 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Phi-3.5-MoE-instruct-4 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Phi-3.5-MoE-instruct-5 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Phi-3.5-vision-instruct | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Phi-3.5-vision-instruct-2 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Phi-4-2 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Phi-4-3 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Phi-4-4 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Phi-4-5 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Phi-4-6 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Phi-4-7 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Phi-4-mini-instruct | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Phi-4-mini-reasoning | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Phi-4-multimodal-instruct | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Phi-4-reasoning | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| qwen-3-32b | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| qwen3-32b | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| sora | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| sora-2025-05-02 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Stable-Diffusion-3.5-Large | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Stable-Image-Core | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Stable-Image-Ultra | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| text-ada-001 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| text-babbage-001 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| text-curie-001 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| text-davinci-001 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| text-davinci-002 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| text-davinci-003 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| text-davinci-fine-tune-002 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| text-search-ada-doc-001 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| text-search-ada-query-001 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| text-search-babbage-doc-001 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| text-search-babbage-query-001 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| text-search-curie-doc-001 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| text-search-curie-query-001 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| text-search-davinci-doc-001 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| text-search-davinci-query-001 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| text-similarity-ada-001 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| text-similarity-babbage-001 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| text-similarity-curie-001 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| text-similarity-davinci-001 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| whisper | azure | In: text, audio; Out: text | streaming | - | - | In: $0.01, Out: $0.01 |
| whisper-001 | azure | In: text, audio; Out: text | streaming | - | - | In: $0.01, Out: $0.01 |
| text-embedding-3-large | azure | In: text; Out: text, embeddings | batch | - | - | In: $0.13, Out: $0.13 |
| text-embedding-3-small | azure | In: text; Out: text, embeddings | batch | - | - | In: $0.02, Out: $0.02 |
| text-embedding-ada-002 | azure | In: text; Out: text, embeddings | batch | - | - | In: $0.10, Out: $0.10 |
| text-embedding-ada-002-2 | azure | In: text; Out: text, embeddings | batch | - | - | In: $0.10, Out: $0.10 |


### Bedrock (175)

| Model | Provider | I/O | Capabilities | Context | Max Output | Standard Pricing (per 1M tokens) |
| :-- | :-- | :-- | :-- | --: | --: | :-- |
| anthropic.claude-v2 | bedrock | In: text; Out: text | - | 100000 | 4096 | In: $8.00, Out: $24.00 |
| anthropic.claude-v2:1 | bedrock | In: text; Out: text | - | 200000 | 4096 | In: $8.00, Out: $24.00 |
| anthropic.claude-3-haiku-20240307-v1:0:48k | bedrock | In: text, image, pdf; Out: text | function_calling, vision, streaming | 48000 | 4096 | In: $0.25, Out: $1.25 |
| anthropic.claude-3-haiku-20240307-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, vision, streaming | 200000 | 4096 | In: $0.25, Out: $1.25 |
| anthropic.claude-3-haiku-20240307-v1:0:200k | bedrock | In: text, image, pdf; Out: text | function_calling, vision, streaming | 200000 | 4096 | In: $0.25, Out: $1.25 |
| anthropic.claude-3-5-haiku-20241022-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, vision, streaming | 200000 | 8192 | In: $0.80, Out: $4.00, Cache: $0.08 |
| anthropic.claude-haiku-4-5-20251001-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 200000 | 64000 | In: $1.00, Out: $5.00, Cache: $0.10 |
| eu.anthropic.claude-haiku-4-5-20251001-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 200000 | 64000 | In: $1.00, Out: $5.00, Cache: $0.10 |
| global.anthropic.claude-haiku-4-5-20251001-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 200000 | 64000 | In: $1.00, Out: $5.00, Cache: $0.10 |
| us.anthropic.claude-haiku-4-5-20251001-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 64000 | In: $1.00, Out: $5.00, Cache: $0.10 |
| anthropic.claude-instant-v1 | bedrock | In: text; Out: text | - | 100000 | 4096 | In: $0.80, Out: $2.40 |
| anthropic.claude-3-opus-20240229-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, vision | 200000 | 4096 | In: $15.00, Out: $75.00 |
| anthropic.claude-opus-4-20250514-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 200000 | 32000 | In: $15.00, Out: $75.00, Cache: $1.50 |
| us.anthropic.claude-opus-4-20250514-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 32000 | In: $15.00, Out: $75.00, Cache: $1.50 |
| anthropic.claude-opus-4-1-20250805-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 200000 | 32000 | In: $15.00, Out: $75.00, Cache: $1.50 |
| us.anthropic.claude-opus-4-1-20250805-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 32000 | In: $15.00, Out: $75.00, Cache: $1.50 |
| anthropic.claude-opus-4-5-20251101-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 200000 | 64000 | In: $5.00, Out: $25.00, Cache: $0.50 |
| eu.anthropic.claude-opus-4-5-20251101-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 200000 | 64000 | In: $5.00, Out: $25.00, Cache: $0.50 |
| global.anthropic.claude-opus-4-5-20251101-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 200000 | 64000 | In: $5.00, Out: $25.00, Cache: $0.50 |
| us.anthropic.claude-opus-4-5-20251101-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 64000 | In: $5.00, Out: $25.00, Cache: $0.50 |
| anthropic.claude-opus-4-6-v1 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache: $0.50 |
| eu.anthropic.claude-opus-4-6-v1 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache: $0.50 |
| global.anthropic.claude-opus-4-6-v1 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache: $0.50 |
| us.anthropic.claude-opus-4-6-v1 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache: $0.50 |
| anthropic.claude-3-sonnet-20240229-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, vision, streaming | 200000 | 4096 | In: $3.00, Out: $15.00 |
| anthropic.claude-3-sonnet-20240229-v1:0:28k | bedrock | In: text, image, pdf; Out: text | function_calling, vision, streaming | 28000 | 4096 | In: $3.00, Out: $15.00 |
| anthropic.claude-3-sonnet-20240229-v1:0:200k | bedrock | In: text, image, pdf; Out: text | function_calling, vision, streaming | 200000 | 4096 | In: $3.00, Out: $15.00 |
| anthropic.claude-3-5-sonnet-20240620-v1:0:51k | bedrock | In: text, image, pdf; Out: text | function_calling, vision, streaming | 51000 | 8192 | In: $3.00, Out: $15.00, Cache: $0.30 |
| anthropic.claude-3-5-sonnet-20240620-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, vision, streaming | 200000 | 8192 | In: $3.00, Out: $15.00, Cache: $0.30 |
| anthropic.claude-3-5-sonnet-20240620-v1:0:18k | bedrock | In: text, image, pdf; Out: text | function_calling, vision, streaming | 18000 | 8192 | In: $3.00, Out: $15.00, Cache: $0.30 |
| anthropic.claude-3-5-sonnet-20240620-v1:0:200k | bedrock | In: text, image, pdf; Out: text | function_calling, vision, streaming | 200000 | 8192 | In: $3.00, Out: $15.00, Cache: $0.30 |
| anthropic.claude-3-5-sonnet-20241022-v2:0:51k | bedrock | In: text, image, pdf; Out: text | function_calling, vision, streaming | 51000 | 8192 | In: $3.00, Out: $15.00, Cache: $0.30 |
| anthropic.claude-3-5-sonnet-20241022-v2:0 | bedrock | In: text, image, pdf; Out: text | function_calling, vision, streaming | 200000 | 8192 | In: $3.00, Out: $15.00, Cache: $0.30 |
| anthropic.claude-3-5-sonnet-20241022-v2:0:18k | bedrock | In: text, image, pdf; Out: text | function_calling, vision, streaming | 18000 | 8192 | In: $3.00, Out: $15.00, Cache: $0.30 |
| anthropic.claude-3-5-sonnet-20241022-v2:0:200k | bedrock | In: text, image, pdf; Out: text | function_calling, vision, streaming | 200000 | 8192 | In: $3.00, Out: $15.00, Cache: $0.30 |
| anthropic.claude-3-7-sonnet-20250219-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, vision | 200000 | 8192 | In: $3.00, Out: $15.00, Cache: $0.30 |
| us.anthropic.claude-3-7-sonnet-20250219-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, vision, streaming | 200000 | 8192 | In: $3.00, Out: $15.00, Cache: $0.30 |
| anthropic.claude-sonnet-4-20250514-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 200000 | 64000 | In: $3.00, Out: $15.00, Cache: $0.30 |
| eu.anthropic.claude-sonnet-4-20250514-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 200000 | 64000 | In: $3.00, Out: $15.00, Cache: $0.30 |
| global.anthropic.claude-sonnet-4-20250514-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 200000 | 64000 | In: $3.00, Out: $15.00, Cache: $0.30 |
| us.anthropic.claude-sonnet-4-20250514-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 64000 | In: $3.00, Out: $15.00, Cache: $0.30 |
| anthropic.claude-sonnet-4-5-20250929-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 200000 | 64000 | In: $3.00, Out: $15.00, Cache: $0.30 |
| eu.anthropic.claude-sonnet-4-5-20250929-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 200000 | 64000 | In: $3.00, Out: $15.00, Cache: $0.30 |
| global.anthropic.claude-sonnet-4-5-20250929-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 200000 | 64000 | In: $3.00, Out: $15.00, Cache: $0.30 |
| us.anthropic.claude-sonnet-4-5-20250929-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 64000 | In: $3.00, Out: $15.00, Cache: $0.30 |
| anthropic.claude-sonnet-4-6 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 200000 | 64000 | In: $3.00, Out: $15.00, Cache: $0.30 |
| eu.anthropic.claude-sonnet-4-6 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 200000 | 64000 | In: $3.00, Out: $15.00, Cache: $0.30 |
| global.anthropic.claude-sonnet-4-6 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 200000 | 64000 | In: $3.00, Out: $15.00, Cache: $0.30 |
| us.anthropic.claude-sonnet-4-6 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 64000 | In: $3.00, Out: $15.00, Cache: $0.30 |
| cohere.command-text-v14 | bedrock | In: text; Out: text | - | 4096 | 4096 | In: $1.50, Out: $2.00 |
| cohere.command-light-text-v14 | bedrock | In: text; Out: text | - | 4096 | 4096 | In: $0.30, Out: $0.60 |
| cohere.command-r-v1:0 | bedrock | In: text; Out: text | function_calling, streaming | 128000 | 4096 | In: $0.50, Out: $1.50 |
| cohere.command-r-plus-v1:0 | bedrock | In: text; Out: text | function_calling, streaming | 128000 | 4096 | In: $3.00, Out: $15.00 |
| deepseek.v3.2 | bedrock | In: text; Out: text | streaming, function_calling | - | 163840 | - |
| us.deepseek.r1-v1:0 | bedrock | In: text; Out: text | function_calling, reasoning, streaming | 128000 | 32768 | In: $1.35, Out: $5.40 |
| deepseek.r1-v1:0 | bedrock | In: text; Out: text | function_calling, reasoning | 128000 | 32768 | In: $1.35, Out: $5.40 |
| deepseek.v3-v1:0 | bedrock | In: text; Out: text | function_calling, reasoning, streaming | 163840 | 81920 | In: $0.58, Out: $1.68 |
| deepseek.v3.2-v1:0 | bedrock | In: text; Out: text | function_calling, reasoning | 163840 | 81920 | In: $0.62, Out: $1.85 |
| mistral.devstral-2-123b | bedrock | In: text; Out: text | streaming, function_calling | - | 262144 | - |
| cohere.embed-english-v3:0:512 | bedrock | In: text; Out: embeddings | function_calling | - | - | - |
| cohere.embed-english-v3 | bedrock | In: text; Out: embeddings | function_calling | - | - | - |
| cohere.embed-multilingual-v3 | bedrock | In: text; Out: embeddings | function_calling | - | - | - |
| cohere.embed-multilingual-v3:0:512 | bedrock | In: text; Out: embeddings | function_calling | - | - | - |
| us.cohere.embed-v4:0 | bedrock | In: text, image; Out: embeddings | function_calling | 128000 | - | - |
| zai.glm-4.7 | bedrock | In: text; Out: text | function_calling, reasoning, streaming | 204800 | 131072 | In: $0.60, Out: $2.20 |
| zai.glm-4.7-flash | bedrock | In: text; Out: text | function_calling, reasoning, streaming | 200000 | 131072 | In: $0.07, Out: $0.40 |
| openai.gpt-oss-safeguard-120b | bedrock | In: text; Out: text | function_calling, streaming, reasoning | 128000 | 4096 | In: $0.15, Out: $0.60 |
| openai.gpt-oss-safeguard-20b | bedrock | In: text; Out: text | function_calling, streaming, reasoning | 128000 | 4096 | In: $0.07, Out: $0.20 |
| google.gemma-3-4b-it | bedrock | In: text, image; Out: text | function_calling, vision, streaming | 128000 | 4096 | In: $0.04, Out: $0.08 |
| google.gemma-3-12b-it | bedrock | In: text, image; Out: text | vision, streaming, function_calling | 131072 | 8192 | In: $0.05, Out: $0.10 |
| google.gemma-3-27b-it | bedrock | In: text, image; Out: text | function_calling, vision, streaming | 202752 | 8192 | In: $0.12, Out: $0.20 |
| ai21.jamba-1-5-large-v1:0 | bedrock | In: text; Out: text | function_calling | 256000 | 4096 | In: $2.00, Out: $8.00 |
| ai21.jamba-1-5-mini-v1:0 | bedrock | In: text; Out: text | function_calling | 256000 | 4096 | In: $0.20, Out: $0.40 |
| moonshot.kimi-k2-thinking | bedrock | In: text; Out: text | function_calling, reasoning, streaming | 256000 | 256000 | In: $0.60, Out: $2.50 |
| moonshotai.kimi-k2.5 | bedrock | In: text, image; Out: text | function_calling, reasoning, vision, streaming | 256000 | 256000 | In: $0.60, Out: $3.00 |
| meta.llama3-70b-instruct-v1:0 | bedrock | In: text; Out: text | streaming, function_calling | 8192 | 2048 | In: $2.65, Out: $3.50 |
| meta.llama3-8b-instruct-v1:0 | bedrock | In: text; Out: text | streaming, function_calling | 8192 | 2048 | In: $0.30, Out: $0.60 |
| meta.llama3-1-405b-instruct-v1:0 | bedrock | In: text; Out: text | streaming, function_calling | - | - | - |
| meta.llama3-1-70b-instruct-v1:0:128k | bedrock | In: text; Out: text | function_calling, streaming | 128000 | 4096 | In: $0.72, Out: $0.72 |
| meta.llama3-1-70b-instruct-v1:0 | bedrock | In: text; Out: text | function_calling, streaming | 128000 | 4096 | In: $0.72, Out: $0.72 |
| meta.llama3-1-8b-instruct-v1:0:128k | bedrock | In: text; Out: text | function_calling, streaming | 128000 | 4096 | In: $0.22, Out: $0.22 |
| meta.llama3-1-8b-instruct-v1:0 | bedrock | In: text; Out: text | function_calling, streaming | 128000 | 4096 | In: $0.22, Out: $0.22 |
| us.meta.llama3-2-11b-instruct-v1:0 | bedrock | In: text, image; Out: text | function_calling, vision, streaming | 128000 | 4096 | In: $0.16, Out: $0.16 |
| meta.llama3-2-11b-instruct-v1:0 | bedrock | In: text, image; Out: text | function_calling, vision | 128000 | 4096 | In: $0.16, Out: $0.16 |
| meta.llama3-2-11b-instruct-v1:0:128k | bedrock | In: text, image; Out: text | function_calling, vision, streaming | 128000 | 4096 | In: $0.16, Out: $0.16 |
| meta.llama3-2-1b-instruct-v1:0 | bedrock | In: text; Out: text | function_calling | 131000 | 4096 | In: $0.10, Out: $0.10 |
| meta.llama3-2-1b-instruct-v1:0:128k | bedrock | In: text; Out: text | function_calling, streaming | 128000 | 4096 | In: $0.10, Out: $0.10 |
| us.meta.llama3-2-1b-instruct-v1:0 | bedrock | In: text; Out: text | function_calling, streaming | 131000 | 4096 | In: $0.10, Out: $0.10 |
| meta.llama3-2-3b-instruct-v1:0 | bedrock | In: text; Out: text | function_calling | 131000 | 4096 | In: $0.15, Out: $0.15 |
| meta.llama3-2-3b-instruct-v1:0:128k | bedrock | In: text; Out: text | function_calling, streaming | 128000 | 4096 | In: $0.15, Out: $0.15 |
| us.meta.llama3-2-3b-instruct-v1:0 | bedrock | In: text; Out: text | function_calling, streaming | 131000 | 4096 | In: $0.15, Out: $0.15 |
| us.meta.llama3-2-90b-instruct-v1:0 | bedrock | In: text, image; Out: text | function_calling, vision, streaming | 128000 | 4096 | In: $0.72, Out: $0.72 |
| meta.llama3-2-90b-instruct-v1:0 | bedrock | In: text, image; Out: text | function_calling, vision | 128000 | 4096 | In: $0.72, Out: $0.72 |
| meta.llama3-2-90b-instruct-v1:0:128k | bedrock | In: text, image; Out: text | function_calling, vision, streaming | 128000 | 4096 | In: $0.72, Out: $0.72 |
| meta.llama3-3-70b-instruct-v1:0:128k | bedrock | In: text; Out: text | function_calling, streaming | 128000 | 4096 | In: $0.72, Out: $0.72 |
| us.meta.llama3-3-70b-instruct-v1:0 | bedrock | In: text; Out: text | function_calling, streaming | 128000 | 4096 | In: $0.72, Out: $0.72 |
| meta.llama3-3-70b-instruct-v1:0 | bedrock | In: text; Out: text | function_calling | 128000 | 4096 | In: $0.72, Out: $0.72 |
| meta.llama4-maverick-17b-instruct-v1:0 | bedrock | In: text, image; Out: text | function_calling, vision | 1000000 | 16384 | In: $0.24, Out: $0.97 |
| us.meta.llama4-maverick-17b-instruct-v1:0 | bedrock | In: text, image; Out: text | function_calling, vision, streaming | 1000000 | 16384 | In: $0.24, Out: $0.97 |
| meta.llama4-scout-17b-instruct-v1:0 | bedrock | In: text, image; Out: text | function_calling, vision | 3500000 | 16384 | In: $0.17, Out: $0.66 |
| us.meta.llama4-scout-17b-instruct-v1:0 | bedrock | In: text, image; Out: text | function_calling, vision, streaming | 3500000 | 16384 | In: $0.17, Out: $0.66 |
| mistral.magistral-small-2509 | bedrock | In: text, image; Out: text | streaming, function_calling, reasoning | - | 131072 | - |
| minimax.minimax-m2 | bedrock | In: text; Out: text | function_calling, reasoning, streaming | 204608 | 128000 | In: $0.30, Out: $1.20 |
| minimax.minimax-m2.1 | bedrock | In: text; Out: text | function_calling, reasoning, streaming | 204800 | 131072 | In: $0.30, Out: $1.20 |
| mistral.ministral-3-14b-instruct | bedrock | In: text; Out: text | function_calling, streaming | 128000 | 4096 | In: $0.20, Out: $0.20 |
| mistral.ministral-3-8b-instruct | bedrock | In: text; Out: text | function_calling, streaming | 128000 | 4096 | In: $0.15, Out: $0.15 |
| mistral.ministral-3-3b-instruct | bedrock | In: text, image; Out: text | streaming, function_calling | - | 262144 | - |
| mistral.mistral-large-2402-v1:0 | bedrock | In: text; Out: text | function_calling, streaming | 128000 | 4096 | In: $0.50, Out: $1.50 |
| mistral.mistral-large-2407-v1:0 | bedrock | In: text; Out: text | streaming, function_calling | - | - | - |
| mistral.mistral-large-3-675b-instruct | bedrock | In: text, image; Out: text | streaming, function_calling | - | 262144 | - |
| mistral.mistral-7b-instruct-v0:2 | bedrock | In: text; Out: text | function_calling, structured_output, streaming | 127000 | 127000 | In: $0.11, Out: $0.11 |
| mistral.mixtral-8x7b-instruct-v0:1 | bedrock | In: text; Out: text | structured_output, streaming, function_calling | 32000 | 32000 | In: $0.70, Out: $0.70 |
| nvidia.nemotron-nano-12b-v2 | bedrock | In: text, image; Out: text | function_calling, vision, streaming | 128000 | 4096 | In: $0.20, Out: $0.60 |
| nvidia.nemotron-nano-9b-v2 | bedrock | In: text; Out: text | function_calling, streaming | 128000 | 4096 | In: $0.06, Out: $0.23 |
| nvidia.nemotron-nano-3-30b | bedrock | In: text; Out: text | streaming, function_calling | - | 262144 | - |
| us.amazon.nova-2-lite-v1:0 | bedrock | In: text, image, video; Out: text | function_calling, vision, streaming | 128000 | 4096 | In: $0.33, Out: $2.75 |
| amazon.nova-2-lite-v1:0 | bedrock | In: text, image, video; Out: text | function_calling, vision | 128000 | 4096 | In: $0.33, Out: $2.75 |
| amazon.nova-2-sonic-v1:0 | bedrock | In: audio; Out: audio, text | streaming, function_calling | - | - | - |
| amazon.nova-lite-v1:0 | bedrock | In: text, image, video; Out: text | function_calling, vision | 300000 | 8192 | In: $0.06, Out: $0.24, Cache: $0.02 |
| us.amazon.nova-lite-v1:0 | bedrock | In: text, image, video; Out: text | function_calling, vision, streaming | 300000 | 8192 | In: $0.06, Out: $0.24, Cache: $0.02 |
| amazon.nova-micro-v1:0 | bedrock | In: text; Out: text | function_calling | 128000 | 8192 | In: $0.04, Out: $0.14, Cache: $0.01 |
| us.amazon.nova-micro-v1:0 | bedrock | In: text; Out: text | function_calling, streaming | 128000 | 8192 | In: $0.04, Out: $0.14, Cache: $0.01 |
| amazon.nova-premier-v1:0:mm | bedrock | In: text, image, video; Out: text | streaming, function_calling | - | - | - |
| us.amazon.nova-premier-v1:0 | bedrock | In: text, image, video; Out: text | function_calling, reasoning, vision, streaming | 1000000 | 16384 | In: $2.50, Out: $12.50 |
| amazon.nova-premier-v1:0:8k | bedrock | In: text, image, video; Out: text | function_calling, reasoning, vision, streaming | 8000 | 16384 | In: $2.50, Out: $12.50 |
| amazon.nova-premier-v1:0:20k | bedrock | In: text, image, video; Out: text | function_calling, reasoning, vision, streaming | 20000 | 16384 | In: $2.50, Out: $12.50 |
| amazon.nova-premier-v1:0:1000k | bedrock | In: text, image, video; Out: text | function_calling, reasoning, vision, streaming | 1000000 | 16384 | In: $2.50, Out: $12.50 |
| amazon.nova-premier-v1:0 | bedrock | In: text, image, video; Out: text | function_calling, reasoning, vision | 1000000 | 16384 | In: $2.50, Out: $12.50 |
| amazon.nova-pro-v1:0 | bedrock | In: text, image, video; Out: text | function_calling, vision | 300000 | 8192 | In: $0.80, Out: $3.20, Cache: $0.20 |
| us.amazon.nova-pro-v1:0 | bedrock | In: text, image, video; Out: text | function_calling, vision, streaming | 300000 | 8192 | In: $0.80, Out: $3.20, Cache: $0.20 |
| writer.palmyra-x4-v1:0 | bedrock | In: text; Out: text | function_calling, reasoning | 122880 | 8192 | In: $2.50, Out: $10.00 |
| us.writer.palmyra-x4-v1:0 | bedrock | In: text; Out: text | function_calling, reasoning, streaming | 122880 | 8192 | In: $2.50, Out: $10.00 |
| writer.palmyra-x5-v1:0 | bedrock | In: text; Out: text | function_calling, reasoning | 1040000 | 8192 | In: $0.60, Out: $6.00 |
| us.writer.palmyra-x5-v1:0 | bedrock | In: text; Out: text | function_calling, reasoning, streaming | 1040000 | 8192 | In: $0.60, Out: $6.00 |
| us.twelvelabs.pegasus-1-2-v1:0 | bedrock | In: text, video; Out: text | streaming, function_calling | - | - | - |
| us.mistral.pixtral-large-2502-v1:0 | bedrock | In: text, image; Out: text | streaming, function_calling | - | - | - |
| qwen.qwen3-next-80b-a3b | bedrock | In: text; Out: text | function_calling, structured_output, streaming | 262000 | 262000 | In: $0.14, Out: $1.40 |
| qwen.qwen3-vl-235b-a22b | bedrock | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 262000 | 262000 | In: $0.30, Out: $1.50 |
| qwen.qwen3-235b-a22b-2507-v1:0 | bedrock | In: text; Out: text | function_calling, streaming | 262144 | 131072 | In: $0.22, Out: $0.88 |
| qwen.qwen3-32b-v1:0 | bedrock | In: text; Out: text | function_calling, reasoning, streaming | 16384 | 16384 | In: $0.15, Out: $0.60 |
| qwen.qwen3-coder-30b-a3b-v1:0 | bedrock | In: text; Out: text | function_calling, streaming | 262144 | 131072 | In: $0.15, Out: $0.60 |
| qwen.qwen3-coder-480b-a35b-v1:0 | bedrock | In: text; Out: text | function_calling, streaming | 131072 | 65536 | In: $0.22, Out: $1.80 |
| luma.ray-v2:0 | bedrock | In: text; Out: video | function_calling | - | - | - |
| amazon.rerank-v1:0 | bedrock | In: text; Out: text | function_calling | - | - | - |
| cohere.rerank-v3-5:0 | bedrock | In: text; Out: text | function_calling | - | - | - |
| stability.sd3-5-large-v1:0 | bedrock | In: text, image; Out: image | function_calling | - | - | - |
| us.stability.stable-conservative-upscale-v1:0 | bedrock | In: text, image; Out: image | function_calling | - | - | - |
| us.stability.stable-image-control-sketch-v1:0 | bedrock | In: text, image; Out: image | function_calling | - | - | - |
| us.stability.stable-image-control-structure-v1:0 | bedrock | In: text, image; Out: image | function_calling | - | - | - |
| stability.stable-image-core-v1:1 | bedrock | In: text; Out: image | function_calling | - | - | - |
| us.stability.stable-creative-upscale-v1:0 | bedrock | In: text, image; Out: image | function_calling | - | - | - |
| us.stability.stable-image-erase-object-v1:0 | bedrock | In: text, image; Out: image | function_calling | - | - | - |
| us.stability.stable-fast-upscale-v1:0 | bedrock | In: text, image; Out: image | function_calling | - | - | - |
| us.stability.stable-image-inpaint-v1:0 | bedrock | In: text, image; Out: image | function_calling | - | - | - |
| us.stability.stable-outpaint-v1:0 | bedrock | In: text, image; Out: image | function_calling | - | - | - |
| us.stability.stable-image-remove-background-v1:0 | bedrock | In: text, image; Out: image | function_calling | - | - | - |
| us.stability.stable-image-search-recolor-v1:0 | bedrock | In: text, image; Out: image | function_calling | - | - | - |
| us.stability.stable-image-search-replace-v1:0 | bedrock | In: text, image; Out: image | function_calling | - | - | - |
| us.stability.stable-image-style-guide-v1:0 | bedrock | In: text, image; Out: image | function_calling | - | - | - |
| us.stability.stable-style-transfer-v1:0 | bedrock | In: text, image; Out: image | function_calling | - | - | - |
| stability.stable-image-ultra-v1:1 | bedrock | In: text; Out: image | function_calling | - | - | - |
| amazon.titan-embed-text-v1:2:8k | bedrock | In: text; Out: embeddings | function_calling | - | - | - |
| amazon.titan-embed-text-v1 | bedrock | In: text; Out: embeddings | function_calling | - | - | - |
| amazon.titan-image-generator-v2:0 | bedrock | In: text, image; Out: image | function_calling | - | - | - |
| amazon.titan-embed-image-v1:0 | bedrock | In: text, image; Out: embeddings | function_calling | - | - | - |
| amazon.titan-embed-image-v1 | bedrock | In: text, image; Out: embeddings | function_calling | - | - | - |
| amazon.titan-embed-text-v2:0 | bedrock | In: text; Out: embeddings | function_calling | - | - | - |
| amazon.titan-embed-g1-text-02 | bedrock | In: text; Out: embeddings | function_calling | - | - | - |
| amazon.titan-text-express-v1:0:8k | bedrock | In: text; Out: text | function_calling | 128000 | 4096 | In: $0.20, Out: $0.60 |
| amazon.titan-text-express-v1 | bedrock | In: text; Out: text | function_calling | 128000 | 4096 | In: $0.20, Out: $0.60 |
| amazon.titan-tg1-large | bedrock | In: text; Out: text | streaming, function_calling | - | - | - |
| mistral.voxtral-mini-3b-2507 | bedrock | In: audio, text; Out: text | function_calling, streaming | 128000 | 4096 | In: $0.04, Out: $0.04 |
| mistral.voxtral-small-24b-2507 | bedrock | In: text, audio; Out: text | function_calling, streaming | 32000 | 8192 | In: $0.15, Out: $0.35 |
| openai.gpt-oss-120b-1:0 | bedrock | In: text; Out: text | function_calling, streaming | 128000 | 4096 | In: $0.15, Out: $0.60 |
| openai.gpt-oss-20b-1:0 | bedrock | In: text; Out: text | function_calling, streaming | 128000 | 4096 | In: $0.07, Out: $0.30 |


### DeepSeek (2)

| Model | Provider | I/O | Capabilities | Context | Max Output | Standard Pricing (per 1M tokens) |
| :-- | :-- | :-- | :-- | --: | --: | :-- |
| deepseek-chat | deepseek | In: text; Out: text | function_calling, streaming | 128000 | 8192 | In: $0.28, Out: $0.42, Cache: $0.03 |
| deepseek-reasoner | deepseek | In: text; Out: text | function_calling, reasoning, streaming | 128000 | 128000 | In: $0.28, Out: $0.42, Cache: $0.03 |


### Gemini (54)

| Model | Provider | I/O | Capabilities | Context | Max Output | Standard Pricing (per 1M tokens) |
| :-- | :-- | :-- | :-- | --: | --: | :-- |
| deep-research-pro-preview-12-2025 | gemini | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, caching | 131072 | 65536 | In: $0.08, Out: $0.30 |
| gemini-1.5-flash | gemini | In: text, image, audio, video; Out: text | function_calling, vision | 1000000 | 8192 | In: $0.08, Out: $0.30, Cache: $0.02 |
| gemini-1.5-flash-8b | gemini | In: text, image, audio, video; Out: text | function_calling, vision | 1000000 | 8192 | In: $0.04, Out: $0.15, Cache: $0.01 |
| gemini-1.5-pro | gemini | In: text, image, audio, video; Out: text | function_calling, vision | 1000000 | 8192 | In: $1.25, Out: $5.00, Cache: $0.31 |
| gemini-2.0-flash | gemini | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, vision, streaming, batch, caching | 1048576 | 8192 | In: $0.10, Out: $0.40, Cache: $0.02 |
| gemini-2.0-flash-001 | gemini | In: text, image, pdf, video; Out: text | streaming, function_calling, structured_output, batch, caching | 1048576 | 8192 | In: $0.10, Out: $0.40 |
| gemini-2.0-flash-lite | gemini | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, vision, streaming, batch | 1048576 | 8192 | In: $0.08, Out: $0.30 |
| gemini-2.0-flash-lite-001 | gemini | In: text, image, pdf, video; Out: text | streaming, batch | 1048576 | 8192 | In: $0.08, Out: $0.30 |
| gemini-2.5-computer-use-preview-10-2025 | gemini | In: text, image, pdf, video; Out: text | streaming, function_calling, structured_output, caching | 131072 | 65536 | In: $0.08, Out: $0.30 |
| gemini-2.5-flash | gemini | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming, batch, caching | 1048576 | 65536 | In: $0.30, Out: $2.50, Cache: $0.08 |
| gemini-2.5-flash-image | gemini | In: text, image; Out: text, image | reasoning, vision, streaming, function_calling, structured_output, batch, caching | 32768 | 32768 | In: $0.30, Out: $30.00, Cache: $0.08 |
| gemini-2.5-flash-image-preview | gemini | In: text, image; Out: text, image | reasoning, vision | 32768 | 32768 | In: $0.30, Out: $30.00, Cache: $0.08 |
| gemini-2.5-flash-lite | gemini | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming, batch | 1048576 | 65536 | In: $0.10, Out: $0.40, Cache: $0.02 |
| gemini-2.5-flash-lite-preview-06-17 | gemini | In: text, image, audio, video, pdf; Out: text | function_calling, reasoning, vision | 1048576 | 65536 | In: $0.10, Out: $0.40, Cache: $0.02 |
| gemini-2.5-flash-lite-preview-09-2025 | gemini | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming, batch | 1048576 | 65536 | In: $0.10, Out: $0.40, Cache: $0.02 |
| gemini-2.5-flash-native-audio-latest | gemini | In: text, image, pdf, video, audio; Out: text | streaming, function_calling, structured_output, batch, caching | 131072 | 8192 | In: $0.08, Out: $0.30 |
| gemini-2.5-flash-native-audio-preview-09-2025 | gemini | In: text, image, pdf, video, audio; Out: text | streaming, function_calling, structured_output, batch, caching | 131072 | 8192 | In: $0.08, Out: $0.30 |
| gemini-2.5-flash-native-audio-preview-12-2025 | gemini | In: text, image, pdf, video, audio; Out: text | streaming, function_calling, structured_output, batch, caching | 131072 | 8192 | In: $0.08, Out: $0.30 |
| gemini-2.5-flash-preview-04-17 | gemini | In: text, image, audio, video, pdf; Out: text | function_calling, reasoning, vision | 1048576 | 65536 | In: $0.15, Out: $0.60, Cache: $0.04 |
| gemini-2.5-flash-preview-05-20 | gemini | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1048576 | 65536 | In: $0.15, Out: $0.60, Cache: $0.04 |
| gemini-2.5-flash-preview-09-2025 | gemini | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1048576 | 65536 | In: $0.30, Out: $2.50, Cache: $0.08 |
| gemini-2.5-flash-preview-tts | gemini | In: text; Out: audio | streaming, function_calling, structured_output, batch, caching | 8000 | 16000 | In: $0.50, Out: $10.00 |
| gemini-2.5-pro | gemini | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming, caching | 1048576 | 65536 | In: $1.25, Out: $10.00, Cache: $0.31 |
| gemini-2.5-pro-preview-05-06 | gemini | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1048576 | 65536 | In: $1.25, Out: $10.00, Cache: $0.31 |
| gemini-2.5-pro-preview-06-05 | gemini | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1048576 | 65536 | In: $1.25, Out: $10.00, Cache: $0.31 |
| gemini-2.5-pro-preview-tts | gemini | In: text; Out: audio | streaming, function_calling, structured_output, caching | 8000 | 16000 | In: $1.00, Out: $20.00 |
| gemini-3-flash-preview | gemini | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming, batch, caching | 1048576 | 65536 | In: $0.50, Out: $3.00, Cache: $0.05 |
| gemini-3-pro-preview | gemini | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming, caching | 1000000 | 64000 | In: $2.00, Out: $12.00, Cache: $0.20 |
| gemini-3.1-pro-preview | gemini | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming, caching | 1048576 | 65536 | In: $2.00, Out: $12.00, Cache: $0.20 |
| gemini-3.1-pro-preview-customtools | gemini | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming, caching | 1048576 | 65536 | In: $2.00, Out: $12.00, Cache: $0.20 |
| gemini-embedding-001 | gemini | In: text; Out: embeddings | streaming, batch | 2048 | 3072 | In: $0.15 |
| gemini-flash-latest | gemini | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming, batch, caching | 1048576 | 65536 | In: $0.30, Out: $2.50, Cache: $0.08 |
| gemini-flash-lite-latest | gemini | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming, batch | 1048576 | 65536 | In: $0.10, Out: $0.40, Cache: $0.02 |
| gemini-live-2.5-flash | gemini | In: text, image, audio, video; Out: text, audio | function_calling, reasoning, vision | 128000 | 8000 | In: $0.50, Out: $2.00 |
| gemini-live-2.5-flash-preview-native-audio | gemini | In: text, audio, video; Out: text, audio | function_calling, reasoning, vision | 131072 | 65536 | In: $0.50, Out: $2.00 |
| gemini-pro-latest | gemini | In: text, image, pdf, video; Out: text | streaming, function_calling, structured_output, caching | 1048576 | 65536 | In: $0.08, Out: $0.30 |
| gemini-robotics-er-1.5-preview | gemini | In: text, image, pdf, video; Out: text | streaming, function_calling, structured_output, caching | 1048576 | 65536 | In: $0.08, Out: $0.30 |
| gemma-3-12b-it | gemini | In: text; Out: text | streaming | 32768 | 8192 | In: $0.08, Out: $0.30 |
| gemma-3-1b-it | gemini | In: text; Out: text | streaming | 32768 | 8192 | In: $0.08, Out: $0.30 |
| gemma-3-27b-it | gemini | In: text; Out: text | streaming | 131072 | 8192 | In: $0.08, Out: $0.30 |
| gemma-3-4b-it | gemini | In: text; Out: text | streaming | 32768 | 8192 | In: $0.08, Out: $0.30 |
| gemma-3n-e2b-it | gemini | In: text; Out: text | streaming | 8192 | 2048 | In: $0.08, Out: $0.30 |
| gemma-3n-e4b-it | gemini | In: text; Out: text | streaming | 8192 | 2048 | In: $0.08, Out: $0.30 |
| imagen-4.0-generate-001 | gemini | In: text, image, pdf; Out: image | streaming | 480 | 8192 | - |
| imagen-4.0-fast-generate-001 | gemini | In: text, image, pdf; Out: image | streaming | 480 | 8192 | - |
| imagen-4.0-ultra-generate-001 | gemini | In: text, image, pdf; Out: image | streaming | 480 | 8192 | - |
| aqa | gemini | In: text; Out: text | streaming | 7168 | 1024 | - |
| gemini-3-pro-image-preview | gemini | In: text, image, pdf, video; Out: text | streaming, function_calling, structured_output, caching | 131072 | 32768 | In: $0.08, Out: $0.30 |
| nano-banana-pro-preview | gemini | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, caching | 131072 | 32768 | In: $0.08, Out: $0.30 |
| veo-2.0-generate-001 | gemini | In: text; Out: text | streaming | 480 | 8192 | In: $0.08, Out: $0.30 |
| veo-3.0-generate-001 | gemini | In: text; Out: text | streaming | 480 | 8192 | In: $0.08, Out: $0.30 |
| veo-3.0-fast-generate-001 | gemini | In: text; Out: text | streaming | 480 | 8192 | In: $0.08, Out: $0.30 |
| veo-3.1-generate-preview | gemini | In: text; Out: text | streaming | 480 | 8192 | In: $0.08, Out: $0.30 |
| veo-3.1-fast-generate-preview | gemini | In: text; Out: text | streaming | 480 | 8192 | In: $0.08, Out: $0.30 |


### Mistral (62)

| Model | Provider | I/O | Capabilities | Context | Max Output | Standard Pricing (per 1M tokens) |
| :-- | :-- | :-- | :-- | --: | --: | :-- |
| codestral-2508 | mistral | In: text; Out: text | streaming, function_calling, structured_output, batch, predicted_outputs | 32768 | 8192 | - |
| codestral-embed | mistral | In: text; Out: embeddings | predicted_outputs | 32768 | 8192 | - |
| codestral-embed-2505 | mistral | In: text; Out: embeddings | predicted_outputs | 32768 | 8192 | - |
| codestral-latest | mistral | In: text; Out: text | function_calling, streaming, structured_output, batch, predicted_outputs | 256000 | 4096 | In: $0.30, Out: $0.90 |
| devstral-2512 | mistral | In: text; Out: text | function_calling, streaming, structured_output, batch, fine_tuning | 262144 | 262144 | In: $0.40, Out: $2.00 |
| devstral-medium-latest | mistral | In: text; Out: text | function_calling, streaming, structured_output, batch, fine_tuning | 262144 | 262144 | In: $0.40, Out: $2.00 |
| devstral-latest | mistral | In: text; Out: text | streaming, function_calling, structured_output, batch, fine_tuning | 32768 | 8192 | - |
| devstral-medium-2507 | mistral | In: text; Out: text | function_calling, streaming, structured_output, batch, fine_tuning | 128000 | 128000 | In: $0.40, Out: $2.00 |
| devstral-small-2507 | mistral | In: text; Out: text | function_calling, streaming, structured_output, batch, fine_tuning | 128000 | 128000 | In: $0.10, Out: $0.30 |
| labs-devstral-small-2512 | mistral | In: text, image; Out: text | function_calling, vision, streaming, structured_output, batch, fine_tuning | 256000 | 256000 | - |
| devstral-small-2505 | mistral | In: text; Out: text | function_calling | 128000 | 128000 | In: $0.10, Out: $0.30 |
| devstral-small-latest | mistral | In: text; Out: text | streaming, function_calling, structured_output, batch, fine_tuning | 32768 | 8192 | - |
| magistral-medium-latest | mistral | In: text; Out: text | function_calling, reasoning, streaming, structured_output, batch | 128000 | 16384 | In: $2.00, Out: $5.00 |
| magistral-medium-2509 | mistral | In: text; Out: text | streaming, function_calling, structured_output, reasoning, batch | 32768 | 8192 | - |
| magistral-small | mistral | In: text; Out: text | function_calling, reasoning | 128000 | 128000 | In: $0.50, Out: $1.50 |
| magistral-small-2509 | mistral | In: text; Out: text | streaming, function_calling, structured_output, reasoning, batch | 32768 | 8192 | - |
| magistral-small-latest | mistral | In: text; Out: text | streaming, function_calling, structured_output, reasoning, batch | 32768 | 8192 | - |
| ministral-14b-2512 | mistral | In: text; Out: text | streaming, function_calling, structured_output, batch, distillation | 32768 | 8192 | - |
| ministral-14b-latest | mistral | In: text; Out: text | streaming, function_calling, structured_output, batch, distillation | 32768 | 8192 | - |
| ministral-3b-latest | mistral | In: text; Out: text | function_calling, streaming, structured_output, batch, distillation | 128000 | 128000 | In: $0.04, Out: $0.04 |
| ministral-3b-2512 | mistral | In: text; Out: text | streaming, function_calling, structured_output, batch, distillation | 32768 | 8192 | - |
| ministral-8b-latest | mistral | In: text; Out: text | function_calling, streaming, structured_output, batch, distillation | 128000 | 128000 | In: $0.10, Out: $0.10 |
| ministral-8b-2512 | mistral | In: text; Out: text | streaming, function_calling, structured_output, batch, distillation | 32768 | 8192 | - |
| open-mistral-7b | mistral | In: text; Out: text | function_calling | 8000 | 8000 | In: $0.25, Out: $0.25 |
| mistral-embed | mistral | In: text; Out: text | - | 8000 | 3072 | In: $0.10 |
| mistral-embed-2312 | mistral | In: text; Out: embeddings | - | 32768 | 8192 | - |
| mistral-large-latest | mistral | In: text, image; Out: text | function_calling, vision, streaming, structured_output, batch, fine_tuning | 262144 | 262144 | In: $0.50, Out: $1.50 |
| mistral-large-pixtral-2411 | mistral | In: text, image; Out: text | streaming, function_calling, structured_output, vision, batch, fine_tuning | 32768 | 8192 | - |
| mistral-large-2411 | mistral | In: text; Out: text | function_calling, streaming, structured_output, batch, fine_tuning | 131072 | 16384 | In: $2.00, Out: $6.00 |
| mistral-large-2512 | mistral | In: text, image; Out: text | function_calling, vision, streaming, structured_output, batch, fine_tuning | 262144 | 262144 | In: $0.50, Out: $1.50 |
| mistral-medium | mistral | In: text; Out: text | streaming, function_calling, structured_output, vision, batch, fine_tuning | 32768 | 8192 | - |
| mistral-medium-latest | mistral | In: text, image; Out: text | function_calling, vision, streaming, structured_output, batch, fine_tuning | 128000 | 16384 | In: $0.40, Out: $2.00 |
| mistral-medium-2505 | mistral | In: text, image; Out: text | function_calling, vision, streaming, structured_output, batch, fine_tuning | 131072 | 131072 | In: $0.40, Out: $2.00 |
| mistral-medium-2508 | mistral | In: text, image; Out: text | function_calling, vision, streaming, structured_output, batch, fine_tuning | 262144 | 262144 | In: $0.40, Out: $2.00 |
| mistral-moderation-latest | mistral | In: text; Out: text | moderation | 32768 | 8192 | - |
| mistral-moderation-2411 | mistral | In: text; Out: text | moderation | 32768 | 8192 | - |
| mistral-nemo | mistral | In: text; Out: text | function_calling | 128000 | 128000 | In: $0.15, Out: $0.15 |
| mistral-ocr-2503 | mistral | In: text; Out: text | vision | 32768 | 8192 | - |
| mistral-ocr-2505 | mistral | In: text; Out: text | vision | 32768 | 8192 | - |
| mistral-ocr-2512 | mistral | In: text; Out: text | vision | 32768 | 8192 | - |
| mistral-ocr-latest | mistral | In: text; Out: text | vision | 32768 | 8192 | - |
| labs-mistral-small-creative | mistral | In: text; Out: text | streaming, function_calling, structured_output, batch, fine_tuning | 32768 | 8192 | - |
| mistral-small-2501 | mistral | In: text; Out: text | streaming, function_calling, structured_output, batch, fine_tuning | 32768 | 8192 | - |
| mistral-small-latest | mistral | In: text, image; Out: text | function_calling, vision, streaming, structured_output, batch, fine_tuning | 128000 | 16384 | In: $0.10, Out: $0.30 |
| mistral-small-2506 | mistral | In: text, image; Out: text | function_calling, vision, streaming, structured_output, batch, fine_tuning | 128000 | 16384 | In: $0.10, Out: $0.30 |
| mistral-tiny-2407 | mistral | In: text; Out: text | streaming, function_calling, structured_output, batch | 32768 | 8192 | - |
| mistral-tiny-latest | mistral | In: text; Out: text | streaming, function_calling, structured_output, batch | 32768 | 8192 | - |
| mistral-vibe-cli-latest | mistral | In: text; Out: text | streaming, function_calling, structured_output, batch | 32768 | 8192 | - |
| mistral-vibe-cli-with-tools | mistral | In: text; Out: text | streaming, function_calling, structured_output, batch | 32768 | 8192 | - |
| open-mixtral-8x22b | mistral | In: text; Out: text | function_calling | 64000 | 64000 | In: $2.00, Out: $6.00 |
| open-mixtral-8x7b | mistral | In: text; Out: text | function_calling | 32000 | 32000 | In: $0.70, Out: $0.70 |
| open-mistral-nemo | mistral | In: text; Out: text | streaming, function_calling, structured_output, batch | 32768 | 8192 | - |
| open-mistral-nemo-2407 | mistral | In: text; Out: text | streaming, function_calling, structured_output, batch | 32768 | 8192 | - |
| pixtral-12b | mistral | In: text, image; Out: text | function_calling, vision | 128000 | 128000 | In: $0.15, Out: $0.15 |
| pixtral-large-latest | mistral | In: text, image; Out: text | function_calling, vision, streaming, structured_output, batch | 128000 | 128000 | In: $2.00, Out: $6.00 |
| pixtral-large-2411 | mistral | In: text, image; Out: text | streaming, function_calling, structured_output, vision, batch | 32768 | 8192 | - |
| voxtral-mini-2507 | mistral | In: text; Out: text | streaming | 32768 | 8192 | - |
| voxtral-mini-2602 | mistral | In: text; Out: text | streaming | 32768 | 8192 | - |
| voxtral-mini-latest | mistral | In: text; Out: text | streaming | 32768 | 8192 | - |
| voxtral-mini-transcribe-2507 | mistral | In: text; Out: text | transcription | 32768 | 8192 | - |
| voxtral-small-2507 | mistral | In: text; Out: text | streaming | 32768 | 8192 | - |
| voxtral-small-latest | mistral | In: text; Out: text | streaming | 32768 | 8192 | - |


### OpenAI (124)

| Model | Provider | I/O | Capabilities | Context | Max Output | Standard Pricing (per 1M tokens) |
| :-- | :-- | :-- | :-- | --: | --: | :-- |
| babbage-002 | openai | In: text; Out: text | streaming | 4096 | 16384 | In: $0.40, Out: $0.40 |
| chatgpt-image-latest | openai | In: text; Out: text, image | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| codex-mini-latest | openai | In: text; Out: text | function_calling, reasoning | 200000 | 100000 | In: $1.50, Out: $6.00, Cache: $0.38 |
| dall-e-2 | openai | In: text; Out: text, image | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| dall-e-3 | openai | In: text; Out: text, image | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| davinci-002 | openai | In: text; Out: text | streaming | 4096 | 16384 | In: $2.00, Out: $2.00 |
| gpt-3.5-turbo-0125 | openai | In: text; Out: text | streaming | 16385 | 4096 | In: $0.50, Out: $1.50 |
| gpt-3.5-turbo-1106 | openai | In: text; Out: text | streaming | 16385 | 4096 | In: $0.50, Out: $1.50 |
| gpt-3.5-turbo-16k | openai | In: text; Out: text | streaming | 16385 | 4096 | In: $0.50, Out: $1.50 |
| gpt-3.5-turbo-instruct | openai | In: text; Out: text | streaming | 16385 | 4096 | In: $0.50, Out: $1.50 |
| gpt-3.5-turbo-instruct-0914 | openai | In: text; Out: text | streaming | 16385 | 4096 | In: $0.50, Out: $1.50 |
| gpt-3.5-turbo | openai | In: text; Out: text | streaming | 16385 | 4096 | In: $0.50, Out: $1.50, Cache: $1.25 |
| gpt-4 | openai | In: text; Out: text | function_calling, streaming | 8192 | 8192 | In: $30.00, Out: $60.00 |
| gpt-4-0125-preview | openai | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| gpt-4-0613 | openai | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| gpt-4-1106-preview | openai | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| gpt-4-turbo | openai | In: text, image; Out: text | function_calling, vision, streaming | 128000 | 4096 | In: $10.00, Out: $30.00 |
| gpt-4-turbo-2024-04-09 | openai | In: text, image, pdf; Out: text | streaming, function_calling | 128000 | 4096 | In: $10.00, Out: $30.00 |
| gpt-4-turbo-preview | openai | In: text, image, pdf; Out: text | streaming, function_calling | 128000 | 4096 | In: $10.00, Out: $30.00 |
| gpt-4.1 | openai | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 1047576 | 32768 | In: $2.00, Out: $8.00, Cache: $0.50 |
| gpt-4.1-2025-04-14 | openai | In: text, image, pdf; Out: text | streaming, function_calling, structured_output | 1047576 | 32768 | In: $2.00, Out: $8.00, Cache: $0.50 |
| gpt-4.1-mini-2025-04-14 | openai | In: text, image, pdf; Out: text | streaming, function_calling, structured_output | 1047576 | 32768 | In: $0.40, Out: $1.60, Cache: $0.10 |
| gpt-4.1-nano-2025-04-14 | openai | In: text, image, pdf; Out: text | streaming, function_calling, structured_output | 1047576 | 32768 | In: $0.10, Out: $0.40 |
| gpt-4.1-mini | openai | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 1047576 | 32768 | In: $0.40, Out: $1.60, Cache: $0.10 |
| gpt-4.1-nano | openai | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 1047576 | 32768 | In: $0.10, Out: $0.40, Cache: $0.03 |
| gpt-4o | openai | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 128000 | 16384 | In: $2.50, Out: $10.00, Cache: $1.25 |
| gpt-4o-2024-05-13 | openai | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 128000 | 4096 | In: $5.00, Out: $15.00 |
| gpt-4o-2024-08-06 | openai | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 128000 | 16384 | In: $2.50, Out: $10.00, Cache: $1.25 |
| gpt-4o-2024-11-20 | openai | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 128000 | 16384 | In: $2.50, Out: $10.00, Cache: $1.25 |
| gpt-4o-search-preview | openai | In: text, image, pdf; Out: text | streaming | 128000 | 16384 | In: $2.50, Out: $10.00 |
| gpt-4o-search-preview-2025-03-11 | openai | In: text, image, pdf; Out: text | streaming | 128000 | 16384 | In: $2.50, Out: $10.00 |
| gpt-4o-mini | openai | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 128000 | 16384 | In: $0.15, Out: $0.60, Cache: $0.08 |
| gpt-4o-audio-preview | openai | In: text, audio; Out: text, audio | streaming, speech_generation, transcription | 128000 | 16384 | In: $2.50, Out: $10.00 |
| gpt-4o-audio-preview-2024-12-17 | openai | In: text, audio; Out: text, audio | streaming, speech_generation, transcription | 128000 | 16384 | In: $2.50, Out: $10.00 |
| gpt-4o-audio-preview-2025-06-03 | openai | In: text, audio; Out: text, audio | streaming, speech_generation, transcription | 128000 | 16384 | In: $2.50, Out: $10.00 |
| gpt-4o-mini-2024-07-18 | openai | In: text, image, pdf; Out: text | streaming, function_calling, structured_output | 128000 | 16384 | In: $0.15, Out: $0.60 |
| gpt-4o-mini-audio-preview | openai | In: text, audio; Out: text, audio | streaming, speech_generation, transcription | 128000 | 16384 | In: $0.15, Out: $0.60 |
| gpt-4o-mini-audio-preview-2024-12-17 | openai | In: text, audio; Out: text, audio | streaming, speech_generation, transcription | 128000 | 16384 | In: $0.15, Out: $0.60 |
| gpt-4o-mini-realtime-preview | openai | In: text; Out: text | streaming | 128000 | 4096 | In: $0.60, Out: $2.40 |
| gpt-4o-mini-realtime-preview-2024-12-17 | openai | In: text; Out: text | streaming | 128000 | 4096 | In: $0.60, Out: $2.40 |
| gpt-4o-mini-search-preview | openai | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| gpt-4o-mini-search-preview-2025-03-11 | openai | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| gpt-4o-mini-transcribe | openai | In: text, audio; Out: text | streaming | 16000 | 2000 | In: $1.25, Out: $5.00 |
| gpt-4o-mini-transcribe-2025-03-20 | openai | In: text, audio; Out: text | streaming | 16000 | 2000 | In: $1.25, Out: $5.00 |
| gpt-4o-mini-transcribe-2025-12-15 | openai | In: text, audio; Out: text | streaming | 16000 | 2000 | In: $1.25, Out: $5.00 |
| gpt-4o-mini-tts | openai | In: text, audio; Out: text, audio | streaming | - | - | In: $0.60, Out: $12.00 |
| gpt-4o-mini-tts-2025-03-20 | openai | In: text, audio; Out: text, audio | streaming | - | - | In: $0.60, Out: $12.00 |
| gpt-4o-mini-tts-2025-12-15 | openai | In: text, audio; Out: text, audio | streaming | - | - | In: $0.60, Out: $12.00 |
| gpt-4o-realtime-preview | openai | In: text; Out: text | streaming | 128000 | 4096 | In: $5.00, Out: $20.00 |
| gpt-4o-realtime-preview-2024-12-17 | openai | In: text; Out: text | streaming | 128000 | 4096 | In: $5.00, Out: $20.00 |
| gpt-4o-realtime-preview-2025-06-03 | openai | In: text; Out: text | streaming | 128000 | 4096 | In: $5.00, Out: $20.00 |
| gpt-4o-transcribe | openai | In: text, audio; Out: text | streaming | 128000 | 16384 | In: $2.50, Out: $10.00 |
| gpt-4o-transcribe-diarize | openai | In: text, audio; Out: text | streaming | 128000 | 16384 | In: $2.50, Out: $10.00 |
| gpt-5 | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5-2025-08-07 | openai | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5-chat-latest | openai | In: text, image; Out: text | structured_output, reasoning, vision, streaming, function_calling | 400000 | 128000 | In: $1.25, Out: $10.00 |
| gpt-5-mini | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $0.25, Out: $2.00, Cache: $0.02 |
| gpt-5-mini-2025-08-07 | openai | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5-nano | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $0.05, Out: $0.40, Cache: $0.01 |
| gpt-5-nano-2025-08-07 | openai | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5-pro | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 272000 | In: $15.00, Out: $120.00 |
| gpt-5-pro-2025-10-06 | openai | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5-search-api | openai | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5-search-api-2025-10-14 | openai | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5-codex | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5.1 | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $1.25, Out: $10.00, Cache: $0.13 |
| gpt-5.1-2025-11-13 | openai | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5.1-chat-latest | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 128000 | 16384 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5.1-codex | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5.1-codex-max | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5.1-codex-mini | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $0.25, Out: $2.00, Cache: $0.02 |
| gpt-5.2 | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $1.75, Out: $14.00, Cache: $0.18 |
| gpt-5.2-2025-12-11 | openai | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5.2-chat-latest | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 128000 | 16384 | In: $1.75, Out: $14.00, Cache: $0.18 |
| gpt-5.2-codex | openai | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $1.75, Out: $14.00, Cache: $0.18 |
| gpt-5.2-pro | openai | In: text, image; Out: text | function_calling, reasoning, vision, streaming, structured_output | 400000 | 128000 | In: $21.00, Out: $168.00 |
| gpt-5.2-pro-2025-12-11 | openai | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5.3-codex | openai | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $1.75, Out: $14.00, Cache: $0.18 |
| gpt-5.3-codex-spark | openai | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 128000 | 32000 | In: $1.75, Out: $14.00, Cache: $0.18 |
| gpt-audio | openai | In: text, audio; Out: text, audio | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| gpt-audio-1.5 | openai | In: text, audio; Out: text, audio | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| gpt-audio-2025-08-28 | openai | In: text, audio; Out: text, audio | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| gpt-audio-mini | openai | In: text, audio; Out: text, audio | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| gpt-audio-mini-2025-10-06 | openai | In: text, audio; Out: text, audio | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| gpt-audio-mini-2025-12-15 | openai | In: text, audio; Out: text, audio | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| gpt-image-1 | openai | In: text; Out: text, image | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| gpt-image-1-mini | openai | In: text; Out: text, image | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| gpt-image-1.5 | openai | In: text; Out: text, image | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| gpt-realtime | openai | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| gpt-realtime-1.5 | openai | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| gpt-realtime-2025-08-28 | openai | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| gpt-realtime-mini | openai | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| gpt-realtime-mini-2025-10-06 | openai | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| gpt-realtime-mini-2025-12-15 | openai | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| o1-2024-12-17 | openai | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 200000 | 100000 | In: $15.00, Out: $60.00 |
| o1-pro-2025-03-19 | openai | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 200000 | 100000 | In: $150.00, Out: $600.00 |
| o3-2025-04-16 | openai | In: text; Out: text | streaming, reasoning | 4096 | 16384 | In: $0.50, Out: $1.50 |
| o3-deep-research-2025-06-26 | openai | In: text; Out: text | streaming, reasoning | 4096 | 16384 | In: $0.50, Out: $1.50 |
| o3-mini-2025-01-31 | openai | In: text; Out: text | streaming, function_calling, structured_output, reasoning | 200000 | 100000 | In: $1.10, Out: $4.40 |
| o3-pro-2025-06-10 | openai | In: text; Out: text | streaming, reasoning | 4096 | 16384 | In: $0.50, Out: $1.50 |
| o4-mini-2025-04-16 | openai | In: text; Out: text | streaming, reasoning | 4096 | 16384 | In: $0.50, Out: $1.50 |
| o4-mini-deep-research-2025-06-26 | openai | In: text; Out: text | streaming, reasoning | 4096 | 16384 | In: $0.50, Out: $1.50 |
| omni-moderation-2024-09-26 | openai | In: text, image, pdf; Out: text, moderation | - | - | - | - |
| omni-moderation-latest | openai | In: text, image, pdf; Out: text, moderation | - | - | - | - |
| sora-2 | openai | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| sora-2-pro | openai | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| tts-1 | openai | In: text, audio; Out: text, audio | streaming | - | - | In: $15.00, Out: $15.00 |
| tts-1-1106 | openai | In: text, audio; Out: text, audio | streaming | - | - | In: $15.00, Out: $15.00 |
| tts-1-hd | openai | In: text, audio; Out: text, audio | streaming | - | - | In: $30.00, Out: $30.00 |
| tts-1-hd-1106 | openai | In: text, audio; Out: text, audio | streaming | - | - | In: $30.00, Out: $30.00 |
| whisper-1 | openai | In: text, audio; Out: text | streaming | - | - | In: $0.01, Out: $0.01 |
| o1 | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 100000 | In: $15.00, Out: $60.00, Cache: $7.50 |
| o1-mini | openai | In: text; Out: text | structured_output, reasoning | 128000 | 65536 | In: $1.10, Out: $4.40, Cache: $0.55 |
| o1-preview | openai | In: text; Out: text | reasoning | 128000 | 32768 | In: $15.00, Out: $60.00, Cache: $7.50 |
| o1-pro | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 100000 | In: $150.00, Out: $600.00 |
| o3 | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 100000 | In: $2.00, Out: $8.00, Cache: $0.50 |
| o3-deep-research | openai | In: text, image; Out: text | function_calling, reasoning, vision, streaming | 200000 | 100000 | In: $10.00, Out: $40.00, Cache: $2.50 |
| o3-mini | openai | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 200000 | 100000 | In: $1.10, Out: $4.40, Cache: $0.55 |
| o3-pro | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 100000 | In: $20.00, Out: $80.00 |
| o4-mini | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 100000 | In: $1.10, Out: $4.40, Cache: $0.28 |
| o4-mini-deep-research | openai | In: text, image; Out: text | function_calling, reasoning, vision, streaming | 200000 | 100000 | In: $2.00, Out: $8.00, Cache: $0.50 |
| text-embedding-3-large | openai | In: text; Out: embeddings | batch | 8191 | 3072 | In: $0.13 |
| text-embedding-3-small | openai | In: text; Out: embeddings | batch | 8191 | 1536 | In: $0.02 |
| text-embedding-ada-002 | openai | In: text; Out: embeddings | batch | 8192 | 1536 | In: $0.10 |


### OpenRouter (391)

| Model | Provider | I/O | Capabilities | Context | Max Output | Standard Pricing (per 1M tokens) |
| :-- | :-- | :-- | :-- | --: | --: | :-- |
| ai21/jamba-large-1.7 | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 256000 | 4096 | In: $2.00, Out: $8.00 |
| aion-labs/aion-1.0 | openrouter | In: text; Out: text | streaming | 131072 | 32768 | In: $4.00, Out: $8.00 |
| aion-labs/aion-1.0-mini | openrouter | In: text; Out: text | streaming | 131072 | 32768 | In: $0.70, Out: $1.40 |
| aion-labs/aion-2.0 | openrouter | In: text; Out: text | streaming | 131072 | 32768 | In: $0.80, Out: $1.60 |
| aion-labs/aion-rp-llama-3.1-8b | openrouter | In: text; Out: text | streaming | 32768 | 32768 | In: $0.80, Out: $1.60 |
| alfredpros/codellama-7b-instruct-solidity | openrouter | In: text; Out: text | streaming | 4096 | 4096 | In: $0.80, Out: $1.20 |
| allenai/molmo-2-8b | openrouter | In: text, image, video; Out: text | streaming, predicted_outputs | 36864 | 36864 | In: $0.20, Out: $0.20 |
| allenai/olmo-2-0325-32b-instruct | openrouter | In: text; Out: text | streaming | 128000 | - | In: $0.05, Out: $0.20 |
| allenai/olmo-3-32b-think | openrouter | In: text; Out: text | streaming, structured_output, predicted_outputs | 65536 | 65536 | In: $0.15, Out: $0.50 |
| allenai/olmo-3-7b-instruct | openrouter | In: text; Out: text | streaming, structured_output, predicted_outputs | 65536 | 65536 | In: $0.10, Out: $0.20 |
| allenai/olmo-3-7b-think | openrouter | In: text; Out: text | streaming, structured_output, predicted_outputs | 65536 | 65536 | In: $0.12, Out: $0.20 |
| allenai/olmo-3.1-32b-instruct | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 65536 | - | In: $0.20, Out: $0.60 |
| allenai/olmo-3.1-32b-think | openrouter | In: text; Out: text | streaming, structured_output, predicted_outputs | 65536 | 65536 | In: $0.15, Out: $0.50 |
| amazon/nova-2-lite-v1 | openrouter | In: text, image, video, file; Out: text | streaming, function_calling | 1000000 | 65535 | In: $0.30, Out: $2.50 |
| amazon/nova-lite-v1 | openrouter | In: text, image; Out: text | streaming, function_calling | 300000 | 5120 | In: $0.06, Out: $0.24 |
| amazon/nova-micro-v1 | openrouter | In: text; Out: text | streaming, function_calling | 128000 | 5120 | In: $0.04, Out: $0.14 |
| amazon/nova-premier-v1 | openrouter | In: text, image; Out: text | streaming, function_calling | 1000000 | 32000 | In: $2.50, Out: $12.50, Cache: $0.62 |
| amazon/nova-pro-v1 | openrouter | In: text, image; Out: text | streaming, function_calling | 300000 | 5120 | In: $0.80, Out: $3.20 |
| anthropic/claude-3-haiku | openrouter | In: text, image; Out: text | streaming, function_calling | 200000 | 4096 | In: $0.25, Out: $1.25, Cache: $0.03 |
| anthropic/claude-3.5-sonnet | openrouter | In: text, image, file; Out: text | streaming, function_calling | 200000 | 8192 | In: $6.00, Out: $30.00, Cache: $0.60 |
| anthropic/claude-3.7-sonnet:thinking | openrouter | In: text, image, file; Out: text | streaming, function_calling | 200000 | 64000 | In: $3.00, Out: $15.00, Cache: $0.30 |
| arcee-ai/coder-large | openrouter | In: text; Out: text | streaming, predicted_outputs | 32768 | - | In: $0.50, Out: $0.80 |
| arcee-ai/maestro-reasoning | openrouter | In: text; Out: text | streaming, predicted_outputs | 131072 | 32000 | In: $0.90, Out: $3.30 |
| arcee-ai/spotlight | openrouter | In: image, text; Out: text | streaming, predicted_outputs | 131072 | 65537 | In: $0.18, Out: $0.18 |
| arcee-ai/trinity-mini | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 131072 | 131072 | In: $0.04, Out: $0.15 |
| arcee-ai/virtuoso-large | openrouter | In: text; Out: text | streaming, function_calling, predicted_outputs | 131072 | 64000 | In: $0.75, Out: $1.20 |
| openrouter/aurora-alpha | openrouter | In: text; Out: text | function_calling, structured_output, reasoning | 128000 | 50000 | - |
| openrouter/auto | openrouter | In: text, image, audio, file, video; Out: text, image | streaming, function_calling, structured_output, predicted_outputs | 2000000 | - | - |
| baidu/ernie-4.5-21b-a3b | openrouter | In: text; Out: text | streaming, function_calling | 120000 | 8000 | In: $0.07, Out: $0.28 |
| baidu/ernie-4.5-21b-a3b-thinking | openrouter | In: text; Out: text | streaming | 131072 | 65536 | In: $0.07, Out: $0.28 |
| baidu/ernie-4.5-300b-a47b | openrouter | In: text; Out: text | streaming, structured_output | 123000 | 12000 | In: $0.28, Out: $1.10 |
| baidu/ernie-4.5-vl-28b-a3b | openrouter | In: text, image; Out: text | streaming, function_calling | 30000 | 8000 | In: $0.14, Out: $0.56 |
| baidu/ernie-4.5-vl-424b-a47b | openrouter | In: image, text; Out: text | streaming | 123000 | 16000 | In: $0.42, Out: $1.25 |
| openrouter/bodybuilder | openrouter | In: text; Out: text | streaming | 128000 | - | - |
| bytedance-seed/seed-1.6 | openrouter | In: image, text, video; Out: text | streaming, function_calling, structured_output | 262144 | 32768 | In: $0.25, Out: $2.00 |
| bytedance-seed/seed-1.6-flash | openrouter | In: image, text, video; Out: text | streaming, function_calling, structured_output | 262144 | 32768 | In: $0.08, Out: $0.30 |
| bytedance/ui-tars-1.5-7b | openrouter | In: image, text; Out: text | streaming, predicted_outputs | 128000 | 2048 | In: $0.10, Out: $0.20 |
| anthropic/claude-3.5-haiku | openrouter | In: text, image, pdf; Out: text | function_calling, vision, streaming | 200000 | 8192 | In: $0.80, Out: $4.00, Cache: $0.08 |
| anthropic/claude-haiku-4.5 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 64000 | In: $1.00, Out: $5.00, Cache: $0.10 |
| anthropic/claude-opus-4 | openrouter | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 32000 | In: $15.00, Out: $75.00, Cache: $1.50 |
| anthropic/claude-opus-4.1 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 32000 | In: $15.00, Out: $75.00, Cache: $1.50 |
| anthropic/claude-opus-4.5 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 32000 | In: $5.00, Out: $25.00, Cache: $0.50 |
| anthropic/claude-opus-4.6 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache: $0.50 |
| anthropic/claude-3.7-sonnet | openrouter | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 128000 | In: $15.00, Out: $75.00, Cache: $1.50 |
| anthropic/claude-sonnet-4 | openrouter | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 64000 | In: $3.00, Out: $15.00, Cache: $0.30 |
| anthropic/claude-sonnet-4.5 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 64000 | In: $3.00, Out: $15.00, Cache: $0.30 |
| anthropic/claude-sonnet-4.6 | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 128000 | In: $3.00, Out: $15.00, Cache: $0.30 |
| mistralai/codestral-2508 | openrouter | In: text; Out: text | function_calling, structured_output, streaming | 256000 | 256000 | In: $0.30, Out: $0.90 |
| cohere/command-a | openrouter | In: text; Out: text | streaming, structured_output | 256000 | 8192 | In: $2.50, Out: $10.00 |
| cohere/command-r-08-2024 | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 128000 | 4000 | In: $0.15, Out: $0.60 |
| cohere/command-r-plus-08-2024 | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 128000 | 4000 | In: $2.50, Out: $10.00 |
| cohere/command-r7b-12-2024 | openrouter | In: text; Out: text | streaming, structured_output | 128000 | 4000 | In: $0.04, Out: $0.15 |
| deepcogito/cogito-v2.1-671b | openrouter | In: text; Out: text | streaming, structured_output, predicted_outputs | 128000 | - | In: $1.25, Out: $1.25 |
| nousresearch/deephermes-3-llama-3-8b-preview | openrouter | In: text; Out: text | function_calling, reasoning | 131072 | 8192 | - |
| deepseek/deepseek-r1-distill-llama-70b | openrouter | In: text; Out: text | structured_output, reasoning, streaming, predicted_outputs | 8192 | 8192 | In: $0.70, Out: $0.80 |
| deepseek/deepseek-r1-distill-qwen-14b | openrouter | In: text; Out: text | reasoning | 64000 | 8192 | - |
| tngtech/deepseek-r1t2-chimera:free | openrouter | In: text; Out: text | structured_output, reasoning | 163840 | 163840 | - |
| deepseek/deepseek-chat-v3-0324 | openrouter | In: text; Out: text | structured_output, streaming, function_calling, predicted_outputs | 16384 | 8192 | In: $0.19, Out: $0.87, Cache: $0.10 |
| deepseek/deepseek-v3-base:free | openrouter | In: text; Out: text | - | 163840 | 163840 | - |
| deepseek/deepseek-v3.1-terminus | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 131072 | 65536 | In: $0.27, Out: $1.00 |
| deepseek/deepseek-v3.1-terminus:exacto | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 131072 | 65536 | In: $0.27, Out: $1.00 |
| deepseek/deepseek-v3.2 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 163840 | 65536 | In: $0.28, Out: $0.40 |
| deepseek/deepseek-v3.2-speciale | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 163840 | 65536 | In: $0.27, Out: $0.41 |
| deepseek/deepseek-chat-v3.1 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 163840 | 163840 | In: $0.20, Out: $0.80 |
| deepseek/deepseek-chat | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 163840 | 163840 | In: $0.32, Out: $0.89 |
| deepseek/deepseek-v3.2-exp | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 163840 | 65536 | In: $0.27, Out: $0.41 |
| deepseek/deepseek-r1 | openrouter | In: text; Out: text | streaming, function_calling | 64000 | 16000 | In: $0.70, Out: $2.50 |
| deepseek/deepseek-r1-0528 | openrouter | In: text; Out: text | streaming, function_calling, structured_output, predicted_outputs | 163840 | 65536 | In: $0.40, Out: $1.75, Cache: $0.20 |
| deepseek/deepseek-r1-distill-qwen-32b | openrouter | In: text; Out: text | streaming, structured_output | 32768 | 32768 | In: $0.29, Out: $0.29 |
| deepseek/deepseek-r1-0528-qwen3-8b:free | openrouter | In: text; Out: text | function_calling, reasoning | 131072 | 131072 | - |
| mistralai/devstral-2512 | openrouter | In: text; Out: text | function_calling, structured_output, streaming | 262144 | 262144 | In: $0.15, Out: $0.60 |
| mistralai/devstral-2512:free | openrouter | In: text; Out: text | function_calling | 262144 | 262144 | - |
| mistralai/devstral-medium-2507 | openrouter | In: text; Out: text | function_calling, structured_output | 131072 | 131072 | In: $0.40, Out: $2.00 |
| mistralai/devstral-small-2505 | openrouter | In: text; Out: text | function_calling | 128000 | 128000 | In: $0.06, Out: $0.12 |
| mistralai/devstral-small-2507 | openrouter | In: text; Out: text | function_calling, structured_output | 131072 | 131072 | In: $0.10, Out: $0.30 |
| mistralai/devstral-small-2505:free | openrouter | In: text; Out: text | function_calling | 32768 | 32768 | - |
| cognitivecomputations/dolphin3.0-mistral-24b | openrouter | In: text; Out: text | function_calling | 32768 | 8192 | - |
| cognitivecomputations/dolphin3.0-r1-mistral-24b | openrouter | In: text; Out: text | function_calling, reasoning | 32768 | 8192 | - |
| eleutherai/llemma_7b | openrouter | In: text; Out: text | streaming | 4096 | 4096 | In: $0.80, Out: $1.20 |
| essentialai/rnj-1-instruct | openrouter | In: text; Out: text | streaming, structured_output, predicted_outputs | 32768 | - | In: $0.15, Out: $0.15 |
| black-forest-labs/flux.2-flex | openrouter | In: image, text; Out: image | vision | 67344 | 67344 | - |
| black-forest-labs/flux.2-klein-4b | openrouter | In: image, text; Out: image | vision | 40960 | 40960 | - |
| black-forest-labs/flux.2-max | openrouter | In: image, text; Out: image | vision | 46864 | 46864 | - |
| black-forest-labs/flux.2-pro | openrouter | In: image, text; Out: image | vision | 46864 | 46864 | - |
| openrouter/free | openrouter | In: text, image; Out: text | streaming, function_calling, structured_output | 200000 | - | - |
| z-ai/glm-4.5 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 128000 | 96000 | In: $0.60, Out: $2.20 |
| z-ai/glm-4.5-air | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 128000 | 96000 | In: $0.20, Out: $1.10 |
| z-ai/glm-4.5-air:free | openrouter | In: text; Out: text | reasoning, streaming, function_calling | 128000 | 96000 | - |
| z-ai/glm-4.5v | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, streaming | 64000 | 16384 | In: $0.60, Out: $1.80 |
| z-ai/glm-4.6 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 200000 | 128000 | In: $0.60, Out: $2.20, Cache: $0.11 |
| z-ai/glm-4.6:exacto | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 200000 | 128000 | In: $0.60, Out: $1.90, Cache: $0.11 |
| thudm/glm-z1-32b:free | openrouter | In: text; Out: text | function_calling, reasoning | 32768 | 32768 | - |
| z-ai/glm-4.7 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 204800 | 131072 | In: $0.60, Out: $2.20, Cache: $0.11 |
| z-ai/glm-4.7-flash | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 200000 | 65535 | In: $0.07, Out: $0.40 |
| z-ai/glm-5 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 202752 | 131000 | In: $1.00, Out: $3.20, Cache: $0.20 |
| openai/gpt-oss-120b | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 131072 | 32768 | In: $0.07, Out: $0.28 |
| openai/gpt-oss-120b:exacto | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 131072 | 32768 | In: $0.05, Out: $0.24 |
| openai/gpt-oss-20b | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 131072 | 32768 | In: $0.05, Out: $0.20 |
| openai/gpt-oss-safeguard-20b | openrouter | In: text; Out: text | function_calling, reasoning, streaming, structured_output | 131072 | 65536 | In: $0.08, Out: $0.30 |
| openai/gpt-4.1 | openrouter | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 1047576 | 32768 | In: $2.00, Out: $8.00, Cache: $0.50 |
| openai/gpt-4.1-mini | openrouter | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 1047576 | 32768 | In: $0.40, Out: $1.60, Cache: $0.10 |
| openai/gpt-4o-mini | openrouter | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 128000 | 16384 | In: $0.15, Out: $0.60, Cache: $0.08 |
| openai/gpt-5 | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $1.25, Out: $10.00 |
| openai/gpt-5-chat | openrouter | In: text, image; Out: text | structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $1.25, Out: $10.00 |
| openai/gpt-5-codex | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| openai/gpt-5-image | openrouter | In: text, image, pdf; Out: text, image | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $5.00, Out: $10.00, Cache: $1.25 |
| openai/gpt-5-mini | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $0.25, Out: $2.00 |
| openai/gpt-5-nano | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $0.05, Out: $0.40 |
| openai/gpt-5-pro | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 272000 | In: $15.00, Out: $120.00 |
| openai/gpt-5.1 | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| openai/gpt-5.1-chat | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 128000 | 16384 | In: $1.25, Out: $10.00, Cache: $0.12 |
| openai/gpt-5.1-codex | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| openai/gpt-5.1-codex-max | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $1.10, Out: $9.00, Cache: $0.11 |
| openai/gpt-5.1-codex-mini | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 100000 | In: $0.25, Out: $2.00, Cache: $0.02 |
| openai/gpt-5.2 | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $1.75, Out: $14.00, Cache: $0.18 |
| openai/gpt-5.2-chat | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 128000 | 16384 | In: $1.75, Out: $14.00, Cache: $0.18 |
| openai/gpt-5.2-pro | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $21.00, Out: $168.00 |
| openai/gpt-5.2-codex | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $1.75, Out: $14.00, Cache: $0.18 |
| google/gemini-2.0-flash-001 | openrouter | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, vision, streaming | 1048576 | 8192 | In: $0.10, Out: $0.40, Cache: $0.02 |
| google/gemini-2.0-flash-exp:free | openrouter | In: text, image; Out: text | function_calling, vision | 1048576 | 1048576 | - |
| google/gemini-2.5-flash | openrouter | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1048576 | 65536 | In: $0.30, Out: $2.50, Cache: $0.04 |
| google/gemini-2.5-flash-lite | openrouter | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1048576 | 65536 | In: $0.10, Out: $0.40, Cache: $0.02 |
| google/gemini-2.5-flash-lite-preview-09-2025 | openrouter | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1048576 | 65536 | In: $0.10, Out: $0.40, Cache: $0.02 |
| google/gemini-2.5-flash-preview-09-2025 | openrouter | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1048576 | 65536 | In: $0.30, Out: $2.50, Cache: $0.03 |
| google/gemini-2.5-pro | openrouter | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1048576 | 65536 | In: $1.25, Out: $10.00, Cache: $0.31 |
| google/gemini-2.5-pro-preview-05-06 | openrouter | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1048576 | 65536 | In: $1.25, Out: $10.00, Cache: $0.31 |
| google/gemini-2.5-pro-preview-06-05 | openrouter | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1048576 | 65536 | In: $1.25, Out: $10.00, Cache: $0.31 |
| google/gemini-3-flash-preview | openrouter | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1048576 | 65536 | In: $0.50, Out: $3.00, Cache: $0.05 |
| google/gemini-3-pro-preview | openrouter | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1050000 | 66000 | In: $2.00, Out: $12.00 |
| google/gemini-3.1-pro-preview | openrouter | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1048576 | 65536 | In: $2.00, Out: $12.00 |
| google/gemma-2-9b-it | openrouter | In: text; Out: text | streaming | 8192 | 8192 | In: $0.03, Out: $0.09 |
| google/gemma-3-12b-it | openrouter | In: text, image; Out: text | structured_output, vision, streaming, predicted_outputs | 131072 | 131072 | In: $0.03, Out: $0.10 |
| google/gemma-3-12b-it:free | openrouter | In: text, image; Out: text | vision, streaming | 32768 | 8192 | - |
| google/gemma-3-27b-it | openrouter | In: text, image; Out: text | function_calling, structured_output, vision, streaming, predicted_outputs | 96000 | 96000 | In: $0.04, Out: $0.15 |
| google/gemma-3-27b-it:free | openrouter | In: text, image; Out: text | function_calling, vision, streaming, structured_output | 131072 | 8192 | - |
| google/gemma-3-4b-it | openrouter | In: text, image; Out: text | vision, streaming, structured_output | 96000 | 96000 | In: $0.02, Out: $0.07 |
| google/gemma-3-4b-it:free | openrouter | In: text, image; Out: text | vision, streaming, structured_output | 32768 | 8192 | - |
| google/gemma-3n-e2b-it:free | openrouter | In: text; Out: text | streaming, structured_output | 8192 | 2000 | - |
| google/gemma-3n-e4b-it | openrouter | In: text; Out: text | streaming, predicted_outputs | 32768 | 32768 | In: $0.02, Out: $0.04 |
| google/gemma-3n-e4b-it:free | openrouter | In: text; Out: text | streaming, structured_output | 8192 | 2000 | - |
| alpindale/goliath-120b | openrouter | In: text; Out: text | streaming, structured_output, predicted_outputs | 6144 | 1024 | In: $3.75, Out: $7.50 |
| google/gemini-2.0-flash-lite-001 | openrouter | In: text, image, file, audio, video; Out: text | streaming, function_calling, structured_output | 1048576 | 8192 | In: $0.08, Out: $0.30 |
| google/gemini-2.5-flash-image | openrouter | In: image, text; Out: image, text | streaming, structured_output | 32768 | 32768 | In: $0.30, Out: $2.50, Cache: $0.03 |
| google/gemini-2.5-pro-preview | openrouter | In: file, image, text, audio; Out: text | streaming, function_calling, structured_output | 1048576 | 65536 | In: $1.25, Out: $10.00, Cache: $0.12 |
| google/gemma-2-27b-it | openrouter | In: text; Out: text | streaming, structured_output | 8192 | 2048 | In: $0.65, Out: $0.65 |
| google/gemini-3-pro-image-preview | openrouter | In: image, text; Out: image, text | streaming, structured_output | 65536 | 32768 | In: $2.00, Out: $12.00, Cache: $0.20 |
| x-ai/grok-3 | openrouter | In: text; Out: text | function_calling, structured_output, streaming | 131072 | 8192 | In: $3.00, Out: $15.00, Cache: $0.75 |
| x-ai/grok-3-beta | openrouter | In: text; Out: text | function_calling, streaming, structured_output | 131072 | 8192 | In: $3.00, Out: $15.00, Cache: $0.75 |
| x-ai/grok-3-mini | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 131072 | 8192 | In: $0.30, Out: $0.50, Cache: $0.08 |
| x-ai/grok-3-mini-beta | openrouter | In: text; Out: text | function_calling, reasoning, streaming, structured_output | 131072 | 8192 | In: $0.30, Out: $0.50, Cache: $0.08 |
| x-ai/grok-4 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 256000 | 64000 | In: $3.00, Out: $15.00, Cache: $0.75 |
| x-ai/grok-4-fast | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 2000000 | 30000 | In: $0.20, Out: $0.50, Cache: $0.05 |
| x-ai/grok-4.1-fast | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 2000000 | 30000 | In: $0.20, Out: $0.50, Cache: $0.05 |
| x-ai/grok-code-fast-1 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 256000 | 10000 | In: $0.20, Out: $1.50, Cache: $0.02 |
| nousresearch/hermes-3-llama-3.1-405b:free | openrouter | In: text; Out: text | reasoning, streaming | 131072 | 131072 | - |
| nousresearch/hermes-4-405b | openrouter | In: text; Out: text | function_calling, reasoning, streaming, structured_output | 131072 | 131072 | In: $1.00, Out: $3.00 |
| nousresearch/hermes-4-70b | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 131072 | 131072 | In: $0.13, Out: $0.40 |
| ibm-granite/granite-4.0-h-micro | openrouter | In: text; Out: text | streaming | 131000 | - | In: $0.02, Out: $0.11 |
| inception/mercury | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 128000 | 16384 | In: $0.25, Out: $1.00 |
| inception/mercury-coder | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 128000 | 16384 | In: $0.25, Out: $1.00 |
| inflection/inflection-3-pi | openrouter | In: text; Out: text | streaming | 8000 | 1024 | In: $2.50, Out: $10.00 |
| inflection/inflection-3-productivity | openrouter | In: text; Out: text | streaming | 8000 | 1024 | In: $2.50, Out: $10.00 |
| prime-intellect/intellect-3 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 131072 | 8192 | In: $0.20, Out: $1.10 |
| kwaipilot/kat-coder-pro:free | openrouter | In: text; Out: text | function_calling, structured_output | 256000 | 65536 | - |
| moonshotai/kimi-dev-72b:free | openrouter | In: text; Out: text | function_calling | 131072 | 131072 | - |
| moonshotai/kimi-k2 | openrouter | In: text; Out: text | function_calling, streaming, structured_output | 131072 | 32768 | In: $0.55, Out: $2.20 |
| moonshotai/kimi-k2:free | openrouter | In: text; Out: text | function_calling | 32800 | 32800 | - |
| moonshotai/kimi-k2-0905 | openrouter | In: text; Out: text | function_calling, structured_output, streaming, predicted_outputs | 262144 | 16384 | In: $0.60, Out: $2.50 |
| moonshotai/kimi-k2-0905:exacto | openrouter | In: text; Out: text | function_calling, structured_output, streaming | 262144 | 16384 | In: $0.60, Out: $2.50 |
| moonshotai/kimi-k2-thinking | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 262144 | 262144 | In: $0.60, Out: $2.50, Cache: $0.15 |
| moonshotai/kimi-k2.5 | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, streaming, predicted_outputs | 262144 | 262144 | In: $0.60, Out: $3.00, Cache: $0.10 |
| kwaipilot/kat-coder-pro | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 256000 | 128000 | In: $0.21, Out: $0.83, Cache: $0.04 |
| liquid/lfm-2.5-1.2b-instruct:free | openrouter | In: text; Out: text | streaming | 131072 | 32768 | - |
| liquid/lfm-2.5-1.2b-thinking:free | openrouter | In: text; Out: text | reasoning, streaming | 131072 | 32768 | - |
| liquid/lfm-2.2-6b | openrouter | In: text; Out: text | streaming | 32768 | - | In: $0.01, Out: $0.02 |
| liquid/lfm2-8b-a1b | openrouter | In: text; Out: text | streaming | 32768 | - | In: $0.01, Out: $0.02 |
| meta-llama/llama-3.1-405b-instruct:free | openrouter | In: text; Out: text | structured_output | 131072 | 131072 | - |
| meta-llama/llama-3.2-11b-vision-instruct | openrouter | In: text, image; Out: text | vision, streaming, structured_output, predicted_outputs | 131072 | 8192 | In: $0.05, Out: $0.05 |
| meta-llama/llama-3.2-3b-instruct:free | openrouter | In: text, image; Out: text | vision, streaming | 131072 | 131072 | - |
| meta-llama/llama-3.3-70b-instruct:free | openrouter | In: text; Out: text | function_calling, structured_output, streaming | 131072 | 131072 | - |
| meta-llama/llama-4-scout:free | openrouter | In: text, image; Out: text | function_calling, structured_output, vision | 64000 | 64000 | - |
| meta-llama/llama-guard-3-8b | openrouter | In: text; Out: text | streaming | 131072 | - | In: $0.02, Out: $0.06 |
| microsoft/mai-ds-r1:free | openrouter | In: text; Out: text | function_calling, reasoning | 163840 | 163840 | - |
| anthracite-org/magnum-v4-72b | openrouter | In: text; Out: text | streaming, structured_output, predicted_outputs | 16384 | 2048 | In: $3.00, Out: $5.00 |
| mancer/weaver | openrouter | In: text; Out: text | streaming, structured_output, predicted_outputs | 8000 | 2000 | In: $0.75, Out: $1.00 |
| meituan/longcat-flash-chat | openrouter | In: text; Out: text | streaming | 131072 | 32768 | In: $0.20, Out: $0.80, Cache: $0.20 |
| meta-llama/llama-3-70b-instruct | openrouter | In: text; Out: text | streaming, structured_output | 8192 | 8000 | In: $0.51, Out: $0.74 |
| meta-llama/llama-3-8b-instruct | openrouter | In: text; Out: text | streaming, function_calling, structured_output, predicted_outputs | 8192 | 16384 | In: $0.03, Out: $0.04 |
| meta-llama/llama-3.1-405b | openrouter | In: text; Out: text | streaming, predicted_outputs | 32768 | 32768 | In: $4.00, Out: $4.00 |
| meta-llama/llama-3.1-405b-instruct | openrouter | In: text; Out: text | streaming, function_calling, structured_output, predicted_outputs | 131000 | - | In: $4.00, Out: $4.00 |
| meta-llama/llama-3.1-70b-instruct | openrouter | In: text; Out: text | streaming, function_calling, structured_output, predicted_outputs | 131072 | - | In: $0.40, Out: $0.40 |
| meta-llama/llama-3.1-8b-instruct | openrouter | In: text; Out: text | streaming, function_calling, structured_output, predicted_outputs | 16384 | 16384 | In: $0.02, Out: $0.05 |
| meta-llama/llama-3.2-1b-instruct | openrouter | In: text; Out: text | streaming | 60000 | - | In: $0.03, Out: $0.20 |
| meta-llama/llama-3.2-3b-instruct | openrouter | In: text; Out: text | streaming, structured_output, predicted_outputs | 131072 | 16384 | In: $0.02, Out: $0.02 |
| meta-llama/llama-3.3-70b-instruct | openrouter | In: text; Out: text | streaming, function_calling, structured_output, predicted_outputs | 131072 | 16384 | In: $0.10, Out: $0.32 |
| meta-llama/llama-4-maverick | openrouter | In: text, image; Out: text | streaming, function_calling, structured_output, predicted_outputs | 1048576 | 16384 | In: $0.15, Out: $0.60 |
| meta-llama/llama-4-scout | openrouter | In: text, image; Out: text | streaming, function_calling, structured_output | 327680 | 16384 | In: $0.08, Out: $0.30 |
| meta-llama/llama-guard-4-12b | openrouter | In: image, text; Out: text | streaming, structured_output, predicted_outputs | 163840 | - | In: $0.18, Out: $0.18 |
| meta-llama/llama-guard-2-8b | openrouter | In: text; Out: text | streaming, predicted_outputs | 8192 | - | In: $0.20, Out: $0.20 |
| xiaomi/mimo-v2-flash | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 262144 | 65536 | In: $0.10, Out: $0.30, Cache: $0.01 |
| microsoft/phi-4 | openrouter | In: text; Out: text | streaming, structured_output | 16384 | 16384 | In: $0.06, Out: $0.14 |
| minimax/minimax-m1 | openrouter | In: text; Out: text | function_calling, reasoning, streaming | 1000000 | 40000 | In: $0.40, Out: $2.20 |
| minimax/minimax-m2 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 196600 | 118000 | In: $0.28, Out: $1.15, Cache: $0.28 |
| minimax/minimax-m2.1 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 204800 | 131072 | In: $0.30, Out: $1.20 |
| minimax/minimax-m2.5 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 204800 | 131072 | In: $0.30, Out: $1.20, Cache: $0.03 |
| minimax/minimax-01 | openrouter | In: text, image; Out: text | function_calling, reasoning, vision, streaming | 1000000 | 1000000 | In: $0.20, Out: $1.10 |
| minimax/minimax-m2-her | openrouter | In: text; Out: text | streaming | 65536 | 2048 | In: $0.30, Out: $1.20, Cache: $0.03 |
| mistralai/mistral-7b-instruct:free | openrouter | In: text; Out: text | function_calling | 32768 | 32768 | - |
| mistralai/mistral-large | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 128000 | - | In: $2.00, Out: $6.00 |
| mistralai/mistral-large-2407 | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 131072 | - | In: $2.00, Out: $6.00 |
| mistralai/mistral-large-2411 | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 131072 | - | In: $2.00, Out: $6.00 |
| mistralai/mistral-medium-3 | openrouter | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 131072 | 131072 | In: $0.40, Out: $2.00 |
| mistralai/mistral-medium-3.1 | openrouter | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 262144 | 262144 | In: $0.40, Out: $2.00 |
| mistralai/mistral-nemo:free | openrouter | In: text; Out: text | function_calling, structured_output | 131072 | 131072 | - |
| mistralai/mistral-small-3.1-24b-instruct | openrouter | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 128000 | 8192 | In: $0.35, Out: $0.56 |
| mistralai/mistral-small-3.2-24b-instruct:free | openrouter | In: text, image; Out: text | function_calling, structured_output, vision | 96000 | 96000 | - |
| mistralai/mistral-small-3.2-24b-instruct | openrouter | In: text, image; Out: text | function_calling, structured_output, vision, streaming, predicted_outputs | 96000 | 8192 | In: $0.06, Out: $0.18, Cache: $0.03 |
| mistralai/devstral-medium | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 131072 | - | In: $0.40, Out: $2.00 |
| mistralai/devstral-small | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 131072 | - | In: $0.10, Out: $0.30 |
| mistralai/ministral-14b-2512 | openrouter | In: text, image; Out: text | streaming, function_calling, structured_output, predicted_outputs | 262144 | - | In: $0.20, Out: $0.20 |
| mistralai/ministral-3b-2512 | openrouter | In: text, image; Out: text | streaming, function_calling, structured_output | 131072 | - | In: $0.10, Out: $0.10 |
| mistralai/ministral-8b-2512 | openrouter | In: text, image; Out: text | streaming, function_calling, structured_output | 262144 | - | In: $0.15, Out: $0.15 |
| mistralai/mistral-7b-instruct | openrouter | In: text; Out: text | streaming, predicted_outputs | 32768 | 4096 | In: $0.20, Out: $0.20 |
| mistralai/mistral-7b-instruct-v0.1 | openrouter | In: text; Out: text | streaming | 2824 | - | In: $0.11, Out: $0.19 |
| mistralai/mistral-7b-instruct-v0.2 | openrouter | In: text; Out: text | streaming, predicted_outputs | 32768 | - | In: $0.20, Out: $0.20 |
| mistralai/mistral-7b-instruct-v0.3 | openrouter | In: text; Out: text | streaming, predicted_outputs | 32768 | 4096 | In: $0.20, Out: $0.20 |
| mistralai/mistral-large-2512 | openrouter | In: text, image; Out: text | streaming, function_calling, structured_output | 262144 | - | In: $0.50, Out: $1.50 |
| mistralai/mistral-nemo | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 131072 | 16384 | In: $0.02, Out: $0.04 |
| mistralai/mistral-small-24b-instruct-2501 | openrouter | In: text; Out: text | streaming, function_calling, structured_output, predicted_outputs | 32768 | 16384 | In: $0.05, Out: $0.08 |
| mistralai/mistral-small-3.1-24b-instruct:free | openrouter | In: text, image; Out: text | streaming, function_calling, structured_output | 128000 | - | - |
| mistralai/mistral-small-creative | openrouter | In: text; Out: text | streaming, function_calling | 32768 | - | In: $0.10, Out: $0.30 |
| mistralai/mixtral-8x22b-instruct | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 65536 | - | In: $2.00, Out: $6.00 |
| mistralai/mixtral-8x7b-instruct | openrouter | In: text; Out: text | streaming, function_calling, structured_output, predicted_outputs | 32768 | 16384 | In: $0.54, Out: $0.54 |
| mistralai/pixtral-large-2411 | openrouter | In: text, image; Out: text | streaming, function_calling, structured_output | 131072 | - | In: $2.00, Out: $6.00 |
| mistralai/mistral-saba | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 32768 | - | In: $0.20, Out: $0.60 |
| mistralai/voxtral-small-24b-2507 | openrouter | In: text, audio; Out: text | streaming, function_calling, structured_output | 32000 | - | In: $0.10, Out: $0.30 |
| allenai/molmo-2-8b:free | openrouter | In: text, image, video; Out: text | reasoning, vision | 36864 | 36864 | - |
| morph/morph-v3-fast | openrouter | In: text; Out: text | streaming | 81920 | 38000 | In: $0.80, Out: $1.20 |
| morph/morph-v3-large | openrouter | In: text; Out: text | streaming | 262144 | 131072 | In: $0.90, Out: $1.90 |
| gryphe/mythomax-l2-13b | openrouter | In: text; Out: text | streaming, structured_output, predicted_outputs | 4096 | 4096 | In: $0.06, Out: $0.06 |
| nvidia/llama-3.1-nemotron-70b-instruct | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 131072 | 16384 | In: $1.20, Out: $1.20 |
| nvidia/llama-3.3-nemotron-super-49b-v1.5 | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 131072 | - | In: $0.10, Out: $0.40 |
| nvidia/nemotron-3-nano-30b-a3b | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 262144 | - | In: $0.05, Out: $0.20 |
| nvidia/nemotron-nano-12b-v2-vl | openrouter | In: image, text, video; Out: text | streaming, structured_output | 131072 | - | In: $0.07, Out: $0.20 |
| nvidia/nemotron-3-nano-30b-a3b:free | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 256000 | 256000 | - |
| nvidia/nemotron-nano-12b-v2-vl:free | openrouter | In: text, image; Out: text | function_calling, reasoning, vision, streaming | 128000 | 128000 | - |
| nvidia/nemotron-nano-9b-v2:free | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 128000 | 128000 | - |
| neversleep/llama-3.1-lumimaid-8b | openrouter | In: text; Out: text | streaming, structured_output | 32768 | 4096 | In: $0.09, Out: $0.60 |
| nex-agi/deepseek-v3.1-nex-n1 | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 131072 | 163840 | In: $0.27, Out: $1.00 |
| neversleep/noromaid-20b | openrouter | In: text; Out: text | streaming, structured_output | 4096 | 2048 | In: $1.00, Out: $1.75 |
| nousresearch/hermes-3-llama-3.1-405b | openrouter | In: text; Out: text | streaming, structured_output | 131072 | 16384 | In: $1.00, Out: $1.00 |
| nousresearch/hermes-3-llama-3.1-70b | openrouter | In: text; Out: text | streaming, structured_output | 65536 | 65536 | In: $0.30, Out: $0.30 |
| nousresearch/hermes-2-pro-llama-3-8b | openrouter | In: text; Out: text | streaming, structured_output | 8192 | 8192 | In: $0.14, Out: $0.14 |
| openai/gpt-audio | openrouter | In: text, audio; Out: text, audio | streaming, structured_output | 128000 | 16384 | In: $2.50, Out: $10.00 |
| openai/gpt-audio-mini | openrouter | In: text, audio; Out: text, audio | streaming, structured_output | 128000 | 16384 | In: $0.60, Out: $2.40 |
| openai/gpt-3.5-turbo | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 16385 | 4096 | In: $0.50, Out: $1.50 |
| openai/gpt-3.5-turbo-0613 | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 4095 | 4096 | In: $1.00, Out: $2.00 |
| openai/gpt-3.5-turbo-16k | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 16385 | 4096 | In: $3.00, Out: $4.00 |
| openai/gpt-3.5-turbo-instruct | openrouter | In: text; Out: text | streaming, structured_output | 4095 | 4096 | In: $1.50, Out: $2.00 |
| openai/gpt-4 | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 8191 | 4096 | In: $30.00, Out: $60.00 |
| openai/gpt-4-0314 | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 8191 | 4096 | In: $30.00, Out: $60.00 |
| openai/gpt-4-turbo | openrouter | In: text, image; Out: text | streaming, function_calling, structured_output | 128000 | 4096 | In: $10.00, Out: $30.00 |
| openai/gpt-4-1106-preview | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 128000 | 4096 | In: $10.00, Out: $30.00 |
| openai/gpt-4-turbo-preview | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 128000 | 4096 | In: $10.00, Out: $30.00 |
| openai/gpt-4.1-nano | openrouter | In: image, text, file; Out: text | streaming, function_calling, structured_output | 1047576 | 32768 | In: $0.10, Out: $0.40, Cache: $0.02 |
| openai/gpt-4o | openrouter | In: text, image, file; Out: text | streaming, function_calling, structured_output | 128000 | 16384 | In: $2.50, Out: $10.00, Cache: $1.25 |
| openai/gpt-4o-2024-05-13 | openrouter | In: text, image, file; Out: text | streaming, function_calling, structured_output | 128000 | 4096 | In: $5.00, Out: $15.00 |
| openai/gpt-4o-2024-08-06 | openrouter | In: text, image, file; Out: text | streaming, function_calling, structured_output | 128000 | 16384 | In: $2.50, Out: $10.00, Cache: $1.25 |
| openai/gpt-4o-2024-11-20 | openrouter | In: text, image, file; Out: text | streaming, function_calling, structured_output | 128000 | 16384 | In: $2.50, Out: $10.00, Cache: $1.25 |
| openai/gpt-4o:extended | openrouter | In: text, image, file; Out: text | streaming, function_calling, structured_output | 128000 | 64000 | In: $6.00, Out: $18.00 |
| openai/gpt-4o-audio-preview | openrouter | In: audio, text; Out: text, audio | streaming, function_calling, structured_output | 128000 | 16384 | In: $2.50, Out: $10.00 |
| openai/gpt-4o-search-preview | openrouter | In: text; Out: text | streaming, structured_output | 128000 | 16384 | In: $2.50, Out: $10.00 |
| openai/gpt-4o-mini-2024-07-18 | openrouter | In: text, image, file; Out: text | streaming, function_calling, structured_output | 128000 | 16384 | In: $0.15, Out: $0.60, Cache: $0.08 |
| openai/gpt-4o-mini-search-preview | openrouter | In: text; Out: text | streaming, structured_output | 128000 | 16384 | In: $0.15, Out: $0.60 |
| openai/gpt-5-image-mini | openrouter | In: file, image, text; Out: image, text | streaming, function_calling, structured_output | 400000 | 128000 | In: $2.50, Out: $2.00, Cache: $0.25 |
| openai/gpt-5.3-codex | openrouter | In: text, image; Out: text | streaming, function_calling, structured_output | 400000 | 128000 | In: $1.75, Out: $14.00, Cache: $0.18 |
| openai/o1 | openrouter | In: text, image, file; Out: text | streaming, function_calling, structured_output | 200000 | 100000 | In: $15.00, Out: $60.00, Cache: $7.50 |
| openai/o1-pro | openrouter | In: text, image, file; Out: text | streaming, structured_output | 200000 | 100000 | In: $150.00, Out: $600.00 |
| openai/o3 | openrouter | In: image, text, file; Out: text | streaming, function_calling, structured_output | 200000 | 100000 | In: $2.00, Out: $8.00, Cache: $0.50 |
| openai/o3-deep-research | openrouter | In: image, text, file; Out: text | streaming, function_calling, structured_output | 200000 | 100000 | In: $10.00, Out: $40.00, Cache: $2.50 |
| openai/o3-mini | openrouter | In: text, file; Out: text | streaming, function_calling, structured_output | 200000 | 100000 | In: $1.10, Out: $4.40, Cache: $0.55 |
| openai/o3-mini-high | openrouter | In: text, file; Out: text | streaming, function_calling, structured_output | 200000 | 100000 | In: $1.10, Out: $4.40, Cache: $0.55 |
| openai/o3-pro | openrouter | In: text, file, image; Out: text | streaming, function_calling, structured_output | 200000 | 100000 | In: $20.00, Out: $80.00 |
| openai/o4-mini-deep-research | openrouter | In: file, image, text; Out: text | streaming, function_calling, structured_output | 200000 | 100000 | In: $2.00, Out: $8.00, Cache: $0.50 |
| openai/o4-mini-high | openrouter | In: image, text, file; Out: text | streaming, function_calling, structured_output | 200000 | 100000 | In: $1.10, Out: $4.40, Cache: $0.28 |
| opengvlab/internvl3-78b | openrouter | In: image, text; Out: text | streaming, structured_output | 32768 | 32768 | In: $0.15, Out: $0.60, Cache: $0.08 |
| perplexity/sonar | openrouter | In: text, image; Out: text | streaming | 127072 | - | In: $1.00, Out: $1.00 |
| perplexity/sonar-deep-research | openrouter | In: text; Out: text | streaming | 128000 | - | In: $2.00, Out: $8.00 |
| perplexity/sonar-pro | openrouter | In: text, image; Out: text | streaming | 200000 | 8000 | In: $3.00, Out: $15.00 |
| perplexity/sonar-pro-search | openrouter | In: text, image; Out: text | streaming | 200000 | 8000 | In: $3.00, Out: $15.00 |
| perplexity/sonar-reasoning-pro | openrouter | In: text, image; Out: text | streaming | 128000 | - | In: $2.00, Out: $8.00 |
| qwen/qwq-32b:free | openrouter | In: text; Out: text | function_calling, structured_output, reasoning | 32768 | 32768 | - |
| qwen/qwen-2.5-72b-instruct | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 32768 | 16384 | In: $0.12, Out: $0.39 |
| qwen/qwen-2.5-coder-32b-instruct | openrouter | In: text; Out: text | structured_output, streaming, predicted_outputs | 32768 | 8192 | In: $0.20, Out: $0.20 |
| qwen/qwen2.5-vl-32b-instruct:free | openrouter | In: text, image, video; Out: text | function_calling, structured_output, vision | 8192 | 8192 | - |
| qwen/qwen2.5-vl-72b-instruct | openrouter | In: text, image; Out: text | structured_output, vision, streaming, predicted_outputs | 32768 | 8192 | In: $0.80, Out: $0.80 |
| qwen/qwen2.5-vl-72b-instruct:free | openrouter | In: text, image; Out: text | function_calling, vision | 32768 | 32768 | - |
| qwen/qwen-2.5-vl-7b-instruct:free | openrouter | In: text, image; Out: text | function_calling, vision | 32768 | 32768 | - |
| qwen/qwen3-14b:free | openrouter | In: text; Out: text | function_calling, structured_output, reasoning | 40960 | 40960 | - |
| qwen/qwen3-235b-a22b:free | openrouter | In: text; Out: text | function_calling, structured_output, reasoning | 131072 | 131072 | - |
| qwen/qwen3-235b-a22b-07-25 | openrouter | In: text; Out: text | function_calling, structured_output | 262144 | 131072 | In: $0.15, Out: $0.85 |
| qwen/qwen3-235b-a22b-07-25:free | openrouter | In: text; Out: text | function_calling | 262144 | 131072 | - |
| qwen/qwen3-235b-a22b-thinking-2507 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 262144 | 81920 | In: $0.08, Out: $0.31 |
| qwen/qwen3-30b-a3b:free | openrouter | In: text; Out: text | function_calling, structured_output, reasoning | 40960 | 40960 | - |
| qwen/qwen3-30b-a3b-instruct-2507 | openrouter | In: text; Out: text | function_calling, structured_output, streaming | 262000 | 262000 | In: $0.20, Out: $0.80 |
| qwen/qwen3-30b-a3b-thinking-2507 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 262000 | 262000 | In: $0.20, Out: $0.80 |
| qwen/qwen3-32b:free | openrouter | In: text; Out: text | function_calling, structured_output, reasoning | 40960 | 40960 | - |
| qwen/qwen3-4b:free | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 40960 | 40960 | - |
| qwen/qwen3-8b:free | openrouter | In: text; Out: text | function_calling, structured_output, reasoning | 40960 | 40960 | - |
| qwen/qwen3-coder | openrouter | In: text; Out: text | function_calling, structured_output, streaming, predicted_outputs | 262144 | 66536 | In: $0.30, Out: $1.20 |
| qwen/qwen3-coder:exacto | openrouter | In: text; Out: text | function_calling, structured_output, streaming | 131072 | 32768 | In: $0.38, Out: $1.53 |
| qwen/qwen3-coder-30b-a3b-instruct | openrouter | In: text; Out: text | function_calling, structured_output, streaming | 160000 | 65536 | In: $0.07, Out: $0.27 |
| qwen/qwen3-coder:free | openrouter | In: text; Out: text | function_calling, streaming | 262144 | 66536 | - |
| qwen/qwen3-coder-flash | openrouter | In: text; Out: text | function_calling, streaming, structured_output | 128000 | 66536 | In: $0.30, Out: $1.50 |
| qwen/qwen3-max | openrouter | In: text; Out: text | function_calling, reasoning, streaming, structured_output | 262144 | 32768 | In: $1.20, Out: $6.00 |
| qwen/qwen3-next-80b-a3b-instruct | openrouter | In: text; Out: text | function_calling, structured_output, streaming, predicted_outputs | 262144 | 262144 | In: $0.14, Out: $1.40 |
| qwen/qwen3-next-80b-a3b-instruct:free | openrouter | In: text; Out: text | function_calling, structured_output, streaming | 262144 | 262144 | - |
| qwen/qwen3-next-80b-a3b-thinking | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 262144 | 262144 | In: $0.14, Out: $1.40 |
| qwen/qwen3.5-397b-a17b | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, streaming, predicted_outputs | 262144 | 65536 | In: $0.60, Out: $3.60 |
| qwen/qwen3.5-plus-02-15 | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 65536 | In: $0.40, Out: $2.40 |
| qwen/qwq-32b | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 32768 | 32768 | In: $0.15, Out: $0.40 |
| qwen/qwen-plus-2025-07-28 | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 1000000 | 32768 | In: $0.40, Out: $1.20 |
| qwen/qwen-plus-2025-07-28:thinking | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 1000000 | 32768 | In: $0.40, Out: $1.20 |
| qwen/qwen-vl-max | openrouter | In: text, image; Out: text | streaming, function_calling, structured_output | 131072 | 32768 | In: $0.80, Out: $3.20 |
| qwen/qwen-vl-plus | openrouter | In: text, image; Out: text | streaming, structured_output | 131072 | 8192 | In: $0.21, Out: $0.63, Cache: $0.04 |
| qwen/qwen-max | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 32768 | 8192 | In: $1.60, Out: $6.40, Cache: $0.32 |
| qwen/qwen-plus | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 1000000 | 32768 | In: $0.40, Out: $1.20, Cache: $0.08 |
| qwen/qwen-turbo | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 131072 | 8192 | In: $0.05, Out: $0.20, Cache: $0.01 |
| qwen/qwen-2.5-7b-instruct | openrouter | In: text; Out: text | streaming, function_calling, predicted_outputs | 32768 | - | In: $0.04, Out: $0.10 |
| qwen/qwen2.5-coder-7b-instruct | openrouter | In: text; Out: text | streaming, structured_output | 32768 | - | In: $0.03, Out: $0.09 |
| qwen/qwen2.5-vl-32b-instruct | openrouter | In: text, image; Out: text | streaming, structured_output | 128000 | - | In: $0.20, Out: $0.60 |
| qwen/qwen-2.5-vl-7b-instruct | openrouter | In: text, image; Out: text | streaming, predicted_outputs | 32768 | - | In: $0.20, Out: $0.20 |
| qwen/qwen3-14b | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 40960 | 40960 | In: $0.06, Out: $0.24 |
| qwen/qwen3-235b-a22b | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 131072 | 8192 | In: $0.46, Out: $1.82 |
| qwen/qwen3-235b-a22b-2507 | openrouter | In: text; Out: text | streaming, function_calling, structured_output, predicted_outputs | 262144 | - | In: $0.07, Out: $0.10 |
| qwen/qwen3-30b-a3b | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 40960 | 40960 | In: $0.08, Out: $0.28 |
| qwen/qwen3-32b | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 40960 | 40960 | In: $0.08, Out: $0.24, Cache: $0.04 |
| qwen/qwen3-8b | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 32000 | 8192 | In: $0.05, Out: $0.40, Cache: $0.05 |
| qwen/qwen3-coder-next | openrouter | In: text; Out: text | streaming, function_calling, structured_output, predicted_outputs | 262144 | 65536 | In: $0.12, Out: $0.75, Cache: $0.06 |
| qwen/qwen3-coder-plus | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 1000000 | 65536 | In: $1.00, Out: $5.00, Cache: $0.20 |
| qwen/qwen3-max-thinking | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 262144 | 32768 | In: $1.20, Out: $6.00 |
| qwen/qwen3-vl-235b-a22b-instruct | openrouter | In: text, image; Out: text | streaming, function_calling, structured_output, predicted_outputs | 262144 | - | In: $0.20, Out: $0.88, Cache: $0.11 |
| qwen/qwen3-vl-235b-a22b-thinking | openrouter | In: text, image; Out: text | streaming, function_calling, structured_output | 131072 | 32768 | - |
| qwen/qwen3-vl-30b-a3b-instruct | openrouter | In: text, image; Out: text | streaming, function_calling, structured_output | 131072 | 32768 | In: $0.13, Out: $0.52 |
| qwen/qwen3-vl-30b-a3b-thinking | openrouter | In: text, image; Out: text | streaming, function_calling, structured_output | 131072 | 32768 | - |
| qwen/qwen3-vl-32b-instruct | openrouter | In: text, image; Out: text | streaming, function_calling, structured_output, predicted_outputs | 131072 | 32768 | In: $0.10, Out: $0.42 |
| qwen/qwen3-vl-8b-instruct | openrouter | In: image, text; Out: text | streaming, function_calling, structured_output, predicted_outputs | 131072 | 32768 | In: $0.08, Out: $0.50 |
| qwen/qwen3-vl-8b-thinking | openrouter | In: image, text; Out: text | streaming, function_calling, structured_output | 131072 | 32768 | In: $0.12, Out: $1.36 |
| featherless/qwerky-72b | openrouter | In: text; Out: text | - | 32768 | 8192 | - |
| deepseek/deepseek-r1:free | openrouter | In: text; Out: text | function_calling, reasoning | 163840 | 163840 | - |
| deepseek/deepseek-r1-0528:free | openrouter | In: text; Out: text | structured_output, reasoning | 163840 | 163840 | - |
| tngtech/tng-r1t-chimera:free | openrouter | In: text; Out: text | function_calling, structured_output, reasoning | 163840 | 163840 | - |
| undi95/remm-slerp-l2-13b | openrouter | In: text; Out: text | streaming, structured_output, predicted_outputs | 6144 | 4096 | In: $0.45, Out: $0.65 |
| rekaai/reka-flash-3 | openrouter | In: text; Out: text | function_calling, reasoning | 32768 | 8192 | - |
| relace/relace-apply-3 | openrouter | In: text; Out: text | streaming | 256000 | 128000 | In: $0.85, Out: $1.25 |
| relace/relace-search | openrouter | In: text; Out: text | streaming, function_calling | 256000 | 128000 | In: $1.00, Out: $3.00 |
| sourceful/riverflow-v2-fast-preview | openrouter | In: text, image; Out: image | vision | 8192 | 8192 | - |
| sourceful/riverflow-v2-max-preview | openrouter | In: text, image; Out: image | vision | 8192 | 8192 | - |
| sourceful/riverflow-v2-standard-preview | openrouter | In: text, image; Out: image | vision | 8192 | 8192 | - |
| sao10k/l3-lunaris-8b | openrouter | In: text; Out: text | streaming, structured_output | 8192 | - | In: $0.04, Out: $0.05 |
| sao10k/l3.1-70b-hanami-x1 | openrouter | In: text; Out: text | streaming, predicted_outputs | 16000 | - | In: $3.00, Out: $3.00 |
| sao10k/l3.1-euryale-70b | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 32768 | 32768 | In: $0.65, Out: $0.75 |
| sao10k/l3.3-euryale-70b | openrouter | In: text; Out: text | streaming, structured_output | 131072 | 16384 | In: $0.65, Out: $0.75 |
| sao10k/l3-euryale-70b | openrouter | In: text; Out: text | streaming, function_calling | 8192 | 8192 | In: $1.48, Out: $1.48 |
| sarvamai/sarvam-m:free | openrouter | In: text; Out: text | function_calling, reasoning | 32768 | 32768 | - |
| bytedance-seed/seedream-4.5 | openrouter | In: image, text; Out: image | vision | 4096 | 4096 | - |
| openrouter/sherlock-dash-alpha | openrouter | In: text, image; Out: text | function_calling, vision | 1840000 | 0 | - |
| openrouter/sherlock-think-alpha | openrouter | In: text, image; Out: text | function_calling, reasoning, vision | 1840000 | 0 | - |
| raifle/sorcererlm-8x22b | openrouter | In: text; Out: text | streaming, predicted_outputs | 16000 | - | In: $4.50, Out: $4.50 |
| stepfun/step-3.5-flash | openrouter | In: text; Out: text | function_calling, reasoning, streaming | 256000 | 256000 | In: $0.10, Out: $0.30, Cache: $0.02 |
| stepfun/step-3.5-flash:free | openrouter | In: text; Out: text | function_calling, reasoning, streaming | 256000 | 256000 | - |
| switchpoint/router | openrouter | In: text; Out: text | streaming | 131072 | - | In: $0.85, Out: $3.40 |
| tngtech/deepseek-r1t2-chimera | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 163840 | 163840 | In: $0.25, Out: $0.85, Cache: $0.12 |
| tencent/hunyuan-a13b-instruct | openrouter | In: text; Out: text | streaming, structured_output | 131072 | 131072 | In: $0.14, Out: $0.57 |
| thedrummer/cydonia-24b-v4.1 | openrouter | In: text; Out: text | streaming, structured_output, predicted_outputs | 131072 | 131072 | In: $0.30, Out: $0.50 |
| thedrummer/rocinante-12b | openrouter | In: text; Out: text | streaming, function_calling, structured_output, predicted_outputs | 32768 | 32768 | In: $0.17, Out: $0.43 |
| thedrummer/skyfall-36b-v2 | openrouter | In: text; Out: text | streaming, predicted_outputs | 32768 | 32768 | In: $0.55, Out: $0.80 |
| thedrummer/unslopnemo-12b | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 32768 | 32768 | In: $0.40, Out: $0.40 |
| alibaba/tongyi-deepresearch-30b-a3b | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 131072 | 131072 | In: $0.09, Out: $0.45, Cache: $0.09 |
| arcee-ai/trinity-large-preview:free | openrouter | In: text; Out: text | function_calling, structured_output, streaming | 131072 | 131072 | - |
| arcee-ai/trinity-mini:free | openrouter | In: text; Out: text | function_calling, structured_output, streaming | 131072 | 131072 | - |
| cognitivecomputations/dolphin-mistral-24b-venice-edition:free | openrouter | In: text; Out: text | structured_output, streaming | 32768 | 32768 | - |
| upstage/solar-pro-3:free | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 128000 | - | - |
| microsoft/wizardlm-2-8x22b | openrouter | In: text; Out: text | streaming | 65535 | 8000 | In: $0.62, Out: $0.62 |
| writer/palmyra-x5 | openrouter | In: text; Out: text | streaming | 1040000 | 8192 | In: $0.60, Out: $6.00 |
| z-ai/glm-4-32b | openrouter | In: text; Out: text | streaming, function_calling | 128000 | - | In: $0.10, Out: $0.10 |
| z-ai/glm-4.6v | openrouter | In: image, text, video; Out: text | streaming, function_calling, structured_output | 131072 | 131072 | In: $0.30, Out: $0.90 |
| openai/gpt-oss-120b:free | openrouter | In: text; Out: text | function_calling, reasoning, streaming | 131072 | 32768 | - |
| openai/gpt-oss-20b:free | openrouter | In: text; Out: text | function_calling, reasoning, streaming | 131072 | 32768 | - |
| nvidia/nemotron-nano-9b-v2 | openrouter | In: text; Out: text | function_calling, reasoning, streaming, structured_output, predicted_outputs | 131072 | 131072 | In: $0.04, Out: $0.16 |
| openai/o4-mini | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 100000 | In: $1.10, Out: $4.40, Cache: $0.28 |


### Perplexity (5)

| Model | Provider | I/O | Capabilities | Context | Max Output | Standard Pricing (per 1M tokens) |
| :-- | :-- | :-- | :-- | --: | --: | :-- |
| sonar-deep-research | perplexity | In: text; Out: text | reasoning, streaming, json_mode, vision | 128000 | 32768 | In: $2.00, Out: $8.00 |
| sonar | perplexity | In: text; Out: text | streaming, json_mode, vision | 128000 | 4096 | In: $1.00, Out: $1.00 |
| sonar-pro | perplexity | In: text, image; Out: text | vision, streaming, json_mode | 200000 | 8192 | In: $3.00, Out: $15.00 |
| sonar-reasoning | perplexity | In: text; Out: text | streaming, json_mode, vision | 128000 | 4096 | In: $1.00, Out: $5.00 |
| sonar-reasoning-pro | perplexity | In: text, image; Out: text | reasoning, vision, streaming, json_mode | 128000 | 4096 | In: $2.00, Out: $8.00 |


### VertexAI (44)

| Model | Provider | I/O | Capabilities | Context | Max Output | Standard Pricing (per 1M tokens) |
| :-- | :-- | :-- | :-- | --: | --: | :-- |
| deepseek-ai/deepseek-v3.1-maas | vertexai | In: text, pdf; Out: text | function_calling, structured_output, reasoning, vision | 163840 | 32768 | In: $0.60, Out: $1.70 |
| zai-org/glm-4.7-maas | vertexai | In: text, pdf; Out: text | function_calling, structured_output, reasoning, vision | 200000 | 128000 | In: $0.60, Out: $2.20 |
| zai-org/glm-5-maas | vertexai | In: text; Out: text | function_calling, reasoning | 204800 | 131072 | In: $1.00, Out: $3.20, Cache: $0.10 |
| openai/gpt-oss-120b-maas | vertexai | In: text; Out: text | function_calling, reasoning | 131072 | 32768 | In: $0.09, Out: $0.36 |
| openai/gpt-oss-20b-maas | vertexai | In: text; Out: text | function_calling, reasoning | 131072 | 32768 | In: $0.07, Out: $0.25 |
| gemini-1.5-flash | vertexai | In: text, image, audio, video; Out: text | function_calling, vision, streaming | 1000000 | 8192 | In: $0.08, Out: $0.30, Cache: $0.02 |
| gemini-1.5-flash-8b | vertexai | In: text, image, audio, video; Out: text | function_calling, vision, streaming | 1000000 | 8192 | In: $0.04, Out: $0.15, Cache: $0.01 |
| gemini-1.5-pro | vertexai | In: text, image, audio, video; Out: text | function_calling, vision, streaming | 1000000 | 8192 | In: $1.25, Out: $5.00, Cache: $0.31 |
| gemini-2.0-flash | vertexai | In: text, image, audio, video, pdf; Out: text | function_calling, vision, streaming | 1048576 | 8192 | In: $0.15, Out: $0.60, Cache: $0.02 |
| gemini-2.0-flash-lite | vertexai | In: text, image, audio, video, pdf; Out: text | function_calling, vision | 1048576 | 8192 | In: $0.08, Out: $0.30 |
| gemini-2.5-flash | vertexai | In: text, image, audio, video, pdf; Out: text | function_calling, reasoning, vision, streaming | 1048576 | 65536 | In: $0.30, Out: $2.50, Cache: $0.08 |
| gemini-2.5-flash-lite | vertexai | In: text, image, audio, video, pdf; Out: text | function_calling, reasoning, vision, streaming | 1048576 | 65536 | In: $0.10, Out: $0.40, Cache: $0.02 |
| gemini-2.5-flash-lite-preview-06-17 | vertexai | In: text, image, audio, video, pdf; Out: text | function_calling, reasoning, vision | 65536 | 65536 | In: $0.10, Out: $0.40, Cache: $0.02 |
| gemini-2.5-flash-lite-preview-09-2025 | vertexai | In: text, image, audio, video, pdf; Out: text | function_calling, reasoning, vision | 1048576 | 65536 | In: $0.10, Out: $0.40, Cache: $0.02 |
| gemini-2.5-flash-preview-04-17 | vertexai | In: text, image, audio, video, pdf; Out: text | function_calling, reasoning, vision, streaming | 1048576 | 65536 | In: $0.15, Out: $0.60, Cache: $0.04 |
| gemini-2.5-flash-preview-05-20 | vertexai | In: text, image, audio, video, pdf; Out: text | function_calling, reasoning, vision | 1048576 | 65536 | In: $0.15, Out: $0.60, Cache: $0.04 |
| gemini-2.5-flash-preview-09-2025 | vertexai | In: text, image, audio, video, pdf; Out: text | function_calling, reasoning, vision | 1048576 | 65536 | In: $0.30, Out: $2.50, Cache: $0.08 |
| gemini-2.5-pro | vertexai | In: text, image, audio, video, pdf; Out: text | function_calling, reasoning, vision, streaming | 1048576 | 65536 | In: $1.25, Out: $10.00, Cache: $0.31 |
| gemini-2.5-pro-preview-05-06 | vertexai | In: text, image, audio, video, pdf; Out: text | function_calling, reasoning, vision | 1048576 | 65536 | In: $1.25, Out: $10.00, Cache: $0.31 |
| gemini-2.5-pro-preview-06-05 | vertexai | In: text, image, audio, video, pdf; Out: text | function_calling, reasoning, vision | 1048576 | 65536 | In: $1.25, Out: $10.00, Cache: $0.31 |
| gemini-3-flash-preview | vertexai | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1048576 | 65536 | In: $0.50, Out: $3.00, Cache: $0.05 |
| gemini-3-pro-preview | vertexai | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1048576 | 65536 | In: $2.00, Out: $12.00, Cache: $0.20 |
| gemini-3.1-pro-preview | vertexai | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1048576 | 65536 | In: $2.00, Out: $12.00, Cache: $0.20 |
| gemini-3.1-pro-preview-customtools | vertexai | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1048576 | 65536 | In: $2.00, Out: $12.00, Cache: $0.20 |
| gemini-embedding-001 | vertexai | In: text; Out: embeddings | streaming, function_calling | 2048 | 3072 | In: $0.15 |
| gemini-flash-latest | vertexai | In: text, image, audio, video, pdf; Out: text | function_calling, reasoning, vision | 1048576 | 65536 | In: $0.30, Out: $2.50, Cache: $0.08 |
| gemini-flash-lite-latest | vertexai | In: text, image, audio, video, pdf; Out: text | function_calling, reasoning, vision | 1048576 | 65536 | In: $0.10, Out: $0.40, Cache: $0.02 |
| meta/llama-3.3-70b-instruct-maas | vertexai | In: text; Out: text | function_calling, structured_output | 128000 | 8192 | In: $0.72, Out: $0.72 |
| meta/llama-4-maverick-17b-128e-instruct-maas | vertexai | In: text, image; Out: text | function_calling, structured_output, vision | 524288 | 8192 | In: $0.35, Out: $1.15 |
| qwen/qwen3-235b-a22b-instruct-2507-maas | vertexai | In: text; Out: text | function_calling, structured_output, reasoning | 262144 | 16384 | In: $0.22, Out: $0.88 |
| gemini-1.5-flash-002 | vertexai | In: -; Out: - | streaming, function_calling | - | - | - |
| gemini-1.5-pro-002 | vertexai | In: -; Out: - | streaming, function_calling | - | - | - |
| gemini-2.0-flash-001 | vertexai | In: -; Out: - | streaming, function_calling | - | - | - |
| gemini-2.0-flash-exp | vertexai | In: -; Out: - | streaming, function_calling | - | - | - |
| gemini-2.0-flash-lite-001 | vertexai | In: -; Out: - | streaming, function_calling | - | - | - |
| gemini-2.0-flash-preview-image-generation | vertexai | In: -; Out: - | streaming, function_calling | - | - | - |
| gemini-2.5-pro-exp-03-25 | vertexai | In: -; Out: - | streaming, function_calling | - | - | - |
| gemini-exp-1121 | vertexai | In: -; Out: - | streaming, function_calling | - | - | - |
| gemini-exp-1206 | vertexai | In: -; Out: - | streaming, function_calling | - | - | - |
| gemini-pro | vertexai | In: -; Out: - | streaming, function_calling | - | - | - |
| gemini-pro-vision | vertexai | In: -; Out: - | streaming, function_calling | - | - | - |
| text-embedding-004 | vertexai | In: -; Out: - | streaming, function_calling | - | - | - |
| text-embedding-005 | vertexai | In: -; Out: - | streaming, function_calling | - | - | - |
| text-multilingual-embedding-002 | vertexai | In: -; Out: - | streaming, function_calling | - | - | - |


### VoyageAI (18)

| Model | Provider | I/O | Capabilities | Context | Max Output | Standard Pricing (per 1M tokens) |
| :-- | :-- | :-- | :-- | --: | --: | :-- |
| rerank-2 | voyage | In: text; Out: rerank | - | 16000 | - | In: $0.05 |
| rerank-2-lite | voyage | In: text; Out: rerank | - | 8000 | - | In: $0.02 |
| rerank-2.5 | voyage | In: text; Out: rerank | - | 32000 | - | In: $0.05 |
| rerank-2.5-lite | voyage | In: text; Out: rerank | - | 32000 | - | In: $0.02 |
| voyage-3-large | voyage | In: text; Out: embeddings | - | 32000 | - | In: $0.18 |
| voyage-3.5 | voyage | In: text; Out: embeddings | - | 32000 | - | In: $0.06 |
| voyage-3.5-lite | voyage | In: text; Out: embeddings | - | 32000 | - | In: $0.02 |
| voyage-4 | voyage | In: text; Out: embeddings | - | 32000 | - | In: $0.06 |
| voyage-4-large | voyage | In: text; Out: embeddings | - | 32000 | - | In: $0.12 |
| voyage-4-lite | voyage | In: text; Out: embeddings | - | 32000 | - | In: $0.02 |
| voyage-4-nano | voyage | In: text; Out: embeddings | - | 32000 | - | - |
| voyage-code-2 | voyage | In: text; Out: embeddings | - | 16000 | - | In: $0.12 |
| voyage-code-3 | voyage | In: text; Out: embeddings | - | 32000 | - | In: $0.18 |
| voyage-context-3 | voyage | In: text; Out: embeddings | - | 32000 | - | In: $0.18 |
| voyage-finance-2 | voyage | In: text; Out: embeddings | - | 32000 | - | In: $0.12 |
| voyage-law-2 | voyage | In: text; Out: embeddings | - | 16000 | - | In: $0.12 |
| voyage-multimodal-3 | voyage | In: text, image; Out: embeddings | - | 32000 | - | In: $0.12 |
| voyage-multimodal-3.5 | voyage | In: text, image, video; Out: embeddings | - | 32000 | - | In: $0.12 |


### XAI (13)

| Model | Provider | I/O | Capabilities | Context | Max Output | Standard Pricing (per 1M tokens) |
| :-- | :-- | :-- | :-- | --: | --: | :-- |
| grok-2-image-1212 | xai | In: text; Out: image | - | - | - | - |
| grok-2-vision-1212 | xai | In: text, image; Out: text | streaming, function_calling, structured_output, vision | - | - | - |
| grok-3 | xai | In: text; Out: text | streaming, function_calling, structured_output | - | - | - |
| grok-3-mini | xai | In: text; Out: text | streaming, function_calling, structured_output, reasoning | - | - | - |
| grok-4-0709 | xai | In: text, image; Out: text | streaming, function_calling, structured_output, reasoning, vision | - | - | - |
| grok-4-1-fast-non-reasoning | xai | In: text, image; Out: text | streaming, function_calling, structured_output, vision | - | - | - |
| grok-4-1-fast-reasoning | xai | In: text, image; Out: text | streaming, function_calling, structured_output, reasoning, vision | - | - | - |
| grok-4-fast-non-reasoning | xai | In: text, image; Out: text | streaming, function_calling, structured_output, vision | - | - | - |
| grok-4-fast-reasoning | xai | In: text, image; Out: text | streaming, function_calling, structured_output, reasoning, vision | - | - | - |
| grok-code-fast-1 | xai | In: text; Out: text | streaming, function_calling, structured_output, reasoning | - | - | - |
| grok-imagine-image | xai | In: text; Out: text | streaming, function_calling, structured_output | - | - | - |
| grok-imagine-image-pro | xai | In: text; Out: text | streaming, function_calling, structured_output | - | - | - |
| grok-imagine-video | xai | In: text; Out: text | streaming, function_calling, structured_output | - | - | - |


## Models by Capability

### Function Calling (694)

| Model | Provider | I/O | Capabilities | Context | Max Output | Standard Pricing (per 1M tokens) |
| :-- | :-- | :-- | :-- | --: | --: | :-- |
| claude-3-haiku-20240307 | anthropic | In: text, image, pdf; Out: text | function_calling, vision, streaming, batch | 200000 | 4096 | In: $0.25, Out: $1.25, Cache: $0.03 |
| claude-3-5-haiku-20241022 | anthropic | In: text, image, pdf; Out: text | function_calling, vision | 200000 | 8192 | In: $0.80, Out: $4.00, Cache: $0.08 |
| claude-3-5-haiku-latest | anthropic | In: text, image, pdf; Out: text | function_calling, vision | 200000 | 8192 | In: $0.80, Out: $4.00, Cache: $0.08 |
| claude-haiku-4-5-20251001 | anthropic | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 64000 | In: $1.00, Out: $5.00, Cache: $0.10 |
| claude-haiku-4-5 | anthropic | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 200000 | 64000 | In: $1.00, Out: $5.00, Cache: $0.10 |
| claude-3-opus-20240229 | anthropic | In: text, image, pdf; Out: text | function_calling, vision | 200000 | 4096 | In: $15.00, Out: $75.00, Cache: $1.50 |
| claude-opus-4-20250514 | anthropic | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 32000 | In: $15.00, Out: $75.00, Cache: $1.50 |
| claude-opus-4-0 | anthropic | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 200000 | 32000 | In: $15.00, Out: $75.00, Cache: $1.50 |
| claude-opus-4-1-20250805 | anthropic | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 32000 | In: $15.00, Out: $75.00, Cache: $1.50 |
| claude-opus-4-1 | anthropic | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 200000 | 32000 | In: $15.00, Out: $75.00, Cache: $1.50 |
| claude-opus-4-5-20251101 | anthropic | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 64000 | In: $5.00, Out: $25.00, Cache: $0.50 |
| claude-opus-4-5 | anthropic | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 200000 | 64000 | In: $5.00, Out: $25.00, Cache: $0.50 |
| claude-opus-4-6 | anthropic | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 128000 | In: $5.00, Out: $25.00, Cache: $0.50 |
| claude-3-sonnet-20240229 | anthropic | In: text, image, pdf; Out: text | function_calling, vision | 200000 | 4096 | In: $3.00, Out: $15.00, Cache: $0.30 |
| claude-3-5-sonnet-20240620 | anthropic | In: text, image, pdf; Out: text | function_calling, vision | 200000 | 8192 | In: $3.00, Out: $15.00, Cache: $0.30 |
| claude-3-5-sonnet-20241022 | anthropic | In: text, image, pdf; Out: text | function_calling, vision | 200000 | 8192 | In: $3.00, Out: $15.00, Cache: $0.30 |
| claude-3-7-sonnet-20250219 | anthropic | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 200000 | 64000 | In: $3.00, Out: $15.00, Cache: $0.30 |
| claude-3-7-sonnet-latest | anthropic | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 200000 | 64000 | In: $3.00, Out: $15.00, Cache: $0.30 |
| claude-sonnet-4-20250514 | anthropic | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 64000 | In: $3.00, Out: $15.00, Cache: $0.30 |
| claude-sonnet-4-0 | anthropic | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 200000 | 64000 | In: $3.00, Out: $15.00, Cache: $0.30 |
| claude-sonnet-4-5-20250929 | anthropic | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 64000 | In: $3.00, Out: $15.00, Cache: $0.30 |
| claude-sonnet-4-5 | anthropic | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 200000 | 64000 | In: $3.00, Out: $15.00, Cache: $0.30 |
| claude-sonnet-4-6 | anthropic | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 64000 | In: $3.00, Out: $15.00, Cache: $0.30 |
| gpt-4 | azure | In: text, image, pdf; Out: text | streaming, function_calling | 8192 | 8192 | In: $10.00, Out: $30.00 |
| gpt-4-turbo-2024-04-09 | azure | In: text, image, pdf; Out: text | streaming, function_calling | 128000 | 4096 | In: $10.00, Out: $30.00 |
| gpt-4-turbo-jp | azure | In: text, image, pdf; Out: text | streaming, function_calling | 128000 | 4096 | In: $10.00, Out: $30.00 |
| gpt-4.1 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output | 1047576 | 32768 | In: $2.00, Out: $8.00, Cache: $0.50 |
| gpt-4.1-2025-04-14 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output | 1047576 | 32768 | In: $2.00, Out: $8.00, Cache: $0.50 |
| gpt-4.1-2025-04-14-text | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output | 1047576 | 32768 | In: $2.00, Out: $8.00, Cache: $0.50 |
| gpt-4.1-mini | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output | 1047576 | 32768 | In: $0.40, Out: $1.60, Cache: $0.10 |
| gpt-4.1-mini-2025-04-14 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output | 1047576 | 32768 | In: $0.40, Out: $1.60, Cache: $0.10 |
| gpt-4.1-nano | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output | 1047576 | 32768 | In: $0.10, Out: $0.40 |
| gpt-4.1-nano-2025-04-14 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output | 1047576 | 32768 | In: $0.10, Out: $0.40 |
| gpt-4o | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output | 128000 | 16384 | In: $2.50, Out: $10.00 |
| gpt-4o-2024-05-13 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output | 128000 | 16384 | In: $2.50, Out: $10.00 |
| gpt-4o-2024-08-06 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output | 128000 | 16384 | In: $2.50, Out: $10.00 |
| gpt-4o-2024-11-20 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output | 128000 | 16384 | In: $2.50, Out: $10.00 |
| gpt-4o-canvas-2024-09-25 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output | 128000 | 16384 | In: $2.50, Out: $10.00 |
| gpt-4o-mini | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output | 128000 | 16384 | In: $0.15, Out: $0.60 |
| gpt-4o-mini-2024-07-18 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output | 128000 | 16384 | In: $0.15, Out: $0.60 |
| gpt-5-chat-2025-08-07 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5-chat-2025-08-15 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5-chat-2025-10-03 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5-codex-2025-09-15 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5-mini-2025-08-07 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5-mini-lite-2025-08-07 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5-nano-2025-08-07 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5.1-chat-2025-11-13 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5.1-codex-mini-2025-11-13 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5.2-chat-2025-12-11 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5.2-chat-2026-02-10 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5.3-codex-2026-02-20 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| o1-2024-12-17 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 200000 | 100000 | In: $15.00, Out: $60.00 |
| o1-pro | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 200000 | 100000 | In: $150.00, Out: $600.00 |
| o1-pro-2025-03-19 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 200000 | 100000 | In: $150.00, Out: $600.00 |
| o3-mini | azure | In: text; Out: text | streaming, function_calling, structured_output, reasoning | 200000 | 100000 | In: $1.10, Out: $4.40 |
| o3-mini-2025-01-31 | azure | In: text; Out: text | streaming, function_calling, structured_output, reasoning | 200000 | 100000 | In: $1.10, Out: $4.40 |
| o3-mini-alpha | azure | In: text; Out: text | streaming, function_calling, structured_output, reasoning | 200000 | 100000 | In: $1.10, Out: $4.40 |
| o3-mini-alpha-2024-12-17 | azure | In: text; Out: text | streaming, function_calling, structured_output, reasoning | 200000 | 100000 | In: $1.10, Out: $4.40 |
| anthropic.claude-3-haiku-20240307-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, vision, streaming | 200000 | 4096 | In: $0.25, Out: $1.25 |
| anthropic.claude-3-haiku-20240307-v1:0:200k | bedrock | In: text, image, pdf; Out: text | function_calling, vision, streaming | 200000 | 4096 | In: $0.25, Out: $1.25 |
| anthropic.claude-3-haiku-20240307-v1:0:48k | bedrock | In: text, image, pdf; Out: text | function_calling, vision, streaming | 48000 | 4096 | In: $0.25, Out: $1.25 |
| anthropic.claude-3-5-haiku-20241022-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, vision, streaming | 200000 | 8192 | In: $0.80, Out: $4.00, Cache: $0.08 |
| anthropic.claude-haiku-4-5-20251001-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 200000 | 64000 | In: $1.00, Out: $5.00, Cache: $0.10 |
| eu.anthropic.claude-haiku-4-5-20251001-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 200000 | 64000 | In: $1.00, Out: $5.00, Cache: $0.10 |
| global.anthropic.claude-haiku-4-5-20251001-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 200000 | 64000 | In: $1.00, Out: $5.00, Cache: $0.10 |
| us.anthropic.claude-haiku-4-5-20251001-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 64000 | In: $1.00, Out: $5.00, Cache: $0.10 |
| anthropic.claude-3-opus-20240229-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, vision | 200000 | 4096 | In: $15.00, Out: $75.00 |
| anthropic.claude-opus-4-20250514-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 200000 | 32000 | In: $15.00, Out: $75.00, Cache: $1.50 |
| us.anthropic.claude-opus-4-20250514-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 32000 | In: $15.00, Out: $75.00, Cache: $1.50 |
| anthropic.claude-opus-4-1-20250805-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 200000 | 32000 | In: $15.00, Out: $75.00, Cache: $1.50 |
| us.anthropic.claude-opus-4-1-20250805-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 32000 | In: $15.00, Out: $75.00, Cache: $1.50 |
| anthropic.claude-opus-4-5-20251101-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 200000 | 64000 | In: $5.00, Out: $25.00, Cache: $0.50 |
| eu.anthropic.claude-opus-4-5-20251101-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 200000 | 64000 | In: $5.00, Out: $25.00, Cache: $0.50 |
| global.anthropic.claude-opus-4-5-20251101-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 200000 | 64000 | In: $5.00, Out: $25.00, Cache: $0.50 |
| us.anthropic.claude-opus-4-5-20251101-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 64000 | In: $5.00, Out: $25.00, Cache: $0.50 |
| anthropic.claude-opus-4-6-v1 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache: $0.50 |
| eu.anthropic.claude-opus-4-6-v1 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache: $0.50 |
| global.anthropic.claude-opus-4-6-v1 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache: $0.50 |
| us.anthropic.claude-opus-4-6-v1 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache: $0.50 |
| anthropic.claude-3-sonnet-20240229-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, vision, streaming | 200000 | 4096 | In: $3.00, Out: $15.00 |
| anthropic.claude-3-sonnet-20240229-v1:0:200k | bedrock | In: text, image, pdf; Out: text | function_calling, vision, streaming | 200000 | 4096 | In: $3.00, Out: $15.00 |
| anthropic.claude-3-sonnet-20240229-v1:0:28k | bedrock | In: text, image, pdf; Out: text | function_calling, vision, streaming | 28000 | 4096 | In: $3.00, Out: $15.00 |
| anthropic.claude-3-5-sonnet-20240620-v1:0:18k | bedrock | In: text, image, pdf; Out: text | function_calling, vision, streaming | 18000 | 8192 | In: $3.00, Out: $15.00, Cache: $0.30 |
| anthropic.claude-3-5-sonnet-20240620-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, vision, streaming | 200000 | 8192 | In: $3.00, Out: $15.00, Cache: $0.30 |
| anthropic.claude-3-5-sonnet-20240620-v1:0:200k | bedrock | In: text, image, pdf; Out: text | function_calling, vision, streaming | 200000 | 8192 | In: $3.00, Out: $15.00, Cache: $0.30 |
| anthropic.claude-3-5-sonnet-20240620-v1:0:51k | bedrock | In: text, image, pdf; Out: text | function_calling, vision, streaming | 51000 | 8192 | In: $3.00, Out: $15.00, Cache: $0.30 |
| anthropic.claude-3-5-sonnet-20241022-v2:0:18k | bedrock | In: text, image, pdf; Out: text | function_calling, vision, streaming | 18000 | 8192 | In: $3.00, Out: $15.00, Cache: $0.30 |
| anthropic.claude-3-5-sonnet-20241022-v2:0:200k | bedrock | In: text, image, pdf; Out: text | function_calling, vision, streaming | 200000 | 8192 | In: $3.00, Out: $15.00, Cache: $0.30 |
| anthropic.claude-3-5-sonnet-20241022-v2:0:51k | bedrock | In: text, image, pdf; Out: text | function_calling, vision, streaming | 51000 | 8192 | In: $3.00, Out: $15.00, Cache: $0.30 |
| anthropic.claude-3-5-sonnet-20241022-v2:0 | bedrock | In: text, image, pdf; Out: text | function_calling, vision, streaming | 200000 | 8192 | In: $3.00, Out: $15.00, Cache: $0.30 |
| us.anthropic.claude-3-7-sonnet-20250219-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, vision, streaming | 200000 | 8192 | In: $3.00, Out: $15.00, Cache: $0.30 |
| anthropic.claude-3-7-sonnet-20250219-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, vision | 200000 | 8192 | In: $3.00, Out: $15.00, Cache: $0.30 |
| anthropic.claude-sonnet-4-20250514-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 200000 | 64000 | In: $3.00, Out: $15.00, Cache: $0.30 |
| eu.anthropic.claude-sonnet-4-20250514-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 200000 | 64000 | In: $3.00, Out: $15.00, Cache: $0.30 |
| global.anthropic.claude-sonnet-4-20250514-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 200000 | 64000 | In: $3.00, Out: $15.00, Cache: $0.30 |
| us.anthropic.claude-sonnet-4-20250514-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 64000 | In: $3.00, Out: $15.00, Cache: $0.30 |
| anthropic.claude-sonnet-4-5-20250929-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 200000 | 64000 | In: $3.00, Out: $15.00, Cache: $0.30 |
| eu.anthropic.claude-sonnet-4-5-20250929-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 200000 | 64000 | In: $3.00, Out: $15.00, Cache: $0.30 |
| global.anthropic.claude-sonnet-4-5-20250929-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 200000 | 64000 | In: $3.00, Out: $15.00, Cache: $0.30 |
| us.anthropic.claude-sonnet-4-5-20250929-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 64000 | In: $3.00, Out: $15.00, Cache: $0.30 |
| anthropic.claude-sonnet-4-6 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 200000 | 64000 | In: $3.00, Out: $15.00, Cache: $0.30 |
| eu.anthropic.claude-sonnet-4-6 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 200000 | 64000 | In: $3.00, Out: $15.00, Cache: $0.30 |
| global.anthropic.claude-sonnet-4-6 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 200000 | 64000 | In: $3.00, Out: $15.00, Cache: $0.30 |
| us.anthropic.claude-sonnet-4-6 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 64000 | In: $3.00, Out: $15.00, Cache: $0.30 |
| cohere.command-r-v1:0 | bedrock | In: text; Out: text | function_calling, streaming | 128000 | 4096 | In: $0.50, Out: $1.50 |
| cohere.command-r-plus-v1:0 | bedrock | In: text; Out: text | function_calling, streaming | 128000 | 4096 | In: $3.00, Out: $15.00 |
| deepseek.v3.2 | bedrock | In: text; Out: text | streaming, function_calling | - | 163840 | - |
| us.deepseek.r1-v1:0 | bedrock | In: text; Out: text | function_calling, reasoning, streaming | 128000 | 32768 | In: $1.35, Out: $5.40 |
| deepseek.r1-v1:0 | bedrock | In: text; Out: text | function_calling, reasoning | 128000 | 32768 | In: $1.35, Out: $5.40 |
| deepseek.v3-v1:0 | bedrock | In: text; Out: text | function_calling, reasoning, streaming | 163840 | 81920 | In: $0.58, Out: $1.68 |
| deepseek.v3.2-v1:0 | bedrock | In: text; Out: text | function_calling, reasoning | 163840 | 81920 | In: $0.62, Out: $1.85 |
| mistral.devstral-2-123b | bedrock | In: text; Out: text | streaming, function_calling | - | 262144 | - |
| cohere.embed-english-v3:0:512 | bedrock | In: text; Out: embeddings | function_calling | - | - | - |
| cohere.embed-english-v3 | bedrock | In: text; Out: embeddings | function_calling | - | - | - |
| cohere.embed-multilingual-v3 | bedrock | In: text; Out: embeddings | function_calling | - | - | - |
| cohere.embed-multilingual-v3:0:512 | bedrock | In: text; Out: embeddings | function_calling | - | - | - |
| us.cohere.embed-v4:0 | bedrock | In: text, image; Out: embeddings | function_calling | 128000 | - | - |
| zai.glm-4.7 | bedrock | In: text; Out: text | function_calling, reasoning, streaming | 204800 | 131072 | In: $0.60, Out: $2.20 |
| zai.glm-4.7-flash | bedrock | In: text; Out: text | function_calling, reasoning, streaming | 200000 | 131072 | In: $0.07, Out: $0.40 |
| openai.gpt-oss-safeguard-120b | bedrock | In: text; Out: text | function_calling, streaming, reasoning | 128000 | 4096 | In: $0.15, Out: $0.60 |
| openai.gpt-oss-safeguard-20b | bedrock | In: text; Out: text | function_calling, streaming, reasoning | 128000 | 4096 | In: $0.07, Out: $0.20 |
| google.gemma-3-4b-it | bedrock | In: text, image; Out: text | function_calling, vision, streaming | 128000 | 4096 | In: $0.04, Out: $0.08 |
| google.gemma-3-12b-it | bedrock | In: text, image; Out: text | vision, streaming, function_calling | 131072 | 8192 | In: $0.05, Out: $0.10 |
| google.gemma-3-27b-it | bedrock | In: text, image; Out: text | function_calling, vision, streaming | 202752 | 8192 | In: $0.12, Out: $0.20 |
| ai21.jamba-1-5-large-v1:0 | bedrock | In: text; Out: text | function_calling | 256000 | 4096 | In: $2.00, Out: $8.00 |
| ai21.jamba-1-5-mini-v1:0 | bedrock | In: text; Out: text | function_calling | 256000 | 4096 | In: $0.20, Out: $0.40 |
| moonshot.kimi-k2-thinking | bedrock | In: text; Out: text | function_calling, reasoning, streaming | 256000 | 256000 | In: $0.60, Out: $2.50 |
| moonshotai.kimi-k2.5 | bedrock | In: text, image; Out: text | function_calling, reasoning, vision, streaming | 256000 | 256000 | In: $0.60, Out: $3.00 |
| meta.llama3-70b-instruct-v1:0 | bedrock | In: text; Out: text | streaming, function_calling | 8192 | 2048 | In: $2.65, Out: $3.50 |
| meta.llama3-8b-instruct-v1:0 | bedrock | In: text; Out: text | streaming, function_calling | 8192 | 2048 | In: $0.30, Out: $0.60 |
| meta.llama3-1-405b-instruct-v1:0 | bedrock | In: text; Out: text | streaming, function_calling | - | - | - |
| meta.llama3-1-70b-instruct-v1:0 | bedrock | In: text; Out: text | function_calling, streaming | 128000 | 4096 | In: $0.72, Out: $0.72 |
| meta.llama3-1-70b-instruct-v1:0:128k | bedrock | In: text; Out: text | function_calling, streaming | 128000 | 4096 | In: $0.72, Out: $0.72 |
| meta.llama3-1-8b-instruct-v1:0:128k | bedrock | In: text; Out: text | function_calling, streaming | 128000 | 4096 | In: $0.22, Out: $0.22 |
| meta.llama3-1-8b-instruct-v1:0 | bedrock | In: text; Out: text | function_calling, streaming | 128000 | 4096 | In: $0.22, Out: $0.22 |
| meta.llama3-2-11b-instruct-v1:0:128k | bedrock | In: text, image; Out: text | function_calling, vision, streaming | 128000 | 4096 | In: $0.16, Out: $0.16 |
| meta.llama3-2-11b-instruct-v1:0 | bedrock | In: text, image; Out: text | function_calling, vision | 128000 | 4096 | In: $0.16, Out: $0.16 |
| us.meta.llama3-2-11b-instruct-v1:0 | bedrock | In: text, image; Out: text | function_calling, vision, streaming | 128000 | 4096 | In: $0.16, Out: $0.16 |
| meta.llama3-2-1b-instruct-v1:0 | bedrock | In: text; Out: text | function_calling | 131000 | 4096 | In: $0.10, Out: $0.10 |
| us.meta.llama3-2-1b-instruct-v1:0 | bedrock | In: text; Out: text | function_calling, streaming | 131000 | 4096 | In: $0.10, Out: $0.10 |
| meta.llama3-2-1b-instruct-v1:0:128k | bedrock | In: text; Out: text | function_calling, streaming | 128000 | 4096 | In: $0.10, Out: $0.10 |
| meta.llama3-2-3b-instruct-v1:0:128k | bedrock | In: text; Out: text | function_calling, streaming | 128000 | 4096 | In: $0.15, Out: $0.15 |
| us.meta.llama3-2-3b-instruct-v1:0 | bedrock | In: text; Out: text | function_calling, streaming | 131000 | 4096 | In: $0.15, Out: $0.15 |
| meta.llama3-2-3b-instruct-v1:0 | bedrock | In: text; Out: text | function_calling | 131000 | 4096 | In: $0.15, Out: $0.15 |
| meta.llama3-2-90b-instruct-v1:0 | bedrock | In: text, image; Out: text | function_calling, vision | 128000 | 4096 | In: $0.72, Out: $0.72 |
| meta.llama3-2-90b-instruct-v1:0:128k | bedrock | In: text, image; Out: text | function_calling, vision, streaming | 128000 | 4096 | In: $0.72, Out: $0.72 |
| us.meta.llama3-2-90b-instruct-v1:0 | bedrock | In: text, image; Out: text | function_calling, vision, streaming | 128000 | 4096 | In: $0.72, Out: $0.72 |
| meta.llama3-3-70b-instruct-v1:0 | bedrock | In: text; Out: text | function_calling | 128000 | 4096 | In: $0.72, Out: $0.72 |
| meta.llama3-3-70b-instruct-v1:0:128k | bedrock | In: text; Out: text | function_calling, streaming | 128000 | 4096 | In: $0.72, Out: $0.72 |
| us.meta.llama3-3-70b-instruct-v1:0 | bedrock | In: text; Out: text | function_calling, streaming | 128000 | 4096 | In: $0.72, Out: $0.72 |
| meta.llama4-maverick-17b-instruct-v1:0 | bedrock | In: text, image; Out: text | function_calling, vision | 1000000 | 16384 | In: $0.24, Out: $0.97 |
| us.meta.llama4-maverick-17b-instruct-v1:0 | bedrock | In: text, image; Out: text | function_calling, vision, streaming | 1000000 | 16384 | In: $0.24, Out: $0.97 |
| us.meta.llama4-scout-17b-instruct-v1:0 | bedrock | In: text, image; Out: text | function_calling, vision, streaming | 3500000 | 16384 | In: $0.17, Out: $0.66 |
| meta.llama4-scout-17b-instruct-v1:0 | bedrock | In: text, image; Out: text | function_calling, vision | 3500000 | 16384 | In: $0.17, Out: $0.66 |
| mistral.magistral-small-2509 | bedrock | In: text, image; Out: text | streaming, function_calling, reasoning | - | 131072 | - |
| minimax.minimax-m2 | bedrock | In: text; Out: text | function_calling, reasoning, streaming | 204608 | 128000 | In: $0.30, Out: $1.20 |
| minimax.minimax-m2.1 | bedrock | In: text; Out: text | function_calling, reasoning, streaming | 204800 | 131072 | In: $0.30, Out: $1.20 |
| mistral.ministral-3-14b-instruct | bedrock | In: text; Out: text | function_calling, streaming | 128000 | 4096 | In: $0.20, Out: $0.20 |
| mistral.ministral-3-8b-instruct | bedrock | In: text; Out: text | function_calling, streaming | 128000 | 4096 | In: $0.15, Out: $0.15 |
| mistral.ministral-3-3b-instruct | bedrock | In: text, image; Out: text | streaming, function_calling | - | 262144 | - |
| mistral.mistral-large-2402-v1:0 | bedrock | In: text; Out: text | function_calling, streaming | 128000 | 4096 | In: $0.50, Out: $1.50 |
| mistral.mistral-large-2407-v1:0 | bedrock | In: text; Out: text | streaming, function_calling | - | - | - |
| mistral.mistral-large-3-675b-instruct | bedrock | In: text, image; Out: text | streaming, function_calling | - | 262144 | - |
| mistral.mistral-7b-instruct-v0:2 | bedrock | In: text; Out: text | function_calling, structured_output, streaming | 127000 | 127000 | In: $0.11, Out: $0.11 |
| mistral.mixtral-8x7b-instruct-v0:1 | bedrock | In: text; Out: text | structured_output, streaming, function_calling | 32000 | 32000 | In: $0.70, Out: $0.70 |
| nvidia.nemotron-nano-12b-v2 | bedrock | In: text, image; Out: text | function_calling, vision, streaming | 128000 | 4096 | In: $0.20, Out: $0.60 |
| nvidia.nemotron-nano-9b-v2 | bedrock | In: text; Out: text | function_calling, streaming | 128000 | 4096 | In: $0.06, Out: $0.23 |
| nvidia.nemotron-nano-3-30b | bedrock | In: text; Out: text | streaming, function_calling | - | 262144 | - |
| amazon.nova-2-lite-v1:0 | bedrock | In: text, image, video; Out: text | function_calling, vision | 128000 | 4096 | In: $0.33, Out: $2.75 |
| us.amazon.nova-2-lite-v1:0 | bedrock | In: text, image, video; Out: text | function_calling, vision, streaming | 128000 | 4096 | In: $0.33, Out: $2.75 |
| amazon.nova-2-sonic-v1:0 | bedrock | In: audio; Out: audio, text | streaming, function_calling | - | - | - |
| amazon.nova-lite-v1:0 | bedrock | In: text, image, video; Out: text | function_calling, vision | 300000 | 8192 | In: $0.06, Out: $0.24, Cache: $0.02 |
| us.amazon.nova-lite-v1:0 | bedrock | In: text, image, video; Out: text | function_calling, vision, streaming | 300000 | 8192 | In: $0.06, Out: $0.24, Cache: $0.02 |
| amazon.nova-micro-v1:0 | bedrock | In: text; Out: text | function_calling | 128000 | 8192 | In: $0.04, Out: $0.14, Cache: $0.01 |
| us.amazon.nova-micro-v1:0 | bedrock | In: text; Out: text | function_calling, streaming | 128000 | 8192 | In: $0.04, Out: $0.14, Cache: $0.01 |
| us.amazon.nova-premier-v1:0 | bedrock | In: text, image, video; Out: text | function_calling, reasoning, vision, streaming | 1000000 | 16384 | In: $2.50, Out: $12.50 |
| amazon.nova-premier-v1:0:mm | bedrock | In: text, image, video; Out: text | streaming, function_calling | - | - | - |
| amazon.nova-premier-v1:0:8k | bedrock | In: text, image, video; Out: text | function_calling, reasoning, vision, streaming | 8000 | 16384 | In: $2.50, Out: $12.50 |
| amazon.nova-premier-v1:0:20k | bedrock | In: text, image, video; Out: text | function_calling, reasoning, vision, streaming | 20000 | 16384 | In: $2.50, Out: $12.50 |
| amazon.nova-premier-v1:0:1000k | bedrock | In: text, image, video; Out: text | function_calling, reasoning, vision, streaming | 1000000 | 16384 | In: $2.50, Out: $12.50 |
| amazon.nova-premier-v1:0 | bedrock | In: text, image, video; Out: text | function_calling, reasoning, vision | 1000000 | 16384 | In: $2.50, Out: $12.50 |
| amazon.nova-pro-v1:0 | bedrock | In: text, image, video; Out: text | function_calling, vision | 300000 | 8192 | In: $0.80, Out: $3.20, Cache: $0.20 |
| us.amazon.nova-pro-v1:0 | bedrock | In: text, image, video; Out: text | function_calling, vision, streaming | 300000 | 8192 | In: $0.80, Out: $3.20, Cache: $0.20 |
| writer.palmyra-x4-v1:0 | bedrock | In: text; Out: text | function_calling, reasoning | 122880 | 8192 | In: $2.50, Out: $10.00 |
| us.writer.palmyra-x4-v1:0 | bedrock | In: text; Out: text | function_calling, reasoning, streaming | 122880 | 8192 | In: $2.50, Out: $10.00 |
| writer.palmyra-x5-v1:0 | bedrock | In: text; Out: text | function_calling, reasoning | 1040000 | 8192 | In: $0.60, Out: $6.00 |
| us.writer.palmyra-x5-v1:0 | bedrock | In: text; Out: text | function_calling, reasoning, streaming | 1040000 | 8192 | In: $0.60, Out: $6.00 |
| us.twelvelabs.pegasus-1-2-v1:0 | bedrock | In: text, video; Out: text | streaming, function_calling | - | - | - |
| us.mistral.pixtral-large-2502-v1:0 | bedrock | In: text, image; Out: text | streaming, function_calling | - | - | - |
| qwen.qwen3-next-80b-a3b | bedrock | In: text; Out: text | function_calling, structured_output, streaming | 262000 | 262000 | In: $0.14, Out: $1.40 |
| qwen.qwen3-vl-235b-a22b | bedrock | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 262000 | 262000 | In: $0.30, Out: $1.50 |
| qwen.qwen3-235b-a22b-2507-v1:0 | bedrock | In: text; Out: text | function_calling, streaming | 262144 | 131072 | In: $0.22, Out: $0.88 |
| qwen.qwen3-32b-v1:0 | bedrock | In: text; Out: text | function_calling, reasoning, streaming | 16384 | 16384 | In: $0.15, Out: $0.60 |
| qwen.qwen3-coder-30b-a3b-v1:0 | bedrock | In: text; Out: text | function_calling, streaming | 262144 | 131072 | In: $0.15, Out: $0.60 |
| qwen.qwen3-coder-480b-a35b-v1:0 | bedrock | In: text; Out: text | function_calling, streaming | 131072 | 65536 | In: $0.22, Out: $1.80 |
| luma.ray-v2:0 | bedrock | In: text; Out: video | function_calling | - | - | - |
| amazon.rerank-v1:0 | bedrock | In: text; Out: text | function_calling | - | - | - |
| cohere.rerank-v3-5:0 | bedrock | In: text; Out: text | function_calling | - | - | - |
| stability.sd3-5-large-v1:0 | bedrock | In: text, image; Out: image | function_calling | - | - | - |
| us.stability.stable-conservative-upscale-v1:0 | bedrock | In: text, image; Out: image | function_calling | - | - | - |
| us.stability.stable-image-control-sketch-v1:0 | bedrock | In: text, image; Out: image | function_calling | - | - | - |
| us.stability.stable-image-control-structure-v1:0 | bedrock | In: text, image; Out: image | function_calling | - | - | - |
| stability.stable-image-core-v1:1 | bedrock | In: text; Out: image | function_calling | - | - | - |
| us.stability.stable-creative-upscale-v1:0 | bedrock | In: text, image; Out: image | function_calling | - | - | - |
| us.stability.stable-image-erase-object-v1:0 | bedrock | In: text, image; Out: image | function_calling | - | - | - |
| us.stability.stable-fast-upscale-v1:0 | bedrock | In: text, image; Out: image | function_calling | - | - | - |
| us.stability.stable-image-inpaint-v1:0 | bedrock | In: text, image; Out: image | function_calling | - | - | - |
| us.stability.stable-outpaint-v1:0 | bedrock | In: text, image; Out: image | function_calling | - | - | - |
| us.stability.stable-image-remove-background-v1:0 | bedrock | In: text, image; Out: image | function_calling | - | - | - |
| us.stability.stable-image-search-recolor-v1:0 | bedrock | In: text, image; Out: image | function_calling | - | - | - |
| us.stability.stable-image-search-replace-v1:0 | bedrock | In: text, image; Out: image | function_calling | - | - | - |
| us.stability.stable-image-style-guide-v1:0 | bedrock | In: text, image; Out: image | function_calling | - | - | - |
| us.stability.stable-style-transfer-v1:0 | bedrock | In: text, image; Out: image | function_calling | - | - | - |
| stability.stable-image-ultra-v1:1 | bedrock | In: text; Out: image | function_calling | - | - | - |
| amazon.titan-embed-text-v1:2:8k | bedrock | In: text; Out: embeddings | function_calling | - | - | - |
| amazon.titan-embed-text-v1 | bedrock | In: text; Out: embeddings | function_calling | - | - | - |
| amazon.titan-image-generator-v2:0 | bedrock | In: text, image; Out: image | function_calling | - | - | - |
| amazon.titan-embed-image-v1 | bedrock | In: text, image; Out: embeddings | function_calling | - | - | - |
| amazon.titan-embed-image-v1:0 | bedrock | In: text, image; Out: embeddings | function_calling | - | - | - |
| amazon.titan-embed-text-v2:0 | bedrock | In: text; Out: embeddings | function_calling | - | - | - |
| amazon.titan-embed-g1-text-02 | bedrock | In: text; Out: embeddings | function_calling | - | - | - |
| amazon.titan-text-express-v1:0:8k | bedrock | In: text; Out: text | function_calling | 128000 | 4096 | In: $0.20, Out: $0.60 |
| amazon.titan-text-express-v1 | bedrock | In: text; Out: text | function_calling | 128000 | 4096 | In: $0.20, Out: $0.60 |
| amazon.titan-tg1-large | bedrock | In: text; Out: text | streaming, function_calling | - | - | - |
| mistral.voxtral-mini-3b-2507 | bedrock | In: audio, text; Out: text | function_calling, streaming | 128000 | 4096 | In: $0.04, Out: $0.04 |
| mistral.voxtral-small-24b-2507 | bedrock | In: text, audio; Out: text | function_calling, streaming | 32000 | 8192 | In: $0.15, Out: $0.35 |
| openai.gpt-oss-120b-1:0 | bedrock | In: text; Out: text | function_calling, streaming | 128000 | 4096 | In: $0.15, Out: $0.60 |
| openai.gpt-oss-20b-1:0 | bedrock | In: text; Out: text | function_calling, streaming | 128000 | 4096 | In: $0.07, Out: $0.30 |
| deepseek-chat | deepseek | In: text; Out: text | function_calling, streaming | 128000 | 8192 | In: $0.28, Out: $0.42, Cache: $0.03 |
| deepseek-reasoner | deepseek | In: text; Out: text | function_calling, reasoning, streaming | 128000 | 128000 | In: $0.28, Out: $0.42, Cache: $0.03 |
| deep-research-pro-preview-12-2025 | gemini | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, caching | 131072 | 65536 | In: $0.08, Out: $0.30 |
| gemini-1.5-flash | gemini | In: text, image, audio, video; Out: text | function_calling, vision | 1000000 | 8192 | In: $0.08, Out: $0.30, Cache: $0.02 |
| gemini-1.5-flash-8b | gemini | In: text, image, audio, video; Out: text | function_calling, vision | 1000000 | 8192 | In: $0.04, Out: $0.15, Cache: $0.01 |
| gemini-1.5-pro | gemini | In: text, image, audio, video; Out: text | function_calling, vision | 1000000 | 8192 | In: $1.25, Out: $5.00, Cache: $0.31 |
| gemini-2.0-flash | gemini | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, vision, streaming, batch, caching | 1048576 | 8192 | In: $0.10, Out: $0.40, Cache: $0.02 |
| gemini-2.0-flash-001 | gemini | In: text, image, pdf, video; Out: text | streaming, function_calling, structured_output, batch, caching | 1048576 | 8192 | In: $0.10, Out: $0.40 |
| gemini-2.0-flash-lite | gemini | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, vision, streaming, batch | 1048576 | 8192 | In: $0.08, Out: $0.30 |
| gemini-2.5-computer-use-preview-10-2025 | gemini | In: text, image, pdf, video; Out: text | streaming, function_calling, structured_output, caching | 131072 | 65536 | In: $0.08, Out: $0.30 |
| gemini-2.5-flash | gemini | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming, batch, caching | 1048576 | 65536 | In: $0.30, Out: $2.50, Cache: $0.08 |
| gemini-2.5-flash-image | gemini | In: text, image; Out: text, image | reasoning, vision, streaming, function_calling, structured_output, batch, caching | 32768 | 32768 | In: $0.30, Out: $30.00, Cache: $0.08 |
| gemini-2.5-flash-lite | gemini | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming, batch | 1048576 | 65536 | In: $0.10, Out: $0.40, Cache: $0.02 |
| gemini-2.5-flash-lite-preview-06-17 | gemini | In: text, image, audio, video, pdf; Out: text | function_calling, reasoning, vision | 1048576 | 65536 | In: $0.10, Out: $0.40, Cache: $0.02 |
| gemini-2.5-flash-lite-preview-09-2025 | gemini | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming, batch | 1048576 | 65536 | In: $0.10, Out: $0.40, Cache: $0.02 |
| gemini-2.5-flash-native-audio-latest | gemini | In: text, image, pdf, video, audio; Out: text | streaming, function_calling, structured_output, batch, caching | 131072 | 8192 | In: $0.08, Out: $0.30 |
| gemini-2.5-flash-native-audio-preview-09-2025 | gemini | In: text, image, pdf, video, audio; Out: text | streaming, function_calling, structured_output, batch, caching | 131072 | 8192 | In: $0.08, Out: $0.30 |
| gemini-2.5-flash-native-audio-preview-12-2025 | gemini | In: text, image, pdf, video, audio; Out: text | streaming, function_calling, structured_output, batch, caching | 131072 | 8192 | In: $0.08, Out: $0.30 |
| gemini-2.5-flash-preview-04-17 | gemini | In: text, image, audio, video, pdf; Out: text | function_calling, reasoning, vision | 1048576 | 65536 | In: $0.15, Out: $0.60, Cache: $0.04 |
| gemini-2.5-flash-preview-05-20 | gemini | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1048576 | 65536 | In: $0.15, Out: $0.60, Cache: $0.04 |
| gemini-2.5-flash-preview-09-2025 | gemini | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1048576 | 65536 | In: $0.30, Out: $2.50, Cache: $0.08 |
| gemini-2.5-flash-preview-tts | gemini | In: text; Out: audio | streaming, function_calling, structured_output, batch, caching | 8000 | 16000 | In: $0.50, Out: $10.00 |
| gemini-2.5-pro | gemini | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming, caching | 1048576 | 65536 | In: $1.25, Out: $10.00, Cache: $0.31 |
| gemini-2.5-pro-preview-05-06 | gemini | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1048576 | 65536 | In: $1.25, Out: $10.00, Cache: $0.31 |
| gemini-2.5-pro-preview-06-05 | gemini | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1048576 | 65536 | In: $1.25, Out: $10.00, Cache: $0.31 |
| gemini-2.5-pro-preview-tts | gemini | In: text; Out: audio | streaming, function_calling, structured_output, caching | 8000 | 16000 | In: $1.00, Out: $20.00 |
| gemini-3-flash-preview | gemini | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming, batch, caching | 1048576 | 65536 | In: $0.50, Out: $3.00, Cache: $0.05 |
| gemini-3-pro-preview | gemini | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming, caching | 1000000 | 64000 | In: $2.00, Out: $12.00, Cache: $0.20 |
| gemini-3.1-pro-preview | gemini | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming, caching | 1048576 | 65536 | In: $2.00, Out: $12.00, Cache: $0.20 |
| gemini-3.1-pro-preview-customtools | gemini | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming, caching | 1048576 | 65536 | In: $2.00, Out: $12.00, Cache: $0.20 |
| gemini-flash-latest | gemini | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming, batch, caching | 1048576 | 65536 | In: $0.30, Out: $2.50, Cache: $0.08 |
| gemini-flash-lite-latest | gemini | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming, batch | 1048576 | 65536 | In: $0.10, Out: $0.40, Cache: $0.02 |
| gemini-live-2.5-flash | gemini | In: text, image, audio, video; Out: text, audio | function_calling, reasoning, vision | 128000 | 8000 | In: $0.50, Out: $2.00 |
| gemini-live-2.5-flash-preview-native-audio | gemini | In: text, audio, video; Out: text, audio | function_calling, reasoning, vision | 131072 | 65536 | In: $0.50, Out: $2.00 |
| gemini-pro-latest | gemini | In: text, image, pdf, video; Out: text | streaming, function_calling, structured_output, caching | 1048576 | 65536 | In: $0.08, Out: $0.30 |
| gemini-robotics-er-1.5-preview | gemini | In: text, image, pdf, video; Out: text | streaming, function_calling, structured_output, caching | 1048576 | 65536 | In: $0.08, Out: $0.30 |
| gemini-3-pro-image-preview | gemini | In: text, image, pdf, video; Out: text | streaming, function_calling, structured_output, caching | 131072 | 32768 | In: $0.08, Out: $0.30 |
| nano-banana-pro-preview | gemini | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, caching | 131072 | 32768 | In: $0.08, Out: $0.30 |
| codestral-2508 | mistral | In: text; Out: text | streaming, function_calling, structured_output, batch, predicted_outputs | 32768 | 8192 | - |
| codestral-latest | mistral | In: text; Out: text | function_calling, streaming, structured_output, batch, predicted_outputs | 256000 | 4096 | In: $0.30, Out: $0.90 |
| devstral-2512 | mistral | In: text; Out: text | function_calling, streaming, structured_output, batch, fine_tuning | 262144 | 262144 | In: $0.40, Out: $2.00 |
| devstral-medium-latest | mistral | In: text; Out: text | function_calling, streaming, structured_output, batch, fine_tuning | 262144 | 262144 | In: $0.40, Out: $2.00 |
| devstral-latest | mistral | In: text; Out: text | streaming, function_calling, structured_output, batch, fine_tuning | 32768 | 8192 | - |
| devstral-medium-2507 | mistral | In: text; Out: text | function_calling, streaming, structured_output, batch, fine_tuning | 128000 | 128000 | In: $0.40, Out: $2.00 |
| devstral-small-2507 | mistral | In: text; Out: text | function_calling, streaming, structured_output, batch, fine_tuning | 128000 | 128000 | In: $0.10, Out: $0.30 |
| labs-devstral-small-2512 | mistral | In: text, image; Out: text | function_calling, vision, streaming, structured_output, batch, fine_tuning | 256000 | 256000 | - |
| devstral-small-2505 | mistral | In: text; Out: text | function_calling | 128000 | 128000 | In: $0.10, Out: $0.30 |
| devstral-small-latest | mistral | In: text; Out: text | streaming, function_calling, structured_output, batch, fine_tuning | 32768 | 8192 | - |
| magistral-medium-latest | mistral | In: text; Out: text | function_calling, reasoning, streaming, structured_output, batch | 128000 | 16384 | In: $2.00, Out: $5.00 |
| magistral-medium-2509 | mistral | In: text; Out: text | streaming, function_calling, structured_output, reasoning, batch | 32768 | 8192 | - |
| magistral-small | mistral | In: text; Out: text | function_calling, reasoning | 128000 | 128000 | In: $0.50, Out: $1.50 |
| magistral-small-2509 | mistral | In: text; Out: text | streaming, function_calling, structured_output, reasoning, batch | 32768 | 8192 | - |
| magistral-small-latest | mistral | In: text; Out: text | streaming, function_calling, structured_output, reasoning, batch | 32768 | 8192 | - |
| ministral-14b-2512 | mistral | In: text; Out: text | streaming, function_calling, structured_output, batch, distillation | 32768 | 8192 | - |
| ministral-14b-latest | mistral | In: text; Out: text | streaming, function_calling, structured_output, batch, distillation | 32768 | 8192 | - |
| ministral-3b-2512 | mistral | In: text; Out: text | streaming, function_calling, structured_output, batch, distillation | 32768 | 8192 | - |
| ministral-3b-latest | mistral | In: text; Out: text | function_calling, streaming, structured_output, batch, distillation | 128000 | 128000 | In: $0.04, Out: $0.04 |
| ministral-8b-2512 | mistral | In: text; Out: text | streaming, function_calling, structured_output, batch, distillation | 32768 | 8192 | - |
| ministral-8b-latest | mistral | In: text; Out: text | function_calling, streaming, structured_output, batch, distillation | 128000 | 128000 | In: $0.10, Out: $0.10 |
| open-mistral-7b | mistral | In: text; Out: text | function_calling | 8000 | 8000 | In: $0.25, Out: $0.25 |
| mistral-large-latest | mistral | In: text, image; Out: text | function_calling, vision, streaming, structured_output, batch, fine_tuning | 262144 | 262144 | In: $0.50, Out: $1.50 |
| mistral-large-pixtral-2411 | mistral | In: text, image; Out: text | streaming, function_calling, structured_output, vision, batch, fine_tuning | 32768 | 8192 | - |
| mistral-large-2411 | mistral | In: text; Out: text | function_calling, streaming, structured_output, batch, fine_tuning | 131072 | 16384 | In: $2.00, Out: $6.00 |
| mistral-large-2512 | mistral | In: text, image; Out: text | function_calling, vision, streaming, structured_output, batch, fine_tuning | 262144 | 262144 | In: $0.50, Out: $1.50 |
| mistral-medium-latest | mistral | In: text, image; Out: text | function_calling, vision, streaming, structured_output, batch, fine_tuning | 128000 | 16384 | In: $0.40, Out: $2.00 |
| mistral-medium | mistral | In: text; Out: text | streaming, function_calling, structured_output, vision, batch, fine_tuning | 32768 | 8192 | - |
| mistral-medium-2505 | mistral | In: text, image; Out: text | function_calling, vision, streaming, structured_output, batch, fine_tuning | 131072 | 131072 | In: $0.40, Out: $2.00 |
| mistral-medium-2508 | mistral | In: text, image; Out: text | function_calling, vision, streaming, structured_output, batch, fine_tuning | 262144 | 262144 | In: $0.40, Out: $2.00 |
| mistral-nemo | mistral | In: text; Out: text | function_calling | 128000 | 128000 | In: $0.15, Out: $0.15 |
| labs-mistral-small-creative | mistral | In: text; Out: text | streaming, function_calling, structured_output, batch, fine_tuning | 32768 | 8192 | - |
| mistral-small-2501 | mistral | In: text; Out: text | streaming, function_calling, structured_output, batch, fine_tuning | 32768 | 8192 | - |
| mistral-small-latest | mistral | In: text, image; Out: text | function_calling, vision, streaming, structured_output, batch, fine_tuning | 128000 | 16384 | In: $0.10, Out: $0.30 |
| mistral-small-2506 | mistral | In: text, image; Out: text | function_calling, vision, streaming, structured_output, batch, fine_tuning | 128000 | 16384 | In: $0.10, Out: $0.30 |
| mistral-tiny-2407 | mistral | In: text; Out: text | streaming, function_calling, structured_output, batch | 32768 | 8192 | - |
| mistral-tiny-latest | mistral | In: text; Out: text | streaming, function_calling, structured_output, batch | 32768 | 8192 | - |
| mistral-vibe-cli-latest | mistral | In: text; Out: text | streaming, function_calling, structured_output, batch | 32768 | 8192 | - |
| mistral-vibe-cli-with-tools | mistral | In: text; Out: text | streaming, function_calling, structured_output, batch | 32768 | 8192 | - |
| open-mixtral-8x22b | mistral | In: text; Out: text | function_calling | 64000 | 64000 | In: $2.00, Out: $6.00 |
| open-mixtral-8x7b | mistral | In: text; Out: text | function_calling | 32000 | 32000 | In: $0.70, Out: $0.70 |
| open-mistral-nemo | mistral | In: text; Out: text | streaming, function_calling, structured_output, batch | 32768 | 8192 | - |
| open-mistral-nemo-2407 | mistral | In: text; Out: text | streaming, function_calling, structured_output, batch | 32768 | 8192 | - |
| pixtral-12b | mistral | In: text, image; Out: text | function_calling, vision | 128000 | 128000 | In: $0.15, Out: $0.15 |
| pixtral-large-2411 | mistral | In: text, image; Out: text | streaming, function_calling, structured_output, vision, batch | 32768 | 8192 | - |
| pixtral-large-latest | mistral | In: text, image; Out: text | function_calling, vision, streaming, structured_output, batch | 128000 | 128000 | In: $2.00, Out: $6.00 |
| codex-mini-latest | openai | In: text; Out: text | function_calling, reasoning | 200000 | 100000 | In: $1.50, Out: $6.00, Cache: $0.38 |
| gpt-4 | openai | In: text; Out: text | function_calling, streaming | 8192 | 8192 | In: $30.00, Out: $60.00 |
| gpt-4-turbo | openai | In: text, image; Out: text | function_calling, vision, streaming | 128000 | 4096 | In: $10.00, Out: $30.00 |
| gpt-4-turbo-2024-04-09 | openai | In: text, image, pdf; Out: text | streaming, function_calling | 128000 | 4096 | In: $10.00, Out: $30.00 |
| gpt-4-turbo-preview | openai | In: text, image, pdf; Out: text | streaming, function_calling | 128000 | 4096 | In: $10.00, Out: $30.00 |
| gpt-4.1 | openai | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 1047576 | 32768 | In: $2.00, Out: $8.00, Cache: $0.50 |
| gpt-4.1-2025-04-14 | openai | In: text, image, pdf; Out: text | streaming, function_calling, structured_output | 1047576 | 32768 | In: $2.00, Out: $8.00, Cache: $0.50 |
| gpt-4.1-mini-2025-04-14 | openai | In: text, image, pdf; Out: text | streaming, function_calling, structured_output | 1047576 | 32768 | In: $0.40, Out: $1.60, Cache: $0.10 |
| gpt-4.1-nano-2025-04-14 | openai | In: text, image, pdf; Out: text | streaming, function_calling, structured_output | 1047576 | 32768 | In: $0.10, Out: $0.40 |
| gpt-4.1-mini | openai | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 1047576 | 32768 | In: $0.40, Out: $1.60, Cache: $0.10 |
| gpt-4.1-nano | openai | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 1047576 | 32768 | In: $0.10, Out: $0.40, Cache: $0.03 |
| gpt-4o | openai | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 128000 | 16384 | In: $2.50, Out: $10.00, Cache: $1.25 |
| gpt-4o-2024-05-13 | openai | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 128000 | 4096 | In: $5.00, Out: $15.00 |
| gpt-4o-2024-08-06 | openai | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 128000 | 16384 | In: $2.50, Out: $10.00, Cache: $1.25 |
| gpt-4o-2024-11-20 | openai | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 128000 | 16384 | In: $2.50, Out: $10.00, Cache: $1.25 |
| gpt-4o-mini | openai | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 128000 | 16384 | In: $0.15, Out: $0.60, Cache: $0.08 |
| gpt-4o-mini-2024-07-18 | openai | In: text, image, pdf; Out: text | streaming, function_calling, structured_output | 128000 | 16384 | In: $0.15, Out: $0.60 |
| gpt-5 | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5-2025-08-07 | openai | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5-chat-latest | openai | In: text, image; Out: text | structured_output, reasoning, vision, streaming, function_calling | 400000 | 128000 | In: $1.25, Out: $10.00 |
| gpt-5-mini | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $0.25, Out: $2.00, Cache: $0.02 |
| gpt-5-mini-2025-08-07 | openai | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5-nano | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $0.05, Out: $0.40, Cache: $0.01 |
| gpt-5-nano-2025-08-07 | openai | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5-pro | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 272000 | In: $15.00, Out: $120.00 |
| gpt-5-pro-2025-10-06 | openai | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5-search-api | openai | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5-search-api-2025-10-14 | openai | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5-codex | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5.1 | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $1.25, Out: $10.00, Cache: $0.13 |
| gpt-5.1-2025-11-13 | openai | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5.1-chat-latest | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 128000 | 16384 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5.1-codex | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5.1-codex-max | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5.1-codex-mini | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $0.25, Out: $2.00, Cache: $0.02 |
| gpt-5.2 | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $1.75, Out: $14.00, Cache: $0.18 |
| gpt-5.2-2025-12-11 | openai | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5.2-chat-latest | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 128000 | 16384 | In: $1.75, Out: $14.00, Cache: $0.18 |
| gpt-5.2-codex | openai | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $1.75, Out: $14.00, Cache: $0.18 |
| gpt-5.2-pro | openai | In: text, image; Out: text | function_calling, reasoning, vision, streaming, structured_output | 400000 | 128000 | In: $21.00, Out: $168.00 |
| gpt-5.2-pro-2025-12-11 | openai | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5.3-codex | openai | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $1.75, Out: $14.00, Cache: $0.18 |
| gpt-5.3-codex-spark | openai | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 128000 | 32000 | In: $1.75, Out: $14.00, Cache: $0.18 |
| o1-2024-12-17 | openai | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 200000 | 100000 | In: $15.00, Out: $60.00 |
| o1-pro-2025-03-19 | openai | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 200000 | 100000 | In: $150.00, Out: $600.00 |
| o3-mini-2025-01-31 | openai | In: text; Out: text | streaming, function_calling, structured_output, reasoning | 200000 | 100000 | In: $1.10, Out: $4.40 |
| o1 | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 100000 | In: $15.00, Out: $60.00, Cache: $7.50 |
| o1-pro | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 100000 | In: $150.00, Out: $600.00 |
| o3 | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 100000 | In: $2.00, Out: $8.00, Cache: $0.50 |
| o3-deep-research | openai | In: text, image; Out: text | function_calling, reasoning, vision, streaming | 200000 | 100000 | In: $10.00, Out: $40.00, Cache: $2.50 |
| o3-mini | openai | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 200000 | 100000 | In: $1.10, Out: $4.40, Cache: $0.55 |
| o3-pro | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 100000 | In: $20.00, Out: $80.00 |
| o4-mini | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 100000 | In: $1.10, Out: $4.40, Cache: $0.28 |
| o4-mini-deep-research | openai | In: text, image; Out: text | function_calling, reasoning, vision, streaming | 200000 | 100000 | In: $2.00, Out: $8.00, Cache: $0.50 |
| ai21/jamba-large-1.7 | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 256000 | 4096 | In: $2.00, Out: $8.00 |
| allenai/olmo-3.1-32b-instruct | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 65536 | - | In: $0.20, Out: $0.60 |
| amazon/nova-2-lite-v1 | openrouter | In: text, image, video, file; Out: text | streaming, function_calling | 1000000 | 65535 | In: $0.30, Out: $2.50 |
| amazon/nova-lite-v1 | openrouter | In: text, image; Out: text | streaming, function_calling | 300000 | 5120 | In: $0.06, Out: $0.24 |
| amazon/nova-micro-v1 | openrouter | In: text; Out: text | streaming, function_calling | 128000 | 5120 | In: $0.04, Out: $0.14 |
| amazon/nova-premier-v1 | openrouter | In: text, image; Out: text | streaming, function_calling | 1000000 | 32000 | In: $2.50, Out: $12.50, Cache: $0.62 |
| amazon/nova-pro-v1 | openrouter | In: text, image; Out: text | streaming, function_calling | 300000 | 5120 | In: $0.80, Out: $3.20 |
| anthropic/claude-3-haiku | openrouter | In: text, image; Out: text | streaming, function_calling | 200000 | 4096 | In: $0.25, Out: $1.25, Cache: $0.03 |
| anthropic/claude-3.5-sonnet | openrouter | In: text, image, file; Out: text | streaming, function_calling | 200000 | 8192 | In: $6.00, Out: $30.00, Cache: $0.60 |
| anthropic/claude-3.7-sonnet:thinking | openrouter | In: text, image, file; Out: text | streaming, function_calling | 200000 | 64000 | In: $3.00, Out: $15.00, Cache: $0.30 |
| arcee-ai/trinity-mini | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 131072 | 131072 | In: $0.04, Out: $0.15 |
| arcee-ai/virtuoso-large | openrouter | In: text; Out: text | streaming, function_calling, predicted_outputs | 131072 | 64000 | In: $0.75, Out: $1.20 |
| openrouter/aurora-alpha | openrouter | In: text; Out: text | function_calling, structured_output, reasoning | 128000 | 50000 | - |
| openrouter/auto | openrouter | In: text, image, audio, file, video; Out: text, image | streaming, function_calling, structured_output, predicted_outputs | 2000000 | - | - |
| baidu/ernie-4.5-21b-a3b | openrouter | In: text; Out: text | streaming, function_calling | 120000 | 8000 | In: $0.07, Out: $0.28 |
| baidu/ernie-4.5-vl-28b-a3b | openrouter | In: text, image; Out: text | streaming, function_calling | 30000 | 8000 | In: $0.14, Out: $0.56 |
| bytedance-seed/seed-1.6 | openrouter | In: image, text, video; Out: text | streaming, function_calling, structured_output | 262144 | 32768 | In: $0.25, Out: $2.00 |
| bytedance-seed/seed-1.6-flash | openrouter | In: image, text, video; Out: text | streaming, function_calling, structured_output | 262144 | 32768 | In: $0.08, Out: $0.30 |
| anthropic/claude-3.5-haiku | openrouter | In: text, image, pdf; Out: text | function_calling, vision, streaming | 200000 | 8192 | In: $0.80, Out: $4.00, Cache: $0.08 |
| anthropic/claude-haiku-4.5 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 64000 | In: $1.00, Out: $5.00, Cache: $0.10 |
| anthropic/claude-opus-4 | openrouter | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 32000 | In: $15.00, Out: $75.00, Cache: $1.50 |
| anthropic/claude-opus-4.1 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 32000 | In: $15.00, Out: $75.00, Cache: $1.50 |
| anthropic/claude-opus-4.5 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 32000 | In: $5.00, Out: $25.00, Cache: $0.50 |
| anthropic/claude-opus-4.6 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache: $0.50 |
| anthropic/claude-3.7-sonnet | openrouter | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 128000 | In: $15.00, Out: $75.00, Cache: $1.50 |
| anthropic/claude-sonnet-4 | openrouter | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 64000 | In: $3.00, Out: $15.00, Cache: $0.30 |
| anthropic/claude-sonnet-4.5 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 64000 | In: $3.00, Out: $15.00, Cache: $0.30 |
| anthropic/claude-sonnet-4.6 | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 128000 | In: $3.00, Out: $15.00, Cache: $0.30 |
| mistralai/codestral-2508 | openrouter | In: text; Out: text | function_calling, structured_output, streaming | 256000 | 256000 | In: $0.30, Out: $0.90 |
| cohere/command-r-08-2024 | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 128000 | 4000 | In: $0.15, Out: $0.60 |
| cohere/command-r-plus-08-2024 | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 128000 | 4000 | In: $2.50, Out: $10.00 |
| nousresearch/deephermes-3-llama-3-8b-preview | openrouter | In: text; Out: text | function_calling, reasoning | 131072 | 8192 | - |
| deepseek/deepseek-chat-v3-0324 | openrouter | In: text; Out: text | structured_output, streaming, function_calling, predicted_outputs | 16384 | 8192 | In: $0.19, Out: $0.87, Cache: $0.10 |
| deepseek/deepseek-v3.1-terminus | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 131072 | 65536 | In: $0.27, Out: $1.00 |
| deepseek/deepseek-v3.1-terminus:exacto | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 131072 | 65536 | In: $0.27, Out: $1.00 |
| deepseek/deepseek-v3.2 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 163840 | 65536 | In: $0.28, Out: $0.40 |
| deepseek/deepseek-v3.2-speciale | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 163840 | 65536 | In: $0.27, Out: $0.41 |
| deepseek/deepseek-chat-v3.1 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 163840 | 163840 | In: $0.20, Out: $0.80 |
| deepseek/deepseek-chat | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 163840 | 163840 | In: $0.32, Out: $0.89 |
| deepseek/deepseek-v3.2-exp | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 163840 | 65536 | In: $0.27, Out: $0.41 |
| deepseek/deepseek-r1 | openrouter | In: text; Out: text | streaming, function_calling | 64000 | 16000 | In: $0.70, Out: $2.50 |
| deepseek/deepseek-r1-0528 | openrouter | In: text; Out: text | streaming, function_calling, structured_output, predicted_outputs | 163840 | 65536 | In: $0.40, Out: $1.75, Cache: $0.20 |
| deepseek/deepseek-r1-0528-qwen3-8b:free | openrouter | In: text; Out: text | function_calling, reasoning | 131072 | 131072 | - |
| mistralai/devstral-2512 | openrouter | In: text; Out: text | function_calling, structured_output, streaming | 262144 | 262144 | In: $0.15, Out: $0.60 |
| mistralai/devstral-2512:free | openrouter | In: text; Out: text | function_calling | 262144 | 262144 | - |
| mistralai/devstral-medium-2507 | openrouter | In: text; Out: text | function_calling, structured_output | 131072 | 131072 | In: $0.40, Out: $2.00 |
| mistralai/devstral-small-2505 | openrouter | In: text; Out: text | function_calling | 128000 | 128000 | In: $0.06, Out: $0.12 |
| mistralai/devstral-small-2507 | openrouter | In: text; Out: text | function_calling, structured_output | 131072 | 131072 | In: $0.10, Out: $0.30 |
| mistralai/devstral-small-2505:free | openrouter | In: text; Out: text | function_calling | 32768 | 32768 | - |
| cognitivecomputations/dolphin3.0-mistral-24b | openrouter | In: text; Out: text | function_calling | 32768 | 8192 | - |
| cognitivecomputations/dolphin3.0-r1-mistral-24b | openrouter | In: text; Out: text | function_calling, reasoning | 32768 | 8192 | - |
| openrouter/free | openrouter | In: text, image; Out: text | streaming, function_calling, structured_output | 200000 | - | - |
| z-ai/glm-4.5 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 128000 | 96000 | In: $0.60, Out: $2.20 |
| z-ai/glm-4.5-air | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 128000 | 96000 | In: $0.20, Out: $1.10 |
| z-ai/glm-4.5-air:free | openrouter | In: text; Out: text | reasoning, streaming, function_calling | 128000 | 96000 | - |
| z-ai/glm-4.5v | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, streaming | 64000 | 16384 | In: $0.60, Out: $1.80 |
| z-ai/glm-4.6 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 200000 | 128000 | In: $0.60, Out: $2.20, Cache: $0.11 |
| z-ai/glm-4.6:exacto | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 200000 | 128000 | In: $0.60, Out: $1.90, Cache: $0.11 |
| thudm/glm-z1-32b:free | openrouter | In: text; Out: text | function_calling, reasoning | 32768 | 32768 | - |
| z-ai/glm-4.7 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 204800 | 131072 | In: $0.60, Out: $2.20, Cache: $0.11 |
| z-ai/glm-4.7-flash | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 200000 | 65535 | In: $0.07, Out: $0.40 |
| z-ai/glm-5 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 202752 | 131000 | In: $1.00, Out: $3.20, Cache: $0.20 |
| openai/gpt-oss-120b | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 131072 | 32768 | In: $0.07, Out: $0.28 |
| openai/gpt-oss-120b:exacto | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 131072 | 32768 | In: $0.05, Out: $0.24 |
| openai/gpt-oss-20b | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 131072 | 32768 | In: $0.05, Out: $0.20 |
| openai/gpt-oss-safeguard-20b | openrouter | In: text; Out: text | function_calling, reasoning, streaming, structured_output | 131072 | 65536 | In: $0.08, Out: $0.30 |
| openai/gpt-4.1 | openrouter | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 1047576 | 32768 | In: $2.00, Out: $8.00, Cache: $0.50 |
| openai/gpt-4.1-mini | openrouter | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 1047576 | 32768 | In: $0.40, Out: $1.60, Cache: $0.10 |
| openai/gpt-4o-mini | openrouter | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 128000 | 16384 | In: $0.15, Out: $0.60, Cache: $0.08 |
| openai/gpt-5 | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $1.25, Out: $10.00 |
| openai/gpt-5-codex | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| openai/gpt-5-image | openrouter | In: text, image, pdf; Out: text, image | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $5.00, Out: $10.00, Cache: $1.25 |
| openai/gpt-5-mini | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $0.25, Out: $2.00 |
| openai/gpt-5-nano | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $0.05, Out: $0.40 |
| openai/gpt-5-pro | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 272000 | In: $15.00, Out: $120.00 |
| openai/gpt-5.1 | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| openai/gpt-5.1-chat | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 128000 | 16384 | In: $1.25, Out: $10.00, Cache: $0.12 |
| openai/gpt-5.1-codex | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| openai/gpt-5.1-codex-max | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $1.10, Out: $9.00, Cache: $0.11 |
| openai/gpt-5.1-codex-mini | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 100000 | In: $0.25, Out: $2.00, Cache: $0.02 |
| openai/gpt-5.2 | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $1.75, Out: $14.00, Cache: $0.18 |
| openai/gpt-5.2-chat | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 128000 | 16384 | In: $1.75, Out: $14.00, Cache: $0.18 |
| openai/gpt-5.2-pro | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $21.00, Out: $168.00 |
| openai/gpt-5.2-codex | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $1.75, Out: $14.00, Cache: $0.18 |
| google/gemini-2.0-flash-001 | openrouter | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, vision, streaming | 1048576 | 8192 | In: $0.10, Out: $0.40, Cache: $0.02 |
| google/gemini-2.0-flash-exp:free | openrouter | In: text, image; Out: text | function_calling, vision | 1048576 | 1048576 | - |
| google/gemini-2.5-flash | openrouter | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1048576 | 65536 | In: $0.30, Out: $2.50, Cache: $0.04 |
| google/gemini-2.5-flash-lite | openrouter | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1048576 | 65536 | In: $0.10, Out: $0.40, Cache: $0.02 |
| google/gemini-2.5-flash-lite-preview-09-2025 | openrouter | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1048576 | 65536 | In: $0.10, Out: $0.40, Cache: $0.02 |
| google/gemini-2.5-flash-preview-09-2025 | openrouter | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1048576 | 65536 | In: $0.30, Out: $2.50, Cache: $0.03 |
| google/gemini-2.5-pro | openrouter | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1048576 | 65536 | In: $1.25, Out: $10.00, Cache: $0.31 |
| google/gemini-2.5-pro-preview-05-06 | openrouter | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1048576 | 65536 | In: $1.25, Out: $10.00, Cache: $0.31 |
| google/gemini-2.5-pro-preview-06-05 | openrouter | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1048576 | 65536 | In: $1.25, Out: $10.00, Cache: $0.31 |
| google/gemini-3-flash-preview | openrouter | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1048576 | 65536 | In: $0.50, Out: $3.00, Cache: $0.05 |
| google/gemini-3-pro-preview | openrouter | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1050000 | 66000 | In: $2.00, Out: $12.00 |
| google/gemini-3.1-pro-preview | openrouter | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1048576 | 65536 | In: $2.00, Out: $12.00 |
| google/gemma-3-27b-it | openrouter | In: text, image; Out: text | function_calling, structured_output, vision, streaming, predicted_outputs | 96000 | 96000 | In: $0.04, Out: $0.15 |
| google/gemma-3-27b-it:free | openrouter | In: text, image; Out: text | function_calling, vision, streaming, structured_output | 131072 | 8192 | - |
| google/gemini-2.0-flash-lite-001 | openrouter | In: text, image, file, audio, video; Out: text | streaming, function_calling, structured_output | 1048576 | 8192 | In: $0.08, Out: $0.30 |
| google/gemini-2.5-pro-preview | openrouter | In: file, image, text, audio; Out: text | streaming, function_calling, structured_output | 1048576 | 65536 | In: $1.25, Out: $10.00, Cache: $0.12 |
| x-ai/grok-3 | openrouter | In: text; Out: text | function_calling, structured_output, streaming | 131072 | 8192 | In: $3.00, Out: $15.00, Cache: $0.75 |
| x-ai/grok-3-beta | openrouter | In: text; Out: text | function_calling, streaming, structured_output | 131072 | 8192 | In: $3.00, Out: $15.00, Cache: $0.75 |
| x-ai/grok-3-mini | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 131072 | 8192 | In: $0.30, Out: $0.50, Cache: $0.08 |
| x-ai/grok-3-mini-beta | openrouter | In: text; Out: text | function_calling, reasoning, streaming, structured_output | 131072 | 8192 | In: $0.30, Out: $0.50, Cache: $0.08 |
| x-ai/grok-4 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 256000 | 64000 | In: $3.00, Out: $15.00, Cache: $0.75 |
| x-ai/grok-4-fast | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 2000000 | 30000 | In: $0.20, Out: $0.50, Cache: $0.05 |
| x-ai/grok-4.1-fast | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 2000000 | 30000 | In: $0.20, Out: $0.50, Cache: $0.05 |
| x-ai/grok-code-fast-1 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 256000 | 10000 | In: $0.20, Out: $1.50, Cache: $0.02 |
| nousresearch/hermes-4-405b | openrouter | In: text; Out: text | function_calling, reasoning, streaming, structured_output | 131072 | 131072 | In: $1.00, Out: $3.00 |
| nousresearch/hermes-4-70b | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 131072 | 131072 | In: $0.13, Out: $0.40 |
| inception/mercury | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 128000 | 16384 | In: $0.25, Out: $1.00 |
| inception/mercury-coder | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 128000 | 16384 | In: $0.25, Out: $1.00 |
| prime-intellect/intellect-3 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 131072 | 8192 | In: $0.20, Out: $1.10 |
| kwaipilot/kat-coder-pro:free | openrouter | In: text; Out: text | function_calling, structured_output | 256000 | 65536 | - |
| moonshotai/kimi-dev-72b:free | openrouter | In: text; Out: text | function_calling | 131072 | 131072 | - |
| moonshotai/kimi-k2 | openrouter | In: text; Out: text | function_calling, streaming, structured_output | 131072 | 32768 | In: $0.55, Out: $2.20 |
| moonshotai/kimi-k2:free | openrouter | In: text; Out: text | function_calling | 32800 | 32800 | - |
| moonshotai/kimi-k2-0905 | openrouter | In: text; Out: text | function_calling, structured_output, streaming, predicted_outputs | 262144 | 16384 | In: $0.60, Out: $2.50 |
| moonshotai/kimi-k2-0905:exacto | openrouter | In: text; Out: text | function_calling, structured_output, streaming | 262144 | 16384 | In: $0.60, Out: $2.50 |
| moonshotai/kimi-k2-thinking | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 262144 | 262144 | In: $0.60, Out: $2.50, Cache: $0.15 |
| moonshotai/kimi-k2.5 | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, streaming, predicted_outputs | 262144 | 262144 | In: $0.60, Out: $3.00, Cache: $0.10 |
| kwaipilot/kat-coder-pro | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 256000 | 128000 | In: $0.21, Out: $0.83, Cache: $0.04 |
| meta-llama/llama-3.3-70b-instruct:free | openrouter | In: text; Out: text | function_calling, structured_output, streaming | 131072 | 131072 | - |
| meta-llama/llama-4-scout:free | openrouter | In: text, image; Out: text | function_calling, structured_output, vision | 64000 | 64000 | - |
| microsoft/mai-ds-r1:free | openrouter | In: text; Out: text | function_calling, reasoning | 163840 | 163840 | - |
| meta-llama/llama-3-8b-instruct | openrouter | In: text; Out: text | streaming, function_calling, structured_output, predicted_outputs | 8192 | 16384 | In: $0.03, Out: $0.04 |
| meta-llama/llama-3.1-405b-instruct | openrouter | In: text; Out: text | streaming, function_calling, structured_output, predicted_outputs | 131000 | - | In: $4.00, Out: $4.00 |
| meta-llama/llama-3.1-70b-instruct | openrouter | In: text; Out: text | streaming, function_calling, structured_output, predicted_outputs | 131072 | - | In: $0.40, Out: $0.40 |
| meta-llama/llama-3.1-8b-instruct | openrouter | In: text; Out: text | streaming, function_calling, structured_output, predicted_outputs | 16384 | 16384 | In: $0.02, Out: $0.05 |
| meta-llama/llama-3.3-70b-instruct | openrouter | In: text; Out: text | streaming, function_calling, structured_output, predicted_outputs | 131072 | 16384 | In: $0.10, Out: $0.32 |
| meta-llama/llama-4-maverick | openrouter | In: text, image; Out: text | streaming, function_calling, structured_output, predicted_outputs | 1048576 | 16384 | In: $0.15, Out: $0.60 |
| meta-llama/llama-4-scout | openrouter | In: text, image; Out: text | streaming, function_calling, structured_output | 327680 | 16384 | In: $0.08, Out: $0.30 |
| xiaomi/mimo-v2-flash | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 262144 | 65536 | In: $0.10, Out: $0.30, Cache: $0.01 |
| minimax/minimax-m1 | openrouter | In: text; Out: text | function_calling, reasoning, streaming | 1000000 | 40000 | In: $0.40, Out: $2.20 |
| minimax/minimax-m2 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 196600 | 118000 | In: $0.28, Out: $1.15, Cache: $0.28 |
| minimax/minimax-m2.1 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 204800 | 131072 | In: $0.30, Out: $1.20 |
| minimax/minimax-m2.5 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 204800 | 131072 | In: $0.30, Out: $1.20, Cache: $0.03 |
| minimax/minimax-01 | openrouter | In: text, image; Out: text | function_calling, reasoning, vision, streaming | 1000000 | 1000000 | In: $0.20, Out: $1.10 |
| mistralai/mistral-7b-instruct:free | openrouter | In: text; Out: text | function_calling | 32768 | 32768 | - |
| mistralai/mistral-large | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 128000 | - | In: $2.00, Out: $6.00 |
| mistralai/mistral-large-2407 | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 131072 | - | In: $2.00, Out: $6.00 |
| mistralai/mistral-large-2411 | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 131072 | - | In: $2.00, Out: $6.00 |
| mistralai/mistral-medium-3 | openrouter | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 131072 | 131072 | In: $0.40, Out: $2.00 |
| mistralai/mistral-medium-3.1 | openrouter | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 262144 | 262144 | In: $0.40, Out: $2.00 |
| mistralai/mistral-nemo:free | openrouter | In: text; Out: text | function_calling, structured_output | 131072 | 131072 | - |
| mistralai/mistral-small-3.1-24b-instruct | openrouter | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 128000 | 8192 | In: $0.35, Out: $0.56 |
| mistralai/mistral-small-3.2-24b-instruct:free | openrouter | In: text, image; Out: text | function_calling, structured_output, vision | 96000 | 96000 | - |
| mistralai/mistral-small-3.2-24b-instruct | openrouter | In: text, image; Out: text | function_calling, structured_output, vision, streaming, predicted_outputs | 96000 | 8192 | In: $0.06, Out: $0.18, Cache: $0.03 |
| mistralai/devstral-medium | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 131072 | - | In: $0.40, Out: $2.00 |
| mistralai/devstral-small | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 131072 | - | In: $0.10, Out: $0.30 |
| mistralai/ministral-14b-2512 | openrouter | In: text, image; Out: text | streaming, function_calling, structured_output, predicted_outputs | 262144 | - | In: $0.20, Out: $0.20 |
| mistralai/ministral-3b-2512 | openrouter | In: text, image; Out: text | streaming, function_calling, structured_output | 131072 | - | In: $0.10, Out: $0.10 |
| mistralai/ministral-8b-2512 | openrouter | In: text, image; Out: text | streaming, function_calling, structured_output | 262144 | - | In: $0.15, Out: $0.15 |
| mistralai/mistral-large-2512 | openrouter | In: text, image; Out: text | streaming, function_calling, structured_output | 262144 | - | In: $0.50, Out: $1.50 |
| mistralai/mistral-nemo | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 131072 | 16384 | In: $0.02, Out: $0.04 |
| mistralai/mistral-small-24b-instruct-2501 | openrouter | In: text; Out: text | streaming, function_calling, structured_output, predicted_outputs | 32768 | 16384 | In: $0.05, Out: $0.08 |
| mistralai/mistral-small-3.1-24b-instruct:free | openrouter | In: text, image; Out: text | streaming, function_calling, structured_output | 128000 | - | - |
| mistralai/mistral-small-creative | openrouter | In: text; Out: text | streaming, function_calling | 32768 | - | In: $0.10, Out: $0.30 |
| mistralai/mixtral-8x22b-instruct | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 65536 | - | In: $2.00, Out: $6.00 |
| mistralai/mixtral-8x7b-instruct | openrouter | In: text; Out: text | streaming, function_calling, structured_output, predicted_outputs | 32768 | 16384 | In: $0.54, Out: $0.54 |
| mistralai/pixtral-large-2411 | openrouter | In: text, image; Out: text | streaming, function_calling, structured_output | 131072 | - | In: $2.00, Out: $6.00 |
| mistralai/mistral-saba | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 32768 | - | In: $0.20, Out: $0.60 |
| mistralai/voxtral-small-24b-2507 | openrouter | In: text, audio; Out: text | streaming, function_calling, structured_output | 32000 | - | In: $0.10, Out: $0.30 |
| nvidia/llama-3.1-nemotron-70b-instruct | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 131072 | 16384 | In: $1.20, Out: $1.20 |
| nvidia/llama-3.3-nemotron-super-49b-v1.5 | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 131072 | - | In: $0.10, Out: $0.40 |
| nvidia/nemotron-3-nano-30b-a3b | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 262144 | - | In: $0.05, Out: $0.20 |
| nvidia/nemotron-3-nano-30b-a3b:free | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 256000 | 256000 | - |
| nvidia/nemotron-nano-12b-v2-vl:free | openrouter | In: text, image; Out: text | function_calling, reasoning, vision, streaming | 128000 | 128000 | - |
| nvidia/nemotron-nano-9b-v2:free | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 128000 | 128000 | - |
| nex-agi/deepseek-v3.1-nex-n1 | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 131072 | 163840 | In: $0.27, Out: $1.00 |
| openai/gpt-3.5-turbo | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 16385 | 4096 | In: $0.50, Out: $1.50 |
| openai/gpt-3.5-turbo-0613 | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 4095 | 4096 | In: $1.00, Out: $2.00 |
| openai/gpt-3.5-turbo-16k | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 16385 | 4096 | In: $3.00, Out: $4.00 |
| openai/gpt-4 | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 8191 | 4096 | In: $30.00, Out: $60.00 |
| openai/gpt-4-0314 | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 8191 | 4096 | In: $30.00, Out: $60.00 |
| openai/gpt-4-turbo | openrouter | In: text, image; Out: text | streaming, function_calling, structured_output | 128000 | 4096 | In: $10.00, Out: $30.00 |
| openai/gpt-4-1106-preview | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 128000 | 4096 | In: $10.00, Out: $30.00 |
| openai/gpt-4-turbo-preview | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 128000 | 4096 | In: $10.00, Out: $30.00 |
| openai/gpt-4.1-nano | openrouter | In: image, text, file; Out: text | streaming, function_calling, structured_output | 1047576 | 32768 | In: $0.10, Out: $0.40, Cache: $0.02 |
| openai/gpt-4o | openrouter | In: text, image, file; Out: text | streaming, function_calling, structured_output | 128000 | 16384 | In: $2.50, Out: $10.00, Cache: $1.25 |
| openai/gpt-4o-2024-05-13 | openrouter | In: text, image, file; Out: text | streaming, function_calling, structured_output | 128000 | 4096 | In: $5.00, Out: $15.00 |
| openai/gpt-4o-2024-08-06 | openrouter | In: text, image, file; Out: text | streaming, function_calling, structured_output | 128000 | 16384 | In: $2.50, Out: $10.00, Cache: $1.25 |
| openai/gpt-4o-2024-11-20 | openrouter | In: text, image, file; Out: text | streaming, function_calling, structured_output | 128000 | 16384 | In: $2.50, Out: $10.00, Cache: $1.25 |
| openai/gpt-4o:extended | openrouter | In: text, image, file; Out: text | streaming, function_calling, structured_output | 128000 | 64000 | In: $6.00, Out: $18.00 |
| openai/gpt-4o-audio-preview | openrouter | In: audio, text; Out: text, audio | streaming, function_calling, structured_output | 128000 | 16384 | In: $2.50, Out: $10.00 |
| openai/gpt-4o-mini-2024-07-18 | openrouter | In: text, image, file; Out: text | streaming, function_calling, structured_output | 128000 | 16384 | In: $0.15, Out: $0.60, Cache: $0.08 |
| openai/gpt-5-image-mini | openrouter | In: file, image, text; Out: image, text | streaming, function_calling, structured_output | 400000 | 128000 | In: $2.50, Out: $2.00, Cache: $0.25 |
| openai/gpt-5.3-codex | openrouter | In: text, image; Out: text | streaming, function_calling, structured_output | 400000 | 128000 | In: $1.75, Out: $14.00, Cache: $0.18 |
| openai/o1 | openrouter | In: text, image, file; Out: text | streaming, function_calling, structured_output | 200000 | 100000 | In: $15.00, Out: $60.00, Cache: $7.50 |
| openai/o3 | openrouter | In: image, text, file; Out: text | streaming, function_calling, structured_output | 200000 | 100000 | In: $2.00, Out: $8.00, Cache: $0.50 |
| openai/o3-deep-research | openrouter | In: image, text, file; Out: text | streaming, function_calling, structured_output | 200000 | 100000 | In: $10.00, Out: $40.00, Cache: $2.50 |
| openai/o3-mini | openrouter | In: text, file; Out: text | streaming, function_calling, structured_output | 200000 | 100000 | In: $1.10, Out: $4.40, Cache: $0.55 |
| openai/o3-mini-high | openrouter | In: text, file; Out: text | streaming, function_calling, structured_output | 200000 | 100000 | In: $1.10, Out: $4.40, Cache: $0.55 |
| openai/o3-pro | openrouter | In: text, file, image; Out: text | streaming, function_calling, structured_output | 200000 | 100000 | In: $20.00, Out: $80.00 |
| openai/o4-mini-deep-research | openrouter | In: file, image, text; Out: text | streaming, function_calling, structured_output | 200000 | 100000 | In: $2.00, Out: $8.00, Cache: $0.50 |
| openai/o4-mini-high | openrouter | In: image, text, file; Out: text | streaming, function_calling, structured_output | 200000 | 100000 | In: $1.10, Out: $4.40, Cache: $0.28 |
| qwen/qwq-32b:free | openrouter | In: text; Out: text | function_calling, structured_output, reasoning | 32768 | 32768 | - |
| qwen/qwen-2.5-72b-instruct | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 32768 | 16384 | In: $0.12, Out: $0.39 |
| qwen/qwen2.5-vl-32b-instruct:free | openrouter | In: text, image, video; Out: text | function_calling, structured_output, vision | 8192 | 8192 | - |
| qwen/qwen2.5-vl-72b-instruct:free | openrouter | In: text, image; Out: text | function_calling, vision | 32768 | 32768 | - |
| qwen/qwen-2.5-vl-7b-instruct:free | openrouter | In: text, image; Out: text | function_calling, vision | 32768 | 32768 | - |
| qwen/qwen3-14b:free | openrouter | In: text; Out: text | function_calling, structured_output, reasoning | 40960 | 40960 | - |
| qwen/qwen3-235b-a22b:free | openrouter | In: text; Out: text | function_calling, structured_output, reasoning | 131072 | 131072 | - |
| qwen/qwen3-235b-a22b-07-25 | openrouter | In: text; Out: text | function_calling, structured_output | 262144 | 131072 | In: $0.15, Out: $0.85 |
| qwen/qwen3-235b-a22b-07-25:free | openrouter | In: text; Out: text | function_calling | 262144 | 131072 | - |
| qwen/qwen3-235b-a22b-thinking-2507 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 262144 | 81920 | In: $0.08, Out: $0.31 |
| qwen/qwen3-30b-a3b:free | openrouter | In: text; Out: text | function_calling, structured_output, reasoning | 40960 | 40960 | - |
| qwen/qwen3-30b-a3b-instruct-2507 | openrouter | In: text; Out: text | function_calling, structured_output, streaming | 262000 | 262000 | In: $0.20, Out: $0.80 |
| qwen/qwen3-30b-a3b-thinking-2507 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 262000 | 262000 | In: $0.20, Out: $0.80 |
| qwen/qwen3-32b:free | openrouter | In: text; Out: text | function_calling, structured_output, reasoning | 40960 | 40960 | - |
| qwen/qwen3-4b:free | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 40960 | 40960 | - |
| qwen/qwen3-8b:free | openrouter | In: text; Out: text | function_calling, structured_output, reasoning | 40960 | 40960 | - |
| qwen/qwen3-coder | openrouter | In: text; Out: text | function_calling, structured_output, streaming, predicted_outputs | 262144 | 66536 | In: $0.30, Out: $1.20 |
| qwen/qwen3-coder:exacto | openrouter | In: text; Out: text | function_calling, structured_output, streaming | 131072 | 32768 | In: $0.38, Out: $1.53 |
| qwen/qwen3-coder-30b-a3b-instruct | openrouter | In: text; Out: text | function_calling, structured_output, streaming | 160000 | 65536 | In: $0.07, Out: $0.27 |
| qwen/qwen3-coder:free | openrouter | In: text; Out: text | function_calling, streaming | 262144 | 66536 | - |
| qwen/qwen3-coder-flash | openrouter | In: text; Out: text | function_calling, streaming, structured_output | 128000 | 66536 | In: $0.30, Out: $1.50 |
| qwen/qwen3-max | openrouter | In: text; Out: text | function_calling, reasoning, streaming, structured_output | 262144 | 32768 | In: $1.20, Out: $6.00 |
| qwen/qwen3-next-80b-a3b-instruct | openrouter | In: text; Out: text | function_calling, structured_output, streaming, predicted_outputs | 262144 | 262144 | In: $0.14, Out: $1.40 |
| qwen/qwen3-next-80b-a3b-instruct:free | openrouter | In: text; Out: text | function_calling, structured_output, streaming | 262144 | 262144 | - |
| qwen/qwen3-next-80b-a3b-thinking | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 262144 | 262144 | In: $0.14, Out: $1.40 |
| qwen/qwen3.5-397b-a17b | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, streaming, predicted_outputs | 262144 | 65536 | In: $0.60, Out: $3.60 |
| qwen/qwen3.5-plus-02-15 | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 65536 | In: $0.40, Out: $2.40 |
| qwen/qwq-32b | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 32768 | 32768 | In: $0.15, Out: $0.40 |
| qwen/qwen-plus-2025-07-28 | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 1000000 | 32768 | In: $0.40, Out: $1.20 |
| qwen/qwen-plus-2025-07-28:thinking | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 1000000 | 32768 | In: $0.40, Out: $1.20 |
| qwen/qwen-vl-max | openrouter | In: text, image; Out: text | streaming, function_calling, structured_output | 131072 | 32768 | In: $0.80, Out: $3.20 |
| qwen/qwen-max | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 32768 | 8192 | In: $1.60, Out: $6.40, Cache: $0.32 |
| qwen/qwen-plus | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 1000000 | 32768 | In: $0.40, Out: $1.20, Cache: $0.08 |
| qwen/qwen-turbo | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 131072 | 8192 | In: $0.05, Out: $0.20, Cache: $0.01 |
| qwen/qwen-2.5-7b-instruct | openrouter | In: text; Out: text | streaming, function_calling, predicted_outputs | 32768 | - | In: $0.04, Out: $0.10 |
| qwen/qwen3-14b | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 40960 | 40960 | In: $0.06, Out: $0.24 |
| qwen/qwen3-235b-a22b | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 131072 | 8192 | In: $0.46, Out: $1.82 |
| qwen/qwen3-235b-a22b-2507 | openrouter | In: text; Out: text | streaming, function_calling, structured_output, predicted_outputs | 262144 | - | In: $0.07, Out: $0.10 |
| qwen/qwen3-30b-a3b | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 40960 | 40960 | In: $0.08, Out: $0.28 |
| qwen/qwen3-32b | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 40960 | 40960 | In: $0.08, Out: $0.24, Cache: $0.04 |
| qwen/qwen3-8b | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 32000 | 8192 | In: $0.05, Out: $0.40, Cache: $0.05 |
| qwen/qwen3-coder-next | openrouter | In: text; Out: text | streaming, function_calling, structured_output, predicted_outputs | 262144 | 65536 | In: $0.12, Out: $0.75, Cache: $0.06 |
| qwen/qwen3-coder-plus | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 1000000 | 65536 | In: $1.00, Out: $5.00, Cache: $0.20 |
| qwen/qwen3-max-thinking | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 262144 | 32768 | In: $1.20, Out: $6.00 |
| qwen/qwen3-vl-235b-a22b-instruct | openrouter | In: text, image; Out: text | streaming, function_calling, structured_output, predicted_outputs | 262144 | - | In: $0.20, Out: $0.88, Cache: $0.11 |
| qwen/qwen3-vl-235b-a22b-thinking | openrouter | In: text, image; Out: text | streaming, function_calling, structured_output | 131072 | 32768 | - |
| qwen/qwen3-vl-30b-a3b-instruct | openrouter | In: text, image; Out: text | streaming, function_calling, structured_output | 131072 | 32768 | In: $0.13, Out: $0.52 |
| qwen/qwen3-vl-30b-a3b-thinking | openrouter | In: text, image; Out: text | streaming, function_calling, structured_output | 131072 | 32768 | - |
| qwen/qwen3-vl-32b-instruct | openrouter | In: text, image; Out: text | streaming, function_calling, structured_output, predicted_outputs | 131072 | 32768 | In: $0.10, Out: $0.42 |
| qwen/qwen3-vl-8b-instruct | openrouter | In: image, text; Out: text | streaming, function_calling, structured_output, predicted_outputs | 131072 | 32768 | In: $0.08, Out: $0.50 |
| qwen/qwen3-vl-8b-thinking | openrouter | In: image, text; Out: text | streaming, function_calling, structured_output | 131072 | 32768 | In: $0.12, Out: $1.36 |
| deepseek/deepseek-r1:free | openrouter | In: text; Out: text | function_calling, reasoning | 163840 | 163840 | - |
| tngtech/tng-r1t-chimera:free | openrouter | In: text; Out: text | function_calling, structured_output, reasoning | 163840 | 163840 | - |
| rekaai/reka-flash-3 | openrouter | In: text; Out: text | function_calling, reasoning | 32768 | 8192 | - |
| relace/relace-search | openrouter | In: text; Out: text | streaming, function_calling | 256000 | 128000 | In: $1.00, Out: $3.00 |
| sao10k/l3.1-euryale-70b | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 32768 | 32768 | In: $0.65, Out: $0.75 |
| sao10k/l3-euryale-70b | openrouter | In: text; Out: text | streaming, function_calling | 8192 | 8192 | In: $1.48, Out: $1.48 |
| sarvamai/sarvam-m:free | openrouter | In: text; Out: text | function_calling, reasoning | 32768 | 32768 | - |
| openrouter/sherlock-dash-alpha | openrouter | In: text, image; Out: text | function_calling, vision | 1840000 | 0 | - |
| openrouter/sherlock-think-alpha | openrouter | In: text, image; Out: text | function_calling, reasoning, vision | 1840000 | 0 | - |
| stepfun/step-3.5-flash | openrouter | In: text; Out: text | function_calling, reasoning, streaming | 256000 | 256000 | In: $0.10, Out: $0.30, Cache: $0.02 |
| stepfun/step-3.5-flash:free | openrouter | In: text; Out: text | function_calling, reasoning, streaming | 256000 | 256000 | - |
| tngtech/deepseek-r1t2-chimera | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 163840 | 163840 | In: $0.25, Out: $0.85, Cache: $0.12 |
| thedrummer/rocinante-12b | openrouter | In: text; Out: text | streaming, function_calling, structured_output, predicted_outputs | 32768 | 32768 | In: $0.17, Out: $0.43 |
| thedrummer/unslopnemo-12b | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 32768 | 32768 | In: $0.40, Out: $0.40 |
| alibaba/tongyi-deepresearch-30b-a3b | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 131072 | 131072 | In: $0.09, Out: $0.45, Cache: $0.09 |
| arcee-ai/trinity-large-preview:free | openrouter | In: text; Out: text | function_calling, structured_output, streaming | 131072 | 131072 | - |
| arcee-ai/trinity-mini:free | openrouter | In: text; Out: text | function_calling, structured_output, streaming | 131072 | 131072 | - |
| upstage/solar-pro-3:free | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 128000 | - | - |
| z-ai/glm-4-32b | openrouter | In: text; Out: text | streaming, function_calling | 128000 | - | In: $0.10, Out: $0.10 |
| z-ai/glm-4.6v | openrouter | In: image, text, video; Out: text | streaming, function_calling, structured_output | 131072 | 131072 | In: $0.30, Out: $0.90 |
| openai/gpt-oss-120b:free | openrouter | In: text; Out: text | function_calling, reasoning, streaming | 131072 | 32768 | - |
| openai/gpt-oss-20b:free | openrouter | In: text; Out: text | function_calling, reasoning, streaming | 131072 | 32768 | - |
| nvidia/nemotron-nano-9b-v2 | openrouter | In: text; Out: text | function_calling, reasoning, streaming, structured_output, predicted_outputs | 131072 | 131072 | In: $0.04, Out: $0.16 |
| openai/o4-mini | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 100000 | In: $1.10, Out: $4.40, Cache: $0.28 |
| deepseek-ai/deepseek-v3.1-maas | vertexai | In: text, pdf; Out: text | function_calling, structured_output, reasoning, vision | 163840 | 32768 | In: $0.60, Out: $1.70 |
| zai-org/glm-4.7-maas | vertexai | In: text, pdf; Out: text | function_calling, structured_output, reasoning, vision | 200000 | 128000 | In: $0.60, Out: $2.20 |
| zai-org/glm-5-maas | vertexai | In: text; Out: text | function_calling, reasoning | 204800 | 131072 | In: $1.00, Out: $3.20, Cache: $0.10 |
| openai/gpt-oss-120b-maas | vertexai | In: text; Out: text | function_calling, reasoning | 131072 | 32768 | In: $0.09, Out: $0.36 |
| openai/gpt-oss-20b-maas | vertexai | In: text; Out: text | function_calling, reasoning | 131072 | 32768 | In: $0.07, Out: $0.25 |
| gemini-1.5-flash | vertexai | In: text, image, audio, video; Out: text | function_calling, vision, streaming | 1000000 | 8192 | In: $0.08, Out: $0.30, Cache: $0.02 |
| gemini-1.5-flash-8b | vertexai | In: text, image, audio, video; Out: text | function_calling, vision, streaming | 1000000 | 8192 | In: $0.04, Out: $0.15, Cache: $0.01 |
| gemini-1.5-pro | vertexai | In: text, image, audio, video; Out: text | function_calling, vision, streaming | 1000000 | 8192 | In: $1.25, Out: $5.00, Cache: $0.31 |
| gemini-2.0-flash | vertexai | In: text, image, audio, video, pdf; Out: text | function_calling, vision, streaming | 1048576 | 8192 | In: $0.15, Out: $0.60, Cache: $0.02 |
| gemini-2.0-flash-lite | vertexai | In: text, image, audio, video, pdf; Out: text | function_calling, vision | 1048576 | 8192 | In: $0.08, Out: $0.30 |
| gemini-2.5-flash | vertexai | In: text, image, audio, video, pdf; Out: text | function_calling, reasoning, vision, streaming | 1048576 | 65536 | In: $0.30, Out: $2.50, Cache: $0.08 |
| gemini-2.5-flash-lite | vertexai | In: text, image, audio, video, pdf; Out: text | function_calling, reasoning, vision, streaming | 1048576 | 65536 | In: $0.10, Out: $0.40, Cache: $0.02 |
| gemini-2.5-flash-lite-preview-06-17 | vertexai | In: text, image, audio, video, pdf; Out: text | function_calling, reasoning, vision | 65536 | 65536 | In: $0.10, Out: $0.40, Cache: $0.02 |
| gemini-2.5-flash-lite-preview-09-2025 | vertexai | In: text, image, audio, video, pdf; Out: text | function_calling, reasoning, vision | 1048576 | 65536 | In: $0.10, Out: $0.40, Cache: $0.02 |
| gemini-2.5-flash-preview-04-17 | vertexai | In: text, image, audio, video, pdf; Out: text | function_calling, reasoning, vision, streaming | 1048576 | 65536 | In: $0.15, Out: $0.60, Cache: $0.04 |
| gemini-2.5-flash-preview-05-20 | vertexai | In: text, image, audio, video, pdf; Out: text | function_calling, reasoning, vision | 1048576 | 65536 | In: $0.15, Out: $0.60, Cache: $0.04 |
| gemini-2.5-flash-preview-09-2025 | vertexai | In: text, image, audio, video, pdf; Out: text | function_calling, reasoning, vision | 1048576 | 65536 | In: $0.30, Out: $2.50, Cache: $0.08 |
| gemini-2.5-pro | vertexai | In: text, image, audio, video, pdf; Out: text | function_calling, reasoning, vision, streaming | 1048576 | 65536 | In: $1.25, Out: $10.00, Cache: $0.31 |
| gemini-2.5-pro-preview-05-06 | vertexai | In: text, image, audio, video, pdf; Out: text | function_calling, reasoning, vision | 1048576 | 65536 | In: $1.25, Out: $10.00, Cache: $0.31 |
| gemini-2.5-pro-preview-06-05 | vertexai | In: text, image, audio, video, pdf; Out: text | function_calling, reasoning, vision | 1048576 | 65536 | In: $1.25, Out: $10.00, Cache: $0.31 |
| gemini-3-flash-preview | vertexai | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1048576 | 65536 | In: $0.50, Out: $3.00, Cache: $0.05 |
| gemini-3-pro-preview | vertexai | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1048576 | 65536 | In: $2.00, Out: $12.00, Cache: $0.20 |
| gemini-3.1-pro-preview | vertexai | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1048576 | 65536 | In: $2.00, Out: $12.00, Cache: $0.20 |
| gemini-3.1-pro-preview-customtools | vertexai | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1048576 | 65536 | In: $2.00, Out: $12.00, Cache: $0.20 |
| gemini-embedding-001 | vertexai | In: text; Out: embeddings | streaming, function_calling | 2048 | 3072 | In: $0.15 |
| gemini-flash-latest | vertexai | In: text, image, audio, video, pdf; Out: text | function_calling, reasoning, vision | 1048576 | 65536 | In: $0.30, Out: $2.50, Cache: $0.08 |
| gemini-flash-lite-latest | vertexai | In: text, image, audio, video, pdf; Out: text | function_calling, reasoning, vision | 1048576 | 65536 | In: $0.10, Out: $0.40, Cache: $0.02 |
| meta/llama-3.3-70b-instruct-maas | vertexai | In: text; Out: text | function_calling, structured_output | 128000 | 8192 | In: $0.72, Out: $0.72 |
| meta/llama-4-maverick-17b-128e-instruct-maas | vertexai | In: text, image; Out: text | function_calling, structured_output, vision | 524288 | 8192 | In: $0.35, Out: $1.15 |
| qwen/qwen3-235b-a22b-instruct-2507-maas | vertexai | In: text; Out: text | function_calling, structured_output, reasoning | 262144 | 16384 | In: $0.22, Out: $0.88 |
| gemini-1.5-flash-002 | vertexai | In: -; Out: - | streaming, function_calling | - | - | - |
| gemini-1.5-pro-002 | vertexai | In: -; Out: - | streaming, function_calling | - | - | - |
| gemini-2.0-flash-001 | vertexai | In: -; Out: - | streaming, function_calling | - | - | - |
| gemini-2.0-flash-exp | vertexai | In: -; Out: - | streaming, function_calling | - | - | - |
| gemini-2.0-flash-lite-001 | vertexai | In: -; Out: - | streaming, function_calling | - | - | - |
| gemini-2.0-flash-preview-image-generation | vertexai | In: -; Out: - | streaming, function_calling | - | - | - |
| gemini-2.5-pro-exp-03-25 | vertexai | In: -; Out: - | streaming, function_calling | - | - | - |
| gemini-exp-1121 | vertexai | In: -; Out: - | streaming, function_calling | - | - | - |
| gemini-exp-1206 | vertexai | In: -; Out: - | streaming, function_calling | - | - | - |
| gemini-pro | vertexai | In: -; Out: - | streaming, function_calling | - | - | - |
| gemini-pro-vision | vertexai | In: -; Out: - | streaming, function_calling | - | - | - |
| text-embedding-004 | vertexai | In: -; Out: - | streaming, function_calling | - | - | - |
| text-embedding-005 | vertexai | In: -; Out: - | streaming, function_calling | - | - | - |
| text-multilingual-embedding-002 | vertexai | In: -; Out: - | streaming, function_calling | - | - | - |
| grok-2-vision-1212 | xai | In: text, image; Out: text | streaming, function_calling, structured_output, vision | - | - | - |
| grok-3 | xai | In: text; Out: text | streaming, function_calling, structured_output | - | - | - |
| grok-3-mini | xai | In: text; Out: text | streaming, function_calling, structured_output, reasoning | - | - | - |
| grok-4-0709 | xai | In: text, image; Out: text | streaming, function_calling, structured_output, reasoning, vision | - | - | - |
| grok-4-1-fast-non-reasoning | xai | In: text, image; Out: text | streaming, function_calling, structured_output, vision | - | - | - |
| grok-4-1-fast-reasoning | xai | In: text, image; Out: text | streaming, function_calling, structured_output, reasoning, vision | - | - | - |
| grok-4-fast-non-reasoning | xai | In: text, image; Out: text | streaming, function_calling, structured_output, vision | - | - | - |
| grok-4-fast-reasoning | xai | In: text, image; Out: text | streaming, function_calling, structured_output, reasoning, vision | - | - | - |
| grok-code-fast-1 | xai | In: text; Out: text | streaming, function_calling, structured_output, reasoning | - | - | - |
| grok-imagine-image | xai | In: text; Out: text | streaming, function_calling, structured_output | - | - | - |
| grok-imagine-image-pro | xai | In: text; Out: text | streaming, function_calling, structured_output | - | - | - |
| grok-imagine-video | xai | In: text; Out: text | streaming, function_calling, structured_output | - | - | - |


### Structured Output (450)

| Model | Provider | I/O | Capabilities | Context | Max Output | Standard Pricing (per 1M tokens) |
| :-- | :-- | :-- | :-- | --: | --: | :-- |
| gpt-4.1 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output | 1047576 | 32768 | In: $2.00, Out: $8.00, Cache: $0.50 |
| gpt-4.1-2025-04-14 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output | 1047576 | 32768 | In: $2.00, Out: $8.00, Cache: $0.50 |
| gpt-4.1-2025-04-14-text | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output | 1047576 | 32768 | In: $2.00, Out: $8.00, Cache: $0.50 |
| gpt-4.1-mini | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output | 1047576 | 32768 | In: $0.40, Out: $1.60, Cache: $0.10 |
| gpt-4.1-mini-2025-04-14 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output | 1047576 | 32768 | In: $0.40, Out: $1.60, Cache: $0.10 |
| gpt-4.1-nano | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output | 1047576 | 32768 | In: $0.10, Out: $0.40 |
| gpt-4.1-nano-2025-04-14 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output | 1047576 | 32768 | In: $0.10, Out: $0.40 |
| gpt-4o | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output | 128000 | 16384 | In: $2.50, Out: $10.00 |
| gpt-4o-2024-05-13 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output | 128000 | 16384 | In: $2.50, Out: $10.00 |
| gpt-4o-2024-08-06 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output | 128000 | 16384 | In: $2.50, Out: $10.00 |
| gpt-4o-2024-11-20 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output | 128000 | 16384 | In: $2.50, Out: $10.00 |
| gpt-4o-canvas-2024-09-25 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output | 128000 | 16384 | In: $2.50, Out: $10.00 |
| gpt-4o-mini | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output | 128000 | 16384 | In: $0.15, Out: $0.60 |
| gpt-4o-mini-2024-07-18 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output | 128000 | 16384 | In: $0.15, Out: $0.60 |
| gpt-5-chat-2025-08-07 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5-chat-2025-08-15 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5-chat-2025-10-03 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5-codex-2025-09-15 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5-mini-2025-08-07 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5-mini-lite-2025-08-07 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5-nano-2025-08-07 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5.1-chat-2025-11-13 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5.1-codex-mini-2025-11-13 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5.2-chat-2025-12-11 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5.2-chat-2026-02-10 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5.3-codex-2026-02-20 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| o1-2024-12-17 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 200000 | 100000 | In: $15.00, Out: $60.00 |
| o1-pro | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 200000 | 100000 | In: $150.00, Out: $600.00 |
| o1-pro-2025-03-19 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 200000 | 100000 | In: $150.00, Out: $600.00 |
| o3-mini | azure | In: text; Out: text | streaming, function_calling, structured_output, reasoning | 200000 | 100000 | In: $1.10, Out: $4.40 |
| o3-mini-2025-01-31 | azure | In: text; Out: text | streaming, function_calling, structured_output, reasoning | 200000 | 100000 | In: $1.10, Out: $4.40 |
| o3-mini-alpha | azure | In: text; Out: text | streaming, function_calling, structured_output, reasoning | 200000 | 100000 | In: $1.10, Out: $4.40 |
| o3-mini-alpha-2024-12-17 | azure | In: text; Out: text | streaming, function_calling, structured_output, reasoning | 200000 | 100000 | In: $1.10, Out: $4.40 |
| mistral.mistral-7b-instruct-v0:2 | bedrock | In: text; Out: text | function_calling, structured_output, streaming | 127000 | 127000 | In: $0.11, Out: $0.11 |
| mistral.mixtral-8x7b-instruct-v0:1 | bedrock | In: text; Out: text | structured_output, streaming, function_calling | 32000 | 32000 | In: $0.70, Out: $0.70 |
| qwen.qwen3-next-80b-a3b | bedrock | In: text; Out: text | function_calling, structured_output, streaming | 262000 | 262000 | In: $0.14, Out: $1.40 |
| qwen.qwen3-vl-235b-a22b | bedrock | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 262000 | 262000 | In: $0.30, Out: $1.50 |
| deep-research-pro-preview-12-2025 | gemini | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, caching | 131072 | 65536 | In: $0.08, Out: $0.30 |
| gemini-2.0-flash | gemini | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, vision, streaming, batch, caching | 1048576 | 8192 | In: $0.10, Out: $0.40, Cache: $0.02 |
| gemini-2.0-flash-001 | gemini | In: text, image, pdf, video; Out: text | streaming, function_calling, structured_output, batch, caching | 1048576 | 8192 | In: $0.10, Out: $0.40 |
| gemini-2.0-flash-lite | gemini | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, vision, streaming, batch | 1048576 | 8192 | In: $0.08, Out: $0.30 |
| gemini-2.5-computer-use-preview-10-2025 | gemini | In: text, image, pdf, video; Out: text | streaming, function_calling, structured_output, caching | 131072 | 65536 | In: $0.08, Out: $0.30 |
| gemini-2.5-flash | gemini | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming, batch, caching | 1048576 | 65536 | In: $0.30, Out: $2.50, Cache: $0.08 |
| gemini-2.5-flash-image | gemini | In: text, image; Out: text, image | reasoning, vision, streaming, function_calling, structured_output, batch, caching | 32768 | 32768 | In: $0.30, Out: $30.00, Cache: $0.08 |
| gemini-2.5-flash-lite | gemini | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming, batch | 1048576 | 65536 | In: $0.10, Out: $0.40, Cache: $0.02 |
| gemini-2.5-flash-lite-preview-09-2025 | gemini | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming, batch | 1048576 | 65536 | In: $0.10, Out: $0.40, Cache: $0.02 |
| gemini-2.5-flash-native-audio-latest | gemini | In: text, image, pdf, video, audio; Out: text | streaming, function_calling, structured_output, batch, caching | 131072 | 8192 | In: $0.08, Out: $0.30 |
| gemini-2.5-flash-native-audio-preview-09-2025 | gemini | In: text, image, pdf, video, audio; Out: text | streaming, function_calling, structured_output, batch, caching | 131072 | 8192 | In: $0.08, Out: $0.30 |
| gemini-2.5-flash-native-audio-preview-12-2025 | gemini | In: text, image, pdf, video, audio; Out: text | streaming, function_calling, structured_output, batch, caching | 131072 | 8192 | In: $0.08, Out: $0.30 |
| gemini-2.5-flash-preview-05-20 | gemini | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1048576 | 65536 | In: $0.15, Out: $0.60, Cache: $0.04 |
| gemini-2.5-flash-preview-09-2025 | gemini | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1048576 | 65536 | In: $0.30, Out: $2.50, Cache: $0.08 |
| gemini-2.5-flash-preview-tts | gemini | In: text; Out: audio | streaming, function_calling, structured_output, batch, caching | 8000 | 16000 | In: $0.50, Out: $10.00 |
| gemini-2.5-pro | gemini | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming, caching | 1048576 | 65536 | In: $1.25, Out: $10.00, Cache: $0.31 |
| gemini-2.5-pro-preview-05-06 | gemini | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1048576 | 65536 | In: $1.25, Out: $10.00, Cache: $0.31 |
| gemini-2.5-pro-preview-06-05 | gemini | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1048576 | 65536 | In: $1.25, Out: $10.00, Cache: $0.31 |
| gemini-2.5-pro-preview-tts | gemini | In: text; Out: audio | streaming, function_calling, structured_output, caching | 8000 | 16000 | In: $1.00, Out: $20.00 |
| gemini-3-flash-preview | gemini | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming, batch, caching | 1048576 | 65536 | In: $0.50, Out: $3.00, Cache: $0.05 |
| gemini-3-pro-preview | gemini | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming, caching | 1000000 | 64000 | In: $2.00, Out: $12.00, Cache: $0.20 |
| gemini-3.1-pro-preview | gemini | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming, caching | 1048576 | 65536 | In: $2.00, Out: $12.00, Cache: $0.20 |
| gemini-3.1-pro-preview-customtools | gemini | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming, caching | 1048576 | 65536 | In: $2.00, Out: $12.00, Cache: $0.20 |
| gemini-flash-latest | gemini | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming, batch, caching | 1048576 | 65536 | In: $0.30, Out: $2.50, Cache: $0.08 |
| gemini-flash-lite-latest | gemini | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming, batch | 1048576 | 65536 | In: $0.10, Out: $0.40, Cache: $0.02 |
| gemini-pro-latest | gemini | In: text, image, pdf, video; Out: text | streaming, function_calling, structured_output, caching | 1048576 | 65536 | In: $0.08, Out: $0.30 |
| gemini-robotics-er-1.5-preview | gemini | In: text, image, pdf, video; Out: text | streaming, function_calling, structured_output, caching | 1048576 | 65536 | In: $0.08, Out: $0.30 |
| gemini-3-pro-image-preview | gemini | In: text, image, pdf, video; Out: text | streaming, function_calling, structured_output, caching | 131072 | 32768 | In: $0.08, Out: $0.30 |
| nano-banana-pro-preview | gemini | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, caching | 131072 | 32768 | In: $0.08, Out: $0.30 |
| codestral-latest | mistral | In: text; Out: text | function_calling, streaming, structured_output, batch, predicted_outputs | 256000 | 4096 | In: $0.30, Out: $0.90 |
| codestral-2508 | mistral | In: text; Out: text | streaming, function_calling, structured_output, batch, predicted_outputs | 32768 | 8192 | - |
| devstral-medium-latest | mistral | In: text; Out: text | function_calling, streaming, structured_output, batch, fine_tuning | 262144 | 262144 | In: $0.40, Out: $2.00 |
| devstral-2512 | mistral | In: text; Out: text | function_calling, streaming, structured_output, batch, fine_tuning | 262144 | 262144 | In: $0.40, Out: $2.00 |
| devstral-latest | mistral | In: text; Out: text | streaming, function_calling, structured_output, batch, fine_tuning | 32768 | 8192 | - |
| devstral-medium-2507 | mistral | In: text; Out: text | function_calling, streaming, structured_output, batch, fine_tuning | 128000 | 128000 | In: $0.40, Out: $2.00 |
| devstral-small-2507 | mistral | In: text; Out: text | function_calling, streaming, structured_output, batch, fine_tuning | 128000 | 128000 | In: $0.10, Out: $0.30 |
| labs-devstral-small-2512 | mistral | In: text, image; Out: text | function_calling, vision, streaming, structured_output, batch, fine_tuning | 256000 | 256000 | - |
| devstral-small-latest | mistral | In: text; Out: text | streaming, function_calling, structured_output, batch, fine_tuning | 32768 | 8192 | - |
| magistral-medium-latest | mistral | In: text; Out: text | function_calling, reasoning, streaming, structured_output, batch | 128000 | 16384 | In: $2.00, Out: $5.00 |
| magistral-medium-2509 | mistral | In: text; Out: text | streaming, function_calling, structured_output, reasoning, batch | 32768 | 8192 | - |
| magistral-small-2509 | mistral | In: text; Out: text | streaming, function_calling, structured_output, reasoning, batch | 32768 | 8192 | - |
| magistral-small-latest | mistral | In: text; Out: text | streaming, function_calling, structured_output, reasoning, batch | 32768 | 8192 | - |
| ministral-14b-2512 | mistral | In: text; Out: text | streaming, function_calling, structured_output, batch, distillation | 32768 | 8192 | - |
| ministral-14b-latest | mistral | In: text; Out: text | streaming, function_calling, structured_output, batch, distillation | 32768 | 8192 | - |
| ministral-3b-2512 | mistral | In: text; Out: text | streaming, function_calling, structured_output, batch, distillation | 32768 | 8192 | - |
| ministral-3b-latest | mistral | In: text; Out: text | function_calling, streaming, structured_output, batch, distillation | 128000 | 128000 | In: $0.04, Out: $0.04 |
| ministral-8b-latest | mistral | In: text; Out: text | function_calling, streaming, structured_output, batch, distillation | 128000 | 128000 | In: $0.10, Out: $0.10 |
| ministral-8b-2512 | mistral | In: text; Out: text | streaming, function_calling, structured_output, batch, distillation | 32768 | 8192 | - |
| mistral-large-pixtral-2411 | mistral | In: text, image; Out: text | streaming, function_calling, structured_output, vision, batch, fine_tuning | 32768 | 8192 | - |
| mistral-large-latest | mistral | In: text, image; Out: text | function_calling, vision, streaming, structured_output, batch, fine_tuning | 262144 | 262144 | In: $0.50, Out: $1.50 |
| mistral-large-2411 | mistral | In: text; Out: text | function_calling, streaming, structured_output, batch, fine_tuning | 131072 | 16384 | In: $2.00, Out: $6.00 |
| mistral-large-2512 | mistral | In: text, image; Out: text | function_calling, vision, streaming, structured_output, batch, fine_tuning | 262144 | 262144 | In: $0.50, Out: $1.50 |
| mistral-medium-latest | mistral | In: text, image; Out: text | function_calling, vision, streaming, structured_output, batch, fine_tuning | 128000 | 16384 | In: $0.40, Out: $2.00 |
| mistral-medium | mistral | In: text; Out: text | streaming, function_calling, structured_output, vision, batch, fine_tuning | 32768 | 8192 | - |
| mistral-medium-2505 | mistral | In: text, image; Out: text | function_calling, vision, streaming, structured_output, batch, fine_tuning | 131072 | 131072 | In: $0.40, Out: $2.00 |
| mistral-medium-2508 | mistral | In: text, image; Out: text | function_calling, vision, streaming, structured_output, batch, fine_tuning | 262144 | 262144 | In: $0.40, Out: $2.00 |
| mistral-small-2501 | mistral | In: text; Out: text | streaming, function_calling, structured_output, batch, fine_tuning | 32768 | 8192 | - |
| mistral-small-latest | mistral | In: text, image; Out: text | function_calling, vision, streaming, structured_output, batch, fine_tuning | 128000 | 16384 | In: $0.10, Out: $0.30 |
| labs-mistral-small-creative | mistral | In: text; Out: text | streaming, function_calling, structured_output, batch, fine_tuning | 32768 | 8192 | - |
| mistral-small-2506 | mistral | In: text, image; Out: text | function_calling, vision, streaming, structured_output, batch, fine_tuning | 128000 | 16384 | In: $0.10, Out: $0.30 |
| mistral-tiny-2407 | mistral | In: text; Out: text | streaming, function_calling, structured_output, batch | 32768 | 8192 | - |
| mistral-tiny-latest | mistral | In: text; Out: text | streaming, function_calling, structured_output, batch | 32768 | 8192 | - |
| mistral-vibe-cli-latest | mistral | In: text; Out: text | streaming, function_calling, structured_output, batch | 32768 | 8192 | - |
| mistral-vibe-cli-with-tools | mistral | In: text; Out: text | streaming, function_calling, structured_output, batch | 32768 | 8192 | - |
| open-mistral-nemo | mistral | In: text; Out: text | streaming, function_calling, structured_output, batch | 32768 | 8192 | - |
| open-mistral-nemo-2407 | mistral | In: text; Out: text | streaming, function_calling, structured_output, batch | 32768 | 8192 | - |
| pixtral-large-2411 | mistral | In: text, image; Out: text | streaming, function_calling, structured_output, vision, batch | 32768 | 8192 | - |
| pixtral-large-latest | mistral | In: text, image; Out: text | function_calling, vision, streaming, structured_output, batch | 128000 | 128000 | In: $2.00, Out: $6.00 |
| gpt-4.1 | openai | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 1047576 | 32768 | In: $2.00, Out: $8.00, Cache: $0.50 |
| gpt-4.1-2025-04-14 | openai | In: text, image, pdf; Out: text | streaming, function_calling, structured_output | 1047576 | 32768 | In: $2.00, Out: $8.00, Cache: $0.50 |
| gpt-4.1-mini-2025-04-14 | openai | In: text, image, pdf; Out: text | streaming, function_calling, structured_output | 1047576 | 32768 | In: $0.40, Out: $1.60, Cache: $0.10 |
| gpt-4.1-nano-2025-04-14 | openai | In: text, image, pdf; Out: text | streaming, function_calling, structured_output | 1047576 | 32768 | In: $0.10, Out: $0.40 |
| gpt-4.1-mini | openai | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 1047576 | 32768 | In: $0.40, Out: $1.60, Cache: $0.10 |
| gpt-4.1-nano | openai | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 1047576 | 32768 | In: $0.10, Out: $0.40, Cache: $0.03 |
| gpt-4o | openai | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 128000 | 16384 | In: $2.50, Out: $10.00, Cache: $1.25 |
| gpt-4o-2024-05-13 | openai | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 128000 | 4096 | In: $5.00, Out: $15.00 |
| gpt-4o-2024-08-06 | openai | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 128000 | 16384 | In: $2.50, Out: $10.00, Cache: $1.25 |
| gpt-4o-2024-11-20 | openai | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 128000 | 16384 | In: $2.50, Out: $10.00, Cache: $1.25 |
| gpt-4o-mini | openai | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 128000 | 16384 | In: $0.15, Out: $0.60, Cache: $0.08 |
| gpt-4o-mini-2024-07-18 | openai | In: text, image, pdf; Out: text | streaming, function_calling, structured_output | 128000 | 16384 | In: $0.15, Out: $0.60 |
| gpt-5 | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5-2025-08-07 | openai | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5-chat-latest | openai | In: text, image; Out: text | structured_output, reasoning, vision, streaming, function_calling | 400000 | 128000 | In: $1.25, Out: $10.00 |
| gpt-5-mini | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $0.25, Out: $2.00, Cache: $0.02 |
| gpt-5-mini-2025-08-07 | openai | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5-nano | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $0.05, Out: $0.40, Cache: $0.01 |
| gpt-5-nano-2025-08-07 | openai | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5-pro | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 272000 | In: $15.00, Out: $120.00 |
| gpt-5-pro-2025-10-06 | openai | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5-search-api | openai | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5-search-api-2025-10-14 | openai | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5-codex | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5.1 | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $1.25, Out: $10.00, Cache: $0.13 |
| gpt-5.1-2025-11-13 | openai | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5.1-chat-latest | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 128000 | 16384 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5.1-codex | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5.1-codex-max | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5.1-codex-mini | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $0.25, Out: $2.00, Cache: $0.02 |
| gpt-5.2 | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $1.75, Out: $14.00, Cache: $0.18 |
| gpt-5.2-2025-12-11 | openai | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5.2-chat-latest | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 128000 | 16384 | In: $1.75, Out: $14.00, Cache: $0.18 |
| gpt-5.2-codex | openai | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $1.75, Out: $14.00, Cache: $0.18 |
| gpt-5.2-pro | openai | In: text, image; Out: text | function_calling, reasoning, vision, streaming, structured_output | 400000 | 128000 | In: $21.00, Out: $168.00 |
| gpt-5.2-pro-2025-12-11 | openai | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5.3-codex | openai | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $1.75, Out: $14.00, Cache: $0.18 |
| gpt-5.3-codex-spark | openai | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 128000 | 32000 | In: $1.75, Out: $14.00, Cache: $0.18 |
| o1-2024-12-17 | openai | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 200000 | 100000 | In: $15.00, Out: $60.00 |
| o1-pro-2025-03-19 | openai | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 200000 | 100000 | In: $150.00, Out: $600.00 |
| o3-mini-2025-01-31 | openai | In: text; Out: text | streaming, function_calling, structured_output, reasoning | 200000 | 100000 | In: $1.10, Out: $4.40 |
| o1 | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 100000 | In: $15.00, Out: $60.00, Cache: $7.50 |
| o1-mini | openai | In: text; Out: text | structured_output, reasoning | 128000 | 65536 | In: $1.10, Out: $4.40, Cache: $0.55 |
| o1-pro | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 100000 | In: $150.00, Out: $600.00 |
| o3 | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 100000 | In: $2.00, Out: $8.00, Cache: $0.50 |
| o3-mini | openai | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 200000 | 100000 | In: $1.10, Out: $4.40, Cache: $0.55 |
| o3-pro | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 100000 | In: $20.00, Out: $80.00 |
| o4-mini | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 100000 | In: $1.10, Out: $4.40, Cache: $0.28 |
| ai21/jamba-large-1.7 | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 256000 | 4096 | In: $2.00, Out: $8.00 |
| allenai/olmo-3-32b-think | openrouter | In: text; Out: text | streaming, structured_output, predicted_outputs | 65536 | 65536 | In: $0.15, Out: $0.50 |
| allenai/olmo-3-7b-instruct | openrouter | In: text; Out: text | streaming, structured_output, predicted_outputs | 65536 | 65536 | In: $0.10, Out: $0.20 |
| allenai/olmo-3-7b-think | openrouter | In: text; Out: text | streaming, structured_output, predicted_outputs | 65536 | 65536 | In: $0.12, Out: $0.20 |
| allenai/olmo-3.1-32b-instruct | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 65536 | - | In: $0.20, Out: $0.60 |
| allenai/olmo-3.1-32b-think | openrouter | In: text; Out: text | streaming, structured_output, predicted_outputs | 65536 | 65536 | In: $0.15, Out: $0.50 |
| arcee-ai/trinity-mini | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 131072 | 131072 | In: $0.04, Out: $0.15 |
| openrouter/aurora-alpha | openrouter | In: text; Out: text | function_calling, structured_output, reasoning | 128000 | 50000 | - |
| openrouter/auto | openrouter | In: text, image, audio, file, video; Out: text, image | streaming, function_calling, structured_output, predicted_outputs | 2000000 | - | - |
| baidu/ernie-4.5-300b-a47b | openrouter | In: text; Out: text | streaming, structured_output | 123000 | 12000 | In: $0.28, Out: $1.10 |
| bytedance-seed/seed-1.6 | openrouter | In: image, text, video; Out: text | streaming, function_calling, structured_output | 262144 | 32768 | In: $0.25, Out: $2.00 |
| bytedance-seed/seed-1.6-flash | openrouter | In: image, text, video; Out: text | streaming, function_calling, structured_output | 262144 | 32768 | In: $0.08, Out: $0.30 |
| anthropic/claude-haiku-4.5 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 64000 | In: $1.00, Out: $5.00, Cache: $0.10 |
| anthropic/claude-opus-4.1 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 32000 | In: $15.00, Out: $75.00, Cache: $1.50 |
| anthropic/claude-opus-4.5 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 32000 | In: $5.00, Out: $25.00, Cache: $0.50 |
| anthropic/claude-opus-4.6 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache: $0.50 |
| anthropic/claude-sonnet-4.5 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 64000 | In: $3.00, Out: $15.00, Cache: $0.30 |
| anthropic/claude-sonnet-4.6 | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 128000 | In: $3.00, Out: $15.00, Cache: $0.30 |
| mistralai/codestral-2508 | openrouter | In: text; Out: text | function_calling, structured_output, streaming | 256000 | 256000 | In: $0.30, Out: $0.90 |
| cohere/command-a | openrouter | In: text; Out: text | streaming, structured_output | 256000 | 8192 | In: $2.50, Out: $10.00 |
| cohere/command-r-08-2024 | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 128000 | 4000 | In: $0.15, Out: $0.60 |
| cohere/command-r-plus-08-2024 | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 128000 | 4000 | In: $2.50, Out: $10.00 |
| cohere/command-r7b-12-2024 | openrouter | In: text; Out: text | streaming, structured_output | 128000 | 4000 | In: $0.04, Out: $0.15 |
| deepcogito/cogito-v2.1-671b | openrouter | In: text; Out: text | streaming, structured_output, predicted_outputs | 128000 | - | In: $1.25, Out: $1.25 |
| deepseek/deepseek-r1-distill-llama-70b | openrouter | In: text; Out: text | structured_output, reasoning, streaming, predicted_outputs | 8192 | 8192 | In: $0.70, Out: $0.80 |
| tngtech/deepseek-r1t2-chimera:free | openrouter | In: text; Out: text | structured_output, reasoning | 163840 | 163840 | - |
| deepseek/deepseek-chat-v3-0324 | openrouter | In: text; Out: text | structured_output, streaming, function_calling, predicted_outputs | 16384 | 8192 | In: $0.19, Out: $0.87, Cache: $0.10 |
| deepseek/deepseek-v3.1-terminus | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 131072 | 65536 | In: $0.27, Out: $1.00 |
| deepseek/deepseek-v3.1-terminus:exacto | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 131072 | 65536 | In: $0.27, Out: $1.00 |
| deepseek/deepseek-v3.2 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 163840 | 65536 | In: $0.28, Out: $0.40 |
| deepseek/deepseek-v3.2-speciale | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 163840 | 65536 | In: $0.27, Out: $0.41 |
| deepseek/deepseek-chat-v3.1 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 163840 | 163840 | In: $0.20, Out: $0.80 |
| deepseek/deepseek-chat | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 163840 | 163840 | In: $0.32, Out: $0.89 |
| deepseek/deepseek-v3.2-exp | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 163840 | 65536 | In: $0.27, Out: $0.41 |
| deepseek/deepseek-r1-0528 | openrouter | In: text; Out: text | streaming, function_calling, structured_output, predicted_outputs | 163840 | 65536 | In: $0.40, Out: $1.75, Cache: $0.20 |
| deepseek/deepseek-r1-distill-qwen-32b | openrouter | In: text; Out: text | streaming, structured_output | 32768 | 32768 | In: $0.29, Out: $0.29 |
| mistralai/devstral-2512 | openrouter | In: text; Out: text | function_calling, structured_output, streaming | 262144 | 262144 | In: $0.15, Out: $0.60 |
| mistralai/devstral-medium-2507 | openrouter | In: text; Out: text | function_calling, structured_output | 131072 | 131072 | In: $0.40, Out: $2.00 |
| mistralai/devstral-small-2507 | openrouter | In: text; Out: text | function_calling, structured_output | 131072 | 131072 | In: $0.10, Out: $0.30 |
| essentialai/rnj-1-instruct | openrouter | In: text; Out: text | streaming, structured_output, predicted_outputs | 32768 | - | In: $0.15, Out: $0.15 |
| openrouter/free | openrouter | In: text, image; Out: text | streaming, function_calling, structured_output | 200000 | - | - |
| z-ai/glm-4.5 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 128000 | 96000 | In: $0.60, Out: $2.20 |
| z-ai/glm-4.5-air | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 128000 | 96000 | In: $0.20, Out: $1.10 |
| z-ai/glm-4.5v | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, streaming | 64000 | 16384 | In: $0.60, Out: $1.80 |
| z-ai/glm-4.6 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 200000 | 128000 | In: $0.60, Out: $2.20, Cache: $0.11 |
| z-ai/glm-4.6:exacto | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 200000 | 128000 | In: $0.60, Out: $1.90, Cache: $0.11 |
| z-ai/glm-4.7 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 204800 | 131072 | In: $0.60, Out: $2.20, Cache: $0.11 |
| z-ai/glm-4.7-flash | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 200000 | 65535 | In: $0.07, Out: $0.40 |
| z-ai/glm-5 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 202752 | 131000 | In: $1.00, Out: $3.20, Cache: $0.20 |
| openai/gpt-oss-120b | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 131072 | 32768 | In: $0.07, Out: $0.28 |
| openai/gpt-oss-120b:exacto | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 131072 | 32768 | In: $0.05, Out: $0.24 |
| openai/gpt-oss-20b | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 131072 | 32768 | In: $0.05, Out: $0.20 |
| openai/gpt-oss-safeguard-20b | openrouter | In: text; Out: text | function_calling, reasoning, streaming, structured_output | 131072 | 65536 | In: $0.08, Out: $0.30 |
| openai/gpt-4.1 | openrouter | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 1047576 | 32768 | In: $2.00, Out: $8.00, Cache: $0.50 |
| openai/gpt-4.1-mini | openrouter | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 1047576 | 32768 | In: $0.40, Out: $1.60, Cache: $0.10 |
| openai/gpt-4o-mini | openrouter | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 128000 | 16384 | In: $0.15, Out: $0.60, Cache: $0.08 |
| openai/gpt-5 | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $1.25, Out: $10.00 |
| openai/gpt-5-chat | openrouter | In: text, image; Out: text | structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $1.25, Out: $10.00 |
| openai/gpt-5-codex | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| openai/gpt-5-image | openrouter | In: text, image, pdf; Out: text, image | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $5.00, Out: $10.00, Cache: $1.25 |
| openai/gpt-5-mini | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $0.25, Out: $2.00 |
| openai/gpt-5-nano | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $0.05, Out: $0.40 |
| openai/gpt-5-pro | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 272000 | In: $15.00, Out: $120.00 |
| openai/gpt-5.1 | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| openai/gpt-5.1-chat | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 128000 | 16384 | In: $1.25, Out: $10.00, Cache: $0.12 |
| openai/gpt-5.1-codex | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| openai/gpt-5.1-codex-max | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $1.10, Out: $9.00, Cache: $0.11 |
| openai/gpt-5.1-codex-mini | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 100000 | In: $0.25, Out: $2.00, Cache: $0.02 |
| openai/gpt-5.2 | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $1.75, Out: $14.00, Cache: $0.18 |
| openai/gpt-5.2-chat | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 128000 | 16384 | In: $1.75, Out: $14.00, Cache: $0.18 |
| openai/gpt-5.2-pro | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $21.00, Out: $168.00 |
| openai/gpt-5.2-codex | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $1.75, Out: $14.00, Cache: $0.18 |
| google/gemini-2.0-flash-001 | openrouter | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, vision, streaming | 1048576 | 8192 | In: $0.10, Out: $0.40, Cache: $0.02 |
| google/gemini-2.5-flash | openrouter | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1048576 | 65536 | In: $0.30, Out: $2.50, Cache: $0.04 |
| google/gemini-2.5-flash-lite | openrouter | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1048576 | 65536 | In: $0.10, Out: $0.40, Cache: $0.02 |
| google/gemini-2.5-flash-lite-preview-09-2025 | openrouter | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1048576 | 65536 | In: $0.10, Out: $0.40, Cache: $0.02 |
| google/gemini-2.5-flash-preview-09-2025 | openrouter | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1048576 | 65536 | In: $0.30, Out: $2.50, Cache: $0.03 |
| google/gemini-2.5-pro | openrouter | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1048576 | 65536 | In: $1.25, Out: $10.00, Cache: $0.31 |
| google/gemini-2.5-pro-preview-05-06 | openrouter | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1048576 | 65536 | In: $1.25, Out: $10.00, Cache: $0.31 |
| google/gemini-2.5-pro-preview-06-05 | openrouter | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1048576 | 65536 | In: $1.25, Out: $10.00, Cache: $0.31 |
| google/gemini-3-flash-preview | openrouter | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1048576 | 65536 | In: $0.50, Out: $3.00, Cache: $0.05 |
| google/gemini-3-pro-preview | openrouter | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1050000 | 66000 | In: $2.00, Out: $12.00 |
| google/gemini-3.1-pro-preview | openrouter | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1048576 | 65536 | In: $2.00, Out: $12.00 |
| google/gemma-3-12b-it | openrouter | In: text, image; Out: text | structured_output, vision, streaming, predicted_outputs | 131072 | 131072 | In: $0.03, Out: $0.10 |
| google/gemma-3-27b-it | openrouter | In: text, image; Out: text | function_calling, structured_output, vision, streaming, predicted_outputs | 96000 | 96000 | In: $0.04, Out: $0.15 |
| google/gemma-3-27b-it:free | openrouter | In: text, image; Out: text | function_calling, vision, streaming, structured_output | 131072 | 8192 | - |
| google/gemma-3-4b-it | openrouter | In: text, image; Out: text | vision, streaming, structured_output | 96000 | 96000 | In: $0.02, Out: $0.07 |
| google/gemma-3-4b-it:free | openrouter | In: text, image; Out: text | vision, streaming, structured_output | 32768 | 8192 | - |
| google/gemma-3n-e2b-it:free | openrouter | In: text; Out: text | streaming, structured_output | 8192 | 2000 | - |
| google/gemma-3n-e4b-it:free | openrouter | In: text; Out: text | streaming, structured_output | 8192 | 2000 | - |
| alpindale/goliath-120b | openrouter | In: text; Out: text | streaming, structured_output, predicted_outputs | 6144 | 1024 | In: $3.75, Out: $7.50 |
| google/gemini-2.0-flash-lite-001 | openrouter | In: text, image, file, audio, video; Out: text | streaming, function_calling, structured_output | 1048576 | 8192 | In: $0.08, Out: $0.30 |
| google/gemini-2.5-flash-image | openrouter | In: image, text; Out: image, text | streaming, structured_output | 32768 | 32768 | In: $0.30, Out: $2.50, Cache: $0.03 |
| google/gemini-2.5-pro-preview | openrouter | In: file, image, text, audio; Out: text | streaming, function_calling, structured_output | 1048576 | 65536 | In: $1.25, Out: $10.00, Cache: $0.12 |
| google/gemma-2-27b-it | openrouter | In: text; Out: text | streaming, structured_output | 8192 | 2048 | In: $0.65, Out: $0.65 |
| google/gemini-3-pro-image-preview | openrouter | In: image, text; Out: image, text | streaming, structured_output | 65536 | 32768 | In: $2.00, Out: $12.00, Cache: $0.20 |
| x-ai/grok-3 | openrouter | In: text; Out: text | function_calling, structured_output, streaming | 131072 | 8192 | In: $3.00, Out: $15.00, Cache: $0.75 |
| x-ai/grok-3-beta | openrouter | In: text; Out: text | function_calling, streaming, structured_output | 131072 | 8192 | In: $3.00, Out: $15.00, Cache: $0.75 |
| x-ai/grok-3-mini | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 131072 | 8192 | In: $0.30, Out: $0.50, Cache: $0.08 |
| x-ai/grok-3-mini-beta | openrouter | In: text; Out: text | function_calling, reasoning, streaming, structured_output | 131072 | 8192 | In: $0.30, Out: $0.50, Cache: $0.08 |
| x-ai/grok-4 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 256000 | 64000 | In: $3.00, Out: $15.00, Cache: $0.75 |
| x-ai/grok-4-fast | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 2000000 | 30000 | In: $0.20, Out: $0.50, Cache: $0.05 |
| x-ai/grok-4.1-fast | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 2000000 | 30000 | In: $0.20, Out: $0.50, Cache: $0.05 |
| x-ai/grok-code-fast-1 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 256000 | 10000 | In: $0.20, Out: $1.50, Cache: $0.02 |
| nousresearch/hermes-4-405b | openrouter | In: text; Out: text | function_calling, reasoning, streaming, structured_output | 131072 | 131072 | In: $1.00, Out: $3.00 |
| nousresearch/hermes-4-70b | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 131072 | 131072 | In: $0.13, Out: $0.40 |
| inception/mercury | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 128000 | 16384 | In: $0.25, Out: $1.00 |
| inception/mercury-coder | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 128000 | 16384 | In: $0.25, Out: $1.00 |
| prime-intellect/intellect-3 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 131072 | 8192 | In: $0.20, Out: $1.10 |
| kwaipilot/kat-coder-pro:free | openrouter | In: text; Out: text | function_calling, structured_output | 256000 | 65536 | - |
| moonshotai/kimi-k2 | openrouter | In: text; Out: text | function_calling, streaming, structured_output | 131072 | 32768 | In: $0.55, Out: $2.20 |
| moonshotai/kimi-k2-0905 | openrouter | In: text; Out: text | function_calling, structured_output, streaming, predicted_outputs | 262144 | 16384 | In: $0.60, Out: $2.50 |
| moonshotai/kimi-k2-0905:exacto | openrouter | In: text; Out: text | function_calling, structured_output, streaming | 262144 | 16384 | In: $0.60, Out: $2.50 |
| moonshotai/kimi-k2-thinking | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 262144 | 262144 | In: $0.60, Out: $2.50, Cache: $0.15 |
| moonshotai/kimi-k2.5 | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, streaming, predicted_outputs | 262144 | 262144 | In: $0.60, Out: $3.00, Cache: $0.10 |
| kwaipilot/kat-coder-pro | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 256000 | 128000 | In: $0.21, Out: $0.83, Cache: $0.04 |
| meta-llama/llama-3.1-405b-instruct:free | openrouter | In: text; Out: text | structured_output | 131072 | 131072 | - |
| meta-llama/llama-3.2-11b-vision-instruct | openrouter | In: text, image; Out: text | vision, streaming, structured_output, predicted_outputs | 131072 | 8192 | In: $0.05, Out: $0.05 |
| meta-llama/llama-3.3-70b-instruct:free | openrouter | In: text; Out: text | function_calling, structured_output, streaming | 131072 | 131072 | - |
| meta-llama/llama-4-scout:free | openrouter | In: text, image; Out: text | function_calling, structured_output, vision | 64000 | 64000 | - |
| anthracite-org/magnum-v4-72b | openrouter | In: text; Out: text | streaming, structured_output, predicted_outputs | 16384 | 2048 | In: $3.00, Out: $5.00 |
| mancer/weaver | openrouter | In: text; Out: text | streaming, structured_output, predicted_outputs | 8000 | 2000 | In: $0.75, Out: $1.00 |
| meta-llama/llama-3-70b-instruct | openrouter | In: text; Out: text | streaming, structured_output | 8192 | 8000 | In: $0.51, Out: $0.74 |
| meta-llama/llama-3-8b-instruct | openrouter | In: text; Out: text | streaming, function_calling, structured_output, predicted_outputs | 8192 | 16384 | In: $0.03, Out: $0.04 |
| meta-llama/llama-3.1-405b-instruct | openrouter | In: text; Out: text | streaming, function_calling, structured_output, predicted_outputs | 131000 | - | In: $4.00, Out: $4.00 |
| meta-llama/llama-3.1-70b-instruct | openrouter | In: text; Out: text | streaming, function_calling, structured_output, predicted_outputs | 131072 | - | In: $0.40, Out: $0.40 |
| meta-llama/llama-3.1-8b-instruct | openrouter | In: text; Out: text | streaming, function_calling, structured_output, predicted_outputs | 16384 | 16384 | In: $0.02, Out: $0.05 |
| meta-llama/llama-3.2-3b-instruct | openrouter | In: text; Out: text | streaming, structured_output, predicted_outputs | 131072 | 16384 | In: $0.02, Out: $0.02 |
| meta-llama/llama-3.3-70b-instruct | openrouter | In: text; Out: text | streaming, function_calling, structured_output, predicted_outputs | 131072 | 16384 | In: $0.10, Out: $0.32 |
| meta-llama/llama-4-maverick | openrouter | In: text, image; Out: text | streaming, function_calling, structured_output, predicted_outputs | 1048576 | 16384 | In: $0.15, Out: $0.60 |
| meta-llama/llama-4-scout | openrouter | In: text, image; Out: text | streaming, function_calling, structured_output | 327680 | 16384 | In: $0.08, Out: $0.30 |
| meta-llama/llama-guard-4-12b | openrouter | In: image, text; Out: text | streaming, structured_output, predicted_outputs | 163840 | - | In: $0.18, Out: $0.18 |
| xiaomi/mimo-v2-flash | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 262144 | 65536 | In: $0.10, Out: $0.30, Cache: $0.01 |
| microsoft/phi-4 | openrouter | In: text; Out: text | streaming, structured_output | 16384 | 16384 | In: $0.06, Out: $0.14 |
| minimax/minimax-m2 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 196600 | 118000 | In: $0.28, Out: $1.15, Cache: $0.28 |
| minimax/minimax-m2.1 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 204800 | 131072 | In: $0.30, Out: $1.20 |
| minimax/minimax-m2.5 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 204800 | 131072 | In: $0.30, Out: $1.20, Cache: $0.03 |
| mistralai/mistral-large | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 128000 | - | In: $2.00, Out: $6.00 |
| mistralai/mistral-large-2407 | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 131072 | - | In: $2.00, Out: $6.00 |
| mistralai/mistral-large-2411 | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 131072 | - | In: $2.00, Out: $6.00 |
| mistralai/mistral-medium-3 | openrouter | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 131072 | 131072 | In: $0.40, Out: $2.00 |
| mistralai/mistral-medium-3.1 | openrouter | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 262144 | 262144 | In: $0.40, Out: $2.00 |
| mistralai/mistral-nemo:free | openrouter | In: text; Out: text | function_calling, structured_output | 131072 | 131072 | - |
| mistralai/mistral-small-3.1-24b-instruct | openrouter | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 128000 | 8192 | In: $0.35, Out: $0.56 |
| mistralai/mistral-small-3.2-24b-instruct:free | openrouter | In: text, image; Out: text | function_calling, structured_output, vision | 96000 | 96000 | - |
| mistralai/mistral-small-3.2-24b-instruct | openrouter | In: text, image; Out: text | function_calling, structured_output, vision, streaming, predicted_outputs | 96000 | 8192 | In: $0.06, Out: $0.18, Cache: $0.03 |
| mistralai/devstral-medium | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 131072 | - | In: $0.40, Out: $2.00 |
| mistralai/devstral-small | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 131072 | - | In: $0.10, Out: $0.30 |
| mistralai/ministral-14b-2512 | openrouter | In: text, image; Out: text | streaming, function_calling, structured_output, predicted_outputs | 262144 | - | In: $0.20, Out: $0.20 |
| mistralai/ministral-3b-2512 | openrouter | In: text, image; Out: text | streaming, function_calling, structured_output | 131072 | - | In: $0.10, Out: $0.10 |
| mistralai/ministral-8b-2512 | openrouter | In: text, image; Out: text | streaming, function_calling, structured_output | 262144 | - | In: $0.15, Out: $0.15 |
| mistralai/mistral-large-2512 | openrouter | In: text, image; Out: text | streaming, function_calling, structured_output | 262144 | - | In: $0.50, Out: $1.50 |
| mistralai/mistral-nemo | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 131072 | 16384 | In: $0.02, Out: $0.04 |
| mistralai/mistral-small-24b-instruct-2501 | openrouter | In: text; Out: text | streaming, function_calling, structured_output, predicted_outputs | 32768 | 16384 | In: $0.05, Out: $0.08 |
| mistralai/mistral-small-3.1-24b-instruct:free | openrouter | In: text, image; Out: text | streaming, function_calling, structured_output | 128000 | - | - |
| mistralai/mixtral-8x22b-instruct | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 65536 | - | In: $2.00, Out: $6.00 |
| mistralai/mixtral-8x7b-instruct | openrouter | In: text; Out: text | streaming, function_calling, structured_output, predicted_outputs | 32768 | 16384 | In: $0.54, Out: $0.54 |
| mistralai/pixtral-large-2411 | openrouter | In: text, image; Out: text | streaming, function_calling, structured_output | 131072 | - | In: $2.00, Out: $6.00 |
| mistralai/mistral-saba | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 32768 | - | In: $0.20, Out: $0.60 |
| mistralai/voxtral-small-24b-2507 | openrouter | In: text, audio; Out: text | streaming, function_calling, structured_output | 32000 | - | In: $0.10, Out: $0.30 |
| gryphe/mythomax-l2-13b | openrouter | In: text; Out: text | streaming, structured_output, predicted_outputs | 4096 | 4096 | In: $0.06, Out: $0.06 |
| nvidia/llama-3.1-nemotron-70b-instruct | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 131072 | 16384 | In: $1.20, Out: $1.20 |
| nvidia/llama-3.3-nemotron-super-49b-v1.5 | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 131072 | - | In: $0.10, Out: $0.40 |
| nvidia/nemotron-3-nano-30b-a3b | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 262144 | - | In: $0.05, Out: $0.20 |
| nvidia/nemotron-nano-12b-v2-vl | openrouter | In: image, text, video; Out: text | streaming, structured_output | 131072 | - | In: $0.07, Out: $0.20 |
| nvidia/nemotron-3-nano-30b-a3b:free | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 256000 | 256000 | - |
| nvidia/nemotron-nano-9b-v2:free | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 128000 | 128000 | - |
| neversleep/llama-3.1-lumimaid-8b | openrouter | In: text; Out: text | streaming, structured_output | 32768 | 4096 | In: $0.09, Out: $0.60 |
| nex-agi/deepseek-v3.1-nex-n1 | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 131072 | 163840 | In: $0.27, Out: $1.00 |
| neversleep/noromaid-20b | openrouter | In: text; Out: text | streaming, structured_output | 4096 | 2048 | In: $1.00, Out: $1.75 |
| nousresearch/hermes-3-llama-3.1-405b | openrouter | In: text; Out: text | streaming, structured_output | 131072 | 16384 | In: $1.00, Out: $1.00 |
| nousresearch/hermes-3-llama-3.1-70b | openrouter | In: text; Out: text | streaming, structured_output | 65536 | 65536 | In: $0.30, Out: $0.30 |
| nousresearch/hermes-2-pro-llama-3-8b | openrouter | In: text; Out: text | streaming, structured_output | 8192 | 8192 | In: $0.14, Out: $0.14 |
| openai/gpt-audio | openrouter | In: text, audio; Out: text, audio | streaming, structured_output | 128000 | 16384 | In: $2.50, Out: $10.00 |
| openai/gpt-audio-mini | openrouter | In: text, audio; Out: text, audio | streaming, structured_output | 128000 | 16384 | In: $0.60, Out: $2.40 |
| openai/gpt-3.5-turbo | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 16385 | 4096 | In: $0.50, Out: $1.50 |
| openai/gpt-3.5-turbo-0613 | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 4095 | 4096 | In: $1.00, Out: $2.00 |
| openai/gpt-3.5-turbo-16k | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 16385 | 4096 | In: $3.00, Out: $4.00 |
| openai/gpt-3.5-turbo-instruct | openrouter | In: text; Out: text | streaming, structured_output | 4095 | 4096 | In: $1.50, Out: $2.00 |
| openai/gpt-4 | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 8191 | 4096 | In: $30.00, Out: $60.00 |
| openai/gpt-4-0314 | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 8191 | 4096 | In: $30.00, Out: $60.00 |
| openai/gpt-4-turbo | openrouter | In: text, image; Out: text | streaming, function_calling, structured_output | 128000 | 4096 | In: $10.00, Out: $30.00 |
| openai/gpt-4-1106-preview | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 128000 | 4096 | In: $10.00, Out: $30.00 |
| openai/gpt-4-turbo-preview | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 128000 | 4096 | In: $10.00, Out: $30.00 |
| openai/gpt-4.1-nano | openrouter | In: image, text, file; Out: text | streaming, function_calling, structured_output | 1047576 | 32768 | In: $0.10, Out: $0.40, Cache: $0.02 |
| openai/gpt-4o | openrouter | In: text, image, file; Out: text | streaming, function_calling, structured_output | 128000 | 16384 | In: $2.50, Out: $10.00, Cache: $1.25 |
| openai/gpt-4o-2024-05-13 | openrouter | In: text, image, file; Out: text | streaming, function_calling, structured_output | 128000 | 4096 | In: $5.00, Out: $15.00 |
| openai/gpt-4o-2024-08-06 | openrouter | In: text, image, file; Out: text | streaming, function_calling, structured_output | 128000 | 16384 | In: $2.50, Out: $10.00, Cache: $1.25 |
| openai/gpt-4o-2024-11-20 | openrouter | In: text, image, file; Out: text | streaming, function_calling, structured_output | 128000 | 16384 | In: $2.50, Out: $10.00, Cache: $1.25 |
| openai/gpt-4o:extended | openrouter | In: text, image, file; Out: text | streaming, function_calling, structured_output | 128000 | 64000 | In: $6.00, Out: $18.00 |
| openai/gpt-4o-audio-preview | openrouter | In: audio, text; Out: text, audio | streaming, function_calling, structured_output | 128000 | 16384 | In: $2.50, Out: $10.00 |
| openai/gpt-4o-search-preview | openrouter | In: text; Out: text | streaming, structured_output | 128000 | 16384 | In: $2.50, Out: $10.00 |
| openai/gpt-4o-mini-2024-07-18 | openrouter | In: text, image, file; Out: text | streaming, function_calling, structured_output | 128000 | 16384 | In: $0.15, Out: $0.60, Cache: $0.08 |
| openai/gpt-4o-mini-search-preview | openrouter | In: text; Out: text | streaming, structured_output | 128000 | 16384 | In: $0.15, Out: $0.60 |
| openai/gpt-5-image-mini | openrouter | In: file, image, text; Out: image, text | streaming, function_calling, structured_output | 400000 | 128000 | In: $2.50, Out: $2.00, Cache: $0.25 |
| openai/gpt-5.3-codex | openrouter | In: text, image; Out: text | streaming, function_calling, structured_output | 400000 | 128000 | In: $1.75, Out: $14.00, Cache: $0.18 |
| openai/o1 | openrouter | In: text, image, file; Out: text | streaming, function_calling, structured_output | 200000 | 100000 | In: $15.00, Out: $60.00, Cache: $7.50 |
| openai/o1-pro | openrouter | In: text, image, file; Out: text | streaming, structured_output | 200000 | 100000 | In: $150.00, Out: $600.00 |
| openai/o3 | openrouter | In: image, text, file; Out: text | streaming, function_calling, structured_output | 200000 | 100000 | In: $2.00, Out: $8.00, Cache: $0.50 |
| openai/o3-deep-research | openrouter | In: image, text, file; Out: text | streaming, function_calling, structured_output | 200000 | 100000 | In: $10.00, Out: $40.00, Cache: $2.50 |
| openai/o3-mini | openrouter | In: text, file; Out: text | streaming, function_calling, structured_output | 200000 | 100000 | In: $1.10, Out: $4.40, Cache: $0.55 |
| openai/o3-mini-high | openrouter | In: text, file; Out: text | streaming, function_calling, structured_output | 200000 | 100000 | In: $1.10, Out: $4.40, Cache: $0.55 |
| openai/o3-pro | openrouter | In: text, file, image; Out: text | streaming, function_calling, structured_output | 200000 | 100000 | In: $20.00, Out: $80.00 |
| openai/o4-mini-deep-research | openrouter | In: file, image, text; Out: text | streaming, function_calling, structured_output | 200000 | 100000 | In: $2.00, Out: $8.00, Cache: $0.50 |
| openai/o4-mini-high | openrouter | In: image, text, file; Out: text | streaming, function_calling, structured_output | 200000 | 100000 | In: $1.10, Out: $4.40, Cache: $0.28 |
| opengvlab/internvl3-78b | openrouter | In: image, text; Out: text | streaming, structured_output | 32768 | 32768 | In: $0.15, Out: $0.60, Cache: $0.08 |
| qwen/qwq-32b:free | openrouter | In: text; Out: text | function_calling, structured_output, reasoning | 32768 | 32768 | - |
| qwen/qwen-2.5-72b-instruct | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 32768 | 16384 | In: $0.12, Out: $0.39 |
| qwen/qwen-2.5-coder-32b-instruct | openrouter | In: text; Out: text | structured_output, streaming, predicted_outputs | 32768 | 8192 | In: $0.20, Out: $0.20 |
| qwen/qwen2.5-vl-32b-instruct:free | openrouter | In: text, image, video; Out: text | function_calling, structured_output, vision | 8192 | 8192 | - |
| qwen/qwen2.5-vl-72b-instruct | openrouter | In: text, image; Out: text | structured_output, vision, streaming, predicted_outputs | 32768 | 8192 | In: $0.80, Out: $0.80 |
| qwen/qwen3-14b:free | openrouter | In: text; Out: text | function_calling, structured_output, reasoning | 40960 | 40960 | - |
| qwen/qwen3-235b-a22b:free | openrouter | In: text; Out: text | function_calling, structured_output, reasoning | 131072 | 131072 | - |
| qwen/qwen3-235b-a22b-07-25 | openrouter | In: text; Out: text | function_calling, structured_output | 262144 | 131072 | In: $0.15, Out: $0.85 |
| qwen/qwen3-235b-a22b-thinking-2507 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 262144 | 81920 | In: $0.08, Out: $0.31 |
| qwen/qwen3-30b-a3b:free | openrouter | In: text; Out: text | function_calling, structured_output, reasoning | 40960 | 40960 | - |
| qwen/qwen3-30b-a3b-instruct-2507 | openrouter | In: text; Out: text | function_calling, structured_output, streaming | 262000 | 262000 | In: $0.20, Out: $0.80 |
| qwen/qwen3-30b-a3b-thinking-2507 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 262000 | 262000 | In: $0.20, Out: $0.80 |
| qwen/qwen3-32b:free | openrouter | In: text; Out: text | function_calling, structured_output, reasoning | 40960 | 40960 | - |
| qwen/qwen3-4b:free | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 40960 | 40960 | - |
| qwen/qwen3-8b:free | openrouter | In: text; Out: text | function_calling, structured_output, reasoning | 40960 | 40960 | - |
| qwen/qwen3-coder | openrouter | In: text; Out: text | function_calling, structured_output, streaming, predicted_outputs | 262144 | 66536 | In: $0.30, Out: $1.20 |
| qwen/qwen3-coder:exacto | openrouter | In: text; Out: text | function_calling, structured_output, streaming | 131072 | 32768 | In: $0.38, Out: $1.53 |
| qwen/qwen3-coder-30b-a3b-instruct | openrouter | In: text; Out: text | function_calling, structured_output, streaming | 160000 | 65536 | In: $0.07, Out: $0.27 |
| qwen/qwen3-coder-flash | openrouter | In: text; Out: text | function_calling, streaming, structured_output | 128000 | 66536 | In: $0.30, Out: $1.50 |
| qwen/qwen3-max | openrouter | In: text; Out: text | function_calling, reasoning, streaming, structured_output | 262144 | 32768 | In: $1.20, Out: $6.00 |
| qwen/qwen3-next-80b-a3b-instruct | openrouter | In: text; Out: text | function_calling, structured_output, streaming, predicted_outputs | 262144 | 262144 | In: $0.14, Out: $1.40 |
| qwen/qwen3-next-80b-a3b-instruct:free | openrouter | In: text; Out: text | function_calling, structured_output, streaming | 262144 | 262144 | - |
| qwen/qwen3-next-80b-a3b-thinking | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 262144 | 262144 | In: $0.14, Out: $1.40 |
| qwen/qwen3.5-397b-a17b | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, streaming, predicted_outputs | 262144 | 65536 | In: $0.60, Out: $3.60 |
| qwen/qwen3.5-plus-02-15 | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 65536 | In: $0.40, Out: $2.40 |
| qwen/qwq-32b | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 32768 | 32768 | In: $0.15, Out: $0.40 |
| qwen/qwen-plus-2025-07-28 | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 1000000 | 32768 | In: $0.40, Out: $1.20 |
| qwen/qwen-plus-2025-07-28:thinking | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 1000000 | 32768 | In: $0.40, Out: $1.20 |
| qwen/qwen-vl-max | openrouter | In: text, image; Out: text | streaming, function_calling, structured_output | 131072 | 32768 | In: $0.80, Out: $3.20 |
| qwen/qwen-vl-plus | openrouter | In: text, image; Out: text | streaming, structured_output | 131072 | 8192 | In: $0.21, Out: $0.63, Cache: $0.04 |
| qwen/qwen-max | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 32768 | 8192 | In: $1.60, Out: $6.40, Cache: $0.32 |
| qwen/qwen-plus | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 1000000 | 32768 | In: $0.40, Out: $1.20, Cache: $0.08 |
| qwen/qwen-turbo | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 131072 | 8192 | In: $0.05, Out: $0.20, Cache: $0.01 |
| qwen/qwen2.5-coder-7b-instruct | openrouter | In: text; Out: text | streaming, structured_output | 32768 | - | In: $0.03, Out: $0.09 |
| qwen/qwen2.5-vl-32b-instruct | openrouter | In: text, image; Out: text | streaming, structured_output | 128000 | - | In: $0.20, Out: $0.60 |
| qwen/qwen3-14b | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 40960 | 40960 | In: $0.06, Out: $0.24 |
| qwen/qwen3-235b-a22b | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 131072 | 8192 | In: $0.46, Out: $1.82 |
| qwen/qwen3-235b-a22b-2507 | openrouter | In: text; Out: text | streaming, function_calling, structured_output, predicted_outputs | 262144 | - | In: $0.07, Out: $0.10 |
| qwen/qwen3-30b-a3b | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 40960 | 40960 | In: $0.08, Out: $0.28 |
| qwen/qwen3-32b | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 40960 | 40960 | In: $0.08, Out: $0.24, Cache: $0.04 |
| qwen/qwen3-8b | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 32000 | 8192 | In: $0.05, Out: $0.40, Cache: $0.05 |
| qwen/qwen3-coder-next | openrouter | In: text; Out: text | streaming, function_calling, structured_output, predicted_outputs | 262144 | 65536 | In: $0.12, Out: $0.75, Cache: $0.06 |
| qwen/qwen3-coder-plus | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 1000000 | 65536 | In: $1.00, Out: $5.00, Cache: $0.20 |
| qwen/qwen3-max-thinking | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 262144 | 32768 | In: $1.20, Out: $6.00 |
| qwen/qwen3-vl-235b-a22b-instruct | openrouter | In: text, image; Out: text | streaming, function_calling, structured_output, predicted_outputs | 262144 | - | In: $0.20, Out: $0.88, Cache: $0.11 |
| qwen/qwen3-vl-235b-a22b-thinking | openrouter | In: text, image; Out: text | streaming, function_calling, structured_output | 131072 | 32768 | - |
| qwen/qwen3-vl-30b-a3b-instruct | openrouter | In: text, image; Out: text | streaming, function_calling, structured_output | 131072 | 32768 | In: $0.13, Out: $0.52 |
| qwen/qwen3-vl-30b-a3b-thinking | openrouter | In: text, image; Out: text | streaming, function_calling, structured_output | 131072 | 32768 | - |
| qwen/qwen3-vl-32b-instruct | openrouter | In: text, image; Out: text | streaming, function_calling, structured_output, predicted_outputs | 131072 | 32768 | In: $0.10, Out: $0.42 |
| qwen/qwen3-vl-8b-instruct | openrouter | In: image, text; Out: text | streaming, function_calling, structured_output, predicted_outputs | 131072 | 32768 | In: $0.08, Out: $0.50 |
| qwen/qwen3-vl-8b-thinking | openrouter | In: image, text; Out: text | streaming, function_calling, structured_output | 131072 | 32768 | In: $0.12, Out: $1.36 |
| deepseek/deepseek-r1-0528:free | openrouter | In: text; Out: text | structured_output, reasoning | 163840 | 163840 | - |
| tngtech/tng-r1t-chimera:free | openrouter | In: text; Out: text | function_calling, structured_output, reasoning | 163840 | 163840 | - |
| undi95/remm-slerp-l2-13b | openrouter | In: text; Out: text | streaming, structured_output, predicted_outputs | 6144 | 4096 | In: $0.45, Out: $0.65 |
| sao10k/l3-lunaris-8b | openrouter | In: text; Out: text | streaming, structured_output | 8192 | - | In: $0.04, Out: $0.05 |
| sao10k/l3.1-euryale-70b | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 32768 | 32768 | In: $0.65, Out: $0.75 |
| sao10k/l3.3-euryale-70b | openrouter | In: text; Out: text | streaming, structured_output | 131072 | 16384 | In: $0.65, Out: $0.75 |
| tngtech/deepseek-r1t2-chimera | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 163840 | 163840 | In: $0.25, Out: $0.85, Cache: $0.12 |
| tencent/hunyuan-a13b-instruct | openrouter | In: text; Out: text | streaming, structured_output | 131072 | 131072 | In: $0.14, Out: $0.57 |
| thedrummer/cydonia-24b-v4.1 | openrouter | In: text; Out: text | streaming, structured_output, predicted_outputs | 131072 | 131072 | In: $0.30, Out: $0.50 |
| thedrummer/rocinante-12b | openrouter | In: text; Out: text | streaming, function_calling, structured_output, predicted_outputs | 32768 | 32768 | In: $0.17, Out: $0.43 |
| thedrummer/unslopnemo-12b | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 32768 | 32768 | In: $0.40, Out: $0.40 |
| alibaba/tongyi-deepresearch-30b-a3b | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 131072 | 131072 | In: $0.09, Out: $0.45, Cache: $0.09 |
| arcee-ai/trinity-large-preview:free | openrouter | In: text; Out: text | function_calling, structured_output, streaming | 131072 | 131072 | - |
| arcee-ai/trinity-mini:free | openrouter | In: text; Out: text | function_calling, structured_output, streaming | 131072 | 131072 | - |
| cognitivecomputations/dolphin-mistral-24b-venice-edition:free | openrouter | In: text; Out: text | structured_output, streaming | 32768 | 32768 | - |
| upstage/solar-pro-3:free | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 128000 | - | - |
| z-ai/glm-4.6v | openrouter | In: image, text, video; Out: text | streaming, function_calling, structured_output | 131072 | 131072 | In: $0.30, Out: $0.90 |
| nvidia/nemotron-nano-9b-v2 | openrouter | In: text; Out: text | function_calling, reasoning, streaming, structured_output, predicted_outputs | 131072 | 131072 | In: $0.04, Out: $0.16 |
| openai/o4-mini | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 100000 | In: $1.10, Out: $4.40, Cache: $0.28 |
| deepseek-ai/deepseek-v3.1-maas | vertexai | In: text, pdf; Out: text | function_calling, structured_output, reasoning, vision | 163840 | 32768 | In: $0.60, Out: $1.70 |
| zai-org/glm-4.7-maas | vertexai | In: text, pdf; Out: text | function_calling, structured_output, reasoning, vision | 200000 | 128000 | In: $0.60, Out: $2.20 |
| gemini-3-flash-preview | vertexai | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1048576 | 65536 | In: $0.50, Out: $3.00, Cache: $0.05 |
| gemini-3-pro-preview | vertexai | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1048576 | 65536 | In: $2.00, Out: $12.00, Cache: $0.20 |
| gemini-3.1-pro-preview | vertexai | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1048576 | 65536 | In: $2.00, Out: $12.00, Cache: $0.20 |
| gemini-3.1-pro-preview-customtools | vertexai | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1048576 | 65536 | In: $2.00, Out: $12.00, Cache: $0.20 |
| meta/llama-3.3-70b-instruct-maas | vertexai | In: text; Out: text | function_calling, structured_output | 128000 | 8192 | In: $0.72, Out: $0.72 |
| meta/llama-4-maverick-17b-128e-instruct-maas | vertexai | In: text, image; Out: text | function_calling, structured_output, vision | 524288 | 8192 | In: $0.35, Out: $1.15 |
| qwen/qwen3-235b-a22b-instruct-2507-maas | vertexai | In: text; Out: text | function_calling, structured_output, reasoning | 262144 | 16384 | In: $0.22, Out: $0.88 |
| grok-2-vision-1212 | xai | In: text, image; Out: text | streaming, function_calling, structured_output, vision | - | - | - |
| grok-3 | xai | In: text; Out: text | streaming, function_calling, structured_output | - | - | - |
| grok-3-mini | xai | In: text; Out: text | streaming, function_calling, structured_output, reasoning | - | - | - |
| grok-4-0709 | xai | In: text, image; Out: text | streaming, function_calling, structured_output, reasoning, vision | - | - | - |
| grok-4-1-fast-non-reasoning | xai | In: text, image; Out: text | streaming, function_calling, structured_output, vision | - | - | - |
| grok-4-1-fast-reasoning | xai | In: text, image; Out: text | streaming, function_calling, structured_output, reasoning, vision | - | - | - |
| grok-4-fast-non-reasoning | xai | In: text, image; Out: text | streaming, function_calling, structured_output, vision | - | - | - |
| grok-4-fast-reasoning | xai | In: text, image; Out: text | streaming, function_calling, structured_output, reasoning, vision | - | - | - |
| grok-code-fast-1 | xai | In: text; Out: text | streaming, function_calling, structured_output, reasoning | - | - | - |
| grok-imagine-image | xai | In: text; Out: text | streaming, function_calling, structured_output | - | - | - |
| grok-imagine-image-pro | xai | In: text; Out: text | streaming, function_calling, structured_output | - | - | - |
| grok-imagine-video | xai | In: text; Out: text | streaming, function_calling, structured_output | - | - | - |


### Streaming (948)

| Model | Provider | I/O | Capabilities | Context | Max Output | Standard Pricing (per 1M tokens) |
| :-- | :-- | :-- | :-- | --: | --: | :-- |
| claude-3-haiku-20240307 | anthropic | In: text, image, pdf; Out: text | function_calling, vision, streaming, batch | 200000 | 4096 | In: $0.25, Out: $1.25, Cache: $0.03 |
| claude-haiku-4-5-20251001 | anthropic | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 64000 | In: $1.00, Out: $5.00, Cache: $0.10 |
| claude-opus-4-20250514 | anthropic | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 32000 | In: $15.00, Out: $75.00, Cache: $1.50 |
| claude-opus-4-1-20250805 | anthropic | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 32000 | In: $15.00, Out: $75.00, Cache: $1.50 |
| claude-opus-4-5-20251101 | anthropic | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 64000 | In: $5.00, Out: $25.00, Cache: $0.50 |
| claude-opus-4-6 | anthropic | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 128000 | In: $5.00, Out: $25.00, Cache: $0.50 |
| claude-sonnet-4-20250514 | anthropic | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 64000 | In: $3.00, Out: $15.00, Cache: $0.30 |
| claude-sonnet-4-5-20250929 | anthropic | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 64000 | In: $3.00, Out: $15.00, Cache: $0.30 |
| claude-sonnet-4-6 | anthropic | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 64000 | In: $3.00, Out: $15.00, Cache: $0.30 |
| ada | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| AI21-Jamba-1.5-Large | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| AI21-Jamba-1.5-Mini | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| AI21-Jamba-Instruct | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| aoai-sora | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| aoai-sora-2025-02-28 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| babbage | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.40, Out: $0.40 |
| claude-haiku-4-5-20251001 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| claude-opus-4-1-20250805 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| claude-opus-4-5-20251101 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| claude-sonnet-4-5-20250929 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| code-cushman-001 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| code-cushman-fine-tune-002 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| code-davinci-002 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| code-davinci-fine-tune-002 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| code-search-ada-code-001 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| code-search-ada-text-001 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| code-search-babbage-code-001 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| code-search-babbage-text-001 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Codestral-2501-2 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| codex-mini-2025-05-16 | azure | In: text; Out: text | streaming, reasoning | 4096 | 16384 | In: $0.50, Out: $1.50 |
| cohere-command-a | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Cohere-command-r | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Cohere-command-r-08-2024 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Cohere-command-r-plus | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Cohere-command-r-plus-08-2024 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Cohere-embed-v3-english | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Cohere-embed-v3-multilingual | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Cohere-rerank-v4.0-fast | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Cohere-rerank-v4.0-pro | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| computer-use-preview-2025-04-15 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| curie | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| dall-e-2 | azure | In: text; Out: text, image | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| dall-e-2-2.0 | azure | In: text; Out: text, image | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| dall-e-3 | azure | In: text; Out: text, image | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| dall-e-3-3.0 | azure | In: text; Out: text, image | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| davinci | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $2.00, Out: $2.00 |
| DeepSeek-R1 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| DeepSeek-R1-0528 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| DeepSeek-V3 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| DeepSeek-V3-0324 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| DeepSeek-V3.1 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| DeepSeek-V3.2 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| DeepSeek-V3.2-Speciale | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| embed-v-4-0 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| FLUX-1.1-pro | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| FLUX.1-Kontext-pro | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| FLUX.2-pro | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| gpt-35-turbo | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| gpt-35-turbo-0125 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| gpt-35-turbo-0301 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| gpt-35-turbo-0613 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| gpt-35-turbo-1106 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| gpt-35-turbo-16k | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| gpt-35-turbo-16k-0613 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| gpt-35-turbo-instruct | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| gpt-35-turbo-instruct-0914 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| gpt-4 | azure | In: text, image, pdf; Out: text | streaming, function_calling | 8192 | 8192 | In: $10.00, Out: $30.00 |
| gpt-4-0125-Preview | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| gpt-4-0314 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| gpt-4-0613 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| gpt-4-1106-Preview | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| gpt-4-32k | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| gpt-4-32k-0314 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| gpt-4-32k-0613 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| gpt-4-turbo-2024-04-09 | azure | In: text, image, pdf; Out: text | streaming, function_calling | 128000 | 4096 | In: $10.00, Out: $30.00 |
| gpt-4-turbo-jp | azure | In: text, image, pdf; Out: text | streaming, function_calling | 128000 | 4096 | In: $10.00, Out: $30.00 |
| gpt-4-vision-preview | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| gpt-4.1 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output | 1047576 | 32768 | In: $2.00, Out: $8.00, Cache: $0.50 |
| gpt-4.1-2025-04-14 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output | 1047576 | 32768 | In: $2.00, Out: $8.00, Cache: $0.50 |
| gpt-4.1-2025-04-14-text | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output | 1047576 | 32768 | In: $2.00, Out: $8.00, Cache: $0.50 |
| gpt-4.1-mini | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output | 1047576 | 32768 | In: $0.40, Out: $1.60, Cache: $0.10 |
| gpt-4.1-mini-2025-04-14 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output | 1047576 | 32768 | In: $0.40, Out: $1.60, Cache: $0.10 |
| gpt-4.1-nano | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output | 1047576 | 32768 | In: $0.10, Out: $0.40 |
| gpt-4.1-nano-2025-04-14 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output | 1047576 | 32768 | In: $0.10, Out: $0.40 |
| gpt-4o | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output | 128000 | 16384 | In: $2.50, Out: $10.00 |
| gpt-4o-2024-05-13 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output | 128000 | 16384 | In: $2.50, Out: $10.00 |
| gpt-4o-2024-08-06 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output | 128000 | 16384 | In: $2.50, Out: $10.00 |
| gpt-4o-2024-11-20 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output | 128000 | 16384 | In: $2.50, Out: $10.00 |
| gpt-4o-canvas-2024-09-25 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output | 128000 | 16384 | In: $2.50, Out: $10.00 |
| gpt-4o-audio-mai | azure | In: text, audio; Out: text, audio | streaming, speech_generation, transcription | 128000 | 16384 | In: $2.50, Out: $10.00 |
| gpt-4o-audio-preview-2024-10-01 | azure | In: text, audio; Out: text, audio | streaming, speech_generation, transcription | 128000 | 16384 | In: $2.50, Out: $10.00 |
| gpt-4o-audio-preview-2024-12-17 | azure | In: text, audio; Out: text, audio | streaming, speech_generation, transcription | 128000 | 16384 | In: $2.50, Out: $10.00 |
| gpt-4o-audio-preview-2025-06-03 | azure | In: text, audio; Out: text, audio | streaming, speech_generation, transcription | 128000 | 16384 | In: $2.50, Out: $10.00 |
| gpt-4o-mini | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output | 128000 | 16384 | In: $0.15, Out: $0.60 |
| gpt-4o-mini-2024-07-18 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output | 128000 | 16384 | In: $0.15, Out: $0.60 |
| gpt-4o-mini-audio-preview-2024-12-17 | azure | In: text, audio; Out: text, audio | streaming, speech_generation, transcription | 128000 | 16384 | In: $0.15, Out: $0.60 |
| gpt-4o-mini-realtime-preview-2024-12-17 | azure | In: text; Out: text | streaming | 128000 | 4096 | In: $0.60, Out: $2.40 |
| gpt-4o-mini-transcribe | azure | In: text, audio; Out: text | streaming | 16000 | 2000 | In: $1.25, Out: $5.00 |
| gpt-4o-mini-transcribe-2025-03-20 | azure | In: text, audio; Out: text | streaming | 16000 | 2000 | In: $1.25, Out: $5.00 |
| gpt-4o-mini-transcribe-2025-12-15 | azure | In: text, audio; Out: text | streaming | 16000 | 2000 | In: $1.25, Out: $5.00 |
| gpt-4o-mini-tts | azure | In: text, audio; Out: text, audio | streaming | - | - | In: $0.60, Out: $12.00 |
| gpt-4o-mini-tts-2025-03-20 | azure | In: text, audio; Out: text, audio | streaming | - | - | In: $0.60, Out: $12.00 |
| gpt-4o-mini-tts-2025-12-15 | azure | In: text, audio; Out: text, audio | streaming | - | - | In: $0.60, Out: $12.00 |
| gpt-4o-realtime-preview | azure | In: text; Out: text | streaming | 128000 | 4096 | In: $5.00, Out: $20.00 |
| gpt-4o-realtime-preview-2024-12-17 | azure | In: text; Out: text | streaming | 128000 | 4096 | In: $5.00, Out: $20.00 |
| gpt-4o-realtime-preview-2025-06-03 | azure | In: text; Out: text | streaming | 128000 | 4096 | In: $5.00, Out: $20.00 |
| gpt-4o-transcribe | azure | In: text, audio; Out: text | streaming | 128000 | 16384 | In: $2.50, Out: $10.00 |
| gpt-4o-transcribe-2025-03-20 | azure | In: text, audio; Out: text | streaming | 128000 | 16384 | In: $2.50, Out: $10.00 |
| gpt-4o-transcribe-diarize | azure | In: text, audio; Out: text | streaming | 128000 | 16384 | In: $2.50, Out: $10.00 |
| gpt-4o-transcribe-diarize-2025-10-15 | azure | In: text, audio; Out: text | streaming | 128000 | 16384 | In: $2.50, Out: $10.00 |
| gpt-5-chat-2025-08-07 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5-chat-2025-08-15 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5-chat-2025-10-03 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5-codex-2025-09-15 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5-mini-2025-08-07 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5-mini-lite-2025-08-07 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5-nano-2025-08-07 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5.1-chat-2025-11-13 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5.1-codex-mini-2025-11-13 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5.2-chat-2025-12-11 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5.2-chat-2026-02-10 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5.3-codex-2026-02-20 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-audio-2025-08-28 | azure | In: text, audio; Out: text, audio | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| gpt-audio-mini-2025-10-06 | azure | In: text, audio; Out: text, audio | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| gpt-oss-120b | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| gpt-oss-20b-11 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| gpt-realtime-2025-08-28 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| gpt-realtime-mini | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| gpt-realtime-mini-2025-10-06 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| gpt-realtime-mini-2025-12-15 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| grok-3 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| grok-3-mini | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| grok-4-fast-non-reasoning | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| grok-4-fast-reasoning | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| jais-30b-chat | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| jais-30b-chat-2 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| jais-30b-chat-3 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Kimi-K2-Thinking | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Kimi-K2.5 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Llama-3.2-11B-Vision-Instruct | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Llama-3.2-11B-Vision-Instruct-2 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Llama-3.2-90B-Vision-Instruct | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Llama-3.2-90B-Vision-Instruct-2 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Llama-3.2-90B-Vision-Instruct-3 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Llama-3.3-70B-Instruct | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Llama-3.3-70B-Instruct-2 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Llama-3.3-70B-Instruct-3 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Llama-3.3-70B-Instruct-4 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Llama-3.3-70B-Instruct-5 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Llama-3.3-70B-Instruct-9 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Llama-4-Maverick-17B-128E-Instruct-FP8 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Llama-4-Scout-17B-16E-Instruct | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| MAI-DS-R1 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Meta-Llama-3-70B-Instruct-6 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Meta-Llama-3-70B-Instruct-7 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Meta-Llama-3-70B-Instruct-8 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Meta-Llama-3-70B-Instruct-9 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Meta-Llama-3-8B-Instruct-6 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Meta-Llama-3-8B-Instruct-7 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Meta-Llama-3-8B-Instruct-8 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Meta-Llama-3-8B-Instruct-9 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Meta-Llama-3.1-405B-Instruct | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Meta-Llama-3.1-70B-Instruct | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Meta-Llama-3.1-70B-Instruct-2 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Meta-Llama-3.1-70B-Instruct-3 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Meta-Llama-3.1-70B-Instruct-4 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Meta-Llama-3.1-8B-Instruct | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Meta-Llama-3.1-8B-Instruct-2 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Meta-Llama-3.1-8B-Instruct-3 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Meta-Llama-3.1-8B-Instruct-4 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Meta-Llama-3.1-8B-Instruct-5 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Ministral-3B | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| mistral-document-ai-2505 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| mistral-document-ai-2512 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Mistral-large | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Mistral-large-2407 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Mistral-Large-2411-2 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Mistral-Large-3 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| mistral-medium-2505 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Mistral-Nemo | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Mistral-small | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| mistral-small-2503 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| model-router | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| model-router-2025-05-19 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| model-router-2025-08-07 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| model-router-2025-11-18 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| o1-2024-12-17 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 200000 | 100000 | In: $15.00, Out: $60.00 |
| o1-mini-2024-09-12 | azure | In: text; Out: text | streaming, reasoning | 128000 | 65536 | In: $1.10, Out: $4.40 |
| o1-pro | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 200000 | 100000 | In: $150.00, Out: $600.00 |
| o1-pro-2025-03-19 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 200000 | 100000 | In: $150.00, Out: $600.00 |
| o3-deep-research-2025-06-26 | azure | In: text; Out: text | streaming, reasoning | 4096 | 16384 | In: $0.50, Out: $1.50 |
| o3-deep-research-2025-06-26-ev3 | azure | In: text; Out: text | streaming, reasoning | 4096 | 16384 | In: $0.50, Out: $1.50 |
| o3-mini | azure | In: text; Out: text | streaming, function_calling, structured_output, reasoning | 200000 | 100000 | In: $1.10, Out: $4.40 |
| o3-mini-2025-01-31 | azure | In: text; Out: text | streaming, function_calling, structured_output, reasoning | 200000 | 100000 | In: $1.10, Out: $4.40 |
| o3-mini-alpha | azure | In: text; Out: text | streaming, function_calling, structured_output, reasoning | 200000 | 100000 | In: $1.10, Out: $4.40 |
| o3-mini-alpha-2024-12-17 | azure | In: text; Out: text | streaming, function_calling, structured_output, reasoning | 200000 | 100000 | In: $1.10, Out: $4.40 |
| o4-mini | azure | In: text; Out: text | streaming, reasoning | 4096 | 16384 | In: $0.50, Out: $1.50 |
| o4-mini-2025-04-16 | azure | In: text; Out: text | streaming, reasoning | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Phi-3-medium-128k-instruct-3 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Phi-3-medium-128k-instruct-4 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Phi-3-medium-128k-instruct-5 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Phi-3-medium-128k-instruct-6 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Phi-3-medium-128k-instruct-7 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Phi-3-medium-4k-instruct-3 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Phi-3-medium-4k-instruct-4 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Phi-3-medium-4k-instruct-5 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Phi-3-medium-4k-instruct-6 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Phi-3-mini-128k-instruct-10 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Phi-3-mini-128k-instruct-11 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Phi-3-mini-128k-instruct-12 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Phi-3-mini-128k-instruct-13 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Phi-3-mini-4k-instruct-10 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Phi-3-mini-4k-instruct-11 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Phi-3-mini-4k-instruct-13 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Phi-3-mini-4k-instruct-14 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Phi-3-mini-4k-instruct-15 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Phi-3-small-128k-instruct-3 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Phi-3-small-128k-instruct-4 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Phi-3-small-128k-instruct-5 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Phi-3-small-8k-instruct-3 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Phi-3-small-8k-instruct-4 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Phi-3-small-8k-instruct-5 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Phi-3.5-mini-instruct | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Phi-3.5-mini-instruct-2 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Phi-3.5-mini-instruct-3 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Phi-3.5-mini-instruct-4 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Phi-3.5-mini-instruct-6 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Phi-3.5-MoE-instruct-2 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Phi-3.5-MoE-instruct-3 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Phi-3.5-MoE-instruct-4 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Phi-3.5-MoE-instruct-5 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Phi-3.5-vision-instruct | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Phi-3.5-vision-instruct-2 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Phi-4-2 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Phi-4-3 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Phi-4-4 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Phi-4-5 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Phi-4-6 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Phi-4-7 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Phi-4-mini-instruct | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Phi-4-mini-reasoning | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Phi-4-multimodal-instruct | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Phi-4-reasoning | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| qwen-3-32b | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| qwen3-32b | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| sora | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| sora-2025-05-02 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Stable-Diffusion-3.5-Large | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Stable-Image-Core | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| Stable-Image-Ultra | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| text-ada-001 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| text-babbage-001 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| text-curie-001 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| text-davinci-001 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| text-davinci-002 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| text-davinci-003 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| text-davinci-fine-tune-002 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| text-search-ada-doc-001 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| text-search-ada-query-001 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| text-search-babbage-doc-001 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| text-search-babbage-query-001 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| text-search-curie-doc-001 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| text-search-curie-query-001 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| text-search-davinci-doc-001 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| text-search-davinci-query-001 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| text-similarity-ada-001 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| text-similarity-babbage-001 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| text-similarity-curie-001 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| text-similarity-davinci-001 | azure | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| whisper | azure | In: text, audio; Out: text | streaming | - | - | In: $0.01, Out: $0.01 |
| whisper-001 | azure | In: text, audio; Out: text | streaming | - | - | In: $0.01, Out: $0.01 |
| anthropic.claude-3-haiku-20240307-v1:0:48k | bedrock | In: text, image, pdf; Out: text | function_calling, vision, streaming | 48000 | 4096 | In: $0.25, Out: $1.25 |
| anthropic.claude-3-haiku-20240307-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, vision, streaming | 200000 | 4096 | In: $0.25, Out: $1.25 |
| anthropic.claude-3-haiku-20240307-v1:0:200k | bedrock | In: text, image, pdf; Out: text | function_calling, vision, streaming | 200000 | 4096 | In: $0.25, Out: $1.25 |
| anthropic.claude-3-5-haiku-20241022-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, vision, streaming | 200000 | 8192 | In: $0.80, Out: $4.00, Cache: $0.08 |
| us.anthropic.claude-haiku-4-5-20251001-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 64000 | In: $1.00, Out: $5.00, Cache: $0.10 |
| us.anthropic.claude-opus-4-20250514-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 32000 | In: $15.00, Out: $75.00, Cache: $1.50 |
| us.anthropic.claude-opus-4-1-20250805-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 32000 | In: $15.00, Out: $75.00, Cache: $1.50 |
| us.anthropic.claude-opus-4-5-20251101-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 64000 | In: $5.00, Out: $25.00, Cache: $0.50 |
| us.anthropic.claude-opus-4-6-v1 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache: $0.50 |
| anthropic.claude-3-sonnet-20240229-v1:0:28k | bedrock | In: text, image, pdf; Out: text | function_calling, vision, streaming | 28000 | 4096 | In: $3.00, Out: $15.00 |
| anthropic.claude-3-sonnet-20240229-v1:0:200k | bedrock | In: text, image, pdf; Out: text | function_calling, vision, streaming | 200000 | 4096 | In: $3.00, Out: $15.00 |
| anthropic.claude-3-sonnet-20240229-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, vision, streaming | 200000 | 4096 | In: $3.00, Out: $15.00 |
| anthropic.claude-3-5-sonnet-20240620-v1:0:18k | bedrock | In: text, image, pdf; Out: text | function_calling, vision, streaming | 18000 | 8192 | In: $3.00, Out: $15.00, Cache: $0.30 |
| anthropic.claude-3-5-sonnet-20240620-v1:0:200k | bedrock | In: text, image, pdf; Out: text | function_calling, vision, streaming | 200000 | 8192 | In: $3.00, Out: $15.00, Cache: $0.30 |
| anthropic.claude-3-5-sonnet-20240620-v1:0:51k | bedrock | In: text, image, pdf; Out: text | function_calling, vision, streaming | 51000 | 8192 | In: $3.00, Out: $15.00, Cache: $0.30 |
| anthropic.claude-3-5-sonnet-20240620-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, vision, streaming | 200000 | 8192 | In: $3.00, Out: $15.00, Cache: $0.30 |
| anthropic.claude-3-5-sonnet-20241022-v2:0:51k | bedrock | In: text, image, pdf; Out: text | function_calling, vision, streaming | 51000 | 8192 | In: $3.00, Out: $15.00, Cache: $0.30 |
| anthropic.claude-3-5-sonnet-20241022-v2:0:200k | bedrock | In: text, image, pdf; Out: text | function_calling, vision, streaming | 200000 | 8192 | In: $3.00, Out: $15.00, Cache: $0.30 |
| anthropic.claude-3-5-sonnet-20241022-v2:0:18k | bedrock | In: text, image, pdf; Out: text | function_calling, vision, streaming | 18000 | 8192 | In: $3.00, Out: $15.00, Cache: $0.30 |
| anthropic.claude-3-5-sonnet-20241022-v2:0 | bedrock | In: text, image, pdf; Out: text | function_calling, vision, streaming | 200000 | 8192 | In: $3.00, Out: $15.00, Cache: $0.30 |
| us.anthropic.claude-3-7-sonnet-20250219-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, vision, streaming | 200000 | 8192 | In: $3.00, Out: $15.00, Cache: $0.30 |
| us.anthropic.claude-sonnet-4-20250514-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 64000 | In: $3.00, Out: $15.00, Cache: $0.30 |
| us.anthropic.claude-sonnet-4-5-20250929-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 64000 | In: $3.00, Out: $15.00, Cache: $0.30 |
| us.anthropic.claude-sonnet-4-6 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 64000 | In: $3.00, Out: $15.00, Cache: $0.30 |
| cohere.command-r-v1:0 | bedrock | In: text; Out: text | function_calling, streaming | 128000 | 4096 | In: $0.50, Out: $1.50 |
| cohere.command-r-plus-v1:0 | bedrock | In: text; Out: text | function_calling, streaming | 128000 | 4096 | In: $3.00, Out: $15.00 |
| deepseek.v3.2 | bedrock | In: text; Out: text | streaming, function_calling | - | 163840 | - |
| us.deepseek.r1-v1:0 | bedrock | In: text; Out: text | function_calling, reasoning, streaming | 128000 | 32768 | In: $1.35, Out: $5.40 |
| deepseek.v3-v1:0 | bedrock | In: text; Out: text | function_calling, reasoning, streaming | 163840 | 81920 | In: $0.58, Out: $1.68 |
| mistral.devstral-2-123b | bedrock | In: text; Out: text | streaming, function_calling | - | 262144 | - |
| zai.glm-4.7 | bedrock | In: text; Out: text | function_calling, reasoning, streaming | 204800 | 131072 | In: $0.60, Out: $2.20 |
| zai.glm-4.7-flash | bedrock | In: text; Out: text | function_calling, reasoning, streaming | 200000 | 131072 | In: $0.07, Out: $0.40 |
| openai.gpt-oss-safeguard-120b | bedrock | In: text; Out: text | function_calling, streaming, reasoning | 128000 | 4096 | In: $0.15, Out: $0.60 |
| openai.gpt-oss-safeguard-20b | bedrock | In: text; Out: text | function_calling, streaming, reasoning | 128000 | 4096 | In: $0.07, Out: $0.20 |
| google.gemma-3-4b-it | bedrock | In: text, image; Out: text | function_calling, vision, streaming | 128000 | 4096 | In: $0.04, Out: $0.08 |
| google.gemma-3-12b-it | bedrock | In: text, image; Out: text | vision, streaming, function_calling | 131072 | 8192 | In: $0.05, Out: $0.10 |
| google.gemma-3-27b-it | bedrock | In: text, image; Out: text | function_calling, vision, streaming | 202752 | 8192 | In: $0.12, Out: $0.20 |
| moonshot.kimi-k2-thinking | bedrock | In: text; Out: text | function_calling, reasoning, streaming | 256000 | 256000 | In: $0.60, Out: $2.50 |
| moonshotai.kimi-k2.5 | bedrock | In: text, image; Out: text | function_calling, reasoning, vision, streaming | 256000 | 256000 | In: $0.60, Out: $3.00 |
| meta.llama3-70b-instruct-v1:0 | bedrock | In: text; Out: text | streaming, function_calling | 8192 | 2048 | In: $2.65, Out: $3.50 |
| meta.llama3-8b-instruct-v1:0 | bedrock | In: text; Out: text | streaming, function_calling | 8192 | 2048 | In: $0.30, Out: $0.60 |
| meta.llama3-1-405b-instruct-v1:0 | bedrock | In: text; Out: text | streaming, function_calling | - | - | - |
| meta.llama3-1-70b-instruct-v1:0:128k | bedrock | In: text; Out: text | function_calling, streaming | 128000 | 4096 | In: $0.72, Out: $0.72 |
| meta.llama3-1-70b-instruct-v1:0 | bedrock | In: text; Out: text | function_calling, streaming | 128000 | 4096 | In: $0.72, Out: $0.72 |
| meta.llama3-1-8b-instruct-v1:0:128k | bedrock | In: text; Out: text | function_calling, streaming | 128000 | 4096 | In: $0.22, Out: $0.22 |
| meta.llama3-1-8b-instruct-v1:0 | bedrock | In: text; Out: text | function_calling, streaming | 128000 | 4096 | In: $0.22, Out: $0.22 |
| meta.llama3-2-11b-instruct-v1:0:128k | bedrock | In: text, image; Out: text | function_calling, vision, streaming | 128000 | 4096 | In: $0.16, Out: $0.16 |
| us.meta.llama3-2-11b-instruct-v1:0 | bedrock | In: text, image; Out: text | function_calling, vision, streaming | 128000 | 4096 | In: $0.16, Out: $0.16 |
| meta.llama3-2-1b-instruct-v1:0:128k | bedrock | In: text; Out: text | function_calling, streaming | 128000 | 4096 | In: $0.10, Out: $0.10 |
| us.meta.llama3-2-1b-instruct-v1:0 | bedrock | In: text; Out: text | function_calling, streaming | 131000 | 4096 | In: $0.10, Out: $0.10 |
| meta.llama3-2-3b-instruct-v1:0:128k | bedrock | In: text; Out: text | function_calling, streaming | 128000 | 4096 | In: $0.15, Out: $0.15 |
| us.meta.llama3-2-3b-instruct-v1:0 | bedrock | In: text; Out: text | function_calling, streaming | 131000 | 4096 | In: $0.15, Out: $0.15 |
| meta.llama3-2-90b-instruct-v1:0:128k | bedrock | In: text, image; Out: text | function_calling, vision, streaming | 128000 | 4096 | In: $0.72, Out: $0.72 |
| us.meta.llama3-2-90b-instruct-v1:0 | bedrock | In: text, image; Out: text | function_calling, vision, streaming | 128000 | 4096 | In: $0.72, Out: $0.72 |
| us.meta.llama3-3-70b-instruct-v1:0 | bedrock | In: text; Out: text | function_calling, streaming | 128000 | 4096 | In: $0.72, Out: $0.72 |
| meta.llama3-3-70b-instruct-v1:0:128k | bedrock | In: text; Out: text | function_calling, streaming | 128000 | 4096 | In: $0.72, Out: $0.72 |
| us.meta.llama4-maverick-17b-instruct-v1:0 | bedrock | In: text, image; Out: text | function_calling, vision, streaming | 1000000 | 16384 | In: $0.24, Out: $0.97 |
| us.meta.llama4-scout-17b-instruct-v1:0 | bedrock | In: text, image; Out: text | function_calling, vision, streaming | 3500000 | 16384 | In: $0.17, Out: $0.66 |
| mistral.magistral-small-2509 | bedrock | In: text, image; Out: text | streaming, function_calling, reasoning | - | 131072 | - |
| minimax.minimax-m2 | bedrock | In: text; Out: text | function_calling, reasoning, streaming | 204608 | 128000 | In: $0.30, Out: $1.20 |
| minimax.minimax-m2.1 | bedrock | In: text; Out: text | function_calling, reasoning, streaming | 204800 | 131072 | In: $0.30, Out: $1.20 |
| mistral.ministral-3-14b-instruct | bedrock | In: text; Out: text | function_calling, streaming | 128000 | 4096 | In: $0.20, Out: $0.20 |
| mistral.ministral-3-8b-instruct | bedrock | In: text; Out: text | function_calling, streaming | 128000 | 4096 | In: $0.15, Out: $0.15 |
| mistral.ministral-3-3b-instruct | bedrock | In: text, image; Out: text | streaming, function_calling | - | 262144 | - |
| mistral.mistral-large-2402-v1:0 | bedrock | In: text; Out: text | function_calling, streaming | 128000 | 4096 | In: $0.50, Out: $1.50 |
| mistral.mistral-large-2407-v1:0 | bedrock | In: text; Out: text | streaming, function_calling | - | - | - |
| mistral.mistral-large-3-675b-instruct | bedrock | In: text, image; Out: text | streaming, function_calling | - | 262144 | - |
| mistral.mistral-7b-instruct-v0:2 | bedrock | In: text; Out: text | function_calling, structured_output, streaming | 127000 | 127000 | In: $0.11, Out: $0.11 |
| mistral.mixtral-8x7b-instruct-v0:1 | bedrock | In: text; Out: text | structured_output, streaming, function_calling | 32000 | 32000 | In: $0.70, Out: $0.70 |
| nvidia.nemotron-nano-12b-v2 | bedrock | In: text, image; Out: text | function_calling, vision, streaming | 128000 | 4096 | In: $0.20, Out: $0.60 |
| nvidia.nemotron-nano-9b-v2 | bedrock | In: text; Out: text | function_calling, streaming | 128000 | 4096 | In: $0.06, Out: $0.23 |
| nvidia.nemotron-nano-3-30b | bedrock | In: text; Out: text | streaming, function_calling | - | 262144 | - |
| us.amazon.nova-2-lite-v1:0 | bedrock | In: text, image, video; Out: text | function_calling, vision, streaming | 128000 | 4096 | In: $0.33, Out: $2.75 |
| amazon.nova-2-sonic-v1:0 | bedrock | In: audio; Out: audio, text | streaming, function_calling | - | - | - |
| us.amazon.nova-lite-v1:0 | bedrock | In: text, image, video; Out: text | function_calling, vision, streaming | 300000 | 8192 | In: $0.06, Out: $0.24, Cache: $0.02 |
| us.amazon.nova-micro-v1:0 | bedrock | In: text; Out: text | function_calling, streaming | 128000 | 8192 | In: $0.04, Out: $0.14, Cache: $0.01 |
| amazon.nova-premier-v1:0:mm | bedrock | In: text, image, video; Out: text | streaming, function_calling | - | - | - |
| us.amazon.nova-premier-v1:0 | bedrock | In: text, image, video; Out: text | function_calling, reasoning, vision, streaming | 1000000 | 16384 | In: $2.50, Out: $12.50 |
| amazon.nova-premier-v1:0:8k | bedrock | In: text, image, video; Out: text | function_calling, reasoning, vision, streaming | 8000 | 16384 | In: $2.50, Out: $12.50 |
| amazon.nova-premier-v1:0:1000k | bedrock | In: text, image, video; Out: text | function_calling, reasoning, vision, streaming | 1000000 | 16384 | In: $2.50, Out: $12.50 |
| amazon.nova-premier-v1:0:20k | bedrock | In: text, image, video; Out: text | function_calling, reasoning, vision, streaming | 20000 | 16384 | In: $2.50, Out: $12.50 |
| us.amazon.nova-pro-v1:0 | bedrock | In: text, image, video; Out: text | function_calling, vision, streaming | 300000 | 8192 | In: $0.80, Out: $3.20, Cache: $0.20 |
| us.writer.palmyra-x4-v1:0 | bedrock | In: text; Out: text | function_calling, reasoning, streaming | 122880 | 8192 | In: $2.50, Out: $10.00 |
| us.writer.palmyra-x5-v1:0 | bedrock | In: text; Out: text | function_calling, reasoning, streaming | 1040000 | 8192 | In: $0.60, Out: $6.00 |
| us.twelvelabs.pegasus-1-2-v1:0 | bedrock | In: text, video; Out: text | streaming, function_calling | - | - | - |
| us.mistral.pixtral-large-2502-v1:0 | bedrock | In: text, image; Out: text | streaming, function_calling | - | - | - |
| qwen.qwen3-next-80b-a3b | bedrock | In: text; Out: text | function_calling, structured_output, streaming | 262000 | 262000 | In: $0.14, Out: $1.40 |
| qwen.qwen3-vl-235b-a22b | bedrock | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 262000 | 262000 | In: $0.30, Out: $1.50 |
| qwen.qwen3-235b-a22b-2507-v1:0 | bedrock | In: text; Out: text | function_calling, streaming | 262144 | 131072 | In: $0.22, Out: $0.88 |
| qwen.qwen3-32b-v1:0 | bedrock | In: text; Out: text | function_calling, reasoning, streaming | 16384 | 16384 | In: $0.15, Out: $0.60 |
| qwen.qwen3-coder-30b-a3b-v1:0 | bedrock | In: text; Out: text | function_calling, streaming | 262144 | 131072 | In: $0.15, Out: $0.60 |
| qwen.qwen3-coder-480b-a35b-v1:0 | bedrock | In: text; Out: text | function_calling, streaming | 131072 | 65536 | In: $0.22, Out: $1.80 |
| amazon.titan-tg1-large | bedrock | In: text; Out: text | streaming, function_calling | - | - | - |
| mistral.voxtral-mini-3b-2507 | bedrock | In: audio, text; Out: text | function_calling, streaming | 128000 | 4096 | In: $0.04, Out: $0.04 |
| mistral.voxtral-small-24b-2507 | bedrock | In: text, audio; Out: text | function_calling, streaming | 32000 | 8192 | In: $0.15, Out: $0.35 |
| openai.gpt-oss-120b-1:0 | bedrock | In: text; Out: text | function_calling, streaming | 128000 | 4096 | In: $0.15, Out: $0.60 |
| openai.gpt-oss-20b-1:0 | bedrock | In: text; Out: text | function_calling, streaming | 128000 | 4096 | In: $0.07, Out: $0.30 |
| deepseek-chat | deepseek | In: text; Out: text | function_calling, streaming | 128000 | 8192 | In: $0.28, Out: $0.42, Cache: $0.03 |
| deepseek-reasoner | deepseek | In: text; Out: text | function_calling, reasoning, streaming | 128000 | 128000 | In: $0.28, Out: $0.42, Cache: $0.03 |
| deep-research-pro-preview-12-2025 | gemini | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, caching | 131072 | 65536 | In: $0.08, Out: $0.30 |
| gemini-2.0-flash | gemini | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, vision, streaming, batch, caching | 1048576 | 8192 | In: $0.10, Out: $0.40, Cache: $0.02 |
| gemini-2.0-flash-001 | gemini | In: text, image, pdf, video; Out: text | streaming, function_calling, structured_output, batch, caching | 1048576 | 8192 | In: $0.10, Out: $0.40 |
| gemini-2.0-flash-lite | gemini | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, vision, streaming, batch | 1048576 | 8192 | In: $0.08, Out: $0.30 |
| gemini-2.0-flash-lite-001 | gemini | In: text, image, pdf, video; Out: text | streaming, batch | 1048576 | 8192 | In: $0.08, Out: $0.30 |
| gemini-2.5-computer-use-preview-10-2025 | gemini | In: text, image, pdf, video; Out: text | streaming, function_calling, structured_output, caching | 131072 | 65536 | In: $0.08, Out: $0.30 |
| gemini-2.5-flash | gemini | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming, batch, caching | 1048576 | 65536 | In: $0.30, Out: $2.50, Cache: $0.08 |
| gemini-2.5-flash-image | gemini | In: text, image; Out: text, image | reasoning, vision, streaming, function_calling, structured_output, batch, caching | 32768 | 32768 | In: $0.30, Out: $30.00, Cache: $0.08 |
| gemini-2.5-flash-lite | gemini | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming, batch | 1048576 | 65536 | In: $0.10, Out: $0.40, Cache: $0.02 |
| gemini-2.5-flash-lite-preview-09-2025 | gemini | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming, batch | 1048576 | 65536 | In: $0.10, Out: $0.40, Cache: $0.02 |
| gemini-2.5-flash-native-audio-latest | gemini | In: text, image, pdf, video, audio; Out: text | streaming, function_calling, structured_output, batch, caching | 131072 | 8192 | In: $0.08, Out: $0.30 |
| gemini-2.5-flash-native-audio-preview-09-2025 | gemini | In: text, image, pdf, video, audio; Out: text | streaming, function_calling, structured_output, batch, caching | 131072 | 8192 | In: $0.08, Out: $0.30 |
| gemini-2.5-flash-native-audio-preview-12-2025 | gemini | In: text, image, pdf, video, audio; Out: text | streaming, function_calling, structured_output, batch, caching | 131072 | 8192 | In: $0.08, Out: $0.30 |
| gemini-2.5-flash-preview-tts | gemini | In: text; Out: audio | streaming, function_calling, structured_output, batch, caching | 8000 | 16000 | In: $0.50, Out: $10.00 |
| gemini-2.5-pro | gemini | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming, caching | 1048576 | 65536 | In: $1.25, Out: $10.00, Cache: $0.31 |
| gemini-2.5-pro-preview-tts | gemini | In: text; Out: audio | streaming, function_calling, structured_output, caching | 8000 | 16000 | In: $1.00, Out: $20.00 |
| gemini-3-flash-preview | gemini | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming, batch, caching | 1048576 | 65536 | In: $0.50, Out: $3.00, Cache: $0.05 |
| gemini-3-pro-preview | gemini | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming, caching | 1000000 | 64000 | In: $2.00, Out: $12.00, Cache: $0.20 |
| gemini-3.1-pro-preview | gemini | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming, caching | 1048576 | 65536 | In: $2.00, Out: $12.00, Cache: $0.20 |
| gemini-3.1-pro-preview-customtools | gemini | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming, caching | 1048576 | 65536 | In: $2.00, Out: $12.00, Cache: $0.20 |
| gemini-embedding-001 | gemini | In: text; Out: embeddings | streaming, batch | 2048 | 3072 | In: $0.15 |
| gemini-flash-latest | gemini | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming, batch, caching | 1048576 | 65536 | In: $0.30, Out: $2.50, Cache: $0.08 |
| gemini-flash-lite-latest | gemini | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming, batch | 1048576 | 65536 | In: $0.10, Out: $0.40, Cache: $0.02 |
| gemini-pro-latest | gemini | In: text, image, pdf, video; Out: text | streaming, function_calling, structured_output, caching | 1048576 | 65536 | In: $0.08, Out: $0.30 |
| gemini-robotics-er-1.5-preview | gemini | In: text, image, pdf, video; Out: text | streaming, function_calling, structured_output, caching | 1048576 | 65536 | In: $0.08, Out: $0.30 |
| gemma-3-12b-it | gemini | In: text; Out: text | streaming | 32768 | 8192 | In: $0.08, Out: $0.30 |
| gemma-3-1b-it | gemini | In: text; Out: text | streaming | 32768 | 8192 | In: $0.08, Out: $0.30 |
| gemma-3-27b-it | gemini | In: text; Out: text | streaming | 131072 | 8192 | In: $0.08, Out: $0.30 |
| gemma-3-4b-it | gemini | In: text; Out: text | streaming | 32768 | 8192 | In: $0.08, Out: $0.30 |
| gemma-3n-e2b-it | gemini | In: text; Out: text | streaming | 8192 | 2048 | In: $0.08, Out: $0.30 |
| gemma-3n-e4b-it | gemini | In: text; Out: text | streaming | 8192 | 2048 | In: $0.08, Out: $0.30 |
| imagen-4.0-generate-001 | gemini | In: text, image, pdf; Out: image | streaming | 480 | 8192 | - |
| imagen-4.0-fast-generate-001 | gemini | In: text, image, pdf; Out: image | streaming | 480 | 8192 | - |
| imagen-4.0-ultra-generate-001 | gemini | In: text, image, pdf; Out: image | streaming | 480 | 8192 | - |
| aqa | gemini | In: text; Out: text | streaming | 7168 | 1024 | - |
| gemini-3-pro-image-preview | gemini | In: text, image, pdf, video; Out: text | streaming, function_calling, structured_output, caching | 131072 | 32768 | In: $0.08, Out: $0.30 |
| nano-banana-pro-preview | gemini | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, caching | 131072 | 32768 | In: $0.08, Out: $0.30 |
| veo-2.0-generate-001 | gemini | In: text; Out: text | streaming | 480 | 8192 | In: $0.08, Out: $0.30 |
| veo-3.0-generate-001 | gemini | In: text; Out: text | streaming | 480 | 8192 | In: $0.08, Out: $0.30 |
| veo-3.0-fast-generate-001 | gemini | In: text; Out: text | streaming | 480 | 8192 | In: $0.08, Out: $0.30 |
| veo-3.1-generate-preview | gemini | In: text; Out: text | streaming | 480 | 8192 | In: $0.08, Out: $0.30 |
| veo-3.1-fast-generate-preview | gemini | In: text; Out: text | streaming | 480 | 8192 | In: $0.08, Out: $0.30 |
| codestral-latest | mistral | In: text; Out: text | function_calling, streaming, structured_output, batch, predicted_outputs | 256000 | 4096 | In: $0.30, Out: $0.90 |
| codestral-2508 | mistral | In: text; Out: text | streaming, function_calling, structured_output, batch, predicted_outputs | 32768 | 8192 | - |
| devstral-medium-latest | mistral | In: text; Out: text | function_calling, streaming, structured_output, batch, fine_tuning | 262144 | 262144 | In: $0.40, Out: $2.00 |
| devstral-2512 | mistral | In: text; Out: text | function_calling, streaming, structured_output, batch, fine_tuning | 262144 | 262144 | In: $0.40, Out: $2.00 |
| devstral-latest | mistral | In: text; Out: text | streaming, function_calling, structured_output, batch, fine_tuning | 32768 | 8192 | - |
| devstral-medium-2507 | mistral | In: text; Out: text | function_calling, streaming, structured_output, batch, fine_tuning | 128000 | 128000 | In: $0.40, Out: $2.00 |
| devstral-small-2507 | mistral | In: text; Out: text | function_calling, streaming, structured_output, batch, fine_tuning | 128000 | 128000 | In: $0.10, Out: $0.30 |
| labs-devstral-small-2512 | mistral | In: text, image; Out: text | function_calling, vision, streaming, structured_output, batch, fine_tuning | 256000 | 256000 | - |
| devstral-small-latest | mistral | In: text; Out: text | streaming, function_calling, structured_output, batch, fine_tuning | 32768 | 8192 | - |
| magistral-medium-latest | mistral | In: text; Out: text | function_calling, reasoning, streaming, structured_output, batch | 128000 | 16384 | In: $2.00, Out: $5.00 |
| magistral-medium-2509 | mistral | In: text; Out: text | streaming, function_calling, structured_output, reasoning, batch | 32768 | 8192 | - |
| magistral-small-2509 | mistral | In: text; Out: text | streaming, function_calling, structured_output, reasoning, batch | 32768 | 8192 | - |
| magistral-small-latest | mistral | In: text; Out: text | streaming, function_calling, structured_output, reasoning, batch | 32768 | 8192 | - |
| ministral-14b-2512 | mistral | In: text; Out: text | streaming, function_calling, structured_output, batch, distillation | 32768 | 8192 | - |
| ministral-14b-latest | mistral | In: text; Out: text | streaming, function_calling, structured_output, batch, distillation | 32768 | 8192 | - |
| ministral-3b-2512 | mistral | In: text; Out: text | streaming, function_calling, structured_output, batch, distillation | 32768 | 8192 | - |
| ministral-3b-latest | mistral | In: text; Out: text | function_calling, streaming, structured_output, batch, distillation | 128000 | 128000 | In: $0.04, Out: $0.04 |
| ministral-8b-latest | mistral | In: text; Out: text | function_calling, streaming, structured_output, batch, distillation | 128000 | 128000 | In: $0.10, Out: $0.10 |
| ministral-8b-2512 | mistral | In: text; Out: text | streaming, function_calling, structured_output, batch, distillation | 32768 | 8192 | - |
| mistral-large-latest | mistral | In: text, image; Out: text | function_calling, vision, streaming, structured_output, batch, fine_tuning | 262144 | 262144 | In: $0.50, Out: $1.50 |
| mistral-large-pixtral-2411 | mistral | In: text, image; Out: text | streaming, function_calling, structured_output, vision, batch, fine_tuning | 32768 | 8192 | - |
| mistral-large-2411 | mistral | In: text; Out: text | function_calling, streaming, structured_output, batch, fine_tuning | 131072 | 16384 | In: $2.00, Out: $6.00 |
| mistral-large-2512 | mistral | In: text, image; Out: text | function_calling, vision, streaming, structured_output, batch, fine_tuning | 262144 | 262144 | In: $0.50, Out: $1.50 |
| mistral-medium-latest | mistral | In: text, image; Out: text | function_calling, vision, streaming, structured_output, batch, fine_tuning | 128000 | 16384 | In: $0.40, Out: $2.00 |
| mistral-medium | mistral | In: text; Out: text | streaming, function_calling, structured_output, vision, batch, fine_tuning | 32768 | 8192 | - |
| mistral-medium-2505 | mistral | In: text, image; Out: text | function_calling, vision, streaming, structured_output, batch, fine_tuning | 131072 | 131072 | In: $0.40, Out: $2.00 |
| mistral-medium-2508 | mistral | In: text, image; Out: text | function_calling, vision, streaming, structured_output, batch, fine_tuning | 262144 | 262144 | In: $0.40, Out: $2.00 |
| labs-mistral-small-creative | mistral | In: text; Out: text | streaming, function_calling, structured_output, batch, fine_tuning | 32768 | 8192 | - |
| mistral-small-2501 | mistral | In: text; Out: text | streaming, function_calling, structured_output, batch, fine_tuning | 32768 | 8192 | - |
| mistral-small-latest | mistral | In: text, image; Out: text | function_calling, vision, streaming, structured_output, batch, fine_tuning | 128000 | 16384 | In: $0.10, Out: $0.30 |
| mistral-small-2506 | mistral | In: text, image; Out: text | function_calling, vision, streaming, structured_output, batch, fine_tuning | 128000 | 16384 | In: $0.10, Out: $0.30 |
| mistral-tiny-2407 | mistral | In: text; Out: text | streaming, function_calling, structured_output, batch | 32768 | 8192 | - |
| mistral-tiny-latest | mistral | In: text; Out: text | streaming, function_calling, structured_output, batch | 32768 | 8192 | - |
| mistral-vibe-cli-latest | mistral | In: text; Out: text | streaming, function_calling, structured_output, batch | 32768 | 8192 | - |
| mistral-vibe-cli-with-tools | mistral | In: text; Out: text | streaming, function_calling, structured_output, batch | 32768 | 8192 | - |
| open-mistral-nemo | mistral | In: text; Out: text | streaming, function_calling, structured_output, batch | 32768 | 8192 | - |
| open-mistral-nemo-2407 | mistral | In: text; Out: text | streaming, function_calling, structured_output, batch | 32768 | 8192 | - |
| pixtral-large-latest | mistral | In: text, image; Out: text | function_calling, vision, streaming, structured_output, batch | 128000 | 128000 | In: $2.00, Out: $6.00 |
| pixtral-large-2411 | mistral | In: text, image; Out: text | streaming, function_calling, structured_output, vision, batch | 32768 | 8192 | - |
| voxtral-mini-2507 | mistral | In: text; Out: text | streaming | 32768 | 8192 | - |
| voxtral-mini-2602 | mistral | In: text; Out: text | streaming | 32768 | 8192 | - |
| voxtral-mini-latest | mistral | In: text; Out: text | streaming | 32768 | 8192 | - |
| voxtral-small-2507 | mistral | In: text; Out: text | streaming | 32768 | 8192 | - |
| voxtral-small-latest | mistral | In: text; Out: text | streaming | 32768 | 8192 | - |
| babbage-002 | openai | In: text; Out: text | streaming | 4096 | 16384 | In: $0.40, Out: $0.40 |
| chatgpt-image-latest | openai | In: text; Out: text, image | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| dall-e-2 | openai | In: text; Out: text, image | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| dall-e-3 | openai | In: text; Out: text, image | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| davinci-002 | openai | In: text; Out: text | streaming | 4096 | 16384 | In: $2.00, Out: $2.00 |
| gpt-3.5-turbo-0125 | openai | In: text; Out: text | streaming | 16385 | 4096 | In: $0.50, Out: $1.50 |
| gpt-3.5-turbo-1106 | openai | In: text; Out: text | streaming | 16385 | 4096 | In: $0.50, Out: $1.50 |
| gpt-3.5-turbo-16k | openai | In: text; Out: text | streaming | 16385 | 4096 | In: $0.50, Out: $1.50 |
| gpt-3.5-turbo-instruct | openai | In: text; Out: text | streaming | 16385 | 4096 | In: $0.50, Out: $1.50 |
| gpt-3.5-turbo-instruct-0914 | openai | In: text; Out: text | streaming | 16385 | 4096 | In: $0.50, Out: $1.50 |
| gpt-3.5-turbo | openai | In: text; Out: text | streaming | 16385 | 4096 | In: $0.50, Out: $1.50, Cache: $1.25 |
| gpt-4 | openai | In: text; Out: text | function_calling, streaming | 8192 | 8192 | In: $30.00, Out: $60.00 |
| gpt-4-0125-preview | openai | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| gpt-4-0613 | openai | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| gpt-4-1106-preview | openai | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| gpt-4-turbo | openai | In: text, image; Out: text | function_calling, vision, streaming | 128000 | 4096 | In: $10.00, Out: $30.00 |
| gpt-4-turbo-2024-04-09 | openai | In: text, image, pdf; Out: text | streaming, function_calling | 128000 | 4096 | In: $10.00, Out: $30.00 |
| gpt-4-turbo-preview | openai | In: text, image, pdf; Out: text | streaming, function_calling | 128000 | 4096 | In: $10.00, Out: $30.00 |
| gpt-4.1 | openai | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 1047576 | 32768 | In: $2.00, Out: $8.00, Cache: $0.50 |
| gpt-4.1-2025-04-14 | openai | In: text, image, pdf; Out: text | streaming, function_calling, structured_output | 1047576 | 32768 | In: $2.00, Out: $8.00, Cache: $0.50 |
| gpt-4.1-mini-2025-04-14 | openai | In: text, image, pdf; Out: text | streaming, function_calling, structured_output | 1047576 | 32768 | In: $0.40, Out: $1.60, Cache: $0.10 |
| gpt-4.1-nano-2025-04-14 | openai | In: text, image, pdf; Out: text | streaming, function_calling, structured_output | 1047576 | 32768 | In: $0.10, Out: $0.40 |
| gpt-4.1-mini | openai | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 1047576 | 32768 | In: $0.40, Out: $1.60, Cache: $0.10 |
| gpt-4.1-nano | openai | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 1047576 | 32768 | In: $0.10, Out: $0.40, Cache: $0.03 |
| gpt-4o | openai | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 128000 | 16384 | In: $2.50, Out: $10.00, Cache: $1.25 |
| gpt-4o-2024-05-13 | openai | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 128000 | 4096 | In: $5.00, Out: $15.00 |
| gpt-4o-2024-08-06 | openai | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 128000 | 16384 | In: $2.50, Out: $10.00, Cache: $1.25 |
| gpt-4o-2024-11-20 | openai | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 128000 | 16384 | In: $2.50, Out: $10.00, Cache: $1.25 |
| gpt-4o-search-preview | openai | In: text, image, pdf; Out: text | streaming | 128000 | 16384 | In: $2.50, Out: $10.00 |
| gpt-4o-search-preview-2025-03-11 | openai | In: text, image, pdf; Out: text | streaming | 128000 | 16384 | In: $2.50, Out: $10.00 |
| gpt-4o-mini | openai | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 128000 | 16384 | In: $0.15, Out: $0.60, Cache: $0.08 |
| gpt-4o-audio-preview | openai | In: text, audio; Out: text, audio | streaming, speech_generation, transcription | 128000 | 16384 | In: $2.50, Out: $10.00 |
| gpt-4o-audio-preview-2024-12-17 | openai | In: text, audio; Out: text, audio | streaming, speech_generation, transcription | 128000 | 16384 | In: $2.50, Out: $10.00 |
| gpt-4o-audio-preview-2025-06-03 | openai | In: text, audio; Out: text, audio | streaming, speech_generation, transcription | 128000 | 16384 | In: $2.50, Out: $10.00 |
| gpt-4o-mini-2024-07-18 | openai | In: text, image, pdf; Out: text | streaming, function_calling, structured_output | 128000 | 16384 | In: $0.15, Out: $0.60 |
| gpt-4o-mini-audio-preview | openai | In: text, audio; Out: text, audio | streaming, speech_generation, transcription | 128000 | 16384 | In: $0.15, Out: $0.60 |
| gpt-4o-mini-audio-preview-2024-12-17 | openai | In: text, audio; Out: text, audio | streaming, speech_generation, transcription | 128000 | 16384 | In: $0.15, Out: $0.60 |
| gpt-4o-mini-realtime-preview | openai | In: text; Out: text | streaming | 128000 | 4096 | In: $0.60, Out: $2.40 |
| gpt-4o-mini-realtime-preview-2024-12-17 | openai | In: text; Out: text | streaming | 128000 | 4096 | In: $0.60, Out: $2.40 |
| gpt-4o-mini-search-preview | openai | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| gpt-4o-mini-search-preview-2025-03-11 | openai | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| gpt-4o-mini-transcribe | openai | In: text, audio; Out: text | streaming | 16000 | 2000 | In: $1.25, Out: $5.00 |
| gpt-4o-mini-transcribe-2025-03-20 | openai | In: text, audio; Out: text | streaming | 16000 | 2000 | In: $1.25, Out: $5.00 |
| gpt-4o-mini-transcribe-2025-12-15 | openai | In: text, audio; Out: text | streaming | 16000 | 2000 | In: $1.25, Out: $5.00 |
| gpt-4o-mini-tts | openai | In: text, audio; Out: text, audio | streaming | - | - | In: $0.60, Out: $12.00 |
| gpt-4o-mini-tts-2025-03-20 | openai | In: text, audio; Out: text, audio | streaming | - | - | In: $0.60, Out: $12.00 |
| gpt-4o-mini-tts-2025-12-15 | openai | In: text, audio; Out: text, audio | streaming | - | - | In: $0.60, Out: $12.00 |
| gpt-4o-realtime-preview | openai | In: text; Out: text | streaming | 128000 | 4096 | In: $5.00, Out: $20.00 |
| gpt-4o-realtime-preview-2024-12-17 | openai | In: text; Out: text | streaming | 128000 | 4096 | In: $5.00, Out: $20.00 |
| gpt-4o-realtime-preview-2025-06-03 | openai | In: text; Out: text | streaming | 128000 | 4096 | In: $5.00, Out: $20.00 |
| gpt-4o-transcribe | openai | In: text, audio; Out: text | streaming | 128000 | 16384 | In: $2.50, Out: $10.00 |
| gpt-4o-transcribe-diarize | openai | In: text, audio; Out: text | streaming | 128000 | 16384 | In: $2.50, Out: $10.00 |
| gpt-5 | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5-2025-08-07 | openai | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5-chat-latest | openai | In: text, image; Out: text | structured_output, reasoning, vision, streaming, function_calling | 400000 | 128000 | In: $1.25, Out: $10.00 |
| gpt-5-mini | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $0.25, Out: $2.00, Cache: $0.02 |
| gpt-5-mini-2025-08-07 | openai | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5-nano | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $0.05, Out: $0.40, Cache: $0.01 |
| gpt-5-nano-2025-08-07 | openai | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5-pro | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 272000 | In: $15.00, Out: $120.00 |
| gpt-5-pro-2025-10-06 | openai | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5-search-api | openai | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5-search-api-2025-10-14 | openai | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5-codex | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5.1 | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $1.25, Out: $10.00, Cache: $0.13 |
| gpt-5.1-2025-11-13 | openai | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5.1-chat-latest | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 128000 | 16384 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5.1-codex | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5.1-codex-max | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5.1-codex-mini | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $0.25, Out: $2.00, Cache: $0.02 |
| gpt-5.2 | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $1.75, Out: $14.00, Cache: $0.18 |
| gpt-5.2-2025-12-11 | openai | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5.2-chat-latest | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 128000 | 16384 | In: $1.75, Out: $14.00, Cache: $0.18 |
| gpt-5.2-codex | openai | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $1.75, Out: $14.00, Cache: $0.18 |
| gpt-5.2-pro | openai | In: text, image; Out: text | function_calling, reasoning, vision, streaming, structured_output | 400000 | 128000 | In: $21.00, Out: $168.00 |
| gpt-5.2-pro-2025-12-11 | openai | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5.3-codex | openai | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $1.75, Out: $14.00, Cache: $0.18 |
| gpt-audio | openai | In: text, audio; Out: text, audio | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| gpt-audio-1.5 | openai | In: text, audio; Out: text, audio | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| gpt-audio-2025-08-28 | openai | In: text, audio; Out: text, audio | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| gpt-audio-mini | openai | In: text, audio; Out: text, audio | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| gpt-audio-mini-2025-10-06 | openai | In: text, audio; Out: text, audio | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| gpt-audio-mini-2025-12-15 | openai | In: text, audio; Out: text, audio | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| gpt-image-1 | openai | In: text; Out: text, image | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| gpt-image-1-mini | openai | In: text; Out: text, image | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| gpt-image-1.5 | openai | In: text; Out: text, image | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| gpt-realtime | openai | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| gpt-realtime-1.5 | openai | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| gpt-realtime-2025-08-28 | openai | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| gpt-realtime-mini | openai | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| gpt-realtime-mini-2025-10-06 | openai | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| gpt-realtime-mini-2025-12-15 | openai | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| o1-2024-12-17 | openai | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 200000 | 100000 | In: $15.00, Out: $60.00 |
| o1-pro-2025-03-19 | openai | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 200000 | 100000 | In: $150.00, Out: $600.00 |
| o3-2025-04-16 | openai | In: text; Out: text | streaming, reasoning | 4096 | 16384 | In: $0.50, Out: $1.50 |
| o3-deep-research-2025-06-26 | openai | In: text; Out: text | streaming, reasoning | 4096 | 16384 | In: $0.50, Out: $1.50 |
| o3-mini-2025-01-31 | openai | In: text; Out: text | streaming, function_calling, structured_output, reasoning | 200000 | 100000 | In: $1.10, Out: $4.40 |
| o3-pro-2025-06-10 | openai | In: text; Out: text | streaming, reasoning | 4096 | 16384 | In: $0.50, Out: $1.50 |
| o4-mini-2025-04-16 | openai | In: text; Out: text | streaming, reasoning | 4096 | 16384 | In: $0.50, Out: $1.50 |
| o4-mini-deep-research-2025-06-26 | openai | In: text; Out: text | streaming, reasoning | 4096 | 16384 | In: $0.50, Out: $1.50 |
| sora-2 | openai | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| sora-2-pro | openai | In: text; Out: text | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| tts-1 | openai | In: text, audio; Out: text, audio | streaming | - | - | In: $15.00, Out: $15.00 |
| tts-1-1106 | openai | In: text, audio; Out: text, audio | streaming | - | - | In: $15.00, Out: $15.00 |
| tts-1-hd | openai | In: text, audio; Out: text, audio | streaming | - | - | In: $30.00, Out: $30.00 |
| tts-1-hd-1106 | openai | In: text, audio; Out: text, audio | streaming | - | - | In: $30.00, Out: $30.00 |
| whisper-1 | openai | In: text, audio; Out: text | streaming | - | - | In: $0.01, Out: $0.01 |
| o1 | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 100000 | In: $15.00, Out: $60.00, Cache: $7.50 |
| o1-pro | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 100000 | In: $150.00, Out: $600.00 |
| o3 | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 100000 | In: $2.00, Out: $8.00, Cache: $0.50 |
| o3-deep-research | openai | In: text, image; Out: text | function_calling, reasoning, vision, streaming | 200000 | 100000 | In: $10.00, Out: $40.00, Cache: $2.50 |
| o3-mini | openai | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 200000 | 100000 | In: $1.10, Out: $4.40, Cache: $0.55 |
| o3-pro | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 100000 | In: $20.00, Out: $80.00 |
| o4-mini | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 100000 | In: $1.10, Out: $4.40, Cache: $0.28 |
| o4-mini-deep-research | openai | In: text, image; Out: text | function_calling, reasoning, vision, streaming | 200000 | 100000 | In: $2.00, Out: $8.00, Cache: $0.50 |
| ai21/jamba-large-1.7 | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 256000 | 4096 | In: $2.00, Out: $8.00 |
| aion-labs/aion-1.0 | openrouter | In: text; Out: text | streaming | 131072 | 32768 | In: $4.00, Out: $8.00 |
| aion-labs/aion-1.0-mini | openrouter | In: text; Out: text | streaming | 131072 | 32768 | In: $0.70, Out: $1.40 |
| aion-labs/aion-2.0 | openrouter | In: text; Out: text | streaming | 131072 | 32768 | In: $0.80, Out: $1.60 |
| aion-labs/aion-rp-llama-3.1-8b | openrouter | In: text; Out: text | streaming | 32768 | 32768 | In: $0.80, Out: $1.60 |
| alfredpros/codellama-7b-instruct-solidity | openrouter | In: text; Out: text | streaming | 4096 | 4096 | In: $0.80, Out: $1.20 |
| allenai/molmo-2-8b | openrouter | In: text, image, video; Out: text | streaming, predicted_outputs | 36864 | 36864 | In: $0.20, Out: $0.20 |
| allenai/olmo-2-0325-32b-instruct | openrouter | In: text; Out: text | streaming | 128000 | - | In: $0.05, Out: $0.20 |
| allenai/olmo-3-32b-think | openrouter | In: text; Out: text | streaming, structured_output, predicted_outputs | 65536 | 65536 | In: $0.15, Out: $0.50 |
| allenai/olmo-3-7b-instruct | openrouter | In: text; Out: text | streaming, structured_output, predicted_outputs | 65536 | 65536 | In: $0.10, Out: $0.20 |
| allenai/olmo-3-7b-think | openrouter | In: text; Out: text | streaming, structured_output, predicted_outputs | 65536 | 65536 | In: $0.12, Out: $0.20 |
| allenai/olmo-3.1-32b-instruct | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 65536 | - | In: $0.20, Out: $0.60 |
| allenai/olmo-3.1-32b-think | openrouter | In: text; Out: text | streaming, structured_output, predicted_outputs | 65536 | 65536 | In: $0.15, Out: $0.50 |
| amazon/nova-2-lite-v1 | openrouter | In: text, image, video, file; Out: text | streaming, function_calling | 1000000 | 65535 | In: $0.30, Out: $2.50 |
| amazon/nova-lite-v1 | openrouter | In: text, image; Out: text | streaming, function_calling | 300000 | 5120 | In: $0.06, Out: $0.24 |
| amazon/nova-micro-v1 | openrouter | In: text; Out: text | streaming, function_calling | 128000 | 5120 | In: $0.04, Out: $0.14 |
| amazon/nova-premier-v1 | openrouter | In: text, image; Out: text | streaming, function_calling | 1000000 | 32000 | In: $2.50, Out: $12.50, Cache: $0.62 |
| amazon/nova-pro-v1 | openrouter | In: text, image; Out: text | streaming, function_calling | 300000 | 5120 | In: $0.80, Out: $3.20 |
| anthropic/claude-3-haiku | openrouter | In: text, image; Out: text | streaming, function_calling | 200000 | 4096 | In: $0.25, Out: $1.25, Cache: $0.03 |
| anthropic/claude-3.5-sonnet | openrouter | In: text, image, file; Out: text | streaming, function_calling | 200000 | 8192 | In: $6.00, Out: $30.00, Cache: $0.60 |
| anthropic/claude-3.7-sonnet:thinking | openrouter | In: text, image, file; Out: text | streaming, function_calling | 200000 | 64000 | In: $3.00, Out: $15.00, Cache: $0.30 |
| arcee-ai/coder-large | openrouter | In: text; Out: text | streaming, predicted_outputs | 32768 | - | In: $0.50, Out: $0.80 |
| arcee-ai/maestro-reasoning | openrouter | In: text; Out: text | streaming, predicted_outputs | 131072 | 32000 | In: $0.90, Out: $3.30 |
| arcee-ai/spotlight | openrouter | In: image, text; Out: text | streaming, predicted_outputs | 131072 | 65537 | In: $0.18, Out: $0.18 |
| arcee-ai/trinity-mini | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 131072 | 131072 | In: $0.04, Out: $0.15 |
| arcee-ai/virtuoso-large | openrouter | In: text; Out: text | streaming, function_calling, predicted_outputs | 131072 | 64000 | In: $0.75, Out: $1.20 |
| openrouter/auto | openrouter | In: text, image, audio, file, video; Out: text, image | streaming, function_calling, structured_output, predicted_outputs | 2000000 | - | - |
| baidu/ernie-4.5-21b-a3b | openrouter | In: text; Out: text | streaming, function_calling | 120000 | 8000 | In: $0.07, Out: $0.28 |
| baidu/ernie-4.5-21b-a3b-thinking | openrouter | In: text; Out: text | streaming | 131072 | 65536 | In: $0.07, Out: $0.28 |
| baidu/ernie-4.5-300b-a47b | openrouter | In: text; Out: text | streaming, structured_output | 123000 | 12000 | In: $0.28, Out: $1.10 |
| baidu/ernie-4.5-vl-28b-a3b | openrouter | In: text, image; Out: text | streaming, function_calling | 30000 | 8000 | In: $0.14, Out: $0.56 |
| baidu/ernie-4.5-vl-424b-a47b | openrouter | In: image, text; Out: text | streaming | 123000 | 16000 | In: $0.42, Out: $1.25 |
| openrouter/bodybuilder | openrouter | In: text; Out: text | streaming | 128000 | - | - |
| bytedance-seed/seed-1.6 | openrouter | In: image, text, video; Out: text | streaming, function_calling, structured_output | 262144 | 32768 | In: $0.25, Out: $2.00 |
| bytedance-seed/seed-1.6-flash | openrouter | In: image, text, video; Out: text | streaming, function_calling, structured_output | 262144 | 32768 | In: $0.08, Out: $0.30 |
| bytedance/ui-tars-1.5-7b | openrouter | In: image, text; Out: text | streaming, predicted_outputs | 128000 | 2048 | In: $0.10, Out: $0.20 |
| anthropic/claude-3.5-haiku | openrouter | In: text, image, pdf; Out: text | function_calling, vision, streaming | 200000 | 8192 | In: $0.80, Out: $4.00, Cache: $0.08 |
| anthropic/claude-haiku-4.5 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 64000 | In: $1.00, Out: $5.00, Cache: $0.10 |
| anthropic/claude-opus-4 | openrouter | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 32000 | In: $15.00, Out: $75.00, Cache: $1.50 |
| anthropic/claude-opus-4.1 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 32000 | In: $15.00, Out: $75.00, Cache: $1.50 |
| anthropic/claude-opus-4.5 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 32000 | In: $5.00, Out: $25.00, Cache: $0.50 |
| anthropic/claude-opus-4.6 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache: $0.50 |
| anthropic/claude-3.7-sonnet | openrouter | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 128000 | In: $15.00, Out: $75.00, Cache: $1.50 |
| anthropic/claude-sonnet-4 | openrouter | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 64000 | In: $3.00, Out: $15.00, Cache: $0.30 |
| anthropic/claude-sonnet-4.5 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 64000 | In: $3.00, Out: $15.00, Cache: $0.30 |
| anthropic/claude-sonnet-4.6 | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 128000 | In: $3.00, Out: $15.00, Cache: $0.30 |
| mistralai/codestral-2508 | openrouter | In: text; Out: text | function_calling, structured_output, streaming | 256000 | 256000 | In: $0.30, Out: $0.90 |
| cohere/command-a | openrouter | In: text; Out: text | streaming, structured_output | 256000 | 8192 | In: $2.50, Out: $10.00 |
| cohere/command-r-08-2024 | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 128000 | 4000 | In: $0.15, Out: $0.60 |
| cohere/command-r-plus-08-2024 | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 128000 | 4000 | In: $2.50, Out: $10.00 |
| cohere/command-r7b-12-2024 | openrouter | In: text; Out: text | streaming, structured_output | 128000 | 4000 | In: $0.04, Out: $0.15 |
| deepcogito/cogito-v2.1-671b | openrouter | In: text; Out: text | streaming, structured_output, predicted_outputs | 128000 | - | In: $1.25, Out: $1.25 |
| deepseek/deepseek-r1-distill-llama-70b | openrouter | In: text; Out: text | structured_output, reasoning, streaming, predicted_outputs | 8192 | 8192 | In: $0.70, Out: $0.80 |
| deepseek/deepseek-chat-v3-0324 | openrouter | In: text; Out: text | structured_output, streaming, function_calling, predicted_outputs | 16384 | 8192 | In: $0.19, Out: $0.87, Cache: $0.10 |
| deepseek/deepseek-v3.1-terminus | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 131072 | 65536 | In: $0.27, Out: $1.00 |
| deepseek/deepseek-v3.1-terminus:exacto | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 131072 | 65536 | In: $0.27, Out: $1.00 |
| deepseek/deepseek-v3.2 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 163840 | 65536 | In: $0.28, Out: $0.40 |
| deepseek/deepseek-v3.2-speciale | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 163840 | 65536 | In: $0.27, Out: $0.41 |
| deepseek/deepseek-chat-v3.1 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 163840 | 163840 | In: $0.20, Out: $0.80 |
| deepseek/deepseek-chat | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 163840 | 163840 | In: $0.32, Out: $0.89 |
| deepseek/deepseek-v3.2-exp | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 163840 | 65536 | In: $0.27, Out: $0.41 |
| deepseek/deepseek-r1 | openrouter | In: text; Out: text | streaming, function_calling | 64000 | 16000 | In: $0.70, Out: $2.50 |
| deepseek/deepseek-r1-0528 | openrouter | In: text; Out: text | streaming, function_calling, structured_output, predicted_outputs | 163840 | 65536 | In: $0.40, Out: $1.75, Cache: $0.20 |
| deepseek/deepseek-r1-distill-qwen-32b | openrouter | In: text; Out: text | streaming, structured_output | 32768 | 32768 | In: $0.29, Out: $0.29 |
| mistralai/devstral-2512 | openrouter | In: text; Out: text | function_calling, structured_output, streaming | 262144 | 262144 | In: $0.15, Out: $0.60 |
| eleutherai/llemma_7b | openrouter | In: text; Out: text | streaming | 4096 | 4096 | In: $0.80, Out: $1.20 |
| essentialai/rnj-1-instruct | openrouter | In: text; Out: text | streaming, structured_output, predicted_outputs | 32768 | - | In: $0.15, Out: $0.15 |
| openrouter/free | openrouter | In: text, image; Out: text | streaming, function_calling, structured_output | 200000 | - | - |
| z-ai/glm-4.5 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 128000 | 96000 | In: $0.60, Out: $2.20 |
| z-ai/glm-4.5-air | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 128000 | 96000 | In: $0.20, Out: $1.10 |
| z-ai/glm-4.5-air:free | openrouter | In: text; Out: text | reasoning, streaming, function_calling | 128000 | 96000 | - |
| z-ai/glm-4.5v | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, streaming | 64000 | 16384 | In: $0.60, Out: $1.80 |
| z-ai/glm-4.6 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 200000 | 128000 | In: $0.60, Out: $2.20, Cache: $0.11 |
| z-ai/glm-4.6:exacto | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 200000 | 128000 | In: $0.60, Out: $1.90, Cache: $0.11 |
| z-ai/glm-4.7 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 204800 | 131072 | In: $0.60, Out: $2.20, Cache: $0.11 |
| z-ai/glm-4.7-flash | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 200000 | 65535 | In: $0.07, Out: $0.40 |
| z-ai/glm-5 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 202752 | 131000 | In: $1.00, Out: $3.20, Cache: $0.20 |
| openai/gpt-oss-120b | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 131072 | 32768 | In: $0.07, Out: $0.28 |
| openai/gpt-oss-120b:exacto | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 131072 | 32768 | In: $0.05, Out: $0.24 |
| openai/gpt-oss-20b | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 131072 | 32768 | In: $0.05, Out: $0.20 |
| openai/gpt-oss-safeguard-20b | openrouter | In: text; Out: text | function_calling, reasoning, streaming, structured_output | 131072 | 65536 | In: $0.08, Out: $0.30 |
| openai/gpt-4.1 | openrouter | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 1047576 | 32768 | In: $2.00, Out: $8.00, Cache: $0.50 |
| openai/gpt-4.1-mini | openrouter | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 1047576 | 32768 | In: $0.40, Out: $1.60, Cache: $0.10 |
| openai/gpt-4o-mini | openrouter | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 128000 | 16384 | In: $0.15, Out: $0.60, Cache: $0.08 |
| openai/gpt-5 | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $1.25, Out: $10.00 |
| openai/gpt-5-chat | openrouter | In: text, image; Out: text | structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $1.25, Out: $10.00 |
| openai/gpt-5-codex | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| openai/gpt-5-image | openrouter | In: text, image, pdf; Out: text, image | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $5.00, Out: $10.00, Cache: $1.25 |
| openai/gpt-5-mini | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $0.25, Out: $2.00 |
| openai/gpt-5-nano | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $0.05, Out: $0.40 |
| openai/gpt-5-pro | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 272000 | In: $15.00, Out: $120.00 |
| openai/gpt-5.1 | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| openai/gpt-5.1-chat | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 128000 | 16384 | In: $1.25, Out: $10.00, Cache: $0.12 |
| openai/gpt-5.1-codex | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| openai/gpt-5.1-codex-max | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $1.10, Out: $9.00, Cache: $0.11 |
| openai/gpt-5.1-codex-mini | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 100000 | In: $0.25, Out: $2.00, Cache: $0.02 |
| openai/gpt-5.2 | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $1.75, Out: $14.00, Cache: $0.18 |
| openai/gpt-5.2-chat | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 128000 | 16384 | In: $1.75, Out: $14.00, Cache: $0.18 |
| openai/gpt-5.2-pro | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $21.00, Out: $168.00 |
| openai/gpt-5.2-codex | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $1.75, Out: $14.00, Cache: $0.18 |
| google/gemini-2.0-flash-001 | openrouter | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, vision, streaming | 1048576 | 8192 | In: $0.10, Out: $0.40, Cache: $0.02 |
| google/gemini-2.5-flash | openrouter | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1048576 | 65536 | In: $0.30, Out: $2.50, Cache: $0.04 |
| google/gemini-2.5-flash-lite | openrouter | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1048576 | 65536 | In: $0.10, Out: $0.40, Cache: $0.02 |
| google/gemini-2.5-flash-lite-preview-09-2025 | openrouter | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1048576 | 65536 | In: $0.10, Out: $0.40, Cache: $0.02 |
| google/gemini-2.5-pro | openrouter | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1048576 | 65536 | In: $1.25, Out: $10.00, Cache: $0.31 |
| google/gemini-2.5-pro-preview-05-06 | openrouter | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1048576 | 65536 | In: $1.25, Out: $10.00, Cache: $0.31 |
| google/gemini-3-flash-preview | openrouter | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1048576 | 65536 | In: $0.50, Out: $3.00, Cache: $0.05 |
| google/gemini-3-pro-preview | openrouter | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1050000 | 66000 | In: $2.00, Out: $12.00 |
| google/gemini-3.1-pro-preview | openrouter | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1048576 | 65536 | In: $2.00, Out: $12.00 |
| google/gemma-2-9b-it | openrouter | In: text; Out: text | streaming | 8192 | 8192 | In: $0.03, Out: $0.09 |
| google/gemma-3-12b-it | openrouter | In: text, image; Out: text | structured_output, vision, streaming, predicted_outputs | 131072 | 131072 | In: $0.03, Out: $0.10 |
| google/gemma-3-12b-it:free | openrouter | In: text, image; Out: text | vision, streaming | 32768 | 8192 | - |
| google/gemma-3-27b-it | openrouter | In: text, image; Out: text | function_calling, structured_output, vision, streaming, predicted_outputs | 96000 | 96000 | In: $0.04, Out: $0.15 |
| google/gemma-3-27b-it:free | openrouter | In: text, image; Out: text | function_calling, vision, streaming, structured_output | 131072 | 8192 | - |
| google/gemma-3-4b-it | openrouter | In: text, image; Out: text | vision, streaming, structured_output | 96000 | 96000 | In: $0.02, Out: $0.07 |
| google/gemma-3-4b-it:free | openrouter | In: text, image; Out: text | vision, streaming, structured_output | 32768 | 8192 | - |
| google/gemma-3n-e2b-it:free | openrouter | In: text; Out: text | streaming, structured_output | 8192 | 2000 | - |
| google/gemma-3n-e4b-it | openrouter | In: text; Out: text | streaming, predicted_outputs | 32768 | 32768 | In: $0.02, Out: $0.04 |
| google/gemma-3n-e4b-it:free | openrouter | In: text; Out: text | streaming, structured_output | 8192 | 2000 | - |
| alpindale/goliath-120b | openrouter | In: text; Out: text | streaming, structured_output, predicted_outputs | 6144 | 1024 | In: $3.75, Out: $7.50 |
| google/gemini-2.0-flash-lite-001 | openrouter | In: text, image, file, audio, video; Out: text | streaming, function_calling, structured_output | 1048576 | 8192 | In: $0.08, Out: $0.30 |
| google/gemini-2.5-flash-image | openrouter | In: image, text; Out: image, text | streaming, structured_output | 32768 | 32768 | In: $0.30, Out: $2.50, Cache: $0.03 |
| google/gemini-2.5-pro-preview | openrouter | In: file, image, text, audio; Out: text | streaming, function_calling, structured_output | 1048576 | 65536 | In: $1.25, Out: $10.00, Cache: $0.12 |
| google/gemma-2-27b-it | openrouter | In: text; Out: text | streaming, structured_output | 8192 | 2048 | In: $0.65, Out: $0.65 |
| google/gemini-3-pro-image-preview | openrouter | In: image, text; Out: image, text | streaming, structured_output | 65536 | 32768 | In: $2.00, Out: $12.00, Cache: $0.20 |
| x-ai/grok-3 | openrouter | In: text; Out: text | function_calling, structured_output, streaming | 131072 | 8192 | In: $3.00, Out: $15.00, Cache: $0.75 |
| x-ai/grok-3-beta | openrouter | In: text; Out: text | function_calling, streaming, structured_output | 131072 | 8192 | In: $3.00, Out: $15.00, Cache: $0.75 |
| x-ai/grok-3-mini | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 131072 | 8192 | In: $0.30, Out: $0.50, Cache: $0.08 |
| x-ai/grok-3-mini-beta | openrouter | In: text; Out: text | function_calling, reasoning, streaming, structured_output | 131072 | 8192 | In: $0.30, Out: $0.50, Cache: $0.08 |
| x-ai/grok-4 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 256000 | 64000 | In: $3.00, Out: $15.00, Cache: $0.75 |
| x-ai/grok-4-fast | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 2000000 | 30000 | In: $0.20, Out: $0.50, Cache: $0.05 |
| x-ai/grok-4.1-fast | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 2000000 | 30000 | In: $0.20, Out: $0.50, Cache: $0.05 |
| x-ai/grok-code-fast-1 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 256000 | 10000 | In: $0.20, Out: $1.50, Cache: $0.02 |
| nousresearch/hermes-3-llama-3.1-405b:free | openrouter | In: text; Out: text | reasoning, streaming | 131072 | 131072 | - |
| nousresearch/hermes-4-405b | openrouter | In: text; Out: text | function_calling, reasoning, streaming, structured_output | 131072 | 131072 | In: $1.00, Out: $3.00 |
| nousresearch/hermes-4-70b | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 131072 | 131072 | In: $0.13, Out: $0.40 |
| ibm-granite/granite-4.0-h-micro | openrouter | In: text; Out: text | streaming | 131000 | - | In: $0.02, Out: $0.11 |
| inception/mercury | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 128000 | 16384 | In: $0.25, Out: $1.00 |
| inception/mercury-coder | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 128000 | 16384 | In: $0.25, Out: $1.00 |
| inflection/inflection-3-pi | openrouter | In: text; Out: text | streaming | 8000 | 1024 | In: $2.50, Out: $10.00 |
| inflection/inflection-3-productivity | openrouter | In: text; Out: text | streaming | 8000 | 1024 | In: $2.50, Out: $10.00 |
| prime-intellect/intellect-3 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 131072 | 8192 | In: $0.20, Out: $1.10 |
| moonshotai/kimi-k2 | openrouter | In: text; Out: text | function_calling, streaming, structured_output | 131072 | 32768 | In: $0.55, Out: $2.20 |
| moonshotai/kimi-k2-0905 | openrouter | In: text; Out: text | function_calling, structured_output, streaming, predicted_outputs | 262144 | 16384 | In: $0.60, Out: $2.50 |
| moonshotai/kimi-k2-0905:exacto | openrouter | In: text; Out: text | function_calling, structured_output, streaming | 262144 | 16384 | In: $0.60, Out: $2.50 |
| moonshotai/kimi-k2-thinking | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 262144 | 262144 | In: $0.60, Out: $2.50, Cache: $0.15 |
| moonshotai/kimi-k2.5 | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, streaming, predicted_outputs | 262144 | 262144 | In: $0.60, Out: $3.00, Cache: $0.10 |
| kwaipilot/kat-coder-pro | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 256000 | 128000 | In: $0.21, Out: $0.83, Cache: $0.04 |
| liquid/lfm-2.5-1.2b-instruct:free | openrouter | In: text; Out: text | streaming | 131072 | 32768 | - |
| liquid/lfm-2.5-1.2b-thinking:free | openrouter | In: text; Out: text | reasoning, streaming | 131072 | 32768 | - |
| liquid/lfm-2.2-6b | openrouter | In: text; Out: text | streaming | 32768 | - | In: $0.01, Out: $0.02 |
| liquid/lfm2-8b-a1b | openrouter | In: text; Out: text | streaming | 32768 | - | In: $0.01, Out: $0.02 |
| meta-llama/llama-3.2-11b-vision-instruct | openrouter | In: text, image; Out: text | vision, streaming, structured_output, predicted_outputs | 131072 | 8192 | In: $0.05, Out: $0.05 |
| meta-llama/llama-3.2-3b-instruct:free | openrouter | In: text, image; Out: text | vision, streaming | 131072 | 131072 | - |
| meta-llama/llama-3.3-70b-instruct:free | openrouter | In: text; Out: text | function_calling, structured_output, streaming | 131072 | 131072 | - |
| meta-llama/llama-guard-3-8b | openrouter | In: text; Out: text | streaming | 131072 | - | In: $0.02, Out: $0.06 |
| anthracite-org/magnum-v4-72b | openrouter | In: text; Out: text | streaming, structured_output, predicted_outputs | 16384 | 2048 | In: $3.00, Out: $5.00 |
| mancer/weaver | openrouter | In: text; Out: text | streaming, structured_output, predicted_outputs | 8000 | 2000 | In: $0.75, Out: $1.00 |
| meituan/longcat-flash-chat | openrouter | In: text; Out: text | streaming | 131072 | 32768 | In: $0.20, Out: $0.80, Cache: $0.20 |
| meta-llama/llama-3-70b-instruct | openrouter | In: text; Out: text | streaming, structured_output | 8192 | 8000 | In: $0.51, Out: $0.74 |
| meta-llama/llama-3-8b-instruct | openrouter | In: text; Out: text | streaming, function_calling, structured_output, predicted_outputs | 8192 | 16384 | In: $0.03, Out: $0.04 |
| meta-llama/llama-3.1-405b | openrouter | In: text; Out: text | streaming, predicted_outputs | 32768 | 32768 | In: $4.00, Out: $4.00 |
| meta-llama/llama-3.1-405b-instruct | openrouter | In: text; Out: text | streaming, function_calling, structured_output, predicted_outputs | 131000 | - | In: $4.00, Out: $4.00 |
| meta-llama/llama-3.1-70b-instruct | openrouter | In: text; Out: text | streaming, function_calling, structured_output, predicted_outputs | 131072 | - | In: $0.40, Out: $0.40 |
| meta-llama/llama-3.1-8b-instruct | openrouter | In: text; Out: text | streaming, function_calling, structured_output, predicted_outputs | 16384 | 16384 | In: $0.02, Out: $0.05 |
| meta-llama/llama-3.2-1b-instruct | openrouter | In: text; Out: text | streaming | 60000 | - | In: $0.03, Out: $0.20 |
| meta-llama/llama-3.2-3b-instruct | openrouter | In: text; Out: text | streaming, structured_output, predicted_outputs | 131072 | 16384 | In: $0.02, Out: $0.02 |
| meta-llama/llama-3.3-70b-instruct | openrouter | In: text; Out: text | streaming, function_calling, structured_output, predicted_outputs | 131072 | 16384 | In: $0.10, Out: $0.32 |
| meta-llama/llama-4-maverick | openrouter | In: text, image; Out: text | streaming, function_calling, structured_output, predicted_outputs | 1048576 | 16384 | In: $0.15, Out: $0.60 |
| meta-llama/llama-4-scout | openrouter | In: text, image; Out: text | streaming, function_calling, structured_output | 327680 | 16384 | In: $0.08, Out: $0.30 |
| meta-llama/llama-guard-4-12b | openrouter | In: image, text; Out: text | streaming, structured_output, predicted_outputs | 163840 | - | In: $0.18, Out: $0.18 |
| meta-llama/llama-guard-2-8b | openrouter | In: text; Out: text | streaming, predicted_outputs | 8192 | - | In: $0.20, Out: $0.20 |
| xiaomi/mimo-v2-flash | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 262144 | 65536 | In: $0.10, Out: $0.30, Cache: $0.01 |
| microsoft/phi-4 | openrouter | In: text; Out: text | streaming, structured_output | 16384 | 16384 | In: $0.06, Out: $0.14 |
| minimax/minimax-m1 | openrouter | In: text; Out: text | function_calling, reasoning, streaming | 1000000 | 40000 | In: $0.40, Out: $2.20 |
| minimax/minimax-m2 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 196600 | 118000 | In: $0.28, Out: $1.15, Cache: $0.28 |
| minimax/minimax-m2.1 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 204800 | 131072 | In: $0.30, Out: $1.20 |
| minimax/minimax-m2.5 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 204800 | 131072 | In: $0.30, Out: $1.20, Cache: $0.03 |
| minimax/minimax-01 | openrouter | In: text, image; Out: text | function_calling, reasoning, vision, streaming | 1000000 | 1000000 | In: $0.20, Out: $1.10 |
| minimax/minimax-m2-her | openrouter | In: text; Out: text | streaming | 65536 | 2048 | In: $0.30, Out: $1.20, Cache: $0.03 |
| mistralai/mistral-large | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 128000 | - | In: $2.00, Out: $6.00 |
| mistralai/mistral-large-2407 | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 131072 | - | In: $2.00, Out: $6.00 |
| mistralai/mistral-large-2411 | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 131072 | - | In: $2.00, Out: $6.00 |
| mistralai/mistral-medium-3 | openrouter | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 131072 | 131072 | In: $0.40, Out: $2.00 |
| mistralai/mistral-medium-3.1 | openrouter | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 262144 | 262144 | In: $0.40, Out: $2.00 |
| mistralai/mistral-small-3.1-24b-instruct | openrouter | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 128000 | 8192 | In: $0.35, Out: $0.56 |
| mistralai/mistral-small-3.2-24b-instruct | openrouter | In: text, image; Out: text | function_calling, structured_output, vision, streaming, predicted_outputs | 96000 | 8192 | In: $0.06, Out: $0.18, Cache: $0.03 |
| mistralai/devstral-medium | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 131072 | - | In: $0.40, Out: $2.00 |
| mistralai/devstral-small | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 131072 | - | In: $0.10, Out: $0.30 |
| mistralai/ministral-14b-2512 | openrouter | In: text, image; Out: text | streaming, function_calling, structured_output, predicted_outputs | 262144 | - | In: $0.20, Out: $0.20 |
| mistralai/ministral-3b-2512 | openrouter | In: text, image; Out: text | streaming, function_calling, structured_output | 131072 | - | In: $0.10, Out: $0.10 |
| mistralai/ministral-8b-2512 | openrouter | In: text, image; Out: text | streaming, function_calling, structured_output | 262144 | - | In: $0.15, Out: $0.15 |
| mistralai/mistral-7b-instruct | openrouter | In: text; Out: text | streaming, predicted_outputs | 32768 | 4096 | In: $0.20, Out: $0.20 |
| mistralai/mistral-7b-instruct-v0.1 | openrouter | In: text; Out: text | streaming | 2824 | - | In: $0.11, Out: $0.19 |
| mistralai/mistral-7b-instruct-v0.2 | openrouter | In: text; Out: text | streaming, predicted_outputs | 32768 | - | In: $0.20, Out: $0.20 |
| mistralai/mistral-7b-instruct-v0.3 | openrouter | In: text; Out: text | streaming, predicted_outputs | 32768 | 4096 | In: $0.20, Out: $0.20 |
| mistralai/mistral-large-2512 | openrouter | In: text, image; Out: text | streaming, function_calling, structured_output | 262144 | - | In: $0.50, Out: $1.50 |
| mistralai/mistral-nemo | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 131072 | 16384 | In: $0.02, Out: $0.04 |
| mistralai/mistral-small-24b-instruct-2501 | openrouter | In: text; Out: text | streaming, function_calling, structured_output, predicted_outputs | 32768 | 16384 | In: $0.05, Out: $0.08 |
| mistralai/mistral-small-3.1-24b-instruct:free | openrouter | In: text, image; Out: text | streaming, function_calling, structured_output | 128000 | - | - |
| mistralai/mistral-small-creative | openrouter | In: text; Out: text | streaming, function_calling | 32768 | - | In: $0.10, Out: $0.30 |
| mistralai/mixtral-8x22b-instruct | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 65536 | - | In: $2.00, Out: $6.00 |
| mistralai/mixtral-8x7b-instruct | openrouter | In: text; Out: text | streaming, function_calling, structured_output, predicted_outputs | 32768 | 16384 | In: $0.54, Out: $0.54 |
| mistralai/pixtral-large-2411 | openrouter | In: text, image; Out: text | streaming, function_calling, structured_output | 131072 | - | In: $2.00, Out: $6.00 |
| mistralai/mistral-saba | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 32768 | - | In: $0.20, Out: $0.60 |
| mistralai/voxtral-small-24b-2507 | openrouter | In: text, audio; Out: text | streaming, function_calling, structured_output | 32000 | - | In: $0.10, Out: $0.30 |
| morph/morph-v3-fast | openrouter | In: text; Out: text | streaming | 81920 | 38000 | In: $0.80, Out: $1.20 |
| morph/morph-v3-large | openrouter | In: text; Out: text | streaming | 262144 | 131072 | In: $0.90, Out: $1.90 |
| gryphe/mythomax-l2-13b | openrouter | In: text; Out: text | streaming, structured_output, predicted_outputs | 4096 | 4096 | In: $0.06, Out: $0.06 |
| nvidia/llama-3.1-nemotron-70b-instruct | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 131072 | 16384 | In: $1.20, Out: $1.20 |
| nvidia/llama-3.3-nemotron-super-49b-v1.5 | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 131072 | - | In: $0.10, Out: $0.40 |
| nvidia/nemotron-3-nano-30b-a3b | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 262144 | - | In: $0.05, Out: $0.20 |
| nvidia/nemotron-nano-12b-v2-vl | openrouter | In: image, text, video; Out: text | streaming, structured_output | 131072 | - | In: $0.07, Out: $0.20 |
| nvidia/nemotron-3-nano-30b-a3b:free | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 256000 | 256000 | - |
| nvidia/nemotron-nano-12b-v2-vl:free | openrouter | In: text, image; Out: text | function_calling, reasoning, vision, streaming | 128000 | 128000 | - |
| nvidia/nemotron-nano-9b-v2:free | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 128000 | 128000 | - |
| neversleep/llama-3.1-lumimaid-8b | openrouter | In: text; Out: text | streaming, structured_output | 32768 | 4096 | In: $0.09, Out: $0.60 |
| nex-agi/deepseek-v3.1-nex-n1 | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 131072 | 163840 | In: $0.27, Out: $1.00 |
| neversleep/noromaid-20b | openrouter | In: text; Out: text | streaming, structured_output | 4096 | 2048 | In: $1.00, Out: $1.75 |
| nousresearch/hermes-3-llama-3.1-405b | openrouter | In: text; Out: text | streaming, structured_output | 131072 | 16384 | In: $1.00, Out: $1.00 |
| nousresearch/hermes-3-llama-3.1-70b | openrouter | In: text; Out: text | streaming, structured_output | 65536 | 65536 | In: $0.30, Out: $0.30 |
| nousresearch/hermes-2-pro-llama-3-8b | openrouter | In: text; Out: text | streaming, structured_output | 8192 | 8192 | In: $0.14, Out: $0.14 |
| openai/gpt-audio | openrouter | In: text, audio; Out: text, audio | streaming, structured_output | 128000 | 16384 | In: $2.50, Out: $10.00 |
| openai/gpt-audio-mini | openrouter | In: text, audio; Out: text, audio | streaming, structured_output | 128000 | 16384 | In: $0.60, Out: $2.40 |
| openai/gpt-3.5-turbo | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 16385 | 4096 | In: $0.50, Out: $1.50 |
| openai/gpt-3.5-turbo-0613 | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 4095 | 4096 | In: $1.00, Out: $2.00 |
| openai/gpt-3.5-turbo-16k | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 16385 | 4096 | In: $3.00, Out: $4.00 |
| openai/gpt-3.5-turbo-instruct | openrouter | In: text; Out: text | streaming, structured_output | 4095 | 4096 | In: $1.50, Out: $2.00 |
| openai/gpt-4 | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 8191 | 4096 | In: $30.00, Out: $60.00 |
| openai/gpt-4-0314 | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 8191 | 4096 | In: $30.00, Out: $60.00 |
| openai/gpt-4-turbo | openrouter | In: text, image; Out: text | streaming, function_calling, structured_output | 128000 | 4096 | In: $10.00, Out: $30.00 |
| openai/gpt-4-1106-preview | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 128000 | 4096 | In: $10.00, Out: $30.00 |
| openai/gpt-4-turbo-preview | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 128000 | 4096 | In: $10.00, Out: $30.00 |
| openai/gpt-4.1-nano | openrouter | In: image, text, file; Out: text | streaming, function_calling, structured_output | 1047576 | 32768 | In: $0.10, Out: $0.40, Cache: $0.02 |
| openai/gpt-4o | openrouter | In: text, image, file; Out: text | streaming, function_calling, structured_output | 128000 | 16384 | In: $2.50, Out: $10.00, Cache: $1.25 |
| openai/gpt-4o-2024-05-13 | openrouter | In: text, image, file; Out: text | streaming, function_calling, structured_output | 128000 | 4096 | In: $5.00, Out: $15.00 |
| openai/gpt-4o-2024-08-06 | openrouter | In: text, image, file; Out: text | streaming, function_calling, structured_output | 128000 | 16384 | In: $2.50, Out: $10.00, Cache: $1.25 |
| openai/gpt-4o-2024-11-20 | openrouter | In: text, image, file; Out: text | streaming, function_calling, structured_output | 128000 | 16384 | In: $2.50, Out: $10.00, Cache: $1.25 |
| openai/gpt-4o:extended | openrouter | In: text, image, file; Out: text | streaming, function_calling, structured_output | 128000 | 64000 | In: $6.00, Out: $18.00 |
| openai/gpt-4o-audio-preview | openrouter | In: audio, text; Out: text, audio | streaming, function_calling, structured_output | 128000 | 16384 | In: $2.50, Out: $10.00 |
| openai/gpt-4o-search-preview | openrouter | In: text; Out: text | streaming, structured_output | 128000 | 16384 | In: $2.50, Out: $10.00 |
| openai/gpt-4o-mini-2024-07-18 | openrouter | In: text, image, file; Out: text | streaming, function_calling, structured_output | 128000 | 16384 | In: $0.15, Out: $0.60, Cache: $0.08 |
| openai/gpt-4o-mini-search-preview | openrouter | In: text; Out: text | streaming, structured_output | 128000 | 16384 | In: $0.15, Out: $0.60 |
| openai/gpt-5-image-mini | openrouter | In: file, image, text; Out: image, text | streaming, function_calling, structured_output | 400000 | 128000 | In: $2.50, Out: $2.00, Cache: $0.25 |
| openai/gpt-5.3-codex | openrouter | In: text, image; Out: text | streaming, function_calling, structured_output | 400000 | 128000 | In: $1.75, Out: $14.00, Cache: $0.18 |
| openai/o1 | openrouter | In: text, image, file; Out: text | streaming, function_calling, structured_output | 200000 | 100000 | In: $15.00, Out: $60.00, Cache: $7.50 |
| openai/o1-pro | openrouter | In: text, image, file; Out: text | streaming, structured_output | 200000 | 100000 | In: $150.00, Out: $600.00 |
| openai/o3 | openrouter | In: image, text, file; Out: text | streaming, function_calling, structured_output | 200000 | 100000 | In: $2.00, Out: $8.00, Cache: $0.50 |
| openai/o3-deep-research | openrouter | In: image, text, file; Out: text | streaming, function_calling, structured_output | 200000 | 100000 | In: $10.00, Out: $40.00, Cache: $2.50 |
| openai/o3-mini | openrouter | In: text, file; Out: text | streaming, function_calling, structured_output | 200000 | 100000 | In: $1.10, Out: $4.40, Cache: $0.55 |
| openai/o3-mini-high | openrouter | In: text, file; Out: text | streaming, function_calling, structured_output | 200000 | 100000 | In: $1.10, Out: $4.40, Cache: $0.55 |
| openai/o3-pro | openrouter | In: text, file, image; Out: text | streaming, function_calling, structured_output | 200000 | 100000 | In: $20.00, Out: $80.00 |
| openai/o4-mini-deep-research | openrouter | In: file, image, text; Out: text | streaming, function_calling, structured_output | 200000 | 100000 | In: $2.00, Out: $8.00, Cache: $0.50 |
| openai/o4-mini-high | openrouter | In: image, text, file; Out: text | streaming, function_calling, structured_output | 200000 | 100000 | In: $1.10, Out: $4.40, Cache: $0.28 |
| opengvlab/internvl3-78b | openrouter | In: image, text; Out: text | streaming, structured_output | 32768 | 32768 | In: $0.15, Out: $0.60, Cache: $0.08 |
| perplexity/sonar | openrouter | In: text, image; Out: text | streaming | 127072 | - | In: $1.00, Out: $1.00 |
| perplexity/sonar-deep-research | openrouter | In: text; Out: text | streaming | 128000 | - | In: $2.00, Out: $8.00 |
| perplexity/sonar-pro | openrouter | In: text, image; Out: text | streaming | 200000 | 8000 | In: $3.00, Out: $15.00 |
| perplexity/sonar-pro-search | openrouter | In: text, image; Out: text | streaming | 200000 | 8000 | In: $3.00, Out: $15.00 |
| perplexity/sonar-reasoning-pro | openrouter | In: text, image; Out: text | streaming | 128000 | - | In: $2.00, Out: $8.00 |
| qwen/qwen-2.5-72b-instruct | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 32768 | 16384 | In: $0.12, Out: $0.39 |
| qwen/qwen-2.5-coder-32b-instruct | openrouter | In: text; Out: text | structured_output, streaming, predicted_outputs | 32768 | 8192 | In: $0.20, Out: $0.20 |
| qwen/qwen2.5-vl-72b-instruct | openrouter | In: text, image; Out: text | structured_output, vision, streaming, predicted_outputs | 32768 | 8192 | In: $0.80, Out: $0.80 |
| qwen/qwen3-235b-a22b-thinking-2507 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 262144 | 81920 | In: $0.08, Out: $0.31 |
| qwen/qwen3-30b-a3b-instruct-2507 | openrouter | In: text; Out: text | function_calling, structured_output, streaming | 262000 | 262000 | In: $0.20, Out: $0.80 |
| qwen/qwen3-30b-a3b-thinking-2507 | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 262000 | 262000 | In: $0.20, Out: $0.80 |
| qwen/qwen3-4b:free | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming | 40960 | 40960 | - |
| qwen/qwen3-coder | openrouter | In: text; Out: text | function_calling, structured_output, streaming, predicted_outputs | 262144 | 66536 | In: $0.30, Out: $1.20 |
| qwen/qwen3-coder:exacto | openrouter | In: text; Out: text | function_calling, structured_output, streaming | 131072 | 32768 | In: $0.38, Out: $1.53 |
| qwen/qwen3-coder-30b-a3b-instruct | openrouter | In: text; Out: text | function_calling, structured_output, streaming | 160000 | 65536 | In: $0.07, Out: $0.27 |
| qwen/qwen3-coder:free | openrouter | In: text; Out: text | function_calling, streaming | 262144 | 66536 | - |
| qwen/qwen3-coder-flash | openrouter | In: text; Out: text | function_calling, streaming, structured_output | 128000 | 66536 | In: $0.30, Out: $1.50 |
| qwen/qwen3-max | openrouter | In: text; Out: text | function_calling, reasoning, streaming, structured_output | 262144 | 32768 | In: $1.20, Out: $6.00 |
| qwen/qwen3-next-80b-a3b-instruct | openrouter | In: text; Out: text | function_calling, structured_output, streaming, predicted_outputs | 262144 | 262144 | In: $0.14, Out: $1.40 |
| qwen/qwen3-next-80b-a3b-instruct:free | openrouter | In: text; Out: text | function_calling, structured_output, streaming | 262144 | 262144 | - |
| qwen/qwen3-next-80b-a3b-thinking | openrouter | In: text; Out: text | function_calling, structured_output, reasoning, streaming, predicted_outputs | 262144 | 262144 | In: $0.14, Out: $1.40 |
| qwen/qwen3.5-397b-a17b | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, streaming, predicted_outputs | 262144 | 65536 | In: $0.60, Out: $3.60 |
| qwen/qwen3.5-plus-02-15 | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 65536 | In: $0.40, Out: $2.40 |
| qwen/qwq-32b | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 32768 | 32768 | In: $0.15, Out: $0.40 |
| qwen/qwen-plus-2025-07-28 | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 1000000 | 32768 | In: $0.40, Out: $1.20 |
| qwen/qwen-plus-2025-07-28:thinking | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 1000000 | 32768 | In: $0.40, Out: $1.20 |
| qwen/qwen-vl-max | openrouter | In: text, image; Out: text | streaming, function_calling, structured_output | 131072 | 32768 | In: $0.80, Out: $3.20 |
| qwen/qwen-vl-plus | openrouter | In: text, image; Out: text | streaming, structured_output | 131072 | 8192 | In: $0.21, Out: $0.63, Cache: $0.04 |
| qwen/qwen-max | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 32768 | 8192 | In: $1.60, Out: $6.40, Cache: $0.32 |
| qwen/qwen-plus | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 1000000 | 32768 | In: $0.40, Out: $1.20, Cache: $0.08 |
| qwen/qwen-turbo | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 131072 | 8192 | In: $0.05, Out: $0.20, Cache: $0.01 |
| qwen/qwen-2.5-7b-instruct | openrouter | In: text; Out: text | streaming, function_calling, predicted_outputs | 32768 | - | In: $0.04, Out: $0.10 |
| qwen/qwen2.5-coder-7b-instruct | openrouter | In: text; Out: text | streaming, structured_output | 32768 | - | In: $0.03, Out: $0.09 |
| qwen/qwen2.5-vl-32b-instruct | openrouter | In: text, image; Out: text | streaming, structured_output | 128000 | - | In: $0.20, Out: $0.60 |
| qwen/qwen-2.5-vl-7b-instruct | openrouter | In: text, image; Out: text | streaming, predicted_outputs | 32768 | - | In: $0.20, Out: $0.20 |
| qwen/qwen3-14b | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 40960 | 40960 | In: $0.06, Out: $0.24 |
| qwen/qwen3-235b-a22b | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 131072 | 8192 | In: $0.46, Out: $1.82 |
| qwen/qwen3-235b-a22b-2507 | openrouter | In: text; Out: text | streaming, function_calling, structured_output, predicted_outputs | 262144 | - | In: $0.07, Out: $0.10 |
| qwen/qwen3-30b-a3b | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 40960 | 40960 | In: $0.08, Out: $0.28 |
| qwen/qwen3-32b | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 40960 | 40960 | In: $0.08, Out: $0.24, Cache: $0.04 |
| qwen/qwen3-8b | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 32000 | 8192 | In: $0.05, Out: $0.40, Cache: $0.05 |
| qwen/qwen3-coder-next | openrouter | In: text; Out: text | streaming, function_calling, structured_output, predicted_outputs | 262144 | 65536 | In: $0.12, Out: $0.75, Cache: $0.06 |
| qwen/qwen3-coder-plus | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 1000000 | 65536 | In: $1.00, Out: $5.00, Cache: $0.20 |
| qwen/qwen3-max-thinking | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 262144 | 32768 | In: $1.20, Out: $6.00 |
| qwen/qwen3-vl-235b-a22b-instruct | openrouter | In: text, image; Out: text | streaming, function_calling, structured_output, predicted_outputs | 262144 | - | In: $0.20, Out: $0.88, Cache: $0.11 |
| qwen/qwen3-vl-235b-a22b-thinking | openrouter | In: text, image; Out: text | streaming, function_calling, structured_output | 131072 | 32768 | - |
| qwen/qwen3-vl-30b-a3b-instruct | openrouter | In: text, image; Out: text | streaming, function_calling, structured_output | 131072 | 32768 | In: $0.13, Out: $0.52 |
| qwen/qwen3-vl-30b-a3b-thinking | openrouter | In: text, image; Out: text | streaming, function_calling, structured_output | 131072 | 32768 | - |
| qwen/qwen3-vl-32b-instruct | openrouter | In: text, image; Out: text | streaming, function_calling, structured_output, predicted_outputs | 131072 | 32768 | In: $0.10, Out: $0.42 |
| qwen/qwen3-vl-8b-instruct | openrouter | In: image, text; Out: text | streaming, function_calling, structured_output, predicted_outputs | 131072 | 32768 | In: $0.08, Out: $0.50 |
| qwen/qwen3-vl-8b-thinking | openrouter | In: image, text; Out: text | streaming, function_calling, structured_output | 131072 | 32768 | In: $0.12, Out: $1.36 |
| undi95/remm-slerp-l2-13b | openrouter | In: text; Out: text | streaming, structured_output, predicted_outputs | 6144 | 4096 | In: $0.45, Out: $0.65 |
| relace/relace-apply-3 | openrouter | In: text; Out: text | streaming | 256000 | 128000 | In: $0.85, Out: $1.25 |
| relace/relace-search | openrouter | In: text; Out: text | streaming, function_calling | 256000 | 128000 | In: $1.00, Out: $3.00 |
| sao10k/l3-lunaris-8b | openrouter | In: text; Out: text | streaming, structured_output | 8192 | - | In: $0.04, Out: $0.05 |
| sao10k/l3.1-70b-hanami-x1 | openrouter | In: text; Out: text | streaming, predicted_outputs | 16000 | - | In: $3.00, Out: $3.00 |
| sao10k/l3.1-euryale-70b | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 32768 | 32768 | In: $0.65, Out: $0.75 |
| sao10k/l3.3-euryale-70b | openrouter | In: text; Out: text | streaming, structured_output | 131072 | 16384 | In: $0.65, Out: $0.75 |
| sao10k/l3-euryale-70b | openrouter | In: text; Out: text | streaming, function_calling | 8192 | 8192 | In: $1.48, Out: $1.48 |
| raifle/sorcererlm-8x22b | openrouter | In: text; Out: text | streaming, predicted_outputs | 16000 | - | In: $4.50, Out: $4.50 |
| stepfun/step-3.5-flash | openrouter | In: text; Out: text | function_calling, reasoning, streaming | 256000 | 256000 | In: $0.10, Out: $0.30, Cache: $0.02 |
| stepfun/step-3.5-flash:free | openrouter | In: text; Out: text | function_calling, reasoning, streaming | 256000 | 256000 | - |
| switchpoint/router | openrouter | In: text; Out: text | streaming | 131072 | - | In: $0.85, Out: $3.40 |
| tngtech/deepseek-r1t2-chimera | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 163840 | 163840 | In: $0.25, Out: $0.85, Cache: $0.12 |
| tencent/hunyuan-a13b-instruct | openrouter | In: text; Out: text | streaming, structured_output | 131072 | 131072 | In: $0.14, Out: $0.57 |
| thedrummer/cydonia-24b-v4.1 | openrouter | In: text; Out: text | streaming, structured_output, predicted_outputs | 131072 | 131072 | In: $0.30, Out: $0.50 |
| thedrummer/rocinante-12b | openrouter | In: text; Out: text | streaming, function_calling, structured_output, predicted_outputs | 32768 | 32768 | In: $0.17, Out: $0.43 |
| thedrummer/skyfall-36b-v2 | openrouter | In: text; Out: text | streaming, predicted_outputs | 32768 | 32768 | In: $0.55, Out: $0.80 |
| thedrummer/unslopnemo-12b | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 32768 | 32768 | In: $0.40, Out: $0.40 |
| alibaba/tongyi-deepresearch-30b-a3b | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 131072 | 131072 | In: $0.09, Out: $0.45, Cache: $0.09 |
| arcee-ai/trinity-large-preview:free | openrouter | In: text; Out: text | function_calling, structured_output, streaming | 131072 | 131072 | - |
| arcee-ai/trinity-mini:free | openrouter | In: text; Out: text | function_calling, structured_output, streaming | 131072 | 131072 | - |
| cognitivecomputations/dolphin-mistral-24b-venice-edition:free | openrouter | In: text; Out: text | structured_output, streaming | 32768 | 32768 | - |
| upstage/solar-pro-3:free | openrouter | In: text; Out: text | streaming, function_calling, structured_output | 128000 | - | - |
| microsoft/wizardlm-2-8x22b | openrouter | In: text; Out: text | streaming | 65535 | 8000 | In: $0.62, Out: $0.62 |
| writer/palmyra-x5 | openrouter | In: text; Out: text | streaming | 1040000 | 8192 | In: $0.60, Out: $6.00 |
| z-ai/glm-4-32b | openrouter | In: text; Out: text | streaming, function_calling | 128000 | - | In: $0.10, Out: $0.10 |
| z-ai/glm-4.6v | openrouter | In: image, text, video; Out: text | streaming, function_calling, structured_output | 131072 | 131072 | In: $0.30, Out: $0.90 |
| openai/gpt-oss-120b:free | openrouter | In: text; Out: text | function_calling, reasoning, streaming | 131072 | 32768 | - |
| openai/gpt-oss-20b:free | openrouter | In: text; Out: text | function_calling, reasoning, streaming | 131072 | 32768 | - |
| nvidia/nemotron-nano-9b-v2 | openrouter | In: text; Out: text | function_calling, reasoning, streaming, structured_output, predicted_outputs | 131072 | 131072 | In: $0.04, Out: $0.16 |
| openai/o4-mini | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 100000 | In: $1.10, Out: $4.40, Cache: $0.28 |
| sonar-deep-research | perplexity | In: text; Out: text | reasoning, streaming, json_mode, vision | 128000 | 32768 | In: $2.00, Out: $8.00 |
| sonar | perplexity | In: text; Out: text | streaming, json_mode, vision | 128000 | 4096 | In: $1.00, Out: $1.00 |
| sonar-pro | perplexity | In: text, image; Out: text | vision, streaming, json_mode | 200000 | 8192 | In: $3.00, Out: $15.00 |
| sonar-reasoning | perplexity | In: text; Out: text | streaming, json_mode, vision | 128000 | 4096 | In: $1.00, Out: $5.00 |
| sonar-reasoning-pro | perplexity | In: text, image; Out: text | reasoning, vision, streaming, json_mode | 128000 | 4096 | In: $2.00, Out: $8.00 |
| gemini-1.5-flash | vertexai | In: text, image, audio, video; Out: text | function_calling, vision, streaming | 1000000 | 8192 | In: $0.08, Out: $0.30, Cache: $0.02 |
| gemini-1.5-flash-8b | vertexai | In: text, image, audio, video; Out: text | function_calling, vision, streaming | 1000000 | 8192 | In: $0.04, Out: $0.15, Cache: $0.01 |
| gemini-1.5-pro | vertexai | In: text, image, audio, video; Out: text | function_calling, vision, streaming | 1000000 | 8192 | In: $1.25, Out: $5.00, Cache: $0.31 |
| gemini-2.0-flash | vertexai | In: text, image, audio, video, pdf; Out: text | function_calling, vision, streaming | 1048576 | 8192 | In: $0.15, Out: $0.60, Cache: $0.02 |
| gemini-2.5-flash | vertexai | In: text, image, audio, video, pdf; Out: text | function_calling, reasoning, vision, streaming | 1048576 | 65536 | In: $0.30, Out: $2.50, Cache: $0.08 |
| gemini-2.5-flash-lite | vertexai | In: text, image, audio, video, pdf; Out: text | function_calling, reasoning, vision, streaming | 1048576 | 65536 | In: $0.10, Out: $0.40, Cache: $0.02 |
| gemini-2.5-flash-preview-04-17 | vertexai | In: text, image, audio, video, pdf; Out: text | function_calling, reasoning, vision, streaming | 1048576 | 65536 | In: $0.15, Out: $0.60, Cache: $0.04 |
| gemini-2.5-pro | vertexai | In: text, image, audio, video, pdf; Out: text | function_calling, reasoning, vision, streaming | 1048576 | 65536 | In: $1.25, Out: $10.00, Cache: $0.31 |
| gemini-embedding-001 | vertexai | In: text; Out: embeddings | streaming, function_calling | 2048 | 3072 | In: $0.15 |
| gemini-1.5-flash-002 | vertexai | In: -; Out: - | streaming, function_calling | - | - | - |
| gemini-1.5-pro-002 | vertexai | In: -; Out: - | streaming, function_calling | - | - | - |
| gemini-2.0-flash-001 | vertexai | In: -; Out: - | streaming, function_calling | - | - | - |
| gemini-2.0-flash-exp | vertexai | In: -; Out: - | streaming, function_calling | - | - | - |
| gemini-2.0-flash-lite-001 | vertexai | In: -; Out: - | streaming, function_calling | - | - | - |
| gemini-2.0-flash-preview-image-generation | vertexai | In: -; Out: - | streaming, function_calling | - | - | - |
| gemini-2.5-pro-exp-03-25 | vertexai | In: -; Out: - | streaming, function_calling | - | - | - |
| gemini-exp-1121 | vertexai | In: -; Out: - | streaming, function_calling | - | - | - |
| gemini-exp-1206 | vertexai | In: -; Out: - | streaming, function_calling | - | - | - |
| gemini-pro | vertexai | In: -; Out: - | streaming, function_calling | - | - | - |
| gemini-pro-vision | vertexai | In: -; Out: - | streaming, function_calling | - | - | - |
| text-embedding-004 | vertexai | In: -; Out: - | streaming, function_calling | - | - | - |
| text-embedding-005 | vertexai | In: -; Out: - | streaming, function_calling | - | - | - |
| text-multilingual-embedding-002 | vertexai | In: -; Out: - | streaming, function_calling | - | - | - |
| grok-2-vision-1212 | xai | In: text, image; Out: text | streaming, function_calling, structured_output, vision | - | - | - |
| grok-3 | xai | In: text; Out: text | streaming, function_calling, structured_output | - | - | - |
| grok-3-mini | xai | In: text; Out: text | streaming, function_calling, structured_output, reasoning | - | - | - |
| grok-4-0709 | xai | In: text, image; Out: text | streaming, function_calling, structured_output, reasoning, vision | - | - | - |
| grok-4-1-fast-non-reasoning | xai | In: text, image; Out: text | streaming, function_calling, structured_output, vision | - | - | - |
| grok-4-1-fast-reasoning | xai | In: text, image; Out: text | streaming, function_calling, structured_output, reasoning, vision | - | - | - |
| grok-4-fast-non-reasoning | xai | In: text, image; Out: text | streaming, function_calling, structured_output, vision | - | - | - |
| grok-4-fast-reasoning | xai | In: text, image; Out: text | streaming, function_calling, structured_output, reasoning, vision | - | - | - |
| grok-code-fast-1 | xai | In: text; Out: text | streaming, function_calling, structured_output, reasoning | - | - | - |
| grok-imagine-image | xai | In: text; Out: text | streaming, function_calling, structured_output | - | - | - |
| grok-imagine-image-pro | xai | In: text; Out: text | streaming, function_calling, structured_output | - | - | - |
| grok-imagine-video | xai | In: text; Out: text | streaming, function_calling, structured_output | - | - | - |


### Batch Processing (63)

| Model | Provider | I/O | Capabilities | Context | Max Output | Standard Pricing (per 1M tokens) |
| :-- | :-- | :-- | :-- | --: | --: | :-- |
| claude-3-haiku-20240307 | anthropic | In: text, image, pdf; Out: text | function_calling, vision, streaming, batch | 200000 | 4096 | In: $0.25, Out: $1.25, Cache: $0.03 |
| text-embedding-3-large | azure | In: text; Out: text, embeddings | batch | - | - | In: $0.13, Out: $0.13 |
| text-embedding-3-small | azure | In: text; Out: text, embeddings | batch | - | - | In: $0.02, Out: $0.02 |
| text-embedding-ada-002 | azure | In: text; Out: text, embeddings | batch | - | - | In: $0.10, Out: $0.10 |
| text-embedding-ada-002-2 | azure | In: text; Out: text, embeddings | batch | - | - | In: $0.10, Out: $0.10 |
| gemini-2.0-flash | gemini | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, vision, streaming, batch, caching | 1048576 | 8192 | In: $0.10, Out: $0.40, Cache: $0.02 |
| gemini-2.0-flash-001 | gemini | In: text, image, pdf, video; Out: text | streaming, function_calling, structured_output, batch, caching | 1048576 | 8192 | In: $0.10, Out: $0.40 |
| gemini-2.0-flash-lite | gemini | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, vision, streaming, batch | 1048576 | 8192 | In: $0.08, Out: $0.30 |
| gemini-2.0-flash-lite-001 | gemini | In: text, image, pdf, video; Out: text | streaming, batch | 1048576 | 8192 | In: $0.08, Out: $0.30 |
| gemini-2.5-flash | gemini | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming, batch, caching | 1048576 | 65536 | In: $0.30, Out: $2.50, Cache: $0.08 |
| gemini-2.5-flash-image | gemini | In: text, image; Out: text, image | reasoning, vision, streaming, function_calling, structured_output, batch, caching | 32768 | 32768 | In: $0.30, Out: $30.00, Cache: $0.08 |
| gemini-2.5-flash-lite | gemini | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming, batch | 1048576 | 65536 | In: $0.10, Out: $0.40, Cache: $0.02 |
| gemini-2.5-flash-lite-preview-09-2025 | gemini | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming, batch | 1048576 | 65536 | In: $0.10, Out: $0.40, Cache: $0.02 |
| gemini-2.5-flash-native-audio-latest | gemini | In: text, image, pdf, video, audio; Out: text | streaming, function_calling, structured_output, batch, caching | 131072 | 8192 | In: $0.08, Out: $0.30 |
| gemini-2.5-flash-native-audio-preview-09-2025 | gemini | In: text, image, pdf, video, audio; Out: text | streaming, function_calling, structured_output, batch, caching | 131072 | 8192 | In: $0.08, Out: $0.30 |
| gemini-2.5-flash-native-audio-preview-12-2025 | gemini | In: text, image, pdf, video, audio; Out: text | streaming, function_calling, structured_output, batch, caching | 131072 | 8192 | In: $0.08, Out: $0.30 |
| gemini-2.5-flash-preview-tts | gemini | In: text; Out: audio | streaming, function_calling, structured_output, batch, caching | 8000 | 16000 | In: $0.50, Out: $10.00 |
| gemini-3-flash-preview | gemini | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming, batch, caching | 1048576 | 65536 | In: $0.50, Out: $3.00, Cache: $0.05 |
| gemini-embedding-001 | gemini | In: text; Out: embeddings | streaming, batch | 2048 | 3072 | In: $0.15 |
| gemini-flash-latest | gemini | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming, batch, caching | 1048576 | 65536 | In: $0.30, Out: $2.50, Cache: $0.08 |
| gemini-flash-lite-latest | gemini | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming, batch | 1048576 | 65536 | In: $0.10, Out: $0.40, Cache: $0.02 |
| codestral-2508 | mistral | In: text; Out: text | streaming, function_calling, structured_output, batch, predicted_outputs | 32768 | 8192 | - |
| codestral-latest | mistral | In: text; Out: text | function_calling, streaming, structured_output, batch, predicted_outputs | 256000 | 4096 | In: $0.30, Out: $0.90 |
| devstral-2512 | mistral | In: text; Out: text | function_calling, streaming, structured_output, batch, fine_tuning | 262144 | 262144 | In: $0.40, Out: $2.00 |
| devstral-medium-latest | mistral | In: text; Out: text | function_calling, streaming, structured_output, batch, fine_tuning | 262144 | 262144 | In: $0.40, Out: $2.00 |
| devstral-latest | mistral | In: text; Out: text | streaming, function_calling, structured_output, batch, fine_tuning | 32768 | 8192 | - |
| devstral-medium-2507 | mistral | In: text; Out: text | function_calling, streaming, structured_output, batch, fine_tuning | 128000 | 128000 | In: $0.40, Out: $2.00 |
| devstral-small-2507 | mistral | In: text; Out: text | function_calling, streaming, structured_output, batch, fine_tuning | 128000 | 128000 | In: $0.10, Out: $0.30 |
| labs-devstral-small-2512 | mistral | In: text, image; Out: text | function_calling, vision, streaming, structured_output, batch, fine_tuning | 256000 | 256000 | - |
| devstral-small-latest | mistral | In: text; Out: text | streaming, function_calling, structured_output, batch, fine_tuning | 32768 | 8192 | - |
| magistral-medium-latest | mistral | In: text; Out: text | function_calling, reasoning, streaming, structured_output, batch | 128000 | 16384 | In: $2.00, Out: $5.00 |
| magistral-medium-2509 | mistral | In: text; Out: text | streaming, function_calling, structured_output, reasoning, batch | 32768 | 8192 | - |
| magistral-small-2509 | mistral | In: text; Out: text | streaming, function_calling, structured_output, reasoning, batch | 32768 | 8192 | - |
| magistral-small-latest | mistral | In: text; Out: text | streaming, function_calling, structured_output, reasoning, batch | 32768 | 8192 | - |
| ministral-14b-2512 | mistral | In: text; Out: text | streaming, function_calling, structured_output, batch, distillation | 32768 | 8192 | - |
| ministral-14b-latest | mistral | In: text; Out: text | streaming, function_calling, structured_output, batch, distillation | 32768 | 8192 | - |
| ministral-3b-latest | mistral | In: text; Out: text | function_calling, streaming, structured_output, batch, distillation | 128000 | 128000 | In: $0.04, Out: $0.04 |
| ministral-3b-2512 | mistral | In: text; Out: text | streaming, function_calling, structured_output, batch, distillation | 32768 | 8192 | - |
| ministral-8b-2512 | mistral | In: text; Out: text | streaming, function_calling, structured_output, batch, distillation | 32768 | 8192 | - |
| ministral-8b-latest | mistral | In: text; Out: text | function_calling, streaming, structured_output, batch, distillation | 128000 | 128000 | In: $0.10, Out: $0.10 |
| mistral-large-latest | mistral | In: text, image; Out: text | function_calling, vision, streaming, structured_output, batch, fine_tuning | 262144 | 262144 | In: $0.50, Out: $1.50 |
| mistral-large-pixtral-2411 | mistral | In: text, image; Out: text | streaming, function_calling, structured_output, vision, batch, fine_tuning | 32768 | 8192 | - |
| mistral-large-2411 | mistral | In: text; Out: text | function_calling, streaming, structured_output, batch, fine_tuning | 131072 | 16384 | In: $2.00, Out: $6.00 |
| mistral-large-2512 | mistral | In: text, image; Out: text | function_calling, vision, streaming, structured_output, batch, fine_tuning | 262144 | 262144 | In: $0.50, Out: $1.50 |
| mistral-medium-latest | mistral | In: text, image; Out: text | function_calling, vision, streaming, structured_output, batch, fine_tuning | 128000 | 16384 | In: $0.40, Out: $2.00 |
| mistral-medium | mistral | In: text; Out: text | streaming, function_calling, structured_output, vision, batch, fine_tuning | 32768 | 8192 | - |
| mistral-medium-2505 | mistral | In: text, image; Out: text | function_calling, vision, streaming, structured_output, batch, fine_tuning | 131072 | 131072 | In: $0.40, Out: $2.00 |
| mistral-medium-2508 | mistral | In: text, image; Out: text | function_calling, vision, streaming, structured_output, batch, fine_tuning | 262144 | 262144 | In: $0.40, Out: $2.00 |
| labs-mistral-small-creative | mistral | In: text; Out: text | streaming, function_calling, structured_output, batch, fine_tuning | 32768 | 8192 | - |
| mistral-small-2501 | mistral | In: text; Out: text | streaming, function_calling, structured_output, batch, fine_tuning | 32768 | 8192 | - |
| mistral-small-latest | mistral | In: text, image; Out: text | function_calling, vision, streaming, structured_output, batch, fine_tuning | 128000 | 16384 | In: $0.10, Out: $0.30 |
| mistral-small-2506 | mistral | In: text, image; Out: text | function_calling, vision, streaming, structured_output, batch, fine_tuning | 128000 | 16384 | In: $0.10, Out: $0.30 |
| mistral-tiny-2407 | mistral | In: text; Out: text | streaming, function_calling, structured_output, batch | 32768 | 8192 | - |
| mistral-tiny-latest | mistral | In: text; Out: text | streaming, function_calling, structured_output, batch | 32768 | 8192 | - |
| mistral-vibe-cli-latest | mistral | In: text; Out: text | streaming, function_calling, structured_output, batch | 32768 | 8192 | - |
| mistral-vibe-cli-with-tools | mistral | In: text; Out: text | streaming, function_calling, structured_output, batch | 32768 | 8192 | - |
| open-mistral-nemo | mistral | In: text; Out: text | streaming, function_calling, structured_output, batch | 32768 | 8192 | - |
| open-mistral-nemo-2407 | mistral | In: text; Out: text | streaming, function_calling, structured_output, batch | 32768 | 8192 | - |
| pixtral-large-2411 | mistral | In: text, image; Out: text | streaming, function_calling, structured_output, vision, batch | 32768 | 8192 | - |
| pixtral-large-latest | mistral | In: text, image; Out: text | function_calling, vision, streaming, structured_output, batch | 128000 | 128000 | In: $2.00, Out: $6.00 |
| text-embedding-3-large | openai | In: text; Out: embeddings | batch | 8191 | 3072 | In: $0.13 |
| text-embedding-3-small | openai | In: text; Out: embeddings | batch | 8191 | 1536 | In: $0.02 |
| text-embedding-ada-002 | openai | In: text; Out: embeddings | batch | 8192 | 1536 | In: $0.10 |


## Models by Modality

### Vision Models (430)

Models that can process images:

| Model | Provider | I/O | Capabilities | Context | Max Output | Standard Pricing (per 1M tokens) |
| :-- | :-- | :-- | :-- | --: | --: | :-- |
| claude-3-haiku-20240307 | anthropic | In: text, image, pdf; Out: text | function_calling, vision, streaming, batch | 200000 | 4096 | In: $0.25, Out: $1.25, Cache: $0.03 |
| claude-3-5-haiku-20241022 | anthropic | In: text, image, pdf; Out: text | function_calling, vision | 200000 | 8192 | In: $0.80, Out: $4.00, Cache: $0.08 |
| claude-3-5-haiku-latest | anthropic | In: text, image, pdf; Out: text | function_calling, vision | 200000 | 8192 | In: $0.80, Out: $4.00, Cache: $0.08 |
| claude-haiku-4-5-20251001 | anthropic | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 64000 | In: $1.00, Out: $5.00, Cache: $0.10 |
| claude-haiku-4-5 | anthropic | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 200000 | 64000 | In: $1.00, Out: $5.00, Cache: $0.10 |
| claude-3-opus-20240229 | anthropic | In: text, image, pdf; Out: text | function_calling, vision | 200000 | 4096 | In: $15.00, Out: $75.00, Cache: $1.50 |
| claude-opus-4-20250514 | anthropic | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 32000 | In: $15.00, Out: $75.00, Cache: $1.50 |
| claude-opus-4-0 | anthropic | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 200000 | 32000 | In: $15.00, Out: $75.00, Cache: $1.50 |
| claude-opus-4-1-20250805 | anthropic | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 32000 | In: $15.00, Out: $75.00, Cache: $1.50 |
| claude-opus-4-1 | anthropic | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 200000 | 32000 | In: $15.00, Out: $75.00, Cache: $1.50 |
| claude-opus-4-5-20251101 | anthropic | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 64000 | In: $5.00, Out: $25.00, Cache: $0.50 |
| claude-opus-4-5 | anthropic | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 200000 | 64000 | In: $5.00, Out: $25.00, Cache: $0.50 |
| claude-opus-4-6 | anthropic | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 128000 | In: $5.00, Out: $25.00, Cache: $0.50 |
| claude-3-sonnet-20240229 | anthropic | In: text, image, pdf; Out: text | function_calling, vision | 200000 | 4096 | In: $3.00, Out: $15.00, Cache: $0.30 |
| claude-3-5-sonnet-20240620 | anthropic | In: text, image, pdf; Out: text | function_calling, vision | 200000 | 8192 | In: $3.00, Out: $15.00, Cache: $0.30 |
| claude-3-5-sonnet-20241022 | anthropic | In: text, image, pdf; Out: text | function_calling, vision | 200000 | 8192 | In: $3.00, Out: $15.00, Cache: $0.30 |
| claude-3-7-sonnet-20250219 | anthropic | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 200000 | 64000 | In: $3.00, Out: $15.00, Cache: $0.30 |
| claude-3-7-sonnet-latest | anthropic | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 200000 | 64000 | In: $3.00, Out: $15.00, Cache: $0.30 |
| claude-sonnet-4-20250514 | anthropic | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 64000 | In: $3.00, Out: $15.00, Cache: $0.30 |
| claude-sonnet-4-0 | anthropic | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 200000 | 64000 | In: $3.00, Out: $15.00, Cache: $0.30 |
| claude-sonnet-4-5-20250929 | anthropic | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 64000 | In: $3.00, Out: $15.00, Cache: $0.30 |
| claude-sonnet-4-5 | anthropic | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 200000 | 64000 | In: $3.00, Out: $15.00, Cache: $0.30 |
| claude-sonnet-4-6 | anthropic | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 64000 | In: $3.00, Out: $15.00, Cache: $0.30 |
| gpt-4 | azure | In: text, image, pdf; Out: text | streaming, function_calling | 8192 | 8192 | In: $10.00, Out: $30.00 |
| gpt-4-turbo-2024-04-09 | azure | In: text, image, pdf; Out: text | streaming, function_calling | 128000 | 4096 | In: $10.00, Out: $30.00 |
| gpt-4-turbo-jp | azure | In: text, image, pdf; Out: text | streaming, function_calling | 128000 | 4096 | In: $10.00, Out: $30.00 |
| gpt-4.1 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output | 1047576 | 32768 | In: $2.00, Out: $8.00, Cache: $0.50 |
| gpt-4.1-2025-04-14 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output | 1047576 | 32768 | In: $2.00, Out: $8.00, Cache: $0.50 |
| gpt-4.1-2025-04-14-text | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output | 1047576 | 32768 | In: $2.00, Out: $8.00, Cache: $0.50 |
| gpt-4.1-mini | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output | 1047576 | 32768 | In: $0.40, Out: $1.60, Cache: $0.10 |
| gpt-4.1-mini-2025-04-14 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output | 1047576 | 32768 | In: $0.40, Out: $1.60, Cache: $0.10 |
| gpt-4.1-nano | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output | 1047576 | 32768 | In: $0.10, Out: $0.40 |
| gpt-4.1-nano-2025-04-14 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output | 1047576 | 32768 | In: $0.10, Out: $0.40 |
| gpt-4o | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output | 128000 | 16384 | In: $2.50, Out: $10.00 |
| gpt-4o-2024-05-13 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output | 128000 | 16384 | In: $2.50, Out: $10.00 |
| gpt-4o-2024-08-06 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output | 128000 | 16384 | In: $2.50, Out: $10.00 |
| gpt-4o-2024-11-20 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output | 128000 | 16384 | In: $2.50, Out: $10.00 |
| gpt-4o-canvas-2024-09-25 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output | 128000 | 16384 | In: $2.50, Out: $10.00 |
| gpt-4o-mini | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output | 128000 | 16384 | In: $0.15, Out: $0.60 |
| gpt-4o-mini-2024-07-18 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output | 128000 | 16384 | In: $0.15, Out: $0.60 |
| gpt-5-chat-2025-08-07 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5-chat-2025-08-15 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5-chat-2025-10-03 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5-codex-2025-09-15 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5-mini-2025-08-07 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5-mini-lite-2025-08-07 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5-nano-2025-08-07 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5.1-chat-2025-11-13 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5.1-codex-mini-2025-11-13 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5.2-chat-2025-12-11 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5.2-chat-2026-02-10 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5.3-codex-2026-02-20 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| o1-2024-12-17 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 200000 | 100000 | In: $15.00, Out: $60.00 |
| o1-pro | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 200000 | 100000 | In: $150.00, Out: $600.00 |
| o1-pro-2025-03-19 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 200000 | 100000 | In: $150.00, Out: $600.00 |
| anthropic.claude-3-haiku-20240307-v1:0:48k | bedrock | In: text, image, pdf; Out: text | function_calling, vision, streaming | 48000 | 4096 | In: $0.25, Out: $1.25 |
| anthropic.claude-3-haiku-20240307-v1:0:200k | bedrock | In: text, image, pdf; Out: text | function_calling, vision, streaming | 200000 | 4096 | In: $0.25, Out: $1.25 |
| anthropic.claude-3-haiku-20240307-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, vision, streaming | 200000 | 4096 | In: $0.25, Out: $1.25 |
| anthropic.claude-3-5-haiku-20241022-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, vision, streaming | 200000 | 8192 | In: $0.80, Out: $4.00, Cache: $0.08 |
| anthropic.claude-haiku-4-5-20251001-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 200000 | 64000 | In: $1.00, Out: $5.00, Cache: $0.10 |
| eu.anthropic.claude-haiku-4-5-20251001-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 200000 | 64000 | In: $1.00, Out: $5.00, Cache: $0.10 |
| global.anthropic.claude-haiku-4-5-20251001-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 200000 | 64000 | In: $1.00, Out: $5.00, Cache: $0.10 |
| us.anthropic.claude-haiku-4-5-20251001-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 64000 | In: $1.00, Out: $5.00, Cache: $0.10 |
| anthropic.claude-3-opus-20240229-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, vision | 200000 | 4096 | In: $15.00, Out: $75.00 |
| anthropic.claude-opus-4-20250514-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 200000 | 32000 | In: $15.00, Out: $75.00, Cache: $1.50 |
| us.anthropic.claude-opus-4-20250514-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 32000 | In: $15.00, Out: $75.00, Cache: $1.50 |
| anthropic.claude-opus-4-1-20250805-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 200000 | 32000 | In: $15.00, Out: $75.00, Cache: $1.50 |
| us.anthropic.claude-opus-4-1-20250805-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 32000 | In: $15.00, Out: $75.00, Cache: $1.50 |
| anthropic.claude-opus-4-5-20251101-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 200000 | 64000 | In: $5.00, Out: $25.00, Cache: $0.50 |
| eu.anthropic.claude-opus-4-5-20251101-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 200000 | 64000 | In: $5.00, Out: $25.00, Cache: $0.50 |
| global.anthropic.claude-opus-4-5-20251101-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 200000 | 64000 | In: $5.00, Out: $25.00, Cache: $0.50 |
| us.anthropic.claude-opus-4-5-20251101-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 64000 | In: $5.00, Out: $25.00, Cache: $0.50 |
| anthropic.claude-opus-4-6-v1 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache: $0.50 |
| eu.anthropic.claude-opus-4-6-v1 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache: $0.50 |
| global.anthropic.claude-opus-4-6-v1 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache: $0.50 |
| us.anthropic.claude-opus-4-6-v1 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache: $0.50 |
| anthropic.claude-3-sonnet-20240229-v1:0:28k | bedrock | In: text, image, pdf; Out: text | function_calling, vision, streaming | 28000 | 4096 | In: $3.00, Out: $15.00 |
| anthropic.claude-3-sonnet-20240229-v1:0:200k | bedrock | In: text, image, pdf; Out: text | function_calling, vision, streaming | 200000 | 4096 | In: $3.00, Out: $15.00 |
| anthropic.claude-3-sonnet-20240229-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, vision, streaming | 200000 | 4096 | In: $3.00, Out: $15.00 |
| anthropic.claude-3-5-sonnet-20240620-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, vision, streaming | 200000 | 8192 | In: $3.00, Out: $15.00, Cache: $0.30 |
| anthropic.claude-3-5-sonnet-20240620-v1:0:18k | bedrock | In: text, image, pdf; Out: text | function_calling, vision, streaming | 18000 | 8192 | In: $3.00, Out: $15.00, Cache: $0.30 |
| anthropic.claude-3-5-sonnet-20240620-v1:0:200k | bedrock | In: text, image, pdf; Out: text | function_calling, vision, streaming | 200000 | 8192 | In: $3.00, Out: $15.00, Cache: $0.30 |
| anthropic.claude-3-5-sonnet-20240620-v1:0:51k | bedrock | In: text, image, pdf; Out: text | function_calling, vision, streaming | 51000 | 8192 | In: $3.00, Out: $15.00, Cache: $0.30 |
| anthropic.claude-3-5-sonnet-20241022-v2:0:51k | bedrock | In: text, image, pdf; Out: text | function_calling, vision, streaming | 51000 | 8192 | In: $3.00, Out: $15.00, Cache: $0.30 |
| anthropic.claude-3-5-sonnet-20241022-v2:0:200k | bedrock | In: text, image, pdf; Out: text | function_calling, vision, streaming | 200000 | 8192 | In: $3.00, Out: $15.00, Cache: $0.30 |
| anthropic.claude-3-5-sonnet-20241022-v2:0:18k | bedrock | In: text, image, pdf; Out: text | function_calling, vision, streaming | 18000 | 8192 | In: $3.00, Out: $15.00, Cache: $0.30 |
| anthropic.claude-3-5-sonnet-20241022-v2:0 | bedrock | In: text, image, pdf; Out: text | function_calling, vision, streaming | 200000 | 8192 | In: $3.00, Out: $15.00, Cache: $0.30 |
| anthropic.claude-3-7-sonnet-20250219-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, vision | 200000 | 8192 | In: $3.00, Out: $15.00, Cache: $0.30 |
| us.anthropic.claude-3-7-sonnet-20250219-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, vision, streaming | 200000 | 8192 | In: $3.00, Out: $15.00, Cache: $0.30 |
| anthropic.claude-sonnet-4-20250514-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 200000 | 64000 | In: $3.00, Out: $15.00, Cache: $0.30 |
| eu.anthropic.claude-sonnet-4-20250514-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 200000 | 64000 | In: $3.00, Out: $15.00, Cache: $0.30 |
| global.anthropic.claude-sonnet-4-20250514-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 200000 | 64000 | In: $3.00, Out: $15.00, Cache: $0.30 |
| us.anthropic.claude-sonnet-4-20250514-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 64000 | In: $3.00, Out: $15.00, Cache: $0.30 |
| anthropic.claude-sonnet-4-5-20250929-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 200000 | 64000 | In: $3.00, Out: $15.00, Cache: $0.30 |
| eu.anthropic.claude-sonnet-4-5-20250929-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 200000 | 64000 | In: $3.00, Out: $15.00, Cache: $0.30 |
| global.anthropic.claude-sonnet-4-5-20250929-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 200000 | 64000 | In: $3.00, Out: $15.00, Cache: $0.30 |
| us.anthropic.claude-sonnet-4-5-20250929-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 64000 | In: $3.00, Out: $15.00, Cache: $0.30 |
| anthropic.claude-sonnet-4-6 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 200000 | 64000 | In: $3.00, Out: $15.00, Cache: $0.30 |
| eu.anthropic.claude-sonnet-4-6 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 200000 | 64000 | In: $3.00, Out: $15.00, Cache: $0.30 |
| global.anthropic.claude-sonnet-4-6 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 200000 | 64000 | In: $3.00, Out: $15.00, Cache: $0.30 |
| us.anthropic.claude-sonnet-4-6 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 64000 | In: $3.00, Out: $15.00, Cache: $0.30 |
| us.cohere.embed-v4:0 | bedrock | In: text, image; Out: embeddings | function_calling | 128000 | - | - |
| google.gemma-3-4b-it | bedrock | In: text, image; Out: text | function_calling, vision, streaming | 128000 | 4096 | In: $0.04, Out: $0.08 |
| google.gemma-3-12b-it | bedrock | In: text, image; Out: text | vision, streaming, function_calling | 131072 | 8192 | In: $0.05, Out: $0.10 |
| google.gemma-3-27b-it | bedrock | In: text, image; Out: text | function_calling, vision, streaming | 202752 | 8192 | In: $0.12, Out: $0.20 |
| moonshotai.kimi-k2.5 | bedrock | In: text, image; Out: text | function_calling, reasoning, vision, streaming | 256000 | 256000 | In: $0.60, Out: $3.00 |
| us.meta.llama3-2-11b-instruct-v1:0 | bedrock | In: text, image; Out: text | function_calling, vision, streaming | 128000 | 4096 | In: $0.16, Out: $0.16 |
| meta.llama3-2-11b-instruct-v1:0 | bedrock | In: text, image; Out: text | function_calling, vision | 128000 | 4096 | In: $0.16, Out: $0.16 |
| meta.llama3-2-11b-instruct-v1:0:128k | bedrock | In: text, image; Out: text | function_calling, vision, streaming | 128000 | 4096 | In: $0.16, Out: $0.16 |
| meta.llama3-2-90b-instruct-v1:0 | bedrock | In: text, image; Out: text | function_calling, vision | 128000 | 4096 | In: $0.72, Out: $0.72 |
| meta.llama3-2-90b-instruct-v1:0:128k | bedrock | In: text, image; Out: text | function_calling, vision, streaming | 128000 | 4096 | In: $0.72, Out: $0.72 |
| us.meta.llama3-2-90b-instruct-v1:0 | bedrock | In: text, image; Out: text | function_calling, vision, streaming | 128000 | 4096 | In: $0.72, Out: $0.72 |
| meta.llama4-maverick-17b-instruct-v1:0 | bedrock | In: text, image; Out: text | function_calling, vision | 1000000 | 16384 | In: $0.24, Out: $0.97 |
| us.meta.llama4-maverick-17b-instruct-v1:0 | bedrock | In: text, image; Out: text | function_calling, vision, streaming | 1000000 | 16384 | In: $0.24, Out: $0.97 |
| meta.llama4-scout-17b-instruct-v1:0 | bedrock | In: text, image; Out: text | function_calling, vision | 3500000 | 16384 | In: $0.17, Out: $0.66 |
| us.meta.llama4-scout-17b-instruct-v1:0 | bedrock | In: text, image; Out: text | function_calling, vision, streaming | 3500000 | 16384 | In: $0.17, Out: $0.66 |
| mistral.magistral-small-2509 | bedrock | In: text, image; Out: text | streaming, function_calling, reasoning | - | 131072 | - |
| mistral.ministral-3-3b-instruct | bedrock | In: text, image; Out: text | streaming, function_calling | - | 262144 | - |
| mistral.mistral-large-3-675b-instruct | bedrock | In: text, image; Out: text | streaming, function_calling | - | 262144 | - |
| nvidia.nemotron-nano-12b-v2 | bedrock | In: text, image; Out: text | function_calling, vision, streaming | 128000 | 4096 | In: $0.20, Out: $0.60 |
| us.amazon.nova-2-lite-v1:0 | bedrock | In: text, image, video; Out: text | function_calling, vision, streaming | 128000 | 4096 | In: $0.33, Out: $2.75 |
| amazon.nova-2-lite-v1:0 | bedrock | In: text, image, video; Out: text | function_calling, vision | 128000 | 4096 | In: $0.33, Out: $2.75 |
| amazon.nova-lite-v1:0 | bedrock | In: text, image, video; Out: text | function_calling, vision | 300000 | 8192 | In: $0.06, Out: $0.24, Cache: $0.02 |
| us.amazon.nova-lite-v1:0 | bedrock | In: text, image, video; Out: text | function_calling, vision, streaming | 300000 | 8192 | In: $0.06, Out: $0.24, Cache: $0.02 |
| us.amazon.nova-premier-v1:0 | bedrock | In: text, image, video; Out: text | function_calling, reasoning, vision, streaming | 1000000 | 16384 | In: $2.50, Out: $12.50 |
| amazon.nova-premier-v1:0:mm | bedrock | In: text, image, video; Out: text | streaming, function_calling | - | - | - |
| amazon.nova-premier-v1:0:8k | bedrock | In: text, image, video; Out: text | function_calling, reasoning, vision, streaming | 8000 | 16384 | In: $2.50, Out: $12.50 |
| amazon.nova-premier-v1:0:20k | bedrock | In: text, image, video; Out: text | function_calling, reasoning, vision, streaming | 20000 | 16384 | In: $2.50, Out: $12.50 |
| amazon.nova-premier-v1:0:1000k | bedrock | In: text, image, video; Out: text | function_calling, reasoning, vision, streaming | 1000000 | 16384 | In: $2.50, Out: $12.50 |
| amazon.nova-premier-v1:0 | bedrock | In: text, image, video; Out: text | function_calling, reasoning, vision | 1000000 | 16384 | In: $2.50, Out: $12.50 |
| amazon.nova-pro-v1:0 | bedrock | In: text, image, video; Out: text | function_calling, vision | 300000 | 8192 | In: $0.80, Out: $3.20, Cache: $0.20 |
| us.amazon.nova-pro-v1:0 | bedrock | In: text, image, video; Out: text | function_calling, vision, streaming | 300000 | 8192 | In: $0.80, Out: $3.20, Cache: $0.20 |
| us.mistral.pixtral-large-2502-v1:0 | bedrock | In: text, image; Out: text | streaming, function_calling | - | - | - |
| qwen.qwen3-vl-235b-a22b | bedrock | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 262000 | 262000 | In: $0.30, Out: $1.50 |
| stability.sd3-5-large-v1:0 | bedrock | In: text, image; Out: image | function_calling | - | - | - |
| us.stability.stable-conservative-upscale-v1:0 | bedrock | In: text, image; Out: image | function_calling | - | - | - |
| us.stability.stable-image-control-sketch-v1:0 | bedrock | In: text, image; Out: image | function_calling | - | - | - |
| us.stability.stable-image-control-structure-v1:0 | bedrock | In: text, image; Out: image | function_calling | - | - | - |
| us.stability.stable-creative-upscale-v1:0 | bedrock | In: text, image; Out: image | function_calling | - | - | - |
| us.stability.stable-image-erase-object-v1:0 | bedrock | In: text, image; Out: image | function_calling | - | - | - |
| us.stability.stable-fast-upscale-v1:0 | bedrock | In: text, image; Out: image | function_calling | - | - | - |
| us.stability.stable-image-inpaint-v1:0 | bedrock | In: text, image; Out: image | function_calling | - | - | - |
| us.stability.stable-outpaint-v1:0 | bedrock | In: text, image; Out: image | function_calling | - | - | - |
| us.stability.stable-image-remove-background-v1:0 | bedrock | In: text, image; Out: image | function_calling | - | - | - |
| us.stability.stable-image-search-recolor-v1:0 | bedrock | In: text, image; Out: image | function_calling | - | - | - |
| us.stability.stable-image-search-replace-v1:0 | bedrock | In: text, image; Out: image | function_calling | - | - | - |
| us.stability.stable-image-style-guide-v1:0 | bedrock | In: text, image; Out: image | function_calling | - | - | - |
| us.stability.stable-style-transfer-v1:0 | bedrock | In: text, image; Out: image | function_calling | - | - | - |
| amazon.titan-image-generator-v2:0 | bedrock | In: text, image; Out: image | function_calling | - | - | - |
| amazon.titan-embed-image-v1 | bedrock | In: text, image; Out: embeddings | function_calling | - | - | - |
| amazon.titan-embed-image-v1:0 | bedrock | In: text, image; Out: embeddings | function_calling | - | - | - |
| deep-research-pro-preview-12-2025 | gemini | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, caching | 131072 | 65536 | In: $0.08, Out: $0.30 |
| gemini-1.5-flash | gemini | In: text, image, audio, video; Out: text | function_calling, vision | 1000000 | 8192 | In: $0.08, Out: $0.30, Cache: $0.02 |
| gemini-1.5-flash-8b | gemini | In: text, image, audio, video; Out: text | function_calling, vision | 1000000 | 8192 | In: $0.04, Out: $0.15, Cache: $0.01 |
| gemini-1.5-pro | gemini | In: text, image, audio, video; Out: text | function_calling, vision | 1000000 | 8192 | In: $1.25, Out: $5.00, Cache: $0.31 |
| gemini-2.0-flash | gemini | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, vision, streaming, batch, caching | 1048576 | 8192 | In: $0.10, Out: $0.40, Cache: $0.02 |
| gemini-2.0-flash-001 | gemini | In: text, image, pdf, video; Out: text | streaming, function_calling, structured_output, batch, caching | 1048576 | 8192 | In: $0.10, Out: $0.40 |
| gemini-2.0-flash-lite | gemini | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, vision, streaming, batch | 1048576 | 8192 | In: $0.08, Out: $0.30 |
| gemini-2.0-flash-lite-001 | gemini | In: text, image, pdf, video; Out: text | streaming, batch | 1048576 | 8192 | In: $0.08, Out: $0.30 |
| gemini-2.5-computer-use-preview-10-2025 | gemini | In: text, image, pdf, video; Out: text | streaming, function_calling, structured_output, caching | 131072 | 65536 | In: $0.08, Out: $0.30 |
| gemini-2.5-flash | gemini | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming, batch, caching | 1048576 | 65536 | In: $0.30, Out: $2.50, Cache: $0.08 |
| gemini-2.5-flash-image | gemini | In: text, image; Out: text, image | reasoning, vision, streaming, function_calling, structured_output, batch, caching | 32768 | 32768 | In: $0.30, Out: $30.00, Cache: $0.08 |
| gemini-2.5-flash-image-preview | gemini | In: text, image; Out: text, image | reasoning, vision | 32768 | 32768 | In: $0.30, Out: $30.00, Cache: $0.08 |
| gemini-2.5-flash-lite | gemini | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming, batch | 1048576 | 65536 | In: $0.10, Out: $0.40, Cache: $0.02 |
| gemini-2.5-flash-lite-preview-06-17 | gemini | In: text, image, audio, video, pdf; Out: text | function_calling, reasoning, vision | 1048576 | 65536 | In: $0.10, Out: $0.40, Cache: $0.02 |
| gemini-2.5-flash-lite-preview-09-2025 | gemini | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming, batch | 1048576 | 65536 | In: $0.10, Out: $0.40, Cache: $0.02 |
| gemini-2.5-flash-native-audio-latest | gemini | In: text, image, pdf, video, audio; Out: text | streaming, function_calling, structured_output, batch, caching | 131072 | 8192 | In: $0.08, Out: $0.30 |
| gemini-2.5-flash-native-audio-preview-09-2025 | gemini | In: text, image, pdf, video, audio; Out: text | streaming, function_calling, structured_output, batch, caching | 131072 | 8192 | In: $0.08, Out: $0.30 |
| gemini-2.5-flash-native-audio-preview-12-2025 | gemini | In: text, image, pdf, video, audio; Out: text | streaming, function_calling, structured_output, batch, caching | 131072 | 8192 | In: $0.08, Out: $0.30 |
| gemini-2.5-flash-preview-04-17 | gemini | In: text, image, audio, video, pdf; Out: text | function_calling, reasoning, vision | 1048576 | 65536 | In: $0.15, Out: $0.60, Cache: $0.04 |
| gemini-2.5-flash-preview-05-20 | gemini | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1048576 | 65536 | In: $0.15, Out: $0.60, Cache: $0.04 |
| gemini-2.5-flash-preview-09-2025 | gemini | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1048576 | 65536 | In: $0.30, Out: $2.50, Cache: $0.08 |
| gemini-2.5-pro | gemini | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming, caching | 1048576 | 65536 | In: $1.25, Out: $10.00, Cache: $0.31 |
| gemini-2.5-pro-preview-05-06 | gemini | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1048576 | 65536 | In: $1.25, Out: $10.00, Cache: $0.31 |
| gemini-2.5-pro-preview-06-05 | gemini | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1048576 | 65536 | In: $1.25, Out: $10.00, Cache: $0.31 |
| gemini-3-flash-preview | gemini | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming, batch, caching | 1048576 | 65536 | In: $0.50, Out: $3.00, Cache: $0.05 |
| gemini-3-pro-preview | gemini | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming, caching | 1000000 | 64000 | In: $2.00, Out: $12.00, Cache: $0.20 |
| gemini-3.1-pro-preview | gemini | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming, caching | 1048576 | 65536 | In: $2.00, Out: $12.00, Cache: $0.20 |
| gemini-3.1-pro-preview-customtools | gemini | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming, caching | 1048576 | 65536 | In: $2.00, Out: $12.00, Cache: $0.20 |
| gemini-flash-latest | gemini | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming, batch, caching | 1048576 | 65536 | In: $0.30, Out: $2.50, Cache: $0.08 |
| gemini-flash-lite-latest | gemini | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming, batch | 1048576 | 65536 | In: $0.10, Out: $0.40, Cache: $0.02 |
| gemini-live-2.5-flash | gemini | In: text, image, audio, video; Out: text, audio | function_calling, reasoning, vision | 128000 | 8000 | In: $0.50, Out: $2.00 |
| gemini-pro-latest | gemini | In: text, image, pdf, video; Out: text | streaming, function_calling, structured_output, caching | 1048576 | 65536 | In: $0.08, Out: $0.30 |
| gemini-robotics-er-1.5-preview | gemini | In: text, image, pdf, video; Out: text | streaming, function_calling, structured_output, caching | 1048576 | 65536 | In: $0.08, Out: $0.30 |
| imagen-4.0-generate-001 | gemini | In: text, image, pdf; Out: image | streaming | 480 | 8192 | - |
| imagen-4.0-fast-generate-001 | gemini | In: text, image, pdf; Out: image | streaming | 480 | 8192 | - |
| imagen-4.0-ultra-generate-001 | gemini | In: text, image, pdf; Out: image | streaming | 480 | 8192 | - |
| gemini-3-pro-image-preview | gemini | In: text, image, pdf, video; Out: text | streaming, function_calling, structured_output, caching | 131072 | 32768 | In: $0.08, Out: $0.30 |
| nano-banana-pro-preview | gemini | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, caching | 131072 | 32768 | In: $0.08, Out: $0.30 |
| labs-devstral-small-2512 | mistral | In: text, image; Out: text | function_calling, vision, streaming, structured_output, batch, fine_tuning | 256000 | 256000 | - |
| mistral-large-latest | mistral | In: text, image; Out: text | function_calling, vision, streaming, structured_output, batch, fine_tuning | 262144 | 262144 | In: $0.50, Out: $1.50 |
| mistral-large-pixtral-2411 | mistral | In: text, image; Out: text | streaming, function_calling, structured_output, vision, batch, fine_tuning | 32768 | 8192 | - |
| mistral-large-2512 | mistral | In: text, image; Out: text | function_calling, vision, streaming, structured_output, batch, fine_tuning | 262144 | 262144 | In: $0.50, Out: $1.50 |
| mistral-medium-latest | mistral | In: text, image; Out: text | function_calling, vision, streaming, structured_output, batch, fine_tuning | 128000 | 16384 | In: $0.40, Out: $2.00 |
| mistral-medium-2505 | mistral | In: text, image; Out: text | function_calling, vision, streaming, structured_output, batch, fine_tuning | 131072 | 131072 | In: $0.40, Out: $2.00 |
| mistral-medium-2508 | mistral | In: text, image; Out: text | function_calling, vision, streaming, structured_output, batch, fine_tuning | 262144 | 262144 | In: $0.40, Out: $2.00 |
| mistral-small-latest | mistral | In: text, image; Out: text | function_calling, vision, streaming, structured_output, batch, fine_tuning | 128000 | 16384 | In: $0.10, Out: $0.30 |
| mistral-small-2506 | mistral | In: text, image; Out: text | function_calling, vision, streaming, structured_output, batch, fine_tuning | 128000 | 16384 | In: $0.10, Out: $0.30 |
| pixtral-12b | mistral | In: text, image; Out: text | function_calling, vision | 128000 | 128000 | In: $0.15, Out: $0.15 |
| pixtral-large-2411 | mistral | In: text, image; Out: text | streaming, function_calling, structured_output, vision, batch | 32768 | 8192 | - |
| pixtral-large-latest | mistral | In: text, image; Out: text | function_calling, vision, streaming, structured_output, batch | 128000 | 128000 | In: $2.00, Out: $6.00 |
| gpt-4-turbo | openai | In: text, image; Out: text | function_calling, vision, streaming | 128000 | 4096 | In: $10.00, Out: $30.00 |
| gpt-4-turbo-2024-04-09 | openai | In: text, image, pdf; Out: text | streaming, function_calling | 128000 | 4096 | In: $10.00, Out: $30.00 |
| gpt-4-turbo-preview | openai | In: text, image, pdf; Out: text | streaming, function_calling | 128000 | 4096 | In: $10.00, Out: $30.00 |
| gpt-4.1 | openai | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 1047576 | 32768 | In: $2.00, Out: $8.00, Cache: $0.50 |
| gpt-4.1-2025-04-14 | openai | In: text, image, pdf; Out: text | streaming, function_calling, structured_output | 1047576 | 32768 | In: $2.00, Out: $8.00, Cache: $0.50 |
| gpt-4.1-mini-2025-04-14 | openai | In: text, image, pdf; Out: text | streaming, function_calling, structured_output | 1047576 | 32768 | In: $0.40, Out: $1.60, Cache: $0.10 |
| gpt-4.1-nano-2025-04-14 | openai | In: text, image, pdf; Out: text | streaming, function_calling, structured_output | 1047576 | 32768 | In: $0.10, Out: $0.40 |
| gpt-4.1-mini | openai | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 1047576 | 32768 | In: $0.40, Out: $1.60, Cache: $0.10 |
| gpt-4.1-nano | openai | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 1047576 | 32768 | In: $0.10, Out: $0.40, Cache: $0.03 |
| gpt-4o | openai | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 128000 | 16384 | In: $2.50, Out: $10.00, Cache: $1.25 |
| gpt-4o-2024-05-13 | openai | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 128000 | 4096 | In: $5.00, Out: $15.00 |
| gpt-4o-2024-08-06 | openai | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 128000 | 16384 | In: $2.50, Out: $10.00, Cache: $1.25 |
| gpt-4o-2024-11-20 | openai | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 128000 | 16384 | In: $2.50, Out: $10.00, Cache: $1.25 |
| gpt-4o-search-preview | openai | In: text, image, pdf; Out: text | streaming | 128000 | 16384 | In: $2.50, Out: $10.00 |
| gpt-4o-search-preview-2025-03-11 | openai | In: text, image, pdf; Out: text | streaming | 128000 | 16384 | In: $2.50, Out: $10.00 |
| gpt-4o-mini | openai | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 128000 | 16384 | In: $0.15, Out: $0.60, Cache: $0.08 |
| gpt-4o-mini-2024-07-18 | openai | In: text, image, pdf; Out: text | streaming, function_calling, structured_output | 128000 | 16384 | In: $0.15, Out: $0.60 |
| gpt-5 | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5-2025-08-07 | openai | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5-chat-latest | openai | In: text, image; Out: text | structured_output, reasoning, vision, streaming, function_calling | 400000 | 128000 | In: $1.25, Out: $10.00 |
| gpt-5-mini | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $0.25, Out: $2.00, Cache: $0.02 |
| gpt-5-mini-2025-08-07 | openai | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5-nano | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $0.05, Out: $0.40, Cache: $0.01 |
| gpt-5-nano-2025-08-07 | openai | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5-pro | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 272000 | In: $15.00, Out: $120.00 |
| gpt-5-pro-2025-10-06 | openai | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5-search-api | openai | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5-search-api-2025-10-14 | openai | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5-codex | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5.1 | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $1.25, Out: $10.00, Cache: $0.13 |
| gpt-5.1-2025-11-13 | openai | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5.1-chat-latest | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 128000 | 16384 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5.1-codex | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5.1-codex-max | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5.1-codex-mini | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $0.25, Out: $2.00, Cache: $0.02 |
| gpt-5.2 | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $1.75, Out: $14.00, Cache: $0.18 |
| gpt-5.2-2025-12-11 | openai | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5.2-chat-latest | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 128000 | 16384 | In: $1.75, Out: $14.00, Cache: $0.18 |
| gpt-5.2-codex | openai | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $1.75, Out: $14.00, Cache: $0.18 |
| gpt-5.2-pro | openai | In: text, image; Out: text | function_calling, reasoning, vision, streaming, structured_output | 400000 | 128000 | In: $21.00, Out: $168.00 |
| gpt-5.2-pro-2025-12-11 | openai | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5.3-codex | openai | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $1.75, Out: $14.00, Cache: $0.18 |
| gpt-5.3-codex-spark | openai | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 128000 | 32000 | In: $1.75, Out: $14.00, Cache: $0.18 |
| o1-2024-12-17 | openai | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 200000 | 100000 | In: $15.00, Out: $60.00 |
| o1-pro-2025-03-19 | openai | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 200000 | 100000 | In: $150.00, Out: $600.00 |
| omni-moderation-2024-09-26 | openai | In: text, image, pdf; Out: text, moderation | - | - | - | - |
| omni-moderation-latest | openai | In: text, image, pdf; Out: text, moderation | - | - | - | - |
| o1 | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 100000 | In: $15.00, Out: $60.00, Cache: $7.50 |
| o1-pro | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 100000 | In: $150.00, Out: $600.00 |
| o3 | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 100000 | In: $2.00, Out: $8.00, Cache: $0.50 |
| o3-deep-research | openai | In: text, image; Out: text | function_calling, reasoning, vision, streaming | 200000 | 100000 | In: $10.00, Out: $40.00, Cache: $2.50 |
| o3-pro | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 100000 | In: $20.00, Out: $80.00 |
| o4-mini | openai | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 100000 | In: $1.10, Out: $4.40, Cache: $0.28 |
| o4-mini-deep-research | openai | In: text, image; Out: text | function_calling, reasoning, vision, streaming | 200000 | 100000 | In: $2.00, Out: $8.00, Cache: $0.50 |
| allenai/molmo-2-8b | openrouter | In: text, image, video; Out: text | streaming, predicted_outputs | 36864 | 36864 | In: $0.20, Out: $0.20 |
| amazon/nova-2-lite-v1 | openrouter | In: text, image, video, file; Out: text | streaming, function_calling | 1000000 | 65535 | In: $0.30, Out: $2.50 |
| amazon/nova-lite-v1 | openrouter | In: text, image; Out: text | streaming, function_calling | 300000 | 5120 | In: $0.06, Out: $0.24 |
| amazon/nova-premier-v1 | openrouter | In: text, image; Out: text | streaming, function_calling | 1000000 | 32000 | In: $2.50, Out: $12.50, Cache: $0.62 |
| amazon/nova-pro-v1 | openrouter | In: text, image; Out: text | streaming, function_calling | 300000 | 5120 | In: $0.80, Out: $3.20 |
| anthropic/claude-3-haiku | openrouter | In: text, image; Out: text | streaming, function_calling | 200000 | 4096 | In: $0.25, Out: $1.25, Cache: $0.03 |
| anthropic/claude-3.5-sonnet | openrouter | In: text, image, file; Out: text | streaming, function_calling | 200000 | 8192 | In: $6.00, Out: $30.00, Cache: $0.60 |
| anthropic/claude-3.7-sonnet:thinking | openrouter | In: text, image, file; Out: text | streaming, function_calling | 200000 | 64000 | In: $3.00, Out: $15.00, Cache: $0.30 |
| arcee-ai/spotlight | openrouter | In: image, text; Out: text | streaming, predicted_outputs | 131072 | 65537 | In: $0.18, Out: $0.18 |
| openrouter/auto | openrouter | In: text, image, audio, file, video; Out: text, image | streaming, function_calling, structured_output, predicted_outputs | 2000000 | - | - |
| baidu/ernie-4.5-vl-28b-a3b | openrouter | In: text, image; Out: text | streaming, function_calling | 30000 | 8000 | In: $0.14, Out: $0.56 |
| baidu/ernie-4.5-vl-424b-a47b | openrouter | In: image, text; Out: text | streaming | 123000 | 16000 | In: $0.42, Out: $1.25 |
| bytedance-seed/seed-1.6 | openrouter | In: image, text, video; Out: text | streaming, function_calling, structured_output | 262144 | 32768 | In: $0.25, Out: $2.00 |
| bytedance-seed/seed-1.6-flash | openrouter | In: image, text, video; Out: text | streaming, function_calling, structured_output | 262144 | 32768 | In: $0.08, Out: $0.30 |
| bytedance/ui-tars-1.5-7b | openrouter | In: image, text; Out: text | streaming, predicted_outputs | 128000 | 2048 | In: $0.10, Out: $0.20 |
| anthropic/claude-3.5-haiku | openrouter | In: text, image, pdf; Out: text | function_calling, vision, streaming | 200000 | 8192 | In: $0.80, Out: $4.00, Cache: $0.08 |
| anthropic/claude-haiku-4.5 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 64000 | In: $1.00, Out: $5.00, Cache: $0.10 |
| anthropic/claude-opus-4 | openrouter | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 32000 | In: $15.00, Out: $75.00, Cache: $1.50 |
| anthropic/claude-opus-4.1 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 32000 | In: $15.00, Out: $75.00, Cache: $1.50 |
| anthropic/claude-opus-4.5 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 32000 | In: $5.00, Out: $25.00, Cache: $0.50 |
| anthropic/claude-opus-4.6 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache: $0.50 |
| anthropic/claude-3.7-sonnet | openrouter | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 128000 | In: $15.00, Out: $75.00, Cache: $1.50 |
| anthropic/claude-sonnet-4 | openrouter | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 64000 | In: $3.00, Out: $15.00, Cache: $0.30 |
| anthropic/claude-sonnet-4.5 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 64000 | In: $3.00, Out: $15.00, Cache: $0.30 |
| anthropic/claude-sonnet-4.6 | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 128000 | In: $3.00, Out: $15.00, Cache: $0.30 |
| black-forest-labs/flux.2-flex | openrouter | In: image, text; Out: image | vision | 67344 | 67344 | - |
| black-forest-labs/flux.2-klein-4b | openrouter | In: image, text; Out: image | vision | 40960 | 40960 | - |
| black-forest-labs/flux.2-max | openrouter | In: image, text; Out: image | vision | 46864 | 46864 | - |
| black-forest-labs/flux.2-pro | openrouter | In: image, text; Out: image | vision | 46864 | 46864 | - |
| openrouter/free | openrouter | In: text, image; Out: text | streaming, function_calling, structured_output | 200000 | - | - |
| z-ai/glm-4.5v | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, streaming | 64000 | 16384 | In: $0.60, Out: $1.80 |
| openai/gpt-4.1 | openrouter | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 1047576 | 32768 | In: $2.00, Out: $8.00, Cache: $0.50 |
| openai/gpt-4.1-mini | openrouter | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 1047576 | 32768 | In: $0.40, Out: $1.60, Cache: $0.10 |
| openai/gpt-4o-mini | openrouter | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 128000 | 16384 | In: $0.15, Out: $0.60, Cache: $0.08 |
| openai/gpt-5 | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $1.25, Out: $10.00 |
| openai/gpt-5-chat | openrouter | In: text, image; Out: text | structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $1.25, Out: $10.00 |
| openai/gpt-5-codex | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| openai/gpt-5-image | openrouter | In: text, image, pdf; Out: text, image | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $5.00, Out: $10.00, Cache: $1.25 |
| openai/gpt-5-mini | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $0.25, Out: $2.00 |
| openai/gpt-5-nano | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $0.05, Out: $0.40 |
| openai/gpt-5-pro | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 272000 | In: $15.00, Out: $120.00 |
| openai/gpt-5.1 | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| openai/gpt-5.1-chat | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 128000 | 16384 | In: $1.25, Out: $10.00, Cache: $0.12 |
| openai/gpt-5.1-codex | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| openai/gpt-5.1-codex-max | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $1.10, Out: $9.00, Cache: $0.11 |
| openai/gpt-5.1-codex-mini | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 100000 | In: $0.25, Out: $2.00, Cache: $0.02 |
| openai/gpt-5.2 | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $1.75, Out: $14.00, Cache: $0.18 |
| openai/gpt-5.2-chat | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 128000 | 16384 | In: $1.75, Out: $14.00, Cache: $0.18 |
| openai/gpt-5.2-pro | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $21.00, Out: $168.00 |
| openai/gpt-5.2-codex | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $1.75, Out: $14.00, Cache: $0.18 |
| google/gemini-2.0-flash-001 | openrouter | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, vision, streaming | 1048576 | 8192 | In: $0.10, Out: $0.40, Cache: $0.02 |
| google/gemini-2.0-flash-exp:free | openrouter | In: text, image; Out: text | function_calling, vision | 1048576 | 1048576 | - |
| google/gemini-2.5-flash | openrouter | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1048576 | 65536 | In: $0.30, Out: $2.50, Cache: $0.04 |
| google/gemini-2.5-flash-lite | openrouter | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1048576 | 65536 | In: $0.10, Out: $0.40, Cache: $0.02 |
| google/gemini-2.5-flash-lite-preview-09-2025 | openrouter | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1048576 | 65536 | In: $0.10, Out: $0.40, Cache: $0.02 |
| google/gemini-2.5-flash-preview-09-2025 | openrouter | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1048576 | 65536 | In: $0.30, Out: $2.50, Cache: $0.03 |
| google/gemini-2.5-pro | openrouter | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1048576 | 65536 | In: $1.25, Out: $10.00, Cache: $0.31 |
| google/gemini-2.5-pro-preview-05-06 | openrouter | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1048576 | 65536 | In: $1.25, Out: $10.00, Cache: $0.31 |
| google/gemini-2.5-pro-preview-06-05 | openrouter | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1048576 | 65536 | In: $1.25, Out: $10.00, Cache: $0.31 |
| google/gemini-3-flash-preview | openrouter | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1048576 | 65536 | In: $0.50, Out: $3.00, Cache: $0.05 |
| google/gemini-3-pro-preview | openrouter | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1050000 | 66000 | In: $2.00, Out: $12.00 |
| google/gemini-3.1-pro-preview | openrouter | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1048576 | 65536 | In: $2.00, Out: $12.00 |
| google/gemma-3-12b-it | openrouter | In: text, image; Out: text | structured_output, vision, streaming, predicted_outputs | 131072 | 131072 | In: $0.03, Out: $0.10 |
| google/gemma-3-12b-it:free | openrouter | In: text, image; Out: text | vision, streaming | 32768 | 8192 | - |
| google/gemma-3-27b-it | openrouter | In: text, image; Out: text | function_calling, structured_output, vision, streaming, predicted_outputs | 96000 | 96000 | In: $0.04, Out: $0.15 |
| google/gemma-3-27b-it:free | openrouter | In: text, image; Out: text | function_calling, vision, streaming, structured_output | 131072 | 8192 | - |
| google/gemma-3-4b-it | openrouter | In: text, image; Out: text | vision, streaming, structured_output | 96000 | 96000 | In: $0.02, Out: $0.07 |
| google/gemma-3-4b-it:free | openrouter | In: text, image; Out: text | vision, streaming, structured_output | 32768 | 8192 | - |
| google/gemini-2.0-flash-lite-001 | openrouter | In: text, image, file, audio, video; Out: text | streaming, function_calling, structured_output | 1048576 | 8192 | In: $0.08, Out: $0.30 |
| google/gemini-2.5-flash-image | openrouter | In: image, text; Out: image, text | streaming, structured_output | 32768 | 32768 | In: $0.30, Out: $2.50, Cache: $0.03 |
| google/gemini-2.5-pro-preview | openrouter | In: file, image, text, audio; Out: text | streaming, function_calling, structured_output | 1048576 | 65536 | In: $1.25, Out: $10.00, Cache: $0.12 |
| google/gemini-3-pro-image-preview | openrouter | In: image, text; Out: image, text | streaming, structured_output | 65536 | 32768 | In: $2.00, Out: $12.00, Cache: $0.20 |
| x-ai/grok-4-fast | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 2000000 | 30000 | In: $0.20, Out: $0.50, Cache: $0.05 |
| x-ai/grok-4.1-fast | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 2000000 | 30000 | In: $0.20, Out: $0.50, Cache: $0.05 |
| moonshotai/kimi-k2.5 | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, streaming, predicted_outputs | 262144 | 262144 | In: $0.60, Out: $3.00, Cache: $0.10 |
| meta-llama/llama-3.2-11b-vision-instruct | openrouter | In: text, image; Out: text | vision, streaming, structured_output, predicted_outputs | 131072 | 8192 | In: $0.05, Out: $0.05 |
| meta-llama/llama-3.2-3b-instruct:free | openrouter | In: text, image; Out: text | vision, streaming | 131072 | 131072 | - |
| meta-llama/llama-4-scout:free | openrouter | In: text, image; Out: text | function_calling, structured_output, vision | 64000 | 64000 | - |
| meta-llama/llama-4-maverick | openrouter | In: text, image; Out: text | streaming, function_calling, structured_output, predicted_outputs | 1048576 | 16384 | In: $0.15, Out: $0.60 |
| meta-llama/llama-4-scout | openrouter | In: text, image; Out: text | streaming, function_calling, structured_output | 327680 | 16384 | In: $0.08, Out: $0.30 |
| meta-llama/llama-guard-4-12b | openrouter | In: image, text; Out: text | streaming, structured_output, predicted_outputs | 163840 | - | In: $0.18, Out: $0.18 |
| minimax/minimax-01 | openrouter | In: text, image; Out: text | function_calling, reasoning, vision, streaming | 1000000 | 1000000 | In: $0.20, Out: $1.10 |
| mistralai/mistral-medium-3 | openrouter | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 131072 | 131072 | In: $0.40, Out: $2.00 |
| mistralai/mistral-medium-3.1 | openrouter | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 262144 | 262144 | In: $0.40, Out: $2.00 |
| mistralai/mistral-small-3.1-24b-instruct | openrouter | In: text, image; Out: text | function_calling, structured_output, vision, streaming | 128000 | 8192 | In: $0.35, Out: $0.56 |
| mistralai/mistral-small-3.2-24b-instruct:free | openrouter | In: text, image; Out: text | function_calling, structured_output, vision | 96000 | 96000 | - |
| mistralai/mistral-small-3.2-24b-instruct | openrouter | In: text, image; Out: text | function_calling, structured_output, vision, streaming, predicted_outputs | 96000 | 8192 | In: $0.06, Out: $0.18, Cache: $0.03 |
| mistralai/ministral-14b-2512 | openrouter | In: text, image; Out: text | streaming, function_calling, structured_output, predicted_outputs | 262144 | - | In: $0.20, Out: $0.20 |
| mistralai/ministral-3b-2512 | openrouter | In: text, image; Out: text | streaming, function_calling, structured_output | 131072 | - | In: $0.10, Out: $0.10 |
| mistralai/ministral-8b-2512 | openrouter | In: text, image; Out: text | streaming, function_calling, structured_output | 262144 | - | In: $0.15, Out: $0.15 |
| mistralai/mistral-large-2512 | openrouter | In: text, image; Out: text | streaming, function_calling, structured_output | 262144 | - | In: $0.50, Out: $1.50 |
| mistralai/mistral-small-3.1-24b-instruct:free | openrouter | In: text, image; Out: text | streaming, function_calling, structured_output | 128000 | - | - |
| mistralai/pixtral-large-2411 | openrouter | In: text, image; Out: text | streaming, function_calling, structured_output | 131072 | - | In: $2.00, Out: $6.00 |
| allenai/molmo-2-8b:free | openrouter | In: text, image, video; Out: text | reasoning, vision | 36864 | 36864 | - |
| nvidia/nemotron-nano-12b-v2-vl | openrouter | In: image, text, video; Out: text | streaming, structured_output | 131072 | - | In: $0.07, Out: $0.20 |
| nvidia/nemotron-nano-12b-v2-vl:free | openrouter | In: text, image; Out: text | function_calling, reasoning, vision, streaming | 128000 | 128000 | - |
| openai/gpt-4-turbo | openrouter | In: text, image; Out: text | streaming, function_calling, structured_output | 128000 | 4096 | In: $10.00, Out: $30.00 |
| openai/gpt-4.1-nano | openrouter | In: image, text, file; Out: text | streaming, function_calling, structured_output | 1047576 | 32768 | In: $0.10, Out: $0.40, Cache: $0.02 |
| openai/gpt-4o | openrouter | In: text, image, file; Out: text | streaming, function_calling, structured_output | 128000 | 16384 | In: $2.50, Out: $10.00, Cache: $1.25 |
| openai/gpt-4o-2024-05-13 | openrouter | In: text, image, file; Out: text | streaming, function_calling, structured_output | 128000 | 4096 | In: $5.00, Out: $15.00 |
| openai/gpt-4o-2024-08-06 | openrouter | In: text, image, file; Out: text | streaming, function_calling, structured_output | 128000 | 16384 | In: $2.50, Out: $10.00, Cache: $1.25 |
| openai/gpt-4o-2024-11-20 | openrouter | In: text, image, file; Out: text | streaming, function_calling, structured_output | 128000 | 16384 | In: $2.50, Out: $10.00, Cache: $1.25 |
| openai/gpt-4o:extended | openrouter | In: text, image, file; Out: text | streaming, function_calling, structured_output | 128000 | 64000 | In: $6.00, Out: $18.00 |
| openai/gpt-4o-mini-2024-07-18 | openrouter | In: text, image, file; Out: text | streaming, function_calling, structured_output | 128000 | 16384 | In: $0.15, Out: $0.60, Cache: $0.08 |
| openai/gpt-5-image-mini | openrouter | In: file, image, text; Out: image, text | streaming, function_calling, structured_output | 400000 | 128000 | In: $2.50, Out: $2.00, Cache: $0.25 |
| openai/gpt-5.3-codex | openrouter | In: text, image; Out: text | streaming, function_calling, structured_output | 400000 | 128000 | In: $1.75, Out: $14.00, Cache: $0.18 |
| openai/o1 | openrouter | In: text, image, file; Out: text | streaming, function_calling, structured_output | 200000 | 100000 | In: $15.00, Out: $60.00, Cache: $7.50 |
| openai/o1-pro | openrouter | In: text, image, file; Out: text | streaming, structured_output | 200000 | 100000 | In: $150.00, Out: $600.00 |
| openai/o3 | openrouter | In: image, text, file; Out: text | streaming, function_calling, structured_output | 200000 | 100000 | In: $2.00, Out: $8.00, Cache: $0.50 |
| openai/o3-deep-research | openrouter | In: image, text, file; Out: text | streaming, function_calling, structured_output | 200000 | 100000 | In: $10.00, Out: $40.00, Cache: $2.50 |
| openai/o3-pro | openrouter | In: text, file, image; Out: text | streaming, function_calling, structured_output | 200000 | 100000 | In: $20.00, Out: $80.00 |
| openai/o4-mini-deep-research | openrouter | In: file, image, text; Out: text | streaming, function_calling, structured_output | 200000 | 100000 | In: $2.00, Out: $8.00, Cache: $0.50 |
| openai/o4-mini-high | openrouter | In: image, text, file; Out: text | streaming, function_calling, structured_output | 200000 | 100000 | In: $1.10, Out: $4.40, Cache: $0.28 |
| opengvlab/internvl3-78b | openrouter | In: image, text; Out: text | streaming, structured_output | 32768 | 32768 | In: $0.15, Out: $0.60, Cache: $0.08 |
| perplexity/sonar | openrouter | In: text, image; Out: text | streaming | 127072 | - | In: $1.00, Out: $1.00 |
| perplexity/sonar-pro | openrouter | In: text, image; Out: text | streaming | 200000 | 8000 | In: $3.00, Out: $15.00 |
| perplexity/sonar-pro-search | openrouter | In: text, image; Out: text | streaming | 200000 | 8000 | In: $3.00, Out: $15.00 |
| perplexity/sonar-reasoning-pro | openrouter | In: text, image; Out: text | streaming | 128000 | - | In: $2.00, Out: $8.00 |
| qwen/qwen2.5-vl-32b-instruct:free | openrouter | In: text, image, video; Out: text | function_calling, structured_output, vision | 8192 | 8192 | - |
| qwen/qwen2.5-vl-72b-instruct | openrouter | In: text, image; Out: text | structured_output, vision, streaming, predicted_outputs | 32768 | 8192 | In: $0.80, Out: $0.80 |
| qwen/qwen2.5-vl-72b-instruct:free | openrouter | In: text, image; Out: text | function_calling, vision | 32768 | 32768 | - |
| qwen/qwen-2.5-vl-7b-instruct:free | openrouter | In: text, image; Out: text | function_calling, vision | 32768 | 32768 | - |
| qwen/qwen3.5-397b-a17b | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, streaming, predicted_outputs | 262144 | 65536 | In: $0.60, Out: $3.60 |
| qwen/qwen3.5-plus-02-15 | openrouter | In: text, image, video; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 65536 | In: $0.40, Out: $2.40 |
| qwen/qwen-vl-max | openrouter | In: text, image; Out: text | streaming, function_calling, structured_output | 131072 | 32768 | In: $0.80, Out: $3.20 |
| qwen/qwen-vl-plus | openrouter | In: text, image; Out: text | streaming, structured_output | 131072 | 8192 | In: $0.21, Out: $0.63, Cache: $0.04 |
| qwen/qwen2.5-vl-32b-instruct | openrouter | In: text, image; Out: text | streaming, structured_output | 128000 | - | In: $0.20, Out: $0.60 |
| qwen/qwen-2.5-vl-7b-instruct | openrouter | In: text, image; Out: text | streaming, predicted_outputs | 32768 | - | In: $0.20, Out: $0.20 |
| qwen/qwen3-vl-235b-a22b-instruct | openrouter | In: text, image; Out: text | streaming, function_calling, structured_output, predicted_outputs | 262144 | - | In: $0.20, Out: $0.88, Cache: $0.11 |
| qwen/qwen3-vl-235b-a22b-thinking | openrouter | In: text, image; Out: text | streaming, function_calling, structured_output | 131072 | 32768 | - |
| qwen/qwen3-vl-30b-a3b-instruct | openrouter | In: text, image; Out: text | streaming, function_calling, structured_output | 131072 | 32768 | In: $0.13, Out: $0.52 |
| qwen/qwen3-vl-30b-a3b-thinking | openrouter | In: text, image; Out: text | streaming, function_calling, structured_output | 131072 | 32768 | - |
| qwen/qwen3-vl-32b-instruct | openrouter | In: text, image; Out: text | streaming, function_calling, structured_output, predicted_outputs | 131072 | 32768 | In: $0.10, Out: $0.42 |
| qwen/qwen3-vl-8b-instruct | openrouter | In: image, text; Out: text | streaming, function_calling, structured_output, predicted_outputs | 131072 | 32768 | In: $0.08, Out: $0.50 |
| qwen/qwen3-vl-8b-thinking | openrouter | In: image, text; Out: text | streaming, function_calling, structured_output | 131072 | 32768 | In: $0.12, Out: $1.36 |
| sourceful/riverflow-v2-fast-preview | openrouter | In: text, image; Out: image | vision | 8192 | 8192 | - |
| sourceful/riverflow-v2-max-preview | openrouter | In: text, image; Out: image | vision | 8192 | 8192 | - |
| sourceful/riverflow-v2-standard-preview | openrouter | In: text, image; Out: image | vision | 8192 | 8192 | - |
| bytedance-seed/seedream-4.5 | openrouter | In: image, text; Out: image | vision | 4096 | 4096 | - |
| openrouter/sherlock-dash-alpha | openrouter | In: text, image; Out: text | function_calling, vision | 1840000 | 0 | - |
| openrouter/sherlock-think-alpha | openrouter | In: text, image; Out: text | function_calling, reasoning, vision | 1840000 | 0 | - |
| z-ai/glm-4.6v | openrouter | In: image, text, video; Out: text | streaming, function_calling, structured_output | 131072 | 131072 | In: $0.30, Out: $0.90 |
| openai/o4-mini | openrouter | In: text, image; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 100000 | In: $1.10, Out: $4.40, Cache: $0.28 |
| sonar-pro | perplexity | In: text, image; Out: text | vision, streaming, json_mode | 200000 | 8192 | In: $3.00, Out: $15.00 |
| sonar-reasoning-pro | perplexity | In: text, image; Out: text | reasoning, vision, streaming, json_mode | 128000 | 4096 | In: $2.00, Out: $8.00 |
| gemini-1.5-flash | vertexai | In: text, image, audio, video; Out: text | function_calling, vision, streaming | 1000000 | 8192 | In: $0.08, Out: $0.30, Cache: $0.02 |
| gemini-1.5-flash-8b | vertexai | In: text, image, audio, video; Out: text | function_calling, vision, streaming | 1000000 | 8192 | In: $0.04, Out: $0.15, Cache: $0.01 |
| gemini-1.5-pro | vertexai | In: text, image, audio, video; Out: text | function_calling, vision, streaming | 1000000 | 8192 | In: $1.25, Out: $5.00, Cache: $0.31 |
| gemini-2.0-flash | vertexai | In: text, image, audio, video, pdf; Out: text | function_calling, vision, streaming | 1048576 | 8192 | In: $0.15, Out: $0.60, Cache: $0.02 |
| gemini-2.0-flash-lite | vertexai | In: text, image, audio, video, pdf; Out: text | function_calling, vision | 1048576 | 8192 | In: $0.08, Out: $0.30 |
| gemini-2.5-flash | vertexai | In: text, image, audio, video, pdf; Out: text | function_calling, reasoning, vision, streaming | 1048576 | 65536 | In: $0.30, Out: $2.50, Cache: $0.08 |
| gemini-2.5-flash-lite | vertexai | In: text, image, audio, video, pdf; Out: text | function_calling, reasoning, vision, streaming | 1048576 | 65536 | In: $0.10, Out: $0.40, Cache: $0.02 |
| gemini-2.5-flash-lite-preview-06-17 | vertexai | In: text, image, audio, video, pdf; Out: text | function_calling, reasoning, vision | 65536 | 65536 | In: $0.10, Out: $0.40, Cache: $0.02 |
| gemini-2.5-flash-lite-preview-09-2025 | vertexai | In: text, image, audio, video, pdf; Out: text | function_calling, reasoning, vision | 1048576 | 65536 | In: $0.10, Out: $0.40, Cache: $0.02 |
| gemini-2.5-flash-preview-04-17 | vertexai | In: text, image, audio, video, pdf; Out: text | function_calling, reasoning, vision, streaming | 1048576 | 65536 | In: $0.15, Out: $0.60, Cache: $0.04 |
| gemini-2.5-flash-preview-05-20 | vertexai | In: text, image, audio, video, pdf; Out: text | function_calling, reasoning, vision | 1048576 | 65536 | In: $0.15, Out: $0.60, Cache: $0.04 |
| gemini-2.5-flash-preview-09-2025 | vertexai | In: text, image, audio, video, pdf; Out: text | function_calling, reasoning, vision | 1048576 | 65536 | In: $0.30, Out: $2.50, Cache: $0.08 |
| gemini-2.5-pro | vertexai | In: text, image, audio, video, pdf; Out: text | function_calling, reasoning, vision, streaming | 1048576 | 65536 | In: $1.25, Out: $10.00, Cache: $0.31 |
| gemini-2.5-pro-preview-05-06 | vertexai | In: text, image, audio, video, pdf; Out: text | function_calling, reasoning, vision | 1048576 | 65536 | In: $1.25, Out: $10.00, Cache: $0.31 |
| gemini-2.5-pro-preview-06-05 | vertexai | In: text, image, audio, video, pdf; Out: text | function_calling, reasoning, vision | 1048576 | 65536 | In: $1.25, Out: $10.00, Cache: $0.31 |
| gemini-3-flash-preview | vertexai | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1048576 | 65536 | In: $0.50, Out: $3.00, Cache: $0.05 |
| gemini-3-pro-preview | vertexai | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1048576 | 65536 | In: $2.00, Out: $12.00, Cache: $0.20 |
| gemini-3.1-pro-preview | vertexai | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1048576 | 65536 | In: $2.00, Out: $12.00, Cache: $0.20 |
| gemini-3.1-pro-preview-customtools | vertexai | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1048576 | 65536 | In: $2.00, Out: $12.00, Cache: $0.20 |
| gemini-flash-latest | vertexai | In: text, image, audio, video, pdf; Out: text | function_calling, reasoning, vision | 1048576 | 65536 | In: $0.30, Out: $2.50, Cache: $0.08 |
| gemini-flash-lite-latest | vertexai | In: text, image, audio, video, pdf; Out: text | function_calling, reasoning, vision | 1048576 | 65536 | In: $0.10, Out: $0.40, Cache: $0.02 |
| meta/llama-4-maverick-17b-128e-instruct-maas | vertexai | In: text, image; Out: text | function_calling, structured_output, vision | 524288 | 8192 | In: $0.35, Out: $1.15 |
| voyage-multimodal-3 | voyage | In: text, image; Out: embeddings | - | 32000 | - | In: $0.12 |
| voyage-multimodal-3.5 | voyage | In: text, image, video; Out: embeddings | - | 32000 | - | In: $0.12 |
| grok-2-vision-1212 | xai | In: text, image; Out: text | streaming, function_calling, structured_output, vision | - | - | - |
| grok-4-0709 | xai | In: text, image; Out: text | streaming, function_calling, structured_output, reasoning, vision | - | - | - |
| grok-4-1-fast-non-reasoning | xai | In: text, image; Out: text | streaming, function_calling, structured_output, vision | - | - | - |
| grok-4-1-fast-reasoning | xai | In: text, image; Out: text | streaming, function_calling, structured_output, reasoning, vision | - | - | - |
| grok-4-fast-non-reasoning | xai | In: text, image; Out: text | streaming, function_calling, structured_output, vision | - | - | - |
| grok-4-fast-reasoning | xai | In: text, image; Out: text | streaming, function_calling, structured_output, reasoning, vision | - | - | - |


### Audio Input Models (111)

Models that can process audio:

| Model | Provider | I/O | Capabilities | Context | Max Output | Standard Pricing (per 1M tokens) |
| :-- | :-- | :-- | :-- | --: | --: | :-- |
| gpt-4o-audio-mai | azure | In: text, audio; Out: text, audio | streaming, speech_generation, transcription | 128000 | 16384 | In: $2.50, Out: $10.00 |
| gpt-4o-audio-preview-2024-10-01 | azure | In: text, audio; Out: text, audio | streaming, speech_generation, transcription | 128000 | 16384 | In: $2.50, Out: $10.00 |
| gpt-4o-audio-preview-2024-12-17 | azure | In: text, audio; Out: text, audio | streaming, speech_generation, transcription | 128000 | 16384 | In: $2.50, Out: $10.00 |
| gpt-4o-audio-preview-2025-06-03 | azure | In: text, audio; Out: text, audio | streaming, speech_generation, transcription | 128000 | 16384 | In: $2.50, Out: $10.00 |
| gpt-4o-mini-audio-preview-2024-12-17 | azure | In: text, audio; Out: text, audio | streaming, speech_generation, transcription | 128000 | 16384 | In: $0.15, Out: $0.60 |
| gpt-4o-mini-transcribe | azure | In: text, audio; Out: text | streaming | 16000 | 2000 | In: $1.25, Out: $5.00 |
| gpt-4o-mini-transcribe-2025-03-20 | azure | In: text, audio; Out: text | streaming | 16000 | 2000 | In: $1.25, Out: $5.00 |
| gpt-4o-mini-transcribe-2025-12-15 | azure | In: text, audio; Out: text | streaming | 16000 | 2000 | In: $1.25, Out: $5.00 |
| gpt-4o-mini-tts | azure | In: text, audio; Out: text, audio | streaming | - | - | In: $0.60, Out: $12.00 |
| gpt-4o-mini-tts-2025-03-20 | azure | In: text, audio; Out: text, audio | streaming | - | - | In: $0.60, Out: $12.00 |
| gpt-4o-mini-tts-2025-12-15 | azure | In: text, audio; Out: text, audio | streaming | - | - | In: $0.60, Out: $12.00 |
| gpt-4o-transcribe | azure | In: text, audio; Out: text | streaming | 128000 | 16384 | In: $2.50, Out: $10.00 |
| gpt-4o-transcribe-2025-03-20 | azure | In: text, audio; Out: text | streaming | 128000 | 16384 | In: $2.50, Out: $10.00 |
| gpt-4o-transcribe-diarize | azure | In: text, audio; Out: text | streaming | 128000 | 16384 | In: $2.50, Out: $10.00 |
| gpt-4o-transcribe-diarize-2025-10-15 | azure | In: text, audio; Out: text | streaming | 128000 | 16384 | In: $2.50, Out: $10.00 |
| gpt-audio-2025-08-28 | azure | In: text, audio; Out: text, audio | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| gpt-audio-mini-2025-10-06 | azure | In: text, audio; Out: text, audio | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| whisper | azure | In: text, audio; Out: text | streaming | - | - | In: $0.01, Out: $0.01 |
| whisper-001 | azure | In: text, audio; Out: text | streaming | - | - | In: $0.01, Out: $0.01 |
| amazon.nova-2-sonic-v1:0 | bedrock | In: audio; Out: audio, text | streaming, function_calling | - | - | - |
| mistral.voxtral-mini-3b-2507 | bedrock | In: audio, text; Out: text | function_calling, streaming | 128000 | 4096 | In: $0.04, Out: $0.04 |
| mistral.voxtral-small-24b-2507 | bedrock | In: text, audio; Out: text | function_calling, streaming | 32000 | 8192 | In: $0.15, Out: $0.35 |
| gemini-1.5-flash | gemini | In: text, image, audio, video; Out: text | function_calling, vision | 1000000 | 8192 | In: $0.08, Out: $0.30, Cache: $0.02 |
| gemini-1.5-flash-8b | gemini | In: text, image, audio, video; Out: text | function_calling, vision | 1000000 | 8192 | In: $0.04, Out: $0.15, Cache: $0.01 |
| gemini-1.5-pro | gemini | In: text, image, audio, video; Out: text | function_calling, vision | 1000000 | 8192 | In: $1.25, Out: $5.00, Cache: $0.31 |
| gemini-2.0-flash | gemini | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, vision, streaming, batch, caching | 1048576 | 8192 | In: $0.10, Out: $0.40, Cache: $0.02 |
| gemini-2.0-flash-lite | gemini | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, vision, streaming, batch | 1048576 | 8192 | In: $0.08, Out: $0.30 |
| gemini-2.5-flash | gemini | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming, batch, caching | 1048576 | 65536 | In: $0.30, Out: $2.50, Cache: $0.08 |
| gemini-2.5-flash-lite | gemini | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming, batch | 1048576 | 65536 | In: $0.10, Out: $0.40, Cache: $0.02 |
| gemini-2.5-flash-lite-preview-06-17 | gemini | In: text, image, audio, video, pdf; Out: text | function_calling, reasoning, vision | 1048576 | 65536 | In: $0.10, Out: $0.40, Cache: $0.02 |
| gemini-2.5-flash-lite-preview-09-2025 | gemini | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming, batch | 1048576 | 65536 | In: $0.10, Out: $0.40, Cache: $0.02 |
| gemini-2.5-flash-native-audio-latest | gemini | In: text, image, pdf, video, audio; Out: text | streaming, function_calling, structured_output, batch, caching | 131072 | 8192 | In: $0.08, Out: $0.30 |
| gemini-2.5-flash-native-audio-preview-09-2025 | gemini | In: text, image, pdf, video, audio; Out: text | streaming, function_calling, structured_output, batch, caching | 131072 | 8192 | In: $0.08, Out: $0.30 |
| gemini-2.5-flash-native-audio-preview-12-2025 | gemini | In: text, image, pdf, video, audio; Out: text | streaming, function_calling, structured_output, batch, caching | 131072 | 8192 | In: $0.08, Out: $0.30 |
| gemini-2.5-flash-preview-04-17 | gemini | In: text, image, audio, video, pdf; Out: text | function_calling, reasoning, vision | 1048576 | 65536 | In: $0.15, Out: $0.60, Cache: $0.04 |
| gemini-2.5-flash-preview-05-20 | gemini | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1048576 | 65536 | In: $0.15, Out: $0.60, Cache: $0.04 |
| gemini-2.5-flash-preview-09-2025 | gemini | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1048576 | 65536 | In: $0.30, Out: $2.50, Cache: $0.08 |
| gemini-2.5-pro | gemini | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming, caching | 1048576 | 65536 | In: $1.25, Out: $10.00, Cache: $0.31 |
| gemini-2.5-pro-preview-05-06 | gemini | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1048576 | 65536 | In: $1.25, Out: $10.00, Cache: $0.31 |
| gemini-2.5-pro-preview-06-05 | gemini | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1048576 | 65536 | In: $1.25, Out: $10.00, Cache: $0.31 |
| gemini-3-flash-preview | gemini | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming, batch, caching | 1048576 | 65536 | In: $0.50, Out: $3.00, Cache: $0.05 |
| gemini-3-pro-preview | gemini | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming, caching | 1000000 | 64000 | In: $2.00, Out: $12.00, Cache: $0.20 |
| gemini-3.1-pro-preview | gemini | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming, caching | 1048576 | 65536 | In: $2.00, Out: $12.00, Cache: $0.20 |
| gemini-3.1-pro-preview-customtools | gemini | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming, caching | 1048576 | 65536 | In: $2.00, Out: $12.00, Cache: $0.20 |
| gemini-flash-latest | gemini | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming, batch, caching | 1048576 | 65536 | In: $0.30, Out: $2.50, Cache: $0.08 |
| gemini-flash-lite-latest | gemini | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming, batch | 1048576 | 65536 | In: $0.10, Out: $0.40, Cache: $0.02 |
| gemini-live-2.5-flash | gemini | In: text, image, audio, video; Out: text, audio | function_calling, reasoning, vision | 128000 | 8000 | In: $0.50, Out: $2.00 |
| gemini-live-2.5-flash-preview-native-audio | gemini | In: text, audio, video; Out: text, audio | function_calling, reasoning, vision | 131072 | 65536 | In: $0.50, Out: $2.00 |
| gpt-4o-audio-preview | openai | In: text, audio; Out: text, audio | streaming, speech_generation, transcription | 128000 | 16384 | In: $2.50, Out: $10.00 |
| gpt-4o-audio-preview-2024-12-17 | openai | In: text, audio; Out: text, audio | streaming, speech_generation, transcription | 128000 | 16384 | In: $2.50, Out: $10.00 |
| gpt-4o-audio-preview-2025-06-03 | openai | In: text, audio; Out: text, audio | streaming, speech_generation, transcription | 128000 | 16384 | In: $2.50, Out: $10.00 |
| gpt-4o-mini-audio-preview | openai | In: text, audio; Out: text, audio | streaming, speech_generation, transcription | 128000 | 16384 | In: $0.15, Out: $0.60 |
| gpt-4o-mini-audio-preview-2024-12-17 | openai | In: text, audio; Out: text, audio | streaming, speech_generation, transcription | 128000 | 16384 | In: $0.15, Out: $0.60 |
| gpt-4o-mini-transcribe | openai | In: text, audio; Out: text | streaming | 16000 | 2000 | In: $1.25, Out: $5.00 |
| gpt-4o-mini-transcribe-2025-03-20 | openai | In: text, audio; Out: text | streaming | 16000 | 2000 | In: $1.25, Out: $5.00 |
| gpt-4o-mini-transcribe-2025-12-15 | openai | In: text, audio; Out: text | streaming | 16000 | 2000 | In: $1.25, Out: $5.00 |
| gpt-4o-mini-tts | openai | In: text, audio; Out: text, audio | streaming | - | - | In: $0.60, Out: $12.00 |
| gpt-4o-mini-tts-2025-03-20 | openai | In: text, audio; Out: text, audio | streaming | - | - | In: $0.60, Out: $12.00 |
| gpt-4o-mini-tts-2025-12-15 | openai | In: text, audio; Out: text, audio | streaming | - | - | In: $0.60, Out: $12.00 |
| gpt-4o-transcribe | openai | In: text, audio; Out: text | streaming | 128000 | 16384 | In: $2.50, Out: $10.00 |
| gpt-4o-transcribe-diarize | openai | In: text, audio; Out: text | streaming | 128000 | 16384 | In: $2.50, Out: $10.00 |
| gpt-audio | openai | In: text, audio; Out: text, audio | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| gpt-audio-1.5 | openai | In: text, audio; Out: text, audio | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| gpt-audio-2025-08-28 | openai | In: text, audio; Out: text, audio | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| gpt-audio-mini | openai | In: text, audio; Out: text, audio | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| gpt-audio-mini-2025-10-06 | openai | In: text, audio; Out: text, audio | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| gpt-audio-mini-2025-12-15 | openai | In: text, audio; Out: text, audio | streaming | 4096 | 16384 | In: $0.50, Out: $1.50 |
| tts-1 | openai | In: text, audio; Out: text, audio | streaming | - | - | In: $15.00, Out: $15.00 |
| tts-1-1106 | openai | In: text, audio; Out: text, audio | streaming | - | - | In: $15.00, Out: $15.00 |
| tts-1-hd | openai | In: text, audio; Out: text, audio | streaming | - | - | In: $30.00, Out: $30.00 |
| tts-1-hd-1106 | openai | In: text, audio; Out: text, audio | streaming | - | - | In: $30.00, Out: $30.00 |
| whisper-1 | openai | In: text, audio; Out: text | streaming | - | - | In: $0.01, Out: $0.01 |
| openrouter/auto | openrouter | In: text, image, audio, file, video; Out: text, image | streaming, function_calling, structured_output, predicted_outputs | 2000000 | - | - |
| google/gemini-2.0-flash-001 | openrouter | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, vision, streaming | 1048576 | 8192 | In: $0.10, Out: $0.40, Cache: $0.02 |
| google/gemini-2.5-flash | openrouter | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1048576 | 65536 | In: $0.30, Out: $2.50, Cache: $0.04 |
| google/gemini-2.5-flash-lite | openrouter | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1048576 | 65536 | In: $0.10, Out: $0.40, Cache: $0.02 |
| google/gemini-2.5-flash-lite-preview-09-2025 | openrouter | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1048576 | 65536 | In: $0.10, Out: $0.40, Cache: $0.02 |
| google/gemini-2.5-flash-preview-09-2025 | openrouter | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1048576 | 65536 | In: $0.30, Out: $2.50, Cache: $0.03 |
| google/gemini-2.5-pro | openrouter | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1048576 | 65536 | In: $1.25, Out: $10.00, Cache: $0.31 |
| google/gemini-2.5-pro-preview-05-06 | openrouter | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1048576 | 65536 | In: $1.25, Out: $10.00, Cache: $0.31 |
| google/gemini-2.5-pro-preview-06-05 | openrouter | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1048576 | 65536 | In: $1.25, Out: $10.00, Cache: $0.31 |
| google/gemini-3-flash-preview | openrouter | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1048576 | 65536 | In: $0.50, Out: $3.00, Cache: $0.05 |
| google/gemini-3-pro-preview | openrouter | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1050000 | 66000 | In: $2.00, Out: $12.00 |
| google/gemini-3.1-pro-preview | openrouter | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1048576 | 65536 | In: $2.00, Out: $12.00 |
| google/gemini-2.0-flash-lite-001 | openrouter | In: text, image, file, audio, video; Out: text | streaming, function_calling, structured_output | 1048576 | 8192 | In: $0.08, Out: $0.30 |
| google/gemini-2.5-pro-preview | openrouter | In: file, image, text, audio; Out: text | streaming, function_calling, structured_output | 1048576 | 65536 | In: $1.25, Out: $10.00, Cache: $0.12 |
| mistralai/voxtral-small-24b-2507 | openrouter | In: text, audio; Out: text | streaming, function_calling, structured_output | 32000 | - | In: $0.10, Out: $0.30 |
| openai/gpt-audio | openrouter | In: text, audio; Out: text, audio | streaming, structured_output | 128000 | 16384 | In: $2.50, Out: $10.00 |
| openai/gpt-audio-mini | openrouter | In: text, audio; Out: text, audio | streaming, structured_output | 128000 | 16384 | In: $0.60, Out: $2.40 |
| openai/gpt-4o-audio-preview | openrouter | In: audio, text; Out: text, audio | streaming, function_calling, structured_output | 128000 | 16384 | In: $2.50, Out: $10.00 |
| gemini-1.5-flash | vertexai | In: text, image, audio, video; Out: text | function_calling, vision, streaming | 1000000 | 8192 | In: $0.08, Out: $0.30, Cache: $0.02 |
| gemini-1.5-flash-8b | vertexai | In: text, image, audio, video; Out: text | function_calling, vision, streaming | 1000000 | 8192 | In: $0.04, Out: $0.15, Cache: $0.01 |
| gemini-1.5-pro | vertexai | In: text, image, audio, video; Out: text | function_calling, vision, streaming | 1000000 | 8192 | In: $1.25, Out: $5.00, Cache: $0.31 |
| gemini-2.0-flash | vertexai | In: text, image, audio, video, pdf; Out: text | function_calling, vision, streaming | 1048576 | 8192 | In: $0.15, Out: $0.60, Cache: $0.02 |
| gemini-2.0-flash-lite | vertexai | In: text, image, audio, video, pdf; Out: text | function_calling, vision | 1048576 | 8192 | In: $0.08, Out: $0.30 |
| gemini-2.5-flash | vertexai | In: text, image, audio, video, pdf; Out: text | function_calling, reasoning, vision, streaming | 1048576 | 65536 | In: $0.30, Out: $2.50, Cache: $0.08 |
| gemini-2.5-flash-lite | vertexai | In: text, image, audio, video, pdf; Out: text | function_calling, reasoning, vision, streaming | 1048576 | 65536 | In: $0.10, Out: $0.40, Cache: $0.02 |
| gemini-2.5-flash-lite-preview-06-17 | vertexai | In: text, image, audio, video, pdf; Out: text | function_calling, reasoning, vision | 65536 | 65536 | In: $0.10, Out: $0.40, Cache: $0.02 |
| gemini-2.5-flash-lite-preview-09-2025 | vertexai | In: text, image, audio, video, pdf; Out: text | function_calling, reasoning, vision | 1048576 | 65536 | In: $0.10, Out: $0.40, Cache: $0.02 |
| gemini-2.5-flash-preview-04-17 | vertexai | In: text, image, audio, video, pdf; Out: text | function_calling, reasoning, vision, streaming | 1048576 | 65536 | In: $0.15, Out: $0.60, Cache: $0.04 |
| gemini-2.5-flash-preview-05-20 | vertexai | In: text, image, audio, video, pdf; Out: text | function_calling, reasoning, vision | 1048576 | 65536 | In: $0.15, Out: $0.60, Cache: $0.04 |
| gemini-2.5-flash-preview-09-2025 | vertexai | In: text, image, audio, video, pdf; Out: text | function_calling, reasoning, vision | 1048576 | 65536 | In: $0.30, Out: $2.50, Cache: $0.08 |
| gemini-2.5-pro | vertexai | In: text, image, audio, video, pdf; Out: text | function_calling, reasoning, vision, streaming | 1048576 | 65536 | In: $1.25, Out: $10.00, Cache: $0.31 |
| gemini-2.5-pro-preview-05-06 | vertexai | In: text, image, audio, video, pdf; Out: text | function_calling, reasoning, vision | 1048576 | 65536 | In: $1.25, Out: $10.00, Cache: $0.31 |
| gemini-2.5-pro-preview-06-05 | vertexai | In: text, image, audio, video, pdf; Out: text | function_calling, reasoning, vision | 1048576 | 65536 | In: $1.25, Out: $10.00, Cache: $0.31 |
| gemini-3-flash-preview | vertexai | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1048576 | 65536 | In: $0.50, Out: $3.00, Cache: $0.05 |
| gemini-3-pro-preview | vertexai | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1048576 | 65536 | In: $2.00, Out: $12.00, Cache: $0.20 |
| gemini-3.1-pro-preview | vertexai | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1048576 | 65536 | In: $2.00, Out: $12.00, Cache: $0.20 |
| gemini-3.1-pro-preview-customtools | vertexai | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1048576 | 65536 | In: $2.00, Out: $12.00, Cache: $0.20 |
| gemini-flash-latest | vertexai | In: text, image, audio, video, pdf; Out: text | function_calling, reasoning, vision | 1048576 | 65536 | In: $0.30, Out: $2.50, Cache: $0.08 |
| gemini-flash-lite-latest | vertexai | In: text, image, audio, video, pdf; Out: text | function_calling, reasoning, vision | 1048576 | 65536 | In: $0.10, Out: $0.40, Cache: $0.02 |


### PDF Models (198)

Models that can process PDF documents:

| Model | Provider | I/O | Capabilities | Context | Max Output | Standard Pricing (per 1M tokens) |
| :-- | :-- | :-- | :-- | --: | --: | :-- |
| claude-3-haiku-20240307 | anthropic | In: text, image, pdf; Out: text | function_calling, vision, streaming, batch | 200000 | 4096 | In: $0.25, Out: $1.25, Cache: $0.03 |
| claude-3-5-haiku-20241022 | anthropic | In: text, image, pdf; Out: text | function_calling, vision | 200000 | 8192 | In: $0.80, Out: $4.00, Cache: $0.08 |
| claude-3-5-haiku-latest | anthropic | In: text, image, pdf; Out: text | function_calling, vision | 200000 | 8192 | In: $0.80, Out: $4.00, Cache: $0.08 |
| claude-haiku-4-5-20251001 | anthropic | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 64000 | In: $1.00, Out: $5.00, Cache: $0.10 |
| claude-haiku-4-5 | anthropic | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 200000 | 64000 | In: $1.00, Out: $5.00, Cache: $0.10 |
| claude-3-opus-20240229 | anthropic | In: text, image, pdf; Out: text | function_calling, vision | 200000 | 4096 | In: $15.00, Out: $75.00, Cache: $1.50 |
| claude-opus-4-20250514 | anthropic | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 32000 | In: $15.00, Out: $75.00, Cache: $1.50 |
| claude-opus-4-0 | anthropic | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 200000 | 32000 | In: $15.00, Out: $75.00, Cache: $1.50 |
| claude-opus-4-1-20250805 | anthropic | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 32000 | In: $15.00, Out: $75.00, Cache: $1.50 |
| claude-opus-4-1 | anthropic | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 200000 | 32000 | In: $15.00, Out: $75.00, Cache: $1.50 |
| claude-opus-4-5-20251101 | anthropic | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 64000 | In: $5.00, Out: $25.00, Cache: $0.50 |
| claude-opus-4-5 | anthropic | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 200000 | 64000 | In: $5.00, Out: $25.00, Cache: $0.50 |
| claude-opus-4-6 | anthropic | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 128000 | In: $5.00, Out: $25.00, Cache: $0.50 |
| claude-3-sonnet-20240229 | anthropic | In: text, image, pdf; Out: text | function_calling, vision | 200000 | 4096 | In: $3.00, Out: $15.00, Cache: $0.30 |
| claude-3-5-sonnet-20240620 | anthropic | In: text, image, pdf; Out: text | function_calling, vision | 200000 | 8192 | In: $3.00, Out: $15.00, Cache: $0.30 |
| claude-3-5-sonnet-20241022 | anthropic | In: text, image, pdf; Out: text | function_calling, vision | 200000 | 8192 | In: $3.00, Out: $15.00, Cache: $0.30 |
| claude-3-7-sonnet-20250219 | anthropic | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 200000 | 64000 | In: $3.00, Out: $15.00, Cache: $0.30 |
| claude-3-7-sonnet-latest | anthropic | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 200000 | 64000 | In: $3.00, Out: $15.00, Cache: $0.30 |
| claude-sonnet-4-20250514 | anthropic | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 64000 | In: $3.00, Out: $15.00, Cache: $0.30 |
| claude-sonnet-4-0 | anthropic | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 200000 | 64000 | In: $3.00, Out: $15.00, Cache: $0.30 |
| claude-sonnet-4-5-20250929 | anthropic | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 64000 | In: $3.00, Out: $15.00, Cache: $0.30 |
| claude-sonnet-4-5 | anthropic | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 200000 | 64000 | In: $3.00, Out: $15.00, Cache: $0.30 |
| claude-sonnet-4-6 | anthropic | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 64000 | In: $3.00, Out: $15.00, Cache: $0.30 |
| gpt-4 | azure | In: text, image, pdf; Out: text | streaming, function_calling | 8192 | 8192 | In: $10.00, Out: $30.00 |
| gpt-4-turbo-2024-04-09 | azure | In: text, image, pdf; Out: text | streaming, function_calling | 128000 | 4096 | In: $10.00, Out: $30.00 |
| gpt-4-turbo-jp | azure | In: text, image, pdf; Out: text | streaming, function_calling | 128000 | 4096 | In: $10.00, Out: $30.00 |
| gpt-4.1 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output | 1047576 | 32768 | In: $2.00, Out: $8.00, Cache: $0.50 |
| gpt-4.1-2025-04-14 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output | 1047576 | 32768 | In: $2.00, Out: $8.00, Cache: $0.50 |
| gpt-4.1-2025-04-14-text | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output | 1047576 | 32768 | In: $2.00, Out: $8.00, Cache: $0.50 |
| gpt-4.1-mini | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output | 1047576 | 32768 | In: $0.40, Out: $1.60, Cache: $0.10 |
| gpt-4.1-mini-2025-04-14 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output | 1047576 | 32768 | In: $0.40, Out: $1.60, Cache: $0.10 |
| gpt-4.1-nano | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output | 1047576 | 32768 | In: $0.10, Out: $0.40 |
| gpt-4.1-nano-2025-04-14 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output | 1047576 | 32768 | In: $0.10, Out: $0.40 |
| gpt-4o | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output | 128000 | 16384 | In: $2.50, Out: $10.00 |
| gpt-4o-2024-05-13 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output | 128000 | 16384 | In: $2.50, Out: $10.00 |
| gpt-4o-2024-08-06 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output | 128000 | 16384 | In: $2.50, Out: $10.00 |
| gpt-4o-2024-11-20 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output | 128000 | 16384 | In: $2.50, Out: $10.00 |
| gpt-4o-canvas-2024-09-25 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output | 128000 | 16384 | In: $2.50, Out: $10.00 |
| gpt-4o-mini | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output | 128000 | 16384 | In: $0.15, Out: $0.60 |
| gpt-4o-mini-2024-07-18 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output | 128000 | 16384 | In: $0.15, Out: $0.60 |
| gpt-5-chat-2025-08-07 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5-chat-2025-08-15 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5-chat-2025-10-03 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5-codex-2025-09-15 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5-mini-2025-08-07 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5-mini-lite-2025-08-07 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5-nano-2025-08-07 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5.1-chat-2025-11-13 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5.1-codex-mini-2025-11-13 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5.2-chat-2025-12-11 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5.2-chat-2026-02-10 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5.3-codex-2026-02-20 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| o1-2024-12-17 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 200000 | 100000 | In: $15.00, Out: $60.00 |
| o1-pro | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 200000 | 100000 | In: $150.00, Out: $600.00 |
| o1-pro-2025-03-19 | azure | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 200000 | 100000 | In: $150.00, Out: $600.00 |
| anthropic.claude-3-haiku-20240307-v1:0:200k | bedrock | In: text, image, pdf; Out: text | function_calling, vision, streaming | 200000 | 4096 | In: $0.25, Out: $1.25 |
| anthropic.claude-3-haiku-20240307-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, vision, streaming | 200000 | 4096 | In: $0.25, Out: $1.25 |
| anthropic.claude-3-haiku-20240307-v1:0:48k | bedrock | In: text, image, pdf; Out: text | function_calling, vision, streaming | 48000 | 4096 | In: $0.25, Out: $1.25 |
| anthropic.claude-3-5-haiku-20241022-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, vision, streaming | 200000 | 8192 | In: $0.80, Out: $4.00, Cache: $0.08 |
| anthropic.claude-haiku-4-5-20251001-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 200000 | 64000 | In: $1.00, Out: $5.00, Cache: $0.10 |
| eu.anthropic.claude-haiku-4-5-20251001-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 200000 | 64000 | In: $1.00, Out: $5.00, Cache: $0.10 |
| global.anthropic.claude-haiku-4-5-20251001-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 200000 | 64000 | In: $1.00, Out: $5.00, Cache: $0.10 |
| us.anthropic.claude-haiku-4-5-20251001-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 64000 | In: $1.00, Out: $5.00, Cache: $0.10 |
| anthropic.claude-3-opus-20240229-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, vision | 200000 | 4096 | In: $15.00, Out: $75.00 |
| anthropic.claude-opus-4-20250514-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 200000 | 32000 | In: $15.00, Out: $75.00, Cache: $1.50 |
| us.anthropic.claude-opus-4-20250514-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 32000 | In: $15.00, Out: $75.00, Cache: $1.50 |
| anthropic.claude-opus-4-1-20250805-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 200000 | 32000 | In: $15.00, Out: $75.00, Cache: $1.50 |
| us.anthropic.claude-opus-4-1-20250805-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 32000 | In: $15.00, Out: $75.00, Cache: $1.50 |
| anthropic.claude-opus-4-5-20251101-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 200000 | 64000 | In: $5.00, Out: $25.00, Cache: $0.50 |
| eu.anthropic.claude-opus-4-5-20251101-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 200000 | 64000 | In: $5.00, Out: $25.00, Cache: $0.50 |
| global.anthropic.claude-opus-4-5-20251101-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 200000 | 64000 | In: $5.00, Out: $25.00, Cache: $0.50 |
| us.anthropic.claude-opus-4-5-20251101-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 64000 | In: $5.00, Out: $25.00, Cache: $0.50 |
| anthropic.claude-opus-4-6-v1 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache: $0.50 |
| eu.anthropic.claude-opus-4-6-v1 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache: $0.50 |
| global.anthropic.claude-opus-4-6-v1 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache: $0.50 |
| us.anthropic.claude-opus-4-6-v1 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache: $0.50 |
| anthropic.claude-3-sonnet-20240229-v1:0:28k | bedrock | In: text, image, pdf; Out: text | function_calling, vision, streaming | 28000 | 4096 | In: $3.00, Out: $15.00 |
| anthropic.claude-3-sonnet-20240229-v1:0:200k | bedrock | In: text, image, pdf; Out: text | function_calling, vision, streaming | 200000 | 4096 | In: $3.00, Out: $15.00 |
| anthropic.claude-3-sonnet-20240229-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, vision, streaming | 200000 | 4096 | In: $3.00, Out: $15.00 |
| anthropic.claude-3-5-sonnet-20240620-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, vision, streaming | 200000 | 8192 | In: $3.00, Out: $15.00, Cache: $0.30 |
| anthropic.claude-3-5-sonnet-20240620-v1:0:18k | bedrock | In: text, image, pdf; Out: text | function_calling, vision, streaming | 18000 | 8192 | In: $3.00, Out: $15.00, Cache: $0.30 |
| anthropic.claude-3-5-sonnet-20240620-v1:0:200k | bedrock | In: text, image, pdf; Out: text | function_calling, vision, streaming | 200000 | 8192 | In: $3.00, Out: $15.00, Cache: $0.30 |
| anthropic.claude-3-5-sonnet-20240620-v1:0:51k | bedrock | In: text, image, pdf; Out: text | function_calling, vision, streaming | 51000 | 8192 | In: $3.00, Out: $15.00, Cache: $0.30 |
| anthropic.claude-3-5-sonnet-20241022-v2:0 | bedrock | In: text, image, pdf; Out: text | function_calling, vision, streaming | 200000 | 8192 | In: $3.00, Out: $15.00, Cache: $0.30 |
| anthropic.claude-3-5-sonnet-20241022-v2:0:18k | bedrock | In: text, image, pdf; Out: text | function_calling, vision, streaming | 18000 | 8192 | In: $3.00, Out: $15.00, Cache: $0.30 |
| anthropic.claude-3-5-sonnet-20241022-v2:0:200k | bedrock | In: text, image, pdf; Out: text | function_calling, vision, streaming | 200000 | 8192 | In: $3.00, Out: $15.00, Cache: $0.30 |
| anthropic.claude-3-5-sonnet-20241022-v2:0:51k | bedrock | In: text, image, pdf; Out: text | function_calling, vision, streaming | 51000 | 8192 | In: $3.00, Out: $15.00, Cache: $0.30 |
| us.anthropic.claude-3-7-sonnet-20250219-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, vision, streaming | 200000 | 8192 | In: $3.00, Out: $15.00, Cache: $0.30 |
| anthropic.claude-3-7-sonnet-20250219-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, vision | 200000 | 8192 | In: $3.00, Out: $15.00, Cache: $0.30 |
| anthropic.claude-sonnet-4-20250514-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 200000 | 64000 | In: $3.00, Out: $15.00, Cache: $0.30 |
| eu.anthropic.claude-sonnet-4-20250514-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 200000 | 64000 | In: $3.00, Out: $15.00, Cache: $0.30 |
| global.anthropic.claude-sonnet-4-20250514-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 200000 | 64000 | In: $3.00, Out: $15.00, Cache: $0.30 |
| us.anthropic.claude-sonnet-4-20250514-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 64000 | In: $3.00, Out: $15.00, Cache: $0.30 |
| anthropic.claude-sonnet-4-5-20250929-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 200000 | 64000 | In: $3.00, Out: $15.00, Cache: $0.30 |
| eu.anthropic.claude-sonnet-4-5-20250929-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 200000 | 64000 | In: $3.00, Out: $15.00, Cache: $0.30 |
| global.anthropic.claude-sonnet-4-5-20250929-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 200000 | 64000 | In: $3.00, Out: $15.00, Cache: $0.30 |
| us.anthropic.claude-sonnet-4-5-20250929-v1:0 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 64000 | In: $3.00, Out: $15.00, Cache: $0.30 |
| anthropic.claude-sonnet-4-6 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 200000 | 64000 | In: $3.00, Out: $15.00, Cache: $0.30 |
| eu.anthropic.claude-sonnet-4-6 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 200000 | 64000 | In: $3.00, Out: $15.00, Cache: $0.30 |
| global.anthropic.claude-sonnet-4-6 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision | 200000 | 64000 | In: $3.00, Out: $15.00, Cache: $0.30 |
| us.anthropic.claude-sonnet-4-6 | bedrock | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 64000 | In: $3.00, Out: $15.00, Cache: $0.30 |
| deep-research-pro-preview-12-2025 | gemini | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, caching | 131072 | 65536 | In: $0.08, Out: $0.30 |
| gemini-2.0-flash | gemini | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, vision, streaming, batch, caching | 1048576 | 8192 | In: $0.10, Out: $0.40, Cache: $0.02 |
| gemini-2.0-flash-001 | gemini | In: text, image, pdf, video; Out: text | streaming, function_calling, structured_output, batch, caching | 1048576 | 8192 | In: $0.10, Out: $0.40 |
| gemini-2.0-flash-lite | gemini | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, vision, streaming, batch | 1048576 | 8192 | In: $0.08, Out: $0.30 |
| gemini-2.0-flash-lite-001 | gemini | In: text, image, pdf, video; Out: text | streaming, batch | 1048576 | 8192 | In: $0.08, Out: $0.30 |
| gemini-2.5-computer-use-preview-10-2025 | gemini | In: text, image, pdf, video; Out: text | streaming, function_calling, structured_output, caching | 131072 | 65536 | In: $0.08, Out: $0.30 |
| gemini-2.5-flash | gemini | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming, batch, caching | 1048576 | 65536 | In: $0.30, Out: $2.50, Cache: $0.08 |
| gemini-2.5-flash-lite | gemini | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming, batch | 1048576 | 65536 | In: $0.10, Out: $0.40, Cache: $0.02 |
| gemini-2.5-flash-lite-preview-06-17 | gemini | In: text, image, audio, video, pdf; Out: text | function_calling, reasoning, vision | 1048576 | 65536 | In: $0.10, Out: $0.40, Cache: $0.02 |
| gemini-2.5-flash-lite-preview-09-2025 | gemini | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming, batch | 1048576 | 65536 | In: $0.10, Out: $0.40, Cache: $0.02 |
| gemini-2.5-flash-native-audio-latest | gemini | In: text, image, pdf, video, audio; Out: text | streaming, function_calling, structured_output, batch, caching | 131072 | 8192 | In: $0.08, Out: $0.30 |
| gemini-2.5-flash-native-audio-preview-09-2025 | gemini | In: text, image, pdf, video, audio; Out: text | streaming, function_calling, structured_output, batch, caching | 131072 | 8192 | In: $0.08, Out: $0.30 |
| gemini-2.5-flash-native-audio-preview-12-2025 | gemini | In: text, image, pdf, video, audio; Out: text | streaming, function_calling, structured_output, batch, caching | 131072 | 8192 | In: $0.08, Out: $0.30 |
| gemini-2.5-flash-preview-04-17 | gemini | In: text, image, audio, video, pdf; Out: text | function_calling, reasoning, vision | 1048576 | 65536 | In: $0.15, Out: $0.60, Cache: $0.04 |
| gemini-2.5-flash-preview-05-20 | gemini | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1048576 | 65536 | In: $0.15, Out: $0.60, Cache: $0.04 |
| gemini-2.5-flash-preview-09-2025 | gemini | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1048576 | 65536 | In: $0.30, Out: $2.50, Cache: $0.08 |
| gemini-2.5-pro | gemini | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming, caching | 1048576 | 65536 | In: $1.25, Out: $10.00, Cache: $0.31 |
| gemini-2.5-pro-preview-05-06 | gemini | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1048576 | 65536 | In: $1.25, Out: $10.00, Cache: $0.31 |
| gemini-2.5-pro-preview-06-05 | gemini | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1048576 | 65536 | In: $1.25, Out: $10.00, Cache: $0.31 |
| gemini-3-flash-preview | gemini | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming, batch, caching | 1048576 | 65536 | In: $0.50, Out: $3.00, Cache: $0.05 |
| gemini-3-pro-preview | gemini | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming, caching | 1000000 | 64000 | In: $2.00, Out: $12.00, Cache: $0.20 |
| gemini-3.1-pro-preview | gemini | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming, caching | 1048576 | 65536 | In: $2.00, Out: $12.00, Cache: $0.20 |
| gemini-3.1-pro-preview-customtools | gemini | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming, caching | 1048576 | 65536 | In: $2.00, Out: $12.00, Cache: $0.20 |
| gemini-flash-latest | gemini | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming, batch, caching | 1048576 | 65536 | In: $0.30, Out: $2.50, Cache: $0.08 |
| gemini-flash-lite-latest | gemini | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming, batch | 1048576 | 65536 | In: $0.10, Out: $0.40, Cache: $0.02 |
| gemini-pro-latest | gemini | In: text, image, pdf, video; Out: text | streaming, function_calling, structured_output, caching | 1048576 | 65536 | In: $0.08, Out: $0.30 |
| gemini-robotics-er-1.5-preview | gemini | In: text, image, pdf, video; Out: text | streaming, function_calling, structured_output, caching | 1048576 | 65536 | In: $0.08, Out: $0.30 |
| imagen-4.0-generate-001 | gemini | In: text, image, pdf; Out: image | streaming | 480 | 8192 | - |
| imagen-4.0-fast-generate-001 | gemini | In: text, image, pdf; Out: image | streaming | 480 | 8192 | - |
| imagen-4.0-ultra-generate-001 | gemini | In: text, image, pdf; Out: image | streaming | 480 | 8192 | - |
| gemini-3-pro-image-preview | gemini | In: text, image, pdf, video; Out: text | streaming, function_calling, structured_output, caching | 131072 | 32768 | In: $0.08, Out: $0.30 |
| nano-banana-pro-preview | gemini | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, caching | 131072 | 32768 | In: $0.08, Out: $0.30 |
| gpt-4-turbo-2024-04-09 | openai | In: text, image, pdf; Out: text | streaming, function_calling | 128000 | 4096 | In: $10.00, Out: $30.00 |
| gpt-4-turbo-preview | openai | In: text, image, pdf; Out: text | streaming, function_calling | 128000 | 4096 | In: $10.00, Out: $30.00 |
| gpt-4.1-2025-04-14 | openai | In: text, image, pdf; Out: text | streaming, function_calling, structured_output | 1047576 | 32768 | In: $2.00, Out: $8.00, Cache: $0.50 |
| gpt-4.1-mini-2025-04-14 | openai | In: text, image, pdf; Out: text | streaming, function_calling, structured_output | 1047576 | 32768 | In: $0.40, Out: $1.60, Cache: $0.10 |
| gpt-4.1-nano-2025-04-14 | openai | In: text, image, pdf; Out: text | streaming, function_calling, structured_output | 1047576 | 32768 | In: $0.10, Out: $0.40 |
| gpt-4o-search-preview | openai | In: text, image, pdf; Out: text | streaming | 128000 | 16384 | In: $2.50, Out: $10.00 |
| gpt-4o-search-preview-2025-03-11 | openai | In: text, image, pdf; Out: text | streaming | 128000 | 16384 | In: $2.50, Out: $10.00 |
| gpt-4o-mini-2024-07-18 | openai | In: text, image, pdf; Out: text | streaming, function_calling, structured_output | 128000 | 16384 | In: $0.15, Out: $0.60 |
| gpt-5-2025-08-07 | openai | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5-mini-2025-08-07 | openai | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5-nano-2025-08-07 | openai | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5-pro-2025-10-06 | openai | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5-search-api | openai | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5-search-api-2025-10-14 | openai | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5.1-2025-11-13 | openai | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5.2-2025-12-11 | openai | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5.2-codex | openai | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $1.75, Out: $14.00, Cache: $0.18 |
| gpt-5.2-pro-2025-12-11 | openai | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 128000 | 400000 | In: $1.25, Out: $10.00, Cache: $0.12 |
| gpt-5.3-codex | openai | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $1.75, Out: $14.00, Cache: $0.18 |
| gpt-5.3-codex-spark | openai | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision | 128000 | 32000 | In: $1.75, Out: $14.00, Cache: $0.18 |
| o1-2024-12-17 | openai | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 200000 | 100000 | In: $15.00, Out: $60.00 |
| o1-pro-2025-03-19 | openai | In: text, image, pdf; Out: text | streaming, function_calling, structured_output, reasoning | 200000 | 100000 | In: $150.00, Out: $600.00 |
| omni-moderation-2024-09-26 | openai | In: text, image, pdf; Out: text, moderation | - | - | - | - |
| omni-moderation-latest | openai | In: text, image, pdf; Out: text, moderation | - | - | - | - |
| anthropic/claude-3.5-haiku | openrouter | In: text, image, pdf; Out: text | function_calling, vision, streaming | 200000 | 8192 | In: $0.80, Out: $4.00, Cache: $0.08 |
| anthropic/claude-haiku-4.5 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 64000 | In: $1.00, Out: $5.00, Cache: $0.10 |
| anthropic/claude-opus-4 | openrouter | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 32000 | In: $15.00, Out: $75.00, Cache: $1.50 |
| anthropic/claude-opus-4.1 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 32000 | In: $15.00, Out: $75.00, Cache: $1.50 |
| anthropic/claude-opus-4.5 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 200000 | 32000 | In: $5.00, Out: $25.00, Cache: $0.50 |
| anthropic/claude-opus-4.6 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 128000 | In: $5.00, Out: $25.00, Cache: $0.50 |
| anthropic/claude-3.7-sonnet | openrouter | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 128000 | In: $15.00, Out: $75.00, Cache: $1.50 |
| anthropic/claude-sonnet-4 | openrouter | In: text, image, pdf; Out: text | function_calling, reasoning, vision, streaming | 200000 | 64000 | In: $3.00, Out: $15.00, Cache: $0.30 |
| anthropic/claude-sonnet-4.5 | openrouter | In: text, image, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1000000 | 64000 | In: $3.00, Out: $15.00, Cache: $0.30 |
| openai/gpt-5-image | openrouter | In: text, image, pdf; Out: text, image | function_calling, structured_output, reasoning, vision, streaming | 400000 | 128000 | In: $5.00, Out: $10.00, Cache: $1.25 |
| google/gemini-2.0-flash-001 | openrouter | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, vision, streaming | 1048576 | 8192 | In: $0.10, Out: $0.40, Cache: $0.02 |
| google/gemini-2.5-flash | openrouter | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1048576 | 65536 | In: $0.30, Out: $2.50, Cache: $0.04 |
| google/gemini-2.5-flash-lite | openrouter | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1048576 | 65536 | In: $0.10, Out: $0.40, Cache: $0.02 |
| google/gemini-2.5-flash-lite-preview-09-2025 | openrouter | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1048576 | 65536 | In: $0.10, Out: $0.40, Cache: $0.02 |
| google/gemini-2.5-flash-preview-09-2025 | openrouter | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1048576 | 65536 | In: $0.30, Out: $2.50, Cache: $0.03 |
| google/gemini-2.5-pro | openrouter | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1048576 | 65536 | In: $1.25, Out: $10.00, Cache: $0.31 |
| google/gemini-2.5-pro-preview-05-06 | openrouter | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1048576 | 65536 | In: $1.25, Out: $10.00, Cache: $0.31 |
| google/gemini-2.5-pro-preview-06-05 | openrouter | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1048576 | 65536 | In: $1.25, Out: $10.00, Cache: $0.31 |
| google/gemini-3-flash-preview | openrouter | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1048576 | 65536 | In: $0.50, Out: $3.00, Cache: $0.05 |
| google/gemini-3-pro-preview | openrouter | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1050000 | 66000 | In: $2.00, Out: $12.00 |
| google/gemini-3.1-pro-preview | openrouter | In: text, image, audio, video, pdf; Out: text | function_calling, structured_output, reasoning, vision, streaming | 1048576 | 65536 | In: $2.00, Out: $12.00 |
| deepseek-ai/deepseek-v3.1-maas | vertexai | In: text, pdf; Out: text | function_calling, structured_output, reasoning, vision | 163840 | 32768 | In: $0.60, Out: $1.70 |
| zai-org/glm-4.7-maas | vertexai | In: text, pdf; Out: text | function_calling, structured_output, reasoning, vision | 200000 | 128000 | In: $0.60, Out: $2.20 |
| gemini-2.0-flash | vertexai | In: text, image, audio, video, pdf; Out: text | function_calling, vision, streaming | 1048576 | 8192 | In: $0.15, Out: $0.60, Cache: $0.02 |
| gemini-2.0-flash-lite | vertexai | In: text, image, audio, video, pdf; Out: text | function_calling, vision | 1048576 | 8192 | In: $0.08, Out: $0.30 |
| gemini-2.5-flash | vertexai | In: text, image, audio, video, pdf; Out: text | function_calling, reasoning, vision, streaming | 1048576 | 65536 | In: $0.30, Out: $2.50, Cache: $0.08 |
| gemini-2.5-flash-lite | vertexai | In: text, image, audio, video, pdf; Out: text | function_calling, reasoning, vision, streaming | 1048576 | 65536 | In: $0.10, Out: $0.40, Cache: $0.02 |
| gemini-2.5-flash-lite-preview-06-17 | vertexai | In: text, image, audio, video, pdf; Out: text | function_calling, reasoning, vision | 65536 | 65536 | In: $0.10, Out: $0.40, Cache: $0.02 |
| gemini-2.5-flash-lite-preview-09-2025 | vertexai | In: text, image, audio, video, pdf; Out: text | function_calling, reasoning, vision | 1048576 | 65536 | In: $0.10, Out: $0.40, Cache: $0.02 |
| gemini-2.5-flash-preview-04-17 | vertexai | In: text, image, audio, video, pdf; Out: text | function_calling, reasoning, vision, streaming | 1048576 | 65536 | In: $0.15, Out: $0.60, Cache: $0.04 |
| gemini-2.5-flash-preview-05-20 | vertexai | In: text, image, audio, video, pdf; Out: text | function_calling, reasoning, vision | 1048576 | 65536 | In: $0.15, Out: $0.60, Cache: $0.04 |
| gemini-2.5-flash-preview-09-2025 | vertexai | In: text, image, audio, video, pdf; Out: text | function_calling, reasoning, vision | 1048576 | 65536 | In: $0.30, Out: $2.50, Cache: $0.08 |
| gemini-2.5-pro | vertexai | In: text, image, audio, video, pdf; Out: text | function_calling, reasoning, vision, streaming | 1048576 | 65536 | In: $1.25, Out: $10.00, Cache: $0.31 |
| gemini-2.5-pro-preview-05-06 | vertexai | In: text, image, audio, video, pdf; Out: text | function_calling, reasoning, vision | 1048576 | 65536 | In: $1.25, Out: $10.00, Cache: $0.31 |
| gemini-2.5-pro-preview-06-05 | vertexai | In: text, image, audio, video, pdf; Out: text | function_calling, reasoning, vision | 1048576 | 65536 | In: $1.25, Out: $10.00, Cache: $0.31 |
| gemini-3-flash-preview | vertexai | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1048576 | 65536 | In: $0.50, Out: $3.00, Cache: $0.05 |
| gemini-3-pro-preview | vertexai | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1048576 | 65536 | In: $2.00, Out: $12.00, Cache: $0.20 |
| gemini-3.1-pro-preview | vertexai | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1048576 | 65536 | In: $2.00, Out: $12.00, Cache: $0.20 |
| gemini-3.1-pro-preview-customtools | vertexai | In: text, image, video, audio, pdf; Out: text | function_calling, structured_output, reasoning, vision | 1048576 | 65536 | In: $2.00, Out: $12.00, Cache: $0.20 |
| gemini-flash-latest | vertexai | In: text, image, audio, video, pdf; Out: text | function_calling, reasoning, vision | 1048576 | 65536 | In: $0.30, Out: $2.50, Cache: $0.08 |
| gemini-flash-lite-latest | vertexai | In: text, image, audio, video, pdf; Out: text | function_calling, reasoning, vision | 1048576 | 65536 | In: $0.10, Out: $0.40, Cache: $0.02 |


### Embedding Models (37)

Models that generate embeddings:

| Model | Provider | I/O | Capabilities | Context | Max Output | Standard Pricing (per 1M tokens) |
| :-- | :-- | :-- | :-- | --: | --: | :-- |
| text-embedding-3-large | azure | In: text; Out: text, embeddings | batch | - | - | In: $0.13, Out: $0.13 |
| text-embedding-3-small | azure | In: text; Out: text, embeddings | batch | - | - | In: $0.02, Out: $0.02 |
| text-embedding-ada-002 | azure | In: text; Out: text, embeddings | batch | - | - | In: $0.10, Out: $0.10 |
| text-embedding-ada-002-2 | azure | In: text; Out: text, embeddings | batch | - | - | In: $0.10, Out: $0.10 |
| cohere.embed-english-v3 | bedrock | In: text; Out: embeddings | function_calling | - | - | - |
| cohere.embed-english-v3:0:512 | bedrock | In: text; Out: embeddings | function_calling | - | - | - |
| cohere.embed-multilingual-v3:0:512 | bedrock | In: text; Out: embeddings | function_calling | - | - | - |
| cohere.embed-multilingual-v3 | bedrock | In: text; Out: embeddings | function_calling | - | - | - |
| us.cohere.embed-v4:0 | bedrock | In: text, image; Out: embeddings | function_calling | 128000 | - | - |
| amazon.titan-embed-text-v1:2:8k | bedrock | In: text; Out: embeddings | function_calling | - | - | - |
| amazon.titan-embed-text-v1 | bedrock | In: text; Out: embeddings | function_calling | - | - | - |
| amazon.titan-embed-image-v1 | bedrock | In: text, image; Out: embeddings | function_calling | - | - | - |
| amazon.titan-embed-image-v1:0 | bedrock | In: text, image; Out: embeddings | function_calling | - | - | - |
| amazon.titan-embed-text-v2:0 | bedrock | In: text; Out: embeddings | function_calling | - | - | - |
| amazon.titan-embed-g1-text-02 | bedrock | In: text; Out: embeddings | function_calling | - | - | - |
| gemini-embedding-001 | gemini | In: text; Out: embeddings | streaming, batch | 2048 | 3072 | In: $0.15 |
| codestral-embed | mistral | In: text; Out: embeddings | predicted_outputs | 32768 | 8192 | - |
| codestral-embed-2505 | mistral | In: text; Out: embeddings | predicted_outputs | 32768 | 8192 | - |
| mistral-embed-2312 | mistral | In: text; Out: embeddings | - | 32768 | 8192 | - |
| text-embedding-3-large | openai | In: text; Out: embeddings | batch | 8191 | 3072 | In: $0.13 |
| text-embedding-3-small | openai | In: text; Out: embeddings | batch | 8191 | 1536 | In: $0.02 |
| text-embedding-ada-002 | openai | In: text; Out: embeddings | batch | 8192 | 1536 | In: $0.10 |
| gemini-embedding-001 | vertexai | In: text; Out: embeddings | streaming, function_calling | 2048 | 3072 | In: $0.15 |
| voyage-3-large | voyage | In: text; Out: embeddings | - | 32000 | - | In: $0.18 |
| voyage-3.5 | voyage | In: text; Out: embeddings | - | 32000 | - | In: $0.06 |
| voyage-3.5-lite | voyage | In: text; Out: embeddings | - | 32000 | - | In: $0.02 |
| voyage-4 | voyage | In: text; Out: embeddings | - | 32000 | - | In: $0.06 |
| voyage-4-large | voyage | In: text; Out: embeddings | - | 32000 | - | In: $0.12 |
| voyage-4-lite | voyage | In: text; Out: embeddings | - | 32000 | - | In: $0.02 |
| voyage-4-nano | voyage | In: text; Out: embeddings | - | 32000 | - | - |
| voyage-code-2 | voyage | In: text; Out: embeddings | - | 16000 | - | In: $0.12 |
| voyage-code-3 | voyage | In: text; Out: embeddings | - | 32000 | - | In: $0.18 |
| voyage-context-3 | voyage | In: text; Out: embeddings | - | 32000 | - | In: $0.18 |
| voyage-finance-2 | voyage | In: text; Out: embeddings | - | 32000 | - | In: $0.12 |
| voyage-law-2 | voyage | In: text; Out: embeddings | - | 16000 | - | In: $0.12 |
| voyage-multimodal-3 | voyage | In: text, image; Out: embeddings | - | 32000 | - | In: $0.12 |
| voyage-multimodal-3.5 | voyage | In: text, image, video; Out: embeddings | - | 32000 | - | In: $0.12 |

