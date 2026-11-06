---
layout: default
title: File Stores
nav_order: 13
description: Give an agent its own files to find, read, search, and edit, in a Rails app or on a computer, without filling the conversation.
redirect_from:
  - /chat-files/
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* How to give an agent files in a Rails app and on a computer.
* The tools the model gets, and how to choose them.
* Why the model reads a file before it changes it.
* What the model sees of attachments and long tool results.
* How converters turn PDFs, scans, and other formats into text the model can read and search.
* Where the files live: in memory, in a folder, or in Active Storage.
* How code execution reads and writes the same files.

## An Agent with Files

A file store gives an agent its own files. The model finds them with `list_files`, searches them with `search_files`, reads the part it needs with `read_file`, and writes and changes them with `write_file` and `edit_file`. Files reach the model only when it asks for them, so a 40-page PDF attached on the first question doesn't travel with every question after it.

### In a Rails App

A persisted chat keeps its files in Active Storage. Declare `file_store` on the agent, and every chat it builds gets the files of its own record:

```ruby
# app/agents/contract_reviewer.rb
class ContractReviewer < ApplicationAgent
  instructions "You review contracts. Keep a summary of each one in notes/."
  file_store
end
```

```ruby
# app/jobs/review_job.rb
class ReviewJob < ApplicationJob
  def perform(chat_id, question, blob_ids)
    chat = ContractReviewer.find(chat_id)
    chat.ask question, with: ActiveStorage::Blob.find(blob_ids)
  end
end
```

