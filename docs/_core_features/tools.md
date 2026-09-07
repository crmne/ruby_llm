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

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* What Tools are and why they are useful.
* How to define a Tool using `RubyLLM::Tool`.
* How to attach Tools to a `RubyLLM::Chat` and trigger them.
* What happens step by step when a model uses a Tool.
* How to handle errors inside a Tool.
* What security considerations apply when you let a model run your code.

## What Are Tools?

A tool lets the model call your Ruby code to look up a record, fetch data, or carry out an action. You write the method; RubyLLM handles passing arguments and returning the result to the model.

## Creating a Tool

Start with a tool that needs no external service:

```ruby
class CurrentTime < RubyLLM::Tool
  description "Returns the current date, time, and time zone"

  def execute
    Time.now.to_s
  end
end

chat = RubyLLM.chat.with_tools(CurrentTime)
response = chat.ask "What day is it?"
puts response.content
```

Tools can also call services your application uses. This one gets weather data from Open-Meteo:

```ruby
class Weather < RubyLLM::Tool
  description "Gets current weather for a location"

  def execute(latitude:, longitude:)
    response = Faraday.get("https://api.open-meteo.com/v1/forecast",
                           latitude: latitude, longitude: longitude,
                           current: "temperature_2m,wind_speed_10m")
    JSON.parse(response.body)
  rescue Faraday::ConnectionFailed
    { error: "The weather service is unavailable. Try again later." }
  end
end
```

### Tool Components

1.  **Inheritance:** Must inherit from `RubyLLM::Tool`.
2.  **`description`:** Tells the model what the tool does and when to call it.
3.  **`execute` Method:** The instance method containing your Ruby code. RubyLLM infers simple keyword parameters from this signature when no explicit parameter schema is declared.
4.  **Parameter declarations:** Optional. Use `parameter` for simple descriptions and types, or `parameters` for nested objects, arrays, enums, and full JSON Schema control.

> The tool's class name is automatically converted to a snake_case name used in the API call, with a trailing `Tool` dropped (e.g., `WeatherLookup` becomes `weather_lookup` and `WeatherTool` becomes `weather`). This is how the LLM would call it. You can override this by defining `tool_name` on the class:
>
> ```ruby
> class WeatherLookup < RubyLLM::Tool
>   def self.tool_name
>     "Weather"
>   end
> end
> ```
>
> `WeatherLookup.tool_name` reads the model-facing name without instantiating the tool, which is useful when you select tool classes by name before building them. The instance method `#name` delegates to it, so overriding `name` on the instance still works.
{: .note }

If the model requests an unavailable tool, RubyLLM returns an error listing the available tools and lets the conversation continue.

## Declaring Parameters

The simplest case needs nothing extra. When a tool has no `parameter` or `parameters` declaration, RubyLLM builds a JSON Schema from the `execute` keyword arguments:

```ruby
class Weather < RubyLLM::Tool
  description "Gets current weather for a location"

  def execute(latitude:, longitude:, units: "metric")
    # ...
  end
end
```

Required keywords become required string parameters. Optional keywords become optional string parameters. A tool with `def execute` receives an empty object schema.

Ruby method signatures do not expose reliable JSON Schema types or descriptions, so add explicit declarations when those details matter. For the `parameter` helper, the `parameters` DSL, and supplying JSON Schema manually, see [Tool Parameters]({% link _core_features/tool-parameters.md %}).

## Using Tools in Chat

Pass tool classes directly when they need no constructor arguments:

```ruby
chat = RubyLLM.chat(model: '{{ site.models.openai_tools }}').with_tools(Weather)
response = chat.ask "What's the weather in Berlin? Latitude 52.52, longitude 13.40."
puts response.content
```

Pass an instance when a tool needs application context, such as the current user. See [Custom Initialization]({% link _core_features/tool-parameters.md %}#custom-initialization).

You can add, replace, or clear the available tools:

```ruby
chat.with_tools(CurrentTime)
chat.with_tools(nil).with_tools(CurrentTime)
chat.with_tools(nil)
```

The first call adds `CurrentTime` to the existing tools. The second replaces the set; the third clears it.

For controlling which tools the model may use, how many calls it can make in one turn, concurrent execution, model compatibility, and callbacks, see [Controlling Tool Execution]({% link _core_features/tool-execution.md %}).

## The Tool Execution Flow

One `ask` call handles the conversation loop:

1. The model receives your question and the available tool descriptions.
2. If it requests a tool, RubyLLM calls `execute` with the model's arguments.
3. The result becomes a tool message, and RubyLLM asks the model to continue.
4. When the model answers without requesting more tools, `ask` returns its message.

For full control over this loop (running each turn as its own job, setting an iteration budget, or stopping and resuming elsewhere), see [Driving the Loop Yourself]({% link _advanced/agentic-workflows.md %}#driving-the-loop-yourself).

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

Use built-in [Server Tools]({% link _core_features/server-tools.md %}#mcp-servers) when the provider should connect to a remote MCP server. For an MCP client running in your Ruby application, see the community [`ruby_llm-mcp`](https://github.com/patvice/ruby_llm-mcp) gem.

## Debugging Tools

Set the `RUBYLLM_DEBUG` environment variable to see detailed logging, including tool calls and results.

```bash
export RUBYLLM_DEBUG=true
# Run your script
```

See the [Error Handling Guide]({% link _advanced/error-handling.md %}#debugging) for more on debugging.

## Next Steps

*   [Tool Parameters]({% link _core_features/tool-parameters.md %}) - Declare flat arguments, structured schemas, and provider-specific metadata.
*   [Controlling Tool Execution]({% link _core_features/tool-execution.md %}) - Steer tool choice, call counts, approval, concurrency, and callbacks.
*   [Chatting with AI Models]({% link _core_features/chat.md %}) - The conversational core that tools plug into.
*   [Error Handling]({% link _advanced/error-handling.md %}) - Recover from failures across the whole stack.
