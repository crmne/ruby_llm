---
layout: default
title: RubyLLM and LangChain
nav_order: 2
description: Compare RubyLLM with LangChain and LangGraph in Python on agents, streaming, structured output, memory, approvals, and cost, with code from both projects.
permalink: /compare/langchain/
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* How the same agent looks in LangChain and in RubyLLM.
* How streaming and structured output compare.
* How LangGraph checkpointers and RubyLLM's stored transcripts keep a conversation.
* How each one pauses a tool call for human approval.
* What each one reports about usage and cost.
* When to choose LangChain and when to choose RubyLLM.

> **Last checked** on 5 November 2026 against RubyLLM 2.2 and the Python packages `langchain` 1.4.9, `langchain-core` 1.7.6, `langgraph` 1.2.20, and `langchain-anthropic` 1.7.10. The Python code comes from LangChain's documentation: [Quickstart](https://docs.langchain.com/oss/python/langchain/quickstart), [Streaming](https://docs.langchain.com/oss/python/langchain/streaming), [Structured output](https://docs.langchain.com/oss/python/langchain/structured-output), [Short-term memory](https://docs.langchain.com/oss/python/langchain/short-term-memory), [Human-in-the-loop](https://docs.langchain.com/oss/python/langchain/human-in-the-loop), and [Models](https://docs.langchain.com/oss/python/langchain/models). Model names match the RubyLLM examples, and comments and highlight markers were removed.

## Two Ecosystems

LangChain is a framework for building agents in Python and JavaScript, and LangGraph is the runtime its agents run on. This page compares the Python packages. RubyLLM is the Ruby AI framework. Both give you agents with tools, streaming, structured output, and provider switching.

The difference is where state lives. A LangChain agent is a compiled graph, and its conversation persists through a checkpointer you configure. A RubyLLM conversation is a transcript: in plain Ruby, an object; in Rails, rows in your database that any process can load.

## An Agent with a Tool

LangChain's quickstart builds an agent from a function and a model:

```python
from langchain.agents import create_agent

def get_weather(city: str) -> str:
    """Get weather for a given city."""
    return f"It's always sunny in {city}!"

agent = create_agent(
    model="{{ site.models.anthropic_latest }}",
    tools=[get_weather],
    system_prompt="You are a helpful assistant",
)

result = agent.invoke(
    {"messages": [{"role": "user", "content": "What's the weather in San Francisco?"}]}
)
print(result["messages"][-1].content_blocks)
```

In RubyLLM, the tool and the agent are classes:

```ruby
class Weather < RubyLLM::Tool
  description "Get weather for a given city"

  def execute(city:) = "It's always sunny in #{city}!"
end

class Assistant < RubyLLM::Agent
  model "{{ site.models.anthropic_latest }}"
  instructions "You are a helpful assistant"
  tools Weather
end

response = Assistant.new.ask "What's the weather in San Francisco?"
puts response.content
```

Both read the tool's parameters from the function signature. LangChain's agent is built where you call it; RubyLLM's is declared once, then used from a controller, a job, or a test with one line.

## Streaming

LangChain streams an agent's tokens with a stream mode, and each chunk carries content blocks and graph metadata:

```python
from langchain.agents import create_agent

def get_weather(city: str) -> str:
    """Get weather for a given city."""

    return f"It's always sunny in {city}!"

agent = create_agent(
    model="{{ site.models.anthropic_latest }}",
    tools=[get_weather],
)
for chunk in agent.stream(
    {"messages": [{"role": "user", "content": "What is the weather in SF?"}]},
    stream_mode="messages",
    version="v2",
):
    if chunk["type"] == "messages":
        token, metadata = chunk["data"]
        print(f"node: {metadata['langgraph_node']}")
        print(f"content: {token.content_blocks}")
        print("\n")
```

RubyLLM streams through a block:

```ruby
Assistant.new.ask "What is the weather in SF?" do |chunk|
  print chunk.content
end
```

Each chunk also carries `thinking` and `tool_calls` when the model produces them. See [Streaming]({% link _core_features/streaming.md %}).

## Structured Output

LangChain takes a Pydantic model as the agent's `response_format`:

