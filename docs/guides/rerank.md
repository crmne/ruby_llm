---
layout: default
title: Reranking
parent: Guides
nav_order: 7
permalink: /guides/rerank
---

# Reranking
{: .no_toc }

Reranking improves search relevancy by reassessing and reordering retrieved documents based on their relevance to a specific query. This is particularly useful for optimizing Retrieval Augmented Generation (RAG) pipelines and enterprise search applications.
{: .fs-6 .fw-300 }

## Table of contents
{: .no_toc .text-delta }

1. TOC
{:toc}

---

After reading this guide, you will know:

*   What reranking is and why it's useful.
*   How to use RubyLLM's reranking API.
*   Best practices for optimizing reranking performance.
*   How to integrate reranking into RAG pipelines.
*   Advanced reranking techniques and parameter tuning.

## Understanding Reranking

### What is Reranking?

Reranking is a specialized AI technique that improves search result quality by:

- **Reassessing document relevance**: Analyzing how well each document matches a specific query
- **Generating relevance scores**: Providing numerical scores (0-1) indicating relevance strength
- **Reordering results**: Sorting documents from most to least relevant
- **Filtering content**: Optionally limiting results to the top N most relevant documents

### Why Use Reranking?

**Enhanced Search Quality**: Reranking models are specifically trained to understand relevance, often providing better results than traditional keyword matching or even semantic search alone.

**RAG Pipeline Optimization**: By filtering out irrelevant documents before they reach your language model, you can:
- Reduce processing costs
- Improve response accuracy
- Minimize hallucinations
- Speed up generation times

**Cost Efficiency**: Process only the most relevant documents, reducing token usage and API costs for downstream language model calls.

### How It Works

1. **Input**: Provide a query and a set of candidate documents
2. **Analysis**: The reranking model analyzes each document's relevance to the query
3. **Scoring**: Each document receives a relevance score between 0 and 1
4. **Reordering**: Documents are sorted by relevance score (highest first)
5. **Filtering**: Optionally limit results to top N documents

## Basic Usage

### Simple Reranking

```ruby
require 'ruby_llm'

# Configure your API key
RubyLLM.configure do |config|
  config.cohere_api_key = ENV['COHERE_API_KEY']
end

# Your search query
query = "How do I handle exceptions in Ruby?"

# Candidate documents to rerank
documents = [
  "Ruby uses begin/rescue/end blocks to handle exceptions, similar to try/catch in other languages.",
  "JavaScript async/await syntax makes handling asynchronous operations much easier.",
  "The raise keyword in Ruby allows you to throw custom exceptions with specific error messages.",
  "Python dictionaries are similar to Ruby hashes but use different syntax for iteration.",
  "Ruby's ensure block always executes, making it perfect for cleanup operations like closing files."
]

# Rerank the documents
rerank_result = RubyLLM.rerank(query, documents)

# Access the results
puts "Found #{rerank_result.results.length} results"
puts "Model used: #{rerank_result.model}"
puts "Search units: #{rerank_result.search_units}"

# Iterate through results (already sorted by relevance)
rerank_result.results.each_with_index do |result, i|
  puts "#{i + 1}. [Score: #{result.relevance_score.round(3)}] #{result.document}"
end
```

### Limiting Results

```ruby
# Only return the top 2 most relevant documents
rerank_result = RubyLLM.rerank(query, documents, top_n: 2)

puts "Top #{rerank_result.results.length} results:"
rerank_result.results.each do |result|
  puts "Score: #{result.relevance_score.round(3)}"
  puts "Document: #{result.document}"
  puts "Original index: #{result.index}"
  puts "---"
end
```

### Specifying Models and Providers

```ruby
# Use a specific model
rerank_result = RubyLLM.rerank(query, documents, model: 'rerank-v3.5')

# Use a specific provider (if you have multiple configured)
rerank_result = RubyLLM.rerank(query, documents, provider: :cohere)

# Use both model and provider
rerank_result = RubyLLM.rerank(query, documents,
                              model: 'rerank-v3.5',
                              provider: :cohere)
```

## Advanced Usage

### Document Token Limits

Control how much of each document is processed:

```ruby
# Limit each document to 100 tokens
rerank_result = RubyLLM.rerank(query, documents, max_tokens_per_doc: 100)
```

This is particularly useful for:
- Very long documents that exceed model context limits
- Reducing processing costs for large document sets
- Ensuring consistent processing times

