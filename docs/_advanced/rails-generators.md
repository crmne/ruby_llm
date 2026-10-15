---
layout: default
title: Generators and App Conventions
parent: "Rails Integration"
nav_order: 3
description: Scaffold chats, a chat UI, agents, tools, and schemas with RubyLLM's Rails generators and conventions.
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

*   What the `ruby_llm:install` and `ruby_llm:chat_ui` generators create for you.
*   How RubyLLM's conventional app directory structure is organized.
*   How to generate agents, tools, schemas, MCP servers, skills, sandboxes, evaluations, and judges.
*   How the generated chat UI renders messages, tool calls, tool results, approvals, and attachments.
*   How to customize model names and set up ActiveStorage.

RubyLLM's generators write models, migrations, controllers, jobs, and views into your application. Start with persistence, then add the chat UI or generate individual agents, tools, and schemas as you need them.

## Quick Setup with Generator

Run the install generator:

```bash
bin/rails generate ruby_llm:install
```

The generator:

- Creates application migrations and models for Chat and Message
- Creates one migration for RubyLLM's internal model, tool-call, usage, and batch tables
- Adds the `acts_as_chat` and `acts_as_message` declarations
- Installs ActiveStorage for file attachments
- Creates an initializer for provider configuration
- Creates the conventional AI app directories: `app/agents`, `app/tools`, `app/schemas`, `app/prompts`, `app/skills`, `app/sandboxes`, `app/mcp`, `app/evals`, and `app/judges`

After running the generator:

```bash
bin/rails db:migrate
bin/rails ruby_llm:load_models
```

You can now create a persisted chat with `Chat.create!` and send a message with `chat.ask`.

### Install Generator Options

The generator uses Rails-like syntax for custom model names:

```bash
# Default - creates the application Chat and Message models
bin/rails generate ruby_llm:install

bin/rails generate ruby_llm:install chat:Conversation message:ChatMessage
bin/rails generate ruby_llm:install chat:Discussion message:DiscussionMessage

# Skip ActiveStorage if you don't need file attachments
bin/rails generate ruby_llm:install --skip-active-storage
```

The `name:ClassName` syntax follows Rails conventions - specify only what you want to customize.

For most apps, keep the default behavior (install ActiveStorage) so file attachments work out of the box. Use `--skip-active-storage` only when you're sure you won't send files to models.

## Adding a Chat UI

Run the chat UI generator to add controllers, views, and a background job:

```bash
bin/rails generate ruby_llm:chat_ui
```

The generator creates:

- **Controllers**: Create chats, enqueue message processing, and record approval decisions
- **Views**: Render messages, their attachments, and approval cards, and update them with Turbo Streams
- **Jobs**: Request AI responses in the background and continue the conversation after a decision
- **Routes**: RESTful routes for chats, messages, and approvals

Start your server and visit `http://localhost:3000/chats`.

The UI generator also supports custom model names:

```bash
bin/rails generate ruby_llm:chat_ui chat:Conversation message:ChatMessage
```

### Approvals and Attachments

