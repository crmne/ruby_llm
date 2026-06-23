---
layout: default
title: Agent Handoffs
parent: "Agentic Workflows"
nav_order: 1
description: Hand an ongoing conversation to a specialist agent so the user keeps one continuous thread
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

* How a handoff differs from routing.
* How to hand a persisted chat to a specialist in a single router turn.
* How `Agent.find(chat_id)` loads a chat and swaps instructions and tools at runtime.
* How to let an agent decide mid-conversation to hand off via a tool.
* How to chain handoffs across multiple specialists with one loop.

[Routing]({% link _advanced/agentic-workflows.md %}#routing-workflow) picks an agent up front. A handoff goes further: it hands the *same ongoing conversation* to a different agent, so the specialist sees the full history and the user keeps one continuous thread. `Agent.find(chat_id)` is what makes this work. It loads a persisted chat and applies a different agent's instructions and tools at runtime, leaving the messages intact, so whichever agent takes over inherits the whole conversation.

## Single-Turn Handoff

The simplest version is a single turn. Give a router an inline schema so it answers with the specialist to hand to, then let that specialist continue the persisted chat:

```ruby
class SupportRouter < RubyLLM::Agent
  schema do
    string :specialist, enum: %w[billing technical]
  end
  instructions "Pick the specialist best suited to the latest message."
end

SPECIALISTS = { "billing" => BillingAgent, "technical" => TechnicalAgent }

def handle(chat_id, message)
  specialist = SupportRouter.new.ask(message).content["specialist"]
  SPECIALISTS.fetch(specialist).find(chat_id).ask(message)
end
```

The router responds immediately with its choice (no tool round-trip), and the specialist takes over the same chat with full history. Outside Rails, pass the chat object with `SpecialistAgent.new(chat: chat)` instead of `find(chat_id)`.

## Mid-Conversation Handoff

If you would rather the agent decide mid-conversation, give it a single handoff tool that returns the specialist to switch to. Drive the [loop]({% link _advanced/agentic-workflows.md %}#driving-the-loop-yourself) a step at a time, and when a tool result names an agent, hand off:

```ruby
class Handoff < RubyLLM::Tool
  description "Hand the conversation to the specialist who should answer next"
  param :specialist, desc: "billing or technical"
  def execute(specialist:) = specialist
end

class SupportRouter < RubyLLM::Agent
  chat_model Chat
  instructions "Call handoff with the specialist who should take over."
  tools Handoff
end

AGENTS = { "billing" => BillingAgent, "technical" => TechnicalAgent }

agent = SupportRouter.find(chat_id)
agent.ask_later(message)

until agent.complete?
  agent.step
  last = agent.messages.reload.last
  specialist = AGENTS[last.content] if last.role == "tool"
  agent = specialist.find(chat_id) if specialist
end
```

The handoff tool just returns the name; the orchestrator owns the routing, watching each tool result and swapping agents when one names a specialist. Because the routing lives in the loop and not in any agent, this extends to a multi-router for free: give the specialists the same `Handoff` tool and they can route onward, with every hop handled the same way.

(A tool cannot reconfigure the chat it runs inside, since its `execute` never receives the chat, so the switch belongs in the loop, not in the tool.)

## Next Steps

* [Agentic Workflows]({% link _advanced/agentic-workflows.md %}) - Orchestrate agents with plain Ruby, including the loop you drive here.
* [Agents]({% link _advanced/agents.md %}) - Define the specialist agent classes you hand off to.
* [Tools]({% link _core_features/tools.md %}) - Build the handoff tool and other capabilities.
* [Persistence with acts_as]({% link _advanced/rails-persistence.md %}) - Persist the chat that `find(chat_id)` reloads.
