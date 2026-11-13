---
layout: default
title: Langchain.rb
seo:
  title: RubyLLM and Langchain.rb
nav_order: 9
description: Compare RubyLLM with Langchain.rb on agents, tools, streaming, structured output, RAG, and Rails, with code from both projects.
permalink: /compare/langchainrb/
redirect_from:
  - /migrate/langchainrb/
---

# RubyLLM and Langchain.rb

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* How the same assistant with a tool looks in Langchain.rb and in RubyLLM.
* How streaming and structured output compare.
* How each one does retrieval-augmented generation (RAG).
* What each one keeps in your Rails database.
* What Langchain.rb does better, and when to choose RubyLLM.

> **Last checked** on 13 November 2026 against RubyLLM 2.2, the [`langchainrb`](https://rubygems.org/gems/langchainrb/versions/0.19.5) gem 0.19.5 (released 1 May 2025), and the [`langchainrb_rails`](https://rubygems.org/gems/langchainrb_rails/versions/0.1.12) gem 0.1.12 (released 20 September 2024). The Langchain.rb code comes from the [Langchain.rb README at 0.19.5](https://github.com/patterns-ai-core/langchainrb/blob/0.19.5/README.md) and the [langchainrb_rails README at 0.1.12](https://github.com/patterns-ai-core/langchainrb_rails/blob/0.1.12/README.md). Comments were removed, except the two that make up the streaming block. Its examples use OpenAI, so the RubyLLM examples do too.

## Two Ruby Frameworks

[Langchain.rb](https://github.com/patterns-ai-core/langchainrb) is an MIT-licensed Ruby library for building LLM applications, started by Andrei Bondarev. Its README names two use cases: RAG with vector search, and assistants. It wraps 11 model providers, 8 vector databases, a set of ready-made tools, prompt templates, and output parsers. The separate `langchainrb_rails` gem adds Rails generators for vector search and stored assistants.

RubyLLM is the Ruby AI framework. It covers chats, agents, tools, streaming, structured output, embeddings, and Rails persistence across {{ site.provider_count }} providers, and adds media, OCR, reranking, evaluations, and cost tracking.

As of November 2026, the newest `langchainrb` release is 0.19.5, from 1 May 2025. Its main branch has [86 commits since that release](https://github.com/patterns-ai-core/langchainrb/compare/0.19.5...main), the latest on 21 October 2026, so `bundle add langchainrb` installs the May 2025 code shown here. The newest `langchainrb_rails` release is 0.1.12, from 20 September 2024.

The two start from different objects. In Langchain.rb you build an LLM client for one provider and pass it to an assistant or a vector store. In RubyLLM you configure your keys once, name a model wherever you use one, and declare agents and tools as classes.

## An Assistant with a Tool

Langchain.rb's tools extend `Langchain::ToolDefinition` and declare one or more functions. Its README defines a movie tool and gives it to an assistant. The client comes from the README's Assistants section, and the README leaves out the body of each function:

```ruby
llm = Langchain::LLM::OpenAI.new(api_key: ENV["OPENAI_API_KEY"])

class MovieInfoTool
  extend Langchain::ToolDefinition

  define_function :search_movie, description: "MovieInfoTool: Search for a movie by title" do
    property :query, type: "string", description: "The movie title to search for", required: true
  end

  define_function :get_movie_details, description: "MovieInfoTool: Get detailed information about a specific movie" do
    property :movie_id, type: "integer", description: "The TMDb ID of the movie", required: true
  end

  def initialize(api_key:)
    @api_key = api_key
  end

  def search_movie(query:)
    tool_response(...)
  end

  def get_movie_details(movie_id:)
    tool_response(...)
  end
end

movie_tool = MovieInfoTool.new(api_key: "...")

assistant = Langchain::Assistant.new(
  llm: llm,
  instructions: "You're a helpful AI assistant that can provide movie information",
  tools: [movie_tool]
)

assistant.add_message_and_run(content: "Can you tell me about the movie 'Inception'?")
assistant.messages.last
```

`add_message_and_run` stops when the model asks for a tool, so you can run it yourself and pass the result to `submit_tool_output`. `add_message_and_run!` runs the tools for you until the model answers.

In RubyLLM, each function is its own tool class, and the agent is a class too. These tools share a small base class that calls TMDb:

```ruby
class MovieTool < RubyLLM::Tool
  def initialize(api_key:)
    @api_key = api_key
  end

  private

  def tmdb(path, **params)
    Faraday.get("https://api.themoviedb.org/3/#{path}", params.merge(api_key: @api_key)).body
  end
end

class SearchMovie < MovieTool
  description "Search for a movie by title"
  parameter :query, description: "The movie title to search for"

  def execute(query:) = tmdb("search/movie", query:)
end

class GetMovieDetails < MovieTool
  description "Get detailed information about a specific movie"
  parameter :movie_id, type: :integer, description: "The TMDb ID of the movie"

  def execute(movie_id:) = tmdb("movie/#{movie_id}")
end

class MovieAssistant < RubyLLM::Agent
  model "{{ site.models.openai_latest }}"
  instructions "You're a helpful AI assistant that can provide movie information"
  tools { [SearchMovie.new(api_key: ENV["TMDB_API_KEY"]), GetMovieDetails.new(api_key: ENV["TMDB_API_KEY"])] }
end

response = MovieAssistant.new.ask "Can you tell me about the movie 'Inception'?"
puts response.content
```

`ask` runs the tools until the model answers and returns the final message. To have a person decide before a tool runs, declare `requires_approval` on it. See [Tools]({% link _getting_started/tools.md %}), [Agents]({% link _getting_started/agents.md %}), and [Controlling Tool Execution]({% link _tools/tool-execution.md %}).

## Streaming

Langchain.rb streams an assistant through a block given to its constructor:

```ruby
assistant = Langchain::Assistant.new(
  llm: llm,
  instructions: "You're a helpful AI assistant",
  tools: [Langchain::Tool::NewsRetriever.new(api_key: ENV["NEWS_API_KEY"])]
) do |response_chunk|
  # ...handle the response stream
  # print(response_chunk.inspect)
end
assistant.add_message(content: "Hello")
assistant.run(auto_tool_execution: true)
```

The README notes that streaming is not supported for every LLM. Each chunk is the provider's own data: with OpenAI, [the first choice of each streamed event](https://github.com/patterns-ai-core/langchainrb/blob/0.19.5/lib/langchain/llm/openai.rb#L128-L135); with Anthropic, [the raw event](https://github.com/patterns-ai-core/langchainrb/blob/0.19.5/lib/langchain/llm/anthropic.rb#L119-L124).

RubyLLM streams through a block given to `ask`:

```ruby
MovieAssistant.new.ask "Can you tell me about the movie 'Inception'?" do |chunk|
  print chunk.content
end
```

Each chunk has the same shape for every provider, with `content`, `thinking`, and `tool_calls`, and `ask` still returns the complete message. See [Streaming]({% link _core_features/streaming.md %}).

## Structured Output

Langchain.rb's README builds a JSON Schema, writes its format instructions into the prompt, and parses the reply:

```ruby
json_schema = {
  type: "object",
  properties: {
    name: {
      type: "string",
      description: "Persons name"
    },
    age: {
      type: "number",
      description: "Persons age"
    },
    interests: {
      type: "array",
      items: {
        type: "object",
        properties: {
          interest: {
            type: "string",
            description: "A topic of interest"
          },
          levelOfInterest: {
            type: "number",
            description: "A value between 0 and 100 of how interested the person is in this interest"
          }
        },
        required: ["interest", "levelOfInterest"],
        additionalProperties: false
      },
      minItems: 1,
      maxItems: 3,
      description: "A list of the person's interests"
    }
  },
  required: ["name", "age", "interests"],
  additionalProperties: false
}
parser = Langchain::OutputParsers::StructuredOutputParser.from_json_schema(json_schema)
prompt = Langchain::Prompt::PromptTemplate.new(template: "Generate details of a fictional character.\n{format_instructions}\nCharacter description: {description}", input_variables: ["description", "format_instructions"])
prompt_text = prompt.format(description: "Korean chemistry student", format_instructions: parser.get_format_instructions)

llm = Langchain::LLM::OpenAI.new(api_key: ENV["OPENAI_API_KEY"])
llm_response = llm.chat(messages: [{role: "user", content: prompt_text}]).completion
parser.parse(llm_response)
```

When the reply does not parse, `OutputFixingParser` sends the error, the reply, and the prompt back to the model and asks for a corrected answer. The LLM classes also [accept a `response_format`](https://github.com/patterns-ai-core/langchainrb/blob/0.19.5/lib/langchain/llm/parameters/chat.rb#L20) for providers that take one.

RubyLLM sends the schema through each provider's structured output support and parses the reply:

```ruby
class Character < Schematist::Schema
  string :name, description: "Persons name"
  number :age, description: "Persons age"
  array :interests, min_items: 1, max_items: 3, description: "A list of the person's interests" do
    object do
      string :interest, description: "A topic of interest"
      number :levelOfInterest,
             description: "A value between 0 and 100 of how interested the person is in this interest"
    end
  end
end

response = RubyLLM.chat(model: "{{ site.models.openai_latest }}")
                  .with_schema(Character)
                  .ask "Generate details of a fictional character. Character description: Korean chemistry student"
response.parsed
```

This schema produces the same JSON Schema as the hash above, and `with_schema` takes that hash too, so you can move it across unchanged. Agents declare theirs with `schema Character`. See [Structured Output]({% link _core_features/structured-output.md %}).

## RAG

Langchain.rb gives eight vector databases one interface. Its README sets up Weaviate, loads files into it, and asks a question:

```ruby
llm = Langchain::LLM::OpenAI.new(api_key: ENV["OPENAI_API_KEY"])

client = Langchain::Vectorsearch::Weaviate.new(
    url: ENV["WEAVIATE_URL"],
    api_key: ENV["WEAVIATE_API_KEY"],
    index_name: "Documents",
    llm: llm
)

client.create_default_schema

my_pdf = Langchain.root.join("path/to/my.pdf")
my_text = Langchain.root.join("path/to/my.txt")
my_docx = Langchain.root.join("path/to/my.docx")

client.add_data(paths: [my_pdf, my_text, my_docx])

client.ask(question: "...")
```

`add_data` reads docx, html, pdf, text, json, jsonl, csv, xlsx, eml, and pptx files, [splits them into chunks](https://github.com/patterns-ai-core/langchainrb/blob/0.19.5/lib/langchain/vectorsearch/base.rb#L181-L194), and embeds them. The same client offers `similarity_search`, `similarity_search_by_vector`, and `similarity_search_with_hyde`.

In Rails, `langchainrb_rails` adds vector search to an Active Record model with a generator, for pgvector, Pinecone, or Qdrant:

```bash
rails generate langchainrb_rails:pgvector --model=Product --llm=openai
```

```ruby
Product.embed!
Product.ask("list the brands of shoes that are in stock")
Product.similarity_search("t-shirt")
```

`Product.ask` embeds the question, finds the closest records, and makes one model call with them as context.

RubyLLM has no vector store wrappers, file loaders, or text splitters. You keep the vector on your own model with the [`neighbor`](https://github.com/ankane/neighbor) gem and pgvector, and a callback keeps it current:

```ruby
class Product < ApplicationRecord
  has_neighbors :embedding

  before_save :embed, if: -> { name_changed? || description_changed? }

  def self.similarity_search(query, limit: 4)
    nearest_neighbors(:embedding, RubyLLM.embed(query).vector, distance: :cosine).limit limit
  end

  private

  def embed
    self.embedding = RubyLLM.embed("#{name}: #{description}").vector
  end
end
```

Records saved before the callback existed still need a one-off backfill, which `langchainrb_rails` ships as `Product.embed!`. To answer from the catalog, give an agent a tool that searches it:

```ruby
class SearchProducts < RubyLLM::Tool
  description "Finds products in the catalog that match what the customer wants"
  parameter :query, description: "What the customer is looking for"

  def execute(query:)
    Product.similarity_search(query).map { |product| product.slice(:name, :brand, :in_stock) }
  end
end

class ShopAssistant < RubyLLM::Agent
  model "{{ site.models.openai_latest }}"
  instructions "Answer questions about the catalog. Search it before answering."
  tools SearchProducts
end

puts ShopAssistant.new.ask("List the brands of shoes that are in stock").content
```

The model decides when to search and what to search for, so it can search twice for a broad question. For a fixed pipeline like `Product.ask`, call `similarity_search` yourself and pass the results to `ask`. See [RAG]({% link _advanced/rag.md %}), [Embeddings]({% link _getting_started/embeddings.md %}), and [Reranking]({% link _getting_started/rerank.md %}).

## Rails

`langchainrb_rails` 0.1.12 has an assistant generator:

```bash
rails generate langchainrb_rails:assistant
```

It creates `Assistant` and `Message` models with their migrations, and [adds `save` and `load`](https://github.com/patterns-ai-core/langchainrb_rails/blob/0.1.12/lib/langchainrb_overrides/assistant.rb) to `Langchain::Assistant`: `save` writes the instructions, tool class names, and messages, and `Langchain::Assistant.load(id)` rebuilds the assistant from them. The README on the main branch describes controllers, views, and a route from the same generator, which are not in a released version yet.

RubyLLM's install generator creates `Chat` and `Message` models, and each message is saved as it arrives, including tool calls and their results:

```bash
bin/rails generate ruby_llm:install
```

```ruby
class Chat < ApplicationRecord
  acts_as_chat
end

chat = Chat.create! model: "{{ site.models.openai_latest }}"
chat.ask "Can you tell me about the movie 'Inception'?"

Chat.find(chat.id).ask "Who directed it?"
```

An agent class stores its chats the same way with `chat_class Chat`, `ask_later` runs a turn in Active Job, and `bin/rails generate ruby_llm:chat_ui` writes a chat interface with Turbo streaming. Each message records its tokens, and chats total their cost in dollars. See [Rails Integration]({% link _getting_started/rails.md %}) and [Agents in Background Jobs]({% link _advanced/durable-agents.md %}).

## Concept Map

| Langchain.rb | RubyLLM |
| --- | --- |
| `Langchain::LLM::OpenAI.new(api_key: ...)` | `RubyLLM.configure` once, then `RubyLLM.chat model: "..."` |
| `llm.chat(messages: [...]).chat_completion` | `RubyLLM.chat.ask("...").content` |
| `llm.embed(text: "...").embedding` | `RubyLLM.embed("...").vector` |
| `Langchain::Assistant.new(llm:, instructions:, tools:)` | A [`RubyLLM::Agent`]({% link _getting_started/agents.md %}) class |
| `extend Langchain::ToolDefinition` with `define_function` | One [`RubyLLM::Tool`]({% link _getting_started/tools.md %}) class per function |
| `add_message_and_run!` | `ask` |
| `add_message_and_run` and `submit_tool_output` | `requires_approval`, `approve`, and `decline` |
| A block given to `Langchain::Assistant.new` | A block given to `ask` |
| `StructuredOutputParser` | `with_schema` and `response.parsed` |
| `Langchain::Prompt::PromptTemplate` | [`RubyLLM.render_prompt`]({% link _core_features/prompt-rendering.md %}) with ERB files |
| `Langchain::Vectorsearch::Pgvector` | `has_neighbors` from the `neighbor` gem on your model |
| `rails generate langchainrb_rails:assistant` | `bin/rails generate ruby_llm:install` and `acts_as_chat` |
| `prompt_tokens` and `completion_tokens` | `response.tokens` and `response.cost` |
| `Langchain::Evals::Ragas` | [Evaluations]({% link _advanced/evaluations.md %}) and [Judgments]({% link _advanced/judgments.md %}) |

## What Langchain.rb Does Better

* **Vector databases behind one interface.** Chroma, Hnswlib, Milvus, Pinecone, Pgvector, Qdrant, Weaviate, and Elasticsearch share `add_texts`, `similarity_search`, and `ask`. RubyLLM leaves storage and search to your database and gems such as `neighbor`.
* **Loading files into an index.** `add_data` reads ten file formats and splits them with [chunkers](https://github.com/patterns-ai-core/langchainrb/tree/0.19.5/lib/langchain/chunker) for plain text, recursive text, sentences, Markdown, and semantic breaks. In RubyLLM you split documents yourself before embedding them.
* **Search techniques built in.** `similarity_search_with_hyde` searches with a hypothetical answer the model writes first.
* **RAG metrics built in.** `Langchain::Evals::Ragas` scores an answer for faithfulness, context relevance, and answer relevance. RubyLLM's evaluations and judgments can measure the same things, with criteria you write.
* **Ready-made tools.** Calculator, Database, FileSystem, RubyCodeInterpreter, NewsRetriever, Tavily, Weather, and Wikipedia ship with the gem. In RubyLLM you write tools like these as classes, or use provider tools such as web search.
* **Prompt templates as data.** Templates and few-shot templates save to and load from JSON or YAML, and `langchainrb_rails` can store them in a `Prompt` model. RubyLLM's prompts are ERB files in your repository.
* **Repairing malformed JSON.** `OutputFixingParser` asks the model to fix a reply that does not parse, which helps with models that lack structured output support.
* **Older Rubies.** Langchain.rb [requires Ruby 3.1 or later](https://github.com/patterns-ai-core/langchainrb/blob/0.19.5/langchain.gemspec#L15); RubyLLM requires 3.2 or later.

## When to Choose RubyLLM

* **Your application is Rails.** Chats and agents are Active Record models whose messages are saved as they arrive, turns run in Active Job, and a generator writes the chat interface.
* **You want one shape for every provider.** The same calls, chunks, and responses across {{ site.provider_count }} providers, with the model chosen by name.
* **You need cost in dollars** on responses, chats, and agents, priced from RubyLLM's model registry.
* **You need more than chat and embeddings.** Images, speech, transcription, OCR, moderation, and reranking use the same configuration.
* **You want structured output from the provider.** The schema goes to the model with the request, and `parsed` gives you the Hash.
* **You want people in the loop.** Tools that need approval pause the chat, and the decision can arrive in a later request.

## Next Steps

* [Getting Started]({% link _getting_started/getting-started.md %}) - Install RubyLLM and build a small support desk.
* [RAG]({% link _advanced/rag.md %}) - Search your own records and cite them.
* [Migrating to RubyLLM]({% link _compare/migrating-from.md %}) - Guides for other frameworks and clients.
