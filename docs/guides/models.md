---
layout: default
title: Working with Models
parent: Guides
nav_order: 9
permalink: /guides/models
---

# Working with Models

RubyLLM provides a clean interface for discovering and working with AI models from multiple providers. This guide explains how to find, filter, and select the right model for your needs.

## Finding Models

### Basic Model Selection

The simplest way to use a model is to specify it when creating a chat:

```ruby
# Use the default model
chat = RubyLLM.chat

# Specify a model
chat = RubyLLM.chat(model: 'gpt-4o-mini')

# Change models mid-conversation
chat.with_model('claude-3-5-sonnet')
```

### Model Resolution

{: .warning-title }
> Coming in v1.1.0
>
> Provider-Specific Match and Alias Resolution will be available in the next release.

When you specify a model, RubyLLM follows these steps to find it:

1. **Exact Match**: First tries to find an exact match for the model ID
   ```ruby
   # Uses the actual gemini-2.0-flash model
   chat = RubyLLM.chat(model: 'gemini-2.0-flash')
   ```

2. **Provider-Specific Match**: If a provider is specified, looks for an exact match in that provider
   ```ruby
   # Looks for gemini-2.0-flash in Gemini
   chat = RubyLLM.chat(model: 'gemini-2.0-flash', provider: 'gemini')
   ```

3. **Alias Resolution**: Only if no exact match is found, checks for aliases
   ```ruby
   # No exact match for 'claude-3', uses alias
   chat = RubyLLM.chat(model: 'claude-3')
   ```

The same model ID can exist both as a concrete model and as an alias, particularly when the same model is available through different providers:

```ruby
# Use native OpenAI GPT-4
chat = RubyLLM.chat(model: 'gpt-4o')

# Use GPT-4 through Bedrock
chat = RubyLLM.chat(model: 'gpt-4o', provider: 'bedrock')
```

### Model Aliases

{: .warning-title }
> Coming in v1.1.0
>
> Alias Resolution will be available in the next release.

RubyLLM provides convenient aliases for popular models, so you don't have to remember specific version numbers:

```ruby
# These are equivalent
chat = RubyLLM.chat(model: 'claude-3-5-sonnet')
chat = RubyLLM.chat(model: 'claude-3-5-sonnet-20241022')

# These are also equivalent
chat = RubyLLM.chat(model: 'gpt-4o')
chat = RubyLLM.chat(model: 'gpt-4o-2024-11-20')
```

If you want to ensure you're always getting a specific version, use the full model ID:

```ruby
# Always gets this exact version
chat = RubyLLM.chat(model: 'claude-3-sonnet-20240229')
```

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
5. **Version control** - Use exact model IDs in production for consistency, aliases for development