### Handling Empty Documents

```ruby
# RubyLLM raises an error if no documents are provided
empty_documents = []

begin
  rerank_result = RubyLLM.rerank(query, empty_documents)
rescue ArgumentError => e
  puts "Error: #{e.message}" # => "No documents provided for reranking"
end
```

### Using Custom Models

```ruby
# Use a custom or unlisted model
rerank_result = RubyLLM.rerank(query, documents,
                              model: 'custom-rerank-model',
                              assume_model_exists: true)
```

## Working with Results

### Understanding RerankResult Objects

Each result in the reranking response is a `RerankResult` object with three main attributes:

```ruby
rerank_result.results.each do |result|
  # Original position in the input array
  puts "Original index: #{result.index}"

  # Relevance score (0.0 to 1.0)
  puts "Relevance score: #{result.relevance_score}"

  # The document content
  puts "Document: #{result.document}"
end
```

### Filtering by Relevance Score

```ruby
# Only keep documents with high relevance scores
high_relevance_docs = rerank_result.results.select do |result|
  result.relevance_score > 0.7
end

puts "Found #{high_relevance_docs.length} highly relevant documents"
```

### Creating a Custom Threshold

```ruby
# Determine threshold based on your use case
def calculate_relevance_threshold(results)
  scores = results.map(&:relevance_score)
  return 0.0 if scores.empty?

  # Use average as threshold
  scores.sum / scores.length
end

threshold = calculate_relevance_threshold(rerank_result.results)
filtered_results = rerank_result.results.select do |result|
  result.relevance_score >= threshold
end
```

## RAG Pipeline Integration

### Basic RAG with Reranking

```ruby
class RAGPipeline
  def initialize
    @embedding_model = 'text-embedding-3-small'
    @rerank_model = 'rerank-v3.5'
    @chat_model = 'gpt-4.1-nano'
  end

  def search_and_answer(query, document_corpus)
    # Step 1: Retrieve candidate documents (semantic search)
    candidate_docs = semantic_search(query, document_corpus)

    # Step 2: Handle empty candidates
    return "No relevant documents found" if candidate_docs.empty?

    # Step 3: Rerank for relevance
    rerank_result = RubyLLM.rerank(query, candidate_docs,
                                  model: @rerank_model,
                                  top_n: 5)

    # Step 4: Filter by relevance score
    relevant_docs = rerank_result.results.select do |result|
      result.relevance_score > 0.6
    end

    # Step 5: Generate answer using most relevant docs
    context = relevant_docs.map(&:document).join("\n\n")
    generate_answer(query, context)
  end

  private

  def semantic_search(query, corpus)
    # Your semantic search implementation
    # This might use embeddings, keyword search, etc.
    corpus.sample(10)  # Placeholder
  end

  def generate_answer(query, context)
    chat = RubyLLM.chat(model: @chat_model)
    chat.with_instructions(
      "Answer the question based on the provided context. " \
      "If the context doesn't contain relevant information, say so."
    )

    prompt = <<~PROMPT
      Context:
      #{context}

      Question: #{query}
    PROMPT

    chat.ask(prompt)
  end
end

# Usage
pipeline = RAGPipeline.new
answer = pipeline.search_and_answer("How do I iterate over arrays in Ruby?", your_documents)
puts answer
```

### Two-Stage Retrieval

```ruby
class TwoStageRAG
  def initialize
    @rerank_model = 'rerank-v3.5'
  end

  def retrieve_documents(query, corpus)
    # Stage 1: Fast, broad retrieval (e.g., BM25, basic embeddings)
    initial_candidates = fast_retrieval(query, corpus, limit: 100)

    # Stage 2: Precise reranking
    rerank_result = RubyLLM.rerank(query, initial_candidates,
                                  model: @rerank_model,
                                  top_n: 10)

    # Return top results with metadata
    rerank_result.results.map do |result|
      {
        content: result.document,
        score: result.relevance_score,
        original_index: result.index
      }
    end
  end

  private

  def fast_retrieval(query, corpus, limit:)
    # Your fast retrieval implementation
    # Could be elasticsearch, database search, etc.
    corpus.sample(limit)
  end
end
```

## Best Practices

### Document Preparation

**Chunk Size Optimization**: For rerank models like `rerank-v3.5` with 4,096 token context:
- Keep documents under 4096 tokens to avoid automatic chunking
- For longer documents, pre-chunk them strategically at paragraph or section boundaries

