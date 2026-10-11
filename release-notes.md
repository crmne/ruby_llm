RubyLLM 2.1.1 fixes fresh installs that today's faraday-net_http 3.5.0 release broke, connects to MCP servers that predate the 2026-07-28 revision, and keeps batch embeddings paired with the right inputs.

```sh
bundle add ruby_llm --version 2.1.1
```

Already on 2.1? Run `bundle update ruby_llm`. No schema or code changes are needed.

## Fixed

- **Install RubyLLM with the latest faraday-net_http.** faraday-net_http 3.5.0 falls outside the range every Faraday from 2.0.1 to 2.14.4 accepts, so a fresh `bundle install` resolved Faraday 2.0.0, which loads no default adapter, and every request failed with `:net_http is not registered on Faraday::Adapter`. RubyLLM now excludes Faraday 2.0.0. By @crmne; thanks @juneira. ([ef2bebdb](https://github.com/crmne/ruby_llm/commit/ef2bebdb))
- **Connect to MCP servers that predate the 2026-07-28 revision.** A server that rejects the revision with `-32022` now gets the `initialize` handshake whether it lists the legacy revisions it speaks, as Atlassian's does, or lists none, as Datadog's does. By @ebeigarts, @juneira, and @crmne. (#1056, #1057, #1053, #1055)
- **Pair batch embeddings with the right inputs.** OpenAI-compatible and Mistral batch results now place each vector by the position the provider reports, and mark a result with duplicate, missing, or out-of-range positions as failed instead of pairing its vectors with the wrong texts. By @D41910. (#1051, #1052)
- **Keep the Bedrock inference profile you choose.** An id that already names a geography, such as `eu.anthropic.claude-sonnet-5-5`, is no longer rewritten to another region's profile, so requests stay where your IAM policy allows them. By @s-andringa. (#1050)
- **Keep chat replies when a usage row cannot be linked.** A persisted chat saves the reply and logs the failed link, instead of rolling back an answer the provider already billed. By @yorzi. (#1048, #1049)
- **Upload converted attachments again after a provider deletes them.** The chat forgets the stale upload and retries, as it already did for plain attachments. By @yorzi. (#1046, #1047)

## Thanks

Thanks to @yorzi, @s-andringa, @D41910, @ebeigarts, and @juneira for the fixes and reports in this release.

**Full changelog**: https://github.com/crmne/ruby_llm/compare/v2.1.0...v2.1.1
