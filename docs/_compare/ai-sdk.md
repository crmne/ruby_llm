---
layout: default
title: RubyLLM and the Vercel AI SDK
nav_order: 1
description: Compare RubyLLM with the Vercel AI SDK on the same agent, structured output, chat interface, and cost tracking, with code from both projects.
permalink: /compare/ai-sdk/
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* How the same tool-using agent looks in each framework.
* How agents, tools, loop control, and structured output map between them.
* How each one builds a chat interface and keeps its history.
* What each one reports about usage and cost.
* When to choose the AI SDK and when to choose RubyLLM.

> **Last checked** on 5 November 2026 against RubyLLM 2.2 and AI SDK 7.0.163 (`ai`), with `@ai-sdk/anthropic` 4.0.97, `@ai-sdk/react` 4.0.167, and `zod` 4.6.7. The AI SDK code comes from its documentation: [Building Agents](https://ai-sdk.dev/docs/agents/building-agents), [Loop Control](https://ai-sdk.dev/docs/agents/loop-control), [Generating Structured Data](https://ai-sdk.dev/docs/ai-sdk-core/generating-structured-data), [Chatbot Message Persistence](https://ai-sdk.dev/docs/ai-sdk-ui/chatbot-message-persistence), [generateText](https://ai-sdk.dev/docs/reference/ai-sdk-core/generate-text), and the [Anthropic provider](https://ai-sdk.dev/providers/ai-sdk-providers/anthropic). Both sides call Anthropic directly with the same model.

## Two Frameworks for the Same Job

The [AI SDK](https://ai-sdk.dev) is Vercel's TypeScript toolkit for building AI applications. RubyLLM is the Ruby one. Both run the tool loop, stream, return structured output, and switch providers by changing a model name.

They differ in what surrounds the model call. The AI SDK fits a TypeScript stack: React hooks, route handlers, and serverless functions. RubyLLM fits a Ruby stack: plain objects, Active Record, Active Job, and Hotwire.

## An Agent with a Tool

The task: a weather agent with one tool streams its answer, and stops after five model calls.

In the AI SDK, the agent is a `ToolLoopAgent`, the tool is a `tool()` with a Zod schema, and the step limit is a `stopWhen` condition:

```ts
import { ToolLoopAgent, isStepCount, tool } from 'ai';
import { anthropic } from '@ai-sdk/anthropic';
import { z } from 'zod';

const weatherAgent = new ToolLoopAgent({
  model: anthropic('{{ site.models.anthropic_latest }}'),
  instructions: 'You are a helpful weather assistant.',
  tools: {
    weather: tool({
      description: 'Get the weather for a city',
      inputSchema: z.object({
        city: z.string(),
      }),
      execute: async ({ city }) => `It's 21°C and sunny in ${city}`,
    }),
  },
  stopWhen: isStepCount(5),
});

const result = await weatherAgent.stream({
  prompt: 'What is the weather in Berlin?',
});

for await (const chunk of result.textStream) {
  process.stdout.write(chunk);
}
```

In RubyLLM, the tool and the agent are classes, and streaming is a block:

```ruby
class Weather < RubyLLM::Tool
  description "Get the weather for a city"

  def execute(city:) = "It's 21°C and sunny in #{city}"
end

class WeatherAgent < RubyLLM::Agent
  model "{{ site.models.anthropic_latest }}"
  instructions "You are a helpful weather assistant."
  tools Weather
end

WeatherAgent.new.ask "What is the weather in Berlin?" do |chunk|
  print chunk.content
end
```

There is no schema library to import: the keyword arguments of `execute` are the schema. When a parameter needs a description, a type, or an enum, declare it with `parameter` or a `parameters` block. See [Tool Parameters]({% link _tools/tool-parameters.md %}).

The agent is a class, so you use it the way you use any other class: in a controller, a job, a console, or a test. Its configuration lives in one place.

### Capping the Loop

A `ToolLoopAgent` stops after 20 steps unless you set `stopWhen`. RubyLLM's `ask` runs until the model answers. To give the loop a budget, drive it yourself with the same verbs `ask` uses:

```ruby
chat = WeatherAgent.new.ask_later "What is the weather in Berlin?"

