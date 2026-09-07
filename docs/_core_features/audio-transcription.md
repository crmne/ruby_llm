---
layout: default
title: Audio Transcription
nav_order: 7
description: Convert speech to text with support for multiple languages and speaker diarization
redirect_from:
  - /guides/audio-transcription
  - /guides/transcription
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

*   How to transcribe audio files to text.
*   How to identify different speakers with diarization.
*   How to improve accuracy with language hints and prompts.
*   How to access segments and timestamps.
*   How to stream a transcript as it is produced.

## Basic Transcription

Turn a recording into text:

```ruby
transcription = RubyLLM.transcribe("meeting.wav")
puts transcription.text
```

Pass a local path, URL, IO object, or Active Storage attachment. Supported audio formats depend on the model.

## Choosing Models

Pass `model:` to choose a transcription model:

```ruby
RubyLLM.transcribe("meeting.wav", model: "{{ site.models.transcription_elevenlabs }}")
```

Set `default_transcription_model` in [Configuration]({% link _getting_started/configuration.md %}#default-models) to change the default. Browse the [Models]({% link _reference/available-models.md %}) page for audio models. Pass `provider:` to select a hosted deployment explicitly.

For Azure, pass your [deployment name]({% link _getting_started/configuration-providers.md %}#azure-deployments). A diarization deployment with a custom name also needs `format: "diarized_json"`.

## Language and Vocabulary Hints

Give the model the recording's language and unfamiliar terms:

```ruby
RubyLLM.transcribe("entrevista.mp3", language: "es")

RubyLLM.transcribe(
  "developer-talk.mp3",
  prompt: "Discussion about Ruby, Rails, PostgreSQL, and Redis."
)
```

Use ISO 639-1 language codes such as `en`, `es`, and `fr`. Google's dedicated transcription models also accept BCP-47 hints such as `en-US`.

For provider-specific vocabulary and formatting controls, use `provider_options:`:

```ruby
RubyLLM.transcribe(
  "developer-talk.mp3",
  model: "{{ site.models.transcription_elevenlabs }}",
  provider_options: { keyterms: ["RubyLLM", "Zeitwerk"], tag_audio_events: true }
)
```

## Speaker Diarization

Pass `speaker_names: []` to request speaker labels:

```ruby
transcription = RubyLLM.transcribe(
  "meeting.wav",
  model: "{{ site.models.transcription_gemini }}",
  speaker_names: [],
  timestamps: :word
)

transcription.words.each do |word|
  puts "#{word['speaker']}: #{word['word']} (#{word['start']}s)"
end
```

Speaker and timing fields retain the provider's names. Depending on the model, speaker labels appear on words or segments. OpenAI's diarization model returns segments:

```ruby
transcription = RubyLLM.transcribe("meeting.wav", model: "gpt-4o-transcribe-diarize")

transcription.segments.each do |segment|
  puts "#{segment['speaker']}: #{segment['text']}"
  puts "#{segment['start']}s - #{segment['end']}s"
end
```

For Google's dedicated transcription model on Vertex AI, use `model: "{{ site.models.transcription_vertexai }}"`, `provider: :vertexai`, and set `vertexai_location` to `"global"` in [Configuration]({% link _getting_started/configuration-providers.md %}#vertex-ai-authentication-configuration).

### Identifying Known Speakers

OpenAI's diarization models can match speakers against 2–10 second reference clips:

```ruby
transcription = RubyLLM.transcribe(
  "team-meeting.wav",
  model: "gpt-4o-transcribe-diarize",
  speaker_names: ["Alice", "Bob"],
  speaker_references: ["alice-voice.wav", "bob-voice.wav"]
)
```

References accept file paths, URLs, IO objects, or Active Storage attachments. Other diarization providers assign speaker labels without matching known identities. ElevenLabs uses the number of supplied names as a speaker-count limit.

## Segments and Timestamps

Use `timestamps:` to request timing information:

```ruby
transcription = RubyLLM.transcribe(
  "interview.mp3",
  model: "{{ site.models.transcription_openai_timestamps }}",
  timestamps: [:word, :segment]
)

puts "Duration: #{transcription.duration} seconds"

transcription.words.each do |word|
  puts "#{word['start']}s - #{word['end']}s: #{word['word']}"
end
```

Available granularities depend on the model. Whisper accepts word and segment timestamps without streaming; Mistral accepts segment timestamps, including streaming. Deepgram, xAI, and ElevenLabs return word timing by default. ElevenLabs also accepts `timestamps: :character`.

## Output Formats

For models that produce subtitles, pass `format:`:

```ruby
transcription = RubyLLM.transcribe(
  "interview.mp3",
  model: "{{ site.models.transcription_openai_timestamps }}",
  format: "srt"
)
File.write("interview.srt", transcription.text)
```

Formats use the provider's names. Leave `format:` unset to get the model's default transcript.

## Streaming Transcripts

Pass a block to receive text as it is transcribed. The call returns the completed `Transcription`:

```ruby
transcription = RubyLLM.transcribe("meeting.wav", model: "gpt-4o-transcribe") do |chunk|
  print chunk.delta if chunk.delta?
end

puts transcription.text
```

| Predicate | What it carries |
| :--- | :--- |
| `chunk.partial?` | `chunk.text`, tentative text that replaces the previous partial |
| `chunk.delta?` | `chunk.delta`, committed text to append |
| `chunk.segment?` | `chunk.segment`, a Hash with speaker and timing fields |
| `chunk.done?` | `chunk.text`, the complete transcript when supplied by the endpoint |

Read the final transcript from `transcription.text`. `chunk.raw` holds the original event when you need additional fields.

Diarization models can stream speaker segments:

```ruby
RubyLLM.transcribe("meeting.wav", model: "gpt-4o-transcribe-diarize") do |chunk|
  next unless chunk.segment?

  puts "#{chunk.segment['speaker']}: #{chunk.segment['text']}"
end
```

### WebSocket Transcription

For Deepgram, ElevenLabs Scribe Realtime, xAI, and Google Live transcription, add the optional dependency:

```ruby
gem "websocket-driver"
```

Use the same block API with the appropriate streaming model:

```ruby
RubyLLM.transcribe(
  "meeting.wav",
  model: "{{ site.models.transcription_elevenlabs_realtime }}",
  provider: :elevenlabs,
  assume_model_exists: true
) do |chunk|
  print chunk.delta if chunk.delta?
end
```

These models have different input requirements:

| Provider | Model | Input |
| --- | --- | --- |
| Deepgram | `{{ site.models.transcription_deepgram }}` | Audio files, including MP3 and WAV |
| ElevenLabs | `{{ site.models.transcription_elevenlabs_realtime }}` | Mono WAV: 16-bit PCM at 8, 16, 22.05, 24, 44.1, or 48 kHz, or 8 kHz mu-law |
| xAI | `{{ site.models.transcription_xai }}` | WAV: 16-bit PCM or 8-bit G.711 |
| Gemini | `{{ site.models.transcription_gemini_live }}` | Mono 16-bit PCM WAV |
| Vertex AI | `{{ site.models.transcription_vertexai_live }}` | Mono 16-bit PCM WAV; `vertexai_location: "global"` |

Google Live returns text without speaker labels or word timestamps; use its dedicated file transcription model for those. Scribe Realtime returns word timing but does not diarize. These WebSocket connections do not support HTTP proxies.

The block processes an existing recording.

## Turning a Recording into Meeting Notes

Use the transcript as input to a chat:

```ruby
transcript = RubyLLM.transcribe "meeting.wav"
notes = RubyLLM.chat.ask "Summarize the decisions and action items:\n#{transcript.text}"
puts notes.content
```

For fields your application can process, add a schema with [Structured Output]({% link _core_features/structured-output.md %}). To make an audio summary, pass the notes to `RubyLLM.speak` and save the result.

## Longer Recordings and Errors

Long recordings may need a longer [request timeout]({% link _getting_started/configuration-connection.md %}#connection-settings). See [Error Handling]({% link _advanced/error-handling.md %}) for retries and provider failures.

## Next Steps

* [Chat]({% link _core_features/chat.md %}) - ask questions about a transcript.
* [Text to Speech]({% link _core_features/text-to-speech.md %}) - turn a summary into audio.
* [Structured Output]({% link _core_features/structured-output.md %}) - extract decisions, speakers, and action items.
