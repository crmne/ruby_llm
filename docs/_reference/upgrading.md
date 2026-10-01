---
layout: default
title: Upgrading
nav_order: 4
description: Move a RubyLLM 2.0 application to 2.1, one release at a time.
redirect_from:
  - /upgrading-to-1-7
  - /upgrading-to-1-7/
---

# Upgrade to 2.1

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* How RubyLLM upgrades move from one release to the next.
* What to finish on 2.0 before you update the gem.
* How to upgrade a 2.0 application and its Rails schema to 2.1.
* How to move Perplexity chat from Sonar to presets.
* Which provider limits now raise the provider's error.
* Where to read the request a chat sends.

This guide covers **2.0 to 2.1**. Coming from 1.x? Follow the [2.0 upgrade guide](https://github.com/crmne/ruby_llm/blob/v2.0.0/docs/_reference/upgrading.md) with RubyLLM 2.0 first.

## One Release at a Time

Each release ships the upgrade steps for the changes since the previous release. When a release changes the Rails schema, `bin/rails generate ruby_llm:upgrade` generates the migrations that take your database from the previous release to the current one. The next release replaces that generator with its own.

To move across several releases, upgrade to each one in turn. Deploy it, run its upgrade, and resolve its deprecation warnings before you continue. Each release's upgrade guide stays in the repository at that release's tag.

## Finish the 2.0 Upgrade

2.1 does not include the 1.16 upgrade generator, its migration helpers, or the `ruby_llm:upgrade:rollback`, `resume`, and `finalize` tasks. Finish that upgrade while your application still runs 2.0:

* Run the 2.0 cleanup phase in every environment. In copy mode, finalize the upgrade first, then remove the generated `ruby_llm_upgrade.rb` concern and initializer.
* Delete the 2.0 upgrade migrations from `db/migrate` once every environment has run them. They load helpers that ship only with 2.0, and your schema file already records their result.

## Update the Gem

Require 2.1 in your `Gemfile`, so the update stops at this release:

```ruby
gem "ruby_llm", "~> 2.1.0"
```

RubyLLM 2.1 allows JSON 3. On Rails versions before 8.1.4, keep JSON 2 explicitly in your `Gemfile` before updating:

```ruby
gem "json", "< 3"
```

Then update it in your development branch:

```bash
bundle update ruby_llm
```

2.1 does not require changes to your code, except to move Perplexity chat off Sonar, to rescue provider errors where RubyLLM used to check a provider's limits, and to stop reading request bodies from raw responses.

## Move Perplexity Chat to Presets

Perplexity retires Sonar on September 27, 2026, so Perplexity chat now runs on its Agent API. Chats that name a Sonar model keep working: each runs the preset Perplexity recommends and logs a deprecation warning. Replace the model names to silence it:

| Sonar model | Preset |
| --- | --- |
| `sonar` | `fast` |
| `sonar-pro` | `low` |
| `sonar-reasoning-pro` | `medium` |
| `sonar-deep-research` | `high` |

```ruby
RubyLLM.chat(model: "fast", provider: :perplexity)
```

Expect a few differences:

* Perplexity picks the model behind each preset, so answers can read differently.
* PDF and other document attachments raise `RubyLLM::UnsupportedAttachmentError`. Images and text files still work.
* `response.cost` is the total Perplexity bills, search fees included.

Sonar's search parameters moved onto the `web_search` tool. The Agent API rejects them at the top level of a request, so a chat that still sends them raises `RubyLLM::BadRequestError` (`unknown field "search_recency_filter"`). Pass them as tool options instead:

```ruby
# Before
chat.with_provider_options(search_recency_filter: "week",
                           search_domain_filter: ["rubyonrails.org"])

# After
chat.with_provider_tools(web_search: {
  filters: { search_recency_filter: "week", search_domain_filter: ["rubyonrails.org"] }
})
```

The options you sent in `web_search_options`, such as `search_context_size` and `user_location`, become `web_search` options too.

Read sources from `response.citations`. The Agent API response has no top-level `citations` field, so code that read them from `response.raw` finds none.

To keep Sonar writing the answers, name it as a model. A model searches only with the `web_search` tool:

```ruby
RubyLLM.chat(model: "perplexity/sonar", provider: :perplexity).with_provider_tools(:web_search)
```

## Rescue Provider Errors for Provider Limits

RubyLLM no longer copies provider limits into checks of its own. A request it used to refuse now reaches the provider, and the provider's error names the limit. These calls raised `ArgumentError` or `RubyLLM::UnsupportedAttachmentError` before the request in 2.0. Now the provider decides, and a request it rejects raises `RubyLLM::BadRequestError` or another `RubyLLM::Error`:

* `RubyLLM.rerank` on Bedrock or Vertex AI with no documents, more than 1,000 documents, an empty query, or a `top_n:` outside the provider's range.
* `RubyLLM.embed` with more than one image on Cohere Embed v3.
* Cohere embedding batches with `dimensions:`.
* `RubyLLM.upload` on OpenAI or Azure without `purpose:`.
* `RubyLLM.upload` on DeepSeek with a file that is not an image, a file over 64 MiB, or a `purpose:` other than `"user_data"`.
* `RubyLLM.research` on Vertex AI with an agent other than the Deep Research preview, or with audio or video attachments.
* `RubyLLM.animate` with Luma Ray 2 on Bedrock and an empty prompt, a prompt over 5,000 characters, or keyframes other than PNG or JPEG.
* Other media formats on Bedrock: Stability source images beyond JPEG, PNG, and WebP, guardrail images beyond PNG and JPEG, and Voxtral audio beyond MP3 and WAV.
* ElevenLabs image masks on models other than GPT Image, and reference audio or video on video models other than Seedance.
* `RubyLLM.animate` without a prompt on ElevenLabs or GPUStack.
* `RubyLLM.transcribe` on Gemini with `prompt:` combined with speaker names or word timestamps.
* Streaming transcription on ElevenLabs or xAI with a WAV sample rate outside the rates RubyLLM listed, or on xAI with more than eight channels.
* Perplexity Router chats with request options such as `seed`, tools without descriptions, audio other than MP3 or WAV, or a schema with `strict: false`, and Sonar chats with documents other than PDF, DOC, DOCX, TXT, or RTF.
* Gemini Interactions chats with a thinking effort other than minimal, low, medium, or high.
* Bedrock Converse chats with a thinking effort and a `max_output_tokens:` too small for the model's smallest thinking budget.

If you rescue `ArgumentError` or `RubyLLM::UnsupportedAttachmentError` around these calls, rescue `RubyLLM::Error` instead. Bedrock and Vertex AI embedding batches also send empty strings to the provider now, instead of refusing the batch.

RubyLLM no longer drops an explicit option the provider might reject, either. `RubyLLM.paint` on xAI now sends `size:`, so xAI's error replaces an image at its default size. Leave `size:` unset for xAI.

## Read Requests Before They Are Sent

A raw response no longer keeps the request it answered: `response.raw.env.request_body` is `nil`, so a conversation does not hold a serialized copy of its history for every reply. Read the request from the chat instead:

```ruby
chat.render
chat.before_request { |payload| Rails.logger.debug(payload) }
```

## Upgrade the Rails Schema

Rails applications generate and run the 2.1 upgrade:

```bash
bin/rails generate ruby_llm:upgrade
bin/rails db:migrate
```

It adds the `ruby_llm_mcp_credentials` table, where the [MCP client]({% link _core_features/mcp.md %}#authorization) keeps OAuth credentials encrypted, a `pending_input` column to `ruby_llm_tool_calls`, where a paused MCP tool call keeps its input requests, and the `ruby_llm_provider_files` table, where RubyLLM records the [provider uploads of stored attachments]({% link _advanced/rails-persistence.md %}#attachments-and-structured-output). All three are new; the migration changes no existing data. Credentials use Active Record encryption, so run `bin/rails db:encryption:init` first if your app has no encryption keys.

Run your tests and deploy.

## The Community MCP Gem

2.1 includes an MCP client, `RubyLLM::MCP`. The community ruby_llm-mcp gem defines the same constant, so remove it before updating and move your servers to [MCP classes]({% link _core_features/mcp.md %}).

## Older Upgrade Guides

Use the [2.0 upgrade guide](https://github.com/crmne/ruby_llm/blob/v2.0.0/docs/_reference/upgrading.md), or the [1.16 upgrade guide](https://rubyllm.com/v1/upgrading/) for older releases. See [GitHub releases](https://github.com/crmne/ruby_llm/releases) for the full changelog.
