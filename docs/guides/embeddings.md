---
layout: default
title: Embeddings
parent: Guides
nav_order: 7
permalink: /guides/embeddings
---

# Embeddings

Text embeddings are numerical representations of text that capture semantic meaning. RubyLLM makes it easy to generate embeddings for a variety of applications, including semantic search, clustering, and recommendation systems.

## Basic Embedding Generation

The simplest way to create an embedding is with the global `embed` method:

```ruby
# Create an embedding for a single text
embedding = RubyLLM.embed("Ruby is a programmer's best friend")

# The vector representation
vector = embedding.vectors
puts "Vector dimension: #{vector.length}"  # => 1536 for text-embedding-3-small
```

## Embedding Multiple Texts

You can efficiently embed multiple texts at once:

```ruby
# Create embeddings for multiple texts
texts = ["Ruby", "Python", "JavaScript"]
embeddings = RubyLLM.embed(texts)

# Each text gets its own vector
puts "Number of vectors: #{embeddings.vectors.length}"  # => 3
puts "First vector dimensions: #{embeddings.vectors.first.length}"
```

## Choosing Models

By default, RubyLLM uses OpenAI's `text-embedding-3-small`, but you can specify a different model:

```ruby
# Use a specific model
embedding = RubyLLM.embed(
  "This is a test sentence",
  model: "text-embedding-3-large"
)

# Or use a Google model
google_embedding = RubyLLM.embed(
  "This is a test sentence",
  model: "text-embedding-004"
)
```

You can configure the default embedding model globally:

```ruby
RubyLLM.configure do |config|
  config.default_embedding_model = "text-embedding-3-large"
end
```

## Choosing Dimensions

Each embedding model has its own default output dimensions. For example, OpenAI's `text-embedding-3-small` outputs 1536 dimensions by default, while `text-embedding-3-large` outputs 3072 dimensions. RubyLLM allows you to specify these dimensions per request:

```ruby
embedding = RubyLLM.embed(
  "This is a test sentence",
  model: "text-embedding-3-small",
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
puts embedding.model  # => "text-embedding-3-small"

# Token usage
puts embedding.input_tokens  # => 3
```

### Calculating Similarity

Embeddings are commonly used to calculate similarity between texts:

```ruby
require 'matrix'

# Create embeddings for two texts
embedding1 = RubyLLM.embed("I love Ruby programming")
embedding2 = RubyLLM.embed("Ruby is my favorite language")

# Convert to Vector objects
vector1 = Vector.elements(embedding1.vectors)
vector2 = Vector.elements(embedding2.vectors)

# Calculate cosine similarity
similarity = vector1.inner_product(vector2) / (vector1.norm * vector2.norm)
puts "Similarity: #{similarity}"  # Higher values (closer to 1) mean more similar
```

### Simple Semantic Search

```ruby
# Create a simple search index
class SearchIndex
  def initialize(texts, model: nil)
    @texts = texts
    @embeddings = RubyLLM.embed(texts, model: model).vectors
  end

  def search(query, top_k: 3)
    query_embedding = RubyLLM.embed(query).vectors
    query_vector = Vector.elements(query_embedding)

    # Calculate similarities
    similarities = @embeddings.map.with_index do |embedding, idx|
      vector = Vector.elements(embedding)
      similarity = query_vector.inner_product(vector) / (query_vector.norm * vector.norm)
      [idx, similarity]
    end

    # Return top results
    similarities.sort_by { |_, similarity| -similarity }
                .take(top_k)
                .map { |idx, similarity| { text: @texts[idx], similarity: similarity } }
  end
end

# Create an index
documents = [
  "Ruby is a dynamic, interpreted language",
  "Python is known for its readability",
  "JavaScript runs in the browser",
  "Ruby on Rails is a web framework",
  "Django is a Python web framework"
]

index = SearchIndex.new(documents)

# Search for similar documents
results = index.search("web development frameworks")
results.each do |result|
  puts "#{result[:text]} (Similarity: #{result[:similarity].round(4)})"
end
```

## Error Handling

Handle errors that may occur during embedding generation:

```ruby
begin
  embedding = RubyLLM.embed("Example text")
rescue RubyLLM::UnauthorizedError
  puts "Please check your API key"
rescue RubyLLM::BadRequestError => e
  puts "Invalid request: #{e.message}"
rescue RubyLLM::Error => e
  puts "Error generating embedding: #{e.message}"
end
```

