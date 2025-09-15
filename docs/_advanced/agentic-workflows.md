---
layout: default
title: Agentic Workflows
nav_order: 5
description: Build intelligent agents that route between models, implement RAG, and coordinate multiple AI systems
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

* How to build a model router that selects the best AI for each task
* How to implement RAG with PostgreSQL and pgvector
* How to run multiple agents in parallel with async
* How to create multi-agent systems with specialized roles

## Model Routing

Different models excel at different tasks. A router can analyze requests and delegate to the most appropriate model.

```ruby
class ModelRouter < RubyLLM::Tool
  description "Routes requests to the optimal model"
  param :query, desc: "The user's request"

  def execute(query:)
    task_type = classify_task(query)

    case task_type
    when :code
      RubyLLM.chat(model: '{{ site.models.best_for_code }}').ask(query).content
    when :creative
      RubyLLM.chat(model: '{{ site.models.best_for_creative }}').ask(query).content
    when :factual
      RubyLLM.chat(model: '{{ site.models.best_for_factual }}').ask(query).content
    else
      RubyLLM.chat.ask(query).content
    end
  end

  private

  def classify_task(query)
    classifier = RubyLLM.chat(model: '{{ site.models.openai_mini }}')
                     .with_instructions("Classify: code, creative, or factual. One word only.")
    classifier.ask(query).content.downcase.to_sym
  end
end

# Usage
chat = RubyLLM.chat.with_tool(ModelRouter)
response = chat.ask "Write a Ruby function to parse JSON"
```

## RAG with PostgreSQL

Use pgvector and the neighbor gem for production-ready RAG implementations.

### Setup

```ruby
# Gemfile
gem 'neighbor'
gem 'ruby_llm'

# Generate migration for pgvector
rails generate neighbor:vector
rails db:migrate

# Create documents table
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

### Document Model with Embeddings

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

### RAG Tool

```ruby
class DocumentSearch < RubyLLM::Tool
  description "Searches knowledge base for relevant information"
  param :query, desc: "Search query"

  def execute(query:)
    # Generate embedding for query
    embedding = RubyLLM.embed(query).vectors

    # Find similar documents using neighbor
    documents = Document.nearest_neighbors(
      :embedding,
      embedding,
      distance: "euclidean"
    ).limit(3)

    # Return formatted context
    documents.map { |doc|
      "#{doc.title}: #{doc.content.truncate(500)}"
    }.join("\n\n---\n\n")
  end
end

# Usage
chat = RubyLLM.chat
      .with_tool(DocumentSearch)
      .with_instructions("Search for context before answering. Cite sources.")

response = chat.ask "What is our refund policy?"
```

## Multi-Agent Systems

### Researcher and Writer Team

```ruby
class ResearchAgent < RubyLLM::Tool
  description "Researches topics"
  param :topic, desc: "Topic to research"

  def execute(topic:)
    RubyLLM.chat(model: '{{ site.models.gemini_current }}')
           .ask("Research #{topic}. List key facts.")
           .content
  end
end

class WriterAgent < RubyLLM::Tool
  description "Writes content based on research"
  param :research, desc: "Research findings"

  def execute(research:)
    RubyLLM.chat(model: '{{ site.models.anthropic_current }}')
           .ask("Write an article:\n#{research}")
           .content
  end
end

# Coordinator uses both tools
coordinator = RubyLLM.chat.with_tools(ResearchAgent, WriterAgent)
article = coordinator.ask("Create an article about Ruby 3.3 features")
```

### Parallel Agent Execution with Async

```ruby
require 'async'

class ParallelAnalyzer
  def analyze(text)
    results = {}

    Async do |task|
      task.async do
        results[:sentiment] = RubyLLM.chat
          .ask("Sentiment of: #{text}. One word: positive/negative/neutral")
          .content
      end

      task.async do
        results[:summary] = RubyLLM.chat
          .ask("Summarize in one sentence: #{text}")
          .content
      end

      task.async do
        results[:keywords] = RubyLLM.chat
          .ask("Extract 5 keywords: #{text}")
          .content
      end
    end

    results
  end
end

# Usage
analyzer = ParallelAnalyzer.new
insights = analyzer.analyze("Your text here...")
# All three analyses run concurrently
```

### Supervisor Pattern

```ruby
require 'async'

class CodeReviewSystem
  def review_code(code)
    reviews = {}

    Async do |task|
      # Run reviews in parallel
      task.async do
        reviews[:security] = RubyLLM.chat(model: '{{ site.models.anthropic_current }}')
          .ask("Security review:\n#{code}")
          .content
      end

      task.async do
        reviews[:performance] = RubyLLM.chat(model: '{{ site.models.openai_tools }}')
          .ask("Performance review:\n#{code}")
          .content
      end

      task.async do
        reviews[:style] = RubyLLM.chat(model: '{{ site.models.openai_mini }}')
          .ask("Style review (Ruby conventions):\n#{code}")
          .content
      end
    end.wait # Block automatically waits for all child tasks

    # Synthesize findings after all reviews complete
    RubyLLM.chat.ask(
      "Summarize these code reviews:\n" +
      reviews.map { |type, review| "#{type}: #{review}" }.join("\n\n")
    ).content
  end
end

# Usage
reviewer = CodeReviewSystem.new
summary = reviewer.review_code("def calculate(x); x * 2; end")
# All three reviews run concurrently, then synthesized
```

## Error Handling

For robust error handling in agent workflows, leverage the patterns from the Tools guide:

* Return `{ error: "description" }` for recoverable errors the LLM might fix
* Raise exceptions for unrecoverable errors (missing config, service down)
* Use the retry middleware for transient failures

See the [Error Handling section in Tools]({% link _core_features/tools.md %}#error-handling-in-tools) for detailed patterns.

## Next Steps

* [Using Tools]({% link _core_features/tools.md %}) - Learn the fundamentals of tool usage
* [Rails Integration]({% link _advanced/rails.md %}) - Build agent workflows in Rails
* [Scale with Async]({% link _advanced/async.md %}) - Deep dive into async patterns
* [Error Handling]({% link _advanced/error-handling.md %}) - Build resilient systems