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

Last updated: 2025-04-25
{: .label .label-green }

### Chat Models (441)

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
| anthropic.claude-3-5-haiku-20241022-v1:0 | chat | Claude 3.5 Haiku | bedrock | 200000 | 4096 | claude3_5_haiku | 0.80 | 4.00 |
| anthropic.claude-3-5-sonnet-20240620-v1:0 | chat | Claude 3.5 Sonnet | bedrock | 200000 | 4096 | claude3_sonnet | 3.00 | 15.00 |
| anthropic.claude-3-5-sonnet-20240620-v1:0:18k | chat | Claude 3.5 Sonnet | bedrock | 200000 | 4096 | claude3_sonnet | 3.00 | 15.00 |
| anthropic.claude-3-5-sonnet-20240620-v1:0:200k | chat | Claude 3.5 Sonnet | bedrock | 200000 | 4096 | claude3_sonnet | 3.00 | 15.00 |
| anthropic.claude-3-5-sonnet-20240620-v1:0:51k | chat | Claude 3.5 Sonnet | bedrock | 200000 | 4096 | claude3_sonnet | 3.00 | 15.00 |
| anthropic.claude-3-5-sonnet-20241022-v2:0 | chat | Claude 3.5 Sonnet v2 | bedrock | 200000 | 4096 | claude3_sonnet | 3.00 | 15.00 |
| anthropic.claude-3-5-sonnet-20241022-v2:0:18k | chat | Claude 3.5 Sonnet v2 | bedrock | 200000 | 4096 | claude3_sonnet | 3.00 | 15.00 |
| anthropic.claude-3-5-sonnet-20241022-v2:0:200k | chat | Claude 3.5 Sonnet v2 | bedrock | 200000 | 4096 | claude3_sonnet | 3.00 | 15.00 |
| anthropic.claude-3-5-sonnet-20241022-v2:0:51k | chat | Claude 3.5 Sonnet v2 | bedrock | 200000 | 4096 | claude3_sonnet | 3.00 | 15.00 |
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
| us.anthropic.claude-3-7-sonnet-20250219-v1:0 | chat | Claude 3.7 Sonnet | bedrock | 200000 | 4096 | claude3_sonnet | 3.00 | 15.00 |
| deepseek-chat | chat | DeepSeek V3 | deepseek | 64000 | 8192 | chat | 0.27 | 1.10 |
| deepseek-reasoner | chat | DeepSeek R1 | deepseek | 64000 | 8192 | reasoner | 0.55 | 2.19 |
| aqa | chat | Model that performs Attributed Question Answering. | gemini | 7168 | 1024 | aqa | 0.00 | 0.00 |
| chat-bison-001 | chat | PaLM 2 Chat (Legacy) | gemini | 4096 | 1024 | other | 0.08 | 0.30 |
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
| gemini-2.0-flash-lite | chat | Gemini 2.0 Flash-Lite | gemini | 1048576 | 8192 | gemini20_flash_lite | 0.08 | 0.30 |
| gemini-2.0-flash-lite-001 | chat | Gemini 2.0 Flash-Lite 001 | gemini | 1048576 | 8192 | gemini20_flash_lite | 0.08 | 0.30 |
| gemini-2.0-flash-lite-preview | chat | Gemini 2.0 Flash-Lite Preview | gemini | 1048576 | 8192 | gemini20_flash_lite | 0.08 | 0.30 |
| gemini-2.0-flash-lite-preview-02-05 | chat | Gemini 2.0 Flash-Lite Preview 02-05 | gemini | 1048576 | 8192 | gemini20_flash_lite | 0.08 | 0.30 |
| gemini-2.0-flash-live-001 | chat | Gemini 2.0 Flash 001 | gemini | 131072 | 8192 | gemini20_flash | 0.10 | 0.40 |
| gemini-2.0-flash-thinking-exp | chat | Gemini 2.5 Flash Preview 04-17 | gemini | 1048576 | 65536 | gemini20_flash | 0.10 | 0.40 |
| gemini-2.0-flash-thinking-exp-01-21 | chat | Gemini 2.5 Flash Preview 04-17 | gemini | 1048576 | 65536 | gemini20_flash | 0.10 | 0.40 |
| gemini-2.0-flash-thinking-exp-1219 | chat | Gemini 2.5 Flash Preview 04-17 | gemini | 1048576 | 65536 | gemini20_flash | 0.10 | 0.40 |
| gemini-2.0-pro-exp | chat | Gemini 2.0 Pro Experimental | gemini | 1048576 | 65536 | other | 0.08 | 0.30 |
| gemini-2.0-pro-exp-02-05 | chat | Gemini 2.0 Pro Experimental 02-05 | gemini | 1048576 | 65536 | other | 0.08 | 0.30 |
| gemini-2.5-flash-preview-04-17 | chat | Gemini 2.5 Flash Preview 04-17 | gemini | 1048576 | 65536 | other | 0.08 | 0.30 |
| gemini-2.5-pro-exp-03-25 | chat | Gemini 2.5 Pro Experimental 03-25 | gemini | 1048576 | 65536 | gemini25_pro_exp | 0.12 | 0.50 |
| gemini-2.5-pro-preview-03-25 | chat | Gemini 2.5 Pro Preview 03-25 | gemini | 1048576 | 65536 | other | 0.08 | 0.30 |
| gemini-exp-1206 | chat | Gemini Experimental 1206 | gemini | 1048576 | 65536 | other | 0.08 | 0.30 |
| gemini-pro-vision | chat | Gemini 1.0 Pro Vision | gemini | 12288 | 4096 | other | 0.08 | 0.30 |
| gemma-3-12b-it | chat | Gemma 3 12B | gemini | 32768 | 8192 | other | 0.08 | 0.30 |
| gemma-3-1b-it | chat | Gemma 3 1B | gemini | 32768 | 8192 | other | 0.08 | 0.30 |
| gemma-3-27b-it | chat | Gemma 3 27B | gemini | 131072 | 8192 | other | 0.08 | 0.30 |
| gemma-3-4b-it | chat | Gemma 3 4B | gemini | 32768 | 8192 | other | 0.08 | 0.30 |
| learnlm-1.5-pro-experimental | chat | LearnLM 1.5 Pro Experimental | gemini | 32767 | 8192 | other | 0.08 | 0.30 |
| learnlm-2.0-flash-experimental | chat | LearnLM 2.0 Flash Experimental | gemini | 1048576 | 32768 | other | 0.08 | 0.30 |
| text-bison-001 | chat | PaLM 2 (Legacy) | gemini | 8196 | 1024 | other | 0.08 | 0.30 |
| veo-2.0-generate-001 | chat | Veo 2 | gemini | 480 | 8192 | other | 0.08 | 0.30 |
| babbage-002 | chat | Babbage 002 | openai | 4096 | 16384 | babbage | 0.40 | 0.40 |
| chatgpt-4o-latest | chat | ChatGPT-4o Latest | openai | 128000 | 16384 | chatgpt4o | 5.00 | 15.00 |
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
| gpt-4o-realtime-preview | chat | GPT-4o-Realtime Preview | openai | 128000 | 4096 | gpt4o_realtime | 5.00 | 20.00 |
| gpt-4o-realtime-preview-2024-10-01 | chat | GPT-4o-Realtime Preview 20241001 | openai | 128000 | 4096 | gpt4o_realtime | 5.00 | 20.00 |
| gpt-4o-realtime-preview-2024-12-17 | chat | GPT-4o-Realtime Preview 20241217 | openai | 128000 | 4096 | gpt4o_realtime | 5.00 | 20.00 |
| gpt-4o-search-preview | chat | GPT-4o Search Preview | openai | 128000 | 16384 | gpt4o_search | 2.50 | 10.00 |
| gpt-4o-search-preview-2025-03-11 | chat | GPT-4o Search Preview 20250311 | openai | 128000 | 16384 | gpt4o_search | 2.50 | 10.00 |
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
| o4-mini | chat | O4 Mini | openai | 4096 | 16384 | other | 0.50 | 1.50 |
| o4-mini-2025-04-16 | chat | O4 Mini 20250416 | openai | 4096 | 16384 | other | 0.50 | 1.50 |
| 01-ai/yi-large | chat | 01.AI: Yi Large | openrouter | 32768 | 4096 | other | 3.00 | 3.00 |
| aetherwiing/mn-starcannon-12b | chat | Aetherwiing: Starcannon 12B | openrouter | 16384 | 4096 | other | 0.80 | 1.20 |
| agentica-org/deepcoder-14b-preview:free | chat | Agentica: Deepcoder 14B Preview (free) | openrouter | 96000 |  | other | 0.00 | 0.00 |
| ai21/jamba-1-5-large | chat | AI21: Jamba 1.5 Large | openrouter | 256000 | 4096 | other | 2.00 | 8.00 |
| ai21/jamba-1-5-mini | chat | AI21: Jamba 1.5 Mini | openrouter | 256000 | 4096 | other | 0.20 | 0.40 |
| ai21/jamba-1.6-large | chat | AI21: Jamba 1.6 Large | openrouter | 256000 | 4096 | other | 2.00 | 8.00 |
| ai21/jamba-1.6-mini | chat | AI21: Jamba Mini 1.6 | openrouter | 256000 | 4096 | other | 0.20 | 0.40 |
| ai21/jamba-instruct | chat | AI21: Jamba Instruct | openrouter | 256000 | 4096 | other | 0.50 | 0.70 |
| aion-labs/aion-1.0 | chat | AionLabs: Aion-1.0 | openrouter | 131072 | 32768 | other | 4.00 | 8.00 |
| aion-labs/aion-1.0-mini | chat | AionLabs: Aion-1.0-Mini | openrouter | 131072 | 32768 | other | 0.70 | 1.40 |
| aion-labs/aion-rp-llama-3.1-8b | chat | AionLabs: Aion-RP 1.0 (8B) | openrouter | 32768 | 32768 | other | 0.20 | 0.20 |
| alfredpros/codellama-7b-instruct-solidity | chat | AlfredPros: CodeLLaMa 7B Instruct Solidity | openrouter | 4096 | 4096 | other | 0.80 | 1.20 |
| all-hands/openhands-lm-32b-v0.1 | chat | OpenHands LM 32B V0.1 | openrouter | 16384 | 4096 | other | 2.60 | 3.40 |
| allenai/molmo-7b-d:free | chat | AllenAI: Molmo 7B D (free) | openrouter | 4096 |  | other | 0.00 | 0.00 |
| alpindale/goliath-120b | chat | Goliath 120B | openrouter | 6144 | 512 | other | 6.56 | 9.38 |
| alpindale/magnum-72b | chat | Magnum 72B | openrouter | 16384 | 4096 | other | 4.00 | 6.00 |
| amazon/nova-lite-v1 | chat | Amazon: Nova Lite 1.0 | openrouter | 300000 | 5120 | other | 0.06 | 0.24 |
| amazon/nova-micro-v1 | chat | Amazon: Nova Micro 1.0 | openrouter | 128000 | 5120 | other | 0.04 | 0.14 |
| amazon/nova-pro-v1 | chat | Amazon: Nova Pro 1.0 | openrouter | 300000 | 5120 | other | 0.80 | 3.20 |
| anthracite-org/magnum-v2-72b | chat | Magnum v2 72B | openrouter | 32768 |  | other | 3.00 | 3.00 |
| anthracite-org/magnum-v4-72b | chat | Magnum v4 72B | openrouter | 16384 | 1024 | other | 1.50 | 2.25 |
| anthropic/claude-2 | chat | Anthropic: Claude v2 | openrouter | 200000 | 4096 | other | 8.00 | 24.00 |
| anthropic/claude-2.0 | chat | Anthropic: Claude v2.0 | openrouter | 100000 | 4096 | other | 8.00 | 24.00 |
| anthropic/claude-2.0:beta | chat | Anthropic: Claude v2.0 (self-moderated) | openrouter | 100000 | 4096 | other | 8.00 | 24.00 |
| anthropic/claude-2.1 | chat | Anthropic: Claude v2.1 | openrouter | 200000 | 4096 | other | 8.00 | 24.00 |
| anthropic/claude-2.1:beta | chat | Anthropic: Claude v2.1 (self-moderated) | openrouter | 200000 | 4096 | other | 8.00 | 24.00 |
| anthropic/claude-2:beta | chat | Anthropic: Claude v2 (self-moderated) | openrouter | 200000 | 4096 | other | 8.00 | 24.00 |
| anthropic/claude-3-haiku | chat | Anthropic: Claude 3 Haiku | openrouter | 200000 | 4096 | other | 0.25 | 1.25 |
| anthropic/claude-3-haiku:beta | chat | Anthropic: Claude 3 Haiku (self-moderated) | openrouter | 200000 | 4096 | other | 0.25 | 1.25 |
| anthropic/claude-3-opus | chat | Anthropic: Claude 3 Opus | openrouter | 200000 | 4096 | other | 15.00 | 75.00 |
| anthropic/claude-3-opus:beta | chat | Anthropic: Claude 3 Opus (self-moderated) | openrouter | 200000 | 4096 | other | 15.00 | 75.00 |
| anthropic/claude-3-sonnet | chat | Anthropic: Claude 3 Sonnet | openrouter | 200000 | 4096 | other | 3.00 | 15.00 |
| anthropic/claude-3-sonnet:beta | chat | Anthropic: Claude 3 Sonnet (self-moderated) | openrouter | 200000 | 4096 | other | 3.00 | 15.00 |
| anthropic/claude-3.5-haiku | chat | Anthropic: Claude 3.5 Haiku | openrouter | 200000 | 8192 | other | 0.80 | 4.00 |
| anthropic/claude-3.5-haiku-20241022 | chat | Anthropic: Claude 3.5 Haiku (2024-10-22) | openrouter | 200000 | 8192 | other | 0.80 | 4.00 |
| anthropic/claude-3.5-haiku-20241022:beta | chat | Anthropic: Claude 3.5 Haiku (2024-10-22) (self-moderated) | openrouter | 200000 | 8192 | other | 0.80 | 4.00 |
| anthropic/claude-3.5-haiku:beta | chat | Anthropic: Claude 3.5 Haiku (self-moderated) | openrouter | 200000 | 8192 | other | 0.80 | 4.00 |
| anthropic/claude-3.5-sonnet | chat | Anthropic: Claude 3.5 Sonnet | openrouter | 200000 | 8192 | other | 3.00 | 15.00 |
| anthropic/claude-3.5-sonnet-20240620 | chat | Anthropic: Claude 3.5 Sonnet (2024-06-20) | openrouter | 200000 | 8192 | other | 3.00 | 15.00 |
| anthropic/claude-3.5-sonnet-20240620:beta | chat | Anthropic: Claude 3.5 Sonnet (2024-06-20) (self-moderated) | openrouter | 200000 | 8192 | other | 3.00 | 15.00 |
| anthropic/claude-3.5-sonnet:beta | chat | Anthropic: Claude 3.5 Sonnet (self-moderated) | openrouter | 200000 | 8192 | other | 3.00 | 15.00 |
| anthropic/claude-3.7-sonnet | chat | Anthropic: Claude 3.7 Sonnet | openrouter | 200000 | 64000 | other | 3.00 | 15.00 |
| anthropic/claude-3.7-sonnet:beta | chat | Anthropic: Claude 3.7 Sonnet (self-moderated) | openrouter | 200000 | 128000 | other | 3.00 | 15.00 |
| anthropic/claude-3.7-sonnet:thinking | chat | Anthropic: Claude 3.7 Sonnet (thinking) | openrouter | 200000 | 64000 | other | 3.00 | 15.00 |
| arliai/qwq-32b-arliai-rpr-v1:free | chat | ArliAI: QwQ 32B RpR v1 (free) | openrouter | 32768 |  | other | 0.00 | 0.00 |
| bytedance-research/ui-tars-72b:free | chat | Bytedance: UI-TARS 72B  (free) | openrouter | 32768 |  | other | 0.00 | 0.00 |
| cognitivecomputations/dolphin-mixtral-8x22b | chat | Dolphin 2.9.2 Mixtral 8x22B 🐬 | openrouter | 16000 |  | other | 0.90 | 0.90 |
| cognitivecomputations/dolphin-mixtral-8x7b | chat | Dolphin 2.6 Mixtral 8x7B 🐬 | openrouter | 32768 |  | other | 0.50 | 0.50 |
| cognitivecomputations/dolphin3.0-mistral-24b:free | chat | Dolphin3.0 Mistral 24B (free) | openrouter | 32768 |  | other | 0.00 | 0.00 |
| cognitivecomputations/dolphin3.0-r1-mistral-24b:free | chat | Dolphin3.0 R1 Mistral 24B (free) | openrouter | 32768 |  | other | 0.00 | 0.00 |
| cohere/command | chat | Cohere: Command | openrouter | 4096 | 4000 | other | 1.00 | 2.00 |
| cohere/command-a | chat | Cohere: Command A | openrouter | 256000 | 8192 | other | 2.50 | 10.00 |
| cohere/command-r | chat | Cohere: Command R | openrouter | 128000 | 4000 | other | 0.50 | 1.50 |
| cohere/command-r-03-2024 | chat | Cohere: Command R (03-2024) | openrouter | 128000 | 4000 | other | 0.50 | 1.50 |
| cohere/command-r-08-2024 | chat | Cohere: Command R (08-2024) | openrouter | 128000 | 4000 | other | 0.15 | 0.60 |
| cohere/command-r-plus | chat | Cohere: Command R+ | openrouter | 128000 | 4000 | other | 3.00 | 15.00 |
| cohere/command-r-plus-04-2024 | chat | Cohere: Command R+ (04-2024) | openrouter | 128000 | 4000 | other | 3.00 | 15.00 |
| cohere/command-r-plus-08-2024 | chat | Cohere: Command R+ (08-2024) | openrouter | 128000 | 4000 | other | 2.50 | 10.00 |
| cohere/command-r7b-12-2024 | chat | Cohere: Command R7B (12-2024) | openrouter | 128000 | 4000 | other | 0.04 | 0.15 |
| deepseek/deepseek-chat | chat | DeepSeek: DeepSeek V3 | openrouter | 163840 | 163840 | other | 0.38 | 0.89 |
| deepseek/deepseek-chat-v3-0324 | chat | DeepSeek: DeepSeek V3 0324 | openrouter | 64000 | 8192 | other | 0.27 | 1.10 |
| deepseek/deepseek-chat-v3-0324:free | chat | DeepSeek: DeepSeek V3 0324 (free) | openrouter | 163840 |  | other | 0.00 | 0.00 |
| deepseek/deepseek-chat:free | chat | DeepSeek: DeepSeek V3 (free) | openrouter | 163840 |  | other | 0.00 | 0.00 |
| deepseek/deepseek-r1 | chat | DeepSeek: R1 | openrouter | 163840 | 163840 | other | 0.50 | 2.18 |
| deepseek/deepseek-r1-distill-llama-70b | chat | DeepSeek: R1 Distill Llama 70B | openrouter | 131072 | 16384 | other | 0.10 | 0.40 |
| deepseek/deepseek-r1-distill-llama-70b:free | chat | DeepSeek: R1 Distill Llama 70B (free) | openrouter | 128000 |  | other | 0.00 | 0.00 |
| deepseek/deepseek-r1-distill-llama-8b | chat | DeepSeek: R1 Distill Llama 8B | openrouter | 32000 | 32000 | other | 0.04 | 0.04 |
| deepseek/deepseek-r1-distill-qwen-1.5b | chat | DeepSeek: R1 Distill Qwen 1.5B | openrouter | 131072 | 32768 | other | 0.18 | 0.18 |
| deepseek/deepseek-r1-distill-qwen-14b | chat | DeepSeek: R1 Distill Qwen 14B | openrouter | 64000 | 64000 | other | 0.15 | 0.15 |
| deepseek/deepseek-r1-distill-qwen-14b:free | chat | DeepSeek: R1 Distill Qwen 14B (free) | openrouter | 64000 |  | other | 0.00 | 0.00 |
| deepseek/deepseek-r1-distill-qwen-32b | chat | DeepSeek: R1 Distill Qwen 32B | openrouter | 131072 | 16384 | other | 0.12 | 0.18 |
| deepseek/deepseek-r1-distill-qwen-32b:free | chat | DeepSeek: R1 Distill Qwen 32B (free) | openrouter | 16000 | 16000 | other | 0.00 | 0.00 |
| deepseek/deepseek-r1-zero:free | chat | DeepSeek: DeepSeek R1 Zero (free) | openrouter | 163840 |  | other | 0.00 | 0.00 |
| deepseek/deepseek-r1:free | chat | DeepSeek: R1 (free) | openrouter | 163840 |  | other | 0.00 | 0.00 |
| deepseek/deepseek-v3-base:free | chat | DeepSeek: DeepSeek V3 Base (free) | openrouter | 163840 |  | other | 0.00 | 0.00 |
| eleutherai/llemma_7b | chat | EleutherAI: Llemma 7b | openrouter | 4096 | 4096 | other | 0.80 | 1.20 |
| eva-unit-01/eva-llama-3.33-70b | chat | EVA Llama 3.33 70B | openrouter | 16384 | 4096 | other | 4.00 | 6.00 |
| eva-unit-01/eva-qwen-2.5-32b | chat | EVA Qwen2.5 32B | openrouter | 16384 | 4096 | other | 2.60 | 3.40 |
| eva-unit-01/eva-qwen-2.5-72b | chat | EVA Qwen2.5 72B | openrouter | 131072 | 131072 | other | 0.90 | 1.20 |
| featherless/qwerky-72b:free | chat | Qwerky 72B (free) | openrouter | 32768 | 4096 | other | 0.00 | 0.00 |
| google/gemini-2.0-flash-001 | chat | Google: Gemini 2.0 Flash | openrouter | 1000000 | 8192 | other | 0.10 | 0.40 |
| google/gemini-2.0-flash-exp:free | chat | Google: Gemini 2.0 Flash Experimental (free) | openrouter | 1048576 | 8192 | other | 0.00 | 0.00 |
| google/gemini-2.0-flash-lite-001 | chat | Google: Gemini 2.0 Flash Lite | openrouter | 1048576 | 8192 | other | 0.08 | 0.30 |
| google/gemini-2.5-flash-preview | chat | Google: Gemini 2.5 Flash Preview | openrouter | 1048576 | 65535 | other | 0.15 | 0.60 |
| google/gemini-2.5-flash-preview:thinking | chat | Google: Gemini 2.5 Flash Preview (thinking) | openrouter | 1048576 | 65535 | other | 0.15 | 3.50 |
| google/gemini-2.5-pro-exp-03-25:free | chat | Google: Gemini 2.5 Pro Experimental (free) | openrouter | 1000000 | 65535 | other | 0.00 | 0.00 |
| google/gemini-2.5-pro-preview-03-25 | chat | Google: Gemini 2.5 Pro Preview | openrouter | 1048576 | 65535 | other | 1.25 | 10.00 |
| google/gemini-flash-1.5 | chat | Google: Gemini 1.5 Flash  | openrouter | 1000000 | 8192 | other | 0.08 | 0.30 |
| google/gemini-flash-1.5-8b | chat | Google: Gemini 1.5 Flash 8B | openrouter | 1000000 | 8192 | other | 0.04 | 0.15 |
| google/gemini-flash-1.5-8b-exp | chat | Google: Gemini 1.5 Flash 8B Experimental | openrouter | 1000000 | 8192 | other | 0.00 | 0.00 |
| google/gemini-pro-1.5 | chat | Google: Gemini 1.5 Pro | openrouter | 2000000 | 8192 | other | 1.25 | 5.00 |
| google/gemini-pro-vision | chat | Google: Gemini Pro Vision 1.0 | openrouter | 16384 | 2048 | other | 0.50 | 1.50 |
| google/gemma-2-27b-it | chat | Google: Gemma 2 27B | openrouter | 8192 | 2048 | other | 0.80 | 0.80 |
| google/gemma-2-9b-it | chat | Google: Gemma 2 9B | openrouter | 8192 |  | other | 0.07 | 0.07 |
| google/gemma-2-9b-it:free | chat | Google: Gemma 2 9B (free) | openrouter | 8192 | 8192 | other | 0.00 | 0.00 |
| google/gemma-3-12b-it | chat | Google: Gemma 3 12B | openrouter | 131072 |  | other | 0.05 | 0.10 |
| google/gemma-3-12b-it:free | chat | Google: Gemma 3 12B (free) | openrouter | 131072 | 8192 | other | 0.00 | 0.00 |
| google/gemma-3-1b-it:free | chat | Google: Gemma 3 1B (free) | openrouter | 32768 | 8192 | other | 0.00 | 0.00 |
| google/gemma-3-27b-it | chat | Google: Gemma 3 27B | openrouter | 131072 | 16384 | other | 0.10 | 0.20 |
| google/gemma-3-27b-it:free | chat | Google: Gemma 3 27B (free) | openrouter | 96000 | 8192 | other | 0.00 | 0.00 |
| google/gemma-3-4b-it | chat | Google: Gemma 3 4B | openrouter | 131072 |  | other | 0.02 | 0.04 |
| google/gemma-3-4b-it:free | chat | Google: Gemma 3 4B (free) | openrouter | 131072 | 8192 | other | 0.00 | 0.00 |
| google/learnlm-1.5-pro-experimental:free | chat | Google: LearnLM 1.5 Pro Experimental (free) | openrouter | 40960 | 8192 | other | 0.00 | 0.00 |
| google/palm-2-chat-bison | chat | Google: PaLM 2 Chat | openrouter | 9216 | 1024 | other | 1.00 | 2.00 |
| google/palm-2-chat-bison-32k | chat | Google: PaLM 2 Chat 32k | openrouter | 32768 | 8192 | other | 1.00 | 2.00 |
| google/palm-2-codechat-bison | chat | Google: PaLM 2 Code Chat | openrouter | 7168 | 1024 | other | 1.00 | 2.00 |
| google/palm-2-codechat-bison-32k | chat | Google: PaLM 2 Code Chat 32k | openrouter | 32768 | 8192 | other | 1.00 | 2.00 |
| gryphe/mythomax-l2-13b | chat | MythoMax 13B | openrouter | 4096 | 4096 | other | 0.06 | 0.06 |
| huggingfaceh4/zephyr-7b-beta:free | chat | Hugging Face: Zephyr 7B (free) | openrouter | 4096 | 2048 | other | 0.00 | 0.00 |
| infermatic/mn-inferor-12b | chat | Infermatic: Mistral Nemo Inferor 12B | openrouter | 16384 | 4096 | other | 0.80 | 1.20 |
| inflection/inflection-3-pi | chat | Inflection: Inflection 3 Pi | openrouter | 8000 | 1024 | other | 2.50 | 10.00 |
| inflection/inflection-3-productivity | chat | Inflection: Inflection 3 Productivity | openrouter | 8000 | 1024 | other | 2.50 | 10.00 |
| jondurbin/airoboros-l2-70b | chat | Airoboros 70B | openrouter | 4096 |  | other | 0.50 | 0.50 |
| latitudegames/wayfarer-large-70b-llama-3.3 | chat | LatitudeGames: Wayfarer Large 70B Llama 3.3 | openrouter | 131072 | 131072 | other | 0.80 | 0.90 |
| liquid/lfm-3b | chat | Liquid: LFM 3B | openrouter | 32768 |  | other | 0.02 | 0.02 |
| liquid/lfm-40b | chat | Liquid: LFM 40B MoE | openrouter | 32768 |  | other | 0.15 | 0.15 |
| liquid/lfm-7b | chat | Liquid: LFM 7B | openrouter | 32768 |  | other | 0.01 | 0.01 |
| mancer/weaver | chat | Mancer: Weaver (alpha) | openrouter | 8000 | 1000 | other | 1.12 | 1.12 |
| meta-llama/llama-2-13b-chat | chat | Meta: Llama 2 13B Chat | openrouter | 4096 |  | other | 0.30 | 0.30 |
| meta-llama/llama-2-70b-chat | chat | Meta: Llama 2 70B Chat | openrouter | 4096 |  | other | 0.90 | 0.90 |
| meta-llama/llama-3-70b-instruct | chat | Meta: Llama 3 70B Instruct | openrouter | 8192 | 16384 | other | 0.30 | 0.40 |
| meta-llama/llama-3-8b-instruct | chat | Meta: Llama 3 8B Instruct | openrouter | 8192 | 16384 | other | 0.03 | 0.06 |
| meta-llama/llama-3.1-405b | chat | Meta: Llama 3.1 405B (base) | openrouter | 32768 |  | other | 2.00 | 2.00 |
| meta-llama/llama-3.1-405b-instruct | chat | Meta: Llama 3.1 405B Instruct | openrouter | 32768 | 16384 | other | 0.80 | 0.80 |
| meta-llama/llama-3.1-405b:free | chat | Meta: Llama 3.1 405B (base) (free) | openrouter | 64000 |  | other | 0.00 | 0.00 |
| meta-llama/llama-3.1-70b-instruct | chat | Meta: Llama 3.1 70B Instruct | openrouter | 131072 | 16384 | other | 0.10 | 0.28 |
| meta-llama/llama-3.1-8b-instruct | chat | Meta: Llama 3.1 8B Instruct | openrouter | 16384 | 16384 | other | 0.02 | 0.03 |
| meta-llama/llama-3.1-8b-instruct:free | chat | Meta: Llama 3.1 8B Instruct (free) | openrouter | 131072 | 4096 | other | 0.00 | 0.00 |
| meta-llama/llama-3.2-11b-vision-instruct | chat | Meta: Llama 3.2 11B Vision Instruct | openrouter | 131072 | 16384 | other | 0.05 | 0.05 |
| meta-llama/llama-3.2-11b-vision-instruct:free | chat | Meta: Llama 3.2 11B Vision Instruct (free) | openrouter | 131072 | 2048 | other | 0.00 | 0.00 |
| meta-llama/llama-3.2-1b-instruct | chat | Meta: Llama 3.2 1B Instruct | openrouter | 131072 |  | other | 0.01 | 0.01 |
| meta-llama/llama-3.2-1b-instruct:free | chat | Meta: Llama 3.2 1B Instruct (free) | openrouter | 131000 |  | other | 0.00 | 0.00 |
| meta-llama/llama-3.2-3b-instruct | chat | Meta: Llama 3.2 3B Instruct | openrouter | 131072 | 131072 | other | 0.02 | 0.02 |
| meta-llama/llama-3.2-3b-instruct:free | chat | Meta: Llama 3.2 3B Instruct (free) | openrouter | 20000 | 20000 | other | 0.00 | 0.00 |
| meta-llama/llama-3.2-90b-vision-instruct | chat | Meta: Llama 3.2 90B Vision Instruct | openrouter | 131072 |  | other | 0.90 | 0.90 |
| meta-llama/llama-3.3-70b-instruct | chat | Meta: Llama 3.3 70B Instruct | openrouter | 128000 | 16384 | other | 0.10 | 0.25 |
| meta-llama/llama-3.3-70b-instruct:free | chat | Meta: Llama 3.3 70B Instruct (free) | openrouter | 8000 | 8000 | other | 0.00 | 0.00 |
| meta-llama/llama-4-maverick | chat | Meta: Llama 4 Maverick | openrouter | 1048576 | 16384 | other | 0.17 | 0.60 |
| meta-llama/llama-4-maverick:free | chat | Meta: Llama 4 Maverick (free) | openrouter | 256000 |  | other | 0.00 | 0.00 |
| meta-llama/llama-4-scout | chat | Meta: Llama 4 Scout | openrouter | 1048576 | 1048576 | other | 0.08 | 0.30 |
| meta-llama/llama-4-scout:free | chat | Meta: Llama 4 Scout (free) | openrouter | 512000 |  | other | 0.00 | 0.00 |
| meta-llama/llama-guard-2-8b | chat | Meta: LlamaGuard 2 8B | openrouter | 8192 |  | other | 0.20 | 0.20 |
| meta-llama/llama-guard-3-8b | chat | Llama Guard 3 8B | openrouter | 131072 |  | other | 0.06 | 0.06 |
| microsoft/mai-ds-r1:free | chat | Microsoft: MAI DS R1 (free) | openrouter | 163840 |  | other | 0.00 | 0.00 |
| microsoft/phi-3-medium-128k-instruct | chat | Microsoft: Phi-3 Medium 128K Instruct | openrouter | 128000 |  | other | 1.00 | 1.00 |
| microsoft/phi-3-mini-128k-instruct | chat | Microsoft: Phi-3 Mini 128K Instruct | openrouter | 128000 |  | other | 0.10 | 0.10 |
| microsoft/phi-3.5-mini-128k-instruct | chat | Microsoft: Phi-3.5 Mini 128K Instruct | openrouter | 128000 |  | other | 0.10 | 0.10 |
| microsoft/phi-4 | chat | Microsoft: Phi 4 | openrouter | 16384 | 16384 | other | 0.07 | 0.14 |
| microsoft/phi-4-multimodal-instruct | chat | Microsoft: Phi 4 Multimodal Instruct | openrouter | 131072 |  | other | 0.05 | 0.10 |
| microsoft/wizardlm-2-7b | chat | WizardLM-2 7B | openrouter | 32000 |  | other | 0.07 | 0.07 |
| microsoft/wizardlm-2-8x22b | chat | WizardLM-2 8x22B | openrouter | 65536 | 16384 | other | 0.50 | 0.50 |
| minimax/minimax-01 | chat | MiniMax: MiniMax-01 | openrouter | 1000192 | 1000192 | other | 0.20 | 1.10 |
| mistral/ministral-8b | chat | Mistral: Ministral 8B | openrouter | 131072 |  | other | 0.10 | 0.10 |
| mistralai/codestral-2501 | chat | Mistral: Codestral 2501 | openrouter | 262144 |  | other | 0.30 | 0.90 |
| mistralai/codestral-mamba | chat | Mistral: Codestral Mamba | openrouter | 262144 |  | other | 0.25 | 0.25 |
| mistralai/ministral-3b | chat | Mistral: Ministral 3B | openrouter | 131072 |  | other | 0.04 | 0.04 |
| mistralai/ministral-8b | chat | Mistral: Ministral 8B | openrouter | 128000 |  | other | 0.10 | 0.10 |
| mistralai/mistral-7b-instruct | chat | Mistral: Mistral 7B Instruct | openrouter | 32768 | 16384 | other | 0.03 | 0.06 |
| mistralai/mistral-7b-instruct-v0.1 | chat | Mistral: Mistral 7B Instruct v0.1 | openrouter | 32768 | 2048 | other | 0.20 | 0.20 |
| mistralai/mistral-7b-instruct-v0.2 | chat | Mistral: Mistral 7B Instruct v0.2 | openrouter | 32768 |  | other | 0.20 | 0.20 |
| mistralai/mistral-7b-instruct-v0.3 | chat | Mistral: Mistral 7B Instruct v0.3 | openrouter | 32768 | 16384 | other | 0.03 | 0.06 |
| mistralai/mistral-7b-instruct:free | chat | Mistral: Mistral 7B Instruct (free) | openrouter | 32768 | 16384 | other | 0.00 | 0.00 |
| mistralai/mistral-large | chat | Mistral Large | openrouter | 128000 |  | other | 2.00 | 6.00 |
| mistralai/mistral-large-2407 | chat | Mistral Large 2407 | openrouter | 131072 |  | other | 2.00 | 6.00 |
| mistralai/mistral-large-2411 | chat | Mistral Large 2411 | openrouter | 131072 |  | other | 2.00 | 6.00 |
| mistralai/mistral-medium | chat | Mistral Medium | openrouter | 32768 |  | other | 2.75 | 8.10 |
| mistralai/mistral-nemo | chat | Mistral: Mistral Nemo | openrouter | 98304 | 49152 | other | 0.03 | 0.07 |
| mistralai/mistral-nemo:free | chat | Mistral: Mistral Nemo (free) | openrouter | 128000 | 128000 | other | 0.00 | 0.00 |
| mistralai/mistral-saba | chat | Mistral: Saba | openrouter | 32768 |  | other | 0.20 | 0.60 |
| mistralai/mistral-small | chat | Mistral Small | openrouter | 32768 |  | other | 0.20 | 0.60 |
| mistralai/mistral-small-24b-instruct-2501 | chat | Mistral: Mistral Small 3 | openrouter | 32768 | 16384 | other | 0.07 | 0.14 |
| mistralai/mistral-small-24b-instruct-2501:free | chat | Mistral: Mistral Small 3 (free) | openrouter | 32768 |  | other | 0.00 | 0.00 |
| mistralai/mistral-small-3.1-24b-instruct | chat | Mistral: Mistral Small 3.1 24B | openrouter | 128000 | 128000 | other | 0.10 | 0.30 |
| mistralai/mistral-small-3.1-24b-instruct:free | chat | Mistral: Mistral Small 3.1 24B (free) | openrouter | 96000 | 96000 | other | 0.00 | 0.00 |
| mistralai/mistral-tiny | chat | Mistral Tiny | openrouter | 32768 |  | other | 0.25 | 0.25 |
| mistralai/mixtral-8x22b-instruct | chat | Mistral: Mixtral 8x22B Instruct | openrouter | 65536 |  | other | 0.90 | 0.90 |
| mistralai/mixtral-8x7b-instruct | chat | Mistral: Mixtral 8x7B Instruct | openrouter | 32768 | 16384 | other | 0.24 | 0.24 |
| mistralai/pixtral-12b | chat | Mistral: Pixtral 12B | openrouter | 32768 |  | other | 0.10 | 0.10 |
| mistralai/pixtral-large-2411 | chat | Mistral: Pixtral Large 2411 | openrouter | 131072 |  | other | 2.00 | 6.00 |
| moonshotai/kimi-vl-a3b-thinking:free | chat | Moonshot AI: Kimi VL A3B Thinking (free) | openrouter | 131072 |  | other | 0.00 | 0.00 |
| moonshotai/moonlight-16b-a3b-instruct:free | chat | Moonshot AI: Moonlight 16B A3B Instruct (free) | openrouter | 8192 |  | other | 0.00 | 0.00 |
| neversleep/llama-3-lumimaid-70b | chat | NeverSleep: Llama 3 Lumimaid 70B | openrouter | 8192 | 4096 | other | 4.00 | 6.00 |
| neversleep/llama-3-lumimaid-8b | chat | NeverSleep: Llama 3 Lumimaid 8B | openrouter | 24576 | 2048 | other | 0.09 | 0.75 |
| neversleep/llama-3-lumimaid-8b:extended | chat | NeverSleep: Llama 3 Lumimaid 8B (extended) | openrouter | 24576 | 2048 | other | 0.09 | 0.75 |
| neversleep/llama-3.1-lumimaid-70b | chat | NeverSleep: Lumimaid v0.2 70B | openrouter | 16384 | 2048 | other | 1.50 | 2.25 |
| neversleep/llama-3.1-lumimaid-8b | chat | NeverSleep: Lumimaid v0.2 8B | openrouter | 32768 | 2048 | other | 0.09 | 0.75 |
| neversleep/noromaid-20b | chat | Noromaid 20B | openrouter | 8192 | 2048 | other | 0.75 | 1.50 |
| nothingiisreal/mn-celeste-12b | chat | Mistral Nemo 12B Celeste | openrouter | 16384 | 4096 | other | 0.80 | 1.20 |
| nousresearch/deephermes-3-llama-3-8b-preview:free | chat | Nous: DeepHermes 3 Llama 3 8B Preview (free) | openrouter | 131072 |  | other | 0.00 | 0.00 |
| nousresearch/hermes-2-pro-llama-3-8b | chat | NousResearch: Hermes 2 Pro - Llama-3 8B | openrouter | 131072 | 131072 | other | 0.02 | 0.04 |
| nousresearch/hermes-3-llama-3.1-405b | chat | Nous: Hermes 3 405B Instruct | openrouter | 131072 | 131072 | other | 0.80 | 0.80 |
| nousresearch/hermes-3-llama-3.1-70b | chat | Nous: Hermes 3 70B Instruct | openrouter | 131072 | 131072 | other | 0.12 | 0.30 |
| nousresearch/nous-hermes-2-mixtral-8x7b-dpo | chat | Nous: Hermes 2 Mixtral 8x7B DPO | openrouter | 32768 | 2048 | other | 0.60 | 0.60 |
| nousresearch/nous-hermes-llama2-13b | chat | Nous: Hermes 13B | openrouter | 4096 |  | other | 0.18 | 0.18 |
| nvidia/llama-3.1-nemotron-70b-instruct | chat | NVIDIA: Llama 3.1 Nemotron 70B Instruct | openrouter | 131072 | 131072 | other | 0.12 | 0.30 |
| nvidia/llama-3.1-nemotron-70b-instruct:free | chat | NVIDIA: Llama 3.1 Nemotron 70B Instruct (free) | openrouter | 131072 |  | other | 0.00 | 0.00 |
| nvidia/llama-3.1-nemotron-nano-8b-v1:free | chat | NVIDIA: Llama 3.1 Nemotron Nano 8B v1 (free) | openrouter | 131072 |  | other | 0.00 | 0.00 |
| nvidia/llama-3.1-nemotron-ultra-253b-v1:free | chat | NVIDIA: Llama 3.1 Nemotron Ultra 253B v1 (free) | openrouter | 131072 |  | other | 0.00 | 0.00 |
| nvidia/llama-3.3-nemotron-super-49b-v1:free | chat | NVIDIA: Llama 3.3 Nemotron Super 49B v1 (free) | openrouter | 131072 |  | other | 0.00 | 0.00 |
| open-r1/olympiccoder-32b:free | chat | OlympicCoder 32B (free) | openrouter | 32768 |  | other | 0.00 | 0.00 |
| openai/chatgpt-4o-latest | chat | OpenAI: ChatGPT-4o | openrouter | 128000 | 16384 | other | 5.00 | 15.00 |
| openai/gpt-3.5-turbo | chat | OpenAI: GPT-3.5 Turbo | openrouter | 16385 | 4096 | other | 0.50 | 1.50 |
| openai/gpt-3.5-turbo-0125 | chat | OpenAI: GPT-3.5 Turbo 16k | openrouter | 16385 | 4096 | other | 0.50 | 1.50 |
| openai/gpt-3.5-turbo-0613 | chat | OpenAI: GPT-3.5 Turbo (older v0613) | openrouter | 4095 | 4096 | other | 1.00 | 2.00 |
| openai/gpt-3.5-turbo-1106 | chat | OpenAI: GPT-3.5 Turbo 16k (older v1106) | openrouter | 16385 | 4096 | other | 1.00 | 2.00 |
| openai/gpt-3.5-turbo-16k | chat | OpenAI: GPT-3.5 Turbo 16k | openrouter | 16385 | 4096 | other | 3.00 | 4.00 |
| openai/gpt-3.5-turbo-instruct | chat | OpenAI: GPT-3.5 Turbo Instruct | openrouter | 4095 | 4096 | other | 1.50 | 2.00 |
| openai/gpt-4 | chat | OpenAI: GPT-4 | openrouter | 8191 | 4096 | other | 30.00 | 60.00 |
| openai/gpt-4-0314 | chat | OpenAI: GPT-4 (older v0314) | openrouter | 8191 | 4096 | other | 30.00 | 60.00 |
| openai/gpt-4-1106-preview | chat | OpenAI: GPT-4 Turbo (older v1106) | openrouter | 128000 | 4096 | other | 10.00 | 30.00 |
| openai/gpt-4-32k | chat | OpenAI: GPT-4 32k | openrouter | 32767 | 4096 | other | 60.00 | 120.00 |
| openai/gpt-4-32k-0314 | chat | OpenAI: GPT-4 32k (older v0314) | openrouter | 32767 | 4096 | other | 60.00 | 120.00 |
| openai/gpt-4-turbo | chat | OpenAI: GPT-4 Turbo | openrouter | 128000 | 4096 | other | 10.00 | 30.00 |
| openai/gpt-4-turbo-preview | chat | OpenAI: GPT-4 Turbo Preview | openrouter | 128000 | 4096 | other | 10.00 | 30.00 |
| openai/gpt-4.1 | chat | OpenAI: GPT-4.1 | openrouter | 1047576 | 32768 | other | 2.00 | 8.00 |
| openai/gpt-4.1-mini | chat | OpenAI: GPT-4.1 Mini | openrouter | 1047576 | 32768 | other | 0.40 | 1.60 |
| openai/gpt-4.1-nano | chat | OpenAI: GPT-4.1 Nano | openrouter | 1047576 | 32768 | other | 0.10 | 0.40 |
| openai/gpt-4.5-preview | chat | OpenAI: GPT-4.5 (Preview) | openrouter | 128000 | 16384 | other | 75.00 | 150.00 |
| openai/gpt-4o | chat | OpenAI: GPT-4o | openrouter | 128000 | 16384 | other | 2.50 | 10.00 |
| openai/gpt-4o-2024-05-13 | chat | OpenAI: GPT-4o (2024-05-13) | openrouter | 128000 | 4096 | other | 5.00 | 15.00 |
| openai/gpt-4o-2024-08-06 | chat | OpenAI: GPT-4o (2024-08-06) | openrouter | 128000 | 16384 | other | 2.50 | 10.00 |
| openai/gpt-4o-2024-11-20 | chat | OpenAI: GPT-4o (2024-11-20) | openrouter | 128000 | 16384 | other | 2.50 | 10.00 |
| openai/gpt-4o-mini | chat | OpenAI: GPT-4o-mini | openrouter | 128000 | 16384 | other | 0.15 | 0.60 |
| openai/gpt-4o-mini-2024-07-18 | chat | OpenAI: GPT-4o-mini (2024-07-18) | openrouter | 128000 | 16384 | other | 0.15 | 0.60 |
| openai/gpt-4o-mini-search-preview | chat | OpenAI: GPT-4o-mini Search Preview | openrouter | 128000 | 16384 | other | 0.15 | 0.60 |
| openai/gpt-4o-search-preview | chat | OpenAI: GPT-4o Search Preview | openrouter | 128000 | 16384 | other | 2.50 | 10.00 |
| openai/gpt-4o:extended | chat | OpenAI: GPT-4o (extended) | openrouter | 128000 | 64000 | other | 6.00 | 18.00 |
| openai/o1 | chat | OpenAI: o1 | openrouter | 200000 | 100000 | other | 15.00 | 60.00 |
| openai/o1-mini | chat | OpenAI: o1-mini | openrouter | 128000 | 65536 | other | 1.10 | 4.40 |
| openai/o1-mini-2024-09-12 | chat | OpenAI: o1-mini (2024-09-12) | openrouter | 128000 | 65536 | other | 1.10 | 4.40 |
| openai/o1-preview | chat | OpenAI: o1-preview | openrouter | 128000 | 32768 | other | 15.00 | 60.00 |
| openai/o1-preview-2024-09-12 | chat | OpenAI: o1-preview (2024-09-12) | openrouter | 128000 | 32768 | other | 15.00 | 60.00 |
| openai/o1-pro | chat | OpenAI: o1-pro | openrouter | 200000 | 100000 | other | 150.00 | 600.00 |
| openai/o3 | chat | OpenAI: o3 | openrouter | 200000 | 100000 | other | 10.00 | 40.00 |
| openai/o3-mini | chat | OpenAI: o3 Mini | openrouter | 200000 | 100000 | other | 1.10 | 4.40 |
| openai/o3-mini-high | chat | OpenAI: o3 Mini High | openrouter | 200000 | 100000 | other | 1.10 | 4.40 |
| openai/o4-mini | chat | OpenAI: o4 Mini | openrouter | 200000 | 100000 | other | 1.10 | 4.40 |
| openai/o4-mini-high | chat | OpenAI: o4 Mini High | openrouter | 200000 | 100000 | other | 1.10 | 4.40 |
| openchat/openchat-7b | chat | OpenChat 3.5 7B | openrouter | 8192 |  | other | 0.07 | 0.07 |
| openrouter/auto | chat | Auto Router | openrouter | 2000000 |  | other | -1000000.00 | -1000000.00 |
| perplexity/llama-3.1-sonar-large-128k-online | chat | Perplexity: Llama 3.1 Sonar 70B Online | openrouter | 127072 |  | other | 1.00 | 1.00 |
| perplexity/llama-3.1-sonar-small-128k-online | chat | Perplexity: Llama 3.1 Sonar 8B Online | openrouter | 127072 |  | other | 0.20 | 0.20 |
| perplexity/r1-1776 | chat | Perplexity: R1 1776 | openrouter | 128000 |  | other | 2.00 | 8.00 |
| perplexity/sonar | chat | Perplexity: Sonar | openrouter | 127072 |  | other | 1.00 | 1.00 |
| perplexity/sonar-deep-research | chat | Perplexity: Sonar Deep Research | openrouter | 128000 |  | other | 2.00 | 8.00 |
| perplexity/sonar-pro | chat | Perplexity: Sonar Pro | openrouter | 200000 | 8000 | other | 3.00 | 15.00 |
| perplexity/sonar-reasoning | chat | Perplexity: Sonar Reasoning | openrouter | 127000 |  | other | 1.00 | 5.00 |
| perplexity/sonar-reasoning-pro | chat | Perplexity: Sonar Reasoning Pro | openrouter | 128000 |  | other | 2.00 | 8.00 |
| pygmalionai/mythalion-13b | chat | Pygmalion: Mythalion 13B | openrouter | 8192 | 1024 | other | 0.56 | 1.12 |
| qwen/qwen-2-72b-instruct | chat | Qwen 2 72B Instruct | openrouter | 32768 | 4096 | other | 0.90 | 0.90 |
| qwen/qwen-2.5-72b-instruct | chat | Qwen2.5 72B Instruct | openrouter | 32768 | 16384 | other | 0.12 | 0.39 |
| qwen/qwen-2.5-72b-instruct:free | chat | Qwen2.5 72B Instruct (free) | openrouter | 32768 |  | other | 0.00 | 0.00 |
| qwen/qwen-2.5-7b-instruct | chat | Qwen2.5 7B Instruct | openrouter | 32768 | 16384 | other | 0.05 | 0.10 |
| qwen/qwen-2.5-7b-instruct:free | chat | Qwen2.5 7B Instruct (free) | openrouter | 32768 | 32768 | other | 0.00 | 0.00 |
| qwen/qwen-2.5-coder-32b-instruct | chat | Qwen2.5 Coder 32B Instruct | openrouter | 32768 | 16384 | other | 0.07 | 0.15 |
| qwen/qwen-2.5-coder-32b-instruct:free | chat | Qwen2.5 Coder 32B Instruct (free) | openrouter | 32768 |  | other | 0.00 | 0.00 |
| qwen/qwen-2.5-vl-72b-instruct | chat | Qwen: Qwen2.5-VL 72B Instruct | openrouter | 32768 |  | other | 0.60 | 0.60 |
| qwen/qwen-2.5-vl-7b-instruct | chat | Qwen: Qwen2.5-VL 7B Instruct | openrouter | 32768 |  | other | 0.20 | 0.20 |
| qwen/qwen-2.5-vl-7b-instruct:free | chat | Qwen: Qwen2.5-VL 7B Instruct (free) | openrouter | 64000 | 64000 | other | 0.00 | 0.00 |
| qwen/qwen-max | chat | Qwen: Qwen-Max  | openrouter | 32768 | 8192 | other | 1.60 | 6.40 |
| qwen/qwen-plus | chat | Qwen: Qwen-Plus | openrouter | 131072 | 8192 | other | 0.40 | 1.20 |
| qwen/qwen-turbo | chat | Qwen: Qwen-Turbo | openrouter | 1000000 | 8192 | other | 0.05 | 0.20 |
| qwen/qwen-vl-max | chat | Qwen: Qwen VL Max | openrouter | 7500 | 1500 | other | 0.80 | 3.20 |
| qwen/qwen-vl-plus | chat | Qwen: Qwen VL Plus | openrouter | 7500 | 1500 | other | 0.21 | 0.63 |
| qwen/qwen2.5-coder-7b-instruct | chat | Qwen: Qwen2.5 Coder 7B Instruct | openrouter | 32768 | 32768 | other | 0.20 | 0.20 |
| qwen/qwen2.5-vl-32b-instruct | chat | Qwen: Qwen2.5 VL 32B Instruct | openrouter | 128000 |  | other | 0.90 | 0.90 |
| qwen/qwen2.5-vl-32b-instruct:free | chat | Qwen: Qwen2.5 VL 32B Instruct (free) | openrouter | 8192 |  | other | 0.00 | 0.00 |
| qwen/qwen2.5-vl-3b-instruct:free | chat | Qwen: Qwen2.5 VL 3B Instruct (free) | openrouter | 64000 |  | other | 0.00 | 0.00 |
| qwen/qwen2.5-vl-72b-instruct | chat | Qwen: Qwen2.5 VL 72B Instruct | openrouter | 128000 | 128000 | other | 0.70 | 0.70 |
| qwen/qwen2.5-vl-72b-instruct:free | chat | Qwen: Qwen2.5 VL 72B Instruct (free) | openrouter | 131072 | 2048 | other | 0.00 | 0.00 |
| qwen/qwq-32b | chat | Qwen: QwQ 32B | openrouter | 131072 |  | other | 0.15 | 0.20 |
| qwen/qwq-32b-preview | chat | Qwen: QwQ 32B Preview | openrouter | 32768 |  | other | 0.20 | 0.20 |
| qwen/qwq-32b-preview:free | chat | Qwen: QwQ 32B Preview (free) | openrouter | 16384 |  | other | 0.00 | 0.00 |
| qwen/qwq-32b:free | chat | Qwen: QwQ 32B (free) | openrouter | 40000 | 40000 | other | 0.00 | 0.00 |
| raifle/sorcererlm-8x22b | chat | SorcererLM 8x22B | openrouter | 16000 |  | other | 4.50 | 4.50 |
| rekaai/reka-flash-3:free | chat | Reka: Flash 3 (free) | openrouter | 32768 |  | other | 0.00 | 0.00 |
| sao10k/fimbulvetr-11b-v2 | chat | Fimbulvetr 11B v2 | openrouter | 4096 | 4096 | other | 0.80 | 1.20 |
| sao10k/l3-euryale-70b | chat | Sao10k: Llama 3 Euryale 70B v2.1 | openrouter | 8192 | 8192 | other | 1.48 | 1.48 |
| sao10k/l3-lunaris-8b | chat | Sao10K: Llama 3 8B Lunaris | openrouter | 8192 |  | other | 0.02 | 0.05 |
| sao10k/l3.1-euryale-70b | chat | Sao10K: Llama 3.1 Euryale 70B v2.2 | openrouter | 131072 | 16384 | other | 0.70 | 0.80 |
| sao10k/l3.3-euryale-70b | chat | Sao10K: Llama 3.3 Euryale 70B | openrouter | 131072 | 16384 | other | 0.70 | 0.80 |
| scb10x/llama3.1-typhoon2-70b-instruct | chat | Typhoon2 70B Instruct | openrouter | 8192 |  | other | 0.88 | 0.88 |
| scb10x/llama3.1-typhoon2-8b-instruct | chat | Typhoon2 8B Instruct | openrouter | 8192 |  | other | 0.18 | 0.18 |
| shisa-ai/shisa-v2-llama3.3-70b:free | chat | Shisa AI: Shisa V2 Llama 3.3 70B  (free) | openrouter | 32768 |  | other | 0.00 | 0.00 |
| sophosympatheia/midnight-rose-70b | chat | Midnight Rose 70B | openrouter | 4096 |  | other | 0.80 | 0.80 |
| sophosympatheia/rogue-rose-103b-v0.2:free | chat | Rogue Rose 103B v0.2 (free) | openrouter | 4096 |  | other | 0.00 | 0.00 |
| steelskull/l3.3-electra-r1-70b | chat | SteelSkull: L3.3 Electra R1 70B | openrouter | 131072 | 131072 | other | 0.70 | 0.95 |
| thedrummer/anubis-pro-105b-v1 | chat | TheDrummer: Anubis Pro 105B V1 | openrouter | 131072 | 131072 | other | 0.80 | 1.00 |
| thedrummer/rocinante-12b | chat | Rocinante 12B | openrouter | 32768 |  | other | 0.25 | 0.50 |
| thedrummer/skyfall-36b-v2 | chat | TheDrummer: Skyfall 36B V2 | openrouter | 32768 | 32768 | other | 0.50 | 0.80 |
| thedrummer/unslopnemo-12b | chat | Unslopnemo 12B | openrouter | 32000 |  | other | 0.50 | 0.50 |
| thudm/glm-4-32b | chat | THUDM: GLM 4 32B | openrouter | 32000 |  | other | 0.24 | 0.24 |
| thudm/glm-4-32b:free | chat | THUDM: GLM 4 32B (free) | openrouter | 32768 |  | other | 0.00 | 0.00 |
| thudm/glm-z1-32b | chat | THUDM: GLM Z1 32B | openrouter | 32000 |  | other | 0.24 | 0.24 |
| thudm/glm-z1-32b:free | chat | THUDM: GLM Z1 32B (free) | openrouter | 32768 |  | other | 0.00 | 0.00 |
| undi95/remm-slerp-l2-13b | chat | ReMM SLERP 13B | openrouter | 6144 | 1024 | other | 0.56 | 1.12 |
| undi95/toppy-m-7b | chat | Toppy M 7B | openrouter | 4096 |  | other | 0.07 | 0.07 |
| x-ai/grok-2-1212 | chat | xAI: Grok 2 1212 | openrouter | 131072 |  | other | 2.00 | 10.00 |
| x-ai/grok-2-vision-1212 | chat | xAI: Grok 2 Vision 1212 | openrouter | 32768 |  | other | 2.00 | 10.00 |
| x-ai/grok-3-beta | chat | xAI: Grok 3 Beta | openrouter | 131072 |  | other | 3.00 | 15.00 |
| x-ai/grok-3-mini-beta | chat | xAI: Grok 3 Mini Beta | openrouter | 131072 |  | other | 0.30 | 0.50 |
| x-ai/grok-beta | chat | xAI: Grok Beta | openrouter | 131072 |  | other | 5.00 | 15.00 |
| x-ai/grok-vision-beta | chat | xAI: Grok Vision Beta | openrouter | 8192 |  | other | 5.00 | 15.00 |

