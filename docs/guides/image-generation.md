---
layout: default
title: Image Generation
parent: Guides
nav_order: 6
permalink: /guides/image-generation
---

# Image Generation
{: .no_toc }

RubyLLM makes it easy to generate images using AI models like DALL-E 3 and Google's Imagen. This guide explains how to create images and customize the generation process.
{: .fs-6 .fw-300 }

## Table of contents
{: .no_toc .text-delta }

1. TOC
{:toc}

---

After reading this guide, you will know:

*   How to generate images from text prompts.
*   How to select different image generation models.
*   How to specify image sizes (for supported models).
*   How to access and save generated image data (URL or Base64).
*   How to integrate image generation with Rails Active Storage.
*   Tips for writing effective image prompts.
*   How to handle errors during image generation.

## Basic Image Generation

The simplest way to generate an image is using the global `RubyLLM.paint` method:

```ruby
# Generate an image using the default image model (usually DALL-E 3)
image = RubyLLM.paint("A photorealistic image of a red panda coding Ruby on a laptop")

# For models returning a URL (like DALL-E):
if image.url
  puts "Image URL: #{image.url}"
  # => "https://oaidalleapiprodscus.blob.core.windows.net/..."
end

# For models returning Base64 data (like Imagen):
if image.base64?
  puts "MIME Type: #{image.mime_type}" # => "image/png" or similar
  puts "Data size: ~#{image.data.length} bytes"
end

# Some models revise the prompt for better results (DALL-E 3 does this)
if image.revised_prompt
  puts "Revised Prompt: #{image.revised_prompt}"
  # => "A photorealistic depiction of a red panda intently coding Ruby..."
end

puts "Model Used: #{image.model_id}"
```

The `paint` method abstracts the differences between provider APIs.

## Choosing Models

By default, RubyLLM uses the model specified in `config.default_image_model` (defaults to `dall-e-3`), but you can specify a different one.

```ruby
# Explicitly use DALL-E 3
image_dalle = RubyLLM.paint(
  "Impressionist painting of a Parisian cafe",
  model: "dall-e-3"
)

# Use Google's Imagen 3
image_imagen = RubyLLM.paint(
  "Cyberpunk city street at night, raining, neon signs",
  model: "imagen-3.0-generate-002"
)

# Use a model not in the registry (useful for custom endpoints)
image_custom = RubyLLM.paint(
  "A sunset over mountains",
  model: "my-custom-image-model",
  provider: :openai,
  assume_model_exists: true
)
```

You can configure the default model globally:

```ruby
RubyLLM.configure do |config|
  config.default_image_model = "dall-e-3" # Or another available image model ID
end
```

Refer to the [Working with Models Guide]({% link guides/models.md %}) and the [Available Models Guide]({% link guides/available-models.md %}) to find image models.

## Image Sizes

Some models, like DALL-E 3, allow you to specify the desired image dimensions via the `size:` argument.

```ruby
# Standard square (1024x1024 - default for DALL-E 3)
image_square = RubyLLM.paint("a fluffy white cat", size: "1024x1024")

# Wide landscape (1792x1024 for DALL-E 3)
image_landscape = RubyLLM.paint(
  "a panoramic mountain landscape at dawn",
  size: "1792x1024"
)

# Tall portrait (1024x1792 for DALL-E 3)
image_portrait = RubyLLM.paint(
  "a knight standing before a castle gate",
  size: "1024x1792"
)
```

{: .note }
Not all models support size customization. If a size is specified for a model that doesn't support it (like Google Imagen), RubyLLM may log a debug message indicating the size parameter is ignored. Check the provider's documentation or the [Available Models Guide]({% link guides/available-models.md %}) for supported sizes.

## Working with Generated Images

The `RubyLLM::Image` object provides access to the generated image data and metadata.

### Accessing Image Data

*   `image.url`: Returns the URL for providers like OpenAI (DALL-E). `nil` otherwise.
*   `image.data`: Returns the Base64-encoded image data string for providers like Google (Imagen). `nil` otherwise.
*   `image.mime_type`: Returns the MIME type (e.g., `"image/png"`, `"image/jpeg"`).
*   `image.base64?`: Returns `true` if the image data is Base64-encoded, `false` otherwise.

### Saving Images Locally

The `save` method works regardless of whether the image was delivered via URL or Base64. It fetches the data if necessary and writes it to the specified file path.

