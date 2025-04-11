---
layout: default
title: Audio Transcription
parent: Guides
nav_order: 8
permalink: /guides/audio-transcription
---

# Audio Transcription

RubyLLM makes it easy to transcribe audio content using AI models. This guide covers how to convert speech to text using transcription models.

## Basic Transcription

The simplest way to convert speech to text is using the global `transcribe` method with only a local audio file path:

```ruby
# Transcribe an audio file
text = RubyLLM.transcribe("meeting.wav")

# Print the transcribed text
puts text
```

This method automatically uses the default transcription model (whisper-1) to convert the audio file to text.

## Specifying a Language

If you know the language in the audio, you can provide a hint to improve transcription accuracy:

```ruby
# Transcribe Spanish audio
spanish_text = RubyLLM.transcribe("entrevista.mp3", language: "Spanish")
```

## Choosing Models

You can specify which model to use for transcription:

```ruby
# Use a specific model
text = RubyLLM.transcribe(
  "interview.mp3",
  model: "whisper-1"
)
```

You can configure the default transcription model globally:

```ruby
RubyLLM.configure do |config|
  config.default_transcription_model = "whisper-1"
end
```

## Working with Large Files

For longer audio files, be aware of potential timeout issues. You can set a global timeout in your application configuration:

```ruby
RubyLLM.configure do |config|
  # Set a longer timeout for large files (in seconds)
  config.request_timeout = 300
end
```

Currently, RubyLLM doesn't support per-request timeout configuration. For handling very large files, you may need to increase the global timeout or consider breaking up the audio into smaller segments.

## Next Steps

Now that you understand audio transcription, you might want to explore:

- [Error Handling]({% link guides/error-handling.md %}) for robust applications
- [Tools]({% link guides/tools.md %}) to extend AI capabilities