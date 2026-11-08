---
layout: default
title: Controlling Tool Execution
nav_order: 2
description: Choose tools, require approval, run calls concurrently, and observe their results
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* How to control whether the model can call tools and which one.
* How to limit how many tool calls appear in one assistant response.
* How a tool call pauses to ask a person, for an approval or anything else, and carries on with the answer.
* How to run multiple tool calls concurrently for I/O-bound work.
* How to keep a tool that shares state from running alongside others.
* How a tool ends the turn without another model call.
* How to access the executing tool call from inside a tool.
* What happens when a model does not support function calling.
* How to observe tool calls and results with callbacks.
* How to report what a slow tool is doing while it runs.
* How to cap tool usage to prevent runaway loops.
* How to run tools that take longer than a request, or pause until something happens.

By default RubyLLM lets the model decide when to call tools and runs them sequentially. When you need tighter control, these options let you steer tool choice, parallelism, and observability per chat.

## Tool Call Controls

Use `choice:` to require or select a tool and `calls:` to limit how many calls the model returns in one response:

```ruby
chat.with_tools(Weather, Calculator)
chat.with_tool_options(choice: :required, calls: :one)
```

### Tool Choice

Use `choice` to control whether the model can call tools and which one it can call.

```ruby
# Model decides if a tool is needed
chat.with_tools(Weather, Calculator).with_tool_options(choice: :auto)

# Model must call a tool
chat.with_tools(Weather, Calculator).with_tool_options(choice: :required)

# Disable tool calls
chat.with_tools(Weather, Calculator).with_tool_options(choice: :none)

# Force one specific tool (symbol or class)
chat.with_tools(Weather, Calculator).with_tool_options(choice: :weather)
chat.with_tools(Weather, Calculator).with_tool_options(choice: Weather)
```

After a required or specific tool executes, RubyLLM clears that choice so the model can answer without calling it again.

Disabling tool calls keeps the tools registered on the chat. Set `choice: :auto` to make them available again. Bedrock Converse has no such setting and raises `ArgumentError`:

```ruby
chat.with_tool_options(choice: :none)
chat.ask "Explain what you can answer without calling a tool."
chat.with_tool_options(choice: :auto)
```

### Calls Per Response

Use `calls` to control how many tool calls the model may return in a single assistant response.

```ruby
chat.with_tools(Weather, Calculator).with_tool_options(calls: :many)

chat.with_tools(Weather, Calculator).with_tool_options(calls: :one)
# equivalent:
chat.with_tools(Weather, Calculator).with_tool_options(calls: 1)
```

Without `calls:`, the provider's default applies. OpenAI and Anthropic honor `calls: :one`; Gemini can still return several calls. Multiple calls run sequentially unless you enable [concurrent execution](#concurrent-tool-execution).

### Clearing Tools and Options

Call `with_tools(nil)` to clear the attached tool list. It leaves the options set with `with_tool_options` in place; pass `nil` options to reset `choice`, `calls`, and `concurrency`:

```ruby
chat.with_tools(nil)       # forget the tools, keep the options
chat.with_tool_options(choice: nil, calls: nil, concurrency: nil) # reset all three
```

## Asking a Person

Some calls need a person before they can go on: a refund someone must approve, a seat only the traveller can choose. The call pauses until they answer. No process waits for them: `ask` and `complete` return, the chat is `waiting?`, and the `complete` after the answer carries the call on.

### Requiring Approval

Some tools should not run without a human decision: issuing refunds, deleting records, sending email. Declare them with `requires_approval`, and the chat asks before the tool runs:

```ruby
class IssueRefund < RubyLLM::Tool
  description "Issues a refund for an order"
  requires_approval

  def execute(order_id:)
    Refunds.issue!(order_id)
  end
end

chat = RubyLLM.chat.with_tools(IssueRefund)
chat.ask "Refund order 42"

question = chat.pending_questions.first
question.approval?           # => true
question.tool_call.name      # => "issue_refund"
question.tool_call.arguments # => {"order_id"=>"42"}
```

