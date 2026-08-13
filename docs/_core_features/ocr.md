---
layout: default
title: Document OCR
nav_order: 9
description: Extract text, tables, and images from PDFs and scans as clean markdown
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

*   How to extract the text of a PDF or image as markdown.
*   How to work with individual pages, tables, and embedded images.
*   How to process specific pages and tune the output with provider options.

## Basic OCR

Extract a document with the global `RubyLLM.ocr` method:

```ruby
ocr = RubyLLM.ocr("contract.pdf")

puts ocr.markdown
# => "# Service Agreement\n\nThis agreement is made between..."

puts ocr.model
# => "mistral-ocr-latest"
```

The file may be a local path, an `http(s)` URL, an IO object, or a `RubyLLM::Attachment`. Local files are inlined into the request; URLs are passed to the provider as-is, so the file must be publicly reachable.

PDFs, office documents (DOCX, PPTX), and images (PNG, JPEG, AVIF) are supported. Mistral Document AI is the only OCR provider today.

## Working with Pages

`RubyLLM.ocr` returns a `RubyLLM::OCR` result. `#markdown` joins every page; `#pages` gives you each page separately:

```ruby
ocr = RubyLLM.ocr("annual-report.pdf")

ocr.pages.each do |page|
  puts "Page #{page.index}"
  puts page.markdown
end
```

Each page carries:

*   `index`: the zero-based page number.
*   `markdown`: the extracted text as markdown.
*   `images`: the images found on the page, with coordinates.
*   `tables`: the tables found on the page, when the provider extracts them separately.
*   `raw`: the provider's unmodified page hash, including any fields beyond these.

The result also exposes `usage`, the provider's usage block for the request, and `raw`, the full response:

```ruby
ocr.usage
# => {"pages_processed" => 12, "doc_size_bytes" => 483210}
```

## Choosing Models

`mistral-ocr-latest` is the default. Pin a specific version with `model:`:

```ruby
RubyLLM.ocr("scan.png", model: "mistral-ocr-2512")
```

Configure the default globally:

```ruby
RubyLLM.configure do |config|
  config.default_ocr_model = "mistral-ocr-latest"
end
```

## Processing Specific Pages

Every keyword beyond `model:` and `provider:` passes through to the request in the provider's own vocabulary. Mistral takes `pages:` with zero-based page numbers:

```ruby
ocr = RubyLLM.ocr("annual-report.pdf", pages: [0, 1, 2])

ocr.usage["pages_processed"]
# => 3
```

## Provider Options

Mistral's other request options pass through the same way:

```ruby
RubyLLM.ocr(
  "annual-report.pdf",
  table_format: "html",          # extract tables as HTML instead of markdown
  include_image_base64: true,    # include embedded images as base64
  extract_header: true,          # separate page headers from the body
  extract_footer: true           # separate page footers from the body
)
```

See the [Mistral Document AI documentation](https://docs.mistral.ai/capabilities/document_ai/basic_ocr/) for the full list, including `image_limit:`, `image_min_size:`, `include_blocks:`, and `confidence_scores_granularity:`.

## Error Handling

Providers without OCR support raise a `RubyLLM::Error`:

```ruby
begin
  ocr = RubyLLM.ocr("contract.pdf")
  puts ocr.markdown
rescue RubyLLM::BadRequestError => e
  puts "Invalid request: #{e.message}"
rescue RubyLLM::Error => e
  puts "OCR failed: #{e.message}"
end
```

For long documents, raise the request timeout:

```ruby
RubyLLM.configure do |config|
  config.request_timeout = 600 # 10 minutes
end
```

## Next Steps

*   [File Attachments]({% link _core_features/attachments.md %}): Send documents to chat models instead.
*   [Audio Transcription]({% link _core_features/audio-transcription.md %}): Convert speech to text.
*   [Error Handling]({% link _advanced/error-handling.md %}): Master handling API errors.
