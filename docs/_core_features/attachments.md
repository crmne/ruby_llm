---
layout: default
title: Attachments
parent: "Chat"
nav_order: 1
description: Attach images, video, audio, text files, and PDFs to a chat message with a single unified interface
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

* How to attach images, video, audio, text files, and PDFs to a message.
* How to send local files and remote URLs through the `with:` parameter.
* How RubyLLM detects file types automatically.
* What provider-specific limits apply to each input type.
* When to use in-prompt attachments versus provider-managed file IDs.

## Attaching Files

Send images, audio, video, documents, and other files to a model alongside your question. RubyLLM takes them all through one `with:` parameter, whatever the provider underneath.

The attachments described here travel inline with the request. To upload a file once and reuse it across many requests by reference, use provider-managed file IDs instead - see [Files]({% link _core_features/files.md %}).
{: .note }

### Working with Images

Vision-capable models can analyze images, answer questions about visual content, and even compare multiple images.

```ruby
chat = RubyLLM.chat(model: '{{ site.models.openai_vision }}')

response = chat.ask "Describe this logo.", with: "path/to/ruby_logo.png"
puts response.content

response = chat.ask "What kind of architecture is shown here?", with: "https://example.com/eiffel_tower.jpg"
puts response.content

response = chat.ask "Compare the user interfaces in these two screenshots.", with: ["screenshot_v1.png", "screenshot_v2.png"]
puts response.content
```

### Working with Videos

You can also analyze video files or URLs with video-capable models. RubyLLM will automatically detect video files and handle them appropriately.

```ruby
chat = RubyLLM.chat(model: 'gemini-2.5-flash')
response = chat.ask "What happens in this video?", with: "path/to/demo.mp4"
puts response.content

response = chat.ask "Summarize the main events in this video.", with: "https://example.com/demo_video.mp4"
puts response.content

response = chat.ask "Analyze these files for visual content.", with: ["diagram.png", "demo.mp4", "notes.txt"]
puts response.content
```

Supported video formats include .mp4, .mov, .avi, .webm, and others (provider-dependent).

Only Google Gemini and VertexAI models currently support video input.

Large video files may be subject to size or duration limits imposed by the provider.
{: .note }

RubyLLM automatically handles image encoding and formatting for each provider's API. Local images are read and encoded as needed, while URLs are passed directly when supported by the provider.

### Working with Audio

Audio-capable models can transcribe speech, analyze audio content, and answer questions about what they hear. Currently, models like `{{ site.models.openai_audio }}` and Google's `gemini-2.5` series of models support audio input.

```ruby
chat = RubyLLM.chat(model: '{{ site.models.openai_audio }}') # Use an audio-capable model

response = chat.ask "Please transcribe this meeting recording.", with: "path/to/meeting.mp3"
puts response.content

response = chat.ask "What were the main action items discussed?"
puts response.content

gemini_chat = RubyLLM.chat(model: 'gemini-2.5-flash')
response = gemini_chat.ask "Summarize this podcast.", with: "path/to/podcast.mp3"
puts response.content
```

### Working with Text Files

You can provide text files directly to models for analysis, summarization, or question answering. This works with any text-based format including plain text, code files, CSV, JSON, and more.

```ruby
chat = RubyLLM.chat(model: '{{ site.models.anthropic_current }}')

response = chat.ask "Summarize the key points in this document.", with: "path/to/document.txt"
puts response.content

response = chat.ask "Explain what this Ruby file does.", with: "app/models/user.rb"
puts response.content
```

### Working with PDFs

PDF support allows models to analyze complex documents including reports, manuals, and research papers. Currently, Claude 3+ and Gemini models offer the best PDF support.

```ruby
chat = RubyLLM.chat(model: '{{ site.models.anthropic_newest }}')

response = chat.ask "Summarize the key findings in this research paper.", with: "path/to/paper.pdf"
puts response.content

response = chat.ask "What are the terms and conditions outlined here?", with: "https://example.com/terms.pdf"
puts response.content

response = chat.ask "Based on section 3 of this document, what is the warranty period?", with: "manual.pdf"
puts response.content
```

Be mindful of provider-specific limits. For example, Anthropic Claude models currently have a 10MB per-file size limit, and the total size/token count of all PDFs must fit within the model's context window (e.g., 200,000 tokens for Claude 3 models).
{: .note }

### Automatic File Type Detection

RubyLLM automatically detects file types based on extensions and content, so you can pass files directly without specifying the type:

```ruby
chat = RubyLLM.chat(model: '{{ site.models.anthropic_current }}')

response = chat.ask "What's in this file?", with: "path/to/document.pdf"

# Multiple files of different types
response = chat.ask "Analyze these files", with: [
  "diagram.png",
  "report.pdf",
  "meeting_notes.txt",
  "recording.mp3"
]

# Still works with the explicit hash format if needed
response = chat.ask "What's in this image?", with: { image: "photo.jpg" }
```

**Supported file types:**
- **Images:** .jpg, .jpeg, .png, .gif, .webp, .bmp
- **Videos:** .mp4, .mov, .avi, .webm
- **Audio:** .mp3, .wav, .m4a, .ogg, .flac
- **Documents:** .pdf, .txt, .md, .csv, .json, .xml
- **Code:** .rb, .py, .js, .html, .css (and many others)

## Next Steps

* [Chat]({% link _core_features/chat.md %}) - the core conversation interface these attachments ride on.
* [Files]({% link _core_features/files.md %}) - upload files once and reuse them by provider-managed ID.
* [Advanced Request Control]({% link _core_features/chat-request-control.md %}) - shape the request payload for provider-specific features.
* [Audio Transcription]({% link _core_features/audio-transcription.md %}) - dedicated speech-to-text endpoints.
