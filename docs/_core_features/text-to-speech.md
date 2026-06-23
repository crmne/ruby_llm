---
layout: default
title: Text to Speech
nav_order: 5
description: Convert text into spoken audio
redirect_from:
  - /guides/text-to-speech
  - /guides/speech
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

*   How to generate speech from text.
*   How to save generated audio files.
*   How to choose models, voices, and formats.
*   How to access raw audio bytes.

## Basic Speech Generation

Generate audio with the global `RubyLLM.speak` method:

```ruby
speech = RubyLLM.speak "Hello, welcome to RubyLLM!"
speech.save "welcome.mp3"
```

The return value is a `RubyLLM::Speech` object:

```ruby
speech.model
# => "{{ site.models.default_speech }}"

speech.voice
# => "alloy"

speech.format
# => "mp3"

speech.mime_type
# => "audio/mpeg"

speech.to_blob
# => raw audio bytes
```

## Choosing Models

By default, RubyLLM uses `config.default_speech_model`.

```ruby
RubyLLM.speak("Ship it.", model: "{{ site.models.speech_openai }}")

RubyLLM.speak(
  "Say cheerfully: Have a wonderful day!",
  model: "{{ site.models.speech_google }}",
  provider: :gemini
)
```

Configure the default globally:

```ruby
RubyLLM.configure do |config|
  config.default_speech_model = "{{ site.models.default_speech }}"
end
```

## Voices

RubyLLM picks a provider default voice for the simple case. Pass `voice:` when you want a specific one.

```ruby
RubyLLM.speak("Welcome back.", voice: "nova")

RubyLLM.speak(
  "Say warmly: Welcome back.",
  provider: :gemini,
  model: "{{ site.models.speech_google }}",
  voice: "Kore"
)
```

OpenAI voices include `alloy`, `ash`, `ballad`, `coral`, `echo`, `fable`, `onyx`, `nova`, `sage`, `shimmer`, `verse`, `marin`, and `cedar`. Gemini supports its own voice set, including `Kore`, `Puck`, `Zephyr`, and `Sadachbia`.

## Formats

OpenAI supports several output formats:

```ruby
speech = RubyLLM.speak("Save this as a WAV file.", format: "wav")
speech.save("voiceover.wav")
```

Supported OpenAI formats are `mp3`, `opus`, `aac`, `flac`, `wav`, and `pcm`.

Gemini's generateContent speech endpoint returns raw PCM audio. RubyLLM reports that honestly:

```ruby
speech = RubyLLM.speak(
  "Say cheerfully: Have a wonderful day!",
  provider: :gemini,
  model: "{{ site.models.speech_google }}"
)

speech.format
# => "pcm"
```

Convert PCM with a tool like ffmpeg when you need a container format:

```bash
ffmpeg -f s16le -ar 24000 -ac 1 -i out.pcm out.wav
```

## Style

Some providers accept extra speech controls. OpenAI supports `instructions:` and `speed:`:

```ruby
RubyLLM.speak(
  "The build is green.",
  instructions: "Speak with calm confidence.",
  speed: 1.1
)
```

Gemini handles style through the prompt:

```ruby
RubyLLM.speak(
  "Say in a bright, encouraging voice: The build is green.",
  provider: :gemini,
  model: "{{ site.models.speech_google }}",
  voice: "Puck"
)
```

## Error Handling

```ruby
begin
  speech = RubyLLM.speak("Hello")
  speech.save("hello.mp3")
rescue RubyLLM::BadRequestError => e
  puts "Invalid request: #{e.message}"
rescue RubyLLM::Error => e
  puts "Speech generation failed: #{e.message}"
end
```

## Next Steps

*   [Audio Transcription]({% link _core_features/audio-transcription.md %}): Convert speech back to text.
*   [Model Resolution]({% link _reference/model-resolution.md %}): Learn how `model:` and `provider:` are resolved.
*   [Instrumentation and Observability]({% link _advanced/instrumentation.md %}): Track speech generation events in production.
