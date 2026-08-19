---
layout: default
title: Reranking
nav_order: 4
description: Order candidate documents by how well they answer a query, the second stage of a retrieval pipeline
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* How to order documents by relevance to a query with `RubyLLM.rerank`.
* How to read the ranked results and their scores.
* How to limit how many results come back.
* How to combine reranking with embeddings in a retrieval pipeline.
* What reranking costs and how to handle providers that do not offer it.

## Reranking Documents

`RubyLLM.rerank` takes a query and an array of documents, and returns them ordered by how well each one answers the query:

```ruby
rerank = RubyLLM.rerank(
  "What is the capital of the United States?",
  ["Carson City is the capital city of the American state of Nevada.",
   "Washington, D.C. is the capital of the United States."],
  model: "rerank-v3.5"
)

rerank.results.first.document # => "Washington, D.C. is the capital of the United States."
rerank.results.first.score    # => 0.99
```

The documents go in as an array of strings and come back reordered, most relevant first.

Unlike `chat` and `embed`, `rerank` has no default model. Rerank catalogs are provider-specific and share no common names, so `model:` is required.
{: .note }

## Why Rerank

Embedding similarity is fast and cheap, which is what makes it a good way to narrow thousands of documents down to a few dozen candidates. It is also shallow: it compares a query vector to a document vector, and never looks at the two together.

A reranker does look at them together. It reads the query and each document as a pair and scores how well that document answers that query, which catches relevance that vector distance misses. It is far too slow to run over your whole corpus, and far more accurate over a short list. That is the division of labor: embeddings retrieve, reranking orders.

## Reading the Results

Each entry in `results` is a `RubyLLM::Rerank::Result` with three readers:

```ruby
rerank = RubyLLM.rerank("ruby", documents, model: "rerank-v3.5")

result = rerank.results.first
result.index    # => 2
result.document # => "Rails is a Ruby framework"
result.score    # => 0.87
```

`index` is the document's position in the array you passed in, which is what you use to map a result back to the record it came from:

```ruby
articles = Article.where(id: candidate_ids).to_a
rerank   = RubyLLM.rerank(query, articles.map(&:body), model: "rerank-v3.5")

best = rerank.results.first(5).map { |result| articles[result.index] }
```

Scores are provider-specific. Use them to order results and to set a cutoff you tune against your own data, not as a probability you compare across models.
{: .warning }

## Limiting Results

Pass `top_n:` to have the provider return only the best few, rather than reordering everything you sent:

```ruby
rerank = RubyLLM.rerank(query, documents, model: "rerank-v3.5", top_n: 5)
rerank.results.length # => 5
```

You still send every candidate, because the reranker has to score them all to pick the best. `top_n:` shrinks the response, not the work.

## Choosing a Model

Several providers offer rerankers, and RubyLLM resolves the provider from the model id the same way it does everywhere else:

```ruby
RubyLLM.rerank(query, documents, model: "rerank-v3.5")                              # Cohere
RubyLLM.rerank(query, documents, model: "cohere.rerank-v3-5:0", provider: :bedrock) # Bedrock
RubyLLM.rerank(query, documents, model: "Cohere-rerank-v4.0-pro", provider: :azure) # Azure
```

Self-hosted rerankers work through GPUStack, and OpenRouter serves several vendors' rerankers behind one endpoint. Pass `provider:` when the same model id is available from more than one of them.

## Cost and Usage

Reranking bills for the tokens it reads, and lands in the same usage ledger as chat and embeddings:

```ruby
rerank = RubyLLM.rerank(query, documents, model: "rerank-v3.5")

rerank.tokens.input # => 812
rerank.cost.total   # => 0.0016
```

Providers that report what they charged put it on `rerank.tokens.reported_cost`, and RubyLLM prefers that figure over its own calculation. See [Tokens and Costs]({% link _core_features/cost-and-usage-tracking.md %}).

## Retrieval End to End

Reranking is the second stage of a pipeline whose first stage is embeddings. Retrieve broadly by vector similarity, then order precisely:

```ruby
# app/models/article.rb
class Article < ApplicationRecord
  def self.search(query, limit: 5)
    query_vector = RubyLLM.embed(query).vectors
    candidates   = nearest_neighbors(:embedding, query_vector, distance: :cosine).limit(50).to_a

    rerank = RubyLLM.rerank(query, candidates.map(&:body), model: "rerank-v3.5", top_n: limit)
    rerank.results.map { |result| candidates[result.index] }
  end
end
```

Fifty candidates by vector similarity, five by relevance. The reranker never sees the rest of the table, and the user never sees the forty-five that did not survive.

See the [RAG guide]({% link _advanced/rag.md %}) for the retrieval-augmented generation pipeline this feeds.

## When a Provider Has No Reranker

Most chat providers do not offer reranking. Asking one to rerank raises immediately rather than falling back to something approximate:

```ruby
RubyLLM.rerank("query", ["doc"], model: "claude-haiku-4-5", provider: :anthropic)
# => RubyLLM::Error: Anthropic doesn't support reranking
```

A guessed ordering is worse than no ordering, so RubyLLM does not simulate a reranker with a chat model.

## Next Steps

* [Embeddings]({% link _core_features/embeddings.md %}) - generate the vectors that produce your candidates.
* [RAG]({% link _advanced/rag.md %}) - build retrieval-augmented generation on top of this pipeline.
* [Tokens and Costs]({% link _core_features/cost-and-usage-tracking.md %}) - track what retrieval costs across every call.
