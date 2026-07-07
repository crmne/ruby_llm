---
layout: default
title: Audio Transcription
nav_order: 5
description: Convert speech to text with support for multiple languages and speaker diarization
redirect_from:
  - /guides/audio-transcription
  - /guides/transcription
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

*   How to transcribe audio files to text.
*   How to identify different speakers with diarization.
*   How to improve accuracy with language hints and prompts.
*   How to access segments and timestamps.

## Basic Transcription

Transcribe audio with the global `RubyLLM.transcribe` method:

```ruby
transcription = RubyLLM.transcribe("meeting.wav")

puts transcription.text
# => "Welcome to today's meeting. Let's discuss..."

puts transcription.model
# => "whisper-1"
```

Supports MP3, M4A, WAV, WebM, OGG, and more.

## Choosing Models

```ruby
# Whisper-1 (default, good for general use)
RubyLLM.transcribe("audio.mp3", model: "whisper-1")

# GPT-4o Transcribe (faster, better for technical content)
RubyLLM.transcribe("audio.mp3", model: "gpt-4o-transcribe")

# GPT-4o Mini Transcribe (fastest, lowest cost)
RubyLLM.transcribe("audio.mp3", model: "gpt-4o-mini-transcribe")

# Diarization model (identifies speakers)
RubyLLM.transcribe("meeting.wav", model: "gpt-4o-transcribe-diarize")

# Gemini 2.5 Flash/Pro (Google's multimodal transcription)
RubyLLM.transcribe(
  "lecture.wav",
  model: "gemini-2.5-flash",
  prompt: "Return only the verbatim transcript."
)
```

Configure the default globally:

```ruby
RubyLLM.configure do |config|
  config.default_transcription_model = "gpt-4o-transcribe"
end
```

## Language Hints

Improve accuracy by specifying the language:

```ruby
RubyLLM.transcribe("entrevista.mp3", language: "es")
RubyLLM.transcribe("conference.mp3", language: "fr")
```

Use ISO 639-1 codes (en, es, fr, de, etc.).

`RubyLLM.transcribe` keeps the transcription vocabulary as keywords: `model:`, `language:`, `prompt:`, `temperature:`, `format:`, `speaker_names:`, and `speaker_references:`. Providers ignore the keywords they do not support. Everything specific to one provider goes in `provider_options:`, a hash of options in the provider's own request vocabulary that RubyLLM merges into the rendered request as-is.

## Output Formats

The `format:` keyword selects the shape of the transcript you get back, using the provider's own values.

OpenAI accepts `json`, `text`, `srt`, `vtt`, `verbose_json`, and `diarized_json`:

```ruby
RubyLLM.transcribe("interview.mp3", model: "whisper-1", format: "srt")
```

Gemini takes a MIME type:

```ruby
RubyLLM.transcribe("lecture.wav", model: "gemini-2.5-flash", format: "application/json")
```

When you omit `format:`, OpenAI's diarization models default to `diarized_json`, Gemini defaults to `text/plain`, and other OpenAI models use the API's default.

## Speaker Diarization

The diarization model identifies different speakers:

```ruby
transcription = RubyLLM.transcribe(
  "team-meeting.wav",
  model: "gpt-4o-transcribe-diarize"
)

transcription.segments.each do |segment|
  puts "#{segment['speaker']}: #{segment['text']}"
  puts "  (#{segment['start']}s - #{segment['end']}s)"
end
# Output:
# A: Hi everyone.
#   (0.5s - 1.2s)
# B: Happy to be here.
#   (2.8s - 3.5s)
```

### Identifying Known Speakers

Map speakers to names with the `speaker_names:` and `speaker_references:` keywords. Provide 2-10 second reference clips:

```ruby
transcription = RubyLLM.transcribe(
  "team-meeting.wav",
  model: "gpt-4o-transcribe-diarize",
  speaker_names: ["Alice", "Bob"],
  speaker_references: ["alice-voice.wav", "bob-voice.wav"]
)

# Alice: Hi everyone.
# Bob: Happy to be here.
```

Speaker references accept file paths, URLs, IO objects, or ActiveStorage attachments. Only OpenAI's diarization models use speaker names and references today; other providers ignore them.

OpenAI's diarization models also send `chunking_strategy: "auto"` by default. Override it in OpenAI's own request shape through `provider_options:`:

```ruby
RubyLLM.transcribe(
  "team-meeting.wav",
  model: "gpt-4o-transcribe-diarize",
  provider_options: { chunking_strategy: { type: "server_vad", threshold: 0.5 } }
)
```

> **Note:** Gemini models currently return plain text transcripts without segment metadata. Use OpenAI's diarization models when you need speaker labels or timestamps.

## Improving Accuracy with Prompts

Guide the model with context about technical terms or domain-specific vocabulary:

```ruby
RubyLLM.transcribe(
  "developer-talk.mp3",
  prompt: "Discussion about Ruby, Rails, PostgreSQL, and Redis."
)

RubyLLM.transcribe(
  "product-demo.mp3",
  prompt: "Product demo for ZyntriQix, Digique Plus, and CynapseFive."
)
```

### Gemini prompt tips

Gemini treats transcription requests like any other conversation. Use the `prompt:` argument to steer formatting (for example, "Respond with plain text only."), and combine it with `language:` when you want a specific locale in the final transcript. RubyLLM automatically adds the language hint to the Gemini request.

Use `format:` to pick the response MIME type. Everything else goes through `provider_options:` in Gemini's own request shape:

```ruby
RubyLLM.transcribe(
  "lecture.wav",
  model: "gemini-2.5-flash",
  provider_options: {
    generationConfig: { maxOutputTokens: 2048 },
    safetySettings: [
      { category: "HARM_CATEGORY_HARASSMENT", threshold: "BLOCK_NONE" }
    ]
  }
)
```

## Segments and Timestamps

Access detailed timing information:

```ruby
transcription = RubyLLM.transcribe("interview.mp3", model: "gpt-4o-transcribe")

puts "Duration: #{transcription.duration} seconds"

transcription.segments.each do |segment|
  puts "#{segment['start']}s - #{segment['end']}s: #{segment['text']}"
end
```

For OpenAI word-level timestamps, request the `verbose_json` format and word granularity:

```ruby
transcription = RubyLLM.transcribe(
  "interview.mp3",
  model: "whisper-1",
  provider: :openai,
  format: "verbose_json",
  provider_options: { timestamp_granularities: ["word"] }
)

transcription.words.each do |word|
  puts "#{word['start']}s - #{word['end']}s: #{word['word']}"
end
```

## Handling Longer Files

The default timeout is 5 minutes. Increase it for longer audio:

```ruby
RubyLLM.configure do |config|
  config.request_timeout = 600 # 10 minutes
end
```

The API supports files up to 25 MB. For larger files, use compressed formats (MP3, M4A) or split into chunks.

## Error Handling

```ruby
begin
  transcription = RubyLLM.transcribe("audio.mp3")
  puts transcription.text
rescue RubyLLM::BadRequestError => e
  puts "Invalid request: #{e.message}"
rescue RubyLLM::TimeoutError => e
  puts "Transcription timed out: #{e.message}"
rescue RubyLLM::Error => e
  puts "Transcription failed: #{e.message}"
end
```

## Next Steps

*   [Chatting with AI Models]({% link _core_features/chat.md %}): Learn about conversational AI.
*   [Image Generation]({% link _core_features/image-generation.md %}): Generate images from text.
*   [Error Handling]({% link _advanced/error-handling.md %}): Master handling API errors.
