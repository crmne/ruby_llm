---
layout: default
title: Prompt Caching
parent: Guides
nav_order: 11
permalink: /guides/prompt-caching
---

# Prompt Caching
{: .no_toc }

Prompt caching allows you to cache frequently used content like system instructions, large documents, or tool definitions to reduce costs and improve response times for subsequent requests.
{: .fs-6 .fw-300 }

## Table of contents
{: .no_toc .text-delta }

1. TOC
{:toc}

---

After reading this guide, you will know:

*   What prompt caching is and when to use it.
*   Which models and providers support prompt caching.
*   How to cache system instructions, user messages, and tool definitions.
*   How to track caching costs and token usage.
*   Best practices for maximizing cache efficiency.

## What is Prompt Caching?

Prompt caching allows AI providers to store and reuse parts of your prompts across multiple requests. When you mark content for caching, the provider stores it in a cache and can reuse it in subsequent requests without reprocessing, leading to:

- **Cost savings**: Cached content is typically charged at 75-90% less than regular input tokens
- **Faster responses**: Cached content doesn't need to be reprocessed
- **Consistent context**: Large documents or instructions remain available across conversations

{: .note }
Prompt caching is currently supported in RubyLLM only for **Anthropic** and **Bedrock** (Anthropic models) providers. The cache is ephemeral and will not be available if not used after 5 minutes by default.

Different models have different minimum numbers of tokens before caching kicks in but it usually takes around 1024 tokens worth of content.

## Basic Usage

Enable prompt caching using the `cache_prompts` method on your chat instance:

```ruby
chat = RubyLLM.chat(model: 'claude-3-5-haiku-20241022')

# Enable caching for different types of content
chat.cache_prompts(
  system: true,  # Cache system instructions
  user: true,    # Cache user messages
  tools: true    # Cache tool definitions
)
```

## Caching System Instructions

System instructions are ideal for caching when you have lengthy guidelines, documentation, or context that remains consistent across multiple conversations.

```ruby
# Large system prompt that would benefit from caching
CODING_GUIDELINES = <<~INSTRUCTIONS
  You are a senior Ruby developer and code reviewer. Follow these detailed guidelines:

  ## Code Style Guidelines
  - Use 2 spaces for indentation, never tabs
  - Keep lines under 120 characters
  - Use descriptive variable and method names
  - Prefer explicit returns in methods
  - Use single quotes for strings unless interpolation is needed
  
  ## Architecture Principles
  - Follow SOLID principles
  - Prefer composition over inheritance
  - Keep controllers thin, move logic to models or services
  - Use dependency injection for better testability
  
  ## Testing Requirements
  - Write RSpec tests for all new functionality
  - Aim for 90%+ test coverage
  - Use factories instead of fixtures
  - Mock external dependencies
  
  ## Security Considerations
  - Always validate and sanitize user input
  - Use strong parameters in controllers
  - Implement proper authentication and authorization
  - Never commit secrets or API keys
  
  ## Performance Guidelines
  - Avoid N+1 queries, use includes/joins
  - Index database columns used in WHERE clauses
  - Use background jobs for long-running tasks
  - Cache expensive computations
  
  [... additional detailed guidelines ...]
INSTRUCTIONS

chat = RubyLLM.chat(model: 'claude-3-5-haiku-20241022')
chat.with_instructions(CODING_GUIDELINES)
chat.cache_prompts(system: true)

# First request creates the cache
response = chat.ask("Review this Ruby method for potential improvements")
puts "Cache creation tokens: #{response.cache_creation_input_tokens}"

# Subsequent requests use the cached instructions
response = chat.ask("What are the testing requirements for this project?")
puts "Cache read tokens: #{response.cache_read_input_tokens}"
```

## Caching Large Documents

When working with large documents, user message caching can significantly reduce costs:

```ruby
# Load a large document (e.g., API documentation, legal contract, research paper)
large_document = File.read('path/to/large_api_documentation.md')

chat = RubyLLM.chat(model: 'claude-3-5-sonnet-20241022')
chat.cache_prompts(user: true)

# First request with the large document
prompt = <<~PROMPT
  #{large_document}
  
  Based on the API documentation above, how do I authenticate with this service?
PROMPT

response = chat.ask(prompt)
puts "Document cached. Creation tokens: #{response.cache_creation_input_tokens}"

# Follow-up questions can reference the cached document
response = chat.ask("What are the rate limits for this API?")
puts "Using cached document. Read tokens: #{response.cache_read_input_tokens}"

response = chat.ask("Show me an example of making a POST request to create a user")
puts "Still using cache. Read tokens: #{response.cache_read_input_tokens}"
```

## Caching Tool Definitions

When using multiple complex tools, caching their definitions can reduce overhead:

```ruby
# Define complex tools with detailed descriptions
class DatabaseQueryTool < RubyLLM::Tool
  description <<~DESC
    Execute SQL queries against the application database. This tool provides access to:
    
    - User management tables (users, profiles, permissions)
    - Content tables (posts, comments, media)
    - Analytics tables (events, metrics, reports)
    - Configuration tables (settings, features, experiments)
    
    Security notes:
    - Only SELECT queries are allowed
    - Results are limited to 1000 rows
    - Sensitive columns are automatically filtered
    - All queries are logged for audit purposes
    
    Usage examples:
    - Find active users: "SELECT * FROM users WHERE status = 'active'"
    - Get recent posts: "SELECT * FROM posts WHERE created_at > NOW() - INTERVAL 7 DAY"
    - Analyze user engagement: "SELECT COUNT(*) FROM events WHERE event_type = 'login'"
  DESC
  
  parameter :query, type: 'string', description: 'SQL query to execute'
  parameter :limit, type: 'integer', description: 'Maximum number of rows to return (default: 100)'
  
  def execute(query:, limit: 100)
    # Implementation here
    { results: [], count: 0 }
  end
end

class FileSystemTool < RubyLLM::Tool
  description <<~DESC
    Access and manipulate files in the application directory. Capabilities include:
    
    - Reading file contents (text files only)
    - Listing directory contents
    - Searching for files by name or pattern
    - Getting file metadata (size, modified date, permissions)
    
    Restrictions:
    - Cannot access files outside the application directory
    - Cannot modify, create, or delete files
    - Binary files are not supported
    - Maximum file size: 10MB
    
    Supported file types:
    - Source code (.rb, .js, .py, .java, etc.)
    - Configuration files (.yml, .json, .xml, etc.)
    - Documentation (.md, .txt, .rst, etc.)
    - Log files (.log, .out, .err)
  DESC
  
  parameter :action, type: 'string', description: 'Action to perform: read, list, search, or info'
  parameter :path, type: 'string', description: 'File or directory path'
  parameter :pattern, type: 'string', description: 'Search pattern (for search action)'
  
  def execute(action:, path:, pattern: nil)
    # Implementation here
    { action: action, path: path, result: 'success' }
  end
end

# Set up chat with tool caching
chat = RubyLLM.chat(model: 'claude-3-5-haiku-20241022')
chat.with_tools(DatabaseQueryTool, FileSystemTool)
chat.cache_prompts(tools: true)

# First request creates the tool cache
response = chat.ask("What tables are available in the database?")
puts "Tools cached. Creation tokens: #{response.cache_creation_input_tokens}"

# Subsequent requests use cached tool definitions
response = chat.ask("Show me the structure of the users table")
puts "Using cached tools. Read tokens: #{response.cache_read_input_tokens}"
```

## Combining Multiple Cache Types

You can cache different types of content simultaneously for maximum efficiency:

```ruby
# Large system context
ANALYSIS_CONTEXT = <<~CONTEXT
  You are an expert data analyst working with e-commerce data. Your analysis should consider:
  
  ## Business Metrics
  - Revenue and profit margins
  - Customer acquisition cost (CAC)
  - Customer lifetime value (CLV)
  - Conversion rates and funnel analysis
  
  ## Data Quality Standards
  - Check for missing or inconsistent data
  - Validate data ranges and formats
  - Identify outliers and anomalies
  - Ensure temporal consistency
  
  ## Reporting Guidelines
  - Use clear, business-friendly language
  - Include confidence intervals where appropriate
  - Highlight actionable insights
  - Provide recommendations with supporting evidence
  
  [... extensive analysis guidelines ...]
CONTEXT

# Load large dataset
sales_data = File.read('path/to/large_sales_dataset.csv')

chat = RubyLLM.chat(model: 'claude-3-5-sonnet-20241022')
chat.with_instructions(ANALYSIS_CONTEXT)
chat.with_tools(DatabaseQueryTool, FileSystemTool)

# Enable caching for all content types
chat.cache_prompts(system: true, user: true, tools: true)

# First request caches everything
prompt = <<~PROMPT
  #{sales_data}
  
  Analyze the sales data above and provide insights on revenue trends.
PROMPT

response = chat.ask(prompt)
puts "All content cached:"
puts "  System cache: #{response.cache_creation_input_tokens} tokens"
puts "  Tools cached: #{chat.messages.any? { |m| m.cache_creation_input_tokens&.positive? }}"

# Follow-up requests benefit from all cached content
response = chat.ask("What are the top-performing product categories?")
puts "Cache read tokens: #{response.cache_read_input_tokens}"

response = chat.ask("Query the database to get customer segmentation data")
puts "Cache read tokens: #{response.cache_read_input_tokens}"
```

