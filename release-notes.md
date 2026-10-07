RubyLLM 2.1.0 adds a built-in MCP client, typed judgments, agent evaluations, and OpenTelemetry tracing. Conversations use less memory, reuse connections, and keep working when you switch providers.

```sh
bundle add ruby_llm --version 2.1.0
```

**Upgrading from 2.0?** Ruby 3.2 or later is required. Run the Rails upgrade generator and read the [upgrade guide](https://rubyllm.com/upgrading/) before deploying. Applications on 1.x must finish the 2.0 upgrade first. See [What's New in 2.1](https://rubyllm.com/whats-new-in-2-1/) for examples.

![RubyLLM 2.1 MCP client guide](https://raw.githubusercontent.com/crmne/ruby_llm/v2.1.0/docs/assets/images/releases/2.1-mcp.png)

## New

- **Connect agents to MCP servers from Ruby.** Class-based servers expose tools, resources, and prompts through the chat API, with OAuth, encrypted Rails credentials, approvals, input requests, change notifications, and resumable background tasks. MCP Apps retain the results their UIs need. By @crmne. (#959, #965, #974)
- **Ask typed questions about your data.** `RubyLLM::Judge` returns probabilities, choices, and scores through TypeSafe Jev, OpenAI Decisions, and local decision models through Ollama. TypeSafe and Hetzner bring the built-in provider count to nineteen. By @crmne and @kieranklaassen. (#1008, [acecd62f](https://github.com/crmne/ruby_llm/commit/acecd62f), [16ad59b0](https://github.com/crmne/ruby_llm/commit/16ad59b0), [689d6c7a](https://github.com/crmne/ruby_llm/commit/689d6c7a))
- **Evaluate agents against reference answers.** `RubyLLM::Evaluation` runs datasets, grades correctness or your own criteria, supports Ruby assertions and RSpec/Minitest integration, and reports verdicts, progress, tokens, and cost. By @crmne. ([10eb5885](https://github.com/crmne/ruby_llm/commit/10eb5885), [50df0d14](https://github.com/crmne/ruby_llm/commit/50df0d14), [e2513142](https://github.com/crmne/ruby_llm/commit/e2513142), [d259e1d6](https://github.com/crmne/ruby_llm/commit/d259e1d6))
- **Trace model calls, tools, and workflows with OpenTelemetry.** Enable the optional integration with your application's SDK and exporters. Spans follow the GenAI conventions and omit prompts and responses. By @crmne. ([45970ee5](https://github.com/crmne/ruby_llm/commit/45970ee5))
- **Give models large tool collections without sending every definition.** `defer: true` enables native tool search on Anthropic and OpenAI Responses. Other protocols receive ordinary tool definitions. Local and MCP tools share `after_tool_progress` for showing work as it happens. By @crmne. (#980, [a76ece81](https://github.com/crmne/ruby_llm/commit/a76ece81), [9a977de3](https://github.com/crmne/ruby_llm/commit/9a977de3))
- **Spend less time and memory inside RubyLLM.** Streaming parses and appends incrementally, model lookups use an index, and replies stop retaining their requests. Persistent Faraday adapters reuse connections; Vertex AI shares credentials; Rails avoids unnecessary queries and downloads and reuses stored provider uploads. See the [measured comparisons](https://rubyllm.com/whats-new-in-2-1/#faster-by-default). By @crmne and @kalicki. (#981, [15b48ed0](https://github.com/crmne/ruby_llm/commit/15b48ed0), [d5ea078e](https://github.com/crmne/ruby_llm/commit/d5ea078e), [b7417796](https://github.com/crmne/ruby_llm/commit/b7417796))
- **Convert files a protocol cannot send.** `convert_unsupported_attachments` lets your application supply a readable replacement once per file while preserving the original transcript. `resolution:` controls supported image detail, including `:original`. By @crmne, @guizaols, and @whatthewhat. (#989, #1005, [d14b1f7a](https://github.com/crmne/ruby_llm/commit/d14b1f7a), [020d6876](https://github.com/crmne/ruby_llm/commit/020d6876))
- **Share prompt partials and configure agents per tenant.** Prompt templates render partials with locals. Runtime agent contexts can use inputs and persisted records to select credentials and endpoints. RubyLLM's supporting records can share your application's secondary database. By @kryzhovnik, @mikemikimike, and @crmne; thanks @BigBlue79. (#956, #903, [fc66b9f0](https://github.com/crmne/ruby_llm/commit/fc66b9f0))
- **Account for operations outside persisted chats.** One-shot operations and completed video/research jobs write Rails usage rows, with owner attribution. Provider tool counts share names and persist with usage; xAI and OpenRouter video results retain reported costs. By @crmne. ([073ab733](https://github.com/crmne/ruby_llm/commit/073ab733), [9775ee90](https://github.com/crmne/ruby_llm/commit/9775ee90), [48278dfa](https://github.com/crmne/ruby_llm/commit/48278dfa), [26fe4ca2](https://github.com/crmne/ruby_llm/commit/26fe4ca2))
- **Use Azure deployment names with model pricing.** Deployment mappings retain the underlying model's pricing and limits. Perplexity chat moves to the Agent API, with compatibility warnings for old Sonar names. By @guizaols, @Halvanhelv, and @crmne. (#987, #985, #994, #995)

![RubyLLM 2.1 agent evaluations guide](https://raw.githubusercontent.com/crmne/ruby_llm/v2.1.0/docs/assets/images/releases/2.1-evaluations.png)

## Fixed

- **Keep images returned by Mistral's hosted tools.** Generated images remain available as attachments and through `paint` when the assistant links to the image instead of returning an image content block. By @crmne.
- **Continue Gemini MCP conversations without repeating completed tools.** Interactions recognizes provider-executed function calls and replays their results with the signatures the API accepts. By @crmne.
- **Resume conversations across providers and interrupted jobs.** Native reasoning and signatures replay only to their originating model, Gemini can continue another provider's tool round, and interrupted history no longer sends blank replies or invalid unfinished rounds. By @crmne. ([ab4a4f06](https://github.com/crmne/ruby_llm/commit/ab4a4f06), [065fe1f8](https://github.com/crmne/ruby_llm/commit/065fe1f8), [6f8d01f5](https://github.com/crmne/ruby_llm/commit/6f8d01f5))
- **Rescue provider failures consistently.** Rejected credentials, exhausted credit, token limits, rate limits, and overloads map to specific RubyLLM errors. Retries honor millisecond delays, refresh Bedrock signatures, and retry TLS failures. Buffered streaming errors stay bounded and preserve validation details. By @crmne, @parterburn, and @tonic20. (#991, #1024, [cbfad65d](https://github.com/crmne/ruby_llm/commit/cbfad65d), [6c8b1b84](https://github.com/crmne/ruby_llm/commit/6c8b1b84), [6f16112c](https://github.com/crmne/ruby_llm/commit/6f16112c), [ca9a6c22](https://github.com/crmne/ruby_llm/commit/ca9a6c22))
- **Thinking controls reach Bedrock and Sonnet correctly.** Converse uses each model's reasoning format, and `with_thinking(false)` works with Claude Sonnet 5.5, including regional model IDs. By @tonic20, @afurm, and @crmne; thanks @davidalejandroaguilar. (#1025, #1023, #1016)
- **Restore attachments and signature-only thinking from exported messages.** Serialization retains the content needed for continued conversations. By @yorzi and @crmne. (#1003, [cd145cd9](https://github.com/crmne/ruby_llm/commit/cd145cd9))
- **Keep batch results aligned with their inputs.** Invalid or duplicate result indices raise instead of silently assigning results to the wrong input. Thinking billed as output contributes to batch costs. By @yorzi, @marckohlbrugge, and @crmne. (#993, #1000, #967, [22c652d0](https://github.com/crmne/ruby_llm/commit/22c652d0))
- **Send media in the format each provider accepts.** DeepSeek image attachments work with Chat Completions; GPUStack images, videos, and generation references stay inline where needed. Video polling respects its timeout. By @guizaols, @iamzayn19, and @crmne. (#972, #970, #975, #977, #978, #979)
- **Keep Rails migrations and usage recording reliable.** PostgreSQL usage constraints cast their columns correctly, generator mappings survive class options, and usage ledger failures do not discard successful replies. By @viktorianer, @yorzi, and @crmne. (#1009, #943, [3647170a](https://github.com/crmne/ruby_llm/commit/3647170a), [94b9ab3e](https://github.com/crmne/ruby_llm/commit/94b9ab3e))
- **Use JSON 3 where your Rails version supports it.** Faraday compatibility is preserved. Rails versions before 8.1.4 still need `gem "json", "< 3"`. By @kalicki. (#968)

## Known limitations

- **Some cost estimates and exported costs remain incomplete.** One-hour Anthropic cache writes use the shorter cache-write price (#1042). Exporting and restoring a plain-Ruby message can lose a provider-reported cost (#1045). Rails retains its stored billed amount.
- **Prompt-cache reuse can fall after reloads or mixed system instructions.** PostgreSQL/MySQL can reorder persisted tool arguments (#1040), and Responses can reorder cache-marked and unmarked system messages (#1039).
- **OpenRouter streamed citations are missing.** The non-streamed response retains them (#1043).
- **Gemini's dedicated transcription endpoint currently rejects requests.** The service returns "Thinking is not enabled for this model" even without thinking options. The Vertex AI transcription path works. See the [upstream report](https://discuss.ai.google.dev/t/gemini-3-5-transcribe-returns-400-thinking-is-not-enabled-for-this-model-without-thinking-configuration/187295).
- **MCP Apps need a UI supplied by your application.** RubyLLM exposes app resources and retained results, not a browser host. The conformance baseline also excludes the older-server elicitation-defaults scenario.
- **Provider access still determines availability.** Hetzner Inference is experimental, and hosted tools, media, and judgments depend on the selected service and account.

## Thanks

Thanks to @crmne, @kieranklaassen, @kryzhovnik, @mikemikimike, @guizaols, @whatthewhat, @kalicki, @yorzi, @marckohlbrugge, @iamzayn19, @parterburn, @viktorianer, @Halvanhelv, @tonic20, and @afurm for their contributions. Thanks to @davidalejandroaguilar and @BigBlue79 for reporting thinking and agent-context issues, and to @yorzi, @nwumnn, and @jbradmil for the outstanding cost, citation, and caching reports listed above.

**Full changelog**: https://github.com/crmne/ruby_llm/compare/v2.0.0...v2.1.0
