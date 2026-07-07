---
layout: default
title: Tool Parameters
parent: "Tools"
nav_order: 1
description: Declare tool arguments - from inferred signatures to full JSON Schema, rich return values, and provider-specific metadata.
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

* How RubyLLM infers parameters from an `execute` signature.
* When to reach for the `parameter` helper versus the `parameters` DSL.
* How to supply your own JSON Schema for full control.
* How to return rich content, such as images and documents, from a tool.
* How to inject dependencies through custom initialization.
* How to attach provider-specific metadata like Anthropic's `cache_control`.

The model only knows what arguments a tool accepts from the schema you give it. RubyLLM lets you describe that schema at whatever level of detail the tool needs, from a bare method signature to a hand-written JSON Schema.

## Declaring Parameters

RubyLLM ships with three complementary approaches:

*   **Signature inference** for simple flat arguments.
*   The **`parameter` helper** for quick, flat argument lists.
*   The **`parameters` DSL** for expressive, structured inputs.

Start with the method signature. Add `parameter` when a flat argument needs a description, type, or optionality that is not obvious from Ruby alone. Use the `parameters` DSL whenever you need nested objects, arrays, enums, or union types.

### Signature Inference

When a tool has no `parameter` or `parameters` declaration, RubyLLM builds a JSON Schema from `execute` keyword arguments:

```ruby
class Weather < RubyLLM::Tool
  description "Gets current weather for a location"

  def execute(latitude:, longitude:, units: "metric")
    # ...
  end
end
```

Required keywords become required string parameters. Optional keywords become optional string parameters. A tool with `def execute` receives an empty object schema.

Ruby method signatures do not expose reliable JSON Schema types or descriptions, so add explicit declarations when those details matter.

### Using the `parameter` Helper for Simple Tools

If your tool just needs a few scalar arguments with descriptions or non-string types, use the `parameter` helper. RubyLLM translates these declarations into JSON Schema under the hood.

```ruby
class Distance < RubyLLM::Tool
  description "Calculates distance between two cities"
  parameter :origin, description: "Origin city name"
  parameter :destination, description: "Destination city name"
  parameter :units, type: :string, description: "Unit system (metric or imperial)", required: false

  def execute(origin:, destination:, units: "metric")
    # ...
  end
end
```

### parameters DSL

When you need nested objects, arrays, enums, or union types, the `parameters do ... end` DSL produces the JSON Schema that function-calling models expect while staying Ruby-flavoured.

```ruby
class Scheduler < RubyLLM::Tool
  description "Books a meeting"

  parameters do
    object :window, description: "Time window to reserve" do
      string :start, description: "ISO8601 start time"
      string :finish, description: "ISO8601 end time"
    end

    array :participants, of: :string, description: "Email addresses to invite"

    any_of :format, description: "Optional meeting format" do
      string enum: %w[virtual in_person]
      null
    end
  end

  def execute(window:, participants:, format: nil)
    # ...
  end
end
```

RubyLLM bundles the DSL through [`ruby_llm-schema`](https://github.com/danielfriis/ruby_llm-schema), so every project has the same schema builders out of the box.

### Supplying JSON Schema Manually

Prefer to own the JSON Schema yourself? Pass a schema hash (or a class/object responding to `#to_json_schema`) directly to `parameters`:

```ruby
class Lookup < RubyLLM::Tool
  description "Performs catalog lookups"

  parameters type: "object",
    properties: {
      sku: { type: "string", description: "Product SKU" },
      locale: { type: "string", description: "Country code", default: "US" }
    },
    required: %w[sku],
    additionalProperties: false,
    strict: true

  def execute(sku:, locale: "US")
    # ...
  end
end
```

RubyLLM normalizes symbol keys, deep duplicates the schema, and sends it to providers unchanged. This gives you full control when you need it.

## Returning Structured Results from Tools

Tool results are text. Strings are sent as-is; a Hash or Array return is serialized to JSON, which models read natively and which persists cleanly:

```ruby
class InventoryTool < RubyLLM::Tool
  description "Checks warehouse inventory"
  parameter :sku, description: "Product SKU"

  def execute(sku:)
    { sku: sku, in_stock: 42, warehouse: "AMS-1" }  # sent as JSON
  end
end
```

To make results citable on providers with citation support, return a `RubyLLM::SearchResults`; see [Citations]({% link _core_features/citations.md %}).

## Returning Attachments from Tools

A tool message is text plus files, like any other message. Return `content, [attachments]` and each lands on the right field:

```ruby
class DocumentSearch < RubyLLM::Tool
  description "Searches the company drive"
  parameter :query, description: "What to look for"

  def execute(query:)
    doc = Drive.search(query).first
    return "Found: #{doc.name}", [RubyLLM::Attachment.new(doc.download_path)]
  end
end
```

The rule underneath is by type, so every natural variation works: strings become the message content, `RubyLLM::Attachment` objects become its attachments. Return a bare attachment for a file-only result, or several attachments for multiple files. Arrays without attachments stay structured data and serialize to JSON as usual.

Vision-capable models see the files: search tools can hand back the documents they found, chart tools their rendered graphs, browser tools their screenshots.

RubyLLM renders tool attachments in each provider's shape. Anthropic and Bedrock Converse take them as native tool-result blocks; Gemini gets the media as parts alongside the function response; OpenAI tool results are text-only on the wire, so the files ride a user message spliced in right after the result. Providers that cannot take a file type at all (for example, images on DeepSeek) raise `UnsupportedAttachmentError` rather than silently dropping files.

## Custom Initialization

Tools can have custom initialization:

```ruby
class DocumentSearch < RubyLLM::Tool
  description "Searches documents by relevance"

  parameter :query,
    description: "The search query"

  parameter :limit,
    type: :integer,
    description: "Maximum number of results",
    required: false

  def initialize(database)
    @database = database
  end

  def execute(query:, limit: 5)
    @database.search(query, limit: limit)
  end
end

search_tool = DocumentSearch.new(MyDatabase)
chat.with_tools(search_tool)
```

Use custom initialization for dependencies and runtime state. If two tools need
different names, descriptions, or inputs, define separate tool classes so the
parameter schema and `execute` signature stay together.

## Advanced Tool Metadata

### Provider-Specific Parameters

Some providers accept additional metadata alongside the JSON Schema, for example Anthropic's `cache_control` hints. Use `provider_options` to declare these once on the tool class and RubyLLM will merge them into the payload when the provider supports the keys.

```ruby
class TodoTool < RubyLLM::Tool
  description "Adds a task to the shared TODO list"

  parameters do
    string :title, description: "Human-friendly task description"
  end

  provider_options cache_control: { type: "ephemeral" }

  def execute(title:)
    Todo.create!(title:)
    "Added \"#{title}\" to the list."
  end
end
```

Provider metadata is passed through verbatim. Turn on `RUBYLLM_DEBUG=true` if you want to inspect the final payload while experimenting.

Pass `nil` to `provider_options` to clear provider-specific tool options.

## Next Steps

*   [Controlling Tool Execution]({% link _core_features/tool-execution.md %}) - Steer tool choice, call counts, concurrency, and callbacks.
*   [Tools]({% link _core_features/tools.md %}) - The execution flow, error handling, and security overview.
*   [Attachments]({% link _core_features/attachments.md %}) - How attachments returned from tools are consumed.
