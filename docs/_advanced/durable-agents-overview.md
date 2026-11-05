---
layout: default
title: Durable Agents
nav_order: 4
description: Keep an agent working across jobs, deploys, and human decisions, and find the guide for each piece.
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* When an agent needs to be durable, and when a plain chat is enough.
* How a durable agent waits for something outside it.
* Which guide covers each piece: jobs, run claims, approvals, input requests, tasks, queued messages, files, and code execution.

## When You Need Durable Agents

Most agents answer inside one request. Call `ask`, show the answer, and you are done. A [Chat]({% link _getting_started/chat.md %}) or an [Agent]({% link _getting_started/agents.md %}) is all you need.

An agent becomes durable when a turn outlives the process that started it:

* It runs longer than a web request, so a background job runs it.
* It waits for a person to approve a tool call or answer a question, which can take hours.
* A tool hands work to something slower, such as a deploy or another agent.
* People send more messages while it is still working.
* It keeps files or runs code across many turns.
* It must carry on after a deploy or a crash.

Durable agents use [Rails persistence]({% link _advanced/rails-persistence.md %}). The saved transcript records what has happened, so any process can load the chat through its agent class and continue:

```ruby
class CompleteJob < ApplicationJob
  def perform(chat_id)
    chat = SupportAgent.find(chat_id)
    chat.complete
    CompleteJob.set(wait: 1.minute).perform_later(chat_id) if chat.running?
  end
end
```

When another process still holds the chat, `complete` returns without doing anything, so the job tries again later. See [Resuming a Crashed Run]({% link _advanced/durable-agents.md %}#resuming-a-crashed-run).

## Waiting for Something Outside

A durable agent never blocks a process while it waits. When a tool call needs a decision, an answer, or work that runs elsewhere, the call pauses, `complete` returns, and the chat is `waiting?`:

```ruby
chat = SupportAgent.find(chat_id)
chat.complete

chat.waiting?           # => true
chat.awaiting_approval? # a tool call needs approval
chat.awaiting_input?    # a tool or MCP server asked a question
chat.awaiting_tasks?    # a tool call runs as a task
chat.awaiting_person?   # any of them needs a person to act
```

`awaiting_person?` is the one to check before you notify someone: it is true for approvals, questions, and tasks that report `input_required?`, and false while the chat only waits on work that runs elsewhere. Record the approval or the answer from your controller, then enqueue the job again. The next `complete` picks up where the last one stopped.

## The Pieces

Each piece has its own guide. Read the ones your agent needs.

| Piece | What it does | Guide |
| --- | --- | --- |
| Background jobs | Run one turn per job, survive deploys with ActiveJob Continuations, and stop a run from anywhere. | [Agents in Background Jobs]({% link _advanced/durable-agents.md %}) |
| Run claims | Let only one process run a chat or a tool call at a time, and resume a run after a crash. | [One Process at a Time]({% link _advanced/durable-agents.md %}#one-process-at-a-time), [Long-Running Tools]({% link _tools/tool-execution.md %}#long-running-tools) |
| Approvals | Pause a tool call until a person approves or denies it. | [Requiring Approval]({% link _tools/tool-execution.md %}#requiring-approval), [Approval in Rails]({% link _tools/tool-execution.md %}#approval-in-rails) |
| Input requests | Let a tool or an MCP server ask the user a question in the middle of a call. | [Asking the User]({% link _tools/tool-execution.md %}#asking-the-user), [MCP Input Requests]({% link _tools/mcp.md %}#input-requests) |
| Tasks | Pause a tool call while slow work runs elsewhere, then resume it. | [Pausing a Tool Call]({% link _tools/tool-execution.md %}#pausing-a-tool-call), [MCP Tasks]({% link _tools/mcp.md %}#tasks) |
| Queued messages | Accept new messages while a job runs the chat, and decide when they join. | [Queueing Messages]({% link _advanced/agentic-workflows.md %}#queueing-messages), [Queued Messages in Rails]({% link _advanced/rails-persistence.md %}#queued-messages) |
| File stores | Keep attachments and long tool results as files the model reads when it needs them. | [File Stores]({% link _core_features/file-stores.md %}) |
| Sandboxes | Decide what code from a model can read, write, and reach. | [Sandboxes]({% link _advanced/sandboxes.md %}) |
| Code execution | Let the model run code in a sandbox and hand back the files it makes. | [Code Execution]({% link _advanced/code-execution.md %}) |

## Running Twice Is Possible

A durable agent runs each tool call at least once, not exactly once. A job that dies after a tool runs, but before its result is saved, runs that tool again. Write tools so that running them twice is safe. See [At-Least-Once, Not Exactly-Once]({% link _advanced/durable-agents.md %}#at-least-once-not-exactly-once).

## Next Steps

* [Agents in Background Jobs]({% link _advanced/durable-agents.md %}) - Start here to run your agent in jobs.
* [Agentic Workflows]({% link _advanced/agentic-workflows.md %}) - The loop methods a job drives.
* [Streaming with Hotwire/Turbo]({% link _advanced/rails-streaming.md %}) - Show a background run as it happens.
