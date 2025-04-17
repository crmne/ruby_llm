---
layout: default
title: Available Models
parent: Guides
nav_order: 10
permalink: /guides/available-models
---

# Available Models
{: .no_toc }

This guide lists all models available in RubyLLM, automatically generated from the current model registry.
{: .fs-6 .fw-300 }

## Table of contents
{: .no_toc .text-delta }

1. TOC
{:toc}

---

## Contributing

The model list is automatically generated from the model registry. To add or update models:

1. Edit the appropriate `capabilities.rb` file in `lib/ruby_llm/providers/<provider>/`
2. Run `rake models:update` to refresh the model registry
3. Submit a pull request with the updated `models.json`

See [Contributing Guide](/CONTRIBUTING.md) for more details.

## Additional Model Information

The tables below show basic model information including context windows, token limits, and pricing. Models also have additional capabilities not shown in the tables:

- **Vision Support**: Whether the model can process images
- **Function Calling**: Whether the model supports function calling
- **JSON Mode**: Whether the model can be constrained to output valid JSON
- **Structured Output**: Whether the model supports structured output formats

For complete model information, you can check the `models.json` file in the RubyLLM source code.

For more information about working with models, see the [Working with Models](/guides/models) guide.

## Models by Type
{: .d-inline-block }

Last updated: 2025-04-15
{: .label .label-green }

### Chat Models (135)

