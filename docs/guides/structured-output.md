---
layout: default
title: Structured Output
parent: Guides
nav_order: 7
---

# Structured Output
{: .no_toc .d-inline-block }

New (v1.3.0)
{: .label .label-green }

Get structured, well-formatted data from language models by providing a JSON schema. Use the `with_response_format` method to ensure the AI returns data that matches your schema instead of free-form text.
{: .fs-6 .fw-300 }

## Table of contents
{: .no_toc .text-delta }

1. TOC
{:toc}

---

After reading this guide, you will know:

*   How to use JSON schemas to get structured data from language models
*   How to request simple JSON responses without a specific schema
*   How to work with models that may not officially support structured output
*   How to handle errors related to structured output
*   Best practices for creating effective JSON schemas

## Getting Structured Data with Schemas

The most powerful way to get structured data is by providing a JSON schema that defines the exact format you need:

```ruby
# Define your JSON schema
schema = {
  type: "object",
  properties: {
    name: { type: "string" },
    age: { type: "integer" },
    interests: { type: "array", items: { type: "string" } }
  },
  required: ["name", "age", "interests"]
}

# Request data that follows this schema
response = RubyLLM.chat(model: "gpt-4o")
  .with_response_format(schema)
  .ask("Create a profile for a Ruby developer")

# Access the structured data as a Hash
puts response.content["name"]      # => "Ruby Smith"
puts response.content["age"]       # => 32
puts response.content["interests"] # => ["Metaprogramming", "Rails", "Testing"]
```

RubyLLM intelligently adapts based on each model's capabilities:

- For models with native schema support (like GPT-4o): Uses the provider's API-level schema validation
- For other models: Automatically adds schema instructions to the system message

## Simple JSON Mode

When you just need well-formed JSON without a specific structure:

```ruby
response = RubyLLM.chat(model: "gpt-4.1-nano")
  .with_response_format(:json)
  .ask("Create a profile for a Ruby developer")

# The response will be valid JSON but with a format chosen by the model
puts response.content.keys # => ["name", "bio", "skills", "experience", "github"]
```

This simpler approach uses OpenAI's `response_format: {type: "json_object"}` parameter, guaranteeing valid JSON output without enforcing a specific schema structure.

## Working with Unsupported Models

To use structured output with models that don't officially support it, set `assume_supported: true`:

```ruby
response = RubyLLM.chat(model: "gemini-2.0-flash")
  .with_response_format(schema, assume_supported: true)
  .ask("Create a profile for a Ruby developer")
```

This bypasses compatibility checks and inserts the schema as system instructions. Most modern models can follow these instructions to produce properly formatted JSON, even without native schema support.

## Error Handling

RubyLLM provides specialized error classes for structured output that help you handle different types of issues:

### UnsupportedStructuredOutputError

Raised when a model doesn't support the structured output format and `assume_supported` is false:

```ruby
begin
  # Try to use structured output with a model that doesn't support it
  response = RubyLLM.chat(model: "gemini-2.0-flash")
    .with_response_format(schema)
    .ask("Create a profile for a Ruby developer")
rescue RubyLLM::UnsupportedStructuredOutputError => e
  puts "This model doesn't support structured output: #{e.message}"
  # Fall back to non-structured output or a different model
end
```

### InvalidStructuredOutput

Raised if the model returns a response that can't be parsed as valid JSON:

```ruby
begin
  response = RubyLLM.chat(model: "gpt-4o")
    .with_response_format(schema)
    .ask("Create a profile for a Ruby developer")
rescue RubyLLM::InvalidStructuredOutput => e
  puts "The model returned invalid JSON: #{e.message}"
  # Handle the error, perhaps by retrying or using a simpler schema
end
```

Note: RubyLLM checks that responses are valid JSON but doesn't verify schema conformance (required fields, data types, etc.). For full schema validation, use a library like `json-schema`.

## With ActiveRecord and Rails

For Rails integration details with structured output, please see the [Rails guide](rails.md#working-with-structured-output).

## Best Practices for JSON Schemas

When creating schemas for structured output, follow these guidelines:

1. **Keep it simple**: Start with the minimum structure needed. More complex schemas can confuse the model.
2. **Be specific with types**: Use appropriate JSON Schema types (`string`, `number`, `boolean`, `array`, `object`) for your data.
3. **Include descriptions**: Add a `description` field to each property to help guide the model.
4. **Mark required fields**: Use the `required` array to indicate which properties must be included.
5. **Provide examples**: When possible, include `examples` for complex properties.
6. **Test thoroughly**: Different models have varying levels of schema compliance.

## Example: Complex Schema

Here's an example of a more complex schema for inventory data:

```ruby
schema = {
  type: "object",
  properties: {
    products: {
      type: "array",
      items: {
        type: "object",
        properties: {
          name: { 
            type: "string",
            description: "Name of the product" 
          },
          price: { 
            type: "number",
            description: "Price in dollars" 
          },
          in_stock: { 
            type: "boolean",
            description: "Whether the item is currently available" 
          },
          categories: {
            type: "array",
            items: { type: "string" },
            description: "List of categories this product belongs to"
          }
        },
        required: ["name", "price", "in_stock"]
      }
    },
    total_products: { 
      type: "integer",
      description: "Total number of products in inventory" 
    }
  },
  required: ["products", "total_products"]
}

inventory = RubyLLM.chat(model: "gpt-4o")
  .with_response_format(schema)
  .ask("Create an inventory for a Ruby gem store")
```

## Limitations

When working with structured output, be aware of these limitations:

* Schema validation is only available at the API level for certain models (primarily OpenAI models)
* RubyLLM validates that responses are valid JSON but doesn't verify schema conformance
* For full schema validation, use a library like `json-schema` to verify output
* Models may occasionally deviate from the schema despite instructions
* Complex, deeply nested schemas may reduce compliance

RubyLLM handles the complexity of supporting different model capabilities, so you can focus on your application logic rather than provider-specific implementation details.