## Understanding Cache Metrics

RubyLLM provides detailed metrics about cache usage in the response:

```ruby
chat = RubyLLM.chat(model: 'claude-3-5-haiku-20241022')
chat.with_instructions("Large system prompt here...")
chat.cache_prompts(system: true)

response = chat.ask("Your question here")

# Check if cache was created (first request)
if response.cache_creation_input_tokens&.positive?
  puts "Cache created with #{response.cache_creation_input_tokens} tokens"
  puts "Regular input tokens: #{response.input_tokens - response.cache_creation_input_tokens}"
end

# Check if cache was used (subsequent requests)
if response.cache_read_input_tokens&.positive?
  puts "Cache read: #{response.cache_read_input_tokens} tokens"
  puts "New input tokens: #{response.input_tokens - response.cache_read_input_tokens}"
end

# Total cost calculation (example with Claude pricing)
cache_creation_cost = (response.cache_creation_input_tokens || 0) * 3.75 / 1_000_000  # $3.75 per 1M tokens
cache_read_cost = (response.cache_read_input_tokens || 0) * 0.30 / 1_000_000          # $0.30 per 1M tokens  
regular_input_cost = (response.input_tokens - (response.cache_creation_input_tokens || 0) - (response.cache_read_input_tokens || 0)) * 3.00 / 1_000_000
output_cost = response.output_tokens * 15.00 / 1_000_000

total_cost = cache_creation_cost + cache_read_cost + regular_input_cost + output_cost
puts "Total request cost: $#{total_cost.round(6)}"
```

## Cost Optimization

Prompt caching can significantly reduce costs for applications with repeated content:

```ruby
# Example cost comparison for Claude 3.5 Sonnet
# Regular pricing: $3.00 per 1M input tokens
# Cache creation: $3.75 per 1M tokens (25% premium)
# Cache read: $0.30 per 1M tokens (90% discount)

def calculate_savings(content_tokens, num_requests)
  # Without caching
  regular_cost = content_tokens * num_requests * 3.00 / 1_000_000
  
  # With caching
  cache_creation_cost = content_tokens * 3.75 / 1_000_000
  cache_read_cost = content_tokens * (num_requests - 1) * 0.30 / 1_000_000
  cached_cost = cache_creation_cost + cache_read_cost
  
  savings = regular_cost - cached_cost
  savings_percentage = (savings / regular_cost * 100).round(1)
  
  puts "Content: #{content_tokens} tokens, #{num_requests} requests"
  puts "Regular cost: $#{regular_cost.round(4)}"
  puts "Cached cost: $#{cached_cost.round(4)}"
  puts "Savings: $#{savings.round(4)} (#{savings_percentage}%)"
end

# Examples
calculate_savings(5000, 10)   # 5K tokens, 10 requests
calculate_savings(20000, 5)   # 20K tokens, 5 requests
calculate_savings(50000, 3)   # 50K tokens, 3 requests
```

## Troubleshooting

### Cache Not Working
If caching doesn't seem to be working:

1. **Check model support**: Ensure you're using a supported model
2. **Verify provider**: Only Anthropic and Bedrock support caching
3. **Check content size**: Smaller content will not be cached - there is a minimum that varies per model
4. **Monitor metrics**: Use `cache_creation_input_tokens` and `cache_read_input_tokens`

```ruby
response = chat.ask("Your question")

if response.cache_creation_input_tokens.zero? && response.cache_read_input_tokens.zero?
  puts "No caching occurred. Check:"
  puts "  Model: #{chat.model.id}"
  puts "  Provider: #{chat.model.provider}"
  puts "  Cache settings: #{chat.instance_variable_get(:@cache_prompts)}"
end
```

### Unexpected Cache Behavior
Cache behavior can vary based on:

- **Content changes**: Any modification invalidates the cache
- **Cache expiration**: Caches are ephemeral and expire automatically
- **Provider limits**: Each provider has different cache policies

```ruby
# Cache is invalidated by any content change
chat.with_instructions("Original instructions")
chat.cache_prompts(system: true)
response1 = chat.ask("Question 1")  # Creates cache

chat.with_instructions("Modified instructions", replace: true)
response2 = chat.ask("Question 2")  # Creates new cache (old one invalidated)
```

## What's Next?

Now that you understand prompt caching, explore these related topics:

*   [Working with Models]({% link guides/models.md %}) - Learn about model capabilities and selection
*   [Using Tools]({% link guides/tools.md %}) - Understand tool definitions that can be cached
*   [Error Handling]({% link guides/error-handling.md %}) - Handle caching-related errors gracefully
*   [Rails Integration]({% link guides/rails.md %}) - Use caching in Rails applications 