---
layout: default
title: Apple Intelligence
nav_order: 4
description: Run AI completely on-device with Apple Intelligence — no API keys, no cloud, fully private.
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

* How to use Apple Intelligence for completely local, on-device AI
* The system requirements and how to verify your setup
* How to configure and customize the provider
* How it works under the hood
* Current limitations and troubleshooting tips

## What is Apple Intelligence?

Apple Intelligence brings on-device AI to RubyLLM through Apple's Foundation Models. Your prompts and responses never leave your Mac — no API keys, no cloud services, no data sharing. It's the most private way to use AI with RubyLLM.

Under the hood, RubyLLM communicates with the `osx-ai-inloop` binary, which pipes JSON requests to Apple's on-device language model via stdin/stdout.

## Requirements

* **macOS 26** (Tahoe) or later
* **Apple Silicon** (M1 or later)
* **Apple Intelligence** enabled in System Settings > Apple Intelligence & Siri

> Apple Intelligence is not available on Intel Macs or older macOS versions. RubyLLM will raise an error if the requirements aren't met.
{: .note }

## Quick Start

No configuration needed. Just use it:

```ruby
chat = RubyLLM.chat(model: "apple-intelligence", provider: :apple_intelligence)
chat.ask "Explain Ruby's block syntax"
```

That's it. No API keys, no environment variables, no account setup. The `osx-ai-inloop` binary is automatically downloaded and cached on first use.

## Conversation History

Apple Intelligence supports multi-turn conversations, just like any other provider:

```ruby
chat = RubyLLM.chat(model: "apple-intelligence", provider: :apple_intelligence)
chat.ask "What is a Ruby module?"
chat.ask "How is that different from a class?"
chat.ask "When should I use one over the other?"
```

Each follow-up includes the full conversation history, so the model maintains context across turns.

## Configuration

### Zero Config (Default)

Apple Intelligence works out of the box with no configuration. RubyLLM automatically downloads the `osx-ai-inloop` binary to `~/.ruby_llm/bin/osx-ai-inloop` on first use.

### Custom Binary Path

If you prefer to manage the binary location yourself:

```ruby
RubyLLM.configure do |config|
  config.apple_intelligence_binary_path = "/opt/bin/osx-ai-inloop"
end
```

### Setting as Default Model

To use Apple Intelligence as your default chat model:

```ruby
RubyLLM.configure do |config|
  config.default_model = "apple-intelligence"
end

# Now RubyLLM.chat uses Apple Intelligence automatically
chat = RubyLLM.chat(provider: :apple_intelligence)
chat.ask "Hello!"
```

## How It Works

1. RubyLLM formats your conversation as a JSON payload
2. The payload is piped to the `osx-ai-inloop` binary via stdin
3. The binary communicates with Apple's Foundation Models on-device
4. The response is read from stdout and parsed back into RubyLLM's standard format

The binary is sourced from the [osx-ai-inloop](https://github.com/inloopstudio-team/apple-intelligence-inloop) project and cached at `~/.ruby_llm/bin/osx-ai-inloop`.

## Limitations

Apple Intelligence is text-only and runs entirely on-device. This means:

* **No streaming** — responses are returned all at once
* **No vision** — image analysis is not supported
* **No tool calling** — function/tool use is not available
* **No embeddings** — use another provider for `RubyLLM.embed`
* **No image generation** — use another provider for `RubyLLM.paint`
* **macOS only** — requires Apple Silicon and macOS 26+

For capabilities that Apple Intelligence doesn't support, you can use another provider alongside it:

```ruby
# Local AI for chat
local_chat = RubyLLM.chat(model: "apple-intelligence", provider: :apple_intelligence)
local_chat.ask "Summarize this concept"

# Cloud provider for embeddings
RubyLLM.embed "Ruby is elegant and expressive"
```

## Troubleshooting

### "Platform not supported" error

Apple Intelligence requires macOS 26+ on Apple Silicon. Verify your setup:

* Check macOS version: Apple menu > About This Mac
* Ensure Apple Intelligence is enabled: System Settings > Apple Intelligence & Siri

### Binary download fails

If the automatic download fails (network issues, firewall, etc.), download manually:

```bash
wget -O ~/.ruby_llm/bin/osx-ai-inloop \
  https://github.com/inloopstudio-team/apple-intelligence-inloop/raw/refs/heads/main/bin/osx-ai-inloop-arm64
chmod +x ~/.ruby_llm/bin/osx-ai-inloop
```

### Binary not found at custom path

If you configured a custom binary path, ensure the file exists and is executable:

```bash
ls -la /your/custom/path/osx-ai-inloop
chmod +x /your/custom/path/osx-ai-inloop
```

## Next Steps

Now that you have local AI running, explore other RubyLLM features:

- [Chat with AI models]({% link _core_features/chat.md %}) for more conversation features
- [Configuration]({% link _getting_started/configuration.md %}) for multi-provider setups
- [Tools and function calling]({% link _core_features/tools.md %}) with cloud providers
