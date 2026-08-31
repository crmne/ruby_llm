# AGENTS.md

Guidance for coding agents working on RubyLLM. Humans welcome too; start with [CONTRIBUTING.md](CONTRIBUTING.md) for the contribution policy, then come back here for the mechanics.

## What this is

RubyLLM is a Ruby AI framework: chat, tools, agents, structured output, embeddings, images, video, audio, and Rails integration behind one API, with seventeen providers in the box. Plain Ruby (>= 3.1.3), a handful of small dependencies, no heavyweight abstractions.

## Ground rules

- New features need an approved GitHub issue before any code. PRs without one get closed without review.
- Never edit generated files: `lib/ruby_llm/models.json`, `lib/ruby_llm/aliases.json`, `docs/_reference/available-models.md`. `rake models` regenerates them.
- Never invent model ids. Every model name in code, specs, and docs must be a real, callable model.
- Keep diffs small and focused. No drive-by refactors, no style sweeps outside the lines you touch.
- Plain commit messages that describe the change. No "Generated with" footers, no Co-Authored-By tags.

## Setup

```bash
bundle install
overcommit --install   # required: installs the git hooks that gate every commit
```

## Commands

| Command | What it does |
|---|---|
| `bundle exec rspec --tag ~live` | Fast unit run. No API keys, no cassettes needed. |
| `bundle exec rspec spec/ruby_llm/chat_spec.rb:42` | One example. |
| `bundle exec rake test` | Full suite through rspec-queue, like CI. |
| `overcommit --run` | Everything the pre-commit hook runs: RuboCop, Flay, archspec, RSpec. |
| `bundle exec rubocop` | Lint (auto-corrects on commit). |
| `bundle exec archspec check` | Architecture rules from `Archspec.rb`. |
| `bundle exec appraisal rails-8.0 rspec` | Rails version matrix (7.1 through 8.1, see `Appraisals`). |
| `docs/bin/serve.sh` | Docs preview at localhost:4002. |

## Testing

- Specs tagged `:live` talk to provider APIs through VCR cassettes in `spec/fixtures/vcr_cassettes`. Everything else is a plain unit test.
- Cassette names derive from the example's full description. A failing `:live` example deletes its cassette on purpose, so the next run hits the real API instead of replaying a recording that may be hiding the bug.
- Re-record cassettes with `rake vcr:record[openai,anthropic]` or `rake vcr:record[all]` (needs real API keys in `.env`).
- Check cassettes for leaked keys before committing. `bin/gitleaks-staged` runs in the pre-commit hook and CI runs gitleaks again.
- Rails specs run against the dummy app in `spec/dummy`. Generator specs are tagged `:generator` and excluded from the pre-commit run because they are slow.
- `spec/support/models_to_test.rb` defines the provider and model matrix the live specs iterate over.

## Architecture (enforced)

`Archspec.rb` at the repo root is the architecture documentation, and `archspec check` fails the build when code violates it. Read it before moving anything across layers. The short version:

- Domain objects (`Chat`, `Message`, `Tool`, `Agent`, ...) never reference `RubyLLM::Providers` or `RubyLLM::Protocols`. They delegate through the `Provider` contract.
- Protocols (`lib/ruby_llm/protocols`) are wire formats: Chat Completions, Responses, Anthropic, Gemini, Converse, Cohere, Files, and provider-specific storage APIs. Serialization methods are `render_*`, parsing methods are `parse_*`. Register every operation through `protocol`; do not add operation-specific protocol registries or macros.
- Providers (`lib/ruby_llm/providers`) are adapters: auth, endpoints, catalogs, dialect quirks. A provider declares which protocols it speaks; it never defines a new wire format inline.
- Treat models.dev as the source of truth for the model metadata it publishes. Report incorrect or missing metadata upstream instead of maintaining parallel pricing, limits, release dates, knowledge cutoffs, families, or modalities in RubyLLM.
- Provider model parsers record facts returned by the provider. Provider `capabilities.rb` files may only augment feature capabilities that neither the provider listing nor models.dev can express. Base those additions on explicit upstream fields, exact model ids, or unambiguous operation markers, never broad family matchers that guess about current or future models.
- Keep registry reconciliation generic. Provider-specific model-id aliases belong with that provider's catalog code, and registry generation diagnostics belong under `tasks/`, outside the runtime library.
- Treat provider gem `models.json` files as explicitly registered, read-only fallbacks. The main registry wins conflicts, global refresh never queries or rewrites catalog-backed provider gems, and only the provider gem's own `rake models` updates its packaged catalog.
- The plain-Ruby library never touches ActiveRecord. Rails integration lives in `lib/ruby_llm/active_record` and `lib/ruby_llm/railtie.rb` only.
- Every `Chat#with_x` setter needs a matching bare `x` class macro on `Agent`. The build checks this.
- Capabilities are one query: `supports?(:vision)`, never a `supports_vision?` predicate.

## Code style

- No implementation comments. A comment earns its place only by stating a constraint the code cannot show. Public API gets RDoc; see `.rdoc_options` for what is documented.
- Follow the wire-naming idioms above, and generic Ruby ones: no `get_`/`set_` accessor prefixes, no `is_` predicates.
- Reserve public bang methods for a meaningfully different non-bang pair, such as `create`/`create!`. Mutation, persistence, blocking, or network activity alone does not earn a bang.
- Flay rejects structural duplication above mass 70. If two providers or protocols share shape, extract, do not copy.

## Docs

- The Jekyll site lives in `docs/` with four collections: `_getting_started`, `_core_features`, `_advanced`, `_reference`.
- Voice is Rails-guides style: second person, present tense, code first, motivate before mechanics. No em dashes. No hype, no "simply".
- Front-matter `title` and `description` feed llms.txt and the social-card images. Keep descriptions to one compelling sentence and never use `&`, `<`, or `>` in them.