The first question sends both contracts. On the next one, the model sees a line like `contract-v2.pdf (application/pdf, 2.1 MB) is in this chat's files`. It reads each contract with `read_file`, which turns a PDF into text through the OCR converter you register (see [PDFs, Scans, and Photos](#pdfs-scans-and-photos)), searches that text for "termination", and adds what it found to `notes/contract-v2.md`. The notes and the extracted text are still there when the next job loads the chat.

### On a Computer

A folder path gives the agent a folder on disk. Files already in the folder are its files too, so a coding or writing agent works on them where they are:

```ruby
class DocsEditor < RubyLLM::Agent
  inputs :folder
  instructions "You edit the Markdown guides in your files. Keep each change small."
  file_store -> { folder }
end

DocsEditor.new(folder: "docs").ask "Fix the broken links in the guides"
```

The model asks `search_files` which files link to a missing page, reads each one, and fixes the links with `edit_file`.

## Giving a Chat Files

`with_file_store` attaches a store to a chat, like `with_tools` attaches tools and `with_schema` a schema. Call it bare for the default store, pass a folder path or `:memory`, and pass `nil` to remove it:

```ruby
chat.with_file_store
chat.with_file_store("tmp/chats/42")
chat.with_file_store(:memory, inline_limit: 20_000)
chat.with_file_store(nil)
```

The default store keeps files in memory, or for a persisted chat, in Active Storage (see [Files in Rails](#files-in-rails)). Agents take the same arguments with the `file_store` macro (see [Agents](#agents)).

### The Tools

The model gets these tools:

| Tool | What it does |
| --- | --- |
| `list_files` | Lists the files, in one folder or matching a glob such as `reports/**/*.csv` |
| `read_file` | Reads a file with line numbers, 1,000 lines or 20,000 characters at a time |
| `search_files` | Finds lines matching a regular expression, or only the files that have one |
| `write_file` | Creates a text file, or replaces one the model has read |
| `edit_file` | Replaces exact spans of text files the model has read, one or several in a call, all or none |
| `delete_file` | Deletes one file. Only when you ask for it |

`read_file` reads text files, and other formats through the converters you register, such as OCR for PDFs (see [Reading Files as Text](#reading-files-as-text)). An image, and a PDF no converter reads, come back as the file itself, so a model with vision sees it.

`search_files` works like `grep`. It ignores case unless the model sets `case_sensitive`, narrows to a folder with `path` and to file names with `glob`, shows lines around each match with `context`, and with `files_only` names the files that match instead of the lines, which is how a model usually starts. Its output stops after 100 matches or 20,000 characters, and a slow regular expression stops instead of tying up the process. It never runs a converter, since one like OCR costs a request per file: it searches text files and the text already extracted, by `read_file`, by `chat.file_store.text`, or by a local converter when the chat kept the attachment, and names the files it skipped so the model can read them first.

A glob without a slash, like `*.md`, matches file names in any folder. One with a slash, like `reports/**/*.csv`, matches paths, inside the `path` folder when the model gives one. `**` matches any number of folders, and `{csv,tsv}` either extension.

### Several Changes in One Call

A rename or a refactor touches many spans, often in several files. `edit_file` takes them all at once in `edits`, applied in order. Each follows the same rules as a single edit: its `old_text` must appear once unless it sets `replace_all`. If any edit fails, none is written, and the error names it, like `Edit 3: old_text does not appear in app/models/user.rb.` If the store refuses a write partway, such as when it is full, the error names the files that already changed. An edit names its own `path`, or uses the call's:

```json
{
  "edits": [
    { "path": "app/models/user.rb", "old_text": "def full_name", "new_text": "def display_name" },
    { "path": "app/views/users/show.html.erb", "old_text": "user.full_name", "new_text": "user.display_name", "replace_all": true }
  ]
}
```

The model reads each file first, as for any edit. One call instead of one per span saves the model a round trip for each change.

### Choosing the Tools

The model can read and write by default. Pass `tools:` to choose:

```ruby
chat.with_file_store(tools: :read)                         # list_files, read_file, search_files
chat.with_file_store(tools: %i[read write edit])           # the default
chat.with_file_store(tools: %i[read write edit delete])    # adds delete_file
```

`:read` gives `list_files`, `read_file`, and `search_files`, and each other name gives its tool. Every store needs `:read`, since older attachments and long tool results reach the model only through it, and `tools:` without it raises `ArgumentError`.

### Reading Before Changing

The model must read a file before `edit_file` or `write_file` changes it, and read it again when it changed since. Otherwise the tool refuses with a message the model acts on:

```
notes/plan.md changed since you read it. Read it again.
```

This keeps the model from writing over a file from memory, or over a change someone else made: a person editing the same draft, code that rewrote it, or another job. A new file needs no read, and the model can keep changing a file it wrote with these tools. A file its code changed counts as changed, because the run's output doesn't show the model the new content, so `run_code` names those files in its result and the model reads them again.

The store remembers the digest of what the model read, for each path. A persisted chat keeps it in the file's row, so it survives a reload and holds across processes. `Memory` and `Directory` stores remember for as long as the store object lives, so after a reload, the model reads a folder store's file again before it changes it.

Each change locks the store while the tool reads the file, checks it, and writes it back, so `edit_file` calls running at once take turns, each on the file as the one before left it. An edit whose `old_text` the earlier one changed fails and says so, instead of writing over it. Two `write_file` calls each write the whole file, so the later one wins. Stores in the box also take the lock for every write and delete, so code execution saving its files, or your code writing one, never lands between a tool's check and its write. The Active Storage store locks the chat's row, and a `Directory` store locks its folder, which holds across processes on the same machine. On SQLite before Rails 8, a thread waiting for the database holds Ruby's global lock, so the thread with the chat's lock can't finish, and the wait ends in `database is locked`. Run one thread per process there, or use Rails 8.

### Working with the Store

`chat.file_store` returns the store, so your code works with the same files:

```ruby
store = chat.file_store

store.write("brief.md", brief)
store.list                    # => [#<RubyLLM::StoredFile path: "brief.md", byte_size: 812, content_type: "text/markdown">]
store.find("brief.md")        # => #<RubyLLM::StoredFile path: "brief.md", ...>
store["missing.md"]           # => nil
store.exist?("brief.md")      # => true
store.read("brief.md")        # => "# Brief\n..."
store.text("contract-v2.pdf") # => "## Page 1\n\nThis agreement..."
store.delete("brief.md")
store.delete_folder("reports") # => [#<RubyLLM::StoredFile path: "reports/q3.pdf", ...>]
```

Each file is a `RubyLLM::StoredFile` with `path`, `filename`, `byte_size`, `content_type`, `digest`, and `updated_at`. Paths are relative, with forward slashes, like `reports/q3.pdf`. A path with `..` raises `ArgumentError`.

`find`, `read`, and `text` raise `RubyLLM::FileNotFoundError` when there is no file, and `store[path]` returns `nil`. `delete` removes one file and returns it, or `nil` when there is none, and raises `ArgumentError` for a folder. `delete_folder` removes everything in a folder and returns the deleted files.

## What the Model Sees

**Attachments.** Every attachment is kept in the chat's files under its file name. The model sees the files attached to the latest question in full, as it would without files. From the next question on, it sees one line naming each of them, and opens them again with `read_file` when it needs to. Files that tools return, such as a PDF an MCP server fetched, become a line at once: the model reads them with `read_file`, which it sees in full until the next question.

An attachment the provider cannot take, such as a Word file for most models, goes as its text instead of the request failing, when RubyLLM's Office converter or one you registered reads that format. The conversion runs when the request is prepared, so a paid converter such as OCR costs its request then. The store keeps the text it converted, so later requests usually reuse it, though a memory store keeps only its most recent conversions. The model sees up to `inline_limit` characters, 10,000 by default, and a note that the rest is in the chat's files. When no converter reads the file, it becomes that line on its own question, and the model reads it with code when it can run code. A `convert_unsupported_attachments` handler you register comes first.

When two different files share a name, the second gets a number, like `report-2.pdf`. The same file attached twice is kept once.

The messages themselves don't change. `chat.messages` still holds every attachment, so your interface shows them as before, and removing the store sends them in full again.

**Long tool results.** A tool result longer than 10,000 characters is saved under `results/`, and the model gets its first 2,000 characters and the path:

```
item 1: Quarterly plan, owner Dana...

[This result has 48210 characters, so only the start is shown. All of it is in
results/search_drive-8f3a2b1c.json: read more with read_file, or search it with search_files.]
```

JSON is saved pretty printed, one value per line, so the model can read and search it by line. The message keeps only what the model saw, so a persisted chat stores the start too.

Change the limit with `inline_limit:`, the characters a result may have and still go to the model whole, or send every result whole with `inline_limit: false`. A tool that already returns what it finds in pages can opt out, and a tool with very long results can set its own limit:

```ruby
class SearchDocs < RubyLLM::Tool
  inline_limit false
end

class ExportOrders < RubyLLM::Tool
  inline_limit 50_000
end
```

## Reading Files as Text

`read_file` and `chat.file_store.text` read a file through converters. Text files, including source code, CSV, JSON, YAML, and Markdown, are read as they are, and Word, Excel, and PowerPoint files (`.docx`, `.xlsx`, `.pptx`) through `RubyLLM::FileStore::Converters::Office`, which reads them on your machine with no setup: a paragraph per line, a row per line with tabs between cells, and a heading for each sheet and slide. Other formats need a converter you register; without one, `read_file` hands an image or a PDF to the model as the file itself, so a model with vision sees it, and says any other file has no text to read.

Each version of a file is converted once. A persisted chat keeps the text in the file's row, and the other stores keep it in memory, so the next read or search is free.

A converter that runs on your machine for free, like the Office one, runs as soon as the chat keeps an attachment, so `search_files` finds a Word file someone attached on the first question without a `read_file` first. Converters that cost money, like OCR, wait until the model reads the file, or until a request has to send a file the provider cannot take as text, and `search_files` names the files it skipped for that: `read_file extracts it`.

### PDFs, Scans, and Photos

The OCR converter, `RubyLLM::FileStore::Converters::OCR`, reads PDFs, scans, and photos with [`RubyLLM.ocr`]({% link _getting_started/ocr.md %}), tables and all. Each file costs one OCR request the first time the model reads it, so OCR only runs where you register it. `search_files` never runs OCR; it searches the text a read already extracted:

```ruby
RubyLLM.configure do |config|
  config.file_converters["image/*"] = RubyLLM::FileStore::Converters::OCR.new
  config.file_converters["application/pdf"] = RubyLLM::FileStore::Converters::OCR.new(model: "{{ site.models.default_ocr }}")
end
```

`OCR.new` takes the options [`RubyLLM.ocr`]({% link _getting_started/ocr.md %}) does, such as `model:` and `provider:`.

`RubyLLM::FileStore::Converters::Text` reads a file as it is, for types that hold plain text but don't say so:

```ruby
config.file_converters["application/x-subrip"] = RubyLLM::FileStore::Converters::Text # .srt subtitles
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

Answer `local?` with `true` from a converter that reads files on your machine for free, and the chat runs it as soon as it keeps a file, while it prepares the request, so keep it fast. Extraction stops at the first converter for a type that isn't local, so a local one placed after a paid one waits for `read_file`. Text files need no extraction: `search_files` reads them as they are, without their converters. A PDF text-layer reader is a good one to put before OCR: it reads PDFs with text at once, and a scan, where it finds no text, falls through to OCR when the model reads it:

```ruby
class PdfText
  def self.call(file)
    PDF::Reader.new(StringIO.new(file.content)).pages.map(&:text).join("\n\n")
  end

  def self.local? = true
end

RubyLLM.configure do |config|
  config.file_converters["application/pdf"] = [PdfText, RubyLLM::FileStore::Converters::OCR.new]
end
```

Types match exactly or by family, like `"image/*"`. `"*/*"` matches every file. Exact types run before families, a type can take an Array of converters, tried in order, and registered converters run before the text and Office ones RubyLLM ships.

To share a converter, ship it as a gem named `ruby_llm-converters-<name>`, like the `ruby_llm-providers-<name>` gems for providers, with a line in its README that registers it.

## Where the Files Live

A store is any `RubyLLM::FileStore`. RubyLLM ships three:

| Store | Attach it with | Keeps files | Use it for |
| --- | --- | --- | --- |
| `RubyLLM::FileStore::Memory` | `:memory` | In memory, for as long as the chat lives | Scripts, tests, and the default in plain Ruby |
| `RubyLLM::FileStore::Directory` | A folder path | In a folder on disk | An agent on a computer, a chat that lives across runs, or a folder you share with other tools |
| `RubyLLM::ActiveRecord::FileStore` | No store, on an `acts_as_chat` record | In `ruby_llm_chat_files`, with their content in Active Storage | Persisted chats, by default; see [Rails](#files-in-rails) |

`with_file_store` also takes a store you built yourself, such as `RubyLLM::FileStore::Directory.new("tmp/work")`. `Directory` creates its folder when it is missing. The Active Storage store needs RubyLLM's Rails integration and Active Storage, and raises `RubyLLM::ConfigurationError` without them.

A `Directory` store reads the files someone else puts in its folder too, and code execution runs in that folder, so give each store a folder of its own. It leaves out hidden files and folders, never follows symbolic links, and refuses paths that would leave the folder and writes over a folder. It detects content types from file names and, when a name does not tell, from file signatures. Images and PDFs do not need a file extension.

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
  def [](path) = ...                                   # a StoredFile, or nil
  def read(path) = ...                                 # the bytes, or raise RubyLLM::FileNotFoundError
  def write(path, content, content_type: nil) = ...    # content is a String or an IO; returns the StoredFile
  def delete(path) = ...                               # the deleted StoredFile, or nil
end
```

`find`, `exist?`, and `delete_folder` come from these. Override `delete_folder` when your storage removes a folder faster than file by file.

To share a store, ship it as a gem named `ruby_llm-file_stores-<name>`, like the `ruby_llm-providers-<name>` gems for providers.

A store with a limit raises `RubyLLM::FileStoreFullError` from `write` when a file wouldn't fit. Its message goes to the model, so say what to do, such as "This chat's files are full: delete or overwrite files." The file tools answer with it as an error, `run_code` saves what fits and lists the rest under `unsaved_files` with the message as `files_error`, and a long tool result that can't be saved goes to the model whole.

RubyLLM passes only paths `RubyLLM::FileStore.path` accepts. A store that keeps its files in a folder on disk can also define `local_root`, returning the folder, so code execution runs there instead of copying files (see [Code Execution](#code-execution)). Conversions are kept in memory unless the store overrides `cached_text(file)` and `cache_text(file, text)`, and what the model read unless it overrides `read_digest(path)` and `record_read(path, digest)`. A store that several processes share should override `with_lock` to lock across them. Give your `StoredFile`s a `digest` when you can: it tells RubyLLM a file changed without reading it.

## Following Writes

`after_file_write` receives each file the conversation writes: attachments as they are kept, long tool results, and what the tools and code write:

```ruby
chat.after_file_write do |file|
  Rails.logger.info "#{file.path} (#{file.human_size})"
end
```

## Code Execution

With [code execution]({% link _advanced/code-execution.md %}) on, `run_code` works with the chat's files instead of the read-only `attachments/` folder. How depends on the store, with nothing to configure.

**A store in a folder** (`RubyLLM::FileStore::Directory`) works like a coding agent's workspace: code runs in the folder itself, reads the files where they are, and what it writes, changes, or deletes there is in the store at once. Nothing is copied in or out. The tool result lists the files the run created or changed, and `after_file_write` receives each of them:

```ruby
chat = RubyLLM.chat
  .with_file_store("tmp/work")
  .with_code_execution(python: %w[pandas matplotlib])
chat.ask "Plot monthly revenue from this export", with: "revenue.csv"

chat.file_store.list.map(&:path) # => ["revenue.csv", "revenue.png"]
```

The sandbox can read and write everything in the folder, hidden files included, so give each store a folder of its own, never one that holds anything else. Skills and mounted folders are linked into the folder for the run, read-only, and removed after it. Where the folder has its own file or folder at that path, the run sees that instead, and the tool result says so.

**Any other store** (memory, Active Storage, or your own) has each run start in an empty directory. The model names the files its code reads in `run_code`'s `files` argument, after finding them with `list_files`, and they are copied in at the same paths; a folder copies everything in it. A name with no file is an error the model sees. What the code writes or changes is saved back to the store when the run ends, and the tool result lists the paths instead of carrying the files. Deleting a file in the run directory leaves it in the store.

Either way, the model can then read a chart back with `read_file`, change a script it wrote with `edit_file` after reading it again, and run it again.

A store of your own that keeps its files in a folder gets the first behavior by returning the folder from `local_root`.

## Agents

Agents attach a store with the `file_store` macro, which takes the same arguments as `with_file_store`. Each chat gets a store of its own. To choose one, pass a lambda: it runs once for each chat, with `chat` and the agent's inputs in scope:

```ruby
class ResearchAgent < RubyLLM::Agent
  file_store inline_limit: 20_000, tools: :read
end

class ProjectAgent < RubyLLM::Agent
  inputs :project
  file_store -> { project.files_path }
end
```

A folder path without a lambda is shared by every chat the agent builds. `file_store :memory` gives each chat a new store in memory, and `file_store nil` removes the store a parent agent declared.

## Files in Rails

A persisted chat keeps its files in Active Storage, on whatever service your application uses: a disk today, a bucket tomorrow, with nothing to change in RubyLLM. Each file is a row in RubyLLM's `ruby_llm_chat_files` table. `with_file_store` with no store gives an `acts_as_chat` record that store:

```ruby
chat = Chat.create!(model: "{{ site.models.default_chat }}").with_file_store

chat.ask "Summarize these", with: params[:files]

chat.file_store.list
chat.ruby_llm_chat_files.with_attached_file # the rows, for your views
```

An attachment already in Active Storage is kept by its blob, so a message's attachment and the chat's file share one copy. Destroying the chat destroys its files.

The row keeps the text a converter made of the file in its `text` column, and the digest of what the model last read in `read_digest`. If your application encrypts what the model reads, encrypt the text too:

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
```

An agent takes the owner as a lambda, like its store: `file_store owner: -> { Current.user }`.

That store writes files for its owner and sees only their files and the files without an owner, preferring theirs when both have the same path. A store without an owner sees only the files without one.

The `ruby_llm:chat_ui` generator lists a chat's files on its page, with links to download them. Add `file_store` to the chat's agent to turn them on.

## Next Steps

* [Code Execution]({% link _advanced/code-execution.md %})
* [Attachments]({% link _core_features/attachments.md %})
* [OCR]({% link _getting_started/ocr.md %})
* [Tools]({% link _getting_started/tools.md %})
* [Rails Integration]({% link _getting_started/rails.md %})
