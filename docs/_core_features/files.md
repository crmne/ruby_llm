---
layout: default
title: Files
nav_order: 11
description: Upload files once, reuse them in chats and batches, and download provider results.
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* How to upload a file and reuse it in a chat or batch.
* When RubyLLM uploads large chat attachments automatically.
* How to set expiration and download provider results.
* Which retention and download restrictions affect stored files.

Use `with:` to send a file with a question. Use `RubyLLM.upload` when you want to upload once and reuse the provider's file ID or URI across requests.

```ruby
file = RubyLLM.upload("report.pdf", provider: :anthropic)
chat = RubyLLM.chat(model: "{{ site.models.anthropic_current }}")
chat.ask "Summarize the financial risks.", with: file
```

RubyLLM can also upload large local attachments automatically when the provider supports stored file references in chat. See [Attachments]({% link _core_features/attachments.md %}) for sending files directly.

## Uploading

```ruby
file = RubyLLM.upload("batch.jsonl", purpose: "batch")

file.id         # => "file_..."
file.filename   # => "batch.jsonl"
file.byte_size  # => 1234
file.mime_type  # => "application/jsonl"
```

When `provider:` is omitted, RubyLLM uses the provider of `config.default_model`. Select another provider explicitly:

```ruby
file = RubyLLM.upload("document.pdf", provider: :anthropic)
```

You can pass a path, an IO object, or a `RubyLLM::Attachment`. For IO objects, pass `filename:` so the provider receives a useful name:

```ruby
io = StringIO.new(jsonl)
file = RubyLLM.upload(io, provider: :openai, purpose: "batch", filename: "batch.jsonl")
```

OpenAI and Azure require `purpose:`. Use `"batch"` for batch inputs, `"user_data"` for OpenAI documents, and `"assistants"` for Azure documents.

Vertex AI and Bedrock store files in a bucket rather than behind a file id. Pass `uri:` to choose the object, and `content_type:` when the MIME type RubyLLM detects is not the one you want:

```ruby
RubyLLM.upload("batch.jsonl", provider: :vertexai, uri: "gs://my-bucket/in/batch.jsonl")
```

Provider-specific options go through `provider_options:` in the provider's own vocabulary: `visibility:` on Mistral, `display_name:` on Gemini.

## Expiration

Pass `expires_in:` with a number of seconds to have the provider delete the file automatically:

```ruby
file = RubyLLM.upload("batch.jsonl", purpose: "batch", expires_in: 24 * 60 * 60)

file.expires_at # => 2026-07-05 12:00:00 +0000
```

OpenAI and xAI accept 1 hour to 30 days. Mistral rounds up to whole hours. Other providers may ignore `expires_in:`; Gemini files always expire after 48 hours.

## Using Files in Chat

Pass an uploaded file through `with:` to reuse it by provider-managed ID or URI:

```ruby
file = RubyLLM.upload("large-report.pdf", provider: :openai, purpose: "user_data")

chat = RubyLLM.chat(model: "{{ site.models.openai_current }}", provider: :openai)
chat.ask("Summarize the financial risks.", with: file)
```

## Large Chat Attachments

Automatic uploads are on by default. Set `config.auto_upload_large_files` to `false` to keep attachments inline:

```ruby
RubyLLM.configure do |config|
  config.auto_upload_large_files = false
end
```

Automatic uploads require a provider that supports stored attachments. Vertex AI and Bedrock also need a [configured storage bucket]({% link _getting_started/configuration-providers.md %}#batch-processing). Uploading separately does not remove the model's input or context limits.

## Finding and Downloading

```ruby
file = RubyLLM::UploadedFile.find("file_123", provider: :openai)
RubyLLM.download(file.id, provider: :openai).save("report.pdf")
```

`download` returns a `RubyLLM::DownloadedFile`. Use `save` to write it to disk or `to_blob` to read its bytes. It is also a Ruby String, so you can pass it directly to a parser or process it with `each_line`.

File IDs are provider-owned, so persist the provider alongside any file id you store and pass it back explicitly when reading later.

## ElevenLabs Media Assets

Upload an image once and reuse it in image or video generation:

```ruby
logo = RubyLLM.upload "logo.png", provider: :elevenlabs

image = RubyLLM.paint(
  "Place this logo on a white coffee mug",
  with: logo,
  model: "{{ site.models.image_elevenlabs }}",
  provider: :elevenlabs,
  assume_model_exists: true
)

image.save "mug.png"
```

ElevenLabs media assets require the [Image & Video plan and permissions]({% link _getting_started/configuration-providers.md %}#media-generation). They are separate from voice-agent knowledge base documents.

## Cohere Datasets

Upload CSV or JSONL data with a dataset type as its purpose:

```ruby
dataset = RubyLLM.upload(
  "documents.jsonl",
  provider: :cohere,
  purpose: "embed-input",
  provider_options: { name: "documents", keep_fields: ["document_id"] }
)

content = RubyLLM.download(dataset.id, provider: :cohere)
```

Cohere validates datasets asynchronously; downloading waits for validation. Uploaded datasets download as the original file by default. Generated datasets and uploads made with `keep_original_file: false` download as JSONL and require `gem "avro"`.

Datasets are separate from chat attachments and expire after 30 days. For [chat and embedding batches]({% link _advanced/batches.md %}#batching-embeddings), `RubyLLM.batch` prepares the datasets for you.

## Downloading Generated Files

A conversation can return generated files as attachments:

```ruby
response = RubyLLM.chat(model: "{{ site.models.mistral_server_tools }}",
                        provider: :mistral, protocol: :conversations)
                 .with_server_tools(:code_execution)
                 .ask("Create a CSV of the first ten squares as a downloadable file.")

file = response.attachments.first.source
RubyLLM.download(file.id, provider: file.provider).save(file.filename)
```

Keep the complete file ID and its provider when storing the reference. For generated images, [use `paint`]({% link _core_features/image-generation.md %}) to save the result directly.

## Download Restrictions

DeepSeek does not allow downloading uploaded images. Perplexity supports downloads of generated Agent files, without general file uploads.

Downloads depend on the provider. Anthropic and OpenRouter only allow downloading files created server-side; uploaded files are not downloadable through their Files APIs.
