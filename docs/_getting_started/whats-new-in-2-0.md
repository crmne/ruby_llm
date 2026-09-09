---
layout: default
title: What's New in 2.0
nav_order: 4
description: Explore the expanded provider coverage, new AI operations, conversation controls, and Rails integration in RubyLLM 2.0.
provider_coverage: true
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* How much more of each provider's API you can use in 2.0.
* How to use tool approvals, citations, thinking, caching, and fallbacks.
* Which new APIs you can use for media, documents, and search.
* How batches, usage tracking, and workflows support larger applications.
* How these features fit into Rails.

RubyLLM 2.0 expands the framework across conversations, agents, media, documents, and Rails. You can use much more of each provider's API through Ruby methods, with consistent results, streaming, and usage tracking. You also get more control over how conversations run and persist.

The examples assume you have [configured the providers you use]({% link _getting_started/configuration.md %}). For an existing application, the [upgrade guide]({% link _reference/upgrading.md %}) covers API changes and database migrations.

## Provider API Coverage

1.16 already supported chat, tools, agents, structured output, thinking, embeddings, images, transcription, and moderation. 2.0 adds video, speech, OCR, reranking, files, batches, and a shared API for provider-hosted tools. It also extends the existing APIs with more controls and richer results.

Red cells show built-in support added in 2.0. Gray cells were already supported in 1.16. Outlined cells with a × mark missing integrations; use “Missing in 2.0” to find them. Select a cell for its sources and implementation notes.

{% include provider_coverage_matrix.html compact=true %}

The [Provider API Coverage]({% link _reference/provider-coverage.md %}) page shows current support, with source references and remaining gaps. The comparison above uses today's documented provider features for both versions, so it includes features providers introduced after 1.16.

## Providers and Protocols

Cohere, Deepgram, ElevenLabs, and Ollama Cloud join the built-in providers, bringing the total to seventeen.

Providers and protocols are now separate. A provider supplies authentication, endpoints, model catalogs, and service-specific behavior. A protocol handles request formats, response parsing, and streaming. RubyLLM selects the protocol for the model and operation, so your application keeps the same API across providers.

