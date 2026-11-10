---
layout: default
title: Generators and App Conventions
nav_order: 9
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
- Creates one migration for RubyLLM's eight supporting tables: models, tool calls, usages, queued messages, chat files, batches, MCP credentials, and provider files
- Adds the `acts_as_chat` and `acts_as_message` declarations
- Installs Active Storage, which `acts_as_message` uses for attachments
- Creates an initializer for provider configuration and the context budget
- Creates `app/agents/application_agent.rb`, the parent of your agents, pointed at your chat model

Like Rails' own generators, it prints the files it creates and the one command you need next. Run it, set your provider's API key in `config/initializers/ruby_llm.rb`, and load the model registry:

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
```

The `name:ClassName` syntax follows Rails conventions - specify only what you want to customize.

The generated models are one line each:

```ruby
class Message < ApplicationRecord
  acts_as_message
end
```

`acts_as_message` declares the message's attachments and, when `config.broadcast_messages` is on, broadcasts the chat's messages with Turbo. `ruby_llm:chat_ui` turns that setting on in your RubyLLM initializer. See [Streaming with Hotwire/Turbo]({% link _advanced/rails-streaming.md %}).

## Adding a Chat UI

Run the chat UI generator to add controllers, views, and a background job:

```bash
bin/rails generate ruby_llm:chat_ui
```

The generator creates:

- **Agent**: `ChatAgent`, which the controllers and job create and load chats through
- **Controllers**: Create chats, save messages and enqueue their replies, queue and withdraw messages sent during a reply, and record approval decisions
- **Views**: Render messages, their attachments, queued messages, and approval cards, and update them with Turbo Streams
- **Jobs**: Request AI responses in the background and continue the conversation after a decision or with queued messages
- **Routes**: RESTful routes for chats, messages, queued messages, and approvals

Start your server and visit `http://localhost:3000/chats`.

`MessagesController` saves the person's message with `ask_later` and enqueues `ChatResponseJob` to answer it:

```ruby
@chat.ask_later(content, with: attachments)
ChatResponseJob.perform_later(@chat.id)
```

The message form has the same model picker as the new-chat form, with the chat's current model selected. When a message comes with another model, `MessagesController` switches the chat with `with_model` before `ask_later`, so the reply and every later one use it, and a reload shows the new model:

```ruby
provider, model = selected.split(":", 2)
@chat.with_model(model, provider: provider)
```

