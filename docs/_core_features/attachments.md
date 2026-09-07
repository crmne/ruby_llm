---
layout: default
title: Attachments
parent: "Chat"
nav_order: 1
description: Ask questions about images, recordings, videos, and documents through one attachment API.
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* How to attach images, video, audio, text files, and PDFs to a message.
* How to send local files and remote URLs through the `with:` parameter.
* How RubyLLM detects file types automatically.
* When to use in-prompt attachments versus provider-managed file IDs.

## Attaching Files

Send files alongside your question with `with:`. Choose a model that accepts the file's input type; the [Models]({% link _reference/available-models.md %}) page lets you filter by input modality.

```ruby
chat = RubyLLM.chat(model: "{{ site.models.gemini_current }}")
response = chat.ask "What happens in this video?", with: "demo.mp4"
puts response.content
```

RubyLLM can upload large local attachments automatically. To upload once and reuse a file across requests, see [Files]({% link _core_features/files.md %}).
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

Ask a video-capable model about local videos or URLs:

```ruby
chat = RubyLLM.chat(model: '{{ site.models.gemini_current }}')
response = chat.ask "What happens in this video?", with: "path/to/demo.mp4"
puts response.content

response = chat.ask "Summarize the main events in this video.", with: "https://example.com/demo_video.mp4"
puts response.content

response = chat.ask "Analyze these files for visual content.", with: ["diagram.png", "demo.mp4", "notes.txt"]
puts response.content
```

### Working with Audio

Audio-capable models can answer questions about a recording:

```ruby
chat = RubyLLM.chat(model: '{{ site.models.openai_audio }}')

response = chat.ask "Please transcribe this meeting recording.", with: "path/to/meeting.mp3"
puts response.content

response = chat.ask "What were the main action items discussed?"
puts response.content
```

For a transcript without a conversation, use [Audio Transcription]({% link _core_features/audio-transcription.md %}).

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

Ask about a report, manual, or research paper with a model that accepts PDFs:

```ruby
chat = RubyLLM.chat(model: '{{ site.models.anthropic_newest }}')

response = chat.ask "Summarize the key findings in this research paper.", with: "path/to/paper.pdf"
puts response.content

response = chat.ask "What are the terms and conditions outlined here?", with: "https://example.com/terms.pdf"
puts response.content

response = chat.ask "Based on section 3 of this document, what is the warranty period?", with: "manual.pdf"
puts response.content
```

Documents still have to fit the model's context limit, even when uploaded separately.
{: .note }

### Working with Office Documents

Word documents, presentations, and spreadsheets attach the same way when the selected model and provider support them:

```ruby
chat = RubyLLM.chat(model: '{{ site.models.openai_current }}')

response = chat.ask "What is the project codename in this document?", with: "brief.docx"
response = chat.ask "Which region had the highest revenue?", with: "sales.xlsx"
```

Providers without native document support raise `RubyLLM::UnsupportedAttachmentError`. Convert those files to PDF or text first.
{: .note }

### Automatic File Type Detection

RubyLLM automatically detects file types based on extensions and content, so you can pass files directly without specifying the type:

```ruby
chat = RubyLLM.chat(model: '{{ site.models.gemini_current }}')

response = chat.ask "What's in this file?", with: "path/to/document.pdf"

# Multiple files of different types
response = chat.ask "Analyze these files", with: [
  "diagram.png",
  "report.pdf",
  "meeting_notes.txt",
  "recording.mp3"
]
```

**Recognized file types:**

- **Images:** .jpg, .jpeg, .png, .gif, .webp, .bmp
- **Videos:** .mp4, .mov, .avi, .webm
- **Audio:** .mp3, .wav, .m4a, .ogg, .flac
- **Documents:** .pdf, .txt, .md, .csv, .json, .xml
- **Code:** .rb, .py, .js, .html, .css (and many others)

## Next Steps

* [Chat]({% link _core_features/chat.md %}) - continue a conversation about your files.
* [Files]({% link _core_features/files.md %}) - upload files once and reuse them by provider-managed ID.
* [Advanced Request Control]({% link _core_features/chat-request-control.md %}) - control model requests.
* [Audio Transcription]({% link _core_features/audio-transcription.md %}) - turn recordings into transcripts.
