---
layout: default
title: Structured Output
parent: "Chat"
nav_order: 3
description: Get AI responses that match an exact JSON schema with required fields and types
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* How JSON mode differs from schema-validated structured output.
* How to define a schema with `Schematist::Schema`.
* How to provide a manual JSON Schema and name it.
* How to build complex nested object and array schemas.
* How to check model support and change schemas during a conversation.

## Getting Structured Output

Describe the data your application needs with `with_schema`, then read it through `response.parsed`:

```ruby
class LanguagesSchema < Schematist::Schema
  array :languages do
    object do
      string :name
      integer :year
    end
  end
end

response = RubyLLM.chat.with_schema(LanguagesSchema)
                  .ask("List 3 programming languages with their year created.")
response.parsed["languages"]
# => [{"name" => "Ruby", "year" => 1995}, ...]
```

RubyLLM sends the schema in the format the provider expects. `response.content` contains the JSON text; `response.parsed` gives you Ruby Hashes and Arrays.

### Using Schematist

[Schematist](https://github.com/crmne/schematist) ships with RubyLLM. Add descriptions and optional fields as your schema grows:

```ruby
class PersonSchema < Schematist::Schema
  string :name, description: "Person's full name"
  integer :age, description: "Person's age in years"
  string :city, required: false, description: "City where they live"
end

chat = RubyLLM.chat
response = chat.with_schema(PersonSchema).ask("Generate a person named Alice who is 30 years old")

puts response.parsed # => {"name" => "Alice", "age" => 30}
puts response.content # => '{"name":"Alice","age":30}'
```

OpenAI's strict mode needs every property in `required`. RubyLLM sends `strict: true` when your schema qualifies and `strict: false` when it has optional properties like `city` above. To keep strict validation with an optional field, make the field required and let its type include `null`.
{: .note }

### Using Manual JSON Schemas

If you prefer not to use Schematist, you can provide a JSON Schema directly:

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

puts response.parsed
# => {"name" => "Bob", "age" => 25, "hobbies" => ["Ruby programming", "Open source"]}
```

Schematist sets `additionalProperties: false` for you. Include it on each object in a manual schema when using OpenAI.

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

### Complex Nested Schemas

Structured output supports complex nested objects and arrays:

```ruby
class CompanySchema < Schematist::Schema
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

response.parsed["employees"].each do |employee|
  puts "#{employee['name']} - #{employee['role']}"
end
```

### Provider Support

Not every model supports structured output. Ask the registry before you rely on it:

```ruby
RubyLLM.models.find('{{ site.models.default_chat }}').supports?(:structured_output) # => true
RubyLLM.models.chat_models.select { |model| model.supports?(:structured_output) }
```

Support varies by model and deployment. A provider can reject a schema or an unsupported JSON Schema keyword. Anthropic document citations cannot be combined with structured output.

DeepSeek requires `protocol: :responses` to enforce a schema:

```ruby
chat = RubyLLM.chat(model: "{{ site.models.deepseek_chat }}", provider: :deepseek, protocol: :responses)
response = chat.with_schema(PersonSchema).ask("Alice is 30 and lives in Rome.")
```

Its default Chat Completions protocol falls back to JSON mode, which does not enforce the fields or types.

### Multi-turn Conversations with Schemas

You can add or remove schemas during a conversation:

```ruby
chat = RubyLLM.chat
chat.with_schema(PersonSchema)
person = chat.ask("Generate a person")

# Remove the schema for free-form responses
chat.with_schema(nil)
analysis = chat.ask("Tell me about this person's potential career paths")

class CareerPlanSchema < Schematist::Schema
  string :title
  array :steps, of: :string
  integer :years_required
end

chat.with_schema(CareerPlanSchema)
career = chat.ask("Now structure a career plan")

person.parsed
analysis.content
career.parsed
```

## JSON Mode

Use JSON mode when you need valid JSON without a particular schema. This OpenAI example uses the default Responses protocol:

```ruby
chat = RubyLLM.chat.with_provider_options(text: { format: { type: 'json_object' } })
response = chat.ask "List three programming languages. Return JSON."
response.parsed
```

JSON mode does not enforce fields or types. Use `with_schema` when your application depends on a particular structure.

## Next Steps

* [Chat]({% link _core_features/chat.md %}) - the conversation interface `with_schema` builds on.
* [Tools]({% link _core_features/tools.md %}) - let the model call your Ruby code when a schema is not enough.
* [Rails Integration]({% link _advanced/rails.md %}) - persist structured responses alongside your conversations.
* [Advanced Request Control]({% link _core_features/chat-request-control.md %}) - reach JSON mode and other provider-specific options directly.
