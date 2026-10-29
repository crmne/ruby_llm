---
layout: default
title: Chat Files
parent: "Tools"
nav_order: 9
description: Give a chat its own files, so attachments and long tool results stop filling the conversation and the model reads only what it needs.
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* How to attach a file store to a chat, and the five tools the model gets to work with it.
* What the model sees of attachments and long tool results.
* How converters turn PDFs, scans, and other formats into text the model can read and search.
* Where the files live: in memory, in a folder, or in Active Storage.
* How code execution reads and writes the same files.

## Why Files

Attachments and tool results usually travel with the conversation. A 40-page PDF someone attached on the first question is sent again with every later question, and a search that returns 30,000 characters stays in every request after it. The model pays for all of it, and its attention spreads thin.

A chat with files keeps them out of the conversation instead. Each file is kept once, the model sees one line naming it, and reads the part it needs when it needs it:

```ruby
chat = RubyLLM.chat.with_file_store
chat.ask "Which clauses changed?", with: ["contract-v1.pdf", "contract-v2.pdf"]
chat.ask "Quote the new termination clause"
```

The first question sends both PDFs. For the second, the model sees two lines like `contract-v2.pdf (application/pdf, 2.1 MB) is in this chat's files`, searches them for "termination", and reads the twenty lines around the match.

## Giving a Chat Files

`with_file_store` attaches a store to the chat, like `with_tools` attaches tools and `with_schema` a schema. Call it bare for the default store, pass the store you want, and pass `nil` to remove it:

```ruby
chat.with_file_store
chat.with_file_store(RubyLLM.file_store.memory, spill_to_file: 20_000)
chat.with_file_store(nil)
```

RubyLLM builds three stores, all from `RubyLLM.file_store`:

```ruby
chat.with_file_store(RubyLLM.file_store.memory)
chat.with_file_store(RubyLLM.file_store.directory("tmp/work"))
chat.with_file_store(RubyLLM.file_store.active_storage(chat_record, owner: user))
```

