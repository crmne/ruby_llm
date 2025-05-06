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

Last updated: 2025-05-06
{: .label .label-green }

### Chat Models (0)

| ID | Type | Name | Provider | Context | MaxTok | Family | In$/M | Out$/M |
| :-- | :-- | :-- | :-- | --: | --: | :-- | --: | --: |

### Image Models (0)

| ID | Type | Name | Provider | Context | MaxTok | Family | In$/M | Out$/M |
| :-- | :-- | :-- | :-- | --: | --: | :-- | --: | --: |

### Audio Models (0)

| ID | Type | Name | Provider | Context | MaxTok | Family | In$/M | Out$/M |
| :-- | :-- | :-- | :-- | --: | --: | :-- | --: | --: |

### Embedding Models (0)

| ID | Type | Name | Provider | Context | MaxTok | Family | In$/M | Out$/M |
| :-- | :-- | :-- | :-- | --: | --: | :-- | --: | --: |

### Moderation Models (0)

| ID | Type | Name | Provider | Context | MaxTok | Family | In$/M | Out$/M |
| :-- | :-- | :-- | :-- | --: | --: | :-- | --: | --: |

## Models by Provider

### Openai Models (74)

  | ID | Type | Name | Provider | Context | MaxTok | Family | In$/M | Out$/M |
| :-- | :-- | :-- | :-- | --: | --: | :-- | --: | --: |
| babbage-002 |  |  | openai |  |  |  |  |  |
| chatgpt-4o-latest |  |  | openai |  |  |  |  |  |
| computer-use-preview |  | computer-use-preview | openai | 8192 |  |  |  |  |
| dall-e-2 |  |  | openai |  |  |  |  |  |
| dall-e-3 |  |  | openai |  |  |  |  |  |
| davinci-002 |  |  | openai |  |  |  |  |  |
| gpt-3.5-turbo |  |  | openai |  |  |  |  |  |
| gpt-3.5-turbo-0125 |  |  | openai |  |  |  |  |  |
| gpt-3.5-turbo-1106 |  |  | openai |  |  |  |  |  |
| gpt-3.5-turbo-16k |  |  | openai |  |  |  |  |  |
| gpt-3.5-turbo-instruct |  |  | openai |  |  |  |  |  |
| gpt-3.5-turbo-instruct-0914 |  |  | openai |  |  |  |  |  |
| gpt-4 |  |  | openai |  |  |  |  |  |
| gpt-4-0125-preview |  |  | openai |  |  |  |  |  |
| gpt-4-0613 |  |  | openai |  |  |  |  |  |
| gpt-4-1106-preview |  |  | openai |  |  |  |  |  |
| gpt-4-turbo |  |  | openai |  |  |  |  |  |
| gpt-4-turbo-2024-04-09 |  |  | openai |  |  |  |  |  |
| gpt-4-turbo-preview |  |  | openai |  |  |  |  |  |
| gpt-4.1 |  |  | openai |  |  |  |  |  |
| gpt-4.1-2025-04-14 |  |  | openai |  |  |  |  |  |
| gpt-4.1-mini |  |  | openai |  |  |  |  |  |
| gpt-4.1-mini-2025-04-14 |  |  | openai |  |  |  |  |  |
| gpt-4.1-nano |  |  | openai |  |  |  |  |  |
| gpt-4.1-nano-2025-04-14 |  |  | openai |  |  |  |  |  |
| gpt-4.5-preview |  |  | openai |  |  |  |  |  |
| gpt-4.5-preview-2025-02-27 |  |  | openai |  |  |  |  |  |
| gpt-4o |  |  | openai |  |  |  |  |  |
| gpt-4o-2024-05-13 |  |  | openai |  |  |  |  |  |
| gpt-4o-2024-08-06 |  |  | openai |  |  |  |  |  |
| gpt-4o-2024-11-20 |  |  | openai |  |  |  |  |  |
| gpt-4o-audio-preview |  |  | openai |  |  |  |  |  |
| gpt-4o-audio-preview-2024-10-01 |  |  | openai |  |  |  |  |  |
| gpt-4o-audio-preview-2024-12-17 |  |  | openai |  |  |  |  |  |
| gpt-4o-mini |  |  | openai |  |  |  |  |  |
| gpt-4o-mini-2024-07-18 |  |  | openai |  |  |  |  |  |
| gpt-4o-mini-audio-preview |  |  | openai |  |  |  |  |  |
| gpt-4o-mini-audio-preview-2024-12-17 |  |  | openai |  |  |  |  |  |
| gpt-4o-mini-realtime-preview |  |  | openai |  |  |  |  |  |
| gpt-4o-mini-realtime-preview-2024-12-17 |  |  | openai |  |  |  |  |  |
| gpt-4o-mini-search-preview |  |  | openai |  |  |  |  |  |
| gpt-4o-mini-search-preview-2025-03-11 |  |  | openai |  |  |  |  |  |
| gpt-4o-mini-transcribe |  |  | openai |  |  |  |  |  |
| gpt-4o-mini-tts |  |  | openai |  |  |  |  |  |
| gpt-4o-realtime-preview |  |  | openai |  |  |  |  |  |
| gpt-4o-realtime-preview-2024-10-01 |  |  | openai |  |  |  |  |  |
| gpt-4o-realtime-preview-2024-12-17 |  |  | openai |  |  |  |  |  |
| gpt-4o-search-preview |  |  | openai |  |  |  |  |  |
| gpt-4o-search-preview-2025-03-11 |  |  | openai |  |  |  |  |  |
| gpt-4o-transcribe |  |  | openai |  |  |  |  |  |
| o1 |  |  | openai |  |  |  |  |  |
| o1-2024-12-17 |  |  | openai |  |  |  |  |  |
| o1-mini |  |  | openai |  |  |  |  |  |
| o1-mini-2024-09-12 |  |  | openai |  |  |  |  |  |
| o1-preview |  |  | openai |  |  |  |  |  |
| o1-preview-2024-09-12 |  |  | openai |  |  |  |  |  |
| o1-pro |  |  | openai |  |  |  |  |  |
| o1-pro-2025-03-19 |  |  | openai |  |  |  |  |  |
| o3 |  | o3 | openai | 200000 |  |  |  |  |
| o3-mini |  |  | openai |  |  |  |  |  |
| o3-mini-2025-01-31 |  |  | openai |  |  |  |  |  |
| o4-mini |  |  | openai |  |  |  |  |  |
| o4-mini-2025-04-16 |  |  | openai |  |  |  |  |  |
| omni-moderation-2024-09-26 |  |  | openai |  |  |  |  |  |
| omni-moderation-latest |  |  | openai |  |  |  |  |  |
| text-embedding-3-large |  |  | openai |  |  |  |  |  |
| text-embedding-3-small |  |  | openai |  |  |  |  |  |
| text-embedding-ada-002 |  |  | openai |  |  |  |  |  |
| text-moderation-latest |  | text-moderation | openai |  |  |  |  |  |
| tts-1 |  |  | openai |  |  |  |  |  |
| tts-1-1106 |  |  | openai |  |  |  |  |  |
| tts-1-hd |  |  | openai |  |  |  |  |  |
| tts-1-hd-1106 |  |  | openai |  |  |  |  |  |
| whisper-1 |  |  | openai |  |  |  |  |  |

### Anthropic Models (9)

  | ID | Type | Name | Provider | Context | MaxTok | Family | In$/M | Out$/M |