| ID | Type | Name | Provider | Context | MaxTok | Family | In$/M | Out$/M |
| :-- | :-- | :-- | :-- | --: | --: | :-- | --: | --: |
| anthropic.claude-3-5-haiku-20241022-v1:0 | chat | Claude 3.5 Haiku | bedrock | 200000 | 4096 | claude3_5_haiku | 0.80 | 4.00 |
| anthropic.claude-3-5-sonnet-20240620-v1:0 | chat | Claude 3.5 Sonnet | bedrock | 200000 | 4096 | claude3_sonnet | 3.00 | 15.00 |
| anthropic.claude-3-5-sonnet-20240620-v1:0:18k | chat | Claude 3.5 Sonnet | bedrock | 200000 | 4096 | claude3_sonnet | 3.00 | 15.00 |
| anthropic.claude-3-5-sonnet-20240620-v1:0:200k | chat | Claude 3.5 Sonnet | bedrock | 200000 | 4096 | claude3_sonnet | 3.00 | 15.00 |
| anthropic.claude-3-5-sonnet-20240620-v1:0:51k | chat | Claude 3.5 Sonnet | bedrock | 200000 | 4096 | claude3_sonnet | 3.00 | 15.00 |
| anthropic.claude-3-5-sonnet-20241022-v2:0 | chat | Claude 3.5 Sonnet v2 | bedrock | 200000 | 4096 | claude3_sonnet | 3.00 | 15.00 |
| anthropic.claude-3-5-sonnet-20241022-v2:0:18k | chat | Claude 3.5 Sonnet v2 | bedrock | 200000 | 4096 | claude3_sonnet | 3.00 | 15.00 |
| anthropic.claude-3-5-sonnet-20241022-v2:0:200k | chat | Claude 3.5 Sonnet v2 | bedrock | 200000 | 4096 | claude3_sonnet | 3.00 | 15.00 |
| anthropic.claude-3-5-sonnet-20241022-v2:0:51k | chat | Claude 3.5 Sonnet v2 | bedrock | 200000 | 4096 | claude3_sonnet | 3.00 | 15.00 |
| anthropic.claude-3-7-sonnet-20250219-v1:0 | chat | Claude 3.7 Sonnet | bedrock | 200000 | 4096 | claude3_sonnet | 3.00 | 15.00 |
| anthropic.claude-3-haiku-20240307-v1:0 | chat | Claude 3 Haiku | bedrock | 200000 | 4096 | claude3_haiku | 0.25 | 1.25 |
| anthropic.claude-3-haiku-20240307-v1:0:200k | chat | Claude 3 Haiku | bedrock | 200000 | 4096 | claude3_haiku | 0.25 | 1.25 |
| anthropic.claude-3-haiku-20240307-v1:0:48k | chat | Claude 3 Haiku | bedrock | 200000 | 4096 | claude3_haiku | 0.25 | 1.25 |
| anthropic.claude-3-opus-20240229-v1:0 | chat | Claude 3 Opus | bedrock | 200000 | 4096 | claude3_opus | 15.00 | 75.00 |
| anthropic.claude-3-opus-20240229-v1:0:12k | chat | Claude 3 Opus | bedrock | 200000 | 4096 | claude3_opus | 15.00 | 75.00 |
| anthropic.claude-3-opus-20240229-v1:0:200k | chat | Claude 3 Opus | bedrock | 200000 | 4096 | claude3_opus | 15.00 | 75.00 |
| anthropic.claude-3-opus-20240229-v1:0:28k | chat | Claude 3 Opus | bedrock | 200000 | 4096 | claude3_opus | 15.00 | 75.00 |
| anthropic.claude-3-sonnet-20240229-v1:0 | chat | Claude 3 Sonnet | bedrock | 200000 | 4096 | claude3_sonnet | 3.00 | 15.00 |
| anthropic.claude-3-sonnet-20240229-v1:0:200k | chat | Claude 3 Sonnet | bedrock | 200000 | 4096 | claude3_sonnet | 3.00 | 15.00 |
| anthropic.claude-3-sonnet-20240229-v1:0:28k | chat | Claude 3 Sonnet | bedrock | 200000 | 4096 | claude3_sonnet | 3.00 | 15.00 |
| anthropic.claude-instant-v1 | chat | Claude Instant | bedrock | 200000 | 4096 | claude_instant | 0.80 | 2.40 |
| anthropic.claude-instant-v1:2:100k | chat | Claude Instant | bedrock | 200000 | 4096 | claude_instant | 0.80 | 2.40 |
| anthropic.claude-v2 | chat | Claude | bedrock | 200000 | 4096 | claude2 | 8.00 | 24.00 |
| anthropic.claude-v2:0:100k | chat | Claude | bedrock | 200000 | 4096 | claude2 | 8.00 | 24.00 |
| anthropic.claude-v2:0:18k | chat | Claude | bedrock | 200000 | 4096 | claude2 | 8.00 | 24.00 |
| anthropic.claude-v2:1 | chat | Claude | bedrock | 200000 | 4096 | claude2 | 8.00 | 24.00 |
| anthropic.claude-v2:1:18k | chat | Claude | bedrock | 200000 | 4096 | claude2 | 8.00 | 24.00 |
| anthropic.claude-v2:1:200k | chat | Claude | bedrock | 200000 | 4096 | claude2 | 8.00 | 24.00 |
| aqa | chat | Model that performs Attributed Question Answering. | gemini | 7168 | 1024 | aqa | 0.00 | 0.00 |
| babbage-002 | chat | Babbage 002 | openai | 4096 | 16384 | babbage | 0.40 | 0.40 |
| chat-bison-001 | chat | PaLM 2 Chat (Legacy) | gemini | 4096 | 1024 | other | 0.08 | 0.30 |
| chatgpt-4o-latest | chat | ChatGPT-4o Latest | openai | 128000 | 16384 | chatgpt4o | 5.00 | 15.00 |
| claude-2.0 | chat | Claude 2.0 | anthropic | 200000 | 4096 | claude2 | 3.00 | 15.00 |
| claude-2.1 | chat | Claude 2.1 | anthropic | 200000 | 4096 | claude2 | 3.00 | 15.00 |
| claude-3-5-haiku-20241022 | chat | Claude 3.5 Haiku | anthropic | 200000 | 8192 | claude35_haiku | 0.80 | 4.00 |
| claude-3-5-sonnet-20240620 | chat | Claude 3.5 Sonnet (Old) | anthropic | 200000 | 8192 | claude35_sonnet | 3.00 | 15.00 |
| claude-3-5-sonnet-20241022 | chat | Claude 3.5 Sonnet (New) | anthropic | 200000 | 8192 | claude35_sonnet | 3.00 | 15.00 |
| claude-3-7-sonnet-20250219 | chat | Claude 3.7 Sonnet | anthropic | 200000 | 8192 | claude37_sonnet | 3.00 | 15.00 |
| claude-3-haiku-20240307 | chat | Claude 3 Haiku | anthropic | 200000 | 4096 | claude3_haiku | 0.25 | 1.25 |
| claude-3-opus-20240229 | chat | Claude 3 Opus | anthropic | 200000 | 4096 | claude3_opus | 15.00 | 75.00 |
| claude-3-sonnet-20240229 | chat | Claude 3 Sonnet | anthropic | 200000 | 4096 | claude3_sonnet | 3.00 | 15.00 |
| davinci-002 | chat | Davinci 002 | openai | 4096 | 16384 | davinci | 2.00 | 2.00 |
| deepseek-chat | chat | DeepSeek V3 | deepseek | 64000 | 8192 | chat | 0.27 | 1.10 |
| deepseek-reasoner | chat | DeepSeek R1 | deepseek | 64000 | 8192 | reasoner | 0.55 | 2.19 |
| gemini-1.0-pro-vision-latest | chat | Gemini 1.0 Pro Vision | gemini | 12288 | 4096 | other | 0.08 | 0.30 |
| gemini-1.5-flash | chat | Gemini 1.5 Flash | gemini | 1000000 | 8192 | gemini15_flash | 0.15 | 0.60 |
| gemini-1.5-flash-001 | chat | Gemini 1.5 Flash 001 | gemini | 1000000 | 8192 | gemini15_flash | 0.15 | 0.60 |
| gemini-1.5-flash-001-tuning | chat | Gemini 1.5 Flash 001 Tuning | gemini | 16384 | 8192 | gemini15_flash | 0.15 | 0.60 |
| gemini-1.5-flash-002 | chat | Gemini 1.5 Flash 002 | gemini | 1000000 | 8192 | gemini15_flash | 0.15 | 0.60 |
| gemini-1.5-flash-8b | chat | Gemini 1.5 Flash-8B | gemini | 1000000 | 8192 | gemini15_flash_8b | 0.08 | 0.30 |
| gemini-1.5-flash-8b-001 | chat | Gemini 1.5 Flash-8B 001 | gemini | 1000000 | 8192 | gemini15_flash_8b | 0.08 | 0.30 |
| gemini-1.5-flash-8b-exp-0827 | chat | Gemini 1.5 Flash 8B Experimental 0827 | gemini | 1000000 | 8192 | gemini15_flash_8b | 0.08 | 0.30 |
| gemini-1.5-flash-8b-exp-0924 | chat | Gemini 1.5 Flash 8B Experimental 0924 | gemini | 1000000 | 8192 | gemini15_flash_8b | 0.08 | 0.30 |
| gemini-1.5-flash-8b-latest | chat | Gemini 1.5 Flash-8B Latest | gemini | 1000000 | 8192 | gemini15_flash_8b | 0.08 | 0.30 |
| gemini-1.5-flash-latest | chat | Gemini 1.5 Flash Latest | gemini | 1000000 | 8192 | gemini15_flash | 0.15 | 0.60 |
| gemini-1.5-pro | chat | Gemini 1.5 Pro | gemini | 2000000 | 8192 | gemini15_pro | 2.50 | 10.00 |
| gemini-1.5-pro-001 | chat | Gemini 1.5 Pro 001 | gemini | 2000000 | 8192 | gemini15_pro | 2.50 | 10.00 |
| gemini-1.5-pro-002 | chat | Gemini 1.5 Pro 002 | gemini | 2000000 | 8192 | gemini15_pro | 2.50 | 10.00 |
| gemini-1.5-pro-latest | chat | Gemini 1.5 Pro Latest | gemini | 2000000 | 8192 | gemini15_pro | 2.50 | 10.00 |
| gemini-2.0-flash | chat | Gemini 2.0 Flash | gemini | 1048576 | 8192 | gemini20_flash | 0.10 | 0.40 |
| gemini-2.0-flash-001 | chat | Gemini 2.0 Flash 001 | gemini | 1048576 | 8192 | gemini20_flash | 0.10 | 0.40 |
| gemini-2.0-flash-exp | chat | Gemini 2.0 Flash Experimental | gemini | 1048576 | 8192 | gemini20_flash | 0.10 | 0.40 |
| gemini-2.0-flash-exp-image-generation | chat | Gemini 2.0 Flash (Image Generation) Experimental | gemini | 1048576 | 8192 | gemini20_flash | 0.10 | 0.40 |
| gemini-2.0-flash-lite | chat | Gemini 2.0 Flash-Lite | gemini | 1048576 | 8192 | gemini20_flash_lite | 0.08 | 0.30 |
| gemini-2.0-flash-lite-001 | chat | Gemini 2.0 Flash-Lite 001 | gemini | 1048576 | 8192 | gemini20_flash_lite | 0.08 | 0.30 |
| gemini-2.0-flash-lite-preview | chat | Gemini 2.0 Flash-Lite Preview | gemini | 1048576 | 8192 | gemini20_flash_lite | 0.08 | 0.30 |
| gemini-2.0-flash-lite-preview-02-05 | chat | Gemini 2.0 Flash-Lite Preview 02-05 | gemini | 1048576 | 8192 | gemini20_flash_lite | 0.08 | 0.30 |
| gemini-2.0-flash-live-001 | chat | Gemini 2.0 Flash 001 | gemini | 131072 | 8192 | gemini20_flash | 0.10 | 0.40 |
| gemini-2.0-flash-thinking-exp | chat | Gemini 2.0 Flash Thinking Experimental 01-21 | gemini | 1048576 | 65536 | gemini20_flash | 0.10 | 0.40 |
| gemini-2.0-flash-thinking-exp-01-21 | chat | Gemini 2.0 Flash Thinking Experimental 01-21 | gemini | 1048576 | 65536 | gemini20_flash | 0.10 | 0.40 |
| gemini-2.0-flash-thinking-exp-1219 | chat | Gemini 2.0 Flash Thinking Experimental | gemini | 1048576 | 65536 | gemini20_flash | 0.10 | 0.40 |
| gemini-2.0-pro-exp | chat | Gemini 2.0 Pro Experimental | gemini | 1048576 | 65536 | other | 0.08 | 0.30 |
| gemini-2.0-pro-exp-02-05 | chat | Gemini 2.0 Pro Experimental 02-05 | gemini | 1048576 | 65536 | other | 0.08 | 0.30 |
| gemini-2.5-pro-exp-03-25 | chat | Gemini 2.5 Pro Experimental 03-25 | gemini | 1048576 | 65536 | gemini25_pro_exp | 0.12 | 0.50 |
| gemini-2.5-pro-preview-03-25 | chat | Gemini 2.5 Pro Preview 03-25 | gemini | 1048576 | 65536 | other | 0.08 | 0.30 |
| gemini-exp-1206 | chat | Gemini Experimental 1206 | gemini | 1048576 | 65536 | other | 0.08 | 0.30 |
| gemini-pro-vision | chat | Gemini 1.0 Pro Vision | gemini | 12288 | 4096 | other | 0.08 | 0.30 |
| gemma-3-12b-it | chat | Gemma 3 12B | gemini | 32768 | 8192 | other | 0.08 | 0.30 |
| gemma-3-1b-it | chat | Gemma 3 1B | gemini | 32768 | 8192 | other | 0.08 | 0.30 |
| gemma-3-27b-it | chat | Gemma 3 27B | gemini | 131072 | 8192 | other | 0.08 | 0.30 |
| gemma-3-4b-it | chat | Gemma 3 4B | gemini | 32768 | 8192 | other | 0.08 | 0.30 |
| gpt-3.5-turbo | chat | GPT-3.5 Turbo | openai | 16385 | 4096 | gpt35_turbo | 0.50 | 1.50 |
| gpt-3.5-turbo-0125 | chat | GPT-3.5 Turbo 0125 | openai | 16385 | 4096 | gpt35_turbo | 0.50 | 1.50 |
| gpt-3.5-turbo-1106 | chat | GPT-3.5 Turbo 1106 | openai | 16385 | 4096 | gpt35_turbo | 0.50 | 1.50 |
| gpt-3.5-turbo-16k | chat | GPT-3.5 Turbo 16k | openai | 16385 | 4096 | gpt35_turbo | 0.50 | 1.50 |
| gpt-3.5-turbo-instruct | chat | GPT-3.5 Turbo Instruct | openai | 16385 | 4096 | gpt35_turbo | 0.50 | 1.50 |
| gpt-3.5-turbo-instruct-0914 | chat | GPT-3.5 Turbo Instruct 0914 | openai | 16385 | 4096 | gpt35_turbo | 0.50 | 1.50 |
| gpt-4 | chat | GPT-4 | openai | 8192 | 8192 | gpt4 | 10.00 | 30.00 |
| gpt-4-0125-preview | chat | GPT-4 0125 Preview | openai | 4096 | 16384 | other | 0.50 | 1.50 |
| gpt-4-0613 | chat | GPT-4 0613 | openai | 4096 | 16384 | other | 0.50 | 1.50 |
| gpt-4-1106-preview | chat | GPT-4 1106 Preview | openai | 4096 | 16384 | other | 0.50 | 1.50 |
| gpt-4-turbo | chat | GPT-4 Turbo | openai | 128000 | 4096 | gpt4_turbo | 10.00 | 30.00 |
| gpt-4-turbo-2024-04-09 | chat | GPT-4 Turbo 20240409 | openai | 128000 | 4096 | gpt4_turbo | 10.00 | 30.00 |
| gpt-4-turbo-preview | chat | GPT-4 Turbo Preview | openai | 128000 | 4096 | gpt4_turbo | 10.00 | 30.00 |
| gpt-4.1 | chat | GPT-4.1 | openai | 1047576 | 32768 | gpt41 | 2.00 | 8.00 |
| gpt-4.1-2025-04-14 | chat | GPT-4.1 20250414 | openai | 1047576 | 32768 | gpt41 | 2.00 | 8.00 |
| gpt-4.1-mini | chat | GPT-4.1 Mini | openai | 1047576 | 32768 | gpt41_mini | 0.40 | 1.60 |
| gpt-4.1-mini-2025-04-14 | chat | GPT-4.1 Mini 20250414 | openai | 1047576 | 32768 | gpt41_mini | 0.40 | 1.60 |
| gpt-4.1-nano | chat | GPT-4.1 Nano | openai | 1047576 | 32768 | gpt41_nano | 0.10 | 0.40 |
| gpt-4.1-nano-2025-04-14 | chat | GPT-4.1 Nano 20250414 | openai | 1047576 | 32768 | gpt41_nano | 0.10 | 0.40 |
| gpt-4.5-preview | chat | GPT-4.5 Preview | openai | 128000 | 4096 | gpt4_turbo | 10.00 | 30.00 |
| gpt-4.5-preview-2025-02-27 | chat | GPT-4.5 Preview 20250227 | openai | 128000 | 4096 | gpt4_turbo | 10.00 | 30.00 |
| gpt-4o | chat | GPT-4o | openai | 128000 | 16384 | gpt4o | 2.50 | 10.00 |
| gpt-4o-2024-05-13 | chat | GPT-4o 20240513 | openai | 128000 | 16384 | gpt4o | 2.50 | 10.00 |
| gpt-4o-2024-08-06 | chat | GPT-4o 20240806 | openai | 128000 | 16384 | gpt4o | 2.50 | 10.00 |
| gpt-4o-2024-11-20 | chat | GPT-4o 20241120 | openai | 128000 | 16384 | gpt4o | 2.50 | 10.00 |
| gpt-4o-audio-preview | chat | GPT-4o-Audio Preview | openai | 128000 | 16384 | gpt4o_audio | 2.50 | 10.00 |
| gpt-4o-audio-preview-2024-10-01 | chat | GPT-4o-Audio Preview 20241001 | openai | 128000 | 16384 | gpt4o_audio | 2.50 | 10.00 |
| gpt-4o-audio-preview-2024-12-17 | chat | GPT-4o-Audio Preview 20241217 | openai | 128000 | 16384 | gpt4o_audio | 2.50 | 10.00 |
| gpt-4o-mini | chat | GPT-4o-Mini | openai | 128000 | 16384 | gpt4o_mini | 0.15 | 0.60 |
| gpt-4o-mini-2024-07-18 | chat | GPT-4o-Mini 20240718 | openai | 128000 | 16384 | gpt4o_mini | 0.15 | 0.60 |
| gpt-4o-mini-audio-preview | chat | GPT-4o-Mini Audio Preview | openai | 128000 | 16384 | gpt4o_mini_audio | 0.15 | 0.60 |
| gpt-4o-mini-audio-preview-2024-12-17 | chat | GPT-4o-Mini Audio Preview 20241217 | openai | 128000 | 16384 | gpt4o_mini_audio | 0.15 | 0.60 |
| gpt-4o-mini-realtime-preview | chat | GPT-4o-Mini Realtime Preview | openai | 128000 | 4096 | gpt4o_mini_realtime | 0.60 | 2.40 |
| gpt-4o-mini-realtime-preview-2024-12-17 | chat | GPT-4o-Mini Realtime Preview 20241217 | openai | 128000 | 4096 | gpt4o_mini_realtime | 0.60 | 2.40 |
| gpt-4o-mini-search-preview | chat | GPT-4o-Mini Search Preview | openai | 4096 | 16384 | other | 0.50 | 1.50 |
| gpt-4o-mini-search-preview-2025-03-11 | chat | GPT-4o-Mini Search Preview 20250311 | openai | 4096 | 16384 | other | 0.50 | 1.50 |
| gpt-4o-realtime-preview | chat | GPT-4o-Realtime Preview | openai | 128000 | 4096 | gpt4o_realtime | 5.00 | 20.00 |
| gpt-4o-realtime-preview-2024-10-01 | chat | GPT-4o-Realtime Preview 20241001 | openai | 128000 | 4096 | gpt4o_realtime | 5.00 | 20.00 |
| gpt-4o-realtime-preview-2024-12-17 | chat | GPT-4o-Realtime Preview 20241217 | openai | 128000 | 4096 | gpt4o_realtime | 5.00 | 20.00 |
| gpt-4o-search-preview | chat | GPT-4o Search Preview | openai | 128000 | 16384 | gpt4o_search | 2.50 | 10.00 |
| gpt-4o-search-preview-2025-03-11 | chat | GPT-4o Search Preview 20250311 | openai | 128000 | 16384 | gpt4o_search | 2.50 | 10.00 |
| learnlm-1.5-pro-experimental | chat | LearnLM 1.5 Pro Experimental | gemini | 32767 | 8192 | other | 0.08 | 0.30 |
| o1 | chat | O1 | openai | 200000 | 100000 | o1 | 15.00 | 60.00 |
| o1-2024-12-17 | chat | O1-20241217 | openai | 200000 | 100000 | o1 | 15.00 | 60.00 |
| o1-mini | chat | O1-Mini | openai | 128000 | 65536 | o1_mini | 1.10 | 4.40 |
| o1-mini-2024-09-12 | chat | O1-Mini 20240912 | openai | 128000 | 65536 | o1_mini | 1.10 | 4.40 |
| o1-preview | chat | O1-Preview | openai | 200000 | 100000 | o1 | 15.00 | 60.00 |
| o1-preview-2024-09-12 | chat | O1-Preview 20240912 | openai | 200000 | 100000 | o1 | 15.00 | 60.00 |
| o1-pro | chat | O1-Pro | openai | 200000 | 100000 | o1_pro | 150.00 | 600.00 |
| o1-pro-2025-03-19 | chat | O1-Pro 20250319 | openai | 200000 | 100000 | o1_pro | 150.00 | 600.00 |
| o3-mini | chat | O3-Mini | openai | 200000 | 100000 | o3_mini | 1.10 | 4.40 |
| o3-mini-2025-01-31 | chat | O3-Mini 20250131 | openai | 200000 | 100000 | o3_mini | 1.10 | 4.40 |
| text-bison-001 | chat | PaLM 2 (Legacy) | gemini | 8196 | 1024 | other | 0.08 | 0.30 |
| veo-2.0-generate-001 | chat | Veo 2 | gemini | 480 | 8192 | other | 0.08 | 0.30 |

