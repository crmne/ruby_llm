---
layout: default
title: Embeddings
nav_order: 3
description: Transform text into numerical vectors for semantic search, recommendations, and content similarity
redirect_from:
  - /guides/embeddings
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

*   How to generate embeddings for single or multiple texts.
*   How to choose specific embedding models.
*   How to use the results, including calculating similarity.
*   How to handle errors during embedding generation.
*   Best practices for performance and large datasets.
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

By default, RubyLLM uses OpenAI's `{{ site.models.embedding_small }}`, but you can specify a different one using the `model:` argument.

```ruby
embedding_large = RubyLLM.embed(
  "This is a test sentence",
  model: "{{ site.models.embedding_large }}"
)

embedding_google = RubyLLM.embed(
  "This is another test sentence",
  model: "{{ site.models.embedding_google }}" # Google's model
)

# Use a model not in the registry (useful for custom endpoints)
embedding_custom = RubyLLM.embed(
  "Custom model test",
  model: ENV.fetch("CUSTOM_EMBEDDING_MODEL"),
  provider: :openai,
  assume_model_exists: true
)
```

You can configure the default embedding model globally:

```ruby
RubyLLM.configure do |config|
  config.default_embedding_model = "{{ site.models.embedding_large }}"
end
```

Refer to the [Model Registry guide]({% link _reference/models.md %}) for details on finding available embedding models and their capabilities, and to [Model Resolution]({% link _reference/model-resolution.md %}) for how `model:`, `provider:`, and `assume_model_exists:` resolve.

## Choosing Dimensions

Each embedding model has its own default output dimensions. For example, OpenAI's `{{ site.models.embedding_small }}` outputs 1536 dimensions by default, while `{{ site.models.embedding_large }}` outputs 3072 dimensions. RubyLLM allows you to specify these dimensions per request:

```ruby
embedding = RubyLLM.embed(
  "This is a test sentence",
  model: "{{ site.models.embedding_small }}",
  dimensions: 512
)
```

Choose dimensions that match your database column. Smaller vectors use less storage; measure retrieval quality on your own data before changing an existing index.

Not every model accepts `dimensions:`. RubyLLM sends the value you set, and a model that does not support it rejects the request. `mistral-embed`, for example, returns a 400. Leave `dimensions:` out for those models.

## Task Types

Some providers tune embeddings for a specific task, such as indexing a document versus matching a search query. Pass `task_type:` with a value in the provider's own vocabulary and RubyLLM places it on the right request field for you.

Vertex AI and Gemini accept values like `RETRIEVAL_QUERY`, `RETRIEVAL_DOCUMENT`, `SEMANTIC_SIMILARITY`, and `CLASSIFICATION` with Gemini Embedding 001. On these providers you can also pass `title:` to label the document being embedded. Gemini Embedding 2 does not accept `task_type:` or `title:`. Put task instructions in the text instead.

```ruby
embedding = RubyLLM.embed(
  "RubyLLM makes provider APIs feel native to Ruby.",
  model: "{{ site.models.embedding_google_text }}",
  provider: :vertexai,
  task_type: "RETRIEVAL_DOCUMENT",
  title: "RubyLLM docs"
)
```

Cohere, on its own API and on Bedrock, maps `task_type:` to its `input_type` field, so pass values like `search_document`, `search_query`, `classification`, or `clustering`. `search_document` is the default. Cohere has no title concept, so `title:` is ignored there.

Cohere's `embed-v4.0` embeds text and images into one vector. Pass the images with `with:`:

```ruby
embedding = RubyLLM.embed(
  "a red gemstone on a white background",
  model: "embed-v4.0",
  provider: :cohere,
  with: "gem.png"
)
```

Providers that have no task concept, such as OpenAI, ignore both `task_type:` and `title:`.

## Provider Options

Use `provider_options:` for request fields in the provider's own vocabulary that are not first-class RubyLLM options. RubyLLM merges them into the rendered request as-is. For example, Vertex AI accepts request-level `parameters:`:

```ruby
embedding = RubyLLM.embed(
  "RubyLLM makes provider APIs feel native to Ruby.",
  model: "{{ site.models.embedding_google_text }}",
  provider: :vertexai,
  provider_options: { parameters: { autoTruncate: false } }
)
```

Keys you pass replace what RubyLLM rendered, so `provider_options:` can override any field RubyLLM sets, including the task type. Reach for it only when a field has no first-class keyword like `task_type:` or `title:`.

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

Sparse output is a de-facto extension rather than part of the OpenAI embeddings spec, so whether you get one depends on the model and the server hosting it. RubyLLM reads it from either `lexical_weights` or `sparse_embedding`, the two spellings in use. Where there is none, `sparse_vectors` is `nil`, which is what every hosted provider returns today.

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

## Error Handling

Embedding API calls can fail for various reasons. Handle errors gracefully:

```ruby
begin
  embedding = RubyLLM.embed("Your text here")
rescue RubyLLM::Error => e
  puts "Embedding failed: #{e.message}"
end
```

For retries and specific exceptions, see [Error Handling]({% link _advanced/error-handling.md %}).

## Performance and Best Practices

*   **Batching:** Always embed multiple texts in a single call when possible. `RubyLLM.embed(["text1", "text2"])` is much faster than calling `RubyLLM.embed` twice.
*   **Caching/Persistence:** Embeddings are generally static for a given text and model. Store generated embeddings in your database or cache instead of regenerating them frequently.
*   **Dimensionality:** Different models produce vectors of different lengths (dimensions). Ensure your storage and similarity calculation methods handle the correct dimensionality (e.g., `{{ site.models.embedding_small }}` uses 1536 dimensions, `{{ site.models.embedding_large }}` uses 3072).
*   **Normalization:** Some vector databases and similarity algorithms perform better if vectors are normalized (scaled to have a length/magnitude of 1). Check the documentation for your specific use case or database.

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
