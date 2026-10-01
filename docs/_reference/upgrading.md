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

2.1 does not require changes to your code, except to move Perplexity chat off Sonar.

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

## Upgrade the Rails Schema

Rails applications generate and run the 2.1 upgrade:

```bash
bin/rails generate ruby_llm:upgrade
bin/rails db:migrate
```

It adds the `ruby_llm_mcp_credentials` table, where the [MCP client]({% link _core_features/mcp.md %}#authorization) keeps OAuth credentials encrypted, and a `pending_input` column to `ruby_llm_tool_calls`, where a paused MCP tool call keeps its input requests. Both are new; the migration changes no existing data. Credentials use Active Record encryption, so run `bin/rails db:encryption:init` first if your app has no encryption keys.

Run your tests and deploy.

## The Community MCP Gem

2.1 includes an MCP client, `RubyLLM::MCP`. The community ruby_llm-mcp gem defines the same constant, so remove it before updating and move your servers to [MCP classes]({% link _core_features/mcp.md %}).

## Older Upgrade Guides

Use the [2.0 upgrade guide](https://github.com/crmne/ruby_llm/blob/v2.0.0/docs/_reference/upgrading.md), or the [1.16 upgrade guide](https://rubyllm.com/v1/upgrading/) for older releases. See [GitHub releases](https://github.com/crmne/ruby_llm/releases) for the full changelog.