| :-- | :-- | :-- | :-- | --: | --: | :-- | --: | --: |
| claude-2.0 |  | Claude 2.0 | anthropic |  |  |  |  |  |
| claude-2.1 |  | Claude 2.1 | anthropic |  |  |  |  |  |
| claude-3-5-haiku-20241022 |  | Claude 3.5 Haiku | anthropic |  |  |  |  |  |
| claude-3-5-sonnet-20240620 |  | Claude 3.5 Sonnet (Old) | anthropic |  |  |  |  |  |
| claude-3-5-sonnet-20241022 |  | Claude 3.5 Sonnet (New) | anthropic |  |  |  |  |  |
| claude-3-7-sonnet-20250219 |  | Claude 3.7 Sonnet | anthropic |  |  |  |  |  |
| claude-3-haiku-20240307 |  | Claude 3 Haiku | anthropic |  |  |  |  |  |
| claude-3-opus-20240229 |  | Claude 3 Opus | anthropic |  |  |  |  |  |
| claude-3-sonnet-20240229 |  | Claude 3 Sonnet | anthropic |  |  |  |  |  |

### Gemini Models (55)

  | ID | Type | Name | Provider | Context | MaxTok | Family | In$/M | Out$/M |
| :-- | :-- | :-- | :-- | --: | --: | :-- | --: | --: |
| aqa |  | Model that performs Attributed Question Answering. | gemini |  |  |  |  |  |
| chat-bison-001 |  | PaLM 2 Chat (Legacy) | gemini |  |  |  |  |  |
| embedding-001 |  | Embedding 001 | gemini |  |  |  |  |  |
| embedding-gecko-001 |  | Embedding Gecko | gemini |  |  |  |  |  |
| gemini-1.0-pro-vision-latest |  | Gemini 1.0 Pro Vision | gemini |  |  |  |  |  |
| gemini-1.5-flash |  | Gemini 1.5 Flash | gemini |  |  |  |  |  |
| gemini-1.5-flash-001 |  | Gemini 1.5 Flash 001 | gemini |  |  |  |  |  |
| gemini-1.5-flash-001-tuning |  | Gemini 1.5 Flash 001 Tuning | gemini |  |  |  |  |  |
| gemini-1.5-flash-002 |  | Gemini 1.5 Flash 002 | gemini |  |  |  |  |  |
| gemini-1.5-flash-8b |  | Gemini 1.5 Flash-8B | gemini |  |  |  |  |  |
| gemini-1.5-flash-8b-001 |  | Gemini 1.5 Flash-8B 001 | gemini |  |  |  |  |  |
| gemini-1.5-flash-8b-exp-0827 |  | Gemini 1.5 Flash 8B Experimental 0827 | gemini |  |  |  |  |  |
| gemini-1.5-flash-8b-exp-0924 |  | Gemini 1.5 Flash 8B Experimental 0924 | gemini |  |  |  |  |  |
| gemini-1.5-flash-8b-latest |  | Gemini 1.5 Flash-8B Latest | gemini |  |  |  |  |  |
| gemini-1.5-flash-latest |  | Gemini 1.5 Flash Latest | gemini |  |  |  |  |  |
| gemini-1.5-pro |  | Gemini 1.5 Pro | gemini |  |  |  |  |  |
| gemini-1.5-pro-001 |  | Gemini 1.5 Pro 001 | gemini |  |  |  |  |  |
| gemini-1.5-pro-002 |  | Gemini 1.5 Pro 002 | gemini |  |  |  |  |  |
| gemini-1.5-pro-latest |  | Gemini 1.5 Pro Latest | gemini |  |  |  |  |  |
| gemini-2.0-flash |  | Gemini 2.0 Flash | gemini |  |  |  |  |  |
| gemini-2.0-flash-001 |  | Gemini 2.0 Flash 001 | gemini |  |  |  |  |  |
| gemini-2.0-flash-exp |  | Gemini 2.0 Flash Experimental | gemini |  |  |  |  |  |
| gemini-2.0-flash-lite |  | Gemini 2.0 Flash-Lite | gemini |  |  |  |  |  |
| gemini-2.0-flash-lite-001 |  | Gemini 2.0 Flash-Lite 001 | gemini |  |  |  |  |  |
| gemini-2.0-flash-lite-preview |  | Gemini 2.0 Flash-Lite Preview | gemini |  |  |  |  |  |
| gemini-2.0-flash-lite-preview-02-05 |  | Gemini 2.0 Flash-Lite Preview 02-05 | gemini |  |  |  |  |  |
| gemini-2.0-flash-live-001 |  | Gemini 2.0 Flash 001 | gemini |  |  |  |  |  |
| gemini-2.0-flash-thinking-exp |  | Gemini 2.0 Flash Thinking Experimental 01-21 | gemini |  |  |  |  |  |
| gemini-2.0-flash-thinking-exp-01-21 |  | Gemini 2.0 Flash Thinking Experimental 01-21 | gemini |  |  |  |  |  |
| gemini-2.0-flash-thinking-exp-1219 |  | Gemini 2.0 Flash Thinking Experimental | gemini |  |  |  |  |  |
| gemini-2.0-pro-exp |  | Gemini 2.0 Pro Experimental | gemini |  |  |  |  |  |
| gemini-2.0-pro-exp-02-05 |  | Gemini 2.0 Pro Experimental 02-05 | gemini |  |  |  |  |  |
| gemini-2.5-flash-preview-04-17 |  | Gemini 2.5 Flash Preview 04-17 | gemini |  |  |  |  |  |
| gemini-2.5-pro-exp-03-25 |  | Gemini 2.5 Pro Experimental 03-25 | gemini |  |  |  |  |  |
| gemini-2.5-pro-preview-03-25 |  | Gemini 2.5 Pro Preview 03-25 | gemini |  |  |  |  |  |
| gemini-embedding-exp |  | Gemini Embedding Experimental | gemini |  |  |  |  |  |
| gemini-embedding-exp-03-07 |  | Gemini Embedding Experimental 03-07 | gemini |  |  |  |  |  |
| gemini-exp-1206 |  | Gemini Experimental 1206 | gemini |  |  |  |  |  |
| gemini-pro-vision |  | Gemini 1.0 Pro Vision | gemini |  |  |  |  |  |
| gemma-3 |  | Gemma 3 | gemini |  |  |  |  |  |
| gemma-3-12b-it |  | Gemma 3 12B | gemini |  |  |  |  |  |
| gemma-3-1b-it |  | Gemma 3 1B | gemini |  |  |  |  |  |
| gemma-3-27b-it |  | Gemma 3 27B | gemini |  |  |  |  |  |
| gemma-3-4b-it |  | Gemma 3 4B | gemini |  |  |  |  |  |
| imagen-3.0-generate-002 |  | Imagen 3.0 002 model | gemini |  |  |  |  |  |
| learnlm-1.5-pro-experimental |  | LearnLM 1.5 Pro Experimental | gemini |  |  |  |  |  |
| learnlm-2.0-flash-experimental |  | LearnLM 2.0 Flash Experimental | gemini |  |  |  |  |  |
| models/gemini-1.5-flash |  | Gemini 1.5 Flash | gemini | 1048576 |  |  |  |  |
| models/gemini-1.5-flash-8b |  | Gemini 1.5 Flash-8B | gemini | 1048576 |  |  |  |  |
| models/gemini-1.5-pro |  | Gemini 1.5 Pro | gemini | 2097152 |  |  |  |  |
| models/gemini-2.0-flash |  | Gemini 2.0 Flash | gemini | 1048576 |  |  |  |  |
| models/gemini-2.0-flash-lite |  | Gemini 2.0 Flash-Lite | gemini | 1048576 |  |  |  |  |
| text-bison-001 |  | PaLM 2 (Legacy) | gemini |  |  |  |  |  |
| text-embedding-004 |  | Text Embedding 004 | gemini |  |  |  |  |  |
| veo-2.0-generate-001 |  | Veo 2 | gemini |  |  |  |  |  |

### Deepseek Models (2)

  | ID | Type | Name | Provider | Context | MaxTok | Family | In$/M | Out$/M |
| :-- | :-- | :-- | :-- | --: | --: | :-- | --: | --: |
| deepseek-chat |  |  | deepseek |  |  |  |  |  |
| deepseek-reasoner |  |  | deepseek |  |  |  |  |  |

### Bedrock Models (28)

  | ID | Type | Name | Provider | Context | MaxTok | Family | In$/M | Out$/M |
