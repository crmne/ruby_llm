---
layout: default
title: Teams
parent: "Agents"
nav_order: 5
description: Coordinate specialized agents as one team the model can delegate work to
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* How to register coworkers on a `RubyLLM::Team`.
* How to hand a chat the team's collaboration tools.
* How the model delegates tasks and asks questions.
* How coworker instances, attachments, and concurrency behave.

## What Is a Team?

A `RubyLLM::Team` groups named coworkers and creates tools that let a model delegate work to them. A Team does not define a task graph or run a process. Use ordinary Ruby or an [Agentic Workflow]({% link _advanced/agentic-workflows.md %}) to coordinate the work around it.

```ruby
team = RubyLLM::Team.new
team.add("Researcher", ResearcherAgent)
team.add("Writer", WriterAgent)

chat.with_tools(*team.collaboration_tools)
chat.ask "Write an article about the benefits of tea"
```

## Registering Coworkers

`add` takes a role and an agent. The agent can be a `RubyLLM::Agent` subclass, an instance, or any object that responds to `#ask`. Use descriptive roles so the model knows which coworker to choose.

```ruby
team.add("Researcher", ResearcherAgent)
```

Each call to a registered class creates a fresh coworker. Register an instance to preserve its conversation:

```ruby
team.add("Support specialist", SupportAgent.new)
```

## Collaboration Tools

`collaboration_tools` returns `delegate_work` and `ask_question`. Pass them to `Chat#with_tools`, or declare them on an agent class:

```ruby
team = RubyLLM::Team.new
team.add("Researcher", ResearcherAgent)

Orchestrator = Class.new(RubyLLM::Agent) do
  tools(*team.collaboration_tools)
end
```

Both tools list the available coworker roles in their descriptions:

| Tool | Arguments | Use it to |
|---|---|---|
| `delegate_work` | `task`, `coworker`, optional `context` | Hand a task to a coworker and get its result |
| `ask_question` | `question`, `coworker`, optional `context` | Consult a coworker about its expertise |

The optional `context:` argument adds labeled shared context after the request.

When a coworker replies with attachments, the tool returns `[content, *attachments]`, so coworkers can hand files or images back to the orchestrator.

## Unknown Coworkers

When the model names an unknown coworker, the tool returns an error such as `{ error: "Unknown coworker 'Editor'. Available: Researcher, Writer" }`. The model can then correct the call and continue.

## Concurrency

Register every coworker before calling `collaboration_tools`. The returned tools capture a stable snapshot of the registry, so concurrent calls only read Team state and need no locks.

Classes create a fresh coworker for every call. Registered instances are reused, including their conversation state. Register a class whenever you enable concurrent tool execution.

## Next Steps

* [Agents]({% link _advanced/agents.md %}) - Define reusable coworker classes.
* [Tools]({% link _core_features/tools.md %}) - Understand the tools a team exposes.
* [Agentic Workflows]({% link _advanced/agentic-workflows.md %}) - Add task order and dependencies around a team. This guide appears under Agents in the navigation.
