---
layout: default
title: Image Generation
nav_order: 5
description: Generate and edit images from text prompts with GPT Image, Gemini, and Grok
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

`save` handles both hosted URLs and inline image data. You use the same two calls across image providers.

## Generating Several Images at Once

Pass `count:` to request several images in one call. RubyLLM returns an array when the request comes back with several images, and a single image otherwise:

```ruby
images = RubyLLM.paint("a siamese cat", model: "{{ site.models.image_openai }}", count: 4)

images.each_with_index do |image, index|
  image.save("cat-#{index}.png")
end
```

`count:` maps to each provider's own parameter: `n` on OpenAI and xAI, and `candidateCount` on Gemini image models. Providers that generate one image per request, such as OpenRouter, ignore it and return a single image.

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

Image costs use provider usage data plus pricing from the model registry. For models that report separate text and image input token details, RubyLLM applies the right pricing bucket to each part and returns the combined value as `image.cost.input`.

## Editing Existing Images

Some models, such as OpenAI's GPT Image models, can edit an existing image instead of generating from scratch. Use `with:` to pass one or more source images, and `mask:` when you want to constrain which parts of the image may change.

```ruby
image = RubyLLM.paint(
  "Turn the logo green and keep the background transparent",
  model: "{{ site.models.image_openai }}",
  with: "logo.png"
)
```

`with:` accepts the same kinds of sources RubyLLM already supports elsewhere for attachments: local files, URLs, IO-like objects, and Active Storage attachments.

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

By default, RubyLLM uses the model specified in `config.default_image_model`, but you can specify a different one.

```ruby
image_openai = RubyLLM.paint(
  "Impressionist painting of a Parisian cafe",
  model: "{{ site.models.image_openai }}"
)

image_google = RubyLLM.paint(
  "Cyberpunk city street at night, raining, neon signs",
  model: "{{ site.models.image_google }}"
)

# Use a model not in the registry (useful for custom endpoints)
image_custom = RubyLLM.paint(
  "A sunset over mountains",
  model: ENV.fetch("CUSTOM_IMAGE_MODEL"),
  provider: :openai,
  assume_model_exists: true
)
```

You can configure the default model globally:

```ruby
RubyLLM.configure do |config|
  config.default_image_model = "{{ site.models.default_image }}" # Or another available image model ID
end
```

Refer to the [Model Registry guide]({% link _reference/models.md %}) and the [Models]({% link _reference/available-models.md %}) page to find image models. See [Model Resolution]({% link _reference/model-resolution.md %}) for how a model name and provider resolve, including unlisted models.

## Image Sizes

Ask for the dimensions you want with the `size:` argument. Every provider that can size an image gets the value you pass. Leave it unset and RubyLLM sends no size at all, so the model returns whatever shape it prefers.

```ruby
# Standard square
image_square = RubyLLM.paint(
  "a fluffy white cat",
  model: "{{ site.models.image_dalle }}",
  size: "1024x1024"
)

# Wide landscape
image_landscape = RubyLLM.paint(
  "a panoramic mountain landscape at dawn",
  model: "{{ site.models.image_dalle }}",
  size: "1536x1024"
)

# Tall portrait
image_portrait = RubyLLM.paint(
  "a knight standing before a castle gate",
  model: "{{ site.models.image_dalle }}",
  size: "1024x1536"
)
```

Gemini sizes an image by aspect ratio and resolution tier rather than by pixel dimensions, so RubyLLM reduces the size you pass to the ratio it represents: `"1024x1024"` becomes `1:1`, `"1536x1024"` becomes `3:2`. You can also pass the ratio directly as `"16:9"`, or a resolution as `"1K"`, `"2K"` or `"4K"`. A size Gemini has no field for, such as `"large"`, raises `ArgumentError`. To let Gemini pick the shape itself, pass `size: nil`.

```ruby
image = RubyLLM.paint(
  "a red ruby gemstone on white",
  model: "{{ site.models.image_google }}",
  size: "16:9"
)
```

> Not every model accepts every size. The provider rejects a size it does not support, so check its documentation for its supported sizes. Pass `size: nil` to let the model choose its own shape.
{: .note }

## Working with Generated Images

### Saving Images Locally

```ruby
image.save "illustration.png"
```

`save` downloads or decodes the image and returns the path you passed. Keep the file extension consistent with `image.mime_type`.

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

## Prompt Engineering for Images

Describe the subject, composition, lighting, and style you want in the image.

```ruby
# Simple prompt - often yields generic results
image1 = RubyLLM.paint("dog")

# Detailed prompt - better results
image2 = RubyLLM.paint(
  "A photorealistic image of a golden retriever puppy playing fetch " \
  "in a sunny park, shallow depth of field, captured with a DSLR camera."
)

# Specify style
image3 = RubyLLM.paint(
  "A majestic mountain range, oil painting in the style of Bob Ross"
)
```

## Errors and Background Work

Generation and downloads can fail, so let your job or request handle the error where it can retry or report the failure. RubyLLM raises `RubyLLM::BadRequestError` for rejected requests and other `RubyLLM::Error` subclasses for provider failures. See [Error Handling]({% link _advanced/error-handling.md %}) for retries and specific exceptions.

Store generated images for reuse. For jobs that need a longer request timeout, see [Connection Settings]({% link _getting_started/configuration-connection.md %}#connection-settings).

## Next Steps

*   [Video Generation]({% link _core_features/video-generation.md %}) - animate an image you have generated.
*   [Attachments]({% link _core_features/attachments.md %}) - ask a model about an image.
*   [Rails Integration]({% link _advanced/rails.md %}) - use media generation in your application jobs.
