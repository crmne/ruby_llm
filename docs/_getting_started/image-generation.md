---
layout: default
title: Image Generation
nav_order: 7
description: Generate and edit images from text prompts, reference images, and masks
redirect_from:
  - /guides/image-generation
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

*   How to generate images from text prompts.
*   How to generate several images from one prompt in a single request.
*   How to edit existing images with source images and masks.
*   How to select different image generation models.
*   How to fall back to another model when one is busy.
*   How to specify image sizes (for supported models).
*   How to inspect token usage and calculate image costs.
*   How to save images to disk or attach them with Rails Active Storage.
*   How to handle errors during image generation.

## Basic Image Generation

Describe the image you want, then save it:

```ruby
image = RubyLLM.paint "A red panda coding Ruby on a laptop, watercolor"
image.save "red_panda.png"
```

`save` handles both hosted URLs and inline image data.

## Generating Several Images at Once

Pass `count:` to request several images in one call. RubyLLM returns an array when the request comes back with several images, and a single image otherwise:

```ruby
images = RubyLLM.paint("a siamese cat", model: "{{ site.models.image_openai }}", count: 4)

images.each_with_index do |image, index|
  image.save("cat-#{index}.png")
end
```

Providers that generate one image per request (Stable Diffusion on Bedrock, ElevenLabs, and OpenRouter) raise `ArgumentError` when `count:` is above 1.

Usage for the request lives on the first image. Read `images.first.cost.total`; it is `nil` when pricing or usage is unavailable.
{: .note }

## Token Usage and Costs

When providers return image token usage, images expose the same cost shape as chats and messages:

```ruby
image = RubyLLM.paint("A small watercolor robot", model: "{{ site.models.image_openai }}")

image.tokens.input
image.tokens.output

image.cost.input
image.cost.output
image.cost.total
```

See [Tokens and Costs]({% link _core_features/cost-and-usage-tracking.md %}) for usage accounting.

## Editing Existing Images

Some models, such as OpenAI's GPT Image models, can edit an existing image instead of generating from scratch. Use `with:` to pass one or more source images, and `mask:` when you want to constrain which parts of the image may change.

```ruby
image = RubyLLM.paint(
  "Turn the logo green and keep the background transparent",
  model: "{{ site.models.image_openai }}",
  with: "logo.png"
)
```

`with:` accepts the same kinds of sources RubyLLM already supports elsewhere for attachments: local files, URLs, IO-like objects, `RubyLLM::Attachment` objects, and Active Storage attachments.

### Editing With Multiple Images

```ruby
image = RubyLLM.paint(
  "Combine these references into a postcard illustration",
  model: "{{ site.models.image_openai }}",
  with: ["person.png", "style-reference.png"]
)
```

### Editing With a Mask

```ruby
image = RubyLLM.paint(
  "Replace only the background with a sunset sky",
  model: "{{ site.models.image_openai }}",
  with: "portrait.png",
  mask: "portrait-mask.png",
  size: "1024x1024"
)
```

## Choosing Models

Pass `model:` to choose an image model:

```ruby
RubyLLM.paint("A mountain village at sunrise", model: "{{ site.models.image_google }}")
```

