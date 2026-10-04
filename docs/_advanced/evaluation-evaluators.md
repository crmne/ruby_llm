---
layout: default
title: Evaluators
parent: Evaluations
nav_order: 3
description: Use configured agents, structured model verdicts, or native decision models to assess behavior
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* How to use default correctness or declare your own criteria.
* How to choose a model or preconfigured Agent.
* How to reuse native Judge questions and decision distributions.
* How to set acceptance thresholds and check evaluator quality.

## Default Correctness and Custom Criteria

An evaluation with only `perform` uses the built-in correctness criterion: "The answer agrees with the expected output". Every selected case must supply `expected_output`. Missing references raise before any case executes. An explicit `null`, `false`, or zero is a valid reference.

Declaring criteria replaces implicit correctness. To customize the comparison:

```ruby
evaluation :correctness, "The answer preserves every reference fact"
```

To assess a property that needs no reference answer:

```ruby
evaluation :grounded, "Every claim is supported by the retrieved documents"
```

To combine built-in correctness with another criterion, omit its instructions:

```ruby
evaluation :correctness
evaluation :concise, "The answer contains no unnecessary detail"
```

The shorthand uses the same reference requirement as implicit correctness. Custom criteria define their own requirements. Other criterion names need instructions unless the configured Judge already defines that question. Criteria inherit from the parent evaluation class; a subclass can replace a named criterion without changing its parent. Implicit correctness is a fallback, so it never becomes an inherited explicit criterion after a run.

Ruby assertions run alongside semantic criteria and do not remove default correctness. For assertions-only evaluations:

```ruby
evaluator false
```

This disables model grading. Requests made by `perform`, setup, assertions, or teardown still run and use the usual accounting. A disabled evaluator cannot be combined with semantic criterion declarations or model options. Subclasses inherit the setting and can enable grading by declaring an evaluator.

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

The Judge's questions become named assessments automatically and take precedence over implicit correctness. A Judge's own `correctness` question keeps its instructions and has no automatic reference requirement. Omit the instructions when configuring a threshold for an existing question. Additional named criteria become probability questions. Conflicting question definitions raise before the run.

Decision probabilities, scores, choices, and their distributions remain available as typed values. `minimum:` applies to probabilities or scores in their native scale. Without a threshold they are measurements, not passes. Choices are measurements; their confidence is not a quality score. Chat evaluators return verdicts and do not accept numeric thresholds.

Choose thresholds against held-out examples labeled by people. A probability of correctness is not the fraction of an answer that is correct. Structured output ensures the result's shape, not the assessment's accuracy.

## Check the Evaluator Itself

Keep a separate set of responses reviewed by people, including correct answers, plausible mistakes, and instructions that try to influence the evaluator. Assess those saved responses and compare the verdicts with the human labels. This tests the evaluator, whereas the normal application dataset tests newly generated behavior.

Keep the human pass/fail labels outside the evidence sent to the evaluator. Use separate examples to choose a decision threshold and to measure its accuracy. A small collection of passing examples does not establish general reliability.
