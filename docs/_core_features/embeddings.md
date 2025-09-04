---
layout: default
title: Embeddings
nav_order: 4
description: Transform text into numerical vectors for semantic search, recommendations, and content similarity
redirect_from:
  - /guides/embeddings
---

# {{ page.title }}
{: .no_toc }

{{ page.description }}
{: .fs-6 .fw-300 }

## Table of contents
{: .no_toc .text-delta }

1. TOC
{:toc}

---

After reading this guide, you will know:

*   How to generate embeddings for single or multiple texts.
*   How to choose specific embedding models.
*   How to use the results, including calculating similarity.
*   How to handle errors during embedding generation.
*   Best practices for performance and large datasets.
*   How to integrate embeddings in a Rails application.

## Basic Embedding Generation

The simplest way to create an embedding is with the global `RubyLLM.embed` method:

```ruby
# Create an embedding for a single text
embedding = RubyLLM.embed("Ruby is a programmer's best friend")

# The vector representation (an array of floats)
vector = embedding.vectors
puts "Vector dimension: #{vector.length}" # e.g., 1536 for {{ site.models.embedding_small }}

# Access metadata
puts "Model used: #{embedding.model}"
puts "Input tokens: #{embedding.input_tokens}"
```

## Embedding Multiple Texts

You can efficiently embed multiple texts in a single API call:

```ruby
texts = ["Ruby", "Python", "JavaScript"]
embeddings = RubyLLM.embed(texts)

# Each text gets its own vector within the `vectors` array
puts "Number of vectors: #{embeddings.vectors.length}" # => 3
puts "First vector dimensions: #{embeddings.vectors.first.length}"
puts "Model used: #{embeddings.model}"
puts "Total input tokens: #{embeddings.input_tokens}"
```

> Batching multiple texts is generally more performant and cost-effective than making individual requests for each text.
{: .note }

## Choosing Models

By default, RubyLLM uses a capable default embedding model (like OpenAI's `{{ site.models.embedding_small }}`), but you can specify a different one using the `model:` argument.

```ruby
# Use a specific OpenAI model
embedding_large = RubyLLM.embed(
  "This is a test sentence",
  model: "{{ site.models.embedding_large }}"
)

# Or use a Google model
embedding_google = RubyLLM.embed(
  "This is another test sentence",
  model: "{{ site.models.embedding_google }}" # Google's model
)

# Use a model not in the registry (useful for custom endpoints)
embedding_custom = RubyLLM.embed(
  "Custom model test",
  model: "my-custom-embedding-model",
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

Refer to the [Working with Models Guide]({% link _advanced/models.md %}) for details on finding available embedding models and their capabilities.

## Choosing Dimensions

Each embedding model has its own default output dimensions. For example, OpenAI's `{{ site.models.embedding_small }}` outputs 1536 dimensions by default, while `{{ site.models.embedding_large }}` outputs 3072 dimensions. RubyLLM allows you to specify these dimensions per request:

```ruby
embedding = RubyLLM.embed(
  "This is a test sentence",
  model: "{{ site.models.embedding_small }}",
  dimensions: 512
)
```

This is particularly useful when:
- Working with vector databases that have specific dimension requirements
- Ensuring consistent dimensionality across different requests
- Optimizing storage and query performance in your vector database

Note that not all models support custom dimensions. If you specify dimensions that aren't supported by the chosen model, RubyLLM will use the model's default dimensions.

## Using Embedding Results

### Vector Properties

The embedding result contains useful information:

```ruby
embedding = RubyLLM.embed("Example text")

# The vector representation
puts embedding.vectors.class  # => Array
puts embedding.vectors.first.class  # => Float

# The vector dimensions
puts embedding.vectors.first.length # => 1536

# The model used
puts embedding.model  # => "{{ site.models.embedding_small }}"
```

## Using Embedding Results

A primary use case for embeddings is measuring the semantic similarity between texts. Cosine similarity is a common metric.

```ruby
require 'matrix' # Ruby's built-in Vector class requires 'matrix'

embedding1 = RubyLLM.embed("I love Ruby programming")
embedding2 = RubyLLM.embed("Ruby is my favorite language")

# Convert embedding vectors to Ruby Vector objects
vector1 = Vector.elements(embedding1.vectors)
vector2 = Vector.elements(embedding2.vectors)

# Calculate cosine similarity (value between -1 and 1, closer to 1 means more similar)
similarity = vector1.inner_product(vector2) / (vector1.norm * vector2.norm)
puts "Similarity: #{similarity.round(4)}" # => e.g., 0.9123
```

## Error Handling

Embedding API calls can fail for various reasons. Handle errors gracefully:

```ruby
begin
  embedding = RubyLLM.embed("Your text here")
  # Process embedding...
rescue RubyLLM::Error => e
  # Handle API errors
  puts "Embedding failed: #{e.message}"
end
```

For comprehensive error handling patterns and retry strategies, see the [Error Handling Guide]({% link _advanced/error-handling.md %}).

## Performance and Best Practices

*   **Batching:** Always embed multiple texts in a single call when possible. `RubyLLM.embed(["text1", "text2"])` is much faster than calling `RubyLLM.embed` twice.
*   **Caching/Persistence:** Embeddings are generally static for a given text and model. Store generated embeddings in your database or cache instead of regenerating them frequently.
*   **Dimensionality:** Different models produce vectors of different lengths (dimensions). Ensure your storage and similarity calculation methods handle the correct dimensionality (e.g., `{{ site.models.embedding_small }}` uses 1536 dimensions, `{{ site.models.embedding_large }}` uses 3072).
*   **Normalization:** Some vector databases and similarity algorithms perform better if vectors are normalized (scaled to have a length/magnitude of 1). Check the documentation for your specific use case or database.

## Rails Integration Example

In a Rails application using PostgreSQL with the `pgvector` extension, you might store and search embeddings like this:

```ruby
# Migration:
# add_column :documents, :embedding, :vector, limit: 1536 # Match your model's dimensions

# app/models/document.rb
class Document < ApplicationRecord
  has_neighbors :embedding # From the neighbor gem for pgvector

  # Automatically generate embedding before saving if content changed
  before_save :generate_embedding, if: :content_changed?

  # Scope for nearest neighbor search
  scope :search_by_similarity, ->(query_text, limit: 5) {
    query_embedding = RubyLLM.embed(query_text).vectors
    nearest_neighbors(:embedding, query_embedding, distance: :cosine).limit(limit)
  }

  private

  def generate_embedding
    return if content.blank?
    puts "Generating embedding for Document #{id}..."
    begin
      embedding_result = RubyLLM.embed(content) # Uses default embedding model
      self.embedding = embedding_result.vectors
    rescue RubyLLM::Error => e
      errors.add(:base, "Failed to generate embedding: #{e.message}")
      # Prevent saving if embedding fails (optional, depending on requirements)
      throw :abort
    end
  end
end

# Usage in controller or console:
# Document.create(title: "Intro to Ruby", content: "Ruby is a dynamic language...")
# results = Document.search_by_similarity("What is Ruby?")
# results.each { |doc| puts "- #{doc.title}" }
```

> This Rails example assumes you have the `pgvector` extension enabled in PostgreSQL and are using a gem like `neighbor` for ActiveRecord integration.
{: .note }

## Next Steps

Now that you understand embeddings, you might want to explore:

*   [Chatting with AI Models]({% link _core_features/chat.md %}) for interactive conversations.
*   [Using Tools]({% link _core_features/tools.md %}) to extend AI capabilities.
*   [Error Handling]({% link _advanced/error-handling.md %}) for building robust applications.
