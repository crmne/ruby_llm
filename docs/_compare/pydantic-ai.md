---
layout: default
title: Pydantic AI
seo:
  title: RubyLLM and Pydantic AI
nav_order: 4
description: Compare RubyLLM with Pydantic AI in Python on dependencies, streaming, stored conversations, approvals, and cost, with code from both projects.
permalink: /compare/pydantic-ai/
---

# RubyLLM and Pydantic AI

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* How typed dependencies in Pydantic AI map to inputs and tools in RubyLLM.
* How each one streams an agent's answer.
* How each one stores a conversation and pauses for approval.
* What each one reports about usage and cost.
* Where Pydantic AI has something RubyLLM doesn't.
* When to choose Pydantic AI and when to choose RubyLLM.

> **Last checked** on 6 November 2026 against RubyLLM 2.2 and the Python package `pydantic-ai` 2.66.0. The Python code comes from Pydantic AI's documentation: [Bank Support](https://pydantic.dev/docs/ai/examples/conversational-agents/bank-support/), [Agents](https://pydantic.dev/docs/ai/core-concepts/agent/), [Persistence](https://pydantic.dev/docs/ai/core-concepts/persistence/), and [Going to Production](https://pydantic.dev/docs/ai/production/). Model names match the RubyLLM examples, comments are removed, and the streaming example adds `asyncio.run` so it runs as a script.

## Two Frameworks for the Same Job

