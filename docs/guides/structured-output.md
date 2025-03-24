# Structured Output

RubyLLM makes it easy to extract structured data from LLM responses using the `with_response_format` method.

## Usage

Define your structure as a Plain Old Ruby Object (PORO) that responds to `.json_schema` or directly pass a JSON schema hash or string:

```ruby
class Delivery
  attr_accessor :timestamp, :dimensions, :address
  
  def self.json_schema
    {
      type: "object",
      properties: {
        timestamp: { type: "string", format: "date-time" },
        dimensions: { 
          type: "array", 
          items: { type: "number" },
          description: "Dimensions in inches [length, width, height]"
        },
        address: { type: "string" }
      },
      required: ["timestamp", "address"]
    }
  end
end

# Use the class directly
response = chat.with_response_format(Delivery)
               .ask("Extract delivery info from: Next day delivery to 123 Main St...")

puts response.timestamp   # => 2025-03-20 14:30:00
puts response.dimensions  # => [12, 8, 4] 
puts response.address     # => "123 Main St, Springfield"

# Or use a JSON schema hash
schema = {
  type: "object",
  properties: {
    name: { type: "string" },
    age: { type: "integer" }
  }
}

response = chat.with_response_format(schema)
               .ask("Extract info: John is 30 years old")

puts response.name  # => "John"
puts response.age   # => 30
```

## Compatibility

Structured output is supported by:
- OpenAI models with JSON mode
- Anthropic models with JSON output
- Gemini models with structured output

The implementation adapts to each provider's specific capabilities while providing a consistent interface.