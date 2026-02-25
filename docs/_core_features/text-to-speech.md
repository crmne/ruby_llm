---
layout: default
title: Text to Speech
nav_order: 7
description: Convert text to speech
redirect_from:
  - /guides/audio-transcription
  - /guides/transcription
---

# {{ page.title }}
{: .d-inline-block .no_toc }

v1.9.0+
{: .label .label-green }

{{ page.description }}
{: .fs-6 .fw-300 }

## Table of contents
{: .no_toc .text-delta }

1. TOC
{:toc}

---

After reading this guide, you will know:

*   How to generate speech from text.
*   How to save audio files.
*   How to select different voices.
*   How to access raw audio data.
*   Specifics of language support.

## Basic Text to Speech

Generate audio with the global `RubyLLM.tts` method:

```ruby
audio = RubyLLM.tts("Hello, welcome to RubyLLM!")

```

## Save Audio File
You can save the generated audio to a file.
If you are using OpenAI, the audio will be saved as an MP3 file.

```ruby
audio = RubyLLM.tts("This is a text to speech example.", provider: :openai, model: "gpt-4o-mini-tts")
audio.save("example.mp3")
```

If you are using Gemini, the audio will be saved as a raw PCM file.

```ruby
audio = RubyLLM.tts("This is a text to speech example.", provider: :gemini, model: "gemini-2.5-flash-preview-tts")
audio.save("example.pcm")
```

You can convert it to MP3 using ffmpeg:

```bash
ffmpeg -f s16le -ar 24000 -ac 1 -i example.pcm example.mp3
```

### Select Voice
You can specify different voices. Supported voices for OpenAI
are alloy, ash, ballad, coral, echo, fable, onyx, nova, sage, shimmer, and verse.

For Gemini have a look at the [gemini voices](https://ai.google.dev/gemini-api/docs/speech-generation#voices).

```ruby
# Using a specific voice
voice = "ash"
audio = RubyLLM.tts("Hello, this is a #{voice}`s voice.", voice: voice)
```

### Access Audio Data
You can access the raw audio data:

```ruby
audio = RubyLLM.tts("Accessing raw audio data.")
audio.data # => binary audio data (MP3 for OpenAI, PCM for Gemini)
```

### Language Support
OpenAi and Gemini gather language support automatically based on the text provided.
Previously, you could specify the language manually in Gemini.

## Next Steps

*   [Chatting with AI Models]({% link _core_features/chat.md %}): Learn about conversational AI.
*   [Image Generation]({% link _core_features/image-generation.md %}): Generate images from text.
*   [Error Handling]({% link _advanced/error-handling.md %}): Master handling API errors.

