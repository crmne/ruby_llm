---
layout: default
title: Structured Output
parent: Guides
nav_order: 7
---

# Structured Output

RubyLLM allows you to request structured data from language models by providing a JSON schema. When you use the `with_output_schema` method, RubyLLM will ensure the model returns data matching your schema instead of free-form text.

## Basic Usage

```ruby
# Define a JSON schema
schema = {
  type: "object",
  properties: {
    name: { type: "string" },
    age: { type: "integer" },
    interests: { 
      type: "array", 
      items: { type: "string" }
    }
  },
  required: ["name", "age", "interests"]
}

# Get structured output as a Hash
response = RubyLLM.chat
  .with_output_schema(schema)
  .ask("Create a profile for a Ruby developer")

# Access the structured data
puts "Name: #{response.content['name']}"
puts "Age: #{response.content['age']}"
puts "Interests: #{response.content['interests'].join(', ')}"
```

## Provider Support

### Strict Mode (Default)

By default, RubyLLM uses "strict mode" which only allows providers that officially support structured JSON output:

- **OpenAI**: For models that support JSON mode (like GPT-4.1, GPT-4o), RubyLLM uses the native `response_format: {type: "json_object"}` parameter.

If you try to use an unsupported model in strict mode, RubyLLM will raise an `UnsupportedStructuredOutputError` (see [Error Handling](#error-handling)).

### Non-Strict Mode

You can disable strict mode by setting `strict: false` when calling `with_output_schema`:

```ruby
# Allow structured output with non-OpenAI models
chat = RubyLLM.chat(model: "gemini-2.0-flash")
response = chat.with_output_schema(schema, strict: false)
                .ask("Create a profile for a Ruby developer")

# The response.content will be a Hash if JSON parsing succeeds
if response.content.is_a?(Hash)
  puts "Name: #{response.content['name']}"
  puts "Age: #{response.content['age']}"
else
  # Fall back to treating as string if parsing failed
  puts "Got text response: #{response.content}"
end
```

In non-strict mode:
- The system will not validate if the model officially supports structured output
- The schema is still included in the system prompt to guide the model
- RubyLLM automatically attempts to handle markdown code blocks (like ````json\n{...}````)
- JSON is parsed when possible, but might fall back to raw text in some cases
- Works with Anthropic Claude and Google Gemini models, but results can vary

This is useful for experimentation with models like Anthropic's Claude or Gemini, but should be used with caution in production environments.

## Error Handling

RubyLLM has two error types related to structured output:

1. **UnsupportedStructuredOutputError**: Raised when you try to use structured output with a model that doesn't support it in strict mode:

```ruby
begin
  chat = RubyLLM.chat(model: 'claude-3-5-haiku')
  chat.with_output_schema(schema) # This will raise an error
rescue RubyLLM::UnsupportedStructuredOutputError => e
  puts "This model doesn't support structured output: #{e.message}"
  
  # You can try with strict mode disabled
  chat.with_output_schema(schema, strict: false)
end
```

2. **InvalidStructuredOutput**: Raised if the model returns invalid JSON:

```ruby
begin
  response = chat.with_output_schema(schema).ask("Create a profile")
rescue RubyLLM::InvalidStructuredOutput => e
  puts "The model returned invalid JSON: #{e.message}"
end
```

Note that the current implementation only checks that the response is valid JSON that can be parsed. It does not verify that the parsed content conforms to the schema structure (e.g., having all required fields or correct data types). If you need full schema validation, you'll need to implement it using a library like `json-schema`.

## With ActiveRecord and Rails

The structured output feature works seamlessly with RubyLLM's Rails integration. Message content can now be either a String or a Hash.

If you're storing message content in your database and want to use structured output, ensure your messages table can store JSON. PostgreSQL's `jsonb` column type is ideal:

```ruby
# In a migration
create_table :messages do |t|
  t.references :chat
  t.string :role
  t.jsonb :content # Use jsonb for efficient JSON storage
  # other fields...
end
```

If you have an existing application with a text-based content column, you can add serialization:

```ruby
# In your Message model
class Message < ApplicationRecord
  serialize :content, JSON
  acts_as_message
end
```

## Tips for Effective Schemas

1. **Be specific**: Provide clear property descriptions to guide the model's output.
2. **Start simple**: Begin with basic schemas and add complexity gradually.
3. **Include required fields**: Specify which properties are required.
4. **Use appropriate types**: Match JSON Schema types to your expected data.
5. **Validate locally**: Consider using a gem like `json-schema` for additional validation.

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

inventory = chat.with_output_schema(schema).ask("Create an inventory for a Ruby gem store")
```

## Implementation Details

The current implementation of structured output in RubyLLM:

1. **For OpenAI**: 
   - Uses OpenAI's native JSON mode via `response_format: {type: "json_object"}`
   - Returns parsed Hash objects directly
   - Works reliably in production settings

2. **For other providers (with strict: false)**:
   - Includes schema guidance in the system prompt
   - Does not use provider-specific JSON modes
   - Automatically handles markdown code blocks (like ````json\n{...}````)
   - Attempts to parse JSON responses when possible
   - Returns varying results depending on the model's capabilities
   - Better suited for experimentation than production use

### Limitations

- No schema validation beyond JSON parsing
- No enforcement of required fields or data types
- Not all providers support structured output reliably
- Response format consistency varies between providers

This feature is currently in alpha and we welcome feedback on how it can be improved. Future versions will likely include more robust schema validation and better support for additional providers.