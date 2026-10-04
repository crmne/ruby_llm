---
layout: default
title: Datasets
parent: Evaluations
nav_order: 1
description: Define reusable evaluation scenarios in YAML, JSON, JSONL, or application code
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* How to name and discover datasets.
* How to pass structured inputs and optional references.
* How to load reviewed examples from your application.

## Datasets

Each case has a unique `name` and `inputs`. `expected_output` and `metadata` are optional. Inputs and reference answers can be strings, numbers, booleans, arrays, objects, or null. An explicit null reference differs from an omitted reference.

The data fields follow Pydantic Evals' case format. Evaluator declarations in external files are not imported; declare them in Ruby. Put labels used to measure the evaluator's accuracy in a separate file. All case metadata is visible to the evaluator. Case names identify reports and tests; they are not sent to the evaluator.

Discovery accepts `.yml`, `.yaml`, `.json`, and `.jsonl`. Multiple matching files raise an error. YAML and JSON accept either a `cases` object as above or an array of cases. JSONL contains one case per line. YAML loads without Ruby object tags or aliases.

Override discovery with a path:

```ruby
dataset "evals/support_regressions.json"
```

Or return cases from application code:

```ruby
dataset do
  ReviewedAnswer.all.map do |answer|
    RubyLLM::Evaluation::Case.new(
      name: answer.id,
      inputs: answer.question,
      expected_output: answer.reviewed_answer
    )
  end
end
```

You can also pass `dataset:` to `run`. The runner loads the dataset once and creates a fresh evaluation instance and mutable copy of the input for each case and repetition. Reference evidence remains frozen.

## Structured Inputs

`inputs` is one value passed to `perform`. It can contain several fields:

```yaml
cases:
  - name: unopened_return
    inputs:
      question: Can I return this item?
      days_since_purchase: 14
      unopened: true
    expected_output: The item can be returned within 30 days.
```

Your method chooses how to use that data:

```ruby
def perform(input)
  ReturnsAgent.new.ask(JSON.generate(input))
end
```

The method parameter can have any Ruby name, such as `question`, `document`, or `scenario`. Inside `assertions`, `input` exposes that case's inputs. The plural `inputs` in dataset files is the portable field name, not a requirement to provide multiple arguments.

A list of user turns is also a valid input. See [Conversations and Tools]({% link _advanced/evaluation-conversations.md %}).

## References Are Optional

Use `expected_output` when you have a reviewed answer or structured result. Semantic evaluators can accept equivalent wording. Ruby's `assert_equal expected_output, output` requires equality.

Some properties need no reference answer. You can check that an agent cites its sources, does not execute an unapproved change, or asks for missing information using criteria and Ruby assertions alone. Keep any additional reference evidence in `metadata`; it is visible to evaluators.
