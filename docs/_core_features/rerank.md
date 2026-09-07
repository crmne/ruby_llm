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
* How to track reranking usage.

## Reranking Documents

`RubyLLM.rerank` takes a query and an array of documents, and returns them ordered by how well each one answers the query:

```ruby
rerank = RubyLLM.rerank(
  "What is the capital of the United States?",
  ["Carson City is the capital city of the American state of Nevada.",
   "Washington, D.C. is the capital of the United States."],
  model: "{{ site.models.rerank_cohere }}"
)

rerank.results.first.document # => "Washington, D.C. is the capital of the United States."
rerank.results.first.score    # => 0.99
```

`rerank` requires `model:`; it has no default model.
{: .note }

## Why Rerank

Use embeddings to retrieve a manageable set of candidates. Then let a reranker score each document against the query. This can improve the ordering before you show results or pass them to a chat model.

## Reading the Results

Each entry in `results` is a `RubyLLM::Rerank::Result` with three readers:

```ruby
rerank = RubyLLM.rerank("ruby", documents, model: "{{ site.models.rerank_cohere }}")

result = rerank.results.first
result.index    # => 2
result.document # => "Rails is a Ruby framework"
result.score    # => 0.87
```

`index` is the document's position in the array you passed in, which is what you use to map a result back to the record it came from:

```ruby
articles = Article.where(id: candidate_ids).to_a
rerank   = RubyLLM.rerank(query, articles.map(&:body), model: "{{ site.models.rerank_cohere }}")

best = rerank.results.first(5).map { |result| articles[result.index] }
```

Scores are provider-specific. Use them to order results and to set a cutoff you tune against your own data, not as a probability you compare across models.
{: .warning }

## Limiting Results

Pass `top_n:` to have the provider return only the best few, rather than reordering everything you sent:

```ruby
rerank = RubyLLM.rerank(query, documents, model: "{{ site.models.rerank_cohere }}", top_n: 5)
rerank.results.length # => 5
```

You still send every candidate, because the reranker has to score them all to pick the best. `top_n:` shrinks the response, not the work.

## Choosing a Model

Pass `provider:` to select a hosted deployment explicitly:

```ruby
RubyLLM.rerank(query, documents, model: "{{ site.models.rerank_cohere }}")
RubyLLM.rerank(query, documents, model: "{{ site.models.rerank_bedrock }}", provider: :bedrock)
RubyLLM.rerank(query, documents, model: "{{ site.models.azure_rerank }}", provider: :azure)
```

Azure requires a [deployed reranker]({% link _getting_started/configuration-providers.md %}#azure-deployments). Bedrock reranking uses your AWS credentials without a knowledge base.

### Vertex AI Search

Enable the Discovery Engine API in your project and use your [Vertex AI ranking configuration]({% link _getting_started/configuration-providers.md %}#reranking):

```ruby
RubyLLM.rerank(
  query, documents,
  model: "{{ site.models.rerank_vertexai }}",
  provider: :vertexai,
  assume_model_exists: true,
  top_n: 3
)
```

The semantic ranker is absent from the general model catalog, so it requires `assume_model_exists: true`. It does not require a search data store.

## Cost and Usage

Reranking lands in the same usage ledger as chat and embeddings. Providers that bill per token report the tokens they read:

```ruby
rerank = RubyLLM.rerank(query, documents, model: "voyageai/rerank-2.5-lite", provider: :openrouter)

rerank.tokens.input # => 812
rerank.cost.total   # => 0.0016
```

Token counts and cost remain `nil` when a provider reports neither token usage nor a charge. Cohere, for example, bills reranking per search unit.

See [Tokens and Costs]({% link _core_features/cost-and-usage-tracking.md %}) for usage accounting.

## Retrieval End to End

Reranking is the second stage of a pipeline whose first stage is embeddings. Retrieve broadly by vector similarity, then order precisely:

```ruby
# app/models/article.rb
class Article < ApplicationRecord
  def self.search(query, limit: 5)
    query_vector = RubyLLM.embed(query).vectors
    candidates   = nearest_neighbors(:embedding, query_vector, distance: :cosine).limit(50).to_a

    rerank = RubyLLM.rerank(query, candidates.map(&:body), model: "{{ site.models.rerank_cohere }}", top_n: limit)
    rerank.results.map { |result| candidates[result.index] }
  end
end
```

The vector query retrieves fifty candidates; the reranker selects five. This example uses the `neighbor` gem with a configured `embedding` vector column.

See the [RAG guide]({% link _advanced/rag.md %}) for the retrieval-augmented generation pipeline this feeds.

## Next Steps

* [Embeddings]({% link _core_features/embeddings.md %}) - generate the vectors that produce your candidates.
* [RAG]({% link _advanced/rag.md %}) - build retrieval-augmented generation on top of this pipeline.
* [Tokens and Costs]({% link _core_features/cost-and-usage-tracking.md %}) - track what retrieval costs across every call.
