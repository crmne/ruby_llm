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
* How a Tool pauses its call and resumes it later.
* How a Tool asks the user something while it runs.
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

If the model requests a tool the chat doesn't have, RubyLLM answers with an error naming up to three tools with similar names, and the conversation continues.

## Tool Namespaces

A namespace groups related tools, and lets tools in different groups share a name. Give it a description so the model knows what the group is for:

```ruby
class CustomerLookup < RubyLLM::Tool
  namespace "crm", description: "Customer records and orders"
  description "Finds a customer by email"

  def execute(email:)
    Customer.find_by(email:)&.attributes
  end
end

chat.with_tools(CustomerLookup)
chat.tools[:crm_customer_lookup]
```

The chat keys the tool by its namespace and name joined, `:crm_customer_lookup`, and raises an `ArgumentError` when another tool already has that name. The tool's own name stays `customer_lookup`, and `tool_call.namespace` names its group. RubyLLM routes calls and remembers approvals by both, including after a Rails reload. `namespace` is inherited; pass `nil` to remove an inherited namespace. Namespaced tools can be [deferred for tool search]({% link _core_features/tool-search.md %}) like any other.

The Responses protocol sends each group as a function namespace, which needs a description. Every other protocol sends the tool under its joined name, `crm_customer_lookup`, and maps the model's calls back to the namespace. Anthropic's `computer` and `browser` namespaces are the members of its [native client toolsets]({% link _core_features/provider-tools.md %}#native-client-toolsets) instead.

You can force a namespaced tool with `with_tool_options(choice: CustomerLookup)` where it travels under its joined name. Responses namespaces and Anthropic's toolset members cannot be forced, so RubyLLM raises there; use `choice: :required` instead.

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

With dozens of tools, pass `defer: true` and let the model search for the ones it needs. See [Tool Search]({% link _core_features/tool-search.md %}).

## The Tool Execution Flow

One `ask` call handles the conversation loop:

1. The model receives your question and the available tool descriptions.
2. If it requests a tool, RubyLLM calls `execute` with the model's arguments.
3. The result becomes a tool message, and RubyLLM asks the model to continue.
4. When the model answers without requesting more tools, `ask` returns its message.

For full control over this loop (running each turn as its own job, setting an iteration budget, or stopping and resuming elsewhere), see [Driving the Loop Yourself]({% link _advanced/agentic-workflows.md %}#driving-the-loop-yourself).

## Long-Running Tools

A persisted chat claims each tool call while it runs, so no other process runs it at the same time. The claim lasts `config.max_run_time`, ten minutes by default. If the process running a tool dies, another process runs the call again once the claim expires. Give a tool that legitimately runs longer its own limit:

```ruby
class GenerateReport < RubyLLM::Tool
  description "Builds the quarterly report"
  max_run_time 2.hours

  def execute(quarter:)
    Reports.build!(quarter)
  end
end
```

A run that takes longer than its `max_run_time` counts as crashed, and another process may start the call again. MCP tools use `config.max_run_time`; tools that [pause their call](#pausing-a-tool-call), like MCP operations that run as [tasks]({% link _core_features/mcp.md %}#tasks), release their claim instead. See [Durable Agents]({% link _advanced/durable-agents.md %}#one-process-at-a-time) for how claims work.

## Pausing a Tool Call

Some calls can't finish while the chat waits. A tool that hands a job to another agent may have to wait for a person to approve a change, and that can take hours. Return a `RubyLLM::Task` from `execute`, and the chat pauses the call the way it pauses for [an approval]({% link _core_features/tool-execution.md %}#requiring-approval), so no process waits for it. Then implement `resume`, which carries the call on:

```ruby
class RunSubAgent < RubyLLM::Tool
  description "Hands a job to a sub-agent"

  def execute(job:)
    run = SubAgentRun.start(job)
    return run.answer if run.finished?

    RubyLLM::Task.new(status: :input_required, status_message: "Waiting for approval", data: { "run_id" => run.id })
  end

  def resume(task, job:)
    run = SubAgentRun.find(task.data["run_id"]).continue
    run.finished? ? run.answer : task
  end
end
```

`ask` and `complete` return while the call waits. The chat is `waiting?` and `awaiting_tasks?`, and `pending_tasks` returns the tasks:

```ruby
chat = RubyLLM.chat.with_tools(RunSubAgent)
chat.ask "Deploy the new pricing page"

chat.awaiting_tasks?               # => true
task = chat.pending_tasks.first
task.status_message                # => "Waiting for approval"
task.input_required?               # => true
```

Each `complete` calls `resume` once for every paused call, with the task and the call's arguments. Return the call's result to finish it, or a task to keep it paused. Once every call has a result, the model carries on.

A task's `status` is `:working` while the work runs on its own, so you check again after its `poll_interval`, and `:input_required` while it waits on a person, so nothing changes until they act. Call `complete` after they do, such as from the controller that records their decision.

`data` is what `resume` needs, as a Hash that serializes to JSON. In Rails, the task persists on its tool call, so one process can pause the chat and another can resume it, even after a deploy. To rebuild a task as your own subclass of `RubyLLM::Task`, override `task(state, tool_call:)` on the tool and return `YourTask.load(state, tool_call:)`. A subclass can override `refresh` to check on its work and `cancel` to stop it; cancelling the chat calls `cancel` on every task it waits on and drops the paused calls.

MCP tools pause the same way when a server runs a call as a [task]({% link _core_features/mcp.md %}#tasks).

## Asking the User

A tool can ask the user something while it runs, the way an MCP server asks for input. `ask` takes the question and the fields to fill, as JSON Schema properties (`required: true` on the ones the user must fill), or `url:` for a page to visit:

```ruby
class AskTeam < RubyLLM::Tool
  description "Ask the team something you can't answer from the docs"

  parameters do
    string :question, description: "Written for a colleague"
  end

  def execute(question:)
    answer = ask(question, answer: { type: "string", title: "Answer", required: true })
    answer.accepted? ? { answer: answer[:answer] } : { error: "Nobody answered" }
  end
end
```

In a chat, the call pauses on the question as on a server's: the chat is `awaiting_input?`, `pending_inputs` lists it, and `answer` or `decline` settles it before `complete` resumes. Resuming runs `execute` again from the start, and this time `ask` returns the answer, so code before `ask` runs twice: ask first, then do the work. A call can ask several questions, one after another. Outside a chat, an unanswered `ask` raises `RubyLLM::InputRequiredError`, which `RubyLLM::MCP::InputRequiredError` now inherits from.

## Long Results

A tool that returns a lot, like a search with hundreds of hits, sends all of it to the model, and all of it stays in every later request. In a chat with a [file store]({% link _core_features/chat-files.md %}), a result longer than 10,000 characters is saved as a file instead, and the model gets its start and the file's path to read or search the rest. A tool can set its own limit, or send its results whole when it already returns them in pages, with `spill_to_file`: see [Long tool results]({% link _core_features/chat-files.md %}#what-the-model-sees) in the Chat Files guide.

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

Connect an MCP server to your chat with `with_mcp`, and the model can call its tools like your own. See [MCP Client]({% link _core_features/mcp.md %}). When the provider should connect to a remote server instead, use [Provider Tools]({% link _core_features/provider-tools.md %}#mcp-servers).

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
*   [Tool Search]({% link _core_features/tool-search.md %}) - Keep large tool sets out of the model's context until it searches for them.
*   [Code Execution]({% link _core_features/code-execution.md %}) - Let the model run Ruby, Python, JavaScript, and shell code in a sandbox.
*   [Chatting with AI Models]({% link _core_features/chat.md %}) - The conversational core that tools plug into.
*   [Error Handling]({% link _advanced/error-handling.md %}) - Recover from failures across the whole stack.
