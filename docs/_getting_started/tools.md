---
layout: default
title: Tools
nav_order: 4
has_children: true
description: Let the model call your Ruby code to look up records, search your content, and take actions.
redirect_from:
  - /guides/tools
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* What tools are and what happens when a model calls one.
* How to define a tool with `RubyLLM::Tool`.
* How to give a tool the current customer or user.
* How to add tools to a chat.
* How to report errors from a tool.
* What to watch for when a model runs your code.

## What Are Tools?

A model only knows what it learned in training and what you put in the conversation. It doesn't know where order R-1042 is, and it can't read your help center. A tool closes that gap: it's a Ruby class the model can call, with a description that says when to call it and an `execute` method that does the work.

The examples in these guides build a support desk. A customer asks where their order is. The model can't answer from memory, so it calls `LookupOrder`, reads the result, and writes a reply.

### What Happens When the Model Calls a Tool

One `ask` runs the whole exchange:

1. RubyLLM sends your question with the name, description, and parameters of each tool.
2. The model answers with a tool call instead of text: the tool's name and its arguments.
3. RubyLLM calls the tool's `execute` with those arguments and adds the result to the conversation as a tool message.
4. RubyLLM asks the model again. It may call more tools, or answer.
5. When the model answers without calling a tool, `ask` returns that answer.

