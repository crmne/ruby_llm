---
layout: default
title: Chunking
parent: Guides
nav_order: 6
permalink: /guides/chunking
---

# Smart Text Chunking

RubyLLM provides sophisticated text chunking capabilities that help you process large documents effectively. Whether you're analyzing documentation, processing articles, or working with large text datasets, the chunking system helps you split content into manageable pieces while preserving context and meaning.

When you provide text to the chunking system, it will return an array of string chunks. If the input is nil, empty, or too small to be chunked, the system will handle these edge cases appropriately (returning an empty array for nil/empty inputs, or the original text as a single chunk for very small inputs).

## Available Chunking Strategies

RubyLLM offers several chunking strategies, each optimized for different use cases:

```ruby
# Basic character-based chunking
chunks = RubyLLM.chunk(text, chunker: :character, chunk_size: 1000)

# Paragraph-aware chunking
chunks = RubyLLM.chunk(text, chunker: :paragraph)

# Sentence-based chunking
chunks = RubyLLM.chunk(text, chunker: :sentence)

# Markdown-aware chunking (preserves document structure)
chunks = RubyLLM.chunk(text, chunker: :markdown)

# Semantic chunking (splits on topic changes)
chunks = RubyLLM.chunk(text, chunker: :semantic, similarity_threshold: 0.7)

# Recursive chunking (hierarchical approach)
chunks = RubyLLM.chunk(text, chunker: :recursive)
```

## Choosing the Right Chunker

Each chunking strategy has its strengths:

| Chunker | Best For | Key Features | Default Parameters |
|---------|----------|--------------|-------------------|
| `:character` | Simple text | Basic splitting by character count | chunk_size: 2000, overlap: 200 |
| `:paragraph` | Articles, essays | Preserves paragraph boundaries | min_size: 100, max_size: 2000, separator: "\n\n" |
| `:sentence` | Natural text | Maintains sentence integrity | min_size: 100, max_size: 2000 |
| `:markdown` | Documentation | Preserves markdown structure | min_size: 500, max_size: 2000 |
| `:semantic` | Complex documents | Maintains topical coherence | min_size: 100, max_size: 2000, similarity_threshold: 0.7 |
| `:recursive` | Mixed content | Adaptive splitting | min_size: 100, max_size: 2000 |

## Common Use Cases

### Processing Large Documents

```ruby
# Read a large document
text = File.read("large_document.txt")

# Split into semantic chunks
chunks = RubyLLM.chunk(text, 
  chunker: :semantic, 
  min_size: 100,
  max_size: 1000
)

# Process each chunk with an LLM
chat = RubyLLM.chat
chunks.each do |chunk|
  summary = chat.ask("Summarize this section: #{chunk}")
  puts summary.content
end
```

### Working with Documentation

```ruby
# Process markdown documentation
docs = File.read("api_docs.md")

# Use markdown-aware chunking
chunks = RubyLLM.chunk(docs, 
  chunker: :markdown,
  min_size: 200,
  max_size: 2000
)

# Analyze each section
chunks.each do |chunk|
  puts "Section length: #{chunk.length}"
end
```

## Advanced Configuration

### Recursive Chunking

The recursive chunker uses a hierarchical approach with multiple separator patterns:

```ruby
chunks = RubyLLM.chunk(text,
  chunker: :recursive,
  min_size: 100,
  max_size: 2000,
  separator_patterns: [
    /\n{3,}/,           # Multiple blank lines
    /[.!?]\s+/,         # Sentence boundaries
    /[,;]\s+/,          # Clause boundaries
    /\s+/               # Word boundaries
  ]
)
```

### Semantic Chunking

Configure semantic chunking sensitivity:

```ruby
chunks = RubyLLM.chunk(text,
  chunker: :semantic,
  min_size: 200,
  max_size: 1500,
  similarity_threshold: 0.8,  # Higher = more granular splits (default: 0.7)
  model: 'gpt-3.5-turbo'      # Model used for embeddings (optional)
)
```

## Best Practices

1. **Choose the Right Strategy**: Match the chunking strategy to your content type and use case.
2. **Balance Chunk Size**: Too small chunks lose context, too large ones may exceed model limits.
3. **Consider Overlap**: Use overlap when context between chunks is important.
4. **Test Different Approaches**: Experiment with different chunkers and settings for optimal results.

## Performance Considerations

- Semantic chunking is more CPU-intensive due to embedding calculations and requires an API call to generate embeddings
- Recursive chunking provides a good balance of speed and quality
- Character chunking is the fastest but least context-aware option
- For very large documents, consider processing chunks in batches

## Next Steps

Now that you understand chunking, you might want to explore:

- [Embeddings]({% link guides/embeddings.md %}) for semantic search
- [Rails Integration]({% link guides/rails.md %}) for document processing
- [Tools]({% link guides/tools.md %}) for custom processing logic
