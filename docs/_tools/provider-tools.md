---
layout: default
title: Provider Tools
nav_order: 4
description: Search the web, run code, and connect remote MCP tools through the same chat API
redirect_from:
  - /server-tools
  - /server-tools/
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* How to enable provider-executed tools with `with_provider_tools`.
* How to read results, citations, web sources, and usage.
* How to show Google's search suggestions with a grounded answer.
* How to connect a search store or MCP server.
* How to approve remote tool calls and resume them in Rails.
* How to connect your own executor to a native client toolset.

## Enabling Provider Tools

Provider tools run on the provider's infrastructure. Use them to search the web or run code without writing a local tool:

```ruby
chat = RubyLLM.chat(model: "{{ site.models.anthropic_provider_tools }}")
              .with_provider_tools(:web_search)

response = chat.ask "What is the latest stable Ruby version? Cite your source."
puts response.content
response.citations
```

Enable several at once, or combine them with your own [Ruby tools]({% link _getting_started/tools.md %}):

```ruby
chat.with_provider_tools(:web_search, :code_execution)
chat.with_tools(Weather).with_provider_tools(:web_search)
```

| Alias | Purpose |
| --- | --- |
| `:web_search` | Search the web |
| `:web_fetch` / `:url_context` | Read a web page |
| `:x_search` | Search X |
| `:code_execution` | Run code in a hosted environment |
| `:file_search` | Search an existing document store |
| `:image_generation` | Generate an image during a conversation |
| `:apply_patch` | Request file edits where supported |
| `:mcp` | Use a remote MCP tool server |

Availability depends on the provider, model, and protocol. An unsupported alias raises `RubyLLM::UnsupportedServerToolError`, listing the available aliases. See [Provider API Coverage]({% link _reference/provider-coverage.md %}) for supported operations and limits.

### Protocol Selection

Some tools need a protocol other than the provider's default:

| Provider | Select | Needed for |
| --- | --- | --- |
| Azure | `protocol: :responses` when the deployment does not already use it | Responses provider tools |
| DeepSeek | `protocol: :responses` | Patch tools |
| Gemini | `protocol: :interactions` | Remote MCP |
| Mistral | `protocol: :conversations` | Web search, page fetching, code execution, and library search |
| OpenRouter | `protocol: :responses` | Hosted shell, patch tools, and remote MCP |
| GPUStack | `protocol: :responses` | Tools configured on the deployed vLLM server |

DeepSeek's Responses API ignores built-in web search. On DeepSeek, `with_provider_tools(:web_search)` raises `RubyLLM::UnsupportedServerToolError` before sending a request.

For example, select OpenRouter's hosted shell and use the same tool alias:

```ruby
chat = RubyLLM.chat(model: "{{ site.models.openrouter_provider_tools }}",
                   provider: :openrouter, protocol: :responses)
              .with_provider_tools(:code_execution)
response = chat.ask "Run Python to calculate 17 times 23."
```

On OpenAI and Azure, `:web_search` also opens pages; a separate `:web_fetch` tool is unnecessary. Bedrock web search requires a Nova 2 model. Mistral's default protocol already supports image generation and configured MCP connectors.

## Native Client Toolsets

Register an application tool for each member your executor implements. A computer screenshot member returns an image through the usual attachment API:

```ruby
class Screenshot < RubyLLM::Tool
  namespace "computer"

  def execute
    RubyLLM::Attachment.new(Desktop.capture_screenshot, filename: "screen.png")
  end
end

chat = RubyLLM.chat(model: "{{ site.models.anthropic_provider_tools }}")
             .with_provider_tools({ type: "computer_toolset_20260801" })
             .with_tools(Screenshot)
response = chat.ask "Describe the screen."
```

`Desktop.capture_screenshot` is your application's executor and returns a path or IO. Your application owns the environment, actions, and screenshot sizing. RubyLLM sends the native toolset declaration, retains each member's identity, and returns text and image results with that identity. It does not send an ordinary function definition for the member.

The namespace must match the native toolset and the tool name must match its member. A separate custom `screenshot` tool can coexist with the member, which the chat keys as `:computer_screenshot`. Member calls are local: `tool_call.remote?` is `false`, and normal tool callbacks and approval rules apply.

Anthropic expects a toolset's calls in one response to run in order, and RubyLLM runs them that way even when you enable tool concurrency. A pending approval, or a call another process is running, holds back the calls after it. Return `{ error: "The display is unavailable" }` for a recoverable failure: RubyLLM answers the later calls of the batch as not executed instead of running them. An exception interrupts the run as it does for any tool.

This supports computer text and image results. Browser member identity is preserved too, but browser-specific `browser_state` result blocks are not represented. Browser tab-management workflows need that additional result support.

## Tool Options

Pass options in the provider's vocabulary with the keyword form:

```ruby
chat.with_provider_tools(web_search: { allowed_domains: ["ruby-lang.org"], max_uses: 3 })
```

Options such as domain filters, connector IDs, and search-store IDs depend on the service. Use its documented settings for the selected tool.

Enabling a tool again replaces its options, so a chat sends each tool once however often you call `with_provider_tools`:

```ruby
chat.with_provider_tools(:web_search)
chat.with_provider_tools(web_search: { max_uses: 3 }) # one web search tool, limited to three uses
```

Raw Hashes and [MCP servers](#mcp-servers) add up instead, one entry for each distinct definition.

A raw Hash lets you use a tool without a RubyLLM alias or select a particular tool version:

```ruby
chat.with_provider_tools({ type: "tool_search_tool_regex_20251119", name: "tool_search" })
```

The selected protocol must support that tool's request and results. Passing a raw definition does not enable another endpoint.

## Reading Results

Read tool activity from the completed response:

```ruby
response.server_tool_calls.each do |call|
  puts call.name
  p call.input
  p call.result
end

response.citations
response.attachments
response.tokens.server_tool_use
```

Search results use the same [Citation objects]({% link _core_features/citations.md %}) as document citations. Generated images and files appear in [attachments]({% link _core_features/files.md %}). Each tool call's `raw` holds additional details returned by the service.

Streaming and follow-up questions use the normal `ask` API. Read the completed message for the full result list. Some services omit intermediate tool records or results; their answer and citations can still be available. OpenRouter MCP currently omits tool names and results from streamed records.

Providers can charge for each tool use as well as for the tokens in the results. `tokens.server_tool_use` counts the uses, such as `{"web_search_requests" => 2}`; see [Pricing Tool Use]({% link _core_features/cost-and-usage-tracking.md %}#pricing-tool-use).

### Web Sources

Sources and citations answer different questions. Sources are the pages a web search returned. Citations link parts of the answer to what supports them, so there are usually fewer of them. Read the sources from `web_sources`:

```ruby
response = chat.with_provider_tools(:web_search).ask "What changed in the latest Ruby release?"

response.web_sources.map(&:url)
response.web_sources.first.title
```

Each `WebSource` has a `url` and, where the provider gives one, a `title`. The list holds each address once, and works the same on streamed replies and on Rails records after a reload.

| Provider | `url` | `title` |
| --- | --- | --- |
| OpenAI, Azure, Meta, xAI | The page | `nil` |
| Anthropic | The page | The page title |
| Gemini, Vertex AI | A Google redirect link that leads to the page | The site's domain |

`web_sources` is empty on other providers and on Gemini's Interactions protocol. RubyLLM does not build the list from citations, which name only what the answer cites. On Gemini and Vertex AI it holds only Google's redirect links, so a link to Google's own results page, which some answers about the weather include, isn't listed.

Sources come from the outside world, so don't use them as an allowlist on their own. Before you let a chat act on an address from this list, such as opening it without asking, keep these in mind:

* Anyone can publish a page that a search returns, and text the model reads can steer what it searches for.
* OpenAI can list a page the model opened beside the pages its search found, and its API doesn't mark which is which. Text the model read can name that page, so an address carrying data can reach this list.
* The list reports what already happened and blocks nothing. If the model opened a page, the provider may have requested it before your code saw the list, so check an address before your app opens it, and don't count on the list to stop a request.

Citations can name a page the model chose in the same way.

Pages the model chose to read aren't web sources, though OpenAI's list can include them as above. Find them in `server_tool_calls`: a Responses `web_search_call` holds the address in `call.input["url"]`, a Gemini `url_context` call in its `result`, and an Anthropic `web_fetch_tool_result` in its `result`.

### Google Search Suggestions

Google requires apps that ground answers with Google Search to show its search suggestions with the answer. On Gemini and Vertex AI, `search_suggestions` holds them as HTML:

```ruby
response = chat.with_provider_tools(:web_search).ask "What changed in Ruby 4.0?"
suggestions = response.server_tool_calls.filter_map(&:search_suggestions).join
```

Show the HTML as Google sends it, without changes, below the answer. Streamed answers carry it on the final chunk. In Rails, send it to the page along with the answer, for example from the job that runs the chat:

```ruby
response = chat.ask(content)
suggestions = response.server_tool_calls.filter_map(&:search_suggestions).join
if suggestions.present?
  Turbo::StreamsChannel.broadcast_append_to chat, target: "message_#{chat.messages.last.id}", html: suggestions
end
```

RubyLLM never stores search suggestions. Google's terms allow storing them only "for the minimum time necessary to comply with applicable law or regulations", so persisted chats keep the answer, its citations, its search queries, and its web sources, but not the suggestions. A reloaded conversation shows the answer without them; display them from the live response.

## Search Your Documents

File search needs a document store that already exists on the service:

| Service | `file_search:` options |
| --- | --- |
| OpenAI and Azure | `{ vector_store_ids: [vector_store_id] }` |
| Mistral Conversations | `{ library_ids: [library_id] }` |
| Vertex AI Search | `{ datastore: datastore_resource_name }` |

For example, query a Vertex AI Search data store:

```ruby
chat = RubyLLM.chat(model: "{{ site.models.gemini_current }}", provider: :vertexai)
              .with_provider_tools(file_search: {
                datastore: ENV.fetch("VERTEX_SEARCH_DATASTORE")
              })

response = chat.ask "What does our documentation say about account recovery?"
response.citations
```

Use the data store's full resource name. Its contents and access permissions are managed in Vertex AI Search, separately from Gemini API file-search stores.

## MCP Servers

Connect a remote MCP server by name and URL:

```ruby
chat = RubyLLM.chat(model: "{{ site.models.anthropic_provider_tools }}")
              .with_provider_tools(mcp: {
                name: "docs",
                url: "https://learn.microsoft.com/api/mcp"
              })
response = chat.ask "Find the Azure Functions overview in Microsoft Learn."
```

Some services use an existing connector or require additional settings:

| Service | Connection and execution requirements |
| --- | --- |
| Anthropic | Use `allowed_tools`, or `default_config` and `configs`, to select tools; allowed calls execute automatically, so `require_approval` other than `"never"` raises |
| Gemini Interactions | Streamable HTTP server; names cannot contain hyphens; allowed tools execute automatically |
| xAI | Use `allowed_tools` to select tools; allowed calls execute automatically |
| Mistral | Use `connector_id:` for a connector configured in Mistral Studio |
| Bedrock Mantle | Use `connector_id:` with an accessible Lambda or AgentCore Gateway ARN; Gateway requires `require_approval: "never"` |
| OpenRouter Responses | Explicit `require_approval: "never"`; approval requests are unavailable |

Vertex AI connects remote MCP through a hosted Deep Research agent. Use the [Hosted Research API]({% link _advanced/hosted-research.md %}) for its single-turn report and job lifecycle.

### Self-Hosted Tool Servers

Configure the MCP servers on your [GPUStack deployment]({% link _reference/configuration-providers.md %}#gpustack-deployments). Per-request URLs are not supported. Select Responses and explicitly allow execution:

```ruby
chat = RubyLLM.chat(model: ENV.fetch("GPUSTACK_MODEL"), provider: :gpustack,
                   protocol: :responses, assume_model_exists: true)
              .with_provider_tools(code_execution: { require_approval: "never" })
chat.ask "Use Python to calculate 17 * 23."
```

The backend must supply the corresponding Python or browser tool. Page fetching also requires a backend that can dispatch the browser's `open` operation. Tool results may be absent from returned records. Configure permissions on the tool server; `allowed_tools` describes tools to the model but does not enforce execution restrictions.

### Remote Tool Approval

OpenAI and Azure Responses can pause before executing an MCP call. Use the same approval API as [local tools]({% link _tools/tool-execution.md %}#requiring-approval):

```ruby
chat = RubyLLM.chat(model: "{{ site.models.openai_mcp }}", provider: :openai)
              .with_provider_tools(mcp: {
                name: "docs",
                url: "https://learn.microsoft.com/api/mcp",
                allowed_tools: ["microsoft_docs_search"],
                require_approval: "always"
              })

chat.ask "Search Microsoft documentation for Azure Blob Storage."
question = chat.pending_questions.first
question.tool_call.remote? # => true

question.approve # or question.decline
response = chat.complete
```

`remote?` distinguishes provider-executed tools from local Ruby tools. The call's `id` identifies the individual approval request. The decision goes to the provider; denied calls do not execute. Approvals work with streaming and require no provider storage on these protocols.

## Rails

Persisted chats use the same API, and agents can declare provider tools:

```ruby
class ResearchAgent < RubyLLM::Agent
  model "{{ site.models.anthropic_provider_tools }}"
  provider_tools :web_search
end
```

A block decides when the chat is built. It returns aliases, or a Hash of aliases and their options, like the macro's keywords:

```ruby
class ResearchAgent < RubyLLM::Agent
  model "{{ site.models.anthropic_provider_tools }}"
  inputs :domains
  provider_tools { { web_search: { allowed_domains: domains } } }
end

ResearchAgent.chat(domains: ["ruby-lang.org"])
```

Tool history and approval decisions survive `Agent.find` and worker restarts. Apps upgrading from 1.16 get the required message and tool-call columns from the [2.0 upgrade](https://github.com/crmne/ruby_llm/blob/v2.0.0/docs/_reference/upgrading.md).

## Next Steps

* [Tools]({% link _getting_started/tools.md %}): write tools that run your own Ruby code.
* [MCP]({% link _tools/mcp.md %}): connect a server from your own process.
* [Citations]({% link _core_features/citations.md %}): read the sources behind search answers.