An approval is a question answered yes or no. Approve it, then continue the loop:

```ruby
question.approve
chat.complete # runs the tool, then lets the model continue
```

A declined call never runs: the model receives a structured result saying the user denied the call, and the conversation continues from there. Give a note, and the model gets it as the call's result instead, so it knows why:

```ruby
question.decline("The order shipped already")
chat.complete # appends the refusal and asks the model to respond
```

The model sees a note as `{"error":"The order shipped already"}`. To give it a result of your own shape, decline with a Hash, and the model gets that Hash as the call's result:

```ruby
question.decline(error: "Denied", reason: "Refunds over $500 need a manager")
```

When the user approves a call and says "don't ask again", pass `remember: true`:

```ruby
question.approve(remember: true)
chat.complete
```

Later calls to the same tool run without asking for the rest of the chat. Approving a call that already has a result remembers nothing. A [code execution]({% link _advanced/code-execution.md %}) call that asks for a wider sandbox is the exception: each one waits for its own approval, and `remember: true` raises `ArgumentError` for it. See [Sandboxes]({% link _advanced/sandboxes.md %}#asking-for-a-wider-sandbox).

To read decisions from your application, pass a resolver block. It receives the `ToolCall` and returns `true` to execute, `false` to deny, or `nil` while the decision is pending:

```ruby
class DeleteRecord < RubyLLM::Tool
  requires_approval { |tool_call| Approvals.status(tool_call.id) }
end
```

The resolver can run repeatedly while a call waits, including after a job resumes. Make it an idempotent read. If it creates an approval request, use a find-or-create operation.

### Asking from a Tool

A tool can ask the person something itself while it runs. Call `ask` from `execute`:

```ruby
class BookFlight < RubyLLM::Tool
  description "Books a flight"
  parameter :destination, description: "The city to fly to"

  def execute(destination:)
    seat = ask("Window or aisle?", choices: %w[window aisle]) or return "No seat chosen."
    Flights.book!(destination, seat:)
  end
end

chat = RubyLLM.chat.with_tools(BookFlight)
chat.ask "Book me a flight to Lisbon"

question = chat.pending_questions.first
question.message              # => "Window or aisle?"
question.fields.first.choices # => ["window", "aisle"]

question.answer "window"
chat.complete
```

The call pauses on the question. Once the person answers, `complete` runs `execute` again from the top, and this time `ask` returns the answer.

Code before `ask` runs again when the call resumes, so make it safe to repeat: ask first, then act.
{: .warning }

Without options, `ask` takes free text. With `choices:`, it returns the one the person picked. A block declares several fields, in the same DSL as [`parameters`]({% link _tools/tool-parameters.md %}), and `ask` returns their values by name. `url:` asks the person to visit a page, such as to connect an account, and `ask` returns `true` once they say they did:

```ruby
name = ask("What name should the booking use?")       # => "Ada Lovelace"

passenger = ask("Who is flying?") do
  string :name, description: "As on the passport"
  integer :age, required: false
end
passenger                                              # => {name: "Ada Lovelace", age: 36}

ask("Connect your calendar", url: calendar.authorization_url)
```

`ask` returns `nil` when the person declines with `question.decline`. A note they give, `question.decline("I'll choose at the gate")`, follows the tool's result to the model, and a Hash follows it as JSON. A call can ask several questions, one after another, and each run asks them in the same order. Outside a chat, nothing can pause the call, so `ask` raises `RubyLLM::InputRequiredError`.

[MCP servers]({% link _tools/mcp.md %}#questions-from-servers) ask their questions the same way, and you answer them the same way.

### Answering Questions

`pending_questions` lists every question the chat waits on, approvals included, in the order the model made the calls. Each one has an `id`, and the chat's `answer`, `approve`, and `decline` take the question or its id, which suits a form:

```ruby
chat.pending_questions.each do |question|
  # Show the person what they decide on, with question.id in the form:
  question.message   # => "Window or aisle?", or nil for an approval
  question.fields    # => the values it asks for, with their choices
  question.url       # => a page to visit, or nil
  question.tool_call # => an approval's call, with its name and arguments
end

# Once they decide, from the form they sent:
if params[:decline]
  chat.decline(params[:question_id], params[:note])   # refuses an approval
else
  chat.answer(params[:question_id], params[:answer]) # an approval's form sends no answer
end
chat.complete
```

Answering an approval approves it, and declining one refuses its call. An approval or a page to visit takes no value, and a blank one counts as none. A question with one field takes its value, and one with several takes them by name, as keywords, a Hash, or the parameters a form sends, of which it keeps only the fields it asks for: `question.answer(name: "Ada", age: 36)`. Strings become the integers, numbers, and booleans the fields ask for, the way a form sends them. Text, and each item of a list, loses the spaces around it, so spaces alone count as left out. An answer the question can't take raises `ArgumentError`: a choice it didn't offer, a field it doesn't ask for, a value of the wrong type, or a required field left out. Its message is a whole sentence you can show the person under the form, naming a field by its title or, without one, by its name in words ("Release name needs an answer."). Answering a question again, or after its call finished, changes nothing, so a form sent twice is safe, and when two people answer one approval at once, the first decision stands. `approve` records its decision whatever came before, so use it to change a decline.

Calls that need no answer still run while the others wait. `chat.ask` and `chat.complete` return the assistant message that holds the waiting calls. If you [drive the loop yourself]({% link _advanced/agentic-workflows.md %}#driving-the-loop-yourself), stop when the chat is waiting: `chat.step until chat.complete? || chat.waiting?`. While `pending_questions` has any, a person must act.

Finish the pending calls before you send the chat another message. Otherwise `chat.ask` raises `RubyLLM::PendingToolCallsError`.

### Remote Tool Approval

Providers can also request approval for a tool running on an MCP server. These requests appear in `chat.pending_questions` as approvals, and their tool call is `remote?`. Use `approve`, `decline`, and `complete` as above; RubyLLM sends the decision to the provider instead of executing a Ruby tool, with a decline's note as its reason. See [MCP servers]({% link _tools/provider-tools.md %}#remote-tool-approval) for a working example.

<div id="approval-in-rails"></div>

### Questions in Rails

With `acts_as_chat`, questions and answers persist on tool-call records. One process can ask, another can record the answer, and a third can carry the call on, even after a deploy. `pending_questions` reads the database only, so rendering questions never builds the chat's tools or connects to its MCP servers.

The [chat UI generator]({% link _advanced/rails-generators.md %}#questions-and-attachments) builds this interface for you: a card for each question, with Approve and Deny buttons for an approval, and the choices, a field, or a form for a question, that records the answer and continues the conversation in a job. To write your own, follow the same pattern. Load the chat through its agent class in the job to restore the tools:

```ruby
class AnswersController < ApplicationController
  def create
    chat = Chat.find(params[:chat_id])
    if params[:decline]
      chat.decline(params[:question_id])
    else
      chat.answer(params[:question_id], params[:answer])
    end
    CompleteJob.perform_later(chat.id)
  end
end

class CompleteJob < ApplicationJob
  def perform(chat_id)
    SupportAgent.find(chat_id).complete
  end
end
```

`answer` takes the parameters a form sends for a question with several fields, and keeps only the fields the question asks for. Authorize who may answer through your application's permissions, as you would any other action.

A double-submitted answer enqueues two jobs, and that is safe: only one process runs a chat at a time, so the second job finds the chat running or the call answered and returns without running it. Declining an approval that is still pending while its call already runs raises `RubyLLM::ToolCallRunningError`, because the tool is already doing its work:

```ruby
class AnswersController < ApplicationController
  rescue_from RubyLLM::ToolCallRunningError do
    redirect_back fallback_location: root_path, alert: "That action is already running."
  end
end
```

A tool call record's `running?` is `true` while a process runs it, so a message's tool calls can show progress:

```erb
<% message.ruby_llm_tool_calls.each do |tool_call| %>
  <%= tool_call.name %>: <%= tool_call.running? ? "Running…" : tool_call.approval %>
<% end %>
```

Write tools that ask or require approval so running them twice is safe. A tool execution can die after its side effect succeeds but before the result is persisted, and the call runs again once its claim expires. See [Agents in Background Jobs]({% link _advanced/durable-agents.md %}#at-least-once-not-exactly-once).

[Agents in Background Jobs]({% link _advanced/durable-agents.md %}) covers jobs, restarts, and cancellation. A call without a result approved with `remember: true` is recorded as `remembered` on its tool call record, so later calls to that tool run without asking in every process.

## Concurrent Tool Execution

When a model returns multiple tool calls in one response, RubyLLM executes them sequentially by default. For I/O-bound tools, opt in to concurrent execution:

```ruby
chat.with_tools(Weather, StockPrice, Currency).with_tool_options(concurrency: true)
```

`concurrency: true` uses Ruby threads and requires no extra dependencies. You can also choose a mode explicitly:

```ruby
chat.with_tools(Weather, StockPrice, Currency).with_tool_options(concurrency: :threads)
chat.with_tools(Weather, StockPrice, Currency).with_tool_options(concurrency: :fibers)
```

The `:fibers` mode uses the optional `async` gem:

```ruby
gem "async", ">= 2.0"
```

Enable concurrent tool execution globally:

```ruby
RubyLLM.configure do |config|
  config.tool_concurrency = true
end
```

Use `:threads`, `:fibers`, `true`, or `false`.

Override it per chat when needed:

```ruby
chat.with_tool_options(concurrency: false)
```

Rails chat records use the same settings.

With concurrency enabled, tool results are added back to the conversation as each tool finishes. RubyLLM waits
for all tool results before asking the model for the next response.

### Exclusive Tools

Some tools share state that can't take two calls at once, such as a browser page: two clicks in the same round race each other. Declare them `exclusive`:

```ruby
class BrowserClick < RubyLLM::Tool
  description "Clicks an element on the open page"
  parameter :selector, description: "CSS selector"

  exclusive

  def execute(selector:)
    Browser.page.click(selector)
  end
end
```

An exclusive call waits for the calls before it to finish, runs by itself, and the calls after it wait for it. The other tools still run in parallel. When the model asks for two searches, a click, and another search, the two searches run together, then the click, then the last search. Results reach the conversation as they do without `exclusive`.

The order holds across pauses too. When an exclusive call waits for an approval or returns a task, the calls after it stay pending, and run on the `complete` that finishes it. This applies with or without concurrency.

In Rails, a tool call on another thread, or on another fiber when `config.active_support.isolation_level` is `:fiber`, runs as its own unit of work, as Rails expects of any work on another thread. It checks out its own database connection and doesn't see the caller's `Current` attributes. Give the tool what it needs when you create it:

```ruby
class SearchDocuments < RubyLLM::Tool
  description "Searches the account's documents"
  parameter :query, description: "Search query"

  def initialize(account:)
    @account = account
  end

  def execute(query:)
    @account.documents.search(query).map(&:title)
  end
end

chat.with_tools(SearchDocuments.new(account: Current.account)).with_tool_options(concurrency: :fibers)
```

Or set the state the tools need around each call, in the thread or fiber that runs it, with [`around_tool_call`]({% link _core_features/chat-callbacks.md %}#wrapping-tool-calls):

```ruby
account = Current.account
chat.around_tool_call { |_call, &run| Current.set(account:, &run) }
```

## Ending the Turn

Some tools say the last word. A triage turn exists to file the ticket, and once the tool has filed it, asking the model to respond only buys an extra call and a "Done!" nobody reads. Call `halt` to end the turn with the tool's result:

```ruby
class FileTicket < RubyLLM::Tool
  description "Files the ticket under a category"
  parameter :category, description: "bug, billing, or question"

  def initialize(ticket)
    @ticket = ticket
  end

  def execute(category:)
    @ticket.update!(category:)
    halt "Filed as #{category}"
  end
end

response = chat.ask "Triage this ticket: #{ticket.body}"
response.halted? # => true
response.content # => "Filed as bug"
```

`halt` stops `execute` where you call it, and its argument is the call's result, which reaches the conversation like any other. The other calls of the round still run, then the turn ends: `ask` returns the halted tool result, and `complete?` is `true`. The next `ask` starts a new turn and sends the whole conversation, the halted result included. A tool result that halted has the finish reason `:halted`, which a Rails chat saves, so a reloaded chat knows the turn is over.

## Accessing the Current Tool Call

A tool sometimes needs to know which invocation triggered it, for example to attribute an audit log entry or an outbound API call to the exact tool call. Declare an optional `tool_call:` keyword on `execute` and RubyLLM fills it with the executing `ToolCall`:

```ruby
class SearchTool < RubyLLM::Tool
  description "Searches the knowledge base"
  parameter :query, description: "Search query"

  def execute(query:, tool_call: nil)
    AuditLog.create!(tool_call_id: tool_call&.id, tool_name: tool_call&.name)
    KnowledgeBase.search(query)
  end
end
```

`tool_call:` is reserved for RubyLLM and is not shown to the model. It also works during concurrent execution.

`tool_call.id` identifies one invocation. Use it to match callbacks, approvals and results. It stays the same when you reload a persisted chat or resume a pending call. If a provider reuses an ID in a later response, RubyLLM gives the new invocation its own ID and approval decision automatically.

RubyLLM stores the provider's original identifier separately as `provider_call_id` when serializing or persisting the call. It uses that identifier when sending the result back to the provider.

## Model Compatibility

RubyLLM will attempt to use tools with any model. If the model doesn't support function calling, the provider will return an appropriate error when you call `ask`.

## Monitoring Tool Calls with Callbacks

You can monitor tool execution using additive callbacks to track when tools are called and what they return.

```ruby
chat = RubyLLM.chat(model: "{{ site.models.openai_tools }}")
      .with_tools(Weather)
      .before_tool_call do |tool_call|
        puts "Calling tool: #{tool_call.name}"
        puts "Arguments: #{tool_call.arguments}"
      end
      .after_tool_result do |result|
        puts "Tool returned: #{result}"
      end

response = chat.ask "What's the weather in Paris?"
# Output:
# Calling tool: weather
# Arguments: {"latitude": "48.8566", "longitude": "2.3522"}
# Tool returned: {"temperature": 15, "conditions": "Partly cloudy"}
```


## Reporting Progress

A tool that downloads a large file, reads a scanned document, or pages through search results can take a while. Call `progress` from `execute` to say what it is doing:

```ruby
class ReadReport < RubyLLM::Tool
  description "Reads a scanned report"
  parameter :url, description: "Report URL"

  def execute(url:)
    progress "Downloading #{File.basename(url)}"
    pages = Scanner.pages(url)

    pages.each_with_index.map do |page, index|
      progress "Reading page #{index + 1} of #{pages.size}", value: index + 1, total: pages.size
      page.text
    end.join("\n")
  end
end
```

`after_tool_progress` receives the tool call and a `RubyLLM::Progress` for each report:

```ruby
chat.with_tools(ReadReport).after_tool_progress do |tool_call, progress|
  puts "#{tool_call.name}: #{progress.message}"
end
```

`progress.value` and `progress.total` are set when the tool counts its work, and `progress.fraction` gives the share done. Tools from [MCP servers]({% link _tools/mcp.md %}#progress-and-cancellation) report the server's progress through the same callback.

The callback runs in the thread or fiber that reports, before the tool's result. That includes threads and fibers the tool starts itself, such as a batch of downloads. With concurrent tool execution, callbacks for different tool calls can run at the same time, so keep shared state thread-safe. Tools can report as often as they like; throttle in the callback if you forward reports to a UI. Outside a chat, `progress` does nothing.

### Limiting Tool Calls

To cap a runaway loop, give the loop a step budget instead of raising inside a callback:

```ruby
chat = RubyLLM.chat(model: "{{ site.models.openai_tools }}")
              .with_tools(Weather)
              .ask_later("Check weather for every major city...")

10.times do
  chat.step
  break if chat.complete?
end
```

When the budget runs out the transcript is still valid, and calling `step` again resumes where it stopped. See [Driving the Loop Yourself]({% link _advanced/agentic-workflows.md %}#driving-the-loop-yourself).

## Long-Running Tools

A persisted chat claims each tool call while it runs, so no other process runs it at the same time. The process running the tool keeps renewing the claim for up to `config.max_run_time`, ten minutes by default. If the process dies, its claim expires within a minute, and another process runs the call again.

A call that runs longer than `config.max_run_time` counts as crashed, and another process may start it again, so set `config.max_run_time` above your slowest tool. Tools that [pause their call](#pausing-a-tool-call), like MCP operations that run as [tasks]({% link _tools/mcp.md %}#tasks), release their claim instead, so work that takes longer can run on its own. See [One Process at a Time]({% link _advanced/durable-agents.md %}#one-process-at-a-time) for how claims work.

## Pausing a Tool Call

Some calls can't finish while the chat waits. A contract sent for signature may wait days for a person to sign it. Return a `RubyLLM::Task` from `execute`, and the chat pauses the call the way it pauses for [an approval](#requiring-approval), so no process waits for it. Then implement `resume`, which carries the call on:

```ruby
class RequestSignature < RubyLLM::Tool
  description "Sends a contract for signature and reports when it is signed"

  def execute(contract_id:, tool_call:)
    envelope = Signatures.find_or_send(Contract.find(contract_id), key: tool_call.id)
    RubyLLM::Task.new(status: :input_required, status_message: "Waiting for the signature",
                      data: { "envelope_id" => envelope.id })
  end

  def resume(task, contract_id:)
    envelope = Signatures.find(task.data["envelope_id"])
    envelope.signed? ? "Signed on #{envelope.signed_on}" : task
  end
end
```

`ask` and `complete` return while the call waits. The chat is `waiting?`, and `pending_tasks` returns the tasks:

```ruby
chat = RubyLLM.chat.with_tools(RequestSignature)
chat.ask "Send contract 42 for signature"

chat.waiting?                      # => true
task = chat.pending_tasks.first
task.status_message                # => "Waiting for the signature"
task.input_required?               # => true
```

Each `complete` calls `resume` once for every paused call, with the task and the call's arguments. Return the call's result to finish it, or a task to keep it paused. Once every call has a result, the model carries on.

A task's `status` is `:working` while the work runs on its own, so you check again after its `poll_interval`, and `:input_required` while it waits on a person, so nothing changes until they act. Call `complete` after they do, such as from the controller that records their decision.

The call can run again if the process dies before the task is saved, so `execute` keys the request on `tool_call.id` to avoid sending it twice. `data` is what `resume` needs, as a Hash that serializes to JSON. In Rails, the task persists on its tool call, so one process can pause the chat and another can resume it, even after a deploy. To rebuild a task as your own subclass of `RubyLLM::Task`, override `task(state, tool_call:)` on the tool and return `YourTask.load(state, tool_call:)`. A subclass can override `refresh` to check on its work and `cancel` to stop it; cancelling the chat calls `cancel` on every task it waits on and drops the paused calls.

MCP tools pause the same way when a server runs a call as a [task]({% link _tools/mcp.md %}#tasks). A [subagent that waits for a person]({% link _getting_started/agents.md %}#subagents-that-wait-for-a-person) pauses its call on a task like this one, holding the ID of the subagent's chat.

## Next Steps

*   [Tool Parameters]({% link _tools/tool-parameters.md %}) - Declare flat arguments, structured schemas, and provider-specific metadata.
*   [Tools]({% link _getting_started/tools.md %}) - The execution flow, error handling, and security overview.
*   [Agentic Workflows]({% link _advanced/agentic-workflows.md %}#driving-the-loop-yourself) - Drive the tool loop yourself for full control.
*   [Chat Event Handlers]({% link _core_features/chat-callbacks.md %}) - Other lifecycle callbacks on a chat.
