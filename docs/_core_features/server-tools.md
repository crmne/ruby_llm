---
layout: default
title: Server Tools
parent: "Tools"
nav_order: 3
description: Search the web, run code, and connect remote MCP tools through the same chat API
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* How to enable provider-executed tools with `with_server_tools`.
* How to read results, citations, and usage.
* How to connect a search store or MCP server.
* How to approve remote tool calls and resume them in Rails.

## Enabling Server Tools

Server tools run on the provider's infrastructure. Use them to search the web or run code without writing a local tool:

```ruby
chat = RubyLLM.chat(model: "{{ site.models.anthropic_server_tools }}")
              .with_server_tools(:web_search)

response = chat.ask "What is the latest stable Ruby version? Cite your source."
puts response.content
response.citations
```

Enable several at once, or combine them with your own [Ruby tools]({% link _core_features/tools.md %}):

```ruby
chat.with_server_tools(:web_search, :code_execution)
chat.with_tools(Weather).with_server_tools(:web_search)
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
| Azure | `protocol: :responses` when the deployment does not already use it | Responses server tools |
| DeepSeek | `protocol: :responses` | Web search and patch tools |
| Gemini | `protocol: :interactions` | Remote MCP |
| Mistral | `protocol: :conversations` | Web search, page fetching, code execution, and library search |
| OpenRouter | `protocol: :responses` | Hosted shell, patch tools, and remote MCP |
| GPUStack | `protocol: :responses` | Tools configured on the deployed vLLM server |

For example, select OpenRouter's hosted shell and use the same tool alias:

```ruby
chat = RubyLLM.chat(model: "{{ site.models.openrouter_server_tools }}",
                   provider: :openrouter, protocol: :responses)
              .with_server_tools(:code_execution)
response = chat.ask "Run Python to calculate 17 times 23."
```

On OpenAI and Azure, `:web_search` also opens pages; a separate `:web_fetch` tool is unnecessary. Bedrock web search requires a Nova 2 model. Mistral's default protocol already supports image generation and configured MCP connectors.

## Tool Options

Pass options in the provider's vocabulary with the keyword form:

```ruby
chat.with_server_tools(web_search: { allowed_domains: ["ruby-lang.org"], max_uses: 3 })
```

Options such as domain filters, connector IDs, and search-store IDs depend on the service. Use its documented settings for the selected tool.

A raw Hash lets you use a tool without a RubyLLM alias or select a particular tool version:

```ruby
chat.with_server_tools({ type: "tool_search_tool_regex_20251119", name: "tool_search" })
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

Providers can charge for tool use as well as the tokens in the results. `tokens.server_tool_use` contains reported per-use counters; see [Tokens and Costs]({% link _core_features/cost-and-usage-tracking.md %}).

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
              .with_server_tools(file_search: {
                datastore: ENV.fetch("VERTEX_SEARCH_DATASTORE")
              })

response = chat.ask "What does our documentation say about account recovery?"
response.citations
```

Use the data store's full resource name. Its contents and access permissions are managed in Vertex AI Search, separately from Gemini API file-search stores.

## MCP Servers

Connect a remote MCP server by name and URL:

```ruby
chat = RubyLLM.chat(model: "{{ site.models.anthropic_server_tools }}")
              .with_server_tools(mcp: {
                name: "docs",
                url: "https://learn.microsoft.com/api/mcp"
              })
response = chat.ask "Find the Azure Functions overview in Microsoft Learn."
```

Some services use an existing connector or require additional settings:

| Service | Connection and execution requirements |
| --- | --- |
| Anthropic | Use `default_config` and `configs` to select allowed tools |
| Gemini Interactions | Streamable HTTP server; names cannot contain hyphens; allowed tools execute automatically |
| xAI | Use `allowed_tools` to select tools; allowed calls execute automatically |
| Mistral | Use `connector_id:` for a connector configured in Mistral Studio |
| Bedrock Mantle | Use `connector_id:` with an accessible Lambda or AgentCore Gateway ARN; Gateway requires `require_approval: "never"` |
| OpenRouter Responses | Explicit `require_approval: "never"`; approval requests are unavailable |

Vertex AI connects remote MCP through a hosted Deep Research agent. Use the [Hosted Research API]({% link _advanced/hosted-research.md %}) for its single-turn report and job lifecycle.

### Self-Hosted Tool Servers

Configure the MCP servers on your [GPUStack deployment]({% link _getting_started/configuration-providers.md %}#gpustack-deployments). Per-request URLs are not supported. Select Responses and explicitly allow execution:

```ruby
chat = RubyLLM.chat(model: ENV.fetch("GPUSTACK_MODEL"), provider: :gpustack,
                   protocol: :responses, assume_model_exists: true)
              .with_server_tools(code_execution: { require_approval: "never" })
chat.ask "Use Python to calculate 17 * 23."
```

The backend must supply the corresponding Python or browser tool. Page fetching also requires a backend that can dispatch the browser's `open` operation. Tool results may be absent from returned records. Configure permissions on the tool server; `allowed_tools` describes tools to the model but does not enforce execution restrictions.

### Remote Tool Approval

OpenAI and Azure Responses can pause before executing an MCP call. Use the same approval API as [local tools]({% link _core_features/tool-execution.md %}#requiring-approval):

```ruby
chat = RubyLLM.chat(model: "{{ site.models.openai_mcp }}", provider: :openai)
              .with_server_tools(mcp: {
                name: "docs",
                url: "https://learn.microsoft.com/api/mcp",
                allowed_tools: ["microsoft_docs_search"],
                require_approval: "always"
              })

chat.ask "Search Microsoft documentation for Azure Blob Storage."
call = chat.pending_approvals.first
call.remote? # => true

chat.approve(call) # or chat.deny(call)
response = chat.complete
```

`remote?` distinguishes provider-executed tools from local Ruby tools. The call's `id` identifies the individual approval request. The decision goes to the provider; denied calls do not execute. Approvals work with streaming and require no provider storage on these protocols.

## Rails

Persisted chats use the same API, and agents can declare server tools:

```ruby
class ResearchAgent < RubyLLM::Agent
  model "{{ site.models.anthropic_server_tools }}"
  server_tools :web_search
end
```

Tool history and approval decisions survive `Agent.find` and worker restarts. Run the [upgrade generator]({% link _reference/upgrading.md %}) for an existing app so its message and tool-call tables have the required columns.