```python
from pydantic import BaseModel, Field
from langchain.agents import create_agent


class ContactInfo(BaseModel):
    """Contact information for a person."""
    name: str = Field(description="The name of the person")
    email: str = Field(description="The email address of the person")
    phone: str = Field(description="The phone number of the person")

agent = create_agent(
    model="{{ site.models.anthropic_latest }}",
    response_format=ContactInfo
)

result = agent.invoke({
    "messages": [{"role": "user", "content": "Extract contact info from: John Doe, john@example.com, (555) 123-4567"}]
})

print(result["structured_response"])
```

RubyLLM takes a schema class on the agent:

```ruby
class ContactInfo < Schematist::Schema
  string :name, description: "The name of the person"
  string :email, description: "The email address of the person"
  string :phone, description: "The phone number of the person"
end

class ContactExtractor < RubyLLM::Agent
  model "{{ site.models.anthropic_latest }}"
  schema ContactInfo
end

response = ContactExtractor.new.ask "Extract contact info from: John Doe, john@example.com, (555) 123-4567"
response.parsed
```

`parsed` is a Hash, so it goes straight into `Contact.create!`. See [Structured Output]({% link _core_features/structured-output.md %}).

## Memory and Persistence

A LangChain agent remembers a conversation through a checkpointer and a thread ID passed on every call:

```python
from langchain.agents import create_agent
from langgraph.checkpoint.memory import InMemorySaver


def get_user_info() -> str:
    """Look up information about the current user."""
    return "No user profile on file."


agent = create_agent(
    model="{{ site.models.anthropic_latest }}",
    tools=[get_user_info],
    checkpointer=InMemorySaver(),
)

thread_config = {"configurable": {"thread_id": "1"}}
response = agent.invoke(
    {"messages": [{"role": "user", "content": "Hi! My name is Bob."}]},
    thread_config,
)["messages"][-1].content

print(response)

response = agent.invoke(
    {"messages": [{"role": "user", "content": "What's my name?"}]},
    thread_config,
)["messages"][-1].content

print(response)
```

In production, the documentation swaps `InMemorySaver` for `PostgresSaver`, which creates its own checkpoint tables.

A RubyLLM chat remembers because it holds its transcript:

```ruby
chat = RubyLLM.chat model: "{{ site.models.anthropic_latest }}"
chat.ask "Hi! My name is Bob."
chat.ask "What's my name?"
```

In Rails, the transcript is your own `Chat` and `Message` records, so the thread ID is the record's ID:

```ruby
class Chat < ApplicationRecord
  acts_as_chat
end

chat = Chat.create! model: "{{ site.models.anthropic_latest }}"
chat.ask "Hi! My name is Bob."

Chat.find(chat.id).ask "What's my name?"
```

The messages are ordinary rows: you can query them, show them in a view, and join them to your users. A background job can run one step of an agent's loop and enqueue the next, and a worker that dies mid-conversation resumes from the last saved message. See [Rails Integration]({% link _getting_started/rails.md %}) and [Agents in Background Jobs]({% link _advanced/durable-agents.md %}).

## Human Approval

LangChain pauses tool calls with middleware, which needs a checkpointer to hold the interrupted graph. Its guide defines `write_file`, `execute_sql`, and `read_data` as tools earlier on the page:

```python
from langchain.agents import create_agent
from langchain.agents.middleware import HumanInTheLoopMiddleware
from langgraph.checkpoint.memory import InMemorySaver


agent = create_agent(
    model="{{ site.models.anthropic_latest }}",
    tools=[write_file, execute_sql, read_data],
    middleware=[
        HumanInTheLoopMiddleware(
            interrupt_on={
                "write_file": True,
                "execute_sql": {"allowed_decisions": ["approve", "reject"]},
                "read_data": False,
            },
            description_prefix="Tool execution pending approval",
        ),
    ],
    checkpointer=InMemorySaver(),
)
```

You resume by invoking the agent again on the same thread with a `Command` that carries a decision for each paused call.

In RubyLLM, the tool declares that it needs approval. `ApplicationAgent` is the base class the install generator writes, with `chat_class Chat`:

```ruby
class ExecuteSql < RubyLLM::Tool
  description "Run a SQL query"
  requires_approval

  def execute(query:) = "Deleted 42 rows"
end

class DataAgent < ApplicationAgent
  model "{{ site.models.anthropic_latest }}"
  tools ExecuteSql
end

chat = DataAgent.create!
chat.ask "Delete last year's test orders"
chat.awaiting_approval? # => true
```

