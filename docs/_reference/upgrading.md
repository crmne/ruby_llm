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

2.1 does not require changes to your code.

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
