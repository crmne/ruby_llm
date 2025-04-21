---
layout: default
title: Structured Output
parent: Guides
nav_order: 7
---

# Structured Output

RubyLLM allows you to request structured data from language models by providing a JSON schema. When you use the `with_response_format` method, RubyLLM will ensure the model returns data matching your schema instead of free-form text.

## Schema-Based Output (Recommended)

We recommend providing a schema for structured data:

```ruby
# Define a JSON schema
schema = {
  type: "object",
  properties: {
    name: { type: "string" },
    age: { type: "integer" },
    interests: { type: "array", items: { type: "string" } }
  },
  required: ["name", "age", "interests"]
}

response = RubyLLM.chat(model: "gpt-4o")
  .with_response_format(schema)
  .ask("Create a profile for a Ruby developer")
```

RubyLLM intelligently handles your schema based on the model's capabilities:

- For models with native schema support (like GPT-4o): Uses API-level schema validation
- For models without schema support: Automatically adds schema instructions to the system message

## Simple JSON Mode (Alternative)

For cases where you just need well-formed JSON:

```ruby
response = RubyLLM.chat(model: "gpt-4.1-nano")
  .with_response_format(:json)
  .ask("Create a profile for a Ruby developer")
```

This uses OpenAI's `response_format: {type: "json_object"}` parameter, works with most OpenAI models, and guarantees valid JSON without enforcing a specific structure.

## Model Compatibility Checks

By default, RubyLLM checks if a model officially supports the requested output format. If you try to use a schema with a model that doesn't support schema validation, RubyLLM will raise an `UnsupportedStructuredOutputError`.

For broader compatibility, you can skip this compatibility check:

```ruby
# Use schema with a model that doesn't currently support schema validation in RubyLLM
response = RubyLLM.chat(model: "gemini-2.0-flash")
  .with_response_format(schema, assume_supported: true)
  .ask("Create a profile for a Ruby developer")
```

When `assume_supported` is set to `true`:

- RubyLLM doesn't validate if the model supports the requested format
- The schema is automatically added to the system message
- JSON parsing is handled automatically
- Works with most models that can produce JSON output, including Claude and Gemini

This allows you to use schema-based output with a wider range of models, though without API-level schema validation.

## Error Handling

RubyLLM provides two main error types for structured output:

1. **UnsupportedStructuredOutputError**: Raised when using schema-based output with a model that doesn't support it (when `assume_supported` is false):
2. **InvalidStructuredOutput**: Raised if the model returns invalid JSON:

Note: RubyLLM checks that responses are valid JSON but doesn't verify conformance to the schema structure. For full schema validation, use a library like `json-schema`.

## With ActiveRecord and Rails

For Rails integration details with structured output, please see the [Rails guide](rails.md#json-response-handling).
