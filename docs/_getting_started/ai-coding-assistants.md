---
layout: default
title: AI Coding Assistants
nav_order: 5
description: Install the RubyLLM skill to help your coding assistant use the API and documentation that match your application.
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* How to install the skill packaged with your RubyLLM version.
* How to use it when building features in your application.
* When to update it alongside the gem.

The RubyLLM gem includes an [Agent Skill](https://agentskills.io/) for building Ruby and Rails applications. It helps coding assistants select the correct API, find relevant documentation, and follow RubyLLM's persistence and upgrade conventions.

## Install the Skill

From your application directory, install the skill packaged with your RubyLLM version with the [`skill`](https://github.com/crmne/skill) installer:

```bash
gem exec skill add "$(bundle show ruby_llm)" --skill rubyllm --agent claude-code
```

`--agent` names your coding assistant: `claude-code`, `codex`, `cursor`, `gemini-cli`, `github-copilot`, or several separated by commas. `gem exec skill agents` lists them all. Name it rather than letting `skill` detect it, so the skill goes only to your coding assistant: in a RubyLLM application `skill` also installs into `app/skills`, where your own chats would load it. Installing from the gem keeps the skill aligned with the version in your bundle. `gem exec` needs RubyGems 3.5 or newer; with an older RubyGems, run `gem install skill` once and use `skill add`.

You can also install the skill from the repository:

```bash
gem exec skill add crmne/ruby_llm@rubyllm --agent claude-code
```

The repository version follows RubyLLM development. For an application pinned to a released version, prefer the skill packaged with that gem, or name the tag of your version, like `crmne/ruby_llm#v2.1.1@rubyllm`. `skill` records the source and commit in `skills.lock`. To install without the installer, copy the gem's `skills/rubyllm` directory into the skill directory supported by your coding assistant.

## Use the Skill

Ask your assistant to build or change a RubyLLM feature. For example:

> Use the RubyLLM skill to add a support agent to this Rails application. Persist conversations and use our existing background jobs to stream responses.

The skill asks the assistant to check your installed version and consult the relevant guides or public API documentation. It covers application development. Framework contributions use the repository's separate contributing instructions.

## Keep It Current

After updating RubyLLM, install the skill from your new version, with `--force`:

```bash
gem exec skill add "$(bundle show ruby_llm)" --skill rubyllm --agent claude-code --force
```

The gem's folder changes with its version, and `skill` replaces a skill installed from another folder, or one you edited since, only with `--force`. Keep your own conventions in your project's instructions rather than in the skill, so nothing is lost. If you installed from the repository's `main`, `gem exec skill update` shows what changed and asks before applying it. Review skill updates alongside dependency updates.

The skill is maintained with the source and guides. It contains API conventions and links to versioned documentation, rather than a generated copy of every guide. It does not run an automatic updater or change your application when RubyLLM publishes a new version.
