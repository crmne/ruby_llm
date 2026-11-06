---
layout: default
title: Agents
seo:
  title: AI Agents in Ruby
nav_order: 5
has_children: true
description: Define a model, instructions, and tools once in a Ruby class, then use it in scripts, services, jobs, and Rails records.
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* Why an agent is worth defining.
* How to declare an agent's model, instructions, and tools.
* How to give an agent runtime inputs, such as the current customer.
* How to get structured answers from an agent.
* How to keep instructions in `app/prompts`.
* How to declare callbacks and error handlers once for every chat.
* How to hand work to another agent as a subagent.
* How to use agents with Rails records.

## Why Agents?

A support chat needs the same setup wherever it runs: the model, the instructions that say how to talk to customers, and the tools that look up orders and search the help center. Without an agent, every controller, job, and console session repeats that setup with `with_instructions` and `with_tools`, and the copies drift apart.

An agent is a class that holds that setup. You name it once, after the job it does, and create a configured chat wherever you need one:

```ruby
class SupportAgent < RubyLLM::Agent
  model "{{ site.models.default_chat }}"
  instructions "You answer customers of Acme Outfitters. Be brief and friendly, and link to articles you used."
  tools SearchDocs
end

response = SupportAgent.new.ask "How do I return a jacket that doesn't fit?"
```

