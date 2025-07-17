---
layout: default
title: Available Models
parent: Guides
nav_order: 11
permalink: /guides/available-models
---

# Available Models
{: .no_toc }

This guide lists all models available in RubyLLM, automatically generated from the current [model registry](https://github.com/crmne/ruby_llm/blob/main/lib/ruby_llm/models.json).
{: .fs-6 .fw-300 }

## Table of contents
{: .no_toc .text-delta }

1. TOC
{:toc}

---

## How Model Data Works

RubyLLM's model registry combines data from multiple sources:

- **OpenAI, Anthropic, DeepSeek, Gemini**: Data from [Parsera](https://api.parsera.org/v1/llm-specs)
- **OpenRouter**: Direct from OpenRouter's API
- **Other providers**: Defined in `capabilities.rb` files

## Contributing Model Updates

**For major providers** (OpenAI, Anthropic, DeepSeek, Gemini): File issues with [Parsera](https://github.com/parsera-labs/api-llm-specs/issues) for public model data corrections.

**For other providers**: Edit `lib/ruby_llm/providers/<provider>/capabilities.rb` then run `rake models:update`.

See the [Contributing Guide](https://github.com/crmne/ruby_llm/blob/main/CONTRIBUTING.md) for details.

## Last Updated
{: .d-inline-block }

2025-07-17
{: .label .label-green }

## Models by Provider

### Openai (84)

| Model | ID | Provider | Context | Max Output | Standard Pricing (per 1M tokens) |
| :-- | :-- | :-- | --: | --: | :-- |
| ChatGPT-4o | chatgpt-4o-latest | openai | 128000 | 16384 | In: $5.00, Out: $15.00 |
| DALL·E 2 | dall-e-2 | openai | - | - | - |
| DALL·E 3 | dall-e-3 | openai | - | - | - |
| GPT Image 1 | gpt-image-1 | openai | - | - | In: $5.00, Out: $40.00, Cache: $1.25 |
| GPT-3.5 Turbo | gpt-3.5-turbo | openai | 16385 | 4096 | In: $0.50, Out: $1.50 |
| GPT-3.5 Turbo 0125 | gpt-3.5-turbo-0125 | openai | 16385 | 4096 | In: $0.50, Out: $1.50 |
| GPT-3.5 Turbo 1106 | gpt-3.5-turbo-1106 | openai | 16385 | 4096 | In: $0.50, Out: $1.50 |
| GPT-3.5 Turbo 16k | gpt-3.5-turbo-16k | openai | 16385 | 4096 | In: $0.50, Out: $1.50 |
| GPT-3.5 Turbo Instruct | gpt-3.5-turbo-instruct | openai | 16385 | 4096 | In: $0.50, Out: $1.50 |
| GPT-3.5 Turbo Instruct 0914 | gpt-3.5-turbo-instruct-0914 | openai | 16385 | 4096 | In: $0.50, Out: $1.50 |
| GPT-4 | gpt-4 | openai | 8192 | 8192 | In: $30.00, Out: $60.00 |
| GPT-4 | gpt-4-0613 | openai | 8192 | 8192 | In: $30.00, Out: $60.00 |
| GPT-4 0125 Preview | gpt-4-0125-preview | openai | 4096 | 16384 | In: $0.50, Out: $1.50 |
| GPT-4 1106 Preview | gpt-4-1106-preview | openai | 4096 | 16384 | In: $0.50, Out: $1.50 |
| GPT-4 Turbo | gpt-4-turbo | openai | 128000 | 4096 | In: $10.00, Out: $30.00 |
| GPT-4 Turbo | gpt-4-turbo-2024-04-09 | openai | 128000 | 4096 | In: $10.00, Out: $30.00 |
| GPT-4 Turbo Preview | gpt-4-turbo-preview | openai | 128000 | 4096 | In: $10.00, Out: $30.00 |
| GPT-4.1 | gpt-4.1 | openai | 1047576 | 32768 | In: $2.00, Out: $8.00, Cache: $0.50 |
| GPT-4.1 | gpt-4.1-2025-04-14 | openai | 1047576 | 32768 | In: $2.00, Out: $8.00, Cache: $0.50 |
| GPT-4.1 mini | gpt-4.1-mini | openai | 1047576 | 32768 | In: $0.40, Out: $1.60, Cache: $0.10 |
| GPT-4.1 mini | gpt-4.1-mini-2025-04-14 | openai | 1047576 | 32768 | In: $0.40, Out: $1.60, Cache: $0.10 |
| GPT-4.1 nano | gpt-4.1-nano | openai | 1047576 | 32768 | In: $0.10, Out: $0.40, Cache: $0.02 |
| GPT-4.1 nano | gpt-4.1-nano-2025-04-14 | openai | 1047576 | 32768 | In: $0.10, Out: $0.40, Cache: $0.02 |
| GPT-4o | gpt-4o | openai | 128000 | 16384 | In: $2.50, Out: $10.00, Cache: $1.25 |
| GPT-4o | gpt-4o-2024-08-06 | openai | 128000 | 16384 | In: $2.50, Out: $10.00, Cache: $1.25 |
| GPT-4o 20240513 | gpt-4o-2024-05-13 | openai | 128000 | 16384 | In: $2.50, Out: $10.00 |
| GPT-4o 20241120 | gpt-4o-2024-11-20 | openai | 128000 | 16384 | In: $2.50, Out: $10.00 |
| GPT-4o Audio | gpt-4o-audio-preview | openai | 128000 | 16384 | In: $2.50, Out: $10.00 |
| GPT-4o Realtime | gpt-4o-realtime-preview | openai | 32000 | 4096 | In: $5.00, Out: $20.00, Cache: $2.50 |
| GPT-4o Search Preview | gpt-4o-search-preview | openai | 128000 | 16384 | In: $2.50, Out: $10.00 |
| GPT-4o Search Preview | gpt-4o-search-preview-2025-03-11 | openai | 128000 | 16384 | In: $2.50, Out: $10.00 |
| GPT-4o Transcribe | gpt-4o-transcribe | openai | 16000 | 2000 | In: $2.50, Out: $10.00 |
| GPT-4o mini | gpt-4o-mini | openai | 128000 | 16384 | In: $0.15, Out: $0.60, Cache: $0.08 |
| GPT-4o mini | gpt-4o-mini-2024-07-18 | openai | 128000 | 16384 | In: $0.15, Out: $0.60, Cache: $0.08 |
| GPT-4o mini Audio | gpt-4o-mini-audio-preview | openai | 128000 | 16384 | In: $0.15, Out: $0.60 |
| GPT-4o mini Audio | gpt-4o-mini-audio-preview-2024-12-17 | openai | 128000 | 16384 | In: $0.15, Out: $0.60 |
| GPT-4o mini Realtime | gpt-4o-mini-realtime-preview | openai | 128000 | 4096 | In: $0.60, Out: $2.40, Cache: $0.30 |
| GPT-4o mini Realtime | gpt-4o-mini-realtime-preview-2024-12-17 | openai | 128000 | 4096 | In: $0.60, Out: $2.40, Cache: $0.30 |
| GPT-4o mini Search Preview | gpt-4o-mini-search-preview | openai | 128000 | 16384 | In: $0.15, Out: $0.60 |
| GPT-4o mini Search Preview | gpt-4o-mini-search-preview-2025-03-11 | openai | 128000 | 16384 | In: $0.15, Out: $0.60 |
| GPT-4o mini TTS | gpt-4o-mini-tts | openai | 2000 | - | In: $0.60, Out: $12.00 |
| GPT-4o mini Transcribe | gpt-4o-mini-transcribe | openai | 16000 | 2000 | In: $1.25, Out: $5.00 |
| GPT-4o-Audio Preview 20241001 | gpt-4o-audio-preview-2024-10-01 | openai | 128000 | 16384 | In: $2.50, Out: $10.00 |
| GPT-4o-Audio Preview 20241217 | gpt-4o-audio-preview-2024-12-17 | openai | 128000 | 16384 | In: $2.50, Out: $10.00 |
| GPT-4o-Audio Preview 20250603 | gpt-4o-audio-preview-2025-06-03 | openai | 128000 | 16384 | In: $2.50, Out: $10.00 |
| GPT-4o-Realtime Preview 20241001 | gpt-4o-realtime-preview-2024-10-01 | openai | 128000 | 4096 | In: $5.00, Out: $20.00 |
| GPT-4o-Realtime Preview 20241217 | gpt-4o-realtime-preview-2024-12-17 | openai | 128000 | 4096 | In: $5.00, Out: $20.00 |
| GPT-4o-Realtime Preview 20250603 | gpt-4o-realtime-preview-2025-06-03 | openai | 128000 | 4096 | In: $5.00, Out: $20.00 |
| O1-Preview | o1-preview | openai | 200000 | 100000 | In: $15.00, Out: $60.00 |
| O1-Preview 20240912 | o1-preview-2024-09-12 | openai | 200000 | 100000 | In: $15.00, Out: $60.00 |
| Omni Moderation 20240926 | omni-moderation-2024-09-26 | openai | - | - | - |
| TTS-1 | tts-1 | openai | - | - | In: $15.00 |
| TTS-1 1106 | tts-1-1106 | openai | - | - | In: $15.00, Out: $15.00 |
| TTS-1 HD | tts-1-hd | openai | - | - | In: $30.00 |
| TTS-1 HD 1106 | tts-1-hd-1106 | openai | - | - | In: $30.00, Out: $30.00 |
| Whisper | whisper-1 | openai | - | - | In: $0.01 |
| babbage-002 | babbage-002 | openai | - | 16384 | In: $0.40, Out: $0.40 |
| codex-mini-latest | codex-mini-latest | openai | 200000 | 100000 | In: $1.50, Out: $6.00, Cache: $0.38 |
| computer-use-preview | computer-use-preview | openai | 8192 | 1024 | In: $3.00, Out: $12.00 |
| computer-use-preview | computer-use-preview-2025-03-11 | openai | 8192 | 1024 | In: $3.00, Out: $12.00 |
| davinci-002 | davinci-002 | openai | - | 16384 | In: $2.00, Out: $2.00 |
| o1 | o1 | openai | 200000 | 100000 | In: $15.00, Out: $60.00, Cache: $7.50 |
| o1 | o1-2024-12-17 | openai | 200000 | 100000 | In: $15.00, Out: $60.00, Cache: $7.50 |
| o1-mini | o1-mini | openai | 128000 | 65536 | In: $1.10, Out: $4.40, Cache: $0.55 |
| o1-mini | o1-mini-2024-09-12 | openai | 128000 | 65536 | In: $1.10, Out: $4.40, Cache: $0.55 |
| o1-pro | o1-pro | openai | 200000 | 100000 | In: $150.00, Out: $600.00 |
| o1-pro | o1-pro-2025-03-19 | openai | 200000 | 100000 | In: $150.00, Out: $600.00 |
| o3 | o3 | openai | 200000 | 100000 | In: $2.00, Out: $8.00, Cache: $0.50 |
| o3 | o3-2025-04-16 | openai | 200000 | 100000 | In: $2.00, Out: $8.00, Cache: $0.50 |
| o3-deep-research | o3-deep-research | openai | 200000 | 100000 | In: $10.00, Out: $40.00, Cache: $2.50 |
| o3-deep-research | o3-deep-research-2025-06-26 | openai | 200000 | 100000 | In: $10.00, Out: $40.00, Cache: $2.50 |
| o3-mini | o3-mini | openai | 200000 | 100000 | In: $1.10, Out: $4.40, Cache: $0.55 |
| o3-mini | o3-mini-2025-01-31 | openai | 200000 | 100000 | In: $1.10, Out: $4.40, Cache: $0.55 |
| o3-pro | o3-pro | openai | 200000 | 100000 | In: $20.00, Out: $80.00 |
| o3-pro | o3-pro-2025-06-10 | openai | 200000 | 100000 | In: $20.00, Out: $80.00 |
| o4-mini | o4-mini | openai | 200000 | 100000 | In: $1.10, Out: $4.40, Cache: $0.28 |
| o4-mini | o4-mini-2025-04-16 | openai | 200000 | 100000 | In: $1.10, Out: $4.40, Cache: $0.28 |
| o4-mini-deep-research | o4-mini-deep-research | openai | 200000 | 100000 | In: $2.00, Out: $8.00, Cache: $0.50 |
| o4-mini-deep-research | o4-mini-deep-research-2025-06-26 | openai | 200000 | 100000 | In: $2.00, Out: $8.00, Cache: $0.50 |
| omni-moderation | omni-moderation-latest | openai | - | - | - |
| text-embedding-3-large | text-embedding-3-large | openai | - | - | In: $0.13 |
| text-embedding-3-small | text-embedding-3-small | openai | - | - | In: $0.02 |
| text-embedding-ada-002 | text-embedding-ada-002 | openai | - | - | In: $0.10 |
| text-moderation | text-moderation-latest | openai | - | 32768 | - |


### Anthropic (11)

| Model | ID | Provider | Context | Max Output | Standard Pricing (per 1M tokens) |
| :-- | :-- | :-- | --: | --: | :-- |
| Claude 2.0 | claude-2.0 | anthropic | 200000 | 4096 | In: $3.00, Out: $15.00 |
| Claude 2.1 | claude-2.1 | anthropic | 200000 | 4096 | In: $3.00, Out: $15.00 |
| Claude Haiku 3 | claude-3-haiku-20240307 | anthropic | 200000 | 4096 | In: $0.25, Out: $1.25, Cache: $0.30 |
| Claude Haiku 3.5 | claude-3-5-haiku-20241022 | anthropic | 200000 | 8192 | In: $0.80, Out: $4.00, Cache: $1.00 |
| Claude Opus 3 | claude-3-opus-20240229 | anthropic | 200000 | 4096 | In: $15.00, Out: $75.00, Cache: $18.75 |
| Claude Opus 4 | claude-opus-4-20250514 | anthropic | 200000 | 32000 | In: $15.00, Out: $75.00, Cache: $18.75 |
| Claude Sonnet 3 | claude-3-sonnet-20240229 | anthropic | 200000 | 4096 | In: $3.00, Out: $15.00 |
| Claude Sonnet 3.5 | claude-3-5-sonnet-20240620 | anthropic | 200000 | 8192 | In: $3.00, Out: $15.00, Cache: $3.75 |
| Claude Sonnet 3.5 | claude-3-5-sonnet-20241022 | anthropic | 200000 | 8192 | In: $3.00, Out: $15.00, Cache: $3.75 |
| Claude Sonnet 3.7 | claude-3-7-sonnet-20250219 | anthropic | 200000 | 64000 | In: $3.00, Out: $15.00, Cache: $3.75 |
| Claude Sonnet 4 | claude-sonnet-4-20250514 | anthropic | 200000 | 64000 | In: $3.00, Out: $15.00, Cache: $3.75 |


### Gemini (58)

| Model | ID | Provider | Context | Max Output | Standard Pricing (per 1M tokens) |
| :-- | :-- | :-- | --: | --: | :-- |
| AQA | aqa | gemini | 7168 | 1024 | - |
| Embedding 001 | embedding-001 | gemini | 2048 | 1 | - |
| Embedding Gecko | embedding-gecko-001 | gemini | 1024 | 1 | - |
| Gemini 1.0 Pro Vision | gemini-1.0-pro-vision-latest | gemini | 12288 | 4096 | In: $0.08, Out: $0.30 |
| Gemini 1.0 Pro Vision | gemini-pro-vision | gemini | 12288 | 4096 | In: $0.08, Out: $0.30 |
| Gemini 1.5 Flash | gemini-1.5-flash | gemini | 1048576 | 8192 | In: $0.08, Out: $0.30, Cache: $0.02 |
| Gemini 1.5 Flash | gemini-1.5-flash-001 | gemini | 1048576 | 8192 | In: $0.08, Out: $0.30, Cache: $0.02 |
| Gemini 1.5 Flash | gemini-1.5-flash-002 | gemini | 1048576 | 8192 | In: $0.08, Out: $0.30, Cache: $0.02 |
| Gemini 1.5 Flash | gemini-1.5-flash-latest | gemini | 1048576 | 8192 | In: $0.08, Out: $0.30, Cache: $0.02 |
| Gemini 1.5 Flash-8B | gemini-1.5-flash-8b | gemini | 1048576 | 8192 | In: $0.08, Out: $0.30, Cache: $0.02 |
| Gemini 1.5 Flash-8B | gemini-1.5-flash-8b-001 | gemini | 1048576 | 8192 | In: $0.08, Out: $0.30, Cache: $0.02 |
| Gemini 1.5 Flash-8B | gemini-1.5-flash-8b-latest | gemini | 1048576 | 8192 | In: $0.08, Out: $0.30, Cache: $0.02 |
| Gemini 1.5 Pro | gemini-1.5-pro | gemini | 2097152 | 8192 | In: $1.25, Out: $5.00, Cache: $0.31 |
| Gemini 1.5 Pro | gemini-1.5-pro-001 | gemini | 2097152 | 8192 | In: $1.25, Out: $5.00, Cache: $0.31 |
| Gemini 1.5 Pro | gemini-1.5-pro-002 | gemini | 2097152 | 8192 | In: $1.25, Out: $5.00, Cache: $0.31 |
| Gemini 1.5 Pro | gemini-1.5-pro-latest | gemini | 2097152 | 8192 | In: $1.25, Out: $5.00, Cache: $0.31 |
| Gemini 2.0 Flash | gemini-2.0-flash | gemini | 1048576 | 8192 | In: $0.10, Out: $0.40, Cache: $0.02 |
| Gemini 2.0 Flash | gemini-2.0-flash-001 | gemini | 1048576 | 8192 | In: $0.10, Out: $0.40, Cache: $0.02 |
| Gemini 2.0 Flash | gemini-2.0-flash-exp | gemini | 1048576 | 8192 | In: $0.10, Out: $0.40, Cache: $0.02 |
| Gemini 2.0 Flash Live | gemini-2.0-flash-live-001 | gemini | 1048576 | 8192 | In: $0.10, Out: $0.40, Cache: $0.02 |
| Gemini 2.0 Flash Preview Image Generation | gemini-2.0-flash-preview-image-generation | gemini | 32000 | 8192 | In: $0.10, Out: $0.40, Cache: $0.02 |
| Gemini 2.0 Flash-Lite | gemini-2.0-flash-lite | gemini | 1048576 | 8192 | In: $0.10, Out: $0.40, Cache: $0.02 |
| Gemini 2.0 Flash-Lite | gemini-2.0-flash-lite-001 | gemini | 1048576 | 8192 | In: $0.10, Out: $0.40, Cache: $0.02 |
| Gemini 2.0 Flash-Lite Preview | gemini-2.0-flash-lite-preview | gemini | 1048576 | 8192 | In: $0.08, Out: $0.30 |
| Gemini 2.0 Flash-Lite Preview 02-05 | gemini-2.0-flash-lite-preview-02-05 | gemini | 1048576 | 8192 | In: $0.08, Out: $0.30 |
| Gemini 2.0 Pro Experimental | gemini-2.0-pro-exp | gemini | 1048576 | 65536 | In: $0.08, Out: $0.30 |
| Gemini 2.0 Pro Experimental 02-05 | gemini-2.0-pro-exp-02-05 | gemini | 1048576 | 65536 | In: $0.08, Out: $0.30 |
| Gemini 2.5 Flash | gemini-2.5-flash | gemini | 1048576 | 65536 | In: $0.30, Out: $2.50, Cache: $0.08 |
| Gemini 2.5 Flash | gemini-2.5-flash-preview-05-20 | gemini | 1048576 | 65536 | In: $0.30, Out: $2.50, Cache: $0.08 |
| Gemini 2.5 Flash Live | gemini-live-2.5-flash-preview | gemini | 1048576 | 8192 | In: $0.30, Out: $2.50, Cache: $0.08 |
| Gemini 2.5 Flash Native Audio | gemini-2.5-flash-exp-native-audio-thinking-dialog | gemini | 128000 | 8000 | In: $0.30, Out: $2.50, Cache: $0.08 |
| Gemini 2.5 Flash Native Audio | gemini-2.5-flash-preview-native-audio-dialog | gemini | 128000 | 8000 | In: $0.30, Out: $2.50, Cache: $0.08 |
| Gemini 2.5 Flash Preview 05-20 | gemini-2.0-flash-thinking-exp | gemini | 1048576 | 65536 | In: $0.10, Out: $0.40 |
| Gemini 2.5 Flash Preview 05-20 | gemini-2.0-flash-thinking-exp-01-21 | gemini | 1048576 | 65536 | In: $0.10, Out: $0.40 |
| Gemini 2.5 Flash Preview 05-20 | gemini-2.0-flash-thinking-exp-1219 | gemini | 1048576 | 65536 | In: $0.10, Out: $0.40 |
| Gemini 2.5 Flash Preview Text-to-Speech | gemini-2.5-flash-preview-tts | gemini | 8000 | 16000 | In: $0.30, Out: $2.50, Cache: $0.08 |
| Gemini 2.5 Flash-Lite Preview | gemini-2.5-flash-lite-preview-06-17 | gemini | 1000000 | 64000 | In: $0.30, Out: $2.50, Cache: $0.08 |
| Gemini 2.5 Pro | gemini-2.5-pro | gemini | 1048576 | 65536 | In: $1.25, Out: $10.00, Cache: $0.31 |
| Gemini 2.5 Pro | gemini-2.5-pro-preview-03-25 | gemini | 1048576 | 65536 | In: $1.25, Out: $10.00, Cache: $0.31 |
| Gemini 2.5 Pro | gemini-2.5-pro-preview-05-06 | gemini | 1048576 | 65536 | In: $1.25, Out: $10.00, Cache: $0.31 |
| Gemini 2.5 Pro | gemini-2.5-pro-preview-06-05 | gemini | 1048576 | 65536 | In: $1.25, Out: $10.00, Cache: $0.31 |
| Gemini 2.5 Pro Preview Text-to-Speech | gemini-2.5-pro-preview-tts | gemini | 8000 | 16000 | In: $1.25, Out: $10.00, Cache: $0.31 |
| Gemini Embedding | gemini-embedding-001 | gemini | 2048 | - | In: $0.15 |
| Gemini Embedding | gemini-embedding-exp-03-07 | gemini | 2048 | - | In: $0.15 |
| Gemini Embedding Experimental | gemini-embedding-exp | gemini | 8192 | 1 | In: $0.00, Out: $0.00 |
| Gemini Experimental 1206 | gemini-exp-1206 | gemini | 1048576 | 65536 | In: $0.08, Out: $0.30 |
| Gemma 3 12B | gemma-3-12b-it | gemini | 32768 | 8192 | In: $0.08, Out: $0.30 |
| Gemma 3 1B | gemma-3-1b-it | gemini | 32768 | 8192 | In: $0.08, Out: $0.30 |
| Gemma 3 27B | gemma-3-27b-it | gemini | 131072 | 8192 | In: $0.08, Out: $0.30 |
| Gemma 3 4B | gemma-3-4b-it | gemini | 32768 | 8192 | In: $0.08, Out: $0.30 |
| Gemma 3n E2B | gemma-3n-e2b-it | gemini | 8192 | 2048 | In: $0.08, Out: $0.30 |
| Gemma 3n E4B | gemma-3n-e4b-it | gemini | 8192 | 2048 | In: $0.08, Out: $0.30 |
| Imagen 3 | imagen-3.0-generate-002 | gemini | - | 4 | - |
| Imagen 4 | imagen-4.0-generate-preview-06-06 | gemini | 480 | 1 | - |
| Imagen 4 | imagen-4.0-ultra-generate-preview-06-06 | gemini | 480 | 1 | - |
| LearnLM 2.0 Flash Experimental | learnlm-2.0-flash-experimental | gemini | 1048576 | 32768 | In: $0.08, Out: $0.30 |
| Legacy Embedding Models | text-embedding-004 | gemini | 2048 | - | - |
| Veo 2 | veo-2.0-generate-001 | gemini | - | 2 | - |


### Deepseek (2)

| Model | ID | Provider | Context | Max Output | Standard Pricing (per 1M tokens) |
| :-- | :-- | :-- | --: | --: | :-- |
| deepseek-chat | deepseek-chat | deepseek | 64000 | 8000 | In: $0.27, Out: $1.10, Cache: $0.07 |
| deepseek-reasoner | deepseek-reasoner | deepseek | 64000 | 64000 | In: $0.55, Out: $2.19, Cache: $0.14 |


### Bedrock (30)

| Model | ID | Provider | Context | Max Output | Standard Pricing (per 1M tokens) |
| :-- | :-- | :-- | --: | --: | :-- |
| Claude | anthropic.claude-v2 | bedrock | 200000 | 4096 | In: $8.00, Out: $24.00 |
| Claude | anthropic.claude-v2:0:100k | bedrock | 200000 | 4096 | In: $8.00, Out: $24.00 |
| Claude | anthropic.claude-v2:0:18k | bedrock | 200000 | 4096 | In: $8.00, Out: $24.00 |
| Claude | anthropic.claude-v2:1 | bedrock | 200000 | 4096 | In: $8.00, Out: $24.00 |
| Claude | anthropic.claude-v2:1:18k | bedrock | 200000 | 4096 | In: $8.00, Out: $24.00 |
| Claude | anthropic.claude-v2:1:200k | bedrock | 200000 | 4096 | In: $8.00, Out: $24.00 |
| Claude 3 Haiku | anthropic.claude-3-haiku-20240307-v1:0 | bedrock | 200000 | 4096 | In: $0.25, Out: $1.25 |
| Claude 3 Haiku | anthropic.claude-3-haiku-20240307-v1:0:200k | bedrock | 200000 | 4096 | In: $0.25, Out: $1.25 |
| Claude 3 Haiku | anthropic.claude-3-haiku-20240307-v1:0:48k | bedrock | 200000 | 4096 | In: $0.25, Out: $1.25 |
| Claude 3 Opus | anthropic.claude-3-opus-20240229-v1:0 | bedrock | 200000 | 4096 | In: $15.00, Out: $75.00 |
| Claude 3 Opus | anthropic.claude-3-opus-20240229-v1:0:12k | bedrock | 200000 | 4096 | In: $15.00, Out: $75.00 |
| Claude 3 Opus | anthropic.claude-3-opus-20240229-v1:0:200k | bedrock | 200000 | 4096 | In: $15.00, Out: $75.00 |
| Claude 3 Opus | anthropic.claude-3-opus-20240229-v1:0:28k | bedrock | 200000 | 4096 | In: $15.00, Out: $75.00 |
| Claude 3 Sonnet | anthropic.claude-3-sonnet-20240229-v1:0 | bedrock | 200000 | 4096 | In: $3.00, Out: $15.00 |
| Claude 3 Sonnet | anthropic.claude-3-sonnet-20240229-v1:0:200k | bedrock | 200000 | 4096 | In: $3.00, Out: $15.00 |
| Claude 3 Sonnet | anthropic.claude-3-sonnet-20240229-v1:0:28k | bedrock | 200000 | 4096 | In: $3.00, Out: $15.00 |
| Claude 3.5 Haiku | anthropic.claude-3-5-haiku-20241022-v1:0 | bedrock | 200000 | 4096 | In: $0.80, Out: $4.00 |
| Claude 3.5 Sonnet | anthropic.claude-3-5-sonnet-20240620-v1:0 | bedrock | 200000 | 4096 | In: $3.00, Out: $15.00 |
| Claude 3.5 Sonnet | anthropic.claude-3-5-sonnet-20240620-v1:0:18k | bedrock | 200000 | 4096 | In: $3.00, Out: $15.00 |
| Claude 3.5 Sonnet | anthropic.claude-3-5-sonnet-20240620-v1:0:200k | bedrock | 200000 | 4096 | In: $3.00, Out: $15.00 |
| Claude 3.5 Sonnet | anthropic.claude-3-5-sonnet-20240620-v1:0:51k | bedrock | 200000 | 4096 | In: $3.00, Out: $15.00 |
| Claude 3.5 Sonnet v2 | anthropic.claude-3-5-sonnet-20241022-v2:0 | bedrock | 200000 | 4096 | In: $3.00, Out: $15.00 |
| Claude 3.5 Sonnet v2 | anthropic.claude-3-5-sonnet-20241022-v2:0:18k | bedrock | 200000 | 4096 | In: $3.00, Out: $15.00 |
| Claude 3.5 Sonnet v2 | anthropic.claude-3-5-sonnet-20241022-v2:0:200k | bedrock | 200000 | 4096 | In: $3.00, Out: $15.00 |
| Claude 3.5 Sonnet v2 | anthropic.claude-3-5-sonnet-20241022-v2:0:51k | bedrock | 200000 | 4096 | In: $3.00, Out: $15.00 |
| Claude 3.7 Sonnet | us.anthropic.claude-3-7-sonnet-20250219-v1:0 | bedrock | 200000 | 4096 | In: $3.00, Out: $15.00 |
| Claude Instant | anthropic.claude-instant-v1 | bedrock | 200000 | 4096 | In: $0.80, Out: $2.40 |
| Claude Instant | anthropic.claude-instant-v1:2:100k | bedrock | 200000 | 4096 | In: $0.80, Out: $2.40 |
| Claude Opus 4 | us.anthropic.claude-opus-4-20250514-v1:0 | bedrock | 200000 | 4096 | In: $0.10, Out: $0.20 |
| Claude Sonnet 4 | us.anthropic.claude-sonnet-4-20250514-v1:0 | bedrock | 200000 | 4096 | In: $0.10, Out: $0.20 |


### Openrouter (319)

| Model | ID | Provider | Context | Max Output | Standard Pricing (per 1M tokens) |
| :-- | :-- | :-- | --: | --: | :-- |
| 01.AI: Yi Large | 01-ai/yi-large | openrouter | 32768 | 4096 | In: $3.00, Out: $3.00 |
| AI21: Jamba 1.6 Large | ai21/jamba-1.6-large | openrouter | 256000 | 4096 | In: $2.00, Out: $8.00 |
| AI21: Jamba Mini 1.6 | ai21/jamba-1.6-mini | openrouter | 256000 | 4096 | In: $0.20, Out: $0.40 |
| Aetherwiing: Starcannon 12B | aetherwiing/mn-starcannon-12b | openrouter | 16384 | 4096 | In: $0.80, Out: $1.20 |
| Agentica: Deepcoder 14B Preview | agentica-org/deepcoder-14b-preview | openrouter | 96000 | - | In: $0.02, Out: $0.02 |
| Agentica: Deepcoder 14B Preview (free) | agentica-org/deepcoder-14b-preview:free | openrouter | 96000 | - | - |
| AionLabs: Aion-1.0 | aion-labs/aion-1.0 | openrouter | 131072 | 32768 | In: $4.00, Out: $8.00 |
| AionLabs: Aion-1.0-Mini | aion-labs/aion-1.0-mini | openrouter | 131072 | 32768 | In: $0.70, Out: $1.40 |
| AionLabs: Aion-RP 1.0 (8B) | aion-labs/aion-rp-llama-3.1-8b | openrouter | 32768 | 32768 | In: $0.20, Out: $0.20 |
| AlfredPros: CodeLLaMa 7B Instruct Solidity | alfredpros/codellama-7b-instruct-solidity | openrouter | 4096 | 4096 | In: $0.80, Out: $1.20 |
| Amazon: Nova Lite 1.0 | amazon/nova-lite-v1 | openrouter | 300000 | 5120 | In: $0.06, Out: $0.24 |
| Amazon: Nova Micro 1.0 | amazon/nova-micro-v1 | openrouter | 128000 | 5120 | In: $0.04, Out: $0.14 |
| Amazon: Nova Pro 1.0 | amazon/nova-pro-v1 | openrouter | 300000 | 5120 | In: $0.80, Out: $3.20 |
| Anthropic: Claude 3 Haiku | anthropic/claude-3-haiku | openrouter | 200000 | 4096 | In: $0.25, Out: $1.25, Cache: $0.03 |
| Anthropic: Claude 3 Haiku (self-moderated) | anthropic/claude-3-haiku:beta | openrouter | 200000 | 4096 | In: $0.25, Out: $1.25, Cache: $0.03 |
| Anthropic: Claude 3 Opus | anthropic/claude-3-opus | openrouter | 200000 | 4096 | In: $15.00, Out: $75.00, Cache: $1.50 |
| Anthropic: Claude 3 Opus (self-moderated) | anthropic/claude-3-opus:beta | openrouter | 200000 | 4096 | In: $15.00, Out: $75.00, Cache: $1.50 |
| Anthropic: Claude 3 Sonnet | anthropic/claude-3-sonnet | openrouter | 200000 | 4096 | In: $3.00, Out: $15.00, Cache: $0.30 |
| Anthropic: Claude 3 Sonnet (self-moderated) | anthropic/claude-3-sonnet:beta | openrouter | 200000 | 4096 | In: $3.00, Out: $15.00, Cache: $0.30 |
| Anthropic: Claude 3.5 Haiku | anthropic/claude-3.5-haiku | openrouter | 200000 | 8192 | In: $0.80, Out: $4.00, Cache: $0.08 |
| Anthropic: Claude 3.5 Haiku (2024-10-22) | anthropic/claude-3.5-haiku-20241022 | openrouter | 200000 | 8192 | In: $0.80, Out: $4.00, Cache: $0.08 |
| Anthropic: Claude 3.5 Haiku (2024-10-22) (self-moderated) | anthropic/claude-3.5-haiku-20241022:beta | openrouter | 200000 | 8192 | In: $0.80, Out: $4.00, Cache: $0.08 |
| Anthropic: Claude 3.5 Haiku (self-moderated) | anthropic/claude-3.5-haiku:beta | openrouter | 200000 | 8192 | In: $0.80, Out: $4.00, Cache: $0.08 |
| Anthropic: Claude 3.5 Sonnet | anthropic/claude-3.5-sonnet | openrouter | 200000 | 8192 | In: $3.00, Out: $15.00, Cache: $0.30 |
| Anthropic: Claude 3.5 Sonnet (2024-06-20) | anthropic/claude-3.5-sonnet-20240620 | openrouter | 200000 | 8192 | In: $3.00, Out: $15.00, Cache: $0.30 |
| Anthropic: Claude 3.5 Sonnet (2024-06-20) (self-moderated) | anthropic/claude-3.5-sonnet-20240620:beta | openrouter | 200000 | 8192 | In: $3.00, Out: $15.00, Cache: $0.30 |
| Anthropic: Claude 3.5 Sonnet (self-moderated) | anthropic/claude-3.5-sonnet:beta | openrouter | 200000 | 8192 | In: $3.00, Out: $15.00, Cache: $0.30 |
| Anthropic: Claude 3.7 Sonnet | anthropic/claude-3.7-sonnet | openrouter | 200000 | 64000 | In: $3.00, Out: $15.00, Cache: $0.30 |
| Anthropic: Claude 3.7 Sonnet (self-moderated) | anthropic/claude-3.7-sonnet:beta | openrouter | 200000 | 128000 | In: $3.00, Out: $15.00, Cache: $0.30 |
| Anthropic: Claude 3.7 Sonnet (thinking) | anthropic/claude-3.7-sonnet:thinking | openrouter | 200000 | 64000 | In: $3.00, Out: $15.00, Cache: $0.30 |
| Anthropic: Claude Opus 4 | anthropic/claude-opus-4 | openrouter | 200000 | 32000 | In: $15.00, Out: $75.00, Cache: $1.50 |
| Anthropic: Claude Sonnet 4 | anthropic/claude-sonnet-4 | openrouter | 200000 | 64000 | In: $3.00, Out: $15.00, Cache: $0.30 |
| Anthropic: Claude v2 | anthropic/claude-2 | openrouter | 200000 | 4096 | In: $8.00, Out: $24.00 |
| Anthropic: Claude v2 (self-moderated) | anthropic/claude-2:beta | openrouter | 200000 | 4096 | In: $8.00, Out: $24.00 |
| Anthropic: Claude v2.0 | anthropic/claude-2.0 | openrouter | 100000 | 4096 | In: $8.00, Out: $24.00 |
| Anthropic: Claude v2.0 (self-moderated) | anthropic/claude-2.0:beta | openrouter | 100000 | 4096 | In: $8.00, Out: $24.00 |
| Anthropic: Claude v2.1 | anthropic/claude-2.1 | openrouter | 200000 | 4096 | In: $8.00, Out: $24.00 |
| Anthropic: Claude v2.1 (self-moderated) | anthropic/claude-2.1:beta | openrouter | 200000 | 4096 | In: $8.00, Out: $24.00 |
| Arcee AI: Arcee Blitz | arcee-ai/arcee-blitz | openrouter | 32768 | - | In: $0.45, Out: $0.75 |
| Arcee AI: Caller Large | arcee-ai/caller-large | openrouter | 32768 | - | In: $0.55, Out: $0.85 |
| Arcee AI: Coder Large | arcee-ai/coder-large | openrouter | 32768 | - | In: $0.50, Out: $0.80 |
| Arcee AI: Maestro Reasoning | arcee-ai/maestro-reasoning | openrouter | 131072 | 32000 | In: $0.90, Out: $3.30 |
| Arcee AI: Spotlight | arcee-ai/spotlight | openrouter | 131072 | 65537 | In: $0.18, Out: $0.18 |
| Arcee AI: Virtuoso Large | arcee-ai/virtuoso-large | openrouter | 131072 | 64000 | In: $0.75, Out: $1.20 |
| Arcee AI: Virtuoso Medium V2 | arcee-ai/virtuoso-medium-v2 | openrouter | 131072 | 32768 | In: $0.50, Out: $0.80 |
| ArliAI: QwQ 32B RpR v1 (free) | arliai/qwq-32b-arliai-rpr-v1:free | openrouter | 32768 | - | - |
| Auto Router | openrouter/auto | openrouter | 2000000 | - | - |
| Baidu: ERNIE 4.5 300B A47B  | baidu/ernie-4.5-300b-a47b | openrouter | 123000 | 12000 | In: $0.28, Out: $1.10 |
| Cohere: Command | cohere/command | openrouter | 4096 | 4000 | In: $1.00, Out: $2.00 |
| Cohere: Command A | cohere/command-a | openrouter | 256000 | 8192 | In: $2.50, Out: $10.00 |
| Cohere: Command R | cohere/command-r | openrouter | 128000 | 4000 | In: $0.50, Out: $1.50 |
| Cohere: Command R (03-2024) | cohere/command-r-03-2024 | openrouter | 128000 | 4000 | In: $0.50, Out: $1.50 |
| Cohere: Command R (08-2024) | cohere/command-r-08-2024 | openrouter | 128000 | 4000 | In: $0.15, Out: $0.60 |
| Cohere: Command R+ | cohere/command-r-plus | openrouter | 128000 | 4000 | In: $3.00, Out: $15.00 |
| Cohere: Command R+ (04-2024) | cohere/command-r-plus-04-2024 | openrouter | 128000 | 4000 | In: $3.00, Out: $15.00 |
| Cohere: Command R+ (08-2024) | cohere/command-r-plus-08-2024 | openrouter | 128000 | 4000 | In: $2.50, Out: $10.00 |
| Cohere: Command R7B (12-2024) | cohere/command-r7b-12-2024 | openrouter | 128000 | 4000 | In: $0.04, Out: $0.15 |
| DeepSeek: DeepSeek Prover V2 | deepseek/deepseek-prover-v2 | openrouter | 163840 | - | In: $0.50, Out: $2.18 |
| DeepSeek: DeepSeek V3 | deepseek/deepseek-chat | openrouter | 163840 | 163840 | In: $0.30, Out: $0.85 |
| DeepSeek: DeepSeek V3 (free) | deepseek/deepseek-chat:free | openrouter | 163840 | - | - |
| DeepSeek: DeepSeek V3 0324 | deepseek/deepseek-chat-v3-0324 | openrouter | 163840 | 163840 | In: $0.25, Out: $0.85 |
| DeepSeek: DeepSeek V3 0324 (free) | deepseek/deepseek-chat-v3-0324:free | openrouter | 32768 | 16384 | - |
| DeepSeek: DeepSeek V3 Base (free) | deepseek/deepseek-v3-base:free | openrouter | 163840 | - | - |
| DeepSeek: Deepseek R1 0528 Qwen3 8B | deepseek/deepseek-r1-0528-qwen3-8b | openrouter | 32000 | - | In: $0.01, Out: $0.02 |
| DeepSeek: Deepseek R1 0528 Qwen3 8B (free) | deepseek/deepseek-r1-0528-qwen3-8b:free | openrouter | 131072 | - | - |
| DeepSeek: R1 | deepseek/deepseek-r1 | openrouter | 163840 | 163840 | In: $0.40, Out: $2.00 |
| DeepSeek: R1 (free) | deepseek/deepseek-r1:free | openrouter | 163840 | - | - |
| DeepSeek: R1 0528 | deepseek/deepseek-r1-0528 | openrouter | 163840 | - | In: $0.27, Out: $0.27 |
| DeepSeek: R1 0528 (free) | deepseek/deepseek-r1-0528:free | openrouter | 163840 | - | - |
| DeepSeek: R1 Distill Llama 70B | deepseek/deepseek-r1-distill-llama-70b | openrouter | 131072 | - | In: $0.05, Out: $0.05 |
| DeepSeek: R1 Distill Llama 70B (free) | deepseek/deepseek-r1-distill-llama-70b:free | openrouter | 8192 | 4096 | - |
| DeepSeek: R1 Distill Llama 8B | deepseek/deepseek-r1-distill-llama-8b | openrouter | 32000 | 32000 | In: $0.04, Out: $0.04 |
| DeepSeek: R1 Distill Qwen 1.5B | deepseek/deepseek-r1-distill-qwen-1.5b | openrouter | 131072 | 32768 | In: $0.18, Out: $0.18 |
| DeepSeek: R1 Distill Qwen 14B | deepseek/deepseek-r1-distill-qwen-14b | openrouter | 64000 | 32000 | In: $0.15, Out: $0.15 |
| DeepSeek: R1 Distill Qwen 14B (free) | deepseek/deepseek-r1-distill-qwen-14b:free | openrouter | 64000 | - | - |
| DeepSeek: R1 Distill Qwen 32B | deepseek/deepseek-r1-distill-qwen-32b | openrouter | 131072 | 16384 | In: $0.08, Out: $0.15 |
| DeepSeek: R1 Distill Qwen 7B | deepseek/deepseek-r1-distill-qwen-7b | openrouter | 131072 | - | In: $0.10, Out: $0.20 |
| Dolphin 2.9.2 Mixtral 8x22B 🐬 | cognitivecomputations/dolphin-mixtral-8x22b | openrouter | 16000 | 8192 | In: $0.90, Out: $0.90 |
| Dolphin3.0 Mistral 24B (free) | cognitivecomputations/dolphin3.0-mistral-24b:free | openrouter | 32768 | - | - |
| Dolphin3.0 R1 Mistral 24B | cognitivecomputations/dolphin3.0-r1-mistral-24b | openrouter | 32768 | - | In: $0.01, Out: $0.01 |
| Dolphin3.0 R1 Mistral 24B (free) | cognitivecomputations/dolphin3.0-r1-mistral-24b:free | openrouter | 32768 | - | - |
| EVA Llama 3.33 70B | eva-unit-01/eva-llama-3.33-70b | openrouter | 16384 | 4096 | In: $4.00, Out: $6.00 |
| EVA Qwen2.5 72B | eva-unit-01/eva-qwen-2.5-72b | openrouter | 16384 | 4096 | In: $4.00, Out: $6.00 |
| EleutherAI: Llemma 7b | eleutherai/llemma_7b | openrouter | 4096 | 4096 | In: $0.80, Out: $1.20 |
| Fimbulvetr 11B v2 | sao10k/fimbulvetr-11b-v2 | openrouter | 4096 | 4096 | In: $0.80, Out: $1.20 |
| Goliath 120B | alpindale/goliath-120b | openrouter | 6144 | - | In: $9.00, Out: $11.00 |
| Google: Gemini 1.5 Flash  | google/gemini-flash-1.5 | openrouter | 1000000 | 8192 | In: $0.08, Out: $0.30, Cache: $0.02 |
| Google: Gemini 1.5 Flash 8B | google/gemini-flash-1.5-8b | openrouter | 1000000 | 8192 | In: $0.04, Out: $0.15, Cache: $0.01 |
| Google: Gemini 1.5 Pro | google/gemini-pro-1.5 | openrouter | 2000000 | 8192 | In: $1.25, Out: $5.00 |
| Google: Gemini 2.0 Flash | google/gemini-2.0-flash-001 | openrouter | 1048576 | 8192 | In: $0.10, Out: $0.40, Cache: $0.02 |
| Google: Gemini 2.0 Flash Experimental (free) | google/gemini-2.0-flash-exp:free | openrouter | 1048576 | 8192 | - |
| Google: Gemini 2.0 Flash Lite | google/gemini-2.0-flash-lite-001 | openrouter | 1048576 | 8192 | In: $0.08, Out: $0.30 |
| Google: Gemini 2.5 Flash | google/gemini-2.5-flash | openrouter | 1048576 | 65535 | In: $0.30, Out: $2.50, Cache: $0.08 |
| Google: Gemini 2.5 Flash Lite Preview 06-17 | google/gemini-2.5-flash-lite-preview-06-17 | openrouter | 1048576 | 65535 | In: $0.10, Out: $0.40, Cache: $0.02 |
| Google: Gemini 2.5 Pro | google/gemini-2.5-pro | openrouter | 1048576 | 65536 | In: $1.25, Out: $10.00, Cache: $0.31 |
| Google: Gemini 2.5 Pro Experimental | google/gemini-2.5-pro-exp-03-25 | openrouter | 1048576 | 65535 | - |
| Google: Gemini 2.5 Pro Preview 05-06 | google/gemini-2.5-pro-preview-05-06 | openrouter | 1048576 | 65535 | In: $1.25, Out: $10.00, Cache: $0.31 |
| Google: Gemini 2.5 Pro Preview 06-05 | google/gemini-2.5-pro-preview | openrouter | 1048576 | 65536 | In: $1.25, Out: $10.00, Cache: $0.31 |
| Google: Gemma 2 27B | google/gemma-2-27b-it | openrouter | 8192 | 2048 | In: $0.80, Out: $0.80 |
| Google: Gemma 2 9B | google/gemma-2-9b-it | openrouter | 8192 | 8192 | In: $0.00, Out: $0.00 |
| Google: Gemma 2 9B (free) | google/gemma-2-9b-it:free | openrouter | 8192 | 8192 | - |
| Google: Gemma 3 12B | google/gemma-3-12b-it | openrouter | 96000 | 8192 | In: $0.03, Out: $0.03 |
| Google: Gemma 3 12B (free) | google/gemma-3-12b-it:free | openrouter | 96000 | 8192 | - |
| Google: Gemma 3 27B | google/gemma-3-27b-it | openrouter | 131072 | 16384 | In: $0.09, Out: $0.17 |
| Google: Gemma 3 27B (free) | google/gemma-3-27b-it:free | openrouter | 96000 | 8192 | - |
| Google: Gemma 3 4B | google/gemma-3-4b-it | openrouter | 131072 | - | In: $0.02, Out: $0.04 |
| Google: Gemma 3 4B (free) | google/gemma-3-4b-it:free | openrouter | 32768 | 8192 | - |
| Google: Gemma 3n 2B (free) | google/gemma-3n-e2b-it:free | openrouter | 8192 | 2048 | - |
| Google: Gemma 3n 4B | google/gemma-3n-e4b-it | openrouter | 32768 | - | In: $0.02, Out: $0.04 |
| Google: Gemma 3n 4B (free) | google/gemma-3n-e4b-it:free | openrouter | 8192 | 2048 | - |
| Inception: Mercury | inception/mercury | openrouter | 32000 | 16000 | In: $0.25, Out: $1.00 |
| Inception: Mercury Coder | inception/mercury-coder | openrouter | 32000 | - | In: $0.25, Out: $1.00 |
| Infermatic: Mistral Nemo Inferor 12B | infermatic/mn-inferor-12b | openrouter | 16384 | 4096 | In: $0.80, Out: $1.20 |
| Inflection: Inflection 3 Pi | inflection/inflection-3-pi | openrouter | 8000 | 1024 | In: $2.50, Out: $10.00 |
| Inflection: Inflection 3 Productivity | inflection/inflection-3-productivity | openrouter | 8000 | 1024 | In: $2.50, Out: $10.00 |
| Kimi Dev 72b (free) | moonshotai/kimi-dev-72b:free | openrouter | 131072 | - | - |
| Liquid: LFM 3B | liquid/lfm-3b | openrouter | 32768 | - | In: $0.02, Out: $0.02 |
| Liquid: LFM 40B MoE | liquid/lfm-40b | openrouter | 32768 | - | In: $0.15, Out: $0.15 |
| Liquid: LFM 7B | liquid/lfm-7b | openrouter | 32768 | - | In: $0.01, Out: $0.01 |
| Llama Guard 3 8B | meta-llama/llama-guard-3-8b | openrouter | 131072 | - | In: $0.02, Out: $0.06 |
| Magnum 72B | alpindale/magnum-72b | openrouter | 16384 | 4096 | In: $4.00, Out: $6.00 |
| Magnum v2 72B | anthracite-org/magnum-v2-72b | openrouter | 32768 | - | In: $3.00, Out: $3.00 |
| Magnum v4 72B | anthracite-org/magnum-v4-72b | openrouter | 16384 | 1024 | In: $2.50, Out: $3.00 |
| Mancer: Weaver (alpha) | mancer/weaver | openrouter | 8000 | 1000 | In: $1.50, Out: $1.50 |
| Meta: Llama 3 70B Instruct | meta-llama/llama-3-70b-instruct | openrouter | 8192 | 16384 | In: $0.30, Out: $0.40 |
| Meta: Llama 3 8B Instruct | meta-llama/llama-3-8b-instruct | openrouter | 8192 | 16384 | In: $0.03, Out: $0.06 |
| Meta: Llama 3.1 405B (base) | meta-llama/llama-3.1-405b | openrouter | 32768 | - | In: $2.00, Out: $2.00 |
| Meta: Llama 3.1 405B Instruct | meta-llama/llama-3.1-405b-instruct | openrouter | 32768 | 16384 | In: $0.80, Out: $0.80 |
| Meta: Llama 3.1 405B Instruct (free) | meta-llama/llama-3.1-405b-instruct:free | openrouter | 65536 | - | - |
| Meta: Llama 3.1 70B Instruct | meta-llama/llama-3.1-70b-instruct | openrouter | 131072 | 16384 | In: $0.10, Out: $0.28 |
| Meta: Llama 3.1 8B Instruct | meta-llama/llama-3.1-8b-instruct | openrouter | 131000 | 131000 | In: $0.02, Out: $0.02 |
| Meta: Llama 3.2 11B Vision Instruct | meta-llama/llama-3.2-11b-vision-instruct | openrouter | 131072 | 16384 | In: $0.05, Out: $0.05 |
| Meta: Llama 3.2 11B Vision Instruct (free) | meta-llama/llama-3.2-11b-vision-instruct:free | openrouter | 131072 | 2048 | - |
| Meta: Llama 3.2 1B Instruct | meta-llama/llama-3.2-1b-instruct | openrouter | 131072 | 16384 | In: $0.01, Out: $0.01 |
| Meta: Llama 3.2 3B Instruct | meta-llama/llama-3.2-3b-instruct | openrouter | 20000 | 20000 | In: $0.00, Out: $0.01 |
| Meta: Llama 3.2 3B Instruct (free) | meta-llama/llama-3.2-3b-instruct:free | openrouter | 131072 | - | - |
| Meta: Llama 3.2 90B Vision Instruct | meta-llama/llama-3.2-90b-vision-instruct | openrouter | 131072 | 2048 | In: $1.20, Out: $1.20 |
| Meta: Llama 3.3 70B Instruct | meta-llama/llama-3.3-70b-instruct | openrouter | 131072 | 16384 | In: $0.04, Out: $0.12 |
| Meta: Llama 3.3 70B Instruct (free) | meta-llama/llama-3.3-70b-instruct:free | openrouter | 65536 | - | - |
| Meta: Llama 4 Maverick | meta-llama/llama-4-maverick | openrouter | 1048576 | 16384 | In: $0.15, Out: $0.60 |
| Meta: Llama 4 Scout | meta-llama/llama-4-scout | openrouter | 1048576 | 1048576 | In: $0.08, Out: $0.30 |
| Meta: Llama Guard 4 12B | meta-llama/llama-guard-4-12b | openrouter | 163840 | - | In: $0.05, Out: $0.05 |
| Meta: LlamaGuard 2 8B | meta-llama/llama-guard-2-8b | openrouter | 8192 | - | In: $0.20, Out: $0.20 |
| Microsoft: MAI DS R1 (free) | microsoft/mai-ds-r1:free | openrouter | 163840 | - | - |
| Microsoft: Phi 4 | microsoft/phi-4 | openrouter | 16384 | 16384 | In: $0.07, Out: $0.14 |
| Microsoft: Phi 4 Multimodal Instruct | microsoft/phi-4-multimodal-instruct | openrouter | 131072 | - | In: $0.05, Out: $0.10 |
| Microsoft: Phi 4 Reasoning Plus | microsoft/phi-4-reasoning-plus | openrouter | 32768 | - | In: $0.07, Out: $0.35 |
| Microsoft: Phi-3 Medium 128K Instruct | microsoft/phi-3-medium-128k-instruct | openrouter | 128000 | - | In: $1.00, Out: $1.00 |
| Microsoft: Phi-3 Mini 128K Instruct | microsoft/phi-3-mini-128k-instruct | openrouter | 128000 | - | In: $0.10, Out: $0.10 |
| Microsoft: Phi-3.5 Mini 128K Instruct | microsoft/phi-3.5-mini-128k-instruct | openrouter | 128000 | - | In: $0.10, Out: $0.10 |
| Midnight Rose 70B | sophosympatheia/midnight-rose-70b | openrouter | 4096 | 2048 | In: $0.80, Out: $0.80 |
| MiniMax: MiniMax M1 | minimax/minimax-m1 | openrouter | 1000000 | 40000 | In: $0.30, Out: $1.65 |
| MiniMax: MiniMax-01 | minimax/minimax-01 | openrouter | 1000192 | 1000192 | In: $0.20, Out: $1.10 |
| Mistral Large | mistralai/mistral-large | openrouter | 128000 | - | In: $2.00, Out: $6.00 |
| Mistral Large 2407 | mistralai/mistral-large-2407 | openrouter | 131072 | - | In: $2.00, Out: $6.00 |
| Mistral Large 2411 | mistralai/mistral-large-2411 | openrouter | 131072 | - | In: $2.00, Out: $6.00 |
| Mistral Nemo 12B Celeste | nothingiisreal/mn-celeste-12b | openrouter | 16384 | 4096 | In: $0.80, Out: $1.20 |
| Mistral Small | mistralai/mistral-small | openrouter | 32768 | - | In: $0.20, Out: $0.60 |
| Mistral Tiny | mistralai/mistral-tiny | openrouter | 32768 | - | In: $0.25, Out: $0.25 |
| Mistral: Codestral 2501 | mistralai/codestral-2501 | openrouter | 262144 | - | In: $0.30, Out: $0.90 |
| Mistral: Devstral Medium | mistralai/devstral-medium | openrouter | 131072 | - | In: $0.40, Out: $2.00 |
| Mistral: Devstral Small 1.1 | mistralai/devstral-small | openrouter | 128000 | - | In: $0.07, Out: $0.28 |
| Mistral: Devstral Small 2505 | mistralai/devstral-small-2505 | openrouter | 32768 | - | In: $0.03, Out: $0.03 |
| Mistral: Devstral Small 2505 (free) | mistralai/devstral-small-2505:free | openrouter | 32768 | - | - |
| Mistral: Magistral Medium 2506 | mistralai/magistral-medium-2506 | openrouter | 40960 | 40000 | In: $2.00, Out: $5.00 |
| Mistral: Magistral Medium 2506 (thinking) | mistralai/magistral-medium-2506:thinking | openrouter | 40960 | 40000 | In: $2.00, Out: $5.00 |
| Mistral: Magistral Small 2506 | mistralai/magistral-small-2506 | openrouter | 40960 | 40960 | In: $0.10, Out: $0.30 |
| Mistral: Ministral 3B | mistralai/ministral-3b | openrouter | 131072 | - | In: $0.04, Out: $0.04 |
| Mistral: Ministral 8B | mistralai/ministral-8b | openrouter | 128000 | - | In: $0.10, Out: $0.10 |
| Mistral: Mistral 7B Instruct | mistralai/mistral-7b-instruct | openrouter | 32768 | 16384 | In: $0.03, Out: $0.05 |
| Mistral: Mistral 7B Instruct (free) | mistralai/mistral-7b-instruct:free | openrouter | 32768 | 16384 | - |
| Mistral: Mistral 7B Instruct v0.1 | mistralai/mistral-7b-instruct-v0.1 | openrouter | 2824 | - | In: $0.11, Out: $0.19 |
| Mistral: Mistral 7B Instruct v0.2 | mistralai/mistral-7b-instruct-v0.2 | openrouter | 32768 | - | In: $0.20, Out: $0.20 |
| Mistral: Mistral 7B Instruct v0.3 | mistralai/mistral-7b-instruct-v0.3 | openrouter | 32768 | 16384 | In: $0.03, Out: $0.05 |
| Mistral: Mistral Medium 3 | mistralai/mistral-medium-3 | openrouter | 131072 | - | In: $0.40, Out: $2.00 |
| Mistral: Mistral Nemo | mistralai/mistral-nemo | openrouter | 32000 | - | In: $0.01, Out: $0.05 |
| Mistral: Mistral Nemo (free) | mistralai/mistral-nemo:free | openrouter | 131072 | 128000 | - |
| Mistral: Mistral Small 3 | mistralai/mistral-small-24b-instruct-2501 | openrouter | 32768 | - | In: $0.03, Out: $0.03 |
| Mistral: Mistral Small 3 (free) | mistralai/mistral-small-24b-instruct-2501:free | openrouter | 32768 | - | - |
| Mistral: Mistral Small 3.1 24B | mistralai/mistral-small-3.1-24b-instruct | openrouter | 128000 | - | In: $0.05, Out: $0.10 |
| Mistral: Mistral Small 3.1 24B (free) | mistralai/mistral-small-3.1-24b-instruct:free | openrouter | 128000 | - | - |
| Mistral: Mistral Small 3.2 24B | mistralai/mistral-small-3.2-24b-instruct | openrouter | 128000 | - | In: $0.05, Out: $0.10 |
| Mistral: Mistral Small 3.2 24B (free) | mistralai/mistral-small-3.2-24b-instruct:free | openrouter | 96000 | - | - |
| Mistral: Mixtral 8x22B Instruct | mistralai/mixtral-8x22b-instruct | openrouter | 65536 | - | In: $0.90, Out: $0.90 |
| Mistral: Mixtral 8x7B Instruct | mistralai/mixtral-8x7b-instruct | openrouter | 32768 | 16384 | In: $0.08, Out: $0.24 |
| Mistral: Pixtral 12B | mistralai/pixtral-12b | openrouter | 32768 | - | In: $0.10, Out: $0.10 |
| Mistral: Pixtral Large 2411 | mistralai/pixtral-large-2411 | openrouter | 131072 | - | In: $2.00, Out: $6.00 |
| Mistral: Saba | mistralai/mistral-saba | openrouter | 32768 | - | In: $0.20, Out: $0.60 |
| Moonshot AI: Kimi VL A3B Thinking (free) | moonshotai/kimi-vl-a3b-thinking:free | openrouter | 131072 | - | - |
| MoonshotAI: Kimi K2 | moonshotai/kimi-k2 | openrouter | 63000 | 63000 | In: $0.14, Out: $2.49 |
| MoonshotAI: Kimi K2 (free) | moonshotai/kimi-k2:free | openrouter | 65536 | - | - |
| Morph: Fast Apply | morph/morph-v2 | openrouter | 32000 | 16000 | In: $1.20, Out: $2.70 |
| Morph: Morph V3 Fast | morph/morph-v3-fast | openrouter | 32000 | 16000 | In: $1.20, Out: $2.70 |
| Morph: Morph V3 Large | morph/morph-v3-large | openrouter | 32000 | 16000 | In: $1.20, Out: $2.70 |
| MythoMax 13B | gryphe/mythomax-l2-13b | openrouter | 4096 | - | In: $0.06, Out: $0.06 |
| NVIDIA: Llama 3.1 Nemotron 70B Instruct | nvidia/llama-3.1-nemotron-70b-instruct | openrouter | 131072 | 131072 | In: $0.12, Out: $0.30 |
| NVIDIA: Llama 3.1 Nemotron Ultra 253B v1 | nvidia/llama-3.1-nemotron-ultra-253b-v1 | openrouter | 131072 | - | In: $0.60, Out: $1.80 |
| NVIDIA: Llama 3.1 Nemotron Ultra 253B v1 (free) | nvidia/llama-3.1-nemotron-ultra-253b-v1:free | openrouter | 131072 | - | - |
| NVIDIA: Llama 3.3 Nemotron Super 49B v1 | nvidia/llama-3.3-nemotron-super-49b-v1 | openrouter | 131072 | - | In: $0.13, Out: $0.40 |
| NeverSleep: Llama 3 Lumimaid 70B | neversleep/llama-3-lumimaid-70b | openrouter | 8192 | 4096 | In: $4.00, Out: $6.00 |
| NeverSleep: Lumimaid v0.2 8B | neversleep/llama-3.1-lumimaid-8b | openrouter | 32768 | - | In: $0.18, Out: $1.00 |
| Noromaid 20B | neversleep/noromaid-20b | openrouter | 8192 | 2048 | In: $1.25, Out: $2.00 |
| Nous: DeepHermes 3 Llama 3 8B Preview (free) | nousresearch/deephermes-3-llama-3-8b-preview:free | openrouter | 131072 | - | - |
| Nous: Hermes 2 Mixtral 8x7B DPO | nousresearch/nous-hermes-2-mixtral-8x7b-dpo | openrouter | 32768 | 2048 | In: $0.60, Out: $0.60 |
| Nous: Hermes 3 405B Instruct | nousresearch/hermes-3-llama-3.1-405b | openrouter | 131072 | 16384 | In: $0.70, Out: $0.80 |
| Nous: Hermes 3 70B Instruct | nousresearch/hermes-3-llama-3.1-70b | openrouter | 131072 | - | In: $0.10, Out: $0.28 |
| NousResearch: Hermes 2 Pro - Llama-3 8B | nousresearch/hermes-2-pro-llama-3-8b | openrouter | 131072 | 131072 | In: $0.02, Out: $0.04 |
| OpenAI: ChatGPT-4o | openai/chatgpt-4o-latest | openrouter | 128000 | 16384 | In: $5.00, Out: $15.00 |
| OpenAI: Codex Mini | openai/codex-mini | openrouter | 200000 | 100000 | In: $1.50, Out: $6.00, Cache: $0.38 |
| OpenAI: GPT-3.5 Turbo | openai/gpt-3.5-turbo | openrouter | 16385 | 4096 | In: $0.50, Out: $1.50 |
| OpenAI: GPT-3.5 Turbo (older v0613) | openai/gpt-3.5-turbo-0613 | openrouter | 4095 | 4096 | In: $1.00, Out: $2.00 |
| OpenAI: GPT-3.5 Turbo 16k | openai/gpt-3.5-turbo-16k | openrouter | 16385 | 4096 | In: $3.00, Out: $4.00 |
| OpenAI: GPT-3.5 Turbo Instruct | openai/gpt-3.5-turbo-instruct | openrouter | 4095 | 4096 | In: $1.50, Out: $2.00 |
| OpenAI: GPT-4 | openai/gpt-4 | openrouter | 8191 | 4096 | In: $30.00, Out: $60.00 |
| OpenAI: GPT-4 (older v0314) | openai/gpt-4-0314 | openrouter | 8191 | 4096 | In: $30.00, Out: $60.00 |
| OpenAI: GPT-4 Turbo | openai/gpt-4-turbo | openrouter | 128000 | 4096 | In: $10.00, Out: $30.00 |
| OpenAI: GPT-4 Turbo (older v1106) | openai/gpt-4-1106-preview | openrouter | 128000 | 4096 | In: $10.00, Out: $30.00 |
| OpenAI: GPT-4 Turbo Preview | openai/gpt-4-turbo-preview | openrouter | 128000 | 4096 | In: $10.00, Out: $30.00 |
| OpenAI: GPT-4.1 | openai/gpt-4.1 | openrouter | 1047576 | 32768 | In: $2.00, Out: $8.00, Cache: $0.50 |
| OpenAI: GPT-4.1 Mini | openai/gpt-4.1-mini | openrouter | 1047576 | 32768 | In: $0.40, Out: $1.60, Cache: $0.10 |
| OpenAI: GPT-4.1 Nano | openai/gpt-4.1-nano | openrouter | 1047576 | 32768 | In: $0.10, Out: $0.40, Cache: $0.02 |
| OpenAI: GPT-4o | openai/gpt-4o | openrouter | 128000 | 16384 | In: $2.50, Out: $10.00, Cache: $1.25 |
| OpenAI: GPT-4o (2024-05-13) | openai/gpt-4o-2024-05-13 | openrouter | 128000 | 4096 | In: $5.00, Out: $15.00 |
| OpenAI: GPT-4o (2024-08-06) | openai/gpt-4o-2024-08-06 | openrouter | 128000 | 16384 | In: $2.50, Out: $10.00, Cache: $1.25 |
| OpenAI: GPT-4o (2024-11-20) | openai/gpt-4o-2024-11-20 | openrouter | 128000 | 16384 | In: $2.50, Out: $10.00, Cache: $1.25 |
| OpenAI: GPT-4o (extended) | openai/gpt-4o:extended | openrouter | 128000 | 64000 | In: $6.00, Out: $18.00 |
| OpenAI: GPT-4o Search Preview | openai/gpt-4o-search-preview | openrouter | 128000 | 16384 | In: $2.50, Out: $10.00 |
| OpenAI: GPT-4o-mini | openai/gpt-4o-mini | openrouter | 128000 | 16384 | In: $0.15, Out: $0.60, Cache: $0.08 |
| OpenAI: GPT-4o-mini (2024-07-18) | openai/gpt-4o-mini-2024-07-18 | openrouter | 128000 | 16384 | In: $0.15, Out: $0.60, Cache: $0.08 |
| OpenAI: GPT-4o-mini Search Preview | openai/gpt-4o-mini-search-preview | openrouter | 128000 | 16384 | In: $0.15, Out: $0.60 |
| OpenAI: o1 | openai/o1 | openrouter | 200000 | 100000 | In: $15.00, Out: $60.00, Cache: $7.50 |
| OpenAI: o1-mini | openai/o1-mini | openrouter | 128000 | 65536 | In: $1.10, Out: $4.40, Cache: $0.55 |
| OpenAI: o1-mini (2024-09-12) | openai/o1-mini-2024-09-12 | openrouter | 128000 | 65536 | In: $1.10, Out: $4.40, Cache: $0.55 |
| OpenAI: o1-preview | openai/o1-preview | openrouter | 128000 | 32768 | In: $15.00, Out: $60.00, Cache: $7.50 |
| OpenAI: o1-preview (2024-09-12) | openai/o1-preview-2024-09-12 | openrouter | 128000 | 32768 | In: $15.00, Out: $60.00, Cache: $7.50 |
| OpenAI: o1-pro | openai/o1-pro | openrouter | 200000 | 100000 | In: $150.00, Out: $600.00 |
| OpenAI: o3 | openai/o3 | openrouter | 200000 | 100000 | In: $2.00, Out: $8.00, Cache: $0.50 |
| OpenAI: o3 Mini | openai/o3-mini | openrouter | 200000 | 100000 | In: $1.10, Out: $4.40, Cache: $0.55 |
| OpenAI: o3 Mini High | openai/o3-mini-high | openrouter | 200000 | 100000 | In: $1.10, Out: $4.40, Cache: $0.55 |
| OpenAI: o3 Pro | openai/o3-pro | openrouter | 200000 | 100000 | In: $20.00, Out: $80.00 |
| OpenAI: o4 Mini | openai/o4-mini | openrouter | 200000 | 100000 | In: $1.10, Out: $4.40, Cache: $0.28 |
| OpenAI: o4 Mini High | openai/o4-mini-high | openrouter | 200000 | 100000 | In: $1.10, Out: $4.40, Cache: $0.28 |
| OpenGVLab: InternVL3 14B | opengvlab/internvl3-14b | openrouter | 12288 | - | In: $0.20, Out: $0.40 |
| Perplexity: R1 1776 | perplexity/r1-1776 | openrouter | 128000 | - | In: $2.00, Out: $8.00 |
| Perplexity: Sonar | perplexity/sonar | openrouter | 127072 | - | In: $1.00, Out: $1.00 |
| Perplexity: Sonar Deep Research | perplexity/sonar-deep-research | openrouter | 128000 | - | In: $2.00, Out: $8.00 |
| Perplexity: Sonar Pro | perplexity/sonar-pro | openrouter | 200000 | 8000 | In: $3.00, Out: $15.00 |
| Perplexity: Sonar Reasoning | perplexity/sonar-reasoning | openrouter | 127000 | - | In: $1.00, Out: $5.00 |
| Perplexity: Sonar Reasoning Pro | perplexity/sonar-reasoning-pro | openrouter | 128000 | - | In: $2.00, Out: $8.00 |
| Pygmalion: Mythalion 13B | pygmalionai/mythalion-13b | openrouter | 4096 | 4096 | In: $0.80, Out: $1.20 |
| Qwen 2 72B Instruct | qwen/qwen-2-72b-instruct | openrouter | 32768 | 4096 | In: $0.90, Out: $0.90 |
| Qwen2.5 72B Instruct | qwen/qwen-2.5-72b-instruct | openrouter | 32768 | 16384 | In: $0.12, Out: $0.39 |
| Qwen2.5 72B Instruct (free) | qwen/qwen-2.5-72b-instruct:free | openrouter | 32768 | - | - |
| Qwen2.5 7B Instruct | qwen/qwen-2.5-7b-instruct | openrouter | 32768 | 16384 | In: $0.04, Out: $0.10 |
| Qwen2.5 Coder 32B Instruct | qwen/qwen-2.5-coder-32b-instruct | openrouter | 32768 | 16384 | In: $0.06, Out: $0.15 |
| Qwen2.5 Coder 32B Instruct (free) | qwen/qwen-2.5-coder-32b-instruct:free | openrouter | 32768 | - | - |
| Qwen: QwQ 32B | qwen/qwq-32b | openrouter | 131072 | - | In: $0.08, Out: $0.15 |
| Qwen: QwQ 32B (free) | qwen/qwq-32b:free | openrouter | 32768 | - | - |
| Qwen: QwQ 32B Preview | qwen/qwq-32b-preview | openrouter | 32768 | - | In: $0.20, Out: $0.20 |
| Qwen: Qwen VL Max | qwen/qwen-vl-max | openrouter | 7500 | 1500 | In: $0.80, Out: $3.20 |
| Qwen: Qwen VL Plus | qwen/qwen-vl-plus | openrouter | 7500 | 1500 | In: $0.21, Out: $0.63 |
| Qwen: Qwen-Max  | qwen/qwen-max | openrouter | 32768 | 8192 | In: $1.60, Out: $6.40, Cache: $0.64 |
| Qwen: Qwen-Plus | qwen/qwen-plus | openrouter | 131072 | 8192 | In: $0.40, Out: $1.20, Cache: $0.16 |
| Qwen: Qwen-Turbo | qwen/qwen-turbo | openrouter | 1000000 | 8192 | In: $0.05, Out: $0.20, Cache: $0.02 |
| Qwen: Qwen2.5 VL 32B Instruct | qwen/qwen2.5-vl-32b-instruct | openrouter | 128000 | - | In: $0.20, Out: $0.60 |
| Qwen: Qwen2.5 VL 32B Instruct (free) | qwen/qwen2.5-vl-32b-instruct:free | openrouter | 8192 | - | - |
| Qwen: Qwen2.5 VL 72B Instruct | qwen/qwen2.5-vl-72b-instruct | openrouter | 32000 | - | In: $0.25, Out: $0.75 |
| Qwen: Qwen2.5 VL 72B Instruct (free) | qwen/qwen2.5-vl-72b-instruct:free | openrouter | 32768 | - | - |
| Qwen: Qwen2.5-VL 7B Instruct | qwen/qwen-2.5-vl-7b-instruct | openrouter | 32768 | - | In: $0.20, Out: $0.20 |
| Qwen: Qwen3 14B | qwen/qwen3-14b | openrouter | 40960 | 40960 | In: $0.06, Out: $0.24 |
| Qwen: Qwen3 14B (free) | qwen/qwen3-14b:free | openrouter | 40960 | - | - |
| Qwen: Qwen3 235B A22B | qwen/qwen3-235b-a22b | openrouter | 40960 | 40960 | In: $0.13, Out: $0.60 |
| Qwen: Qwen3 235B A22B (free) | qwen/qwen3-235b-a22b:free | openrouter | 131072 | - | - |
| Qwen: Qwen3 30B A3B | qwen/qwen3-30b-a3b | openrouter | 40960 | 40960 | In: $0.08, Out: $0.29 |
| Qwen: Qwen3 30B A3B (free) | qwen/qwen3-30b-a3b:free | openrouter | 40960 | - | - |
| Qwen: Qwen3 32B | qwen/qwen3-32b | openrouter | 40960 | - | In: $0.10, Out: $0.30 |
| Qwen: Qwen3 32B (free) | qwen/qwen3-32b:free | openrouter | 40960 | - | - |
| Qwen: Qwen3 4B (free) | qwen/qwen3-4b:free | openrouter | 40960 | - | - |
| Qwen: Qwen3 8B | qwen/qwen3-8b | openrouter | 128000 | 20000 | In: $0.04, Out: $0.14 |
| Qwen: Qwen3 8B (free) | qwen/qwen3-8b:free | openrouter | 40960 | 40960 | - |
| Qwerky 72B (free) | featherless/qwerky-72b:free | openrouter | 32768 | 4096 | - |
| ReMM SLERP 13B | undi95/remm-slerp-l2-13b | openrouter | 6144 | - | In: $0.70, Out: $1.00 |
| Reka: Flash 3 | rekaai/reka-flash-3 | openrouter | 32768 | - | In: $0.01, Out: $0.01 |
| Reka: Flash 3 (free) | rekaai/reka-flash-3:free | openrouter | 32768 | - | - |
| Sao10K: Llama 3 8B Lunaris | sao10k/l3-lunaris-8b | openrouter | 8192 | - | In: $0.02, Out: $0.05 |
| Sao10K: Llama 3.1 Euryale 70B v2.2 | sao10k/l3.1-euryale-70b | openrouter | 32768 | - | In: $0.65, Out: $0.75 |
| Sao10K: Llama 3.3 Euryale 70B | sao10k/l3.3-euryale-70b | openrouter | 131072 | - | In: $0.65, Out: $0.75 |
| Sao10k: Llama 3 Euryale 70B v2.1 | sao10k/l3-euryale-70b | openrouter | 8192 | 8192 | In: $1.48, Out: $1.48 |
| Sarvam AI: Sarvam-M | sarvamai/sarvam-m | openrouter | 32768 | - | In: $0.02, Out: $0.02 |
| Sarvam AI: Sarvam-M (free) | sarvamai/sarvam-m:free | openrouter | 32768 | - | - |
| Shisa AI: Shisa V2 Llama 3.3 70B  (free) | shisa-ai/shisa-v2-llama3.3-70b:free | openrouter | 32768 | - | - |
| SorcererLM 8x22B | raifle/sorcererlm-8x22b | openrouter | 16000 | - | In: $4.50, Out: $4.50 |
| Switchpoint Router | switchpoint/router | openrouter | 131072 | - | In: $0.85, Out: $3.40 |
| THUDM: GLM 4 32B | thudm/glm-4-32b | openrouter | 32000 | 32000 | In: $0.24, Out: $0.24 |
| THUDM: GLM 4 32B (free) | thudm/glm-4-32b:free | openrouter | 32768 | - | - |
| THUDM: GLM 4.1V 9B Thinking | thudm/glm-4.1v-9b-thinking | openrouter | 65536 | 8000 | In: $0.04, Out: $0.14 |
| THUDM: GLM Z1 32B (free) | thudm/glm-z1-32b:free | openrouter | 32768 | - | - |
| TNG: DeepSeek R1T Chimera (free) | tngtech/deepseek-r1t-chimera:free | openrouter | 163840 | - | - |
| TNG: DeepSeek R1T2 Chimera (free) | tngtech/deepseek-r1t2-chimera:free | openrouter | 163840 | - | - |
| Tencent: Hunyuan A13B Instruct | tencent/hunyuan-a13b-instruct | openrouter | 32768 | - | In: $0.03, Out: $0.03 |
| Tencent: Hunyuan A13B Instruct (free) | tencent/hunyuan-a13b-instruct:free | openrouter | 32768 | - | - |
| TheDrummer: Anubis 70B V1.1 | thedrummer/anubis-70b-v1.1 | openrouter | 131072 | 131072 | In: $0.50, Out: $0.80 |
| TheDrummer: Anubis Pro 105B V1 | thedrummer/anubis-pro-105b-v1 | openrouter | 131072 | 131072 | In: $0.50, Out: $1.00 |
| TheDrummer: Rocinante 12B | thedrummer/rocinante-12b | openrouter | 32768 | - | In: $0.20, Out: $0.50 |
| TheDrummer: Skyfall 36B V2 | thedrummer/skyfall-36b-v2 | openrouter | 32768 | - | In: $0.40, Out: $0.70 |
| TheDrummer: UnslopNemo 12B | thedrummer/unslopnemo-12b | openrouter | 32768 | - | In: $0.40, Out: $0.40 |
| TheDrummer: Valkyrie 49B V1 | thedrummer/valkyrie-49b-v1 | openrouter | 32768 | - | In: $0.60, Out: $0.80 |
| Toppy M 7B | undi95/toppy-m-7b | openrouter | 4096 | 4096 | In: $0.80, Out: $1.20 |
| Typhoon2 70B Instruct | scb10x/llama3.1-typhoon2-70b-instruct | openrouter | 8192 | - | In: $0.88, Out: $0.88 |
| Venice: Uncensored (free) | cognitivecomputations/dolphin-mistral-24b-venice-edition:free | openrouter | 32768 | - | - |
| WizardLM-2 8x22B | microsoft/wizardlm-2-8x22b | openrouter | 65536 | 65536 | In: $0.48, Out: $0.48 |
| xAI: Grok 2 1212 | x-ai/grok-2-1212 | openrouter | 131072 | - | In: $2.00, Out: $10.00 |
| xAI: Grok 2 Vision 1212 | x-ai/grok-2-vision-1212 | openrouter | 32768 | - | In: $2.00, Out: $10.00 |
| xAI: Grok 3 | x-ai/grok-3 | openrouter | 131072 | - | In: $3.00, Out: $15.00, Cache: $0.75 |
| xAI: Grok 3 Beta | x-ai/grok-3-beta | openrouter | 131072 | - | In: $3.00, Out: $15.00, Cache: $0.75 |
| xAI: Grok 3 Mini | x-ai/grok-3-mini | openrouter | 131072 | - | In: $0.30, Out: $0.50, Cache: $0.08 |
| xAI: Grok 3 Mini Beta | x-ai/grok-3-mini-beta | openrouter | 131072 | - | In: $0.30, Out: $0.50, Cache: $0.08 |
| xAI: Grok 4 | x-ai/grok-4 | openrouter | 256000 | - | In: $3.00, Out: $15.00, Cache: $0.75 |
| xAI: Grok Vision Beta | x-ai/grok-vision-beta | openrouter | 8192 | - | In: $5.00, Out: $15.00 |


## Models by Capability

### Function Calling (261)

| Model | ID | Provider | Context | Max Output | Standard Pricing (per 1M tokens) |
| :-- | :-- | :-- | --: | --: | :-- |
| Claude Haiku 3 | claude-3-haiku-20240307 | anthropic | 200000 | 4096 | In: $0.25, Out: $1.25, Cache: $0.30 |
| Claude Haiku 3.5 | claude-3-5-haiku-20241022 | anthropic | 200000 | 8192 | In: $0.80, Out: $4.00, Cache: $1.00 |
| Claude Opus 3 | claude-3-opus-20240229 | anthropic | 200000 | 4096 | In: $15.00, Out: $75.00, Cache: $18.75 |
| Claude Opus 4 | claude-opus-4-20250514 | anthropic | 200000 | 32000 | In: $15.00, Out: $75.00, Cache: $18.75 |
| Claude Sonnet 3 | claude-3-sonnet-20240229 | anthropic | 200000 | 4096 | In: $3.00, Out: $15.00 |
| Claude Sonnet 3.5 | claude-3-5-sonnet-20240620 | anthropic | 200000 | 8192 | In: $3.00, Out: $15.00, Cache: $3.75 |
| Claude Sonnet 3.5 | claude-3-5-sonnet-20241022 | anthropic | 200000 | 8192 | In: $3.00, Out: $15.00, Cache: $3.75 |
| Claude Sonnet 3.7 | claude-3-7-sonnet-20250219 | anthropic | 200000 | 64000 | In: $3.00, Out: $15.00, Cache: $3.75 |
| Claude Sonnet 4 | claude-sonnet-4-20250514 | anthropic | 200000 | 64000 | In: $3.00, Out: $15.00, Cache: $3.75 |
| Claude | anthropic.claude-v2 | bedrock | 200000 | 4096 | In: $8.00, Out: $24.00 |
| Claude | anthropic.claude-v2:0:100k | bedrock | 200000 | 4096 | In: $8.00, Out: $24.00 |
| Claude | anthropic.claude-v2:0:18k | bedrock | 200000 | 4096 | In: $8.00, Out: $24.00 |
| Claude | anthropic.claude-v2:1 | bedrock | 200000 | 4096 | In: $8.00, Out: $24.00 |
| Claude | anthropic.claude-v2:1:18k | bedrock | 200000 | 4096 | In: $8.00, Out: $24.00 |
| Claude | anthropic.claude-v2:1:200k | bedrock | 200000 | 4096 | In: $8.00, Out: $24.00 |
| Claude 3 Haiku | anthropic.claude-3-haiku-20240307-v1:0 | bedrock | 200000 | 4096 | In: $0.25, Out: $1.25 |
| Claude 3 Haiku | anthropic.claude-3-haiku-20240307-v1:0:200k | bedrock | 200000 | 4096 | In: $0.25, Out: $1.25 |
| Claude 3 Haiku | anthropic.claude-3-haiku-20240307-v1:0:48k | bedrock | 200000 | 4096 | In: $0.25, Out: $1.25 |
| Claude 3 Opus | anthropic.claude-3-opus-20240229-v1:0 | bedrock | 200000 | 4096 | In: $15.00, Out: $75.00 |
| Claude 3 Opus | anthropic.claude-3-opus-20240229-v1:0:12k | bedrock | 200000 | 4096 | In: $15.00, Out: $75.00 |
| Claude 3 Opus | anthropic.claude-3-opus-20240229-v1:0:200k | bedrock | 200000 | 4096 | In: $15.00, Out: $75.00 |
| Claude 3 Opus | anthropic.claude-3-opus-20240229-v1:0:28k | bedrock | 200000 | 4096 | In: $15.00, Out: $75.00 |
| Claude 3 Sonnet | anthropic.claude-3-sonnet-20240229-v1:0 | bedrock | 200000 | 4096 | In: $3.00, Out: $15.00 |
| Claude 3 Sonnet | anthropic.claude-3-sonnet-20240229-v1:0:200k | bedrock | 200000 | 4096 | In: $3.00, Out: $15.00 |
| Claude 3 Sonnet | anthropic.claude-3-sonnet-20240229-v1:0:28k | bedrock | 200000 | 4096 | In: $3.00, Out: $15.00 |
| Claude 3.5 Haiku | anthropic.claude-3-5-haiku-20241022-v1:0 | bedrock | 200000 | 4096 | In: $0.80, Out: $4.00 |
| Claude 3.5 Sonnet | anthropic.claude-3-5-sonnet-20240620-v1:0 | bedrock | 200000 | 4096 | In: $3.00, Out: $15.00 |
| Claude 3.5 Sonnet | anthropic.claude-3-5-sonnet-20240620-v1:0:18k | bedrock | 200000 | 4096 | In: $3.00, Out: $15.00 |
| Claude 3.5 Sonnet | anthropic.claude-3-5-sonnet-20240620-v1:0:200k | bedrock | 200000 | 4096 | In: $3.00, Out: $15.00 |
| Claude 3.5 Sonnet | anthropic.claude-3-5-sonnet-20240620-v1:0:51k | bedrock | 200000 | 4096 | In: $3.00, Out: $15.00 |
| Claude 3.5 Sonnet v2 | anthropic.claude-3-5-sonnet-20241022-v2:0 | bedrock | 200000 | 4096 | In: $3.00, Out: $15.00 |
| Claude 3.5 Sonnet v2 | anthropic.claude-3-5-sonnet-20241022-v2:0:18k | bedrock | 200000 | 4096 | In: $3.00, Out: $15.00 |
| Claude 3.5 Sonnet v2 | anthropic.claude-3-5-sonnet-20241022-v2:0:200k | bedrock | 200000 | 4096 | In: $3.00, Out: $15.00 |
| Claude 3.5 Sonnet v2 | anthropic.claude-3-5-sonnet-20241022-v2:0:51k | bedrock | 200000 | 4096 | In: $3.00, Out: $15.00 |
| Claude 3.7 Sonnet | us.anthropic.claude-3-7-sonnet-20250219-v1:0 | bedrock | 200000 | 4096 | In: $3.00, Out: $15.00 |
| Claude Instant | anthropic.claude-instant-v1 | bedrock | 200000 | 4096 | In: $0.80, Out: $2.40 |
| Claude Instant | anthropic.claude-instant-v1:2:100k | bedrock | 200000 | 4096 | In: $0.80, Out: $2.40 |
| Claude Opus 4 | us.anthropic.claude-opus-4-20250514-v1:0 | bedrock | 200000 | 4096 | In: $0.10, Out: $0.20 |
| Claude Sonnet 4 | us.anthropic.claude-sonnet-4-20250514-v1:0 | bedrock | 200000 | 4096 | In: $0.10, Out: $0.20 |
| deepseek-chat | deepseek-chat | deepseek | 64000 | 8000 | In: $0.27, Out: $1.10, Cache: $0.07 |
| deepseek-reasoner | deepseek-reasoner | deepseek | 64000 | 64000 | In: $0.55, Out: $2.19, Cache: $0.14 |
| Gemini 1.0 Pro Vision | gemini-1.0-pro-vision-latest | gemini | 12288 | 4096 | In: $0.08, Out: $0.30 |
| Gemini 1.0 Pro Vision | gemini-pro-vision | gemini | 12288 | 4096 | In: $0.08, Out: $0.30 |
| Gemini 1.5 Flash | gemini-1.5-flash | gemini | 1048576 | 8192 | In: $0.08, Out: $0.30, Cache: $0.02 |
| Gemini 1.5 Flash | gemini-1.5-flash-001 | gemini | 1048576 | 8192 | In: $0.08, Out: $0.30, Cache: $0.02 |
| Gemini 1.5 Flash | gemini-1.5-flash-002 | gemini | 1048576 | 8192 | In: $0.08, Out: $0.30, Cache: $0.02 |
| Gemini 1.5 Flash | gemini-1.5-flash-latest | gemini | 1048576 | 8192 | In: $0.08, Out: $0.30, Cache: $0.02 |
| Gemini 1.5 Flash-8B | gemini-1.5-flash-8b | gemini | 1048576 | 8192 | In: $0.08, Out: $0.30, Cache: $0.02 |
| Gemini 1.5 Flash-8B | gemini-1.5-flash-8b-001 | gemini | 1048576 | 8192 | In: $0.08, Out: $0.30, Cache: $0.02 |
| Gemini 1.5 Flash-8B | gemini-1.5-flash-8b-latest | gemini | 1048576 | 8192 | In: $0.08, Out: $0.30, Cache: $0.02 |
| Gemini 1.5 Pro | gemini-1.5-pro | gemini | 2097152 | 8192 | In: $1.25, Out: $5.00, Cache: $0.31 |
| Gemini 1.5 Pro | gemini-1.5-pro-001 | gemini | 2097152 | 8192 | In: $1.25, Out: $5.00, Cache: $0.31 |
| Gemini 1.5 Pro | gemini-1.5-pro-002 | gemini | 2097152 | 8192 | In: $1.25, Out: $5.00, Cache: $0.31 |
| Gemini 1.5 Pro | gemini-1.5-pro-latest | gemini | 2097152 | 8192 | In: $1.25, Out: $5.00, Cache: $0.31 |
| Gemini 2.0 Flash | gemini-2.0-flash | gemini | 1048576 | 8192 | In: $0.10, Out: $0.40, Cache: $0.02 |
| Gemini 2.0 Flash | gemini-2.0-flash-001 | gemini | 1048576 | 8192 | In: $0.10, Out: $0.40, Cache: $0.02 |
| Gemini 2.0 Flash | gemini-2.0-flash-exp | gemini | 1048576 | 8192 | In: $0.10, Out: $0.40, Cache: $0.02 |
| Gemini 2.0 Flash Live | gemini-2.0-flash-live-001 | gemini | 1048576 | 8192 | In: $0.10, Out: $0.40, Cache: $0.02 |
| Gemini 2.0 Flash-Lite | gemini-2.0-flash-lite | gemini | 1048576 | 8192 | In: $0.10, Out: $0.40, Cache: $0.02 |
| Gemini 2.0 Flash-Lite | gemini-2.0-flash-lite-001 | gemini | 1048576 | 8192 | In: $0.10, Out: $0.40, Cache: $0.02 |
| Gemini 2.0 Pro Experimental | gemini-2.0-pro-exp | gemini | 1048576 | 65536 | In: $0.08, Out: $0.30 |
| Gemini 2.0 Pro Experimental 02-05 | gemini-2.0-pro-exp-02-05 | gemini | 1048576 | 65536 | In: $0.08, Out: $0.30 |
| Gemini 2.5 Flash | gemini-2.5-flash | gemini | 1048576 | 65536 | In: $0.30, Out: $2.50, Cache: $0.08 |
| Gemini 2.5 Flash | gemini-2.5-flash-preview-05-20 | gemini | 1048576 | 65536 | In: $0.30, Out: $2.50, Cache: $0.08 |
| Gemini 2.5 Flash Live | gemini-live-2.5-flash-preview | gemini | 1048576 | 8192 | In: $0.30, Out: $2.50, Cache: $0.08 |
| Gemini 2.5 Flash Native Audio | gemini-2.5-flash-exp-native-audio-thinking-dialog | gemini | 128000 | 8000 | In: $0.30, Out: $2.50, Cache: $0.08 |
| Gemini 2.5 Flash Native Audio | gemini-2.5-flash-preview-native-audio-dialog | gemini | 128000 | 8000 | In: $0.30, Out: $2.50, Cache: $0.08 |
| Gemini 2.5 Flash Preview 05-20 | gemini-2.0-flash-thinking-exp | gemini | 1048576 | 65536 | In: $0.10, Out: $0.40 |
| Gemini 2.5 Flash Preview 05-20 | gemini-2.0-flash-thinking-exp-01-21 | gemini | 1048576 | 65536 | In: $0.10, Out: $0.40 |
| Gemini 2.5 Flash Preview 05-20 | gemini-2.0-flash-thinking-exp-1219 | gemini | 1048576 | 65536 | In: $0.10, Out: $0.40 |
| Gemini 2.5 Flash-Lite Preview | gemini-2.5-flash-lite-preview-06-17 | gemini | 1000000 | 64000 | In: $0.30, Out: $2.50, Cache: $0.08 |
| Gemini 2.5 Pro | gemini-2.5-pro | gemini | 1048576 | 65536 | In: $1.25, Out: $10.00, Cache: $0.31 |
| Gemini 2.5 Pro | gemini-2.5-pro-preview-03-25 | gemini | 1048576 | 65536 | In: $1.25, Out: $10.00, Cache: $0.31 |
| Gemini 2.5 Pro | gemini-2.5-pro-preview-05-06 | gemini | 1048576 | 65536 | In: $1.25, Out: $10.00, Cache: $0.31 |
| Gemini 2.5 Pro | gemini-2.5-pro-preview-06-05 | gemini | 1048576 | 65536 | In: $1.25, Out: $10.00, Cache: $0.31 |
| Gemini Embedding Experimental | gemini-embedding-exp | gemini | 8192 | 1 | In: $0.00, Out: $0.00 |
| Gemini Experimental 1206 | gemini-exp-1206 | gemini | 1048576 | 65536 | In: $0.08, Out: $0.30 |
| LearnLM 2.0 Flash Experimental | learnlm-2.0-flash-experimental | gemini | 1048576 | 32768 | In: $0.08, Out: $0.30 |
| GPT-4 Turbo | gpt-4-turbo | openai | 128000 | 4096 | In: $10.00, Out: $30.00 |
| GPT-4 Turbo | gpt-4-turbo-2024-04-09 | openai | 128000 | 4096 | In: $10.00, Out: $30.00 |
| GPT-4 Turbo Preview | gpt-4-turbo-preview | openai | 128000 | 4096 | In: $10.00, Out: $30.00 |
| GPT-4.1 | gpt-4.1 | openai | 1047576 | 32768 | In: $2.00, Out: $8.00, Cache: $0.50 |
| GPT-4.1 | gpt-4.1-2025-04-14 | openai | 1047576 | 32768 | In: $2.00, Out: $8.00, Cache: $0.50 |
| GPT-4.1 mini | gpt-4.1-mini | openai | 1047576 | 32768 | In: $0.40, Out: $1.60, Cache: $0.10 |
| GPT-4.1 mini | gpt-4.1-mini-2025-04-14 | openai | 1047576 | 32768 | In: $0.40, Out: $1.60, Cache: $0.10 |
| GPT-4.1 nano | gpt-4.1-nano | openai | 1047576 | 32768 | In: $0.10, Out: $0.40, Cache: $0.02 |
| GPT-4.1 nano | gpt-4.1-nano-2025-04-14 | openai | 1047576 | 32768 | In: $0.10, Out: $0.40, Cache: $0.02 |
| GPT-4o | gpt-4o | openai | 128000 | 16384 | In: $2.50, Out: $10.00, Cache: $1.25 |
| GPT-4o | gpt-4o-2024-08-06 | openai | 128000 | 16384 | In: $2.50, Out: $10.00, Cache: $1.25 |
| GPT-4o 20240513 | gpt-4o-2024-05-13 | openai | 128000 | 16384 | In: $2.50, Out: $10.00 |
| GPT-4o 20241120 | gpt-4o-2024-11-20 | openai | 128000 | 16384 | In: $2.50, Out: $10.00 |
| GPT-4o Audio | gpt-4o-audio-preview | openai | 128000 | 16384 | In: $2.50, Out: $10.00 |
| GPT-4o Realtime | gpt-4o-realtime-preview | openai | 32000 | 4096 | In: $5.00, Out: $20.00, Cache: $2.50 |
| GPT-4o mini | gpt-4o-mini | openai | 128000 | 16384 | In: $0.15, Out: $0.60, Cache: $0.08 |
| GPT-4o mini | gpt-4o-mini-2024-07-18 | openai | 128000 | 16384 | In: $0.15, Out: $0.60, Cache: $0.08 |
| GPT-4o mini Audio | gpt-4o-mini-audio-preview | openai | 128000 | 16384 | In: $0.15, Out: $0.60 |
| GPT-4o mini Audio | gpt-4o-mini-audio-preview-2024-12-17 | openai | 128000 | 16384 | In: $0.15, Out: $0.60 |
| GPT-4o mini Realtime | gpt-4o-mini-realtime-preview | openai | 128000 | 4096 | In: $0.60, Out: $2.40, Cache: $0.30 |
| GPT-4o mini Realtime | gpt-4o-mini-realtime-preview-2024-12-17 | openai | 128000 | 4096 | In: $0.60, Out: $2.40, Cache: $0.30 |
| O1-Preview | o1-preview | openai | 200000 | 100000 | In: $15.00, Out: $60.00 |
| O1-Preview 20240912 | o1-preview-2024-09-12 | openai | 200000 | 100000 | In: $15.00, Out: $60.00 |
| codex-mini-latest | codex-mini-latest | openai | 200000 | 100000 | In: $1.50, Out: $6.00, Cache: $0.38 |
| computer-use-preview | computer-use-preview | openai | 8192 | 1024 | In: $3.00, Out: $12.00 |
| computer-use-preview | computer-use-preview-2025-03-11 | openai | 8192 | 1024 | In: $3.00, Out: $12.00 |
| o1 | o1 | openai | 200000 | 100000 | In: $15.00, Out: $60.00, Cache: $7.50 |
| o1 | o1-2024-12-17 | openai | 200000 | 100000 | In: $15.00, Out: $60.00, Cache: $7.50 |
| o1-pro | o1-pro | openai | 200000 | 100000 | In: $150.00, Out: $600.00 |
| o1-pro | o1-pro-2025-03-19 | openai | 200000 | 100000 | In: $150.00, Out: $600.00 |
| o3 | o3 | openai | 200000 | 100000 | In: $2.00, Out: $8.00, Cache: $0.50 |
| o3 | o3-2025-04-16 | openai | 200000 | 100000 | In: $2.00, Out: $8.00, Cache: $0.50 |
| o3-mini | o3-mini | openai | 200000 | 100000 | In: $1.10, Out: $4.40, Cache: $0.55 |
| o3-mini | o3-mini-2025-01-31 | openai | 200000 | 100000 | In: $1.10, Out: $4.40, Cache: $0.55 |
| o3-pro | o3-pro | openai | 200000 | 100000 | In: $20.00, Out: $80.00 |
| o3-pro | o3-pro-2025-06-10 | openai | 200000 | 100000 | In: $20.00, Out: $80.00 |
| o4-mini | o4-mini | openai | 200000 | 100000 | In: $1.10, Out: $4.40, Cache: $0.28 |
| o4-mini | o4-mini-2025-04-16 | openai | 200000 | 100000 | In: $1.10, Out: $4.40, Cache: $0.28 |
| AI21: Jamba 1.6 Large | ai21/jamba-1.6-large | openrouter | 256000 | 4096 | In: $2.00, Out: $8.00 |
| AI21: Jamba Mini 1.6 | ai21/jamba-1.6-mini | openrouter | 256000 | 4096 | In: $0.20, Out: $0.40 |
| Amazon: Nova Lite 1.0 | amazon/nova-lite-v1 | openrouter | 300000 | 5120 | In: $0.06, Out: $0.24 |
| Amazon: Nova Micro 1.0 | amazon/nova-micro-v1 | openrouter | 128000 | 5120 | In: $0.04, Out: $0.14 |
| Amazon: Nova Pro 1.0 | amazon/nova-pro-v1 | openrouter | 300000 | 5120 | In: $0.80, Out: $3.20 |
| Anthropic: Claude 3 Haiku | anthropic/claude-3-haiku | openrouter | 200000 | 4096 | In: $0.25, Out: $1.25, Cache: $0.03 |
| Anthropic: Claude 3 Haiku (self-moderated) | anthropic/claude-3-haiku:beta | openrouter | 200000 | 4096 | In: $0.25, Out: $1.25, Cache: $0.03 |
| Anthropic: Claude 3 Opus | anthropic/claude-3-opus | openrouter | 200000 | 4096 | In: $15.00, Out: $75.00, Cache: $1.50 |
| Anthropic: Claude 3 Opus (self-moderated) | anthropic/claude-3-opus:beta | openrouter | 200000 | 4096 | In: $15.00, Out: $75.00, Cache: $1.50 |
| Anthropic: Claude 3 Sonnet | anthropic/claude-3-sonnet | openrouter | 200000 | 4096 | In: $3.00, Out: $15.00, Cache: $0.30 |
| Anthropic: Claude 3 Sonnet (self-moderated) | anthropic/claude-3-sonnet:beta | openrouter | 200000 | 4096 | In: $3.00, Out: $15.00, Cache: $0.30 |
| Anthropic: Claude 3.5 Haiku | anthropic/claude-3.5-haiku | openrouter | 200000 | 8192 | In: $0.80, Out: $4.00, Cache: $0.08 |
| Anthropic: Claude 3.5 Haiku (2024-10-22) | anthropic/claude-3.5-haiku-20241022 | openrouter | 200000 | 8192 | In: $0.80, Out: $4.00, Cache: $0.08 |
| Anthropic: Claude 3.5 Haiku (2024-10-22) (self-moderated) | anthropic/claude-3.5-haiku-20241022:beta | openrouter | 200000 | 8192 | In: $0.80, Out: $4.00, Cache: $0.08 |
| Anthropic: Claude 3.5 Haiku (self-moderated) | anthropic/claude-3.5-haiku:beta | openrouter | 200000 | 8192 | In: $0.80, Out: $4.00, Cache: $0.08 |
| Anthropic: Claude 3.5 Sonnet | anthropic/claude-3.5-sonnet | openrouter | 200000 | 8192 | In: $3.00, Out: $15.00, Cache: $0.30 |
| Anthropic: Claude 3.5 Sonnet (2024-06-20) | anthropic/claude-3.5-sonnet-20240620 | openrouter | 200000 | 8192 | In: $3.00, Out: $15.00, Cache: $0.30 |
| Anthropic: Claude 3.5 Sonnet (2024-06-20) (self-moderated) | anthropic/claude-3.5-sonnet-20240620:beta | openrouter | 200000 | 8192 | In: $3.00, Out: $15.00, Cache: $0.30 |
| Anthropic: Claude 3.5 Sonnet (self-moderated) | anthropic/claude-3.5-sonnet:beta | openrouter | 200000 | 8192 | In: $3.00, Out: $15.00, Cache: $0.30 |
| Anthropic: Claude 3.7 Sonnet | anthropic/claude-3.7-sonnet | openrouter | 200000 | 64000 | In: $3.00, Out: $15.00, Cache: $0.30 |
| Anthropic: Claude 3.7 Sonnet (self-moderated) | anthropic/claude-3.7-sonnet:beta | openrouter | 200000 | 128000 | In: $3.00, Out: $15.00, Cache: $0.30 |
| Anthropic: Claude 3.7 Sonnet (thinking) | anthropic/claude-3.7-sonnet:thinking | openrouter | 200000 | 64000 | In: $3.00, Out: $15.00, Cache: $0.30 |
| Anthropic: Claude Opus 4 | anthropic/claude-opus-4 | openrouter | 200000 | 32000 | In: $15.00, Out: $75.00, Cache: $1.50 |
| Anthropic: Claude Sonnet 4 | anthropic/claude-sonnet-4 | openrouter | 200000 | 64000 | In: $3.00, Out: $15.00, Cache: $0.30 |
| Arcee AI: Caller Large | arcee-ai/caller-large | openrouter | 32768 | - | In: $0.55, Out: $0.85 |
| Arcee AI: Virtuoso Large | arcee-ai/virtuoso-large | openrouter | 131072 | 64000 | In: $0.75, Out: $1.20 |
| Arcee AI: Virtuoso Medium V2 | arcee-ai/virtuoso-medium-v2 | openrouter | 131072 | 32768 | In: $0.50, Out: $0.80 |
| Cohere: Command R | cohere/command-r | openrouter | 128000 | 4000 | In: $0.50, Out: $1.50 |
| Cohere: Command R (03-2024) | cohere/command-r-03-2024 | openrouter | 128000 | 4000 | In: $0.50, Out: $1.50 |
| Cohere: Command R (08-2024) | cohere/command-r-08-2024 | openrouter | 128000 | 4000 | In: $0.15, Out: $0.60 |
| Cohere: Command R+ | cohere/command-r-plus | openrouter | 128000 | 4000 | In: $3.00, Out: $15.00 |
| Cohere: Command R+ (04-2024) | cohere/command-r-plus-04-2024 | openrouter | 128000 | 4000 | In: $3.00, Out: $15.00 |
| Cohere: Command R+ (08-2024) | cohere/command-r-plus-08-2024 | openrouter | 128000 | 4000 | In: $2.50, Out: $10.00 |
| DeepSeek: DeepSeek V3 | deepseek/deepseek-chat | openrouter | 163840 | 163840 | In: $0.30, Out: $0.85 |
| DeepSeek: DeepSeek V3 0324 | deepseek/deepseek-chat-v3-0324 | openrouter | 163840 | 163840 | In: $0.25, Out: $0.85 |
| DeepSeek: DeepSeek V3 0324 (free) | deepseek/deepseek-chat-v3-0324:free | openrouter | 32768 | 16384 | - |
| DeepSeek: R1 | deepseek/deepseek-r1 | openrouter | 163840 | 163840 | In: $0.40, Out: $2.00 |
| DeepSeek: R1 0528 | deepseek/deepseek-r1-0528 | openrouter | 163840 | - | In: $0.27, Out: $0.27 |
| DeepSeek: R1 Distill Llama 70B | deepseek/deepseek-r1-distill-llama-70b | openrouter | 131072 | - | In: $0.05, Out: $0.05 |
| Google: Gemini 1.5 Flash  | google/gemini-flash-1.5 | openrouter | 1000000 | 8192 | In: $0.08, Out: $0.30, Cache: $0.02 |
| Google: Gemini 1.5 Flash 8B | google/gemini-flash-1.5-8b | openrouter | 1000000 | 8192 | In: $0.04, Out: $0.15, Cache: $0.01 |
| Google: Gemini 1.5 Pro | google/gemini-pro-1.5 | openrouter | 2000000 | 8192 | In: $1.25, Out: $5.00 |
| Google: Gemini 2.0 Flash | google/gemini-2.0-flash-001 | openrouter | 1048576 | 8192 | In: $0.10, Out: $0.40, Cache: $0.02 |
| Google: Gemini 2.0 Flash Experimental (free) | google/gemini-2.0-flash-exp:free | openrouter | 1048576 | 8192 | - |
| Google: Gemini 2.0 Flash Lite | google/gemini-2.0-flash-lite-001 | openrouter | 1048576 | 8192 | In: $0.08, Out: $0.30 |
| Google: Gemini 2.5 Flash | google/gemini-2.5-flash | openrouter | 1048576 | 65535 | In: $0.30, Out: $2.50, Cache: $0.08 |
| Google: Gemini 2.5 Flash Lite Preview 06-17 | google/gemini-2.5-flash-lite-preview-06-17 | openrouter | 1048576 | 65535 | In: $0.10, Out: $0.40, Cache: $0.02 |
| Google: Gemini 2.5 Pro | google/gemini-2.5-pro | openrouter | 1048576 | 65536 | In: $1.25, Out: $10.00, Cache: $0.31 |
| Google: Gemini 2.5 Pro Experimental | google/gemini-2.5-pro-exp-03-25 | openrouter | 1048576 | 65535 | - |
| Google: Gemini 2.5 Pro Preview 05-06 | google/gemini-2.5-pro-preview-05-06 | openrouter | 1048576 | 65535 | In: $1.25, Out: $10.00, Cache: $0.31 |
| Google: Gemini 2.5 Pro Preview 06-05 | google/gemini-2.5-pro-preview | openrouter | 1048576 | 65536 | In: $1.25, Out: $10.00, Cache: $0.31 |
| Meta: Llama 3 70B Instruct | meta-llama/llama-3-70b-instruct | openrouter | 8192 | 16384 | In: $0.30, Out: $0.40 |
| Meta: Llama 3 8B Instruct | meta-llama/llama-3-8b-instruct | openrouter | 8192 | 16384 | In: $0.03, Out: $0.06 |
| Meta: Llama 3.1 405B Instruct | meta-llama/llama-3.1-405b-instruct | openrouter | 32768 | 16384 | In: $0.80, Out: $0.80 |
| Meta: Llama 3.1 70B Instruct | meta-llama/llama-3.1-70b-instruct | openrouter | 131072 | 16384 | In: $0.10, Out: $0.28 |
| Meta: Llama 3.1 8B Instruct | meta-llama/llama-3.1-8b-instruct | openrouter | 131000 | 131000 | In: $0.02, Out: $0.02 |
| Meta: Llama 3.2 11B Vision Instruct | meta-llama/llama-3.2-11b-vision-instruct | openrouter | 131072 | 16384 | In: $0.05, Out: $0.05 |
| Meta: Llama 3.2 3B Instruct | meta-llama/llama-3.2-3b-instruct | openrouter | 20000 | 20000 | In: $0.00, Out: $0.01 |
| Meta: Llama 3.3 70B Instruct | meta-llama/llama-3.3-70b-instruct | openrouter | 131072 | 16384 | In: $0.04, Out: $0.12 |
| Meta: Llama 3.3 70B Instruct (free) | meta-llama/llama-3.3-70b-instruct:free | openrouter | 65536 | - | - |
| Meta: Llama 4 Maverick | meta-llama/llama-4-maverick | openrouter | 1048576 | 16384 | In: $0.15, Out: $0.60 |
| Meta: Llama 4 Scout | meta-llama/llama-4-scout | openrouter | 1048576 | 1048576 | In: $0.08, Out: $0.30 |
| Microsoft: Phi-3 Medium 128K Instruct | microsoft/phi-3-medium-128k-instruct | openrouter | 128000 | - | In: $1.00, Out: $1.00 |
| Microsoft: Phi-3 Mini 128K Instruct | microsoft/phi-3-mini-128k-instruct | openrouter | 128000 | - | In: $0.10, Out: $0.10 |
| Microsoft: Phi-3.5 Mini 128K Instruct | microsoft/phi-3.5-mini-128k-instruct | openrouter | 128000 | - | In: $0.10, Out: $0.10 |
| MiniMax: MiniMax M1 | minimax/minimax-m1 | openrouter | 1000000 | 40000 | In: $0.30, Out: $1.65 |
| Mistral Large | mistralai/mistral-large | openrouter | 128000 | - | In: $2.00, Out: $6.00 |
| Mistral Large 2407 | mistralai/mistral-large-2407 | openrouter | 131072 | - | In: $2.00, Out: $6.00 |
| Mistral Large 2411 | mistralai/mistral-large-2411 | openrouter | 131072 | - | In: $2.00, Out: $6.00 |
| Mistral Small | mistralai/mistral-small | openrouter | 32768 | - | In: $0.20, Out: $0.60 |
| Mistral Tiny | mistralai/mistral-tiny | openrouter | 32768 | - | In: $0.25, Out: $0.25 |
| Mistral: Codestral 2501 | mistralai/codestral-2501 | openrouter | 262144 | - | In: $0.30, Out: $0.90 |
| Mistral: Devstral Medium | mistralai/devstral-medium | openrouter | 131072 | - | In: $0.40, Out: $2.00 |
| Mistral: Devstral Small 1.1 | mistralai/devstral-small | openrouter | 128000 | - | In: $0.07, Out: $0.28 |
| Mistral: Devstral Small 2505 | mistralai/devstral-small-2505 | openrouter | 32768 | - | In: $0.03, Out: $0.03 |
| Mistral: Devstral Small 2505 (free) | mistralai/devstral-small-2505:free | openrouter | 32768 | - | - |
| Mistral: Magistral Medium 2506 | mistralai/magistral-medium-2506 | openrouter | 40960 | 40000 | In: $2.00, Out: $5.00 |
| Mistral: Magistral Medium 2506 (thinking) | mistralai/magistral-medium-2506:thinking | openrouter | 40960 | 40000 | In: $2.00, Out: $5.00 |
| Mistral: Magistral Small 2506 | mistralai/magistral-small-2506 | openrouter | 40960 | 40960 | In: $0.10, Out: $0.30 |
| Mistral: Ministral 3B | mistralai/ministral-3b | openrouter | 131072 | - | In: $0.04, Out: $0.04 |
| Mistral: Ministral 8B | mistralai/ministral-8b | openrouter | 128000 | - | In: $0.10, Out: $0.10 |
| Mistral: Mistral 7B Instruct | mistralai/mistral-7b-instruct | openrouter | 32768 | 16384 | In: $0.03, Out: $0.05 |
| Mistral: Mistral 7B Instruct (free) | mistralai/mistral-7b-instruct:free | openrouter | 32768 | 16384 | - |
| Mistral: Mistral 7B Instruct v0.1 | mistralai/mistral-7b-instruct-v0.1 | openrouter | 2824 | - | In: $0.11, Out: $0.19 |
| Mistral: Mistral 7B Instruct v0.3 | mistralai/mistral-7b-instruct-v0.3 | openrouter | 32768 | 16384 | In: $0.03, Out: $0.05 |
| Mistral: Mistral Medium 3 | mistralai/mistral-medium-3 | openrouter | 131072 | - | In: $0.40, Out: $2.00 |
| Mistral: Mistral Nemo | mistralai/mistral-nemo | openrouter | 32000 | - | In: $0.01, Out: $0.05 |
| Mistral: Mistral Small 3 | mistralai/mistral-small-24b-instruct-2501 | openrouter | 32768 | - | In: $0.03, Out: $0.03 |
| Mistral: Mistral Small 3.1 24B | mistralai/mistral-small-3.1-24b-instruct | openrouter | 128000 | - | In: $0.05, Out: $0.10 |
| Mistral: Mistral Small 3.1 24B (free) | mistralai/mistral-small-3.1-24b-instruct:free | openrouter | 128000 | - | - |
| Mistral: Mistral Small 3.2 24B | mistralai/mistral-small-3.2-24b-instruct | openrouter | 128000 | - | In: $0.05, Out: $0.10 |
| Mistral: Mistral Small 3.2 24B (free) | mistralai/mistral-small-3.2-24b-instruct:free | openrouter | 96000 | - | - |
| Mistral: Mixtral 8x22B Instruct | mistralai/mixtral-8x22b-instruct | openrouter | 65536 | - | In: $0.90, Out: $0.90 |
| Mistral: Mixtral 8x7B Instruct | mistralai/mixtral-8x7b-instruct | openrouter | 32768 | 16384 | In: $0.08, Out: $0.24 |
| Mistral: Pixtral 12B | mistralai/pixtral-12b | openrouter | 32768 | - | In: $0.10, Out: $0.10 |
| Mistral: Pixtral Large 2411 | mistralai/pixtral-large-2411 | openrouter | 131072 | - | In: $2.00, Out: $6.00 |
| Mistral: Saba | mistralai/mistral-saba | openrouter | 32768 | - | In: $0.20, Out: $0.60 |
| MoonshotAI: Kimi K2 | moonshotai/kimi-k2 | openrouter | 63000 | 63000 | In: $0.14, Out: $2.49 |
| MoonshotAI: Kimi K2 (free) | moonshotai/kimi-k2:free | openrouter | 65536 | - | - |
| NVIDIA: Llama 3.1 Nemotron 70B Instruct | nvidia/llama-3.1-nemotron-70b-instruct | openrouter | 131072 | 131072 | In: $0.12, Out: $0.30 |
| Nous: Hermes 3 70B Instruct | nousresearch/hermes-3-llama-3.1-70b | openrouter | 131072 | - | In: $0.10, Out: $0.28 |
| OpenAI: Codex Mini | openai/codex-mini | openrouter | 200000 | 100000 | In: $1.50, Out: $6.00, Cache: $0.38 |
| OpenAI: GPT-3.5 Turbo | openai/gpt-3.5-turbo | openrouter | 16385 | 4096 | In: $0.50, Out: $1.50 |
| OpenAI: GPT-3.5 Turbo (older v0613) | openai/gpt-3.5-turbo-0613 | openrouter | 4095 | 4096 | In: $1.00, Out: $2.00 |
| OpenAI: GPT-3.5 Turbo 16k | openai/gpt-3.5-turbo-16k | openrouter | 16385 | 4096 | In: $3.00, Out: $4.00 |
| OpenAI: GPT-4 | openai/gpt-4 | openrouter | 8191 | 4096 | In: $30.00, Out: $60.00 |
| OpenAI: GPT-4 (older v0314) | openai/gpt-4-0314 | openrouter | 8191 | 4096 | In: $30.00, Out: $60.00 |
| OpenAI: GPT-4 Turbo | openai/gpt-4-turbo | openrouter | 128000 | 4096 | In: $10.00, Out: $30.00 |
| OpenAI: GPT-4 Turbo (older v1106) | openai/gpt-4-1106-preview | openrouter | 128000 | 4096 | In: $10.00, Out: $30.00 |
| OpenAI: GPT-4 Turbo Preview | openai/gpt-4-turbo-preview | openrouter | 128000 | 4096 | In: $10.00, Out: $30.00 |
| OpenAI: GPT-4.1 | openai/gpt-4.1 | openrouter | 1047576 | 32768 | In: $2.00, Out: $8.00, Cache: $0.50 |
| OpenAI: GPT-4.1 Mini | openai/gpt-4.1-mini | openrouter | 1047576 | 32768 | In: $0.40, Out: $1.60, Cache: $0.10 |
| OpenAI: GPT-4.1 Nano | openai/gpt-4.1-nano | openrouter | 1047576 | 32768 | In: $0.10, Out: $0.40, Cache: $0.02 |
| OpenAI: GPT-4o | openai/gpt-4o | openrouter | 128000 | 16384 | In: $2.50, Out: $10.00, Cache: $1.25 |
| OpenAI: GPT-4o (2024-05-13) | openai/gpt-4o-2024-05-13 | openrouter | 128000 | 4096 | In: $5.00, Out: $15.00 |
| OpenAI: GPT-4o (2024-08-06) | openai/gpt-4o-2024-08-06 | openrouter | 128000 | 16384 | In: $2.50, Out: $10.00, Cache: $1.25 |
| OpenAI: GPT-4o (2024-11-20) | openai/gpt-4o-2024-11-20 | openrouter | 128000 | 16384 | In: $2.50, Out: $10.00, Cache: $1.25 |
| OpenAI: GPT-4o (extended) | openai/gpt-4o:extended | openrouter | 128000 | 64000 | In: $6.00, Out: $18.00 |
| OpenAI: GPT-4o-mini | openai/gpt-4o-mini | openrouter | 128000 | 16384 | In: $0.15, Out: $0.60, Cache: $0.08 |
| OpenAI: GPT-4o-mini (2024-07-18) | openai/gpt-4o-mini-2024-07-18 | openrouter | 128000 | 16384 | In: $0.15, Out: $0.60, Cache: $0.08 |
| OpenAI: o1 | openai/o1 | openrouter | 200000 | 100000 | In: $15.00, Out: $60.00, Cache: $7.50 |
| OpenAI: o3 | openai/o3 | openrouter | 200000 | 100000 | In: $2.00, Out: $8.00, Cache: $0.50 |
| OpenAI: o3 Mini | openai/o3-mini | openrouter | 200000 | 100000 | In: $1.10, Out: $4.40, Cache: $0.55 |
| OpenAI: o3 Mini High | openai/o3-mini-high | openrouter | 200000 | 100000 | In: $1.10, Out: $4.40, Cache: $0.55 |
| OpenAI: o3 Pro | openai/o3-pro | openrouter | 200000 | 100000 | In: $20.00, Out: $80.00 |
| OpenAI: o4 Mini | openai/o4-mini | openrouter | 200000 | 100000 | In: $1.10, Out: $4.40, Cache: $0.28 |
| OpenAI: o4 Mini High | openai/o4-mini-high | openrouter | 200000 | 100000 | In: $1.10, Out: $4.40, Cache: $0.28 |
| Qwen2.5 72B Instruct | qwen/qwen-2.5-72b-instruct | openrouter | 32768 | 16384 | In: $0.12, Out: $0.39 |
| Qwen: Qwen-Max  | qwen/qwen-max | openrouter | 32768 | 8192 | In: $1.60, Out: $6.40, Cache: $0.64 |
| Qwen: Qwen-Plus | qwen/qwen-plus | openrouter | 131072 | 8192 | In: $0.40, Out: $1.20, Cache: $0.16 |
| Qwen: Qwen-Turbo | qwen/qwen-turbo | openrouter | 1000000 | 8192 | In: $0.05, Out: $0.20, Cache: $0.02 |
| Qwen: Qwen3 14B | qwen/qwen3-14b | openrouter | 40960 | 40960 | In: $0.06, Out: $0.24 |
| Qwen: Qwen3 235B A22B | qwen/qwen3-235b-a22b | openrouter | 40960 | 40960 | In: $0.13, Out: $0.60 |
| Qwen: Qwen3 235B A22B (free) | qwen/qwen3-235b-a22b:free | openrouter | 131072 | - | - |
| Qwen: Qwen3 30B A3B | qwen/qwen3-30b-a3b | openrouter | 40960 | 40960 | In: $0.08, Out: $0.29 |
| Qwen: Qwen3 32B | qwen/qwen3-32b | openrouter | 40960 | - | In: $0.10, Out: $0.30 |
| Qwen: Qwen3 4B (free) | qwen/qwen3-4b:free | openrouter | 40960 | - | - |
| TheDrummer: Rocinante 12B | thedrummer/rocinante-12b | openrouter | 32768 | - | In: $0.20, Out: $0.50 |
| TheDrummer: UnslopNemo 12B | thedrummer/unslopnemo-12b | openrouter | 32768 | - | In: $0.40, Out: $0.40 |
| xAI: Grok 2 1212 | x-ai/grok-2-1212 | openrouter | 131072 | - | In: $2.00, Out: $10.00 |
| xAI: Grok 3 | x-ai/grok-3 | openrouter | 131072 | - | In: $3.00, Out: $15.00, Cache: $0.75 |
| xAI: Grok 3 Beta | x-ai/grok-3-beta | openrouter | 131072 | - | In: $3.00, Out: $15.00, Cache: $0.75 |
| xAI: Grok 3 Mini | x-ai/grok-3-mini | openrouter | 131072 | - | In: $0.30, Out: $0.50, Cache: $0.08 |
| xAI: Grok 3 Mini Beta | x-ai/grok-3-mini-beta | openrouter | 131072 | - | In: $0.30, Out: $0.50, Cache: $0.08 |
| xAI: Grok 4 | x-ai/grok-4 | openrouter | 256000 | - | In: $3.00, Out: $15.00, Cache: $0.75 |


### Structured Output (284)

| Model | ID | Provider | Context | Max Output | Standard Pricing (per 1M tokens) |
| :-- | :-- | :-- | --: | --: | :-- |
| Claude Sonnet 3 | claude-3-sonnet-20240229 | anthropic | 200000 | 4096 | In: $3.00, Out: $15.00 |
| Claude | anthropic.claude-v2 | bedrock | 200000 | 4096 | In: $8.00, Out: $24.00 |
| Claude | anthropic.claude-v2:0:100k | bedrock | 200000 | 4096 | In: $8.00, Out: $24.00 |
| Claude | anthropic.claude-v2:0:18k | bedrock | 200000 | 4096 | In: $8.00, Out: $24.00 |
| Claude | anthropic.claude-v2:1 | bedrock | 200000 | 4096 | In: $8.00, Out: $24.00 |
| Claude | anthropic.claude-v2:1:18k | bedrock | 200000 | 4096 | In: $8.00, Out: $24.00 |
| Claude | anthropic.claude-v2:1:200k | bedrock | 200000 | 4096 | In: $8.00, Out: $24.00 |
| Claude 3 Haiku | anthropic.claude-3-haiku-20240307-v1:0 | bedrock | 200000 | 4096 | In: $0.25, Out: $1.25 |
| Claude 3 Haiku | anthropic.claude-3-haiku-20240307-v1:0:200k | bedrock | 200000 | 4096 | In: $0.25, Out: $1.25 |
| Claude 3 Haiku | anthropic.claude-3-haiku-20240307-v1:0:48k | bedrock | 200000 | 4096 | In: $0.25, Out: $1.25 |
| Claude 3 Opus | anthropic.claude-3-opus-20240229-v1:0 | bedrock | 200000 | 4096 | In: $15.00, Out: $75.00 |
| Claude 3 Opus | anthropic.claude-3-opus-20240229-v1:0:12k | bedrock | 200000 | 4096 | In: $15.00, Out: $75.00 |
| Claude 3 Opus | anthropic.claude-3-opus-20240229-v1:0:200k | bedrock | 200000 | 4096 | In: $15.00, Out: $75.00 |
| Claude 3 Opus | anthropic.claude-3-opus-20240229-v1:0:28k | bedrock | 200000 | 4096 | In: $15.00, Out: $75.00 |
| Claude 3 Sonnet | anthropic.claude-3-sonnet-20240229-v1:0 | bedrock | 200000 | 4096 | In: $3.00, Out: $15.00 |
| Claude 3 Sonnet | anthropic.claude-3-sonnet-20240229-v1:0:200k | bedrock | 200000 | 4096 | In: $3.00, Out: $15.00 |
| Claude 3 Sonnet | anthropic.claude-3-sonnet-20240229-v1:0:28k | bedrock | 200000 | 4096 | In: $3.00, Out: $15.00 |
| Claude 3.5 Haiku | anthropic.claude-3-5-haiku-20241022-v1:0 | bedrock | 200000 | 4096 | In: $0.80, Out: $4.00 |
| Claude 3.5 Sonnet | anthropic.claude-3-5-sonnet-20240620-v1:0 | bedrock | 200000 | 4096 | In: $3.00, Out: $15.00 |
| Claude 3.5 Sonnet | anthropic.claude-3-5-sonnet-20240620-v1:0:18k | bedrock | 200000 | 4096 | In: $3.00, Out: $15.00 |
| Claude 3.5 Sonnet | anthropic.claude-3-5-sonnet-20240620-v1:0:200k | bedrock | 200000 | 4096 | In: $3.00, Out: $15.00 |
| Claude 3.5 Sonnet | anthropic.claude-3-5-sonnet-20240620-v1:0:51k | bedrock | 200000 | 4096 | In: $3.00, Out: $15.00 |
| Claude 3.5 Sonnet v2 | anthropic.claude-3-5-sonnet-20241022-v2:0 | bedrock | 200000 | 4096 | In: $3.00, Out: $15.00 |
| Claude 3.5 Sonnet v2 | anthropic.claude-3-5-sonnet-20241022-v2:0:18k | bedrock | 200000 | 4096 | In: $3.00, Out: $15.00 |
| Claude 3.5 Sonnet v2 | anthropic.claude-3-5-sonnet-20241022-v2:0:200k | bedrock | 200000 | 4096 | In: $3.00, Out: $15.00 |
| Claude 3.5 Sonnet v2 | anthropic.claude-3-5-sonnet-20241022-v2:0:51k | bedrock | 200000 | 4096 | In: $3.00, Out: $15.00 |
| Claude 3.7 Sonnet | us.anthropic.claude-3-7-sonnet-20250219-v1:0 | bedrock | 200000 | 4096 | In: $3.00, Out: $15.00 |
| Claude Instant | anthropic.claude-instant-v1 | bedrock | 200000 | 4096 | In: $0.80, Out: $2.40 |
| Claude Instant | anthropic.claude-instant-v1:2:100k | bedrock | 200000 | 4096 | In: $0.80, Out: $2.40 |
| Claude Opus 4 | us.anthropic.claude-opus-4-20250514-v1:0 | bedrock | 200000 | 4096 | In: $0.10, Out: $0.20 |
| Claude Sonnet 4 | us.anthropic.claude-sonnet-4-20250514-v1:0 | bedrock | 200000 | 4096 | In: $0.10, Out: $0.20 |
| deepseek-chat | deepseek-chat | deepseek | 64000 | 8000 | In: $0.27, Out: $1.10, Cache: $0.07 |
| deepseek-reasoner | deepseek-reasoner | deepseek | 64000 | 64000 | In: $0.55, Out: $2.19, Cache: $0.14 |
| Gemini 1.0 Pro Vision | gemini-1.0-pro-vision-latest | gemini | 12288 | 4096 | In: $0.08, Out: $0.30 |
| Gemini 1.0 Pro Vision | gemini-pro-vision | gemini | 12288 | 4096 | In: $0.08, Out: $0.30 |
| Gemini 1.5 Flash | gemini-1.5-flash | gemini | 1048576 | 8192 | In: $0.08, Out: $0.30, Cache: $0.02 |
| Gemini 1.5 Flash | gemini-1.5-flash-001 | gemini | 1048576 | 8192 | In: $0.08, Out: $0.30, Cache: $0.02 |
| Gemini 1.5 Flash | gemini-1.5-flash-002 | gemini | 1048576 | 8192 | In: $0.08, Out: $0.30, Cache: $0.02 |
| Gemini 1.5 Flash | gemini-1.5-flash-latest | gemini | 1048576 | 8192 | In: $0.08, Out: $0.30, Cache: $0.02 |
| Gemini 1.5 Flash-8B | gemini-1.5-flash-8b | gemini | 1048576 | 8192 | In: $0.08, Out: $0.30, Cache: $0.02 |
| Gemini 1.5 Flash-8B | gemini-1.5-flash-8b-001 | gemini | 1048576 | 8192 | In: $0.08, Out: $0.30, Cache: $0.02 |
| Gemini 1.5 Flash-8B | gemini-1.5-flash-8b-latest | gemini | 1048576 | 8192 | In: $0.08, Out: $0.30, Cache: $0.02 |
| Gemini 1.5 Pro | gemini-1.5-pro | gemini | 2097152 | 8192 | In: $1.25, Out: $5.00, Cache: $0.31 |
| Gemini 1.5 Pro | gemini-1.5-pro-001 | gemini | 2097152 | 8192 | In: $1.25, Out: $5.00, Cache: $0.31 |
| Gemini 1.5 Pro | gemini-1.5-pro-002 | gemini | 2097152 | 8192 | In: $1.25, Out: $5.00, Cache: $0.31 |
| Gemini 1.5 Pro | gemini-1.5-pro-latest | gemini | 2097152 | 8192 | In: $1.25, Out: $5.00, Cache: $0.31 |
| Gemini 2.0 Flash | gemini-2.0-flash | gemini | 1048576 | 8192 | In: $0.10, Out: $0.40, Cache: $0.02 |
| Gemini 2.0 Flash | gemini-2.0-flash-001 | gemini | 1048576 | 8192 | In: $0.10, Out: $0.40, Cache: $0.02 |
| Gemini 2.0 Flash | gemini-2.0-flash-exp | gemini | 1048576 | 8192 | In: $0.10, Out: $0.40, Cache: $0.02 |
| Gemini 2.0 Flash Live | gemini-2.0-flash-live-001 | gemini | 1048576 | 8192 | In: $0.10, Out: $0.40, Cache: $0.02 |
| Gemini 2.0 Flash Preview Image Generation | gemini-2.0-flash-preview-image-generation | gemini | 32000 | 8192 | In: $0.10, Out: $0.40, Cache: $0.02 |
| Gemini 2.0 Flash-Lite | gemini-2.0-flash-lite | gemini | 1048576 | 8192 | In: $0.10, Out: $0.40, Cache: $0.02 |
| Gemini 2.0 Flash-Lite | gemini-2.0-flash-lite-001 | gemini | 1048576 | 8192 | In: $0.10, Out: $0.40, Cache: $0.02 |
| Gemini 2.0 Pro Experimental | gemini-2.0-pro-exp | gemini | 1048576 | 65536 | In: $0.08, Out: $0.30 |
| Gemini 2.0 Pro Experimental 02-05 | gemini-2.0-pro-exp-02-05 | gemini | 1048576 | 65536 | In: $0.08, Out: $0.30 |
| Gemini 2.5 Flash | gemini-2.5-flash | gemini | 1048576 | 65536 | In: $0.30, Out: $2.50, Cache: $0.08 |
| Gemini 2.5 Flash | gemini-2.5-flash-preview-05-20 | gemini | 1048576 | 65536 | In: $0.30, Out: $2.50, Cache: $0.08 |
| Gemini 2.5 Flash Live | gemini-live-2.5-flash-preview | gemini | 1048576 | 8192 | In: $0.30, Out: $2.50, Cache: $0.08 |
| Gemini 2.5 Flash Preview 05-20 | gemini-2.0-flash-thinking-exp | gemini | 1048576 | 65536 | In: $0.10, Out: $0.40 |
| Gemini 2.5 Flash Preview 05-20 | gemini-2.0-flash-thinking-exp-01-21 | gemini | 1048576 | 65536 | In: $0.10, Out: $0.40 |
| Gemini 2.5 Flash Preview 05-20 | gemini-2.0-flash-thinking-exp-1219 | gemini | 1048576 | 65536 | In: $0.10, Out: $0.40 |
| Gemini 2.5 Flash-Lite Preview | gemini-2.5-flash-lite-preview-06-17 | gemini | 1000000 | 64000 | In: $0.30, Out: $2.50, Cache: $0.08 |
| Gemini 2.5 Pro | gemini-2.5-pro | gemini | 1048576 | 65536 | In: $1.25, Out: $10.00, Cache: $0.31 |
| Gemini 2.5 Pro | gemini-2.5-pro-preview-03-25 | gemini | 1048576 | 65536 | In: $1.25, Out: $10.00, Cache: $0.31 |
| Gemini 2.5 Pro | gemini-2.5-pro-preview-05-06 | gemini | 1048576 | 65536 | In: $1.25, Out: $10.00, Cache: $0.31 |
| Gemini 2.5 Pro | gemini-2.5-pro-preview-06-05 | gemini | 1048576 | 65536 | In: $1.25, Out: $10.00, Cache: $0.31 |
| Gemini Embedding Experimental | gemini-embedding-exp | gemini | 8192 | 1 | In: $0.00, Out: $0.00 |
| Gemini Experimental 1206 | gemini-exp-1206 | gemini | 1048576 | 65536 | In: $0.08, Out: $0.30 |
| LearnLM 2.0 Flash Experimental | learnlm-2.0-flash-experimental | gemini | 1048576 | 32768 | In: $0.08, Out: $0.30 |
| GPT-4.1 | gpt-4.1 | openai | 1047576 | 32768 | In: $2.00, Out: $8.00, Cache: $0.50 |
| GPT-4.1 | gpt-4.1-2025-04-14 | openai | 1047576 | 32768 | In: $2.00, Out: $8.00, Cache: $0.50 |
| GPT-4.1 mini | gpt-4.1-mini | openai | 1047576 | 32768 | In: $0.40, Out: $1.60, Cache: $0.10 |
| GPT-4.1 mini | gpt-4.1-mini-2025-04-14 | openai | 1047576 | 32768 | In: $0.40, Out: $1.60, Cache: $0.10 |
| GPT-4.1 nano | gpt-4.1-nano | openai | 1047576 | 32768 | In: $0.10, Out: $0.40, Cache: $0.02 |
| GPT-4.1 nano | gpt-4.1-nano-2025-04-14 | openai | 1047576 | 32768 | In: $0.10, Out: $0.40, Cache: $0.02 |
| GPT-4o | gpt-4o | openai | 128000 | 16384 | In: $2.50, Out: $10.00, Cache: $1.25 |
| GPT-4o | gpt-4o-2024-08-06 | openai | 128000 | 16384 | In: $2.50, Out: $10.00, Cache: $1.25 |
| GPT-4o 20240513 | gpt-4o-2024-05-13 | openai | 128000 | 16384 | In: $2.50, Out: $10.00 |
| GPT-4o 20241120 | gpt-4o-2024-11-20 | openai | 128000 | 16384 | In: $2.50, Out: $10.00 |
| GPT-4o Search Preview | gpt-4o-search-preview | openai | 128000 | 16384 | In: $2.50, Out: $10.00 |
| GPT-4o Search Preview | gpt-4o-search-preview-2025-03-11 | openai | 128000 | 16384 | In: $2.50, Out: $10.00 |
| GPT-4o mini | gpt-4o-mini | openai | 128000 | 16384 | In: $0.15, Out: $0.60, Cache: $0.08 |
| GPT-4o mini | gpt-4o-mini-2024-07-18 | openai | 128000 | 16384 | In: $0.15, Out: $0.60, Cache: $0.08 |
| GPT-4o mini Search Preview | gpt-4o-mini-search-preview | openai | 128000 | 16384 | In: $0.15, Out: $0.60 |
| GPT-4o mini Search Preview | gpt-4o-mini-search-preview-2025-03-11 | openai | 128000 | 16384 | In: $0.15, Out: $0.60 |
| O1-Preview | o1-preview | openai | 200000 | 100000 | In: $15.00, Out: $60.00 |
| O1-Preview 20240912 | o1-preview-2024-09-12 | openai | 200000 | 100000 | In: $15.00, Out: $60.00 |
| codex-mini-latest | codex-mini-latest | openai | 200000 | 100000 | In: $1.50, Out: $6.00, Cache: $0.38 |
| o1 | o1 | openai | 200000 | 100000 | In: $15.00, Out: $60.00, Cache: $7.50 |
| o1 | o1-2024-12-17 | openai | 200000 | 100000 | In: $15.00, Out: $60.00, Cache: $7.50 |
| o1-pro | o1-pro | openai | 200000 | 100000 | In: $150.00, Out: $600.00 |
| o1-pro | o1-pro-2025-03-19 | openai | 200000 | 100000 | In: $150.00, Out: $600.00 |
| o3 | o3 | openai | 200000 | 100000 | In: $2.00, Out: $8.00, Cache: $0.50 |
| o3 | o3-2025-04-16 | openai | 200000 | 100000 | In: $2.00, Out: $8.00, Cache: $0.50 |
| o3-mini | o3-mini | openai | 200000 | 100000 | In: $1.10, Out: $4.40, Cache: $0.55 |
| o3-mini | o3-mini-2025-01-31 | openai | 200000 | 100000 | In: $1.10, Out: $4.40, Cache: $0.55 |
| o3-pro | o3-pro | openai | 200000 | 100000 | In: $20.00, Out: $80.00 |
| o3-pro | o3-pro-2025-06-10 | openai | 200000 | 100000 | In: $20.00, Out: $80.00 |
| o4-mini | o4-mini | openai | 200000 | 100000 | In: $1.10, Out: $4.40, Cache: $0.28 |
| o4-mini | o4-mini-2025-04-16 | openai | 200000 | 100000 | In: $1.10, Out: $4.40, Cache: $0.28 |
| 01.AI: Yi Large | 01-ai/yi-large | openrouter | 32768 | 4096 | In: $3.00, Out: $3.00 |
| Arcee AI: Arcee Blitz | arcee-ai/arcee-blitz | openrouter | 32768 | - | In: $0.45, Out: $0.75 |
| Arcee AI: Caller Large | arcee-ai/caller-large | openrouter | 32768 | - | In: $0.55, Out: $0.85 |
| Arcee AI: Coder Large | arcee-ai/coder-large | openrouter | 32768 | - | In: $0.50, Out: $0.80 |
| Arcee AI: Maestro Reasoning | arcee-ai/maestro-reasoning | openrouter | 131072 | 32000 | In: $0.90, Out: $3.30 |
| Arcee AI: Spotlight | arcee-ai/spotlight | openrouter | 131072 | 65537 | In: $0.18, Out: $0.18 |
| Arcee AI: Virtuoso Large | arcee-ai/virtuoso-large | openrouter | 131072 | 64000 | In: $0.75, Out: $1.20 |
| Arcee AI: Virtuoso Medium V2 | arcee-ai/virtuoso-medium-v2 | openrouter | 131072 | 32768 | In: $0.50, Out: $0.80 |
| Cohere: Command | cohere/command | openrouter | 4096 | 4000 | In: $1.00, Out: $2.00 |
| Cohere: Command A | cohere/command-a | openrouter | 256000 | 8192 | In: $2.50, Out: $10.00 |
| Cohere: Command R | cohere/command-r | openrouter | 128000 | 4000 | In: $0.50, Out: $1.50 |
| Cohere: Command R (03-2024) | cohere/command-r-03-2024 | openrouter | 128000 | 4000 | In: $0.50, Out: $1.50 |
| Cohere: Command R (08-2024) | cohere/command-r-08-2024 | openrouter | 128000 | 4000 | In: $0.15, Out: $0.60 |
| Cohere: Command R+ | cohere/command-r-plus | openrouter | 128000 | 4000 | In: $3.00, Out: $15.00 |
| Cohere: Command R+ (04-2024) | cohere/command-r-plus-04-2024 | openrouter | 128000 | 4000 | In: $3.00, Out: $15.00 |
| Cohere: Command R+ (08-2024) | cohere/command-r-plus-08-2024 | openrouter | 128000 | 4000 | In: $2.50, Out: $10.00 |
| Cohere: Command R7B (12-2024) | cohere/command-r7b-12-2024 | openrouter | 128000 | 4000 | In: $0.04, Out: $0.15 |
| DeepSeek: DeepSeek Prover V2 | deepseek/deepseek-prover-v2 | openrouter | 163840 | - | In: $0.50, Out: $2.18 |
| DeepSeek: DeepSeek V3 | deepseek/deepseek-chat | openrouter | 163840 | 163840 | In: $0.30, Out: $0.85 |
| DeepSeek: DeepSeek V3 0324 | deepseek/deepseek-chat-v3-0324 | openrouter | 163840 | 163840 | In: $0.25, Out: $0.85 |
| DeepSeek: R1 | deepseek/deepseek-r1 | openrouter | 163840 | 163840 | In: $0.40, Out: $2.00 |
| DeepSeek: R1 0528 | deepseek/deepseek-r1-0528 | openrouter | 163840 | - | In: $0.27, Out: $0.27 |
| DeepSeek: R1 0528 (free) | deepseek/deepseek-r1-0528:free | openrouter | 163840 | - | - |
| DeepSeek: R1 Distill Llama 70B | deepseek/deepseek-r1-distill-llama-70b | openrouter | 131072 | - | In: $0.05, Out: $0.05 |
| DeepSeek: R1 Distill Llama 70B (free) | deepseek/deepseek-r1-distill-llama-70b:free | openrouter | 8192 | 4096 | - |
| DeepSeek: R1 Distill Qwen 1.5B | deepseek/deepseek-r1-distill-qwen-1.5b | openrouter | 131072 | 32768 | In: $0.18, Out: $0.18 |
| DeepSeek: R1 Distill Qwen 14B | deepseek/deepseek-r1-distill-qwen-14b | openrouter | 64000 | 32000 | In: $0.15, Out: $0.15 |
| DeepSeek: R1 Distill Qwen 32B | deepseek/deepseek-r1-distill-qwen-32b | openrouter | 131072 | 16384 | In: $0.08, Out: $0.15 |
| Goliath 120B | alpindale/goliath-120b | openrouter | 6144 | - | In: $9.00, Out: $11.00 |
| Google: Gemini 1.5 Flash  | google/gemini-flash-1.5 | openrouter | 1000000 | 8192 | In: $0.08, Out: $0.30, Cache: $0.02 |
| Google: Gemini 1.5 Flash 8B | google/gemini-flash-1.5-8b | openrouter | 1000000 | 8192 | In: $0.04, Out: $0.15, Cache: $0.01 |
| Google: Gemini 1.5 Pro | google/gemini-pro-1.5 | openrouter | 2000000 | 8192 | In: $1.25, Out: $5.00 |
| Google: Gemini 2.0 Flash | google/gemini-2.0-flash-001 | openrouter | 1048576 | 8192 | In: $0.10, Out: $0.40, Cache: $0.02 |
| Google: Gemini 2.0 Flash Lite | google/gemini-2.0-flash-lite-001 | openrouter | 1048576 | 8192 | In: $0.08, Out: $0.30 |
| Google: Gemini 2.5 Flash | google/gemini-2.5-flash | openrouter | 1048576 | 65535 | In: $0.30, Out: $2.50, Cache: $0.08 |
| Google: Gemini 2.5 Flash Lite Preview 06-17 | google/gemini-2.5-flash-lite-preview-06-17 | openrouter | 1048576 | 65535 | In: $0.10, Out: $0.40, Cache: $0.02 |
| Google: Gemini 2.5 Pro | google/gemini-2.5-pro | openrouter | 1048576 | 65536 | In: $1.25, Out: $10.00, Cache: $0.31 |
| Google: Gemini 2.5 Pro Experimental | google/gemini-2.5-pro-exp-03-25 | openrouter | 1048576 | 65535 | - |
| Google: Gemini 2.5 Pro Preview 05-06 | google/gemini-2.5-pro-preview-05-06 | openrouter | 1048576 | 65535 | In: $1.25, Out: $10.00, Cache: $0.31 |
| Google: Gemini 2.5 Pro Preview 06-05 | google/gemini-2.5-pro-preview | openrouter | 1048576 | 65536 | In: $1.25, Out: $10.00, Cache: $0.31 |
| Google: Gemma 2 27B | google/gemma-2-27b-it | openrouter | 8192 | 2048 | In: $0.80, Out: $0.80 |
| Google: Gemma 2 9B | google/gemma-2-9b-it | openrouter | 8192 | 8192 | In: $0.00, Out: $0.00 |
| Google: Gemma 3 12B | google/gemma-3-12b-it | openrouter | 96000 | 8192 | In: $0.03, Out: $0.03 |
| Google: Gemma 3 12B (free) | google/gemma-3-12b-it:free | openrouter | 96000 | 8192 | - |
| Google: Gemma 3 27B | google/gemma-3-27b-it | openrouter | 131072 | 16384 | In: $0.09, Out: $0.17 |
| Google: Gemma 3 27B (free) | google/gemma-3-27b-it:free | openrouter | 96000 | 8192 | - |
| Google: Gemma 3 4B | google/gemma-3-4b-it | openrouter | 131072 | - | In: $0.02, Out: $0.04 |
| Google: Gemma 3 4B (free) | google/gemma-3-4b-it:free | openrouter | 32768 | 8192 | - |
| Google: Gemma 3n 2B (free) | google/gemma-3n-e2b-it:free | openrouter | 8192 | 2048 | - |
| Google: Gemma 3n 4B | google/gemma-3n-e4b-it | openrouter | 32768 | - | In: $0.02, Out: $0.04 |
| Google: Gemma 3n 4B (free) | google/gemma-3n-e4b-it:free | openrouter | 8192 | 2048 | - |
| Liquid: LFM 40B MoE | liquid/lfm-40b | openrouter | 32768 | - | In: $0.15, Out: $0.15 |
| Liquid: LFM 7B | liquid/lfm-7b | openrouter | 32768 | - | In: $0.01, Out: $0.01 |
| Llama Guard 3 8B | meta-llama/llama-guard-3-8b | openrouter | 131072 | - | In: $0.02, Out: $0.06 |
| Meta: Llama 3 70B Instruct | meta-llama/llama-3-70b-instruct | openrouter | 8192 | 16384 | In: $0.30, Out: $0.40 |
| Meta: Llama 3 8B Instruct | meta-llama/llama-3-8b-instruct | openrouter | 8192 | 16384 | In: $0.03, Out: $0.06 |
| Meta: Llama 3.1 405B Instruct | meta-llama/llama-3.1-405b-instruct | openrouter | 32768 | 16384 | In: $0.80, Out: $0.80 |
| Meta: Llama 3.1 405B Instruct (free) | meta-llama/llama-3.1-405b-instruct:free | openrouter | 65536 | - | - |
| Meta: Llama 3.1 70B Instruct | meta-llama/llama-3.1-70b-instruct | openrouter | 131072 | 16384 | In: $0.10, Out: $0.28 |
| Meta: Llama 3.1 8B Instruct | meta-llama/llama-3.1-8b-instruct | openrouter | 131000 | 131000 | In: $0.02, Out: $0.02 |
| Meta: Llama 3.2 11B Vision Instruct | meta-llama/llama-3.2-11b-vision-instruct | openrouter | 131072 | 16384 | In: $0.05, Out: $0.05 |
| Meta: Llama 3.2 11B Vision Instruct (free) | meta-llama/llama-3.2-11b-vision-instruct:free | openrouter | 131072 | 2048 | - |
| Meta: Llama 3.2 1B Instruct | meta-llama/llama-3.2-1b-instruct | openrouter | 131072 | 16384 | In: $0.01, Out: $0.01 |
| Meta: Llama 3.2 3B Instruct | meta-llama/llama-3.2-3b-instruct | openrouter | 20000 | 20000 | In: $0.00, Out: $0.01 |
| Meta: Llama 3.2 90B Vision Instruct | meta-llama/llama-3.2-90b-vision-instruct | openrouter | 131072 | 2048 | In: $1.20, Out: $1.20 |
| Meta: Llama 3.3 70B Instruct | meta-llama/llama-3.3-70b-instruct | openrouter | 131072 | 16384 | In: $0.04, Out: $0.12 |
| Meta: Llama 3.3 70B Instruct (free) | meta-llama/llama-3.3-70b-instruct:free | openrouter | 65536 | - | - |
| Meta: Llama 4 Maverick | meta-llama/llama-4-maverick | openrouter | 1048576 | 16384 | In: $0.15, Out: $0.60 |
| Meta: Llama 4 Scout | meta-llama/llama-4-scout | openrouter | 1048576 | 1048576 | In: $0.08, Out: $0.30 |
| Meta: Llama Guard 4 12B | meta-llama/llama-guard-4-12b | openrouter | 163840 | - | In: $0.05, Out: $0.05 |
| Meta: LlamaGuard 2 8B | meta-llama/llama-guard-2-8b | openrouter | 8192 | - | In: $0.20, Out: $0.20 |
| Microsoft: Phi 4 | microsoft/phi-4 | openrouter | 16384 | 16384 | In: $0.07, Out: $0.14 |
| Microsoft: Phi 4 Multimodal Instruct | microsoft/phi-4-multimodal-instruct | openrouter | 131072 | - | In: $0.05, Out: $0.10 |
| Microsoft: Phi 4 Reasoning Plus | microsoft/phi-4-reasoning-plus | openrouter | 32768 | - | In: $0.07, Out: $0.35 |
| Mistral Large | mistralai/mistral-large | openrouter | 128000 | - | In: $2.00, Out: $6.00 |
| Mistral Large 2407 | mistralai/mistral-large-2407 | openrouter | 131072 | - | In: $2.00, Out: $6.00 |
| Mistral Large 2411 | mistralai/mistral-large-2411 | openrouter | 131072 | - | In: $2.00, Out: $6.00 |
| Mistral Small | mistralai/mistral-small | openrouter | 32768 | - | In: $0.20, Out: $0.60 |
| Mistral Tiny | mistralai/mistral-tiny | openrouter | 32768 | - | In: $0.25, Out: $0.25 |
| Mistral: Codestral 2501 | mistralai/codestral-2501 | openrouter | 262144 | - | In: $0.30, Out: $0.90 |
| Mistral: Devstral Medium | mistralai/devstral-medium | openrouter | 131072 | - | In: $0.40, Out: $2.00 |
| Mistral: Devstral Small 1.1 | mistralai/devstral-small | openrouter | 128000 | - | In: $0.07, Out: $0.28 |
| Mistral: Devstral Small 2505 | mistralai/devstral-small-2505 | openrouter | 32768 | - | In: $0.03, Out: $0.03 |
| Mistral: Magistral Medium 2506 | mistralai/magistral-medium-2506 | openrouter | 40960 | 40000 | In: $2.00, Out: $5.00 |
| Mistral: Magistral Medium 2506 (thinking) | mistralai/magistral-medium-2506:thinking | openrouter | 40960 | 40000 | In: $2.00, Out: $5.00 |
| Mistral: Magistral Small 2506 | mistralai/magistral-small-2506 | openrouter | 40960 | 40960 | In: $0.10, Out: $0.30 |
| Mistral: Ministral 3B | mistralai/ministral-3b | openrouter | 131072 | - | In: $0.04, Out: $0.04 |
| Mistral: Ministral 8B | mistralai/ministral-8b | openrouter | 128000 | - | In: $0.10, Out: $0.10 |
| Mistral: Mistral 7B Instruct | mistralai/mistral-7b-instruct | openrouter | 32768 | 16384 | In: $0.03, Out: $0.05 |
| Mistral: Mistral 7B Instruct (free) | mistralai/mistral-7b-instruct:free | openrouter | 32768 | 16384 | - |
| Mistral: Mistral 7B Instruct v0.1 | mistralai/mistral-7b-instruct-v0.1 | openrouter | 2824 | - | In: $0.11, Out: $0.19 |
| Mistral: Mistral 7B Instruct v0.2 | mistralai/mistral-7b-instruct-v0.2 | openrouter | 32768 | - | In: $0.20, Out: $0.20 |
| Mistral: Mistral 7B Instruct v0.3 | mistralai/mistral-7b-instruct-v0.3 | openrouter | 32768 | 16384 | In: $0.03, Out: $0.05 |
| Mistral: Mistral Medium 3 | mistralai/mistral-medium-3 | openrouter | 131072 | - | In: $0.40, Out: $2.00 |
| Mistral: Mistral Nemo | mistralai/mistral-nemo | openrouter | 32000 | - | In: $0.01, Out: $0.05 |
| Mistral: Mistral Small 3 | mistralai/mistral-small-24b-instruct-2501 | openrouter | 32768 | - | In: $0.03, Out: $0.03 |
| Mistral: Mistral Small 3.1 24B | mistralai/mistral-small-3.1-24b-instruct | openrouter | 128000 | - | In: $0.05, Out: $0.10 |
| Mistral: Mistral Small 3.1 24B (free) | mistralai/mistral-small-3.1-24b-instruct:free | openrouter | 128000 | - | - |
| Mistral: Mistral Small 3.2 24B | mistralai/mistral-small-3.2-24b-instruct | openrouter | 128000 | - | In: $0.05, Out: $0.10 |
| Mistral: Mixtral 8x22B Instruct | mistralai/mixtral-8x22b-instruct | openrouter | 65536 | - | In: $0.90, Out: $0.90 |
| Mistral: Mixtral 8x7B Instruct | mistralai/mixtral-8x7b-instruct | openrouter | 32768 | 16384 | In: $0.08, Out: $0.24 |
| Mistral: Pixtral 12B | mistralai/pixtral-12b | openrouter | 32768 | - | In: $0.10, Out: $0.10 |
| Mistral: Pixtral Large 2411 | mistralai/pixtral-large-2411 | openrouter | 131072 | - | In: $2.00, Out: $6.00 |
| Mistral: Saba | mistralai/mistral-saba | openrouter | 32768 | - | In: $0.20, Out: $0.60 |
| MoonshotAI: Kimi K2 | moonshotai/kimi-k2 | openrouter | 63000 | 63000 | In: $0.14, Out: $2.49 |
| MythoMax 13B | gryphe/mythomax-l2-13b | openrouter | 4096 | - | In: $0.06, Out: $0.06 |
| NVIDIA: Llama 3.1 Nemotron 70B Instruct | nvidia/llama-3.1-nemotron-70b-instruct | openrouter | 131072 | 131072 | In: $0.12, Out: $0.30 |
| NeverSleep: Lumimaid v0.2 8B | neversleep/llama-3.1-lumimaid-8b | openrouter | 32768 | - | In: $0.18, Out: $1.00 |
| Nous: Hermes 2 Mixtral 8x7B DPO | nousresearch/nous-hermes-2-mixtral-8x7b-dpo | openrouter | 32768 | 2048 | In: $0.60, Out: $0.60 |
| Nous: Hermes 3 405B Instruct | nousresearch/hermes-3-llama-3.1-405b | openrouter | 131072 | 16384 | In: $0.70, Out: $0.80 |
| Nous: Hermes 3 70B Instruct | nousresearch/hermes-3-llama-3.1-70b | openrouter | 131072 | - | In: $0.10, Out: $0.28 |
| NousResearch: Hermes 2 Pro - Llama-3 8B | nousresearch/hermes-2-pro-llama-3-8b | openrouter | 131072 | 131072 | In: $0.02, Out: $0.04 |
| OpenAI: ChatGPT-4o | openai/chatgpt-4o-latest | openrouter | 128000 | 16384 | In: $5.00, Out: $15.00 |
| OpenAI: Codex Mini | openai/codex-mini | openrouter | 200000 | 100000 | In: $1.50, Out: $6.00, Cache: $0.38 |
| OpenAI: GPT-3.5 Turbo | openai/gpt-3.5-turbo | openrouter | 16385 | 4096 | In: $0.50, Out: $1.50 |
| OpenAI: GPT-3.5 Turbo (older v0613) | openai/gpt-3.5-turbo-0613 | openrouter | 4095 | 4096 | In: $1.00, Out: $2.00 |
| OpenAI: GPT-3.5 Turbo 16k | openai/gpt-3.5-turbo-16k | openrouter | 16385 | 4096 | In: $3.00, Out: $4.00 |
| OpenAI: GPT-3.5 Turbo Instruct | openai/gpt-3.5-turbo-instruct | openrouter | 4095 | 4096 | In: $1.50, Out: $2.00 |
| OpenAI: GPT-4 | openai/gpt-4 | openrouter | 8191 | 4096 | In: $30.00, Out: $60.00 |
| OpenAI: GPT-4 (older v0314) | openai/gpt-4-0314 | openrouter | 8191 | 4096 | In: $30.00, Out: $60.00 |
| OpenAI: GPT-4 Turbo | openai/gpt-4-turbo | openrouter | 128000 | 4096 | In: $10.00, Out: $30.00 |
| OpenAI: GPT-4 Turbo (older v1106) | openai/gpt-4-1106-preview | openrouter | 128000 | 4096 | In: $10.00, Out: $30.00 |
| OpenAI: GPT-4 Turbo Preview | openai/gpt-4-turbo-preview | openrouter | 128000 | 4096 | In: $10.00, Out: $30.00 |
| OpenAI: GPT-4.1 | openai/gpt-4.1 | openrouter | 1047576 | 32768 | In: $2.00, Out: $8.00, Cache: $0.50 |
| OpenAI: GPT-4.1 Mini | openai/gpt-4.1-mini | openrouter | 1047576 | 32768 | In: $0.40, Out: $1.60, Cache: $0.10 |
| OpenAI: GPT-4.1 Nano | openai/gpt-4.1-nano | openrouter | 1047576 | 32768 | In: $0.10, Out: $0.40, Cache: $0.02 |
| OpenAI: GPT-4o | openai/gpt-4o | openrouter | 128000 | 16384 | In: $2.50, Out: $10.00, Cache: $1.25 |
| OpenAI: GPT-4o (2024-05-13) | openai/gpt-4o-2024-05-13 | openrouter | 128000 | 4096 | In: $5.00, Out: $15.00 |
| OpenAI: GPT-4o (2024-08-06) | openai/gpt-4o-2024-08-06 | openrouter | 128000 | 16384 | In: $2.50, Out: $10.00, Cache: $1.25 |
| OpenAI: GPT-4o (2024-11-20) | openai/gpt-4o-2024-11-20 | openrouter | 128000 | 16384 | In: $2.50, Out: $10.00, Cache: $1.25 |
| OpenAI: GPT-4o (extended) | openai/gpt-4o:extended | openrouter | 128000 | 64000 | In: $6.00, Out: $18.00 |
| OpenAI: GPT-4o Search Preview | openai/gpt-4o-search-preview | openrouter | 128000 | 16384 | In: $2.50, Out: $10.00 |
| OpenAI: GPT-4o-mini | openai/gpt-4o-mini | openrouter | 128000 | 16384 | In: $0.15, Out: $0.60, Cache: $0.08 |
| OpenAI: GPT-4o-mini (2024-07-18) | openai/gpt-4o-mini-2024-07-18 | openrouter | 128000 | 16384 | In: $0.15, Out: $0.60, Cache: $0.08 |
| OpenAI: GPT-4o-mini Search Preview | openai/gpt-4o-mini-search-preview | openrouter | 128000 | 16384 | In: $0.15, Out: $0.60 |
| OpenAI: o1 | openai/o1 | openrouter | 200000 | 100000 | In: $15.00, Out: $60.00, Cache: $7.50 |
| OpenAI: o1-pro | openai/o1-pro | openrouter | 200000 | 100000 | In: $150.00, Out: $600.00 |
| OpenAI: o3 | openai/o3 | openrouter | 200000 | 100000 | In: $2.00, Out: $8.00, Cache: $0.50 |
| OpenAI: o3 Mini | openai/o3-mini | openrouter | 200000 | 100000 | In: $1.10, Out: $4.40, Cache: $0.55 |
| OpenAI: o3 Mini High | openai/o3-mini-high | openrouter | 200000 | 100000 | In: $1.10, Out: $4.40, Cache: $0.55 |
| OpenAI: o3 Pro | openai/o3-pro | openrouter | 200000 | 100000 | In: $20.00, Out: $80.00 |
| OpenAI: o4 Mini | openai/o4-mini | openrouter | 200000 | 100000 | In: $1.10, Out: $4.40, Cache: $0.28 |
| OpenAI: o4 Mini High | openai/o4-mini-high | openrouter | 200000 | 100000 | In: $1.10, Out: $4.40, Cache: $0.28 |
| Perplexity: R1 1776 | perplexity/r1-1776 | openrouter | 128000 | - | In: $2.00, Out: $8.00 |
| Qwen 2 72B Instruct | qwen/qwen-2-72b-instruct | openrouter | 32768 | 4096 | In: $0.90, Out: $0.90 |
| Qwen2.5 72B Instruct | qwen/qwen-2.5-72b-instruct | openrouter | 32768 | 16384 | In: $0.12, Out: $0.39 |
| Qwen2.5 7B Instruct | qwen/qwen-2.5-7b-instruct | openrouter | 32768 | 16384 | In: $0.04, Out: $0.10 |
| Qwen2.5 Coder 32B Instruct | qwen/qwen-2.5-coder-32b-instruct | openrouter | 32768 | 16384 | In: $0.06, Out: $0.15 |
| Qwen: QwQ 32B | qwen/qwq-32b | openrouter | 131072 | - | In: $0.08, Out: $0.15 |
| Qwen: QwQ 32B (free) | qwen/qwq-32b:free | openrouter | 32768 | - | - |
| Qwen: Qwen VL Max | qwen/qwen-vl-max | openrouter | 7500 | 1500 | In: $0.80, Out: $3.20 |
| Qwen: Qwen VL Plus | qwen/qwen-vl-plus | openrouter | 7500 | 1500 | In: $0.21, Out: $0.63 |
| Qwen: Qwen-Max  | qwen/qwen-max | openrouter | 32768 | 8192 | In: $1.60, Out: $6.40, Cache: $0.64 |
| Qwen: Qwen-Plus | qwen/qwen-plus | openrouter | 131072 | 8192 | In: $0.40, Out: $1.20, Cache: $0.16 |
| Qwen: Qwen-Turbo | qwen/qwen-turbo | openrouter | 1000000 | 8192 | In: $0.05, Out: $0.20, Cache: $0.02 |
| Qwen: Qwen2.5 VL 32B Instruct | qwen/qwen2.5-vl-32b-instruct | openrouter | 128000 | - | In: $0.20, Out: $0.60 |
| Qwen: Qwen2.5 VL 32B Instruct (free) | qwen/qwen2.5-vl-32b-instruct:free | openrouter | 8192 | - | - |
| Qwen: Qwen2.5 VL 72B Instruct | qwen/qwen2.5-vl-72b-instruct | openrouter | 32000 | - | In: $0.25, Out: $0.75 |
| Qwen: Qwen2.5 VL 72B Instruct (free) | qwen/qwen2.5-vl-72b-instruct:free | openrouter | 32768 | - | - |
| Qwen: Qwen3 14B | qwen/qwen3-14b | openrouter | 40960 | 40960 | In: $0.06, Out: $0.24 |
| Qwen: Qwen3 235B A22B | qwen/qwen3-235b-a22b | openrouter | 40960 | 40960 | In: $0.13, Out: $0.60 |
| Qwen: Qwen3 235B A22B (free) | qwen/qwen3-235b-a22b:free | openrouter | 131072 | - | - |
| Qwen: Qwen3 30B A3B | qwen/qwen3-30b-a3b | openrouter | 40960 | 40960 | In: $0.08, Out: $0.29 |
| Qwen: Qwen3 32B | qwen/qwen3-32b | openrouter | 40960 | - | In: $0.10, Out: $0.30 |
| Qwen: Qwen3 4B (free) | qwen/qwen3-4b:free | openrouter | 40960 | - | - |
| ReMM SLERP 13B | undi95/remm-slerp-l2-13b | openrouter | 6144 | - | In: $0.70, Out: $1.00 |
| Sao10K: Llama 3 8B Lunaris | sao10k/l3-lunaris-8b | openrouter | 8192 | - | In: $0.02, Out: $0.05 |
| Sao10K: Llama 3.1 Euryale 70B v2.2 | sao10k/l3.1-euryale-70b | openrouter | 32768 | - | In: $0.65, Out: $0.75 |
| Sao10K: Llama 3.3 Euryale 70B | sao10k/l3.3-euryale-70b | openrouter | 131072 | - | In: $0.65, Out: $0.75 |
| TheDrummer: Rocinante 12B | thedrummer/rocinante-12b | openrouter | 32768 | - | In: $0.20, Out: $0.50 |
| TheDrummer: Skyfall 36B V2 | thedrummer/skyfall-36b-v2 | openrouter | 32768 | - | In: $0.40, Out: $0.70 |
| TheDrummer: UnslopNemo 12B | thedrummer/unslopnemo-12b | openrouter | 32768 | - | In: $0.40, Out: $0.40 |
| TheDrummer: Valkyrie 49B V1 | thedrummer/valkyrie-49b-v1 | openrouter | 32768 | - | In: $0.60, Out: $0.80 |
| Typhoon2 70B Instruct | scb10x/llama3.1-typhoon2-70b-instruct | openrouter | 8192 | - | In: $0.88, Out: $0.88 |
| Venice: Uncensored (free) | cognitivecomputations/dolphin-mistral-24b-venice-edition:free | openrouter | 32768 | - | - |
| WizardLM-2 8x22B | microsoft/wizardlm-2-8x22b | openrouter | 65536 | 65536 | In: $0.48, Out: $0.48 |
| xAI: Grok 2 1212 | x-ai/grok-2-1212 | openrouter | 131072 | - | In: $2.00, Out: $10.00 |
| xAI: Grok 2 Vision 1212 | x-ai/grok-2-vision-1212 | openrouter | 32768 | - | In: $2.00, Out: $10.00 |
| xAI: Grok 3 | x-ai/grok-3 | openrouter | 131072 | - | In: $3.00, Out: $15.00, Cache: $0.75 |
| xAI: Grok 3 Beta | x-ai/grok-3-beta | openrouter | 131072 | - | In: $3.00, Out: $15.00, Cache: $0.75 |
| xAI: Grok 3 Mini | x-ai/grok-3-mini | openrouter | 131072 | - | In: $0.30, Out: $0.50, Cache: $0.08 |
| xAI: Grok 3 Mini Beta | x-ai/grok-3-mini-beta | openrouter | 131072 | - | In: $0.30, Out: $0.50, Cache: $0.08 |
| xAI: Grok 4 | x-ai/grok-4 | openrouter | 256000 | - | In: $3.00, Out: $15.00, Cache: $0.75 |
| xAI: Grok Vision Beta | x-ai/grok-vision-beta | openrouter | 8192 | - | In: $5.00, Out: $15.00 |


### Streaming (392)

| Model | ID | Provider | Context | Max Output | Standard Pricing (per 1M tokens) |
| :-- | :-- | :-- | --: | --: | :-- |
| Claude 2.0 | claude-2.0 | anthropic | 200000 | 4096 | In: $3.00, Out: $15.00 |
| Claude 2.1 | claude-2.1 | anthropic | 200000 | 4096 | In: $3.00, Out: $15.00 |
| Claude Sonnet 3 | claude-3-sonnet-20240229 | anthropic | 200000 | 4096 | In: $3.00, Out: $15.00 |
| Claude | anthropic.claude-v2 | bedrock | 200000 | 4096 | In: $8.00, Out: $24.00 |
| Claude | anthropic.claude-v2:0:100k | bedrock | 200000 | 4096 | In: $8.00, Out: $24.00 |
| Claude | anthropic.claude-v2:0:18k | bedrock | 200000 | 4096 | In: $8.00, Out: $24.00 |
| Claude | anthropic.claude-v2:1 | bedrock | 200000 | 4096 | In: $8.00, Out: $24.00 |
| Claude | anthropic.claude-v2:1:18k | bedrock | 200000 | 4096 | In: $8.00, Out: $24.00 |
| Claude | anthropic.claude-v2:1:200k | bedrock | 200000 | 4096 | In: $8.00, Out: $24.00 |
| Claude 3 Haiku | anthropic.claude-3-haiku-20240307-v1:0 | bedrock | 200000 | 4096 | In: $0.25, Out: $1.25 |
| Claude 3 Haiku | anthropic.claude-3-haiku-20240307-v1:0:200k | bedrock | 200000 | 4096 | In: $0.25, Out: $1.25 |
| Claude 3 Haiku | anthropic.claude-3-haiku-20240307-v1:0:48k | bedrock | 200000 | 4096 | In: $0.25, Out: $1.25 |
| Claude 3 Opus | anthropic.claude-3-opus-20240229-v1:0 | bedrock | 200000 | 4096 | In: $15.00, Out: $75.00 |
| Claude 3 Opus | anthropic.claude-3-opus-20240229-v1:0:12k | bedrock | 200000 | 4096 | In: $15.00, Out: $75.00 |
| Claude 3 Opus | anthropic.claude-3-opus-20240229-v1:0:200k | bedrock | 200000 | 4096 | In: $15.00, Out: $75.00 |
| Claude 3 Opus | anthropic.claude-3-opus-20240229-v1:0:28k | bedrock | 200000 | 4096 | In: $15.00, Out: $75.00 |
| Claude 3 Sonnet | anthropic.claude-3-sonnet-20240229-v1:0 | bedrock | 200000 | 4096 | In: $3.00, Out: $15.00 |
| Claude 3 Sonnet | anthropic.claude-3-sonnet-20240229-v1:0:200k | bedrock | 200000 | 4096 | In: $3.00, Out: $15.00 |
| Claude 3 Sonnet | anthropic.claude-3-sonnet-20240229-v1:0:28k | bedrock | 200000 | 4096 | In: $3.00, Out: $15.00 |
| Claude 3.5 Haiku | anthropic.claude-3-5-haiku-20241022-v1:0 | bedrock | 200000 | 4096 | In: $0.80, Out: $4.00 |
| Claude 3.5 Sonnet | anthropic.claude-3-5-sonnet-20240620-v1:0 | bedrock | 200000 | 4096 | In: $3.00, Out: $15.00 |
| Claude 3.5 Sonnet | anthropic.claude-3-5-sonnet-20240620-v1:0:18k | bedrock | 200000 | 4096 | In: $3.00, Out: $15.00 |
| Claude 3.5 Sonnet | anthropic.claude-3-5-sonnet-20240620-v1:0:200k | bedrock | 200000 | 4096 | In: $3.00, Out: $15.00 |
| Claude 3.5 Sonnet | anthropic.claude-3-5-sonnet-20240620-v1:0:51k | bedrock | 200000 | 4096 | In: $3.00, Out: $15.00 |
| Claude 3.5 Sonnet v2 | anthropic.claude-3-5-sonnet-20241022-v2:0 | bedrock | 200000 | 4096 | In: $3.00, Out: $15.00 |
| Claude 3.5 Sonnet v2 | anthropic.claude-3-5-sonnet-20241022-v2:0:18k | bedrock | 200000 | 4096 | In: $3.00, Out: $15.00 |
| Claude 3.5 Sonnet v2 | anthropic.claude-3-5-sonnet-20241022-v2:0:200k | bedrock | 200000 | 4096 | In: $3.00, Out: $15.00 |
| Claude 3.5 Sonnet v2 | anthropic.claude-3-5-sonnet-20241022-v2:0:51k | bedrock | 200000 | 4096 | In: $3.00, Out: $15.00 |
| Claude 3.7 Sonnet | us.anthropic.claude-3-7-sonnet-20250219-v1:0 | bedrock | 200000 | 4096 | In: $3.00, Out: $15.00 |
| Claude Instant | anthropic.claude-instant-v1 | bedrock | 200000 | 4096 | In: $0.80, Out: $2.40 |
| Claude Instant | anthropic.claude-instant-v1:2:100k | bedrock | 200000 | 4096 | In: $0.80, Out: $2.40 |
| Claude Opus 4 | us.anthropic.claude-opus-4-20250514-v1:0 | bedrock | 200000 | 4096 | In: $0.10, Out: $0.20 |
| Claude Sonnet 4 | us.anthropic.claude-sonnet-4-20250514-v1:0 | bedrock | 200000 | 4096 | In: $0.10, Out: $0.20 |
| Embedding 001 | embedding-001 | gemini | 2048 | 1 | - |
| Embedding Gecko | embedding-gecko-001 | gemini | 1024 | 1 | - |
| Gemini 1.0 Pro Vision | gemini-1.0-pro-vision-latest | gemini | 12288 | 4096 | In: $0.08, Out: $0.30 |
| Gemini 1.0 Pro Vision | gemini-pro-vision | gemini | 12288 | 4096 | In: $0.08, Out: $0.30 |
| Gemini 2.0 Flash-Lite Preview | gemini-2.0-flash-lite-preview | gemini | 1048576 | 8192 | In: $0.08, Out: $0.30 |
| Gemini 2.0 Flash-Lite Preview 02-05 | gemini-2.0-flash-lite-preview-02-05 | gemini | 1048576 | 8192 | In: $0.08, Out: $0.30 |
| Gemini 2.0 Pro Experimental | gemini-2.0-pro-exp | gemini | 1048576 | 65536 | In: $0.08, Out: $0.30 |
| Gemini 2.0 Pro Experimental 02-05 | gemini-2.0-pro-exp-02-05 | gemini | 1048576 | 65536 | In: $0.08, Out: $0.30 |
| Gemini 2.5 Flash Preview 05-20 | gemini-2.0-flash-thinking-exp | gemini | 1048576 | 65536 | In: $0.10, Out: $0.40 |
| Gemini 2.5 Flash Preview 05-20 | gemini-2.0-flash-thinking-exp-01-21 | gemini | 1048576 | 65536 | In: $0.10, Out: $0.40 |
| Gemini 2.5 Flash Preview 05-20 | gemini-2.0-flash-thinking-exp-1219 | gemini | 1048576 | 65536 | In: $0.10, Out: $0.40 |
| Gemini Embedding Experimental | gemini-embedding-exp | gemini | 8192 | 1 | In: $0.00, Out: $0.00 |
| Gemini Experimental 1206 | gemini-exp-1206 | gemini | 1048576 | 65536 | In: $0.08, Out: $0.30 |
| Gemma 3 12B | gemma-3-12b-it | gemini | 32768 | 8192 | In: $0.08, Out: $0.30 |
| Gemma 3 1B | gemma-3-1b-it | gemini | 32768 | 8192 | In: $0.08, Out: $0.30 |
| Gemma 3 27B | gemma-3-27b-it | gemini | 131072 | 8192 | In: $0.08, Out: $0.30 |
| Gemma 3 4B | gemma-3-4b-it | gemini | 32768 | 8192 | In: $0.08, Out: $0.30 |
| Gemma 3n E2B | gemma-3n-e2b-it | gemini | 8192 | 2048 | In: $0.08, Out: $0.30 |
| Gemma 3n E4B | gemma-3n-e4b-it | gemini | 8192 | 2048 | In: $0.08, Out: $0.30 |
| LearnLM 2.0 Flash Experimental | learnlm-2.0-flash-experimental | gemini | 1048576 | 32768 | In: $0.08, Out: $0.30 |
| GPT-3.5 Turbo 0125 | gpt-3.5-turbo-0125 | openai | 16385 | 4096 | In: $0.50, Out: $1.50 |
| GPT-3.5 Turbo 1106 | gpt-3.5-turbo-1106 | openai | 16385 | 4096 | In: $0.50, Out: $1.50 |
| GPT-3.5 Turbo 16k | gpt-3.5-turbo-16k | openai | 16385 | 4096 | In: $0.50, Out: $1.50 |
| GPT-3.5 Turbo Instruct | gpt-3.5-turbo-instruct | openai | 16385 | 4096 | In: $0.50, Out: $1.50 |
| GPT-3.5 Turbo Instruct 0914 | gpt-3.5-turbo-instruct-0914 | openai | 16385 | 4096 | In: $0.50, Out: $1.50 |
| GPT-4 0125 Preview | gpt-4-0125-preview | openai | 4096 | 16384 | In: $0.50, Out: $1.50 |
| GPT-4 1106 Preview | gpt-4-1106-preview | openai | 4096 | 16384 | In: $0.50, Out: $1.50 |
| GPT-4 Turbo Preview | gpt-4-turbo-preview | openai | 128000 | 4096 | In: $10.00, Out: $30.00 |
| GPT-4o 20240513 | gpt-4o-2024-05-13 | openai | 128000 | 16384 | In: $2.50, Out: $10.00 |
| GPT-4o 20241120 | gpt-4o-2024-11-20 | openai | 128000 | 16384 | In: $2.50, Out: $10.00 |
| GPT-4o-Audio Preview 20241001 | gpt-4o-audio-preview-2024-10-01 | openai | 128000 | 16384 | In: $2.50, Out: $10.00 |
| GPT-4o-Audio Preview 20241217 | gpt-4o-audio-preview-2024-12-17 | openai | 128000 | 16384 | In: $2.50, Out: $10.00 |
| GPT-4o-Audio Preview 20250603 | gpt-4o-audio-preview-2025-06-03 | openai | 128000 | 16384 | In: $2.50, Out: $10.00 |
| GPT-4o-Realtime Preview 20241001 | gpt-4o-realtime-preview-2024-10-01 | openai | 128000 | 4096 | In: $5.00, Out: $20.00 |
| GPT-4o-Realtime Preview 20241217 | gpt-4o-realtime-preview-2024-12-17 | openai | 128000 | 4096 | In: $5.00, Out: $20.00 |
| GPT-4o-Realtime Preview 20250603 | gpt-4o-realtime-preview-2025-06-03 | openai | 128000 | 4096 | In: $5.00, Out: $20.00 |
| O1-Preview | o1-preview | openai | 200000 | 100000 | In: $15.00, Out: $60.00 |
| O1-Preview 20240912 | o1-preview-2024-09-12 | openai | 200000 | 100000 | In: $15.00, Out: $60.00 |
| TTS-1 1106 | tts-1-1106 | openai | - | - | In: $15.00, Out: $15.00 |
| TTS-1 HD 1106 | tts-1-hd-1106 | openai | - | - | In: $30.00, Out: $30.00 |
| 01.AI: Yi Large | 01-ai/yi-large | openrouter | 32768 | 4096 | In: $3.00, Out: $3.00 |
| AI21: Jamba 1.6 Large | ai21/jamba-1.6-large | openrouter | 256000 | 4096 | In: $2.00, Out: $8.00 |
| AI21: Jamba Mini 1.6 | ai21/jamba-1.6-mini | openrouter | 256000 | 4096 | In: $0.20, Out: $0.40 |
| Aetherwiing: Starcannon 12B | aetherwiing/mn-starcannon-12b | openrouter | 16384 | 4096 | In: $0.80, Out: $1.20 |
| Agentica: Deepcoder 14B Preview | agentica-org/deepcoder-14b-preview | openrouter | 96000 | - | In: $0.02, Out: $0.02 |
| Agentica: Deepcoder 14B Preview (free) | agentica-org/deepcoder-14b-preview:free | openrouter | 96000 | - | - |
| AionLabs: Aion-1.0 | aion-labs/aion-1.0 | openrouter | 131072 | 32768 | In: $4.00, Out: $8.00 |
| AionLabs: Aion-1.0-Mini | aion-labs/aion-1.0-mini | openrouter | 131072 | 32768 | In: $0.70, Out: $1.40 |
| AionLabs: Aion-RP 1.0 (8B) | aion-labs/aion-rp-llama-3.1-8b | openrouter | 32768 | 32768 | In: $0.20, Out: $0.20 |
| AlfredPros: CodeLLaMa 7B Instruct Solidity | alfredpros/codellama-7b-instruct-solidity | openrouter | 4096 | 4096 | In: $0.80, Out: $1.20 |
| Amazon: Nova Lite 1.0 | amazon/nova-lite-v1 | openrouter | 300000 | 5120 | In: $0.06, Out: $0.24 |
| Amazon: Nova Micro 1.0 | amazon/nova-micro-v1 | openrouter | 128000 | 5120 | In: $0.04, Out: $0.14 |
| Amazon: Nova Pro 1.0 | amazon/nova-pro-v1 | openrouter | 300000 | 5120 | In: $0.80, Out: $3.20 |
| Anthropic: Claude 3 Haiku | anthropic/claude-3-haiku | openrouter | 200000 | 4096 | In: $0.25, Out: $1.25, Cache: $0.03 |
| Anthropic: Claude 3 Haiku (self-moderated) | anthropic/claude-3-haiku:beta | openrouter | 200000 | 4096 | In: $0.25, Out: $1.25, Cache: $0.03 |
| Anthropic: Claude 3 Opus | anthropic/claude-3-opus | openrouter | 200000 | 4096 | In: $15.00, Out: $75.00, Cache: $1.50 |
| Anthropic: Claude 3 Opus (self-moderated) | anthropic/claude-3-opus:beta | openrouter | 200000 | 4096 | In: $15.00, Out: $75.00, Cache: $1.50 |
| Anthropic: Claude 3 Sonnet | anthropic/claude-3-sonnet | openrouter | 200000 | 4096 | In: $3.00, Out: $15.00, Cache: $0.30 |
| Anthropic: Claude 3 Sonnet (self-moderated) | anthropic/claude-3-sonnet:beta | openrouter | 200000 | 4096 | In: $3.00, Out: $15.00, Cache: $0.30 |
| Anthropic: Claude 3.5 Haiku | anthropic/claude-3.5-haiku | openrouter | 200000 | 8192 | In: $0.80, Out: $4.00, Cache: $0.08 |
| Anthropic: Claude 3.5 Haiku (2024-10-22) | anthropic/claude-3.5-haiku-20241022 | openrouter | 200000 | 8192 | In: $0.80, Out: $4.00, Cache: $0.08 |
| Anthropic: Claude 3.5 Haiku (2024-10-22) (self-moderated) | anthropic/claude-3.5-haiku-20241022:beta | openrouter | 200000 | 8192 | In: $0.80, Out: $4.00, Cache: $0.08 |
| Anthropic: Claude 3.5 Haiku (self-moderated) | anthropic/claude-3.5-haiku:beta | openrouter | 200000 | 8192 | In: $0.80, Out: $4.00, Cache: $0.08 |
| Anthropic: Claude 3.5 Sonnet | anthropic/claude-3.5-sonnet | openrouter | 200000 | 8192 | In: $3.00, Out: $15.00, Cache: $0.30 |
| Anthropic: Claude 3.5 Sonnet (2024-06-20) | anthropic/claude-3.5-sonnet-20240620 | openrouter | 200000 | 8192 | In: $3.00, Out: $15.00, Cache: $0.30 |
| Anthropic: Claude 3.5 Sonnet (2024-06-20) (self-moderated) | anthropic/claude-3.5-sonnet-20240620:beta | openrouter | 200000 | 8192 | In: $3.00, Out: $15.00, Cache: $0.30 |
| Anthropic: Claude 3.5 Sonnet (self-moderated) | anthropic/claude-3.5-sonnet:beta | openrouter | 200000 | 8192 | In: $3.00, Out: $15.00, Cache: $0.30 |
| Anthropic: Claude 3.7 Sonnet | anthropic/claude-3.7-sonnet | openrouter | 200000 | 64000 | In: $3.00, Out: $15.00, Cache: $0.30 |
| Anthropic: Claude 3.7 Sonnet (self-moderated) | anthropic/claude-3.7-sonnet:beta | openrouter | 200000 | 128000 | In: $3.00, Out: $15.00, Cache: $0.30 |
| Anthropic: Claude 3.7 Sonnet (thinking) | anthropic/claude-3.7-sonnet:thinking | openrouter | 200000 | 64000 | In: $3.00, Out: $15.00, Cache: $0.30 |
| Anthropic: Claude Opus 4 | anthropic/claude-opus-4 | openrouter | 200000 | 32000 | In: $15.00, Out: $75.00, Cache: $1.50 |
| Anthropic: Claude Sonnet 4 | anthropic/claude-sonnet-4 | openrouter | 200000 | 64000 | In: $3.00, Out: $15.00, Cache: $0.30 |
| Anthropic: Claude v2 | anthropic/claude-2 | openrouter | 200000 | 4096 | In: $8.00, Out: $24.00 |
| Anthropic: Claude v2 (self-moderated) | anthropic/claude-2:beta | openrouter | 200000 | 4096 | In: $8.00, Out: $24.00 |
| Anthropic: Claude v2.0 | anthropic/claude-2.0 | openrouter | 100000 | 4096 | In: $8.00, Out: $24.00 |
| Anthropic: Claude v2.0 (self-moderated) | anthropic/claude-2.0:beta | openrouter | 100000 | 4096 | In: $8.00, Out: $24.00 |
| Anthropic: Claude v2.1 | anthropic/claude-2.1 | openrouter | 200000 | 4096 | In: $8.00, Out: $24.00 |
| Anthropic: Claude v2.1 (self-moderated) | anthropic/claude-2.1:beta | openrouter | 200000 | 4096 | In: $8.00, Out: $24.00 |
| Arcee AI: Arcee Blitz | arcee-ai/arcee-blitz | openrouter | 32768 | - | In: $0.45, Out: $0.75 |
| Arcee AI: Caller Large | arcee-ai/caller-large | openrouter | 32768 | - | In: $0.55, Out: $0.85 |
| Arcee AI: Coder Large | arcee-ai/coder-large | openrouter | 32768 | - | In: $0.50, Out: $0.80 |
| Arcee AI: Maestro Reasoning | arcee-ai/maestro-reasoning | openrouter | 131072 | 32000 | In: $0.90, Out: $3.30 |
| Arcee AI: Spotlight | arcee-ai/spotlight | openrouter | 131072 | 65537 | In: $0.18, Out: $0.18 |
| Arcee AI: Virtuoso Large | arcee-ai/virtuoso-large | openrouter | 131072 | 64000 | In: $0.75, Out: $1.20 |
| Arcee AI: Virtuoso Medium V2 | arcee-ai/virtuoso-medium-v2 | openrouter | 131072 | 32768 | In: $0.50, Out: $0.80 |
| ArliAI: QwQ 32B RpR v1 (free) | arliai/qwq-32b-arliai-rpr-v1:free | openrouter | 32768 | - | - |
| Auto Router | openrouter/auto | openrouter | 2000000 | - | - |
| Baidu: ERNIE 4.5 300B A47B  | baidu/ernie-4.5-300b-a47b | openrouter | 123000 | 12000 | In: $0.28, Out: $1.10 |
| Cohere: Command | cohere/command | openrouter | 4096 | 4000 | In: $1.00, Out: $2.00 |
| Cohere: Command A | cohere/command-a | openrouter | 256000 | 8192 | In: $2.50, Out: $10.00 |
| Cohere: Command R | cohere/command-r | openrouter | 128000 | 4000 | In: $0.50, Out: $1.50 |
| Cohere: Command R (03-2024) | cohere/command-r-03-2024 | openrouter | 128000 | 4000 | In: $0.50, Out: $1.50 |
| Cohere: Command R (08-2024) | cohere/command-r-08-2024 | openrouter | 128000 | 4000 | In: $0.15, Out: $0.60 |
| Cohere: Command R+ | cohere/command-r-plus | openrouter | 128000 | 4000 | In: $3.00, Out: $15.00 |
| Cohere: Command R+ (04-2024) | cohere/command-r-plus-04-2024 | openrouter | 128000 | 4000 | In: $3.00, Out: $15.00 |
| Cohere: Command R+ (08-2024) | cohere/command-r-plus-08-2024 | openrouter | 128000 | 4000 | In: $2.50, Out: $10.00 |
| Cohere: Command R7B (12-2024) | cohere/command-r7b-12-2024 | openrouter | 128000 | 4000 | In: $0.04, Out: $0.15 |
| DeepSeek: DeepSeek Prover V2 | deepseek/deepseek-prover-v2 | openrouter | 163840 | - | In: $0.50, Out: $2.18 |
| DeepSeek: DeepSeek V3 | deepseek/deepseek-chat | openrouter | 163840 | 163840 | In: $0.30, Out: $0.85 |
| DeepSeek: DeepSeek V3 (free) | deepseek/deepseek-chat:free | openrouter | 163840 | - | - |
| DeepSeek: DeepSeek V3 0324 | deepseek/deepseek-chat-v3-0324 | openrouter | 163840 | 163840 | In: $0.25, Out: $0.85 |
| DeepSeek: DeepSeek V3 0324 (free) | deepseek/deepseek-chat-v3-0324:free | openrouter | 32768 | 16384 | - |
| DeepSeek: DeepSeek V3 Base (free) | deepseek/deepseek-v3-base:free | openrouter | 163840 | - | - |
| DeepSeek: Deepseek R1 0528 Qwen3 8B | deepseek/deepseek-r1-0528-qwen3-8b | openrouter | 32000 | - | In: $0.01, Out: $0.02 |
| DeepSeek: Deepseek R1 0528 Qwen3 8B (free) | deepseek/deepseek-r1-0528-qwen3-8b:free | openrouter | 131072 | - | - |
| DeepSeek: R1 | deepseek/deepseek-r1 | openrouter | 163840 | 163840 | In: $0.40, Out: $2.00 |
| DeepSeek: R1 (free) | deepseek/deepseek-r1:free | openrouter | 163840 | - | - |
| DeepSeek: R1 0528 | deepseek/deepseek-r1-0528 | openrouter | 163840 | - | In: $0.27, Out: $0.27 |
| DeepSeek: R1 0528 (free) | deepseek/deepseek-r1-0528:free | openrouter | 163840 | - | - |
| DeepSeek: R1 Distill Llama 70B | deepseek/deepseek-r1-distill-llama-70b | openrouter | 131072 | - | In: $0.05, Out: $0.05 |
| DeepSeek: R1 Distill Llama 70B (free) | deepseek/deepseek-r1-distill-llama-70b:free | openrouter | 8192 | 4096 | - |
| DeepSeek: R1 Distill Llama 8B | deepseek/deepseek-r1-distill-llama-8b | openrouter | 32000 | 32000 | In: $0.04, Out: $0.04 |
| DeepSeek: R1 Distill Qwen 1.5B | deepseek/deepseek-r1-distill-qwen-1.5b | openrouter | 131072 | 32768 | In: $0.18, Out: $0.18 |
| DeepSeek: R1 Distill Qwen 14B | deepseek/deepseek-r1-distill-qwen-14b | openrouter | 64000 | 32000 | In: $0.15, Out: $0.15 |
| DeepSeek: R1 Distill Qwen 14B (free) | deepseek/deepseek-r1-distill-qwen-14b:free | openrouter | 64000 | - | - |
| DeepSeek: R1 Distill Qwen 32B | deepseek/deepseek-r1-distill-qwen-32b | openrouter | 131072 | 16384 | In: $0.08, Out: $0.15 |
| DeepSeek: R1 Distill Qwen 7B | deepseek/deepseek-r1-distill-qwen-7b | openrouter | 131072 | - | In: $0.10, Out: $0.20 |
| Dolphin 2.9.2 Mixtral 8x22B 🐬 | cognitivecomputations/dolphin-mixtral-8x22b | openrouter | 16000 | 8192 | In: $0.90, Out: $0.90 |
| Dolphin3.0 Mistral 24B (free) | cognitivecomputations/dolphin3.0-mistral-24b:free | openrouter | 32768 | - | - |
| Dolphin3.0 R1 Mistral 24B | cognitivecomputations/dolphin3.0-r1-mistral-24b | openrouter | 32768 | - | In: $0.01, Out: $0.01 |
| Dolphin3.0 R1 Mistral 24B (free) | cognitivecomputations/dolphin3.0-r1-mistral-24b:free | openrouter | 32768 | - | - |
| EVA Llama 3.33 70B | eva-unit-01/eva-llama-3.33-70b | openrouter | 16384 | 4096 | In: $4.00, Out: $6.00 |
| EVA Qwen2.5 72B | eva-unit-01/eva-qwen-2.5-72b | openrouter | 16384 | 4096 | In: $4.00, Out: $6.00 |
| EleutherAI: Llemma 7b | eleutherai/llemma_7b | openrouter | 4096 | 4096 | In: $0.80, Out: $1.20 |
| Fimbulvetr 11B v2 | sao10k/fimbulvetr-11b-v2 | openrouter | 4096 | 4096 | In: $0.80, Out: $1.20 |
| Goliath 120B | alpindale/goliath-120b | openrouter | 6144 | - | In: $9.00, Out: $11.00 |
| Google: Gemini 1.5 Flash  | google/gemini-flash-1.5 | openrouter | 1000000 | 8192 | In: $0.08, Out: $0.30, Cache: $0.02 |
| Google: Gemini 1.5 Flash 8B | google/gemini-flash-1.5-8b | openrouter | 1000000 | 8192 | In: $0.04, Out: $0.15, Cache: $0.01 |
| Google: Gemini 1.5 Pro | google/gemini-pro-1.5 | openrouter | 2000000 | 8192 | In: $1.25, Out: $5.00 |
| Google: Gemini 2.0 Flash | google/gemini-2.0-flash-001 | openrouter | 1048576 | 8192 | In: $0.10, Out: $0.40, Cache: $0.02 |
| Google: Gemini 2.0 Flash Experimental (free) | google/gemini-2.0-flash-exp:free | openrouter | 1048576 | 8192 | - |
| Google: Gemini 2.0 Flash Lite | google/gemini-2.0-flash-lite-001 | openrouter | 1048576 | 8192 | In: $0.08, Out: $0.30 |
| Google: Gemini 2.5 Flash | google/gemini-2.5-flash | openrouter | 1048576 | 65535 | In: $0.30, Out: $2.50, Cache: $0.08 |
| Google: Gemini 2.5 Flash Lite Preview 06-17 | google/gemini-2.5-flash-lite-preview-06-17 | openrouter | 1048576 | 65535 | In: $0.10, Out: $0.40, Cache: $0.02 |
| Google: Gemini 2.5 Pro | google/gemini-2.5-pro | openrouter | 1048576 | 65536 | In: $1.25, Out: $10.00, Cache: $0.31 |
| Google: Gemini 2.5 Pro Experimental | google/gemini-2.5-pro-exp-03-25 | openrouter | 1048576 | 65535 | - |
| Google: Gemini 2.5 Pro Preview 05-06 | google/gemini-2.5-pro-preview-05-06 | openrouter | 1048576 | 65535 | In: $1.25, Out: $10.00, Cache: $0.31 |
| Google: Gemini 2.5 Pro Preview 06-05 | google/gemini-2.5-pro-preview | openrouter | 1048576 | 65536 | In: $1.25, Out: $10.00, Cache: $0.31 |
| Google: Gemma 2 27B | google/gemma-2-27b-it | openrouter | 8192 | 2048 | In: $0.80, Out: $0.80 |
| Google: Gemma 2 9B | google/gemma-2-9b-it | openrouter | 8192 | 8192 | In: $0.00, Out: $0.00 |
| Google: Gemma 2 9B (free) | google/gemma-2-9b-it:free | openrouter | 8192 | 8192 | - |
| Google: Gemma 3 12B | google/gemma-3-12b-it | openrouter | 96000 | 8192 | In: $0.03, Out: $0.03 |
| Google: Gemma 3 12B (free) | google/gemma-3-12b-it:free | openrouter | 96000 | 8192 | - |
| Google: Gemma 3 27B | google/gemma-3-27b-it | openrouter | 131072 | 16384 | In: $0.09, Out: $0.17 |
| Google: Gemma 3 27B (free) | google/gemma-3-27b-it:free | openrouter | 96000 | 8192 | - |
| Google: Gemma 3 4B | google/gemma-3-4b-it | openrouter | 131072 | - | In: $0.02, Out: $0.04 |
| Google: Gemma 3 4B (free) | google/gemma-3-4b-it:free | openrouter | 32768 | 8192 | - |
| Google: Gemma 3n 2B (free) | google/gemma-3n-e2b-it:free | openrouter | 8192 | 2048 | - |
| Google: Gemma 3n 4B | google/gemma-3n-e4b-it | openrouter | 32768 | - | In: $0.02, Out: $0.04 |
| Google: Gemma 3n 4B (free) | google/gemma-3n-e4b-it:free | openrouter | 8192 | 2048 | - |
| Inception: Mercury | inception/mercury | openrouter | 32000 | 16000 | In: $0.25, Out: $1.00 |
| Inception: Mercury Coder | inception/mercury-coder | openrouter | 32000 | - | In: $0.25, Out: $1.00 |
| Infermatic: Mistral Nemo Inferor 12B | infermatic/mn-inferor-12b | openrouter | 16384 | 4096 | In: $0.80, Out: $1.20 |
| Inflection: Inflection 3 Pi | inflection/inflection-3-pi | openrouter | 8000 | 1024 | In: $2.50, Out: $10.00 |
| Inflection: Inflection 3 Productivity | inflection/inflection-3-productivity | openrouter | 8000 | 1024 | In: $2.50, Out: $10.00 |
| Kimi Dev 72b (free) | moonshotai/kimi-dev-72b:free | openrouter | 131072 | - | - |
| Liquid: LFM 3B | liquid/lfm-3b | openrouter | 32768 | - | In: $0.02, Out: $0.02 |
| Liquid: LFM 40B MoE | liquid/lfm-40b | openrouter | 32768 | - | In: $0.15, Out: $0.15 |
| Liquid: LFM 7B | liquid/lfm-7b | openrouter | 32768 | - | In: $0.01, Out: $0.01 |
| Llama Guard 3 8B | meta-llama/llama-guard-3-8b | openrouter | 131072 | - | In: $0.02, Out: $0.06 |
| Magnum 72B | alpindale/magnum-72b | openrouter | 16384 | 4096 | In: $4.00, Out: $6.00 |
| Magnum v2 72B | anthracite-org/magnum-v2-72b | openrouter | 32768 | - | In: $3.00, Out: $3.00 |
| Magnum v4 72B | anthracite-org/magnum-v4-72b | openrouter | 16384 | 1024 | In: $2.50, Out: $3.00 |
| Mancer: Weaver (alpha) | mancer/weaver | openrouter | 8000 | 1000 | In: $1.50, Out: $1.50 |
| Meta: Llama 3 70B Instruct | meta-llama/llama-3-70b-instruct | openrouter | 8192 | 16384 | In: $0.30, Out: $0.40 |
| Meta: Llama 3 8B Instruct | meta-llama/llama-3-8b-instruct | openrouter | 8192 | 16384 | In: $0.03, Out: $0.06 |
| Meta: Llama 3.1 405B (base) | meta-llama/llama-3.1-405b | openrouter | 32768 | - | In: $2.00, Out: $2.00 |
| Meta: Llama 3.1 405B Instruct | meta-llama/llama-3.1-405b-instruct | openrouter | 32768 | 16384 | In: $0.80, Out: $0.80 |
| Meta: Llama 3.1 405B Instruct (free) | meta-llama/llama-3.1-405b-instruct:free | openrouter | 65536 | - | - |
| Meta: Llama 3.1 70B Instruct | meta-llama/llama-3.1-70b-instruct | openrouter | 131072 | 16384 | In: $0.10, Out: $0.28 |
| Meta: Llama 3.1 8B Instruct | meta-llama/llama-3.1-8b-instruct | openrouter | 131000 | 131000 | In: $0.02, Out: $0.02 |
| Meta: Llama 3.2 11B Vision Instruct | meta-llama/llama-3.2-11b-vision-instruct | openrouter | 131072 | 16384 | In: $0.05, Out: $0.05 |
| Meta: Llama 3.2 11B Vision Instruct (free) | meta-llama/llama-3.2-11b-vision-instruct:free | openrouter | 131072 | 2048 | - |
| Meta: Llama 3.2 1B Instruct | meta-llama/llama-3.2-1b-instruct | openrouter | 131072 | 16384 | In: $0.01, Out: $0.01 |
| Meta: Llama 3.2 3B Instruct | meta-llama/llama-3.2-3b-instruct | openrouter | 20000 | 20000 | In: $0.00, Out: $0.01 |
| Meta: Llama 3.2 3B Instruct (free) | meta-llama/llama-3.2-3b-instruct:free | openrouter | 131072 | - | - |
| Meta: Llama 3.2 90B Vision Instruct | meta-llama/llama-3.2-90b-vision-instruct | openrouter | 131072 | 2048 | In: $1.20, Out: $1.20 |
| Meta: Llama 3.3 70B Instruct | meta-llama/llama-3.3-70b-instruct | openrouter | 131072 | 16384 | In: $0.04, Out: $0.12 |
| Meta: Llama 3.3 70B Instruct (free) | meta-llama/llama-3.3-70b-instruct:free | openrouter | 65536 | - | - |
| Meta: Llama 4 Maverick | meta-llama/llama-4-maverick | openrouter | 1048576 | 16384 | In: $0.15, Out: $0.60 |
| Meta: Llama 4 Scout | meta-llama/llama-4-scout | openrouter | 1048576 | 1048576 | In: $0.08, Out: $0.30 |
| Meta: Llama Guard 4 12B | meta-llama/llama-guard-4-12b | openrouter | 163840 | - | In: $0.05, Out: $0.05 |
| Meta: LlamaGuard 2 8B | meta-llama/llama-guard-2-8b | openrouter | 8192 | - | In: $0.20, Out: $0.20 |
| Microsoft: MAI DS R1 (free) | microsoft/mai-ds-r1:free | openrouter | 163840 | - | - |
| Microsoft: Phi 4 | microsoft/phi-4 | openrouter | 16384 | 16384 | In: $0.07, Out: $0.14 |
| Microsoft: Phi 4 Multimodal Instruct | microsoft/phi-4-multimodal-instruct | openrouter | 131072 | - | In: $0.05, Out: $0.10 |
| Microsoft: Phi 4 Reasoning Plus | microsoft/phi-4-reasoning-plus | openrouter | 32768 | - | In: $0.07, Out: $0.35 |
| Microsoft: Phi-3 Medium 128K Instruct | microsoft/phi-3-medium-128k-instruct | openrouter | 128000 | - | In: $1.00, Out: $1.00 |
| Microsoft: Phi-3 Mini 128K Instruct | microsoft/phi-3-mini-128k-instruct | openrouter | 128000 | - | In: $0.10, Out: $0.10 |
| Microsoft: Phi-3.5 Mini 128K Instruct | microsoft/phi-3.5-mini-128k-instruct | openrouter | 128000 | - | In: $0.10, Out: $0.10 |
| Midnight Rose 70B | sophosympatheia/midnight-rose-70b | openrouter | 4096 | 2048 | In: $0.80, Out: $0.80 |
| MiniMax: MiniMax M1 | minimax/minimax-m1 | openrouter | 1000000 | 40000 | In: $0.30, Out: $1.65 |
| MiniMax: MiniMax-01 | minimax/minimax-01 | openrouter | 1000192 | 1000192 | In: $0.20, Out: $1.10 |
| Mistral Large | mistralai/mistral-large | openrouter | 128000 | - | In: $2.00, Out: $6.00 |
| Mistral Large 2407 | mistralai/mistral-large-2407 | openrouter | 131072 | - | In: $2.00, Out: $6.00 |
| Mistral Large 2411 | mistralai/mistral-large-2411 | openrouter | 131072 | - | In: $2.00, Out: $6.00 |
| Mistral Nemo 12B Celeste | nothingiisreal/mn-celeste-12b | openrouter | 16384 | 4096 | In: $0.80, Out: $1.20 |
| Mistral Small | mistralai/mistral-small | openrouter | 32768 | - | In: $0.20, Out: $0.60 |
| Mistral Tiny | mistralai/mistral-tiny | openrouter | 32768 | - | In: $0.25, Out: $0.25 |
| Mistral: Codestral 2501 | mistralai/codestral-2501 | openrouter | 262144 | - | In: $0.30, Out: $0.90 |
| Mistral: Devstral Medium | mistralai/devstral-medium | openrouter | 131072 | - | In: $0.40, Out: $2.00 |
| Mistral: Devstral Small 1.1 | mistralai/devstral-small | openrouter | 128000 | - | In: $0.07, Out: $0.28 |
| Mistral: Devstral Small 2505 | mistralai/devstral-small-2505 | openrouter | 32768 | - | In: $0.03, Out: $0.03 |
| Mistral: Devstral Small 2505 (free) | mistralai/devstral-small-2505:free | openrouter | 32768 | - | - |
| Mistral: Magistral Medium 2506 | mistralai/magistral-medium-2506 | openrouter | 40960 | 40000 | In: $2.00, Out: $5.00 |
| Mistral: Magistral Medium 2506 (thinking) | mistralai/magistral-medium-2506:thinking | openrouter | 40960 | 40000 | In: $2.00, Out: $5.00 |
| Mistral: Magistral Small 2506 | mistralai/magistral-small-2506 | openrouter | 40960 | 40960 | In: $0.10, Out: $0.30 |
| Mistral: Ministral 3B | mistralai/ministral-3b | openrouter | 131072 | - | In: $0.04, Out: $0.04 |
| Mistral: Ministral 8B | mistralai/ministral-8b | openrouter | 128000 | - | In: $0.10, Out: $0.10 |
| Mistral: Mistral 7B Instruct | mistralai/mistral-7b-instruct | openrouter | 32768 | 16384 | In: $0.03, Out: $0.05 |
| Mistral: Mistral 7B Instruct (free) | mistralai/mistral-7b-instruct:free | openrouter | 32768 | 16384 | - |
| Mistral: Mistral 7B Instruct v0.1 | mistralai/mistral-7b-instruct-v0.1 | openrouter | 2824 | - | In: $0.11, Out: $0.19 |
| Mistral: Mistral 7B Instruct v0.2 | mistralai/mistral-7b-instruct-v0.2 | openrouter | 32768 | - | In: $0.20, Out: $0.20 |
| Mistral: Mistral 7B Instruct v0.3 | mistralai/mistral-7b-instruct-v0.3 | openrouter | 32768 | 16384 | In: $0.03, Out: $0.05 |
| Mistral: Mistral Medium 3 | mistralai/mistral-medium-3 | openrouter | 131072 | - | In: $0.40, Out: $2.00 |
| Mistral: Mistral Nemo | mistralai/mistral-nemo | openrouter | 32000 | - | In: $0.01, Out: $0.05 |
| Mistral: Mistral Nemo (free) | mistralai/mistral-nemo:free | openrouter | 131072 | 128000 | - |
| Mistral: Mistral Small 3 | mistralai/mistral-small-24b-instruct-2501 | openrouter | 32768 | - | In: $0.03, Out: $0.03 |
| Mistral: Mistral Small 3 (free) | mistralai/mistral-small-24b-instruct-2501:free | openrouter | 32768 | - | - |
| Mistral: Mistral Small 3.1 24B | mistralai/mistral-small-3.1-24b-instruct | openrouter | 128000 | - | In: $0.05, Out: $0.10 |
| Mistral: Mistral Small 3.1 24B (free) | mistralai/mistral-small-3.1-24b-instruct:free | openrouter | 128000 | - | - |
| Mistral: Mistral Small 3.2 24B | mistralai/mistral-small-3.2-24b-instruct | openrouter | 128000 | - | In: $0.05, Out: $0.10 |
| Mistral: Mistral Small 3.2 24B (free) | mistralai/mistral-small-3.2-24b-instruct:free | openrouter | 96000 | - | - |
| Mistral: Mixtral 8x22B Instruct | mistralai/mixtral-8x22b-instruct | openrouter | 65536 | - | In: $0.90, Out: $0.90 |
| Mistral: Mixtral 8x7B Instruct | mistralai/mixtral-8x7b-instruct | openrouter | 32768 | 16384 | In: $0.08, Out: $0.24 |
| Mistral: Pixtral 12B | mistralai/pixtral-12b | openrouter | 32768 | - | In: $0.10, Out: $0.10 |
| Mistral: Pixtral Large 2411 | mistralai/pixtral-large-2411 | openrouter | 131072 | - | In: $2.00, Out: $6.00 |
| Mistral: Saba | mistralai/mistral-saba | openrouter | 32768 | - | In: $0.20, Out: $0.60 |
| Moonshot AI: Kimi VL A3B Thinking (free) | moonshotai/kimi-vl-a3b-thinking:free | openrouter | 131072 | - | - |
| MoonshotAI: Kimi K2 | moonshotai/kimi-k2 | openrouter | 63000 | 63000 | In: $0.14, Out: $2.49 |
| MoonshotAI: Kimi K2 (free) | moonshotai/kimi-k2:free | openrouter | 65536 | - | - |
| Morph: Fast Apply | morph/morph-v2 | openrouter | 32000 | 16000 | In: $1.20, Out: $2.70 |
| Morph: Morph V3 Fast | morph/morph-v3-fast | openrouter | 32000 | 16000 | In: $1.20, Out: $2.70 |
| Morph: Morph V3 Large | morph/morph-v3-large | openrouter | 32000 | 16000 | In: $1.20, Out: $2.70 |
| MythoMax 13B | gryphe/mythomax-l2-13b | openrouter | 4096 | - | In: $0.06, Out: $0.06 |
| NVIDIA: Llama 3.1 Nemotron 70B Instruct | nvidia/llama-3.1-nemotron-70b-instruct | openrouter | 131072 | 131072 | In: $0.12, Out: $0.30 |
| NVIDIA: Llama 3.1 Nemotron Ultra 253B v1 | nvidia/llama-3.1-nemotron-ultra-253b-v1 | openrouter | 131072 | - | In: $0.60, Out: $1.80 |
| NVIDIA: Llama 3.1 Nemotron Ultra 253B v1 (free) | nvidia/llama-3.1-nemotron-ultra-253b-v1:free | openrouter | 131072 | - | - |
| NVIDIA: Llama 3.3 Nemotron Super 49B v1 | nvidia/llama-3.3-nemotron-super-49b-v1 | openrouter | 131072 | - | In: $0.13, Out: $0.40 |
| NeverSleep: Llama 3 Lumimaid 70B | neversleep/llama-3-lumimaid-70b | openrouter | 8192 | 4096 | In: $4.00, Out: $6.00 |
| NeverSleep: Lumimaid v0.2 8B | neversleep/llama-3.1-lumimaid-8b | openrouter | 32768 | - | In: $0.18, Out: $1.00 |
| Noromaid 20B | neversleep/noromaid-20b | openrouter | 8192 | 2048 | In: $1.25, Out: $2.00 |
| Nous: DeepHermes 3 Llama 3 8B Preview (free) | nousresearch/deephermes-3-llama-3-8b-preview:free | openrouter | 131072 | - | - |
| Nous: Hermes 2 Mixtral 8x7B DPO | nousresearch/nous-hermes-2-mixtral-8x7b-dpo | openrouter | 32768 | 2048 | In: $0.60, Out: $0.60 |
| Nous: Hermes 3 405B Instruct | nousresearch/hermes-3-llama-3.1-405b | openrouter | 131072 | 16384 | In: $0.70, Out: $0.80 |
| Nous: Hermes 3 70B Instruct | nousresearch/hermes-3-llama-3.1-70b | openrouter | 131072 | - | In: $0.10, Out: $0.28 |
| NousResearch: Hermes 2 Pro - Llama-3 8B | nousresearch/hermes-2-pro-llama-3-8b | openrouter | 131072 | 131072 | In: $0.02, Out: $0.04 |
| OpenAI: ChatGPT-4o | openai/chatgpt-4o-latest | openrouter | 128000 | 16384 | In: $5.00, Out: $15.00 |
| OpenAI: Codex Mini | openai/codex-mini | openrouter | 200000 | 100000 | In: $1.50, Out: $6.00, Cache: $0.38 |
| OpenAI: GPT-3.5 Turbo | openai/gpt-3.5-turbo | openrouter | 16385 | 4096 | In: $0.50, Out: $1.50 |
| OpenAI: GPT-3.5 Turbo (older v0613) | openai/gpt-3.5-turbo-0613 | openrouter | 4095 | 4096 | In: $1.00, Out: $2.00 |
| OpenAI: GPT-3.5 Turbo 16k | openai/gpt-3.5-turbo-16k | openrouter | 16385 | 4096 | In: $3.00, Out: $4.00 |
| OpenAI: GPT-3.5 Turbo Instruct | openai/gpt-3.5-turbo-instruct | openrouter | 4095 | 4096 | In: $1.50, Out: $2.00 |
| OpenAI: GPT-4 | openai/gpt-4 | openrouter | 8191 | 4096 | In: $30.00, Out: $60.00 |
| OpenAI: GPT-4 (older v0314) | openai/gpt-4-0314 | openrouter | 8191 | 4096 | In: $30.00, Out: $60.00 |
| OpenAI: GPT-4 Turbo | openai/gpt-4-turbo | openrouter | 128000 | 4096 | In: $10.00, Out: $30.00 |
| OpenAI: GPT-4 Turbo (older v1106) | openai/gpt-4-1106-preview | openrouter | 128000 | 4096 | In: $10.00, Out: $30.00 |
| OpenAI: GPT-4 Turbo Preview | openai/gpt-4-turbo-preview | openrouter | 128000 | 4096 | In: $10.00, Out: $30.00 |
| OpenAI: GPT-4.1 | openai/gpt-4.1 | openrouter | 1047576 | 32768 | In: $2.00, Out: $8.00, Cache: $0.50 |
| OpenAI: GPT-4.1 Mini | openai/gpt-4.1-mini | openrouter | 1047576 | 32768 | In: $0.40, Out: $1.60, Cache: $0.10 |
| OpenAI: GPT-4.1 Nano | openai/gpt-4.1-nano | openrouter | 1047576 | 32768 | In: $0.10, Out: $0.40, Cache: $0.02 |
| OpenAI: GPT-4o | openai/gpt-4o | openrouter | 128000 | 16384 | In: $2.50, Out: $10.00, Cache: $1.25 |
| OpenAI: GPT-4o (2024-05-13) | openai/gpt-4o-2024-05-13 | openrouter | 128000 | 4096 | In: $5.00, Out: $15.00 |
| OpenAI: GPT-4o (2024-08-06) | openai/gpt-4o-2024-08-06 | openrouter | 128000 | 16384 | In: $2.50, Out: $10.00, Cache: $1.25 |
| OpenAI: GPT-4o (2024-11-20) | openai/gpt-4o-2024-11-20 | openrouter | 128000 | 16384 | In: $2.50, Out: $10.00, Cache: $1.25 |
| OpenAI: GPT-4o (extended) | openai/gpt-4o:extended | openrouter | 128000 | 64000 | In: $6.00, Out: $18.00 |
| OpenAI: GPT-4o Search Preview | openai/gpt-4o-search-preview | openrouter | 128000 | 16384 | In: $2.50, Out: $10.00 |
| OpenAI: GPT-4o-mini | openai/gpt-4o-mini | openrouter | 128000 | 16384 | In: $0.15, Out: $0.60, Cache: $0.08 |
| OpenAI: GPT-4o-mini (2024-07-18) | openai/gpt-4o-mini-2024-07-18 | openrouter | 128000 | 16384 | In: $0.15, Out: $0.60, Cache: $0.08 |
| OpenAI: GPT-4o-mini Search Preview | openai/gpt-4o-mini-search-preview | openrouter | 128000 | 16384 | In: $0.15, Out: $0.60 |
| OpenAI: o1 | openai/o1 | openrouter | 200000 | 100000 | In: $15.00, Out: $60.00, Cache: $7.50 |
| OpenAI: o1-mini | openai/o1-mini | openrouter | 128000 | 65536 | In: $1.10, Out: $4.40, Cache: $0.55 |
| OpenAI: o1-mini (2024-09-12) | openai/o1-mini-2024-09-12 | openrouter | 128000 | 65536 | In: $1.10, Out: $4.40, Cache: $0.55 |
| OpenAI: o1-preview | openai/o1-preview | openrouter | 128000 | 32768 | In: $15.00, Out: $60.00, Cache: $7.50 |
| OpenAI: o1-preview (2024-09-12) | openai/o1-preview-2024-09-12 | openrouter | 128000 | 32768 | In: $15.00, Out: $60.00, Cache: $7.50 |
| OpenAI: o1-pro | openai/o1-pro | openrouter | 200000 | 100000 | In: $150.00, Out: $600.00 |
| OpenAI: o3 | openai/o3 | openrouter | 200000 | 100000 | In: $2.00, Out: $8.00, Cache: $0.50 |
| OpenAI: o3 Mini | openai/o3-mini | openrouter | 200000 | 100000 | In: $1.10, Out: $4.40, Cache: $0.55 |
| OpenAI: o3 Mini High | openai/o3-mini-high | openrouter | 200000 | 100000 | In: $1.10, Out: $4.40, Cache: $0.55 |
| OpenAI: o3 Pro | openai/o3-pro | openrouter | 200000 | 100000 | In: $20.00, Out: $80.00 |
| OpenAI: o4 Mini | openai/o4-mini | openrouter | 200000 | 100000 | In: $1.10, Out: $4.40, Cache: $0.28 |
| OpenAI: o4 Mini High | openai/o4-mini-high | openrouter | 200000 | 100000 | In: $1.10, Out: $4.40, Cache: $0.28 |
| OpenGVLab: InternVL3 14B | opengvlab/internvl3-14b | openrouter | 12288 | - | In: $0.20, Out: $0.40 |
| Perplexity: R1 1776 | perplexity/r1-1776 | openrouter | 128000 | - | In: $2.00, Out: $8.00 |
| Perplexity: Sonar | perplexity/sonar | openrouter | 127072 | - | In: $1.00, Out: $1.00 |
| Perplexity: Sonar Deep Research | perplexity/sonar-deep-research | openrouter | 128000 | - | In: $2.00, Out: $8.00 |
| Perplexity: Sonar Pro | perplexity/sonar-pro | openrouter | 200000 | 8000 | In: $3.00, Out: $15.00 |
| Perplexity: Sonar Reasoning | perplexity/sonar-reasoning | openrouter | 127000 | - | In: $1.00, Out: $5.00 |
| Perplexity: Sonar Reasoning Pro | perplexity/sonar-reasoning-pro | openrouter | 128000 | - | In: $2.00, Out: $8.00 |
| Pygmalion: Mythalion 13B | pygmalionai/mythalion-13b | openrouter | 4096 | 4096 | In: $0.80, Out: $1.20 |
| Qwen 2 72B Instruct | qwen/qwen-2-72b-instruct | openrouter | 32768 | 4096 | In: $0.90, Out: $0.90 |
| Qwen2.5 72B Instruct | qwen/qwen-2.5-72b-instruct | openrouter | 32768 | 16384 | In: $0.12, Out: $0.39 |
| Qwen2.5 72B Instruct (free) | qwen/qwen-2.5-72b-instruct:free | openrouter | 32768 | - | - |
| Qwen2.5 7B Instruct | qwen/qwen-2.5-7b-instruct | openrouter | 32768 | 16384 | In: $0.04, Out: $0.10 |
| Qwen2.5 Coder 32B Instruct | qwen/qwen-2.5-coder-32b-instruct | openrouter | 32768 | 16384 | In: $0.06, Out: $0.15 |
| Qwen2.5 Coder 32B Instruct (free) | qwen/qwen-2.5-coder-32b-instruct:free | openrouter | 32768 | - | - |
| Qwen: QwQ 32B | qwen/qwq-32b | openrouter | 131072 | - | In: $0.08, Out: $0.15 |
| Qwen: QwQ 32B (free) | qwen/qwq-32b:free | openrouter | 32768 | - | - |
| Qwen: QwQ 32B Preview | qwen/qwq-32b-preview | openrouter | 32768 | - | In: $0.20, Out: $0.20 |
| Qwen: Qwen VL Max | qwen/qwen-vl-max | openrouter | 7500 | 1500 | In: $0.80, Out: $3.20 |
| Qwen: Qwen VL Plus | qwen/qwen-vl-plus | openrouter | 7500 | 1500 | In: $0.21, Out: $0.63 |
| Qwen: Qwen-Max  | qwen/qwen-max | openrouter | 32768 | 8192 | In: $1.60, Out: $6.40, Cache: $0.64 |
| Qwen: Qwen-Plus | qwen/qwen-plus | openrouter | 131072 | 8192 | In: $0.40, Out: $1.20, Cache: $0.16 |
| Qwen: Qwen-Turbo | qwen/qwen-turbo | openrouter | 1000000 | 8192 | In: $0.05, Out: $0.20, Cache: $0.02 |
| Qwen: Qwen2.5 VL 32B Instruct | qwen/qwen2.5-vl-32b-instruct | openrouter | 128000 | - | In: $0.20, Out: $0.60 |
| Qwen: Qwen2.5 VL 32B Instruct (free) | qwen/qwen2.5-vl-32b-instruct:free | openrouter | 8192 | - | - |
| Qwen: Qwen2.5 VL 72B Instruct | qwen/qwen2.5-vl-72b-instruct | openrouter | 32000 | - | In: $0.25, Out: $0.75 |
| Qwen: Qwen2.5 VL 72B Instruct (free) | qwen/qwen2.5-vl-72b-instruct:free | openrouter | 32768 | - | - |
| Qwen: Qwen2.5-VL 7B Instruct | qwen/qwen-2.5-vl-7b-instruct | openrouter | 32768 | - | In: $0.20, Out: $0.20 |
| Qwen: Qwen3 14B | qwen/qwen3-14b | openrouter | 40960 | 40960 | In: $0.06, Out: $0.24 |
| Qwen: Qwen3 14B (free) | qwen/qwen3-14b:free | openrouter | 40960 | - | - |
| Qwen: Qwen3 235B A22B | qwen/qwen3-235b-a22b | openrouter | 40960 | 40960 | In: $0.13, Out: $0.60 |
| Qwen: Qwen3 235B A22B (free) | qwen/qwen3-235b-a22b:free | openrouter | 131072 | - | - |
| Qwen: Qwen3 30B A3B | qwen/qwen3-30b-a3b | openrouter | 40960 | 40960 | In: $0.08, Out: $0.29 |
| Qwen: Qwen3 30B A3B (free) | qwen/qwen3-30b-a3b:free | openrouter | 40960 | - | - |
| Qwen: Qwen3 32B | qwen/qwen3-32b | openrouter | 40960 | - | In: $0.10, Out: $0.30 |
| Qwen: Qwen3 32B (free) | qwen/qwen3-32b:free | openrouter | 40960 | - | - |
| Qwen: Qwen3 4B (free) | qwen/qwen3-4b:free | openrouter | 40960 | - | - |
| Qwen: Qwen3 8B | qwen/qwen3-8b | openrouter | 128000 | 20000 | In: $0.04, Out: $0.14 |
| Qwen: Qwen3 8B (free) | qwen/qwen3-8b:free | openrouter | 40960 | 40960 | - |
| Qwerky 72B (free) | featherless/qwerky-72b:free | openrouter | 32768 | 4096 | - |
| ReMM SLERP 13B | undi95/remm-slerp-l2-13b | openrouter | 6144 | - | In: $0.70, Out: $1.00 |
| Reka: Flash 3 | rekaai/reka-flash-3 | openrouter | 32768 | - | In: $0.01, Out: $0.01 |
| Reka: Flash 3 (free) | rekaai/reka-flash-3:free | openrouter | 32768 | - | - |
| Sao10K: Llama 3 8B Lunaris | sao10k/l3-lunaris-8b | openrouter | 8192 | - | In: $0.02, Out: $0.05 |
| Sao10K: Llama 3.1 Euryale 70B v2.2 | sao10k/l3.1-euryale-70b | openrouter | 32768 | - | In: $0.65, Out: $0.75 |
| Sao10K: Llama 3.3 Euryale 70B | sao10k/l3.3-euryale-70b | openrouter | 131072 | - | In: $0.65, Out: $0.75 |
| Sao10k: Llama 3 Euryale 70B v2.1 | sao10k/l3-euryale-70b | openrouter | 8192 | 8192 | In: $1.48, Out: $1.48 |
| Sarvam AI: Sarvam-M | sarvamai/sarvam-m | openrouter | 32768 | - | In: $0.02, Out: $0.02 |
| Sarvam AI: Sarvam-M (free) | sarvamai/sarvam-m:free | openrouter | 32768 | - | - |
| Shisa AI: Shisa V2 Llama 3.3 70B  (free) | shisa-ai/shisa-v2-llama3.3-70b:free | openrouter | 32768 | - | - |
| SorcererLM 8x22B | raifle/sorcererlm-8x22b | openrouter | 16000 | - | In: $4.50, Out: $4.50 |
| Switchpoint Router | switchpoint/router | openrouter | 131072 | - | In: $0.85, Out: $3.40 |
| THUDM: GLM 4 32B | thudm/glm-4-32b | openrouter | 32000 | 32000 | In: $0.24, Out: $0.24 |
| THUDM: GLM 4 32B (free) | thudm/glm-4-32b:free | openrouter | 32768 | - | - |
| THUDM: GLM 4.1V 9B Thinking | thudm/glm-4.1v-9b-thinking | openrouter | 65536 | 8000 | In: $0.04, Out: $0.14 |
| THUDM: GLM Z1 32B (free) | thudm/glm-z1-32b:free | openrouter | 32768 | - | - |
| TNG: DeepSeek R1T Chimera (free) | tngtech/deepseek-r1t-chimera:free | openrouter | 163840 | - | - |
| TNG: DeepSeek R1T2 Chimera (free) | tngtech/deepseek-r1t2-chimera:free | openrouter | 163840 | - | - |
| Tencent: Hunyuan A13B Instruct | tencent/hunyuan-a13b-instruct | openrouter | 32768 | - | In: $0.03, Out: $0.03 |
| Tencent: Hunyuan A13B Instruct (free) | tencent/hunyuan-a13b-instruct:free | openrouter | 32768 | - | - |
| TheDrummer: Anubis 70B V1.1 | thedrummer/anubis-70b-v1.1 | openrouter | 131072 | 131072 | In: $0.50, Out: $0.80 |
| TheDrummer: Anubis Pro 105B V1 | thedrummer/anubis-pro-105b-v1 | openrouter | 131072 | 131072 | In: $0.50, Out: $1.00 |
| TheDrummer: Rocinante 12B | thedrummer/rocinante-12b | openrouter | 32768 | - | In: $0.20, Out: $0.50 |
| TheDrummer: Skyfall 36B V2 | thedrummer/skyfall-36b-v2 | openrouter | 32768 | - | In: $0.40, Out: $0.70 |
| TheDrummer: UnslopNemo 12B | thedrummer/unslopnemo-12b | openrouter | 32768 | - | In: $0.40, Out: $0.40 |
| TheDrummer: Valkyrie 49B V1 | thedrummer/valkyrie-49b-v1 | openrouter | 32768 | - | In: $0.60, Out: $0.80 |
| Toppy M 7B | undi95/toppy-m-7b | openrouter | 4096 | 4096 | In: $0.80, Out: $1.20 |
| Typhoon2 70B Instruct | scb10x/llama3.1-typhoon2-70b-instruct | openrouter | 8192 | - | In: $0.88, Out: $0.88 |
| Venice: Uncensored (free) | cognitivecomputations/dolphin-mistral-24b-venice-edition:free | openrouter | 32768 | - | - |
| WizardLM-2 8x22B | microsoft/wizardlm-2-8x22b | openrouter | 65536 | 65536 | In: $0.48, Out: $0.48 |
| xAI: Grok 2 1212 | x-ai/grok-2-1212 | openrouter | 131072 | - | In: $2.00, Out: $10.00 |
| xAI: Grok 2 Vision 1212 | x-ai/grok-2-vision-1212 | openrouter | 32768 | - | In: $2.00, Out: $10.00 |
| xAI: Grok 3 | x-ai/grok-3 | openrouter | 131072 | - | In: $3.00, Out: $15.00, Cache: $0.75 |
| xAI: Grok 3 Beta | x-ai/grok-3-beta | openrouter | 131072 | - | In: $3.00, Out: $15.00, Cache: $0.75 |
| xAI: Grok 3 Mini | x-ai/grok-3-mini | openrouter | 131072 | - | In: $0.30, Out: $0.50, Cache: $0.08 |
| xAI: Grok 3 Mini Beta | x-ai/grok-3-mini-beta | openrouter | 131072 | - | In: $0.30, Out: $0.50, Cache: $0.08 |
| xAI: Grok 4 | x-ai/grok-4 | openrouter | 256000 | - | In: $3.00, Out: $15.00, Cache: $0.75 |
| xAI: Grok Vision Beta | x-ai/grok-vision-beta | openrouter | 8192 | - | In: $5.00, Out: $15.00 |


### Batch Processing (58)

| Model | ID | Provider | Context | Max Output | Standard Pricing (per 1M tokens) |
| :-- | :-- | :-- | --: | --: | :-- |
| Claude Sonnet 3 | claude-3-sonnet-20240229 | anthropic | 200000 | 4096 | In: $3.00, Out: $15.00 |
| Claude 3.7 Sonnet | us.anthropic.claude-3-7-sonnet-20250219-v1:0 | bedrock | 200000 | 4096 | In: $3.00, Out: $15.00 |
| Embedding 001 | embedding-001 | gemini | 2048 | 1 | - |
| Embedding Gecko | embedding-gecko-001 | gemini | 1024 | 1 | - |
| Gemini 2.0 Flash | gemini-2.0-flash | gemini | 1048576 | 8192 | In: $0.10, Out: $0.40, Cache: $0.02 |
| Gemini 2.0 Flash | gemini-2.0-flash-001 | gemini | 1048576 | 8192 | In: $0.10, Out: $0.40, Cache: $0.02 |
| Gemini 2.0 Flash | gemini-2.0-flash-exp | gemini | 1048576 | 8192 | In: $0.10, Out: $0.40, Cache: $0.02 |
| Gemini 2.0 Flash-Lite | gemini-2.0-flash-lite | gemini | 1048576 | 8192 | In: $0.10, Out: $0.40, Cache: $0.02 |
| Gemini 2.0 Flash-Lite | gemini-2.0-flash-lite-001 | gemini | 1048576 | 8192 | In: $0.10, Out: $0.40, Cache: $0.02 |
| Gemini 2.0 Flash-Lite Preview | gemini-2.0-flash-lite-preview | gemini | 1048576 | 8192 | In: $0.08, Out: $0.30 |
| Gemini 2.0 Flash-Lite Preview 02-05 | gemini-2.0-flash-lite-preview-02-05 | gemini | 1048576 | 8192 | In: $0.08, Out: $0.30 |
| Gemini 2.5 Flash | gemini-2.5-flash | gemini | 1048576 | 65536 | In: $0.30, Out: $2.50, Cache: $0.08 |
| Gemini 2.5 Flash | gemini-2.5-flash-preview-05-20 | gemini | 1048576 | 65536 | In: $0.30, Out: $2.50, Cache: $0.08 |
| Gemini 2.5 Flash Preview 05-20 | gemini-2.0-flash-thinking-exp | gemini | 1048576 | 65536 | In: $0.10, Out: $0.40 |
| Gemini 2.5 Flash Preview 05-20 | gemini-2.0-flash-thinking-exp-01-21 | gemini | 1048576 | 65536 | In: $0.10, Out: $0.40 |
| Gemini 2.5 Flash Preview 05-20 | gemini-2.0-flash-thinking-exp-1219 | gemini | 1048576 | 65536 | In: $0.10, Out: $0.40 |
| Gemini 2.5 Pro | gemini-2.5-pro | gemini | 1048576 | 65536 | In: $1.25, Out: $10.00, Cache: $0.31 |
| Gemini 2.5 Pro | gemini-2.5-pro-preview-03-25 | gemini | 1048576 | 65536 | In: $1.25, Out: $10.00, Cache: $0.31 |
| Gemini 2.5 Pro | gemini-2.5-pro-preview-05-06 | gemini | 1048576 | 65536 | In: $1.25, Out: $10.00, Cache: $0.31 |
| Gemini 2.5 Pro | gemini-2.5-pro-preview-06-05 | gemini | 1048576 | 65536 | In: $1.25, Out: $10.00, Cache: $0.31 |
| Gemini Embedding Experimental | gemini-embedding-exp | gemini | 8192 | 1 | In: $0.00, Out: $0.00 |
| LearnLM 2.0 Flash Experimental | learnlm-2.0-flash-experimental | gemini | 1048576 | 32768 | In: $0.08, Out: $0.30 |
| GPT-3.5 Turbo | gpt-3.5-turbo | openai | 16385 | 4096 | In: $0.50, Out: $1.50 |
| GPT-4 | gpt-4 | openai | 8192 | 8192 | In: $30.00, Out: $60.00 |
| GPT-4 | gpt-4-0613 | openai | 8192 | 8192 | In: $30.00, Out: $60.00 |
| GPT-4 Turbo | gpt-4-turbo | openai | 128000 | 4096 | In: $10.00, Out: $30.00 |
| GPT-4 Turbo | gpt-4-turbo-2024-04-09 | openai | 128000 | 4096 | In: $10.00, Out: $30.00 |
| GPT-4.1 | gpt-4.1 | openai | 1047576 | 32768 | In: $2.00, Out: $8.00, Cache: $0.50 |
| GPT-4.1 | gpt-4.1-2025-04-14 | openai | 1047576 | 32768 | In: $2.00, Out: $8.00, Cache: $0.50 |
| GPT-4.1 mini | gpt-4.1-mini | openai | 1047576 | 32768 | In: $0.40, Out: $1.60, Cache: $0.10 |
| GPT-4.1 mini | gpt-4.1-mini-2025-04-14 | openai | 1047576 | 32768 | In: $0.40, Out: $1.60, Cache: $0.10 |
| GPT-4.1 nano | gpt-4.1-nano | openai | 1047576 | 32768 | In: $0.10, Out: $0.40, Cache: $0.02 |
| GPT-4.1 nano | gpt-4.1-nano-2025-04-14 | openai | 1047576 | 32768 | In: $0.10, Out: $0.40, Cache: $0.02 |
| GPT-4o | gpt-4o | openai | 128000 | 16384 | In: $2.50, Out: $10.00, Cache: $1.25 |
| GPT-4o | gpt-4o-2024-08-06 | openai | 128000 | 16384 | In: $2.50, Out: $10.00, Cache: $1.25 |
| GPT-4o mini | gpt-4o-mini | openai | 128000 | 16384 | In: $0.15, Out: $0.60, Cache: $0.08 |
| GPT-4o mini | gpt-4o-mini-2024-07-18 | openai | 128000 | 16384 | In: $0.15, Out: $0.60, Cache: $0.08 |
| computer-use-preview | computer-use-preview | openai | 8192 | 1024 | In: $3.00, Out: $12.00 |
| computer-use-preview | computer-use-preview-2025-03-11 | openai | 8192 | 1024 | In: $3.00, Out: $12.00 |
| o1 | o1 | openai | 200000 | 100000 | In: $15.00, Out: $60.00, Cache: $7.50 |
| o1 | o1-2024-12-17 | openai | 200000 | 100000 | In: $15.00, Out: $60.00, Cache: $7.50 |
| o1-pro | o1-pro | openai | 200000 | 100000 | In: $150.00, Out: $600.00 |
| o1-pro | o1-pro-2025-03-19 | openai | 200000 | 100000 | In: $150.00, Out: $600.00 |
| o3 | o3 | openai | 200000 | 100000 | In: $2.00, Out: $8.00, Cache: $0.50 |
| o3 | o3-2025-04-16 | openai | 200000 | 100000 | In: $2.00, Out: $8.00, Cache: $0.50 |
| o3-deep-research | o3-deep-research | openai | 200000 | 100000 | In: $10.00, Out: $40.00, Cache: $2.50 |
| o3-deep-research | o3-deep-research-2025-06-26 | openai | 200000 | 100000 | In: $10.00, Out: $40.00, Cache: $2.50 |
| o3-mini | o3-mini | openai | 200000 | 100000 | In: $1.10, Out: $4.40, Cache: $0.55 |
| o3-mini | o3-mini-2025-01-31 | openai | 200000 | 100000 | In: $1.10, Out: $4.40, Cache: $0.55 |
| o3-pro | o3-pro | openai | 200000 | 100000 | In: $20.00, Out: $80.00 |
| o3-pro | o3-pro-2025-06-10 | openai | 200000 | 100000 | In: $20.00, Out: $80.00 |
| o4-mini | o4-mini | openai | 200000 | 100000 | In: $1.10, Out: $4.40, Cache: $0.28 |
| o4-mini | o4-mini-2025-04-16 | openai | 200000 | 100000 | In: $1.10, Out: $4.40, Cache: $0.28 |
| o4-mini-deep-research | o4-mini-deep-research | openai | 200000 | 100000 | In: $2.00, Out: $8.00, Cache: $0.50 |
| o4-mini-deep-research | o4-mini-deep-research-2025-06-26 | openai | 200000 | 100000 | In: $2.00, Out: $8.00, Cache: $0.50 |
| text-embedding-3-large | text-embedding-3-large | openai | - | - | In: $0.13 |
| text-embedding-3-small | text-embedding-3-small | openai | - | - | In: $0.02 |
| text-embedding-ada-002 | text-embedding-ada-002 | openai | - | - | In: $0.10 |


## Models by Modality

### Vision Models (204)

Models that can process images:

| Model | ID | Provider | Context | Max Output | Standard Pricing (per 1M tokens) |
| :-- | :-- | :-- | --: | --: | :-- |
| Claude Haiku 3 | claude-3-haiku-20240307 | anthropic | 200000 | 4096 | In: $0.25, Out: $1.25, Cache: $0.30 |
| Claude Haiku 3.5 | claude-3-5-haiku-20241022 | anthropic | 200000 | 8192 | In: $0.80, Out: $4.00, Cache: $1.00 |
| Claude Opus 3 | claude-3-opus-20240229 | anthropic | 200000 | 4096 | In: $15.00, Out: $75.00, Cache: $18.75 |
| Claude Opus 4 | claude-opus-4-20250514 | anthropic | 200000 | 32000 | In: $15.00, Out: $75.00, Cache: $18.75 |
| Claude Sonnet 3 | claude-3-sonnet-20240229 | anthropic | 200000 | 4096 | In: $3.00, Out: $15.00 |
| Claude Sonnet 3.5 | claude-3-5-sonnet-20240620 | anthropic | 200000 | 8192 | In: $3.00, Out: $15.00, Cache: $3.75 |
| Claude Sonnet 3.5 | claude-3-5-sonnet-20241022 | anthropic | 200000 | 8192 | In: $3.00, Out: $15.00, Cache: $3.75 |
| Claude Sonnet 3.7 | claude-3-7-sonnet-20250219 | anthropic | 200000 | 64000 | In: $3.00, Out: $15.00, Cache: $3.75 |
| Claude Sonnet 4 | claude-sonnet-4-20250514 | anthropic | 200000 | 64000 | In: $3.00, Out: $15.00, Cache: $3.75 |
| Claude | anthropic.claude-v2 | bedrock | 200000 | 4096 | In: $8.00, Out: $24.00 |
| Claude | anthropic.claude-v2:0:100k | bedrock | 200000 | 4096 | In: $8.00, Out: $24.00 |
| Claude | anthropic.claude-v2:0:18k | bedrock | 200000 | 4096 | In: $8.00, Out: $24.00 |
| Claude | anthropic.claude-v2:1 | bedrock | 200000 | 4096 | In: $8.00, Out: $24.00 |
| Claude | anthropic.claude-v2:1:18k | bedrock | 200000 | 4096 | In: $8.00, Out: $24.00 |
| Claude | anthropic.claude-v2:1:200k | bedrock | 200000 | 4096 | In: $8.00, Out: $24.00 |
| Claude 3 Haiku | anthropic.claude-3-haiku-20240307-v1:0 | bedrock | 200000 | 4096 | In: $0.25, Out: $1.25 |
| Claude 3 Haiku | anthropic.claude-3-haiku-20240307-v1:0:200k | bedrock | 200000 | 4096 | In: $0.25, Out: $1.25 |
| Claude 3 Haiku | anthropic.claude-3-haiku-20240307-v1:0:48k | bedrock | 200000 | 4096 | In: $0.25, Out: $1.25 |
| Claude 3 Opus | anthropic.claude-3-opus-20240229-v1:0 | bedrock | 200000 | 4096 | In: $15.00, Out: $75.00 |
| Claude 3 Opus | anthropic.claude-3-opus-20240229-v1:0:12k | bedrock | 200000 | 4096 | In: $15.00, Out: $75.00 |
| Claude 3 Opus | anthropic.claude-3-opus-20240229-v1:0:200k | bedrock | 200000 | 4096 | In: $15.00, Out: $75.00 |
| Claude 3 Opus | anthropic.claude-3-opus-20240229-v1:0:28k | bedrock | 200000 | 4096 | In: $15.00, Out: $75.00 |
| Claude 3 Sonnet | anthropic.claude-3-sonnet-20240229-v1:0 | bedrock | 200000 | 4096 | In: $3.00, Out: $15.00 |
| Claude 3 Sonnet | anthropic.claude-3-sonnet-20240229-v1:0:200k | bedrock | 200000 | 4096 | In: $3.00, Out: $15.00 |
| Claude 3 Sonnet | anthropic.claude-3-sonnet-20240229-v1:0:28k | bedrock | 200000 | 4096 | In: $3.00, Out: $15.00 |
| Claude 3.5 Haiku | anthropic.claude-3-5-haiku-20241022-v1:0 | bedrock | 200000 | 4096 | In: $0.80, Out: $4.00 |
| Claude 3.5 Sonnet | anthropic.claude-3-5-sonnet-20240620-v1:0 | bedrock | 200000 | 4096 | In: $3.00, Out: $15.00 |
| Claude 3.5 Sonnet | anthropic.claude-3-5-sonnet-20240620-v1:0:18k | bedrock | 200000 | 4096 | In: $3.00, Out: $15.00 |
| Claude 3.5 Sonnet | anthropic.claude-3-5-sonnet-20240620-v1:0:200k | bedrock | 200000 | 4096 | In: $3.00, Out: $15.00 |
| Claude 3.5 Sonnet | anthropic.claude-3-5-sonnet-20240620-v1:0:51k | bedrock | 200000 | 4096 | In: $3.00, Out: $15.00 |
| Claude 3.5 Sonnet v2 | anthropic.claude-3-5-sonnet-20241022-v2:0 | bedrock | 200000 | 4096 | In: $3.00, Out: $15.00 |
| Claude 3.5 Sonnet v2 | anthropic.claude-3-5-sonnet-20241022-v2:0:18k | bedrock | 200000 | 4096 | In: $3.00, Out: $15.00 |
| Claude 3.5 Sonnet v2 | anthropic.claude-3-5-sonnet-20241022-v2:0:200k | bedrock | 200000 | 4096 | In: $3.00, Out: $15.00 |
| Claude 3.5 Sonnet v2 | anthropic.claude-3-5-sonnet-20241022-v2:0:51k | bedrock | 200000 | 4096 | In: $3.00, Out: $15.00 |
| Claude 3.7 Sonnet | us.anthropic.claude-3-7-sonnet-20250219-v1:0 | bedrock | 200000 | 4096 | In: $3.00, Out: $15.00 |
| Claude Instant | anthropic.claude-instant-v1 | bedrock | 200000 | 4096 | In: $0.80, Out: $2.40 |
| Claude Instant | anthropic.claude-instant-v1:2:100k | bedrock | 200000 | 4096 | In: $0.80, Out: $2.40 |
| Claude Opus 4 | us.anthropic.claude-opus-4-20250514-v1:0 | bedrock | 200000 | 4096 | In: $0.10, Out: $0.20 |
| Claude Sonnet 4 | us.anthropic.claude-sonnet-4-20250514-v1:0 | bedrock | 200000 | 4096 | In: $0.10, Out: $0.20 |
| Gemini 1.0 Pro Vision | gemini-1.0-pro-vision-latest | gemini | 12288 | 4096 | In: $0.08, Out: $0.30 |
| Gemini 1.0 Pro Vision | gemini-pro-vision | gemini | 12288 | 4096 | In: $0.08, Out: $0.30 |
| Gemini 1.5 Flash | gemini-1.5-flash | gemini | 1048576 | 8192 | In: $0.08, Out: $0.30, Cache: $0.02 |
| Gemini 1.5 Flash | gemini-1.5-flash-001 | gemini | 1048576 | 8192 | In: $0.08, Out: $0.30, Cache: $0.02 |
| Gemini 1.5 Flash | gemini-1.5-flash-002 | gemini | 1048576 | 8192 | In: $0.08, Out: $0.30, Cache: $0.02 |
| Gemini 1.5 Flash | gemini-1.5-flash-latest | gemini | 1048576 | 8192 | In: $0.08, Out: $0.30, Cache: $0.02 |
| Gemini 1.5 Flash-8B | gemini-1.5-flash-8b | gemini | 1048576 | 8192 | In: $0.08, Out: $0.30, Cache: $0.02 |
| Gemini 1.5 Flash-8B | gemini-1.5-flash-8b-001 | gemini | 1048576 | 8192 | In: $0.08, Out: $0.30, Cache: $0.02 |
| Gemini 1.5 Flash-8B | gemini-1.5-flash-8b-latest | gemini | 1048576 | 8192 | In: $0.08, Out: $0.30, Cache: $0.02 |
| Gemini 1.5 Pro | gemini-1.5-pro | gemini | 2097152 | 8192 | In: $1.25, Out: $5.00, Cache: $0.31 |
| Gemini 1.5 Pro | gemini-1.5-pro-001 | gemini | 2097152 | 8192 | In: $1.25, Out: $5.00, Cache: $0.31 |
| Gemini 1.5 Pro | gemini-1.5-pro-002 | gemini | 2097152 | 8192 | In: $1.25, Out: $5.00, Cache: $0.31 |
| Gemini 1.5 Pro | gemini-1.5-pro-latest | gemini | 2097152 | 8192 | In: $1.25, Out: $5.00, Cache: $0.31 |
| Gemini 2.0 Flash | gemini-2.0-flash | gemini | 1048576 | 8192 | In: $0.10, Out: $0.40, Cache: $0.02 |
| Gemini 2.0 Flash | gemini-2.0-flash-001 | gemini | 1048576 | 8192 | In: $0.10, Out: $0.40, Cache: $0.02 |
| Gemini 2.0 Flash | gemini-2.0-flash-exp | gemini | 1048576 | 8192 | In: $0.10, Out: $0.40, Cache: $0.02 |
| Gemini 2.0 Flash Preview Image Generation | gemini-2.0-flash-preview-image-generation | gemini | 32000 | 8192 | In: $0.10, Out: $0.40, Cache: $0.02 |
| Gemini 2.0 Flash-Lite | gemini-2.0-flash-lite | gemini | 1048576 | 8192 | In: $0.10, Out: $0.40, Cache: $0.02 |
| Gemini 2.0 Flash-Lite | gemini-2.0-flash-lite-001 | gemini | 1048576 | 8192 | In: $0.10, Out: $0.40, Cache: $0.02 |
| Gemini 2.0 Flash-Lite Preview | gemini-2.0-flash-lite-preview | gemini | 1048576 | 8192 | In: $0.08, Out: $0.30 |
| Gemini 2.0 Flash-Lite Preview 02-05 | gemini-2.0-flash-lite-preview-02-05 | gemini | 1048576 | 8192 | In: $0.08, Out: $0.30 |
| Gemini 2.0 Pro Experimental | gemini-2.0-pro-exp | gemini | 1048576 | 65536 | In: $0.08, Out: $0.30 |
| Gemini 2.0 Pro Experimental 02-05 | gemini-2.0-pro-exp-02-05 | gemini | 1048576 | 65536 | In: $0.08, Out: $0.30 |
| Gemini 2.5 Flash | gemini-2.5-flash | gemini | 1048576 | 65536 | In: $0.30, Out: $2.50, Cache: $0.08 |
| Gemini 2.5 Flash | gemini-2.5-flash-preview-05-20 | gemini | 1048576 | 65536 | In: $0.30, Out: $2.50, Cache: $0.08 |
| Gemini 2.5 Flash Preview 05-20 | gemini-2.0-flash-thinking-exp | gemini | 1048576 | 65536 | In: $0.10, Out: $0.40 |
| Gemini 2.5 Flash Preview 05-20 | gemini-2.0-flash-thinking-exp-01-21 | gemini | 1048576 | 65536 | In: $0.10, Out: $0.40 |
| Gemini 2.5 Flash Preview 05-20 | gemini-2.0-flash-thinking-exp-1219 | gemini | 1048576 | 65536 | In: $0.10, Out: $0.40 |
| Gemini 2.5 Flash-Lite Preview | gemini-2.5-flash-lite-preview-06-17 | gemini | 1000000 | 64000 | In: $0.30, Out: $2.50, Cache: $0.08 |
| Gemini 2.5 Pro | gemini-2.5-pro | gemini | 1048576 | 65536 | In: $1.25, Out: $10.00, Cache: $0.31 |
| Gemini 2.5 Pro | gemini-2.5-pro-preview-03-25 | gemini | 1048576 | 65536 | In: $1.25, Out: $10.00, Cache: $0.31 |
| Gemini 2.5 Pro | gemini-2.5-pro-preview-05-06 | gemini | 1048576 | 65536 | In: $1.25, Out: $10.00, Cache: $0.31 |
| Gemini 2.5 Pro | gemini-2.5-pro-preview-06-05 | gemini | 1048576 | 65536 | In: $1.25, Out: $10.00, Cache: $0.31 |
| Gemini Embedding Experimental | gemini-embedding-exp | gemini | 8192 | 1 | In: $0.00, Out: $0.00 |
| Gemini Experimental 1206 | gemini-exp-1206 | gemini | 1048576 | 65536 | In: $0.08, Out: $0.30 |
| LearnLM 2.0 Flash Experimental | learnlm-2.0-flash-experimental | gemini | 1048576 | 32768 | In: $0.08, Out: $0.30 |
| Veo 2 | veo-2.0-generate-001 | gemini | - | 2 | - |
| ChatGPT-4o | chatgpt-4o-latest | openai | 128000 | 16384 | In: $5.00, Out: $15.00 |
| GPT Image 1 | gpt-image-1 | openai | - | - | In: $5.00, Out: $40.00, Cache: $1.25 |
| GPT-4 Turbo | gpt-4-turbo | openai | 128000 | 4096 | In: $10.00, Out: $30.00 |
| GPT-4 Turbo | gpt-4-turbo-2024-04-09 | openai | 128000 | 4096 | In: $10.00, Out: $30.00 |
| GPT-4 Turbo Preview | gpt-4-turbo-preview | openai | 128000 | 4096 | In: $10.00, Out: $30.00 |
| GPT-4.1 | gpt-4.1 | openai | 1047576 | 32768 | In: $2.00, Out: $8.00, Cache: $0.50 |
| GPT-4.1 | gpt-4.1-2025-04-14 | openai | 1047576 | 32768 | In: $2.00, Out: $8.00, Cache: $0.50 |
| GPT-4.1 mini | gpt-4.1-mini | openai | 1047576 | 32768 | In: $0.40, Out: $1.60, Cache: $0.10 |
| GPT-4.1 mini | gpt-4.1-mini-2025-04-14 | openai | 1047576 | 32768 | In: $0.40, Out: $1.60, Cache: $0.10 |
| GPT-4.1 nano | gpt-4.1-nano | openai | 1047576 | 32768 | In: $0.10, Out: $0.40, Cache: $0.02 |
| GPT-4.1 nano | gpt-4.1-nano-2025-04-14 | openai | 1047576 | 32768 | In: $0.10, Out: $0.40, Cache: $0.02 |
| GPT-4o | gpt-4o | openai | 128000 | 16384 | In: $2.50, Out: $10.00, Cache: $1.25 |
| GPT-4o | gpt-4o-2024-08-06 | openai | 128000 | 16384 | In: $2.50, Out: $10.00, Cache: $1.25 |
| GPT-4o 20240513 | gpt-4o-2024-05-13 | openai | 128000 | 16384 | In: $2.50, Out: $10.00 |
| GPT-4o 20241120 | gpt-4o-2024-11-20 | openai | 128000 | 16384 | In: $2.50, Out: $10.00 |
| GPT-4o mini | gpt-4o-mini | openai | 128000 | 16384 | In: $0.15, Out: $0.60, Cache: $0.08 |
| GPT-4o mini | gpt-4o-mini-2024-07-18 | openai | 128000 | 16384 | In: $0.15, Out: $0.60, Cache: $0.08 |
| O1-Preview | o1-preview | openai | 200000 | 100000 | In: $15.00, Out: $60.00 |
| O1-Preview 20240912 | o1-preview-2024-09-12 | openai | 200000 | 100000 | In: $15.00, Out: $60.00 |
| Omni Moderation 20240926 | omni-moderation-2024-09-26 | openai | - | - | - |
| codex-mini-latest | codex-mini-latest | openai | 200000 | 100000 | In: $1.50, Out: $6.00, Cache: $0.38 |
| computer-use-preview | computer-use-preview | openai | 8192 | 1024 | In: $3.00, Out: $12.00 |
| computer-use-preview | computer-use-preview-2025-03-11 | openai | 8192 | 1024 | In: $3.00, Out: $12.00 |
| o1 | o1 | openai | 200000 | 100000 | In: $15.00, Out: $60.00, Cache: $7.50 |
| o1 | o1-2024-12-17 | openai | 200000 | 100000 | In: $15.00, Out: $60.00, Cache: $7.50 |
| o1-pro | o1-pro | openai | 200000 | 100000 | In: $150.00, Out: $600.00 |
| o1-pro | o1-pro-2025-03-19 | openai | 200000 | 100000 | In: $150.00, Out: $600.00 |
| o3 | o3 | openai | 200000 | 100000 | In: $2.00, Out: $8.00, Cache: $0.50 |
| o3 | o3-2025-04-16 | openai | 200000 | 100000 | In: $2.00, Out: $8.00, Cache: $0.50 |
| o3-deep-research | o3-deep-research | openai | 200000 | 100000 | In: $10.00, Out: $40.00, Cache: $2.50 |
| o3-deep-research | o3-deep-research-2025-06-26 | openai | 200000 | 100000 | In: $10.00, Out: $40.00, Cache: $2.50 |
| o3-pro | o3-pro | openai | 200000 | 100000 | In: $20.00, Out: $80.00 |
| o3-pro | o3-pro-2025-06-10 | openai | 200000 | 100000 | In: $20.00, Out: $80.00 |
| o4-mini | o4-mini | openai | 200000 | 100000 | In: $1.10, Out: $4.40, Cache: $0.28 |
| o4-mini | o4-mini-2025-04-16 | openai | 200000 | 100000 | In: $1.10, Out: $4.40, Cache: $0.28 |
| o4-mini-deep-research | o4-mini-deep-research | openai | 200000 | 100000 | In: $2.00, Out: $8.00, Cache: $0.50 |
| o4-mini-deep-research | o4-mini-deep-research-2025-06-26 | openai | 200000 | 100000 | In: $2.00, Out: $8.00, Cache: $0.50 |
| omni-moderation | omni-moderation-latest | openai | - | - | - |
| Amazon: Nova Lite 1.0 | amazon/nova-lite-v1 | openrouter | 300000 | 5120 | In: $0.06, Out: $0.24 |
| Amazon: Nova Pro 1.0 | amazon/nova-pro-v1 | openrouter | 300000 | 5120 | In: $0.80, Out: $3.20 |
| Anthropic: Claude 3 Haiku | anthropic/claude-3-haiku | openrouter | 200000 | 4096 | In: $0.25, Out: $1.25, Cache: $0.03 |
| Anthropic: Claude 3 Haiku (self-moderated) | anthropic/claude-3-haiku:beta | openrouter | 200000 | 4096 | In: $0.25, Out: $1.25, Cache: $0.03 |
| Anthropic: Claude 3 Opus | anthropic/claude-3-opus | openrouter | 200000 | 4096 | In: $15.00, Out: $75.00, Cache: $1.50 |
| Anthropic: Claude 3 Opus (self-moderated) | anthropic/claude-3-opus:beta | openrouter | 200000 | 4096 | In: $15.00, Out: $75.00, Cache: $1.50 |
| Anthropic: Claude 3 Sonnet | anthropic/claude-3-sonnet | openrouter | 200000 | 4096 | In: $3.00, Out: $15.00, Cache: $0.30 |
| Anthropic: Claude 3 Sonnet (self-moderated) | anthropic/claude-3-sonnet:beta | openrouter | 200000 | 4096 | In: $3.00, Out: $15.00, Cache: $0.30 |
| Anthropic: Claude 3.5 Haiku | anthropic/claude-3.5-haiku | openrouter | 200000 | 8192 | In: $0.80, Out: $4.00, Cache: $0.08 |
| Anthropic: Claude 3.5 Haiku (2024-10-22) | anthropic/claude-3.5-haiku-20241022 | openrouter | 200000 | 8192 | In: $0.80, Out: $4.00, Cache: $0.08 |
| Anthropic: Claude 3.5 Haiku (2024-10-22) (self-moderated) | anthropic/claude-3.5-haiku-20241022:beta | openrouter | 200000 | 8192 | In: $0.80, Out: $4.00, Cache: $0.08 |
| Anthropic: Claude 3.5 Haiku (self-moderated) | anthropic/claude-3.5-haiku:beta | openrouter | 200000 | 8192 | In: $0.80, Out: $4.00, Cache: $0.08 |
| Anthropic: Claude 3.5 Sonnet | anthropic/claude-3.5-sonnet | openrouter | 200000 | 8192 | In: $3.00, Out: $15.00, Cache: $0.30 |
| Anthropic: Claude 3.5 Sonnet (2024-06-20) | anthropic/claude-3.5-sonnet-20240620 | openrouter | 200000 | 8192 | In: $3.00, Out: $15.00, Cache: $0.30 |
| Anthropic: Claude 3.5 Sonnet (2024-06-20) (self-moderated) | anthropic/claude-3.5-sonnet-20240620:beta | openrouter | 200000 | 8192 | In: $3.00, Out: $15.00, Cache: $0.30 |
| Anthropic: Claude 3.5 Sonnet (self-moderated) | anthropic/claude-3.5-sonnet:beta | openrouter | 200000 | 8192 | In: $3.00, Out: $15.00, Cache: $0.30 |
| Anthropic: Claude 3.7 Sonnet | anthropic/claude-3.7-sonnet | openrouter | 200000 | 64000 | In: $3.00, Out: $15.00, Cache: $0.30 |
| Anthropic: Claude 3.7 Sonnet (self-moderated) | anthropic/claude-3.7-sonnet:beta | openrouter | 200000 | 128000 | In: $3.00, Out: $15.00, Cache: $0.30 |
| Anthropic: Claude 3.7 Sonnet (thinking) | anthropic/claude-3.7-sonnet:thinking | openrouter | 200000 | 64000 | In: $3.00, Out: $15.00, Cache: $0.30 |
| Anthropic: Claude Opus 4 | anthropic/claude-opus-4 | openrouter | 200000 | 32000 | In: $15.00, Out: $75.00, Cache: $1.50 |
| Anthropic: Claude Sonnet 4 | anthropic/claude-sonnet-4 | openrouter | 200000 | 64000 | In: $3.00, Out: $15.00, Cache: $0.30 |
| Arcee AI: Spotlight | arcee-ai/spotlight | openrouter | 131072 | 65537 | In: $0.18, Out: $0.18 |
| Google: Gemini 1.5 Flash  | google/gemini-flash-1.5 | openrouter | 1000000 | 8192 | In: $0.08, Out: $0.30, Cache: $0.02 |
| Google: Gemini 1.5 Flash 8B | google/gemini-flash-1.5-8b | openrouter | 1000000 | 8192 | In: $0.04, Out: $0.15, Cache: $0.01 |
| Google: Gemini 1.5 Pro | google/gemini-pro-1.5 | openrouter | 2000000 | 8192 | In: $1.25, Out: $5.00 |
| Google: Gemini 2.0 Flash | google/gemini-2.0-flash-001 | openrouter | 1048576 | 8192 | In: $0.10, Out: $0.40, Cache: $0.02 |
| Google: Gemini 2.0 Flash Experimental (free) | google/gemini-2.0-flash-exp:free | openrouter | 1048576 | 8192 | - |
| Google: Gemini 2.0 Flash Lite | google/gemini-2.0-flash-lite-001 | openrouter | 1048576 | 8192 | In: $0.08, Out: $0.30 |
| Google: Gemini 2.5 Flash | google/gemini-2.5-flash | openrouter | 1048576 | 65535 | In: $0.30, Out: $2.50, Cache: $0.08 |
| Google: Gemini 2.5 Flash Lite Preview 06-17 | google/gemini-2.5-flash-lite-preview-06-17 | openrouter | 1048576 | 65535 | In: $0.10, Out: $0.40, Cache: $0.02 |
| Google: Gemini 2.5 Pro | google/gemini-2.5-pro | openrouter | 1048576 | 65536 | In: $1.25, Out: $10.00, Cache: $0.31 |
| Google: Gemini 2.5 Pro Experimental | google/gemini-2.5-pro-exp-03-25 | openrouter | 1048576 | 65535 | - |
| Google: Gemini 2.5 Pro Preview 05-06 | google/gemini-2.5-pro-preview-05-06 | openrouter | 1048576 | 65535 | In: $1.25, Out: $10.00, Cache: $0.31 |
| Google: Gemini 2.5 Pro Preview 06-05 | google/gemini-2.5-pro-preview | openrouter | 1048576 | 65536 | In: $1.25, Out: $10.00, Cache: $0.31 |
| Google: Gemma 3 12B | google/gemma-3-12b-it | openrouter | 96000 | 8192 | In: $0.03, Out: $0.03 |
| Google: Gemma 3 12B (free) | google/gemma-3-12b-it:free | openrouter | 96000 | 8192 | - |
| Google: Gemma 3 27B | google/gemma-3-27b-it | openrouter | 131072 | 16384 | In: $0.09, Out: $0.17 |
| Google: Gemma 3 27B (free) | google/gemma-3-27b-it:free | openrouter | 96000 | 8192 | - |
| Google: Gemma 3 4B | google/gemma-3-4b-it | openrouter | 131072 | - | In: $0.02, Out: $0.04 |
| Google: Gemma 3 4B (free) | google/gemma-3-4b-it:free | openrouter | 32768 | 8192 | - |
| Meta: Llama 3.2 11B Vision Instruct | meta-llama/llama-3.2-11b-vision-instruct | openrouter | 131072 | 16384 | In: $0.05, Out: $0.05 |
| Meta: Llama 3.2 11B Vision Instruct (free) | meta-llama/llama-3.2-11b-vision-instruct:free | openrouter | 131072 | 2048 | - |
| Meta: Llama 3.2 90B Vision Instruct | meta-llama/llama-3.2-90b-vision-instruct | openrouter | 131072 | 2048 | In: $1.20, Out: $1.20 |
| Meta: Llama 4 Maverick | meta-llama/llama-4-maverick | openrouter | 1048576 | 16384 | In: $0.15, Out: $0.60 |
| Meta: Llama 4 Scout | meta-llama/llama-4-scout | openrouter | 1048576 | 1048576 | In: $0.08, Out: $0.30 |
| Meta: Llama Guard 4 12B | meta-llama/llama-guard-4-12b | openrouter | 163840 | - | In: $0.05, Out: $0.05 |
| Microsoft: Phi 4 Multimodal Instruct | microsoft/phi-4-multimodal-instruct | openrouter | 131072 | - | In: $0.05, Out: $0.10 |
| MiniMax: MiniMax-01 | minimax/minimax-01 | openrouter | 1000192 | 1000192 | In: $0.20, Out: $1.10 |
| Mistral: Mistral Medium 3 | mistralai/mistral-medium-3 | openrouter | 131072 | - | In: $0.40, Out: $2.00 |
| Mistral: Mistral Small 3.1 24B | mistralai/mistral-small-3.1-24b-instruct | openrouter | 128000 | - | In: $0.05, Out: $0.10 |
| Mistral: Mistral Small 3.1 24B (free) | mistralai/mistral-small-3.1-24b-instruct:free | openrouter | 128000 | - | - |
| Mistral: Mistral Small 3.2 24B | mistralai/mistral-small-3.2-24b-instruct | openrouter | 128000 | - | In: $0.05, Out: $0.10 |
| Mistral: Mistral Small 3.2 24B (free) | mistralai/mistral-small-3.2-24b-instruct:free | openrouter | 96000 | - | - |
| Mistral: Pixtral 12B | mistralai/pixtral-12b | openrouter | 32768 | - | In: $0.10, Out: $0.10 |
| Mistral: Pixtral Large 2411 | mistralai/pixtral-large-2411 | openrouter | 131072 | - | In: $2.00, Out: $6.00 |
| Moonshot AI: Kimi VL A3B Thinking (free) | moonshotai/kimi-vl-a3b-thinking:free | openrouter | 131072 | - | - |
| OpenAI: ChatGPT-4o | openai/chatgpt-4o-latest | openrouter | 128000 | 16384 | In: $5.00, Out: $15.00 |
| OpenAI: Codex Mini | openai/codex-mini | openrouter | 200000 | 100000 | In: $1.50, Out: $6.00, Cache: $0.38 |
| OpenAI: GPT-4 Turbo | openai/gpt-4-turbo | openrouter | 128000 | 4096 | In: $10.00, Out: $30.00 |
| OpenAI: GPT-4.1 | openai/gpt-4.1 | openrouter | 1047576 | 32768 | In: $2.00, Out: $8.00, Cache: $0.50 |
| OpenAI: GPT-4.1 Mini | openai/gpt-4.1-mini | openrouter | 1047576 | 32768 | In: $0.40, Out: $1.60, Cache: $0.10 |
| OpenAI: GPT-4.1 Nano | openai/gpt-4.1-nano | openrouter | 1047576 | 32768 | In: $0.10, Out: $0.40, Cache: $0.02 |
| OpenAI: GPT-4o | openai/gpt-4o | openrouter | 128000 | 16384 | In: $2.50, Out: $10.00, Cache: $1.25 |
| OpenAI: GPT-4o (2024-05-13) | openai/gpt-4o-2024-05-13 | openrouter | 128000 | 4096 | In: $5.00, Out: $15.00 |
| OpenAI: GPT-4o (2024-08-06) | openai/gpt-4o-2024-08-06 | openrouter | 128000 | 16384 | In: $2.50, Out: $10.00, Cache: $1.25 |
| OpenAI: GPT-4o (2024-11-20) | openai/gpt-4o-2024-11-20 | openrouter | 128000 | 16384 | In: $2.50, Out: $10.00, Cache: $1.25 |
| OpenAI: GPT-4o (extended) | openai/gpt-4o:extended | openrouter | 128000 | 64000 | In: $6.00, Out: $18.00 |
| OpenAI: GPT-4o-mini | openai/gpt-4o-mini | openrouter | 128000 | 16384 | In: $0.15, Out: $0.60, Cache: $0.08 |
| OpenAI: GPT-4o-mini (2024-07-18) | openai/gpt-4o-mini-2024-07-18 | openrouter | 128000 | 16384 | In: $0.15, Out: $0.60, Cache: $0.08 |
| OpenAI: o1 | openai/o1 | openrouter | 200000 | 100000 | In: $15.00, Out: $60.00, Cache: $7.50 |
| OpenAI: o1-pro | openai/o1-pro | openrouter | 200000 | 100000 | In: $150.00, Out: $600.00 |
| OpenAI: o3 | openai/o3 | openrouter | 200000 | 100000 | In: $2.00, Out: $8.00, Cache: $0.50 |
| OpenAI: o3 Pro | openai/o3-pro | openrouter | 200000 | 100000 | In: $20.00, Out: $80.00 |
| OpenAI: o4 Mini | openai/o4-mini | openrouter | 200000 | 100000 | In: $1.10, Out: $4.40, Cache: $0.28 |
| OpenAI: o4 Mini High | openai/o4-mini-high | openrouter | 200000 | 100000 | In: $1.10, Out: $4.40, Cache: $0.28 |
| OpenGVLab: InternVL3 14B | opengvlab/internvl3-14b | openrouter | 12288 | - | In: $0.20, Out: $0.40 |
| Perplexity: Sonar | perplexity/sonar | openrouter | 127072 | - | In: $1.00, Out: $1.00 |
| Perplexity: Sonar Pro | perplexity/sonar-pro | openrouter | 200000 | 8000 | In: $3.00, Out: $15.00 |
| Perplexity: Sonar Reasoning Pro | perplexity/sonar-reasoning-pro | openrouter | 128000 | - | In: $2.00, Out: $8.00 |
| Qwen: Qwen VL Max | qwen/qwen-vl-max | openrouter | 7500 | 1500 | In: $0.80, Out: $3.20 |
| Qwen: Qwen VL Plus | qwen/qwen-vl-plus | openrouter | 7500 | 1500 | In: $0.21, Out: $0.63 |
| Qwen: Qwen2.5 VL 32B Instruct | qwen/qwen2.5-vl-32b-instruct | openrouter | 128000 | - | In: $0.20, Out: $0.60 |
| Qwen: Qwen2.5 VL 32B Instruct (free) | qwen/qwen2.5-vl-32b-instruct:free | openrouter | 8192 | - | - |
| Qwen: Qwen2.5 VL 72B Instruct | qwen/qwen2.5-vl-72b-instruct | openrouter | 32000 | - | In: $0.25, Out: $0.75 |
| Qwen: Qwen2.5 VL 72B Instruct (free) | qwen/qwen2.5-vl-72b-instruct:free | openrouter | 32768 | - | - |
| Qwen: Qwen2.5-VL 7B Instruct | qwen/qwen-2.5-vl-7b-instruct | openrouter | 32768 | - | In: $0.20, Out: $0.20 |
| THUDM: GLM 4.1V 9B Thinking | thudm/glm-4.1v-9b-thinking | openrouter | 65536 | 8000 | In: $0.04, Out: $0.14 |
| xAI: Grok 2 Vision 1212 | x-ai/grok-2-vision-1212 | openrouter | 32768 | - | In: $2.00, Out: $10.00 |
| xAI: Grok 4 | x-ai/grok-4 | openrouter | 256000 | - | In: $3.00, Out: $15.00, Cache: $0.75 |
| xAI: Grok Vision Beta | x-ai/grok-vision-beta | openrouter | 8192 | - | In: $5.00, Out: $15.00 |


### Audio Input Models (42)

Models that can process audio:

| Model | ID | Provider | Context | Max Output | Standard Pricing (per 1M tokens) |
| :-- | :-- | :-- | --: | --: | :-- |
| Gemini 1.5 Flash | gemini-1.5-flash | gemini | 1048576 | 8192 | In: $0.08, Out: $0.30, Cache: $0.02 |
| Gemini 1.5 Flash | gemini-1.5-flash-001 | gemini | 1048576 | 8192 | In: $0.08, Out: $0.30, Cache: $0.02 |
| Gemini 1.5 Flash | gemini-1.5-flash-002 | gemini | 1048576 | 8192 | In: $0.08, Out: $0.30, Cache: $0.02 |
| Gemini 1.5 Flash | gemini-1.5-flash-latest | gemini | 1048576 | 8192 | In: $0.08, Out: $0.30, Cache: $0.02 |
| Gemini 1.5 Flash-8B | gemini-1.5-flash-8b | gemini | 1048576 | 8192 | In: $0.08, Out: $0.30, Cache: $0.02 |
| Gemini 1.5 Flash-8B | gemini-1.5-flash-8b-001 | gemini | 1048576 | 8192 | In: $0.08, Out: $0.30, Cache: $0.02 |
| Gemini 1.5 Flash-8B | gemini-1.5-flash-8b-latest | gemini | 1048576 | 8192 | In: $0.08, Out: $0.30, Cache: $0.02 |
| Gemini 1.5 Pro | gemini-1.5-pro | gemini | 2097152 | 8192 | In: $1.25, Out: $5.00, Cache: $0.31 |
| Gemini 1.5 Pro | gemini-1.5-pro-001 | gemini | 2097152 | 8192 | In: $1.25, Out: $5.00, Cache: $0.31 |
| Gemini 1.5 Pro | gemini-1.5-pro-002 | gemini | 2097152 | 8192 | In: $1.25, Out: $5.00, Cache: $0.31 |
| Gemini 1.5 Pro | gemini-1.5-pro-latest | gemini | 2097152 | 8192 | In: $1.25, Out: $5.00, Cache: $0.31 |
| Gemini 2.0 Flash | gemini-2.0-flash | gemini | 1048576 | 8192 | In: $0.10, Out: $0.40, Cache: $0.02 |
| Gemini 2.0 Flash | gemini-2.0-flash-001 | gemini | 1048576 | 8192 | In: $0.10, Out: $0.40, Cache: $0.02 |
| Gemini 2.0 Flash | gemini-2.0-flash-exp | gemini | 1048576 | 8192 | In: $0.10, Out: $0.40, Cache: $0.02 |
| Gemini 2.0 Flash Live | gemini-2.0-flash-live-001 | gemini | 1048576 | 8192 | In: $0.10, Out: $0.40, Cache: $0.02 |
| Gemini 2.0 Flash Preview Image Generation | gemini-2.0-flash-preview-image-generation | gemini | 32000 | 8192 | In: $0.10, Out: $0.40, Cache: $0.02 |
| Gemini 2.0 Flash-Lite | gemini-2.0-flash-lite | gemini | 1048576 | 8192 | In: $0.10, Out: $0.40, Cache: $0.02 |
| Gemini 2.0 Flash-Lite | gemini-2.0-flash-lite-001 | gemini | 1048576 | 8192 | In: $0.10, Out: $0.40, Cache: $0.02 |
| Gemini 2.5 Flash | gemini-2.5-flash | gemini | 1048576 | 65536 | In: $0.30, Out: $2.50, Cache: $0.08 |
| Gemini 2.5 Flash | gemini-2.5-flash-preview-05-20 | gemini | 1048576 | 65536 | In: $0.30, Out: $2.50, Cache: $0.08 |
| Gemini 2.5 Flash Live | gemini-live-2.5-flash-preview | gemini | 1048576 | 8192 | In: $0.30, Out: $2.50, Cache: $0.08 |
| Gemini 2.5 Flash Native Audio | gemini-2.5-flash-exp-native-audio-thinking-dialog | gemini | 128000 | 8000 | In: $0.30, Out: $2.50, Cache: $0.08 |
| Gemini 2.5 Flash Native Audio | gemini-2.5-flash-preview-native-audio-dialog | gemini | 128000 | 8000 | In: $0.30, Out: $2.50, Cache: $0.08 |
| Gemini 2.5 Flash-Lite Preview | gemini-2.5-flash-lite-preview-06-17 | gemini | 1000000 | 64000 | In: $0.30, Out: $2.50, Cache: $0.08 |
| Gemini 2.5 Pro | gemini-2.5-pro | gemini | 1048576 | 65536 | In: $1.25, Out: $10.00, Cache: $0.31 |
| Gemini 2.5 Pro | gemini-2.5-pro-preview-03-25 | gemini | 1048576 | 65536 | In: $1.25, Out: $10.00, Cache: $0.31 |
| Gemini 2.5 Pro | gemini-2.5-pro-preview-05-06 | gemini | 1048576 | 65536 | In: $1.25, Out: $10.00, Cache: $0.31 |
| Gemini 2.5 Pro | gemini-2.5-pro-preview-06-05 | gemini | 1048576 | 65536 | In: $1.25, Out: $10.00, Cache: $0.31 |
| GPT-4o Audio | gpt-4o-audio-preview | openai | 128000 | 16384 | In: $2.50, Out: $10.00 |
| GPT-4o Realtime | gpt-4o-realtime-preview | openai | 32000 | 4096 | In: $5.00, Out: $20.00, Cache: $2.50 |
| GPT-4o Transcribe | gpt-4o-transcribe | openai | 16000 | 2000 | In: $2.50, Out: $10.00 |
| GPT-4o mini Audio | gpt-4o-mini-audio-preview | openai | 128000 | 16384 | In: $0.15, Out: $0.60 |
| GPT-4o mini Audio | gpt-4o-mini-audio-preview-2024-12-17 | openai | 128000 | 16384 | In: $0.15, Out: $0.60 |
| GPT-4o mini Realtime | gpt-4o-mini-realtime-preview | openai | 128000 | 4096 | In: $0.60, Out: $2.40, Cache: $0.30 |
| GPT-4o mini Realtime | gpt-4o-mini-realtime-preview-2024-12-17 | openai | 128000 | 4096 | In: $0.60, Out: $2.40, Cache: $0.30 |
| GPT-4o mini Transcribe | gpt-4o-mini-transcribe | openai | 16000 | 2000 | In: $1.25, Out: $5.00 |
| GPT-4o-Audio Preview 20241001 | gpt-4o-audio-preview-2024-10-01 | openai | 128000 | 16384 | In: $2.50, Out: $10.00 |
| GPT-4o-Audio Preview 20241217 | gpt-4o-audio-preview-2024-12-17 | openai | 128000 | 16384 | In: $2.50, Out: $10.00 |
| GPT-4o-Audio Preview 20250603 | gpt-4o-audio-preview-2025-06-03 | openai | 128000 | 16384 | In: $2.50, Out: $10.00 |
| TTS-1 1106 | tts-1-1106 | openai | - | - | In: $15.00, Out: $15.00 |
| TTS-1 HD 1106 | tts-1-hd-1106 | openai | - | - | In: $30.00, Out: $30.00 |
| Whisper | whisper-1 | openai | - | - | In: $0.01 |


### PDF Models (49)

Models that can process PDF documents:

| Model | ID | Provider | Context | Max Output | Standard Pricing (per 1M tokens) |
| :-- | :-- | :-- | --: | --: | :-- |
| Claude Sonnet 3 | claude-3-sonnet-20240229 | anthropic | 200000 | 4096 | In: $3.00, Out: $15.00 |
| Claude | anthropic.claude-v2 | bedrock | 200000 | 4096 | In: $8.00, Out: $24.00 |
| Claude | anthropic.claude-v2:0:100k | bedrock | 200000 | 4096 | In: $8.00, Out: $24.00 |
| Claude | anthropic.claude-v2:0:18k | bedrock | 200000 | 4096 | In: $8.00, Out: $24.00 |
| Claude | anthropic.claude-v2:1 | bedrock | 200000 | 4096 | In: $8.00, Out: $24.00 |
| Claude | anthropic.claude-v2:1:18k | bedrock | 200000 | 4096 | In: $8.00, Out: $24.00 |
| Claude | anthropic.claude-v2:1:200k | bedrock | 200000 | 4096 | In: $8.00, Out: $24.00 |
| Claude 3 Haiku | anthropic.claude-3-haiku-20240307-v1:0 | bedrock | 200000 | 4096 | In: $0.25, Out: $1.25 |
| Claude 3 Haiku | anthropic.claude-3-haiku-20240307-v1:0:200k | bedrock | 200000 | 4096 | In: $0.25, Out: $1.25 |
| Claude 3 Haiku | anthropic.claude-3-haiku-20240307-v1:0:48k | bedrock | 200000 | 4096 | In: $0.25, Out: $1.25 |
| Claude 3 Opus | anthropic.claude-3-opus-20240229-v1:0 | bedrock | 200000 | 4096 | In: $15.00, Out: $75.00 |
| Claude 3 Opus | anthropic.claude-3-opus-20240229-v1:0:12k | bedrock | 200000 | 4096 | In: $15.00, Out: $75.00 |
| Claude 3 Opus | anthropic.claude-3-opus-20240229-v1:0:200k | bedrock | 200000 | 4096 | In: $15.00, Out: $75.00 |
| Claude 3 Opus | anthropic.claude-3-opus-20240229-v1:0:28k | bedrock | 200000 | 4096 | In: $15.00, Out: $75.00 |
| Claude 3 Sonnet | anthropic.claude-3-sonnet-20240229-v1:0 | bedrock | 200000 | 4096 | In: $3.00, Out: $15.00 |
| Claude 3 Sonnet | anthropic.claude-3-sonnet-20240229-v1:0:200k | bedrock | 200000 | 4096 | In: $3.00, Out: $15.00 |
| Claude 3 Sonnet | anthropic.claude-3-sonnet-20240229-v1:0:28k | bedrock | 200000 | 4096 | In: $3.00, Out: $15.00 |
| Claude 3.5 Haiku | anthropic.claude-3-5-haiku-20241022-v1:0 | bedrock | 200000 | 4096 | In: $0.80, Out: $4.00 |
| Claude 3.5 Sonnet | anthropic.claude-3-5-sonnet-20240620-v1:0 | bedrock | 200000 | 4096 | In: $3.00, Out: $15.00 |
| Claude 3.5 Sonnet | anthropic.claude-3-5-sonnet-20240620-v1:0:18k | bedrock | 200000 | 4096 | In: $3.00, Out: $15.00 |
| Claude 3.5 Sonnet | anthropic.claude-3-5-sonnet-20240620-v1:0:200k | bedrock | 200000 | 4096 | In: $3.00, Out: $15.00 |
| Claude 3.5 Sonnet | anthropic.claude-3-5-sonnet-20240620-v1:0:51k | bedrock | 200000 | 4096 | In: $3.00, Out: $15.00 |
| Claude 3.5 Sonnet v2 | anthropic.claude-3-5-sonnet-20241022-v2:0 | bedrock | 200000 | 4096 | In: $3.00, Out: $15.00 |
| Claude 3.5 Sonnet v2 | anthropic.claude-3-5-sonnet-20241022-v2:0:18k | bedrock | 200000 | 4096 | In: $3.00, Out: $15.00 |
| Claude 3.5 Sonnet v2 | anthropic.claude-3-5-sonnet-20241022-v2:0:200k | bedrock | 200000 | 4096 | In: $3.00, Out: $15.00 |
| Claude 3.5 Sonnet v2 | anthropic.claude-3-5-sonnet-20241022-v2:0:51k | bedrock | 200000 | 4096 | In: $3.00, Out: $15.00 |
| Claude 3.7 Sonnet | us.anthropic.claude-3-7-sonnet-20250219-v1:0 | bedrock | 200000 | 4096 | In: $3.00, Out: $15.00 |
| Claude Instant | anthropic.claude-instant-v1 | bedrock | 200000 | 4096 | In: $0.80, Out: $2.40 |
| Claude Instant | anthropic.claude-instant-v1:2:100k | bedrock | 200000 | 4096 | In: $0.80, Out: $2.40 |
| Claude Opus 4 | us.anthropic.claude-opus-4-20250514-v1:0 | bedrock | 200000 | 4096 | In: $0.10, Out: $0.20 |
| Claude Sonnet 4 | us.anthropic.claude-sonnet-4-20250514-v1:0 | bedrock | 200000 | 4096 | In: $0.10, Out: $0.20 |
| Gemini 1.0 Pro Vision | gemini-1.0-pro-vision-latest | gemini | 12288 | 4096 | In: $0.08, Out: $0.30 |
| Gemini 1.0 Pro Vision | gemini-pro-vision | gemini | 12288 | 4096 | In: $0.08, Out: $0.30 |
| Gemini 2.0 Flash-Lite Preview | gemini-2.0-flash-lite-preview | gemini | 1048576 | 8192 | In: $0.08, Out: $0.30 |
| Gemini 2.0 Flash-Lite Preview 02-05 | gemini-2.0-flash-lite-preview-02-05 | gemini | 1048576 | 8192 | In: $0.08, Out: $0.30 |
| Gemini 2.0 Pro Experimental | gemini-2.0-pro-exp | gemini | 1048576 | 65536 | In: $0.08, Out: $0.30 |
| Gemini 2.0 Pro Experimental 02-05 | gemini-2.0-pro-exp-02-05 | gemini | 1048576 | 65536 | In: $0.08, Out: $0.30 |
| Gemini 2.5 Flash Preview 05-20 | gemini-2.0-flash-thinking-exp | gemini | 1048576 | 65536 | In: $0.10, Out: $0.40 |
| Gemini 2.5 Flash Preview 05-20 | gemini-2.0-flash-thinking-exp-01-21 | gemini | 1048576 | 65536 | In: $0.10, Out: $0.40 |
| Gemini 2.5 Flash Preview 05-20 | gemini-2.0-flash-thinking-exp-1219 | gemini | 1048576 | 65536 | In: $0.10, Out: $0.40 |
| Gemini Embedding Experimental | gemini-embedding-exp | gemini | 8192 | 1 | In: $0.00, Out: $0.00 |
| Gemini Experimental 1206 | gemini-exp-1206 | gemini | 1048576 | 65536 | In: $0.08, Out: $0.30 |
| LearnLM 2.0 Flash Experimental | learnlm-2.0-flash-experimental | gemini | 1048576 | 32768 | In: $0.08, Out: $0.30 |
| GPT-4 Turbo Preview | gpt-4-turbo-preview | openai | 128000 | 4096 | In: $10.00, Out: $30.00 |
| GPT-4o 20240513 | gpt-4o-2024-05-13 | openai | 128000 | 16384 | In: $2.50, Out: $10.00 |
| GPT-4o 20241120 | gpt-4o-2024-11-20 | openai | 128000 | 16384 | In: $2.50, Out: $10.00 |
| O1-Preview | o1-preview | openai | 200000 | 100000 | In: $15.00, Out: $60.00 |
| O1-Preview 20240912 | o1-preview-2024-09-12 | openai | 200000 | 100000 | In: $15.00, Out: $60.00 |
| Omni Moderation 20240926 | omni-moderation-2024-09-26 | openai | - | - | - |


### Embedding Models (9)

Models that generate embeddings:

| Model | ID | Provider | Context | Max Output | Standard Pricing (per 1M tokens) |
| :-- | :-- | :-- | --: | --: | :-- |
| Embedding 001 | embedding-001 | gemini | 2048 | 1 | - |
| Embedding Gecko | embedding-gecko-001 | gemini | 1024 | 1 | - |
| Gemini Embedding | gemini-embedding-001 | gemini | 2048 | - | In: $0.15 |
| Gemini Embedding | gemini-embedding-exp-03-07 | gemini | 2048 | - | In: $0.15 |
| Gemini Embedding Experimental | gemini-embedding-exp | gemini | 8192 | 1 | In: $0.00, Out: $0.00 |
| Legacy Embedding Models | text-embedding-004 | gemini | 2048 | - | - |
| text-embedding-3-large | text-embedding-3-large | openai | - | - | In: $0.13 |
| text-embedding-3-small | text-embedding-3-small | openai | - | - | In: $0.02 |
| text-embedding-ada-002 | text-embedding-ada-002 | openai | - | - | In: $0.10 |