```ruby
def prepare_documents(long_documents)
  chunks = []

  long_documents.each do |doc|
    if doc.length > 3000  # Leave buffer for query
      # Split into smaller chunks
      chunks.concat(split_document(doc))
    else
      chunks << doc
    end
  end

  chunks
end

def split_document(text, max_length: 3000)
  # Split on paragraph boundaries
  paragraphs = text.split("\n\n")
  chunks = []
  current_chunk = ""

  paragraphs.each do |paragraph|
    if (current_chunk + paragraph).length > max_length && !current_chunk.empty?
      chunks << current_chunk.strip
      current_chunk = paragraph
    else
      current_chunk += "\n\n" + paragraph
    end
  end

  chunks << current_chunk.strip unless current_chunk.empty?
  chunks
end
```

### Query Optimization

**Keep queries concise**: Rerank models typically allow queries up to half the context length (e.g., 2048 tokens for `rerank-v3.5`).

```ruby
def optimize_query(query, max_tokens: 2000)
  # Truncate very long queries
  if query.length > max_tokens
    truncated = query[0...max_tokens]
    # Try to break at word boundary
    last_space = truncated.rindex(' ')
    truncated = truncated[0...last_space] if last_space
    truncated
  else
    query
  end
end
```

### Relevance Threshold Tuning

**Establish empirical thresholds**: Test with representative queries to find optimal score thresholds.

```ruby
class ThresholdTuner
  def initialize(test_queries_and_docs)
    @test_data = test_queries_and_docs
    @rerank_model = 'rerank-v3.5'
  end

  def find_optimal_threshold
    all_scores = []

    @test_data.each do |query, docs, expected_relevant|
      rerank_result = RubyLLM.rerank(query, docs, model: @rerank_model)

      # Collect scores for documents you know are relevant
      relevant_scores = rerank_result.results.select do |result|
        expected_relevant.include?(result.document)
      end.map(&:relevance_score)

      all_scores.concat(relevant_scores)
    end

    # Use average of known relevant documents as threshold
    all_scores.sum / all_scores.length
  end
end
```

### Performance Optimization

**Batch processing**: Process multiple queries efficiently:

```ruby
def batch_rerank(queries_and_docs)
  results = {}

  queries_and_docs.each do |query, docs|
    # Use threading for concurrent processing
    Thread.new do
      results[query] = RubyLLM.rerank(query, docs, top_n: 5)
    end
  end

  # Wait for all threads to complete
  Thread.list.each(&:join)
  results
end
```

### Error Handling

```ruby
def safe_rerank(query, documents, options = {})
  begin
    rerank_result = RubyLLM.rerank(query, documents, **options)
    { results: rerank_result.results, error: nil }
  rescue ArgumentError => e
    # Handle empty documents error
    { results: [], error: e.message }
  rescue RubyLLM::Error => e
    # Handle API errors
    { results: [], error: e.message }
  end
end
```

## Configuration

### Default Model Configuration

```ruby
RubyLLM.configure do |config|
  config.cohere_api_key = ENV['COHERE_API_KEY']
  config.default_rerank_model = 'rerank-v3.5'
end

# Now you can omit the model parameter
rerank_result = RubyLLM.rerank(query, documents)
```

### Using Contexts

```ruby
# Use different configurations for different environments
production_context = RubyLLM.context do |config|
  config.cohere_api_key = ENV['COHERE_PROD_API_KEY']
  config.default_rerank_model = 'rerank-english-v3.0'
end

staging_context = RubyLLM.context do |config|
  config.cohere_api_key = ENV['COHERE_STAGING_API_KEY']
  config.default_rerank_model = 'rerank-v3.5'
end

# Use specific context
prod_result = production_context.rerank(query, documents)
staging_result = staging_context.rerank(query, documents)
```

## Common Use Cases

### Enterprise Search

```ruby
class EnterpriseSearch
  def initialize
    @rerank_model = 'rerank-v3.5'
  end

  def search(query, department: nil)
    # Get initial candidates from your search system
    candidates = fetch_candidates(query, department)

    # Rerank for relevance
    rerank_result = RubyLLM.rerank(query, candidates,
                                  model: @rerank_model,
                                  top_n: 20)

    # Format results for presentation
    format_search_results(rerank_result.results)
  end

  private

  def fetch_candidates(query, department)
    # Your existing search logic
    # Could be Elasticsearch, database search, etc.
  end

  def format_search_results(results)
    results.map do |result|
      {
        content: result.document,
        relevance: result.relevance_score,
        confidence: relevance_to_confidence(result.relevance_score)
      }
    end
  end

  def relevance_to_confidence(score)
    case score
    when 0.8..1.0 then 'High'
    when 0.6..0.8 then 'Medium'
    when 0.4..0.6 then 'Low'
    else 'Very Low'
    end
  end
end
```