A new provider can reuse an existing protocol. The [provider gem generator]({% link _reference/custom-providers.md %}#generate-the-starting-point) creates the package, configuration, and tests to get started.

## Human Approval for Tools

A tool can now require approval before it runs. In a Rails app with a `Post` model, you can let an agent prepare a post while leaving publication to a person:

```ruby
class PublishPost < RubyLLM::Tool
  description "Publishes a draft post"
  requires_approval

  def execute(post_id:)
    Post.find(post_id).update!(published: true)
    "Published post #{post_id}"
  end
end

chat = RubyLLM.chat.with_tools(PublishPost)
chat.ask "Publish post 42."
chat.awaiting_approval? # => true when the model requests publication
```

The tool call stays pending and `ask` returns. Your application can show the proposed action, collect a decision, and continue from its approval handler:

```ruby
chat.approve(chat.pending_approvals.first)
chat.complete
```

Use `deny` to reject a call. The model receives the decision and can respond to it. See [Tool Approvals]({% link _core_features/tool-execution.md %}#requiring-approval).

You also get explicit control over the conversation loop. `ask_later` stages a question, `generate` asks the model for one response, `run_tools` executes pending tools, and `step` advances the conversation by one generation or tool execution. Use them to set limits, hand work to another agent, or run one turn per job. See [Agentic Workflows]({% link _advanced/agentic-workflows.md %}).

## Citations

Citations now have a common result object for document references, web search, and grounding. Enable document citations, ask a question, and read the passages the model used:

```ruby
chat = RubyLLM.chat(model: "{{ site.models.anthropic_latest }}").with_citations
response = chat.ask "What are the report's main findings?", with: "report.pdf"

response.citations.each do |citation|
  puts citation.cited_text
  puts citation.start_page
end
```

Web citations expose `url` and `title`; document citations can include page or character locations. RubyLLM also collects citations while streaming and saves them with Rails messages. See [Citations]({% link _core_features/citations.md %}) for supported providers and citable search results from your own tools.

## Thinking Controls

1.16 let you set thinking effort and token budgets. In 2.0, you can also let RubyLLM choose the model's default thinking settings:

```ruby
chat = RubyLLM.chat(model: "{{ site.models.anthropic_latest }}").with_thinking
response = chat.ask "Find the flaw in this argument: every square is a rectangle, so every rectangle is a square."
puts response.content
```

Use `with_thinking(effort: :high)` or `with_thinking(budget: 10_000)` when you need a specific setting. `with_thinking(false)` turns thinking off where the model allows it. The defaults follow the model when you change it, including during a fallback.

You can also request thinking summaries on supported models and read them through `response.thinking`. See [Thinking]({% link _core_features/thinking.md %}).

## Prompt Caching

Prompt caching now has a common API across supported providers. Enable it with `with_caching`, and mark a reusable prefix with `cache_until_here`:

```ruby
chat = RubyLLM.chat(model: "{{ site.models.anthropic_latest }}").with_caching
chat.with_instructions(File.read("support-policy.txt")).cache_until_here

chat.ask "Can I return an order after 20 days?"
response = chat.ask "What if the item arrived damaged?"
response.tokens.cache_read
```

The boundary marks the end of the policy, before the changing questions. Boundaries also persist on Rails messages. Providers still set the minimum prefix length, lifetime, and supported models; a cache hit is not guaranteed.

You can also create reusable cache resources with `RubyLLM.cache` on Gemini and Vertex AI. See [Prompt Caching]({% link _core_features/prompt-caching.md %}) for automatic caching, boundaries, and cache resources.

## Model Fallbacks

Choose another model to try when a request fails with a transient provider or network error:

```ruby
chat = RubyLLM.chat(model: "{{ site.models.default_chat }}")
             .with_fallbacks("{{ site.models.anthropic_latest }}")

response = chat.ask "Explain Ruby pattern matching with an example."
```

Configure credentials for both providers. The conversation keeps its tools, schema, and settings, so choose fallback models that support the features you use. Usage tracking includes the failed attempts as well as the successful one. See [Model Fallbacks]({% link _advanced/error-handling.md %}#model-fallbacks).

## Video and Speech Generation

Generate a video and save it with the same pattern you use for images:

```ruby
video = RubyLLM.animate "A red panda typing Ruby code, with rain at the window"
video.save "red_panda.mp4"
```

`animate` waits for the result. `animate_later` returns a job you can check and collect later. See [Video Generation]({% link _core_features/video-generation.md %}) for animating images and choosing a provider.

Turn text into speech, too:

```ruby
speech = RubyLLM.speak "Welcome to the Ruby study group."
speech.save "welcome.mp3"
```

See [Text to Speech]({% link _core_features/text-to-speech.md %}) for voices and formats.

## Transcription, Speakers, and Timestamps

Request speaker labels and word timestamps in the same call:

```ruby
transcript = RubyLLM.transcribe("meeting.wav",
                               model: "{{ site.models.transcription_gemini }}",
                               speaker_names: [], timestamps: :word)
puts transcript.text
transcript.words
```

An empty `speaker_names` array asks the model to identify speakers without assigning known names. Supported models can also stream the transcript as it arrives. See [Audio Transcription]({% link _core_features/audio-transcription.md %}) for live transcription, speaker labels, and timing formats.

## OCR, Multimodal Embeddings, and Reranking

The new OCR API extracts Markdown from PDFs and scanned images:

```ruby
document = RubyLLM.ocr "scanned-contract.pdf"
puts document.markdown
```

Use [OCR]({% link _core_features/ocr.md %}) when you need the document's text for indexing, extraction, or later model calls.

Reranking orders search results by how well they answer a question:

```ruby
documents = ["Invoices arrive by email.", "Reset your password in Settings."]

ranked = RubyLLM.rerank("How do I reset my password?", documents,
                       model: "{{ site.models.rerank_cohere }}")
puts ranked.results.first.document
```

[Embeddings]({% link _core_features/embeddings.md %}) now accept media through `with:` on supported models. Combine embeddings, [reranking]({% link _core_features/rerank.md %}), and chats to build [search over your own content]({% link _advanced/rag.md %}).

[Moderation]({% link _core_features/moderation.md %}) also supports configured Bedrock guardrails. Text checks use the existing `RubyLLM.moderate` API and report the guardrail's assessment and usage without requiring a generation model.

## Server Tools

Models can use tools hosted by the provider, including web search, code execution, and remote MCP servers. Enable them on a chat with `with_server_tools`, or declare them on an agent:

```ruby
class ResearchAgent < RubyLLM::Agent
  model "{{ site.models.anthropic_server_tools }}"
  instructions "Research the question and cite your sources."
  server_tools :web_search
end

response = ResearchAgent.new.ask "What changed in the latest Ruby release?"
response.citations.each { |citation| puts citation.url }
```

Combine server tools with tools that run your Ruby code. Both work with streaming and follow-up questions. See [Server Tools]({% link _core_features/server-tools.md %}).

## Hosted Research

Run a provider's research agent and read its report:

```ruby
report = RubyLLM.research(
  "Find the official Ruby documentation and explain where its API reference lives.",
  provider: :vertexai, agent: "{{ site.hosted_agents.vertexai_research }}"
)
puts report.content
```

`research_later` returns a job ID you can save, retrieve, poll, or cancel. Vertex AI supports this through its Deep Research agent, including remote MCP tools. See [Hosted Research]({% link _advanced/hosted-research.md %}) for credentials, tools, citations, and recovery.

## Batch Processing

Submit chats or embedding requests to a provider's batch API when the results can arrive later. Stage the questions with the same chat settings you use for interactive work:

```ruby
chats = ["Ruby blocks", "Rails migrations"].map do |topic|
  RubyLLM.chat(model: "{{ site.models.default_chat }}")
    .with_instructions("Explain the topic in one paragraph.")
    .ask_later(topic)
end

batch = RubyLLM.batch(chats)
```

Save `batch.id`. Another process can find the batch and check whether it has finished:

```ruby
batch = RubyLLM::Batch.find(batch_id, provider: :openai)
batch.complete?
```

Once complete, `batch.messages` returns the results in submission order. Batch pricing and turnaround depend on the provider; RubyLLM uses batch rates when calculating the results' costs. See [Batches]({% link _advanced/batches.md %}) for polling, failures, embedding batches, and conversations with tools.

## Tokenization and Token Counting

Inspect the token IDs a model uses for your text:

```ruby
result = RubyLLM.tokenize("Ruby makes AI useful.", model: "{{ site.models.xai_tokenization }}")
result.ids
result.count
```

For a complete chat input, use `chat.count_tokens` before asking the model to generate a response:

```ruby
chat = RubyLLM.chat(model: "{{ site.models.anthropic_latest }}")
             .with_instructions("Review the contract for renewal terms.")
chat.count_tokens("What should I check in a renewal clause?")
```

See [Tokenization]({% link _core_features/tokenization.md %}) for the standalone counting API, supported inputs, and the difference between input counts and billed usage.

## Usage and Cost Tracking

Usage tracking now follows individual provider attempts, including retries, fallbacks, and cancelled requests. Read normalized token counts and costs through the same objects:

```ruby
chat = RubyLLM.chat
response = chat.ask "Explain Ruby fibers in one paragraph."

response.tokens.input
response.tokens.output
response.cost.total
chat.cost.total
```

An answer that required several attempts includes their reported usage. Unknown usage or pricing stays `nil`, so missing information does not look like a free request.

In Rails, the usage ledger records attempts separately from messages and keeps the costs calculated at completion. Updating model prices later does not rewrite that history. See [Tokens and Costs]({% link _core_features/cost-and-usage-tracking.md %}).

## Workflow Instrumentation

Group a piece of work with `RubyLLM.workflow` and name its steps. Calls inside each step carry the workflow and step identifiers in their instrumentation events:

```ruby
RubyLLM.workflow("Summarize meeting") do |workflow|
  transcript = workflow.step("Transcribe") do
    RubyLLM.transcribe("meeting.wav").text
  end

  workflow.step("Summarize") do
    RubyLLM.chat.ask("List the decisions and action items:\n#{transcript}").content
  end
end
```

Use ordinary Ruby for branching, loops, and concurrency. Rails sends the events through `ActiveSupport::Notifications`; plain Ruby applications can configure an instrumenter. See [Instrumentation]({% link _advanced/instrumentation.md %}) for connecting your logs and tracing tools.

## Rails Persistence and Durable Agents

The new loop controls and approval decisions also work on persisted conversations. Declare an agent with your application's chat model and the `PublishPost` tool from above:

```ruby
class EditorialAgent < RubyLLM::Agent
  chat_model Chat
  model "{{ site.models.default_chat }}"
  tools PublishPost
end

chat = EditorialAgent.create!
chat.ask "Publish post 42."
```

Once a user approves a pending call, an approval handler or job can reload the agent and continue:

```ruby
chat = EditorialAgent.find(chat_id)
chat.approve(tool_call_id)
chat.complete
```

The saved transcript records completed work. If a job stops before saving a result, that operation may run again, so tools need to tolerate retries. [Durable Agents]({% link _advanced/durable-agents.md %}) shows how to run turns with Active Job and resume after interruptions.

RubyLLM now owns the model-registry, tool-call, usage, and batch tables. These records describe the framework's work, so RubyLLM can evolve their schema without asking every application to maintain its own supporting models. Your app owns its chats and messages.

The upgrade runs in phases, with cleanup in a later deployment. Optional [copy mode]({% link _reference/upgrading.md %}#copy-mode) keeps a controlled route back to 1.16; conversations written by 2.0 remain hidden during that rollback.

The Rails integration uses the same Ruby API with Active Record persistence, Active Storage attachments, and Hotwire streaming. The [generators]({% link _advanced/rails-generators.md %}) set up those pieces in conventional Rails directories.

The [model registry]({% link _reference/models.md %}) uses the same `RubyLLM.models` API in plain Ruby and Rails, backed by a file cache or RubyLLM's database table. Browse [Models]({% link _reference/available-models.md %}) to compare providers, capabilities, and prices.

## API Consistency

The API uses one name for each concept across chats, agents, and persisted records. For example, `max_output_tokens` replaces `max_tokens`, and provider-specific request options use `with_provider_options`. Responses expose typed token counts, costs, citations, and other results through readers.

The [upgrade guide]({% link _reference/upgrading.md %}) lists the renames and Rails migration steps. Two other additions are [context compaction]({% link _core_features/chat-request-control.md %}#compacting-long-conversations) with `with_compaction`, and [file storage]({% link _core_features/files.md %}) with `RubyLLM.upload` and `RubyLLM.download`.

## Try 2.0

These features are available in the 2.0 release candidate:

```sh
bundle add ruby_llm --version 2.0.0.rc2
```

Start with [Getting Started]({% link _getting_started/getting-started.md %}), or follow [Upgrade to 2.0]({% link _reference/upgrading.md %}) to update an existing application.
