---
layout: default
title: Citations
nav_order: 9
description: Get verifiable answers with normalized citations pointing at documents and web sources, on every provider that supports them
redirect_from:
  - /guides/citations
---

# {{ page.title }}
{: .d-inline-block .no_toc }

New in 1.17
{: .label .label-green }

{{ page.description }}
{: .fs-6 .fw-300 }

## Table of contents
{: .no_toc .text-delta }

1. TOC
{:toc}

---

After reading this guide, you will know:

* How to enable document citations with `with_citations`
* How to make tool results citable with `RubyLLM::SearchResults`
* How to read normalized citations from responses and streams
* How citations map to each provider's native format
* How to persist citations with ActiveRecord

## What are Citations?

Citations link spans of a model's answer back to the source material that supports them — a document you attached, or a web page found through search or grounding. They make answers verifiable and reduce hallucinations, and providers parse them server-side so cited quotes are guaranteed to exist in the source.

Every provider returns citations in a different shape. RubyLLM normalizes all of them into `RubyLLM::Citation` objects on `response.citations`, so your rendering code never branches on provider.

## Citing Your Documents

Use `with_citations` to make attached documents citable. The model will then back its claims with quotes from your files:

```ruby
chat = RubyLLM.chat(model: 'claude-sonnet-4-5').with_citations

response = chat.ask "Who created Ruby?", with: "facts.txt"

response.content
# => "Ruby was created by Yukihiro Matsumoto in 1993."

response.citations.each do |citation|
  citation.title       # => "facts.txt"
  citation.cited_text  # => "The Ruby programming language was created by Yukihiro Matsumoto in 1993."
  citation.text        # => the span of the answer this citation supports
end
```

This works with plain text files and PDFs. PDF citations include page numbers:

```ruby
response = chat.ask "Summarize the findings", with: "report.pdf"

response.citations.first.start_page # => 5
response.citations.first.end_page   # => 5
```

{: .note }
Document citations are currently supported by Anthropic. RubyLLM checks the [model registry]({% link _advanced/models.md %}) and logs a warning when you request citations from a model that can't return them. Citations from search and grounding are always parsed regardless (see below).

## Citing Tool Results (RAG)

When your tools fetch documents, e.g. from a vector store, Google Drive, a wiki, return them as `RubyLLM::SearchResults` and the model can cite them:

```ruby
class KnowledgeBase < RubyLLM::Tool
  description "Searches the company knowledge base"
  param :query, desc: "What to look for"

  def execute(query:)
    docs = MyVectorStore.search(query)

    RubyLLM::SearchResults.new(
      *docs.map { |doc| { title: doc.name, url: doc.link, text: doc.body } }
    )
  end
end

response = RubyLLM.chat(model: 'claude-sonnet-4-5')
  .with_tool(KnowledgeBase)
  .ask "Who created Ruby? Cite your sources."

response.citations.first.url        # => the doc.link you provided
response.citations.first.cited_text # => the quoted passage
```

A single result reads even simpler: `RubyLLM::SearchResults.new(title: "Q4 Report", url: report_url, text: report_text)`.

On Anthropic these become native citable search result blocks. Other providers receive the same results as plain text, so your tools stay provider-agnostic.

## Citing the Web

When a provider searches the web, RubyLLM parses the resulting citations automatically — no `with_citations` needed. Enable search the way each provider expects:

```ruby
# Perplexity searches by default
response = RubyLLM.chat(model: 'sonar', provider: :perplexity)
  .ask "What's new in Ruby?"

# Gemini with Google Search grounding
response = RubyLLM.chat(model: 'gemini-2.5-flash')
  .with_params(tools: [{ google_search: {} }])
  .ask "What's the latest stable Ruby version?"

# OpenAI with web search
response = RubyLLM.chat(model: 'gpt-4o-mini-search-preview')
  .with_params(web_search_options: {})
  .ask "What's the latest stable Ruby version?"

response.citations.map(&:url).uniq
# => ["https://www.ruby-lang.org/...", ...]
```

## The Citation Object

Each citation exposes a normalized set of fields. Fields a provider doesn't report are `nil`.

| Field | Description |
| :--- | :--- |
| `url` | Source URL, when citing the web |
| `title` | Document or page title |
| `cited_text` | The quoted snippet from the source |
| `text` | The span of the response this citation supports |
| `start_index` / `end_index` | Character range of that span in `response.content` |
| `source_index` | 0-indexed position of the source document or search result |
| `start_page` / `end_page` | Page range for PDF citations (1-indexed, inclusive) |

`start_index` and `end_index` let you place citation markers exactly where they belong:

```ruby
response.citations.each do |citation|
  response.content[citation.start_index...citation.end_index] == citation.text # => true
end
```

For example, rendering footnotes:

```ruby
sources = response.citations.map(&:url).compact.uniq

markdown = response.content.dup
response.citations.reverse.each do |citation|
  next unless citation.end_index

  marker = sources.index(citation.url)&.+(1)
  markdown.insert(citation.end_index, "[^#{marker}]") if marker
end

footnotes = sources.map.with_index(1) { |url, i| "[^#{i}]: #{url}" }
```

## Streaming with Citations

Citations arrive in streaming chunks alongside content, and the final message accumulates all of them:

```ruby
chat = RubyLLM.chat(model: 'claude-sonnet-4-5').with_citations

response = chat.ask("Who created Ruby?", with: "facts.txt") do |chunk|
  chunk.citations.each { |citation| puts "Cited: #{citation.cited_text || citation.url}" }
end

response.citations # all citations, deduplicated
```

What arrives mid-stream varies by provider. Anthropic streams each citation (with `cited_text`) as the cited sentence completes, but without response positions; OpenAI sends its `url_citation` annotations in one chunk near the end of the stream, with positions but no quoted snippet. The finished message is always the complete picture: RubyLLM resolves `text` from `start_index`/`end_index` against the full content where positions are available.
{: .note }

## ActiveRecord Integration

When using `acts_as_chat` and `acts_as_message`, citations are persisted to the message table as JSON:

```ruby
# Migration (generated automatically with new installs)
# t.json :citations

chat_record = Chat.create!(model: 'claude-sonnet-4-5')
chat_record.with_citations
response = chat_record.ask "Who created Ruby?", with: "facts.txt"

chat_record.messages.last.citations # => [RubyLLM::Citation, ...]
```

### Upgrading Existing Installations

Run the upgrade generator:

```bash
rails generate ruby_llm:upgrade_to_v1_17
rails db:migrate
```

Or add the column manually:

```ruby
class AddCitationsToMessages < ActiveRecord::Migration[7.1]
  def change
    add_column :messages, :citations, :json
  end
end
```

Without the column, everything still works — citations just aren't persisted.

## Provider Notes

- **Anthropic** returns the richest citations: quoted snippets, document titles, exact response spans, and page numbers for PDFs. Citations and structured output (`with_schema`) cannot be combined.
- **OpenAI** (and Azure/OpenRouter) return `url_citation` annotations from web search, with response spans.
- **Gemini / Vertex AI** return grounding metadata when the `google_search` tool is enabled. RubyLLM converts grounding byte offsets to character offsets for you.
- **Perplexity** returns its search results on every response; `cited_text` carries the result snippet when available.
- **xAI** returns a list of cited URLs when live search is enabled via `with_params`.
- **Bedrock, DeepSeek, Mistral, Ollama, GPUStack** don't currently surface citations through RubyLLM.

## Next Steps

* [Chatting with AI Models]({% link _core_features/chat.md %})
* [Streaming Responses]({% link _core_features/streaming.md %})
* [Rails Integration]({% link _advanced/rails.md %})
