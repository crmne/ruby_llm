---
layout: default
title: Files
nav_order: 7
description: Upload, inspect, and download provider-managed files with a consistent Ruby API
---

# {{ page.title }}
{: .d-inline-block .no_toc }

v1.16.0+
{: .label .label-green }

{{ page.description }}
{: .fs-6 .fw-300 }

## Table of contents
{: .no_toc .text-delta }

1. TOC
{:toc}

---

After reading this guide, you will know:

*   How to upload files to a provider with `RubyLLM.upload_file`.
*   How to inspect uploaded file metadata with `RubyLLM::ProviderFile.file_info`.
*   How to download file contents as bytes or stream them to a destination.
*   How to use contexts for tenant-specific file operations.
*   How provider-managed files differ from chat attachments.

## Provider-Managed Files vs Chat Attachments

RubyLLM supports two different ways of working with files:

- Chat attachments use `with:` on `chat.ask` to send files as part of a prompt.
- Provider-managed files use `RubyLLM.upload_file` to create a file resource stored by the provider.

Use chat attachments when you want the model to analyze a file as part of a conversation. Use provider-managed files when the provider's API expects an uploaded file ID, or when you need to look up metadata or download the file later.

## Uploading a File

Upload a file with the global `RubyLLM.upload_file` helper. You must specify a `provider:` explicitly.

```ruby
uploaded = RubyLLM.upload_file(
  "spec/fixtures/openai_batch.jsonl",
  provider: :openai,
  purpose: "batch"
)

puts uploaded.id
puts uploaded.filename
puts uploaded.byte_size
puts uploaded.created_at
```

The return value is a `RubyLLM::ProviderFile` object containing provider metadata:

- `id`
- `filename`
- `byte_size`
- `created_at`

### OpenAI Upload Options

OpenAI file uploads currently support:

- `purpose:` — required by the OpenAI Files API
- `expires_after:` — optional expiration settings accepted by the API

```ruby
uploaded = RubyLLM.upload_file(
  "batch.jsonl",
  provider: :openai,
  purpose: "batch",
  expires_after: { anchor: "created_at", seconds: 86_400 }
)
```

> `purpose:` values and expiration settings are provider-specific. RubyLLM forwards them to the provider API.
{: .note }

## Looking Up File Metadata

Once a file is uploaded, you can retrieve its metadata later:

```ruby
uploaded = RubyLLM.upload_file("batch.jsonl", provider: :openai, purpose: "batch")

file_info = RubyLLM::ProviderFile.file_info(uploaded.id, provider: :openai)

puts file_info.id
puts file_info.filename
puts file_info.byte_size
puts file_info.created_at
```

## Downloading File Contents

Download file content with `RubyLLM.download_file`. By default, RubyLLM returns the raw response body.

```ruby
content = RubyLLM.download_file("file_123", provider: :openai)
File.binwrite("tmp/downloaded.jsonl", content)
```

### Downloading to a Path

Write the file directly to disk:

```ruby
saved_path = RubyLLM.download_file(
  "file_123",
  provider: :openai,
  path: "tmp/downloaded.jsonl"
)

puts saved_path
```

### Downloading to an IO Object

Stream the content into an existing IO object:

```ruby
File.open("tmp/downloaded.jsonl", "wb") do |io|
  RubyLLM.download_file("file_123", provider: :openai, io: io)
end
```

### Downloading to a Tempfile

Ask RubyLLM to manage a temporary file for you:

```ruby
file = RubyLLM.download_file("file_123", provider: :openai, tempfile: true)
puts file.path
puts file.read
file.close!
```

If you use block form, RubyLLM yields the tempfile and cleans it up afterward:

```ruby
RubyLLM.download_file("file_123", provider: :openai, tempfile: true) do |file|
  puts file.path
  puts file.read
end
```

## Provider Support

Provider-managed file uploads are currently implemented for OpenAI.

Support for other providers may be added over time.

## Notes and Limitations

- `provider:` is required for provider-managed file operations.
- Only one of `io:`, `path:`, or `tempfile: true` can be used for a download.
- Block form is supported with `io:` and `tempfile: true`, but not with `path:`.
- File retention, supported purposes, and size limits are determined by the provider API.