[Pydantic AI](https://pydantic.dev/docs/ai/overview/) is the Pydantic team's Python framework: a typed agent loop that swaps models with a string. RubyLLM is the Ruby one. Both run the tool loop, stream, return structured output, connect to MCP servers, fall back between models, and report cost in dollars.

They differ in what they build on. Pydantic AI builds on Python's type hints: your type checker knows what an agent needs and what it returns. RubyLLM builds on Ruby classes and on Rails: an agent is a class, and a conversation is rows in your database.

## An Agent That Knows the Customer

The task comes from Pydantic AI's bank support example: an agent answers one customer, reads that customer's balance through a tool, and returns structured advice.

Pydantic AI's central idea here is the dependency. You declare a type with `deps_type`, pass an instance on every run, and read it through `ctx.deps` in instructions and tools:

```python
from dataclasses import dataclass

from pydantic import BaseModel

from pydantic_ai import Agent, RunContext
from pydantic_ai.capabilities import Caching


@dataclass
class SupportDependencies:
    customer_id: int
    db: DatabaseConn


class SupportOutput(BaseModel):
    support_advice: str
    """Advice returned to the customer"""
    block_card: bool
    """Whether to block their card or not"""
    risk: int
    """Risk level of query"""


support_agent = Agent(
    'anthropic:{{ site.models.anthropic_latest }}',
    deps_type=SupportDependencies,
    output_type=SupportOutput,
    instructions=(
        'You are a support agent in our bank, give the '
        'customer support and judge the risk level of their query. '
        "Reply using the customer's name."
    ),
    capabilities=[Caching()],
)


@support_agent.instructions
async def add_customer_name(ctx: RunContext[SupportDependencies]) -> str:
    customer_name = await ctx.deps.db.customer_name(id=ctx.deps.customer_id)
    return f"The customer's name is {customer_name!r}"


@support_agent.tool
async def customer_balance(ctx: RunContext[SupportDependencies]) -> str:
    """Returns the customer's current account balance."""
    balance = await ctx.deps.db.customer_balance(
        id=ctx.deps.customer_id,
    )
    return f'${balance:.2f}'


deps = SupportDependencies(customer_id=123, db=DatabaseConn(sqlite_conn=con))
result = support_agent.run_sync('What is my balance?', deps=deps)
print(result.output)
```

The example also defines `DatabaseConn`, a wrapper over a SQLite connection, and sets up that database. Both are left out here, as the `Customer` model is below.

In RubyLLM, the agent declares its `inputs`. Blocks read each input as a method, and a tool that acts for someone takes that someone when you create it:

```ruby
class CustomerBalance < RubyLLM::Tool
  description "Returns the customer's current account balance"

  def initialize(customer)
    @customer = customer
  end

  def execute = format("$%.2f", @customer.balance)
end

class SupportOutput < Schematist::Schema
  string :support_advice, description: "Advice returned to the customer"
  boolean :block_card, description: "Whether to block their card or not"
  integer :risk, description: "Risk level of query"
end

class SupportAgent < RubyLLM::Agent
  model "{{ site.models.anthropic_latest }}"
  inputs :customer
  schema SupportOutput
  caching

  instructions do
    "You are a support agent in our bank, give the customer support and judge the risk level " \
      "of their query. Reply using the customer's name. The customer's name is #{customer.name}."
  end

  tools { CustomerBalance.new customer }
end

response = SupportAgent.new(customer: Customer.find(123)).ask "What is my balance?"
puts response.parsed
```

The model chooses a tool's arguments, and your code chooses whose data it sees. There is no context parameter to thread through, because the tool is an ordinary object holding the customer. See [Runtime Inputs]({% link _getting_started/agents.md %}#runtime-inputs) and [Tools That Need the Current User]({% link _getting_started/tools.md %}#tools-that-need-the-current-user).

What you give up is the type checker. [Pydantic AI's agents](https://pydantic.dev/docs/ai/core-concepts/agent/) are generic in their dependency and output types, so mypy or pyright reports a tool that reads the wrong field before anything runs. RubyLLM has no equivalent: `customer.nmae` raises `NoMethodError` when the block runs, so your tests catch it. [`agent.override(deps=...)`](https://pydantic.dev/docs/ai/core-concepts/dependencies/) swaps dependencies in Pydantic AI's tests; in RubyLLM you pass a different customer to `new`.

The outputs differ too. `result.output` is a validated `SupportOutput` instance. When the response fails validation, or an [output validator](https://pydantic.dev/docs/ai/core-concepts/output/) raises `ModelRetry`, Pydantic AI [sends the feedback to the model and tries again](https://pydantic.dev/docs/ai/core-concepts/retries/). `response.parsed` is a Hash: RubyLLM sends your schema to the provider and parses the JSON, without validating it locally or retrying. To enforce rules of your own, give the Hash to a model and check its validations. See [Structured Output]({% link _core_features/structured-output.md %}).

## Streaming

Pydantic AI streams through an async context manager:

```python
import asyncio

from pydantic_ai import Agent

agent = Agent('anthropic:{{ site.models.anthropic_latest }}')


async def main():
    async with agent.run_stream('What is the capital of the UK?') as response:
        async for text in response.stream_text():
            print(text)


asyncio.run(main())
```

Each `text` is the answer so far, and `stream_text(delta=True)` gives you the new part only. [The agent has a separate method](https://pydantic.dev/docs/ai/core-concepts/agent/) for each way of running: `run`, `run_sync`, `run_stream`, `run_stream_sync`, `run_stream_events`, and `iter`. `run_stream` treats the first output that matches the output type as final, so by default, tool calls the model makes alongside that text do not run. To keep the loop going, the documentation points you to `run_stream_events` or `iter`.

RubyLLM has one method. Give `ask` a block, and it streams:

```ruby
chat = RubyLLM.chat model: "{{ site.models.anthropic_latest }}"

chat.ask "What is the capital of the UK?" do |chunk|
  print chunk.content
end
```

The block doesn't change the loop: `ask` runs every tool call and returns when the model answers without one. The same call works inside an `Async` block when you want concurrency, with no `await` to add. See [Streaming]({% link _core_features/streaming.md %}) and [Scale with Async]({% link _advanced/async.md %}).

## Keeping a Conversation

[Pydantic AI's persistence guide](https://pydantic.dev/docs/ai/core-concepts/persistence/) says it is "deliberately unopinionated about your database". It gives you a serialization boundary, and the schema is yours:

```python
from pydantic_ai import Agent, ConversationTypeAdapter

agent = Agent('anthropic:{{ site.models.anthropic_latest }}', instructions='Be a helpful assistant.')

result = agent.run_sync('Tell me a joke.')
stored = ConversationTypeAdapter.dump_json(result.conversation)

conversation = ConversationTypeAdapter.validate_json(stored)
result = agent.run_sync('Explain?', conversation=conversation)
print(result.usage.requests)
```

`stored` is JSON bytes for a `jsonb` column that you create, read, and write. To append instead of rewriting on every turn, you store new messages in a table of your own. A `ConversationStore` does that for you with conflict checks, branches, and forks, and for a real database you subclass it and implement its storage primitives. [Going to Production](https://pydantic.dev/docs/ai/production/) adds that you check access before loading a conversation and serialize concurrent updates to it.

In Rails, the install generator writes the tables, and the conversation is your own model:

```ruby
class Chat < ApplicationRecord
  acts_as_chat
end

chat = Chat.create! model: "{{ site.models.anthropic_latest }}"
chat.ask "Tell me a joke."

Chat.find(chat.id).ask "Explain?"
```

Each message is saved as it arrives, as a row. You query it, show it in a view, join it to your users, and scope access with the associations you already have, such as `current_user.chats.find`. Outside Rails, a plain chat holds its transcript in memory, and storing it is up to you. A plain chat copies with `dup`, but stored chats have no branch API. See [Rails Integration]({% link _getting_started/rails.md %}) and [Persistence with acts_as]({% link _advanced/rails-persistence.md %}).

## Human Approval

Pydantic AI ends the run with a `DeferredToolRequests` output, which has to be among the agent's output types. You store the conversation yourself, and load it again to resume:

```python
from pydantic_ai import Agent, ConversationTypeAdapter, DeferredToolRequests

agent = Agent('anthropic:{{ site.models.anthropic_latest }}', output_type=[str, DeferredToolRequests])


@agent.tool_plain(requires_approval=True)
def issue_refund(order_id: str, amount: float) -> str:
    return f'Refunded {amount} on order {order_id}'


async def start(prompt: str) -> bytes:
    result = await agent.run(prompt)
    if isinstance(result.output, DeferredToolRequests):
        ...
    return ConversationTypeAdapter.dump_json(result.conversation)


async def resume(
    stored: bytes, approvals: dict[str, bool]
) -> tuple[bytes, str | DeferredToolRequests]:
    conversation = ConversationTypeAdapter.validate_json(stored)
    assert conversation.deferred_tool_requests is not None
    result = await agent.run(
        conversation=conversation,
        deferred_tool_results=conversation.deferred_tool_requests.build_results(approvals=approvals),
    )
    return ConversationTypeAdapter.dump_json(result.conversation), result.output
```

In RubyLLM, the tool declares that it needs approval. `ApplicationAgent` is the base class the install generator writes, with `chat_class Chat`:

```ruby
class IssueRefund < RubyLLM::Tool
  description "Issues a refund for an order"
  requires_approval

  def execute(order_id:, amount:) = "Refunded #{amount} on order #{order_id}"
end

class RefundAgent < ApplicationAgent
  model "{{ site.models.anthropic_latest }}"
  tools IssueRefund
end

chat = RefundAgent.create!
chat.ask "Refund 12.50 on order R-1042"
chat.awaiting_approval? # => true
```

The pending call is already a row, so any later request can show it, decide, and continue:

```ruby
chat = RefundAgent.find params[:id]
chat.approve params[:tool_call_id]
chat.complete
```

You still scope the lookup and authorize the reviewer in your controller, as you would for any other action. `chat.pending_approvals` lists the calls to show the reviewer, and `chat.deny` sends the model a refusal. The chat UI generator builds the approval cards. [Pydantic AI's deferred tools](https://pydantic.dev/docs/ai/tools-toolsets/deferred-tools/) also let the reviewer change a call's arguments, and hand a call to a frontend or a worker to run; RubyLLM has no way to edit the arguments of a pending call. See [Controlling Tool Execution]({% link _tools/tool-execution.md %}#requiring-approval).

## Usage and Cost

Both report cost in dollars, from a price list that ships with the library. [Pydantic AI's](https://pydantic.dev/docs/ai/core-concepts/agent/) `result.usage.cost` is a best-effort estimate from genai-prices, and requests with no pricing data don't contribute to the total. In RubyLLM, a response whose price is unknown has a `nil` cost rather than a low one:

```ruby
response = SupportAgent.new(customer: Customer.find(123)).ask "What is my balance?"

response.tokens.input
response.tokens.output
response.cost.total
```

In Rails, every billed attempt also becomes a row in `ruby_llm_usages`, including failed and cancelled ones, so spend per customer is a query:

```ruby
chat = Chat.create! model: "{{ site.models.anthropic_latest }}"
chat.with_owner(current_user).ask "What is my balance?"

RubyLLM::ActiveRecord::Usage.where(owner: current_user).sum(:total_cost)
```

Pydantic AI also stops spend. [`UsageLimits`](https://pydantic.dev/docs/ai/production/) caps one run's requests, tool calls, tokens, and cost, and `SpendLimits` in its [Harness](https://pydantic.dev/docs/ai/harness/spend/) handles daily and per-tenant budgets. RubyLLM has no built-in limit: you [drive the loop yourself]({% link _advanced/agentic-workflows.md %}#driving-the-loop-yourself) and read `chat.cost.total` between steps. See [Tokens and Costs]({% link _core_features/cost-and-usage-tracking.md %}).

## Around the Agent

Pydantic AI comes with a stack of neighboring projects. Here's how each maps to RubyLLM:

* **[Pydantic Graph](https://pydantic.dev/docs/ai/graph/graph/)** models workflows as typed state machines. RubyLLM has no graph library: workflows are methods, conditionals, and `Async` blocks. See [Agentic Workflows]({% link _advanced/agentic-workflows.md %}).
* **[Pydantic Logfire](https://pydantic.dev/docs/ai/integrations/logfire/)** is Pydantic's observability platform, and Pydantic AI's instrumentation is plain OpenTelemetry, so any backend works. RubyLLM emits [OpenTelemetry]({% link _advanced/opentelemetry.md %}) traces too, and [instrumentation events]({% link _advanced/instrumentation.md %}) you can subscribe to. It has no observability product of its own.
* **[Pydantic Evals](https://pydantic.dev/docs/ai/evals/evals/)** grades outputs and tool-call trajectories on datasets or live traffic. RubyLLM has [Evaluations]({% link _advanced/evaluations.md %}) for datasets and your test suite.
* **[Durable execution](https://pydantic.dev/docs/ai/capabilities/durable_execution/overview/)** runs an agent on an engine such as Temporal or DBOS, which journals its steps and replays them after a crash. RubyLLM has no engine integrations: in Rails, Active Job runs [one step per job]({% link _advanced/durable-agents.md %}), and a worker that dies resumes from the last saved message.
* **[Realtime voice](https://pydantic.dev/docs/ai/realtime/overview/)** puts an agent on a live speech session. RubyLLM has none. It generates speech and transcribes audio as separate operations.
* **[`TestModel` and `FunctionModel`](https://pydantic.dev/docs/ai/guides/testing/)** run an agent offline in unit tests. RubyLLM has no test model, so you stub the HTTP requests or record them.

## Concept Map

| Pydantic AI | RubyLLM |
| --- | --- |
| `Agent(...)` | A [`RubyLLM::Agent`]({% link _getting_started/agents.md %}) class |
| `@agent.tool` and `@agent.tool_plain` | A [`RubyLLM::Tool`]({% link _getting_started/tools.md %}) class |
| `deps_type` and `RunContext` | `inputs`, and a tool's constructor |
| `@agent.instructions` | `instructions` with a block |
| `output_type=Model` | `schema Schema` or `with_schema` |
| `result.output` | `response.parsed` |
| `run_stream` and `stream_text` | A block given to `ask` |
| `ConversationTypeAdapter` and `ConversationStore` | `acts_as_chat` |
| `requires_approval=True` and `DeferredToolRequests` | `requires_approval`, `approve`, and `deny` |
| `ModelFallback` | [`fallbacks`]({% link _getting_started/agents.md %}#model-fallbacks) |
| `result.usage` | `response.tokens` and `response.cost` |
| `UsageLimits` and `SpendLimits` | Your own loop, reading `chat.cost.total` |
| Pydantic Evals | [Evaluations]({% link _advanced/evaluations.md %}) |
| Logfire or any OpenTelemetry backend | [OpenTelemetry]({% link _advanced/opentelemetry.md %}) |

## When to Choose Pydantic AI

* **Your team works in Python.** Data science, notebooks, and FastAPI services are already there, and Pydantic is likely in them.
* **You want your type checker to cover your agents.** Dependencies, tools, and outputs are typed end to end, and outputs are validated with retries.
* **You run a durable engine.** Temporal, DBOS, and Prefect attach to an agent as capabilities.
* **You need realtime voice, typed graphs, or built-in spend caps.** RubyLLM has none of these.
* **You want the Logfire stack.** Tracing, cost tracking, and evals come from one vendor, along with a gateway for model keys and budgets.

## When to Choose RubyLLM

* **Your application is Ruby or Rails.** Agents are classes, chats are Active Record models, and loops run in Active Job, with no store to write and no engine to run.
* **You want the conversation in your database from the start.** Messages, tool calls, approvals, and usage are rows you can query and join, with no serialization code.
* **You want a chat interface you own.** The `ruby_llm:chat_ui` generator writes controllers, views, and a job that streams over Turbo.
* **You need one API beyond chat.** [Pydantic AI's overview](https://pydantic.dev/docs/ai/overview/) lists agents, realtime voice, image generation, and embeddings. RubyLLM has images, video, speech, transcription, OCR, moderation, embeddings, and reranking as one-call operations with the same configuration.

## Next Steps

* [Agents]({% link _getting_started/agents.md %}) - Define agents as classes and use them anywhere.
* [Rails Integration]({% link _getting_started/rails.md %}) - Persist chats and stream them with Hotwire.
* [Migrating to RubyLLM]({% link _compare/migrating-from.md %}) - Guides for other frameworks and clients.
