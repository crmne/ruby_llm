---
layout: default
title: Tools
parent: Guides
nav_order: 3
permalink: /guides/tools
---

# Using Tools with RubyLLM

Tools allow AI models to call your Ruby code to perform actions or retrieve information. This guide explains how to create and use tools with RubyLLM.

## What Are Tools?

Tools (also known as "functions" or "plugins") let AI models:

1. Recognize when external functionality is needed
2. Call your Ruby code with appropriate parameters
3. Use the results to enhance their responses

Common use cases include:
- Retrieving real-time data
- Performing calculations
- Accessing databases
- Controlling external systems

## Creating a Tool

Tools are defined as Ruby classes that inherit from `RubyLLM::Tool`:

```ruby
class Weather < RubyLLM::Tool
  description "Gets current weather for a location"
  param :latitude, desc: "Latitude (e.g., 52.5200)"
  param :longitude, desc: "Longitude (e.g., 13.4050)"

  def execute(latitude:, longitude:)
    url = "https://api.open-meteo.com/v1/forecast?latitude=#{latitude}&longitude=#{longitude}&current=temperature_2m,wind_speed_10m"

    response = Faraday.get(url)
    data = JSON.parse(response.body)
  rescue => e
    { error: e.message }
  end
end
```

### Tool Components

Each tool has these key elements:

1. **Description** - Explains what the tool does, helping the AI decide when to use it
2. **Parameters** - Define the inputs the tool expects
3. **Execute Method** - The code that runs when the tool is called

### Parameter Definition

Parameters accept several options:

```ruby
param :parameter_name,
  type: :string,          # Data type (:string, :integer, :boolean, :array, :object)
  desc: "Description",    # Description of what the parameter does
  required: true          # Whether the parameter is required (default: true)
```

## Using Tools in Chat

To use a tool, attach it to a chat:

```ruby
# Create the chat
chat = RubyLLM.chat

# Add a tool
chat.with_tool(Weather)

# Now you can ask questions that might require weather data
response = chat.ask "What's the weather in Berlin? (52.5200, 13.4050)?"
# => "The current weather in Berlin is as follows:\n- **Temperature:** 4.6°C\n- **Wind Speed:** 6.6 km/h\n\nPlease note that the weather information is up to date as of March 15, 2025, at 20:15 GMT."
```

### Multiple Tools

You can provide multiple tools to a single chat:

```ruby
require 'tzinfo'

class TimeInfo < RubyLLM::Tool
  description 'Gets the current time in various timezones'
  param :timezone,
        desc: "Timezone name (e.g., 'UTC', 'America/New_York')"

  def execute(timezone:)
    time = TZInfo::Timezone.get(timezone).now.strftime('%Y-%m-%d %H:%M:%S')
    "Current time in #{timezone}: #{time}"
   rescue StandardError => e
      { error: e.message }
   end
end

# Add multiple tools
chat = RubyLLM.chat
  .with_tools(Weather, TimeInfo)

# Ask questions that might use either tool
chat.ask "What's the temperature in Rome?"
chat.ask "What's the time in Tokyo?"
```

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
    # Search in @database
    @database.search(query, limit: limit)
  end
end

# Initialize with dependencies
search_tool = DocumentSearch.new(MyDatabase)
chat.with_tool(search_tool)
```

## The Tool Execution Flow

Here's what happens when a tool is used:

1. You ask a question
2. The model decides a tool is needed
3. The model selects the tool and provides arguments
4. RubyLLM calls your tool's `execute` method
5. The result is sent back to the model
6. The model incorporates the result into its response

For example:

```ruby
response = chat.ask "What's the weather like in Paris? Coordinates are 48.8566, 2.3522. Also, what time is it there?"

# Behind the scenes:
# 1. Model decides it needs weather data
# 2. Model calls Weather with coordinates for Paris
# 3. Tool returns "Current weather: 22°C, Wind: 8 km/h"
# 4. Model decides it needs time information
# 5. Model calls TimeInfo with timezone "Europe/Paris"
# 6. Tool returns "Current time in Europe/Paris: 2025-03-15 14:30:45 CET"
# 7. Model incorporates both results in its response
```

## Debugging Tools

Enable debugging to see tool calls in action:

```ruby
# Enable debug logging
ENV['RUBYLLM_DEBUG'] = 'true'