### Image Models (3)

| ID | Type | Name | Provider | Context | MaxTok | Family | In$/M | Out$/M |
| :-- | :-- | :-- | :-- | --: | --: | :-- | --: | --: |
| imagen-3.0-generate-002 | image | Imagen 3.0 002 model | gemini | 480 | 8192 | imagen3 | 0.08 | 0.30 |
| dall-e-2 | image | DALL-E-2 | openai | 4096 | 16384 | dall_e | 0.50 | 1.50 |
| dall-e-3 | image | DALL-E-3 | openai | 4096 | 16384 | dall_e | 0.50 | 1.50 |

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

### Openai Models (71)

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
| o4-mini | chat | O4 Mini | openai | 4096 | 16384 | other | 0.50 | 1.50 |
| o4-mini-2025-04-16 | chat | O4 Mini 20250416 | openai | 4096 | 16384 | other | 0.50 | 1.50 |
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

### Gemini Models (49)

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
| gemini-2.0-flash-lite | chat | Gemini 2.0 Flash-Lite | gemini | 1048576 | 8192 | gemini20_flash_lite | 0.08 | 0.30 |
| gemini-2.0-flash-lite-001 | chat | Gemini 2.0 Flash-Lite 001 | gemini | 1048576 | 8192 | gemini20_flash_lite | 0.08 | 0.30 |
| gemini-2.0-flash-lite-preview | chat | Gemini 2.0 Flash-Lite Preview | gemini | 1048576 | 8192 | gemini20_flash_lite | 0.08 | 0.30 |
| gemini-2.0-flash-lite-preview-02-05 | chat | Gemini 2.0 Flash-Lite Preview 02-05 | gemini | 1048576 | 8192 | gemini20_flash_lite | 0.08 | 0.30 |
| gemini-2.0-flash-live-001 | chat | Gemini 2.0 Flash 001 | gemini | 131072 | 8192 | gemini20_flash | 0.10 | 0.40 |
| gemini-2.0-flash-thinking-exp | chat | Gemini 2.5 Flash Preview 04-17 | gemini | 1048576 | 65536 | gemini20_flash | 0.10 | 0.40 |
| gemini-2.0-flash-thinking-exp-01-21 | chat | Gemini 2.5 Flash Preview 04-17 | gemini | 1048576 | 65536 | gemini20_flash | 0.10 | 0.40 |
| gemini-2.0-flash-thinking-exp-1219 | chat | Gemini 2.5 Flash Preview 04-17 | gemini | 1048576 | 65536 | gemini20_flash | 0.10 | 0.40 |
| gemini-2.0-pro-exp | chat | Gemini 2.0 Pro Experimental | gemini | 1048576 | 65536 | other | 0.08 | 0.30 |
| gemini-2.0-pro-exp-02-05 | chat | Gemini 2.0 Pro Experimental 02-05 | gemini | 1048576 | 65536 | other | 0.08 | 0.30 |
| gemini-2.5-flash-preview-04-17 | chat | Gemini 2.5 Flash Preview 04-17 | gemini | 1048576 | 65536 | other | 0.08 | 0.30 |
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
| learnlm-2.0-flash-experimental | chat | LearnLM 2.0 Flash Experimental | gemini | 1048576 | 32768 | other | 0.08 | 0.30 |
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
| us.anthropic.claude-3-7-sonnet-20250219-v1:0 | chat | Claude 3.7 Sonnet | bedrock | 200000 | 4096 | claude3_sonnet | 3.00 | 15.00 |

