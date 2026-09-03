# AGENTS.md

How RubyLLM is built. For coding agents first, humans welcome. Read [CONTRIBUTING.md](CONTRIBUTING.md) for what gets accepted; this file is how to write it.

## What this is

RubyLLM is a Ruby AI framework: chat, tools, agents, structured output, embeddings, images, video, audio, and Rails integration behind one API, with seventeen providers in the box. Plain Ruby (>= 3.1.3), a handful of small dependencies, no heavyweight abstractions.

## What we are optimizing for

The pitch is the public API. Every change is judged against four things, in this order:

1. **Ruby-native.** The API reads like Ruby that a Rails developer already knows: chainable setters, one name per concept, keyword arguments, value objects with readers, predicates that end in `?`, and nothing that looks like a port of a Python SDK. If DHH would raise an eyebrow at a method name, rename it.
2. **Seamless in Rails.** `acts_as_chat` and `acts_as_message` make an application's own records behave exactly like the plain-Ruby objects. RubyLLM owns its supporting tables, the app owns chats and messages, and every plain-Ruby feature works on a persisted record without a second API.
3. **Providers and protocols in their place.** A provider is who you talk to; a protocol is how. Wire vocabulary never leaks into the domain, and the domain never names a provider. `Archspec.rb` fails the build when it does.
4. **Craftsmanship.** Small focused diffs, specs for every behavior, RDoc on every public method, docs in the Rails-guides voice, no implementation comments, no dead code. Quality is the feature.

## Ground rules

- New features need an approved GitHub issue before any code. PRs without one get closed without review.
- Never edit generated files: `lib/ruby_llm/models.json`, `lib/ruby_llm/aliases.json`, `docs/_reference/available-models.md`. `rake models` regenerates them.
- Never invent model ids. Every model name in code, specs, and docs must be a real, callable model. Check with `RubyLLM.models.find`.
- Keep diffs small and focused. No drive-by refactors, no style sweeps outside the lines you touch.
- Plain commit messages that describe the change: a subject of at most 60 characters, a body wrapped at 72 that says why. No "Generated with" footers, no Co-Authored-By tags.
- Never push and never post to GitHub on a maintainer's behalf. Commit locally and leave the rest to the maintainer.

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
| `bundle exec rspec --tag generator` | The slow Rails generator specs, excluded from the commit hook. |
| `overcommit --run` | Everything the pre-commit hook runs: RuboCop, Flay, archspec, RSpec. |
| `bundle exec rubocop` | Lint (auto-corrects on commit). |
| `bundle exec archspec check` | Architecture rules from `Archspec.rb`. |
| `bundle exec appraisal rails-8.0 rspec` | Rails version matrix (7.1 through 8.1, see `Appraisals`). |
| `docs/bin/serve.sh` | Docs preview at localhost:4002. |

## Public API rules

- **Chain setters, read state.** Every `Chat#with_x` returns `self`, accepts `nil` to reset, and has a bare `x` reader (instructions are the one exception: they live in the transcript, so read `chat.messages`). Every `with_x` also has a bare `x` class macro on `Agent` and appears in the delegate lists in `Agent` and `ActiveRecord::ChatMethods`; the delegation specs fail when the three drift.
- **Feature switches share one shape.** `with_thinking`, `with_citations`, `with_caching`, and `with_compaction` take nothing or `true` to enable, `false` to disable, and options as keywords or a Hash. They reject `nil`.
- **One name per concept, everywhere.** `max_output_tokens` not `max_tokens`, `thinking` not `reasoning`, `cache_read` and `cache_write`, `provider_options` for the provider's own vocabulary, `provider:` as a keyword. The registry's capability names come from models.dev and stay as they are (`supports?(:reasoning)`).
- **Capabilities are one query**, `supports?(:vision)`, never a `supports_vision?` predicate.
- **RubyLLM's own enumerations are Symbols.** `finish_reason` is `:stop`, a usage entry's status is `:succeeded`, thinking effort is `:medium`, `Model#type` is `:chat`. Values that come from a provider or from models.dev (slugs, model ids, MIME types, reasoning option values) stay Strings, and protocols turn Symbols into Strings only at the wire.
- **Bang methods are for a meaningfully different pair**, like `create`/`create!`. Mutation, persistence, blocking, or network activity alone does not earn a bang. `cancel`, `approve`, `refresh` are plain.
- **Value objects, not hashes.** Results are typed (`Message`, `Tokens`, `Cost`, `Citation`, `Moderation::Result`) with readers named after the concept. `to_h` is for serialization, `inspect` is one short line through `Inspectable`.
- **Errors take the message first** and the response as a keyword: `Error.new("msg", response: response)`.
- **Public means documented.** RDoc on the method, an example in `docs/`, and `:nodoc:` on everything that is internal.

## Boundaries (enforced by Archspec.rb)

`Archspec.rb` at the repo root is the architecture documentation, and `archspec check` fails the build when code violates it. Read it before moving anything across layers. The short version:

