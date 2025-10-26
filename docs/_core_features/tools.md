---
layout: default
title: Tools
nav_order: 2
description: Let AI call your Ruby code. Connect to databases, APIs, or any external system with function calling.
redirect_from:
  - /guides/tools
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

> The tool's class name is automatically converted to a snake_case name used in the API call (e.g., `WeatherLookup` becomes `weather_lookup`). This is how the LLM would call it. You can override this by defining a `name` method in your tool class:
>
> ```ruby
> class WeatherLookup < RubyLLM::Tool
>   def name
>     "Weather"
>   end
> end
> ```
{: .note }

### Provider-Specific Parameters
{: .d-inline-block }

v1.9.0+
{: .label .label-green }

Some providers allow you to attach extra metadata to tool definitions (for example, Anthropic's `cache_control` directive for prompt caching). Use `with_params` on your tool class to declare these once and RubyLLM will merge them into the API payload when the provider understands them.

```ruby
class TodoTool < RubyLLM::Tool
  description "Adds a task to the shared TODO list"
  param :title, desc: "Human-friendly task description"

  with_params cache_control: { type: 'ephemeral' }

  def execute(title:)
    Todo.create!(title:)
    "Added “#{title}” to the list."
  end
end
```

Provider-specific tool parameters are passed through verbatim. Use `RUBYLLM_DEBUG=true` and keep an eye on your logs when rolling out new metadata.

## Returning Rich Content from Tools

Tools can return `RubyLLM::Content` objects with file attachments, allowing you to pass images, documents, or other files from your tools to the AI model:

```ruby
class AnalyzeTool < RubyLLM::Tool
  description "Analyzes data and returns results with visualizations"
  param :query, desc: "Analysis query"

  def execute(query:)
    # Generate analysis and create visualization
    chart_path = generate_chart(query)

    # Return Content with text and attachments
    RubyLLM::Content.new(
      "Analysis complete for: #{query}",
      [chart_path]  # Attach the generated chart (array of paths/blobs)
    )
  end

  private

  def generate_chart(query)
    # Your chart generation logic
    "/tmp/chart_#{Time.now.to_i}.png"
  end
end

chat = RubyLLM.chat.with_tool(AnalyzeTool)
response = chat.ask("Analyze sales trends for Q4")
# The AI receives both the text and the chart image
```

When a tool returns a `Content` object:
- The text and attachments are preserved in the conversation history
- Vision-capable models can see and analyze attached images
- The AI can reference the attachments in its response

This is particularly useful for:
- **Data visualization:** Return charts, graphs, or diagrams
- **Document processing:** Pass PDFs or documents for the AI to analyze
- **Image generation:** Return generated or processed images
- **Multi-modal workflows:** Combine text results with visual elements

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
chat = RubyLLM.chat(model: '{{ site.models.openai_tools }}') # Use a model that supports tools

# Instantiate your tool if it requires arguments, otherwise use the class
weather_tool = Weather.new

# Add the tool(s) to the chat
chat.with_tool(weather_tool)
# Or add multiple: chat.with_tools(WeatherLookup, AnotherTool.new)

# Replace all tools with new ones
chat.with_tools(NewTool, AnotherTool, replace: true)

# Clear all tools
chat.with_tools(replace: true)

# Ask a question that should trigger the tool
response = chat.ask "What's the current weather like in Berlin? (Lat: 52.52, Long: 13.40)"
puts response.content
# => "Current weather at 52.52, 13.4: Temperature: 12.5°C, Wind Speed: 8.3 km/h, Conditions: Mainly clear, partly cloudy, and overcast."
```

### Model Compatibility

RubyLLM will attempt to use tools with any model. If the model doesn't support function calling, the provider will return an appropriate error when you call `ask`.

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

## Monitoring Tool Calls with Callbacks

You can monitor tool execution using event callbacks to track when tools are called and what they return:

```ruby
chat = RubyLLM.chat(model: '{{ site.models.openai_tools }}')
      .with_tool(Weather)
      .on_tool_call do |tool_call|
        # Called when the AI decides to use a tool
        puts "Calling tool: #{tool_call.name}"
        puts "Arguments: #{tool_call.arguments}"
      end
      .on_tool_result do |result|
        # Called after the tool returns its result
        puts "Tool returned: #{result}"
      end

response = chat.ask "What's the weather in Paris?"
# Output:
# Calling tool: weather
# Arguments: {"latitude": "48.8566", "longitude": "2.3522"}
# Tool returned: {"temperature": 15, "conditions": "Partly cloudy"}
```

These callbacks are useful for:
- **Logging and Analytics:** Track which tools are used most frequently
- **UI Updates:** Show loading states or progress indicators
- **Debugging:** Monitor tool inputs and outputs in production
- **Auditing:** Record tool usage for compliance or billing

### Example: Limiting Tool Calls

To prevent excessive API usage or infinite loops, you can use callbacks to limit tool calls:

```ruby
# Limit total tool calls per conversation
call_count = 0
max_calls = 10

chat = RubyLLM.chat(model: '{{ site.models.openai_tools }}')
      .with_tool(Weather)
      .on_tool_call do |tool_call|
        call_count += 1
        if call_count > max_calls
          raise "Tool call limit exceeded (#{max_calls} calls)"
        end
      end

# The conversation will stop if it tries to use tools more than 10 times
chat.ask("Check weather for every major city...")
```

> Raising an exception in `on_tool_call` breaks the conversation flow - the LLM expects a tool response after requesting a tool call. This can leave the chat in an inconsistent state. Consider using better models or clearer tool descriptions to prevent loops instead of hard limits.
{: .warning }

## Advanced: Halting Tool Continuation

After a tool executes, the LLM normally continues the conversation to explain what happened. In rare cases, you might want to skip this and return the tool result directly.

### What halt does

The `halt` helper stops the LLM from continuing after your tool:

```ruby
class SaveFileTool < RubyLLM::Tool
  description "Save content to a file"
  param :path, desc: "File path"
  param :content, desc: "File content"

  def execute(path:, content:)
    File.write(path, content)
    halt "Saved to #{path}"  # Returns this directly, no LLM commentary
  end
end

# Without halt: LLM adds "I've successfully saved the file to config.yml..."
# With halt: Just returns "Saved to config.yml"
```

### When you might use it

- **Token savings:** Skip the LLM's summary for simple confirmations
- **Sub-agent delegation:** When another agent fully handles the response
- **Precise responses:** When you need exact output without LLM interpretation

> The LLM's continuation is usually helpful - it provides context and natural language formatting. Only use `halt` when you specifically need to bypass this behavior.
{: .warning }

### Example with sub-agents

```ruby
class DelegateTool < RubyLLM::Tool
  description "Delegate to expert"
  param :query, desc: "The query"

  def execute(query:)
    response = RubyLLM.chat
      .with_instructions("You are an expert...")
      .ask(query) { |chunk| print chunk }  # Stream to user
    halt response.content  # Skip router's commentary
  end
end
```

> **Sub-agents work perfectly without halt!** You can create sub-agents and stream their responses without using `halt`. The router will simply summarize what the sub-agent said, which is often helpful. Use `halt` only when you specifically want to skip the router's summary.
{: .note }

## Model Context Protocol (MCP) Support

For MCP server integration, check out the community-maintained [`ruby_llm-mcp`](https://github.com/patvice/ruby_llm-mcp) gem.

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
See the [Error Handling Guide]({% link _advanced/error-handling.md %}#debugging) for more on debugging.

## Error Handling in Tools

Tools should handle errors based on whether they're recoverable:

- **Recoverable errors** (invalid parameters, external API failures): Return `{ error: "description" }`
- **Unrecoverable errors** (missing configuration, database down): Raise an exception

```ruby
def execute(location:)
  return { error: "Location too short" } if location.length < 3

  # Fetch weather data...
rescue Faraday::ConnectionFailed
  { error: "Weather service unavailable" }
end
```

See the [Error Handling Guide]({% link _advanced/error-handling.md %}#handling-errors-within-tools) for more discussion.

## Security Considerations

> Treat any arguments passed to your `execute` method as potentially untrusted user input, as the AI model generates them based on the conversation.
{: .warning }

*   **NEVER** use methods like `eval`, `system`, `send`, or direct SQL interpolation with raw arguments from the AI.
*   **Validate and Sanitize:** Always validate parameter types, ranges, formats, and allowed values. Sanitize strings to prevent injection attacks if they are used in database queries or system commands (though ideally, avoid direct system commands).
*   **Principle of Least Privilege:** Ensure the code within `execute` only has access to the resources it absolutely needs.

## Next Steps

*   [Chatting with AI Models]({% link _core_features/chat.md %})
*   [Streaming Responses]({% link _core_features/streaming.md %}) (See how tools interact with streaming)
*   [Rails Integration]({% link _advanced/rails.md %}) (Persisting tool calls and results)
*   [Error Handling]({% link _advanced/error-handling.md %})