## Performance Considerations

When working with embeddings, keep these best practices in mind:

1. **Batch processing** - Embedding multiple texts at once is more efficient than making separate calls
2. **Caching** - Store embeddings in your database rather than regenerating them
3. **Dimensionality** - Different models produce embeddings with different dimensions
4. **Normalization** - Consider normalizing vectors to improve similarity calculations

## Working with Large Datasets

For larger datasets, process embeddings in batches:

```ruby
def embed_in_batches(texts, batch_size: 100, model: nil)
  all_embeddings = []

  texts.each_slice(batch_size) do |batch|
    batch_embeddings = RubyLLM.embed(batch, model: model).vectors
    all_embeddings.concat(batch_embeddings)

    # Optional: add a small delay to avoid rate limiting
    sleep(0.1)
  end

  all_embeddings
end

# Usage
documents = File.readlines("documents.txt", chomp: true)
embeddings = embed_in_batches(documents)
```

## Rails Integration

In a Rails application, you might integrate embeddings like this:

```ruby
class Document < ApplicationRecord
  serialize :embedding, Array

  before_save :generate_embedding, if: -> { content_changed? }

  def self.search(query, limit: 10)
    # Generate query embedding
    query_embedding = RubyLLM.embed(query).vectors

    # Convert to SQL for similarity search
    where.not(embedding: nil)
         .select("*, (embedding <=> ?) AS similarity", query_embedding)
         .order("similarity DESC")
         .limit(limit)
  end

  private

  def generate_embedding
    return if content.blank?

    self.embedding = RubyLLM.embed(content).vectors
  rescue RubyLLM::Error => e
    errors.add(:base, "Failed to generate embedding: #{e.message}")
    throw :abort
  end
end
```

Note: The above example assumes you're using PostgreSQL with the `pgvector` extension for vector similarity search.

## Example Use Cases

### Document Classification

```ruby
# Train a simple classifier
class SimpleClassifier
  def initialize
    @categories = {}
  end

  def train(text, category)
    @categories[category] ||= []
    @categories[category] << RubyLLM.embed(text).vectors
  end

  def classify(text)
    # Get embedding for the query text
    query_embedding = RubyLLM.embed(text).vectors
    query_vector = Vector.elements(query_embedding)

    # Find the closest category
    best_similarity = -1
    best_category = nil

    @categories.each do |category, embeddings|
      # Calculate average similarity to this category
      similarity = embeddings.map do |embedding|
        vector = Vector.elements(embedding)
        query_vector.inner_product(vector) / (query_vector.norm * vector.norm)
      end.sum / embeddings.size

      if similarity > best_similarity
        best_similarity = similarity
        best_category = category
      end
    end

    { category: best_category, confidence: best_similarity }
  end
end

# Usage
classifier = SimpleClassifier.new

# Train with examples
classifier.train("How do I install Ruby?", :installation)
classifier.train("Setting up Ruby environment", :installation)
classifier.train("What are blocks in Ruby?", :language_features)
classifier.train("Understanding Ruby modules", :language_features)

# Classify new queries
puts classifier.classify("How to install Ruby on Ubuntu?")
# => {:category=>:installation, :confidence=>0.92}
```

### Content Recommendation

```ruby
def recommend_similar_content(content_id, library, count: 3)
  # Get the target content
  target = library.find(content_id)
  target_embedding = RubyLLM.embed(target.description).vectors
  target_vector = Vector.elements(target_embedding)

  # Compare with all other content
  similarities = library.reject { |item| item.id == content_id }.map do |item|
    next if item.embedding.nil?

    item_vector = Vector.elements(item.embedding)
    similarity = target_vector.inner_product(item_vector) / (target_vector.norm * item_vector.norm)

    [item, similarity]
  end.compact

  # Return top matches
  similarities.sort_by { |_, similarity| -similarity }
              .take(count)
              .map { |item, similarity| { item: item, similarity: similarity } }
end
```

## Next Steps

Now that you understand embeddings, you might want to explore:

- [Chat]({% link guides/chat.md %}) for interactive AI conversations
- [Tools]({% link guides/tools.md %}) to extend AI capabilities
- [Error Handling]({% link guides/error-handling.md %}) for robust applications
