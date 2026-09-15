# Issue assessment

One Copilot prompt chooses up to two labels and an optional clarification.
Technical questions can use one additional prompt with up to two docs or source
files. The Ruby script validates the result and applies it through GitHub's API.

```ruby
item, labels = read_report
decision = assess(item, labels)
publish(item, labels, decision)
```

## What runs

The workflow handles new issues, reopened issues, and new discussions. Ordinary
comments do not trigger it. It reads the report and its five latest comments.
It skips closed reports and bot reports. Previews can assess closed reports.

The model selects labels and clarification replies from `config.yml`. A complete
bug report normally gets a label and no comment. For technical questions, it can
select up to two files from the configured source catalog, then answer from their
contents in at most 60 words. The script validates the cited files and appends
links to the exact Git revision it read. It leaves uncertain answers, product
decisions, and duplicate investigations to the maintainer.

The model has no tools or GitHub write access. It cannot close reports or modify
files. Source paths must come from the configured catalog; symlinked files are
excluded. Generated answers cannot contain external URLs, HTML, or user mentions.
Ruby examples can use instance variables inside code spans or fenced blocks.

Successful assessments get a bot 🎉 reaction after publishing. Reopening or
manually assessing a report considers its current text and recent comments;
an old reaction does not prevent reassessment. The script checks for changes
before publishing and leaves an updated report for a later run.

## Try it

Run **Issue assessment** from the Actions tab with a report number. Keep
`dry_run` enabled to see its choice in the job summary without changing GitHub.
Uncached prompts in a preview use Copilot credits.

To use this in another repository:

1. Copy this directory and `.github/workflows/issue-assessment.yml`.
2. Edit `config.yml` with your existing labels, replies, source file patterns, and
   triage policy.
3. Add a `COPILOT_GITHUB_TOKEN` secret with Copilot access.
4. Set `COPILOT_ISSUE_ASSESSMENT_ENABLED` to `true` in repository variables.

The script uses Ruby's standard library, GitHub CLI, and Copilot CLI. It does not
need Bundler, RubyLLM, or a provider API key. The workflow installs a pinned Copilot
version on an Ubuntu runner. Use a dedicated fine-grained token with **Copilot
Requests** permission; see [Copilot authentication](https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-command-reference#copilot-login-options).
The workflow's separate GitHub token supplies issue and discussion permissions.

## Cost and failures

Validated model responses are cached per report through GitHub Actions. The key
includes the complete prompt, model, and script version. Unchanged prompts reuse
their response without calling Copilot. New comments, policy changes, or a
different model produce a new key. Technical answer keys include the complete
source contents, so a source change refreshes the answer while source selection
can still be reused. Cached output is validated again before use.

Only model responses are cached, not a remote conversation or a claim that an
issue is permanently handled. Every run reads the current report. A response
that failed validation is never cached, and a corrupt cache entry is discarded.
Stable instructions and source material precede the changing report text to
help provider-side prompt caching too; Copilot controls whether those tokens
actually receive a cache discount. GitHub may evict the Actions cache, in which
case the next run makes a fresh model call.

The default model is `gpt-5.6-luna`. The first prompt is limited to 24 KB. A
technical answer can include at most 48 KB of complete source files in a prompt
of at most 64 KB. Oversized requests are left for a maintainer; files are not
silently truncated. Copilot runs with an empty tool list, no MCP servers,
no repository instructions, and an isolated settings
directory. The CLI can add its own system prompt, so total billed input is larger
than the text supplied by the script.

The pinned CLI retains its skill and SQL tools even with an empty agent tool
list. The script excludes those explicitly. The offline integration spec checks
the actual request sent by the installed CLI, including that no tools are exposed.

There are at most two prompt invocations, each with a 90-second process timeout,
and no workflow retry loop. Copilot may retry service requests internally.
Its 30-credit session limit is a secondary safeguard: that is the CLI's minimum,
and it is a soft limit that
can be exceeded by an in-flight response. It is not the expected cost per report.
The actual usage JSON is recorded in the job summary when available.

Copilot failures and invalid output produce a job summary and leave the report
unchanged. They do not create failure issues or comments. GitHub write failures
fail the job without marking the assessment complete. Exhausted account credits
still require a reset or a paid usage budget; the workflow does not change billing.

Run the offline specs from the repository root:

```bash
bundle exec rspec spec/tasks/issue_assessment_spec.rb spec/tasks/issue_assessment_cli_spec.rb
```

The CLI integration spec uses a local fake model with Copilot's offline mode.
It spends no credits and skips when Copilot CLI is not installed.