### Image Models (3)

| ID | Type | Name | Provider | Context | MaxTok | Family | In$/M | Out$/M |
| :-- | :-- | :-- | :-- | --: | --: | :-- | --: | --: |
| dall-e-2 | image | DALL-E-2 | openai | 4096 | 16384 | dall_e | 0.50 | 1.50 |
| dall-e-3 | image | DALL-E-3 | openai | 4096 | 16384 | dall_e | 0.50 | 1.50 |
| imagen-3.0-generate-002 | image | Imagen 3.0 002 model | gemini | 480 | 8192 | imagen3 | 0.08 | 0.30 |

### Audio Models (8)

| ID | Type | Name | Provider | Context | MaxTok | Family | In$/M | Out$/M |
| :-- | :-- | :-- | :-- | --: | --: | :-- | --: | --: |
| gpt-4o-mini-transcribe | audio | GPT-4o-Mini Transcribe | openai | 16000 | 2000 | gpt4o_mini_transcribe | 1.25 | 5.00 |
| gpt-4o-mini-tts | audio | GPT-4o-Mini Tts | openai |  |  | gpt4o_mini_tts | 0.60 | 12.00 |
| gpt-4o-transcribe | audio | GPT-4o-Transcribe | openai | 128000 | 16384 | gpt4o_transcribe | 2.50 | 10.00 |
| tts-1 | audio | TTS-1 | openai |  |  | tts1 | 15.00 | 15.00 |
| tts-1-1106 | audio | TTS-1 1106 | openai |  |  | tts1 | 15.00 | 15.00 |
| tts-1-hd | audio | TTS-1 HD | openai |  |  | tts1_hd | 30.00 | 30.00 |
| tts-1-hd-1106 | audio | TTS-1 HD 1106 | openai |  |  | tts1_hd | 30.00 | 30.00 |
| whisper-1 | audio | Whisper 1 | openai |  |  | whisper | 0.01 | 0.01 |

