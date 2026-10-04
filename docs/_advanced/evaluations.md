---
layout: default
title: Evaluations
nav_order: 14
has_children: true
description: Evaluate answers and agent behavior with reusable datasets, model assessments, and Ruby assertions
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* How to define an evaluation and its dataset.
* How inputs, actual output, and expected output differ.
* Where to learn about conversations, evaluators, test runners, and reports.

## Your First Evaluation

Define an evaluation for one application behavior. `perform` runs your application. RubyLLM checks whether the answer agrees with the dataset's expected output.

```ruby
class SupportEvaluation < RubyLLM::Evaluation
  def perform(input)
    SupportAgent.new.ask(input)
  end
end

report = SupportEvaluation.run
puts report
```

Without an `evaluator` declaration, RubyLLM uses your configured default chat model with its built-in evaluation Agent. It requests a verdict and a short justification. The built-in prompt accepts equivalent answers and treats instructions inside candidate answers as evidence, not grading instructions.

Create `app/evals/support_evaluation.yml` beside `support_evaluation.rb`:

```yaml
cases:
  - name: unopened_return
    inputs: Can I return an unopened item after 14 days?
    expected_output: Yes, unopened items can be returned within 30 days.
    metadata:
      category: returns
```

Plain Ruby resolves `app/evals` from the working directory. Rails resolves it from the application root. A namespaced class such as `Support::AnswerEvaluation` uses `app/evals/support/answer_evaluation.yml`.

Default correctness requires `expected_output` on every selected case. Missing references raise before your application or evaluator runs. Declare `evaluation` criteria to replace the default, or use `evaluation :correctness` to include the built-in comparison alongside other criteria. See [Evaluators]({% link _advanced/evaluation-evaluators.md %}) for overrides and decision models.

You can also define `assertions` to check conditions in Ruby. Assertions run alongside model grading. For assertions-only evaluations, set `evaluator false` as shown in [Examples]({% link _advanced/evaluation-examples.md %}).

## Inputs, Output, and Expected Output

The dataset supplies the question. Your application produces the response. The reference describes what a correct response should say.

| Name | Where it comes from | In this example |
| --- | --- | --- |
| `inputs` | A dataset case, passed to `perform` | The customer's return question |
| `output` | Extracted from what `perform` returns | The response your agent actually produced |
| `expected_output` | The reference used by default correctness | The correct return policy |

You do not put the actual response in a normal application dataset. `perform` produces it during the run. There is no required field called `answer`.

A case describes one scenario. Its `inputs` can be a question, several turns, a document, or structured application data. Return a Chat or Agent to assess the whole retained conversation, including tool calls and results. The `output` reader exposes the final answer for convenient Ruby assertions; it does not limit what the evaluator sees.

## Continue the Guide

* [Datasets]({% link _advanced/evaluation-datasets.md %}): file formats, references, and application data.
* [Conversations and Tools]({% link _advanced/evaluation-conversations.md %}): multiple turns, existing transcripts, and tool traces.
* [Evaluators]({% link _advanced/evaluation-evaluators.md %}): configured agents, structured output, and decision models.
* [Running and Reports]({% link _advanced/evaluation-running.md %}): assertions, RSpec, Minitest, Rake, tokens, costs, and UI progress.
* [Examples]({% link _advanced/evaluation-examples.md %}): complete classes and datasets you can put in your application.
