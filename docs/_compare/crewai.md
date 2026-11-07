---
layout: default
title: CrewAI
seo:
  title: RubyLLM and CrewAI
nav_order: 5
description: Compare RubyLLM with CrewAI in Python on multi-agent work, delegation, flows, routing, human review, and cost, with code from both projects.
permalink: /compare/crewai/
---

# RubyLLM and CrewAI

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* How CrewAI's agents, tasks, crews, processes, and flows map to RubyLLM.
* How the same two-agent job looks in each framework.
* How a hierarchical crew compares with subagents.
* How flows and routers compare with plain Ruby classes.
* How each one pauses for a person.
* What each one reports about usage and cost.
* What CrewAI adds as framework features.
* When to choose CrewAI and when to choose RubyLLM.

> **Last checked** on 6 November 2026 against RubyLLM 2.2 and the Python package `crewai` 1.15.36, with its `anthropic` and `litellm` extras. The Python code comes from CrewAI's documentation: [Introduction](https://docs.crewai.com/edge/en/introduction), [Agents](https://docs.crewai.com/edge/en/concepts/agents), [Tasks](https://docs.crewai.com/edge/en/concepts/tasks), [Crews](https://docs.crewai.com/edge/en/concepts/crews), [Processes](https://docs.crewai.com/edge/en/concepts/processes), [Collaboration](https://docs.crewai.com/edge/en/concepts/collaboration), [Hierarchical Process](https://docs.crewai.com/edge/en/learn/hierarchical-process), [Flows](https://docs.crewai.com/edge/en/concepts/flows), and [Human Feedback in Flows](https://docs.crewai.com/edge/en/learn/human-feedback-in-flows). Model names match the RubyLLM examples, and each agent sets `llm` so both sides use the same model. Comments, `verbose` flags, demo `print` calls, and `.env` loading were removed, so neither side shows API key setup.

## Two Frameworks

