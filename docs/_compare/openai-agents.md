---
layout: default
title: OpenAI Agents SDK
seo:
  title: RubyLLM and the OpenAI Agents SDK
nav_order: 3
description: Compare RubyLLM with the OpenAI Agents SDK for Python on agents, streaming, sessions, approvals, handoffs, guardrails, tracing, and cost, with code from both projects.
permalink: /compare/openai-agents/
---

# RubyLLM and the OpenAI Agents SDK

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* How the same agent looks in the Agents SDK and in RubyLLM.
* How streaming compares.
* How sessions and RubyLLM's stored transcripts keep a conversation.
* How each one pauses a tool call for approval and resumes it later.
* What handoffs and guardrails are, and what you write in RubyLLM instead.
* How tracing, other providers, and cost compare.
* When to choose the Agents SDK and when to choose RubyLLM.

> **Last checked** on 6 November 2026 against RubyLLM 2.2 and the Python package [`openai-agents`](https://pypi.org/project/openai-agents/) 0.24.0. The Python code comes from the SDK's documentation: [Quickstart](https://openai.github.io/openai-agents-python/quickstart/), [Streaming](https://openai.github.io/openai-agents-python/streaming/), [Sessions](https://openai.github.io/openai-agents-python/sessions/), [Human-in-the-loop](https://openai.github.io/openai-agents-python/human_in_the_loop/), [Tools](https://openai.github.io/openai-agents-python/tools/), [Guardrails](https://openai.github.io/openai-agents-python/guardrails/), [Tracing](https://openai.github.io/openai-agents-python/tracing/), [Models](https://openai.github.io/openai-agents-python/models/), and [Usage](https://openai.github.io/openai-agents-python/usage/). Comments, annotation markers, and the session example's third turn were removed, and the handoff example joins the quickstart's separate steps. Two more examples are adapted, and each says how.

## Two Frameworks for the Same Job

The [Agents SDK](https://openai.github.io/openai-agents-python/) is OpenAI's Python runtime for agents. You describe an `Agent`, hand it to a `Runner`, and the runner manages turns, tools, handoffs, and guardrails. This page compares the Python package. RubyLLM is the Ruby AI framework. Both give you agents with tools, delegation, streaming, structured output, approvals, and tracing.

The difference is what a conversation is. In the SDK, a run is the unit of work: a conversation lives in a session store, and a paused run is a `RunState` snapshot you serialize. In RubyLLM, a conversation is a transcript: in plain Ruby, an object; in Rails, rows in your database that any process can load, including a chat that waits for an approval.

## An Agent with a Tool

The SDK's quickstart gives an agent one function tool:

```python
import asyncio
from agents import Agent, Runner
from agents.decorators import tool


@tool
def history_fun_fact() -> str:
    """Return a short history fact."""
    return "Sharks are older than trees."


agent = Agent(
    name="History Tutor",
    instructions="Answer history questions clearly. Use history_fun_fact when it helps.",
    tools=[history_fun_fact],
)


async def main():
    result = await Runner.run(
        agent,
        "Tell me something surprising about ancient life on Earth.",
    )
    print(result.final_output)


if __name__ == "__main__":
    asyncio.run(main())
```

In RubyLLM, the tool and the agent are classes:

```ruby
class HistoryFunFact < RubyLLM::Tool
  description "Return a short history fact."

  def execute = "Sharks are older than trees."
end

class HistoryTutor < RubyLLM::Agent
  instructions "Answer history questions clearly. Use history_fun_fact when it helps."
  tools HistoryFunFact
end

response = HistoryTutor.new.ask "Tell me something surprising about ancient life on Earth."
puts response.content
```

Neither names a model. The SDK falls back to [its default](https://openai.github.io/openai-agents-python/models/), and RubyLLM to `default_model` in your [configuration]({% link _getting_started/configuration.md %}). To choose one, pass `model=` in Python or add `model "{{ site.models.default_chat }}"` to the class.

`Runner.run` is asynchronous, so the example needs `asyncio`. The SDK also has `Runner.run_sync`, which drops that wrapper in a script. RubyLLM's `ask` returns when the answer is ready, and runs concurrently inside [`Async`]({% link _advanced/async.md %}) when you want that.

## Streaming

The SDK streams events from the run. To print tokens, you filter for OpenAI's text delta events:

```python
import asyncio
from openai.types.responses import ResponseTextDeltaEvent
from agents import Agent, Runner


async def main():
    agent = Agent(
        name="Joker",
        instructions="You are a helpful assistant.",
    )

    result = Runner.run_streamed(agent, input="Please tell me 5 jokes.")
    async for event in result.stream_events():
        if event.type == "raw_response_event" and isinstance(event.data, ResponseTextDeltaEvent):
            print(event.data.delta, end="", flush=True)


if __name__ == "__main__":
    asyncio.run(main())
```

RubyLLM streams through a block:

```ruby
class Joker < RubyLLM::Agent
  instructions "You are a helpful assistant."
end

Joker.new.ask "Please tell me 5 jokes." do |chunk|
  print chunk.content
end
```

The chunks have the same shape for every provider, and also carry `thinking` and `tool_calls` when the model produces them. The SDK's event stream also reports run items, such as a tool call or a handoff, as they complete. See [Streaming]({% link _core_features/streaming.md %}).

## Sessions and Stored Conversations

An SDK session loads and saves a conversation's history around each run:

```python
from agents import Agent, Runner, SQLiteSession

agent = Agent(
    name="Assistant",
    instructions="Reply very concisely.",
)

session = SQLiteSession("conversation_123")

result = await Runner.run(agent, "What city is the Golden Gate Bridge in?", session=session)
print(result.final_output)

result = await Runner.run(agent, "What state is it in?", session=session)
print(result.final_output)
```

The guide recommends `SQLiteSession` for development and simple apps, and offers Redis, SQLAlchemy, MongoDB, Dapr, and OpenAI-hosted sessions for the rest. [`SQLAlchemySession`](https://github.com/openai/openai-agents-python/blob/v0.24.0/src/agents/extensions/memory/sqlalchemy_session.py) keeps history in its own `agent_sessions` and `agent_messages` tables, with each item serialized into a `message_data` text column.

A RubyLLM agent remembers because its chat holds the transcript:

```ruby
class Assistant < RubyLLM::Agent
  instructions "Reply very concisely."
end

agent = Assistant.new
agent.ask "What city is the Golden Gate Bridge in?"
agent.ask "What state is it in?"
```

In Rails, the transcript is your own `Chat` and `Message` records, so the session ID is the record's ID:

```ruby
class Chat < ApplicationRecord
  acts_as_chat
end

chat = Chat.create! model: "{{ site.models.default_chat }}"
chat.ask "What city is the Golden Gate Bridge in?"

Chat.find(chat.id).ask "What state is it in?"
```

The messages are ordinary rows with their own columns: you can query them, show them in a view, and join them to your users. See [Rails Integration]({% link _getting_started/rails.md %}).

## Human Approval

The SDK marks a tool with `needs_approval`. A paused run lists its `interruptions`, and you serialize its state, approve the calls, and run again. The guide's full example also prompts on the console. This version is adapted from it and keeps the tool, the stored state, and the resume, with the guide's own `cancel_order` tool:

```python
from pathlib import Path

from agents import Agent, Runner, RunState
from agents.decorators import tool


@tool(needs_approval=True)
async def cancel_order(order_id: int) -> str:
    return f"Cancelled order {order_id}"


agent = Agent(
    name="Support agent",
    instructions="Handle tickets and ask for approval when needed.",
    tools=[cancel_order],
)

STATE_PATH = Path("hitl_state.json")


async def request() -> None:
    result = await Runner.run(agent, "Cancel order 42.")

    if result.interruptions:
        STATE_PATH.write_text(result.to_state().to_string())


async def resume() -> None:
    state = await RunState.from_string(agent, STATE_PATH.read_text())

    for interruption in state.get_interruptions():
        state.approve(interruption)

    result = await Runner.run(agent, state)
    print(result.final_output)
```

The snapshot is yours to look after. The guide says it holds your app context, pending calls, and approval decisions, so you [keep it on the server](https://openai.github.io/openai-agents-python/human_in_the_loop/#long-running-approvals), deserialize only trusted snapshots, and coordinate storage so that a replayed submission can't resume the same snapshot twice. It also suggests storing a version marker in case your agent definitions change while an approval waits.

In RubyLLM, the tool declares that it needs approval, and the waiting call is a row. `ApplicationAgent` is the base class the install generator writes, with `chat_class Chat`:

```ruby
class CancelOrder < RubyLLM::Tool
  description "Cancels an order"
  requires_approval

  def execute(order_id:) = "Cancelled order #{order_id}"
end

class SupportAgent < ApplicationAgent
  instructions "Handle tickets and ask for approval when needed."
  tools CancelOrder
end

chat = SupportAgent.create!
chat.ask "Cancel order 42."
chat.waiting?                          # => true
chat.pending_questions.first.approval? # => true
```

Another request, after a deploy if need be, records the decision and continues:

```ruby
chat = SupportAgent.find params[:id]
chat.approve params[:tool_call_id]
chat.complete
```

You still authorize the reviewer in your controller, as you would for any other action. A double-submitted approval is safe, because only one process runs a chat at a time, and `find` applies the agent's current tools and instructions. `chat.pending_questions` lists what to show, and `chat.decline` sends the model a refusal, with the reviewer's note if they give one. See [Controlling Tool Execution]({% link _tools/tool-execution.md %}#requiring-approval).

Nested agents differ. In the SDK, an approval inside a nested agent tool surfaces on the outer run and is stored with it, so it can resume in another process. A RubyLLM [subagent]({% link _getting_started/agents.md %}#subagents) from `tools` has to finish within its call. One that waits for a person keeps its work in a [chat of its own]({% link _getting_started/agents.md %}#subagents-that-wait-for-a-person), and the outer call pauses on a task that holds that chat's ID, so any process can carry both on once the person decides.

## Handoffs

Handoffs are the idea this SDK is known for. The model picks a specialist, and that specialist takes over the conversation for the rest of the turn. To the model, a [handoff](https://openai.github.io/openai-agents-python/handoffs/) is a tool named `transfer_to_<agent_name>`. The quickstart's triage agent:

```python
import asyncio
from agents import Agent, Runner

history_tutor_agent = Agent(
    name="History Tutor",
    handoff_description="Specialist agent for historical questions",
    instructions="You answer history questions clearly and concisely.",
)

math_tutor_agent = Agent(
    name="Math Tutor",
    handoff_description="Specialist agent for math questions",
    instructions="You explain math step by step and include worked examples.",
)

triage_agent = Agent(
    name="Triage Agent",
    instructions="Route each homework question to the right specialist.",
    handoffs=[history_tutor_agent, math_tutor_agent],
)


async def main():
    result = await Runner.run(
        triage_agent,
        "Who was the first president of the United States?",
    )
    print(result.final_output)
    print(f"Answered by: {result.last_agent.name}")


if __name__ == "__main__":
    asyncio.run(main())
```

RubyLLM has no `handoffs` argument, so you write the switch in Ruby. A triage agent answers with a schema, and your code picks the specialist:

```ruby
class HistoryTutor < RubyLLM::Agent
  instructions "You answer history questions clearly and concisely."
end

class MathTutor < RubyLLM::Agent
  instructions "You explain math step by step and include worked examples."
end

class TriageAgent < RubyLLM::Agent
  instructions "Route each homework question to the right specialist."

  schema do
    string :specialist, enum: %w[history math]
  end
end

question = "Who was the first president of the United States?"
specialist = TriageAgent.new.ask(question).parsed["specialist"]
tutor = { "history" => HistoryTutor, "math" => MathTutor }.fetch specialist

puts tutor.new.ask(question).content
```

This routes before the specialist starts, and the choice is a value you can log, test, or override. The SDK's handoff differs in one way: the triage model can also call tools first and transfer mid-turn with the history attached. For that, you give the model a tool that names the specialist and run the loop yourself, as [Agent Handoffs]({% link _advanced/agentic-workflows.md %}#agent-handoffs) shows.

`Agent.new(chat:)` is the part that moves a conversation. It applies another agent's instructions and tools to a stored chat, and the specialist reads the whole history:

```ruby
chat = Chat.find params[:id]
HistoryTutor.new(chat:).ask params[:question]
```

### Agents as Tools

When a manager should keep control and call specialists for an answer, the SDK turns each agent into a tool with `as_tool`:

```python
import asyncio

from agents import Agent, Runner

spanish_agent = Agent(
    name="Spanish agent",
    instructions="You translate the user's message to Spanish",
)

french_agent = Agent(
    name="French agent",
    instructions="You translate the user's message to French",
)

orchestrator_agent = Agent(
    name="orchestrator_agent",
    instructions=(
        "You are a translation agent. You use the tools given to you to translate. "
        "If asked for multiple translations, you call the relevant tools."
    ),
    tools=[
        spanish_agent.as_tool(
            tool_name="translate_to_spanish",
            tool_description="Translate the user's message to Spanish",
        ),
        french_agent.as_tool(
            tool_name="translate_to_french",
            tool_description="Translate the user's message to French",
        ),
    ],
)


async def main():
    result = await Runner.run(orchestrator_agent, input="Say 'Hello, how are you?' in Spanish.")
    print(result.final_output)


if __name__ == "__main__":
    asyncio.run(main())
```

In RubyLLM, an agent class goes wherever a tool goes:

```ruby
class SpanishAgent < RubyLLM::Agent
  description "Translate the user's message to Spanish"
  instructions "You translate the user's message to Spanish"
end

class FrenchAgent < RubyLLM::Agent
  description "Translate the user's message to French"
  instructions "You translate the user's message to French"
end

class Orchestrator < RubyLLM::Agent
  instructions "You are a translation agent. You use the tools given to you to translate. " \
               "If asked for multiple translations, you call the relevant tools."
  tools SpanishAgent, FrenchAgent
end

response = Orchestrator.new.ask "Say 'Hello, how are you?' in Spanish."
puts response.content
```

The model calls them as `spanish_agent` and `french_agent`. See [Subagents]({% link _getting_started/agents.md %}#subagents).

## Guardrails

An SDK guardrail attaches a check to an agent. An input guardrail runs on the first agent's input, an output guardrail on the final output, and a tripwire raises an exception. The guide's example uses a second agent as the check:

```python
from pydantic import BaseModel
from agents import (
    Agent,
    GuardrailFunctionOutput,
    InputGuardrailTripwireTriggered,
    RunContextWrapper,
    Runner,
    TResponseInputItem,
)
from agents.decorators import input_guardrail


class MathHomeworkOutput(BaseModel):
    is_math_homework: bool
    reasoning: str


guardrail_agent = Agent(
    name="Guardrail check",
    instructions="Check if the user is asking you to do their math homework.",
    output_type=MathHomeworkOutput,
)


@input_guardrail
async def math_guardrail(
    ctx: RunContextWrapper[None], agent: Agent, input: str | list[TResponseInputItem]
) -> GuardrailFunctionOutput:
    result = await Runner.run(guardrail_agent, input, context=ctx.context)

    return GuardrailFunctionOutput(
        output_info=result.final_output,
        tripwire_triggered=result.final_output.is_math_homework,
    )


agent = Agent(
    name="Customer support agent",
    instructions="You are a customer support agent. You help customers with their questions.",
    input_guardrails=[math_guardrail],
)


async def main():
    try:
        await Runner.run(agent, "Hello, can you help me solve for x: 2x + 3 = 11?")
        print("Guardrail didn't trip - this is unexpected")

    except InputGuardrailTripwireTriggered:
        print("Math homework guardrail tripped")
```

RubyLLM has no guardrail primitive. A check is an agent with a schema, and the tripwire is an `if`:

```ruby
class MathHomeworkCheck < RubyLLM::Agent
  instructions "Check if the user is asking you to do their math homework."

  schema do
    boolean :is_math_homework
    string :reasoning
  end
end

class SupportAgent < RubyLLM::Agent
  instructions "You are a customer support agent. You help customers with their questions."
end

question = "Hello, can you help me solve for x: 2x + 3 = 11?"

if MathHomeworkCheck.new.ask(question).parsed["is_math_homework"]
  puts "Math homework guardrail tripped"
else
  puts SupportAgent.new.ask(question).content
end
```

This matches the SDK's blocking mode, `run_in_parallel=False`: the expensive agent never starts when the check trips. The SDK's default runs the two concurrently, stops the agent when the tripwire fires, and keeps the check on the agent, so every run that starts with it gets the check. In RubyLLM, you put the check where you call the agent, and you write any concurrent version yourself with `Async`.

The nearest pieces for the rest: `around_tool_call` wraps each tool call and can skip it, where the SDK has tool guardrails. `RubyLLM.moderate` screens content with a provider's moderation model. See [Chat Event Handlers]({% link _core_features/chat-callbacks.md %}#wrapping-tool-calls) and [Moderation]({% link _getting_started/moderation.md %}).

## Tracing

The SDK [traces every run by default](https://openai.github.io/openai-agents-python/tracing/) and exports to OpenAI's Traces dashboard, with no setup beyond an OpenAI API key. Model calls, tools, handoffs, and guardrails each get a span. Custom processors send traces elsewhere, and the guide lists integrations for other backends. Tracing is unavailable to organizations under OpenAI's Zero Data Retention policy, and without an OpenAI key the [Models guide](https://openai.github.io/openai-agents-python/models/) recommends disabling it or adding another processor.

RubyLLM has no hosted dashboard. It traces to the OpenTelemetry backend you already run, with one line:

```ruby
RubyLLM::OpenTelemetry.enable
```

Tracing is off until you add that line. `RubyLLM.workflow` groups calls the way the SDK's `trace()` does, and in Rails it also groups their cost. See [OpenTelemetry]({% link _advanced/opentelemetry.md %}) and [Agentic Workflows]({% link _advanced/agentic-workflows.md %}#grouping-a-workflows-calls).

## Other Providers

The SDK speaks OpenAI's APIs natively. For other providers, it offers OpenAI-compatible clients, custom `ModelProvider`s, and two adapters its guide calls [best-effort and beta](https://openai.github.io/openai-agents-python/models/#third-party-adapters). This is the shortest path, a `litellm/` model name after installing `openai-agents[litellm]`. It's adapted from the guide's LiteLLM example, with the model changed to match:

```python
from agents import Agent, Runner, set_tracing_disabled

set_tracing_disabled(disabled=True)

agent = Agent(
    name="Assistant",
    instructions="You only respond in haikus.",
    model="litellm/anthropic/{{ site.models.anthropic_latest }}",
)

result = Runner.run_sync(agent, "What's the weather in Tokyo?")
print(result.final_output)
```

The guide adds that feature support and request semantics can vary by provider through an adapter, and that [hosted tools](https://openai.github.io/openai-agents-python/tools/#hosted-tools) need the `OpenAIResponsesModel`.

In RubyLLM, the model name is the only change, and the provider is one RubyLLM speaks directly:

```ruby
class HaikuAgent < RubyLLM::Agent
  model "{{ site.models.anthropic_latest }}"
  instructions "You only respond in haikus."
end

response = HaikuAgent.new.ask "What's the weather in Tokyo?"
puts response.content
```

The same tools, schemas, streaming, thinking, and caching APIs cover every [provider]({% link _reference/configuration-providers.md %}) that offers them.

## Usage and Cost

The SDK adds up tokens across a run:

```python
result = await Runner.run(agent, "What's the weather in Tokyo?")
usage = result.context_wrapper.usage

print("Requests:", usage.requests)
print("Input tokens:", usage.input_tokens)
print("Output tokens:", usage.output_tokens)
print("Total tokens:", usage.total_tokens)
```

[`Usage`](https://openai.github.io/openai-agents-python/ref/usage/) also has per-request entries and cache and reasoning details. It has no price field, so turning tokens into dollars is your code.

RubyLLM reports tokens and dollars on responses and chats, priced from its model registry. When usage or a price is unknown, the cost is `nil`, never a misleading zero:

```ruby
chat = RubyLLM.chat
response = chat.ask "What's the weather in Tokyo?"

response.tokens.input
response.tokens.output
response.cost.total
chat.cost.total
```

With `acts_as_chat`, every billed attempt also lands in the `ruby_llm_usages` table, and `RubyLLM.with_owner` attributes each row to a user or account. See [Cost and Usage Tracking]({% link _core_features/cost-and-usage-tracking.md %}).

## Concept Map

| Agents SDK | RubyLLM |
| --- | --- |
| `Agent(name, instructions, tools)` | A [`RubyLLM::Agent`]({% link _getting_started/agents.md %}) class |
| `@tool` | A [`RubyLLM::Tool`]({% link _getting_started/tools.md %}) class |
| `Runner.run` and `Runner.run_sync` | `ask` |
| `Runner.run_streamed` and `stream_events` | A block given to `ask` |
| `output_type=Schema` | `schema Schema` or `with_schema` |
| `max_turns` | `generate`, `run_tools`, and `complete?` in [your own loop]({% link _advanced/agentic-workflows.md %}#driving-the-loop-yourself) |
| `handoffs=[...]` | No equivalent. `Agent.new(chat:)` and [your own workflow code]({% link _advanced/agentic-workflows.md %}#agent-handoffs) |
| `agent.as_tool()` | An agent class in `tools` |
| `input_guardrails` and `output_guardrails` | No equivalent. A check agent or `RubyLLM.moderate` in your code |
| Tool guardrails | `around_tool_call` |
| `SQLiteSession` and other sessions | The chat's transcript, or an `acts_as_chat` record |
| `needs_approval` and `RunState` | `requires_approval`, `approve`, and `decline` |
| `result.context_wrapper.usage` | `response.tokens` and `response.cost` |
| Tracing and the Traces dashboard | [OpenTelemetry]({% link _advanced/opentelemetry.md %}) and your own backend |
| `trace()` | `RubyLLM.workflow` |
| `mcp_servers` | [`with_mcp`]({% link _tools/mcp.md %}) |
| Hosted tools | [`with_provider_tools`]({% link _tools/provider-tools.md %}) |
| Sandbox agents | [Code Execution]({% link _advanced/code-execution.md %}) is the closest |
| Voice pipeline | `transcribe`, an agent, and `speak` in your own code |
| Realtime agents | No equivalent |

## When to Choose the Agents SDK

* **Your team works in Python.** Data science, notebooks, and machine learning code are already there, and the SDK fits next to them.
* **You build on OpenAI.** Hosted tools, the Responses API, and the Traces dashboard work with little setup, and tracing connects to OpenAI's evaluation and fine-tuning tools.
* **You want handoffs as a framework feature.** One `handoffs` argument gives you the mid-turn transfer that you write as a tool in RubyLLM.
* **You want guardrails on the agent.** They run in parallel by default and stop the run when a tripwire fires.
* **You build realtime voice agents.** The SDK has [Realtime agents](https://openai.github.io/openai-agents-python/realtime/guide/). RubyLLM has speech and transcription as separate operations, and no live conversation API.
* **You already run a durable workflow engine.** The guide covers [Temporal, Restate, DBOS, and Dapr](https://openai.github.io/openai-agents-python/running_agents/#durable-execution-integrations-and-human-in-the-loop).

## When to Choose RubyLLM

* **Your application is Ruby or Rails.** Agents are classes, chats are Active Record models, and loops run in Active Job, without a separate store for runs.
* **Waiting work must survive processes.** Approvals and the loop read and write the database, so a worker that dies resumes from the last saved message, and there is no snapshot to serialize. See [Agents in Background Jobs]({% link _advanced/durable-agents.md %}).
* **You need cost in dollars** on responses, chats, and agents, and a usage ledger in Rails.
* **You use more than one provider.** Changing a model name moves an agent to another provider, with no adapter in between.
* **You need more than chat.** Images, video, speech, transcription, OCR, moderation, embeddings, and reranking use the same configuration.

## Next Steps

* [Agents]({% link _getting_started/agents.md %}) - Define agents as classes and use them anywhere.
* [Agentic Workflows]({% link _advanced/agentic-workflows.md %}) - Route, hand off, and run agents in parallel with plain Ruby.
* [Agents in Background Jobs]({% link _advanced/durable-agents.md %}) - Run the loop one step per job.
