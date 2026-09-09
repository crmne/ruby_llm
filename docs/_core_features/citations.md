---
layout: default
title: Citations
parent: "Chat"
nav_order: 5
description: Get verifiable answers with normalized citations pointing at documents and web sources, on every provider that supports them
redirect_from:
  - /guides/citations
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* How to enable document citations with `with_citations`
* How to make tool results citable with `RubyLLM::SearchResults`
* How to read normalized citations from responses and streams
* Which citation fields your application can use
* How to persist citations with ActiveRecord

## What are Citations?

Citations link spans of a model's answer back to the source material that supports them - a document you attached, or a web page found through search or grounding. They let readers inspect the source behind a claim. A citation points to evidence; your application or reader still needs to assess whether it supports the answer.

Read citations as `RubyLLM::Citation` objects on `response.citations`. Available fields depend on the source and model.

## Citing Your Documents

Use `with_citations` to make attached documents citable. The response can then include citations to your files:

```ruby
chat = RubyLLM.chat(model: '{{ site.models.anthropic_current }}').with_citations

response = chat.ask "Who created Ruby?", with: "facts.txt"

response.content
# => "Ruby was created by Yukihiro Matsumoto in 1993."

response.citations.each do |citation|
  citation.title       # => "facts.txt"
  citation.cited_text  # => "The Ruby programming language was created by Yukihiro Matsumoto in 1993."
  citation.text        # => the span of the answer this citation supports
end
```

Pass `false` to turn citations back off:

```ruby
chat.with_citations(false)
```

This works with plain text files and PDFs. PDF citations include page numbers:

```ruby
response = chat.ask "Summarize the findings", with: "report.pdf"

response.citations.first.start_page # => 5
response.citations.first.end_page   # => 5
```

{: .note }
Document citations are supported by Anthropic, Cohere, and Claude models through Bedrock Converse. Anthropic cannot combine document citations with `with_schema`. Citations from search arrive automatically, without this setting.

## Citing Tool Results (RAG)

When your tools fetch documents from a vector store, Google Drive, or a wiki, return them as `RubyLLM::SearchResults` and the model can cite them:

```ruby
class KnowledgeBase < RubyLLM::Tool
  description "Searches the company knowledge base"
  parameter :query, description: "What to look for"

  def execute(query:)
    docs = MyVectorStore.search(query)

    RubyLLM::SearchResults.new(
      *docs.map { |doc| { title: doc.name, url: doc.link, text: doc.body } }
    )
  end
end

response = RubyLLM.chat(model: '{{ site.models.anthropic_current }}')
  .with_tools(KnowledgeBase)
  .ask "Who created Ruby? Cite your sources."

response.citations.first.url        # => the doc.link you provided
response.citations.first.cited_text # => the quoted passage
```

For a single result, pass keywords directly: `RubyLLM::SearchResults.new(title: "Q4 Report", url: report_url, text: report_text)`.

`SearchResults` gives Anthropic citable passages, including after a Rails conversation is reloaded. Other providers receive the results as JSON text.

## Citing the Web

Search citations arrive automatically. Enable [web search]({% link _core_features/server-tools.md %}) and read the returned sources:

```ruby
response = RubyLLM.chat(model: '{{ site.models.openai_mini }}')
  .with_server_tools(:web_search)
  .ask "What's the latest stable Ruby version?"

response.citations.map(&:url).compact.uniq
# => ["https://www.ruby-lang.org/...", ...]
```

Models that search by default, such as Perplexity Sonar, need no tool setting.

## Citing Files from Search

OpenAI and Azure return file citations when you use file search. Pass an existing vector store to the server tool:

```ruby
response = RubyLLM.chat(model: '{{ site.models.openai_mini }}')
  .with_server_tools(file_search: { vector_store_ids: [vector_store_id] })
  .ask "What does our refund policy cover?"

response.citations.each do |citation|
  citation.source_id # => "file_..."
  citation.title     # => "refund-policy.pdf"
end
```

File-search citations may identify a file without quoting a passage or marking a response range. Check the available fields before rendering them.

## The Citation Object

Each citation exposes a normalized set of fields. Fields a provider doesn't report are `nil`.

| Field | Description |
| :--- | :--- |
| `url` | Source URL or provider collection URI |
| `title` | Document or page title |
| `cited_text` | The quoted snippet from the source |
| `text` | The span of the response this citation supports |
| `start_index` / `end_index` | Character range of that span in `response.content` |
| `source_id` | Provider identifier for the source, such as a file ID |
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

  index = sources.index(citation.url)
  markdown.insert(citation.end_index, "[^#{index + 1}]") if index
end

footnotes = sources.map.with_index(1) { |url, i| "[^#{i}]: #{url}" }
```

## Streaming with Citations

Citations arrive in streaming chunks alongside content, and the final message accumulates all of them:

```ruby
chat = RubyLLM.chat(model: '{{ site.models.anthropic_current }}').with_citations

response = chat.ask("Who created Ruby?", with: "facts.txt") do |chunk|
  chunk.citations.each { |citation| puts "Cited: #{citation.cited_text || citation.url}" }
end

response.citations # all citations, deduplicated
```

Some citations arrive only when the response finishes. Read the final message for the complete list and response positions.

## ActiveRecord Integration

When using `acts_as_chat` and `acts_as_message`, citations are persisted to the message table as JSON:

```ruby
# Migration (generated automatically with new installs)
# t.json :citations

chat_record = Chat.create!(model: '{{ site.models.anthropic_current }}')
chat_record.with_citations
response = chat_record.ask "Who created Ruby?", with: "facts.txt"

chat_record.messages.last.citations # => [RubyLLM::Citation, ...]
```

Apps upgrading from 1.16 get the column from `bin/rails generate ruby_llm:upgrade`. See [Upgrading]({% link _reference/upgrading.md %}).

## Next Steps

* [Chatting with AI Models]({% link _core_features/chat.md %})
* [Streaming Responses]({% link _core_features/streaming.md %})
* [Rails Integration]({% link _advanced/rails.md %})
