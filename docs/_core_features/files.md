---
layout: default
title: Files
nav_order: 11
description: Upload provider-managed files for APIs that require file IDs
---

# {{ page.title }}
{: .d-inline-block .no_toc }

New in 2.0
{: .label .label-green }

{{ page.description }}
{: .fs-6 .fw-300 }

Provider-managed files are different from chat attachments. Use `with:` when a file belongs in the prompt. Use `RubyLLM.upload` when the provider API asks for a stored file ID or URI.

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

## Finding and Downloading

```ruby
file = RubyLLM::UploadedFile.find("file_123")
content = RubyLLM.download(file.id)
```

File IDs are provider-owned, so persist the provider alongside any file id you store and pass it back explicitly when reading later.

## Provider Notes

* **OpenAI:** stores files through the OpenAI Files API. `purpose:` is required.
* **Azure OpenAI / Foundry:** uses the OpenAI-compatible Files API under `/openai/v1`. `purpose:` is required.
* **Anthropic:** uses the beta Files API. Downloads only work for downloadable files, such as files created by skills or code execution.
* **Gemini:** uses the Gemini Files API. Uploaded files return a `files/...` id and `uri`.
* **Mistral:** uses the Mistral Files API. `purpose:` is optional but useful for batch, fine-tuning, and OCR.
* **xAI:** uses the xAI Files API. `purpose:` is not required; `expires_after:` is accepted.
* **Vertex AI:** uploads to Google Cloud Storage and returns a `gs://...` URI. Configure `vertexai_batch_gcs_uri`; add `google-cloud-storage` to your Gemfile when using uploads or downloads.
* **Bedrock:** uploads to S3 and returns an `s3://...` URI. Configure `bedrock_batch_s3_uri`; add `aws-sdk-s3` to your Gemfile when using uploads or downloads.
