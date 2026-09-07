---
layout: default
title: Tokenization
nav_order: 12
description: Inspect token IDs and count a conversation's input tokens before generating a response.
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* How to tokenize text with `RubyLLM.tokenize`.
* How to read token IDs and their count.
* How to count a chat request before sending it.
* How tokenization differs from billed usage.

## Tokenizing Text

See how a model splits text into tokens:

```ruby
result = RubyLLM.tokenize(
  "Ruby makes AI useful.",
  model: "{{ site.models.xai_tokenization }}"
)

result.ids   # integer token IDs, in text order
result.count # number of tokens
```

The result is a `RubyLLM::Tokenization`. `result.model` identifies the tokenizer's model, and `result.raw` contains any additional provider fields.

Token IDs depend on the model. Use the same model when comparing tokenized inputs. Tokenization covers the supplied string; it excludes chat formatting, instructions, tools, and attachments.

For GPUStack, enable the [model proxy]({% link _getting_started/configuration-providers.md %}#gpustack-deployments) and select the deployed model with `provider: :gpustack`.

## Counting a Chat Request

Use `RubyLLM.count_tokens` to count a prompt as chat input:

```ruby
count = RubyLLM.count_tokens(
  "Explain Ruby blocks.",
  model: "{{ site.models.anthropic_current }}"
)
```

For a configured conversation, call `chat.count_tokens`:

```ruby
chat = RubyLLM.chat(model: "{{ site.models.anthropic_latest }}")
             .with_instructions("Review the contract for renewal terms.")

count = chat.count_tokens("What should I check in a renewal clause?")
```

This includes the history, instructions, function tools, schema, thinking settings, and attachments supported by the counting endpoint. The proposed question is counted without being added to the conversation.

Call it without arguments to count the existing conversation. To include a new attachment, stage its question with `ask_later` first:

```ruby
chat.ask_later "Summarize the contract.", with: "contract.pdf"
chat.count_tokens
```

Server tools, `provider_options`, compaction, and changes from `before_request` hooks are not forwarded to counting endpoints. Counts for chats using those settings can differ from the request you eventually send.

Tokenization and chat token counting use different provider endpoints. Check [Provider API Coverage]({% link _reference/provider-coverage.md %}) for availability. Unsupported operations raise `RubyLLM::Error`.

## Token Counts and Usage

These calls help you inspect inputs before generation. They do not predict output length or establish a request's billed usage. After generation, read the actual reported counts and costs:

```ruby
response = chat.complete
response.tokens.input
response.tokens.output
response.cost.total
```

See [Tokens and Costs]({% link _core_features/cost-and-usage-tracking.md %}) for cache buckets, thinking tokens, and accounting across retries.
