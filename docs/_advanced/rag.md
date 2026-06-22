---
layout: default
title: Retrieval-Augmented Generation (RAG)
parent: "Agentic Workflows"
nav_order: 2
description: Retrieve relevant context from your own documents, then answer with that context
---

# {{ page.title }}
{: .no_toc }

{{ page.description }}
{: .fs-6 .fw-300 }

## Table of contents
{: .no_toc .text-delta }

1. TOC
{:toc}

---

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

# Generate migration for pgvector
bin/rails generate neighbor:vector
bin/rails db:migrate

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
  param :query, desc: "Search query"

  def execute(query:)
    embedding = RubyLLM.embed(query).vectors

    documents = Document.nearest_neighbors(
      :embedding,
      embedding,
      distance: "euclidean"
    ).limit(3)

    documents.map do |doc|
      "#{doc.title}: #{doc.content.truncate(500)}"
    end.join("\n\n---\n\n")
  end
end
```

## Answering Agent

```ruby
class SupportWithDocsAgent < RubyLLM::Agent
  tools DocumentSearch
  instructions "Search for context before answering. Cite sources."
end

agent = SupportWithDocsAgent.new
response = agent.ask("What is our refund policy?").content
```

## Next Steps

* [Embeddings]({% link _core_features/embeddings.md %}) - Turn text into vectors for similarity search.
* [Agentic Workflows]({% link _advanced/agentic-workflows.md %}) - Compose retrieval into larger orchestrations.
* [Tools]({% link _core_features/tools.md %}) - Build the retrieval tool and other capabilities.
* [Agents]({% link _advanced/agents.md %}) - Define the answering agent class.
