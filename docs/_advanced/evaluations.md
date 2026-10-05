---
layout: default
title: Evaluations
nav_order: 14
has_children: true
description: Measure how well your agents answer, with reusable datasets, model grading, and Ruby assertions
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* How to write and run your first evaluation.
* How to read its report.
* How inputs, output, and expected output relate.
* Where to go next for conversations, evaluators, and test suites.

## Why Evaluate

A spec tells you your code works. It cannot tell you whether your agent gives the right answer, because the same question can produce different words on every run. An evaluation runs your agent against a set of questions with known answers and has a model judge whether each response is correct. Run it after you change a prompt, a tool, or a model, and you see what improved and what broke.

## Your First Evaluation

An evaluation has two parts: a class that runs your application and a dataset of cases.

Create `app/evals/support_evaluation.rb`:

```ruby
class SupportEvaluation < RubyLLM::Evaluation
  def perform(input)
    SupportAgent.new.ask(input)
  end
end
```

Create `app/evals/support_evaluation.yml` beside it:

```yaml
cases:
  - name: unopened_return
    inputs: Can I return an unopened item after 14 days?
    expected_output: Yes, unopened items can be returned within 30 days.
  - name: sale_item
    inputs: Can I return something I bought on sale?
    expected_output: No, sale items are final.
```

Run it:

```sh
bin/rails "ruby_llm:eval[SupportEvaluation]"
```

For each case, RubyLLM passes `inputs` to `perform`, then asks your default chat model whether the agent's answer agrees with `expected_output`. Different wording is fine as long as the meaning matches.

## Reading the Report

The task prints one line per case, then a summary:

```text
SupportEvaluation
unopened_return [1]: passed (correctness=passed)
sale_item [1]: failed (correctness=failed)
  correctness: The answer says sale items can be returned within 30 days, but the reference says sale items are final.
1 passed, 1 failed, 0 measured, 0 unassessed, 0 error
Report: tmp/evaluations/SupportEvaluation.json
Evaluations failed
```

Each failure includes the evaluator's reason. The saved JSON report holds every response, verdict, and reason, plus the tokens and cost of the run. The command exits unsuccessfully when any case does not pass, so you can run it in CI.

You can also run an evaluation from Ruby:

```ruby
report = SupportEvaluation.run
puts report
report.passed? # => false
```

## Inputs, Output, and Expected Output

Three values take part in every case:

* `inputs` comes from the dataset and is passed to `perform`.
* `output` is what your application answered. `perform` produces it during the run, so it never goes in the dataset.
* `expected_output` comes from the dataset and describes a correct answer.

`inputs` can be a question, a list of turns, or structured data. `perform` can return a string, a Chat, an Agent, or another result. When it returns a conversation, the evaluator sees every message and tool call in it, not only the final answer.

## Where Files Go

RubyLLM finds the dataset by class name. `SupportEvaluation` uses `app/evals/support_evaluation.yml`, and `Support::AnswerEvaluation` uses `app/evals/support/answer_evaluation.yml`. Rails resolves `app/evals` from the application root and autoloads the classes in it. Plain Ruby resolves it from the working directory.

## Continue the Guide

* [Evaluation Datasets]({% link _advanced/evaluation-datasets.md %}): file formats, structured inputs, and cases from your database.
* [Evaluating Conversations and Tools]({% link _advanced/evaluation-conversations.md %}): several turns, saved transcripts, and tool calls.
* [Evaluators]({% link _advanced/evaluation-evaluators.md %}): your own criteria, models, Agents, and Judges.
* [Running Evaluations]({% link _advanced/evaluation-running.md %}): assertions, RSpec, Minitest, Rake, tokens, and costs.
* [Evaluation Progress and Monitoring]({% link _advanced/evaluation-progress.md %}): progress in your UI, notifications, and traces.
* [Evaluation Examples]({% link _advanced/evaluation-examples.md %}): complete evaluations to adapt.
