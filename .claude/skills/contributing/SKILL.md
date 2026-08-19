---
name: contributing
description: Contribute to RubyLLM - set up the repo, run and record specs, add providers or chat options, work on the Rails integration, and edit docs. Use when fixing a bug, building a feature, writing specs, or changing documentation in the RubyLLM codebase.
---

# Contributing to RubyLLM

Read AGENTS.md at the repo root first: it has the ground rules, the command table, and the architecture constraints that `archspec check` enforces. This skill adds the step-by-step recipes.

## The fast loop

```bash
bundle exec rspec --tag ~live          # unit tests only, no keys, seconds not minutes
bundle exec rspec spec/ruby_llm/chat_spec.rb:42   # one example
overcommit --run                       # what the commit hook will run
```

Run the fast loop while developing. Run `overcommit --run` before declaring anything done: it runs RuboCop (auto-correct), Flay (duplication), archspec (architecture), and the unit suite, and the commit fails if any of them do.

## Working with cassettes

Specs tagged `:live` replay recorded provider traffic from `spec/fixtures/vcr_cassettes`. The cassette name derives from the example's full description, so renaming an example orphans its cassette.

To re-record after changing request shapes:

```bash
rake vcr:record[openai]            # deletes that provider's cassettes, reruns the suite
rake vcr:record[openai,anthropic]  # several providers
rake vcr:record[all]               # everything (long, needs many keys)
```

Recording needs real API keys in `.env`. To re-record a single spec, delete its cassette file and run the spec with the provider's key set.

Rules that bite:

- A failing `:live` example deletes its own cassette on purpose. Do not "fix" a red spec by restoring the cassette; fix the code, then re-record.
- Review every new or changed cassette for leaked keys and personal data before committing. The pre-commit hook runs gitleaks, but eyes first.
- A spec that can neither replay (no cassette) nor record (no key) skips with a message naming the env var it needs. That is expected on a fork without keys.

## Adding or changing a chat option

1. Add `with_x` to `lib/ruby_llm/chat.rb` (chainable, returns `self`).
2. Add the matching bare `x` class macro to `lib/ruby_llm/agent.rb`. The archspec build fails without it.
3. Thread the option through the `Provider` contract, never by referencing a concrete provider or protocol from `Chat`.
4. Implement per protocol in `lib/ruby_llm/protocols/*` (`render_*` for request payloads, `parse_*` for responses).
5. Spec it in `spec/ruby_llm/chat_<x>_spec.rb`; add live coverage over the matrix in `spec/support/models_to_test.rb` when providers differ.
6. Document it on the matching page in `docs/_core_features/`.

## Adding a provider

For smaller or emerging providers, ship a community gem instead of a core PR (the core bar is high, see CONTRIBUTING.md):

```bash
bundle exec ruby_llm provider-gem Acme --api-base https://api.acme.ai/v1
```

That scaffolds a complete gem with specs and CI. For an approved core provider:

```bash
script/generate-provider acme
```

Then make it real:

1. `lib/ruby_llm/providers/acme.rb` declares auth, API base, and which protocols it speaks (`protocol :chat_completions, ...`). If the provider has its own wire format, that format is a new protocol under `lib/ruby_llm/protocols/`, not code inside the provider.
2. Replace the scaffold's example capabilities with the provider's real ones, and identify the model-catalog source.
3. Register the provider in `lib/ruby_llm.rb` (the entrypoint is the only place concrete providers get wired in).
4. Record cassettes covering normal chat and streaming chat at minimum.
5. Document configuration in `docs/_getting_started/configuration-providers.md`.

## Rails work

- Rails specs run against the dummy app in `spec/dummy`; `acts_as_chat` and `acts_as_message` live in `lib/ruby_llm/active_record/`.
- The Rails integration builds on the domain layer and the `Provider` contract only. It converts records with `to_llm`/`from_llm`; plain-Ruby objects never define those.
- Generators live in `lib/generators/ruby_llm/` (install, upgrade, chat_ui, agent, tool, schema, provider). Their specs are tagged `:generator` and excluded from the pre-commit run; run them explicitly with `bundle exec rspec --tag generator`.
- Check Rails-version compatibility across the matrix: `bundle exec appraisal rails-7.1 rspec` through `rails-8.1`.

## Docs work

- Pages live in `docs/` under `_getting_started`, `_core_features`, `_advanced`, and `_reference`. Preview with `docs/bin/serve.sh`.
- Voice: Rails guides. Second person, present tense, show the code before explaining it, motivate each feature with the problem it solves in one sentence. No em dashes, no hype, no "simply".
- Front-matter `description` becomes the page's llms.txt entry and social card text: one compelling sentence, no `&`, `<`, or `>`.
- Cross-link with `{% link _collection/page.md %}`, never hard-coded URLs.
- `docs/_reference/available-models.md` is generated; never edit it.

## Before opening the PR

1. `overcommit --run` passes.
2. New behavior has specs; changed provider behavior has re-recorded cassettes, reviewed for secrets.
3. Public API changes are documented in `docs/` and have RDoc.
4. The PR does one thing, references its approved issue, and explains the problem before the solution.
