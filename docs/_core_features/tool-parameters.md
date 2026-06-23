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
* When to reach for the `param` helper versus the `params` DSL.
* How to supply your own JSON Schema for full control.
* How to return rich content, such as images and documents, from a tool.
* How to inject dependencies through custom initialization.
* How to attach provider-specific metadata like Anthropic's `cache_control`.

The model only knows what arguments a tool accepts from the schema you give it. RubyLLM lets you describe that schema at whatever level of detail the tool needs, from a bare method signature to a hand-written JSON Schema.

## Declaring Parameters

RubyLLM ships with three complementary approaches:

*   **Signature inference** for simple flat arguments.
*   The **`param` helper** for quick, flat argument lists. (v1.0+)
*   The **`params` DSL** for expressive, structured inputs. (v1.9+)

Start with the method signature. Add `param` when a flat argument needs a description, type, or optionality that is not obvious from Ruby alone. Use the `params` DSL whenever you need nested objects, arrays, enums, or union types.

### Signature Inference

When a tool has no `param` or `params` declaration, RubyLLM builds a JSON Schema from `execute` keyword arguments:

```ruby
class Weather < RubyLLM::Tool
  desc "Gets current weather for a location"

  def execute(latitude:, longitude:, units: "metric")
    # ...
  end
end
```

Required keywords become required string parameters. Optional keywords become optional string parameters. A tool with `def execute` receives an empty object schema.

Ruby method signatures do not expose reliable JSON Schema types or descriptions, so add explicit declarations when those details matter.

### Using the `param` Helper for Simple Tools

If your tool just needs a few scalar arguments with descriptions or non-string types, use the `param` helper. RubyLLM translates these declarations into JSON Schema under the hood.

```ruby
class Distance < RubyLLM::Tool
  desc "Calculates distance between two cities"
  param :origin, desc: "Origin city name"
  param :destination, description: "Destination city name"
  param :units, type: :string, desc: "Unit system (metric or imperial)", required: false

  def execute(origin:, destination:, units: "metric")
    # ...
  end
end
```

### params DSL

When you need nested objects, arrays, enums, or union types, the `params do ... end` DSL produces the JSON Schema that function-calling models expect while staying Ruby-flavoured.

```ruby
class Scheduler < RubyLLM::Tool
  desc "Books a meeting"

  params do
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

Prefer to own the JSON Schema yourself? Pass a schema hash (or a class/object responding to `#to_json_schema`) directly to `params`:

```ruby
class Lookup < RubyLLM::Tool
  description "Performs catalog lookups"

  params type: "object",
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

## Returning Rich Content from Tools

Tools can return `RubyLLM::Content` objects with file attachments, allowing you to pass images, documents, or other files from your tools to the AI model:

```ruby
class AnalyzeTool < RubyLLM::Tool
  description "Analyzes data and returns results with visualizations"
  param :query, desc: "Analysis query"

  def execute(query:)
    chart_path = generate_chart(query)

    RubyLLM::Content.new(
      "Analysis complete for: #{query}",
      [chart_path]  # Attach the generated chart (array of paths/blobs)
    )
  end

  private

  def generate_chart(query)
    # Your chart generation logic
    "/tmp/chart_#{Time.now.to_i}.png"
  end
end

chat = RubyLLM.chat.with_tool(AnalyzeTool)
response = chat.ask("Analyze sales trends for Q4")
```

When a tool returns a `Content` object:
- The text and attachments are preserved in the conversation history
- Vision-capable models can see and analyze attached images
- The AI can reference the attachments in its response

This is particularly useful for:
- **Data visualization:** Return charts, graphs, or diagrams
- **Document processing:** Pass PDFs or documents for the AI to analyze
- **Image generation:** Return generated or processed images
- **Mixed media workflows:** Combine text results with visual elements

## Custom Initialization

Tools can have custom initialization:

```ruby
class DocumentSearch < RubyLLM::Tool
  description "Searches documents by relevance"

  param :query,
    desc: "The search query"

  param :limit,
    type: :integer,
    desc: "Maximum number of results",
    required: false

  def initialize(database)
    @database = database
  end

  def execute(query:, limit: 5)
    @database.search(query, limit: limit)
  end
end

search_tool = DocumentSearch.new(MyDatabase)
chat.with_tool(search_tool)
```

Use custom initialization for dependencies and runtime state. If two tools need
different names, descriptions, or inputs, define separate tool classes so the
parameter schema and `execute` signature stay together.

## Advanced Tool Metadata

### Provider-Specific Parameters

Some providers accept additional metadata alongside the JSON Schema, for example Anthropic's `cache_control` hints. Use `with_params` to declare these once on the tool class and RubyLLM will merge them into the payload when the provider supports the keys.

```ruby
class TodoTool < RubyLLM::Tool
  description "Adds a task to the shared TODO list"

  params do
    string :title, description: "Human-friendly task description"
  end

  with_params cache_control: { type: "ephemeral" }

  def execute(title:)
    Todo.create!(title:)
    "Added \"#{title}\" to the list."
  end
end
```

Provider metadata is passed through verbatim. Turn on `RUBYLLM_DEBUG=true` if you want to inspect the final payload while experimenting.

## Next Steps

*   [Controlling Tool Execution]({% link _core_features/tool-execution.md %}) - Steer tool choice, call counts, concurrency, and callbacks.
*   [Tools]({% link _core_features/tools.md %}) - The execution flow, error handling, and security overview.
*   [Attachments]({% link _core_features/attachments.md %}) - How attachments returned from tools are consumed.
