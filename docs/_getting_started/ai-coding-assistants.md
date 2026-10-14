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

From your application directory, install the skill packaged with your RubyLLM version:

```bash
npx skills add "$(bundle show ruby_llm)" --skill rubyllm
```

The [skills installer](https://github.com/vercel-labs/skills) prompts you to choose your coding assistant and installation scope. Installing from the gem keeps the skill aligned with the version in your bundle.

You can also install the skill from the repository:

```bash
npx skills add crmne/ruby_llm --skill rubyllm
```

The repository version follows RubyLLM development. For an application pinned to a released version, prefer the skill packaged with that gem. To install without the CLI, copy the gem's `skills/rubyllm` directory into the skill directory supported by your coding assistant.

## Use the Skill

Ask your assistant to build or change a RubyLLM feature. For example:

> Use the RubyLLM skill to add a support agent to this Rails application. Persist conversations and use our existing background jobs to stream responses.

The skill asks the assistant to check your installed version and consult the relevant guides or public API documentation. It covers application development. Framework contributions use the repository's separate contributing instructions.

## Keep It Current

After updating RubyLLM, repeat the installation command from your application directory. Review skill updates alongside dependency updates.

The skill is maintained with the source and guides. It contains API conventions and links to versioned documentation, rather than a generated copy of every guide. It does not run an automatic updater or change your application when RubyLLM publishes a new version.
