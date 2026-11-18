RubyLLM 2.2.3 adds Gemini judgments, your own prices for models, a limit on how many tool calls run at once, a callback for chats under row-level security, and titled choices from a Hash. It also fixes a batch of bugs in questions, file stores, code execution, and logging.

```sh
bundle add ruby_llm --version 2.2.3
```

Already on 2.2? Run `bundle update ruby_llm`. No schema or code changes are needed.

## New

- **Judge with Gemini.** `RubyLLM::Judge` works with `gemini-decision-1` through Google's Decisions API, for probabilities, choices, and scores over text, images, audio, video, and PDFs. A blocked input raises `ContentFilterError`. By @alextrueman. (#1692)
- **Set the prices you pay.** `config.price "gpt-5.6-luna", provider: :azure, input: 0.24, output: 1.44` replaces the registry's price for a model, for a Data Zone deployment, a negotiated rate, or a model the registry has no price for. Every cost uses it, and a registry refresh keeps it. Prices are global: a context can't set them. By @crmne; thanks @siem-moneybird. (#1685, #1703)
- **Cap how many tool calls run at once.** `chat.with_tool_options(concurrency: :threads, workers: 4)` runs a response's tool calls four at a time, on a pool of that many threads or fibers. Every call still runs and returns its result. By @crmne; thanks @yorzi. (#1674, #1707)
- **Renew claims under row-level security.** A running chat renews its claims from a thread of its own, on a connection with no tenant set, so under PostgreSQL row-level security any run longer than the renewal interval stopped as busy. `around_claim_renewal` on an `acts_as_chat` model wraps each renewal, so you can set the tenant in a transaction around it. By @crmne; thanks @PabloAraya6. (#1694, #1701)
- **Title each choice with a Hash.** `ask("Which card?", choices: { "17" => "River bank", "42" => "Money bank" })` shows the titles and returns the value, without writing the `oneOf` schema by hand. By @kryzhovnik. (#1662)
- **Rerank on OpenAI-compatible servers.** `RubyLLM.rerank` with `provider: :openai` and a custom `openai_api_base` reaches the `/v1/rerank` endpoint of llama.cpp, vLLM, and similar servers. By @crmne; thanks @mvysny. (#1684, #1690)
- **Keep request and response bodies out of debug logs.** `config.log_bodies = false` logs requests without their bodies. API keys are also replaced with `[FILTERED]` in every log line, and streaming uses the logger of its context. By @josh-sanders. (#1669, #1680)

## Fixed

- **Code execution no longer rewrites what the model already read.** When a later run returned a file with a name an earlier one had used, the earlier tool result's description changed. Anthropic refused the next request once a thinking block followed it ("bound to a different conversation"), and prompt caching stopped at that turn on every provider. Each description now stays as the model first read it. By @jordanyeo. (#1699, #1700)
- **An answer only reaches the question it was given to.** A tool that asked a different question when it ran again could receive the answer to the earlier one. It now asks again. By @crmne; thanks @kryzhovnik. (#1682, #1691)
- **Number questions refuse `Infinity` and `NaN`.** An answer such as `"1e309"` was accepted and then couldn't be stored as JSON. By @yorzi. (#1695, #1697)
- **List answers check each item's type.** `ask { array :seats, of: :integer }` accepted `["2", "bad"]`. Items are now converted and checked like single fields. By @yorzi. (#1696, #1698)
- **A folder file store refuses paths through links to folders.** A link inside the store's folder that pointed at a hidden folder let `read`, `text`, and `delete` reach it. By @yorzi. (#1673, #1677)
- **Listing a folder file store survives a concurrent write.** A listing that raced a write could come back empty, so the model was told the chat had no files. By @yorzi. (#1672, #1676)
- **A stopped run under a fiber scheduler ends its claims.** When the other fibers held every connection, the run raised `ActiveRecord::ConnectionTimeoutError` in place of what stopped it. By @crmne. (#1687, #1688)
- **Errors from hand-built responses keep their own message.** A `RubyLLM::Error` raised with a response that had no request options was replaced by a `NoMethodError` during cleanup. By @crmne; thanks @thomaswitt. (#1679, #1689)
- **Requiring RubyLLM holds less memory.** The MIME type table loads the first time a file's type is looked up, not at require. By @Evshved. (#1686)

## Known limitations

- **MiniMax has no structured output again.** MiniMax retired `MiniMax-Text-01`, the only one of its models that applied a schema, so `with_schema` raises `ArgumentError` on MiniMax as it did before 2.2. (#1706)

## Thanks

Thanks to @alextrueman, @kryzhovnik, @josh-sanders, @jordanyeo, @yorzi, and @Evshved for the features and fixes in this release, and to @siem-moneybird, @yorzi, @PabloAraya6, @mvysny, and @thomaswitt for the reports behind them.

**Full changelog**: https://github.com/crmne/ruby_llm/compare/v2.2.2...v2.2.3
