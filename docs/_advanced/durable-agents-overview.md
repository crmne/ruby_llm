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
* Which guide covers each piece: jobs, run claims, approvals and questions, tasks, queued messages, files, and code execution.

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
chat.pending_questions  # approvals and questions a person must answer
chat.pending_tasks      # tool calls that run as tasks
```

A person must act while a question waits for an answer, an approval included, or a task reports `input_required?`. Check that before you notify someone, and leave a chat alone while it only waits on work that runs elsewhere:

```ruby
notify(chat.owner) if chat.pending_questions.any? || chat.pending_tasks.any?(&:input_required?)
```

Record the answer from your controller, then enqueue the job again. The next `complete` picks up where the last one stopped.

## The Pieces

Each piece has its own guide. Read the ones your agent needs.

| Piece | What it does | Guide |
| --- | --- | --- |
| Background jobs | Run one turn per job, survive deploys with ActiveJob Continuations, and stop a run from anywhere. | [Agents in Background Jobs]({% link _advanced/durable-agents.md %}) |
| Run claims | Let only one process run a chat or a tool call at a time, and resume a run after a crash. | [One Process at a Time]({% link _advanced/durable-agents.md %}#one-process-at-a-time), [Long-Running Tools]({% link _tools/tool-execution.md %}#long-running-tools) |
| Questions | Pause a tool call until a person answers: the approval before a tool runs, or a question a tool or an MCP server asks in the middle of a call. | [Asking a Person]({% link _tools/tool-execution.md %}#asking-a-person), [Questions in Rails]({% link _tools/tool-execution.md %}#questions-in-rails), [Questions from Servers]({% link _tools/mcp.md %}#questions-from-servers) |
| Tasks | Pause a tool call while slow work runs elsewhere, then resume it. | [Pausing a Tool Call]({% link _tools/tool-execution.md %}#pausing-a-tool-call), [MCP Tasks]({% link _tools/mcp.md %}#tasks) |
| Subagents | Hand work to another agent that keeps its own chat, so it can wait for a person. | [Subagents That Wait for a Person]({% link _getting_started/agents.md %}#subagents-that-wait-for-a-person) |
| Queued messages | Accept new messages while a job runs the chat, and decide when they join. | [Queueing Messages]({% link _advanced/agentic-workflows.md %}#queueing-messages), [Queued Messages in Rails]({% link _advanced/rails-persistence.md %}#queued-messages) |
| File stores | Keep attachments and long tool results as files the model reads when it needs them. | [File Stores]({% link _core_features/file-stores.md %}) |
| Sandboxes | Decide what code from a model can read, write, and reach. | [Sandboxes]({% link _advanced/sandboxes.md %}) |
| Code execution | Let the model run code in a sandbox and hand back the files it makes. | [Code Execution]({% link _advanced/code-execution.md %}) |

## Running Twice Is Possible

A durable agent doesn't run a tool call twice. When a job dies after a tool started, but before its result is saved, the model hears the call may have partly run and decides what to do, so give it a way to check. A model call can repeat. See [What a Crash Repeats]({% link _advanced/durable-agents.md %}#what-a-crash-repeats).

## Next Steps

* [Agents in Background Jobs]({% link _advanced/durable-agents.md %}) - Start here to run your agent in jobs.
* [Agentic Workflows]({% link _advanced/agentic-workflows.md %}) - The loop methods a job drives.
* [Streaming with Hotwire/Turbo]({% link _advanced/rails-streaming.md %}) - Show a background run as it happens.
