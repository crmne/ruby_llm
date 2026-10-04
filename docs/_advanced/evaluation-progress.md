---
layout: default
title: Progress and Monitoring
parent: Evaluations
nav_order: 5
description: Show evaluation progress in your application, save trials as they finish, and trace runs
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* How to receive each trial as it finishes.
* How to run evaluations from a background job and show progress.
* Which instrumentation events an evaluation emits.
* How evaluation runs appear in OpenTelemetry traces.

## Receiving Trials as They Finish

A long evaluation can take minutes. Pass a block to `run` to handle each trial as soon as it finishes:

```ruby
report = SupportEvaluation.run do |trial|
  puts "#{trial.test_case.name}: #{trial.status}"
end
```

The block receives the same `Evaluation::Trial` the final report holds, after its assertions, grading, and teardown are done. Failed and errored trials are passed too. The next trial starts when the block returns. If the block raises, the run stops and the exception reaches your code.

## Showing Progress in Your Application

Run the evaluation in a background job and save each trial as it arrives. RubyLLM does not need a schema for this; use whatever records suit your application. This job uses an `EvaluationRun` model that has many trials, with JSON columns for the data:

```ruby
class EvaluationJob < ApplicationJob
  def perform(evaluation_run)
    cases = SupportEvaluation.cases
    evaluation_run.update!(total: cases.size)

    report = SupportEvaluation.run(dataset: cases, id: evaluation_run.id) do |trial|
      evaluation_run.trials.create!(
        case_name: trial.test_case.name,
        repetition: trial.repetition,
        status: trial.status,
        data: trial.to_h
      )
    end

    evaluation_run.update!(report: report.to_h)
  end
end
```

A few details make this work:

* Loading the cases first and passing them as `dataset:` keeps the total you display equal to what actually runs. With `repetitions:`, the total is the number of cases multiplied by the repetitions. With `only:`, pass the same selection to `cases`.
* `id:` gives the run your record's ID. It becomes `report.id` and appears on every request the run makes. Use a unique ID for each attempt. Without one, RubyLLM generates a UUID.
* `trial.to_h` includes the case, the evidence, the status, every verdict and reason, errors, duration, tokens, and costs. `report.to_h` adds the run ID, the criteria, and the summary counts.
* Saving each trial as it arrives keeps partial results if the job is interrupted.

To update the page live, broadcast each saved trial with Turbo Streams from an `after_create_commit` callback, as you would for any other record.

## Instrumentation Events

Monitoring tools can follow evaluations through the [instrumentation API]({% link _advanced/instrumentation.md %}) without changes to your evaluation classes. In Rails:

```ruby
ActiveSupport::Notifications.subscribe("evaluation_trial.ruby_llm") do |event|
  payload = event.payload
  Rails.logger.info(
    evaluation_id: payload[:evaluation_id],
    completed: payload[:completed],
    total: payload[:total],
    status: payload[:trial].status
  )
end
```

| Event | When | Payload |
| --- | --- | --- |
| `evaluation_trial.ruby_llm` | After each trial, before the progress block | `evaluation_id`, `evaluation_name`, `total`, `completed`, `case`, `repetition`, `trial` |
| `evaluation.ruby_llm` | When the run finishes | `evaluation_id`, `evaluation_name`, `total`, `completed`, `started_at`, `report` |

`completed` counts finished trials, including failures and errors, starting at one. Both events wrap their work, so Rails reports their duration and any exception. If a progress block stops the run, `evaluation.ruby_llm` still reports how many trials completed, but has no `report`. Configuration errors, such as a missing `expected_output`, raise before either event starts.

Progress is reported between trials. To follow tokens and tool calls inside a trial, use the ordinary [chat callbacks]({% link _core_features/chat-callbacks.md %}) and instrumentation events.

## Tracing

Each trial runs as a [workflow]({% link _advanced/instrumentation.md %}#workflows-and-steps) named after the evaluation class, with two steps:

* `perform` covers `setup`, `perform`, and `assertions`.
* `evaluate` covers the grading requests.

Every trial in a run shares the run's `id:` as its workflow ID and records the case name and repetition as workflow metadata. With [OpenTelemetry]({% link _advanced/opentelemetry.md %}) enabled, each trial appears as its own trace:

```text
invoke_workflow SupportEvaluation
├── ruby_llm.workflow_step perform
│   ├── chat {{ site.models.default_chat }}
│   └── execute_tool lookup_order
└── ruby_llm.workflow_step evaluate
    └── chat {{ site.models.default_chat }}
```

Search by the `ruby_llm.workflow.id` attribute to find every trial of one run.
