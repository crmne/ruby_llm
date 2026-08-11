---
layout: default
title: Video Generation
nav_order: 4
description: Generate short video clips from text prompts and reference images with Veo, Grok Imagine, and Sora
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

*   How to generate a video from a text prompt.
*   How to start a video job and collect the result later.
*   How to animate a still image into a video.
*   How to select video models and pass provider-specific options.
*   How to control polling and timeouts.
*   How to access and save generated video data.
*   How to handle errors during video generation.

## Basic Video Generation

Video generation is asynchronous on every provider: you submit a job, the provider renders the clip over the next seconds or minutes, and you download the result. `RubyLLM.animate` hides that lifecycle. It submits the job, polls until the video is ready, and returns a `RubyLLM::Video`:

```ruby
video = RubyLLM.animate("A paper boat sailing down a rainy gutter")

video.mime_type # => "video/mp4"
video.save("boat.mp4")
```

The call blocks for as long as the provider takes to render, typically under a minute for short clips. Because of that, run it from a background job in web applications, exactly as you would image generation.

## Generating Without Blocking

When you don't want to hold a thread while the provider renders, use `RubyLLM.animate_later`. It submits the same job and returns a `RubyLLM::VideoJob` immediately:

```ruby
job = RubyLLM.animate_later("A hummingbird hovering in slow motion")

job.id      # => "0eb6910f-a353-4699-9d1e-6a4f7a5b39e2"
job.status  # => :pending
job.done?   # => false
```

Poll the job whenever it suits you, from a scheduled job or a retry loop:

```ruby
job.refresh!
job.done?      # => true
job.completed? # => true

video = job.video
video.save("hummingbird.mp4")
```

`refresh!` re-fetches the job state from the provider and does nothing once the job is done. `video` returns `nil` while the job is pending and raises `RubyLLM::Error` when the job failed, with the provider's failure message. `wait!` runs the same polling loop `animate` uses, so `RubyLLM.animate(...)` is `RubyLLM.animate_later(...).wait!.video` with instrumentation around it.

## Animating a Still Image

Models that support image-to-video take a reference image through `with:`, the same option chats and image generation use for attachments:

```ruby
video = RubyLLM.animate(
  "Make the waterfall crash down and slowly pan out",
  model: "grok-imagine-video",
  with: "waterfall.png",
  provider_options: { duration: 5 }
)
```

`with:` accepts local files, URLs, and Active Storage attachments. Veo and Grok Imagine take a single reference image. OpenRouter takes up to two, used as the first and last frames of the clip. Passing a reference image to a model without image-to-video support raises `RubyLLM::UnsupportedAttachmentError`.

## Choosing Models

By default, RubyLLM uses the model in `config.default_video_model`. Pass `model:` to pick another one:

```ruby
video = RubyLLM.animate(
  "A time-lapse of a city skyline from day to night",
  model: "veo-3.1-fast-generate-preview"
)
```

You can change the default globally:

```ruby
RubyLLM.configure do |config|
  config.default_video_model = "grok-imagine-video"
end
```

These providers generate video through RubyLLM:

| Provider | Models | Notes |
| --- | --- | --- |
| Gemini | `veo-3.1-generate-preview`, `veo-3.1-fast-generate-preview`, `veo-3.1-lite-generate-preview` | 4, 6, or 8 second clips with audio |
| xAI | `grok-imagine-video`, `grok-imagine-video-1.5` | Clips up to 15 seconds, priced per second |
| OpenRouter | `x-ai/grok-imagine-video`, `google/veo-3.1-lite`, `openai/sora-2-pro`, and the rest of its video catalog | One API across many video models |
| Azure OpenAI | Sora deployments such as `sora-2` | Uses your deployment name as the model id |

Refer to the [Working with Models Guide]({% link _reference/models.md %}) for finding and filtering models, and [Model Resolution]({% link _reference/model-resolution.md %}) for how a model name and provider resolve.

## Provider Options

Durations, resolutions, and aspect ratios vary by provider, so they travel through `provider_options` in each provider's own request vocabulary:

```ruby
# xAI and OpenRouter take flat request fields
RubyLLM.animate(
  "A calm ocean wave at sunset",
  model: "grok-imagine-video",
  provider_options: { duration: 5, resolution: "720p" }
)

# Gemini nests Veo options under parameters
RubyLLM.animate(
  "A calm ocean wave at sunset",
  model: "veo-3.1-fast-generate-preview",
  provider_options: { parameters: { durationSeconds: 8, resolution: "1080p" } }
)

# Azure Sora takes explicit dimensions
RubyLLM.animate(
  "A calm ocean wave at sunset",
  model: "sora-2",
  provider: :azure,
  provider_options: { width: 480, height: 480, n_seconds: 5 }
)
```

> Video generation is priced per second of output on most providers, and resolution multiplies the rate. Check your provider's pricing page before rendering long or high-resolution clips.
{: .warning }

## Polling and Timeouts

While waiting, `animate` polls the job on an interval and gives up after a timeout, both configurable:

```ruby
RubyLLM.configure do |config|
  config.video_generation_timeout = 600      # seconds, default 600
  config.video_generation_poll_interval = 5  # seconds, default 5
end
```

When the timeout elapses, `animate` raises `RubyLLM::Error`. The provider keeps rendering; only the wait stops. `wait!` also accepts both values per call:

```ruby
job = RubyLLM.animate_later("A rocket launch seen from orbit")
job.wait!(timeout: 900, interval: 10)
```

## Working with Generated Videos

`RubyLLM::Video` mirrors `RubyLLM::Image`:

*   `video.url`: the hosted video URL, for providers that return one. `nil` otherwise.
*   `video.data`: the raw video bytes, for providers whose downloads require authentication. `nil` otherwise.
*   `video.mime_type`: the MIME type, such as `"video/mp4"`.
*   `video.duration`: the clip length in seconds, when the provider reports it.
*   `video.model`: the id of the model that rendered the clip.
*   `video.raw`: the provider's raw job response, for provider-specific fields such as reported cost.

`save` and `to_blob` work regardless of which form the provider returned:

```ruby
video = RubyLLM.animate("A steampunk mechanical owl taking flight")

video.save("owl.mp4")
blob = video.to_blob # => raw MP4 bytes
```

### Rails Active Storage Integration

Use `to_blob` to attach generated videos to Active Storage attributes:

```ruby
# app/jobs/generate_trailer_job.rb
class GenerateTrailerJob < ApplicationJob
  def perform(product, prompt)
    video = RubyLLM.animate(prompt)

    product.trailer.attach(
      io: StringIO.new(video.to_blob),
      filename: "#{product.slug}-trailer.mp4",
      content_type: video.mime_type
    )
  end
end
```

## Error Handling

Video generation fails for the same reasons image generation does, plus one of its own: the job itself can fail after it was accepted, for example when the content filter blocks the prompt mid-render. RubyLLM surfaces both as `RubyLLM::Error`:

```ruby
begin
  video = RubyLLM.animate("Your prompt here")
rescue RubyLLM::BadRequestError => e
  # The provider rejected the request up front
  puts "Request failed: #{e.message}"
rescue RubyLLM::Error => e
  # The job failed while rendering, or the wait timed out
  puts "Generation failed: #{e.message}"
end
```

Providers without video generation raise a clear error as well:

```ruby
RubyLLM.animate_later("A cat", model: "claude-sonnet-4-6")
# => RubyLLM::Error: Anthropic doesn't support video generation
```

See the [Error Handling Guide]({% link _advanced/error-handling.md %}) for comprehensive error handling strategies.

## What's Next?

*   [Image Generation]({% link _core_features/image-generation.md %}) - Generate the still images you can animate.
*   [Attachments]({% link _core_features/attachments.md %}) - Everything `with:` accepts across RubyLLM.
*   [Instrumentation]({% link _advanced/instrumentation.md %}) - Subscribe to the `video.ruby_llm` and `video_job.ruby_llm` events.
