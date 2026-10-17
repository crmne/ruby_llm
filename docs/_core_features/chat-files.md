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

* How to give a chat files, and the five tools the model gets to work with them.
* What the model sees of attachments and long tool results.
* How PDFs, Office files, and scans become text the model can read and search.
* Where the files live: in memory, in a folder, or in Active Storage.
* How code execution reads and writes the same files.

## Why Files

Attachments and tool results usually travel with the conversation. A 40-page PDF someone attached on the first question is sent again with every later question, and a search that returns 30,000 characters stays in every request after it. The model pays for all of it, and its attention spreads thin.

A chat with files keeps them out of the conversation instead. Each file is kept once, the model sees one line naming it, and reads the part it needs when it needs it:

```ruby
chat = RubyLLM.chat.with_files
chat.ask "Which clauses changed?", with: ["contract-v1.pdf", "contract-v2.pdf"]
chat.ask "Quote the new termination clause"
```

The first question sends both PDFs. For the second, the model sees two lines like `contract-v2.pdf (application/pdf, 2.1 MB) is in this chat's files`, searches them for "termination", and reads the twenty lines around the match.

## Giving a Chat Files

`with_files` follows the same shape as `with_code_execution`: call it bare to turn it on, pass options to tune it, and pass `false` to turn it off:

```ruby
chat.with_files
chat.with_files(spill_over: 20_000)
chat.with_files(store: RubyLLM::FileStore::Directory.new("tmp/chats/42"))
chat.with_files(false)
```

The model gets five tools:

| Tool | What it does |
| --- | --- |
| `list_files` | Lists the files, or one folder, with sizes and types |
| `read_file` | Reads a file by lines or by characters, 1,000 lines or 20,000 characters at a time |
| `search_files` | Finds lines matching a regular expression across the files, with paths and line numbers |
| `write_file` | Writes a text file, replacing any file at that path |
| `edit_file` | Replaces one exact span of a text file, or every occurrence with `replace_all` |

