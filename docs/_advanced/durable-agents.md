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
* How a tool call that asks a person parks the loop across processes.
* Why only one process runs a chat at a time, and how a crashed run resumes.
* How to run a durable queue in development.
* How to stop a running agent from anywhere.
* What a crash repeats, what it doesn't, and what that asks of your tools.

## The Transcript Is the State

A persisted conversation records which model responses and tool results have completed. Load it through the agent class in another process and continue:

```ruby
chat = SupportAgent.find(chat_id)
chat.complete
```

Each loop method reads the saved transcript to choose its next action. Tool calls with saved results are skipped, and only one process runs the chat at a time; see [One Process at a Time](#one-process-at-a-time). If a process stops before saving a result, a model call may run again, but a tool call that had started doesn't; see [What a Crash Repeats](#what-a-crash-repeats).

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

Each job makes one move and enqueues the next unless the conversation is complete or `waiting?`: paused until something outside it happens, such as an answer from a person, an approval included, or a task. Any worker can load the saved transcript.

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

A tool call that [asks a person]({% link _tools/tool-execution.md %}#asking-a-person) pauses the loop until they answer, whether it is the approval of a tool declared with `requires_approval` or a question the tool asks with `ask`. The question is saved in the database, and `complete` returns so the job can finish.

```ruby
class CompleteJob < ApplicationJob
  def perform(chat_id)
    SupportAgent.find(chat_id).complete
  end
end

class AnswersController < ApplicationController
  def create
    chat = Chat.find(params[:chat_id])
    params[:decline] ? chat.decline(params[:question_id]) : chat.answer(params[:question_id], params[:answer])
    CompleteJob.perform_later(chat.id)
  end
end
```

The answer persists on the tool call. The next job reads it and carries the call on: an approved tool runs, and a tool that asked runs again with the answer. Use `chat.pending_questions` to render what waits for an answer, and authorize the answer through your application's permissions.

A double click on "Approve" enqueues two jobs. Only one of them runs the tool: the other finds the chat running, or the call answered, and returns. Answering again changes nothing, and declining an approval that is still pending while its call already runs raises `RubyLLM::ToolCallRunningError`.

## One Process at a Time

Before `complete`, `step`, `generate`, `run_tools`, or `compact` call the model or run a tool, the chat claims itself in the database. The claim is a conditional update of two columns on your chats table, `claim_token` and `claimed_until`, so no transaction stays open while the model or a tool runs. Each tool call is claimed the same way before it runs. A second process that finds the chat claimed returns at once: `complete` returns the latest message, `step` and `generate` return `nil`, and `waiting?` is `true`.

`chat.running?` reads the claim from the database, and a tool call record's `running?`, from `message.ruby_llm_tool_calls`, tells you which call is running. Ask it rather than reading the columns. A run clears both columns when it ends, but a process that dies leaves them until another process takes the chat over, so `claim_token` alone doesn't mean a run is alive:

```ruby
chat.running?      # => true while any process runs the chat
tool_call.running? # => true while a process runs this call
```

The process that holds the claim finishes the work recorded while it ran. An answer that arrives as it finishes, or a message queued while it streams a reply, is picked up before it lets go, so the job the answer enqueued can return without losing anything.

A claim is a one-minute lease. While a run is alive, a background thread renews the leases on the chat and on the tool calls it runs every 15 seconds, whether the model streams, stays silent, or a tool works for minutes. Each renewal checks out a database connection and returns it, so leave room in your connection pool for one more connection per running chat. A process that dies stops renewing, and its claims expire within a minute, on any number of servers, without a step at boot. Each server compares leases against its own clock, so keep your servers' clocks synchronized. A renewal that fails, for example because the database is locked, is skipped, and the next one tries again. A claim outlasts a skipped renewal, and RubyLLM logs a warning when two in a row fail, since the claim may then lapse before the next one. On SQLite before Rails 8, a thread waiting for a lock holds Ruby's global lock and would stop the whole process, including the run that holds the database lock. There a renewal waits with Ruby's lock released, for at most a quarter of the interval, then reconnects, so your own queries keep the database's `timeout` as you configured it.

`config.max_run_time`, ten minutes by default, limits how long a run may go without progress. A run makes progress as it streams, between steps, and as each message is saved. Past that, the run stops renewing and counts as crashed:

```ruby
RubyLLM.configure do |config|
  config.max_run_time = 15.minutes
end
```

Set `config.max_run_time` above your slowest model request without streaming and your slowest tool call. A tool whose work takes longer can [pause its call]({% link _tools/tool-execution.md %}#pausing-a-tool-call) instead. When a run counts as crashed, another process can take the chat over, and the late run's results are discarded.

Claims rely on the database to make them visible to other processes, so call these methods outside your own transactions. Inside a transaction, the claim stays invisible until it commits, the transaction stays open while the model and tools run, and the claims can't be renewed from another connection, so they last `config.max_run_time` instead of a minute.

## When a Run Is Interrupted

| | Stopped with `cancel` | Process dies | Request fails | Tool raises |
|---|---|---|---|---|
| The job | Raises `RubyLLM::CancelledError` at the next event, or when the running tool returns | Is gone | Raises the error | Raises the error |
| The reply so far | Kept as a reply that is `cancelled?`, if any text streamed | Not saved: the text streamed so far was only on the page. A blank placeholder stays, and requests leave it out | Removed if blank | Not affected |
| Tool calls | A finished one keeps its result. The rest close as unfinished | A finished one keeps its result. Once the claims expire, the rest are answered as interrupted, and the model decides what to do | Not affected | The incomplete round can be removed, with its finished results, so the model is asked again |
| What continues | Nothing after a stop in a tool round or a kept reply, until a new message. A stop before any text left the question unanswered, so a later `complete` asks it again | The next `complete` once the chat and tool claims expire | The next `complete` or message | The next `complete` or message |
| The person | Sees the partial reply, and the page stops streaming | Sees "Thinking…" until a job runs again, then a new reply | Sees what your job shows them | Sees what your job shows them |
| Provider usage | An interrupted request is recorded as `:cancelled` with the tokens seen. One that already finished stays `:succeeded` | Lost for that attempt | Recorded as `:failed` | The request that finished stays `:succeeded` |

A tool call that had started when its process stopped never runs again: the model gets an error saying the call did not finish and may have partly run, and decides whether to check or try again. A deploy or restart (TERM) releases the calls of the round that hadn't started yet, and those run on resume. A hard kill can't tell which calls had started, so every unfinished call of its round is answered that way. See [What a Crash Repeats](#what-a-crash-repeats).

A hard kill (a SIGKILL, or running out of memory) drops the text the reply had streamed: RubyLLM saves a reply when it finishes or is cancelled, so until then that text exists only on the page. The exception is a Gemini [long response]({% link _advanced/rails-persistence.md %}#resuming-long-responses), which keeps what it saved at its last pause and continues from there. The resumed run asks the model again and regenerates the reply, which reaches the page through the same broadcasts as any other reply. A page that shows the generated broadcasts needs no extra code for this, and saving chunks yourself would not help, since the model writes the whole reply again. The killed run's blank placeholder stays in the transcript, and the generated page shows it as "The model returned no reply." above the new reply.

The generated chat UI handles each of these: its job discards the cancel and tries again every minute while a dead process still holds the chat, `complete` saves a failure in the chat's `reply_error` column for the page before it raises, and `ResumeInterruptedChatsJob` answers a reply whose process died, every minute and at boot. See [Resuming a Crashed Run](#resuming-a-crashed-run).

## Resuming a Crashed Run

No job backend runs a reply that a crash or a deploy killed again by itself. Development's `:async` queue keeps its jobs in the server's memory, so they die with it. Solid Queue doesn't run a dead worker's jobs again either: once the worker has missed its heartbeats for five minutes, Solid Queue marks the jobs it held as failed. The transcript, the finished tool results, and the claims are all in the database, but nothing starts the turn again.

The chat UI generator writes a job that does:

```ruby
class ResumeInterruptedChatsJob < ApplicationJob
  def perform(boot: false)
    Chat.interrupted.find_each { |chat| ChatResponseJob.perform_later(chat.id) }
    expiry = Chat.where(claimed_until: Time.current..).maximum(:claimed_until) if boot
    self.class.set(wait_until: expiry + 1.second).perform_later if expiry
  end
end
```

It runs every minute from Solid Queue's `config/recurring.yml`, and as soon as the web server boots:

```ruby
# config/initializers/resume_interrupted_chats.rb
Rails.application.server { ResumeInterruptedChatsJob.perform_later(boot: true) }
```

A deploy or a restart stops its processes with a TERM, and a run stopped that way expires its claims as it exits, so the boot run answers its chat right away. A process killed outright, with a SIGKILL or by running out of memory, leaves claims that expire within a minute, so the boot run comes back once, a second after every claim held at boot has expired, and answers those chats about a minute after the kill. Only the boot run comes back, so the jobs can't pile up while chats are busy, and the run every minute catches anything else.

`Rails.application.server` runs when a web server loads `config.ru`, never in the console, a rake task, or a job worker. Don't write a polling worker or a boot sweep of your own: the generated job is both, and the claims let only one process answer each chat, however many servers boot at once.

`Chat.interrupted` returns the chats whose run died holding its claim, because a crash or a deploy stopped its process, once that claim has expired; a run that finishes, pauses, is cancelled, or fails releases its claim, so its chat never counts. A run stopped by a TERM, an exit, or a thread killed as its process exits keeps its claim but expires it, so its chat counts at once; Ctrl-C releases it, as a stop. A tool call that was running when its process shut down keeps its claim expired too, the only record that it started. A live run whose tool works past `config.max_run_time` also shows up as interrupted, since its claims stop renewing then, so give a long tool a longer `config.max_run_time`, or have it [pause its call]({% link _tools/tool-execution.md %}#pausing-a-tool-call).

It's a scope, so it chains with your own and loads in batches:

```ruby
Chat.where(account: account).interrupted.find_each { |chat| CompleteJob.perform_later(chat.id) }
```

A job that finds another process holding the chat returns without doing anything, and `chat.running?` stays `true` until that process's claims expire: right away after a shutdown, up to a minute after a crash. Check it after `complete` and try again later, so a message that arrives in that minute still gets its answer:

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

A process that dies mid-request removes nothing. Its assistant placeholder stays blank, and a tool call it was running keeps no result. RubyLLM leaves blank assistant messages out of every request, so the chat still works. Once the claims expire, the next `complete` answers each call that had started with an error saying it did not finish, never running it again, and the model decides what to do, as [When a Run Is Interrupted](#when-a-run-is-interrupted) describes. Two kinds of call are the exception: one whose tool [asked]({% link _tools/tool-execution.md %}#asking-from-a-tool) a question the person answered can run again with that answer, and a paused task's `resume` can run again. Your records stay as they are.

### A Durable Queue in Development

With development's `:async` queue, stopping `bin/rails server` mid-reply loses the job, and the boot job answers the chat as soon as the server starts again. To run jobs as production does, run Solid Queue inside Puma. Its worker is a separate process, and the `async` cable adapter only reaches browsers connected to the process that broadcasts, so use Solid Cable as well. Add the queue and cable databases to development in `config/database.yml`, as production has them:

```yaml
development:
  primary:
    <<: *default
    database: storage/development.sqlite3
  queue:
    <<: *default
    database: storage/development_queue.sqlite3
    migrations_paths: db/queue_migrate
  cable:
    <<: *default
    database: storage/development_cable.sqlite3
    migrations_paths: db/cable_migrate
```

Point Active Job and Action Cable at them:

```ruby
# config/environments/development.rb
config.active_job.queue_adapter = :solid_queue
config.solid_queue.connects_to = { database: { writing: :queue } }
```

```yaml
# config/cable.yml
development:
  adapter: solid_cable
  connects_to:
    database:
      writing: cable
  polling_interval: 0.1.seconds
  message_retention: 1.day
```

Solid Queue reads all of `config/recurring.yml` in an environment without a key of its own, so give it a `development:` key with the resume job:

```yaml
development:
  resume_interrupted_chats:
    class: ResumeInterruptedChatsJob
    schedule: every minute
```

Then run `bin/rails db:prepare` and start the server with `SOLID_QUEUE_IN_PUMA=1 bin/rails server`.

## Stopping from Anywhere

`chat.cancel` on a persisted chat writes the request to the database, so a stop button in the web process halts a background job mid-stream at its next checkpoint. A stop pressed after a message is saved or queued, before its job claims the chat, stops that reply too. A stop with nothing to stop does nothing, and a message sent after a stop goes on. See [Cancelling a Background Stream]({% link _advanced/rails-streaming.md %}#cancelling-a-background-stream).

## What a Crash Repeats

Claims keep two healthy processes from running the same tool call or asking the model the same question. A crash doesn't run a tool call twice either. A call that had started when its process stopped, whether by a deploy, a crash, or a run that went past `config.max_run_time`, is answered with an error saying it did not finish and may have partly run. The model reads it and decides what to do, such as checking before trying again. Its work may be half done, so give the model a way to check it, such as a tool that looks up a payment, and make the work safe to repeat where you can: `find_or_create_by!` over `create!`, and idempotency keys on external calls.

Model calls are at least once: a job that dies after the model responds but before the message is saved asks the model again once its claim expires. Some tool code runs again by design, too: [approval resolvers]({% link _tools/tool-execution.md %}#requiring-approval) may be consulted again on resume, and code in a tool before it [asks]({% link _tools/tool-execution.md %}#asking-from-a-tool) runs again once the person answers. If its process stops before the result is saved, a call whose tool asked can run again from the top with the answer, and a paused task's `resume` can run again, so code after the answer and in `resume` can repeat too.

[Batches]({% link _advanced/batches.md %}) are the same durability at scale: a batch is `generate` deferred for many chats at once, with `run_tools` run locally between rounds, and batch state persisted so any process can collect the results.

## Next Steps

* [Agentic Workflows]({% link _advanced/agentic-workflows.md %}) - The loop verbs these jobs drive, and multi-agent patterns.
* [Controlling Tool Execution]({% link _tools/tool-execution.md %}) - Approvals and questions, tool choice, and concurrency.
* [Persistence with acts_as]({% link _advanced/rails-persistence.md %}) - The transcript persistence durability builds on.
* [Batches]({% link _advanced/batches.md %}) - Deferred provider-side generation for many chats, with provider-specific pricing.
