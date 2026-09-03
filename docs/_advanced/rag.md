---
layout: default
title: Retrieval-Augmented Generation (RAG)
parent: "Agents"
nav_order: 2
description: Retrieve relevant context from your own documents, then answer with that context
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* How RAG fits as one step in a larger workflow.
* How to store document embeddings with `neighbor` and pgvector.
* How to generate embeddings automatically when a document changes.
* How to expose semantic search to an agent as a retrieval tool.
* How to build an answering agent that cites its sources.

RAG is often just one step in a larger [workflow]({% link _advanced/agentic-workflows.md %}): retrieve relevant context, then answer with that context. You embed your documents once, search them by similarity at query time, and feed the closest matches to the model as grounding. For the mechanics of turning text into vectors, see [Embeddings]({% link _core_features/embeddings.md %}).

## Setup

```ruby
# Gemfile
gem 'neighbor'
gem 'ruby_llm'
```

```bash
bin/rails generate neighbor:vector
bin/rails db:migrate
```

```ruby
class CreateDocuments < ActiveRecord::Migration[7.1]
  def change
    create_table :documents do |t|
      t.text :content
      t.string :title
      t.vector :embedding, limit: 1536 # OpenAI embedding size
      t.timestamps
    end

    add_index :documents, :embedding, using: :hnsw, opclass: :vector_l2_ops
  end
end
```

## Document Model with Embeddings

```ruby
class Document < ApplicationRecord
  has_neighbors :embedding

  before_save :generate_embedding, if: :content_changed?

  private

  def generate_embedding
    response = RubyLLM.embed(content)
    self.embedding = response.vectors
  end
end
```

## Retrieval Tool

```ruby
class DocumentSearch < RubyLLM::Tool
  description "Searches knowledge base for relevant information"
  parameter :query, description: "Search query"

  def execute(query:)
    embedding = RubyLLM.embed(query).vectors

    documents = Document.nearest_neighbors(
      :embedding,
      embedding,
      distance: "euclidean"
    ).limit(3)

    RubyLLM::SearchResults.new(
      *documents.map { |doc| { title: doc.title, text: doc.content.truncate(500) } }
    )
  end
end
```

Return `RubyLLM::SearchResults` rather than a joined string and the model can cite each document it used. See [Citing Tool Results]({% link _core_features/citations.md %}#citing-tool-results-rag).

## Answering Agent

```ruby
class SupportWithDocsAgent < RubyLLM::Agent
  tools DocumentSearch
  instructions "Search for context before answering. Cite sources."
end

agent = SupportWithDocsAgent.new
agent.ask("What is our refund policy?").content
```

## Next Steps

* [Embeddings]({% link _core_features/embeddings.md %}) - Turn text into vectors for similarity search.
* [Memory]({% link _advanced/memory.md %}) - The same pattern over memories the agent writes itself.
* [Agentic Workflows]({% link _advanced/agentic-workflows.md %}) - Compose retrieval into larger orchestrations.
* [Tools]({% link _core_features/tools.md %}) - Build the retrieval tool and other capabilities.
* [Agents]({% link _advanced/agents.md %}) - Define the answering agent class.