The default store is `RubyLLM.file_store.memory`, or for a persisted chat, `RubyLLM.file_store.active_storage` with its files in Active Storage (see [Files in Rails](#files-in-rails)).

The model gets five tools:

| Tool | What it does |
| --- | --- |
| `list_files` | Lists the files, or one folder, with sizes and types |
| `read_file` | Reads a file by lines or by characters, 1,000 lines or 20,000 characters at a time |
| `search_files` | Finds lines matching a regular expression across the files, with paths and line numbers |
| `write_file` | Writes a text file, replacing any file at that path |
| `edit_file` | Replaces one exact span of a text file, or every occurrence with `replace_all` |

`read_file` and `search_files` read text files, and other formats through the converters you register, such as OCR for PDFs (see [Reading Files as Text](#reading-files-as-text)). An image, and a PDF no converter reads, come back from `read_file` as the file itself, so a model with vision sees it.

`chat.file_store` returns the store, so your code works with the same files:

```ruby
chat.file_store.write("brief.md", brief)
chat.file_store.list   # => [#<RubyLLM::StoredFile path: "brief.md", byte_size: 812, content_type: "text/markdown">]
chat.file_store.read("brief.md")
chat.file_store.text("contract-v2.pdf") # => "## Page 1\n\nThis agreement..."
chat.file_store.delete("brief.md")
```

Each file is a `RubyLLM::StoredFile` with `path`, `filename`, `byte_size`, `content_type`, `digest`, and `updated_at`. Paths are relative, with forward slashes, like `reports/q3.pdf`. A path with `..` raises `ArgumentError`, and reading a missing file raises `RubyLLM::FileNotFoundError`.

## What the Model Sees

**Attachments.** Every attachment is kept in the chat's files under its file name. The model sees the files attached to the latest question in full, as it would without files. From the next question on, it sees one line naming each of them, and opens them again with `read_file` when it needs to. Files that tools return, such as a PDF an MCP server fetched, become a line at once: the model reads them with `read_file`, which it sees in full until the next question.

An attachment the provider cannot take, such as a Word file for most models, becomes that line on its own question too, instead of the request failing. The model reads it with `read_file` when a converter you registered reads that format, or with code when it can run code.

When two different files share a name, the second gets a number, like `report-2.pdf`. The same file attached twice is kept once.

The messages themselves don't change. `chat.messages` still holds every attachment, so your interface shows them as before, and removing the store sends them in full again.

**Long tool results.** A tool result longer than 10,000 characters is saved under `results/`, and the model gets its first 2,000 characters and the path:

```
item 1: Quarterly plan, owner Dana...

[This result has 48210 characters, so only the start is shown. All of it is in
results/search_drive-8f3a2b1c.json: read more with read_file, or search it with search_files.]
```

JSON is saved pretty printed, one value per line, so the model can read and search it by line. The message keeps only what the model saw, so a persisted chat stores the start too.

Change the limit with `spill_to_file:`, or send every result whole with `spill_to_file: false`. A tool that already returns what it finds in pages can opt out, and a tool with very long results can set its own limit:

```ruby
class SearchDocs < RubyLLM::Tool
  spill_to_file false
end

class ExportOrders < RubyLLM::Tool
  spill_to_file 50_000
end
```

## Reading Files as Text

`read_file`, `search_files`, and `chat.file_store.text` read a file through converters. Text files, including source code, CSV, JSON, YAML, and Markdown, are read as they are. Other formats need a converter you register; without one, `read_file` hands an image or a PDF to the model as the file itself, so a model with vision sees it, and says any other file has no text to read.

Each version of a file is converted once. A persisted chat keeps the text in the file's row, and the other stores keep it in memory, so the next read or search is free.

### PDFs, Scans, and Photos

The OCR converter, `RubyLLM.file_store.converter.ocr`, reads PDFs, scans, and photos with [`RubyLLM.ocr`]({% link _core_features/ocr.md %}), tables and all. Each file costs one OCR request the first time the model reads or searches it, so OCR only runs where you register it:

```ruby
RubyLLM.configure do |config|
  config.file_converters["image/*"] = RubyLLM.file_store.converter.ocr
  config.file_converters["application/pdf"] = RubyLLM.file_store.converter.ocr(model: "{{ site.models.default_ocr }}")
end
```

`ocr` takes the options [`RubyLLM.ocr`]({% link _core_features/ocr.md %}) does, such as `model:` and `provider:`.

`RubyLLM.file_store.converter.text` reads a file as it is, for types that hold plain text but don't say so:

```ruby
config.file_converters["application/x-subrip"] = RubyLLM.file_store.converter.text # .srt subtitles
```

### Writing a Converter

A converter is anything that answers `call` with an `Attachment` and returns the file's text, or `nil` to pass it to the next converter for its type. Register it for the types it reads:

```ruby
class OdtConverter
  def self.call(file)
    OdtReader.new(file.content).text
  end
end

RubyLLM.configure do |config|
  config.file_converters["application/vnd.oasis.opendocument.text"] = OdtConverter
end
```

Types match exactly or by family, like `"image/*"`. `"*/*"` matches every file. Exact types run before families, a type can take an Array of converters, tried in order, and registered converters run before the text one RubyLLM ships.

To share a converter, ship it as a gem named `ruby_llm-converters-<name>`, like the `ruby_llm-providers-<name>` gems for providers, with a line in its README that registers it.

## Where the Files Live

A store is any `RubyLLM::FileStore`. RubyLLM ships three:

| Store | Keeps files | Use it for |
| --- | --- | --- |
| `RubyLLM.file_store.memory` | In memory, for as long as the chat lives | Scripts, tests, and the default in plain Ruby |
| `RubyLLM.file_store.directory(path)` | In a folder on disk | A chat that lives across runs, or a folder you share with other tools |
| `RubyLLM.file_store.active_storage(chat_record, owner: nil)` | In `ruby_llm_chat_files`, with their content in Active Storage | Persisted chats, by default; see [Rails](#files-in-rails) |

`RubyLLM.file_store.memory` builds a `RubyLLM::FileStore::Memory`, `RubyLLM.file_store.directory(path)` a `RubyLLM::FileStore::Directory`, creating the folder when it is missing, and `RubyLLM.file_store.active_storage(chat_record)` a `RubyLLM::ActiveRecord::FileStore` for an `acts_as_chat` record. The last needs RubyLLM's Rails integration and Active Storage, and raises `RubyLLM::ConfigurationError` without them.

A `Directory` store reads the files someone else puts in its folder too, and code execution runs in that folder, so give each store a folder of its own. It leaves out hidden files and folders, never follows symbolic links, and refuses paths that would leave the folder. It detects content types from file names and, when a name does not tell, from file signatures. Images and PDFs do not need a file extension.

### Writing Your Own Store

Subclass `RubyLLM::FileStore` and implement five methods:

```ruby
class BucketStore < RubyLLM::FileStore
  def initialize(bucket, prefix)
    super()
    @bucket = bucket
    @prefix = prefix
  end

  def list(prefix = nil) = ...                         # StoredFiles inside the folder, sorted by path
  def find(path) = ...                                 # a StoredFile, or nil
  def read(path) = ...                                 # the bytes, or raise RubyLLM::FileNotFoundError
  def write(path, content, content_type: nil) = ...    # content is a String or an IO; returns the StoredFile
  def delete(path) = ...                               # the StoredFile, or nil
end
```

To share a store, ship it as a gem named `ruby_llm-file_stores-<name>`, like the `ruby_llm-providers-<name>` gems for providers.

A store with a limit raises `RubyLLM::FileStoreFullError` from `write` when a file wouldn't fit. Its message goes to the model, so say what to do, such as "This chat's files are full: delete or overwrite files." The file tools answer with it as an error, `run_code` saves what fits and lists the rest under `unsaved_files` with the message as `files_error`, and a long tool result that can't be saved goes to the model whole.

RubyLLM passes only paths `RubyLLM::FileStore.path` accepts. A store that keeps its files in a folder on disk can also define `local_root`, returning the folder, so code execution runs there instead of copying files (see [Code Execution](#code-execution)). Conversions are kept in memory unless the store overrides `cached_text(file)` and `cache_text(file, text)`. Give your `StoredFile`s a `digest` when you can: it tells RubyLLM a file changed without reading it.

## Following Writes

`after_file_write` receives each file the conversation writes: attachments as they are kept, long tool results, and what the tools and code write:

```ruby
chat.after_file_write do |file|
  Rails.logger.info "#{file.path} (#{file.human_size})"
end
```

## Code Execution

With [code execution]({% link _core_features/code-execution.md %}) on, `run_code` works with the chat's files instead of the read-only `attachments/` folder. How depends on the store, with nothing to configure.

**A store in a folder** (`RubyLLM.file_store.directory`) works like a coding agent's workspace: code runs in the folder itself, reads the files where they are, and what it writes, changes, or deletes there is in the store at once. Nothing is copied in or out. The tool result lists the files the run created or changed, and `after_file_write` receives each of them:

```ruby
chat = RubyLLM.chat
  .with_file_store(RubyLLM.file_store.directory("tmp/work"))
  .with_code_execution(python: %w[pandas matplotlib])
chat.ask "Plot monthly revenue from this export", with: "revenue.csv"

chat.file_store.list.map(&:path) # => ["revenue.csv", "revenue.png"]
```

The sandbox can read and write everything in the folder, hidden files included, so give each store a folder of its own, never one that holds anything else. Skills and mounted folders are linked into the folder for the run, read-only, and removed after it. Where the folder has its own file or folder at that path, the run sees that instead, and the tool result says so.

**Any other store** (memory, Active Storage, or your own) has each run start in an empty directory. The model names the files its code reads in `run_code`'s `files` argument, after finding them with `list_files`, and they are copied in at the same paths; a folder copies everything in it. A name with no file is an error the model sees. What the code writes or changes is saved back to the store when the run ends, and the tool result lists the paths instead of carrying the files. Deleting a file in the run directory leaves it in the store.

Either way, the model can then read a chart back with `read_file`, change a script it wrote with `edit_file`, and run it again.

A store of your own that keeps its files in a folder gets the first behavior by returning the folder from `local_root`.

## Agents

Agents attach a store with the `file_store` macro, which takes the same arguments as `with_file_store`. Each chat gets a store of its own. To choose one, pass a lambda: it runs once for each chat, with `chat` and the agent's inputs in scope:

```ruby
class ResearchAgent < RubyLLM::Agent
  file_store spill_to_file: 20_000
end

class ProjectAgent < RubyLLM::Agent
  inputs :project
  file_store -> { RubyLLM.file_store.directory(project.files_path) }
end
```

`file_store nil` removes the store a parent agent declared.

## Files in Rails

A persisted chat keeps its files in Active Storage, on whatever service your application uses: a disk today, a bucket tomorrow, with nothing to change in RubyLLM. Each file is a row in RubyLLM's `ruby_llm_chat_files` table. `with_file_store` with no store gives an `acts_as_chat` record that store, the one `RubyLLM.file_store.active_storage` builds:

```ruby
chat = Chat.create!(model: "{{ site.models.default_chat }}").with_file_store
# the same as
chat.with_file_store(RubyLLM.file_store.active_storage(chat))

chat.ask "Summarize these", with: params[:files]

chat.file_store.list
chat.ruby_llm_chat_files.with_attached_file # the rows, for your views
```

An attachment already in Active Storage is kept by its blob, so a message's attachment and the chat's file share one copy. Destroying the chat destroys its files.

The row keeps the text a converter made of the file in its `text` column. If your application encrypts what the model reads, encrypt it too:

```ruby
# config/initializers/ruby_llm.rb
Rails.application.config.to_prepare do
  RubyLLM::ActiveRecord::ChatFile.encrypts :text
end
```

### Files of Several People

In a chat several people share, files a tool fetched for one of them may not be for the others. Give the store an owner:

```ruby
chat.with_file_store(owner: Current.user)
# short for
chat.with_file_store(RubyLLM.file_store.active_storage(chat, owner: Current.user))
```

An agent takes the owner as a lambda, like its store: `file_store owner: -> { Current.user }`.

That store writes files for its owner and sees only their files and the files without an owner, preferring theirs when both have the same path. A store without an owner sees only the files without one.

The `ruby_llm:chat_ui` generator lists a chat's files on its page, with links to download them. Add `file_store` to the chat's agent to turn them on.

## Next Steps

* [Code Execution]({% link _core_features/code-execution.md %})
* [Attachments]({% link _core_features/attachments.md %})
* [OCR]({% link _core_features/ocr.md %})
* [Tools]({% link _core_features/tools.md %})
* [Rails Integration]({% link _advanced/rails.md %})