### Embedding Models (8)

| ID | Type | Name | Provider | Context | MaxTok | Family | In$/M | Out$/M |
| :-- | :-- | :-- | :-- | --: | --: | :-- | --: | --: |
| embedding-001 | embedding | Embedding 001 | gemini | 2048 | 1 | embedding1 | 0.00 | 0.00 |
| embedding-gecko-001 | embedding | Embedding Gecko | gemini | 1024 | 1 | other | 0.00 | 0.00 |
| gemini-embedding-exp | embedding | Gemini Embedding Experimental | gemini | 8192 | 1 | gemini_embedding_exp | 0.00 | 0.00 |
| gemini-embedding-exp-03-07 | embedding | Gemini Embedding Experimental 03-07 | gemini | 8192 | 1 | gemini_embedding_exp | 0.00 | 0.00 |
| text-embedding-004 | embedding | Text Embedding 004 | gemini | 2048 | 1 | embedding4 | 0.00 | 0.00 |
| text-embedding-3-large | embedding | text-embedding- 3 Large | openai |  |  | embedding3_large | 0.13 | 0.13 |
| text-embedding-3-small | embedding | text-embedding- 3 Small | openai |  |  | embedding3_small | 0.02 | 0.02 |
| text-embedding-ada-002 | embedding | text-embedding- Ada 002 | openai |  |  | embedding_ada | 0.10 | 0.10 |