| :-- | :-- | :-- | :-- | --: | --: | :-- | --: | --: |
| anthropic.claude-3-5-haiku-20241022-v1:0 |  | Claude 3.5 Haiku | bedrock |  |  |  |  |  |
| anthropic.claude-3-5-sonnet-20240620-v1:0 |  | Claude 3.5 Sonnet | bedrock |  |  |  |  |  |
| anthropic.claude-3-5-sonnet-20240620-v1:0:18k |  | Claude 3.5 Sonnet | bedrock |  |  |  |  |  |
| anthropic.claude-3-5-sonnet-20240620-v1:0:200k |  | Claude 3.5 Sonnet | bedrock |  |  |  |  |  |
| anthropic.claude-3-5-sonnet-20240620-v1:0:51k |  | Claude 3.5 Sonnet | bedrock |  |  |  |  |  |
| anthropic.claude-3-5-sonnet-20241022-v2:0 |  | Claude 3.5 Sonnet v2 | bedrock |  |  |  |  |  |
| anthropic.claude-3-5-sonnet-20241022-v2:0:18k |  | Claude 3.5 Sonnet v2 | bedrock |  |  |  |  |  |
| anthropic.claude-3-5-sonnet-20241022-v2:0:200k |  | Claude 3.5 Sonnet v2 | bedrock |  |  |  |  |  |
| anthropic.claude-3-5-sonnet-20241022-v2:0:51k |  | Claude 3.5 Sonnet v2 | bedrock |  |  |  |  |  |
| anthropic.claude-3-7-sonnet-20250219-v1:0 |  | Claude 3.7 Sonnet | bedrock |  |  |  |  |  |
| anthropic.claude-3-haiku-20240307-v1:0 |  | Claude 3 Haiku | bedrock |  |  |  |  |  |
| anthropic.claude-3-haiku-20240307-v1:0:200k |  | Claude 3 Haiku | bedrock |  |  |  |  |  |
| anthropic.claude-3-haiku-20240307-v1:0:48k |  | Claude 3 Haiku | bedrock |  |  |  |  |  |
| anthropic.claude-3-opus-20240229-v1:0 |  | Claude 3 Opus | bedrock |  |  |  |  |  |
| anthropic.claude-3-opus-20240229-v1:0:12k |  | Claude 3 Opus | bedrock |  |  |  |  |  |
| anthropic.claude-3-opus-20240229-v1:0:200k |  | Claude 3 Opus | bedrock |  |  |  |  |  |
| anthropic.claude-3-opus-20240229-v1:0:28k |  | Claude 3 Opus | bedrock |  |  |  |  |  |
| anthropic.claude-3-sonnet-20240229-v1:0 |  | Claude 3 Sonnet | bedrock |  |  |  |  |  |
| anthropic.claude-3-sonnet-20240229-v1:0:200k |  | Claude 3 Sonnet | bedrock |  |  |  |  |  |
| anthropic.claude-3-sonnet-20240229-v1:0:28k |  | Claude 3 Sonnet | bedrock |  |  |  |  |  |
| anthropic.claude-instant-v1 |  | Claude Instant | bedrock |  |  |  |  |  |
| anthropic.claude-instant-v1:2:100k |  | Claude Instant | bedrock |  |  |  |  |  |
| anthropic.claude-v2 |  | Claude | bedrock |  |  |  |  |  |
| anthropic.claude-v2:0:100k |  | Claude | bedrock |  |  |  |  |  |
| anthropic.claude-v2:0:18k |  | Claude | bedrock |  |  |  |  |  |
| anthropic.claude-v2:1 |  | Claude | bedrock |  |  |  |  |  |
| anthropic.claude-v2:1:18k |  | Claude | bedrock |  |  |  |  |  |
| anthropic.claude-v2:1:200k |  | Claude | bedrock |  |  |  |  |  |

### Openrouter Models (325)

  | ID | Type | Name | Provider | Context | MaxTok | Family | In$/M | Out$/M |
