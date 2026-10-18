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
* How to trade tokens for detail with `resolution:`.
* How to let a model navigate a long video with `processing:`.
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

### Attachment Security

String sources are instructions to read a local file or fetch a URL. Only pass paths and URLs that your application trusts and the current user is authorized to access. RubyLLM does not restrict them to a directory or public network addresses. Reading can begin during attachment construction to detect the file type.

RubyLLM follows up to five HTTP or HTTPS redirects when it fetches a URL, never from HTTPS to plain HTTP, so a URL you trust can lead to another host. Checking a URL's host before you pass it does not limit where the download ends. A download that ends on a redirect raises `RubyLLM::Error`.

Passing an unchecked upload parameter to `with:` or `RubyLLM::Attachment.new` lets a user supply a URL or server-side path instead of a file. This can expose internal services through server-side request forgery (SSRF), or disclose local files when their contents are sent to a model. The same restriction applies to file inputs for standalone operations such as `RubyLLM.upload` and `RubyLLM.transcribe`.

For browser uploads, validate that each value is an actual uploaded file before passing it to RubyLLM. The [Rails persistence example]({% link _advanced/rails-persistence.md %}#attachments-and-structured-output) shows this check. For stored files, load attachments through records the current user is authorized to access.

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

### Converting Unsupported Attachments

Register a converter when you want the same conversation to work across protocols with different document formats:

```ruby
require "stringio"

chat.convert_unsupported_attachments do |attachment|
  text = TextExtraction.call(attachment)
  RubyLLM::Attachment.new(StringIO.new(text), filename: "extracted.txt") if text
end

chat.ask "Summarize this report.", with: "report.docx"
```

`TextExtraction` is your application's converter. The callback receives the original `RubyLLM::Attachment` and returns a replacement attachment. Return `nil` when you cannot convert it; RubyLLM keeps the protocol's existing error. A replacement must itself be supported. Errors from your converter propagate to the caller.

Callbacks run in registration order until one returns a replacement. A chat converts each attachment once and reuses the replacement, including its provider upload, on later requests. A persisted chat loaded in another process converts again, so cache expensive conversions in your application. The conversation keeps the original attachment. Switching to a protocol that supports the original file sends that file without calling the converter. Persisted chats and agents use the same callback.

If the provider deletes an uploaded replacement, RubyLLM uploads the cached replacement again and retries the request once. It does not call your converter again or retry after streaming has reached your application.

This handles formats the protocol cannot send. A model can still reject an attachment the protocol can represent; that API error does not trigger the callback.

### Keeping Attachments Out of the Conversation

Every attachment travels with the conversation, so a long PDF attached to the first question is sent again with every later one. With [chat files]({% link _core_features/chat-files.md %}), the model sees a file in full on the question it came with, and one line naming it after that. It reads the parts it needs with its `read_file` and `search_files` tools:

```ruby
chat = RubyLLM.chat.with_file_store
chat.ask "Summarize this report.", with: "report.pdf"
chat.ask "What does it say about churn?" # the model searches report.pdf instead of rereading it
```

With a converter registered for a format, such as the OCR converter for PDFs and scans, the same tools read it as text, so they work with models that cannot take that format.

### Choosing the Media Resolution

Small print and dense tables need more detail than a photo of a cat. Build the attachment yourself and set `resolution:` to control how many tokens the model spends on it:

```ruby
page = RubyLLM::Attachment.new("page-3.png", resolution: :original)
chat.ask "Where is the revenue figure?", with: page
```

The values are `:low`, `:medium`, `:high`, `:ultra_high`, and `:original`. Each attachment keeps its own setting, so one message can mix a high-detail page with low-detail thumbnails. Leave it unset to use the provider's default. Persisted chats keep the setting, so later turns and background jobs send the same detail.

Gemini applies the setting to images, videos, and PDFs, sending `:high` for videos and PDFs when you ask for `:ultra_high`. OpenAI, Azure, OpenRouter, and xAI apply it to images, sending `:low` as low detail and `:medium`, `:high`, and `:ultra_high` as high detail. Other providers ignore it, since it is a quality hint rather than a requirement.

For `:original`, OpenAI and Azure send `detail: "original"`. RubyLLM passes the request through without checking the model; a model that does not support original detail returns an API error. Gemini treats `:original` like `:ultra_high`, using its highest setting for the attachment type. OpenRouter and xAI use high detail, and other providers ignore it.

### Choosing How a Model Watches a Video

A model usually samples a video at one frame per second and reads every frame before it answers. For an hour-long lecture, that fills most of the context window, even when the question is about one moment. Set `processing: :agentic` to let the model navigate the video instead:

```ruby
lecture = RubyLLM::Attachment.new("lecture.mp4", processing: :agentic)
chat = RubyLLM.chat(model: "{{ site.models.gemini_agentic_video }}")
chat.ask "When does the speaker introduce recursion?", with: lecture
```

The model reads the transcript first, then loads only the frames and audio it needs. `:static` samples the whole video up front. Leave it unset to use the provider's default, which is static. Each video keeps its own setting, so one message can mix an agentic lecture with a static clip.

Persisted chats keep the setting in the metadata of the file RubyLLM stores for the message, so later turns and background jobs send the same mode. A file already in Active Storage is attached as it is, so a reloaded chat reads the mode from that blob's own metadata. Set it on the blob as well as on the attachment:

```ruby
blob = lesson.video.blob
blob.update!(metadata: blob.metadata.merge("processing" => "agentic"))

chat = Chat.create!(model: "{{ site.models.gemini_agentic_video }}")
chat.ask "When does the speaker introduce recursion?",
         with: RubyLLM::Attachment.new(blob, processing: :agentic)
```

Blob metadata is shared, so every chat that attaches the blob replays it with that mode.

Agentic processing suits long videos and questions about specific moments. Short clips answer faster with static processing. Navigating a long video takes time, so stream the response to keep the connection active while the model works.

The frames and audio the model loads count as input tokens, so `response.tokens` and `response.cost` include them.

Gemini applies the setting to videos alongside `resolution:`. Other providers ignore it. Through the [Interactions protocol]({% link _core_features/chat-request-control.md %}#choosing-the-wire-protocol), `response.server_tool_calls` lists each step the model took, and RubyLLM sends the steps back on the next turn, so a follow-up question reuses what the model already loaded:

```ruby
chat = RubyLLM.chat(model: "{{ site.models.gemini_agentic_video }}", protocol: :interactions)
chat.ask "When does the speaker introduce recursion?", with: lecture
chat.ask "What example does the speaker use?"
```

Gemini's default protocol does not accept the steps back, so the model navigates the video again when a follow-up needs it.

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
