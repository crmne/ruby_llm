---
layout: default
title: LlamaIndex
seo:
  title: RubyLLM and LlamaIndex
nav_order: 6
description: Compare RubyLLM with LlamaIndex in Python on querying documents, stored vectors, reranking, OCR, citations, agents, workflows, and cost, with code from both projects.
permalink: /compare/llamaindex/
---

# RubyLLM and LlamaIndex

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* How LlamaIndex's index and query engine map onto RubyLLM's file stores, embeddings, and your own records.
* How reranking, OCR, and citations compare.
* How the same retrieval agent looks in each framework.
* How each one keeps a conversation and pauses for approval.
* How LlamaIndex Workflows compare with plain Ruby.
* What each one reports about usage and cost.
* When to choose LlamaIndex and when to choose RubyLLM.

> **Last checked** on 6 November 2026 against RubyLLM 2.2 and the Python packages `llama-index` 0.14.25, `llama-index-core` 0.14.25, `llama-index-vector-stores-postgres` 0.9.0, `llama-index-postprocessor-cohere-rerank` 0.10.0, `llama-index-llms-openai` 0.8.3, and `llama-cloud` 2.19.0. The model below needs that `llama-index-llms-openai`: `llama-index` 0.14.25 pins an older one, 0.7.10, which rejects its name. The Python code comes from LlamaIndex's documentation: [Starter Tutorial](https://developers.llamaindex.ai/python/framework/getting_started/starter_example/), [Postgres Vector Store](https://developers.llamaindex.ai/python/framework/integrations/vector_stores/postgres/), [Node Postprocessor](https://developers.llamaindex.ai/python/framework/module_guides/querying/node_postprocessors/), [Cohere Rerank](https://developers.llamaindex.ai/python/examples/node_postprocessor/coherererank/), [Parse Getting Started](https://developers.llamaindex.ai/llamaparse/parse/getting_started/), [CitationQueryEngine](https://developers.llamaindex.ai/python/examples/query_engine/citation_query_engine/), [Maintaining state](https://developers.llamaindex.ai/python/framework/understanding/agent/state/), [Human in the loop](https://developers.llamaindex.ai/python/framework/understanding/agent/human_in_the_loop/), [Workflows](https://developers.llamaindex.ai/python/llamaagents/workflows/), and [Token Counting Handler](https://developers.llamaindex.ai/python/examples/observability/tokencountinghandler/). Model names are updated to current ones, comments are removed, and notebook cells are joined into one example.

## Two Frameworks