| :-- | :-- | :-- | :-- | --: | --: | :-- | --: | --: |
| 01-ai/yi-large |  | 01.AI: Yi Large | openrouter | 32768 |  |  |  |  |
| aetherwiing/mn-starcannon-12b |  | Aetherwiing: Starcannon 12B | openrouter | 16384 |  |  |  |  |
| agentica-org/deepcoder-14b-preview:free |  | Agentica: Deepcoder 14B Preview (free) | openrouter | 96000 |  |  |  |  |
| ai21/jamba-1-5-large |  | AI21: Jamba 1.5 Large | openrouter | 256000 |  |  |  |  |
| ai21/jamba-1-5-mini |  | AI21: Jamba 1.5 Mini | openrouter | 256000 |  |  |  |  |
| ai21/jamba-1.6-large |  | AI21: Jamba 1.6 Large | openrouter | 256000 |  |  |  |  |
| ai21/jamba-1.6-mini |  | AI21: Jamba Mini 1.6 | openrouter | 256000 |  |  |  |  |
| ai21/jamba-instruct |  | AI21: Jamba Instruct | openrouter | 256000 |  |  |  |  |
| aion-labs/aion-1.0 |  | AionLabs: Aion-1.0 | openrouter | 131072 |  |  |  |  |
| aion-labs/aion-1.0-mini |  | AionLabs: Aion-1.0-Mini | openrouter | 131072 |  |  |  |  |
| aion-labs/aion-rp-llama-3.1-8b |  | AionLabs: Aion-RP 1.0 (8B) | openrouter | 32768 |  |  |  |  |
| alfredpros/codellama-7b-instruct-solidity |  | AlfredPros: CodeLLaMa 7B Instruct Solidity | openrouter | 4096 |  |  |  |  |
| all-hands/openhands-lm-32b-v0.1 |  | OpenHands LM 32B V0.1 | openrouter | 16384 |  |  |  |  |
| allenai/molmo-7b-d:free |  | AllenAI: Molmo 7B D (free) | openrouter | 4096 |  |  |  |  |
| alpindale/goliath-120b |  | Goliath 120B | openrouter | 6144 |  |  |  |  |
| alpindale/magnum-72b |  | Magnum 72B | openrouter | 16384 |  |  |  |  |
| amazon/nova-lite-v1 |  | Amazon: Nova Lite 1.0 | openrouter | 300000 |  |  |  |  |
| amazon/nova-micro-v1 |  | Amazon: Nova Micro 1.0 | openrouter | 128000 |  |  |  |  |
| amazon/nova-pro-v1 |  | Amazon: Nova Pro 1.0 | openrouter | 300000 |  |  |  |  |
| anthracite-org/magnum-v2-72b |  | Magnum v2 72B | openrouter | 32768 |  |  |  |  |
| anthracite-org/magnum-v4-72b |  | Magnum v4 72B | openrouter | 16384 |  |  |  |  |
| anthropic/claude-2 |  | Anthropic: Claude v2 | openrouter | 200000 |  |  |  |  |
| anthropic/claude-2.0 |  | Anthropic: Claude v2.0 | openrouter | 100000 |  |  |  |  |
| anthropic/claude-2.0:beta |  | Anthropic: Claude v2.0 (self-moderated) | openrouter | 100000 |  |  |  |  |
| anthropic/claude-2.1 |  | Anthropic: Claude v2.1 | openrouter | 200000 |  |  |  |  |
| anthropic/claude-2.1:beta |  | Anthropic: Claude v2.1 (self-moderated) | openrouter | 200000 |  |  |  |  |
| anthropic/claude-2:beta |  | Anthropic: Claude v2 (self-moderated) | openrouter | 200000 |  |  |  |  |
| anthropic/claude-3-haiku |  | Anthropic: Claude 3 Haiku | openrouter | 200000 |  |  |  |  |
| anthropic/claude-3-haiku:beta |  | Anthropic: Claude 3 Haiku (self-moderated) | openrouter | 200000 |  |  |  |  |
| anthropic/claude-3-opus |  | Anthropic: Claude 3 Opus | openrouter | 200000 |  |  |  |  |
| anthropic/claude-3-opus:beta |  | Anthropic: Claude 3 Opus (self-moderated) | openrouter | 200000 |  |  |  |  |
| anthropic/claude-3-sonnet |  | Anthropic: Claude 3 Sonnet | openrouter | 200000 |  |  |  |  |
| anthropic/claude-3-sonnet:beta |  | Anthropic: Claude 3 Sonnet (self-moderated) | openrouter | 200000 |  |  |  |  |
| anthropic/claude-3.5-haiku |  | Anthropic: Claude 3.5 Haiku | openrouter | 200000 |  |  |  |  |
| anthropic/claude-3.5-haiku-20241022 |  | Anthropic: Claude 3.5 Haiku (2024-10-22) | openrouter | 200000 |  |  |  |  |
| anthropic/claude-3.5-haiku-20241022:beta |  | Anthropic: Claude 3.5 Haiku (2024-10-22) (self-moderated) | openrouter | 200000 |  |  |  |  |
| anthropic/claude-3.5-haiku:beta |  | Anthropic: Claude 3.5 Haiku (self-moderated) | openrouter | 200000 |  |  |  |  |
| anthropic/claude-3.5-sonnet |  | Anthropic: Claude 3.5 Sonnet | openrouter | 200000 |  |  |  |  |
| anthropic/claude-3.5-sonnet-20240620 |  | Anthropic: Claude 3.5 Sonnet (2024-06-20) | openrouter | 200000 |  |  |  |  |
| anthropic/claude-3.5-sonnet-20240620:beta |  | Anthropic: Claude 3.5 Sonnet (2024-06-20) (self-moderated) | openrouter | 200000 |  |  |  |  |
| anthropic/claude-3.5-sonnet:beta |  | Anthropic: Claude 3.5 Sonnet (self-moderated) | openrouter | 200000 |  |  |  |  |
| anthropic/claude-3.7-sonnet |  | Anthropic: Claude 3.7 Sonnet | openrouter | 200000 |  |  |  |  |
| anthropic/claude-3.7-sonnet:beta |  | Anthropic: Claude 3.7 Sonnet (self-moderated) | openrouter | 200000 |  |  |  |  |
| anthropic/claude-3.7-sonnet:thinking |  | Anthropic: Claude 3.7 Sonnet (thinking) | openrouter | 200000 |  |  |  |  |
| arliai/qwq-32b-arliai-rpr-v1:free |  | ArliAI: QwQ 32B RpR v1 (free) | openrouter | 32768 |  |  |  |  |
| bytedance-research/ui-tars-72b:free |  | Bytedance: UI-TARS 72B  (free) | openrouter | 32768 |  |  |  |  |
| cognitivecomputations/dolphin-mixtral-8x22b |  | Dolphin 2.9.2 Mixtral 8x22B 🐬 | openrouter | 16000 |  |  |  |  |
| cognitivecomputations/dolphin-mixtral-8x7b |  | Dolphin 2.6 Mixtral 8x7B 🐬 | openrouter | 32768 |  |  |  |  |
| cognitivecomputations/dolphin3.0-mistral-24b:free |  | Dolphin3.0 Mistral 24B (free) | openrouter | 32768 |  |  |  |  |
| cognitivecomputations/dolphin3.0-r1-mistral-24b:free |  | Dolphin3.0 R1 Mistral 24B (free) | openrouter | 32768 |  |  |  |  |
| cohere/command |  | Cohere: Command | openrouter | 4096 |  |  |  |  |
| cohere/command-a |  | Cohere: Command A | openrouter | 256000 |  |  |  |  |
| cohere/command-r |  | Cohere: Command R | openrouter | 128000 |  |  |  |  |
| cohere/command-r-03-2024 |  | Cohere: Command R (03-2024) | openrouter | 128000 |  |  |  |  |
| cohere/command-r-08-2024 |  | Cohere: Command R (08-2024) | openrouter | 128000 |  |  |  |  |
| cohere/command-r-plus |  | Cohere: Command R+ | openrouter | 128000 |  |  |  |  |
| cohere/command-r-plus-04-2024 |  | Cohere: Command R+ (04-2024) | openrouter | 128000 |  |  |  |  |
| cohere/command-r-plus-08-2024 |  | Cohere: Command R+ (08-2024) | openrouter | 128000 |  |  |  |  |
| cohere/command-r7b-12-2024 |  | Cohere: Command R7B (12-2024) | openrouter | 128000 |  |  |  |  |
| deepseek/deepseek-chat |  | DeepSeek: DeepSeek V3 | openrouter | 163840 |  |  |  |  |
| deepseek/deepseek-chat-v3-0324 |  | DeepSeek: DeepSeek V3 0324 | openrouter | 64000 |  |  |  |  |
| deepseek/deepseek-chat-v3-0324:free |  | DeepSeek: DeepSeek V3 0324 (free) | openrouter | 163840 |  |  |  |  |
| deepseek/deepseek-chat:free |  | DeepSeek: DeepSeek V3 (free) | openrouter | 163840 |  |  |  |  |
| deepseek/deepseek-r1 |  | DeepSeek: R1 | openrouter | 163840 |  |  |  |  |
| deepseek/deepseek-r1-distill-llama-70b |  | DeepSeek: R1 Distill Llama 70B | openrouter | 131072 |  |  |  |  |
| deepseek/deepseek-r1-distill-llama-70b:free |  | DeepSeek: R1 Distill Llama 70B (free) | openrouter | 128000 |  |  |  |  |
| deepseek/deepseek-r1-distill-llama-8b |  | DeepSeek: R1 Distill Llama 8B | openrouter | 32000 |  |  |  |  |
| deepseek/deepseek-r1-distill-qwen-1.5b |  | DeepSeek: R1 Distill Qwen 1.5B | openrouter | 131072 |  |  |  |  |
| deepseek/deepseek-r1-distill-qwen-14b |  | DeepSeek: R1 Distill Qwen 14B | openrouter | 64000 |  |  |  |  |
| deepseek/deepseek-r1-distill-qwen-14b:free |  | DeepSeek: R1 Distill Qwen 14B (free) | openrouter | 64000 |  |  |  |  |
| deepseek/deepseek-r1-distill-qwen-32b |  | DeepSeek: R1 Distill Qwen 32B | openrouter | 131072 |  |  |  |  |
| deepseek/deepseek-r1-distill-qwen-32b:free |  | DeepSeek: R1 Distill Qwen 32B (free) | openrouter | 16000 |  |  |  |  |
| deepseek/deepseek-r1-zero:free |  | DeepSeek: DeepSeek R1 Zero (free) | openrouter | 163840 |  |  |  |  |
| deepseek/deepseek-r1:free |  | DeepSeek: R1 (free) | openrouter | 163840 |  |  |  |  |
| deepseek/deepseek-v3-base:free |  | DeepSeek: DeepSeek V3 Base (free) | openrouter | 163840 |  |  |  |  |
| eleutherai/llemma_7b |  | EleutherAI: Llemma 7b | openrouter | 4096 |  |  |  |  |
| eva-unit-01/eva-llama-3.33-70b |  | EVA Llama 3.33 70B | openrouter | 16384 |  |  |  |  |
| eva-unit-01/eva-qwen-2.5-32b |  | EVA Qwen2.5 32B | openrouter | 16384 |  |  |  |  |
| eva-unit-01/eva-qwen-2.5-72b |  | EVA Qwen2.5 72B | openrouter | 131072 |  |  |  |  |
| featherless/qwerky-72b:free |  | Qwerky 72B (free) | openrouter | 32768 |  |  |  |  |
| google/gemini-2.0-flash-001 |  | Google: Gemini 2.0 Flash | openrouter | 1000000 |  |  |  |  |
| google/gemini-2.0-flash-exp:free |  | Google: Gemini 2.0 Flash Experimental (free) | openrouter | 1048576 |  |  |  |  |
| google/gemini-2.0-flash-lite-001 |  | Google: Gemini 2.0 Flash Lite | openrouter | 1048576 |  |  |  |  |
| google/gemini-2.0-flash-thinking-exp-1219:free |  | Google: Gemini 2.0 Flash Thinking Experimental (free) | openrouter | 40000 |  |  |  |  |
| google/gemini-2.0-flash-thinking-exp:free |  | Google: Gemini 2.0 Flash Thinking Experimental 01-21 (free) | openrouter | 1048576 |  |  |  |  |
| google/gemini-2.5-flash-preview |  | Google: Gemini 2.5 Flash Preview | openrouter | 1048576 |  |  |  |  |
| google/gemini-2.5-flash-preview:thinking |  | Google: Gemini 2.5 Flash Preview (thinking) | openrouter | 1048576 |  |  |  |  |
| google/gemini-2.5-pro-exp-03-25:free |  | Google: Gemini 2.5 Pro Experimental (free) | openrouter | 1000000 |  |  |  |  |
| google/gemini-2.5-pro-preview-03-25 |  | Google: Gemini 2.5 Pro Preview | openrouter | 1048576 |  |  |  |  |
| google/gemini-flash-1.5 |  | Google: Gemini 1.5 Flash  | openrouter | 1000000 |  |  |  |  |
| google/gemini-flash-1.5-8b |  | Google: Gemini 1.5 Flash 8B | openrouter | 1000000 |  |  |  |  |
| google/gemini-flash-1.5-8b-exp |  | Google: Gemini 1.5 Flash 8B Experimental | openrouter | 1000000 |  |  |  |  |
| google/gemini-pro |  | Google: Gemini Pro 1.0 | openrouter | 32760 |  |  |  |  |
| google/gemini-pro-1.5 |  | Google: Gemini 1.5 Pro | openrouter | 2000000 |  |  |  |  |
| google/gemini-pro-vision |  | Google: Gemini Pro Vision 1.0 | openrouter | 16384 |  |  |  |  |
| google/gemma-2-27b-it |  | Google: Gemma 2 27B | openrouter | 8192 |  |  |  |  |
| google/gemma-2-9b-it |  | Google: Gemma 2 9B | openrouter | 8192 |  |  |  |  |
| google/gemma-2-9b-it:free |  | Google: Gemma 2 9B (free) | openrouter | 8192 |  |  |  |  |
| google/gemma-3-12b-it |  | Google: Gemma 3 12B | openrouter | 131072 |  |  |  |  |
| google/gemma-3-12b-it:free |  | Google: Gemma 3 12B (free) | openrouter | 131072 |  |  |  |  |
| google/gemma-3-1b-it:free |  | Google: Gemma 3 1B (free) | openrouter | 32768 |  |  |  |  |
| google/gemma-3-27b-it |  | Google: Gemma 3 27B | openrouter | 131072 |  |  |  |  |
| google/gemma-3-27b-it:free |  | Google: Gemma 3 27B (free) | openrouter | 96000 |  |  |  |  |
| google/gemma-3-4b-it |  | Google: Gemma 3 4B | openrouter | 131072 |  |  |  |  |
| google/gemma-3-4b-it:free |  | Google: Gemma 3 4B (free) | openrouter | 131072 |  |  |  |  |
| google/learnlm-1.5-pro-experimental:free |  | Google: LearnLM 1.5 Pro Experimental (free) | openrouter | 40960 |  |  |  |  |
| google/palm-2-chat-bison |  | Google: PaLM 2 Chat | openrouter | 9216 |  |  |  |  |
| google/palm-2-chat-bison-32k |  | Google: PaLM 2 Chat 32k | openrouter | 32768 |  |  |  |  |
| google/palm-2-codechat-bison |  | Google: PaLM 2 Code Chat | openrouter | 7168 |  |  |  |  |
| google/palm-2-codechat-bison-32k |  | Google: PaLM 2 Code Chat 32k | openrouter | 32768 |  |  |  |  |
| gryphe/mythomax-l2-13b |  | MythoMax 13B | openrouter | 4096 |  |  |  |  |
| huggingfaceh4/zephyr-7b-beta:free |  | Hugging Face: Zephyr 7B (free) | openrouter | 4096 |  |  |  |  |
| infermatic/mn-inferor-12b |  | Infermatic: Mistral Nemo Inferor 12B | openrouter | 16384 |  |  |  |  |
| inflection/inflection-3-pi |  | Inflection: Inflection 3 Pi | openrouter | 8000 |  |  |  |  |
| inflection/inflection-3-productivity |  | Inflection: Inflection 3 Productivity | openrouter | 8000 |  |  |  |  |
| jondurbin/airoboros-l2-70b |  | Airoboros 70B | openrouter | 4096 |  |  |  |  |
| latitudegames/wayfarer-large-70b-llama-3.3 |  | LatitudeGames: Wayfarer Large 70B Llama 3.3 | openrouter | 131072 |  |  |  |  |
| liquid/lfm-3b |  | Liquid: LFM 3B | openrouter | 32768 |  |  |  |  |
| liquid/lfm-40b |  | Liquid: LFM 40B MoE | openrouter | 32768 |  |  |  |  |
| liquid/lfm-7b |  | Liquid: LFM 7B | openrouter | 32768 |  |  |  |  |
| mancer/weaver |  | Mancer: Weaver (alpha) | openrouter | 8000 |  |  |  |  |
| meta-llama/llama-2-13b-chat |  | Meta: Llama 2 13B Chat | openrouter | 4096 |  |  |  |  |
| meta-llama/llama-2-70b-chat |  | Meta: Llama 2 70B Chat | openrouter | 4096 |  |  |  |  |
| meta-llama/llama-3-70b-instruct |  | Meta: Llama 3 70B Instruct | openrouter | 8192 |  |  |  |  |
| meta-llama/llama-3-8b-instruct |  | Meta: Llama 3 8B Instruct | openrouter | 8192 |  |  |  |  |
| meta-llama/llama-3.1-405b |  | Meta: Llama 3.1 405B (base) | openrouter | 32768 |  |  |  |  |
| meta-llama/llama-3.1-405b-instruct |  | Meta: Llama 3.1 405B Instruct | openrouter | 32768 |  |  |  |  |
| meta-llama/llama-3.1-405b:free |  | Meta: Llama 3.1 405B (base) (free) | openrouter | 64000 |  |  |  |  |
| meta-llama/llama-3.1-70b-instruct |  | Meta: Llama 3.1 70B Instruct | openrouter | 131072 |  |  |  |  |
| meta-llama/llama-3.1-8b-instruct |  | Meta: Llama 3.1 8B Instruct | openrouter | 16384 |  |  |  |  |
| meta-llama/llama-3.1-8b-instruct:free |  | Meta: Llama 3.1 8B Instruct (free) | openrouter | 131072 |  |  |  |  |
| meta-llama/llama-3.2-11b-vision-instruct |  | Meta: Llama 3.2 11B Vision Instruct | openrouter | 131072 |  |  |  |  |
| meta-llama/llama-3.2-11b-vision-instruct:free |  | Meta: Llama 3.2 11B Vision Instruct (free) | openrouter | 131072 |  |  |  |  |
| meta-llama/llama-3.2-1b-instruct |  | Meta: Llama 3.2 1B Instruct | openrouter | 131072 |  |  |  |  |
| meta-llama/llama-3.2-1b-instruct:free |  | Meta: Llama 3.2 1B Instruct (free) | openrouter | 131072 |  |  |  |  |
| meta-llama/llama-3.2-3b-instruct |  | Meta: Llama 3.2 3B Instruct | openrouter | 131072 |  |  |  |  |
| meta-llama/llama-3.2-3b-instruct:free |  | Meta: Llama 3.2 3B Instruct (free) | openrouter | 20000 |  |  |  |  |
| meta-llama/llama-3.2-90b-vision-instruct |  | Meta: Llama 3.2 90B Vision Instruct | openrouter | 131072 |  |  |  |  |
| meta-llama/llama-3.3-70b-instruct |  | Meta: Llama 3.3 70B Instruct | openrouter | 128000 |  |  |  |  |
| meta-llama/llama-3.3-70b-instruct:free |  | Meta: Llama 3.3 70B Instruct (free) | openrouter | 8000 |  |  |  |  |
| meta-llama/llama-4-maverick |  | Meta: Llama 4 Maverick | openrouter | 1048576 |  |  |  |  |
| meta-llama/llama-4-maverick:free |  | Meta: Llama 4 Maverick (free) | openrouter | 256000 |  |  |  |  |
| meta-llama/llama-4-scout |  | Meta: Llama 4 Scout | openrouter | 1048576 |  |  |  |  |
| meta-llama/llama-4-scout:free |  | Meta: Llama 4 Scout (free) | openrouter | 512000 |  |  |  |  |
| meta-llama/llama-guard-2-8b |  | Meta: LlamaGuard 2 8B | openrouter | 8192 |  |  |  |  |
| meta-llama/llama-guard-3-8b |  | Llama Guard 3 8B | openrouter | 131072 |  |  |  |  |
| microsoft/mai-ds-r1:free |  | Microsoft: MAI DS R1 (free) | openrouter | 163840 |  |  |  |  |
| microsoft/phi-3-medium-128k-instruct |  | Microsoft: Phi-3 Medium 128K Instruct | openrouter | 128000 |  |  |  |  |
| microsoft/phi-3-mini-128k-instruct |  | Microsoft: Phi-3 Mini 128K Instruct | openrouter | 128000 |  |  |  |  |
| microsoft/phi-3.5-mini-128k-instruct |  | Microsoft: Phi-3.5 Mini 128K Instruct | openrouter | 128000 |  |  |  |  |
| microsoft/phi-4 |  | Microsoft: Phi 4 | openrouter | 16384 |  |  |  |  |
| microsoft/phi-4-multimodal-instruct |  | Microsoft: Phi 4 Multimodal Instruct | openrouter | 131072 |  |  |  |  |
| microsoft/wizardlm-2-7b |  | WizardLM-2 7B | openrouter | 32000 |  |  |  |  |
| microsoft/wizardlm-2-8x22b |  | WizardLM-2 8x22B | openrouter | 65536 |  |  |  |  |
| minimax/minimax-01 |  | MiniMax: MiniMax-01 | openrouter | 1000192 |  |  |  |  |
| mistral/ministral-8b |  | Mistral: Ministral 8B | openrouter | 131072 |  |  |  |  |
| mistralai/codestral-2501 |  | Mistral: Codestral 2501 | openrouter | 262144 |  |  |  |  |
| mistralai/codestral-mamba |  | Mistral: Codestral Mamba | openrouter | 262144 |  |  |  |  |
| mistralai/ministral-3b |  | Mistral: Ministral 3B | openrouter | 131072 |  |  |  |  |
| mistralai/ministral-8b |  | Mistral: Ministral 8B | openrouter | 128000 |  |  |  |  |
| mistralai/mistral-7b-instruct |  | Mistral: Mistral 7B Instruct | openrouter | 32768 |  |  |  |  |
| mistralai/mistral-7b-instruct-v0.1 |  | Mistral: Mistral 7B Instruct v0.1 | openrouter | 32768 |  |  |  |  |
| mistralai/mistral-7b-instruct-v0.2 |  | Mistral: Mistral 7B Instruct v0.2 | openrouter | 32768 |  |  |  |  |
| mistralai/mistral-7b-instruct-v0.3 |  | Mistral: Mistral 7B Instruct v0.3 | openrouter | 32768 |  |  |  |  |
| mistralai/mistral-7b-instruct:free |  | Mistral: Mistral 7B Instruct (free) | openrouter | 32768 |  |  |  |  |
| mistralai/mistral-large |  | Mistral Large | openrouter | 128000 |  |  |  |  |
| mistralai/mistral-large-2407 |  | Mistral Large 2407 | openrouter | 131072 |  |  |  |  |
| mistralai/mistral-large-2411 |  | Mistral Large 2411 | openrouter | 131072 |  |  |  |  |
| mistralai/mistral-medium |  | Mistral Medium | openrouter | 32768 |  |  |  |  |
| mistralai/mistral-nemo |  | Mistral: Mistral Nemo | openrouter | 131072 |  |  |  |  |
| mistralai/mistral-nemo:free |  | Mistral: Mistral Nemo (free) | openrouter | 128000 |  |  |  |  |
| mistralai/mistral-saba |  | Mistral: Saba | openrouter | 32768 |  |  |  |  |
| mistralai/mistral-small |  | Mistral Small | openrouter | 32768 |  |  |  |  |
| mistralai/mistral-small-24b-instruct-2501 |  | Mistral: Mistral Small 3 | openrouter | 32768 |  |  |  |  |
| mistralai/mistral-small-24b-instruct-2501:free |  | Mistral: Mistral Small 3 (free) | openrouter | 32768 |  |  |  |  |
| mistralai/mistral-small-3.1-24b-instruct |  | Mistral: Mistral Small 3.1 24B | openrouter | 32768 |  |  |  |  |
| mistralai/mistral-small-3.1-24b-instruct:free |  | Mistral: Mistral Small 3.1 24B (free) | openrouter | 96000 |  |  |  |  |
| mistralai/mistral-tiny |  | Mistral Tiny | openrouter | 32768 |  |  |  |  |
| mistralai/mixtral-8x22b-instruct |  | Mistral: Mixtral 8x22B Instruct | openrouter | 65536 |  |  |  |  |
| mistralai/mixtral-8x7b-instruct |  | Mistral: Mixtral 8x7B Instruct | openrouter | 32768 |  |  |  |  |
| mistralai/pixtral-12b |  | Mistral: Pixtral 12B | openrouter | 32768 |  |  |  |  |
| mistralai/pixtral-large-2411 |  | Mistral: Pixtral Large 2411 | openrouter | 131072 |  |  |  |  |
| moonshotai/kimi-vl-a3b-thinking:free |  | Moonshot AI: Kimi VL A3B Thinking (free) | openrouter | 131072 |  |  |  |  |
| moonshotai/moonlight-16b-a3b-instruct:free |  | Moonshot AI: Moonlight 16B A3B Instruct (free) | openrouter | 8192 |  |  |  |  |
| neversleep/llama-3-lumimaid-70b |  | NeverSleep: Llama 3 Lumimaid 70B | openrouter | 8192 |  |  |  |  |
| neversleep/llama-3-lumimaid-8b |  | NeverSleep: Llama 3 Lumimaid 8B | openrouter | 24576 |  |  |  |  |
| neversleep/llama-3-lumimaid-8b:extended |  | NeverSleep: Llama 3 Lumimaid 8B (extended) | openrouter | 24576 |  |  |  |  |
| neversleep/llama-3.1-lumimaid-70b |  | NeverSleep: Lumimaid v0.2 70B | openrouter | 16384 |  |  |  |  |
| neversleep/llama-3.1-lumimaid-8b |  | NeverSleep: Lumimaid v0.2 8B | openrouter | 32768 |  |  |  |  |
| neversleep/noromaid-20b |  | Noromaid 20B | openrouter | 8192 |  |  |  |  |
| nothingiisreal/mn-celeste-12b |  | Mistral Nemo 12B Celeste | openrouter | 16384 |  |  |  |  |
| nousresearch/deephermes-3-llama-3-8b-preview:free |  | Nous: DeepHermes 3 Llama 3 8B Preview (free) | openrouter | 131072 |  |  |  |  |
| nousresearch/hermes-2-pro-llama-3-8b |  | NousResearch: Hermes 2 Pro - Llama-3 8B | openrouter | 131072 |  |  |  |  |
| nousresearch/hermes-3-llama-3.1-405b |  | Nous: Hermes 3 405B Instruct | openrouter | 131072 |  |  |  |  |
| nousresearch/hermes-3-llama-3.1-70b |  | Nous: Hermes 3 70B Instruct | openrouter | 131072 |  |  |  |  |
| nousresearch/nous-hermes-2-mixtral-8x7b-dpo |  | Nous: Hermes 2 Mixtral 8x7B DPO | openrouter | 32768 |  |  |  |  |
| nousresearch/nous-hermes-llama2-13b |  | Nous: Hermes 13B | openrouter | 4096 |  |  |  |  |
| nvidia/llama-3.1-nemotron-70b-instruct |  | NVIDIA: Llama 3.1 Nemotron 70B Instruct | openrouter | 131072 |  |  |  |  |
| nvidia/llama-3.1-nemotron-70b-instruct:free |  | NVIDIA: Llama 3.1 Nemotron 70B Instruct (free) | openrouter | 131072 |  |  |  |  |
| nvidia/llama-3.1-nemotron-nano-8b-v1:free |  | NVIDIA: Llama 3.1 Nemotron Nano 8B v1 (free) | openrouter | 131072 |  |  |  |  |
| nvidia/llama-3.1-nemotron-ultra-253b-v1:free |  | NVIDIA: Llama 3.1 Nemotron Ultra 253B v1 (free) | openrouter | 131072 |  |  |  |  |
| nvidia/llama-3.3-nemotron-super-49b-v1:free |  | NVIDIA: Llama 3.3 Nemotron Super 49B v1 (free) | openrouter | 131072 |  |  |  |  |
| open-r1/olympiccoder-32b:free |  | OlympicCoder 32B (free) | openrouter | 32768 |  |  |  |  |
| open-r1/olympiccoder-7b:free |  | OlympicCoder 7B (free) | openrouter | 32768 |  |  |  |  |
| openai/chatgpt-4o-latest |  | OpenAI: ChatGPT-4o | openrouter | 128000 |  |  |  |  |
| openai/gpt-3.5-turbo |  | OpenAI: GPT-3.5 Turbo | openrouter | 16385 |  |  |  |  |
| openai/gpt-3.5-turbo-0125 |  | OpenAI: GPT-3.5 Turbo 16k | openrouter | 16385 |  |  |  |  |
| openai/gpt-3.5-turbo-0613 |  | OpenAI: GPT-3.5 Turbo (older v0613) | openrouter | 4095 |  |  |  |  |
| openai/gpt-3.5-turbo-1106 |  | OpenAI: GPT-3.5 Turbo 16k (older v1106) | openrouter | 16385 |  |  |  |  |
| openai/gpt-3.5-turbo-16k |  | OpenAI: GPT-3.5 Turbo 16k | openrouter | 16385 |  |  |  |  |
| openai/gpt-3.5-turbo-instruct |  | OpenAI: GPT-3.5 Turbo Instruct | openrouter | 4095 |  |  |  |  |
| openai/gpt-4 |  | OpenAI: GPT-4 | openrouter | 8191 |  |  |  |  |
| openai/gpt-4-0314 |  | OpenAI: GPT-4 (older v0314) | openrouter | 8191 |  |  |  |  |
| openai/gpt-4-1106-preview |  | OpenAI: GPT-4 Turbo (older v1106) | openrouter | 128000 |  |  |  |  |
| openai/gpt-4-32k |  | OpenAI: GPT-4 32k | openrouter | 32767 |  |  |  |  |
| openai/gpt-4-32k-0314 |  | OpenAI: GPT-4 32k (older v0314) | openrouter | 32767 |  |  |  |  |
| openai/gpt-4-turbo |  | OpenAI: GPT-4 Turbo | openrouter | 128000 |  |  |  |  |
| openai/gpt-4-turbo-preview |  | OpenAI: GPT-4 Turbo Preview | openrouter | 128000 |  |  |  |  |
| openai/gpt-4.1 |  | OpenAI: GPT-4.1 | openrouter | 1047576 |  |  |  |  |
| openai/gpt-4.1-mini |  | OpenAI: GPT-4.1 Mini | openrouter | 1047576 |  |  |  |  |
| openai/gpt-4.1-nano |  | OpenAI: GPT-4.1 Nano | openrouter | 1047576 |  |  |  |  |
| openai/gpt-4.5-preview |  | OpenAI: GPT-4.5 (Preview) | openrouter | 128000 |  |  |  |  |
| openai/gpt-4o |  | OpenAI: GPT-4o | openrouter | 128000 |  |  |  |  |
| openai/gpt-4o-2024-05-13 |  | OpenAI: GPT-4o (2024-05-13) | openrouter | 128000 |  |  |  |  |
| openai/gpt-4o-2024-08-06 |  | OpenAI: GPT-4o (2024-08-06) | openrouter | 128000 |  |  |  |  |
| openai/gpt-4o-2024-11-20 |  | OpenAI: GPT-4o (2024-11-20) | openrouter | 128000 |  |  |  |  |
| openai/gpt-4o-mini |  | OpenAI: GPT-4o-mini | openrouter | 128000 |  |  |  |  |
| openai/gpt-4o-mini-2024-07-18 |  | OpenAI: GPT-4o-mini (2024-07-18) | openrouter | 128000 |  |  |  |  |
| openai/gpt-4o-mini-search-preview |  | OpenAI: GPT-4o-mini Search Preview | openrouter | 128000 |  |  |  |  |
| openai/gpt-4o-search-preview |  | OpenAI: GPT-4o Search Preview | openrouter | 128000 |  |  |  |  |
| openai/gpt-4o:extended |  | OpenAI: GPT-4o (extended) | openrouter | 128000 |  |  |  |  |
| openai/o1 |  | OpenAI: o1 | openrouter | 200000 |  |  |  |  |
| openai/o1-mini |  | OpenAI: o1-mini | openrouter | 128000 |  |  |  |  |
| openai/o1-mini-2024-09-12 |  | OpenAI: o1-mini (2024-09-12) | openrouter | 128000 |  |  |  |  |
| openai/o1-preview |  | OpenAI: o1-preview | openrouter | 128000 |  |  |  |  |
| openai/o1-preview-2024-09-12 |  | OpenAI: o1-preview (2024-09-12) | openrouter | 128000 |  |  |  |  |
| openai/o1-pro |  | OpenAI: o1-pro | openrouter | 200000 |  |  |  |  |
| openai/o3 |  | OpenAI: o3 | openrouter | 200000 |  |  |  |  |
| openai/o3-mini |  | OpenAI: o3 Mini | openrouter | 200000 |  |  |  |  |
| openai/o3-mini-high |  | OpenAI: o3 Mini High | openrouter | 200000 |  |  |  |  |
| openai/o4-mini |  | OpenAI: o4 Mini | openrouter | 200000 |  |  |  |  |
| openai/o4-mini-high |  | OpenAI: o4 Mini High | openrouter | 200000 |  |  |  |  |
| openchat/openchat-7b |  | OpenChat 3.5 7B | openrouter | 8192 |  |  |  |  |
| openrouter/auto |  | Auto Router | openrouter | 2000000 |  |  |  |  |
| perplexity/llama-3.1-sonar-large-128k-online |  | Perplexity: Llama 3.1 Sonar 70B Online | openrouter | 127072 |  |  |  |  |
| perplexity/llama-3.1-sonar-small-128k-online |  | Perplexity: Llama 3.1 Sonar 8B Online | openrouter | 127072 |  |  |  |  |
| perplexity/r1-1776 |  | Perplexity: R1 1776 | openrouter | 128000 |  |  |  |  |
| perplexity/sonar |  | Perplexity: Sonar | openrouter | 127072 |  |  |  |  |
| perplexity/sonar-deep-research |  | Perplexity: Sonar Deep Research | openrouter | 128000 |  |  |  |  |
| perplexity/sonar-pro |  | Perplexity: Sonar Pro | openrouter | 200000 |  |  |  |  |
| perplexity/sonar-reasoning |  | Perplexity: Sonar Reasoning | openrouter | 127000 |  |  |  |  |
| perplexity/sonar-reasoning-pro |  | Perplexity: Sonar Reasoning Pro | openrouter | 128000 |  |  |  |  |
| pygmalionai/mythalion-13b |  | Pygmalion: Mythalion 13B | openrouter | 8192 |  |  |  |  |
| qwen/qwen-2-72b-instruct |  | Qwen 2 72B Instruct | openrouter | 32768 |  |  |  |  |
| qwen/qwen-2.5-72b-instruct |  | Qwen2.5 72B Instruct | openrouter | 32768 |  |  |  |  |
| qwen/qwen-2.5-72b-instruct:free |  | Qwen2.5 72B Instruct (free) | openrouter | 32768 |  |  |  |  |
| qwen/qwen-2.5-7b-instruct |  | Qwen2.5 7B Instruct | openrouter | 32768 |  |  |  |  |
| qwen/qwen-2.5-7b-instruct:free |  | Qwen2.5 7B Instruct (free) | openrouter | 32768 |  |  |  |  |
| qwen/qwen-2.5-coder-32b-instruct |  | Qwen2.5 Coder 32B Instruct | openrouter | 32768 |  |  |  |  |
| qwen/qwen-2.5-coder-32b-instruct:free |  | Qwen2.5 Coder 32B Instruct (free) | openrouter | 32768 |  |  |  |  |
| qwen/qwen-2.5-vl-72b-instruct |  | Qwen: Qwen2.5-VL 72B Instruct | openrouter | 32768 |  |  |  |  |
| qwen/qwen-2.5-vl-7b-instruct |  | Qwen: Qwen2.5-VL 7B Instruct | openrouter | 32768 |  |  |  |  |
| qwen/qwen-2.5-vl-7b-instruct:free |  | Qwen: Qwen2.5-VL 7B Instruct (free) | openrouter | 64000 |  |  |  |  |
| qwen/qwen-max |  | Qwen: Qwen-Max  | openrouter | 32768 |  |  |  |  |
| qwen/qwen-plus |  | Qwen: Qwen-Plus | openrouter | 131072 |  |  |  |  |
| qwen/qwen-turbo |  | Qwen: Qwen-Turbo | openrouter | 1000000 |  |  |  |  |
| qwen/qwen-vl-max |  | Qwen: Qwen VL Max | openrouter | 7500 |  |  |  |  |
| qwen/qwen-vl-plus |  | Qwen: Qwen VL Plus | openrouter | 7500 |  |  |  |  |
| qwen/qwen2.5-coder-7b-instruct |  | Qwen: Qwen2.5 Coder 7B Instruct | openrouter | 32768 |  |  |  |  |
| qwen/qwen2.5-vl-32b-instruct |  | Qwen: Qwen2.5 VL 32B Instruct | openrouter | 128000 |  |  |  |  |
| qwen/qwen2.5-vl-32b-instruct:free |  | Qwen: Qwen2.5 VL 32B Instruct (free) | openrouter | 8192 |  |  |  |  |
| qwen/qwen2.5-vl-3b-instruct:free |  | Qwen: Qwen2.5 VL 3B Instruct (free) | openrouter | 64000 |  |  |  |  |
| qwen/qwen2.5-vl-72b-instruct |  | Qwen: Qwen2.5 VL 72B Instruct | openrouter | 128000 |  |  |  |  |
| qwen/qwen2.5-vl-72b-instruct:free |  | Qwen: Qwen2.5 VL 72B Instruct (free) | openrouter | 131072 |  |  |  |  |
| qwen/qwq-32b |  | Qwen: QwQ 32B | openrouter | 131072 |  |  |  |  |
| qwen/qwq-32b-preview |  | Qwen: QwQ 32B Preview | openrouter | 32768 |  |  |  |  |
| qwen/qwq-32b-preview:free |  | Qwen: QwQ 32B Preview (free) | openrouter | 16384 |  |  |  |  |
| qwen/qwq-32b:free |  | Qwen: QwQ 32B (free) | openrouter | 40000 |  |  |  |  |
| raifle/sorcererlm-8x22b |  | SorcererLM 8x22B | openrouter | 16000 |  |  |  |  |
| rekaai/reka-flash-3:free |  | Reka: Flash 3 (free) | openrouter | 32768 |  |  |  |  |
| sao10k/fimbulvetr-11b-v2 |  | Fimbulvetr 11B v2 | openrouter | 4096 |  |  |  |  |
| sao10k/l3-euryale-70b |  | Sao10k: Llama 3 Euryale 70B v2.1 | openrouter | 8192 |  |  |  |  |
| sao10k/l3-lunaris-8b |  | Sao10K: Llama 3 8B Lunaris | openrouter | 8192 |  |  |  |  |
| sao10k/l3.1-euryale-70b |  | Sao10K: Llama 3.1 Euryale 70B v2.2 | openrouter | 131072 |  |  |  |  |
| sao10k/l3.3-euryale-70b |  | Sao10K: Llama 3.3 Euryale 70B | openrouter | 131072 |  |  |  |  |
| scb10x/llama3.1-typhoon2-70b-instruct |  | Typhoon2 70B Instruct | openrouter | 8192 |  |  |  |  |
| scb10x/llama3.1-typhoon2-8b-instruct |  | Typhoon2 8B Instruct | openrouter | 8192 |  |  |  |  |
| shisa-ai/shisa-v2-llama3.3-70b:free |  | Shisa AI: Shisa V2 Llama 3.3 70B  (free) | openrouter | 32768 |  |  |  |  |
| sophosympatheia/midnight-rose-70b |  | Midnight Rose 70B | openrouter | 4096 |  |  |  |  |
| sophosympatheia/rogue-rose-103b-v0.2:free |  | Rogue Rose 103B v0.2 (free) | openrouter | 4096 |  |  |  |  |
| steelskull/l3.3-electra-r1-70b |  | SteelSkull: L3.3 Electra R1 70B | openrouter | 131072 |  |  |  |  |
| thedrummer/anubis-pro-105b-v1 |  | TheDrummer: Anubis Pro 105B V1 | openrouter | 131072 |  |  |  |  |
| thedrummer/rocinante-12b |  | Rocinante 12B | openrouter | 32768 |  |  |  |  |
| thedrummer/skyfall-36b-v2 |  | TheDrummer: Skyfall 36B V2 | openrouter | 32768 |  |  |  |  |
| thedrummer/unslopnemo-12b |  | Unslopnemo 12B | openrouter | 32000 |  |  |  |  |
| thudm/glm-4-32b:free |  | THUDM: GLM 4 32B (free) | openrouter | 32768 |  |  |  |  |
| thudm/glm-z1-32b:free |  | THUDM: GLM Z1 32B (free) | openrouter | 32768 |  |  |  |  |
| undi95/remm-slerp-l2-13b |  | ReMM SLERP 13B | openrouter | 6144 |  |  |  |  |
| undi95/toppy-m-7b |  | Toppy M 7B | openrouter | 4096 |  |  |  |  |
| x-ai/grok-2-1212 |  | xAI: Grok 2 1212 | openrouter | 131072 |  |  |  |  |
| x-ai/grok-2-vision-1212 |  | xAI: Grok 2 Vision 1212 | openrouter | 32768 |  |  |  |  |
| x-ai/grok-3-beta |  | xAI: Grok 3 Beta | openrouter | 131072 |  |  |  |  |
| x-ai/grok-3-mini-beta |  | xAI: Grok 3 Mini Beta | openrouter | 131072 |  |  |  |  |
| x-ai/grok-beta |  | xAI: Grok Beta | openrouter | 131072 |  |  |  |  |
| x-ai/grok-vision-beta |  | xAI: Grok Vision Beta | openrouter | 8192 |  |  |  |  |

