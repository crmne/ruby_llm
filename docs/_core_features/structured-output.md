---
layout: default
title: Structured Output
parent: "Chat"
nav_order: 3
description: Get AI responses that match an exact JSON schema with required fields and types
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

* How JSON mode differs from schema-validated structured output.
* How to define a schema with `RubyLLM::Schema`.
* How to provide a manual JSON Schema and name it.
* How to build complex nested object and array schemas.
* Which providers support structured output and how to add or remove a schema mid-conversation.

## Getting Structured Output

When building applications, you often need AI responses in a specific format for parsing and processing. RubyLLM provides two approaches: JSON mode for valid JSON output, and structured output for guaranteed schema compliance.

JSON mode (using `with_params(response_format: { type: 'json_object' })`) guarantees valid JSON but not any specific structure. Structured output (`with_schema`) guarantees the response matches your exact schema with required fields and types. Use structured output when you need predictable, validated responses.
{: .note }

```ruby
chat = RubyLLM.chat.with_params(response_format: { type: 'json_object' })
response = chat.ask("List 3 programming languages with their year created. Return as JSON.")

class LanguagesSchema < RubyLLM::Schema
  array :languages do
    object do
      string :name
      integer :year
    end
  end
end

chat = RubyLLM.chat.with_schema(LanguagesSchema)
response = chat.ask("List 3 programming languages with their year created")
# Always returns: {"languages" => [{"name" => "...", "year" => ...}, ...]}
```

### Using RubyLLM::Schema (Recommended)

The easiest way to define schemas is with the [RubyLLM::Schema](https://github.com/danielfriis/ruby_llm-schema) gem:

```ruby
# First, add to your Gemfile:
# gem 'ruby_llm-schema'
#
# Then in your code:
require 'ruby_llm/schema'

class PersonSchema < RubyLLM::Schema
  string :name, description: "Person's full name"
  integer :age, description: "Person's age in years"
  string :city, required: false, description: "City where they live"
end

chat = RubyLLM.chat
response = chat.with_schema(PersonSchema).ask("Generate a person named Alice who is 30 years old")

puts response.content # => {"name" => "Alice", "age" => 30}
puts response.content.class # => Hash
```

RubyLLM::Schema classes automatically use their class name (e.g., `PersonSchema`) as the schema name in API requests, which can help the model better understand the expected output structure.
{: .note }

### Using Manual JSON Schemas

If you prefer not to use RubyLLM::Schema, you can provide a JSON Schema directly:

```ruby
person_schema = {
  type: 'object',
  properties: {
    name: { type: 'string' },
    age: { type: 'integer' },
    hobbies: {
      type: 'array',
      items: { type: 'string' }
    }
  },
  required: ['name', 'age', 'hobbies'],
  additionalProperties: false  # Required for OpenAI structured output
}

chat = RubyLLM.chat
response = chat.with_schema(person_schema).ask("Generate a person who likes Ruby")

puts response.content
# => {"name" => "Bob", "age" => 25, "hobbies" => ["Ruby programming", "Open source"]}
```

**OpenAI Requirement:** When using manual JSON schemas with OpenAI, you must include `additionalProperties: false` in your schema objects. RubyLLM::Schema handles this automatically.
{: .warning }

#### Custom Schema Names

By default, schemas are named 'response' in API requests. You can provide a custom name that can influence model behavior and aid debugging:

```ruby
person_schema = {
  name: 'PersonSchema',
  schema: {
    type: 'object',
    properties: {
      name: { type: 'string' },
      age: { type: 'integer' }
    },
    required: ['name', 'age'],
    additionalProperties: false
  }
}

chat = RubyLLM.chat
response = chat.with_schema(person_schema).ask("Generate a person")
```

Custom schema names are useful for:
- **Influencing model behavior** - Descriptive names can help the model better understand the expected output structure
- **Debugging and logging** - Identifying which schema was used in API requests

### Complex Nested Schemas

Structured output supports complex nested objects and arrays:

```ruby
class CompanySchema < RubyLLM::Schema
  string :name, description: "Company name"

  array :employees do
    object do
      string :name
      string :role, enum: ["developer", "designer", "manager"]
      array :skills, of: :string
    end
  end

  object :metadata do
    integer :founded
    string :industry
  end
end

chat = RubyLLM.chat
response = chat.with_schema(CompanySchema).ask("Generate a small tech startup")

response.content["employees"].each do |employee|
  puts "#{employee['name']} - #{employee['role']}"
end
```

### Provider Support

Not all models support structured output. Currently supported:
- **OpenAI**: GPT-4o, GPT-4o-mini, and newer models
- **Anthropic**: Claude 4.5+ models (Haiku, Sonnet, Opus)
- **Gemini**: Gemini 1.5 Pro/Flash and newer

Models that don't support structured output:

```ruby
chat = RubyLLM.chat(model: '{{ site.models.openai_legacy }}')
chat.with_schema(schema)
response = chat.ask('Generate a person')
# Provider will return an error if unsupported
```

### Multi-turn Conversations with Schemas

You can add or remove schemas during a conversation:

```ruby
chat = RubyLLM.chat
chat.with_schema(PersonSchema)
person = chat.ask("Generate a person")

# Remove the schema for free-form responses
chat.with_schema(nil)
analysis = chat.ask("Tell me about this person's potential career paths")

class CareerPlanSchema < RubyLLM::Schema
  string :title
  array :steps, of: :string
  integer :years_required
end

chat.with_schema(CareerPlanSchema)
career = chat.ask("Now structure a career plan")

puts person.content
puts analysis.content
puts career.content
```

## Next Steps

* [Chat]({% link _core_features/chat.md %}) - the conversation interface `with_schema` builds on.
* [Tools]({% link _core_features/tools.md %}) - let the model call your Ruby code when a schema is not enough.
* [Rails Integration]({% link _advanced/rails.md %}) - persist structured responses alongside your conversations.
* [Advanced Request Control]({% link _core_features/chat-request-control.md %}) - reach JSON mode and other provider-specific options directly.
