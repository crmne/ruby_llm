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

## Strict and Non-Strict Modes

By default, RubyLLM operates in "strict mode" which only allows models that officially support the requested output format. If you try to use a schema with a model that doesn't support schema validation, RubyLLM will raise an `UnsupportedStructuredOutputError`.

For broader compatibility, you can disable strict mode:

```ruby
# Use schema with a model that doesn't currently support schema validation on RubyLLM
response = RubyLLM.chat(model: "gemini-2.0-flash")
  .with_response_format(schema, strict: false)
  .ask("Create a profile for a Ruby developer")
```

In non-strict mode:

- RubyLLM doesn't validate if the model supports the requested format
- The schema is automatically added to the system message
- JSON parsing is handled automatically
- Works with most models that can produce JSON output, including Claude and Gemini

This allows you to use schema-based output with a wider range of models, though without API-level schema validation.

## Error Handling

RubyLLM provides two main error types for structured output:

1. **UnsupportedStructuredOutputError**: Raised when using schema-based output with a model that doesn't support it in strict mode:
2. **InvalidStructuredOutput**: Raised if the model returns invalid JSON:

Note: RubyLLM checks that responses are valid JSON but doesn't verify conformance to the schema structure. For full schema validation, use a library like `json-schema`.

## With ActiveRecord and Rails

The structured output feature works seamlessly with RubyLLM's Rails integration. Message content can be either a String or a Hash.

If you're storing message content in your database, ensure your messages table can store JSON. PostgreSQL's `jsonb` column type is ideal:

```ruby
# In a migration
create_table :messages do |t|
  t.references :chat
  t.string :role
  t.jsonb :content # Use jsonb for efficient JSON storage
  # other fields...
end
```

If you have an existing application with a text-based content column, add serialization:

```ruby
# In your Message model
class Message < ApplicationRecord
  serialize :content, JSON
  acts_as_message
end
```

## Tips for Effective Schemas

1. **Be specific**: Provide clear property descriptions to guide the model.
2. **Start simple**: Begin with basic schemas and add complexity gradually.
3. **Include required fields**: Specify which properties are required.
4. **Use appropriate types**: Match JSON Schema types to your expected data.
5. **Validate locally**: Consider using a gem like `json-schema` for additional validation.
6. **Test model compatibility**: Different models have different levels of schema support.

## Example: Complex Schema

```ruby
schema = {
  type: "object",
  properties: {
    products: {
      type: "array",
      items: {
        type: "object",
        properties: {
          name: { type: "string" },
          price: { type: "number" },
          in_stock: { type: "boolean" },
          categories: {
            type: "array",
            items: { type: "string" }
          }
        },
        required: ["name", "price", "in_stock"]
      }
    },
    total_products: { type: "integer" },
    store_info: {
      type: "object",
      properties: {
        name: { type: "string" },
        location: { type: "string" }
      }
    }
  },
  required: ["products", "total_products"]
}

inventory = chat.with_response_format(schema)  # Let RubyLLM handle the schema formatting
  .ask("Create an inventory for a Ruby gem store")
```

### Limitations

- Schema validation is only available at the API level for certain OpenAI models
- No enforcement of required fields or data types without external validation
- For full schema validation, use a library like `json-schema` to verify the output

RubyLLM handles all the complexity of supporting different model capabilities, so you can focus on your application logic.
