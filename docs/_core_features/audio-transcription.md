---
layout: default
title: Audio Transcription
nav_order: 6
description: Convert speech to text with support for multiple languages and speaker diarization
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

Provide 2-10 second reference clips to map speakers to names:

```ruby
transcription = RubyLLM.transcribe(
  "team-meeting.wav",
  model: "gpt-4o-transcribe-diarize",
  speaker_names: ["Alice", "Bob"],
  speaker_references: ["alice-voice.wav", "bob-voice.wav"]
)

# Now segments use the provided names
# Alice: Hi everyone.
# Bob: Happy to be here.
```

Speaker references accept file paths, URLs, IO objects, or ActiveStorage attachments.

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

## Segments and Timestamps

Access detailed timing information:

```ruby
transcription = RubyLLM.transcribe("interview.mp3", model: "gpt-4o-transcribe")

puts "Duration: #{transcription.duration} seconds"

transcription.segments.each do |segment|
  puts "#{segment['start']}s - #{segment['end']}s: #{segment['text']}"
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
