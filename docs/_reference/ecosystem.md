---
layout: default
title: RubyLLM Ecosystem
nav_order: 5
description: Extend RubyLLM with MCP servers, structured schemas, instrumentation, monitoring and community-built tools for production AI apps.
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* Which community projects add integrations, testing, observability, and storage.
* Which related features already ship with RubyLLM.
* Where to find each project's setup instructions and examples.

These projects are maintained by their authors. Follow each project's documentation for installation and compatibility with your RubyLLM version.

## Schematist

[Schematist](https://github.com/crmne/schematist) ships with RubyLLM. Use its Ruby DSL to describe structured responses and tool parameters:

```ruby
class TaskList < Schematist::Schema
  array :tasks, of: :string
end

response = RubyLLM.chat.with_schema(TaskList).ask "Plan a first Ruby study session."
response.parsed["tasks"]
```

See [Structured Output]({% link _core_features/structured-output.md %}) and [Tool Parameters]({% link _core_features/tool-parameters.md %}) for the built-in integration.

## RubyLLM::MCP

[RubyLLM::MCP](https://github.com/patvice/ruby_llm-mcp) connect to MCP servers from Ruby and use their tools, resources, and prompts in conversations.

For provider-executed MCP tools, also see the built-in [Server Tools]({% link _core_features/server-tools.md %}#mcp-servers).

## RubyLLM::Instrumentation

[RubyLLM::Instrumentation](https://github.com/sinaptia/ruby_llm-instrumentation) adds ActiveSupport notifications to RubyLLM 1.x.

RubyLLM 2.0 emits instrumentation events itself. Start with the [Instrumentation guide]({% link _advanced/instrumentation.md %}) on 2.0.

## RubyLLM::Monitoring

[RubyLLM::Monitoring](https://github.com/sinaptia/ruby_llm-monitoring) adds a Rails dashboard for cost, throughput, latency, and errors, with configurable alerts.

Check its supported RubyLLM and instrumentation versions when upgrading.

## RubyLLM::RedCandle

[RubyLLM::RedCandle](https://github.com/scientist-labs/ruby_llm-red_candle) runs quantized models inside your Ruby process through Red Candle, with streaming and local inference.

See its setup instructions for model downloads, hardware acceleration, and the Rust toolchain.

## OpenTelemetry RubyLLM Instrumentation

[OpenTelemetry RubyLLM Instrumentation](https://github.com/thoughtbot/opentelemetry-instrumentation-ruby_llm) exports traces for RubyLLM calls and tools to OpenTelemetry-compatible backends.

See its documentation for supported versions, exporters, and event coverage.

## RubyLLM::Tribunal

[RubyLLM::Tribunal](https://github.com/Alqemist-labs/ruby_llm-tribunal) tests AI outputs with deterministic assertions and model-based evaluations in RSpec or Minitest.

Use its evaluation reports to compare prompt or model changes on your own examples.

## RubyLLM::Contract

[RubyLLM::Contract](https://github.com/justi/ruby_llm-contract) adds input and output contracts, business-rule validation, retries with model escalation, and regression evaluations.

It checks application rules beyond the shape described by a schema.

## RubyLLM::TopSecret

[RubyLLM::TopSecret](https://github.com/thoughtbot/ruby_llm-top_secret) filters sensitive information before a conversation reaches the provider and restores the corresponding values in responses.

See the project documentation for filter configuration and supported chat integrations.

## RubyLLM::Test

[RubyLLM::Test](https://github.com/RockSolt/ruby_llm-test) stubs model responses for application tests, with RSpec and Minitest support.

Use controlled responses to exercise application behavior and error paths without calling a provider.

## RubyLLM::Instructor

[RubyLLM::Instructor](https://github.com/washu/ruby_llm-instructor) builds Ruby objects from model responses, validates them, and feeds validation errors back to the model for another attempt.

Use built-in [Structured Output]({% link _core_features/structured-output.md %}) when a parsed Hash meets your needs.

## RubyLLM::Registry

[RubyLLM::Registry](https://github.com/washu/ruby_llm-registry) stores versioned prompt artifacts with labels, ERB rendering, and revision comparisons.

For templates that ship with your application code, RubyLLM includes [Prompt Rendering]({% link _core_features/prompt-rendering.md %}).

## RubyLLM::Tokenizer

[RubyLLM::Tokenizer](https://github.com/washu/ruby_llm-tokenizer) counts and truncates text locally using model-to-tokenizer mappings.

RubyLLM also provides [provider-side token counting]({% link _core_features/cost-and-usage-tracking.md %}#counting-tokens-before-you-send) for supported providers.

## RubyLLM::Turbovec

[RubyLLM::Turbovec](https://github.com/washu/ruby_llm-turbovec) adds vector search inside your Ruby process, with quantized indexes and disk persistence.

The native extension requires a Rust toolchain. See its documentation for index types and setup.

## Community Projects

Built something with RubyLLM? Open a documentation PR to add your project, share it in GitHub Discussions, or use the `ruby-llm` topic on its repository.
