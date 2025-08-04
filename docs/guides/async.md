---
layout: default
title: Scale with Async
parent: Guides
nav_order: 10
permalink: /guides/async
description: Handle hundreds of concurrent AI requests on modest hardware. Ruby's async ecosystem meets AI.
---

# Scale with Async
{: .no_toc }

Scale your AI features without breaking the bank. Efficient concurrency on a single server.
{: .fs-6 .fw-300 }

## Table of contents
{: .no_toc .text-delta }

1. TOC
{:toc}

---

After reading this guide, you will know:

* Why LLM applications benefit dramatically from async Ruby
* How RubyLLM automatically works with async
* How to perform concurrent LLM operations
* How to use async-job for background processing
* How to handle rate limits with semaphores

For a deeper dive into Async, Threads, and why Async Ruby is perfect for LLM applications, including benchmarks and architectural comparisons, check out my blog post: [Async Ruby is the Future of AI Apps (And It's Already Here)](https://paolino.me/async-ruby-is-the-future/)

## Why Async for LLMs?

LLM operations are unique - they take 5-60 seconds and spend 99% of that time waiting for tokens to stream back. Using traditional thread-based job queues (Sidekiq, GoodJob, SolidQueue) for LLM operations creates a problem:

```ruby
# With 25 worker threads configured:
class ChatResponseJob < ApplicationJob
  def perform(conversation_id, message)
    # This occupies 1 of your 25 slots for 30-60 seconds...
    response = RubyLLM.chat.ask(message)
    # ...even though the thread is 99% idle
  end
end

# Your 26th user? They're waiting in line.
```

Async solves this by using fibers instead of threads:
- **Threads**: OS-managed, preemptive, heavy (each needs its own database connection)
- **Fibers**: Userspace, cooperative, lightweight (thousands can share a few connections)

## How RubyLLM Works with Async

The beautiful part: RubyLLM automatically becomes non-blocking when used in an async context. No configuration needed.

```ruby
require 'async'
require 'ruby_llm'

# This is all you need for concurrent LLM calls
Async do
  10.times.map do
    Async do
      # RubyLLM automatically becomes non-blocking
      # because Net::HTTP knows how to yield to fibers
      message = RubyLLM.chat.ask "Explain quantum computing"
      puts message.content
    end
  end.map(&:wait)
end
```

This works because RubyLLM uses `Net::HTTP`, which cooperates with Ruby's fiber scheduler.

## Concurrent Operations

### Multiple Chat Requests

Process multiple questions concurrently:

```ruby
require 'async'
require 'ruby_llm'

def process_questions(questions)
  Async do
    tasks = questions.map do |question|
      Async do
        response = RubyLLM.chat.ask(question)
        { question: question, answer: response.content }
      end
    end

    # Wait for all tasks and return results
    tasks.map(&:wait)
  end.result
end

questions = [
  "What is Ruby?",
  "Explain metaprogramming",
  "What are symbols?"
]

results = process_questions(questions)
results.each do |result|
  puts "Q: #{result[:question]}"
  puts "A: #{result[:answer]}\n\n"
end
```

### Batch Embeddings

Generate embeddings efficiently:

```ruby
def generate_embeddings(texts, batch_size: 100)
  Async do
    embeddings = []

    texts.each_slice(batch_size) do |batch|
      task = Async do
        response = RubyLLM.embed(batch)
        response.vectors
      end
      embeddings.concat(task.wait)
    end

    # Return text-embedding pairs
    texts.zip(embeddings)
  end.result
end

texts = ["Ruby is great", "Python is good", "JavaScript is popular"]
pairs = generate_embeddings(texts)
pairs.each do |text, embedding|
  puts "#{text}: #{embedding[0..5]}..." # Show first 6 dimensions
end
```

### Parallel Analysis

Run multiple analyses concurrently:

```ruby
def analyze_document(content)
  Async do
    summary_task = Async do
      RubyLLM.chat.ask("Summarize in one sentence: #{content}")
    end

    sentiment_task = Async do
      RubyLLM.chat.ask("Is this positive or negative: #{content}")
    end

    {
      summary: summary_task.wait.content,
      sentiment: sentiment_task.wait.content
    }
  end.result
end

result = analyze_document("Ruby is an amazing language with a wonderful community!")
puts "Summary: #{result[:summary]}"
puts "Sentiment: #{result[:sentiment]}"
```

## Background Processing with `Async::Job`

The real power comes from using `Async::Job` for background processing. Unlike traditional thread-based job processors that get blocked during long LLM operations, `Async::Job` uses fibers to handle thousands of concurrent jobs efficiently.

### Setup with Falcon (Recommended)

Falcon is a Ruby application server built on fibers. With Falcon, async just works™.

```ruby
# Gemfile
gem 'falcon'
gem 'async-job-adapter-active_job'
```

```ruby
# config/application.rb
config.active_job.queue_adapter = :async_job
```

```ruby
# config/initializers/async_job_adapter.rb
require 'async/job/processor/inline'

Rails.application.configure do
  config.async_job.define_queue "default" do
    dequeue Async::Job::Processor::Inline
  end
end
```

That's it. Start your server with `bin/dev` and enjoy concurrent job processing. Your jobs now run concurrently without any additional infrastructure. One process, thousands of concurrent LLM operations.

### Note on Puma

Still using Puma? You'll need a Redis-backed job processor for concurrent execution:

```ruby
# Gemfile additions
gem 'async-job-processor-redis'

# config/initializers/async_job_adapter.rb
require 'async/job/processor/redis'

Rails.application.configure do
  config.async_job.define_queue "default" do
    dequeue Async::Job::Processor::Redis
  end
end
```

Then run these processes:

**Option 1: Add to Procfile.dev (Recommended)**
```ruby
# Procfile.dev
web: bin/rails server
css: bin/rails tailwindcss:watch  # or your CSS processor
redis: redis-server
async_job: bundle exec async-job-adapter-active_job-server
```

Then just run `bin/dev` to start everything.

**Option 2: Separate terminals**
```bash
# Terminal 1: Redis
redis-server

# Terminal 2: Job processor (auto-scales to CPU cores)
bundle exec async-job-adapter-active_job-server

# Terminal 3: Rails
bin/dev
```

This setup requires more infrastructure but still delivers the concurrency benefits of async for your LLM operations.

### Your Jobs Work Unchanged

Here's the key insight: you don't need to modify your jobs at all. `Async::Job` runs each job inside an async context automatically:

```ruby
class DocumentAnalyzerJob < ApplicationJob
  def perform(document_id)
    document = Document.find(document_id)

    # This automatically runs in an async context!
    # No need to wrap in Async blocks
    response = RubyLLM.chat.ask("Analyze: #{document.content}")

    document.update!(
      analysis: response.content,
      analyzed_at: Time.current
    )
  end
end
```

### Mixing Job Adapters: Best of Both Worlds

You don't have to go all-in. Use async-job only for LLM operations while keeping your existing job processor for everything else:

```ruby
# Keep your existing adapter as default
config.active_job.queue_adapter = :solid_queue  # or :sidekiq, :good_job, etc.

# Base class for all LLM jobs
class LLMJob < ApplicationJob
  self.queue_adapter = :async_job
end

# LLM jobs inherit the async adapter
class ChatResponseJob < LLMJob
  def perform(conversation_id, message)
    # Runs with async-job - perfect for streaming
    response = RubyLLM.chat.ask(message)
    # ...
  end
end

# Regular jobs use your default adapter
class ImageProcessingJob < ApplicationJob
  def perform(image_id)
    # Runs with solid_queue - better for CPU work
    # ...
  end
end
```

This approach lets you optimize each job type for its workload without disrupting your existing infrastructure.

## Rate Limiting with Semaphores

When making many concurrent requests, use a semaphore to respect rate limits:

```ruby
require 'async'
require 'async/semaphore'

class RateLimitedProcessor
  def initialize(max_concurrent: 10)
    @semaphore = Async::Semaphore.new(max_concurrent)
  end

  def process_items(items)
    Async do
      items.map do |item|
        Async do
          # Only 10 items processed at once
          @semaphore.acquire do
            response = RubyLLM.chat.ask("Process: #{item}")
            { item: item, result: response.content }
          end
        end
      end.map(&:wait)
    end.result
  end
end

# Usage
processor = RateLimitedProcessor.new(max_concurrent: 5)
items = ["Item 1", "Item 2", "Item 3", "Item 4", "Item 5", "Item 6"]
results = processor.process_items(items)
```

The semaphore ensures only 5 requests run concurrently, preventing rate limit errors while still maintaining high throughput.

## Summary

Key takeaways:

- LLM operations are perfect for async (99% waiting for I/O)
- RubyLLM automatically works with async - no configuration needed
- Use async-job for LLM background jobs without changing your job code
- Use semaphores to manage rate limits
- Keep thread-based processors for CPU-intensive work

The combination of RubyLLM and async Ruby gives you the ability to handle thousands of concurrent AI conversations on modest hardware - something that would require massive infrastructure with traditional thread-based approaches.

Ready to dive deeper? Read the full architectural comparison: [Async Ruby is the Future of AI Apps](https://paolino.me/async-ruby-is-the-future/)