Set `default_image_model` in [Configuration]({% link _getting_started/configuration.md %}#default-models) to change the default. Find image models on the [Models]({% link _reference/available-models.md %}) page. For hosted deployments, pass `provider:` explicitly; see [Model Resolution]({% link _reference/model-resolution.md %}).

Mistral accepts a chat model for image generation:

```ruby
RubyLLM.paint("A red panda drawing a Ruby logo",
              model: "{{ site.models.mistral_provider_tools }}")
```

ElevenLabs does not list image models through its model-listing endpoint. Pass a documented image model with `assume_model_exists: true`:

```ruby
RubyLLM.paint("A small red ruby on a white background",
              model: "{{ site.models.image_elevenlabs }}",
              provider: :elevenlabs, assume_model_exists: true)
```

Configure the required [Image & Video plan and permissions]({% link _reference/configuration-providers.md %}#media-generation). You can reuse [uploaded media assets]({% link _core_features/files.md %}#elevenlabs-media-assets) as inputs.

### Falling Back to Another Model

Image models hit rate limits and overload like any other. Pass `fallbacks:` to try other models, in order, when one fails:

```ruby
RubyLLM.paint("A mountain village at sunrise",
              model: "{{ site.models.image_openai }}",
              fallbacks: ["{{ site.models.image_google }}"])
```

Each fallback gets the same prompt and options, and runs only after an error that [chat fallbacks]({% link _advanced/error-handling.md %}#model-fallbacks) move on from by default: a rate limit, a server error, an overloaded or unavailable service, or a connection failure. A rejected prompt raises at once. A fallback can be a model ID or a `RubyLLM::Model`, and one whose model can't be found is skipped. When every model fails, the last error is raised.

While a fallback is left, a timeout, a failed connection, or a rate limit that asks you to wait more than 2 seconds moves on to it at once instead of being [retried]({% link _advanced/error-handling.md %}#automatic-retries) on the same model, as it does for chats. A shorter wait, or an error without one, is retried on the same model first. The last model retries as configured.

Each attempt has its own `image.ruby_llm` event and usage entry, so failed attempts the provider billed still reach your [usage tracking]({% link _core_features/cost-and-usage-tracking.md %}).

## Image Sizes

Pass `size:` to choose dimensions supported by your model:

```ruby
image = RubyLLM.paint(
  "A panoramic mountain landscape at dawn",
  model: "{{ site.models.image_openai }}",
  size: "1536x1024"
)
```

For Gemini, you can specify an aspect ratio or resolution tier:

```ruby
image = RubyLLM.paint(
  "A red ruby gemstone on white",
  model: "{{ site.models.image_google }}",
  size: "16:9"
)
```

Gemini image models also accept `"1K"`, `"2K"`, and `"4K"`, and OpenRouter accepts tiers and pixel dimensions where the model supports them. Gemini, Imagen, ElevenLabs, and Stable Diffusion on Bedrock interpret pixel dimensions as an aspect ratio; the model may return different dimensions. Bedrock image editing controls its own output size, so leave `size:` unset when editing. Omit `size:` to let a model choose.

## Working with Generated Images

### Saving Images Locally

```ruby
image.save "illustration.png"
```

`save` returns the path you passed. Keep the extension consistent with `image.mime_type`, and save hosted images before their URLs expire.

### Getting Raw Image Blob

Use `to_blob` when another library or storage service needs the image bytes:

```ruby
image_bytes = image.to_blob
```

### Rails Active Storage Integration

Attach a generated image to your own model:

```ruby
class Product < ApplicationRecord
  has_one_attached :illustration
end
```

```ruby
image = RubyLLM.paint "A hand-drawn illustration of #{product.name}"

product.illustration.attach(
  io: StringIO.new(image.to_blob),
  filename: "illustration.png",
  content_type: image.mime_type
)
```

Here `product` is an existing `Product` record. Run generation in a background job when a web request should return immediately.

### Image Metadata

| Reader | Value |
| --- | --- |
| `image.model` | The model that generated the image. |
| `image.mime_type` | The image's MIME type, such as `"image/png"`. |
| `image.revised_prompt` | The provider's rewritten prompt, when reported. |
| `image.url` | A hosted image URL, when returned. |
| `image.data` | Base64-encoded image data, when returned inline. |
| `image.base64?` | Whether inline data is available. |

Use `save` or `to_blob` to read the image without branching on its delivery format.

## Errors and Background Work

Generation and downloads can fail, so let your job or request handle the error where it can retry or report the failure. RubyLLM raises `RubyLLM::BadRequestError` for rejected requests and other `RubyLLM::Error` subclasses for provider failures. See [Error Handling]({% link _advanced/error-handling.md %}) for retries and specific exceptions.

Store generated images for reuse. For jobs that need a longer request timeout, see [Connection Settings]({% link _reference/configuration-connection.md %}#connection-settings).

## Next Steps

*   [Video Generation]({% link _advanced/video-generation.md %}) - animate an image you have generated.
*   [Attachments]({% link _core_features/attachments.md %}) - ask a model about an image.
*   [Rails Integration]({% link _getting_started/rails.md %}) - use media generation in your application jobs.
