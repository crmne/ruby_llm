RubyLLM 2.2.1 caps how many tool calls one answer may run, keeps a tool that already acted from running twice when another raises, fixes a deadlock Postgres apps could hit while a reply saved, and fixes Gemini batches, judgments, file stores and the generated question cards.

```sh
bundle add ruby_llm --version 2.2.1
```

Already on 2.2? Run `bundle update ruby_llm`. No schema or code changes are needed.

## New

- **Cap the tool calls one answer may run.** A model can ask for hundreds of tool calls in a single response. `with_tool_options(calls: 50)` runs the first 50; the rest get an error telling the model to continue a few calls at a time, so they never run and never ask for approval. Set it on an agent with `tool_options rounds: 25, calls: 50`, and watch it with the `tool_calls_capped.ruby_llm` event. It's off by default. By @crmne. (#1668)

## Fixed

- **A tool that already acted doesn't run again when another one raises.** When a tool raised during `complete` on a persisted chat, the finished results of its round were deleted, so the model called a tool that had already sent the email or created the record a second time. Finished calls now keep their results and the rest are closed as unfinished, as when a chat is cancelled. By @crmne; thanks @LuisFelipeRisch. (#1660, #1664)
- **No more deadlocks on Postgres when a reply saves.** With `acts_as_message touch_chat: true`, saving an answer wrote the chat row twice in one transaction, so Postgres locked every row the chat points to, such as its account or schedule. App code that locked one of those rows and waited on another could deadlock with a reply. The answer now saves with one write to the chat, and the chat is touched right after, in a transaction of its own, so its `after_touch` and `after_commit` callbacks still run. By @crmne. (#1655)
- **Keep a message sent while another job starts a reply.** A message sent with `ask_later` just as another process claimed the chat could be saved with no reply. It is now queued and answered when that run ends. By @yorzi. (#1646, #1647)
- **Record what a failed judgment cost.** A judgment whose answer couldn't be parsed was recorded with no tokens and no cost, although the provider billed it. The usage it reported is now saved first, on System One, OpenRouter and OpenAI judgments alike, and the parse error still reaches your code. By @crmne; thanks @josh-sanders. (#1614, #1658)
- **Approve a tool call without loading the whole chat.** `approve` on a persisted chat used to build the chat and its transcript just to record the decision. It now records it straight on the tool call. By @costajohnt; thanks @stephanmoneybird. (#1644, #1645)
- **Read the current version of a file.** A folder file store could show the text it had converted from an earlier version of a file with the same size and modification time, and mark the new version as read. Converted text is now tied to the exact bytes it came from. By @yorzi. (#1648, #1656)
- **Convert a file by the type it was stored with.** A file stored with an explicit type and no telling extension, such as `captions` saved as `application/x-subrip`, now goes to that type's converter. By @yorzi. (#1649, #1652)
- **Keep every type of a union in Gemini batches.** A schema field such as `["string", "integer", "null"]` lost every type after the first, or reached Gemini in a form it rejects, when the chat went through `RubyLLM.batch`. Batches now send it the way Google's own SDK does. By @crmne; thanks @yorzi for the report and the approach. (#1665, #1667)
- **Submit list answers from the generated question cards.** A question with a free-form list field, such as tags, lost its answer when submitted from the chat UI. Regenerate the chat UI to pick up the fix. By @yorzi. (#1650, #1653)

## Thanks

Thanks to @yorzi, @costajohnt, @LuisFelipeRisch, @stephanmoneybird, and @josh-sanders for the fixes and reports in this release.

**Full changelog**: https://github.com/crmne/ruby_llm/compare/v2.2.0...v2.2.1
