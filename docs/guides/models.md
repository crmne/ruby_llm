---
layout: default
title: Working with Models
parent: Guides
nav_order: 9
permalink: /guides/models
---

# Working with Models

RubyLLM provides a clean interface for discovering and working with AI models from multiple providers. This guide explains how to find, filter, and select the right model for your needs.

## Exploring Available Models

RubyLLM automatically discovers available models from all configured providers:

```ruby
# Get all available models
all_models = RubyLLM.models.all

# See how many models are available
puts "Total models: #{all_models.count}"

# List models with details
all_models.each do |model|
  puts "#{model.id} (#{model.provider}) - #{model.display_name}"
end
```

## Filtering Models

You can filter models by various criteria:

```ruby
# Get only chat models
chat_models = RubyLLM.models.chat_models

# Get only embedding models
embedding_models = RubyLLM.models.embedding_models

# Get only image generation models
image_models = RubyLLM.models.image_models

# Get only audio models
audio_models = RubyLLM.models.audio_models
```

## Finding Models by Provider

Filter models by provider:

```ruby
# Get OpenAI models
openai_models = RubyLLM.models.by_provider('openai')

# Get Anthropic models
anthropic_models = RubyLLM.models.by_provider('anthropic')

# Get Google models
google_models = RubyLLM.models.by_provider('gemini')

# Get DeepSeek models
deepseek_models = RubyLLM.models.by_provider('deepseek')
```

## Using Model Aliases

RubyLLM provides convenient aliases for popular models, so you don't have to remember specific version numbers:

```ruby
# These are equivalent
chat = RubyLLM.chat(model: 'claude-3-5-sonnet')
chat = RubyLLM.chat(model: 'claude-3-5-sonnet-20241022')

# These are also equivalent
chat = RubyLLM.chat(model: 'gpt-4o')
chat = RubyLLM.chat(model: 'gpt-4o-2024-11-20')
```

Aliases for common models include:

| Alias | Resolves To |
|--------|-------------|
| `claude-3-5-sonnet` | `claude-3-5-sonnet-20241022` |
| `claude-3-5-haiku` | `claude-3-5-haiku-20241022` |
| `claude-3-7-sonnet` | `claude-3-7-sonnet-20250219` |
| `claude-3-opus` | `claude-3-opus-20240229` |
| `gpt-4o` | `gpt-4o-2024-11-20` |
| `gpt-4o-mini` | `gpt-4o-mini-2024-07-18` |
| `gemini-1.5-flash` | `gemini-1.5-flash-002` |
| `gemini-2.0-flash` | `gemini-2.0-flash-001` |

Aliases are particularly useful when you want your code to always use the latest stable version of a model without having to update your codebase when providers release new model versions.

## Chaining Filters

You can chain multiple filters to find exactly what you need:

```ruby
# Get OpenAI chat models
openai_chat_models = RubyLLM.models.by_provider('openai').chat_models

# Get Anthropic embedding models (if any)
anthropic_embeddings = RubyLLM.models.by_provider('anthropic').embedding_models

# Get Google models that support vision
google_vision_models = RubyLLM.models.by_provider('gemini').chat_models.select(&:supports_vision)
```

Filters can be applied in any order:

```ruby
# These return the same models
chat_anthropic = RubyLLM.models.chat_models.by_provider('anthropic')
anthropic_chat = RubyLLM.models.by_provider('anthropic').chat_models
```

## Getting Model Details

Find a specific model by ID to see its capabilities:

```ruby
model = RubyLLM.models.find('gpt-4o-mini')

puts "Model: #{model.display_name}"
puts "Provider: #{model.provider}"
puts "Context window: #{model.context_window} tokens"
puts "Max generation: #{model.max_tokens} tokens"
puts "Input price: $#{model.input_price_per_million} per million tokens"
puts "Output price: $#{model.output_price_per_million} per million tokens"
puts "Supports vision: #{model.supports_vision}"
puts "Supports functions: #{model.supports_functions}"
puts "Supports JSON mode: #{model.supports_json_mode}"
```

## Using Enumerable Methods

The models collection includes Ruby's `Enumerable` module, so you can use all your favorite methods:

```ruby
# Count models by provider
provider_counts = RubyLLM.models.group_by(&:provider).transform_values(&:count)
puts "OpenAI models: #{provider_counts['openai']}"
puts "Anthropic models: #{provider_counts['anthropic']}"

# Find models matching specific criteria
vision_models = RubyLLM.models.select(&:supports_vision)
function_models = RubyLLM.models.select(&:supports_functions)

# Find the cheapest model for a task
cheapest_chat = RubyLLM.models.chat_models.min_by(&:input_price_per_million)
puts "Cheapest chat model: #{cheapest_chat.display_name} ($#{cheapest_chat.input_price_per_million}/M tokens)"
```

## Finding Models by Family

Filter models by family (model architecture):

```ruby
# Get all GPT-4 models
gpt4_models = RubyLLM.models.by_family('gpt4')

# Get all Claude 3 models
claude3_models = RubyLLM.models.by_family('claude3_sonnet')
```

## Refreshing Model Data

Force a refresh of model data from providers:

```ruby
RubyLLM.models.refresh!
```

## Best Practices

When selecting models for your application:

1. **Consider context windows** - Larger context windows support longer conversations but may cost more
2. **Balance cost vs. quality** - More capable models cost more but may give better results
3. **Check capabilities** - Make sure the model supports features you need (vision, functions, etc.)
4. **Use appropriate model types** - Use embedding models for vector operations, chat models for conversations