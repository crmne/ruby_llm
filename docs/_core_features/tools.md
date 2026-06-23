---
layout: default
title: Tools
nav_order: 2
has_children: true
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

* What Tools are and why they are useful.
* How to define a Tool using `RubyLLM::Tool`.
* How to attach Tools to a `RubyLLM::Chat` and trigger them.
* What happens step by step when a model uses a Tool.
* How to handle errors inside a Tool.
* What security considerations apply when you let a model run your code.

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
  desc "Gets current weather for a location"

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
2.  **`desc` / `description`:** A class method defining what the tool does. Crucial for the AI model to understand its purpose. Keep it clear and concise.
3.  **`execute` Method:** The instance method containing your Ruby code. RubyLLM v1.15+ infers simple keyword parameters from this signature when no explicit parameter schema is declared.
4.  **Parameter declarations:** Optional. Use `param` for simple descriptions and types, or `params` for nested objects, arrays, enums, and full JSON Schema control.

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

> If a model attempts to call a tool that doesn't exist (sometimes called "tool hallucination"), RubyLLM handles this gracefully by:
>
> 1. Returning an error message to the model indicating which tool it tried to call
> 2. Listing the actually available tools
> 3. Allowing the conversation to continue so the model can correct itself
>
> This prevents crashes and gives the model a chance to use the correct tool or respond appropriately.
{: .note }

## Declaring Parameters

RubyLLM ships with three complementary approaches to telling the model what arguments a tool accepts:

*   **Signature inference** for simple flat arguments.
*   The **`param` helper** for quick, flat argument lists. (v1.0+)
*   The **`params` DSL** for expressive, structured inputs. (v1.9+)

The simplest case needs nothing extra. When a tool has no `param` or `params` declaration, RubyLLM builds a JSON Schema from the `execute` keyword arguments:

```ruby
class Weather < RubyLLM::Tool
  desc "Gets current weather for a location"

  def execute(latitude:, longitude:, units: "metric")
    # ...
  end
end
```

Required keywords become required string parameters. Optional keywords become optional string parameters. A tool with `def execute` receives an empty object schema.

Ruby method signatures do not expose reliable JSON Schema types or descriptions, so add explicit declarations when those details matter. For the `param` helper, the `params` DSL, and supplying JSON Schema manually, see [Tool Parameters]({% link _core_features/tool-parameters.md %}).

## Using Tools in Chat

Attach tools to a `Chat` instance using `with_tool` or `with_tools`.

```ruby
chat = RubyLLM.chat(model: '{{ site.models.openai_tools }}') # Use a model that supports tools

# Instantiate your tool if it requires arguments, otherwise use the class
weather_tool = Weather.new

chat.with_tool(weather_tool)
# Or add multiple: chat.with_tools(WeatherLookup, AnotherTool.new)

# Replace all tools with new ones
chat.with_tools(NewTool, AnotherTool, replace: true)

# Clear all tools
chat.with_tools(replace: true)

response = chat.ask "What's the current weather like in Berlin? (Lat: 52.52, Long: 13.40)"
puts response.content
# => "Current weather at 52.52, 13.4: Temperature: 12.5°C, Wind Speed: 8.3 km/h, Conditions: Mainly clear, partly cloudy, and overcast."
```

For controlling which tools the model may use, how many calls it can make in one turn, concurrent execution, model compatibility, and callbacks, see [Controlling Tool Execution]({% link _core_features/tool-execution.md %}).

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

For full control over the loop the tool execution flow runs (running each turn as its own job, setting an iteration budget, or stopping and resuming elsewhere), see [Driving the Loop Yourself]({% link _advanced/agentic-workflows.md %}#driving-the-loop-yourself).

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

## Next Steps

*   [Tool Parameters]({% link _core_features/tool-parameters.md %}) - Declare flat arguments, structured schemas, and provider-specific metadata.
*   [Controlling Tool Execution]({% link _core_features/tool-execution.md %}) - Steer tool choice, call counts, concurrency, and callbacks.
*   [Chatting with AI Models]({% link _core_features/chat.md %}) - The conversational core that tools plug into.
*   [Error Handling]({% link _advanced/error-handling.md %}) - Recover from failures across the whole stack.