`SearchDocs` is the tool from the [Tools guide]({% link _getting_started/tools.md %}#creating-a-tool). An agent adds no new abilities: it's the same `Chat` you'd build by hand, configured from a class. Use a plain chat for a one-off script, and an agent once the setup is worth naming.

## Defining an Agent

Inherit from `RubyLLM::Agent` and declare the configuration with class macros. Each macro does what the matching `Chat` method does:

```ruby
class SupportAgent < RubyLLM::Agent
  model "{{ site.models.default_chat }}"
  instructions "You answer customers of Acme Outfitters. Be brief and friendly, and link to articles you used."
  tools SearchDocs
  temperature 0.2
  max_output_tokens 1_000
end
```

Feature macros such as `thinking`, `caching`, `citations`, and `compaction` follow the shape of their `with_*` methods: call them bare to turn the feature on, pass `false` to turn it off, or pass options to tune it.

| Macro | Same as | See |
| --- | --- | --- |
| `model` | `RubyLLM.chat(model:, provider:, protocol:)` | [Chat]({% link _getting_started/chat.md %}#working-with-different-models) |
| `instructions` | `with_instructions` | [Chat]({% link _getting_started/chat.md %}#giving-the-model-instructions), [Prompts](#keeping-instructions-in-prompt-templates) |
| `tools`, `tool_options` | `with_tools`, `with_tool_options` | [Tools]({% link _getting_started/tools.md %}), [Tool Execution]({% link _tools/tool-execution.md %}) |
| `mcp`, `provider_tools`, `skills` | `with_mcp`, `with_provider_tools`, `with_skills` | [MCP]({% link _tools/mcp.md %}), [Provider Tools]({% link _tools/provider-tools.md %}), [Skills]({% link _tools/skills.md %}) |
| `code_execution`, `file_store` | `with_code_execution`, `with_file_store` | [Code Execution]({% link _advanced/code-execution.md %}), [File Stores]({% link _core_features/file-stores.md %}#agents) |
| `schema` | `with_schema` | [Structured Answers](#structured-answers) |
| `temperature`, `max_output_tokens` | `with_temperature`, `with_max_output_tokens` | [Chat]({% link _getting_started/chat.md %}#controlling-responses) |
| `context_budget` | `with_context_budget` | [Request Control]({% link _core_features/chat-request-control.md %}#keeping-tool-results-in-budget) |
| `thinking`, `citations`, `caching`, `compaction` | `with_thinking`, `with_citations`, `with_caching`, `with_compaction` | [Thinking]({% link _core_features/thinking.md %}), [Citations]({% link _core_features/citations.md %}), [Prompt Caching]({% link _core_features/prompt-caching.md %}), [Request Control]({% link _core_features/chat-request-control.md %}#compacting-long-conversations) |
| `provider_options`, `headers` | `with_provider_options`, `with_headers` | [Request Control]({% link _core_features/chat-request-control.md %}) |
| `end_user`, `owner` | `with_end_user`, `with_owner` | [Request Control]({% link _core_features/chat-request-control.md %}#identifying-end-users), [Usage]({% link _core_features/cost-and-usage-tracking.md %}#one-shot-operations) |
| `fallbacks` | `with_fallbacks` | [Model Fallbacks](#model-fallbacks) |
| `context` | `with_context` | [Configuration Contexts](#configuration-contexts) |
| `inputs` | | [Runtime Inputs](#runtime-inputs) |
| `description` | | [Subagents](#subagents) |
| `chat_class` | | [Rails-Backed Agents](#rails-backed-agents) |
| `rescue_from` | | [Handling Errors](#handling-errors-with-rescue_from) |
| `after_message` and the other callbacks | `after_message` and the other callbacks | [Callbacks](#callbacks) |

## Runtime Inputs

The support desk's `LookupOrder` tool needs the customer whose orders it may read, and that customer changes with every conversation. Declare it with `inputs`, then read it in a block:

```ruby
class SupportAgent < RubyLLM::Agent
  model "{{ site.models.default_chat }}"
  inputs :customer

  instructions { "You answer #{customer.name}, a customer of Acme Outfitters. Be brief and friendly." }
  tools { [LookupOrder.new(customer), SearchDocs] }
end

agent = SupportAgent.new(customer: current_customer)
agent.ask "Where is my order R-1042?"
```

Blocks run each time the agent builds a chat, with every input available as a method, along with `chat`, the chat being configured. A value that depends on an input or on `chat` must sit in a block or lambda; a plain value is read once, when Ruby loads the class. `temperature` and `max_output_tokens` take plain values only: to set them per customer, call `with_temperature` or `with_max_output_tokens` on the chat.
{: .warning }

`model` takes a block too, so an agent can pick a model from its inputs. The `model` block runs before the chat exists, so it reads inputs but not `chat`:

```ruby
class SupportAgent < RubyLLM::Agent
  inputs :customer
  model { customer.premium? ? "{{ site.models.default_chat }}" : "{{ site.models.openai_mini }}" }
end
```

Options stay beside the block: `model(provider: :openai) { ... }`.

## Structured Answers

Give an agent a `schema`, and every answer comes back as data you read with `parsed`. This one triages incoming support email:

```ruby
class TicketTriage < Schematist::Schema
  string :category, enum: %w[billing shipping returns other]
  string :priority, enum: %w[low normal urgent]
  string :summary, description: "One sentence for the support queue"
end

class TriageAgent < RubyLLM::Agent
  model "{{ site.models.openai_mini }}"
  instructions "Triage emails sent to the Acme Outfitters help desk."
  schema TicketTriage
end
```

The schema's fields match the `tickets` table's columns, so the parsed Hash goes straight into the record:

```ruby
class TriageTicketJob < ApplicationJob
  def perform(ticket)
    ticket.update!(TriageAgent.new.ask(ticket.body).parsed)
  end
end
```

`schema` also takes a JSON Schema Hash, or a block for a schema only one agent uses:

```ruby
class TriageAgent < RubyLLM::Agent
  schema do
    string :category, enum: %w[billing shipping returns other]
    string :priority, enum: %w[low normal urgent]
  end
end
```

See [Structured Output]({% link _core_features/structured-output.md %}) for nested objects, arrays, and provider support.

## Keeping Instructions in Prompt Templates

Instructions grow. Once they're longer than a line, keep them in a template next to your other views. An agent finds its own: `SupportAgent` reads `app/prompts/support_agent/instructions.txt.erb` when the file exists, and `Admin::SupportAgent` reads `app/prompts/admin/support_agent/instructions.txt.erb`.

```erb
<%# app/prompts/support_agent/instructions.txt.erb %>
You answer <%= customer_name %>, a customer of Acme Outfitters.
Be brief and friendly. Link to every help center article you used.
Never promise a refund; offer to pass the request to the billing team.
```

Pass the template's locals to `instructions`. Use lambdas for values that come from inputs or the chat:

```ruby
class SupportAgent < RubyLLM::Agent
  inputs :customer
  instructions customer_name: -> { customer.name }
end
```

An agent picks its instructions in this order:

1. `instructions` declared on the class.
2. Its `instructions.txt.erb` template.
3. Instructions inherited from its parent class.

An empty template or `instructions ""` means no instructions. To fail loudly when the template is missing, render it explicitly with `instructions { prompt("instructions") }`, which raises `RubyLLM::PromptNotFoundError`. `prompt` also renders other templates in the agent's folder, with locals: `prompt("escalation", order: order)`.

See [Prompt Rendering]({% link _core_features/prompt-rendering.md %}) for rendering templates outside an agent.

## Model Fallbacks

`fallbacks` gives every chat the agent builds the same list of models to try when the first one fails:

```ruby
class SupportAgent < RubyLLM::Agent
  model "{{ site.models.default_chat }}"
  fallbacks "{{ site.models.openai_mini }}", "{{ site.models.anthropic_haiku }}"
end
```

Fallbacks may be model ids or `RubyLLM::Model` objects, and `on:` chooses which errors trigger them:

```ruby
fallbacks "{{ site.models.anthropic_haiku }}", on: [RubyLLM::RateLimitError, RubyLLM::ServiceUnavailableError]
```

See [Model Fallbacks]({% link _advanced/error-handling.md %}#model-fallbacks).

## Configuration Contexts

A context gives an agent its own credentials or connection settings without touching the global configuration. Pass a context you defined elsewhere, or configure one in a block:

```ruby
class SupportAgent < RubyLLM::Agent
  model "{{ site.models.default_chat }}", provider: :openai

  context do |config|
    config.openai_api_key = Rails.application.credentials.support_openai_api_key
    config.request_timeout = 180
  end
end
```

The block runs once, when Ruby loads the class, on a copy of the global configuration. A block that takes no arguments runs each time the agent builds a chat instead: it reads inputs and returns a context. See [Contexts]({% link _reference/configuration-connection.md %}#contexts-isolated-configurations).

## Callbacks

Declare a [chat callback]({% link _core_features/chat-callbacks.md %}) on the agent, and every chat it builds or finds runs it. Name a method, as a Rails model does, or pass a block. This agent shows the customer what it's doing and logs each reply:

```ruby
class SupportAgent < ApplicationAgent
  STATUSES = { "lookup_order" => "Looking up your order", "search_docs" => "Searching the help center" }

  before_tool_call :show_status
  after_message :log_reply, if: ->(message) { message.role == :assistant }

  private

  def show_status(tool_call)
    Turbo::StreamsChannel.broadcast_update_to chat, target: "support_status",
                                                    html: STATUSES.fetch(tool_call.name, "Working on it")
  end

  def log_reply(message)
    Rails.logger.info "[support] chat=#{chat.id} model=#{message.model_id} cost=#{message.cost.total}"
  end
end
```

Callbacks run on the agent instance, so they read its inputs and `chat`, and receive the callback's arguments when they take any. `if:` and `unless:` take a method name, a lambda, or an array of them.

Every chat callback has a macro: `before_request`, `before_message`, `after_message`, `before_tool_call`, `around_tool_call`, `after_tool_result`, `after_tool_progress`, `before_fallback`, `after_fallback`, and `after_file_write`. Subclasses inherit callbacks, so `ApplicationAgent` is the place for the ones every agent shares.

`around_tool_call` wraps each tool's execution, in the thread or fiber that runs it, so a tool can see state such as the current tenant. Its method or block calls the tool by yielding to its block. When `if:` or `unless:` skips it, the tool runs without it:

```ruby
class SupportAgent < ApplicationAgent
  inputs :account

  around_tool_call :in_tenant

  private

  def in_tenant(tool_call, &)
    ActsAsTenant.with_tenant(account, &)
  end
end
```

See [Wrapping Tool Calls]({% link _core_features/chat-callbacks.md %}#wrapping-tool-calls). `around_join` works the same way for [queued messages]({% link _advanced/agentic-workflows.md %}#joining-queued-messages).

Chats from `SupportAgent.chat` and `SupportAgent.find` bind to an agent without calling `initialize`, so read inputs and `chat` in callbacks rather than instance variables your `initialize` sets.
{: .note }

## Subagents

Some questions take a long search: twenty help center articles read to answer one question. Run that in the support chat and every article stays in its context. Hand it to another agent instead. A subagent works in its own conversation, and only its answer comes back.

An agent class goes wherever a tool goes. Describe it so the calling model knows when to use it:

```ruby
class ResearchAgent < RubyLLM::Agent
  description "Researches a question across the help center and reports back with links"
  instructions "Read every relevant article before you answer. Cite each one."
  tools SearchDocs
end

class SupportAgent < RubyLLM::Agent
  inputs :customer
  tools { [LookupOrder.new(customer), ResearchAgent] }
end
```

The model calls it as the tool `research_agent`, or `billing_research_agent` for `Billing::ResearchAgent`, with a `task` and any of the agent's inputs. Fix inputs yourself with `to_tool`, and the model fills only the rest:

```ruby
tools { [LookupOrder.new(customer), BillingAgent.to_tool(customer: customer)] }
```

Each call runs a new instance of the agent under the [owner]({% link _core_features/cost-and-usage-tracking.md %}#one-shot-operations) of the chat that called it, and returns the content of the agent's last answer.

A subagent can wait on a person. When `BillingAgent` calls a refund tool that [requires approval]({% link _tools/tool-execution.md %}#requiring-approval), the call pauses on a `RubyLLM::AgentTask`, and the calling chat is `awaiting_person?`. The task's `agent` is the subagent, so settle what it waits for, then `complete` the calling chat:

```ruby
agent = SupportAgent.new(customer: current_customer)
agent.ask "Please refund the shipping on order R-1042"

task = agent.pending_tasks.first
task.agent.pending_approvals.each { |tool_call| task.agent.approve(tool_call) }
agent.complete
```

Cancelling the calling chat cancels a subagent it waits on. A subagent lives in the process that ran it: a chat resumed in another process, such as a later job, reports the subagent's work as lost, and the model can start it again.

## Handling Errors with `rescue_from`

`rescue_from` declares how an agent handles exceptions from its chat operations, the way a Rails controller does:

```ruby
class ApplicationAgent < RubyLLM::Agent
  rescue_from RubyLLM::RateLimitError, RubyLLM::ServerError, with: :report_transient
  rescue_from RubyLLM::BadRequestError, with: :report_bug

  private

  def report_transient(error)
    Rails.logger.warn "#{self.class.name}: #{error.class}: #{error.message}"
    raise
  end

  def report_bug(error)
    Sentry.capture_exception(error)
    raise
  end
end
```

Handlers cover `ask`, `say`, `ask_later`, `complete`, `generate`, `run_tools`, `step`, `count_tokens`, and `compact`, however you reach the chat: `new`, `chat`, `create`, `find`, or a chained setter such as `agent.with_temperature(0.2).ask "Hi"`. They run on the agent instance, so inputs and `chat` are available. A handler that doesn't re-raise swallows the exception, and its return value becomes the operation's return value.

The rules match `ActiveSupport::Rescuable`. The last matching handler wins, so a subclass can override an inherited one. Class names may be Strings, looked up when an exception is raised. Handlers catch `StandardError`s, and a module matches the errors that include it. Unhandled exceptions keep their original backtrace.

## Rails-Backed Agents

Set `chat_class`, and the agent creates and finds your Active Record chats instead of plain ones. The install generator puts it in `ApplicationAgent`, which your agents inherit from as models inherit from `ApplicationRecord`:

```ruby
class ApplicationAgent < RubyLLM::Agent
  chat_class Chat
end
```

In Rails, the chat record knows its customer, so read it from `chat` instead of declaring an input:

```ruby
class SupportAgent < ApplicationAgent
  model "{{ site.models.default_chat }}"
  instructions { "You answer #{chat.customer.name}, a customer of Acme Outfitters. Be brief and friendly." }
  tools { [LookupOrder.new(chat.customer), SearchDocs] }
end

chat = SupportAgent.create!(customer: current_customer)
SupportAgent.find(chat.id).ask "Where is my order R-1042?"
```

`bin/rails generate ruby_llm:agent Support` writes the class to start from. Keywords that aren't declared inputs, such as `customer:` here, go to `Chat.create!`.

`create` and `create!` save the agent's instructions with the new chat. `find` applies them in memory without saving, so a changed prompt reaches old chats without rewriting their history. `SupportAgent.sync_instructions(chat)` saves the current instructions explicitly. When you already have the record, `SupportAgent.new(chat: chat)` configures it without loading it again.

`create`, `create!`, and `find` raise without a `chat_class`. See [Durable Agents]({% link _advanced/durable-agents-overview.md %}) for agents that run in jobs and wait for people.

## Using an Agent

An agent instance answers everything a chat does. `ask`, `complete`, `messages`, `cost`, the `with_*` setters, and the rest delegate to the chat it wraps, which `agent.chat` returns. `SupportAgent.chat` returns that configured `RubyLLM::Chat` directly. See the [Agent API reference]({{ '/api/RubyLLM/Agent.html' | relative_url }}) for every method.

## Next Steps

* [Configuration]({% link _getting_started/configuration.md %}): API keys, default models, and per-agent contexts.
* [Agentic Workflows]({% link _advanced/agentic-workflows.md %}): route, chain, and run agents in parallel.
* [Durable Agents]({% link _advanced/durable-agents-overview.md %}): run agents in jobs and resume them across deploys.
* [Memory]({% link _advanced/memory.md %}): let agents remember across conversations.
* [Evaluations]({% link _advanced/evaluations.md %}): test agents against a dataset of cases.
