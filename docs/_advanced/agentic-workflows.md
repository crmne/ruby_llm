---
layout: default
title: Agentic Workflows
nav_order: 1
description: Compose agents and AI operations with ordinary Ruby methods, from routing and handoffs to parallel work, and drive the agentic loop yourself.
redirect_from:
  - /agent-handoffs/
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* What a workflow is, and which pattern fits which problem.
* How to chain, route, hand off, and run agents in parallel with plain Ruby classes.
* When an evaluator loop is worth its cost.
* How to group a workflow's calls for instrumentation and cost tracking.
* How to drive the agentic loop yourself, one move at a time.
* How to queue messages that join a running loop or wait for its turn to end.

## What Is a Workflow?

One agent with good tools handles most requests. Some work is better split: a cheap model sorts incoming email so an expensive one only sees what needs it, independent checks run at once instead of one after another, or a second agent reviews the first one's draft before a customer sees it.

A workflow is the Ruby code that coordinates those steps. RubyLLM has no workflow DSL: a workflow is usually a small class with one public method that calls agents and operations and passes results between them. You test it, retry it, and run it in jobs like any other Ruby code.

## Choosing a Pattern

| Pattern | Use it when | Support desk example |
| --- | --- | --- |
| [Sequential](#sequential-workflow) | Each step needs the previous step's result. | Transcribe a voicemail, then draft a reply. |
| [Routing](#routing-workflow) | Requests fall into categories that need different agents or models. | Send billing questions to `BillingAgent` and delivery questions to `ShippingAgent`. |
| [Handoff](#agent-handoffs) | A specialist should take over the same conversation. | Billing takes over a chat that started as a delivery question. |
| [Subagent](#subagents) | The model should decide when to delegate, and only the answer matters. | `SupportAgent` asks `ResearchAgent` to read the help center. |
| [Parallel](#parallel-workflow) | Independent steps can run at the same time. | Moderate, triage, and search for one email at once. |
| [Fan-out, fan-in](#fan-outfan-in-workflow) | Several specialists' results combine into one. | Three reviewers check a reply, and one summary comes back. |
| [Evaluator loop](#evaluation-loop-evaluator-optimizer) | Quality criteria are clear and a draft can improve. | Revise a reply until it follows the refund policy. |

Start with the simplest pattern that works. Each step adds latency and cost, so add one when it makes the result better.

## Workflow Patterns

The examples use `SupportAgent` and `TriageAgent` from [Agents]({% link _getting_started/agents.md %}) and the tools from [Tools]({% link _getting_started/tools.md %}).

### Sequential Workflow

Use this pattern when each step needs the previous step's result. A voicemail becomes text, and the text becomes a drafted reply:

```ruby
class VoicemailReply
  def call(voicemail)
    transcript = RubyLLM.transcribe(voicemail.audio).text
    SupportAgent.new(customer: voicemail.customer).ask("Draft a reply to this voicemail:\n#{transcript}").content
  end
end
```

### Routing Workflow

Use this pattern when requests fall into categories that need different agents, instructions, or models. A cheap model triages, and a specialist answers:

```ruby
class BillingAgent < RubyLLM::Agent
  model "{{ site.models.anthropic_current }}"
  inputs :customer
  instructions "You handle billing for Acme Outfitters: invoices, charges, and refunds."
  tools { [LookupOrder.new(customer), IssueRefund] }
end

class ShippingAgent < RubyLLM::Agent
  model "{{ site.models.openai_mini }}"
  inputs :customer
  instructions "You handle deliveries for Acme Outfitters: tracking, delays, and addresses."
  tools { [LookupOrder.new(customer)] }
end

class SupportRouter
  SPECIALISTS = { "billing" => BillingAgent, "shipping" => ShippingAgent }

  def call(customer, message)
    category = TriageAgent.new.ask(message).parsed["category"]
    SPECIALISTS.fetch(category, SupportAgent).new(customer: customer).ask(message)
  end
end
```

`TriageAgent` answers with its schema, so the category is always one the router expects, and anything else goes to the general `SupportAgent`. `IssueRefund` is the tool from [Requiring Approval]({% link _tools/tool-execution.md %}#requiring-approval), so a refund waits for a person.

### Agent Handoffs

Routing picks an agent for one message. A handoff gives the *same conversation* to another agent, so the specialist sees the whole history and the customer keeps one thread. `Agent.new(chat:)` makes this work: it applies another agent's instructions and tools to a saved chat, and the conversation carries on.

The simplest handoff routes each new message, and the specialist answers in the saved chat:

```ruby
class SupportHandoff
  SPECIALISTS = { "billing" => BillingAgent, "shipping" => ShippingAgent }

  def call(chat_id, message)
    chat = Chat.find(chat_id)
    category = TriageAgent.new.ask(message).parsed["category"]
    SPECIALISTS.fetch(category, SupportAgent).new(chat: chat, customer: chat.customer).ask(message)
  end
end
```

To let the agent decide in the middle of a conversation, give it a tool that names the specialist. Run the [loop](#driving-the-loop-yourself) yourself, and stop when the tool has been called:

```ruby
class Handoff < RubyLLM::Tool
  description "Hands the conversation to the specialist who should answer next"
  parameter :specialist, description: "billing or shipping"

  attr_reader :specialist

  def execute(specialist:)
    return { error: "Choose billing or shipping" } unless %w[billing shipping].include?(specialist)

    @specialist = specialist
    "The #{specialist} team is taking over."
  end
end

class SupportDesk
  SPECIALISTS = { "billing" => BillingAgent, "shipping" => ShippingAgent }

  def call(chat_id, message)
    handoff = Handoff.new
    chat = Chat.find(chat_id)
    SupportAgent.new(chat: chat, customer: chat.customer)
    chat.with_tools(handoff).ask_later(message)

    chat.step until chat.complete? || chat.waiting? || handoff.specialist
    return chat.messages.last unless handoff.specialist

    chat = Chat.find(chat_id)
    SPECIALISTS.fetch(handoff.specialist).new(chat: chat, customer: chat.customer)
    chat.complete
  end
end
```

The switch belongs in the workflow, not the tool: a tool's `execute` never receives the chat, so it can't reconfigure it. Loading the chat again drops the first agent's tools, so the specialist starts with only its own.

A saved chat keeps its model: an agent's `model` applies when it creates a chat. Call `chat.with_model` to move the conversation to the specialist's model.
{: .note }

### Subagents

A subagent is a handoff the model decides on: a fresh agent does the work in its own conversation, and only its answer comes back. Use one when the delegated work is long, such as reading twenty articles, and the calling conversation needs only the result. See [Subagents]({% link _getting_started/agents.md %}#subagents).

### Parallel Workflow

Use this pattern when independent steps can run at the same time. Before anyone reads an email, moderate it, triage it, and look for help center articles at once:

```ruby
require "async"

class IncomingEmail
  def call(email)
    Async do |task|
      moderation = task.async { RubyLLM.moderate(email.body) }
      triage = task.async { TriageAgent.new.ask(email.body).parsed }
      articles = task.async { SearchDocs.new.execute(query: email.subject) }

      { flagged: moderation.wait.flagged?, triage: triage.wait, articles: articles.wait }
    end.wait
  end
end
```

The three calls take as long as the slowest one. See [Scale with Async]({% link _advanced/async.md %}) for running RubyLLM in fibers.

### Fan-Out/Fan-In Workflow

Use this pattern when several specialists review the same input and one summary comes back. Before a sensitive reply goes out, check it three ways:

```ruby
require "async"

class ToneReviewer < RubyLLM::Agent
  model "{{ site.models.openai_mini }}"
  instructions "Review a support reply for tone. Is it friendly, calm, and free of blame?"
end

class PolicyReviewer < RubyLLM::Agent
  model "{{ site.models.anthropic_current }}"
  instructions "Review a support reply against the Acme Outfitters refund and returns policy."
end

class AccuracyReviewer < RubyLLM::Agent
  model "{{ site.models.default_chat }}"
  instructions "Check every order detail in a support reply against the order data given."
end

class ReviewSummary < RubyLLM::Agent
  instructions "Combine the reviews into a short, prioritized list of changes to make."
end

class ReplyReview
  def call(reply, order)
    Async do |task|
      tone = task.async { ToneReviewer.new.ask(reply).content }
      policy = task.async { PolicyReviewer.new.ask(reply).content }
      accuracy = task.async { AccuracyReviewer.new.ask("Order: #{order.to_json}\n\nReply: #{reply}").content }

      ReviewSummary.new.ask("Tone:\n#{tone.wait}\n\nPolicy:\n#{policy.wait}\n\nAccuracy:\n#{accuracy.wait}").content
    end.wait
  end
end
```

### Evaluation Loop (Evaluator-Optimizer)

Use this pattern when you have clear criteria and a draft can get better. One agent writes, another judges, and the writer revises until the judge passes it or the rounds run out:

```ruby
class PolicyCritic < RubyLLM::Agent
  instructions "Check a support reply against the refund policy: refunds within 30 days, store credit after."

  schema do
    string :verdict, enum: %w[pass revise], description: "Whether the reply follows the policy"
    string :feedback, description: "What to change, if anything"
  end
end

class PolicyCheckedReply
  MAX_ROUNDS = 3

  def call(customer, question)
    writer = SupportAgent.new(customer: customer)
    reply = writer.ask(question).content

    MAX_ROUNDS.times do |round|
      review = PolicyCritic.new.ask("Question:\n#{question}\n\nReply:\n#{reply}").parsed
      return reply if review["verdict"] == "pass"

      reply = writer.ask("Revise your reply. #{review['feedback']}").content if round < MAX_ROUNDS - 1
    end

    nil
  end
end
```

A `nil` means the rounds ran out without a passing reply, so pass the ticket to a person. Each round costs a review and a revision. Cap the rounds, and use this pattern where a wrong answer costs more than the extra calls. To grade agents offline instead of on every request, see [Evaluations]({% link _advanced/evaluations.md %}).

## Grouping a Workflow's Calls

Wrap a workflow in `RubyLLM.workflow` and mark its steps with `workflow.step` to see it as one unit. This one turns a voicemail into a triaged ticket and reads a reply back on the phone line:

```ruby
RubyLLM.workflow("Voicemail", id: "voicemail-#{voicemail.id}") do |workflow|
  transcript = workflow.step("Transcribe") { RubyLLM.transcribe(voicemail.audio) }
  triage = workflow.step("Triage") { TriageAgent.new.ask(transcript.text).parsed }
  reply = workflow.step("Reply") do
    SupportAgent.new(customer: voicemail.customer).ask("Reply to this voicemail:\n#{transcript.text}")
  end
  workflow.step("Speak") { RubyLLM.speak(reply.content).save("reply-#{voicemail.id}.mp3") }
end
```

Each step returns its block's value. The wrappers don't run anything themselves: they add correlation to the [instrumentation events]({% link _advanced/instrumentation.md %}#workflows-and-steps), so you can follow the four calls as one operation. In Rails, the usage ledger records the workflow too, so you can read what it cost:

```ruby
RubyLLM::ActiveRecord::Usage.where(workflow_id: "voicemail-#{voicemail.id}").sum(:total_cost)
```

See [Usage by Workflow]({% link _core_features/cost-and-usage-tracking.md %}#usage-by-workflow).

## Driving the Loop Yourself

`ask` sends your message and runs the conversation to completion: it calls the model, runs any [tools]({% link _getting_started/tools.md %}) the model asks for, and calls the model again until it answers without a tool. When you need to control that loop, for example to run each turn as its own background job, set an iteration budget, or stop and resume on another machine, `Chat` exposes it as named verbs:

* `generate` runs the model once and appends its response (the model's move). It returns the response.
* `run_tools` executes the tool calls the model asked for and appends their results (your move). It makes no model call and returns the chat.
* `step` does whichever move is next: `run_tools` if tools are pending, otherwise `generate`. It returns the message that move produced, and `nil` once there is nothing left or the loop is parked for approval.
* `complete` steps until done. This is what `ask` calls, and it returns the final response.
* `complete?` is true when the model answered without calling a tool, or a tool [ended the turn]({% link _tools/tool-execution.md %}#ending-the-turn) with `halt`.

So the agentic loop is `step` until `complete?`:

```ruby
chat = RubyLLM.chat.with_tools(LookupOrder.new(customer)).ask_later("Where is my order R-1042?")

chat.step until chat.complete? || chat.waiting?
chat.messages.last.content      # => "Order R-1042 shipped on Monday and arrives tomorrow."
```

`ask_later` stages the question without sending it, so `ask` is `ask_later` then `complete`.

With Rails persistence, each method reads the saved transcript and skips tool calls with saved results. Only one process runs a chat at a time: while another process is running it, each method returns without doing anything and `waiting?` is `true`. Work interrupted before its result is saved may run again once its claim expires. See [Agents in Background Jobs]({% link _advanced/durable-agents.md %}) for job retries and idempotent tools.

Stop scheduling work while `waiting?` is true: the chat waits on something outside it. `awaiting_approval?` tells you it waits on an approval, so record one or a denial, then resume the loop. `awaiting_input?` and `awaiting_tasks?` cover [MCP servers]({% link _tools/mcp.md %}#input-requests) asking for input and running tasks. `awaiting_person?` is true when any of them needs a person to act, including a task that reports `input_required?`.

When a tool calls `halt`, its round still finishes, and then `step` returns `nil`, `complete` returns the halted tool result, and the queue's messages join as they would after an answer.

[Batches]({% link _advanced/batches.md %}) are the same idea at scale: a batch is `generate` deferred for many chats at once, with `run_tools` run locally between rounds. A chat whose tool halted is `complete?`, so leave it out of the next round, as you would a chat the model answered.

## Queueing Messages

People keep typing while an agent works. `queue` adds a user message without touching the conversation, from any thread, even while `complete` runs in another one, and the loop takes it between two of its moves:

```ruby
chat = SupportAgent.chat(customer: customer)
chat.ask_later "Where is my order R-1042?"
worker = Thread.new { chat.complete }

chat.queue "Actually, it's R-1043"
worker.join
chat.complete if chat.queued_messages.any?
```

By default a queued message steers the turn that is running. It joins after the next round of tool results, so the model reads it on its next request, still inside its tool loop. If the model is writing its final answer, the message waits for the answer to finish, and the loop then asks the model again so it answers the new message too. Nothing is cut short.

Pass `steer: false` to wait for the turn boundary instead. `complete` finishes the turn and returns, the chat is `complete?`, and the message stays queued until the conversation moves on:

```ruby
chat.queue "Also, can I change the delivery address?", steer: false
chat.complete while chat.queued_messages.any?
```

A turn starts once its question is in place. With no tool calls pending, every `ask`, `ask_later`, or `step`, and a `complete` on a chat the model has answered, first takes every queued message, steering or not, oldest first, before the model is asked and before the new question `ask` adds. Within a turn only steering messages join, so a steering message can join before a waiting one queued earlier. A `complete` after `ask_later`, or one that retries a turn that failed, continues that turn: messages queued with `steer: false` wait for its answer. Messages that join together become separate user messages, in order.

`queue` never runs the loop. When nothing is running, call `complete` yourself. A few more rules:

* While the chat is `waiting?` on an approval, an input, or a task, nothing joins: the round's tool calls need their results first. Record the decision and call `complete`. The tools run, then the steering messages join. The resumed turn is the same turn, so messages queued with `steer: false` keep waiting for the next one.
* `cancel` stops the loop and leaves the queue as it is. The next `ask` takes those messages as ordinary user messages. A `complete` instead continues the cancelled turn, so only the steering ones join until the model answers.
* `withdraw` takes a message back before the loop takes it. It returns `false` once the loop has taken it, so a Cancel button and the loop can race safely.
* `queued_messages` lists what waits, oldest first, as `RubyLLM::QueuedMessage` values with `content`, `attachments`, `sender`, `queued_at`, and `steer?`.

```ruby
queued = chat.queue "Here is the receipt", with: "receipt.pdf", sender: current_customer
chat.queued_messages # => [#<RubyLLM::QueuedMessage ...>]
queued.withdraw      # => true
```

`chat.withdraw(queued)` does the same by message or id. `sender` is stored with the message and handed back on it. RubyLLM does not interpret it, so use it for whatever your application needs to know about who asked.

### Joining Queued Messages

`around_join` wraps the moment a queued message joins the conversation. The block receives the queued message and `join`. Call `join.call` to add the user message; it returns the message:

```ruby
chat.around_join do |queued, join|
  message = join.call
  AuditLog.record(queued.sender, message.content)
end
```

A block that never calls `join` withdraws the message. It leaves the queue without joining, and the turn goes on without it:

```ruby
chat.around_join do |queued, join|
  join.call unless queued.sender.blocked?
end
```

If the block raises, the message stays queued and out of the conversation, and the error reaches the caller of `complete`. Several `around_join` blocks nest in the order you register them, the first outermost, like Rails around callbacks. When an inner block withdraws the message, `join.call` in an outer block returns `nil`. Agents declare them with the `around_join` class macro.

`join_queued_messages` joins everything waiting, steering or not, without asking the model. Each message goes through `around_join` and `after_message`, and you get back the messages that joined:

```ruby
chat.queue "Actually, it's R-1043"
chat.queue "Also, can I change the delivery address?", steer: false
chat.join_queued_messages.map(&:content) # => ["Actually, it's R-1043", "Also, can I change the delivery address?"]
```

Like `ask_later`, it raises `RubyLLM::PendingToolCallsError` while tool calls wait for their results.

`after_message` receives each message that joins; see [Queue Events]({% link _core_features/chat-callbacks.md %}#queue-events). With Rails, queued messages live in their own table, so a request can queue a message for a reply a job is running; see [Queued Messages]({% link _advanced/rails-persistence.md %}#queued-messages).

## Retrieval-Augmented Generation

Retrieve relevant documents and pass them to an answering agent. See [RAG]({% link _advanced/rag.md %}) for a retrieval tool, and [Reranking]({% link _getting_started/rerank.md %}) for ordering candidate documents before the model reads them.

## Error Handling

Handle failures at the step that can recover from them:

* Return `{ error: "..." }` from a tool when the model can fix the problem, and raise when it can't. See [Handling Errors in Tools]({% link _getting_started/tools.md %}#handling-errors-in-tools).
* Let RubyLLM's automatic retries handle rate limits and outages, and add [model fallbacks]({% link _advanced/error-handling.md %}#model-fallbacks) for a step that must answer.
* Run workflows in jobs, and use `retry_on` and `discard_on` for what's left. See [Handling Errors in Jobs]({% link _getting_started/rails.md %}#handling-errors-in-jobs).

## Next Steps

* [Durable Agents]({% link _advanced/durable-agents-overview.md %}): run workflows in jobs that pause for people and survive deploys.
* [Retrieval-Augmented Generation]({% link _advanced/rag.md %}): ground answers in your own documents.
* [Scale with Async]({% link _advanced/async.md %}): run workflow steps concurrently.
* [Instrumentation]({% link _advanced/instrumentation.md %}): follow a workflow's calls in your observability stack.