```ruby
# Generate an image (works for DALL-E or Imagen)
image = RubyLLM.paint("A steampunk mechanical owl")

# Save the image to a local file
begin
  saved_path = image.save("steampunk_owl.png")
  puts "Image saved to #{saved_path}"
rescue => e
  puts "Failed to save image: #{e.message}"
end
```

### Getting Raw Image Blob

The `to_blob` method returns the raw binary image data (decoded from Base64 or downloaded from URL). This is useful for integration with other libraries or frameworks.

```ruby
image = RubyLLM.paint("Abstract geometric patterns in pastel colors")
image_blob = image.to_blob

# Now you can use image_blob, e.g., upload to S3, process with MiniMagick, etc.
puts "Image blob size: #{image_blob.bytesize} bytes"
```

### Rails Active Storage Integration

Use `to_blob` to easily attach generated images to Active Storage attributes.

```ruby
# In a Rails model or job
class Product < ApplicationRecord
  has_one_attached :generated_image
end

def generate_and_attach_image(product, prompt)
  puts "Generating image for Product #{product.id}..."
  image = RubyLLM.paint(prompt, model: 'dall-e-3') # Or another model

  filename = "#{product.slug}-#{Time.current.to_i}.png"

  # Use StringIO to provide an IO object to Active Storage
  image_io = StringIO.new(image.to_blob)

  product.generated_image.attach(
    io: image_io,
    filename: filename,
    content_type: image.mime_type || 'image/png' # Use detected MIME type or default
  )

  puts "Image attached successfully."

  # Optionally save metadata
  product.update(
    image_prompt: prompt,
    image_revised_prompt: image.revised_prompt,
    image_model: image.model_id
  )
rescue RubyLLM::Error => e
  puts "Image generation failed: #{e.message}"
  # Handle error appropriately
rescue => e
  puts "Failed to attach image: #{e.message}"
  # Handle attachment error
end

# Usage:
# product = Product.find(1)
# generate_and_attach_image(product, "A sleek, modern logo for 'RubyLLM'")
```

## Prompt Engineering for Images

Crafting effective prompts is key to getting the desired image. Be descriptive!

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

**Tips for Better Prompts:**

*   **Subject:** Be specific (e.g., "red panda" vs. "animal").
*   **Action/Setting:** Describe what's happening and where (e.g., "coding on a laptop in a cozy library").
*   **Style:** Specify artistic style ("photorealistic", "watercolor", "pixel art", "impressionist painting", "3D render").
*   **Details:** Add adjectives ("fluffy", "ancient", "glowing", "minimalist").
*   **Composition:** Mention framing ("close-up", "wide angle", "overhead shot").
*   **Lighting:** Describe the light ("soft morning light", "dramatic sunset", "neon glow").
*   **Mood:** Convey the feeling ("serene", "chaotic", "mysterious").

## Error Handling

Wrap `paint` calls in `begin/rescue` blocks.

```ruby
begin
  image = RubyLLM.paint("A plausible prompt")
  puts "Image URL: #{image.url}"
rescue RubyLLM::UnauthorizedError
  puts "Error: Invalid API key."
rescue RubyLLM::BadRequestError => e
  # Often indicates a content policy violation
  puts "Error: Bad Request - #{e.message}"
  puts "Check if your prompt violates content safety policies."
rescue RubyLLM::RateLimitError
  puts "Error: Rate limit exceeded."
rescue RubyLLM::Error => e
  puts "Image generation failed: #{e.message}"
end
```

See the [Error Handling Guide]({% link guides/error-handling.md %}) for more details.

## Content Safety

AI image generation services have content safety filters. Prompts requesting harmful, explicit, or otherwise prohibited content will usually result in a `BadRequestError`. Avoid generating:

*   Violent or hateful imagery.
*   Sexually explicit content.
*   Images of real people (especially public figures without consent, though policies vary).
*   Direct copies of copyrighted characters or artwork.

## Performance Considerations

Image generation can take several seconds (typically 5-20 seconds depending on the model and load).

*   **Use Background Jobs:** In web applications, always perform image generation in a background job (like Sidekiq or GoodJob) to avoid blocking web requests.
*   **Timeouts:** Configure appropriate network timeouts in RubyLLM (see [Installation Guide]({% link installation.md %})).
*   **Caching:** Store generated images (e.g., using Active Storage, cloud storage) rather than regenerating them frequently if the prompt is the same.

## Next Steps

*   [Chatting with AI Models]({% link guides/chat.md %}): Learn about conversational AI.
*   [Embeddings]({% link guides/embeddings.md %}): Explore text vector representations.
*   [Error Handling]({% link guides/error-handling.md %}): Master handling API errors.