---
layout: default
title: Judgments
nav_order: 5
description: Ask typed questions about your application data and receive probabilities, choices, and scores
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* How to define reusable questions with `RubyLLM::Judge`.
* How to supply text, structured data, or images.
* How to read probabilities, choices, scores, and confidence.
* How to use blocks, hashes, and runtime inputs.
* How to connect to hosted models or a compatible local server.
* How to track token usage and cost.

## Asking a Question

Use a judgment when your application needs to check a condition, select an option, or rate something against a defined scale:

```ruby
class Urgency < RubyLLM::Judge
  probability :urgent, "Does this need attention today?"
end

judgment = Urgency.judge("Please refund the duplicate charge today.")
judgment.urgent.probability # => 0.96
```

Configure your [TypeSafe API key]({% link _getting_started/configuration-providers.md %}#typesafe) or a [Jev-compatible local endpoint]({% link _getting_started/configuration-providers.md %}#jev-compatible-apis) before making a request. With an [OpenAI API key]({% link _getting_started/configuration-providers.md %}#api-keys), choose `{{ site.models.openai_judgment }}`. OpenAI judgments use the Decisions API and answer the same questions. Judges use `config.default_judgment_model`, not the default chat model.

Each call judges the input you supply. It does not retain conversation history. Put a conversation in the input when you want the questions to consider it.

## Defining Questions

Write each declaration as a name, a question, and its possible answers. All questions run over the same input in one request:

```ruby
class TicketTriage < RubyLLM::Judge
  probability :urgent, "Does this need attention today?"

  choice :department, "Which team should handle this?" do
    billing   "Payments and refunds"
    technical "Bugs and integrations"
    other     "Everything else"
  end

  score :frustration, "How frustrated is the customer?",
    ["Calm", "Frustrated", "Angry"]
end
```

Question names identify answers in your code. Include the full meaning in the question or its answer descriptions; the model does not use the question name as an instruction.

### Probabilities

`probability` asks whether a condition holds. Its answer is the probability of yes, between zero and one. You can describe the boundary:

```ruby
probability :urgent, "Does this need attention today?" do
  yes "An explicit deadline today or an ongoing outage"
  no  "A general question with no time pressure"
end
```

Either description is optional. A value near `0.5` means yes and no have similar probability. It does not mean medium urgency. Use a score to measure degree.

### Choices

`choice` selects one option and returns a probability for every option. Include an alternative such as `other` when none of the specific options may fit. Use a separate probability question for each condition when several can apply at once.

A Hash supports names containing spaces, punctuation, or names that conflict with Ruby methods:

```ruby
choice :department, "Which team?", {
  "Billing & payments" => "Charges and refunds",
  "Technical support" => "Bugs and integrations",
  "Other" => nil
}
```

Use `nil` when an option needs no description. Symbol options return Symbols; String options return Strings.

### Scores

`score` places the input on an ordered scale. The first level is zero, the second is one, and so on. The answer is probability-weighted and can fall between levels:

```ruby
score :frustration, "How frustrated is the customer?" do
  ["Calm", "Frustrated", "Angry"]
end
```

Describe each level concretely.

## Supplying Input

Pass a String, Hash, or Array directly, or build named fields with a block:

```ruby
judgment = TicketTriage.judge do
  message "I was charged twice. Please refund the duplicate charge today."

  customer do
    plan "Pro"
    previous_contacts 2
  end
end
```

A block can also return the input:

```ruby
judgment = TicketTriage.judge { ticket.as_json(only: [:subject, :body]) }
```

Pass JSON-compatible data. Convert records explicitly with `as_json`; arbitrary Ruby objects are rejected. An input array is one shared input, such as a list of messages, not several independent requests.

### Images

Pass images with `with:`, alongside text or on their own:

```ruby
class DocumentType < RubyLLM::Judge
  model "{{ site.models.openai_judgment }}"

  choice :type, "What kind of document is this?" do
    invoice "A bill requesting payment"
    receipt "Proof of a completed payment"
    other nil
  end
end

DocumentType.judge("Scanned by the mail room", with: "scan.png").type.choice
DocumentType.judge(with: document.scan).type.choice
```

`with:` accepts the same files, URLs, and Active Storage attachments as chat. Images need a model that accepts them, such as `{{ site.models.openai_judgment }}`. Other attachment types, and models that judge text only, raise `RubyLLM::UnsupportedAttachmentError`.

## Structured Questions and Dynamic Values

Questions and descriptions can be Strings, Hashes, or Arrays. Choice descriptions and yes/no descriptions can also be `nil`. A nested block builds a structured description:

```ruby
choice :department, "Which team?" do
  billing do
    handles ["Charges", "Invoices", "Refunds"]
    excludes "Account access"
  end

  technical ["Bugs", "Integrations"]
  other nil
end
```

Use procs and declared inputs when instructions or options depend on application data:

```ruby
class TeamRouter < RubyLLM::Judge
  inputs :teams

  choice :team, "Which team should handle this?",
    -> { teams.to_h { |team| [team.slug, team.description] } }
end

judgment = TeamRouter.judge(ticket.body, teams: Team.active.to_a)
```

Declared inputs are required keyword arguments. They are available in model, question, criteria, and input blocks. They are not sent to the model unless you include them in the input or a question. You can also create an instance with `TeamRouter.new(teams: teams)` and call `judge` on it.

Blocks and procs resolve once for each judgment, before any transport retries. A block either declares fields or returns a value. Passing both a value and a block, mixing declarations with a returned value, or repeating a name raises `ArgumentError`. A subclass can replace an inherited question by declaring the same name.

You may omit the question argument when the answer descriptions carry its full meaning. A supplied question can itself be a Hash, Array, or proc returning structured instructions.

## Reading Answers

`Judgment` holds immutable `Probability`, `Choice`, and `Score` answers:

```ruby
judgment.urgent.probability

judgment.department.choice
judgment.department.probabilities
judgment.department.confidence

judgment.frustration.score
judgment.frustration.levels
judgment.frustration.probabilities
judgment.frustration.confidence
```

Score distributions use zero-based Integer keys. `levels` preserves the ordered descriptions, including structured values. `confidence` describes the concentration of a choice or score distribution; it is not a guarantee that the judgment is correct. Probability answers do not have a separate confidence value.

Choose thresholds in your application and check them against representative data:

```ruby
if judgment.urgent.probability >= 0.8
  ticket.update!(priority: :high)
end
```

Read named answers as methods, such as `judgment.urgent.probability`. Unknown answer methods raise `NoMethodError`. For dynamic names or names that collide with existing methods, use brackets: `judgment[question_name]` or `judgment[:model]`. Brackets accept String or Symbol names.

`judgment[:missing]` returns `nil`; `judgment.fetch(:missing)` raises `KeyError`. `judgment.answers` preserves declared names, and `judgment.each` yields each name and answer. Use `to_h` to serialize the result.

## Questions from Data

Use `RubyLLM.judge` when the question definitions already exist as data:

```ruby
RubyLLM.judge("Please help today.", questions: {
  urgent: { type: :probability, instructions: "Does this need attention today?" },
  department: {
    type: :choice,
    instructions: "Which team?",
    options: { billing: "Payments and refunds", other: "Everything else" }
  }
})
```

Each definition has a `type` and optional `instructions`. Supply `criteria` for probability descriptions, `options` for choices, and `levels` for scores. A questions Hash can be built with ordinary Ruby loops or supplied by a proc. The `judge` block always supplies input.

## Choosing a Model

Set the default once for your application:

```ruby
RubyLLM.configure do |config|
  config.default_judgment_model = "{{ site.models.judgment }}"
end
```

The built-in default is `{{ site.models.judgment }}`. A Judge class can override it with a `model` declaration, and a call can override either setting with `model:`. Pass `model: nil` to use the configured default again.

When you pass an isolated `context:`, its default replaces the global default. The class and per-call overrides still take precedence. See [Default Models]({% link _getting_started/configuration.md %}#default-models).

## Configuration and Usage

Read the actual model, token usage, and cost from the result:

```ruby
judgment.model
judgment.tokens.input
judgment.tokens.output
judgment.cost.total
```

Unknown costs remain `nil`. The provider's catalog does not necessarily include pricing. See [Cost and Usage Tracking]({% link _core_features/cost-and-usage-tracking.md %}).

Pass `model:`, `provider:`, `context:`, `provider_options:`, or instrumentation `metadata:` to `judge`. You can also declare `provider_options` on a Judge class as a Hash, proc, or block. Reserved input, question, and model fields must use the public arguments. `RubyLLM.context` exposes the same `judge` entry point for isolated credentials and settings.

Judgments use the shared timeouts, retries, and error classes. They emit `judgment.ruby_llm` and per-attempt `usage.ruby_llm` events. See [Instrumentation]({% link _advanced/instrumentation.md %}). Call judges from ordinary Rails services or jobs; no chat record is required.
