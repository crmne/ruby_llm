---
layout: default
title: Text to Speech
nav_order: 8
description: Convert text into spoken audio
redirect_from:
  - /guides/text-to-speech
  - /guides/speech
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

*   How to generate speech from text.
*   How to save generated audio files.
*   How to stream audio as it is generated.
*   How to choose models, voices, and formats.
*   How to access raw audio bytes.

## Basic Speech Generation

Give your application a voice. Generate speech and save the audio:

```ruby
RubyLLM.speak("Hello, welcome to RubyLLM!").save("welcome.mp3")
```

The return value is a `RubyLLM::Speech` object:

```ruby
speech = RubyLLM.speak "Hello, welcome to RubyLLM!"

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

## Streaming Speech

Pass a block to receive audio before the complete recording is ready:

```ruby
speech = RubyLLM.speak("Hello, welcome to RubyLLM!") do |chunk|
  player.write(chunk.data)
end

speech.save "welcome.mp3"
```

Here, `player` is your application's audio player or output stream. Each `RubyLLM::SpeechChunk` has `data`, `format`, `mime_type`, and `to_blob`. Chunks are consecutive bytes of one recording. The call returns a complete `RubyLLM::Speech`, so you can save the recording after playing its chunks.

Chunks are not retried once delivered to your block.

## Choosing Models

Pass `model:` to choose a speech model:

```ruby
RubyLLM.speak("Ship it.", model: "{{ site.models.speech_elevenlabs }}")
```

Set `default_speech_model` in [Configuration]({% link _getting_started/configuration.md %}#default-models) to change the default. For Azure, pass the [deployment name]({% link _getting_started/configuration-providers.md %}#azure-deployments) with `provider: :azure`.

## Voices

RubyLLM picks a provider default voice for the simple case. Pass `voice:` when you want a specific one.

```ruby
RubyLLM.speak("Welcome back.", voice: "nova")

RubyLLM.speak(
  "Say warmly: Welcome back.",
  model: "{{ site.models.speech_google }}",
  voice: "Kore"
)
```

ElevenLabs identifies voices by id rather than by name, so pass the voice id from your ElevenLabs voice library:

```ruby
RubyLLM.speak(
  "Welcome back.",
  model: "{{ site.models.speech_elevenlabs }}",
  voice: "JBFqnCBsd6RMkjVDRZzb"
)
```

Deepgram Aura models include a voice in their model name. Override it with `voice:`:

```ruby
RubyLLM.speak(
  "Welcome back.",
  model: "{{ site.models.speech_deepgram }}",
  voice: "zeus"
)
```

Choose a model in the language you want to speak.

## Formats

Choose an output format with `format:`:

```ruby
speech = RubyLLM.speak("Save this as a WAV file.", format: "wav")
speech.save("voiceover.wav")
```

Available formats depend on the model. `speech.format` and `speech.mime_type` describe the returned audio.

Gemini's speech endpoint returns raw PCM audio:

```ruby
speech = RubyLLM.speak(
  "Say cheerfully: Have a wonderful day!",
  model: "{{ site.models.speech_google }}"
)

speech.format
# => "pcm"
speech.save "out.pcm"
```

Convert PCM with a tool like ffmpeg when you need a container format:

```bash
ffmpeg -f s16le -ar 24000 -ac 1 -i out.pcm out.wav
```

ElevenLabs also accepts formats with an explicit sample rate:

```ruby
RubyLLM.speak("Ship it.", model: "{{ site.models.speech_elevenlabs }}",
              format: "pcm_24000")
```

## Style

Use `provider_options:` for controls specific to a provider. OpenAI accepts delivery instructions and speed:

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
  model: "{{ site.models.speech_elevenlabs }}",
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
  model: "{{ site.models.speech_google }}",
  voice: "Puck"
)
```

For retries and provider errors, see [Error Handling]({% link _advanced/error-handling.md %}).

## Next Steps

*   [Audio Transcription]({% link _core_features/audio-transcription.md %}): Convert speech back to text.
*   [Model Resolution]({% link _reference/model-resolution.md %}): Learn how `model:` and `provider:` are resolved.
*   [Instrumentation and Observability]({% link _advanced/instrumentation.md %}): Track speech generation events in production.