The decision is stored on the tool call's row, so another request, after a deploy if need be, can record it and continue:

```ruby
chat = DataAgent.find params[:id]
chat.approve params[:tool_call_id]
chat.complete
```

`chat.pending_approvals` lists the calls to show the reviewer, and `chat.deny` sends the model a refusal instead. LangChain's middleware can also let the reviewer edit the arguments or answer in place of the tool. See [Controlling Tool Execution]({% link _tools/tool-execution.md %}).

## Usage and Cost

LangChain collects token counts per model with a callback:

```python
from langchain.chat_models import init_chat_model
from langchain_core.callbacks import get_usage_metadata_callback

model_1 = init_chat_model(model="{{ site.models.openai_latest }}")
model_2 = init_chat_model(model="{{ site.models.anthropic_latest }}")

with get_usage_metadata_callback() as cb:
    model_1.invoke("Hello")
    model_2.invoke("Hello")
    print(cb.usage_metadata)
```

The result maps each model to its `input_tokens`, `output_tokens`, and token details. Prices are not part of it; LangChain's documentation points to LangSmith for tracing.

RubyLLM prices responses from its model registry, in the same shape for every provider. When usage or a price is unknown, the cost is `nil`, never a misleading zero:

```ruby
response = RubyLLM.chat(model: "{{ site.models.anthropic_latest }}").ask "Hello"

response.tokens.input
response.tokens.output
response.cost.total
```

Chats and agents total their cost with `chat.cost.total`, and Rails apps get a usage ledger table with every billed attempt. See [Cost and Usage Tracking]({% link _core_features/cost-and-usage-tracking.md %}).

## Concept Map

| LangChain | RubyLLM |
| --- | --- |
| `init_chat_model(...)` | `RubyLLM.chat model: "..."` |
| `create_agent(model, tools, system_prompt)` | A [`RubyLLM::Agent`]({% link _getting_started/agents.md %}) class |
| A function or `@tool` | A [`RubyLLM::Tool`]({% link _getting_started/tools.md %}) class |
| `agent.stream(..., stream_mode="messages")` | A block given to `ask` |
| `response_format=Schema` | `schema Schema` or `with_schema` |
| Checkpointer and `thread_id` | The chat's transcript, or an `acts_as_chat` record |
| `HumanInTheLoopMiddleware` | `requires_approval`, `approve`, and `deny` |
| `usage_metadata` | `response.tokens` and `response.cost` |
| LangSmith tracing | [Instrumentation]({% link _advanced/instrumentation.md %}) and [OpenTelemetry]({% link _advanced/opentelemetry.md %}) |
| LangSmith evaluations | [Evaluations]({% link _advanced/evaluations.md %}) |

## When to Choose LangChain

* **Your team works in Python.** Data science, notebooks, and machine learning code are already there, and LangChain fits next to them.
* **You want an explicit graph.** LangGraph lets you design custom control flow as nodes and edges, with branches, parallel nodes, and subgraphs.
* **You want a wide integration catalog.** Document loaders, text splitters, vector stores, and retrievers for many services, maintained by LangChain and its community.
* **You use LangSmith.** Tracing, evaluation, and deployment are built around LangChain agents.

## When to Choose RubyLLM

* **Your application is Ruby or Rails.** Agents are classes, chats are Active Record models, and loops run in Active Job, without a separate runtime or checkpoint store.
* **You want plain Ruby control flow.** Workflows are methods, conditionals, and `Async` blocks, not a graph DSL. See [Agentic Workflows]({% link _advanced/agentic-workflows.md %}).
* **You need cost in dollars** on responses, chats, and agents.
* **You need more than chat.** Images, speech, transcription, OCR, moderation, embeddings, and reranking use the same configuration.

## Next Steps

* [Agents]({% link _getting_started/agents.md %}) - Define agents as classes and use them anywhere.
* [Agents in Background Jobs]({% link _advanced/durable-agents.md %}) - Run the loop one step per job.
* [Migrating from langchainrb]({% link _compare/migrate-langchainrb.md %}) - Move a Ruby app from langchainrb to RubyLLM.