`read_file` and `search_files` read PDFs, Word, Excel, and PowerPoint files as text (see [Reading Files as Text](#reading-files-as-text)). An image, and a PDF without a text layer, come back from `read_file` as the file itself, so a model with vision sees it.

`chat.files` returns the store, so your code works with the same files:

```ruby
chat.files.write("brief.md", brief)
chat.files.list   # => [#<RubyLLM::StoredFile path: "brief.md", byte_size: 812, content_type: "text/markdown">]
chat.files.read("brief.md")
chat.files.text("contract-v2.pdf") # => "## Page 1\n\nThis agreement..."
chat.files.delete("brief.md")
```

Each file is a `RubyLLM::StoredFile` with `path`, `filename`, `byte_size`, `content_type`, `digest`, and `updated_at`. Paths are relative, with forward slashes, like `reports/q3.pdf`. A path with `..` raises `ArgumentError`, and reading a missing file raises `RubyLLM::FileNotFoundError`.

## What the Model Sees

**Attachments.** Every attachment is kept in the chat's files under its file name. The model sees the files attached to the latest question in full, as it would without files. From the next question on, it sees one line naming each of them, and opens them again with `read_file` when it needs to. Files that tools return, such as a PDF an MCP server fetched, become a line at once: the model reads them with `read_file`, which it sees in full until the next question.

An attachment the provider cannot take, such as a Word file for most models, becomes that line on its own question too, so the model reads it with `read_file` instead of the request failing.

When two different files share a name, the second gets a number, like `report-2.pdf`. The same file attached twice is kept once.

The messages themselves don't change. `chat.messages` still holds every attachment, so your interface shows them as before, and turning files off sends them in full again.

**Long tool results.** A tool result longer than 10,000 characters is saved under `results/`, and the model gets its first 2,000 characters and the path:

```
item 1: Quarterly plan, owner Dana...

[This result has 48210 characters, so only the start is shown. All of it is in
results/search_drive-8f3a2b1c.json: read more with read_file, or search it with search_files.]
```

JSON is saved pretty printed, one value per line, so the model can read and search it by line. The message keeps only what the model saw, so a persisted chat stores the start too.

Change the limit with `spill_over:`, or send every result whole with `spill_over: false`. A tool that already returns what it finds in pages can opt out, and a tool with very long results can set its own limit:

```ruby
class SearchDocs < RubyLLM::Tool
  spill_over false
end

class ExportOrders < RubyLLM::Tool
  spill_over 50_000
end
```

## Reading Files as Text

`read_file`, `search_files`, and `chat.files.text` read a file through converters. RubyLLM ships converters for:

* Text files, including source code, CSV, JSON, YAML, and Markdown, as they are.
* HTML, without its tags, scripts, and styles.
* Word, Excel, and PowerPoint files (`.docx`, `.xlsx`, `.pptx`): paragraphs, sheets with tab-separated cells, and slides.
* PDFs, page by page, when your bundle has the [pdf-reader](https://github.com/yob/pdf-reader) gem.

```ruby
# Gemfile
gem "pdf-reader"
```

Each version of a file is converted once. A persisted chat keeps the text in the file's row, and the other stores keep it in memory, so the next read or search is free.

### Scans and Photos

A scanned PDF has no text layer, and a photo of a whiteboard has no text at all. `RubyLLM::FileStore::Converters::OCR` reads both with [`RubyLLM.ocr`]({% link _core_features/ocr.md %}). Each file costs one OCR request the first time the model reads or searches it, so OCR only runs where you register it:

```ruby
RubyLLM.configure do |config|
  config.file_converters = {
    "image/*" => RubyLLM::FileStore::Converters::OCR.new,
    "application/pdf" => RubyLLM::FileStore::Converters::OCR.new(model: "{{ site.models.default_ocr }}")
  }
end
```

Converters you register run before the built-in ones. Registering OCR for PDFs reads every PDF with OCR, even those with a text layer. To use OCR only for scans, leave PDFs to the built-in converter: `read_file` hands a PDF without text to the model as the file itself.

### Your Own Converters

A converter is anything that answers `call` with an `Attachment` and returns the file's text, or `nil` to pass it to the next converter for its type:

```ruby
RubyLLM.configure do |config|
  config.file_converters = {
    "application/vnd.oasis.opendocument.text" => ->(file) { OdtReader.new(file.content).text },
    "application/zip" => ZipListing
  }
end
```

Types match exactly or by family, like `"image/*"`. `"*/*"` matches every file. Exact types run before families, and a type can take an Array of converters, tried in order.

## Where the Files Live

A store is any `RubyLLM::FileStore`. RubyLLM ships three:

| Store | Keeps files | Use it for |
| --- | --- | --- |
| `RubyLLM::FileStore::Memory` | In memory, for as long as the chat lives | Scripts, tests, and the default in plain Ruby |
| `RubyLLM::FileStore::Directory` | In a folder on disk | A chat that lives across runs, or a folder you share with other tools |
| `RubyLLM::ActiveRecord::FileStore` | In Active Storage, in `ruby_llm_chat_files` | Persisted chats; see [Rails](#files-in-rails) |

A `Directory` store reads the files someone else puts in its folder too. It leaves out hidden files and folders, never follows symbolic links, and refuses paths that would leave the folder. It detects content types from file names.

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

RubyLLM passes only paths `RubyLLM::FileStore.path` accepts. Conversions are kept in memory unless the store overrides `cached_text(file)` and `cache_text(file, text)`. Give your `StoredFile`s a `digest` when you can: it tells RubyLLM a file changed without reading it.

## Following Writes

`after_file_write` receives each file the conversation writes: attachments as they are kept, long tool results, and what the tools and code write:

```ruby
chat.after_file_write do |file|
  Rails.logger.info "#{file.path} (#{file.human_size})"
end
```

## Code Execution

With [code execution]({% link _core_features/code-execution.md %}) on, each run starts with a copy of the chat's files in its run directory, instead of the read-only `attachments/` folder. What the code writes or changes there is saved back to the store when the run ends, and the tool result lists the paths instead of carrying the files:

```ruby
chat = RubyLLM.chat.with_files.with_code_execution(python: %w[pandas matplotlib])
chat.ask "Plot monthly revenue from this export", with: "revenue.csv"

chat.files.list.map(&:path) # => ["revenue.csv", "revenue.png"]
```

The model can then read the chart back with `read_file`, change a script it wrote with `edit_file`, and run it again. Deleting a file in the run directory leaves it in the store. Mounted folders and skills keep their places, so a file in the store under `skills/` or a mount's path is not copied.

## Agents

Agents declare files with the `files` macro, which takes the same options. Each chat gets a store of its own. To choose one, pass a lambda: it runs once for each chat, with `chat` and the agent's inputs in scope:

```ruby
class ResearchAgent < RubyLLM::Agent
  files spill_over: 20_000
end

class ProjectAgent < RubyLLM::Agent
  inputs :project
  files store: -> { RubyLLM::FileStore::Directory.new(project.files_path) }
end
```

`files false` removes the files a parent agent declared.

## Files in Rails

A persisted chat keeps its files in Active Storage, on whatever service your application uses: a disk today, a bucket tomorrow, with nothing to change in RubyLLM. Each file is a row in RubyLLM's `ruby_llm_chat_files` table:

```ruby
chat = Chat.create!(model: "{{ site.models.default_chat }}").with_files
chat.ask "Summarize these", with: params[:files]

chat.files.list
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
chat.with_files(store: chat.file_store(owner: Current.user))
```

That store writes files for its owner and sees only their files and the files without an owner, preferring theirs when both have the same path. A store without an owner sees only the files without one.

The `ruby_llm:chat_ui` generator lists a chat's files on its page, with links to download them. Add `files` to the chat's agent to turn them on.

## Next Steps

* [Code Execution]({% link _core_features/code-execution.md %})
* [Attachments]({% link _core_features/attachments.md %})
* [OCR]({% link _core_features/ocr.md %})
* [Tools]({% link _core_features/tools.md %})
* [Rails Integration]({% link _advanced/rails.md %})