5.times do
  chat.generate { |chunk| print chunk.content }
  break if chat.complete?

  chat.run_tools
end
```

`generate` is one model call, the AI SDK's step. `run_tools` runs the calls the model asked for, and `complete?` is true once the model answers without one. The transcript stays valid when the budget runs out, so a later `chat.complete` picks up where the loop stopped. See [Driving the Loop Yourself]({% link _advanced/agentic-workflows.md %}#driving-the-loop-yourself).

## Structured Output

The AI SDK takes a Zod schema through `Output.object`:

```ts
import { generateText, Output } from 'ai';
import { anthropic } from '@ai-sdk/anthropic';
import { z } from 'zod';

const { output } = await generateText({
  model: anthropic('{{ site.models.anthropic_latest }}'),
  output: Output.object({
    schema: z.object({
      recipe: z.object({
        name: z.string(),
        ingredients: z.array(
          z.object({ name: z.string(), amount: z.string() }),
        ),
        steps: z.array(z.string()),
      }),
    }),
  }),
  prompt: 'Generate a lasagna recipe.',
});
```

RubyLLM takes a schema class:

```ruby
class Recipe < Schematist::Schema
  object :recipe do
    string :name

    array :ingredients do
      object do
        string :name
        string :amount
      end
    end

    array :steps, of: :string
  end
end

chat = RubyLLM.chat(model: "{{ site.models.anthropic_latest }}").with_schema Recipe
recipe = chat.ask("Generate a lasagna recipe.").parsed
```

`parsed` is a Hash. On an agent, the class macro `schema Recipe` does the same, and `schema do ... end` declares one inline. See [Structured Output]({% link _core_features/structured-output.md %}).

## A Chat Interface with History

The AI SDK gives you `useChat` for the browser and stream helpers for the server. Storing the conversation is yours to write. Its message persistence guide has you implement `loadChat` and `saveChat`, then wires them into the route handler:

```ts
import {
  convertToModelMessages,
  createUIMessageStreamResponse,
  streamText,
  toUIMessageStream,
  UIMessage,
  validateUIMessages,
} from 'ai';
import { anthropic } from '@ai-sdk/anthropic';
import { loadChat, saveChat } from '@util/chat-store';
import { dataSchemas, metadataSchema } from '@util/schemas';

const tools = { /* the weather tool from above */ };

export async function POST(req: Request) {
  const { message, id } = await req.json();

  const previousMessages = await loadChat(id);

  const messages = [...previousMessages, message];

  const validatedMessages = await validateUIMessages({
    messages,
    tools,
    dataSchemas,
    metadataSchema,
  });

  const result = streamText({
    model: anthropic('{{ site.models.anthropic_latest }}'),
    messages: await convertToModelMessages(validatedMessages),
    tools,
  });

  return createUIMessageStreamResponse({
    stream: toUIMessageStream({
      stream: result.stream,
      originalMessages: messages,
      onEnd: ({ messages }) => {
        saveChat({ chatId: id, messages });
      },
    }),
  });
}
```

Comments are removed, and the model matches the other examples. The guide's example `saveChat` writes JSON files and notes that a real application would use a database. A page component then loads the messages and passes them to a client component that calls `useChat`.

In Rails, two generators write the whole thing as your application's code:

```bash
bin/rails generate ruby_llm:install
bin/rails generate ruby_llm:chat_ui
bin/rails db:migrate
```

The install generator writes your `Chat` and `Message` models and their migrations. The chat UI generator adds controllers, views, and an Active Job that streams each answer into the page over Turbo Streams. The conversation is stored as rows as it happens:

```ruby
class Chat < ApplicationRecord
  acts_as_chat
end

chat = Chat.create! model: "{{ site.models.anthropic_latest }}"
chat.ask "What is the weather in Berlin?"

