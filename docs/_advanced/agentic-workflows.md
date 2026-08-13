---
layout: default
title: Agentic Workflows
parent: "Agents"
nav_order: 1
description: Build workflow-oriented AI systems with plain Ruby orchestration, from routing and handoffs to parallelization
redirect_from:
  - /agent-handoffs/
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* How to drive the agentic loop yourself, one move at a time.
* Why the loop is safe to interrupt and resume between moves.
* How to implement common workflow patterns with plain Ruby classes.
* How to compose sequential, routing, parallel, and fan-in workflows.
* When to reach for an evaluator loop to iterate on output quality.

A workflow is just orchestration code that coordinates one or more agents. In practice, this is often a small Ruby class with a single public method, plus a loop you control. Before you build a multi-agent workflow, it helps to understand how a single agent's turn-by-turn loop runs, so you can pause it, persist it, and resume it on demand.

When you want to see the whole operation as one unit in your observability stack, wrap that Ruby code with `RubyLLM.workflow` and mark meaningful regions with `workflow.step`. These wrappers only add correlation to [instrumentation]({% link _advanced/instrumentation.md %}#workflows-and-steps); they do not introduce a workflow DSL or take over execution.

## Driving the Loop Yourself

`ask` sends your message and runs the conversation to completion: it calls the model, runs any [tools]({% link _core_features/tools.md %}) the model asks for, and calls the model again until it answers without a tool. When you need to control that loop, for example to run each turn as its own background job, set an iteration budget, or stop and resume on another machine, `Chat` exposes it as named verbs:

* `generate` runs the model once and appends its response (the model's move). It returns the response.
* `run_tools` executes the tool calls the model asked for and appends their results (your move). It makes no model call and returns the chat.
* `step` does whichever move is next: `run_tools` if tools are pending, otherwise `generate`. It returns `nil` once there is nothing left.
* `complete` steps until done. This is what `ask` calls, and it returns the final response.
* `complete?` is true when the model answered without calling a tool.

So the agentic loop is just `step` until `complete?`:

```ruby
chat = RubyLLM.chat.with_tools(Weather).ask_later("What's the weather in Paris?")

chat.step until chat.complete?  # generate, run_tools, generate
chat.messages.last.content      # => "It's 15°C and partly cloudy in Paris."
```

`ask_later` stages the question without sending it, so `ask` is `ask_later` then `complete`.

It is safe to interrupt the loop between moves. Each verb decides what to do next by reading the persisted messages, and `run_tools` skips tool calls that already have results. If a process dies after running one tool call of three, reloading the chat and calling `step` executes only the two remaining tool calls.

That property is what makes agents durable: run every turn as a background job, survive deploys with ActiveJob Continuations, and park for days on a human approval. [Durable Agents]({% link _advanced/durable-agents.md %}) is the guide for all of it.

[Batches]({% link _advanced/batches.md %}) are the same idea at scale: a batch is `generate` deferred for many chats at once, with `run_tools` run locally between rounds.

## Workflow Patterns

With the loop in hand, you can compose agents into larger systems. Each pattern below is a small, plain Ruby class - no framework, just orchestration.

### Sequential Workflow

Use this pattern when each step depends on the previous one.

```ruby
class ResearchAgent < RubyLLM::Agent
  model "{{ site.models.gemini_current }}"
  instructions "Given a topic, return concise, reliable key facts."
end

class WriterAgent < RubyLLM::Agent
  model "{{ site.models.anthropic_current }}"
  instructions "Given research notes, write a clear article."
end

class ResearchWriterWorkflow
  def create_article(topic)
    research = ResearchAgent.new.ask(topic).content
    WriterAgent.new.ask(research).content
  end
end

workflow = ResearchWriterWorkflow.new
article = workflow.create_article("Ruby 3.3 features")
```

### Routing Workflow

Use this pattern when requests fall into clear categories that benefit from specialized agents or models.

```ruby
class CodeAgent < RubyLLM::Agent
  model "{{ site.models.best_for_code }}"
  instructions "You are a coding assistant. Be precise and practical."
end

class CreativeAgent < RubyLLM::Agent
  model "{{ site.models.best_for_creative }}"
  instructions "You are a creative writing assistant."
end

class FactualAgent < RubyLLM::Agent
  model "{{ site.models.best_for_factual }}"
  instructions "You are a factual assistant. Prioritize accuracy."
end

class TaskClassifierAgent < RubyLLM::Agent
  model "{{ site.models.openai_mini }}"
  instructions "Classify the request as one word only: code, creative, or factual."
end

class ModelRouterWorkflow
  def call(query)
    agent_for(query).new.ask(query).content
  end

  private

  def agent_for(query)
    case classify(query)
    when :code then CodeAgent
    when :creative then CreativeAgent
    when :factual then FactualAgent
    else FactualAgent
    end
  end

  def classify(query)
    TaskClassifierAgent.new.ask(query).content.downcase.to_sym
  end
end

workflow = ModelRouterWorkflow.new
response = workflow.call("Write a Ruby function to parse JSON")
```

### Agent Handoffs

[Routing](#routing-workflow) picks an agent up front. A handoff goes further: it hands the *same ongoing conversation* to a different agent, so the specialist sees the full history and the user keeps one continuous thread. `Agent.find(chat_id)` is what makes this work. It loads a persisted chat and applies a different agent's instructions and tools at runtime, leaving the messages intact, so whichever agent takes over inherits the whole conversation.

The simplest version is a single turn. Give a router an inline schema so it answers with the specialist to hand to, then let that specialist continue the persisted chat:

```ruby
class SupportRouter < RubyLLM::Agent
  schema do
    string :specialist, enum: %w[billing technical]
  end
  instructions "Pick the specialist best suited to the latest message."
end

SPECIALISTS = { "billing" => BillingAgent, "technical" => TechnicalAgent }

def handle(chat_id, message)
  specialist = SupportRouter.new.ask(message).content["specialist"]
  SPECIALISTS.fetch(specialist).find(chat_id).ask(message)
end
```

The router responds immediately with its choice (no tool round-trip), and the specialist takes over the same chat with full history. Outside Rails, pass the chat object with `SpecialistAgent.new(chat: chat)` instead of `find(chat_id)`.

If you would rather the agent decide mid-conversation, give it a single handoff tool that returns the specialist to switch to. Drive the [loop](#driving-the-loop-yourself) a step at a time, and when a tool result names an agent, hand off:

```ruby
class Handoff < RubyLLM::Tool
  description "Hand the conversation to the specialist who should answer next"
  parameter :specialist, description: "billing or technical"
  def execute(specialist:) = specialist
end

class SupportRouter < RubyLLM::Agent
  chat_model Chat
  instructions "Call handoff with the specialist who should take over."
  tools Handoff
end

AGENTS = { "billing" => BillingAgent, "technical" => TechnicalAgent }

agent = SupportRouter.find(chat_id)
agent.ask_later(message)

until agent.complete?
  agent.step
  last = agent.messages.reload.last
  specialist = AGENTS[last.content] if last.role == "tool"
  agent = specialist.find(chat_id) if specialist
end
```

The handoff tool just returns the name; the orchestrator owns the routing, watching each tool result and swapping agents when one names a specialist. Because the routing lives in the loop and not in any agent, this extends to a multi-router for free: give the specialists the same `Handoff` tool and they can route onward, with every hop handled the same way.

(A tool cannot reconfigure the chat it runs inside, since its `execute` never receives the chat, so the switch belongs in the loop, not in the tool.)

### Parallel Workflow

Use this pattern when independent analyses can run at the same time.

```ruby
require 'async'

class SentimentAgent < RubyLLM::Agent
  instructions "Given text, return one word sentiment: positive, negative, or neutral."
end

class SummaryAgent < RubyLLM::Agent
  instructions "Given text, summarize it in one concise sentence."
end

class KeywordAgent < RubyLLM::Agent
  instructions "Given text, extract exactly 5 relevant keywords."
end

class ParallelAnalyzer
  def analyze(text)
    Async do |task|
      sentiment = task.async { SentimentAgent.new.ask(text).content }
      summary = task.async { SummaryAgent.new.ask(text).content }
      keywords = task.async { KeywordAgent.new.ask(text).content }

      {
        sentiment: sentiment.wait,
        summary: summary.wait,
        keywords: keywords.wait
      }
    end.wait
  end
end

analyzer = ParallelAnalyzer.new
insights = analyzer.analyze("Your text here...")
```

### Fan-Out/Fan-In Workflow

Use this pattern when multiple specialists produce outputs that are later synthesized.

```ruby
require 'async'

class SecurityReviewAgent < RubyLLM::Agent
  model "{{ site.models.anthropic_current }}"
  instructions "Given code, review it for security issues."
end

class PerformanceReviewAgent < RubyLLM::Agent
  model "{{ site.models.openai_tools }}"
  instructions "Given code, review it for performance issues."
end

class StyleReviewAgent < RubyLLM::Agent
  model "{{ site.models.openai_mini }}"
  instructions "Given code, review style against Ruby conventions."
end

class ReviewSynthesizerAgent < RubyLLM::Agent
  instructions "Given multiple code review reports, summarize prioritized findings."
end

class CodeReviewSystem
  def review_code(code)
    Async do |task|
      security = task.async { SecurityReviewAgent.new.ask(code).content }
      performance = task.async { PerformanceReviewAgent.new.ask(code).content }
      style = task.async { StyleReviewAgent.new.ask(code).content }

      ReviewSynthesizerAgent.new.ask(
        "security: #{security.wait}\n\n" \
        "performance: #{performance.wait}\n\n" \
        "style: #{style.wait}"
      ).content
    end.wait
  end
end

reviewer = CodeReviewSystem.new
summary = reviewer.review_code("def calculate(x); x * 2; end")
```

### Evaluation Loop (Evaluator-Optimizer)

Use this pattern when you have clear quality criteria and want iterative refinement.

```ruby
class DraftAgent < RubyLLM::Agent
  instructions "Given a task, produce the best possible draft response."
end

class CriticAgent < RubyLLM::Agent
  schema do
    string :verdict, enum: ["pass", "revise"], description: "Whether the draft passes or needs changes"
    string :feedback, description: "Specific feedback for improvement"
  end
  instructions "Review the draft against the task and return a verdict and specific feedback."
end

class EvaluatorOptimizerWorkflow
  MAX_ROUNDS = 3

  def call(task)
    draft = DraftAgent.new.ask(task).content

    MAX_ROUNDS.times do
      verdict, feedback = review(task:, draft:)
      return draft if verdict == "pass"

      draft = revise(task:, draft:, feedback:)
    end

    draft
  end

  private

  def review(task:, draft:)
    result = CriticAgent.new.ask("Task:\n#{task}\n\nDraft:\n#{draft}").content
    [result.fetch("verdict"), result.fetch("feedback")]
  end

  def revise(task:, draft:, feedback:)
    DraftAgent.new.ask("Task:\n#{task}\n\nCurrent draft:\n#{draft}\n\nFeedback:\n#{feedback}").content
  end
end

workflow = EvaluatorOptimizerWorkflow.new
final = workflow.call("Write a concise onboarding email for a new API customer")
```

## Retrieval-Augmented Generation

RAG is often just one step in a larger workflow: retrieve relevant context, then answer with that context. See [Retrieval-Augmented Generation (RAG)]({% link _advanced/rag.md %}) for the full pattern.

## Error Handling

For robust error handling in workflow code, leverage the patterns from the Tools guide:

* Return `{ error: "description" }` for recoverable errors the LLM might fix
* Raise exceptions for unrecoverable errors (missing config, service down)
* Use the retry middleware for transient failures

See the [Error Handling section in Tools]({% link _core_features/tools.md %}#error-handling-in-tools) for detailed patterns.

## Next Steps

* [Retrieval-Augmented Generation (RAG)]({% link _advanced/rag.md %}) - Ground answers in your own documents.
* [Agents]({% link _advanced/agents.md %}) - Define reusable agent classes.
* [Tools]({% link _core_features/tools.md %}) - Add capabilities and external actions.
* [Scale with Async]({% link _advanced/async.md %}) - Run concurrent workflow steps.
* [Error Handling]({% link _advanced/error-handling.md %}) - Build resilient systems.