### Ruby Code Documentation Search

```ruby
class RubyDocumentationSearch
  def initialize
    @rerank_model = 'rerank-v3.5'
  end

  def find_relevant_docs(search_query, code_docs)
    doc_contents = code_docs.map(&:content)

    rerank_result = RubyLLM.rerank(search_query, doc_contents,
                                  model: @rerank_model)

    # Return documentation with relevance scores
    rerank_result.results.map do |result|
      original_doc = code_docs[result.index]
      {
        documentation: original_doc,
        relevance_score: result.relevance_score,
        category: original_doc.category # e.g., 'classes', 'methods', 'gems'
      }
    end
  end
end
```

### Ruby Code Similarity Detection

```ruby
class RubyCodeSimilarity
  def initialize
    @rerank_model = 'rerank-v3.5'
  end

  def find_similar_code(reference_code, candidate_snippets)
    # Use the reference code as the "query"
    rerank_result = RubyLLM.rerank(reference_code, candidate_snippets,
                                  model: @rerank_model)

    # Group by similarity level for code review or refactoring
    {
      highly_similar: rerank_result.results.select { |r| r.relevance_score > 0.8 },
      moderately_similar: rerank_result.results.select { |r| r.relevance_score.between?(0.5, 0.8) },
      low_similarity: rerank_result.results.select { |r| r.relevance_score < 0.5 }
    }
  end

  def find_duplicate_methods(method_implementations)
    duplicates = []

    method_implementations.each_with_index do |reference_method, index|
      remaining_methods = method_implementations[(index + 1)..-1]
      next if remaining_methods.empty?

      similar_methods = find_similar_code(reference_method, remaining_methods)

      # Flag potential duplicates
      similar_methods[:highly_similar].each do |similar|
        duplicates << {
          original: reference_method,
          duplicate: similar.document,
          similarity_score: similar.relevance_score
        }
      end
    end

    duplicates
  end
end
```

## Troubleshooting

### Common Issues

**Empty Documents Error**: If you get an `ArgumentError` about "No documents provided":
- Ensure your documents array is not empty
- Check that your document filtering logic doesn't accidentally remove all documents
- Handle empty cases explicitly in your application logic

**Low Relevance Scores**: If all scores are low:
- Check if your query matches the document domain
- Consider preprocessing documents (remove noise, extract key content)
- Experiment with different query formulations

**Performance Issues**: For slow reranking:
- Reduce document count before reranking
- Use `max_tokens_per_doc` to limit processing
- Consider caching results for repeated queries

### Debugging

```ruby
def debug_rerank(query, documents)
  puts "Query: #{query}"
  puts "Document count: #{documents.length}"

  rerank_result = RubyLLM.rerank(query, documents, model: 'rerank-v3.5')

  puts "Results count: #{rerank_result.results.length}"
  puts "Search units: #{rerank_result.search_units}"

  rerank_result.results.each_with_index do |result, i|
    puts "#{i + 1}. Score: #{result.relevance_score.round(3)}"
    puts "   Index: #{result.index}"
    puts "   Preview: #{result.document[0..100]}..."
    puts
  end
end

# Example usage with Ruby-specific content
ruby_query = "How do I create a class in Ruby?"
ruby_docs = [
  "Ruby classes are defined using the class keyword followed by the class name in CamelCase.",
  "Python classes use the class keyword but follow snake_case naming conventions.",
  "Instance variables in Ruby start with @ and are accessible throughout the class.",
  "JavaScript classes were introduced in ES6 and use constructor functions.",
  "Ruby methods are defined with def and end keywords, making the syntax very readable."
]

# debug_rerank(ruby_query, ruby_docs)
```

## Next Steps

*   [Working with Embeddings]({% link guides/embeddings.md %})
*   [Chatting with AI Models]({% link guides/chat.md %})
*   [Using Tools]({% link guides/tools.md %})
*   [Error Handling]({% link guides/error-handling.md %})
*   [Available Models]({% link guides/available-models.md %})
