---
layout: default
title: Scale with Async
nav_order: 5
description: Run AI jobs with Solid Queue fiber workers, use Async for concurrent Ruby calls, and choose Async::Job for higher throughput.
redirect_from:
  - /guides/async
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* Why AI calls benefit from concurrent execution.
* How to use Solid Queue fiber workers for Rails jobs.
* How to mix fiber and thread workers for different queues.
* When to consider Async::Job for higher throughput.
* How to run independent RubyLLM calls with Async and limit concurrency.

## Why Async for LLMs?

AI calls spend much of their time waiting for a provider. Ruby fibers let other work progress during that wait. Use concurrency when calls are independent, such as answering several questions or processing separate documents.

## Background Jobs with Solid Queue

For Rails applications, start with **Solid Queue 1.6 or later**. Fiber workers let many AI jobs wait for provider responses while keeping Solid Queue's persisted jobs, retries, and Mission Control integration. Your job's RubyLLM calls stay the same.

### Enable Fiber Workers

Upgrade Solid Queue and add Async to your Gemfile, then run `bundle install`:

```ruby
# Gemfile
gem "solid_queue", "~> 1.6"
gem "async"
```

Enable fiber isolation in your Rails application:

```ruby
# config/application.rb
config.active_job.queue_adapter = :solid_queue
config.active_support.isolation_level = :fiber
```

The isolation setting keeps Rails execution state separate for each fiber. It applies to the whole application and is required for Solid Queue fiber workers.

In `config/queue.yml`, replace `threads:` with `fibers:` for the worker that handles AI jobs. You can keep thread workers for your other queues:

```yaml
# config/queue.yml
production:
  dispatchers:
    - polling_interval: 1
      batch_size: 500
  workers:
    - queues: llm
      fibers: 50
    - queues: default
      threads: 3
```

Adapt the workers in your existing configuration, keeping any other queues, environments, and dispatcher settings you use. Choose `threads` or `fibers` for each worker, and keep their queue names separate so a thread worker does not also claim the AI jobs.

Route a job to the fiber worker with `queue_as`:

```ruby
class DocumentAnalyzerJob < ApplicationJob
  queue_as :llm

  def perform(document_id)
    document = Document.find(document_id)
    response = RubyLLM.chat.ask "Summarize this document", with: document.file
    document.update!(summary: response.content)
  end
end

DocumentAnalyzerJob.perform_later(document.id)
```

Start the workers with `bin/jobs`. Solid Queue supplies the Async context, so the job does not need an `Async` block. This works with Puma or Falcon as your web server.

### What the Fiber Count Means

`fibers: 50` allows up to 50 jobs in flight in that worker. Jobs run as fibers on one reactor thread, yielding while RubyLLM waits for network I/O. Execution fibers are created as jobs arrive; the setting does not preallocate 50 idle fibers.

The choice belongs to each worker entry, which can serve one queue or a list of queues. Put AI requests and streaming on fiber workers. Keep CPU-heavy work and libraries that block the reactor on separate thread workers or processes.

With the default supervisor mode, `processes: 2` creates two worker processes with their own limits, so `fibers: 50` allows up to 100 jobs across them. This is separate from the supervisor's `--mode async` option; you do not need that option to use fiber workers.

### Database Connections

On Rails 7.2+, Solid Queue recommends starting with 3–5 queue database connections per fiber worker process. The pool does not need to match the number of jobs waiting on provider I/O. Size application database pools for the database work your jobs actually perform, and avoid holding a transaction or leased connection open across an AI call. Rails 7.1 needs more conservative pool sizing.

See Solid Queue's [worker configuration](https://github.com/rails/solid_queue#configuration) and [Fiber-Safe ActiveRecord Connections]({% link _advanced/rails-advanced-config.md %}#fiber-safe-activerecord-connections-for-asyncfiber-workloads) for details.

Fiber mode was contributed by RubyLLM's author, Carmine Paolino, and shipped in [Solid Queue 1.6.0](https://github.com/rails/solid_queue/releases/tag/v1.6.0). His post, [Making the Rails Default Job Queue Fiber-Based](https://paolino.me/solid-queue-doesnt-need-a-thread-per-job/), explains the implementation and tradeoffs.

## How RubyLLM Works with Async

Wrap independent calls in Async tasks:

