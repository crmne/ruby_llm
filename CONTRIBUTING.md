# Contributing to RubyLLM

Working with a coding agent? [AGENTS.md](AGENTS.md) has the commands, architecture rules, and style conventions, and the repo ships a `contributing` skill in `.claude/skills/` with step-by-step recipes. Both are worth a read for humans too.

## Did you find a bug?

* **Ensure the bug was not already reported** by searching on GitHub under [Issues](https://github.com/crmne/ruby_llm/issues).

* If you're unable to find an open issue addressing the problem, [open a new one](https://github.com/crmne/ruby_llm/issues/new). Include a **title and clear description**, relevant information, and a **code sample** demonstrating the issue.

* **Verify it's a RubyLLM bug**, not your application code, before opening an issue.

## Did you write a patch that fixes a bug?

* Open a new GitHub pull request with the patch.

* Ensure the PR description clearly describes the problem and solution. Include the relevant issue number if applicable.

* Run `overcommit --install` before committing - it handles code style and tests automatically.

## Do you intend to add a new feature or change an existing one?

* **First check if this belongs in RubyLLM or your application.**
  RubyLLM already provides chat, agents, tools, embeddings, and the building blocks for workflows and RAG. Before proposing a new feature, ask: *can this be built with what RubyLLM already offers?* If so, it belongs in your application code, not in the gem.

* Features we'll reject:
  - Anything you can build in a few lines of application code using existing RubyLLM features
  - Opinionated abstractions over patterns that are already straightforward (e.g., specific RAG pipeline frameworks, workflow orchestration DSLs)
  - Integrations with specific external services (vector databases, search engines, etc.) — these work great as separate gems
  - Testing frameworks

* **Keep PRs focused and reasonably sized.** Break large features into smaller, reviewable PRs.

* **Use whatever tools you like, AI included.** We review the change, not how it was written. You're responsible for every line you submit, so make sure you understand it and can answer questions about it.

### How we write it

[AGENTS.md](AGENTS.md) has the full rules. The ones PRs most often miss:

* **Let the provider say no.** Don't add checks that raise before a request for things the provider validates itself, such as model capabilities, limits, or allowed values. Its error stays current; a copy in RubyLLM goes stale.
* **Keep provider knowledge in providers and protocols.** `Chat`, `Thinking`, and other domain objects never name a provider or a model family.
* **One name per concept.** When several providers can do the same thing, give it one RubyLLM name and translate it per protocol. `provider_options` is for what only one provider does.
* **Use real model IDs.** Check them with `RubyLLM.models.find`.
* **Prove it.** Add a spec that fails before your change, and re-record the cassettes when a request changes.
* **No implementation comments.** Name things so the code reads on its own. Public methods get RDoc.

### Provider contributions

* **Core providers have a high acceptance bar.**
* **For smaller or emerging providers, the preferred path is a community gem** rather than RubyLLM core.
* Start a community integration with `bundle exec ruby_llm provider-gem NAME`. See the [Custom Providers and Protocols](https://rubyllm.com/custom-providers/) guide.
* **Documentation must teach RubyLLM.** We do not accept provider listings, promotional links, or dedicated setup sections for third-party services that work by changing an existing provider's API base URL or API key. Document how to use RubyLLM in that service's own documentation.
* Keep generic endpoint configuration in the shared provider guide. Provider-specific documentation in this repository must support an approved core integration or explain a distinct RubyLLM requirement; a documentation-only PR does not bypass the provider acceptance policy.
* After a core provider has been discussed and approved, use `script/generate-provider NAME` to create the standard files and wiring.
* Generated code is a starting point. A core provider PR must use the real API, replace example capabilities, cover normal and streaming chat with sanitized VCR cassettes, document its configuration, and identify its model-catalog source.

## Quick Start

```bash
gh repo fork crmne/ruby_llm --clone && cd ruby_llm
bundle install
overcommit --install  # Required - sets up git hooks
gh issue develop 123 --checkout  # or create your own branch
# make changes, add tests
gh pr create --web
```

## Testing

```bash
overcommit --run

# Fast unit-only run - skips specs tagged :live, needs no cassettes or API keys:
bundle exec rspec --tag ~live

# Re-recording VCR cassettes (requires API keys):
rake vcr:record[openai,anthropic]  # Specific providers
rake vcr:record[all]               # Everything
```

Specs tagged `:live` talk to provider APIs through VCR cassettes; everything else is a plain unit test.

When a `:live` example fails, the spec suite deletes its cassette. This is on purpose. The missing file shows you which recording to look at, and the next run with API keys records it again against the real API instead of replaying a response that may be hiding the bug. Check `git status` after a failing run and re-record or restore the cassettes it removed.

Always check cassettes for leaked API keys before committing.

### Mutation testing

[Mutineer](https://github.com/davidteren/mutineer) changes the library one line at a time and runs the specs against each change. A change no spec notices is a surviving mutant: a line your specs execute but do not check. It needs MRI 3.4 or later and runs on your machine, not in CI.

Mutate a file or directory with the specs that reach it:

```bash
bin/mutineer run lib/ruby_llm/cost.rb
bin/mutineer run lib/ruby_llm/protocols/anthropic --spec spec/ruby_llm/protocols/anthropic/chat_spec.rb
bin/mutineer run lib/ruby_llm/tokens.rb -- --only 'RubyLLM::Tokens.aggregate' --format json
```

Plain-Ruby code runs against the plain specs, booted from `spec/spec_helper.rb`. Rails integration code (`lib/ruby_llm/active_record` and the railtie) runs against the Rails specs, booted from `spec/rails_helper.rb`, one mutant at a time with mutineer's `redefine` strategy. `bin/mutineer` picks the pass for each file. Options after `--` go to mutineer.

A run over the whole library takes several hours, so it runs in shards, in the background, at idle priority:

```bash
bin/mutineer start    # run every shard whose report is missing or out of date
bin/mutineer status   # running or paused, shards done, score so far
bin/mutineer pause    # freeze it while you need the CPU
bin/mutineer resume
bin/mutineer stop     # the next start picks up where this one stopped
bin/mutineer report   # survivors by file, tmp/mutineer/report.json and report.html
```

Each shard keeps its report in `tmp/mutineer/shards`, keyed by a digest of its sources and the spec tree, so `start` skips shards nothing has changed for, including after a reboot. Stopping loses only the shard in progress. A shard that was paused and came back with timed-out mutants runs again, because mutineer times mutants by the wall clock. The background run uses a systemd user unit, so it needs Linux; `bin/mutineer full` runs the same shards in the foreground anywhere.

Mutants replay cassettes and never record them. `bin/mutineer` sets `CI=1`, which puts VCR in `record: :none`, and makes the cassette directories read-only while it runs. A mutant's failing example says nothing about its cassette, so it must not delete it, and a deleted cassette would send every later mutant to the real API. The permissions come back when the run ends, is stopped, or on the next `bin/mutineer` command after a crash. `bin/mutineer unlock` restores them by hand.

The pre-push hook mutates the lines your push changes, compared with the upstream branch or `origin/main`. With a full-run report in `tmp/mutineer/report.json`, it fails only on survivors that report does not already list; without one, it fails on any survivor. It takes its specs from the coverage the full run recorded, so keep a recent full run around. Skip it for one push with `SKIP=MutationTesting git push`.

Kill a survivor with a spec that checks the behavior the line exists for, never by loosening an assertion. When a mutant is equivalent, behaving exactly like the original, remove the redundant code if you can. Otherwise add its id from the report to the `ignore:` list in `.mutineer.yml`, with a comment naming the method and why the mutant is equivalent:

```yaml
ignore:
  # Chat#initialize: an unset instance variable reads nil too.
  - cdd92a72524b
```

Keep suppressions out of `lib/`. An id changes when its method changes, so check the list when you edit one of those methods.

### OpenTelemetry conformance

Install [OpenTelemetry Weaver](https://github.com/open-telemetry/weaver/releases/tag/v0.26.1), then run:

```bash
bundle exec rake opentelemetry:check
# Or select a local executable:
WEAVER=/path/to/weaver bundle exec rake opentelemetry:check
```

This runs the tracing unit, Rails, and recorded provider specs, then checks
the exported span attributes against a pinned official GenAI registry.
The test registry adds RubyLLM's three workflow identity attributes.
Weaver reports the GenAI attributes as development conventions; violations
fail the task. SDK assertions separately check span kinds, names, parents,
context cleanup, errors, and streaming lifetimes.

The provider specs use VCR. With credentials in `.env`, missing cassettes
record real calls; otherwise existing cassettes replay without API access.

## Documentation

The site builds three versions from the same repository:

| URL | Source |
| --- | --- |
| `/` | Latest stable release tag |
| `/next/` | `main`, including unreleased changes |
| `/v1/` | Latest stable 1.x release tag |

Each version has its own guides, API reference, search, and Markdown
exports. The version selector uses the release tags selected during the
build. Prerelease tags do not replace the stable documentation.
`/models.json` remains the live model registry shared by clients.

Run `docs/bin/serve.sh` to preview all three versions. Changes to guides
rebuild under `/next/`; restart the preview to regenerate API references.
Run `docs/bin/build-versions.sh` for the complete deployment build. Both
commands require the release tags in your local checkout.

Pushing documentation or library changes to `main` updates `/next/`.
Publishing a release also rebuilds the site, promoting its tagged docs
to `/` while `main` continues at `/next/`.

## Publishing a release

Pushing to `main` runs CI. Publishing a GitHub release starts the release
workflow, which validates the tag and gem version, tests the released commit,
and publishes the gem to RubyGems and GitHub Packages. A tag push alone does
not publish the gem.

A minor release has a What's New page in `docs/_getting_started`. Only the
newest one stays there: when a new one is added, move the previous page to
`docs/_reference` with `parent: Release History`, keeping its file name so its
URL stays the same, and update the release's row in
`docs/_reference/release-history.md`.

Commit the hand-written notes in `release-notes.md`. Start the first line
with `RubyLLM` followed by the exact gem version and a summary. Include
credits, known limitations, release media, and the comparison link.

As a maintainer, push the reviewed commit to `main`, wait for CI, and create
the release using your own GitHub account. Run these commands together in
Bash so a failed check stops before GitHub creates a tag or release:

```bash
set -euo pipefail
bundle exec rake release:verify_notes release:verify_cassettes
version=$(ruby -r ./lib/ruby_llm/version -e 'puts RubyLLM::VERSION')
commit=$(git rev-parse HEAD)
git diff --exit-code HEAD
git fetch origin main
git merge-base --is-ancestor "$commit" origin/main
release_flags=()
if ruby -rrubygems/version -e 'exit(Gem::Version.new(ARGV.fetch(0)).prerelease? ? 0 : 1)' "$version"; then
  release_flags+=(--prerelease)
fi
gh release create "v$version" --target "$commit" \
  --title "RubyLLM $version" --notes-file release-notes.md "${release_flags[@]}"
```

The commands set `--prerelease` only for beta and release candidate versions.
The tag must be `v` followed by the exact gem version, and the commit
must be on `main`. GitHub creates the tag if it does not exist. Add `--draft`
to review the release on GitHub before publishing it; drafts do not start gem
publication.

The workflow retains the cassette freshness check: run
`bundle exec rake release:verify_cassettes` before publishing. It currently
requires recordings from the preceding 24 hours. If a release workflow fails,
fix the cause and rerun it; do not move a published release tag.

GitHub Pages identifies a deployment by its commit. When the release commit
is the commit `main` last deployed, the release's documentation build reuses
that deployment, which predates the tag, so the site keeps the previous
version. After publishing, check that the site's install command names the new
version. If it does not, push the next commit to `main` and run the Deploy docs
workflow on it.

## Important Notes

* **Never edit `models.json`, `aliases.json`, or `available-models.md`** - they're auto-generated by `rake models`
* **Keep it simple** - if it needs extensive documentation, reconsider the approach
* Model data comes from [models.dev](https://models.dev/). If you spot issues in the upstream registry, please report them via their site or repo.

## Response Times

This is my gift to the Ruby community.

Gifts don't come with SLAs. I respond when I can.

## Support

If RubyLLM helps you, consider [sponsoring](https://github.com/sponsors/crmne).

Sponsorship is just a way to say thanks - it doesn't buy priority support or feature requests.

Go ship AI apps!

— Carmine
