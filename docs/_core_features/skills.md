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
* Which folders RubyLLM reads skills from, and how to fill them.
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

## Where Skills Live

RubyLLM reads skills from the folders in `RubyLLM::Skill.roots`, in order:

1. `app/skills` under `Rails.root`, or under the current directory outside Rails. It is always first.
2. Every folder you append to `RubyLLM::Skill.roots`, in the order you append them.

A skill is a folder directly under one of these roots, holding a `SKILL.md`. RubyLLM does not look deeper. When two roots have a skill with the same name, the earlier root wins, so a skill in `app/skills` replaces any other with that name. `with_skills` with no arguments gives the chat the skills of every root.

Add a root in an initializer:

```ruby
# config/initializers/ruby_llm.rb
RubyLLM::Skill.roots << Rails.root.join("vendor/skills")
```

An engine adds its own folder the same way, before RubyLLM's `ruby_llm.skills` initializer:

```ruby
initializer "billing_engine.skills", before: "ruby_llm.skills" do
  RubyLLM::Skill.roots << BillingEngine::Engine.root.join("app/skills")
end
```

Rails does not autoload skills. RubyLLM keeps `app/skills` and every root registered before its `ruby_llm.skills` initializer out of the autoloader, so a skill's Ruby scripts are never loaded at boot and a hyphenated folder is never read as a namespace. Keep the roots you add in `config/initializers` outside `app/`.

### Adding Skills Written Elsewhere

RubyLLM ships no skills and never downloads them. Put a skill's folder in a root and it is ready to use: copy it into `app/skills`, or keep a repository of skills as a Git submodule and add the folder that holds its skills to `Skill.roots`.

The [`skill`](https://github.com/crmne/skill) gem does the copying for you. Run it from your application with `gem exec` (RubyGems 3.5 or newer), without adding it to your bundle:

```sh
gem exec skill find pdf                                    # search skills.sh
gem exec skill add anthropics/skills --list                # what a repository holds
gem exec skill add anthropics/skills@pdf --agent rubyllm   # install one into app/skills
```

It reads GitHub repositories (`owner/repo`, `owner/repo@skill`, `owner/repo#tag`), plugin marketplaces, and local folders, and checks every `SKILL.md` with the same rules as `RubyLLM::Skill`. It records each skill's source and commit in `skills.lock` at the root of your application, so commit that file with the skills. `gem exec skill update` shows the commits and files that changed and applies them only after you say yes, and `gem exec skill list` names any skill you edited since. Without `--agent`, it installs into `app/skills` and into the folders of the coding agents your project uses, such as `.claude/skills`; `--agent rubyllm` keeps a skill for your application out of your coding agent's folders. Pass `--dir` to install into another root, such as `vendor/skills`.

A skill's instructions steer the model and its scripts run with what your sandbox grants, so review a skill written elsewhere like any other code you add to your project, and commit it so you see every change in a diff.

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
