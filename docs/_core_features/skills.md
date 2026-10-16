---
layout: default
title: Skills
parent: "Tools"
nav_order: 8
description: Teach the model your workflows with folders of instructions, scripts, and files in the open Agent Skills format, loaded only when a task needs them.
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* What a skill is, and how the model finds and loads one.
* How to give skills to a chat or an agent.
* How a skill's scripts run with code execution.
* How engines ship skills of their own.
* How to add the skills of a plugin marketplace.
* What makes a `SKILL.md` invalid, and when RubyLLM tells you.

## What Is a Skill?

Some tasks need more than a sentence of instructions: how your company formats an invoice, which steps build a quarterly report, the script that turns a spreadsheet into slides. Putting all of that in the instructions of every chat fills the model's context with procedures it rarely needs.

A skill is a folder that holds those procedures. It follows the open [Agent Skills format](https://agentskills.io/specification), so the skills you write work in other tools that read the format, and skills written elsewhere work in RubyLLM:

```
app/skills/
└── invoices/
    ├── SKILL.md
    ├── references/
    │   └── TAX_RULES.md
    └── scripts/
        └── build_invoice.py
```

`SKILL.md` starts with front matter that names the skill and says when to use it, followed by the instructions:

```markdown
---
name: invoices
description: Creates invoices as PDFs from order data. Use when someone asks for an invoice or a bill.
---

# Invoices

1. Read references/TAX_RULES.md to find the tax rate for the customer's country.
2. Run `python skills/invoices/scripts/build_invoice.py` with the order as JSON.
3. Return the PDF it writes.
```

The model loads a skill in steps, and only as far as a task needs:

1. Every request lists each skill's name and description.
2. When a task matches a skill, the model loads its instructions with the `load_skill` tool.
3. When the instructions mention a file, the model loads it with the same tool, one file at a time.

A chat with twenty skills costs twenty descriptions until the model needs one of them.

## Giving Skills to a Chat

Put skills in `app/skills` and turn them on:

```ruby
chat = RubyLLM.chat.with_skills
chat.ask "Bill order 1042 to ACME"
```

Called bare, `with_skills` gives the chat every folder directly under `app/skills` that holds a `SKILL.md`. Name skills to give only those:

```ruby
chat.with_skills(:invoices, :reports)
```

A Symbol names a folder under `app/skills`. Skill names use hyphens, and a Symbol's underscores stand for them, so `:pdf_processing` finds `app/skills/pdf-processing`. Pass a String or a Pathname for a skill that lives anywhere else, and mix both:

```ruby
chat.with_skills(:invoices, "vendor/skills/pdf")
```

`with_skills` adds to the skills a chat already has. Read them with `skills`, and remove them all with `false`:

```ruby
chat.skills.map(&:name) # => ["invoices", "pdf"]
chat.with_skills(false)
chat.skills             # => []
```

Passing `nil` raises `ArgumentError`, like every other feature switch.

### What the Model Sees

The list of skills is part of each request, the way instructions are, and never becomes a message in the conversation. Change the skills between turns and the next request lists the new ones.

The model gets one tool, `load_skill`. Called with a skill's name, it returns the instructions in `SKILL.md`, without the front matter. Called with a file as well, it returns that file:

```ruby
chat.ask "Bill order 1042 to ACME"

chat.messages.select(&:tool_call?).flat_map { |message| message.tool_calls.values.map(&:arguments) }
# => [{"skill"=>"invoices"}, {"skill"=>"invoices", "file"=>"references/TAX_RULES.md"}]
```

What the model loads stays in the conversation as tool results, so it does not need to load a skill again on the next turn.

`load_skill` reads only inside the skill's folder. It refuses absolute paths, paths with `..`, and symbolic links that point outside the folder, and returns text files only, up to 256 KB each. Larger files and other formats, such as images and templates, are for the skill's scripts to use.

## Running Scripts

Many skills ship scripts that do the real work, such as building a document or converting a file. Scripts run through [code execution]({% link _core_features/code-execution.md %}), in the same sandbox as the code the model writes:

```ruby
chat = RubyLLM.chat
              .with_skills(:invoices)
              .with_code_execution(python: %w[reportlab])
chat.ask "Bill order 1042 to ACME", with: "order-1042.json"

chat.messages.find { |message| message.attachments.any? }.attachments.first.filename
# => "invoice-1042.pdf"
```

Every skill the chat has is mounted read-only in each run, at `skills/<name>/` in the working directory, so `python skills/invoices/scripts/build_invoice.py` works as written. The run sees the rest of its working directory as usual: the conversation's files in `attachments/`, temporary files in `$TMPDIR`, and every file the script writes to the working directory comes back as an attachment. A script cannot change its skill's folder.

Install what the scripts import the way you would for any code the model runs: with `gems:`, `python:`, and `npm:`, or a prebuilt `gem_home:`, `virtualenv:`, and `node_modules:`. See [Packages]({% link _core_features/code-execution.md %}#packages).

Without code execution, the model still reads the instructions and the files they mention, and is told that the scripts cannot run, so it can say so instead of pretending.

## Skills in Agents

Agents name their skills with the `skills` macro:

```ruby
class BillingAgent < RubyLLM::Agent
  instructions "You handle billing questions for ACME."
  skills :invoices, :refunds
  code_execution python: %w[reportlab]
end
```

`skills true` gives the agent every skill under `app/skills`, and `skills false` removes the skills a parent agent declared. An agent without a `skills` declaration has no skills, even when `app/skills` has a folder named after it. Called bare, `skills` returns the declaration.

Persisted chats take the same calls, and `BillingAgent.find(id)` applies the agent's skills again:

```ruby
chat = Chat.create!(model: "{{ site.models.default_chat }}").with_skills(:invoices)
```

## Skills From Engines

RubyLLM looks for skills in `app/skills` under `Rails.root`, or under the current directory outside Rails. An engine adds its own folder in an initializer:

```ruby
initializer "billing_engine.skills" do
  RubyLLM::Skill.roots << BillingEngine::Engine.root.join("app/skills")
end
```

The application's folder comes first, so a skill in `app/skills` replaces an engine's skill with the same name.

## Skills From Marketplaces

Skills written for coding assistants are published in plugin marketplaces: a repository that lists plugins, each holding skill folders. Copying those folders by hand, one skill at a time, leaves you with no record of where a skill came from or how to refresh it. Add the whole marketplace instead:

```bash
bin/rails "ruby_llm:marketplaces:add[anthropics/skills]"
```

Or from Ruby:

```ruby
marketplace = RubyLLM::Skill::Marketplace.add("anthropics/skills")
marketplace.name               # => "anthropic-agent-skills"
marketplace.plugins            # => ["claude-api", "document-skills", "example-skills", ...]
marketplace.skills.map(&:name) # => ["claude-api", "docx", "pdf", "pptx", "xlsx", ...]
```

RubyLLM reads the marketplace file that Claude Code, Codex, or Cursor would read, and copies each plugin's skill folders into `vendor/skills`, under the marketplace's and the plugin's names:

```
vendor/skills/
└── anthropic-agent-skills/
    ├── marketplace.json
    └── document-skills/
        ├── docx/
        │   └── SKILL.md
        └── pdf/
            └── SKILL.md
```

RubyLLM looks for skills in these folders after `app/skills` and the folders engines add, so the calls you know find them:

```ruby
chat.with_skills(:pdf, :docx)
```

A skill in `app/skills` replaces a marketplace skill with the same name. Called bare, `with_skills` includes every marketplace skill, so name the ones a chat needs once you have added a large marketplace.

The source is a GitHub repository, or the path of a directory that holds a marketplace. Add `@` and a branch, a tag, or a commit to pin a repository, and pass `only:` to add some of its plugins:

```ruby
RubyLLM::Skill::Marketplace.add("acme/skills@v1.2.0", only: "billing")
RubyLLM::Skill::Marketplace.add("../our-skills")
```

```bash
bin/rails "ruby_llm:marketplaces:add[acme/skills@v1.2.0,billing]"
```

For a private repository, or one on another host, clone it and add the directory.

### What Gets Copied

RubyLLM copies skills and nothing else. A plugin's skills are the folders its marketplace entry lists under `skills`, or the folders under its `skills` folder when the entry lists none. Hooks, commands, agents, and MCP servers stay behind, and so do symbolic links. A skill that reads files outside its own folder, through `${CLAUDE_PLUGIN_ROOT}` or `../`, will not find them.

Without `only:`, a plugin with no skills, or with a source that is neither the marketplace itself nor a GitHub repository, is left out. Named in `only:`, it raises.

Every copied skill is checked the way `with_skills` checks it. An [invalid skill](#invalid-skills) raises `RubyLLM::InvalidSkillError` and nothing changes on disk: the skills of an earlier add stay in place.

### Updating and Removing

`marketplace.json` records the source and the commit the skills were copied at:

```ruby
marketplace = RubyLLM::Skill::Marketplace.find("anthropic-agent-skills")
marketplace.source # => "anthropics/skills"
marketplace.commit # => "3bf9a60e6aef..."

marketplace.update # fetches the source again, for the plugins it has
marketplace.remove # deletes vendor/skills/anthropic-agent-skills
```

```bash
bin/rails ruby_llm:marketplaces
bin/rails ruby_llm:marketplaces:update
bin/rails "ruby_llm:marketplaces:remove[anthropic-agent-skills]"
```

`update` keeps the plugins you chose. To pick up plugins a marketplace gained, or to pin another tag, add it again.

RubyLLM ships no skills, and downloads them only when you add or update a marketplace, never when a chat runs. A skill's instructions steer the model and its scripts run with what your sandbox grants, so review a skill written elsewhere like any other code you add to your project. Marketplace skills are files in your repository: read the diff, then commit it.

## Writing a Skill

In Rails, `bin/rails generate ruby_llm:skill invoices "Bills an order to a customer as a PDF."` creates `app/skills/invoices/SKILL.md` with a valid name and description. Add the instructions below the front matter.

The [specification](https://agentskills.io/specification) defines the front matter:

| Field | Required | Rules |
| --- | --- | --- |
| `name` | Yes | Up to 64 lowercase letters, digits, and hyphens, without a hyphen at the start, at the end, or twice in a row. It must match the folder name. |
| `description` | Yes | Up to 1,024 characters saying what the skill does and when to use it. |
| `license` | No | A license name, or the name of a license file in the folder. |
| `compatibility` | No | Up to 500 characters on what the skill needs, such as Python 3 or network access. |
| `metadata` | No | A mapping of your own keys to string values. |
| `allowed-tools` | No | Tools the skill may use without asking. RubyLLM reads it but does not act on it. |

The description decides whether the model ever loads the skill, so say both what it does and the requests that should trigger it. Keep `SKILL.md` short, and move long references into files the instructions point to: the model loads them only when it needs them.

Read a skill as Ruby with `RubyLLM::Skill`:

```ruby
skill = RubyLLM::Skill.find(:invoices)
skill.name         # => "invoices"
skill.description  # => "Creates invoices as PDFs from order data. ..."
skill.path         # => #<Pathname:/app/app/skills/invoices>
skill.instructions # => "\n# Invoices\n\n1. Read references/TAX_RULES.md ..."
```

### Invalid Skills

RubyLLM checks every skill when you give it to a chat, so a broken skill fails when the chat is configured, not halfway through a conversation:

* A missing skill raises `RubyLLM::SkillNotFoundError`.
* A `SKILL.md` without front matter, or with a missing or malformed `name` or `description`, a name that differs from its folder, or a field over its length limit, raises `RubyLLM::InvalidSkillError` naming the file and the problem.
* Two skills with the same name in one chat raise `ArgumentError`.

`with_skills` with no arguments raises for any invalid skill under `app/skills`, so one broken folder is never silently skipped. Front matter keys the specification does not define are ignored, so skills written for other tools load unchanged.

## Next Steps

* [Code Execution]({% link _core_features/code-execution.md %}) - Configure the sandbox that runs skill scripts.
* [Sandboxes]({% link _core_features/sandboxes.md %}) - Decide what skill scripts can read, write, and reach.
* [Agents]({% link _advanced/agents.md %}) - Package skills with instructions and tools.
