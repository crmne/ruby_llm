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
* How to make tool results citable with `RubyLLM::SearchResults` or by returning files
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

To find the record a citation points to, give each result a `source_id` string, such as a Global ID. Its citations return the same `source_id`:

```ruby
RubyLLM::SearchResults.new(title: doc.name, source_id: doc.to_global_id.to_s, text: doc.body)

citation.source_id # => "gid://app/Document/42"
GlobalID::Locator.locate(citation.source_id, only: Document) # => the Document
```

RubyLLM sends `source_id` in place of `url`, so `citation.url` can be `nil`; look the link up through the record. The model sees the `source_id` as the result's label and may quote it in its answer.

`SearchResults` gives citable passages to Cohere and to Claude, on Anthropic and on Bedrock, including after a Rails conversation is reloaded. Other providers, other models on Bedrock, and Bedrock application inference profiles, which don't name their model, receive the results as JSON text.

Tools can also return whole files as [attachments]({% link _core_features/tool-parameters.md %}#returning-attachments-from-tools). With `with_citations` on, the model cites them the same way it cites files you attach yourself:

```ruby
class PolicyLookup < RubyLLM::Tool
  description "Fetches a company policy"
  parameter :policy, description: "The policy to fetch"

  def execute(policy:)
    found = Policy.find_by!(name: policy)
    return "Found the #{found.name} policy", [RubyLLM::Attachment.new(found.file_path)]
  end
end

response = RubyLLM.chat(model: '{{ site.models.anthropic_current }}')
  .with_tools(PolicyLookup)
  .with_citations
  .ask "How many vacation days do I get?"

response.citations.first.start_page # => 3
```

## Citing the Web

Search citations arrive automatically. Enable [web search]({% link _core_features/provider-tools.md %}) and read the returned sources:

```ruby
response = RubyLLM.chat(model: '{{ site.models.openai_mini }}')
  .with_provider_tools(:web_search)
  .ask "What's the latest stable Ruby version?"

response.citations.map(&:url).compact.uniq
# => ["https://www.ruby-lang.org/...", ...]
```

Models that search by default, such as Perplexity's presets, need no tool setting.

## Citing Files from Search

OpenAI and Azure return file citations when you use file search. Pass an existing vector store to the server tool:

```ruby
response = RubyLLM.chat(model: '{{ site.models.openai_mini }}')
  .with_provider_tools(file_search: { vector_store_ids: [vector_store_id] })
  .ask "What does our refund policy cover?"

response.citations.each do |citation|
  citation.source_id # => "file_..."
  citation.title     # => "refund-policy.pdf"
end
```

File-search citations may identify a file without quoting a passage or marking a response range. Check the available fields before rendering them.

## The Citation Object

Each citation exposes a normalized set of fields. Fields a provider doesn't report are `nil`. Character ranges refer to the complete `response.content`, including when an answer arrives in several parts.

| Field | Description |
| :--- | :--- |
| `url` | Source URL or provider collection URI |
| `title` | Document or page title |
| `cited_text` | The quoted snippet from the source |
| `text` | The span of the response this citation supports |
| `start_index` / `end_index` | Character range of that span in `response.content` |
| `source_id` | Provider identifier for the source, such as a file ID or a search result's `source_id` |
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

Apps upgrading from 1.16 get the column from the [2.0 upgrade](https://github.com/crmne/ruby_llm/blob/v2.0.0/docs/_reference/upgrading.md).

## Next Steps

* [Chatting with AI Models]({% link _core_features/chat.md %})
* [Streaming Responses]({% link _core_features/streaming.md %})
* [Rails Integration]({% link _advanced/rails.md %})