When a tool [requires approval]({% link _core_features/tool-execution.md %}#requiring-approval), the chat page shows a card for each call in `chat.pending_approvals`, with its arguments and Approve and Deny buttons. A `run_code` call that asks for a [wider sandbox]({% link _core_features/sandboxes.md %}) shows its reason, its code, and what that sandbox allows. Remote tool calls, such as those from MCP servers, get the same cards. While a call waits, the transcript hides its tool call entry so the call shows only as a card, and the message form gives way to a line asking for a decision. `MessagesController` redirects a message sent in the meantime back to the chat.

Each button posts to `ApprovalsController#create`, which records the decision with `chat.approve` or `chat.deny`, replaces the cards with a Turbo Stream, and enqueues `ChatResponseJob` to continue the conversation. Decided calls show as ordinary tool calls with their results. When the job finishes or pauses for the next approval, it broadcasts the cards and the message form to the page.

The generated controllers and job load chats with `Chat.find`, which has the transcript but no tools. Load the chat through your agent instead, so the page and the job know which calls need approval:

```ruby
# app/controllers/chats_controller.rb
@chat = SupportAgent.find(params[:id])

# app/controllers/messages_controller.rb and app/controllers/approvals_controller.rb
@chat = SupportAgent.find(params[:chat_id])

# app/jobs/chat_response_job.rb
chat = SupportAgent.find(chat_id)
```

Messages show their Active Storage attachments: images inline, and other files as download links with their size. That includes the files a code run returns, such as charts.

## Upgrading an Existing Integration

When a release changes the Rails schema, it ships `ruby_llm:upgrade` for applications on the previous release. The generator covers only the changes since that release, so upgrade one release at a time. See [Upgrading]({% link _reference/upgrading.md %}) for the current steps.

An application on RubyLLM 1.16 first installs 2.0 and follows the [2.0 upgrade guide](https://github.com/crmne/ruby_llm/blob/v2.0.0/docs/_reference/upgrading.md).

## Conventional Directory Structure

RubyLLM's Rails generators establish a default app structure:

```text
app/
|-- agents/      agent classes
|-- tools/       tool classes
|-- schemas/     structured output schemas
|-- prompts/     ERB instructions, one folder per agent
|-- skills/      Agent Skills folders, one per skill
|-- sandboxes/   sandbox classes for code execution
|-- mcp/         MCP server classes
|-- evals/       evaluations and their datasets
`-- judges/      judge classes
```

The install generator creates these directories with `.gitkeep` files so teams start from one shared convention, and the upgrade generator adds any an existing application lacks.

These are conventions, not hard requirements:

- Agents, tools, schemas, sandboxes, MCP servers, and judges can live anywhere in your app autoload paths.
- `with_skills` and the `skills` macro find skills in `app/skills` unless you add other roots.
- Evaluations find their dataset next to the class in `app/evals`.
- Prompt lookup convention: named agents automatically resolve `instructions.txt.erb` from the agent class name when the file exists.

For prompt lookup, RubyLLM uses class name conventions:

- `WorkAssistant` -> `app/prompts/work_assistant/instructions.txt.erb`
- `Admin::SupportAgent` -> `app/prompts/admin/support_agent/instructions.txt.erb`

See the [Agents guide]({% link _advanced/agents.md %}#default-instructions-prompt) for how agent instruction rendering works, or [Prompt Rendering]({% link _core_features/prompt-rendering.md %}) for direct `RubyLLM.render_prompt` usage.

## Generators

Alongside `ruby_llm:install` and `ruby_llm:chat_ui`, every building block has a generator that puts it where RubyLLM looks for it:

```bash
bin/rails generate ruby_llm:agent Support
bin/rails generate ruby_llm:tool Weather
bin/rails generate ruby_llm:schema Product
bin/rails generate ruby_llm:mcp Linear https://mcp.linear.app/mcp
bin/rails generate ruby_llm:skill invoices "Bills an order to a customer as a PDF."
bin/rails generate ruby_llm:sandbox Workspace
bin/rails generate ruby_llm:evaluation Support
bin/rails generate ruby_llm:judge Urgency
```

What each generator creates:

- `ruby_llm:agent`: `app/agents/support_agent.rb` and `app/prompts/support_agent/instructions.txt.erb`
- `ruby_llm:tool`: `app/tools/weather_tool.rb` plus tool-specific chat UI partials under `app/views/messages/tool_calls` and `app/views/messages/tool_results`
- `ruby_llm:schema`: `app/schemas/product_schema.rb`
- `ruby_llm:mcp`: `app/mcp/linear.rb`, connecting to the URL you give. For a server that runs on your machine, pass `--command` instead: `bin/rails generate ruby_llm:mcp Files --command "npx -y @modelcontextprotocol/server-filesystem ."`
- `ruby_llm:skill`: `app/skills/invoices/SKILL.md` with the name and description. Names use lowercase letters, digits, and hyphens, as the Agent Skills format requires.
- `ruby_llm:sandbox`: `app/sandboxes/workspace_sandbox.rb`, an `MXC::Sandbox` with a two-minute timeout
- `ruby_llm:evaluation`: `app/evals/support_evaluation.rb` and its dataset, `support_evaluation.yml`, with one case to fill in. It runs `SupportAgent` when you have one.
- `ruby_llm:judge`: `app/judges/urgency_judge.rb`

`ruby_llm:chat_ui` and `ruby_llm:tool` accept `--ui scaffold` or `--ui tailwind`. The default, `--ui auto`, picks Tailwind when your app has it. An existing app follows [Upgrading]({% link _reference/upgrading.md %}) instead of running `ruby_llm:install`.

If your chat UI uses a custom message model, pass the same mapping you gave `ruby_llm:chat_ui` so the partials land where the UI looks for them:

```bash
bin/rails generate ruby_llm:tool Weather message:ChatMessage
```

## Chat UI View Conventions

The generated chat UI follows one convention: each message partial uses the local that matches its partial name.

- `messages/_user.html.erb` gets `user`
- `messages/_assistant.html.erb` gets `assistant`
- `messages/_system.html.erb` gets `system`
- `messages/_tool.html.erb` gets `tool`
- `messages/_tool_calls.html.erb` gets `tool_calls`

This comes from Rails partial rendering: `render @chat.messages` calls `to_partial_path`, and Rails injects a local named after that partial.

For compatibility with model broadcasts (`broadcasts_to`), generated message partials also accept a `message` local as a fallback.

Shared partials take explicit locals: `messages/_attachments.html.erb` gets `message`, `chats/_approvals.html.erb` gets `chat`, and `approvals/_approval.html.erb` gets `approval` and `chat`.

### Tool Call and Tool Result Partials

Tool-specific partials are generated under `app/views/messages/tool_calls` and `app/views/messages/tool_results`:

```text
app/views/messages/
|-- tool_calls/
|   |-- _default.html.erb
|   `-- _your_tool.html.erb
`-- tool_results/
    |-- _default.html.erb
    `-- _your_tool.html.erb
```

Locals passed to those partials:

- `messages/tool_calls/_your_tool.html.erb` receives `message` and `tool_call`
- `messages/tool_results/_your_tool.html.erb` receives `tool`

`ruby_llm:tool` creates `_your_tool.html.erb` files with the correct names so custom rendering hooks up automatically.

Using fixed locals keeps the templates dumb and predictable.

Turbo Stream templates used by the generated chat UI:

- `messages/create.turbo_stream.erb` resets the message form for `MessagesController#create`.
- `approvals/create.turbo_stream.erb` replaces the approval cards for `ApprovalsController#create`.

## Setting Up ActiveStorage

The generator automatically configures ActiveStorage for file attachments. If you skipped it during generation, add it manually:

```bash
bin/rails active_storage:install
bin/rails db:migrate
```

Then add to your Message model:

```ruby
# app/models/message.rb
class Message < ApplicationRecord
  acts_as_message
  has_many_attached :attachments  # Required for file attachments
end
```

This `:attachments` association is only required on RubyLLM message records. The ActiveStorage attachments you pass to `with:` from your own models can use any name.

## Next Steps

*   [Persistence with acts_as]({% link _advanced/rails-persistence.md %}) - what the generated models do once they `acts_as_chat`.
*   [Streaming with Hotwire/Turbo]({% link _advanced/rails-streaming.md %}) - the streaming flow behind the generated chat UI.
*   [Agents]({% link _advanced/agents.md %}) - build on the generated agent and prompt conventions.
*   [Advanced Rails Configuration]({% link _advanced/rails-advanced-config.md %}) - provider overrides and custom contexts for the generated app.
