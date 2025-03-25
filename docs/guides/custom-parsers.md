# Custom Parsers

RubyLLM's custom parser system allows you to extract and transform model responses into any format you need. While structured JSON output is handled by `with_response_format`, custom parsers give you flexibility for all other formats including XML, regex patterns, markdown, JSON, and more.

## Built-in Parsers

RubyLLM comes with several built-in parsers:

- `:text` - Default parser that returns the raw content (no transformation)
- `:json` - Parses JSON responses into Ruby objects
- `:xml` - Extracts content from specific XML tags

## Using Parsers

You can specify a parser for any chat by calling `with_parser`:

```ruby
chat = RubyLLM.chat

# Use the built-in XML parser
response = chat.with_parser(:xml, tag: 'data')
               .ask("Can you provide the answer in XML? <data>42</data>")

puts response.content  # => "42"
```

### XML Parser

The XML parser can extract content from specified tags:

```ruby
# Extract content from the <answer> tag
response = chat.with_parser(:xml, tag: 'answer')
               .ask("Respond with: <answer>This is the extracted content</answer>")

puts response.content  # => "This is the extracted content"

# You can also extract from different tags in different requests
response = chat.with_parser(:xml, tag: 'code')
               .ask("Give me a Ruby function in XML: <code>def hello; puts 'world'; end</code>")

puts response.content  # => "def hello; puts 'world'; end"
```

### JSON Parser

The JSON parser converts JSON responses to Ruby objects:

```ruby
response = chat.with_parser(:json)
               .ask("Respond with JSON: {\"name\":\"Ruby\",\"age\":30}")

# Access the parsed JSON as an OpenStruct
puts response.content.name  # => "Ruby"
puts response.content.age   # => 30
```

## Creating Custom Parsers

Creating custom parsers is straightforward. You need to:

1. Define a module with a `parse` method
2. Register it with `ResponseParser.register`
3. Use it in your chats with `with_parser`

### Parser Interface

Your parser module must implement a `parse` method with this signature:

```ruby
def self.parse(response, options)
  # Process response.content and return the parsed result
  # 'options' can be any format specified when calling with_parser
end
```

Where:

- `response` is a `RubyLLM::Message` object with the model's response
- `options` is any value passed as the second argument to `with_parser`
- The return value can be any Ruby object

### CSV Parser Example

Here's how to create a parser for CSV content:

```ruby
module CSVParser
  def self.parse(response, options)
    return response unless response.content.is_a?(String)

    # Skip empty responses
    return response if response.content.strip.empty?

    # Parse CSV content
    rows = response.content.strip.split("\n")
    headers = rows.first.split(',')

    rows[1..-1].map do |row|
      values = row.split(',')
      headers.zip(values).to_h
    end
  end
end

# Register your parser
RubyLLM::ResponseParser.register(:csv, CSVParser)

# Use your parser in a chat
results = chat.with_parser(:csv)
              .ask("Give me a CSV with name,age,city with 3 rows of data")
              .content

# Process the results
results.each do |person|
  puts "#{person['name']} is #{person['age']} years old from #{person['city']}"
end
```

### Markdown Parser Example

A parser for extracting code blocks from markdown:

````ruby
module MarkdownParser
  def self.parse(response, options)
    return response unless response.content.is_a?(String)

    content = response.content
    language = options[:language] if options.is_a?(Hash)

    # Extract all code blocks
    if language
      # Get only blocks of specified language
      blocks = content.scan(/```#{language}\n(.*?)```/m).flatten
    else
      # Get all code blocks regardless of language
      blocks = content.scan(/```(?:\w+)?\n(.*?)```/m).flatten
    end

    # Return a single string if only one block, otherwise an array
    blocks.size == 1 ? blocks.first : blocks
  end
end

RubyLLM::ResponseParser.register(:markdown, MarkdownParser)

# Extract Ruby code from markdown
ruby_code = chat.with_parser(:markdown, language: "ruby")
                .ask("Write a function to calculate Fibonacci numbers")
                .content

# Extract all code blocks
all_code = chat.with_parser(:markdown)
               .ask("Write a function in both Ruby and Python")
               .content
````

### Regular Expression Parser

Extract specific patterns using regex:

```ruby
module RegexParser
  def self.parse(response, options)
    return response unless response.content.is_a?(String)

    if options.is_a?(Hash) && options[:pattern]
      pattern = options[:pattern]

      # Support for named capture groups
      if options[:named_captures] && options[:named_captures] == true
        regex = Regexp.new(pattern)
        match = regex.match(response.content)
        return match&.named_captures || response.content
      end

      # Support for multiple matches
      if options[:all_matches] && options[:all_matches] == true
        return response.content.scan(Regexp.new(pattern))
      end

      # Default: return first capture group of first match
      match = response.content.match(Regexp.new(pattern))
      return match[1] if match && match[1]
    end

    # Return original content if no pattern or no match
    response.content
  end
end

RubyLLM::ResponseParser.register(:regex, RegexParser)

# Extract an email address
email = chat.with_parser(:regex, pattern: 'Email: ([a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,})')
            .ask("My email is: Email: user@example.com")
            .content  # => "user@example.com"

# Extract named captures
contact = chat.with_parser(:regex,
                         pattern: 'Name: (?<name>[A-Za-z ]+), Phone: (?<phone>[0-9-]+)',
                         named_captures: true)
              .ask("Contact info - Name: John Doe, Phone: 555-1234")
              .content

puts contact["name"]   # => "John Doe"
puts contact["phone"]  # => "555-1234"

# Extract all matches
numbers = chat.with_parser(:regex,
                         pattern: '\d+',
                         all_matches: true)
              .ask("Here are some numbers: 42, 17, 99, 3.14")
              .content  # => ["42", "17", "99", "3", "14"]
```

## Advanced Usage

### Chaining Parsers

You can create parser chains by registering a parser that calls another parser:

```ruby
module JsonToYamlParser
  def self.parse(response, options)
    # First use the JSON parser
    json_data = RubyLLM::ResponseParser::JsonParser.parse(response, options)

    # Convert to YAML format
    require 'yaml'
    json_data.to_h.to_yaml
  end
end

RubyLLM::ResponseParser.register(:json_to_yaml, JsonToYamlParser)
```

### Dynamic Parser Selection

You can dynamically select parsers based on response content:

```ruby
module AutoParser
  def self.parse(response, options)
    content = response.content.to_s

    if content.start_with?('{') && content.end_with?('}')
      RubyLLM::ResponseParser::JsonParser.parse(response, options)
    elsif content.include?('</') && content.include?('>')
      RubyLLM::ResponseParser::XmlParser.parse(response, {tag: 'result'})
    else
      content
    end
  end
end

RubyLLM::ResponseParser.register(:auto, AutoParser)

# Will automatically use the right parser based on content
result = chat.with_parser(:auto)
             .ask("Give me either JSON or XML, your choice")
             .content
```

### Stateful Parsers

You can create stateful parsers by using class variables:

```ruby
module AccumulatingParser
  @@accumulated = []

  def self.parse(response, options)
    @@accumulated << response.content
    @@accumulated
  end

  def self.reset
    @@accumulated = []
  end
end

RubyLLM::ResponseParser.register(:accumulate, AccumulatingParser)

# Will collect responses across multiple requests
chat.with_parser(:accumulate)
    .ask("Give me part 1")
    .content  # => ["part 1 content"]

chat.with_parser(:accumulate)
    .ask("Give me part 2")
    .content  # => ["part 1 content", "part 2 content"]

# Reset when done
AccumulatingParser.reset
```

## Error Handling

Custom parsers should handle errors gracefully. When a parsing error occurs, your parser can:

1. Return the original response
2. Return a default value
3. Raise a custom error

```ruby
module SafeJsonParser
  def self.parse(response, options)
    return response unless response.content.is_a?(String)

    begin
      JSON.parse(response.content, object_class: OpenStruct)
    rescue JSON::ParserError => e
      if options[:fallback] == :original
        # Option 1: Return original content
        response.content
      elsif options[:fallback]
        # Option 2: Return default value
        options[:fallback]
      else
        # Option 3: Raise error with context
        raise RubyLLM::ResponseParser::ParsingError,
              "Failed to parse JSON: #{e.message} in: #{response.content[0..100]}"
      end
    end
  end
end

RubyLLM::ResponseParser.register(:safe_json, SafeJsonParser)
```

## Compatibility with Response Format

Custom parsers work alongside the structured output functionality. You can use both together:

```ruby
class Person
  attr_accessor :name, :age

  def self.json_schema
    {
      type: "object",
      properties: {
        name: { type: "string" },
        age: { type: "integer" }
      }
    }
  end
end

# First use response_format to get structured JSON
result = chat.with_response_format(Person)
             .ask("Create a profile for John, age 30")

# Then use a custom parser on subsequent messages
details = chat.with_parser(:regex, pattern: 'Details: (.+)')
              .ask("Give me more details about this person")
              .content
```

The custom parser system gives you ultimate flexibility in handling model outputs, letting you extract and transform data exactly how you need it.
