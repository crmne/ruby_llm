---
layout: default
title: Migrating from langchainrb
nav_order: 5
description: Move a langchainrb application to RubyLLM, with before and after code for chat, retrieval Q&A, and a tool-using assistant.
permalink: /migrate/langchainrb/
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* How langchainrb's LLM clients, assistants, and tools map to RubyLLM.
* How to move retrieval Q&A from a vector search client to your own database.
* How to turn a `Langchain::Assistant` with custom tools into a RubyLLM agent.
* Where prompt templates, output parsers, and evaluations go.
* When langchainrb still covers something RubyLLM does not.

> **Last checked** on 5 November 2026 against RubyLLM 2.2 and langchainrb 0.19.5, released 1 May 2025. There has been no langchainrb gem release since May 2025 (checked 5 November 2026); its repository still receives commits. The langchainrb code comes from its [README](https://github.com/patterns-ai-core/langchainrb#readme): [Generating Chat Completions](https://github.com/patterns-ai-core/langchainrb#generating-chat-completions), [Using Vector Search Databases](https://github.com/patterns-ai-core/langchainrb#using-vector-search-databases-), [Assistants](https://github.com/patterns-ai-core/langchainrb#assistants), and [Creating custom Tools](https://github.com/patterns-ai-core/langchainrb#creating-custom-tools). Model names were updated, long strings were shortened, and options that do not change the example were removed.

## The Shape of the Move

langchainrb follows the LangChain pattern: an LLM client object per provider, an `Assistant` that holds the conversation and tools, tool classes that declare functions with `define_function`, and a client per vector database.

RubyLLM keeps fewer objects. `RubyLLM.chat` talks to every provider. An agent is a class that declares its model, instructions, and tools. A tool is a class with an `execute` method. Retrieval lives in your own database, and RubyLLM supplies the embeddings and the model.

## Install

```ruby
# Gemfile
gem "ruby_llm"
```

```ruby
RubyLLM.configure do |config|
  config.openai_api_key = ENV.fetch("OPENAI_API_KEY")
  config.anthropic_api_key = ENV.fetch("ANTHROPIC_API_KEY")
end
```

Both gems can stay in the bundle while you migrate. See [Configuration]({% link _getting_started/configuration.md %}).

## Chat

Before:

```ruby
llm = Langchain::LLM::OpenAI.new(
  api_key: ENV["OPENAI_API_KEY"],
  default_options: { chat_model: "{{ site.models.openai_latest }}" }
)

messages = [
  { role: "system", content: "You are a helpful assistant." },
  { role: "user", content: "What's the weather like today?" }
]
response = llm.chat(messages: messages)
chat_completion = response.chat_completion
```

After:

```ruby
chat = RubyLLM.chat model: "{{ site.models.openai_latest }}"
chat.with_instructions "You are a helpful assistant."

response = chat.ask "What's the weather like today?"
response.content
```

The chat keeps the transcript, so the next `chat.ask` continues the conversation. To switch providers, langchainrb swaps the client class, such as `Langchain::LLM::Anthropic`. In RubyLLM you change the model name:

```ruby
chat = RubyLLM.chat model: "{{ site.models.anthropic_latest }}"
```

Embeddings move the same way. `llm.embed(text: "Hello, world!").embedding` becomes:

```ruby
RubyLLM.embed("Hello, world!").vector
```

## Retrieval Q&A

langchainrb wraps vector databases. You create a client for Weaviate, Pinecone, Qdrant, pgvector, or another store, add texts, and call `ask`:

```ruby
llm = Langchain::LLM::OpenAI.new(api_key: ENV["OPENAI_API_KEY"])

client = Langchain::Vectorsearch::Weaviate.new(
    url: ENV["WEAVIATE_URL"],
    api_key: ENV["WEAVIATE_API_KEY"],
    index_name: "Documents",
    llm: llm
)

client.create_default_schema

client.add_texts(
  texts: [
    "Begin by preheating your oven to 375°F (190°C)...",
    "In a bowl, combine the spinach mixture with 4 ounces of softened cream cheese..."
  ]
)

client.ask(question: "How long do I sear the chicken?")
```

RubyLLM does not wrap vector databases. In a Rails app, the vectors live next to the records they describe. With pgvector and the [neighbor](https://github.com/ankane/neighbor) gem, a model embeds itself when its content changes:

```ruby
class Document < ApplicationRecord
  has_neighbors :embedding
  before_save :embed, if: :content_changed?

  private

  def embed
    self.embedding = RubyLLM.embed(content).vector
  end
end

Document.create! content: "Begin by preheating your oven to 375°F (190°C)..."
Document.create! content: "In a bowl, combine the spinach mixture with 4 ounces of softened cream cheese..."
```

Then give the model a search tool and an agent that uses it:

```ruby
class SearchRecipes < RubyLLM::Tool
  description "Searches the recipe collection"

  def execute(query:)
    Document.nearest_neighbors(:embedding, RubyLLM.embed(query).vector, distance: "cosine")
            .first(4)
            .map(&:content)
  end
end

class RecipeAssistant < RubyLLM::Agent
  instructions "Answer from the recipe collection. Search it before you answer."
  tools SearchRecipes
end

RecipeAssistant.new.ask "How long do I sear the chicken?"
```

`client.ask` retrieves once and answers. The agent decides what to search for, can search again when the first results fall short, and answers in the same conversation as everything else. The [RAG guide]({% link _advanced/rag.md %}) covers the migration, indexes, reranking, and citations.

## An Assistant with Tools

langchainrb defines several functions in one tool class with `define_function`, then hands an instance to `Langchain::Assistant`:

```ruby
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

In RubyLLM, each function is a tool class, and the assistant is an agent class:

```ruby
class SearchMovie < RubyLLM::Tool
  description "Search for a movie by title"
  parameter :query, description: "The movie title to search for"

  def execute(query:) = Tmdb.search(query)
end

class MovieDetails < RubyLLM::Tool
  description "Get detailed information about a specific movie"
  parameter :movie_id, type: :integer, description: "The TMDb ID of the movie"

  def execute(movie_id:) = Tmdb.movie(movie_id)
end

class MovieAssistant < RubyLLM::Agent
  instructions "You're a helpful AI assistant that can provide movie information"
  tools SearchMovie, MovieDetails
end

MovieAssistant.new.ask "Can you tell me about the movie 'Inception'?"
```

`Tmdb` stands for your own API client, as `tool_response(...)` does in the langchainrb example. Whatever `execute` returns goes back to the model, so there is no `tool_response` wrapper. Tools run automatically; to pause a call for a person's approval, declare the tool with `requires_approval`. See [Tools]({% link _getting_started/tools.md %}).

langchainrb streams through a block given to `Assistant.new`. In RubyLLM, give the block to `ask`:

```ruby
MovieAssistant.new.ask "Can you tell me about the movie 'Inception'?" do |chunk|
  print chunk.content
end
```

## Concept Map

| langchainrb | RubyLLM |
| --- | --- |
| `Langchain::LLM::OpenAI.new(...)` | `RubyLLM.chat model: "..."` |
| `llm.chat(messages:).chat_completion` | `chat.ask(...).content` |
| `llm.embed(text:).embedding` | `RubyLLM.embed(text).vector` |
| `Langchain::Assistant` | [`RubyLLM::Agent`]({% link _getting_started/agents.md %}), or a chat with `with_tools` |
| `extend Langchain::ToolDefinition` and `define_function` | [`RubyLLM::Tool`]({% link _getting_started/tools.md %}), one class per function |
| `tool_response(...)` | the return value of `execute` |
| `assistant.messages` | `chat.messages` |
| `Langchain::Prompt::PromptTemplate` | ERB templates in `app/prompts` ([Prompt Rendering]({% link _core_features/prompt-rendering.md %})) |
| `Langchain::OutputParsers::StructuredOutputParser` | `with_schema` and `response.parsed` ([Structured Output]({% link _core_features/structured-output.md %})) |
| `Langchain::Vectorsearch::*` | your database, with `RubyLLM.embed` ([RAG]({% link _advanced/rag.md %})) |
| `Langchain::Evals::Ragas` | [Evaluations]({% link _advanced/evaluations.md %}) |

## What You Gain

* **Persistence.** In Rails, `acts_as_chat` stores the conversation, tool calls, and usage as your records. An assistant's thread in langchainrb lives in memory. See [Rails Integration]({% link _getting_started/rails.md %}).
* **Cost.** Every response and chat reports `cost.total` in dollars. See [Cost and Usage Tracking]({% link _core_features/cost-and-usage-tracking.md %}).
* **More operations.** Images, speech, transcription, OCR, moderation, and reranking use the same configuration. See the [Overview]({% link _getting_started/overview.md %}).

## When langchainrb Still Fits

* **You depend on a hosted vector database.** langchainrb has clients for Weaviate, Pinecone, Qdrant, Milvus, Chroma, and Elasticsearch. RubyLLM leaves storage to your application and its gems.
* **You use its document loaders.** `add_data(paths:)` parses PDF, DOCX, HTML, CSV, XLSX, and other formats before indexing. RubyLLM can attach files to a chat and run [OCR]({% link _getting_started/ocr.md %}), but it does not chunk and index documents for you.

## Next Steps

* [Agents]({% link _getting_started/agents.md %}) - Define agents as classes and use them anywhere.
* [Retrieval-Augmented Generation]({% link _advanced/rag.md %}) - Store embeddings and search them from an agent.
* [Rails Integration]({% link _getting_started/rails.md %}) - Persist chats as Active Record models.
