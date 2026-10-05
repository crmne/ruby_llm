---
layout: default
title: Evaluation Datasets
parent: Evaluations
nav_order: 1
description: Define evaluation cases in YAML, JSON, JSONL, or application code
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* Which fields a case has.
* Which file formats RubyLLM loads and where it finds them.
* How to pass structured inputs to `perform`.
* How to build cases from your database.

## Cases

A dataset is a list of cases. Each case describes one scenario:

```yaml
cases:
  - name: unopened_return
    inputs: Can I return an unopened item after 14 days?
    expected_output: Yes, unopened items can be returned within 30 days.
    metadata:
      category: returns
```

| Field | Required | Purpose |
| --- | --- | --- |
| `name` | Yes | Identifies the case in reports and tests. Must be unique. |
| `inputs` | Yes | The value passed to `perform`. |
| `expected_output` | For correctness | The reference answer. |
| `metadata` | No | Extra context, such as a category or the source documents. |

The evaluator sees `inputs`, `expected_output`, and `metadata`, but not `name`. Values can be strings, numbers, booleans, arrays, objects, or null.

`expected_output` is required by the default correctness check. An evaluation with its own [criteria]({% link _advanced/evaluation-evaluators.md %}) or with only Ruby assertions can leave it out. An explicit `null` is a reference answer of null, which is different from leaving the field out.

## File Formats

RubyLLM looks for a file named after the class with one of these extensions: `.yml`, `.yaml`, `.json`, or `.jsonl`. Having more than one raises an error.

YAML and JSON files contain either a `cases` key, as above, or a bare array of cases. JSONL files contain one case per line:

```json
{"name": "unopened_return", "inputs": "Can I return an unopened item?", "expected_output": "Yes, within 30 days."}
{"name": "sale_item", "inputs": "Can I return a sale item?", "expected_output": "No, sale items are final."}
```

YAML is loaded safely, without Ruby object tags or aliases.

The case fields match Pydantic Evals, so you can reuse cases written for it. Evaluators are declared in Ruby, so a file that declares evaluators raises an error.

To use a different file, pass its path:

```ruby
class SupportEvaluation < RubyLLM::Evaluation
  dataset "evals/support_regressions.json"
end
```

## Structured Inputs

`inputs` is a single value, but that value can hold several fields:

```yaml
cases:
  - name: unopened_return
    inputs:
      question: Can I return this item?
      days_since_purchase: 14
      unopened: true
    expected_output: The item can be returned within 30 days.
```

`perform` receives the Hash and decides how to use it:

```ruby
def perform(input)
  ReturnsAgent.new.ask(<<~PROMPT)
    #{input["question"]}
    Days since purchase: #{input["days_since_purchase"]}
    Unopened: #{input["unopened"]}
  PROMPT
end
```

Keys are strings, as they are in the file. Name the parameter whatever reads best: `question`, `document`, or `scenario`. Each case gets its own copy of the inputs, so `perform` can modify it freely.

A list of user turns is also a valid input. See [Evaluating Conversations and Tools]({% link _advanced/evaluation-conversations.md %}).

## Cases from Your Application

When the cases live in your database, return them from a block:

```ruby
class SupportEvaluation < RubyLLM::Evaluation
  dataset do
    ReviewedAnswer.all.map do |answer|
      RubyLLM::Evaluation::Case.new(
        name: "reviewed_answer_#{answer.id}",
        inputs: answer.question,
        expected_output: answer.reviewed_answer
      )
    end
  end
end
```

You can also pass `dataset:` to `run` for a single run. RubyLLM loads the dataset once per run.

## Answers That Need No Reference

Some properties have no single correct answer: an agent cites its sources, asks for missing information, or never issues a refund without approval. Leave out `expected_output` and declare a [criterion]({% link _advanced/evaluation-evaluators.md %}#writing-your-own-criteria) that describes the behavior instead. Put any supporting material, such as the documents the answer should rely on, in `metadata` so the evaluator can see it.
