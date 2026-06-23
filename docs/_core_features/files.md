---
layout: default
title: Files
nav_order: 7
description: Upload provider-managed files for APIs that require file IDs
---

# {{ page.title }}
{: .d-inline-block .no_toc }

New in 2.0
{: .label .label-green }

{{ page.description }}
{: .fs-6 .fw-300 }

Provider-managed files are different from inline chat attachments. Use `with:` for normal prompt files. RubyLLM automatically promotes large eligible local attachments to provider-managed files when the selected provider can reference stored files in chat. Use `RubyLLM.upload` when you want to upload once and reuse the same provider file ID or URI yourself.

## Uploading

```ruby
file = RubyLLM.upload("batch.jsonl", purpose: "batch")

file.id         # => "file_..."
file.filename   # => "batch.jsonl"
file.byte_size  # => 1234
file.mime_type  # => "application/jsonl"
```

When `provider:` is omitted, RubyLLM uses the provider of `config.default_model`, the same model resolution path as `RubyLLM.chat`. Pass `provider:` when the file belongs to a different provider:

```ruby
file = RubyLLM.upload("document.pdf", provider: :anthropic)
```

You can pass a path, an IO object, or a `RubyLLM::Attachment`. For IO objects, pass `filename:` so the provider receives a useful name:

```ruby
io = StringIO.new(jsonl)
file = RubyLLM.upload(io, provider: :openai, purpose: "batch", filename: "batch.jsonl")
```

OpenAI and Azure require `purpose:` because their Files API requires it: `assistants`, `batch`, `fine-tune`, `vision`, `user_data`, or `evals`. Mistral accepts `purpose:` for batch, fine-tuning, and OCR workflows. Other providers infer the file use from the API call that later references the file.

## Using Files in Chat

Pass an uploaded file through `with:` to reuse it by provider-managed ID or URI:

```ruby
file = RubyLLM.upload("large-report.pdf", provider: :openai, purpose: "user_data")

chat = RubyLLM.chat(model: "gpt-5-nano", provider: :openai)
chat.ask("Summarize the financial risks.", with: file)
```

For Gemini and Vertex AI, uploaded files are referenced by URI:

```ruby
file = RubyLLM.upload("demo.mp4", provider: :gemini)

chat = RubyLLM.chat(model: "gemini-2.5-flash", provider: :gemini)
chat.ask("What happens in this video?", with: file)
```

## Large Chat Attachments

When `config.auto_upload_large_files` is true, RubyLLM uploads oversized local attachments before storing the message and replaces them with a provider-managed file reference. The original chat message then contains the provider file ID or URI instead of inline bytes.

```ruby
RubyLLM.configure do |config|
  config.auto_upload_large_files = true
end
```

Automatic uploads are enabled only for providers and protocols that can reference stored files in chat. Other providers keep their existing inline behavior and still raise provider errors when a request exceeds that provider's limits.

## Finding and Downloading

```ruby
file = RubyLLM::UploadedFile.find("file_123")
content = RubyLLM.download(file.id)
```

File IDs are provider-owned, so persist the provider alongside any file id you store and pass it back explicitly when reading later.

## Provider Notes

| Provider | Files API limit | Chat file references | Automatic large attachments |
| --- | --- | --- | --- |
| OpenAI | 512 MB per file; `purpose:` required | PDF files by `file_id` in Responses and Chat Completions | PDFs above 50 MB, uploaded with `purpose: "user_data"` |
| Azure OpenAI / Foundry | 512 MB per API upload for assistants and fine-tuning; `purpose:` required | Upload/find/download only; Azure chat file references are not enabled | No |
| Anthropic | 500 MB per file; beta Files API | Images, PDFs, and text files by `file_id` | Images, PDFs, and text files above 24 MB |
| Gemini | 2 GB per file, 20 GB per project, 48-hour retention | Media, PDFs, and text files by Files API URI | Supported attachments above 20 MB |
| Mistral | 512 MB per file | Upload/find/download for batch, fine-tuning, OCR, and retrieval workflows | No |
| xAI | 48 MB per file | Upload/find/download only in RubyLLM's current xAI Chat Completions protocol | No |
| OpenRouter | 100 MB per file | PDF files by `file_id` in Chat Completions file parts | PDFs above 50 MB |
| Vertex AI | Google Cloud Storage backed; Gemini `fileData` supports large `gs://` inputs | Gemini models by `gs://` URI; batch workflows also use GCS | Supported Gemini attachments above 7 MB |
| Bedrock | S3 backed | Supported Converse document formats by S3 URI | Supported documents above 4.5 MB |
| DeepSeek, GPUStack, Ollama, Perplexity | No provider-managed Files API in RubyLLM | Inline/provider-specific attachment behavior only | No |

Downloads depend on the provider. Anthropic and OpenRouter only allow downloading files created server-side; uploaded files are not downloadable through their Files APIs.