### Moderation Models (2)

| ID | Type | Name | Provider | Context | MaxTok | Family | In$/M | Out$/M |
| :-- | :-- | :-- | :-- | --: | --: | :-- | --: | --: |
| omni-moderation-2024-09-26 | moderation | Omni Moderation 20240926 | openai |  |  | moderation | 0.00 | 0.00 |
| omni-moderation-latest | moderation | Omni Moderation Latest | openai |  |  | moderation | 0.00 | 0.00 |

## Models by Provider

### Openai Models (69)

  | ID | Type | Name | Provider | Context | MaxTok | Family | In$/M | Out$/M |
| :-- | :-- | :-- | :-- | --: | --: | :-- | --: | --: |
| babbage-002 | chat | Babbage 002 | openai | 4096 | 16384 | babbage | 0.40 | 0.40 |
| chatgpt-4o-latest | chat | ChatGPT-4o Latest | openai | 128000 | 16384 | chatgpt4o | 5.00 | 15.00 |
| dall-e-2 | image | DALL-E-2 | openai | 4096 | 16384 | dall_e | 0.50 | 1.50 |
| dall-e-3 | image | DALL-E-3 | openai | 4096 | 16384 | dall_e | 0.50 | 1.50 |
| davinci-002 | chat | Davinci 002 | openai | 4096 | 16384 | davinci | 2.00 | 2.00 |
| gpt-3.5-turbo | chat | GPT-3.5 Turbo | openai | 16385 | 4096 | gpt35_turbo | 0.50 | 1.50 |
| gpt-3.5-turbo-0125 | chat | GPT-3.5 Turbo 0125 | openai | 16385 | 4096 | gpt35_turbo | 0.50 | 1.50 |
| gpt-3.5-turbo-1106 | chat | GPT-3.5 Turbo 1106 | openai | 16385 | 4096 | gpt35_turbo | 0.50 | 1.50 |
| gpt-3.5-turbo-16k | chat | GPT-3.5 Turbo 16k | openai | 16385 | 4096 | gpt35_turbo | 0.50 | 1.50 |
| gpt-3.5-turbo-instruct | chat | GPT-3.5 Turbo Instruct | openai | 16385 | 4096 | gpt35_turbo | 0.50 | 1.50 |
| gpt-3.5-turbo-instruct-0914 | chat | GPT-3.5 Turbo Instruct 0914 | openai | 16385 | 4096 | gpt35_turbo | 0.50 | 1.50 |
| gpt-4 | chat | GPT-4 | openai | 8192 | 8192 | gpt4 | 10.00 | 30.00 |
| gpt-4-0125-preview | chat | GPT-4 0125 Preview | openai | 4096 | 16384 | other | 0.50 | 1.50 |
| gpt-4-0613 | chat | GPT-4 0613 | openai | 4096 | 16384 | other | 0.50 | 1.50 |
| gpt-4-1106-preview | chat | GPT-4 1106 Preview | openai | 4096 | 16384 | other | 0.50 | 1.50 |
| gpt-4-turbo | chat | GPT-4 Turbo | openai | 128000 | 4096 | gpt4_turbo | 10.00 | 30.00 |
| gpt-4-turbo-2024-04-09 | chat | GPT-4 Turbo 20240409 | openai | 128000 | 4096 | gpt4_turbo | 10.00 | 30.00 |
| gpt-4-turbo-preview | chat | GPT-4 Turbo Preview | openai | 128000 | 4096 | gpt4_turbo | 10.00 | 30.00 |
| gpt-4.1 | chat | GPT-4.1 | openai | 1047576 | 32768 | gpt41 | 2.00 | 8.00 |
| gpt-4.1-2025-04-14 | chat | GPT-4.1 20250414 | openai | 1047576 | 32768 | gpt41 | 2.00 | 8.00 |
| gpt-4.1-mini | chat | GPT-4.1 Mini | openai | 1047576 | 32768 | gpt41_mini | 0.40 | 1.60 |
| gpt-4.1-mini-2025-04-14 | chat | GPT-4.1 Mini 20250414 | openai | 1047576 | 32768 | gpt41_mini | 0.40 | 1.60 |
| gpt-4.1-nano | chat | GPT-4.1 Nano | openai | 1047576 | 32768 | gpt41_nano | 0.10 | 0.40 |
| gpt-4.1-nano-2025-04-14 | chat | GPT-4.1 Nano 20250414 | openai | 1047576 | 32768 | gpt41_nano | 0.10 | 0.40 |
| gpt-4.5-preview | chat | GPT-4.5 Preview | openai | 128000 | 4096 | gpt4_turbo | 10.00 | 30.00 |
| gpt-4.5-preview-2025-02-27 | chat | GPT-4.5 Preview 20250227 | openai | 128000 | 4096 | gpt4_turbo | 10.00 | 30.00 |
| gpt-4o | chat | GPT-4o | openai | 128000 | 16384 | gpt4o | 2.50 | 10.00 |
| gpt-4o-2024-05-13 | chat | GPT-4o 20240513 | openai | 128000 | 16384 | gpt4o | 2.50 | 10.00 |
| gpt-4o-2024-08-06 | chat | GPT-4o 20240806 | openai | 128000 | 16384 | gpt4o | 2.50 | 10.00 |
| gpt-4o-2024-11-20 | chat | GPT-4o 20241120 | openai | 128000 | 16384 | gpt4o | 2.50 | 10.00 |
| gpt-4o-audio-preview | chat | GPT-4o-Audio Preview | openai | 128000 | 16384 | gpt4o_audio | 2.50 | 10.00 |
| gpt-4o-audio-preview-2024-10-01 | chat | GPT-4o-Audio Preview 20241001 | openai | 128000 | 16384 | gpt4o_audio | 2.50 | 10.00 |
| gpt-4o-audio-preview-2024-12-17 | chat | GPT-4o-Audio Preview 20241217 | openai | 128000 | 16384 | gpt4o_audio | 2.50 | 10.00 |
| gpt-4o-mini | chat | GPT-4o-Mini | openai | 128000 | 16384 | gpt4o_mini | 0.15 | 0.60 |
| gpt-4o-mini-2024-07-18 | chat | GPT-4o-Mini 20240718 | openai | 128000 | 16384 | gpt4o_mini | 0.15 | 0.60 |
| gpt-4o-mini-audio-preview | chat | GPT-4o-Mini Audio Preview | openai | 128000 | 16384 | gpt4o_mini_audio | 0.15 | 0.60 |
| gpt-4o-mini-audio-preview-2024-12-17 | chat | GPT-4o-Mini Audio Preview 20241217 | openai | 128000 | 16384 | gpt4o_mini_audio | 0.15 | 0.60 |
| gpt-4o-mini-realtime-preview | chat | GPT-4o-Mini Realtime Preview | openai | 128000 | 4096 | gpt4o_mini_realtime | 0.60 | 2.40 |
| gpt-4o-mini-realtime-preview-2024-12-17 | chat | GPT-4o-Mini Realtime Preview 20241217 | openai | 128000 | 4096 | gpt4o_mini_realtime | 0.60 | 2.40 |
| gpt-4o-mini-search-preview | chat | GPT-4o-Mini Search Preview | openai | 4096 | 16384 | other | 0.50 | 1.50 |
| gpt-4o-mini-search-preview-2025-03-11 | chat | GPT-4o-Mini Search Preview 20250311 | openai | 4096 | 16384 | other | 0.50 | 1.50 |
| gpt-4o-mini-transcribe | audio | GPT-4o-Mini Transcribe | openai | 16000 | 2000 | gpt4o_mini_transcribe | 1.25 | 5.00 |
| gpt-4o-mini-tts | audio | GPT-4o-Mini Tts | openai |  |  | gpt4o_mini_tts | 0.60 | 12.00 |
| gpt-4o-realtime-preview | chat | GPT-4o-Realtime Preview | openai | 128000 | 4096 | gpt4o_realtime | 5.00 | 20.00 |
| gpt-4o-realtime-preview-2024-10-01 | chat | GPT-4o-Realtime Preview 20241001 | openai | 128000 | 4096 | gpt4o_realtime | 5.00 | 20.00 |
| gpt-4o-realtime-preview-2024-12-17 | chat | GPT-4o-Realtime Preview 20241217 | openai | 128000 | 4096 | gpt4o_realtime | 5.00 | 20.00 |
| gpt-4o-search-preview | chat | GPT-4o Search Preview | openai | 128000 | 16384 | gpt4o_search | 2.50 | 10.00 |
| gpt-4o-search-preview-2025-03-11 | chat | GPT-4o Search Preview 20250311 | openai | 128000 | 16384 | gpt4o_search | 2.50 | 10.00 |
| gpt-4o-transcribe | audio | GPT-4o-Transcribe | openai | 128000 | 16384 | gpt4o_transcribe | 2.50 | 10.00 |
| o1 | chat | O1 | openai | 200000 | 100000 | o1 | 15.00 | 60.00 |
| o1-2024-12-17 | chat | O1-20241217 | openai | 200000 | 100000 | o1 | 15.00 | 60.00 |
| o1-mini | chat | O1-Mini | openai | 128000 | 65536 | o1_mini | 1.10 | 4.40 |
| o1-mini-2024-09-12 | chat | O1-Mini 20240912 | openai | 128000 | 65536 | o1_mini | 1.10 | 4.40 |
| o1-preview | chat | O1-Preview | openai | 200000 | 100000 | o1 | 15.00 | 60.00 |
| o1-preview-2024-09-12 | chat | O1-Preview 20240912 | openai | 200000 | 100000 | o1 | 15.00 | 60.00 |
| o1-pro | chat | O1-Pro | openai | 200000 | 100000 | o1_pro | 150.00 | 600.00 |
| o1-pro-2025-03-19 | chat | O1-Pro 20250319 | openai | 200000 | 100000 | o1_pro | 150.00 | 600.00 |
| o3-mini | chat | O3-Mini | openai | 200000 | 100000 | o3_mini | 1.10 | 4.40 |
| o3-mini-2025-01-31 | chat | O3-Mini 20250131 | openai | 200000 | 100000 | o3_mini | 1.10 | 4.40 |
| omni-moderation-2024-09-26 | moderation | Omni Moderation 20240926 | openai |  |  | moderation | 0.00 | 0.00 |
| omni-moderation-latest | moderation | Omni Moderation Latest | openai |  |  | moderation | 0.00 | 0.00 |
| text-embedding-3-large | embedding | text-embedding- 3 Large | openai |  |  | embedding3_large | 0.13 | 0.13 |
| text-embedding-3-small | embedding | text-embedding- 3 Small | openai |  |  | embedding3_small | 0.02 | 0.02 |
| text-embedding-ada-002 | embedding | text-embedding- Ada 002 | openai |  |  | embedding_ada | 0.10 | 0.10 |
| tts-1 | audio | TTS-1 | openai |  |  | tts1 | 15.00 | 15.00 |
| tts-1-1106 | audio | TTS-1 1106 | openai |  |  | tts1 | 15.00 | 15.00 |
| tts-1-hd | audio | TTS-1 HD | openai |  |  | tts1_hd | 30.00 | 30.00 |
| tts-1-hd-1106 | audio | TTS-1 HD 1106 | openai |  |  | tts1_hd | 30.00 | 30.00 |
| whisper-1 | audio | Whisper 1 | openai |  |  | whisper | 0.01 | 0.01 |