[LlamaIndex](https://developers.llamaindex.ai/llms.txt) is a company and an open-source Python framework for RAG and agents, and this page compares that framework. The company's hosted product, LlamaParse, parses documents for it. RubyLLM is the Ruby AI framework. Both give you embeddings, reranking, agents with tools, structured output, and streaming.

They start from different places. A LlamaIndex application starts from an index: readers load your data, the index splits and embeds it, and a query engine answers from it. A RubyLLM application starts from your own records: you call `embed` and `rerank` as operations and keep the vectors on your models.

LlamaIndex's data layer is wider than anything RubyLLM ships. It has [hundreds of data connectors](https://developers.llamaindex.ai/python/framework/understanding/rag/loading/), text splitters and an [ingestion pipeline](https://developers.llamaindex.ai/python/framework/module_guides/loading/ingestion_pipeline/) with caching, [over 20 vector stores](https://developers.llamaindex.ai/python/framework/module_guides/storing/vector_stores/), and [several index types](https://developers.llamaindex.ai/python/framework/module_guides/indexing/index_guide/). RubyLLM has no document loaders, text splitters, index classes, or vector store integrations. It works with your own records instead.

## A Question Over a Folder

LlamaIndex's starter reads a folder, builds an index, and answers from it:

```python
from llama_index.core import VectorStoreIndex, SimpleDirectoryReader

documents = SimpleDirectoryReader("data").load_data()
index = VectorStoreIndex.from_documents(documents)
query_engine = index.as_query_engine()
response = query_engine.query("What did the author do growing up?")
print(response)
```

This is the shortest path to vector search in either framework, and RubyLLM has no one-call equivalent. It splits the files, embeds every chunk before the first question, and finds passages by meaning.

RubyLLM's nearest tool is a [file store]({% link _core_features/file-stores.md %}), which skips the index. The model searches the folder and reads what it finds:

```ruby
chat = RubyLLM.chat(model: "{{ site.models.anthropic_latest }}").with_file_store "data", tools: :read
response = chat.ask "What did the author do growing up?"
puts response.content
```

Nothing is embedded, so a new file is searchable as soon as it lands in the folder. The trade is that `search_files` matches regular expressions, not meaning, so it finds the words the model thinks to try. It suits a folder of documents the model can look through. For a large collection, or questions phrased differently from the text, use vectors, as in the next section. Word, Excel, and PowerPoint files read out of the box. PDFs and scans need a [converter]({% link _core_features/file-stores.md %}#pdfs-scans-and-photos).

## Vectors in Your Database

LlamaIndex [keeps its vectors in memory by default](https://developers.llamaindex.ai/python/framework/module_guides/storing/vector_stores/), and a vector store integration moves them to a database. Its Postgres guide gives the store its connection and a table name:

```python
from llama_index.core import SimpleDirectoryReader, StorageContext, VectorStoreIndex
from llama_index.vector_stores.postgres import PGVectorStore
from sqlalchemy import make_url

documents = SimpleDirectoryReader("./data/paul_graham").load_data()

connection_string = "postgresql://postgres:password@localhost:5432"
db_name = "vector_db"
url = make_url(connection_string)
vector_store = PGVectorStore.from_params(
    database=db_name,
    host=url.host,
    password=url.password,
    port=url.port,
    user=url.username,
    table_name="paul_graham_essay",
    embed_dim=1536,
    hnsw_kwargs={
        "hnsw_m": 16,
        "hnsw_ef_construction": 64,
        "hnsw_ef_search": 40,
        "hnsw_dist_method": "vector_cosine_ops",
    },
)

storage_context = StorageContext.from_defaults(vector_store=vector_store)
index = VectorStoreIndex.from_documents(
    documents, storage_context=storage_context, show_progress=True
)
query_engine = index.as_query_engine()
```

When a document changes, you tell the index with [`update_ref_doc` or `refresh_ref_docs`](https://developers.llamaindex.ai/python/framework/module_guides/indexing/document_management/).

In RubyLLM, the vector is a column on your own model. The [`neighbor`](https://github.com/ankane/neighbor) gem and pgvector handle storage and search, your `database.yml` already has the connection, and a callback keeps the vector current:

```ruby
class Article < ApplicationRecord
  has_neighbors :embedding

  before_save :embed, if: :body_changed?

  def self.search(query, limit: 3)
    nearest_neighbors(:embedding, RubyLLM.embed(query).vector, distance: :cosine).limit limit
  end

  private

  def embed
    self.embedding = RubyLLM.embed(body).vector
  end
end

Article.create! title: "Returns", body: "Return any jacket within 30 days."
Article.search("How do I return a jacket?").map(&:title)
```

A search result is an `Article`, so you can link to it, authorize it, and scope it with `where`. Nothing here splits a long article, though: LlamaIndex chunks documents for you, and in RubyLLM you split them yourself before embedding. LlamaIndex's Postgres store also has [hybrid search and metadata filters](https://developers.llamaindex.ai/python/framework/integrations/vector_stores/postgres/) as options, while here they are queries you write. See [RAG]({% link _advanced/rag.md %}) for the migration and [Embeddings]({% link _getting_started/embeddings.md %}) for models and dimensions.

## Reranking

Inside a query engine, LlamaIndex takes a reranker as one keyword, from its own package, `llama-index-postprocessor-cohere-rerank`:

```python
import os
from llama_index.postprocessor.cohere_rerank import CohereRerank

api_key = os.environ["COHERE_API_KEY"]
cohere_rerank = CohereRerank(api_key=api_key, top_n=2)

query_engine = index.as_query_engine(
    similarity_top_k=10,
    node_postprocessors=[cohere_rerank],
)
response = query_engine.query(
    "What did Sam Altman do in this essay?",
)
```

Outside one, a postprocessor takes wrapped nodes and returns wrapped nodes:

```python
from llama_index.postprocessor.cohere_rerank import CohereRerank
from llama_index.core.data_structs import Node
from llama_index.core.schema import NodeWithScore

nodes = [
    NodeWithScore(node=Node(text="text1"), score=0.7),
    NodeWithScore(node=Node(text="text2"), score=0.8),
]

reranker = CohereRerank(
    api_key="<COHERE_API_KEY>", model="{{ site.models.rerank_cohere }}", top_n=2
)
reranker.postprocess_nodes(nodes, query_str="<user_query>")
```

In RubyLLM, reranking is an operation over strings, and each result's `index` maps back to your records:

```ruby
query = "How do I return a jacket?"
articles = Article.search(query, limit: 10).to_a

rerank = RubyLLM.rerank query, articles.map(&:body), model: "{{ site.models.rerank_cohere }}", top_n: 2
rerank.results.map { |result| articles[result.index] }
```

It uses the same configuration as every other call, with no extra package. LlamaIndex offers more kinds of reranker, including [local cross-encoders and LLM-based ones](https://developers.llamaindex.ai/python/framework/module_guides/querying/node_postprocessors/node_postprocessors/). See [Reranking]({% link _getting_started/rerank.md %}).

## Reading Scans

`SimpleDirectoryReader` [reads PDFs and images](https://developers.llamaindex.ai/python/framework/understanding/rag/loading/) as it loads a folder. For parsing as a service, the same company offers LlamaParse, with its own SDK and API key:

```python
from llama_cloud import LlamaCloud

client = LlamaCloud()

file = client.files.create(file="./attention_is_all_you_need.pdf", purpose="parse")
result = client.parsing.parse(
    file_id=file.id,
    tier="agentic",
    version="latest",
    expand=["markdown"],
)

print(result.markdown.pages[0].markdown)
```

RubyLLM reads a file through an OCR model, with the provider keys you already configure:

```ruby
ocr = RubyLLM.ocr "attention_is_all_you_need.pdf"
puts ocr.pages.first.markdown
```

`RubyLLM.ocr` calls [Mistral or Cohere]({% link _getting_started/ocr.md %}), so it is hosted too, and each page carries its Markdown, tables, and images. LlamaParse is a larger product, with [extraction, classification, splitting, and indexing](https://developers.llamaindex.ai/llms.txt) behind one API, and the same company publishes LiteParse, an open-source local parser.

## An Agent That Searches

LlamaIndex's starter wraps a query engine in an async function and gives it to a `FunctionAgent`. Here it is without the starter's calculator tool:

```python
from llama_index.core import VectorStoreIndex, SimpleDirectoryReader
from llama_index.core.agent.workflow import FunctionAgent
from llama_index.llms.openai import OpenAI
import asyncio

documents = SimpleDirectoryReader("data").load_data()
index = VectorStoreIndex.from_documents(documents)
query_engine = index.as_query_engine()


async def search_documents(query: str) -> str:
    """Useful for answering natural language questions about an personal essay written by Paul Graham."""
    response = await query_engine.aquery(query)
    return str(response)


agent = FunctionAgent(
    tools=[search_documents],
    llm=OpenAI(model="{{ site.models.openai_latest }}"),
    system_prompt="""You are a helpful assistant that can search through documents to answer questions.""",
)


async def main():
    response = await agent.run("What did the author do in college?")
    print(response)


if __name__ == "__main__":
    asyncio.run(main())
```

The tool returns the query engine's written answer, and a [`VectorStoreIndex` query takes one LLM call](https://developers.llamaindex.ai/python/framework/understanding/evaluating/cost_analysis/) of its own by default.

In RubyLLM, the tool returns the passages and the agent's model reads them. `SearchDocs` and `SupportAgent` are the classes from [Tools]({% link _getting_started/tools.md %}) and [Agents]({% link _getting_started/agents.md %}), searching the `Article` model above:

```ruby
class SearchDocs < RubyLLM::Tool
  description "Searches the help center for articles that answer a customer's question"
  parameter :query, description: "What the customer wants to know"

  def execute(query:)
    results = Article.search(query).map do |article|
      { title: article.title, source_id: article.to_global_id.to_s, text: article.body }
    end
    return "No articles found" if results.empty?

    RubyLLM::SearchResults.new(*results)
  end
end

class SupportAgent < RubyLLM::Agent
  model "{{ site.models.anthropic_latest }}"
  instructions "Search the help center before answering. Cite your sources."
  tools SearchDocs
end

response = SupportAgent.new.ask "How do I return a jacket?"
puts response.content
```

There is no event loop to set up, so this runs as written in a controller, a job, or a console. For concurrency, RubyLLM runs in fibers. See [Scale with Async]({% link _advanced/async.md %}).

### Citations

LlamaIndex's `CitationQueryEngine` works with any existing index. It numbers the sources in the answer's text, and `source_nodes` holds them:

```python
from llama_index.core.query_engine import CitationQueryEngine

query_engine = CitationQueryEngine.from_args(
    index,
    similarity_top_k=3,
    citation_chunk_size=512,
)

response = query_engine.query("What did the author do growing up?")

print(response)
print(response.source_nodes[0].node.get_text())
```

The `SearchResults` that `SearchDocs` returns give the model citable passages, and you read each citation as an object that points back at your record:

```ruby
response.citations.each do |citation|
  citation.cited_text
  citation.text
  GlobalID::Locator.locate citation.source_id, only: Article
end
```

`cited_text` is the passage, `text` is the span of the answer it supports, and `source_id` is the record's Global ID. These citable passages reach Cohere and Claude. Other providers receive the results as JSON text, so the model can still use them, but you get no citation objects. LlamaIndex's numbered citations come from [its own prompt](https://github.com/run-llama/llama_index/blob/main/llama-index-core/llama_index/core/query_engine/citation_query_engine.py), which asks the model to number its sources. See [Citations]({% link _core_features/citations.md %}).

## Conversations and Approvals

An `AgentWorkflow` is [stateless between runs](https://developers.llamaindex.ai/python/framework/understanding/agent/state/). It remembers through a `Context`, which you serialize and store yourself when a conversation outlives the process:

```python
from llama_index.core.workflow import Context, JsonSerializer

ctx = Context(workflow)
response = await workflow.run(user_msg="Hi, my name is Laurie!", ctx=ctx)

ctx_dict = ctx.to_dict(serializer=JsonSerializer())

restored_ctx = Context.from_dict(
    workflow, ctx_dict, serializer=JsonSerializer()
)
response3 = await workflow.run(user_msg="What's my name?", ctx=restored_ctx)
```

For chat history alone, its [`Memory`](https://developers.llamaindex.ai/python/framework/module_guides/deploying/agents/memory/) class can also write to a SQL database you point it at.

A human approval is a tool that emits one event and waits for another, with the caller listening on the stream:

```python
from llama_index.core.workflow import (
    Context,
    InputRequiredEvent,
    HumanResponseEvent,
)


async def dangerous_task(ctx: Context) -> str:
    """A dangerous task that requires human confirmation."""
    question = "Are you sure you want to proceed? "
    response = await ctx.wait_for_event(
        HumanResponseEvent,
        waiter_id=question,
        waiter_event=InputRequiredEvent(
            prefix=question,
            user_name="Laurie",
        ),
        requirements={"user_name": "Laurie"},
    )

    if response.response.strip().lower() == "yes":
        return "Dangerous task completed successfully."
    else:
        return "Dangerous task aborted."


handler = workflow.run(user_msg="I want to proceed with the dangerous task.")

async for event in handler.stream_events():
    if isinstance(event, InputRequiredEvent):
        response = input(event.prefix)
        handler.ctx.send_event(
            HumanResponseEvent(
                response=response,
                user_name=event.user_name,
            )
        )

response = await handler
print(str(response))
```

The guide adds that a slow answer, or one from another process, means serializing the context and resuming later. The same mechanism can ask any question, not only yes or no.

In Rails, a RubyLLM conversation is your `Chat` and `Message` rows, so another process loads it by ID. `ApplicationAgent` is the base class the install generator writes, with `chat_class Chat`. The tool declares that it needs approval:

```ruby
class IssueRefund < RubyLLM::Tool
  description "Issues a refund for an order"
  requires_approval

  def execute(order_id:) = "Refunded order #{order_id}"
end

class RefundAgent < ApplicationAgent
  model "{{ site.models.anthropic_latest }}"
  tools IssueRefund
end

chat = RefundAgent.create!
chat.ask "Refund order 42"
chat.awaiting_approval? # => true
```

The decision is stored on the tool call's row, so a later request can record it and continue:

```ruby
chat = RefundAgent.find params[:id]
chat.approve params[:tool_call_id]
chat.complete
```

Nothing is serialized by hand, and the pending call survives a deploy. An approval is a decision on a tool call, `approve` or `deny`. You still scope the lookup and authorize the reviewer in your controller, as you would for any other action. See [Controlling Tool Execution]({% link _tools/tool-execution.md %}) and [Agents in Background Jobs]({% link _advanced/durable-agents.md %}).

## Workflows

LlamaIndex Workflows are its [event-driven orchestration layer](https://developers.llamaindex.ai/python/llamaagents/workflows/). A step receives an event and returns another, and the type annotations connect the steps:

```python
from workflows import Workflow, step
from workflows.events import (
    Event,
    StartEvent,
    StopEvent,
)
from llama_index.llms.openai import OpenAI


class JokeEvent(Event):
    joke: str


class JokeFlow(Workflow):
    llm = OpenAI(model="{{ site.models.openai_latest }}")

    @step
    async def generate_joke(self, ev: StartEvent) -> JokeEvent:
        topic = ev.topic

        prompt = f"Write your best joke about {topic}."
        response = await self.llm.acomplete(prompt)
        return JokeEvent(joke=str(response))

    @step
    async def critique_joke(self, ev: JokeEvent) -> StopEvent:
        joke = ev.joke

        prompt = f"Give a thorough analysis and critique of the following joke: {joke}"
        response = await self.llm.acomplete(prompt)
        return StopEvent(result=str(response))


w = JokeFlow(timeout=60, verbose=False)
result = await w.run(topic="pirates")
print(str(result))
```

RubyLLM has no workflow engine. A workflow is a method:

```ruby
class JokeFlow
  def run(topic:)
    joke = ask "Write your best joke about #{topic}."
    ask "Give a thorough analysis and critique of the following joke: #{joke}"
  end

  private

  def ask(prompt) = RubyLLM.chat(model: "{{ site.models.openai_latest }}").ask(prompt).content
end

puts JokeFlow.new.run topic: "pirates"
```

Branches are `if`, loops are `loop`, and concurrent steps are `Async` blocks. What you give up is what an engine provides: LlamaIndex checks that the events connect before it runs, applies the `timeout`, and exposes each step's events to stream. Long-running work in RubyLLM goes through Active Job instead. See [Agentic Workflows]({% link _advanced/agentic-workflows.md %}).

## Usage and Cost

LlamaIndex counts tokens with a callback handler you register in its global settings. The guide passes a `tiktoken` tokenizer as well, and the counts accumulate until you reset them:

```python
from llama_index.core.callbacks import CallbackManager, TokenCountingHandler
from llama_index.llms.openai import OpenAI
from llama_index.core import Settings

token_counter = TokenCountingHandler()

Settings.llm = OpenAI(model="{{ site.models.openai_latest }}", temperature=0.2)
Settings.callback_manager = CallbackManager([token_counter])

print(token_counter.total_embedding_token_count)
print(token_counter.prompt_llm_token_count)
print(token_counter.completion_llm_token_count)
print(token_counter.total_llm_token_count)

token_counter.reset_counts()
```

The handler reports tokens. It has no dollar amount, and the [Cost Analysis](https://developers.llamaindex.ai/python/framework/understanding/evaluating/cost_analysis/) guide works in tokens as well.

RubyLLM prices each result from its model registry. When usage or a price is unknown, the cost is `nil`, never a misleading zero:

```ruby
embedding = RubyLLM.embed "How do I return a jacket?", model: "{{ site.models.embedding_small }}"
embedding.tokens.input
embedding.cost.total

response = RubyLLM.chat(model: "{{ site.models.anthropic_latest }}").ask "How do I return a jacket?"
response.tokens.input
response.cost.total
```

In Rails, every billed attempt also lands in the `ruby_llm_usages` table, and `RubyLLM.with_owner` attributes each row to a user or account. See [Cost and Usage Tracking]({% link _core_features/cost-and-usage-tracking.md %}).

## Concept Map

| LlamaIndex | RubyLLM |
| --- | --- |
| `SimpleDirectoryReader` and data connectors | None. Your own code loads data, and a [file store]({% link _core_features/file-stores.md %}) reads a folder |
| `SentenceSplitter` and `IngestionPipeline` | None. Split text yourself, then call `RubyLLM.embed` |
| `VectorStoreIndex` | None. A vector column on your model, with `neighbor` and pgvector |
| `PropertyGraphIndex`, `TreeIndex`, and other index types | None |
| Vector store integrations | None. Whatever your application's database offers |
| `index.as_query_engine()` | An agent or chat with a [retrieval tool]({% link _advanced/rag.md %}) |
| `index.as_chat_engine()` | The same agent, since a chat keeps its transcript |
| `OpenAIEmbedding` and other embedding classes | [`RubyLLM.embed`]({% link _getting_started/embeddings.md %}) |
| `CohereRerank` and other postprocessors | [`RubyLLM.rerank`]({% link _getting_started/rerank.md %}) |
| LlamaParse | [`RubyLLM.ocr`]({% link _getting_started/ocr.md %}) |
| `CitationQueryEngine` and `source_nodes` | `RubyLLM::SearchResults` and `response.citations` |
| `FunctionAgent` | A [`RubyLLM::Agent`]({% link _getting_started/agents.md %}) class |
| A Python function as a tool | A [`RubyLLM::Tool`]({% link _getting_started/tools.md %}) class |
| `output_cls` | `schema` on an agent, or `with_schema` |
| `Context` and its serializers | The chat's transcript, or an `acts_as_chat` record |
| `InputRequiredEvent` and `HumanResponseEvent` | `requires_approval`, `approve`, and `deny` |
| `Workflow` and `@step` | Ruby methods, `Async`, and Active Job |
| `TokenCountingHandler` | `tokens` and `cost` on each result |

## When to Choose LlamaIndex

* **Your team works in Python.** Data science, notebooks, and machine learning code are already there.
* **Your data lives in many places.** Connectors for sources such as Notion, Google Docs, Slack, and SQL databases are packages you install, and RubyLLM has none.
* **Retrieval is the hard part of your application.** Chunking strategies, metadata extractors, ingestion caching, several index types, and many retrievers are there to tune. In RubyLLM, you would write them.
* **You want to swap vector stores.** The same index code runs over Pinecone, Qdrant, Weaviate, Postgres, and many more.
* **You want one vendor for document parsing.** LlamaParse and the framework come from the same company.
* **You want an event-driven workflow engine.** Workflows give you typed events, validation before a run, and an event stream.

## When to Choose RubyLLM

* **Your application is Ruby or Rails.** Vectors are columns on your models, chats are Active Record models, and agents run in Active Job.
* **Your data is already in your database.** You search your own records and get your own records back, with your scopes and your authorization.
* **Conversations must survive processes.** Transcripts and approval decisions are rows, so you serialize nothing and a deploy loses nothing.
* **You need to know what it costs.** Responses and operations report cost in dollars wherever the registry has a price, and Rails apps get a usage ledger.
* **You need more than retrieval.** Images, video, speech, transcription, and moderation come from the same gem with the same configuration.

## Next Steps

* [RAG]({% link _advanced/rag.md %}) - Store embeddings and search them with an agent.
* [File Stores]({% link _core_features/file-stores.md %}) - Give an agent files to find, read, and search.
* [Migrating to RubyLLM]({% link _compare/migrating-from.md %}) - Guides for other frameworks and clients.
