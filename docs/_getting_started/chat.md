---
layout: default
title: Chat
nav_order: 3
has_children: true
description: Start a conversation, give it instructions, and switch models while keeping the same Ruby API.
redirect_from:
  - /guides/chat
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* How to start and continue a conversation.
* How to give the model instructions.
* How to choose and switch models.
* How to control how varied answers are, and when to let the model think.
* Why a response stopped, and how to read the raw provider response.
* Where to go for attachments, streaming, structured output, and costs.

## Starting a Conversation

`RubyLLM.chat` starts a conversation with your default model. `ask` sends a message and returns the model's answer:

```ruby
chat = RubyLLM.chat

response = chat.ask "A customer says their parcel arrived damaged. Draft a short, friendly reply."
puts response.content
# => "I'm so sorry your parcel arrived damaged. Could you send a photo of..."
```

`ask` adds your message to the conversation as a `:user` message, sends the whole conversation to the provider, and returns the answer as a `RubyLLM::Message`. `say` does the same, for code where it reads better.

When the chat has [tools]({% link _getting_started/tools.md %}), `ask` keeps going until the model answers: it runs the tools the model calls and asks the model again. To run that loop yourself, see [Driving the Loop Yourself]({% link _advanced/agentic-workflows.md %}#driving-the-loop-yourself).

## Continuing the Conversation

Ask again on the same chat, and the model sees everything said so far:

```ruby
chat.ask "Make it shorter, and offer a replacement."

chat.messages.map(&:role)
# => [:user, :assistant, :user, :assistant]
```

`chat.messages` holds the conversation. RubyLLM sends it with every request, so you never assemble the history yourself.

### Branching a Conversation

`dup` copies a chat, so you can try another direction without touching the original:

```ruby
refund = chat.dup
refund.ask "Rewrite it to offer a refund instead."

chat.messages.count   # => 4
refund.messages.count # => 6
```

The copy starts with the same messages, tools, and options. From then on, each chat keeps its own messages and settings. Both chats share the same tool instances, so give each branch a fresh instance of a tool that keeps state.

## Giving the Model Instructions

Instructions tell the model who it is and how to behave for the whole conversation:

```ruby
chat = RubyLLM.chat
chat.with_instructions "You answer customers of Acme Outfitters. Be brief and friendly."

chat.ask "Can I change the delivery address on my order?"
```

`with_instructions` replaces the current instructions. Pass `append: true` to add to them, or `nil` to remove them:

```ruby
chat.with_instructions "Answer in the customer's language.", append: true
chat.with_instructions nil
```

Instructions are `:system` messages that RubyLLM sends with every request. In Rails, they're saved with the rest of the conversation. Longer instructions belong in a template in `app/prompts`; see [Prompt Rendering]({% link _core_features/prompt-rendering.md %}) and, for agents, [Keeping Instructions in Prompt Templates]({% link _getting_started/agents.md %}#keeping-instructions-in-prompt-templates).

## Working with Different Models

Pass `model:` to choose a model, and `with_model` to switch in the middle of a conversation:

```ruby
chat = RubyLLM.chat(model: "{{ site.models.anthropic_current }}")
chat.ask "Summarize this customer's complaint in one line: ..."

chat.with_model "{{ site.models.gemini_current }}"
chat.ask "Now suggest three ways to make it right."
```

RubyLLM finds the provider from the model name, and the conversation carries over. `with_model nil` goes back to your default model. See the [Model Registry]({% link _reference/models.md %}) for capabilities, aliases, and custom models, and [Model Resolution]({% link _reference/model-resolution.md %}) for how a name becomes a model and a provider.

## Controlling Responses

### Temperature

Temperature controls how varied the answers are. Low values give focused, repeatable answers; high values give more varied ones:

```ruby
replies = RubyLLM.chat.with_temperature(0.2)
replies.ask "What is your returns policy for sale items?"

slogans = RubyLLM.chat.with_temperature(0.9)
slogans.ask "Write five subject lines for our winter sale email."
```

Until you set a temperature, RubyLLM sends none and the model uses its own default. `with_temperature nil` removes it again.

Many reasoning models reject a temperature or accept only one value, and which ones do changes from model to model. RubyLLM sends the value you set unchanged, so such a model answers with an error, raised as [`RubyLLM::BadRequestError`]({% link _advanced/error-handling.md %}). Leave the temperature unset for those models.
{: .note }

### Letting the Model Think

Reasoning models can think before they answer: they work through the problem first and write the answer after. Thinking costs more and takes longer, because the model generates, and you pay for, the thinking tokens too.

Turn it on where a better answer is worth the wait: a refund dispute that weighs an order's history against the returns policy, a bug report that needs reasoning across several log lines, or a plan with several steps. Leave it off for replies that need no reasoning, such as rewording a message or answering from one help article.

```ruby
chat = RubyLLM.chat(model: "{{ site.models.anthropic_current }}").with_thinking(effort: :high)
response = chat.ask "This customer has returned 6 of their last 8 orders. Should we approve another return?"

response.thinking&.text
response.content
```

See [Extended Thinking]({% link _core_features/thinking.md %}) for effort, budgets, streaming the thinking, and provider differences.

### Request Options

For provider-specific options, the wire protocol, request hooks, and custom headers, see [Advanced Request Control]({% link _core_features/chat-request-control.md %}).

## Finish Reasons

`finish_reason` tells you why the model stopped. RubyLLM maps each provider's values onto four symbols: `:stop`, `:max_tokens`, `:tool_calls`, and `:content_filter`. Anything else comes through as the provider named it, as a lowercase symbol, such as Anthropic's `:pause_turn` or Gemini's `:malformed_function_call`.

```ruby
response = chat.ask "Summarize this ticket in one paragraph."

if response.truncated?
  puts "The response hit a token limit."
elsif response.content_filtered?
  puts "The provider filtered the response."
elsif response.tool_call_stop?
  puts "The model requested a tool call."
elsif response.stopped?
  puts "The model finished normally."
end

response.finish_reason # => :stop, :max_tokens, :tool_calls, or :content_filter
```

Anthropic's `end_turn`, Gemini's `STOP`, Cohere's `COMPLETE`, and the Responses API's `completed` all arrive as `:stop`, so the same code reads every provider. A response that carries tool calls answers `tool_call_stop?`, not `stopped?`. A finish reason describes a response the provider completed. A failed request raises an error instead. RubyLLM never sends `finish_reason` back to a provider.

Providers that filter content, such as Azure, also say what their filters found, on the request and on the response, in `content_filters`. Each `RubyLLM::ContentFilter` names its `source` (`:prompt` or `:completion`), its `category` as the provider spells it, and its `severity`, and answers `filtered?` when it blocked or cut the text:

```ruby
if response.content_filtered?
  response.content_filters.select(&:filtered?).map { |filter| [filter.source, filter.category, filter.severity] }
  # => [[:completion, "hate", "medium"]]
end
```

A verdict never holds the text it judged, so you can log it. Only the live response carries the verdicts; a persisted chat does not store them.

A token limit can also cut off a tool call while the model writes its arguments. The chat then raises `RubyLLM::ToolCallTruncatedError`, a kind of `RubyLLM::ToolCallParseError`. Unless you call `with_max_output_tokens`, RubyLLM asks providers that need a number for the model's whole output limit, so this only happens when the model writes more than it can. Arguments that aren't a JSON object for any other reason don't raise: the tool doesn't run and no approval is asked, the call gets an error result that names the problem, and the model calls the tool again. Later requests send the bad call with empty arguments, so the provider never sees the invalid text again.
{: .note }

## Long Responses

Gemini models that support long decode can write more than one response holds. Set a total output budget above 65,536 tokens and stream the answer:

```ruby
response = chat.with_max_output_tokens(262_144).ask "Work through this proof in full" do |chunk|
  print chunk.content
end
```

Gemini pauses at its per-response limit and hands back a continuation token. RubyLLM sends the same request again with the newest token, streams the rest, and returns one message. The budget covers every request. Each request has its own usage entry, and the message's tokens and cost add them up. A paused response that only thought produces no blank message.

Stream long responses. Without a block, each response holds at most 32,768 tokens, and the Gemini API rejects a larger budget. Vertex AI accepts it and continues in 32,768-token responses.

While RubyLLM continues, the unfinished answer stands at the end of `chat.messages`. If a request fails, it stays there with its token, and `complete` picks the answer up where Gemini paused instead of starting again:

```ruby
begin
  chat.ask("Work through this proof in full") { |chunk| print chunk.content }
rescue RubyLLM::ServiceUnavailableError
  chat.complete { |chunk| print chunk.content }
end
```

Gemini rejects the token if the conversation or the model changed, and each continuation bills the earlier output again as input. Chunks from the request that failed stream again, because the answer resumes from the last pause. A persisted chat keeps the unfinished answer and its token in the `continuation` column, so a job that runs `chat.complete` again resumes it after a restart. See [Rails Integration]({% link _advanced/rails-persistence.md %}#resuming-long-responses).

## Raw Responses

`response.raw` is the provider's response as a `Faraday::Response`, with its status, headers, and body:

```ruby
response = chat.ask "Where is order R-1042?"
response.raw.status
response.raw.headers["x-request-id"]
```

It keeps no copy of the request it answered, neither body nor headers, so a long conversation doesn't hold every request it sent, and logging the response never prints your API key. The response an error carries, `error.response`, keeps no request either. To see what a chat sends, use `render` or a `before_request` hook; see [Request Hooks]({% link _core_features/chat-request-control.md %}#request-hooks).

## Replacing the Model's Transcript

`chat.messages` is what the model sees, and you can replace it. Your application can keep a different transcript for people. Use this for compaction, moderation, redaction, or any case where the model should see something other than what the customer sees.

```ruby
messages_for_model = chat.messages.last(4)
chat.messages = messages_for_model
```

For persisted Rails chats, see [Separate User and LLM Transcripts]({% link _advanced/rails-persistence.md %}#separate-user-and-llm-transcripts).

## Going Further

Each part of a conversation has its own guide in Chat in Depth:

* [Attachments]({% link _core_features/attachments.md %}): images, video, audio, text files, and PDFs.
* [Streaming]({% link _core_features/streaming.md %}): show answers as they're written.
* [Structured Output]({% link _core_features/structured-output.md %}): answers that match a schema.
* [Extended Thinking]({% link _core_features/thinking.md %}): effort, budgets, and reading the model's thinking.
* [Citations]({% link _core_features/citations.md %}): answers that cite your documents and web sources.
* [Prompt Rendering]({% link _core_features/prompt-rendering.md %}): ERB templates in `app/prompts`.
* [Prompt Caching]({% link _core_features/prompt-caching.md %}): reuse long, stable prompts for less.
* [Advanced Request Control]({% link _core_features/chat-request-control.md %}): provider options, wire protocols, request hooks, and headers.
* [Cost and Usage Tracking]({% link _core_features/cost-and-usage-tracking.md %}): tokens and costs per message and per conversation.
* [Chat Event Handlers]({% link _core_features/chat-callbacks.md %}): run code as messages and tool calls happen.

## Next Steps

* [Tools]({% link _getting_started/tools.md %}): let the model look up orders and search your help center.
* [Agents]({% link _getting_started/agents.md %}): put a chat's setup in a reusable class.
* [Error Handling]({% link _advanced/error-handling.md %}): retry requests and fall back to another model.