`ask_later` saves the message when the chat is idle. While a reply runs, it [queues]({% link _advanced/rails-persistence.md %}#queued-messages) the message instead, so the transcript that reply writes stays whole. The running job answers it right after: a run takes the messages that wait at each step, and looks again once it lets the chat go. The message is saved before the job runs, so a job that runs again after a failure does not repeat it.

The job completes the chat, streaming each reply with the chunks' own `broadcast`:

```ruby
class ChatResponseJob < ApplicationJob
  discard_on RubyLLM::CancelledError

  def perform(chat_id)
    chat = ChatAgent.find(chat_id)
    chat.complete(&:broadcast)
    retry_job wait: 1.minute if chat.running?
  end
end
```

When another process is running the chat, `complete` returns at once, and the job tries again a minute later. That retry only matters when the other process has died: a live one answers what waits before it lets the chat go, and the claim of a dead one expires within a minute, so the retry finds the chat free. No queue runs the job the dead process was running again, so the generator also writes `app/jobs/resume_interrupted_chats_job.rb`, which answers the chats a dead process left. It runs every minute from Solid Queue's `config/recurring.yml`, when the app has one, and as soon as the web server boots, from `config/initializers/resume_interrupted_chats.rb`, so a reply a deploy or a restart cut off resumes right away. A process killed outright leaves claims that expire within a minute, so the boot run comes back once when the last of them expires, and resumes those replies about a minute after the kill. See [Resuming a Crashed Run]({% link _advanced/durable-agents.md %}#resuming-a-crashed-run). `ChatsController#create` enqueues a new chat's first reply a second later, so the new page has subscribed to the chat's stream before the reply starts.

`MessagesController` answers the send with a Turbo Stream that clears the form and refreshes the page, so the message shows right away, in the transcript or queued under it, without waiting for the job. RubyLLM's page refreshes carry no request id, so Turbo never skips one as the page's own. The message form sits in a Turbo Frame, so a page refresh that starts while the message is sending doesn't cancel the send.

Replies stream into the page chunk by chunk, and the finished message replaces the streamed text once when it is saved. New messages, approval cards, and the form appear through page refreshes, so the page always matches what a reload would show. A Stimulus controller that ships with RubyLLM puts the chunks in order, ignores an empty reply that arrives after the failed reply's removal, and renders assistant replies as Markdown, sanitized with DOMPurify. It also refreshes the page whenever the chat's stream connects, the `turbo_stream_from` with `data: { chat_stream: true }`, so the page shows what was broadcast before it subscribed or while it was offline. A refresh that arrives while another visit loads waits until that visit ends, since Turbo would drop it. Images in a reply show as text, so a prompt injection cannot make the browser fetch a URL that leaks the chat, while attachments still show. In an app with an import map and no jsbundling-rails, RubyLLM pins the controller as `ruby_llm/chat_message_controller`, along with `marked` and `dompurify`, and the generated `app/javascript/controllers/chat_message_controller.js` is one line that loads it, so the controller updates with the gem. An app that switches to importmap-rails after running the generator, without jsbundling-rails, has a copy of the controller instead; replace it with that line, `export { default } from "ruby_llm/chat_message_controller"`. Pins in your own `config/importmap.rb` win, and to change the controller, replace that line with your own. In an app that bundles its JavaScript with jsbundling-rails, the generator copies the controller into that file, even when the app also has importmap-rails. Add the packages it imports with your app's package manager, such as `yarn add marked@18.0.14 dompurify@3.4.16`, or `npm install` with the same two packages, and register the controller as `chat-message`, as you register your other Stimulus controllers. `bin/rails stimulus:manifest:update` does that by rewriting `app/javascript/controllers/index.js` from the files next to it, so if you keep that file by hand, add the registration to it yourself instead. With another bundler, add the same packages and register the controller the same way. Without JavaScript, replies show as plain text. See [Message Ordering Issues]({% link _advanced/rails-streaming.md %}#message-ordering-issues).

While the job runs the chat, an empty reply shows "Thinking…", the message form stays, and a Stop button posts to `ChatsController#cancel`, which calls [`chat.cancel`]({% link _advanced/rails-streaming.md %}#cancelling-a-background-stream). Stop raises `RubyLLM::CancelledError` in the job, which discards it. A message sent while a reply runs shows under the transcript, faded, with a Cancel button that posts to `QueuedMessagesController#destroy`, which finds the queued message and calls `withdraw` on it. When Stop ends a reply while messages wait, `complete` goes on to answer them before the job ends. Each finished reply shows what it cost, and the page shows the chat's total. Both message forms take file attachments, and the Stimulus controller keeps a page refresh from undoing any field a person changed in the message form, whether what they are typing, the model they picked, or a field your app adds. Sending clears the form, and another chat starts empty.

When a reply fails, `complete` saves a message for the person in the chat's `reply_error` column, refreshes the page, and raises, so the job fails and your error reporting sees it. The page renders the message whenever it loads or refreshes, including the refresh it makes once its stream connects, so it shows a quick failure even when the failure's broadcast came before the page subscribed, and the next run clears it. The message is "The reply failed. Send your message again.", or "This conversation is too long for the model. Start a new chat." for `RubyLLM::ContextLengthExceededError`. Change or translate them with the I18n keys `ruby_llm.reply_error.failed` and `ruby_llm.reply_error.too_long`. The generator adds the column with a migration, so run `bin/rails db:migrate` after it.

The generator needs Hotwire's `turbo-rails` and `stimulus-rails`, which a plain `rails new` has, and says so when an app lacks them. Install them as their guides describe for your JavaScript setup and package manager; an app with no JavaScript yet can add them with an import map, with `bundle add turbo-rails stimulus-rails importmap-rails` and `bin/rails importmap:install turbo:install stimulus:install`. When the app has `test/test_helper.rb`, it also writes `test/system/chats_test.rb`, so `bin/rails test:system` checks streaming, Stop, a message sent right after a reply or Stop, switching the model mid-conversation, cost, and errors with [scripted replies]({% link _advanced/testing.md %}), in a real browser. That needs Chrome, and it adds `capybara` and `selenium-webdriver` to your test group when they're missing. It writes `test/agents/chat_agent_test.rb` too, which `bin/rails test` runs to check the agent's context budget. In tests of your own, `RubyLLM::TestHelper` scripts the replies, with no provider or key.

The UI generator also supports custom model names:

```bash
bin/rails generate ruby_llm:chat_ui chat:Conversation message:ChatMessage
```

### Questions and Attachments

When a tool call [waits on a person]({% link _tools/tool-execution.md %}#asking-a-person), the chat page shows a card for each question in `chat.pending_questions`. An approval shows the call's arguments with Approve and Deny buttons. A `run_code` call that asks for a [wider sandbox]({% link _advanced/sandboxes.md %}) shows its reason, its code, and what that sandbox allows. A question a tool asks with `ask`, or an MCP server asks, shows a button for each choice, Yes and No for a yes-or-no question, a field for free text or a number, a form for several fields, or the whole address of the page it asks the person to visit, with a Decline button. Remote tool calls, such as those from MCP servers, get the same cards. While an approval waits, the transcript hides its tool call entry so the call shows only as a card, and the message form gives way to a line asking for an answer. `MessagesController` redirects a message sent in the meantime back to the chat.

Each card posts to `AnswersController#create`, which records the answer with `chat.answer`, or `chat.decline` for Deny and Decline, replaces the cards with a Turbo Stream, and enqueues `ChatResponseJob` to continue the conversation. An answer the question can't take, such as a choice it doesn't offer, comes back to the chat page as a notice, and the question keeps waiting. Approved calls run, and a tool that asked runs again with the answer. When the job finishes or pauses for the next question, the page refreshes with the new cards and the message form.

The chat UI talks to `ChatAgent` in `app/agents/chat_agent.rb`. The controllers and the job create chats with `ChatAgent.create!` and load them with `ChatAgent.find`, so whatever you add to it reaches the UI. Give it tools, instructions, an MCP server, files, or code execution, one line each, and every question its tools ask gets a card:

```ruby
class ChatAgent < ApplicationAgent
  instructions "You help the finance team with invoices."
  tools SendInvoiceTool
  mcp LinearMcp
  file_store
  code_execution sandbox: ReadOnlySandbox, escalate_to: [WorkspaceSandbox]
end
```

Generate the classes it names first, with `ruby_llm:tool SendInvoice`, `ruby_llm:mcp Linear URL`, and `ruby_llm:sandbox` for each sandbox. `file_store` gives the model tools to read, search, and edit the chat's files; with it, code reads a chat's attachments in `attachments/`, and what the code writes joins the chat's files.

Where the rest lives, with the default model names: `app/jobs/chat_response_job.rb` runs each turn and saves its errors, `ChatsController#cancel` is the Stop button, and `app/views/messages/_assistant.html.erb` renders a reply.

The generated agent starts with [prompt caching]({% link _core_features/prompt-caching.md %}):

```ruby
class ChatAgent < ApplicationAgent
  caching
end
```

Its chats use the [context budget]({% link _core_features/chat-request-control.md %}#keeping-tool-results-in-budget) the install generator writes into `config/initializers/ruby_llm.rb`, so you can rewrite the agent freely. The chat UI generator adds it there too when your initializer sets none:

```ruby
config.context_budget = { per_result: 0.25, per_request: 0.7 }
```

A tool result longer than a quarter of the model's context window is cut when it is added, and a request that would take more than 70% of the window leaves out the oldest tool results. Without it, one tool result larger than the window stays in the transcript, and every later reply in that chat fails with `RubyLLM::ContextLengthExceededError`. Raise `per_request` if your tools return mostly prose, or remove the line to send every result whole.

`caching` turns on the provider's default prompt caching. Every reply and every tool round sends the whole conversation again, usually seconds after the last request. Once that unchanged prefix reaches the model's minimum cacheable length, it is read from the cache at a lower price. Anthropic caches only when RubyLLM asks it to, and on Bedrock RubyLLM adds cache points; OpenAI and Gemini cache on their own either way and keep the cache as long as they choose. On Anthropic and Bedrock the default cache lives for 5 minutes, and a chat that sits idle longer pays the cache write surcharge again on its next reply. If your users come back to chats after longer pauses, pass a longer lifetime, such as `caching ttl: 1.hour`, on models that [accept one]({% link _core_features/prompt-caching.md %}#automatic-prompt-caching); it costs more to write. Pass `caching false` to stop asking for caching. When your `ApplicationAgent` already declares `caching`, the generated agent leaves it out and inherits that policy.

The agent is named after your chat model: `chat:Conversation` gives `ConversationAgent`, and `chat:Llm::Chat` gives `Llm::ChatAgent` in `app/agents/llm/chat_agent.rb`.

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

Each generator puts what it creates in its folder, so your application has the folders it uses and no empty ones.

These are conventions, not hard requirements:

- Agents, tools, schemas, sandboxes, MCP servers, and judges can live anywhere in your app autoload paths.
- `with_skills` and the `skills` macro find skills in `app/skills` unless you add other roots.
- Evaluations find their dataset next to the class in `app/evals`.
- Prompt lookup convention: named agents automatically resolve `instructions.txt.erb` from the agent class name when the file exists.

For prompt lookup, RubyLLM uses class name conventions:

- `WorkAssistant` -> `app/prompts/work_assistant/instructions.txt.erb`
- `Admin::SupportAgent` -> `app/prompts/admin/support_agent/instructions.txt.erb`

See the [Agents guide]({% link _getting_started/agents.md %}#keeping-instructions-in-prompt-templates) for how agent instruction rendering works, or [Prompt Rendering]({% link _core_features/prompt-rendering.md %}) for direct `RubyLLM.render_prompt` usage.

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

- `ruby_llm:agent`: `app/agents/support_agent.rb`, a subclass of `ApplicationAgent`, and `app/prompts/support_agent/instructions.txt.erb`. In an app without `ApplicationAgent`, the agent inherits from `RubyLLM::Agent` and names its chat model itself.
- `ruby_llm:tool`: `app/tools/weather_tool.rb` plus tool-specific chat UI partials under `app/views/messages/tool_calls` and `app/views/messages/tool_results`. Offer it with `tools WeatherTool` in an agent or `with_tools(WeatherTool)` on a chat.
- `ruby_llm:schema`: `app/schemas/product_schema.rb`
- `ruby_llm:mcp`: `app/mcp/linear_mcp.rb`, a `LinearMcp` server connecting to the URL you give, or `LinearMCP` when your inflections make MCP an acronym. For a server that runs on your machine, pass `--command` instead: `bin/rails generate ruby_llm:mcp Files --command "npx -y @modelcontextprotocol/server-filesystem ."`. Connect it with `mcp LinearMcp` in an agent or `with_mcp(LinearMcp)` on a chat.
- `ruby_llm:skill`: `app/skills/invoices/SKILL.md` with the name and description. Names use lowercase letters, digits, and hyphens, as the Agent Skills format requires.
- `ruby_llm:sandbox`: `app/sandboxes/workspace_sandbox.rb`, an `MXC::Sandbox` with a two-minute timeout, `gem "mxc", ">= 0.4.1"` in your Gemfile when it is missing, so run `bundle install` after it, and `config.sandbox` in your initializer when you have no default sandbox yet. Turn code execution on with `code_execution` in an agent or `with_code_execution` on a chat.
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

A reply that also calls a tool renders as `messages/_tool_calls.html.erb`, which renders `messages/_assistant.html.erb` for its text with `nested: true`, so a change to the assistant card shows on those replies too.

Shared partials take explicit locals: `messages/_attachments.html.erb` gets `message`, `chats/_questions.html.erb` gets `chat`, and `questions/_question.html.erb` gets `question` and `chat`.

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

`ruby_llm:tool` creates `_your_tool.html.erb` files with the correct names so custom rendering hooks up automatically: `messages/_tool_calls.html.erb` renders `tool_call_partial(tool_call)`, which is the call's own partial in the `tool_calls` folder beside it, or `_default`, and `messages/_tool.html.erb` does the same with `tool_result_partial(tool)`.

Using fixed locals keeps the templates dumb and predictable.

### View Helpers

The views use helpers that RubyLLM adds to every view, so the generator writes no helper of its own:

- `tool_call_partial(tool_call)` and `tool_result_partial(message)` pick a tool's partial, as described above.
- `tool_label(name)` and `tool_result_label(message)` turn a tool's name into a label, such as "Send mail".
- `cost_label(cost)` shows a `RubyLLM::Cost` in US dollars to four decimal places, such as "$0.0123". RubyLLM prices every cost in US dollars, so the label stays in dollars whatever your locale.
- `default_model_display_name` labels the model picker's empty choice with the name of `config.default_model`.

To change one, define a method with the same name in a helper of your own, such as `app/helpers/messages_helper.rb`: it takes the place of RubyLLM's in every view. A chat UI generated before RubyLLM shipped these keeps the `MessagesHelper` the generator wrote, and its methods win the same way.

Turbo Stream templates used by the generated chat UI:

- `messages/create.turbo_stream.erb` resets the message form for `MessagesController#create`.
- `answers/create.turbo_stream.erb` replaces the question cards for `AnswersController#create`.

## Setting Up Active Storage

`acts_as_message` stores attachments with Active Storage, and the install generator installs it. Without it, the message model boots without attachments and RubyLLM logs how to add them. An application that does not have it yet runs:

```bash
bin/rails active_storage:install
bin/rails db:migrate
```

The ActiveStorage attachments you pass to `with:` from your own models can use any name.

## Next Steps

*   [Persistence with acts_as]({% link _advanced/rails-persistence.md %}) - what the generated models do once they `acts_as_chat`.
*   [Streaming with Hotwire/Turbo]({% link _advanced/rails-streaming.md %}) - the streaming flow behind the generated chat UI.
*   [Agents]({% link _getting_started/agents.md %}) - build on the generated agent and prompt conventions.
*   [Advanced Rails Configuration]({% link _advanced/rails-advanced-config.md %}) - provider overrides and custom contexts for the generated app.