chat.messages.count # => 2
```

Agents work on these records too. Point your agents at the model with `chat_class Chat`, then `WeatherAgent.create!` starts a stored conversation and `WeatherAgent.find(id)` loads one with the agent's tools and instructions applied. Because the transcript is the state, a job can run one move of the loop and enqueue the next, and a worker that dies mid-conversation resumes where it stopped:

```ruby
class AgentTurnJob < ApplicationJob
  def perform(chat_id)
    chat = WeatherAgent.find chat_id
    chat.step

    AgentTurnJob.perform_later chat_id unless chat.complete? || chat.waiting?
  end
end
```

See [Rails Integration]({% link _getting_started/rails.md %}), [Streaming with Hotwire/Turbo]({% link _advanced/rails-streaming.md %}), and [Agents in Background Jobs]({% link _advanced/durable-agents.md %}).

## Usage and Cost

The AI SDK reports tokens. `result.usage` has `inputTokens`, `outputTokens`, cache and reasoning details, and `totalTokens`, summed across steps. It has no cost field. Through Vercel's AI Gateway, you can look up a generation's cost with a second call to `gateway.getGenerationInfo`.

RubyLLM reports tokens and dollars on every response and chat, priced from its model registry:

```ruby
response = chat.ask "What is the weather in Berlin?"

response.tokens.input
response.tokens.output
response.cost.total
chat.cost.total
```

With `acts_as_chat`, every billed attempt also lands in the `ruby_llm_usages` table, including failed and cancelled ones, and `RubyLLM.with_usage_owner` attributes each row to a user or account, so spend per customer is a SQL query. See [Cost and Usage Tracking]({% link _core_features/cost-and-usage-tracking.md %}).

## Concept Map

| AI SDK | RubyLLM |
| --- | --- |
| `tool({ description, inputSchema, execute })` | A [`RubyLLM::Tool`]({% link _getting_started/tools.md %}) class with `description` and `execute` |
| `ToolLoopAgent` | A [`RubyLLM::Agent`]({% link _getting_started/agents.md %}) class |
| `instructions` | `instructions` |
| `stopWhen: isStepCount(n)` | `generate`, `run_tools`, and `complete?` in your own loop |
| `agent.stream()` and `textStream` | A block given to `ask` |
| `Output.object({ schema })` and `output` | `with_schema` and `response.parsed` |
| `providerOptions` | `with_provider_options`, or `provider_options` on an agent |
| `embed` | `RubyLLM.embed` |
| `useChat` and a route handler | The `ruby_llm:chat_ui` generator and Turbo Streams |
| Your own `loadChat` and `saveChat` | `acts_as_chat` |
| `result.usage` | `response.tokens` and `response.cost` |

## When to Choose the AI SDK

* **Your application is TypeScript.** Next.js, SvelteKit, Nuxt, or a Node service. The AI SDK is the natural choice there, and its UI hooks stream straight into React, Svelte, and Vue components.
* **You deploy to serverless or edge functions.** The SDK is built for Vercel's runtime, and the AI Gateway gives you one key for many providers.
* **You want generative UI.** Typed tool parts render as components in the browser as the model calls them.

## When to Choose RubyLLM

* **Your application is Ruby or Rails.** Chats are Active Record models, agents run in Active Job, and the chat UI is Hotwire code you own.
* **Conversations must survive processes.** Approvals, cancellation, queued messages, and the loop itself read and write the database, so a deploy or a crashed worker loses nothing.
* **You need to know what it costs.** Every response, chat, and agent reports dollars, and Rails apps get a usage ledger.
* **You need more than chat.** Images, video, speech, transcription, OCR, moderation, embeddings, and reranking come from the same gem with the same configuration.

## Next Steps

* [Getting Started]({% link _getting_started/getting-started.md %}) - Install RubyLLM and make your first call.
* [Agents]({% link _getting_started/agents.md %}) - Define agents as classes and use them anywhere.
* [Rails Integration]({% link _getting_started/rails.md %}) - Persist chats and stream them with Hotwire.
