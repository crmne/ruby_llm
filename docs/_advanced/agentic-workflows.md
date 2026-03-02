---
layout: default
title: Agentic Workflows
nav_order: 5
description: Build workflow-oriented AI systems with plain Ruby orchestration, from routing and parallelization to RAG
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

* How to implement common workflow patterns with plain Ruby classes
* How to compose sequential, routing, parallel, and fan-in workflows
* How to use evaluator loops when output quality needs iteration
* How to implement RAG as part of a workflow

## Workflow Patterns

A workflow is just orchestration code that coordinates one or more agents. In practice, this is often a small Ruby class with a single public method.

### Sequential Workflow

Use this pattern when each step depends on the previous one.

```ruby
class ResearchAgent < RubyLLM::Agent
  model "{{ site.models.gemini_current }}"
  instructions "Given a topic, return concise, reliable key facts."
end

class WriterAgent < RubyLLM::Agent
  model "{{ site.models.anthropic_current }}"
  instructions "Given research notes, write a clear article."
end

class ResearchWriterWorkflow
  def create_article(topic)
    research = ResearchAgent.new.ask(topic).content
    WriterAgent.new.ask(research).content
  end
end

# Usage
workflow = ResearchWriterWorkflow.new
article = workflow.create_article("Ruby 3.3 features")
```

### Routing Workflow

Use this pattern when requests fall into clear categories that benefit from specialized agents or models.

```ruby
class CodeAgent < RubyLLM::Agent
  model "{{ site.models.best_for_code }}"
  instructions "You are a coding assistant. Be precise and practical."
end

class CreativeAgent < RubyLLM::Agent
  model "{{ site.models.best_for_creative }}"
  instructions "You are a creative writing assistant."
end

class FactualAgent < RubyLLM::Agent
  model "{{ site.models.best_for_factual }}"
  instructions "You are a factual assistant. Prioritize accuracy."
end

class TaskClassifierAgent < RubyLLM::Agent
  model "{{ site.models.openai_mini }}"
  instructions "Classify the request as one word only: code, creative, or factual."
end

class ModelRouterWorkflow
  def call(query)
    agent_for(query).new.ask(query).content
  end

  private

  def agent_for(query)
    case classify(query)
    when :code then CodeAgent
    when :creative then CreativeAgent
    when :factual then FactualAgent
    else FactualAgent
    end
  end

  def classify(query)
    TaskClassifierAgent.new.ask(query).content.downcase.to_sym
  end
end

# Usage
workflow = ModelRouterWorkflow.new
response = workflow.call("Write a Ruby function to parse JSON")
```

### Parallel Workflow

Use this pattern when independent analyses can run at the same time.

```ruby
require 'async'

class SentimentAgent < RubyLLM::Agent
  instructions "Given text, return one word sentiment: positive, negative, or neutral."
end

class SummaryAgent < RubyLLM::Agent
  instructions "Given text, summarize it in one concise sentence."
end

class KeywordAgent < RubyLLM::Agent
  instructions "Given text, extract exactly 5 relevant keywords."
end

class ParallelAnalyzer
  def analyze(text)
    Async do |task|
      sentiment = task.async { SentimentAgent.new.ask(text).content }
      summary = task.async { SummaryAgent.new.ask(text).content }
      keywords = task.async { KeywordAgent.new.ask(text).content }

      {
        sentiment: sentiment.wait,
        summary: summary.wait,
        keywords: keywords.wait
      }
    end.wait
  end
end

# Usage
analyzer = ParallelAnalyzer.new
insights = analyzer.analyze("Your text here...")
# All three analyses run concurrently
```

### Fan-Out/Fan-In Workflow

Use this pattern when multiple specialists produce outputs that are later synthesized.

```ruby
require 'async'

class SecurityReviewAgent < RubyLLM::Agent
  model "{{ site.models.anthropic_current }}"
  instructions "Given code, review it for security issues."
end

class PerformanceReviewAgent < RubyLLM::Agent
  model "{{ site.models.openai_tools }}"
  instructions "Given code, review it for performance issues."
end

class StyleReviewAgent < RubyLLM::Agent
  model "{{ site.models.openai_mini }}"
  instructions "Given code, review style against Ruby conventions."
end

class ReviewSynthesizerAgent < RubyLLM::Agent
  instructions "Given multiple code review reports, summarize prioritized findings."
end

class CodeReviewSystem
  def review_code(code)
    Async do |task|
      security = task.async { SecurityReviewAgent.new.ask(code).content }
      performance = task.async { PerformanceReviewAgent.new.ask(code).content }
      style = task.async { StyleReviewAgent.new.ask(code).content }

      ReviewSynthesizerAgent.new.ask(
        "security: #{security.wait}\n\n" \
        "performance: #{performance.wait}\n\n" \
        "style: #{style.wait}"
      ).content
    end.wait
  end
end

# Usage
reviewer = CodeReviewSystem.new
summary = reviewer.review_code("def calculate(x); x * 2; end")
```

### Evaluation Loop (Evaluator-Optimizer)

Use this pattern when you have clear quality criteria and want iterative refinement.

```ruby
class DraftAgent < RubyLLM::Agent
  instructions "Given a task, produce the best possible draft response."
end

class CriticAgent < RubyLLM::Agent
  schema do
    string :verdict, enum: ["pass", "revise"], description: "Whether the draft passes or needs changes"
    string :feedback, description: "Specific feedback for improvement"
  end
  instructions "Review the draft against the task and return a verdict and specific feedback."
end

class EvaluatorOptimizerWorkflow
  MAX_ROUNDS = 3

  def call(task)
    draft = DraftAgent.new.ask(task).content

    MAX_ROUNDS.times do
      verdict, feedback = review(task:, draft:)
      return draft if verdict == "pass"

      draft = revise(task:, draft:, feedback:)
    end

    draft
  end

  private

  def review(task:, draft:)
    result = CriticAgent.new.ask("Task:\n#{task}\n\nDraft:\n#{draft}").content
    [result.fetch("verdict"), result.fetch("feedback")]
  end

  def revise(task:, draft:, feedback:)
    DraftAgent.new.ask("Task:\n#{task}\n\nCurrent draft:\n#{draft}\n\nFeedback:\n#{feedback}").content
  end
end

# Usage
workflow = EvaluatorOptimizerWorkflow.new
final = workflow.call("Write a concise onboarding email for a new API customer")
```

## RAG as a Workflow Step

RAG is often just one step in a larger workflow: retrieve relevant context, then answer with that context.

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

### Retrieval Tool

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

### Answering Agent

```ruby
class SupportWithDocsAgent < RubyLLM::Agent
  tools DocumentSearch
  instructions "Search for context before answering. Cite sources."
end

# Usage
agent = SupportWithDocsAgent.new
response = agent.ask("What is our refund policy?").content
```

## Error Handling

For robust error handling in workflow code, leverage the patterns from the Tools guide:

* Return `{ error: "description" }` for recoverable errors the LLM might fix
* Raise exceptions for unrecoverable errors (missing config, service down)
* Use the retry middleware for transient failures

See the [Error Handling section in Tools]({% link _core_features/tools.md %}#error-handling-in-tools) for detailed patterns.

## Next Steps

* [Agents]({% link _core_features/agents.md %}) - Define reusable agent classes
* [Using Tools]({% link _core_features/tools.md %}) - Add capabilities and external actions
* [Scale with Async]({% link _advanced/async.md %}) - Run concurrent workflow steps
* [Error Handling]({% link _advanced/error-handling.md %}) - Build resilient systems
