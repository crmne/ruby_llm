---
layout: default
title: Embeddings
nav_order: 3
description: Create vectors from text, images, audio, video, and documents for search and similarity
redirect_from:
  - /guides/embeddings
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

*   How to generate embeddings for single or multiple texts.
*   How to embed images, audio, video, and documents with multimodal models.
*   How to choose specific embedding models.
*   How to use the results, including calculating similarity.
*   How to integrate embeddings in a Rails application.

## Basic Embedding Generation

Turn text into a vector you can store or use for similarity search:

```ruby
embedding = RubyLLM.embed("Ruby is a programmer's best friend")

vector = embedding.vectors
# => [0.018, -0.027, ...]
```

## Embedding Multiple Texts

You can efficiently embed multiple texts in a single API call:

```ruby
texts = ["Ruby", "Python", "JavaScript"]
embeddings = RubyLLM.embed(texts)

embeddings.vectors.length # => 3
texts.zip(embeddings.vectors)
```

## Choosing Models

Pass `model:` to choose an embedding model:

```ruby
embedding = RubyLLM.embed("Ruby frameworks", model: "{{ site.models.embedding_large }}")
```

Set `default_embedding_model` in [Configuration]({% link _getting_started/configuration.md %}#default-models) to change the default. Use the [Models]({% link _reference/available-models.md %}) page to find embedding models, and pass `provider:` to select a hosted deployment explicitly.

## Choosing Dimensions

For models with configurable output dimensions, pass `dimensions:`:

```ruby
embedding = RubyLLM.embed(
  "This is a test sentence",
  model: "{{ site.models.embedding_small }}",
  dimensions: 512
)
```

Choose dimensions that match your database column. Smaller vectors use less storage; measure retrieval quality on your own data before changing an existing index.

## Task Types

Some models distinguish search queries from the documents they search. Pass `task_type:` with a value the model accepts:

```ruby
embedding = RubyLLM.embed(
  "RubyLLM makes provider APIs feel native to Ruby.",
  model: "{{ site.models.embedding_google_text }}",
  provider: :vertexai,
  task_type: "RETRIEVAL_DOCUMENT",
  title: "RubyLLM docs"
)
```

Gemini Embedding 001 accepts `RETRIEVAL_QUERY` and `RETRIEVAL_DOCUMENT`, with an optional document `title:`. Cohere uses `search_query` and `search_document` (the default). Gemini Embedding 2 takes task instructions in the text instead of `task_type:` or `title:`.

## Embedding Images and Other Media

Use `with:` to embed an attachment alongside text:

```ruby
embedding = RubyLLM.embed(
  "The Ruby logo",
  model: "{{ site.models.embedding_openrouter }}",
  provider: :openrouter,
  with: "logo.png",
  dimensions: 768
)

embedding.vectors # => [0.018, -0.027, ...]
```

You can embed video, audio, and PDFs with a model that accepts them:

```ruby
embedding = RubyLLM.embed(
  "A product demonstration",
  model: "{{ site.models.embedding_google }}",
  provider: :vertexai,
  with: "demo.mp4",
  dimensions: 768
)
```

Pass `nil` as the text to embed only the attachment. Combine attachments with one text at a time. Vertex AI's Gemini Embedding 2 accepts one input per request, including text-only requests.

Cohere Embed v3 accepts one image per request without text. RubyLLM selects the image input type when you pass `nil` and `with:`. Embed v4 can combine text and images. The same calls work on Cohere and Azure deployments; see [Azure configuration]({% link _getting_started/configuration-providers.md %}#azure-deployments).

## Provider Options

Use `provider_options:` for settings specific to one provider. For example, prevent Vertex AI from truncating long inputs:

```ruby
embedding = RubyLLM.embed(
  "RubyLLM makes provider APIs feel native to Ruby.",
  model: "{{ site.models.embedding_google_text }}",
  provider: :vertexai,
  provider_options: { parameters: { autoTruncate: false } }
)
```

## Using Embedding Results

### Vector Properties

The embedding result contains useful information:

```ruby
embedding = RubyLLM.embed("Example text")

puts embedding.vectors.class  # => Array
puts embedding.vectors.first.class  # => Float

puts embedding.vectors.length # => 1536

puts embedding.model  # => "{{ site.models.embedding_small }}"
```

### Sparse Vectors

Some models return a sparse vector beside the dense one, so you can run hybrid retrieval that combines semantic similarity with exact term matching. `sparse_vectors` holds it as a Hash mapping token id to weight, shaped like `vectors`: one Hash for a single text, an array of them for an array of texts.

```ruby
embedding = RubyLLM.embed("Ruby is a programmer's best friend", model: "bge-m3", provider: :gpustack, assume_model_exists: true)

embedding.sparse_vectors # => { 1037 => 0.25, 2003 => 0.5 }
```

`sparse_vectors` is `nil` when the model or server does not return sparse output.

## Measuring Similarity

A primary use case for embeddings is measuring the semantic similarity between texts. Cosine similarity is a common metric.

```ruby
require 'matrix' # Ruby's built-in Vector class requires 'matrix'

embedding = RubyLLM.embed(["I love Ruby programming", "Ruby is my favorite language"])
vector1, vector2 = embedding.vectors.map { |values| Vector.elements(values) }

# Calculate cosine similarity (value between -1 and 1, closer to 1 means more similar)
similarity = vector1.inner_product(vector2) / (vector1.norm * vector2.norm)
puts "Similarity: #{similarity.round(4)}" # => e.g., 0.9123
```

## Storing Embeddings

Store vectors for reuse, and use the same model and dimensions for documents and search queries. If you change either, regenerate the existing vectors. For large imports, see [Embedding Batches]({% link _advanced/batches.md %}#batching-embeddings).

## Rails Integration Example

With PostgreSQL, pgvector, and the `neighbor` gem configured, store vectors on your own records:

```ruby
class Document < ApplicationRecord
  has_neighbors :embedding

  before_save :generate_embedding, if: :content_changed?

  def self.search(query)
    vector = RubyLLM.embed(query).vectors
    nearest_neighbors(:embedding, vector, distance: :cosine).limit(5)
  end

  private

  def generate_embedding
    self.embedding = RubyLLM.embed(content).vectors
  end
end
```

```ruby
Document.create!(title: "Ruby blocks", content: "A block is a piece of Ruby code...")
Document.search("How do I pass behavior to a method?").pluck(:title)
```

The `embedding` vector column must match your model's dimensions. This example generates embeddings during save; use a job for imports that should run in the background. See [RAG]({% link _advanced/rag.md %}) for database setup and an agent that searches these records.

## Next Steps

*   [Reranking]({% link _core_features/rerank.md %}) to order your candidates by relevance before you use them.
*   [Retrieval-Augmented Generation (RAG)]({% link _advanced/rag.md %}) to ground answers in your own documents.
*   [Chatting with AI Models]({% link _core_features/chat.md %}) for interactive conversations.
*   [Using Tools]({% link _core_features/tools.md %}) to extend AI capabilities.
*   [Error Handling]({% link _advanced/error-handling.md %}) for retries and provider failures.