# Make a request
chat.ask "What's the weather in New York? Coordinates are 40.7128, -74.0060"

# Console output:
# D, -- RubyLLM: Tool weather_api called with: {"latitude"=>"40.7128", "longitude"=>"-74.0060"}
# D, -- RubyLLM: Tool weather_api returned: "Current weather: 18°C, Wind: 12 km/h"
```

## Error Handling

Tools should handle errors differently based on whether they're recoverable by the LLM or require application intervention:

```ruby
class Weather < RubyLLM::Tool
  description "Gets current weather for a location"
  param :latitude, desc: "Latitude (e.g., 52.5200)"
  param :longitude, desc: "Longitude (e.g., 13.4050)"

  def execute(latitude:, longitude:)
    validate_coordinates!(latitude, longitude)
    response = Faraday.get(weather_api_url(latitude, longitude))

    case response.status
    when 429
      # Return errors the LLM should know about and can retry
      { error: "Rate limit exceeded. Please try again in 60 seconds." }
    when 200
      JSON.parse(response.body)
    else
      # Let serious problems bubble up
      raise "Weather API error: #{response.status}"
    end
  end

  private
    def validate_coordinates!(lat, long)
      lat = lat.to_f
      long = long.to_f

      if lat.abs > 90 || long.abs > 180
        # Return validation errors to the LLM
        { error: "Invalid coordinates. Latitude must be between -90 and 90, longitude between -180 and 180." }
      end
    end

    def weather_api_url(lat, long)
      "https://api.open-meteo.com/v1/forecast?latitude=#{lat}&longitude=#{long}&current=temperature_2m"
    end
end
```

Handle application-level errors in your code:

```ruby
begin
  chat = RubyLLM.chat.with_tool(Weather)
  response = chat.ask "What's the weather in Berlin?"
rescue RubyLLM::Error => e
  # Handle LLM-specific errors
  Rails.logger.error "LLM error: #{e.message}"
  raise
rescue StandardError => e
  # Handle other unexpected errors
  Rails.logger.error "Tool execution failed: #{e.message}"
  raise
end
```

### Error Handling Guidelines

When implementing tools, follow these principles:

1. **Return errors to the LLM when:**
   - Input validation fails
   - The operation can be retried (rate limits, temporary failures)
   - Alternative approaches might work

2. **Let errors bubble up when:**
   - The tool encounters unexpected states
   - System resources are unavailable
   - Authentication or authorization fails
   - Data integrity is compromised

The LLM can handle returned errors intelligently by:
- Retrying with different parameters
- Suggesting alternative approaches
- Explaining the issue to the user
- Using different tools to accomplish the task

## Simple Tool Parameters

RubyLLM currently only supports simple parameter types: strings, numbers, and booleans. Complex types like arrays and objects are not supported.

```ruby
class WeatherTool < RubyLLM::Tool
  description "Gets current weather for a location"

  param :latitude,
    type: :string,
    desc: "Latitude (e.g., 52.5200)"

  param :longitude,
    type: :string,
    desc: "Longitude (e.g., 13.4050)"

  param :unit,
    type: :string,
    desc: "Temperature unit. Must be 'celsius' or 'fahrenheit'",
    required: false

  def execute(latitude:, longitude:, unit: 'celsius')
    # Weather lookup logic here
  end
end
```

> Note: For parameters with limited valid values, clearly specify them in the description.

## Security Considerations

When implementing tools that process user input (via the AI):

* Avoid using `eval`, `system` or similar methods with unsanitized input
* Remember that AI models might be tricked into producing dangerous inputs
* Validate all inputs and use appropriate sanitization

## When to Use Tools

Tools are best for:

1. **External data retrieval** - Getting real-time information like weather, prices, or database records
2. **Computation** - When calculations are complex or involve large numbers
3. **System integration** - Connecting to external APIs or services
4. **Data processing** - Working with files, formatting data, or analyzing information
5. **Stateful operations** - When you need to maintain state between calls