You write the tool. RubyLLM handles the requests, the arguments, and the results. To run this loop one step at a time instead, for example one step per background job, see [Driving the Loop Yourself]({% link _advanced/agentic-workflows.md %}#driving-the-loop-yourself).

## Creating a Tool

A tool inherits from `RubyLLM::Tool`, describes itself, and implements `execute`. Here's the tool the support desk uses to search its help center:

```ruby
class SearchDocs < RubyLLM::Tool
  description "Searches the help center for articles that answer a customer's question"
  parameter :query, description: "What the customer wants to know"

  def execute(query:)
    Article.search(query).first(3).map do |article|
      { title: article.title, url: article.url, body: article.body }
    end
  end
end
```

`Article.search` stands for whatever search your application already has, such as a SQL query, full-text search, or the embeddings in [RAG]({% link _advanced/rag.md %}). Give the tool to a chat and ask:

```ruby
chat = RubyLLM.chat.with_tools(SearchDocs)
response = chat.ask "How do I return a jacket that doesn't fit?"
puts response.content
# => "You can return it within 30 days. Start a return from Orders..."
```

A tool has three parts:

* **`description`** tells the model what the tool does and when to call it. Write it for the model: it's the only documentation the model reads.
* **`parameter`** declares an argument the model fills, with a description. Without declarations, RubyLLM reads the keyword arguments of `execute` and treats each as a string. See [Tool Parameters]({% link _tools/tool-parameters.md %}) for types, nested objects, enums, and JSON Schema.
* **`execute`** runs your code. Return a String, or a Hash or Array that RubyLLM sends as JSON.

The model calls the tool by a name derived from its class: `SearchDocs` becomes `search_docs`, and a trailing `Tool` is dropped, so `WeatherTool` becomes `weather`. To choose another name, or to group tools under a namespace, see [Tool Names and Namespaces]({% link _tools/tool-parameters.md %}#tool-names-and-namespaces).

## Tools That Need the Current User

Most useful tools act on behalf of someone. `LookupOrder` must only find the current customer's orders, whatever order number the model asks for. Pass the customer to the tool when you create it:

```ruby
class LookupOrder < RubyLLM::Tool
  description "Looks up one of the customer's orders by its number"
  parameter :number, description: "The order number, such as R-1042"

  def initialize(customer)
    @customer = customer
  end

  def execute(number:)
    order = @customer.orders.find_by(number: number)
    return { error: "No order #{number} on this account" } unless order

    { number: order.number, status: order.status, shipped_on: order.shipped_on&.iso8601 }
  end
end
```

Pass an instance instead of the class:

```ruby
chat = RubyLLM.chat.with_tools(LookupOrder.new(current_customer), SearchDocs)
chat.ask "Where is my order R-1042?"
```

The model chooses the arguments; your code chooses whose data it may see. Scope every query to the customer, as `@customer.orders` does here, so a model that asks for someone else's order number gets nothing. An [agent]({% link _getting_started/agents.md %}#runtime-inputs) builds these tools for you from its inputs.

## Using Tools in a Chat

`with_tools` adds tools to the ones the chat already has. Pass `nil` to remove them all, then add the ones you want to replace them:

```ruby
chat.with_tools(SearchDocs)
chat.with_tools(nil).with_tools(LookupOrder.new(current_customer))
chat.with_tools(nil)
```

When the model calls a tool the chat doesn't have, RubyLLM answers with an error naming up to three tools with similar names, and the conversation continues.

[Controlling Tool Execution]({% link _tools/tool-execution.md %}) covers forcing a tool, limiting calls, requiring a person's approval, running calls concurrently, and callbacks. With dozens of tools, pass `defer: true` and let the model search for the ones it needs; see [Tool Search]({% link _tools/tool-search.md %}).

## Handling Errors in Tools

Decide who can fix the problem.

When the model can fix it, return an error as the result. The model reads it and tries again, or tells the customer. `LookupOrder` does this for an unknown order number. Do the same when a service the tool calls is down:

```ruby
def execute(query:)
  HelpCenter.search(query)
rescue Faraday::ConnectionFailed
  { error: "The help center is unavailable. Try again later." }
end
```

When only you can fix it, such as a missing API key or a database that's down, raise. The exception stops the chat and reaches your code. See [Handling Errors Within Tools]({% link _advanced/error-handling.md %}#handling-errors-within-tools).

## Security

The model writes a tool's arguments from the conversation, and the conversation includes what the customer typed. Treat arguments as untrusted input.
{: .warning }

* Never pass arguments to `eval`, `system`, `send`, or SQL strings.
* Validate types, ranges, and allowed values before acting on them.
* Scope queries to the current user, as `LookupOrder` does, and give each tool access only to what it needs.
* Require a person's [approval]({% link _tools/tool-execution.md %}#requiring-approval) before a tool does something you can't undo, such as issuing a refund.

## More Kinds of Tools

* **Agents as tools.** An agent class goes wherever a tool goes, so the model can hand a task to another agent and get its answer back. See [Subagents]({% link _getting_started/agents.md %}#subagents).
* **MCP servers.** `with_mcp` connects a [Model Context Protocol server]({% link _tools/mcp.md %}), and the model calls its tools like your own. To have the provider connect to a remote server instead, see [Provider Tools]({% link _tools/provider-tools.md %}#mcp-servers).
* **Provider tools.** Web search, code execution, and other tools the provider runs on its side. See [Provider Tools]({% link _tools/provider-tools.md %}).
* **Tools that wait.** A tool can run for hours, pause until a person signs a contract, or ask the user a question. See [Long-Running Tools]({% link _tools/tool-execution.md %}#long-running-tools), [Pausing a Tool Call]({% link _tools/tool-execution.md %}#pausing-a-tool-call), and [Asking the User]({% link _tools/tool-execution.md %}#asking-the-user).

## Long Results

A tool that returns a lot, like a search with hundreds of hits, sends all of it to the model, and all of it stays in every later request. In a chat with a [file store]({% link _core_features/file-stores.md %}), a result longer than 10,000 characters is saved as a file instead, and the model gets its start and the file's path to read or search the rest. A tool can set its own limit, or send its results whole when it already returns them in pages, with `inline_limit`: see [Long tool results]({% link _core_features/file-stores.md %}#what-the-model-sees) in the File Stores guide.

## Debugging Tools

Set `RUBYLLM_DEBUG` to log every request, including tool calls and their results:

```bash
export RUBYLLM_DEBUG=true
```

See [Debugging]({% link _advanced/error-handling.md %}#debugging) for more.

## Next Steps

* [Agents]({% link _getting_started/agents.md %}): put the support desk's model, instructions, and tools in one class.
* [Tool Parameters]({% link _tools/tool-parameters.md %}): types, nested objects, enums, names, and namespaces.
* [Controlling Tool Execution]({% link _tools/tool-execution.md %}): tool choice, approvals, concurrency, callbacks, and tools that wait.
* [Tool Search]({% link _tools/tool-search.md %}): keep large tool sets out of the model's context.
* [Code Execution]({% link _advanced/code-execution.md %}): let the model run code in a sandbox.