[CrewAI](https://docs.crewai.com/edge/en/introduction) is a Python framework for multi-agent work. RubyLLM is the Ruby AI framework. Both give you agents with tools, structured output, streaming, and many providers.

The difference is how much of the coordination is framework. CrewAI gives each part of a job a name:

* An **agent** has a `role`, a `goal`, and a `backstory`.
* A **task** has a `description` and an `expected_output`, and is assigned to an agent.
* A **crew** holds agents and tasks, and runs them with `kickoff()`.
* A **process** decides the order: `sequential`, or `hierarchical` with a manager.
* A **flow** connects steps with the `@start`, `@listen`, and `@router` decorators, and holds shared state.

RubyLLM has one of those five, the agent. A task is a prompt you pass to `ask`. A crew, a process, and a flow are a Ruby class that calls agents in the order you write, which RubyLLM calls a [workflow]({% link _advanced/agentic-workflows.md %}).

## Two Agents, One Job

The task: one agent researches a topic, and a second writes an article from the research.

CrewAI's [recommended form](https://docs.crewai.com/edge/en/concepts/crews#jsonc-configuration-recommended) for a new crew is a project with a `crew.jsonc` and one file per agent. Its direct code form keeps everything in one file. These are the first two steps of the Research, Write, Edit pattern from its [Collaboration](https://docs.crewai.com/edge/en/concepts/collaboration) guide, with the agents from the same page:

```python
from crewai import Agent, Crew, Task

researcher = Agent(
    role="Research Specialist",
    goal="Find accurate, up-to-date information on any topic",
    backstory="""You're a meticulous researcher with expertise in finding
    reliable sources and fact-checking information across various domains.""",
    llm="anthropic/{{ site.models.anthropic_latest }}",
)

writer = Agent(
    role="Content Writer",
    goal="Create engaging, well-structured content",
    backstory="""You're a skilled content writer who excels at transforming
    research into compelling, readable content for different audiences.""",
    llm="anthropic/{{ site.models.anthropic_latest }}",
)

research_task = Task(
    description="Research the latest developments in quantum computing",
    expected_output="Comprehensive research summary with key findings and sources",
    agent=researcher,
)

writing_task = Task(
    description="Write an article based on the research findings",
    expected_output="Engaging 800-word article about quantum computing",
    agent=writer,
    context=[research_task],
)

crew = Crew(
    agents=[researcher, writer],
    tasks=[research_task, writing_task],
)

result = crew.kickoff()
print(result.raw)
```

In RubyLLM, the agents are classes, and the workflow is a method:

```ruby
class Researcher < RubyLLM::Agent
  model "{{ site.models.anthropic_latest }}"
  instructions "You're a meticulous researcher. Find accurate, up-to-date information from reliable sources."
end

class Writer < RubyLLM::Agent
  model "{{ site.models.anthropic_latest }}"
  instructions "You're a skilled content writer. Turn research into engaging, well-structured content."
end

class Article
  def call(topic)
    research = Researcher.new.ask "Research the latest developments in #{topic}. Summarize key findings and sources."
    article = Writer.new.ask "Write an engaging 800-word article about #{topic} from this research:\n\n#{research.content}"
    article.content
  end
end

puts Article.new.call "quantum computing"
```

`role`, `goal`, and `backstory` become `instructions`. `description` and `expected_output` become the prompt. `context=[research_task]` becomes a local variable, so you can read exactly what the second agent receives. The topic is a method argument, which you can pass from a controller or a job.

CrewAI's task fields do more than carry text: `output_file` writes the result to disk, and `guardrail` validates the output and retries. In RubyLLM, you write those as Ruby after the call, or as an [evaluator loop]({% link _advanced/agentic-workflows.md %}#evaluation-loop-evaluator-optimizer).

## A Manager and a Team

In a hierarchical process, CrewAI's [manager](https://docs.crewai.com/edge/en/concepts/processes#hierarchical-process) allocates tasks to agents, reviews their outputs, and assesses completion. You give it a model, and it is created for you:

```python
from crewai import Agent, Crew, Process, Task

researcher = Agent(
    role="Researcher",
    goal="Conduct in-depth analysis",
    backstory="Experienced data analyst with a knack for uncovering hidden trends.",
    llm="anthropic/{{ site.models.anthropic_latest }}",
)
writer = Agent(
    role="Writer",
    goal="Create engaging content",
    backstory="Creative writer passionate about storytelling in technical domains.",
    llm="anthropic/{{ site.models.anthropic_latest }}",
)

article_task = Task(
    description="Write an article about quantum computing",
    expected_output="Engaging 800-word article about quantum computing",
)

project_crew = Crew(
    tasks=[article_task],
    agents=[researcher, writer],
    manager_llm="anthropic/{{ site.models.anthropic_latest }}",
    process=Process.hierarchical,
)

result = project_crew.kickoff()
print(result.raw)
```

The documentation's task list is a placeholder, so the task here comes from the crew example above.

In RubyLLM, the manager is an agent, and its team goes where its tools go. Each `description` tells it when to use that agent:

```ruby
class Researcher < RubyLLM::Agent
  model "{{ site.models.anthropic_latest }}"
  description "Researches a topic and reports key findings and sources"
  instructions "You're a data analyst with a knack for uncovering hidden trends."
end

class Writer < RubyLLM::Agent
  model "{{ site.models.anthropic_latest }}"
  description "Writes an article from the research it is given"
  instructions "You're a creative writer passionate about storytelling in technical domains."
end

class Manager < RubyLLM::Agent
  model "{{ site.models.anthropic_latest }}"
  instructions "Delegate the work to your team, and check each result before you answer."
  tools Researcher, Writer
end

puts Manager.new.ask("Write an 800-word article about quantum computing").content
```

Each call runs a new [subagent]({% link _getting_started/agents.md %}#subagents) in its own conversation, and only its answer comes back to the manager. The transcript of the manager's chat shows who was asked what.

The two are not the same. CrewAI's manager comes with its delegation behavior, while yours is the instructions you write. CrewAI's agents can also delegate to each other with [`allow_delegation=True`](https://docs.crewai.com/edge/en/concepts/collaboration), which adds tools for delegating work and asking questions. In RubyLLM, an agent can call only the agents in its `tools`.

A subagent lives in the process that ran it. A chat resumed in another process reports the subagent's work as lost, and the model can start it again.
{: .note }

## Flows

CrewAI's [introduction](https://docs.crewai.com/edge/en/introduction) tells you to start any production application with a flow. Its Getting Started example asks a model for a city, then for a fun fact about that city:

```python
from crewai.flow.flow import Flow, listen, start
from litellm import completion


class ExampleFlow(Flow):
    model = "anthropic/{{ site.models.anthropic_latest }}"

    @start()
    def generate_city(self):
        response = completion(
            model=self.model,
            messages=[
                {
                    "role": "user",
                    "content": "Return the name of a random city in the world.",
                },
            ],
        )

        random_city = response["choices"][0]["message"]["content"]
        self.state["city"] = random_city

        return random_city

    @listen(generate_city)
    def generate_fun_fact(self, random_city):
        response = completion(
            model=self.model,
            messages=[
                {
                    "role": "user",
                    "content": f"Tell me a fun fact about {random_city}",
                },
            ],
        )

        fun_fact = response["choices"][0]["message"]["content"]
        self.state["fun_fact"] = fun_fact
        return fun_fact


flow = ExampleFlow()
result = flow.kickoff()

print(f"Generated fun fact: {result}")
```

A flow method can also call [`LLM(...).call(...)`](https://docs.crewai.com/edge/en/concepts/flows#flow-usage-metrics), which skips the response indexing.

In RubyLLM, the order of the lines is the order of the steps, and local variables are the state:

```ruby
class CityFact
  def call
    chat = RubyLLM.chat model: "{{ site.models.anthropic_latest }}"
    city = chat.ask "Return the name of a random city in the world."
    fact = chat.ask "Tell me a fun fact about #{city.content}"
    fact.content
  end
end

puts CityFact.new.call
```

### Routing

A flow branches with `@router`, which returns a label that `@listen` methods wait for. The documentation's example branches on a random flag, so it runs without a model:

```python
import random
from typing import Literal

from crewai.flow.flow import Flow, listen, router, start
from pydantic import BaseModel

class ExampleState(BaseModel):
    success_flag: bool = False

class RouterFlow(Flow[ExampleState]):

    @start()
    def start_method(self):
        random_boolean = random.choice([True, False])
        self.state.success_flag = random_boolean

    @router(start_method)
    def second_method(self) -> Literal["success", "failed"]:
        if self.state.success_flag:
            return "success"
        else:
            return "failed"

    @listen("success")
    def third_method(self):
        print("Third method running")

    @listen("failed")
    def fourth_method(self):
        print("Fourth method running")


flow = RouterFlow()
flow.kickoff()
```

In Ruby, a branch is a `case`. Here, a model makes the decision, and a specialist answers:

```ruby
class Triage < RubyLLM::Agent
  model "{{ site.models.anthropic_haiku }}"
  instructions "Sort a support message."

  schema do
    string :category, enum: %w[billing shipping]
  end
end

class Billing < RubyLLM::Agent
  model "{{ site.models.anthropic_latest }}"
  instructions "You handle invoices, charges, and refunds."
end

class Shipping < RubyLLM::Agent
  model "{{ site.models.anthropic_latest }}"
  instructions "You handle tracking, delays, and addresses."
end

class SupportRouter
  def call(message)
    case Triage.new.ask(message).parsed["category"]
    when "billing" then Billing.new.ask message
    when "shipping" then Shipping.new.ask message
    end
  end
end

SupportRouter.new.call("Why was I charged twice?").content
```

Flows give you things a method doesn't. `and_` and `or_` combine triggers, several `@start` methods can run in parallel, and `flow.plot()` draws the graph. For parallel steps in Ruby, use `Async` blocks. See [Parallel Workflow]({% link _advanced/agentic-workflows.md %}#parallel-workflow).

### Where State Lives

The [`@persist`](https://docs.crewai.com/edge/en/concepts/flows#flow-persistence) decorator saves a flow's state to SQLite by default, and `kickoff(inputs={"id": ...})` loads the latest snapshot and continues. You can write your own `FlowPersistence` for other storage. A crew can [checkpoint](https://docs.crewai.com/edge/en/concepts/crews#checkpointing) to JSON files after each task and resume from one.

RubyLLM saves conversations, not workflow objects. A local variable in a workflow class is gone when the process ends. Add `chat_class Chat` to `Researcher`, with an `acts_as_chat` model, and its chat is rows in your application's database, so a job can run one move and enqueue the next:

```ruby
class ResearchTurnJob < ApplicationJob
  def perform(chat_id)
    chat = Researcher.find chat_id
    chat.step

    ResearchTurnJob.perform_later chat_id unless chat.complete? || chat.waiting?
  end
end
```

A worker that dies mid-conversation resumes from the last saved message. See [Agents in Background Jobs]({% link _advanced/durable-agents.md %}).

## Waiting for a Person

CrewAI's `@human_feedback` decorator reviews a flow method's output. By default it [blocks on console input](https://docs.crewai.com/edge/en/learn/human-feedback-in-flows#async-human-feedback-non-blocking). To wait for a reply from another system, you write a provider that notifies it and raises `HumanFeedbackPending`, then resume the flow when the answer arrives. This is the documentation's complete example, without its async handler:

```python
from crewai.flow import (
    Flow, start, listen, human_feedback,
    HumanFeedbackProvider, HumanFeedbackPending, PendingFeedbackContext
)

class SlackNotificationProvider(HumanFeedbackProvider):
    """Provider that sends Slack notifications and pauses for async feedback."""

    def __init__(self, channel: str):
        self.channel = channel

    def request_feedback(self, context: PendingFeedbackContext, flow: Flow) -> str:
        slack_thread_id = self.post_to_slack(
            channel=self.channel,
            message=f"Review needed:\n\n{context.method_output}\n\n{context.message}",
        )

        raise HumanFeedbackPending(
            context=context,
            callback_info={
                "slack_channel": self.channel,
                "thread_id": slack_thread_id,
            }
        )

class ContentPipeline(Flow):
    @start()
    @human_feedback(
        message="Approve this content for publication?",
        emit=["approved", "rejected"],
        llm="anthropic/{{ site.models.anthropic_latest }}",
        default_outcome="rejected",
        provider=SlackNotificationProvider("#content-reviews"),
    )
    def generate_content(self):
        return "AI-generated blog post content..."

    @listen("approved")
    def publish(self, result):
        print(f"Publishing! Reviewer said: {result.feedback}")
        return {"status": "published"}

    @listen("rejected")
    def archive(self, result):
        print(f"Archived. Reason: {result.feedback}")
        return {"status": "archived"}


def start_content_pipeline():
    flow = ContentPipeline()
    result = flow.kickoff()

    if isinstance(result, HumanFeedbackPending):
        return {"status": "pending", "flow_id": result.context.flow_id}

    return result


def on_slack_feedback(flow_id: str, slack_message: str):
    flow = ContentPipeline.from_pending(flow_id)
    result = flow.resume(slack_message)
    return result
```

`post_to_slack` stands for your own notification code, as it does in the documentation. The reviewer writes free text, and the model in `llm` turns it into one of the outcomes in `emit`.

In RubyLLM, the tool declares that it needs approval. `ApplicationAgent` is the base class the install generator writes, with `chat_class Chat`:

```ruby
class Publish < RubyLLM::Tool
  description "Publishes a blog post"
  requires_approval

  def execute(title:) = "Published #{title}"
end

class Editor < ApplicationAgent
  model "{{ site.models.anthropic_latest }}"
  tools Publish
end

chat = Editor.create!
chat.ask "Publish the quantum computing post"
chat.awaiting_person? # => true
```

The decision is stored on the tool call's row, so another request, after a deploy if need be, can record it and continue:

```ruby
chat = Editor.find params[:id]
chat.approve params[:tool_call_id]
chat.complete
```

You still scope the lookup and authorize the reviewer in your controller, as you would for any other action. `chat.pending_questions` lists what to show the reviewer, and `chat.deny` sends the model a refusal instead.

The two gate different things. CrewAI reviews what a step produced, and routes on what the reviewer said. RubyLLM stops an action before it happens, and takes a yes or a no. It doesn't read free text into an outcome, and notifying the reviewer is your application's code, such as a mailer or a Slack call. See [Controlling Tool Execution]({% link _tools/tool-execution.md %}).

## Structured Output

A CrewAI task takes `output_pydantic`, and a single agent's `kickoff()` takes `response_format`. This is the documentation's `Blog` model and agent with the shorter `kickoff()` form:

```python
from crewai import Agent
from pydantic import BaseModel


class Blog(BaseModel):
    title: str
    content: str


blog_agent = Agent(
    role="Blog Content Generator Agent",
    goal="Generate a blog title and content",
    backstory="""You are an expert content creator, skilled in crafting engaging and informative blog posts.""",
    llm="anthropic/{{ site.models.anthropic_latest }}",
)

result = blog_agent.kickoff(
    "Create a blog title and content on a given topic. Make sure the content is under 200 words.",
    response_format=Blog,
)
print(result.pydantic)
```

RubyLLM takes a schema class on the agent:

```ruby
class Blog < Schematist::Schema
  string :title
  string :content
end

class BlogAgent < RubyLLM::Agent
  model "{{ site.models.anthropic_latest }}"
  instructions "You are an expert content creator, skilled in crafting engaging and informative blog posts."
  schema Blog
end

response = BlogAgent.new.ask "Create a blog title and content on quantum computing. Keep the content under 200 words."
response.parsed
```

`result.pydantic` is a typed `Blog` object. `parsed` is a Hash, so it goes straight into `Post.create!`. See [Structured Output]({% link _core_features/structured-output.md %}).

## Usage and Cost

CrewAI [reports tokens](https://docs.crewai.com/edge/en/concepts/crews#crew-usage-metrics) on the crew:

```python
crew = Crew(agents=[agent1, agent2], tasks=[task1, task2])
crew.kickoff()
print(crew.usage_metrics)
```

The [`UsageMetrics` fields](https://docs.crewai.com/edge/en/concepts/flows#usagemetrics-field-semantics) are `total_tokens`, `prompt_tokens`, `completion_tokens`, `cached_prompt_tokens`, `cache_creation_tokens`, `reasoning_tokens`, and `successful_requests`. None of them is a price.

RubyLLM reports tokens and dollars, priced from its model registry. When usage or a price is unknown, the cost is `nil`, never a misleading zero:

```ruby
response = RubyLLM.chat(model: "{{ site.models.anthropic_latest }}").ask "Hello"

response.tokens.input
response.tokens.output
response.cost.total
```

A workflow spans several agents, so `RubyLLM.workflow` groups their calls. In Rails, every billed attempt lands in the usage ledger, so one query gives you what the whole job cost:

```ruby
RubyLLM.workflow "Article", id: "article-42" do
  Article.new.call "quantum computing"
end

RubyLLM::ActiveRecord::Usage.where(workflow_id: "article-42").sum(:total_cost)
```

`sum` skips an attempt whose cost is unknown, so check `where(total_cost: nil)` when you need the whole bill.

See [Cost and Usage Tracking]({% link _core_features/cost-and-usage-tracking.md %}).

## What CrewAI Adds

CrewAI ships these as framework features:

* **Planning.** [`Crew(planning=True)`](https://docs.crewai.com/edge/en/concepts/planning) writes a plan for every task before the crew runs. In RubyLLM, a plan is a step you write in your workflow.
* **Training.** [`crewai train`](https://docs.crewai.com/edge/en/concepts/training) improves agents from human feedback over several iterations. RubyLLM's [Evaluations]({% link _advanced/evaluations.md %}) grade agents, but don't train them.
* **Replay.** [`crewai replay -t <task_id>`](https://docs.crewai.com/edge/en/concepts/crews#replaying-from-a-specific-task) reruns a crew from one task of its latest kickoff.
* **A flow diagram.** `flow.plot()` draws the steps. A RubyLLM workflow is code, and nothing draws it.
* **A managed memory object.** CrewAI's [`Memory`](https://docs.crewai.com/edge/en/concepts/memory) class stores facts, uses a model to infer their scope and importance, and recalls them by meaning. In RubyLLM, the [memory guide]({% link _advanced/memory.md %}) shows you how to build that as your own table and tools.
* **Knowledge sources.** CrewAI's [`knowledge_sources`](https://docs.crewai.com/edge/en/concepts/knowledge) give agents a reference library. In RubyLLM, the [RAG guide]({% link _advanced/rag.md %}) shows you how to build retrieval as a tool.
* **A hosted platform.** [CrewAI AMP](https://docs.crewai.com/edge/en/quickstart#deploying) deploys your flows with `crewai deploy create`. RubyLLM runs wherever your application runs.

## Concept Map

| CrewAI | RubyLLM |
| --- | --- |
| `Agent(role, goal, backstory)` | A [`RubyLLM::Agent`]({% link _getting_started/agents.md %}) class with `instructions` |
| `Task(description, expected_output)` | A prompt passed to `ask` |
| `context=[task]` | A local variable in the next prompt |
| `Crew(...).kickoff()` | A [workflow]({% link _advanced/agentic-workflows.md %}) class with one method |
| `Process.sequential` | Method calls in order |
| `Process.hierarchical` and `manager_llm` | An agent with [subagents]({% link _getting_started/agents.md %}#subagents) in its `tools` |
| `allow_delegation=True` | `tools OtherAgent` |
| `Flow`, `@start`, and `@listen` | A Ruby class with one method |
| `@router` | `if` or `case` |
| `and_` | `Async` blocks, waiting for each |
| `or_` | `Async` blocks, acting on the first to finish |
| `@persist` and `checkpoint` | `acts_as_chat` and [one step per job]({% link _advanced/durable-agents.md %}) |
| `@human_feedback` | `requires_approval`, `approve`, and `deny` |
| `output_pydantic` and `response_format` | `schema` |
| `BaseTool` or `@tool` | A [`RubyLLM::Tool`]({% link _getting_started/tools.md %}) class |
| `Crew(stream=True)` | A block given to `ask` |
| Task `guardrail` | An [evaluator loop]({% link _advanced/agentic-workflows.md %}#evaluation-loop-evaluator-optimizer) or a [judgment]({% link _advanced/judgments.md %}) |
| `usage_metrics` | `response.tokens`, `response.cost`, and the usage ledger |

## When to Choose CrewAI

* **Your team works in Python.** CrewAI is a Python package, and your data and machine learning code is already there.
* **You think in roles and teams.** Agents with roles, tasks with expected outputs, and a manager that delegates are the framework's own vocabulary, ready to configure in JSONC or YAML.
* **You want the framework to run the team.** Hierarchical crews, peer delegation, planning, and training come built in, and you configure them instead of writing them.
* **You want memory and knowledge built in.** `Memory` and `knowledge_sources` work without a table of your own.
* **You want a hosted platform.** AMP deploys flows, and its enterprise features include a [human review platform](https://docs.crewai.com/edge/en/learn/human-in-the-loop#enterprise-features).

## When to Choose RubyLLM

* **Your application is Ruby or Rails.** Agents are classes, chats are Active Record models, and loops run in Active Job, without a separate runtime.
* **You want plain Ruby control flow.** Steps are lines, state is variables, and branches are `case`. You test a workflow like any other class.
* **Waiting must survive deploys in your own database.** Approvals, cancellation, and the loop itself read and write your application's tables.
* **You need to know what it costs.** Responses, chats, and workflows report cost in dollars wherever the registry has a price.
* **You don't want telemetry.** CrewAI [collects anonymous usage data](https://docs.crewai.com/edge/en/telemetry), including tool names and agent roles, until you set `CREWAI_DISABLE_TELEMETRY`. RubyLLM collects nothing.
* **You need more than chat.** Images, video, speech, transcription, OCR, moderation, embeddings, and reranking come from the same gem with the same configuration.

## Next Steps

* [Agentic Workflows]({% link _advanced/agentic-workflows.md %}) - Chain, route, hand off, and run agents in parallel with plain Ruby.
* [Agents]({% link _getting_started/agents.md %}) - Define agents as classes, and hand work to subagents.
* [Agents in Background Jobs]({% link _advanced/durable-agents.md %}) - Run the loop one step per job.
* [Migrating to RubyLLM]({% link _compare/migrating-from.md %}) - Guides for other frameworks and clients.
