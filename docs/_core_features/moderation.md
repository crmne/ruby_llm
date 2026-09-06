---
layout: default
title: Moderation
nav_order: 10
description: Screen text and images for harmful content before it reaches your models
redirect_from:
  - /guides/moderation
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* How to screen text and images.
* How to read flagged categories and scores.
* How to check several inputs in one call.
* How to use moderation in your application's review process.
* How to choose and configure a moderation provider.

## Basic Content Moderation

Pass the content you want to check:

```ruby
result = RubyLLM.moderate "I love programming in Ruby."
result.flagged? # => false
```

`flagged?` reports the model's decision. Your application decides whether to publish the content, reject it, or send it for review.

## Understanding Moderation Results

Read the categories the model flagged and its scores:

```ruby
result = RubyLLM.moderate(user_input)
result.flagged_categories
result.category_scores
```

Categories depend on the provider and model. Common categories include harassment, hate, violence, sexual content, and self-harm. Scores are model outputs you can use in a review policy; tune any thresholds against examples from your own application.

### Checking Several Inputs

Send an array of texts to get a verdict for each one:

```ruby
comments = ["Great explanation!", "Can you add a Rails example?"]
moderation = RubyLLM.moderate(comments)

comments.zip(moderation.results).each do |text, verdict|
  puts "#{text}: #{verdict.flagged?}"
end
```

Each `RubyLLM::Moderation::Result` has `flagged?`, `categories`, and `category_scores`. The outer result aggregates them: `flagged?` is true if any input was flagged, `flagged_categories` combines their category names, and `category_scores` keeps the highest score per category.

## Moderating Images

Use `with:` for images, with or without a caption:

```ruby
result = RubyLLM.moderate("Photo for my profile", with: "profile.png")
result.flagged?
```

```ruby
result = RubyLLM.moderate(with: ["screenshot.png", "cover.png"])
result.flagged_categories
```

Choose a model that supports image moderation. Other attachment types raise `RubyLLM::UnsupportedAttachmentError`.

## Choosing Models

The default model is OpenAI's `{{ site.models.default_moderation }}`. Pass `model:` to use another moderation model:

```ruby
RubyLLM.moderate(user_input, model: "{{ site.models.default_moderation }}")
RubyLLM.moderate(user_input, model: "{{ site.models.moderation_mistral }}")
```

Configure the key for the provider you use and, optionally, a default model:

```ruby
RubyLLM.configure do |config|
  config.mistral_api_key = ENV.fetch('MISTRAL_API_KEY')
  config.default_moderation_model = "{{ site.models.moderation_mistral }}"
end
```

Pass `provider:` when you need to select the service explicitly. For unlisted models, see [Custom Endpoints]({% link _reference/custom-endpoints.md %}). Browse moderation models on the [Models]({% link _reference/available-models.md %}) page.

## Integration Patterns

### Pre-Chat Moderation

Check input before asking the chat to answer:

```ruby
def reply_to(text)
  moderation = RubyLLM.moderate(text)
  return "Please revise your message." if moderation.flagged?

  RubyLLM.chat.ask(text).content
end
```

### Reviewing Uploaded Images in Rails

Pass an Active Storage attachment directly, just as you pass a local file:

```ruby
class ReviewPhotoJob < ApplicationJob
  def perform(photo_id)
    photo = Photo.find(photo_id)
    result = RubyLLM.moderate(with: photo.image)
    photo.update!(needs_review: result.flagged?)
  end
end
```

This example assumes your `Photo` model has an `image` attachment and a `needs_review` boolean. The job records the decision without downloading or encoding the file in application code.

## Error Handling

A failed request gives you no moderation decision. Let the error reach your job's retry handler, or rescue it where your application can keep the content pending and report the problem. See [Error Handling]({% link _advanced/error-handling.md %}) for automatic retries and specific exceptions.

## Next Steps

* [Chat]({% link _core_features/chat.md %}) - check user input before starting a conversation.
* [Rails Integration]({% link _advanced/rails.md %}) - work with application records and attachments.
* [Image Generation]({% link _core_features/image-generation.md %}) - generate and edit images through the same framework.
