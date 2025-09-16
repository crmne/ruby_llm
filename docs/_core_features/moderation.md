---
layout: default
title: Moderation
nav_order: 6
description: Identify potentially harmful content in text using AI moderation models before sending to LLMs
redirect_from:
  - /guides/moderation
---

# {{ page.title }}
{: .no_toc .d-inline-block }

Available in v1.8.0+
{: .label .label-green }

{{ page.description }}
{: .fs-6 .fw-300 }

## Table of contents
{: .no_toc .text-delta }

1. TOC
{:toc}

---

After reading this guide, you will know:

*   How to moderate text content for harmful material.
*   How to interpret moderation results and category scores.
*   How to use moderation as a safety layer before LLM requests.
*   How to configure moderation models and providers.
*   How to integrate moderation into your application workflows.
*   Best practices for content safety and user experience.

## Basic Content Moderation

The simplest way to moderate content is using the global `RubyLLM.moderate` method:

```ruby
# Moderate a text input
result = RubyLLM.moderate("This is a safe message about Ruby programming")

# Check if content was flagged
puts result.flagged?  # => false

# Access the full results
puts result.results
# => [{"flagged" => false, "categories" => {...}, "category_scores" => {...}}]

# Get basic information
puts "Moderation ID: #{result.id}"     # => "modr-ABC123..."
puts "Model used: #{result.model}"     # => "omni-moderation-latest"
```

The `moderate` method returns a `RubyLLM::Moderation` object containing the moderation results from the provider.

## Understanding Moderation Results

Moderation results include categories and confidence scores for different types of potentially harmful content:

```ruby
result = RubyLLM.moderate("Some user input text")

# Check overall flagging status
if result.flagged?
  puts "Content was flagged for: #{result.flagged_categories.join(', ')}"
else
  puts "Content appears safe"
end

# Examine category scores (0.0 to 1.0, higher = more likely)
scores = result.category_scores
puts "Sexual content score: #{scores['sexual']}"
puts "Harassment score: #{scores['harassment']}"
puts "Violence score: #{scores['violence']}"

# Get boolean flags for each category
categories = result.categories
puts "Contains hate speech: #{categories['hate']}"
puts "Contains self-harm content: #{categories['self-harm']}"
```

### Moderation Categories

Current moderation models typically check for these categories:

- **Sexual**: Sexually explicit or suggestive content
- **Hate**: Content that promotes hate based on identity
- **Harassment**: Content intended to harass, threaten, or bully
- **Self-harm**: Content promoting self-harm or suicide
- **Sexual/minors**: Sexual content involving minors
- **Hate/threatening**: Hateful content that includes threats
- **Violence**: Content promoting or glorifying violence
- **Violence/graphic**: Graphic violent content
- **Self-harm/intent**: Content expressing intent to self-harm
- **Self-harm/instructions**: Instructions for self-harm
- **Harassment/threatening**: Harassing content that includes threats

## Alternative Calling Methods

You can also use the class method directly:

```ruby
# Direct class method
result = RubyLLM::Moderation.moderate("Your content here")

# With explicit model specification
result = RubyLLM.moderate(
  "User message",
  model: "text-moderation-007",
  provider: "openai"
)

# Using assume_model_exists for custom models
result = RubyLLM.moderate(
  "Content to check",
  provider: "openai",
  assume_model_exists: true
)
```

## Choosing Models

By default, RubyLLM uses OpenAI's latest moderation model (`omni-moderation-latest`), but you can specify different models:

```ruby
# Use a specific OpenAI moderation model
result = RubyLLM.moderate(
  "Content to moderate",
  model: "text-moderation-007"
)

# Configure the default moderation model globally
RubyLLM.configure do |config|
  config.default_moderation_model = "text-moderation-007"
end
```

Refer to the [Available Models Reference]({% link _reference/available-models.md %}) for details on moderation models and their capabilities.

## Integration Patters

### Pre-Chat Moderation

Use moderation as a safety layer before sending user input to LLMs:

```ruby
def safe_chat_response(user_input)
  # Check content safety first
  moderation = RubyLLM.moderate(user_input)

  if moderation.flagged?
    flagged_categories = moderation.flagged_categories.join(', ')
    return {
      error: "Content flagged for: #{flagged_categories}",
      safe: false
    }
  end

  # Content is safe, proceed with chat
  response = RubyLLM.chat.ask(user_input)
  {
    content: response.content,
    safe: true
  }
end
```

