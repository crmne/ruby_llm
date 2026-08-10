---
layout: default
title: Durable Agents
parent: "Agents"
nav_order: 3
description: Run agent turns as background jobs that survive crashes, deploys, and the wait for a human decision.
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

* Why a persisted chat is resumable by construction, with no run state to serialize.
* How to run each agent turn as its own background job.
* How to survive deploys with ActiveJob Continuations.
* How an approval-gated tool parks the loop across processes.
* How to stop a running agent from anywhere.
* Why execution is at-least-once, and what that asks of your tools.

## The Transcript Is the State

Frameworks that suspend an agent usually hand you a run state to keep: a serialized blob you must store, present back, and never lose. RubyLLM has no such object. Every loop verb decides its next move by reading the persisted messages, and `run_tools` skips tool calls that already have results. The database you already have is the checkpoint format.

That is the whole trick. A [chat persisted with `acts_as_chat`]({% link _advanced/rails-persistence.md %}) can be loaded in another process, on another machine, after a crash or a deploy, and `complete` picks up exactly where the transcript says the conversation is. If a process dies after running one tool call of three, the next `complete` executes only the two remaining.

## One Turn per Job

Because each [`step`]({% link _advanced/agentic-workflows.md %}#driving-the-loop-yourself) is a discrete move, you can run one move per job and let the queue carry the loop:

```ruby
class AgentTurnJob < ApplicationJob
  def perform(chat_id)
    chat = Chat.find(chat_id)
    chat.step
    AgentTurnJob.perform_later(chat_id) unless chat.complete?
  end
end
```

Every job picks up the persisted transcript, makes one move, and re-enqueues. Nothing holds a connection across turns, a wall-clock budget is one counter away, and any worker can take the next move.

## Surviving Deploys with ActiveJob Continuations

On Rails 8.1 and later, [ActiveJob Continuations](https://api.rubyonrails.org/classes/ActiveJob/Continuable.html) runs the whole loop in one job that survives restarts. Checkpoint after each move; when the queue adapter interrupts the job during a deploy, the job is requeued and the loop continues from the persisted messages:

```ruby
class AgentRunJob < ApplicationJob
  include ActiveJob::Continuable

  def perform(chat_id)
    step :agent_loop do |job_step|
      chat = Chat.find(chat_id)
      until chat.complete?
        chat.step
        job_step.checkpoint!
      end
    end
  end
end
```

ActiveJob's `step` and the chat's `step` are unrelated methods. The job step wraps the whole loop, and each checkpoint marks a point where the job may be interrupted. The step does not need a cursor, because the persisted messages already record how far the loop has progressed.

## Parking for a Human Decision

A tool declared with [`requires_approval`]({% link _core_features/tool-execution.md %}#requiring-approval) parks the loop until someone decides, and durability is what makes that practical: the pending tool call is a row, not a suspended process. `complete` returns cleanly, the job finishes, and nothing waits in memory.

```ruby
class CompleteJob < ApplicationJob
  def perform(chat_id)
    Chat.find(chat_id).complete
  end
end

class ApprovalsController < ApplicationController
  def create
    chat = Chat.find(params[:chat_id])
    params[:approved] ? chat.approve!(params[:tool_call_id]) : chat.deny!(params[:tool_call_id])
    CompleteJob.perform_later(chat.id)
  end
end
```

The decision persists on the tool call record, so the next `complete` reads it from any process. A worker restart while the approval is pending finds the same undecided call and stays parked: one approval card, not two, even if the wait is measured in days. `chat.pending_approvals` returns the records to render as cards.

## Stopping from Anywhere

`chat.cancel!` on a persisted chat writes the request to the database, so a stop button in the web process halts a background job mid-stream at its next checkpoint. See [Cancelling a Background Stream]({% link _advanced/rails-streaming.md %}#cancelling-a-background-stream).

## At-Least-Once, Not Exactly-Once

Interruption never gives you exactly-once execution. A job that dies after the model responds but before the message is saved repeats that model call when it resumes, and a job that dies after a tool runs but before its result is saved runs that tool again. Write tools so that running them twice is safe: `find_or_create_by!` over `create!`, and idempotency keys on external calls. The same rule applies to [approval resolvers]({% link _core_features/tool-execution.md %}#requiring-approval), which may be consulted again on resume.

[Batches]({% link _advanced/batches.md %}) are the same durability at scale: a batch is `generate` deferred for many chats at once, with `run_tools` run locally between rounds, and batch state persisted so any process can collect the results.

## Next Steps

* [Agentic Workflows]({% link _advanced/agentic-workflows.md %}) - The loop verbs these jobs drive, and multi-agent patterns.
* [Controlling Tool Execution]({% link _core_features/tool-execution.md %}) - Approval, tool choice, and concurrency.
* [Persistence with acts_as]({% link _advanced/rails-persistence.md %}) - The transcript persistence durability builds on.
* [Batches]({% link _advanced/batches.md %}) - Deferred generation for many chats at half price.