### Anthropic Models (9)

  | ID | Type | Name | Provider | Context | MaxTok | Family | In$/M | Out$/M |
| :-- | :-- | :-- | :-- | --: | --: | :-- | --: | --: |
| claude-2.0 | chat | Claude 2.0 | anthropic | 200000 | 4096 | claude2 | 3.00 | 15.00 |
| claude-2.1 | chat | Claude 2.1 | anthropic | 200000 | 4096 | claude2 | 3.00 | 15.00 |
| claude-3-5-haiku-20241022 | chat | Claude 3.5 Haiku | anthropic | 200000 | 8192 | claude35_haiku | 0.80 | 4.00 |
| claude-3-5-sonnet-20240620 | chat | Claude 3.5 Sonnet (Old) | anthropic | 200000 | 8192 | claude35_sonnet | 3.00 | 15.00 |
| claude-3-5-sonnet-20241022 | chat | Claude 3.5 Sonnet (New) | anthropic | 200000 | 8192 | claude35_sonnet | 3.00 | 15.00 |
| claude-3-7-sonnet-20250219 | chat | Claude 3.7 Sonnet | anthropic | 200000 | 8192 | claude37_sonnet | 3.00 | 15.00 |
| claude-3-haiku-20240307 | chat | Claude 3 Haiku | anthropic | 200000 | 4096 | claude3_haiku | 0.25 | 1.25 |
| claude-3-opus-20240229 | chat | Claude 3 Opus | anthropic | 200000 | 4096 | claude3_opus | 15.00 | 75.00 |
| claude-3-sonnet-20240229 | chat | Claude 3 Sonnet | anthropic | 200000 | 4096 | claude3_sonnet | 3.00 | 15.00 |

### Gemini Models (48)

  | ID | Type | Name | Provider | Context | MaxTok | Family | In$/M | Out$/M |
