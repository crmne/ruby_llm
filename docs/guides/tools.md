---
layout: default
title: Tools
parent: Guides
nav_order: 3
permalink: /guides/tools
---

# Using Tools with RubyLLM
{: .no_toc }

Tools (also known as Function Calling or Plugins) allow AI models to interact with external systems by calling your Ruby code. This enables them to access real-time data, perform actions, or use capabilities beyond their built-in knowledge.
{: .fs-6 .fw-300 }

## Table of contents
{: .no_toc .text-delta }

1. TOC
{:toc}

---

After reading this guide, you will know:

*   What Tools are and why they are useful.
*   How to define a Tool using `RubyLLM::Tool`.
*   How to define parameters for your Tools.
*   How to use Tools within a `RubyLLM::Chat`.
*   The execution flow when a model uses a Tool.
*   How to handle errors within Tools.
*   Security considerations when using Tools.

## What Are Tools?

Tools bridge the gap between the AI model's conversational abilities and the real world. They allow the model to delegate tasks it cannot perform itself to your application code.

Common use cases:

*   **Fetching Real-time Data:** Get current stock prices, weather forecasts, news headlines, or sports scores.
*   **Database Interaction:** Look up customer information, product details, or order statuses.
*   **Calculations:** Perform precise mathematical operations or complex financial modeling.
*   **External APIs:** Interact with third-party services (e.g., send an email, book a meeting, control smart home devices).
*   **Executing Code:** Run specific business logic or algorithms within your application.

## Creating a Tool

Define a tool by creating a class that inherits from `RubyLLM::Tool`.

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

1.  **Inheritance:** Must inherit from `RubyLLM::Tool`.
2.  **`description`:** A class method defining what the tool does. Crucial for the AI model to understand its purpose. Keep it clear and concise.
3.  **`param`:** A class method used to define each input parameter.
    *   **Name:** The first argument (a symbol) is the parameter name. It will become a keyword argument in the `execute` method.
    *   **`type:`:** (Optional, defaults to `:string`) The expected data type. Common types include `:string`, `:integer`, `:number` (float), `:boolean`. Provider support for complex types like `:array` or `:object` varies. Stick to simple types for broad compatibility.
    *   **`desc:`:** (Required) A clear description of the parameter, explaining its purpose and expected format (e.g., "The city and state, e.g., San Francisco, CA").
    *   **`required:`:** (Optional, defaults to `true`) Whether the AI *must* provide this parameter when calling the tool. Set to `false` for optional parameters and provide a default value in your `execute` method signature.
4.  **`execute` Method:** The instance method containing your Ruby code. It receives the parameters defined by `param` as keyword arguments. Its return value (typically a String or Hash) is sent back to the AI model.

{: .note }
The tool's class name is automatically converted to a snake_case name used in the API call (e.g., `WeatherLookup` becomes `weather_lookup`).

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

## Using Tools in Chat

Attach tools to a `Chat` instance using `with_tool` or `with_tools`.

```ruby
# Create a chat instance
chat = RubyLLM.chat(model: 'gpt-4o') # Use a model that supports tools

# Instantiate your tool if it requires arguments, otherwise use the class
weather_tool = WeatherLookup.new

# Add the tool(s) to the chat
chat.with_tool(weather_tool)
# Or add multiple: chat.with_tools(WeatherLookup, AnotherTool.new)

# Ask a question that should trigger the tool
response = chat.ask "What's the current weather like in Berlin? (Lat: 52.52, Long: 13.40)"
puts response.content
# => "Current weather at 52.52, 13.4: Temperature: 12.5°C, Wind Speed: 8.3 km/h, Conditions: Mainly clear, partly cloudy, and overcast."
```

{: .warning }
Ensure the model you select supports function calling/tools. Check model capabilities using `RubyLLM.models.find('your-model-id').supports_functions`. Attempting to use `with_tool` on an unsupported model will raise `RubyLLM::UnsupportedFunctionsError`.

## The Tool Execution Flow

When you `ask` a question that the model determines requires a tool:

1.  **User Query:** Your message is sent to the model.
2.  **Model Decision:** The model analyzes the query and its available tools (based on their descriptions). It decides the `WeatherLookup` tool is needed and extracts the latitude and longitude.
3.  **Tool Call Request:** The model responds *not* with text, but with a special message indicating a tool call, including the tool name (`weather_lookup`) and arguments (`{ latitude: 52.52, longitude: 13.40 }`).
4.  **RubyLLM Execution:** RubyLLM receives this tool call request. It finds the registered `WeatherLookup` tool and calls its `execute(latitude: 52.52, longitude: 13.40)` method.
5.  **Tool Result:** Your `execute` method runs (calling the weather API) and returns a result string.
6.  **Result Sent Back:** RubyLLM sends this result back to the AI model in a new message with the `:tool` role.
7.  **Final Response Generation:** The model receives the tool result and uses it to generate a natural language response to your original query.
8.  **Final Response Returned:** RubyLLM returns the final `RubyLLM::Message` object containing the text generated in step 7.

This entire multi-step process happens behind the scenes within a single `chat.ask` call when a tool is invoked.

## Debugging Tools

Set the `RUBYLLM_DEBUG` environment variable to see detailed logging, including tool calls and results.

```bash
export RUBYLLM_DEBUG=true
# Run your script
```

You'll see log lines similar to:

```
D, [timestamp] -- RubyLLM: Tool weather_lookup called with: {:latitude=>52.52, :longitude=>13.4}
D, [timestamp] -- RubyLLM: Tool weather_lookup returned: "Current weather at 52.52, 13.4: Temperature: 12.5°C, Wind Speed: 8.3 km/h, Conditions: Mainly clear, partly cloudy, and overcast."
```
See the [Error Handling Guide]({% link guides/error-handling.md %}#debugging) for more on debugging.

## Error Handling in Tools

Proper error handling within your `execute` method is crucial.

*   **Recoverable Errors (Return Hash):** If the tool fails in a way the LLM might fix (e.g., bad input from the LLM, temporary external API issue), `return` a Hash with an `:error` key. This informs the LLM about the problem.

    ```ruby
    def execute(location:, unit: "celsius")
      if location.length < 3
        return { error: "Location name '#{location}' seems too short. Please provide a more specific location." }
      end
      # ... rest of the logic ...
    rescue Faraday::ConnectionFailed
      { error: "Could not connect to the weather service. Please try again later." }
    end
    ```

*   **Unrecoverable Errors (Raise Exception):** If the error is internal to your application or tool (e.g., missing configuration, database down), `raise` an exception. This will stop the chat interaction and propagate the error to your application's main error handling.

    ```ruby
    def execute(query:)
      api_key = ENV['INTERNAL_DB_KEY']
      raise "Configuration Error: INTERNAL_DB_KEY not set!" unless api_key
      # ... query database ...
    rescue ActiveRecord::StatementInvalid => e
      # Let application handle critical DB errors
      raise e
    end
    ```

See the [Error Handling Guide]({% link guides/error-handling.md %}#handling-errors-within-tools) for more discussion.

## Security Considerations

{: .warning }
Treat any arguments passed to your `execute` method as potentially untrusted user input, as the AI model generates them based on the conversation.

*   **NEVER** use methods like `eval`, `system`, `send`, or direct SQL interpolation with raw arguments from the AI.
*   **Validate and Sanitize:** Always validate parameter types, ranges, formats, and allowed values. Sanitize strings to prevent injection attacks if they are used in database queries or system commands (though ideally, avoid direct system commands).
*   **Principle of Least Privilege:** Ensure the code within `execute` only has access to the resources it absolutely needs.

## Next Steps

*   [Chatting with AI Models]({% link guides/chat.md %})
*   [Streaming Responses]({% link guides/streaming.md %}) (See how tools interact with streaming)
*   [Rails Integration]({% link guides/rails.md %}) (Persisting tool calls and results)
*   [Error Handling]({% link guides/error-handling.md %})