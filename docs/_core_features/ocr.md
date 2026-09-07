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

Turn a PDF or scan into text you can search, summarize, or store:

```ruby
ocr = RubyLLM.ocr("contract.pdf")

puts ocr.markdown
# => "# Service Agreement\n\nThis agreement is made between..."
```

The file may be a local path, an `http(s)` URL, an IO object, or a `RubyLLM::Attachment`. Remote URLs must be publicly reachable.

Mistral accepts PDFs, office documents, and images. Cohere Parse accepts one image per request.

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

`ocr.raw` holds the full provider response when you need fields beyond the normalized page readers.

## Choosing Models

Choose another OCR model with `model:`:

```ruby
RubyLLM.ocr("scan.png", model: "{{ site.models.cohere_ocr }}")
```

Configure the default globally:

```ruby
RubyLLM.configure do |config|
  config.default_ocr_model = "{{ site.models.default_ocr }}"
end
```

## Processing Specific Pages

Pass `pages:` to extract specific pages, using zero-based page numbers:

```ruby
ocr = RubyLLM.ocr("annual-report.pdf", pages: [0, 1, 2])

ocr.pages.length
# => 3
```

## Provider Options

Mistral's other request options pass through `provider_options:` in Mistral's own vocabulary:

```ruby
RubyLLM.ocr(
  "annual-report.pdf",
  provider_options: {
    table_format: "html",          # extract tables as HTML instead of markdown
    include_image_base64: true,    # include embedded images as base64
    extract_header: true,          # separate page headers from the body
    extract_footer: true           # separate page footers from the body
  }
)
```

See [Mistral Document AI](https://docs.mistral.ai/capabilities/document_ai/basic_ocr/) for more extraction options.

For Cohere, `provider_options: { output_format: "blocks" }` includes text, image, and table blocks in `ocr.pages.first.raw["blocks"]`.

## Extracting Structured Data

Combine OCR with structured output to turn a scan into application data:

```ruby
class InvoiceSchema < Schematist::Schema
  string :invoice_number
  string :currency
  number :total
end

text = RubyLLM.ocr("invoice.pdf").markdown
response = RubyLLM.chat.with_schema(InvoiceSchema)
                  .ask("Extract the invoice details:\n#{text}")
response.parsed
# => {"invoice_number" => "INV-1042", "currency" => "EUR", "total" => 120.0}
```

OCR extracts the text, then a chat model structures it. See [Structured Output]({% link _core_features/structured-output.md %}) for schemas and typed fields.

## Error Handling

A provider without OCR support raises `RubyLLM::Error`. Rejected files or options raise `RubyLLM::BadRequestError`. See [Error Handling]({% link _advanced/error-handling.md %}) for retries and [Connection Settings]({% link _getting_started/configuration-connection.md %}#connection-settings) for longer document timeouts.

## Next Steps

*   [File Attachments]({% link _core_features/attachments.md %}): Send documents to chat models instead.
*   [Structured Output]({% link _core_features/structured-output.md %}) - extract fields from document text.
*   [Embeddings]({% link _core_features/embeddings.md %}) - make extracted documents searchable.