| :-- | :-- | :-- | :-- | --: | --: | :-- | --: | --: |
| aqa | chat | Model that performs Attributed Question Answering. | gemini | 7168 | 1024 | aqa | 0.00 | 0.00 |
| chat-bison-001 | chat | PaLM 2 Chat (Legacy) | gemini | 4096 | 1024 | other | 0.08 | 0.30 |
| embedding-001 | embedding | Embedding 001 | gemini | 2048 | 1 | embedding1 | 0.00 | 0.00 |
| embedding-gecko-001 | embedding | Embedding Gecko | gemini | 1024 | 1 | other | 0.00 | 0.00 |
| gemini-1.0-pro-vision-latest | chat | Gemini 1.0 Pro Vision | gemini | 12288 | 4096 | other | 0.08 | 0.30 |
| gemini-1.5-flash | chat | Gemini 1.5 Flash | gemini | 1000000 | 8192 | gemini15_flash | 0.15 | 0.60 |
| gemini-1.5-flash-001 | chat | Gemini 1.5 Flash 001 | gemini | 1000000 | 8192 | gemini15_flash | 0.15 | 0.60 |
| gemini-1.5-flash-001-tuning | chat | Gemini 1.5 Flash 001 Tuning | gemini | 16384 | 8192 | gemini15_flash | 0.15 | 0.60 |
| gemini-1.5-flash-002 | chat | Gemini 1.5 Flash 002 | gemini | 1000000 | 8192 | gemini15_flash | 0.15 | 0.60 |
| gemini-1.5-flash-8b | chat | Gemini 1.5 Flash-8B | gemini | 1000000 | 8192 | gemini15_flash_8b | 0.08 | 0.30 |
| gemini-1.5-flash-8b-001 | chat | Gemini 1.5 Flash-8B 001 | gemini | 1000000 | 8192 | gemini15_flash_8b | 0.08 | 0.30 |
| gemini-1.5-flash-8b-exp-0827 | chat | Gemini 1.5 Flash 8B Experimental 0827 | gemini | 1000000 | 8192 | gemini15_flash_8b | 0.08 | 0.30 |
| gemini-1.5-flash-8b-exp-0924 | chat | Gemini 1.5 Flash 8B Experimental 0924 | gemini | 1000000 | 8192 | gemini15_flash_8b | 0.08 | 0.30 |
| gemini-1.5-flash-8b-latest | chat | Gemini 1.5 Flash-8B Latest | gemini | 1000000 | 8192 | gemini15_flash_8b | 0.08 | 0.30 |
| gemini-1.5-flash-latest | chat | Gemini 1.5 Flash Latest | gemini | 1000000 | 8192 | gemini15_flash | 0.15 | 0.60 |
| gemini-1.5-pro | chat | Gemini 1.5 Pro | gemini | 2000000 | 8192 | gemini15_pro | 2.50 | 10.00 |
| gemini-1.5-pro-001 | chat | Gemini 1.5 Pro 001 | gemini | 2000000 | 8192 | gemini15_pro | 2.50 | 10.00 |
| gemini-1.5-pro-002 | chat | Gemini 1.5 Pro 002 | gemini | 2000000 | 8192 | gemini15_pro | 2.50 | 10.00 |
| gemini-1.5-pro-latest | chat | Gemini 1.5 Pro Latest | gemini | 2000000 | 8192 | gemini15_pro | 2.50 | 10.00 |
| gemini-2.0-flash | chat | Gemini 2.0 Flash | gemini | 1048576 | 8192 | gemini20_flash | 0.10 | 0.40 |
| gemini-2.0-flash-001 | chat | Gemini 2.0 Flash 001 | gemini | 1048576 | 8192 | gemini20_flash | 0.10 | 0.40 |
| gemini-2.0-flash-exp | chat | Gemini 2.0 Flash Experimental | gemini | 1048576 | 8192 | gemini20_flash | 0.10 | 0.40 |
| gemini-2.0-flash-exp-image-generation | chat | Gemini 2.0 Flash (Image Generation) Experimental | gemini | 1048576 | 8192 | gemini20_flash | 0.10 | 0.40 |
| gemini-2.0-flash-lite | chat | Gemini 2.0 Flash-Lite | gemini | 1048576 | 8192 | gemini20_flash_lite | 0.08 | 0.30 |
| gemini-2.0-flash-lite-001 | chat | Gemini 2.0 Flash-Lite 001 | gemini | 1048576 | 8192 | gemini20_flash_lite | 0.08 | 0.30 |
| gemini-2.0-flash-lite-preview | chat | Gemini 2.0 Flash-Lite Preview | gemini | 1048576 | 8192 | gemini20_flash_lite | 0.08 | 0.30 |
| gemini-2.0-flash-lite-preview-02-05 | chat | Gemini 2.0 Flash-Lite Preview 02-05 | gemini | 1048576 | 8192 | gemini20_flash_lite | 0.08 | 0.30 |
| gemini-2.0-flash-live-001 | chat | Gemini 2.0 Flash 001 | gemini | 131072 | 8192 | gemini20_flash | 0.10 | 0.40 |
| gemini-2.0-flash-thinking-exp | chat | Gemini 2.0 Flash Thinking Experimental 01-21 | gemini | 1048576 | 65536 | gemini20_flash | 0.10 | 0.40 |
| gemini-2.0-flash-thinking-exp-01-21 | chat | Gemini 2.0 Flash Thinking Experimental 01-21 | gemini | 1048576 | 65536 | gemini20_flash | 0.10 | 0.40 |
| gemini-2.0-flash-thinking-exp-1219 | chat | Gemini 2.0 Flash Thinking Experimental | gemini | 1048576 | 65536 | gemini20_flash | 0.10 | 0.40 |
| gemini-2.0-pro-exp | chat | Gemini 2.0 Pro Experimental | gemini | 1048576 | 65536 | other | 0.08 | 0.30 |
| gemini-2.0-pro-exp-02-05 | chat | Gemini 2.0 Pro Experimental 02-05 | gemini | 1048576 | 65536 | other | 0.08 | 0.30 |
| gemini-2.5-pro-exp-03-25 | chat | Gemini 2.5 Pro Experimental 03-25 | gemini | 1048576 | 65536 | gemini25_pro_exp | 0.12 | 0.50 |
| gemini-2.5-pro-preview-03-25 | chat | Gemini 2.5 Pro Preview 03-25 | gemini | 1048576 | 65536 | other | 0.08 | 0.30 |
| gemini-embedding-exp | embedding | Gemini Embedding Experimental | gemini | 8192 | 1 | gemini_embedding_exp | 0.00 | 0.00 |
| gemini-embedding-exp-03-07 | embedding | Gemini Embedding Experimental 03-07 | gemini | 8192 | 1 | gemini_embedding_exp | 0.00 | 0.00 |
| gemini-exp-1206 | chat | Gemini Experimental 1206 | gemini | 1048576 | 65536 | other | 0.08 | 0.30 |
| gemini-pro-vision | chat | Gemini 1.0 Pro Vision | gemini | 12288 | 4096 | other | 0.08 | 0.30 |
| gemma-3-12b-it | chat | Gemma 3 12B | gemini | 32768 | 8192 | other | 0.08 | 0.30 |
| gemma-3-1b-it | chat | Gemma 3 1B | gemini | 32768 | 8192 | other | 0.08 | 0.30 |
| gemma-3-27b-it | chat | Gemma 3 27B | gemini | 131072 | 8192 | other | 0.08 | 0.30 |
| gemma-3-4b-it | chat | Gemma 3 4B | gemini | 32768 | 8192 | other | 0.08 | 0.30 |
| imagen-3.0-generate-002 | image | Imagen 3.0 002 model | gemini | 480 | 8192 | imagen3 | 0.08 | 0.30 |
| learnlm-1.5-pro-experimental | chat | LearnLM 1.5 Pro Experimental | gemini | 32767 | 8192 | other | 0.08 | 0.30 |
| text-bison-001 | chat | PaLM 2 (Legacy) | gemini | 8196 | 1024 | other | 0.08 | 0.30 |
| text-embedding-004 | embedding | Text Embedding 004 | gemini | 2048 | 1 | embedding4 | 0.00 | 0.00 |
| veo-2.0-generate-001 | chat | Veo 2 | gemini | 480 | 8192 | other | 0.08 | 0.30 |

