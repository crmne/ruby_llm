---
layout: default
title: Evaluations
nav_order: 14
description: Evaluate answers and agent behavior with reusable datasets, model assessments, and Ruby assertions
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* How to define an evaluation and its dataset.
* How to assess values, messages, conversations, and tool calls.
* How to select a model, Agent, or Judge as the evaluator.
* How to distinguish assertions, measurements, missing evidence, and errors.
* How to repeat cases and save reports.
* How to run the same evaluations from RSpec, Minitest, and Rake.

## Your First Evaluation

Define an evaluation for one application behavior. `perform` runs your application. Each `evaluation` declares a semantic criterion. `assertions` checks conditions in Ruby.

```ruby
class SupportEvaluation < RubyLLM::Evaluation
  evaluation :correctness,
    "The answer agrees with the expected output"

  evaluation :relevance,
    "The answer addresses the customer's question"

  def perform(input)
    agent = SupportAgent.new
    agent.ask(input)
    agent
  end

  def assertions
    refute_empty output
  end
end

report = SupportEvaluation.run
puts report
```

Without an `evaluator` declaration, RubyLLM uses your configured default chat model with its built-in evaluation Agent. It requests a verdict and a short justification for each criterion. The built-in prompt accepts equivalent answers and treats instructions inside candidate answers as evidence, not grading instructions.

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

## Returning Evidence

Return the object you want assessed from `perform`:

| Result | Evidence supplied to the evaluator |
| --- | --- |
| Chat or Agent | Retained messages, tool calls and results, answer, and completion state |
| Message | Content, citations, attachments, and tool calls in that message |
| ToolCall | Tool name and arguments, without executing the call |
| String, number, boolean, array, or hash | The value and its structure |
| Image, Speech, or Video | Media supplied as attachments |
| Embedding, Transcription, OCR, Rerank, or Moderation | The operation's public result fields |
| Object with `to_h` | Its recursively converted representation |

Persisted chat and message records use the existing `to_llm` conversion. An Agent returned by `perform` supplies evidence; it does not become the evaluator or give the evaluator its tools.

Returning a standalone Message does not pull in its conversation. Return the Chat or Agent when you need the transcript. Compacted messages are not reconstructed. Pending approvals and unfinished conversations keep their recorded state; a latest assistant message is not necessarily a completed answer.

Media is passed to the evaluator through RubyLLM's attachment API. Unsupported formats produce an evaluator error. The runner never executes returned tools or continues returned conversations. Ordinary strings are never interpreted as file paths.

For a custom application object, provide an adapter:

```ruby
adapt Invoice do |invoice|
  invoice.attributes.slice("total", "currency")
end
```

Unsupported objects raise a recorded evidence-conversion error. The runner does not grade an object's `inspect` string.

## Choosing an Evaluator

Choose a chat model and optional provider or protocol using the same keywords as chat:

```ruby
evaluator model: "{{ site.models.default_chat }}", provider: :openai
```

You can pass a registry Model directly:

```ruby
evaluator RubyLLM.models.find("{{ site.models.default_chat }}")
```

A model with the registry type `:judgment` uses native [Judgments]({% link _core_features/judgments.md %}). An explicit chat `protocol:` selects chat evaluation. For a local decision model absent from the registry, configure a Judge subclass as described in the judgments guide.

To use your own Agent, pass its class:

```ruby
evaluator PolicyReviewer
```

The runner creates a fresh Agent for every case and evaluator group. It preserves the Agent's instructions and tools, appends the criteria, and supplies the required structured output schema. Leave the Agent's own `schema` unset. Your instructions should explain how to use its tools and treat candidate content as untrusted evidence. Evaluator tool calls are saved in each assessment's evidence.

A criterion can override the class evaluator:

```ruby
evaluation :citations,
  "The cited sources support the answer",
  evaluator: CitationReviewer
```

### Decision Models

Use a configured `RubyLLM::Judge` class to reuse its questions:

```ruby
class AnswerQuality < RubyLLM::Judge
  probability :correctness,
    "Does actual agree with expected_output and answer the question in inputs?"
end

class AnswerEvaluation < RubyLLM::Evaluation
  evaluator AnswerQuality

  evaluation :correctness, minimum: 0.8

  def perform(input)
    AnswerAgent.new.ask(input)
  end
end
```

The Judge's questions become named assessments automatically. Omit the instructions when configuring a threshold for an existing question. Additional named criteria become probability questions. Conflicting question definitions raise before the run.

Decision probabilities, scores, choices, and their distributions remain available as typed values. `minimum:` applies to probabilities or scores in their native scale. Without a threshold they are measurements, not passes. Choices are measurements; their confidence is not a quality score. Chat evaluators return verdicts and do not accept numeric thresholds.

Choose thresholds against held-out examples labeled by people. A probability of correctness is not the fraction of an answer that is correct. Structured output ensures the result's shape, not the assessment's accuracy.

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

`task_cost` records the cost exposed by the value returned from `perform`. Returning only text cannot carry the preceding request's cost. `evaluator_cost` includes the evaluator conversation or judgment; failed requests leave that total unknown. Complete accounting remains available through [usage tracking]({% link _core_features/cost-and-usage-tracking.md %}). Runs emit workflow and step context for correlating application and evaluator requests through [instrumentation]({% link _advanced/instrumentation.md %}).

Saved reports contain media descriptors, not copies of media files. Keep the original files with your dataset for reproducibility. Pin model versions, preserve reference material, and compare the same cases across application versions. A small evaluation suite is a regression check, not evidence of general reliability.