### Custom Threshold Handling

You might want to implement custom logic based on category scores:

```ruby
def assess_content_risk(text)
  result = RubyLLM.moderate(text)
  scores = result.category_scores

  # Custom thresholds for different risk levels
  high_risk = scores.any? { |_, score| score > 0.8 }
  medium_risk = scores.any? { |_, score| score > 0.5 }

  case
  when high_risk
    { risk: :high, action: :block, message: "Content blocked" }
  when medium_risk
    { risk: :medium, action: :review, message: "Content flagged for review" }
  else
    { risk: :low, action: :allow, message: "Content approved" }
  end
end

# Usage
assessment = assess_content_risk("Some user input")
puts "Risk level: #{assessment[:risk]}"
puts "Action: #{assessment[:action]}"
```

## Error Handling

Handle moderation errors gracefully:

```ruby
begin
  result = RubyLLM.moderate("User content")

  if result.flagged?
    handle_unsafe_content(result)
  else
    process_safe_content(content)
  end
rescue RubyLLM::ConfigurationError => e
  # Handle missing API key or configuration
  logger.error "Moderation not configured: #{e.message}"
  # Fallback: proceed with caution or block all content
rescue RubyLLM::RateLimitError => e
  # Handle rate limits
  logger.warn "Moderation rate limited: #{e.message}"
  # Fallback: temporary approval or queue for later
rescue RubyLLM::Error => e
  # Handle other API errors
  logger.error "Moderation failed: #{e.message}"
  # Fallback: proceed with caution
end
```

## Configuration Requirements

Content moderation currently requires an OpenAI API key:

```ruby
RubyLLM.configure do |config|
  config.openai_api_key = ENV['OPENAI_API_KEY']

  # Optional: set default moderation model
  config.default_moderation_model = "omni-moderation-latest"
end
```

For more details about OpenAI's moderation capabilities and policies, see the [OpenAI Moderation Guide](https://platform.openai.com/docs/guides/moderation).

> Moderation API calls are typically less expensive than chat completions and have generous rate limits, making them suitable for screening all user inputs.
{: .note }

## Best Practices

### Content Safety Strategy

- **Always moderate user-generated content** before sending to LLMs
- **Handle false positives gracefully** with human review processes
- **Log moderation decisions** for auditing and improvement
- **Provide clear feedback** to users about content policies

### Performance Considerations

- **Cache moderation results** for repeated content (with appropriate TTL)
- **Use background jobs** for non-blocking moderation of large volumes
- **Implement fallbacks** for when moderation services are unavailable

### User Experience

```ruby
def user_friendly_moderation(content)
  result = RubyLLM.moderate(content)

  return { approved: true } unless result.flagged?

  # Provide specific, actionable feedback
  categories = result.flagged_categories
  message = case
  when categories.include?('harassment')
    "Please keep interactions respectful and constructive."
  when categories.include?('sexual')
    "This content appears inappropriate for our platform."
  when categories.include?('violence')
    "Please avoid content that promotes violence or harm."
  else
    "This content doesn't meet our community guidelines."
  end

  {
    approved: false,
    message: message,
    categories: categories
  }
end
```

## Rails Integration

When using moderation in Rails applications:

```ruby
# In a controller or service
class MessageController < ApplicationController
  def create
    content = params[:message]

    moderation_result = RubyLLM.moderate(content)

    if moderation_result.flagged?
      render json: {
        error: "Message not allowed",
        categories: moderation_result.flagged_categories
      }, status: :unprocessable_entity
    else
      # Process the safe message
      message = Message.create!(content: content, user: current_user)
      render json: message, status: :created
    end
  end
end

# Background job for batch moderation
class ModerationJob < ApplicationJob
  def perform(message_ids)
    messages = Message.where(id: message_ids)

    messages.each do |message|
      result = RubyLLM.moderate(message.content)
      message.update!(
        moderation_flagged: result.flagged?,
        moderation_categories: result.flagged_categories,
        moderation_scores: result.category_scores
      )
    end
  end
end
```

This allows you to build robust content safety systems that protect both your application and your users while maintaining a good user experience.