```ruby
require 'async'
require 'ruby_llm'

questions = ["What is a Ruby block?", "What is a Ruby symbol?", "What is a module?"]

answers = Async do |task|
  questions.map do |question|
    task.async { RubyLLM.chat.ask(question).content }
  end.map(&:wait)
end.wait
```

RubyLLM's default HTTP adapter cooperates with Ruby's fiber scheduler. Each task above creates its own chat, so the conversations stay independent. See Async's [task guide](https://socketry.github.io/async/guides/tasks/index.html) for task creation and waiting.

## Concurrent Operations

### Multiple Chat Requests

Collect each question with its answer:

```ruby
results = Async do |task|
  questions.map do |question|
    task.async do
      response = RubyLLM.chat.ask(question)
      { question: question, answer: response.content }
    end
  end.map(&:wait)
end.wait
```

### Concurrent Embeddings

Generate embeddings efficiently:

```ruby
def generate_embeddings(texts, batch_size: 100)
  Async do
    tasks = texts.each_slice(batch_size).map do |batch|
      Async { RubyLLM.embed(batch).vectors }
    end

    texts.zip(tasks.flat_map(&:wait))
  end.result
end

texts = ["Ruby is great", "Python is good", "JavaScript is popular"]
pairs = generate_embeddings(texts)
pairs.each do |text, embedding|
  puts "#{text}: #{embedding[0..5]}..." # Show first 6 dimensions
end
```

For discounted provider-side batches, see [Batching Embeddings]({% link _advanced/batches.md %}#batching-embeddings).

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

Consider `Async::Job` when throughput is the priority and you are happy to operate a Redis-backed job processor. In Carmine's [queue benchmark](https://github.com/crmne/solid_queue_bench#asyncjob-comparison), Async::Job with Redis achieved higher throughput than Solid Queue fiber workers on the tested workloads, including RubyLLM streaming with Turbo broadcasts. Those results use the April 2026 Solid Queue PR implementation; they are a backend comparison, not measurements of the final 1.6 release.

For most Rails applications, Solid Queue fiber mode is the starting point. Benchmark your workload with Async::Job if you need more throughput, and review its job storage, failure handling, and monitoring options for your deployment.

### Add a Redis Queue

Add the adapter and Redis processor to your Gemfile, then run `bundle install`:

```ruby
# Gemfile
gem "async-job-adapter-active_job"
gem "async-job-processor-redis"
```

Define a queue:

```ruby
# config/initializers/async_job.rb
require "async/job/processor/redis"

Rails.application.configure do
  config.async_job.define_queue "llm" do
    dequeue Async::Job::Processor::Redis
  end
end
```

You can select the adapter per job while the rest of the application keeps Solid Queue:

```ruby
class DocumentAnalyzerJob < ApplicationJob
  self.queue_adapter = :async_job
  queue_as :llm

  def perform(document_id)
    document = Document.find(document_id)
    response = RubyLLM.chat.ask "Summarize this document", with: document.file
    document.update!(summary: response.content)
  end
end
```

With Redis running, start the separate processor:

```bash
bundle exec async-job-adapter-active_job-server
```

The processor supplies the Async context independently of your web server. For Redis connection settings, inline execution with Falcon, and deployment options, follow the adapter's [documentation](https://github.com/socketry/async-job-adapter-active_job#usage).

## Rate Limiting with Semaphores

A semaphore limits the number of requests in flight:

```ruby
require 'async'
require 'async/semaphore'

answers = Async do
  semaphore = Async::Semaphore.new(5)
  questions.map do |question|
    semaphore.async { RubyLLM.chat.ask(question).content }
  end.map(&:wait)
end.wait
```

At most five calls run at once. That limits concurrency, but does not enforce a requests-per-minute or tokens-per-minute quota. Keep [retry and rate-limit handling]({% link _advanced/error-handling.md %}#automatic-retries) in place. See the [Semaphore reference](https://socketry.github.io/async/source/Async/Semaphore/index.html).

For Active Record work inside fibers, follow [Fiber-Safe ActiveRecord Connections]({% link _advanced/rails-advanced-config.md %}#fiber-safe-activerecord-connections-for-asyncfiber-workloads).

For more on fibers, threads, and processes, read [Ruby Concurrency: What Actually Happens](https://paolino.me/ruby-concurrency-what-actually-happens/).

## Next Steps

* [Batches]({% link _advanced/batches.md %}) - Provider-side batching at a discount when nobody is waiting.
* [Streaming Responses]({% link _core_features/streaming.md %})
* [Rails Integration]({% link _advanced/rails.md %})
