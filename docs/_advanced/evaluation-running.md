---
layout: default
title: Running and Reports
parent: Evaluations
nav_order: 4
description: Run evaluations from Ruby, test suites, or Rake and inspect outcomes, tokens, and costs
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* How to use assertions and lifecycle hooks.
* How to run the same cases in RSpec, Minitest, and Rake.
* How to inspect reports and standard RubyLLM usage accounting.

## Ruby Assertions and Fixtures

The assertion methods delegate to Minitest::Assertions. Use `assert`, `refute`, `assert_equal`, `assert_includes`, `assert_operator`, `assert_nil`, and the other Minitest assertions. A failure ends the assertion method for that case, while model criteria and later cases still run.

```ruby
def assertions
  assert_equal expected_output, output
  assert_includes tool_calls.map(&:name), "lookup_order"
end
```

`result` is the original return value. `output` is the latest assistant content for a conversation or Message, and the returned value otherwise. `messages` and `tool_calls` expose recorded conversation evidence. `input`, `expected_output`, and `metadata` expose the current case.

Override `setup` and `teardown` for application fixtures. Teardown runs after each attempted case, including failures. Verify side effects with assertions against the application state when tool responses alone are insufficient evidence.

## Running from Tests

Use the same evaluation class in your existing test suite. RSpec creates one example per dataset case:

```ruby
RSpec.describe SupportEvaluation do
  extend RubyLLM::Evaluation::RSpec

  evaluates described_class
end
```

Minitest and Rails create one test per case:

```ruby
class SupportTest < ActiveSupport::TestCase
  extend RubyLLM::Evaluation::Minitest

  evaluates SupportEvaluation
end
```

For plain Minitest, inherit from `Minitest::Test`. Load the evaluation class as you load other application classes. Rails autoloads classes in `app/evals`.

Both integrations accept `dataset:`, `only:`, and `repetitions:`. They use the same runner as `SupportEvaluation.run`, and failures include the case name, assertion message, and evaluator explanation. Evaluations run inside the test framework's ordinary setup and teardown. Declaring the tests loads their dataset but makes no model requests.

Assertions-only evaluations need no model. Semantic evaluations make the same requests when called from tests as they do from Ruby or Rake. Use your existing recording setup or run those tests in a separate live suite.

## Running from Rake

In Rails, the task is available automatically:

```sh
bin/rails ruby_llm:eval
bin/rails "ruby_llm:eval[SupportEvaluation]"
bin/rails "ruby_llm:eval[SupportEvaluation,unopened_return]"
```

In plain Ruby, load the task in your `Rakefile` after your application:

```ruby
require "ruby_llm"
load "tasks/ruby_llm.rake"
```

Then run `bundle exec rake ruby_llm:eval`. The task loads `app/evals/**/*_evaluation.rb` and expects each file to define its matching class. Pass the full class name for a namespaced evaluation. Helpers can live beside evaluations under other filenames.

Reports are saved to `tmp/evaluations/<ClassName>.json`. Set `EVAL_OUTPUT` to another directory or `EVAL_REPETITIONS` to repeat every case. Failed, unassessed, measured, or errored cases make the command exit unsuccessfully. An unknown class or case also fails, so a typo cannot produce a passing empty run.

## Reports

```ruby
report = SupportEvaluation.run(repetitions: 3)
puts report
report.save("tmp/support.json")

exit(report.passed? ? 0 : 1)
```

Use `SupportEvaluation.cases` to list cases without executing them. Select cases with `SupportEvaluation.run(only: "unopened_return")` or an array of names.

Reports contain case data, frozen evidence, criterion definitions, actual evaluator model IDs, reasons, native decisions, assertion counts, errors, and duration. They distinguish:

* `passed`: Every assessment passed.
* `failed`: An assertion or criterion failed.
* `measured`: A decision has no acceptance policy, or the case assessed nothing.
* `unassessed`: The evaluator reports insufficient evidence.
* `error`: Application execution, evidence conversion, cleanup, or an evaluator failed.

`pass_rate` uses every trial as its denominator, including errors and unassessed cases. `passed?` requires every trial to pass. Empty datasets are rejected. The runner executes sequentially; repetitions create fresh cases rather than retrying failures until they pass.

## Tokens, Costs, and the Usage Ledger

```ruby
report = SupportEvaluation.run
report.tokens.input
report.tokens.output
report.cost.total

trial = report.first
trial.tokens.cache_read
trial.cost.total
trial.task_tokens.input
trial.task_cost.total
trial.evaluator_tokens.input
trial.evaluator_cost.total
```

`tokens` returns `RubyLLM::Tokens`; `cost` returns `RubyLLM::Cost`. A report aggregates every case and repetition. A trial includes the application's requests and its evaluators' requests, including model calls made by tools. The task and evaluator readers show that split.

Accounting uses the existing `usage.ruby_llm` events. It works when `perform` returns only text or discards intermediate results. Task usage includes requests made in `setup`, `perform`, `assertions`, and `teardown`. A shared evaluator request is counted once even when it assesses several criteria. Billed failures remain included. Unknown token counts and costs keep the standard RubyLLM semantics; an unpriced attempt leaves the total cost unknown.

Only attempts completed during the trial are included. Earlier requests in a returned conversation are not charged again. Await background work inside `perform` if it belongs in the trial. Requests made through another SDK do not emit RubyLLM usage events.

In Rails, the same provider attempts are written to `ruby_llm_usages` by the existing accounting path. Evaluations add no duplicate rows. Persisted chat attempts keep their chat association; plain chats, evaluator agents, and native judgments use the ordinary standalone usage ledger. Attribute them using the existing owner scope:

```ruby
report = RubyLLM.with_usage_owner(account) do
  SupportEvaluation.run
end
```

See [Cost and Usage Tracking]({% link _core_features/cost-and-usage-tracking.md %}) for owner rules and unknown costs. Runs also emit workflow and step context for correlating task and evaluator requests through [instrumentation]({% link _advanced/instrumentation.md %}).

Saved reports contain media descriptors, not copies of media files. Keep the original files with your dataset for reproducibility. Pin model versions, preserve reference material, and compare the same cases across application versions. A small evaluation suite is a regression check, not evidence of general reliability.