### Deepseek Models (2)

  | ID | Type | Name | Provider | Context | MaxTok | Family | In$/M | Out$/M |
| :-- | :-- | :-- | :-- | --: | --: | :-- | --: | --: |
| deepseek-chat | chat | DeepSeek V3 | deepseek | 64000 | 8192 | chat | 0.27 | 1.10 |
| deepseek-reasoner | chat | DeepSeek R1 | deepseek | 64000 | 8192 | reasoner | 0.55 | 2.19 |

### Bedrock Models (28)

  | ID | Type | Name | Provider | Context | MaxTok | Family | In$/M | Out$/M |
| :-- | :-- | :-- | :-- | --: | --: | :-- | --: | --: |
| anthropic.claude-3-5-haiku-20241022-v1:0 | chat | Claude 3.5 Haiku | bedrock | 200000 | 4096 | claude3_5_haiku | 0.80 | 4.00 |
| anthropic.claude-3-5-sonnet-20240620-v1:0 | chat | Claude 3.5 Sonnet | bedrock | 200000 | 4096 | claude3_sonnet | 3.00 | 15.00 |
| anthropic.claude-3-5-sonnet-20240620-v1:0:18k | chat | Claude 3.5 Sonnet | bedrock | 200000 | 4096 | claude3_sonnet | 3.00 | 15.00 |
| anthropic.claude-3-5-sonnet-20240620-v1:0:200k | chat | Claude 3.5 Sonnet | bedrock | 200000 | 4096 | claude3_sonnet | 3.00 | 15.00 |
| anthropic.claude-3-5-sonnet-20240620-v1:0:51k | chat | Claude 3.5 Sonnet | bedrock | 200000 | 4096 | claude3_sonnet | 3.00 | 15.00 |
| anthropic.claude-3-5-sonnet-20241022-v2:0 | chat | Claude 3.5 Sonnet v2 | bedrock | 200000 | 4096 | claude3_sonnet | 3.00 | 15.00 |
| anthropic.claude-3-5-sonnet-20241022-v2:0:18k | chat | Claude 3.5 Sonnet v2 | bedrock | 200000 | 4096 | claude3_sonnet | 3.00 | 15.00 |
| anthropic.claude-3-5-sonnet-20241022-v2:0:200k | chat | Claude 3.5 Sonnet v2 | bedrock | 200000 | 4096 | claude3_sonnet | 3.00 | 15.00 |
| anthropic.claude-3-5-sonnet-20241022-v2:0:51k | chat | Claude 3.5 Sonnet v2 | bedrock | 200000 | 4096 | claude3_sonnet | 3.00 | 15.00 |
| anthropic.claude-3-7-sonnet-20250219-v1:0 | chat | Claude 3.7 Sonnet | bedrock | 200000 | 4096 | claude3_sonnet | 3.00 | 15.00 |
| anthropic.claude-3-haiku-20240307-v1:0 | chat | Claude 3 Haiku | bedrock | 200000 | 4096 | claude3_haiku | 0.25 | 1.25 |
| anthropic.claude-3-haiku-20240307-v1:0:200k | chat | Claude 3 Haiku | bedrock | 200000 | 4096 | claude3_haiku | 0.25 | 1.25 |
| anthropic.claude-3-haiku-20240307-v1:0:48k | chat | Claude 3 Haiku | bedrock | 200000 | 4096 | claude3_haiku | 0.25 | 1.25 |
| anthropic.claude-3-opus-20240229-v1:0 | chat | Claude 3 Opus | bedrock | 200000 | 4096 | claude3_opus | 15.00 | 75.00 |
| anthropic.claude-3-opus-20240229-v1:0:12k | chat | Claude 3 Opus | bedrock | 200000 | 4096 | claude3_opus | 15.00 | 75.00 |
| anthropic.claude-3-opus-20240229-v1:0:200k | chat | Claude 3 Opus | bedrock | 200000 | 4096 | claude3_opus | 15.00 | 75.00 |
| anthropic.claude-3-opus-20240229-v1:0:28k | chat | Claude 3 Opus | bedrock | 200000 | 4096 | claude3_opus | 15.00 | 75.00 |
| anthropic.claude-3-sonnet-20240229-v1:0 | chat | Claude 3 Sonnet | bedrock | 200000 | 4096 | claude3_sonnet | 3.00 | 15.00 |
| anthropic.claude-3-sonnet-20240229-v1:0:200k | chat | Claude 3 Sonnet | bedrock | 200000 | 4096 | claude3_sonnet | 3.00 | 15.00 |
| anthropic.claude-3-sonnet-20240229-v1:0:28k | chat | Claude 3 Sonnet | bedrock | 200000 | 4096 | claude3_sonnet | 3.00 | 15.00 |
| anthropic.claude-instant-v1 | chat | Claude Instant | bedrock | 200000 | 4096 | claude_instant | 0.80 | 2.40 |
| anthropic.claude-instant-v1:2:100k | chat | Claude Instant | bedrock | 200000 | 4096 | claude_instant | 0.80 | 2.40 |
| anthropic.claude-v2 | chat | Claude | bedrock | 200000 | 4096 | claude2 | 8.00 | 24.00 |
| anthropic.claude-v2:0:100k | chat | Claude | bedrock | 200000 | 4096 | claude2 | 8.00 | 24.00 |
| anthropic.claude-v2:0:18k | chat | Claude | bedrock | 200000 | 4096 | claude2 | 8.00 | 24.00 |
| anthropic.claude-v2:1 | chat | Claude | bedrock | 200000 | 4096 | claude2 | 8.00 | 24.00 |
| anthropic.claude-v2:1:18k | chat | Claude | bedrock | 200000 | 4096 | claude2 | 8.00 | 24.00 |
| anthropic.claude-v2:1:200k | chat | Claude | bedrock | 200000 | 4096 | claude2 | 8.00 | 24.00 |

