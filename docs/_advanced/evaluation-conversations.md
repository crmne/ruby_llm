---
layout: default
title: Conversations and Tools
parent: Evaluations
nav_order: 2
description: Evaluate multi-turn conversations, saved transcripts, tool calls, and your own result objects
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* How to evaluate several turns in one case.
* How to grade a conversation you already saved.
* What the evaluator sees for each kind of result.
* How to evaluate your own result objects.

## Evaluate Several Turns

Agents often go wrong on the second message, not the first. A case can hold a whole conversation. Create `app/evals/returns_conversation_evaluation.yml`:

```yaml
cases:
  - name: sale_item_followup
    inputs:
      - I bought an unopened item two weeks ago. Can I return it?
      - I forgot to mention that it was on sale. Does that change things?
    expected_output: Sale items cannot be returned, even within 30 days.
```

Ask each turn on the same agent and return the agent:

```ruby
class ReturnsConversationEvaluation < RubyLLM::Evaluation
  evaluation :correctness
  evaluation :corrects_itself,
    "After the follow-up, the assistant withdraws its earlier advice that the item can be returned"

  def perform(questions)
    agent = ReturnsAgent.new
    questions.each { |question| agent.ask(question) }
    agent
  end
end
```

Because `perform` returns the agent, the evaluator sees both user turns, both answers, and every tool call and result in between. `expected_output` describes the correct final advice. Write each criterion so it says which part of the conversation matters: the final answer, an earlier turn, or the order of actions.

`perform` is ordinary Ruby. It can branch on an earlier answer, approve or deny a tool call, run several agents, or change application state. Return whatever holds the evidence your criteria need.

## Grade a Saved Conversation

To grade conversations your application already had, without asking the agent again, put the record ID in the case:

```yaml
cases:
  - name: refund_request_42
    inputs: 42
    expected_output: The assistant asks for approval before issuing the refund.
```

```ruby
def perform(chat_id)
  Chat.find(chat_id)
end
```

Only the grading requests cost anything. Load records through your application's usual authorization and tenancy rules.

## Assert on Tool Calls

`tool_calls` lists every tool call in the returned conversation. Use it to check what the agent did, alongside what it said:

```ruby
def assertions
  assert_includes tool_calls.map(&:name), "lookup_order"
  refute_includes tool_calls.map(&:name), "issue_refund"
end
```

See [Running and Reports]({% link _advanced/evaluation-running.md %}#assertions) for the other values available in assertions.

## What the Evaluator Sees

The evidence depends on what `perform` returns:

| `perform` returns | The evaluator sees |
| --- | --- |
| Chat, Agent, or chat record | Every retained message, tool call, and tool result, plus whether the conversation finished |
| Message | Its content, citations, attachments, and tool calls |
| ToolCall | The tool name and arguments |
| String, number, boolean, array, or Hash | The value itself |
| Image, Speech, or Video | The media, as attachments |
| Embedding, Transcription, OCR, Rerank, or Moderation result | The result's public fields |
| Any object with `to_h` | Its Hash representation |

A few rules follow from this:

* A Message alone does not include the rest of its conversation. Return the Chat or Agent when earlier turns matter.
* A conversation waiting for approval, or one that never finished, is graded as it stands. Its last message may not be a final answer.
* Messages removed by compaction are not restored.
* RubyLLM never runs returned tool calls or continues a returned conversation.
* Strings are graded as text, never opened as file paths.

## Evaluate Your Own Objects

For an object without a useful `to_h`, tell the evaluation how to describe it with `adapt` in the class body:

```ruby
class InvoiceEvaluation < RubyLLM::Evaluation
  adapt Invoice do |invoice|
    invoice.attributes.slice("total", "currency")
  end

  def perform(input)
    InvoiceDrafter.call(input)
  end
end
```

`result` in assertions is still the original Invoice. An object RubyLLM cannot convert makes the case end with an error. It is never graded from its `inspect` string.
