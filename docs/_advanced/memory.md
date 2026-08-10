---
layout: default
title: Memory
parent: "Agents"
nav_order: 4
description: Give agents short-term memory through the transcript and long-term memory your app owns, recalled by meaning.
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

* Why the transcript already is your agent's short-term memory.
* How to compact long conversations without losing what the user sees.
* How to store long-term memories as rows with embeddings.
* How to let the agent save its own memories with a tool.
* How to recall memories by meaning, as a tool or as instructions.

## Short-Term Memory Is the Transcript

Within a conversation, memory needs no machinery: the chat sends its whole message history with every request, and with [`acts_as_chat`]({% link _advanced/rails-persistence.md %}) that history is rows in your database. An agent reloaded tomorrow remembers everything it was told today.

When the transcript grows past what you want to send, compact it with [transcript replacement]({% link _core_features/chat.md %}#advanced-replacing-the-llm-transcript): summarize the old turns, keep the recent ones verbatim, and show the model the compacted version while your users keep the full history. Memory of the conversation is a view of the conversation, not a second store.

## A Memories Table

Long-term memory, the kind that survives across conversations, is your application's data: rows with embeddings, exactly like [RAG]({% link _advanced/rag.md %}) but written by the agent instead of imported from documents.

```ruby
# Gemfile
gem 'neighbor'

class CreateMemories < ActiveRecord::Migration[7.1]
  def change
    create_table :memories do |t|
      t.references :user, null: false
      t.text :content, null: false
      t.vector :embedding, limit: 1536 # OpenAI embedding size
      t.timestamps
    end

    add_index :memories, :embedding, using: :hnsw, opclass: :vector_l2_ops
  end
end

class Memory < ApplicationRecord
  belongs_to :user
  has_neighbors :embedding

  before_save :generate_embedding, if: :content_changed?

  private

  def generate_embedding
    self.embedding = RubyLLM.embed(content).vectors
  end
end
```

## Remembering

Give the agent a tool and let it decide what is worth keeping. The instructions carry the policy; the tool carries the mechanism:

```ruby
class Remember < RubyLLM::Tool
  description "Saves a lasting fact about the user for future conversations"
  parameter :fact, description: "One self-contained sentence worth remembering"

  def initialize(user)
    @user = user
  end

  def execute(fact:)
    @user.memories.find_or_create_by!(content: fact)
    "Remembered."
  end
end
```

`find_or_create_by!` keeps the tool idempotent, so a [resumed job]({% link _advanced/durable-agents.md %}) that runs it twice stores one memory.

## Recalling

Recall works two ways, and they compose. As a tool, the agent searches its memories when it decides it needs them:

```ruby
class Recall < RubyLLM::Tool
  description "Searches lasting memories about the user"
  parameter :query, description: "What to look for"

  def initialize(user)
    @user = user
  end

  def execute(query:)
    embedding = RubyLLM.embed(query).vectors
    memories = @user.memories.nearest_neighbors(:embedding, embedding, distance: "euclidean").limit(5)
    memories.map(&:content).join("\n")
  end
end
```

As instructions, the freshest memories ride along on every request, no tool round-trip needed:

```ruby
class Assistant < RubyLLM::Agent
  inputs :user

  tools { [Remember.new(user), Recall.new(user)] }

  instructions do
    memories = user.memories.order(updated_at: :desc).limit(10).pluck(:content)
    "You are #{user.name}'s assistant.\n\nWhat you remember:\n#{memories.join("\n")}"
  end
end
```

A few recent memories in the instructions cover the common case cheaply; the `Recall` tool covers the long tail by meaning. Forgetting is `memory.destroy`.

## Keep It Honest

There is no memory framework here, and that is the point: two tools, one table, and the database features you already run. Scoping is your ordinary Rails scoping (`user.memories`, never a global store), review UIs are ordinary CRUD, and retention policy is a `where` clause. When a framework offers you "semantic memory" as an abstraction, this is what is inside it.

## Next Steps

* [Retrieval-Augmented Generation (RAG)]({% link _advanced/rag.md %}) - The same embeddings pattern over imported documents.
* [Agents]({% link _advanced/agents.md %}) - The `inputs` and instructions machinery used above.
* [Chat]({% link _core_features/chat.md %}) - Transcript replacement for compaction.
* [Embeddings]({% link _core_features/embeddings.md %}) - Turning text into vectors.
