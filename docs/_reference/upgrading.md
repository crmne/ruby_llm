---
layout: default
title: Upgrading
nav_order: 4
description: Move a RubyLLM 2.1 application to 2.2, one release at a time.
redirect_from:
  - /upgrading-to-1-7
  - /upgrading-to-1-7/
---

# Upgrade to 2.2

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* How RubyLLM upgrades move from one release to the next.
* How to upgrade a 2.1 application and its Rails schema to 2.2.
* How persisted chats now run in one process at a time.
* What changes for a crashed job, a denial, and a deploy that mixes versions.

This guide covers **2.1 to 2.2**. Coming from 2.0? Follow the [2.1 upgrade guide](https://github.com/crmne/ruby_llm/blob/v2.1.1/docs/_reference/upgrading.md) with RubyLLM 2.1 first.

## One Release at a Time

Each release ships the upgrade steps for the changes since the previous release. When a release changes the Rails schema, `bin/rails generate ruby_llm:upgrade` generates the migrations that take your database from the previous release to the current one. The next release replaces that generator with its own.

To move across several releases, upgrade to each one in turn. Deploy it, run its upgrade, and resolve its deprecation warnings before you continue. Each release's upgrade guide stays in the repository at that release's tag.

## Finish the 2.1 Upgrade

2.2 does not include the 2.1 upgrade generator. Run it while your application still runs 2.1, in every environment, and keep the migration it generated in `db/migrate`.

## Update the Gem

Require 2.2 in your `Gemfile`, so the update stops at this release:

```ruby
gem "ruby_llm", "~> 2.2.0"
```

Then update it in your development branch:

```bash
bundle update ruby_llm
```

Plain Ruby applications need no changes. Rails applications upgrade their schema and read the changes to persisted chats below.

## Upgrade the Rails Schema

Rails applications generate and run the 2.2 upgrade:

```bash
bin/rails generate ruby_llm:upgrade
bin/rails db:migrate
```

If your chat model is not `Chat`, name it the way you did for the install generator, for example `bin/rails generate ruby_llm:upgrade chat:Conversation`.

It adds `claim_token` and `claimed_until` columns to your chats table and a `claimed_until` column to `ruby_llm_tool_calls`. They record which process runs a chat and its tool calls. The migration changes no existing data. The generator also creates any of RubyLLM's conventional directories your application lacks, such as `app/skills` and `app/sandboxes`, and an `app/agents/application_agent.rb` that points at your chat model, unless you already have one. New agents from `ruby_llm:agent` inherit from it.

The generator also removes the broadcasting code and the `has_many_attached :attachments` line that `ruby_llm:chat_ui` wrote into your message model, because `acts_as_message` now provides both, and installs Active Storage if your application lacks it. Broadcasting code you wrote yourself stays, and the generator tells you to remove it or set `broadcasts: false`. Rerunning `ruby_llm:chat_ui` cleans the model the same way.

Until it runs, RubyLLM claims nothing, and overlapping runs behave as they did in 2.1.

## Messages Broadcast With Turbo

> If your application broadcasts its messages with Turbo itself, for example with `broadcasts_to` or its own chunk broadcasting in a job, set `acts_as_message broadcasts: false` before you deploy 2.2, or every message is sent twice.
{: .warning }

```ruby
class Message < ApplicationRecord
  acts_as_message broadcasts: false
end
```

When turbo-rails and Action Cable are loaded, `acts_as_message` now broadcasts a chat's messages to the chat record's stream, `turbo_stream_from @chat`. It appends an empty assistant reply when it is created, replaces a message when it is saved, removes it when it is destroyed, and refreshes the chat's page after every change and at the end of each run. Streamed chunks know their record, so a job streams with `chat.complete(&:broadcast)`. See [Streaming with Hotwire/Turbo]({% link _advanced/rails-streaming.md %}).

Broadcasting renders each message with its partial, chosen by `to_partial_path`, so an application that broadcasts needs `messages/_user`, `messages/_assistant`, `messages/_tool`, and `messages/_tool_calls`, or `broadcasts: false`.

## Messages Declare Their Attachments

`acts_as_message` now declares `has_many_attached :attachments`, so Active Storage is required. Remove `has_many_attached :attachments` from your message model. An application without Active Storage runs `bin/rails active_storage:install` and `bin/rails db:migrate`.

## The Default Model Is GPT-6.1 Sol

`RubyLLM.chat` without a model, and a persisted chat created without one, now use `gpt-6.1-sol` instead of `gpt-5.6`. To keep the previous model, set it in your configuration:

```ruby
RubyLLM.configure do |config|
  config.default_model = "gpt-5.6"
end
```

## One Process Runs a Chat

In 2.1, two processes that completed the same persisted chat at the same time could both run an approved tool call and both ask the model for a reply, for example when a double-submitted approval enqueued two jobs. In 2.2, `complete`, `step`, `generate`, `run_tools`, and `compact` claim the chat before they call the model or run a tool, and each tool call is claimed before it runs. A process that finds the chat claimed returns without doing anything:

* `complete` returns the latest message, and `step`, `generate`, and `compact` return `nil`.
* `waiting?` is `true`, so loops that stop on `complete? || waiting?` stop.
* `chat.running?` and a tool call record's `running?` are `true`.

The process that holds the claim continues with approvals and questions recorded while it ran. See [One Process at a Time]({% link _advanced/durable-agents.md %}#one-process-at-a-time).

## Crashed Runs Resume After Their Claim Expires

In 2.1, `complete` ran the unfinished tool calls of a crashed job right away. In 2.2, a crashed job keeps its claims for `config.max_run_time`, ten minutes by default, and `complete` in another process returns until they expire. A job retried within that time finds the chat `running?` and does nothing. Check `running?` after `complete` and enqueue the job again later, as [Resuming a Crashed Run]({% link _advanced/durable-agents.md %}#resuming-a-crashed-run) shows.

Give tools that legitimately run longer than ten minutes their own limit with [`max_run_time`]({% link _core_features/tools.md %}#long-running-tools), and raise `config.max_run_time` above your slowest model request without streaming. A run that outlasts its claim counts as crashed and may run again.

## Rescue Denials of Running Calls

`deny` on a persisted tool call that has started running now raises `RubyLLM::ToolCallRunningError`; in 2.1 it recorded a denial the running tool never saw. `approve` on a running call and either decision on an answered call change nothing, where 2.1 overwrote the recorded decision. Rescue the error where you record denials:

```ruby
rescue_from RubyLLM::ToolCallRunningError do
  redirect_back fallback_location: root_path, alert: "That action is already running."
end
```

## Responses Keep No Request Headers

In 2.1, `message.raw` and `error.response` still carried the request headers, including the API key, and `error.response` also carried the request body, the whole serialized conversation. In 2.2 they keep neither, so logging or reporting them no longer leaks keys or prompts. To see what a chat sends, use `render` or a `before_request` hook, described in [Advanced Request Control]({% link _core_features/chat-request-control.md %}#request-hooks).

## Rename Chat Columns Named After New Methods

`acts_as_chat` records gain `code_execution`, `skills`, `with_code_execution`, and `with_skills` in 2.2. A column of your own with one of those names is hidden behind RubyLLM's method, so reading it returns RubyLLM's setting, usually `nil`, instead of your value. Rename such a column before you upgrade, for example a `code_execution` toggle to `runs_code`:

```ruby
rename_column :chats, :code_execution, :runs_code
```

## Deploy Without Mixing Versions

Workers on 2.1 do not claim chats, so they can still overlap with workers on 2.2 while a deploy rolls out. Run the schema upgrade first, then let the new version replace every worker before you rely on claims. Chats that run once all workers are on 2.2 are covered.

Run your tests and deploy.

## Older Upgrade Guides

Use the [2.1 upgrade guide](https://github.com/crmne/ruby_llm/blob/v2.1.1/docs/_reference/upgrading.md), the [2.0 upgrade guide](https://github.com/crmne/ruby_llm/blob/v2.0.0/docs/_reference/upgrading.md), or the [1.16 upgrade guide](https://rubyllm.com/v1/upgrading/) for older releases. See [GitHub releases](https://github.com/crmne/ruby_llm/releases) for the full changelog.
