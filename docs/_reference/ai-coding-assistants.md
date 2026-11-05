---
layout: default
title: AI Coding Assistants
nav_order: 7
description: Install the RubyLLM skill to help your coding assistant use the API and documentation that match your application.
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* How to install the skill packaged with your RubyLLM version.
* How to install it as a Claude Code plugin.
* How to give your assistant RubyLLM's documentation through Context7, `llms.txt`, or GitMCP.
* How to use it when building features in your application.
* When to update it alongside the gem.

The RubyLLM gem includes an [Agent Skill](https://agentskills.io/) for building Ruby and Rails applications. It helps coding assistants select the correct API, find relevant documentation, and follow RubyLLM's persistence and upgrade conventions.

## Install the Skill

From your application directory, install the skill packaged with your RubyLLM version with the [`skill`](https://github.com/crmne/skill) installer:

```bash
gem exec skill add "$(bundle show ruby_llm)" --skill rubyllm --agents coding
```

`--agents coding` installs the skill for every coding assistant your project shows signs of, such as Claude Code (`.claude`), Codex (`AGENTS.md`), or Cursor (`.cursor`), and never into `app/skills`, where your own chats would load it. Without it, `skill` installs into `app/skills` too. To name assistants instead, pass them separated by commas, like `--agents claude-code,cursor`; `gem exec skill agents` lists them all. `--agents` needs `skill` 0.2 or newer, which `gem exec` fetches. Installing from the gem keeps the skill aligned with the version in your bundle. `gem exec` needs RubyGems 3.5 or newer; with an older RubyGems, run `gem install skill` once and use `skill add`.

You can also install the skill from the repository:

```bash
gem exec skill add crmne/ruby_llm@rubyllm --agents coding
```

The repository version follows RubyLLM development. For an application pinned to a released version, prefer the skill packaged with that gem, or name the tag of your version, like `crmne/ruby_llm#v2.1.1@rubyllm`. `skill` records the source and commit in `skills.lock`. To install without the installer, copy the gem's `skills/rubyllm` directory into the skill directory supported by your coding assistant.

## Install the Claude Code Plugin

The repository is also a Claude Code plugin marketplace. Add it and install the plugin from a Claude Code session:

```
/plugin marketplace add crmne/ruby_llm
/plugin install rubyllm@ruby_llm
```

The plugin contains the same skill and follows the repository's `main` branch. Run `/plugin marketplace update ruby_llm` to pick up changes. For an application pinned to a released version, prefer the skill packaged with your gem.

## Give Your Assistant the Docs

The skill tells your assistant which guide to read. These tools let it fetch the guides itself.

### Context7

[Context7](https://context7.com/crmne/ruby_llm) indexes RubyLLM's guides and serves them through its MCP server, along with rules such as checking the installed version and using `instructions` instead of `system_prompt`. Add the server to Claude Code:

```bash
claude mcp add --transport http context7 https://mcp.context7.com/mcp
```

Then mention RubyLLM in your request, or ask your assistant to use Context7.

### llms.txt

[`llms.txt`](https://rubyllm.com/llms.txt) starts with a quick reference, then lists every guide with a link to its Markdown version. It also links the full documentation split by area, so a model can read only the part it needs. Every guide has a Markdown version at the same address with `.md` in place of the trailing slash, such as [`chat.md`](https://rubyllm.com/chat.md).

[mcpdoc](https://github.com/langchain-ai/mcpdoc) turns any `llms.txt` into an MCP server:

```bash
claude mcp add-json rubyllm-docs '{"type":"stdio","command":"uvx","args":["--from","mcpdoc","mcpdoc","--urls","RubyLLM:https://rubyllm.com/llms.txt"]}'
```

Use `https://rubyllm.com/next/llms.txt` for `main`, or `https://rubyllm.com/v1/llms.txt` for 1.x.

### GitMCP

[GitMCP](https://gitmcp.io/crmne/ruby_llm) serves the repository's documentation and code from `main` as a remote MCP server:

```bash
claude mcp add --transport http rubyllm-gitmcp https://gitmcp.io/crmne/ruby_llm
```

Because it reads `main`, it can describe features that are not released yet. Check them against your installed version.

## Use the Skill

Ask your assistant to build or change a RubyLLM feature. For example:

> Use the RubyLLM skill to add a support agent to this Rails application. Persist conversations and use our existing background jobs to stream responses.

The skill asks the assistant to check your installed version and consult the relevant guides or public API documentation. It covers application development. Framework contributions use the repository's separate contributing instructions.

## Keep It Current

After updating RubyLLM, install the skill from your new version, with `--force`:

```bash
gem exec skill add "$(bundle show ruby_llm)" --skill rubyllm --agents coding --force
```

The gem's folder changes with its version, and `skill` replaces a skill installed from another folder, or one you edited since, only with `--force`. Keep your own conventions in your project's instructions rather than in the skill, so nothing is lost. If you installed from the repository's `main`, `gem exec skill update` shows what changed and asks before applying it. Review skill updates alongside dependency updates.

The skill is maintained with the source and guides. It contains API conventions and links to versioned documentation, rather than a generated copy of every guide. It does not run an automatic updater or change your application when RubyLLM publishes a new version.
