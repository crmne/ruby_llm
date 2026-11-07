---
layout: default
title: Agents in Background Jobs
parent: "Durable Agents"
nav_order: 1
description: Run agent turns as background jobs that survive crashes, deploys, and the wait for a human decision.
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* Why a persisted chat is resumable by construction, with no run state to serialize.
* How to run each agent turn as its own background job.
* How to survive deploys with ActiveJob Continuations.
* How an approval-gated tool parks the loop across processes, in the chat or in one of its subagents.
* Why only one process runs a chat at a time, and how a crashed run resumes.
* How to stop a running agent from anywhere.
* Why execution is at-least-once, and what that asks of your tools.

## The Transcript Is the State

A persisted conversation records which model responses and tool results have completed. Load it through the agent class in another process and continue:

```ruby
chat = SupportAgent.find(chat_id)
chat.complete
```

Each loop method reads the saved transcript to choose its next action. Tool calls with saved results are skipped, and only one process runs the chat at a time; see [One Process at a Time](#one-process-at-a-time). If a process stops before saving a result, that work may run again; see [At-Least-Once, Not Exactly-Once](#at-least-once-not-exactly-once).

This guide assumes `SupportAgent` uses a chat model with [Rails persistence]({% link _advanced/rails-persistence.md %}).

## One Turn per Job

Each [`step`]({% link _advanced/agentic-workflows.md %}#driving-the-loop-yourself) is one move, so a job can make one move and hand the loop back to the queue. Load the chat through its agent class. A bare `Chat.find` has the transcript but no tools, so it can neither run them nor see that a call needs approval.

```ruby
class AgentTurnJob < ApplicationJob
  def perform(chat_id)
    chat = SupportAgent.find(chat_id)
    chat.step
    AgentTurnJob.perform_later(chat_id) unless chat.complete? || chat.waiting?
  end
end
```

Each job makes one move and enqueues the next unless the conversation is complete or `waiting?`: paused until something outside it happens, such as an approval, an answer to an MCP input request, or an MCP task. Any worker can load the saved transcript.

## Surviving Deploys with ActiveJob Continuations

On Rails 8.1 and later, [ActiveJob Continuations](https://api.rubyonrails.org/classes/ActiveJob/Continuable.html) runs the whole loop in one job that survives restarts. Checkpoint after each move; when the queue adapter interrupts the job during a deploy, the job is requeued and the loop continues from the persisted messages:

```ruby
class AgentRunJob < ApplicationJob
  include ActiveJob::Continuable

  def perform(chat_id)
    step :agent_loop do |job_step|
      chat = SupportAgent.find(chat_id)
      until chat.complete? || chat.waiting?
        chat.step
        job_step.checkpoint!
      end
    end
  end
end
```

ActiveJob's `step` and the chat's `step` are unrelated methods. The job step wraps the whole loop, and each checkpoint marks a point where the job may be interrupted. The step does not need a cursor, because the persisted messages already record how far the loop has progressed.

## Parking for a Human Decision

A tool declared with [`requires_approval`]({% link _tools/tool-execution.md %}#requiring-approval) pauses the loop until someone decides. The pending call is saved in the database, and `complete` returns so the job can finish.

```ruby
class CompleteJob < ApplicationJob
  def perform(chat_id)
    SupportAgent.find(chat_id).complete
  end
end

class ApprovalsController < ApplicationController
  def create
    chat = Chat.find(params[:chat_id])
    params[:approved] == "true" ? chat.approve(params[:tool_call_id]) : chat.deny(params[:tool_call_id])
    CompleteJob.perform_later(chat.id)
  end
end
```

The decision persists on the tool call. The next job reads it and continues the conversation. Use `chat.pending_approvals` to render the calls awaiting a decision, and authorize that decision through your application's permissions.

A double click on "Approve" enqueues two jobs. Only one of them runs the tool: the other finds the chat running, or the call answered, and returns. Approving again changes nothing, and denying a call that has started raises `RubyLLM::ToolCallRunningError`.

A [subagent]({% link _getting_started/agents.md %}#subagents-in-rails) whose agent has a `chat_class` parks the same way, in a chat of its own. The chat that called it waits on it, lists its pending calls in `pending_approvals`, and records decisions on them with `approve` and `deny`, so the controller above needs no change. The next job completes the calling chat, which carries the subagent on first. A decision that arrives while a job finishes the calling chat's run is picked up before that job lets go.

## One Process at a Time

Before `complete`, `step`, `generate`, `run_tools`, or `compact` call the model or run a tool, the chat claims itself in the database. The claim is a conditional update of two columns on your chats table, `claim_token` and `claimed_until`, so no transaction stays open while the model or a tool runs. Each tool call is claimed the same way before it runs. A second process that finds the chat claimed returns at once: `complete` returns the latest message, `step` and `generate` return `nil`, and `waiting?` is `true`.

`chat.running?` reads the claim from the database, and a tool call record's `running?`, from `message.ruby_llm_tool_calls`, tells you which call is running. Ask it rather than reading the columns. A run clears both columns when it ends, but a process that dies leaves them until another process takes the chat over, so `claim_token` alone doesn't mean a run is alive:

```ruby
chat.running?      # => true while any process runs the chat
tool_call.running? # => true while a process runs this call
```

The process that holds the claim finishes the work recorded while it ran. An approval that arrives as it finishes, or a question asked while it streams an answer, is picked up before it lets go, so the job the approval enqueued can return without losing anything.

A claim is a one-minute lease. While a run is alive, a background thread renews the leases on the chat and on the tool calls it runs every 15 seconds, whether the model streams, stays silent, or a tool works for minutes. Each renewal checks out a database connection and returns it, so leave room in your connection pool for one more connection per running chat. A process that dies stops renewing, and its claims expire within a minute, on any number of servers, without a step at boot. Each server compares leases against its own clock, so keep your servers' clocks synchronized.

`config.max_run_time`, ten minutes by default, limits how long a run may go without progress. A run makes progress as it streams, between steps, and as each message is saved. A tool call may run for its own `max_run_time`, and the chat's claim stretches to cover it. Past that, the run stops renewing and counts as crashed:

```ruby
RubyLLM.configure do |config|
  config.max_run_time = 15.minutes
end

class GenerateReport < RubyLLM::Tool
  max_run_time 2.hours
end
```

Set `config.max_run_time` above your slowest model request without streaming. When a run counts as crashed, another process can take the chat over, and the late run's results are discarded.

Claims rely on the database to make them visible to other processes, so call these methods outside your own transactions. Inside a transaction, the claim stays invisible until it commits, the transaction stays open while the model and tools run, and the claims can't be renewed from another connection, so they last `max_run_time` instead of a minute.

## When a Run Is Interrupted

| | Stopped with `cancel` | Process dies | Request fails | Tool raises |
|---|---|---|---|---|
| The job | Raises `RubyLLM::CancelledError` at the next event, or when the running tool returns | Is gone | Raises the error | Raises the error |
| The reply so far | Kept as a reply that is `cancelled?`, if any text streamed | Lost: a blank placeholder stays, and requests leave it out | Removed if blank | Not affected |
| Tool calls | A finished one keeps its result. The rest close as unfinished | A finished one keeps its result. The rest run again once the claims expire | Not affected | The incomplete round can be removed, with its finished results, so the model is asked again |
| What continues | Nothing after a stop in a tool round or a kept reply, until a new message. A stop before any text left the question unanswered, so a later `complete` asks it again | The next `complete` once the chat and tool claims expire | The next `complete` or message | The next `complete` or message |
| The person | Sees the partial reply, and the page stops streaming | Sees "Thinking…" until a job runs again | Sees what your job shows them | Sees what your job shows them |
| Provider usage | An interrupted request is recorded as `:cancelled` with the tokens seen. One that already finished stays `:succeeded` | Lost for that attempt | Recorded as `:failed` | The request that finished stays `:succeeded` |

The generated chat UI handles each of these: its job discards the cancel and tries again every minute while a dead process still holds the chat, and `complete` saves a failure in the chat's `reply_error` column for the page before it raises. With a queue that loses jobs on a crash, such as development's `:async`, a run only resumes when the next message arrives.

## Resuming a Crashed Run

A process that dies keeps its claims for up to a minute, until their leases expire. Until then, `complete` in another process returns without doing anything and `chat.running?` stays `true`. Check it after `complete` and try again later, so the conversation resumes once the claim expires:

```ruby
class CompleteJob < ApplicationJob
  def perform(chat_id)
    chat = SupportAgent.find(chat_id)
    chat.complete
    retry_job wait: 1.minute if chat.running?
  end
end
```

When the other process is alive, it finishes the work and the retry finds nothing to do. Don't clear the claim columns at boot to resume sooner: a process on another server that is still running would then share the chat, and both would run its tools.

A process that dies mid-request removes nothing. Its assistant placeholder stays blank, and a tool call it was running keeps no result. RubyLLM leaves blank assistant messages out of every request, so the chat still works. Once the claims expire, the next `complete` runs the unfinished calls of the latest round again. A call in a round the conversation has moved past reaches the model with an error saying it didn't finish. Your records stay as they are.

## Stopping from Anywhere

`chat.cancel` on a persisted chat writes the request to the database, so a stop button in the web process halts a background job mid-stream at its next checkpoint, along with any subagent the job is running for the chat. A stop pressed after a message is saved or queued, before its job claims the chat, stops that reply too. A stop with nothing to stop does nothing, and a message sent after a stop goes on. See [Cancelling a Background Stream]({% link _advanced/rails-streaming.md %}#cancelling-a-background-stream).

## At-Least-Once, Not Exactly-Once

Claims keep two healthy processes from running the same tool call or asking the model the same question. Interruption still never gives you exactly-once execution. A job that dies after the model responds but before the message is saved repeats that model call once its claim expires, and a job that dies after a tool runs but before its result is saved runs that tool again. Write tools so that running them twice is safe: `find_or_create_by!` over `create!`, and idempotency keys on external calls. The same rule applies to [approval resolvers]({% link _tools/tool-execution.md %}#requiring-approval), which may be consulted again on resume.

[Batches]({% link _advanced/batches.md %}) are the same durability at scale: a batch is `generate` deferred for many chats at once, with `run_tools` run locally between rounds, and batch state persisted so any process can collect the results.

## Next Steps

* [Agentic Workflows]({% link _advanced/agentic-workflows.md %}) - The loop verbs these jobs drive, and multi-agent patterns.
* [Controlling Tool Execution]({% link _tools/tool-execution.md %}) - Approval, tool choice, and concurrency.
* [Persistence with acts_as]({% link _advanced/rails-persistence.md %}) - The transcript persistence durability builds on.
* [Batches]({% link _advanced/batches.md %}) - Deferred provider-side generation for many chats, with provider-specific pricing.
