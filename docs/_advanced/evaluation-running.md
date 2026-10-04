---
layout: default
title: Running and Reports
parent: Evaluations
nav_order: 4
description: Run evaluations from Rake, RSpec, Minitest, or Ruby and read their results, tokens, and costs
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* How to check results with Ruby assertions.
* How to prepare and clean up application state for each case.
* How to run evaluations from Rake, RSpec, Minitest, and Ruby.
* What each case status means.
* How to read tokens and costs.

## Assertions

Some checks do not need a model. Define `assertions` to check them in Ruby:

```ruby
class SupportEvaluation < RubyLLM::Evaluation
  def perform(input)
    SupportAgent.new.ask(input)
  end

  def assertions
    assert_includes tool_calls.map(&:name), "lookup_order"
    refute_match(/guarantee/i, output)
  end
end
```

You can use `assert`, `refute`, `assert_equal`, `assert_includes`, `assert_match`, and every other method from `Minitest::Assertions`. The first failing assertion fails the case and stops that case's assertions. Model grading and later cases still run.

These values are available inside `assertions`:

| Method | Returns |
| --- | --- |
| `input` | The case's inputs |
| `expected_output` | The case's reference answer |
| `metadata` | The case's metadata |
| `result` | Exactly what `perform` returned |
| `output` | The final answer: the last assistant message for a conversation or Message, otherwise `result` |
| `messages` | The messages of a returned Chat, Agent, or Message |
| `tool_calls` | The tool calls in those messages |

Assertions run in addition to model grading. To run only assertions, set [`evaluator false`]({% link _advanced/evaluation-evaluators.md %}#assertions-only).

## Setup and Teardown

Override `setup` and `teardown` to prepare and clean up application state for each case:

```ruby
def setup
  @order = Order.create!(status: "shipped")
end

def teardown
  @order&.destroy
end
```

Each case runs on a fresh instance, so instance variables never leak between cases. `teardown` runs after every case, even when `setup`, `perform`, or an assertion fails. When a tool changes data, assert against the database rather than trusting the tool's own reply.

## Running from Rake

In Rails, the task is available automatically:

```sh
bin/rails ruby_llm:eval                                      # every evaluation
bin/rails "ruby_llm:eval[SupportEvaluation]"                 # one evaluation
bin/rails "ruby_llm:eval[SupportEvaluation,unopened_return]" # one case
```

In plain Ruby, load the task in your `Rakefile` after your application:

```ruby
require "ruby_llm"
load "tasks/ruby_llm.rake"
```

Then run `bundle exec rake ruby_llm:eval`.

The task loads every `app/evals/**/*_evaluation.rb` file and expects it to define the matching class. Use the full name for a namespaced evaluation, such as `Support::AnswerEvaluation`. Helper files with other names can live in the same directory.

Each report is printed and saved as JSON under `tmp/evaluations`. Two environment variables change this:

* `EVAL_OUTPUT` saves reports to another directory.
* `EVAL_REPETITIONS` runs every case several times.

The command exits unsuccessfully unless every case passes, so it works as a CI step. A misspelled evaluation or case name also fails, so a typo never produces an empty passing run.

## Running from Tests

Add an evaluation to your test suite to get one test per case. In RSpec:

```ruby
RSpec.describe SupportEvaluation do
  extend RubyLLM::Evaluation::RSpec

  evaluates described_class
end
```

In Minitest and Rails tests:

```ruby
class SupportEvaluationTest < ActiveSupport::TestCase
  extend RubyLLM::Evaluation::Minitest

  evaluates SupportEvaluation
end
```

For plain Minitest, inherit from `Minitest::Test` and load the evaluation class yourself. Both integrations accept `dataset:`, `only:`, and `repetitions:`. A failing test shows the case name, the assertion message, and the evaluator's reason.

Defining the tests makes no model requests. Running them makes the same requests as running from Rake, so evaluations that use model grading cost money on every test run. Keep them in a separate suite, or record them with your existing VCR setup. Evaluations with `evaluator false` make no grading requests.

## Running from Ruby

`run` returns a report:

```ruby
report = SupportEvaluation.run
puts report
report.save("tmp/support.json")
report.passed? # => true when every case passed
report.pass_rate # => 0.9
```

Select cases with `only:`, repeat them with `repetitions:`, or list them without running anything:

```ruby
SupportEvaluation.cases.map(&:name) # => ["unopened_return", "sale_item"]
SupportEvaluation.run(only: "unopened_return")
SupportEvaluation.run(only: ["unopened_return", "sale_item"], repetitions: 3)
```

Repetitions show how consistent your agent is. Each one is a fresh attempt, not a retry of a failure. Cases run one after another.

## Case Statuses

A report is a list of trials, one per case and repetition. Each trial has one status:

| Status | Meaning |
| --- | --- |
| `passed` | Every assertion and criterion passed. |
| `failed` | An assertion or criterion failed. |
| `unassessed` | The evaluator said the evidence was not enough to decide. |
| `measured` | A Judge returned a value with no `minimum`, or the case had nothing to check. |
| `error` | Your application, the evidence conversion, `teardown`, or the evaluator raised. |

Only `passed` counts as success. `pass_rate` divides passing trials by all trials, including errors. A `measured` result fails the Rake task too: give the [Judge question a `minimum`]({% link _advanced/evaluation-evaluators.md %}#grading-with-a-judge) to turn the measurement into a pass or fail.

Each trial keeps its case, the evidence, every verdict and reason, the evaluator model, the assertion count, any error, and its duration:

```ruby
report.each do |trial|
  puts "#{trial.test_case.name}: #{trial.status}"
  trial.evaluations.each do |evaluation|
    puts "  #{evaluation.name}: #{evaluation.reason}"
  end
end
```

## Tokens and Costs

Reports track usage the same way as the rest of RubyLLM. `tokens` returns `RubyLLM::Tokens` and `cost` returns `RubyLLM::Cost`:

```ruby
report = SupportEvaluation.run
report.tokens.input
report.cost.total

trial = report.first
trial.cost.total           # everything in this trial
trial.task_cost.total      # your application's requests
trial.evaluator_cost.total # grading requests
trial.task_tokens.input
trial.evaluator_tokens.output
```

The task side counts every RubyLLM request made in `setup`, `perform`, `assertions`, and `teardown`, including requests made by tools, even when `perform` returns only a string. Requests made before the trial, such as the earlier turns of a saved conversation, are not counted again. Requests made through another SDK are not counted. Unknown prices leave the total cost unknown, as they do elsewhere in RubyLLM.

In Rails, these requests are written to `ruby_llm_usages` like any other request, with no duplicate rows. Attribute them to an owner with the usual scope:

```ruby
report = RubyLLM.with_usage_owner(account) do
  SupportEvaluation.run
end
```

See [Cost and Usage Tracking]({% link _core_features/cost-and-usage-tracking.md %}) for owners and unknown costs.

## Comparing Runs

An evaluation is most useful when you compare runs over time: before and after a prompt change, or across two models. Keep the comparison fair:

* Pin model versions, both for your application and for the evaluator.
* Keep the dataset under version control, and keep any media files it refers to. Saved reports describe media but do not copy it.
* Run the same cases with enough repetitions to see past random variation.

A small dataset catches regressions. It does not prove your agent is reliable in general.
