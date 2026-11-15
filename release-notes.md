RubyLLM 2.2.2 loads the Ruby classes apps keep in `app/skills` again, keeps model rows your chats still use when a registry refresh runs without a foreign key, and shows each choice's title on the generated question cards.

```sh
bundle add ruby_llm --version 2.2.2
```

Already on 2.2? Run `bundle update ruby_llm`. No schema or code changes are needed.

## Fixed

- **Your own classes in `app/skills` load again.** 2.2 told the Rails autoloader to skip the whole `app/skills` folder, so an app that keeps its own Ruby classes there got `NameError` for every one of them after upgrading, whether or not it used RubyLLM skills. Now only skill folders are skipped: any folder holding a `SKILL.md`, at any depth, including skill folders that are symbolic links. Everything else in `app/skills` loads as it did in 2.1, and a skill you add while the development server runs is skipped on the next reload, with no restart. By @crmne; thanks @sebscholl. (#1671, #1675)
- **A model refresh keeps the models your chats use, with or without a foreign key.** Refreshing the model registry deleted `ruby_llm_models` rows it no longer listed, and only the foreign key from chats stopped it from deleting rows a chat still pointed at. Schemas without that key, such as MySQL setups that skip foreign keys, lost those rows and left chats pointing at nothing. Referenced rows are now kept and marked unlisted, as they are with the foreign key. By @yshmarov. (#1670)

## New

- **Question cards show each choice's title.** When a tool's `ask` or an MCP server gives its choices titles, the generated chat UI showed the raw values, such as `17` and `42`, instead of "River bank" and "Money bank". The cards now label each button and option with its title and still submit the value. Your own UI can read the titles with `field.choice_titles`, which understands `oneOf` and `items.anyOf` with `const` and `title`, and `enumNames`. Regenerate the chat UI to pick it up. By @kryzhovnik. (#1661)

## Thanks

Thanks to @yshmarov and @kryzhovnik for the fixes in this release, and to @sebscholl for reporting the `app/skills` regression.

**Full changelog**: https://github.com/crmne/ruby_llm/compare/v2.2.1...v2.2.2
