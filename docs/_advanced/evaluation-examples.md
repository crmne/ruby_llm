---
layout: default
title: Examples
parent: Evaluations
nav_order: 5
description: Copy complete evaluation classes and datasets into your application
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* How to run a deterministic evaluation without a model.
* How to assess saved tool requests against expected arguments.

## Check Formatting Without a Model

Create `app/evals/title_formatting_evaluation.rb`:

```ruby
class TitleFormattingEvaluation < RubyLLM::Evaluation
  def perform(title)
    title.strip.delete_prefix('"').delete_suffix('"')
  end

  def assertions
    assert_equal expected_output, output
  end
end
```

Create `app/evals/title_formatting_evaluation.yml`:

```yaml
cases:
  - name: quoted
    inputs: '"Quarterly planning"'
    expected_output: Quarterly planning
  - name: whitespace
    inputs: '  Quarterly planning  '
    expected_output: Quarterly planning
```

Run `bin/rails "ruby_llm:eval[TitleFormattingEvaluation]"`, or `bundle exec rake "ruby_llm:eval[TitleFormattingEvaluation]"` in plain Ruby after [loading the task]({% link _advanced/evaluation-running.md %}#running-from-rake). Both cases pass without making a model request. In your application, have `perform` call the formatter you actually ship.

## Check Saved Tool Requests

You can also assess a tool request without executing it. Here the dataset deliberately contains one correct request and two incorrect requests, so you can verify that the assertions distinguish them.

Create `app/evals/tool_selection_evaluation.rb`:

```ruby
class ToolSelectionEvaluation < RubyLLM::Evaluation
  def perform(input)
    RubyLLM::ToolCall.new(id: 'candidate', name: input.fetch('name'), arguments: input.fetch('arguments'))
  end

  def assertions
    assert_equal expected_output.fetch('name'), result.name
    assert_equal expected_output.fetch('arguments'), result.arguments
  end
end
```

Create `app/evals/tool_selection_evaluation.json`:

```json
{
  "cases": [
    {
      "name": "case_01",
      "inputs": { "name": "lookup_order", "arguments": { "order_id": 42 } },
      "expected_output": { "name": "lookup_order", "arguments": { "order_id": 42 } }
    },
    {
      "name": "case_02",
      "inputs": { "name": "refund_order", "arguments": { "order_id": 42 } },
      "expected_output": { "name": "lookup_order", "arguments": { "order_id": 42 } }
    },
    {
      "name": "case_03",
      "inputs": { "name": "lookup_order", "arguments": { "order_id": 99 } },
      "expected_output": { "name": "lookup_order", "arguments": { "order_id": 42 } }
    }
  ]
}
```

Run `bin/rails "ruby_llm:eval[ToolSelectionEvaluation]"`. The report contains one pass and two failures, and the command exits unsuccessfully. No tool executes and no API request is made.

To test fresh agent behavior, replace `perform` with code that asks your agent and returns it. Assert against `tool_calls` and use semantic criteria for the conversation, as shown in [Conversations and Tools]({% link _advanced/evaluation-conversations.md %}).
