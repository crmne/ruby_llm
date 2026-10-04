---
layout: default
title: Conversations and Tools
parent: Evaluations
nav_order: 2
description: Evaluate full conversations, tool use, approval states, and custom traces
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* How to evaluate several turns in one scenario.
* How to review existing conversations.
* What evidence an evaluator receives for each return type.

## Evaluate Several Turns

A dataset case can contain a whole scenario. Create `app/evals/returns_conversation_evaluation.yml`:

```yaml
cases:
  - name: sale_item_followup
    inputs:
      - I bought an unopened item two weeks ago. Can I return it?
      - I forgot to mention that it was on sale. Does that change things?
    expected_output: Sale items cannot be returned, even within 30 days.
```

Run each turn on the same agent, then return it:

```ruby
class ReturnsConversationEvaluation < RubyLLM::Evaluation
  evaluation :policy,
    "The assistant applies the return policy to the whole conversation and corrects its advice after the follow-up"

  def perform(questions)
    agent = ReturnsAgent.new
    questions.each do |question|
      agent.ask(question)
    end
    agent
  end

  def assertions
    user_turns = messages.count do |message|
      message.role == :user
    end
    assert_equal 2, user_turns
    refute_empty output
  end
end
```

The evaluator receives both user turns, both assistant responses, and any intervening tool requests and tool results. `expected_output` here describes the correct final advice. A criterion can assess the final advice, an earlier turn, or the sequence of actions. It should say which behavior matters.

`perform` is ordinary Ruby. You can branch on an earlier response, approve or deny a proposed change, run several agents, or assert against an application's side effects. Return the conversation or structured trace that contains the evidence for your criteria. The runner does not impose a one-question, one-answer shape.

## Evaluate an Existing Conversation

For a Rails application that owns its chat records, a case can identify an existing transcript:

```yaml
cases:
  - name: reviewed_conversation
    inputs: 42
    expected_output: The assistant should request approval before posting.
```

```ruby
def perform(chat_id)
  Chat.find(chat_id)
end
```

This assesses the recorded conversation without asking the application agent again. Only new evaluator requests contribute to the run's cost. Access records through your application's normal authorization and tenancy rules.

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