- **Domain objects** (`Chat`, `Message`, `Tool`, `Agent`, ...) never reference `RubyLLM::Providers` or `RubyLLM::Protocols`, never name a provider or a wire format in a method, and never carry a table of provider values. They delegate through the `Provider` contract.
- **Protocols** (`lib/ruby_llm/protocols`) are wire formats: Chat Completions, Responses, Anthropic, Gemini, Converse, Cohere, Files, and provider-specific storage APIs. Serialization methods are `render_*`, parsing methods are `parse_*`. A protocol normalizes on the way in and out: it maps its finish reasons onto `stop`, `max_tokens`, `tool_calls`, and `content_filter` in its `finish_reasons` table, it decides its own request rules (OpenAI strict mode lives in the OpenAI protocols, not in `Chat`), and it turns its error bodies into RubyLLM errors. Register every operation through `protocol`; do not add operation-specific protocol registries or macros.
- **Providers** (`lib/ruby_llm/providers`) are adapters: auth, endpoints, catalogs, dialect quirks. A provider declares which protocols it speaks; it never defines a new wire format inline. A protocol that needs something only the provider knows asks its `@provider` for it.
- **Support** (`Configuration`, `Models`, `Model`, `Connection`, errors) is a leaf layer: it knows neither protocols nor concrete providers, nor Active Record. Provider-specific registry behavior, such as how a provider spells a models.dev id, goes through a `Provider` class hook (`models_dev_alias`, `models_dev_model_id`), not a branch on the slug.
- **Model metadata comes from models.dev.** Report incorrect or missing pricing, limits, release dates, knowledge cutoffs, families, or modalities upstream instead of maintaining parallel tables. Provider model parsers record facts the provider returns. Provider `capabilities.rb` files may only augment feature capabilities that neither the provider listing nor models.dev can express, based on explicit upstream fields, exact model ids, or unambiguous operation markers, never broad family matchers that guess about current or future models.
- **Registry reconciliation stays generic.** Provider-specific model-id aliases belong with that provider's catalog code, and registry generation diagnostics belong under `tasks/`, outside the runtime library. Provider gem `models.json` files are explicitly registered, read-only fallbacks: the main registry wins conflicts, global refresh never queries or rewrites catalog-backed provider gems, and only the provider gem's own `rake models` updates its packaged catalog.
- **The plain-Ruby library never touches Active Record.** Rails integration lives in `lib/ruby_llm/active_record` and `lib/ruby_llm/railtie.rb` only, converts with `to_llm`/`from_llm`, and delegates through the domain and the `Provider` contract.

When you find provider vocabulary in the wrong layer, move it and add the rule to `Archspec.rb` so it cannot come back.

## Rails integration rules

- A persisted chat behaves like a plain chat. Whatever `Chat` can do, `acts_as_chat` records do through the same names, and `Agent.find` gives back the record with the agent's tools, instructions, and options applied.
- RubyLLM owns `ruby_llm_models`, `ruby_llm_tool_calls`, `ruby_llm_usages`, and `ruby_llm_batches`. Applications own chats and messages. Schema changes go through the install generator for new apps and the upgrade generator for existing ones; both templates must move together.
- Persistence must survive other processes: cancellation, approvals, and the loop verbs read and write the database, and anything polled inside a job runs outside the query cache.
- Generators write what a Rails scaffold would: omakase style, conventional paths, no starter prose, no TODO comments beyond the one place the developer has to type. An empty prompt file means no instructions.
- Rails specs run against the dummy app in `spec/dummy`. Generator specs are tagged `:generator` and excluded from the pre-commit run because they are slow.

## Testing

- Specs tagged `:live` talk to provider APIs through VCR cassettes in `spec/fixtures/vcr_cassettes`. Everything else is a plain unit test. Every bug fix ships with a unit spec that fails before the fix.
- Cassette names derive from the example's full description. A failing `:live` example deletes its cassette on purpose, so the next run hits the real API instead of replaying a recording that may be hiding the bug.
- Re-record cassettes with `rake vcr:record[openai,anthropic]` or `rake vcr:record[all]` (needs real API keys in `.env`). Check cassettes for leaked keys before committing. `bin/gitleaks-staged` runs in the pre-commit hook and CI runs gitleaks again.
- Protocol chat modules use `module_function`. To unit-test a render or parse method, extend the module (plus `Tools` and `Media` when the method needs them) onto a bare Object, the way the existing protocol specs do.
- `spec/support/models_to_test.rb` defines the provider and model matrix the live specs iterate over.
- Changed a wire request? Re-record the cassette. Changed a parsed value? Update the protocol spec, not the domain spec.

## Code style

- No implementation comments. A comment earns its place only by stating a constraint the code cannot show. Public API gets RDoc; see `.rdoc_options` for what is documented.
- Follow the wire-naming idioms above, and generic Ruby ones: no `get_`/`set_` accessor prefixes, no `is_` predicates.
- Flay rejects structural duplication above mass 70. If two providers or protocols share shape, extract, do not copy.
- RuboCop runs with auto-correct on commit; do not disable cops inline unless the existing code already does at that spot for the same reason.

## Docs

- The Jekyll site lives in `docs/` with four collections: `_getting_started`, `_core_features`, `_advanced`, `_reference`. Preview with `docs/bin/serve.sh`.
- Voice is Rails-guides style: second person, present tense, code first, motivate before mechanics. No em dashes. No hype, no "simply".
- Front-matter `title` and `description` feed llms.txt and the social-card images. Keep descriptions to one compelling sentence and never use `&`, `<`, or `>` in them.
- Cross-link with `{% link _collection/page.md %}`, never hard-coded URLs. Use the `site.models.*` ids from `docs/_config.yml` in examples so model names stay current.
- A public API change is not done until its docs page changes in the same commit, and `docs/_reference/upgrading.md` records anything that breaks.
