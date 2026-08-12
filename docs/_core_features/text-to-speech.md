---
layout: default
title: Text to Speech
nav_order: 6
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

RubyLLM.speak(
  "The first move is what sets everything in motion.",
  model: "eleven_v3",
  provider: :elevenlabs
)
```

ElevenLabs offers `eleven_v3` for the most expressive delivery, `eleven_multilingual_v2` for the highest audio fidelity, and `eleven_flash_v2_5` when latency matters more than nuance.

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

ElevenLabs identifies voices by id rather than by name, so pass the voice id from your ElevenLabs voice library:

```ruby
RubyLLM.speak(
  "Welcome back.",
  model: "eleven_v3",
  provider: :elevenlabs,
  voice: "JBFqnCBsd6RMkjVDRZzb"
)
```

That id is George, the default voice RubyLLM uses when you omit `voice:`.

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

ElevenLabs picks a sample rate and bitrate along with the container. RubyLLM maps `mp3`, `opus`, `pcm`, `wav`, `ulaw`, and `alaw` onto sensible ElevenLabs defaults, and passes anything else through unchanged so you can name an exact output format:

```ruby
RubyLLM.speak("Ship it.", model: "eleven_v3", provider: :elevenlabs, format: "mp3")
# requests output_format=mp3_44100_128

RubyLLM.speak("Ship it.", model: "eleven_v3", provider: :elevenlabs, format: "pcm_24000")
# requests output_format=pcm_24000
```

Either way `speech.format` reports the container you actually got, so `pcm_24000` comes back as `"pcm"`.

## Style

`RubyLLM.speak` keeps the options every provider understands as keywords: `model:`, `voice:`, and `format:`. Provider-specific speech controls go in `provider_options:`, a hash of options in the provider's own request vocabulary that RubyLLM merges into the request as-is. OpenAI supports `instructions:` and `speed:`:

```ruby
RubyLLM.speak(
  "The build is green.",
  provider_options: {
    instructions: "Speak with calm confidence.",
    speed: 1.1
  }
)
```

ElevenLabs takes `voice_settings` and a `language_code`:

```ruby
RubyLLM.speak(
  "The build is green.",
  model: "eleven_v3",
  provider: :elevenlabs,
  provider_options: {
    voice_settings: { stability: 0.4, similarity_boost: 0.8, speed: 1.1 },
    language_code: "en"
  }
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
