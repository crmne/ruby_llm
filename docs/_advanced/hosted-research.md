---
layout: default
title: Hosted Research
nav_order: 8
description: Run a hosted research agent with remote tools and collect its report through a durable job ID
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* How to submit research to a hosted agent.
* How to connect a remote MCP server.
* How to retrieve a report, citations, and usage.
* How to poll, cancel, or recover an existing task.

## Run a Research Task

```ruby
report = RubyLLM.research(
  "Find the official documentation for deploying an Azure Function.",
  provider: :vertexai,
  agent: "{{ site.hosted_agents.vertexai_research }}",
  server_tools: {
    mcp: { name: "microsoft_learn", url: "https://learn.microsoft.com/api/mcp" }
  }
)

puts report.content
report.citations
```

`research` submits one task, waits, and returns a `RubyLLM::Message`. `agent:` identifies a hosted agent, separate from a model ID or local `RubyLLM::Agent` class.

Vertex AI's Deep Research agent currently supports this API. Configure your [Vertex AI credentials]({% link _getting_started/configuration.md %}) and select the global location:

```ruby
RubyLLM.configure do |config|
  config.vertexai_project_id = ENV.fetch("GOOGLE_CLOUD_PROJECT")
  config.vertexai_location = "global"
end
```

You can include images or PDFs with `with:`. Each research task takes one prompt; it does not continue a previous conversation.

## Work with a Background Task

Use `research_later` to get the job ID immediately:

```ruby
job = RubyLLM.research_later(
  "Find the official Ruby documentation and explain where its API reference lives.",
  provider: :vertexai,
  agent: "{{ site.hosted_agents.vertexai_research }}"
)

job.id
job.status # => :pending
```

Save `job.id` in your application. A later Rails job or Ruby process can retrieve it without submitting the task again:

```ruby
job = RubyLLM::ResearchJob.find(saved_job_id, provider: :vertexai)
job.refresh

puts job.message.content if job.completed?
```

`job.wait(timeout: 300, interval: 5)` polls for up to five minutes. Both values are in seconds. A wait timeout raises `RubyLLM::ResearchJob::TimeoutError` and leaves the independent task running. The exception retains it as `error.job`.

In Rails, call these methods from a service or Active Job and store the remote ID on an application record. RubyLLM does not create a persisted chat or manage a research-task table for you.

## Read the Report

Read the report using the same result objects as chat:

```ruby
job.wait
report = job.message

report.content
report.citations
report.thinking
report.server_tool_calls
job.tokens
job.cost.total
```

`job.raw` preserves the original task response. A complete report has `finish_reason: :stop`. A task that reaches its output budget can return `job.incomplete?` with a partial message and `finish_reason: :max_tokens`. Failed and cancelled tasks raise when you read `message`; their status and error remain available on the job.

`job.tokens` reports task usage. Cost remains unknown when the service supplies no price; `report.model` is `nil` for a hosted agent task.

Reports can omit intermediate tool calls, thinking summaries, and citation URLs. Check for those fields before displaying them.

## Configure Remote Tools

Without `server_tools:`, the agent uses its default search and URL tools. Pass a tool list to select `:mcp` or `:web_search` explicitly.

The provider's `allowed_tools` filter uses structured entries:

```ruby
tools = {
  mcp: {
    name: "microsoft_learn",
    url: "https://learn.microsoft.com/api/mcp",
    allowed_tools: [{ tools: ["microsoft_docs_search"], mode: "auto" }]
  }
}
```

Pass this Hash as `server_tools: tools`. Allowed remote tools run without approval pauses; approval options raise an error. Use [chat tools]({% link _core_features/server-tools.md %}) for interactive approvals or local Ruby tools.

## Cancel and Recover

```ruby
job.cancel
job.cancelled?
```

Only the provider's response confirms cancellation. Cancelling execution does not delete the provider's stored task data.

The blocking `RubyLLM.research` helper attempts a bounded cancellation if waiting times out, is interrupted, or fails before returning a handle. `RubyLLM::ResearchJob::Error` and `RubyLLM::ResearchJob::InterruptedError` retain the job. If cancellation cannot be confirmed, `error.job.cancellation_error` records that failure; use the saved ID to retrieve the task again.

Vertex AI retains research task data according to its service policy. See the [Deep Research documentation](https://docs.cloud.google.com/gemini-enterprise-agent-platform/agents/use-deep-research) for current retention, access requirements, and provider-specific agent options.