### Openrouter Models (303)

  | ID | Type | Name | Provider | Context | MaxTok | Family | In$/M | Out$/M |
| :-- | :-- | :-- | :-- | --: | --: | :-- | --: | --: |
| 01-ai/yi-large | chat | 01.AI: Yi Large | openrouter | 32768 | 4096 | other | 3.00 | 3.00 |
| aetherwiing/mn-starcannon-12b | chat | Aetherwiing: Starcannon 12B | openrouter | 16384 | 4096 | other | 0.80 | 1.20 |
| agentica-org/deepcoder-14b-preview:free | chat | Agentica: Deepcoder 14B Preview (free) | openrouter | 96000 |  | other | 0.00 | 0.00 |
| ai21/jamba-1-5-large | chat | AI21: Jamba 1.5 Large | openrouter | 256000 | 4096 | other | 2.00 | 8.00 |
| ai21/jamba-1-5-mini | chat | AI21: Jamba 1.5 Mini | openrouter | 256000 | 4096 | other | 0.20 | 0.40 |
| ai21/jamba-1.6-large | chat | AI21: Jamba 1.6 Large | openrouter | 256000 | 4096 | other | 2.00 | 8.00 |
| ai21/jamba-1.6-mini | chat | AI21: Jamba Mini 1.6 | openrouter | 256000 | 4096 | other | 0.20 | 0.40 |
| ai21/jamba-instruct | chat | AI21: Jamba Instruct | openrouter | 256000 | 4096 | other | 0.50 | 0.70 |
| aion-labs/aion-1.0 | chat | AionLabs: Aion-1.0 | openrouter | 131072 | 32768 | other | 4.00 | 8.00 |
| aion-labs/aion-1.0-mini | chat | AionLabs: Aion-1.0-Mini | openrouter | 131072 | 32768 | other | 0.70 | 1.40 |
| aion-labs/aion-rp-llama-3.1-8b | chat | AionLabs: Aion-RP 1.0 (8B) | openrouter | 32768 | 32768 | other | 0.20 | 0.20 |
| alfredpros/codellama-7b-instruct-solidity | chat | AlfredPros: CodeLLaMa 7B Instruct Solidity | openrouter | 4096 | 4096 | other | 0.80 | 1.20 |
| all-hands/openhands-lm-32b-v0.1 | chat | OpenHands LM 32B V0.1 | openrouter | 16384 | 4096 | other | 2.60 | 3.40 |
| allenai/molmo-7b-d:free | chat | AllenAI: Molmo 7B D (free) | openrouter | 4096 |  | other | 0.00 | 0.00 |
| alpindale/goliath-120b | chat | Goliath 120B | openrouter | 6144 | 512 | other | 6.56 | 9.38 |
| alpindale/magnum-72b | chat | Magnum 72B | openrouter | 16384 | 4096 | other | 4.00 | 6.00 |
| amazon/nova-lite-v1 | chat | Amazon: Nova Lite 1.0 | openrouter | 300000 | 5120 | other | 0.06 | 0.24 |
| amazon/nova-micro-v1 | chat | Amazon: Nova Micro 1.0 | openrouter | 128000 | 5120 | other | 0.04 | 0.14 |
| amazon/nova-pro-v1 | chat | Amazon: Nova Pro 1.0 | openrouter | 300000 | 5120 | other | 0.80 | 3.20 |
| anthracite-org/magnum-v2-72b | chat | Magnum v2 72B | openrouter | 32768 |  | other | 3.00 | 3.00 |
| anthracite-org/magnum-v4-72b | chat | Magnum v4 72B | openrouter | 16384 | 1024 | other | 1.50 | 2.25 |
| anthropic/claude-2 | chat | Anthropic: Claude v2 | openrouter | 200000 | 4096 | other | 8.00 | 24.00 |
| anthropic/claude-2.0 | chat | Anthropic: Claude v2.0 | openrouter | 100000 | 4096 | other | 8.00 | 24.00 |
| anthropic/claude-2.0:beta | chat | Anthropic: Claude v2.0 (self-moderated) | openrouter | 100000 | 4096 | other | 8.00 | 24.00 |
| anthropic/claude-2.1 | chat | Anthropic: Claude v2.1 | openrouter | 200000 | 4096 | other | 8.00 | 24.00 |
| anthropic/claude-2.1:beta | chat | Anthropic: Claude v2.1 (self-moderated) | openrouter | 200000 | 4096 | other | 8.00 | 24.00 |
| anthropic/claude-2:beta | chat | Anthropic: Claude v2 (self-moderated) | openrouter | 200000 | 4096 | other | 8.00 | 24.00 |
| anthropic/claude-3-haiku | chat | Anthropic: Claude 3 Haiku | openrouter | 200000 | 4096 | other | 0.25 | 1.25 |
| anthropic/claude-3-haiku:beta | chat | Anthropic: Claude 3 Haiku (self-moderated) | openrouter | 200000 | 4096 | other | 0.25 | 1.25 |
| anthropic/claude-3-opus | chat | Anthropic: Claude 3 Opus | openrouter | 200000 | 4096 | other | 15.00 | 75.00 |
| anthropic/claude-3-opus:beta | chat | Anthropic: Claude 3 Opus (self-moderated) | openrouter | 200000 | 4096 | other | 15.00 | 75.00 |
| anthropic/claude-3-sonnet | chat | Anthropic: Claude 3 Sonnet | openrouter | 200000 | 4096 | other | 3.00 | 15.00 |
| anthropic/claude-3-sonnet:beta | chat | Anthropic: Claude 3 Sonnet (self-moderated) | openrouter | 200000 | 4096 | other | 3.00 | 15.00 |
| anthropic/claude-3.5-haiku | chat | Anthropic: Claude 3.5 Haiku | openrouter | 200000 | 8192 | other | 0.80 | 4.00 |
| anthropic/claude-3.5-haiku-20241022 | chat | Anthropic: Claude 3.5 Haiku (2024-10-22) | openrouter | 200000 | 8192 | other | 0.80 | 4.00 |
| anthropic/claude-3.5-haiku-20241022:beta | chat | Anthropic: Claude 3.5 Haiku (2024-10-22) (self-moderated) | openrouter | 200000 | 8192 | other | 0.80 | 4.00 |
| anthropic/claude-3.5-haiku:beta | chat | Anthropic: Claude 3.5 Haiku (self-moderated) | openrouter | 200000 | 8192 | other | 0.80 | 4.00 |
| anthropic/claude-3.5-sonnet | chat | Anthropic: Claude 3.5 Sonnet | openrouter | 200000 | 8192 | other | 3.00 | 15.00 |
| anthropic/claude-3.5-sonnet-20240620 | chat | Anthropic: Claude 3.5 Sonnet (2024-06-20) | openrouter | 200000 | 8192 | other | 3.00 | 15.00 |
| anthropic/claude-3.5-sonnet-20240620:beta | chat | Anthropic: Claude 3.5 Sonnet (2024-06-20) (self-moderated) | openrouter | 200000 | 8192 | other | 3.00 | 15.00 |
| anthropic/claude-3.5-sonnet:beta | chat | Anthropic: Claude 3.5 Sonnet (self-moderated) | openrouter | 200000 | 8192 | other | 3.00 | 15.00 |
| anthropic/claude-3.7-sonnet | chat | Anthropic: Claude 3.7 Sonnet | openrouter | 200000 | 64000 | other | 3.00 | 15.00 |
| anthropic/claude-3.7-sonnet:beta | chat | Anthropic: Claude 3.7 Sonnet (self-moderated) | openrouter | 200000 | 128000 | other | 3.00 | 15.00 |
| anthropic/claude-3.7-sonnet:thinking | chat | Anthropic: Claude 3.7 Sonnet (thinking) | openrouter | 200000 | 64000 | other | 3.00 | 15.00 |
| arliai/qwq-32b-arliai-rpr-v1:free | chat | ArliAI: QwQ 32B RpR v1 (free) | openrouter | 32768 |  | other | 0.00 | 0.00 |
| bytedance-research/ui-tars-72b:free | chat | Bytedance: UI-TARS 72B  (free) | openrouter | 32768 |  | other | 0.00 | 0.00 |
| cognitivecomputations/dolphin-mixtral-8x22b | chat | Dolphin 2.9.2 Mixtral 8x22B 🐬 | openrouter | 16000 |  | other | 0.90 | 0.90 |
| cognitivecomputations/dolphin-mixtral-8x7b | chat | Dolphin 2.6 Mixtral 8x7B 🐬 | openrouter | 32768 |  | other | 0.50 | 0.50 |
| cognitivecomputations/dolphin3.0-mistral-24b:free | chat | Dolphin3.0 Mistral 24B (free) | openrouter | 32768 |  | other | 0.00 | 0.00 |
| cognitivecomputations/dolphin3.0-r1-mistral-24b:free | chat | Dolphin3.0 R1 Mistral 24B (free) | openrouter | 32768 |  | other | 0.00 | 0.00 |
| cohere/command | chat | Cohere: Command | openrouter | 4096 | 4000 | other | 1.00 | 2.00 |
| cohere/command-a | chat | Cohere: Command A | openrouter | 256000 | 8192 | other | 2.50 | 10.00 |
| cohere/command-r | chat | Cohere: Command R | openrouter | 128000 | 4000 | other | 0.50 | 1.50 |
| cohere/command-r-03-2024 | chat | Cohere: Command R (03-2024) | openrouter | 128000 | 4000 | other | 0.50 | 1.50 |
| cohere/command-r-08-2024 | chat | Cohere: Command R (08-2024) | openrouter | 128000 | 4000 | other | 0.15 | 0.60 |
| cohere/command-r-plus | chat | Cohere: Command R+ | openrouter | 128000 | 4000 | other | 3.00 | 15.00 |
| cohere/command-r-plus-04-2024 | chat | Cohere: Command R+ (04-2024) | openrouter | 128000 | 4000 | other | 3.00 | 15.00 |
| cohere/command-r-plus-08-2024 | chat | Cohere: Command R+ (08-2024) | openrouter | 128000 | 4000 | other | 2.50 | 10.00 |
| cohere/command-r7b-12-2024 | chat | Cohere: Command R7B (12-2024) | openrouter | 128000 | 4000 | other | 0.04 | 0.15 |
| deepseek/deepseek-chat | chat | DeepSeek: DeepSeek V3 | openrouter | 163840 | 163840 | other | 0.38 | 0.89 |
| deepseek/deepseek-chat-v3-0324 | chat | DeepSeek: DeepSeek V3 0324 | openrouter | 64000 | 8192 | other | 0.27 | 1.10 |
| deepseek/deepseek-chat-v3-0324:free | chat | DeepSeek: DeepSeek V3 0324 (free) | openrouter | 163840 |  | other | 0.00 | 0.00 |
| deepseek/deepseek-chat:free | chat | DeepSeek: DeepSeek V3 (free) | openrouter | 163840 |  | other | 0.00 | 0.00 |
| deepseek/deepseek-r1 | chat | DeepSeek: R1 | openrouter | 163840 | 163840 | other | 0.50 | 2.18 |
| deepseek/deepseek-r1-distill-llama-70b | chat | DeepSeek: R1 Distill Llama 70B | openrouter | 131072 | 16384 | other | 0.10 | 0.40 |
| deepseek/deepseek-r1-distill-llama-70b:free | chat | DeepSeek: R1 Distill Llama 70B (free) | openrouter | 128000 |  | other | 0.00 | 0.00 |
| deepseek/deepseek-r1-distill-llama-8b | chat | DeepSeek: R1 Distill Llama 8B | openrouter | 32000 | 32000 | other | 0.04 | 0.04 |
| deepseek/deepseek-r1-distill-qwen-1.5b | chat | DeepSeek: R1 Distill Qwen 1.5B | openrouter | 131072 | 32768 | other | 0.18 | 0.18 |
| deepseek/deepseek-r1-distill-qwen-14b | chat | DeepSeek: R1 Distill Qwen 14B | openrouter | 64000 | 64000 | other | 0.15 | 0.15 |
| deepseek/deepseek-r1-distill-qwen-14b:free | chat | DeepSeek: R1 Distill Qwen 14B (free) | openrouter | 64000 |  | other | 0.00 | 0.00 |
| deepseek/deepseek-r1-distill-qwen-32b | chat | DeepSeek: R1 Distill Qwen 32B | openrouter | 131072 | 16384 | other | 0.12 | 0.18 |
| deepseek/deepseek-r1-distill-qwen-32b:free | chat | DeepSeek: R1 Distill Qwen 32B (free) | openrouter | 16000 | 16000 | other | 0.00 | 0.00 |
| deepseek/deepseek-r1-zero:free | chat | DeepSeek: DeepSeek R1 Zero (free) | openrouter | 163840 |  | other | 0.00 | 0.00 |
| deepseek/deepseek-r1:free | chat | DeepSeek: R1 (free) | openrouter | 163840 |  | other | 0.00 | 0.00 |
| deepseek/deepseek-v3-base:free | chat | DeepSeek: DeepSeek V3 Base (free) | openrouter | 163840 |  | other | 0.00 | 0.00 |
| eleutherai/llemma_7b | chat | EleutherAI: Llemma 7b | openrouter | 4096 | 4096 | other | 0.80 | 1.20 |
| eva-unit-01/eva-llama-3.33-70b | chat | EVA Llama 3.33 70B | openrouter | 16384 | 4096 | other | 4.00 | 6.00 |
| eva-unit-01/eva-qwen-2.5-32b | chat | EVA Qwen2.5 32B | openrouter | 16384 | 4096 | other | 2.60 | 3.40 |
| eva-unit-01/eva-qwen-2.5-72b | chat | EVA Qwen2.5 72B | openrouter | 131072 | 131072 | other | 0.90 | 1.20 |
| featherless/qwerky-72b:free | chat | Qwerky 72B (free) | openrouter | 32768 | 4096 | other | 0.00 | 0.00 |
| google/gemini-2.0-flash-001 | chat | Google: Gemini 2.0 Flash | openrouter | 1000000 | 8192 | other | 0.10 | 0.40 |
| google/gemini-2.0-flash-exp:free | chat | Google: Gemini 2.0 Flash Experimental (free) | openrouter | 1048576 | 8192 | other | 0.00 | 0.00 |
| google/gemini-2.0-flash-lite-001 | chat | Google: Gemini 2.0 Flash Lite | openrouter | 1048576 | 8192 | other | 0.08 | 0.30 |
| google/gemini-2.5-flash-preview | chat | Google: Gemini 2.5 Flash Preview | openrouter | 1048576 | 65535 | other | 0.15 | 0.60 |
| google/gemini-2.5-flash-preview:thinking | chat | Google: Gemini 2.5 Flash Preview (thinking) | openrouter | 1048576 | 65535 | other | 0.15 | 3.50 |
| google/gemini-2.5-pro-exp-03-25:free | chat | Google: Gemini 2.5 Pro Experimental (free) | openrouter | 1000000 | 65535 | other | 0.00 | 0.00 |
| google/gemini-2.5-pro-preview-03-25 | chat | Google: Gemini 2.5 Pro Preview | openrouter | 1048576 | 65535 | other | 1.25 | 10.00 |
| google/gemini-flash-1.5 | chat | Google: Gemini 1.5 Flash  | openrouter | 1000000 | 8192 | other | 0.08 | 0.30 |
| google/gemini-flash-1.5-8b | chat | Google: Gemini 1.5 Flash 8B | openrouter | 1000000 | 8192 | other | 0.04 | 0.15 |
| google/gemini-flash-1.5-8b-exp | chat | Google: Gemini 1.5 Flash 8B Experimental | openrouter | 1000000 | 8192 | other | 0.00 | 0.00 |
| google/gemini-pro-1.5 | chat | Google: Gemini 1.5 Pro | openrouter | 2000000 | 8192 | other | 1.25 | 5.00 |
| google/gemini-pro-vision | chat | Google: Gemini Pro Vision 1.0 | openrouter | 16384 | 2048 | other | 0.50 | 1.50 |
| google/gemma-2-27b-it | chat | Google: Gemma 2 27B | openrouter | 8192 | 2048 | other | 0.80 | 0.80 |
| google/gemma-2-9b-it | chat | Google: Gemma 2 9B | openrouter | 8192 |  | other | 0.07 | 0.07 |
| google/gemma-2-9b-it:free | chat | Google: Gemma 2 9B (free) | openrouter | 8192 | 8192 | other | 0.00 | 0.00 |
| google/gemma-3-12b-it | chat | Google: Gemma 3 12B | openrouter | 131072 |  | other | 0.05 | 0.10 |
| google/gemma-3-12b-it:free | chat | Google: Gemma 3 12B (free) | openrouter | 131072 | 8192 | other | 0.00 | 0.00 |
| google/gemma-3-1b-it:free | chat | Google: Gemma 3 1B (free) | openrouter | 32768 | 8192 | other | 0.00 | 0.00 |
| google/gemma-3-27b-it | chat | Google: Gemma 3 27B | openrouter | 131072 | 16384 | other | 0.10 | 0.20 |
| google/gemma-3-27b-it:free | chat | Google: Gemma 3 27B (free) | openrouter | 96000 | 8192 | other | 0.00 | 0.00 |
| google/gemma-3-4b-it | chat | Google: Gemma 3 4B | openrouter | 131072 |  | other | 0.02 | 0.04 |
| google/gemma-3-4b-it:free | chat | Google: Gemma 3 4B (free) | openrouter | 131072 | 8192 | other | 0.00 | 0.00 |
| google/learnlm-1.5-pro-experimental:free | chat | Google: LearnLM 1.5 Pro Experimental (free) | openrouter | 40960 | 8192 | other | 0.00 | 0.00 |
| google/palm-2-chat-bison | chat | Google: PaLM 2 Chat | openrouter | 9216 | 1024 | other | 1.00 | 2.00 |
| google/palm-2-chat-bison-32k | chat | Google: PaLM 2 Chat 32k | openrouter | 32768 | 8192 | other | 1.00 | 2.00 |
| google/palm-2-codechat-bison | chat | Google: PaLM 2 Code Chat | openrouter | 7168 | 1024 | other | 1.00 | 2.00 |
| google/palm-2-codechat-bison-32k | chat | Google: PaLM 2 Code Chat 32k | openrouter | 32768 | 8192 | other | 1.00 | 2.00 |
| gryphe/mythomax-l2-13b | chat | MythoMax 13B | openrouter | 4096 | 4096 | other | 0.06 | 0.06 |
| huggingfaceh4/zephyr-7b-beta:free | chat | Hugging Face: Zephyr 7B (free) | openrouter | 4096 | 2048 | other | 0.00 | 0.00 |
| infermatic/mn-inferor-12b | chat | Infermatic: Mistral Nemo Inferor 12B | openrouter | 16384 | 4096 | other | 0.80 | 1.20 |
| inflection/inflection-3-pi | chat | Inflection: Inflection 3 Pi | openrouter | 8000 | 1024 | other | 2.50 | 10.00 |
| inflection/inflection-3-productivity | chat | Inflection: Inflection 3 Productivity | openrouter | 8000 | 1024 | other | 2.50 | 10.00 |
| jondurbin/airoboros-l2-70b | chat | Airoboros 70B | openrouter | 4096 |  | other | 0.50 | 0.50 |
| latitudegames/wayfarer-large-70b-llama-3.3 | chat | LatitudeGames: Wayfarer Large 70B Llama 3.3 | openrouter | 131072 | 131072 | other | 0.80 | 0.90 |
| liquid/lfm-3b | chat | Liquid: LFM 3B | openrouter | 32768 |  | other | 0.02 | 0.02 |
| liquid/lfm-40b | chat | Liquid: LFM 40B MoE | openrouter | 32768 |  | other | 0.15 | 0.15 |
| liquid/lfm-7b | chat | Liquid: LFM 7B | openrouter | 32768 |  | other | 0.01 | 0.01 |
| mancer/weaver | chat | Mancer: Weaver (alpha) | openrouter | 8000 | 1000 | other | 1.12 | 1.12 |
| meta-llama/llama-2-13b-chat | chat | Meta: Llama 2 13B Chat | openrouter | 4096 |  | other | 0.30 | 0.30 |
| meta-llama/llama-2-70b-chat | chat | Meta: Llama 2 70B Chat | openrouter | 4096 |  | other | 0.90 | 0.90 |
| meta-llama/llama-3-70b-instruct | chat | Meta: Llama 3 70B Instruct | openrouter | 8192 | 16384 | other | 0.30 | 0.40 |
| meta-llama/llama-3-8b-instruct | chat | Meta: Llama 3 8B Instruct | openrouter | 8192 | 16384 | other | 0.03 | 0.06 |
| meta-llama/llama-3.1-405b | chat | Meta: Llama 3.1 405B (base) | openrouter | 32768 |  | other | 2.00 | 2.00 |
| meta-llama/llama-3.1-405b-instruct | chat | Meta: Llama 3.1 405B Instruct | openrouter | 32768 | 16384 | other | 0.80 | 0.80 |
| meta-llama/llama-3.1-405b:free | chat | Meta: Llama 3.1 405B (base) (free) | openrouter | 64000 |  | other | 0.00 | 0.00 |
| meta-llama/llama-3.1-70b-instruct | chat | Meta: Llama 3.1 70B Instruct | openrouter | 131072 | 16384 | other | 0.10 | 0.28 |
| meta-llama/llama-3.1-8b-instruct | chat | Meta: Llama 3.1 8B Instruct | openrouter | 16384 | 16384 | other | 0.02 | 0.03 |
| meta-llama/llama-3.1-8b-instruct:free | chat | Meta: Llama 3.1 8B Instruct (free) | openrouter | 131072 | 4096 | other | 0.00 | 0.00 |
| meta-llama/llama-3.2-11b-vision-instruct | chat | Meta: Llama 3.2 11B Vision Instruct | openrouter | 131072 | 16384 | other | 0.05 | 0.05 |
| meta-llama/llama-3.2-11b-vision-instruct:free | chat | Meta: Llama 3.2 11B Vision Instruct (free) | openrouter | 131072 | 2048 | other | 0.00 | 0.00 |
| meta-llama/llama-3.2-1b-instruct | chat | Meta: Llama 3.2 1B Instruct | openrouter | 131072 |  | other | 0.01 | 0.01 |
| meta-llama/llama-3.2-1b-instruct:free | chat | Meta: Llama 3.2 1B Instruct (free) | openrouter | 131000 |  | other | 0.00 | 0.00 |
| meta-llama/llama-3.2-3b-instruct | chat | Meta: Llama 3.2 3B Instruct | openrouter | 131072 | 131072 | other | 0.02 | 0.02 |
| meta-llama/llama-3.2-3b-instruct:free | chat | Meta: Llama 3.2 3B Instruct (free) | openrouter | 20000 | 20000 | other | 0.00 | 0.00 |
| meta-llama/llama-3.2-90b-vision-instruct | chat | Meta: Llama 3.2 90B Vision Instruct | openrouter | 131072 |  | other | 0.90 | 0.90 |
| meta-llama/llama-3.3-70b-instruct | chat | Meta: Llama 3.3 70B Instruct | openrouter | 128000 | 16384 | other | 0.10 | 0.25 |
| meta-llama/llama-3.3-70b-instruct:free | chat | Meta: Llama 3.3 70B Instruct (free) | openrouter | 8000 | 8000 | other | 0.00 | 0.00 |
| meta-llama/llama-4-maverick | chat | Meta: Llama 4 Maverick | openrouter | 1048576 | 16384 | other | 0.17 | 0.60 |
| meta-llama/llama-4-maverick:free | chat | Meta: Llama 4 Maverick (free) | openrouter | 256000 |  | other | 0.00 | 0.00 |
| meta-llama/llama-4-scout | chat | Meta: Llama 4 Scout | openrouter | 1048576 | 1048576 | other | 0.08 | 0.30 |
| meta-llama/llama-4-scout:free | chat | Meta: Llama 4 Scout (free) | openrouter | 512000 |  | other | 0.00 | 0.00 |
| meta-llama/llama-guard-2-8b | chat | Meta: LlamaGuard 2 8B | openrouter | 8192 |  | other | 0.20 | 0.20 |
| meta-llama/llama-guard-3-8b | chat | Llama Guard 3 8B | openrouter | 131072 |  | other | 0.06 | 0.06 |
| microsoft/mai-ds-r1:free | chat | Microsoft: MAI DS R1 (free) | openrouter | 163840 |  | other | 0.00 | 0.00 |
| microsoft/phi-3-medium-128k-instruct | chat | Microsoft: Phi-3 Medium 128K Instruct | openrouter | 128000 |  | other | 1.00 | 1.00 |
| microsoft/phi-3-mini-128k-instruct | chat | Microsoft: Phi-3 Mini 128K Instruct | openrouter | 128000 |  | other | 0.10 | 0.10 |
| microsoft/phi-3.5-mini-128k-instruct | chat | Microsoft: Phi-3.5 Mini 128K Instruct | openrouter | 128000 |  | other | 0.10 | 0.10 |
| microsoft/phi-4 | chat | Microsoft: Phi 4 | openrouter | 16384 | 16384 | other | 0.07 | 0.14 |
| microsoft/phi-4-multimodal-instruct | chat | Microsoft: Phi 4 Multimodal Instruct | openrouter | 131072 |  | other | 0.05 | 0.10 |
| microsoft/wizardlm-2-7b | chat | WizardLM-2 7B | openrouter | 32000 |  | other | 0.07 | 0.07 |
| microsoft/wizardlm-2-8x22b | chat | WizardLM-2 8x22B | openrouter | 65536 | 16384 | other | 0.50 | 0.50 |
| minimax/minimax-01 | chat | MiniMax: MiniMax-01 | openrouter | 1000192 | 1000192 | other | 0.20 | 1.10 |
| mistral/ministral-8b | chat | Mistral: Ministral 8B | openrouter | 131072 |  | other | 0.10 | 0.10 |
| mistralai/codestral-2501 | chat | Mistral: Codestral 2501 | openrouter | 262144 |  | other | 0.30 | 0.90 |
| mistralai/codestral-mamba | chat | Mistral: Codestral Mamba | openrouter | 262144 |  | other | 0.25 | 0.25 |
| mistralai/ministral-3b | chat | Mistral: Ministral 3B | openrouter | 131072 |  | other | 0.04 | 0.04 |
| mistralai/ministral-8b | chat | Mistral: Ministral 8B | openrouter | 128000 |  | other | 0.10 | 0.10 |
| mistralai/mistral-7b-instruct | chat | Mistral: Mistral 7B Instruct | openrouter | 32768 | 16384 | other | 0.03 | 0.06 |
| mistralai/mistral-7b-instruct-v0.1 | chat | Mistral: Mistral 7B Instruct v0.1 | openrouter | 32768 | 2048 | other | 0.20 | 0.20 |
| mistralai/mistral-7b-instruct-v0.2 | chat | Mistral: Mistral 7B Instruct v0.2 | openrouter | 32768 |  | other | 0.20 | 0.20 |
| mistralai/mistral-7b-instruct-v0.3 | chat | Mistral: Mistral 7B Instruct v0.3 | openrouter | 32768 | 16384 | other | 0.03 | 0.06 |
| mistralai/mistral-7b-instruct:free | chat | Mistral: Mistral 7B Instruct (free) | openrouter | 32768 | 16384 | other | 0.00 | 0.00 |
| mistralai/mistral-large | chat | Mistral Large | openrouter | 128000 |  | other | 2.00 | 6.00 |
| mistralai/mistral-large-2407 | chat | Mistral Large 2407 | openrouter | 131072 |  | other | 2.00 | 6.00 |
| mistralai/mistral-large-2411 | chat | Mistral Large 2411 | openrouter | 131072 |  | other | 2.00 | 6.00 |
| mistralai/mistral-medium | chat | Mistral Medium | openrouter | 32768 |  | other | 2.75 | 8.10 |
| mistralai/mistral-nemo | chat | Mistral: Mistral Nemo | openrouter | 98304 | 49152 | other | 0.03 | 0.07 |
| mistralai/mistral-nemo:free | chat | Mistral: Mistral Nemo (free) | openrouter | 128000 | 128000 | other | 0.00 | 0.00 |
| mistralai/mistral-saba | chat | Mistral: Saba | openrouter | 32768 |  | other | 0.20 | 0.60 |
| mistralai/mistral-small | chat | Mistral Small | openrouter | 32768 |  | other | 0.20 | 0.60 |
| mistralai/mistral-small-24b-instruct-2501 | chat | Mistral: Mistral Small 3 | openrouter | 32768 | 16384 | other | 0.07 | 0.14 |
| mistralai/mistral-small-24b-instruct-2501:free | chat | Mistral: Mistral Small 3 (free) | openrouter | 32768 |  | other | 0.00 | 0.00 |
| mistralai/mistral-small-3.1-24b-instruct | chat | Mistral: Mistral Small 3.1 24B | openrouter | 128000 | 128000 | other | 0.10 | 0.30 |
| mistralai/mistral-small-3.1-24b-instruct:free | chat | Mistral: Mistral Small 3.1 24B (free) | openrouter | 96000 | 96000 | other | 0.00 | 0.00 |
| mistralai/mistral-tiny | chat | Mistral Tiny | openrouter | 32768 |  | other | 0.25 | 0.25 |
| mistralai/mixtral-8x22b-instruct | chat | Mistral: Mixtral 8x22B Instruct | openrouter | 65536 |  | other | 0.90 | 0.90 |
| mistralai/mixtral-8x7b-instruct | chat | Mistral: Mixtral 8x7B Instruct | openrouter | 32768 | 16384 | other | 0.24 | 0.24 |
| mistralai/pixtral-12b | chat | Mistral: Pixtral 12B | openrouter | 32768 |  | other | 0.10 | 0.10 |
| mistralai/pixtral-large-2411 | chat | Mistral: Pixtral Large 2411 | openrouter | 131072 |  | other | 2.00 | 6.00 |
| moonshotai/kimi-vl-a3b-thinking:free | chat | Moonshot AI: Kimi VL A3B Thinking (free) | openrouter | 131072 |  | other | 0.00 | 0.00 |
| moonshotai/moonlight-16b-a3b-instruct:free | chat | Moonshot AI: Moonlight 16B A3B Instruct (free) | openrouter | 8192 |  | other | 0.00 | 0.00 |
| neversleep/llama-3-lumimaid-70b | chat | NeverSleep: Llama 3 Lumimaid 70B | openrouter | 8192 | 4096 | other | 4.00 | 6.00 |
| neversleep/llama-3-lumimaid-8b | chat | NeverSleep: Llama 3 Lumimaid 8B | openrouter | 24576 | 2048 | other | 0.09 | 0.75 |
| neversleep/llama-3-lumimaid-8b:extended | chat | NeverSleep: Llama 3 Lumimaid 8B (extended) | openrouter | 24576 | 2048 | other | 0.09 | 0.75 |
| neversleep/llama-3.1-lumimaid-70b | chat | NeverSleep: Lumimaid v0.2 70B | openrouter | 16384 | 2048 | other | 1.50 | 2.25 |
| neversleep/llama-3.1-lumimaid-8b | chat | NeverSleep: Lumimaid v0.2 8B | openrouter | 32768 | 2048 | other | 0.09 | 0.75 |
| neversleep/noromaid-20b | chat | Noromaid 20B | openrouter | 8192 | 2048 | other | 0.75 | 1.50 |
| nothingiisreal/mn-celeste-12b | chat | Mistral Nemo 12B Celeste | openrouter | 16384 | 4096 | other | 0.80 | 1.20 |
| nousresearch/deephermes-3-llama-3-8b-preview:free | chat | Nous: DeepHermes 3 Llama 3 8B Preview (free) | openrouter | 131072 |  | other | 0.00 | 0.00 |
| nousresearch/hermes-2-pro-llama-3-8b | chat | NousResearch: Hermes 2 Pro - Llama-3 8B | openrouter | 131072 | 131072 | other | 0.02 | 0.04 |
| nousresearch/hermes-3-llama-3.1-405b | chat | Nous: Hermes 3 405B Instruct | openrouter | 131072 | 131072 | other | 0.80 | 0.80 |
| nousresearch/hermes-3-llama-3.1-70b | chat | Nous: Hermes 3 70B Instruct | openrouter | 131072 | 131072 | other | 0.12 | 0.30 |
| nousresearch/nous-hermes-2-mixtral-8x7b-dpo | chat | Nous: Hermes 2 Mixtral 8x7B DPO | openrouter | 32768 | 2048 | other | 0.60 | 0.60 |
| nousresearch/nous-hermes-llama2-13b | chat | Nous: Hermes 13B | openrouter | 4096 |  | other | 0.18 | 0.18 |
| nvidia/llama-3.1-nemotron-70b-instruct | chat | NVIDIA: Llama 3.1 Nemotron 70B Instruct | openrouter | 131072 | 131072 | other | 0.12 | 0.30 |
| nvidia/llama-3.1-nemotron-70b-instruct:free | chat | NVIDIA: Llama 3.1 Nemotron 70B Instruct (free) | openrouter | 131072 |  | other | 0.00 | 0.00 |
| nvidia/llama-3.1-nemotron-nano-8b-v1:free | chat | NVIDIA: Llama 3.1 Nemotron Nano 8B v1 (free) | openrouter | 131072 |  | other | 0.00 | 0.00 |
| nvidia/llama-3.1-nemotron-ultra-253b-v1:free | chat | NVIDIA: Llama 3.1 Nemotron Ultra 253B v1 (free) | openrouter | 131072 |  | other | 0.00 | 0.00 |
| nvidia/llama-3.3-nemotron-super-49b-v1:free | chat | NVIDIA: Llama 3.3 Nemotron Super 49B v1 (free) | openrouter | 131072 |  | other | 0.00 | 0.00 |
| open-r1/olympiccoder-32b:free | chat | OlympicCoder 32B (free) | openrouter | 32768 |  | other | 0.00 | 0.00 |
| openai/chatgpt-4o-latest | chat | OpenAI: ChatGPT-4o | openrouter | 128000 | 16384 | other | 5.00 | 15.00 |
| openai/gpt-3.5-turbo | chat | OpenAI: GPT-3.5 Turbo | openrouter | 16385 | 4096 | other | 0.50 | 1.50 |
| openai/gpt-3.5-turbo-0125 | chat | OpenAI: GPT-3.5 Turbo 16k | openrouter | 16385 | 4096 | other | 0.50 | 1.50 |
| openai/gpt-3.5-turbo-0613 | chat | OpenAI: GPT-3.5 Turbo (older v0613) | openrouter | 4095 | 4096 | other | 1.00 | 2.00 |
| openai/gpt-3.5-turbo-1106 | chat | OpenAI: GPT-3.5 Turbo 16k (older v1106) | openrouter | 16385 | 4096 | other | 1.00 | 2.00 |
| openai/gpt-3.5-turbo-16k | chat | OpenAI: GPT-3.5 Turbo 16k | openrouter | 16385 | 4096 | other | 3.00 | 4.00 |
| openai/gpt-3.5-turbo-instruct | chat | OpenAI: GPT-3.5 Turbo Instruct | openrouter | 4095 | 4096 | other | 1.50 | 2.00 |
| openai/gpt-4 | chat | OpenAI: GPT-4 | openrouter | 8191 | 4096 | other | 30.00 | 60.00 |
| openai/gpt-4-0314 | chat | OpenAI: GPT-4 (older v0314) | openrouter | 8191 | 4096 | other | 30.00 | 60.00 |
| openai/gpt-4-1106-preview | chat | OpenAI: GPT-4 Turbo (older v1106) | openrouter | 128000 | 4096 | other | 10.00 | 30.00 |
| openai/gpt-4-32k | chat | OpenAI: GPT-4 32k | openrouter | 32767 | 4096 | other | 60.00 | 120.00 |
| openai/gpt-4-32k-0314 | chat | OpenAI: GPT-4 32k (older v0314) | openrouter | 32767 | 4096 | other | 60.00 | 120.00 |
| openai/gpt-4-turbo | chat | OpenAI: GPT-4 Turbo | openrouter | 128000 | 4096 | other | 10.00 | 30.00 |
| openai/gpt-4-turbo-preview | chat | OpenAI: GPT-4 Turbo Preview | openrouter | 128000 | 4096 | other | 10.00 | 30.00 |
| openai/gpt-4.1 | chat | OpenAI: GPT-4.1 | openrouter | 1047576 | 32768 | other | 2.00 | 8.00 |
| openai/gpt-4.1-mini | chat | OpenAI: GPT-4.1 Mini | openrouter | 1047576 | 32768 | other | 0.40 | 1.60 |
| openai/gpt-4.1-nano | chat | OpenAI: GPT-4.1 Nano | openrouter | 1047576 | 32768 | other | 0.10 | 0.40 |
| openai/gpt-4.5-preview | chat | OpenAI: GPT-4.5 (Preview) | openrouter | 128000 | 16384 | other | 75.00 | 150.00 |
| openai/gpt-4o | chat | OpenAI: GPT-4o | openrouter | 128000 | 16384 | other | 2.50 | 10.00 |
| openai/gpt-4o-2024-05-13 | chat | OpenAI: GPT-4o (2024-05-13) | openrouter | 128000 | 4096 | other | 5.00 | 15.00 |
| openai/gpt-4o-2024-08-06 | chat | OpenAI: GPT-4o (2024-08-06) | openrouter | 128000 | 16384 | other | 2.50 | 10.00 |
| openai/gpt-4o-2024-11-20 | chat | OpenAI: GPT-4o (2024-11-20) | openrouter | 128000 | 16384 | other | 2.50 | 10.00 |
| openai/gpt-4o-mini | chat | OpenAI: GPT-4o-mini | openrouter | 128000 | 16384 | other | 0.15 | 0.60 |
| openai/gpt-4o-mini-2024-07-18 | chat | OpenAI: GPT-4o-mini (2024-07-18) | openrouter | 128000 | 16384 | other | 0.15 | 0.60 |
| openai/gpt-4o-mini-search-preview | chat | OpenAI: GPT-4o-mini Search Preview | openrouter | 128000 | 16384 | other | 0.15 | 0.60 |
| openai/gpt-4o-search-preview | chat | OpenAI: GPT-4o Search Preview | openrouter | 128000 | 16384 | other | 2.50 | 10.00 |
| openai/gpt-4o:extended | chat | OpenAI: GPT-4o (extended) | openrouter | 128000 | 64000 | other | 6.00 | 18.00 |
| openai/o1 | chat | OpenAI: o1 | openrouter | 200000 | 100000 | other | 15.00 | 60.00 |
| openai/o1-mini | chat | OpenAI: o1-mini | openrouter | 128000 | 65536 | other | 1.10 | 4.40 |
| openai/o1-mini-2024-09-12 | chat | OpenAI: o1-mini (2024-09-12) | openrouter | 128000 | 65536 | other | 1.10 | 4.40 |
| openai/o1-preview | chat | OpenAI: o1-preview | openrouter | 128000 | 32768 | other | 15.00 | 60.00 |
| openai/o1-preview-2024-09-12 | chat | OpenAI: o1-preview (2024-09-12) | openrouter | 128000 | 32768 | other | 15.00 | 60.00 |
| openai/o1-pro | chat | OpenAI: o1-pro | openrouter | 200000 | 100000 | other | 150.00 | 600.00 |
| openai/o3 | chat | OpenAI: o3 | openrouter | 200000 | 100000 | other | 10.00 | 40.00 |
| openai/o3-mini | chat | OpenAI: o3 Mini | openrouter | 200000 | 100000 | other | 1.10 | 4.40 |
| openai/o3-mini-high | chat | OpenAI: o3 Mini High | openrouter | 200000 | 100000 | other | 1.10 | 4.40 |
| openai/o4-mini | chat | OpenAI: o4 Mini | openrouter | 200000 | 100000 | other | 1.10 | 4.40 |
| openai/o4-mini-high | chat | OpenAI: o4 Mini High | openrouter | 200000 | 100000 | other | 1.10 | 4.40 |
| openchat/openchat-7b | chat | OpenChat 3.5 7B | openrouter | 8192 |  | other | 0.07 | 0.07 |
| openrouter/auto | chat | Auto Router | openrouter | 2000000 |  | other | -1000000.00 | -1000000.00 |
| perplexity/llama-3.1-sonar-large-128k-online | chat | Perplexity: Llama 3.1 Sonar 70B Online | openrouter | 127072 |  | other | 1.00 | 1.00 |
| perplexity/llama-3.1-sonar-small-128k-online | chat | Perplexity: Llama 3.1 Sonar 8B Online | openrouter | 127072 |  | other | 0.20 | 0.20 |
| perplexity/r1-1776 | chat | Perplexity: R1 1776 | openrouter | 128000 |  | other | 2.00 | 8.00 |
| perplexity/sonar | chat | Perplexity: Sonar | openrouter | 127072 |  | other | 1.00 | 1.00 |
| perplexity/sonar-deep-research | chat | Perplexity: Sonar Deep Research | openrouter | 128000 |  | other | 2.00 | 8.00 |
| perplexity/sonar-pro | chat | Perplexity: Sonar Pro | openrouter | 200000 | 8000 | other | 3.00 | 15.00 |
| perplexity/sonar-reasoning | chat | Perplexity: Sonar Reasoning | openrouter | 127000 |  | other | 1.00 | 5.00 |
| perplexity/sonar-reasoning-pro | chat | Perplexity: Sonar Reasoning Pro | openrouter | 128000 |  | other | 2.00 | 8.00 |
| pygmalionai/mythalion-13b | chat | Pygmalion: Mythalion 13B | openrouter | 8192 | 1024 | other | 0.56 | 1.12 |
| qwen/qwen-2-72b-instruct | chat | Qwen 2 72B Instruct | openrouter | 32768 | 4096 | other | 0.90 | 0.90 |
| qwen/qwen-2.5-72b-instruct | chat | Qwen2.5 72B Instruct | openrouter | 32768 | 16384 | other | 0.12 | 0.39 |
| qwen/qwen-2.5-72b-instruct:free | chat | Qwen2.5 72B Instruct (free) | openrouter | 32768 |  | other | 0.00 | 0.00 |
| qwen/qwen-2.5-7b-instruct | chat | Qwen2.5 7B Instruct | openrouter | 32768 | 16384 | other | 0.05 | 0.10 |
| qwen/qwen-2.5-7b-instruct:free | chat | Qwen2.5 7B Instruct (free) | openrouter | 32768 | 32768 | other | 0.00 | 0.00 |
| qwen/qwen-2.5-coder-32b-instruct | chat | Qwen2.5 Coder 32B Instruct | openrouter | 32768 | 16384 | other | 0.07 | 0.15 |
| qwen/qwen-2.5-coder-32b-instruct:free | chat | Qwen2.5 Coder 32B Instruct (free) | openrouter | 32768 |  | other | 0.00 | 0.00 |
| qwen/qwen-2.5-vl-72b-instruct | chat | Qwen: Qwen2.5-VL 72B Instruct | openrouter | 32768 |  | other | 0.60 | 0.60 |
| qwen/qwen-2.5-vl-7b-instruct | chat | Qwen: Qwen2.5-VL 7B Instruct | openrouter | 32768 |  | other | 0.20 | 0.20 |
| qwen/qwen-2.5-vl-7b-instruct:free | chat | Qwen: Qwen2.5-VL 7B Instruct (free) | openrouter | 64000 | 64000 | other | 0.00 | 0.00 |
| qwen/qwen-max | chat | Qwen: Qwen-Max  | openrouter | 32768 | 8192 | other | 1.60 | 6.40 |
| qwen/qwen-plus | chat | Qwen: Qwen-Plus | openrouter | 131072 | 8192 | other | 0.40 | 1.20 |
| qwen/qwen-turbo | chat | Qwen: Qwen-Turbo | openrouter | 1000000 | 8192 | other | 0.05 | 0.20 |
| qwen/qwen-vl-max | chat | Qwen: Qwen VL Max | openrouter | 7500 | 1500 | other | 0.80 | 3.20 |
| qwen/qwen-vl-plus | chat | Qwen: Qwen VL Plus | openrouter | 7500 | 1500 | other | 0.21 | 0.63 |
| qwen/qwen2.5-coder-7b-instruct | chat | Qwen: Qwen2.5 Coder 7B Instruct | openrouter | 32768 | 32768 | other | 0.20 | 0.20 |
| qwen/qwen2.5-vl-32b-instruct | chat | Qwen: Qwen2.5 VL 32B Instruct | openrouter | 128000 |  | other | 0.90 | 0.90 |
| qwen/qwen2.5-vl-32b-instruct:free | chat | Qwen: Qwen2.5 VL 32B Instruct (free) | openrouter | 8192 |  | other | 0.00 | 0.00 |
| qwen/qwen2.5-vl-3b-instruct:free | chat | Qwen: Qwen2.5 VL 3B Instruct (free) | openrouter | 64000 |  | other | 0.00 | 0.00 |
| qwen/qwen2.5-vl-72b-instruct | chat | Qwen: Qwen2.5 VL 72B Instruct | openrouter | 128000 | 128000 | other | 0.70 | 0.70 |
| qwen/qwen2.5-vl-72b-instruct:free | chat | Qwen: Qwen2.5 VL 72B Instruct (free) | openrouter | 131072 | 2048 | other | 0.00 | 0.00 |
| qwen/qwq-32b | chat | Qwen: QwQ 32B | openrouter | 131072 |  | other | 0.15 | 0.20 |
| qwen/qwq-32b-preview | chat | Qwen: QwQ 32B Preview | openrouter | 32768 |  | other | 0.20 | 0.20 |
| qwen/qwq-32b-preview:free | chat | Qwen: QwQ 32B Preview (free) | openrouter | 16384 |  | other | 0.00 | 0.00 |
| qwen/qwq-32b:free | chat | Qwen: QwQ 32B (free) | openrouter | 40000 | 40000 | other | 0.00 | 0.00 |
| raifle/sorcererlm-8x22b | chat | SorcererLM 8x22B | openrouter | 16000 |  | other | 4.50 | 4.50 |
| rekaai/reka-flash-3:free | chat | Reka: Flash 3 (free) | openrouter | 32768 |  | other | 0.00 | 0.00 |
| sao10k/fimbulvetr-11b-v2 | chat | Fimbulvetr 11B v2 | openrouter | 4096 | 4096 | other | 0.80 | 1.20 |
| sao10k/l3-euryale-70b | chat | Sao10k: Llama 3 Euryale 70B v2.1 | openrouter | 8192 | 8192 | other | 1.48 | 1.48 |
| sao10k/l3-lunaris-8b | chat | Sao10K: Llama 3 8B Lunaris | openrouter | 8192 |  | other | 0.02 | 0.05 |
| sao10k/l3.1-euryale-70b | chat | Sao10K: Llama 3.1 Euryale 70B v2.2 | openrouter | 131072 | 16384 | other | 0.70 | 0.80 |
| sao10k/l3.3-euryale-70b | chat | Sao10K: Llama 3.3 Euryale 70B | openrouter | 131072 | 16384 | other | 0.70 | 0.80 |
| scb10x/llama3.1-typhoon2-70b-instruct | chat | Typhoon2 70B Instruct | openrouter | 8192 |  | other | 0.88 | 0.88 |
| scb10x/llama3.1-typhoon2-8b-instruct | chat | Typhoon2 8B Instruct | openrouter | 8192 |  | other | 0.18 | 0.18 |
| shisa-ai/shisa-v2-llama3.3-70b:free | chat | Shisa AI: Shisa V2 Llama 3.3 70B  (free) | openrouter | 32768 |  | other | 0.00 | 0.00 |
| sophosympatheia/midnight-rose-70b | chat | Midnight Rose 70B | openrouter | 4096 |  | other | 0.80 | 0.80 |
| sophosympatheia/rogue-rose-103b-v0.2:free | chat | Rogue Rose 103B v0.2 (free) | openrouter | 4096 |  | other | 0.00 | 0.00 |
| steelskull/l3.3-electra-r1-70b | chat | SteelSkull: L3.3 Electra R1 70B | openrouter | 131072 | 131072 | other | 0.70 | 0.95 |
| thedrummer/anubis-pro-105b-v1 | chat | TheDrummer: Anubis Pro 105B V1 | openrouter | 131072 | 131072 | other | 0.80 | 1.00 |
| thedrummer/rocinante-12b | chat | Rocinante 12B | openrouter | 32768 |  | other | 0.25 | 0.50 |
| thedrummer/skyfall-36b-v2 | chat | TheDrummer: Skyfall 36B V2 | openrouter | 32768 | 32768 | other | 0.50 | 0.80 |
| thedrummer/unslopnemo-12b | chat | Unslopnemo 12B | openrouter | 32000 |  | other | 0.50 | 0.50 |
| thudm/glm-4-32b | chat | THUDM: GLM 4 32B | openrouter | 32000 |  | other | 0.24 | 0.24 |
| thudm/glm-4-32b:free | chat | THUDM: GLM 4 32B (free) | openrouter | 32768 |  | other | 0.00 | 0.00 |
| thudm/glm-z1-32b | chat | THUDM: GLM Z1 32B | openrouter | 32000 |  | other | 0.24 | 0.24 |
| thudm/glm-z1-32b:free | chat | THUDM: GLM Z1 32B (free) | openrouter | 32768 |  | other | 0.00 | 0.00 |
| undi95/remm-slerp-l2-13b | chat | ReMM SLERP 13B | openrouter | 6144 | 1024 | other | 0.56 | 1.12 |
| undi95/toppy-m-7b | chat | Toppy M 7B | openrouter | 4096 |  | other | 0.07 | 0.07 |
| x-ai/grok-2-1212 | chat | xAI: Grok 2 1212 | openrouter | 131072 |  | other | 2.00 | 10.00 |
| x-ai/grok-2-vision-1212 | chat | xAI: Grok 2 Vision 1212 | openrouter | 32768 |  | other | 2.00 | 10.00 |
| x-ai/grok-3-beta | chat | xAI: Grok 3 Beta | openrouter | 131072 |  | other | 3.00 | 15.00 |
| x-ai/grok-3-mini-beta | chat | xAI: Grok 3 Mini Beta | openrouter | 131072 |  | other | 0.30 | 0.50 |
| x-ai/grok-beta | chat | xAI: Grok Beta | openrouter | 131072 |  | other | 5.00 | 15.00 |
| x-ai/grok-vision-beta | chat | xAI: Grok Vision Beta | openrouter | 8192 |  | other | 5.00 | 15.00 |

