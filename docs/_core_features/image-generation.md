---
layout: default
title: Image Generation
nav_order: 5
description: Generate images from text descriptions using AI models like DALL-E 3 and Imagen
redirect_from:
  - /guides/image-generation
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

*   How to generate images from text prompts.
*   How to edit existing images with AI (local files and remote URLs).
*   How to select different image generation models.
*   How to specify image sizes (for supported models).
*   How to access and save generated image data (URL or Base64).
*   How to integrate image generation with Rails Active Storage.
*   Tips for writing effective image prompts.
*   How to handle errors during image generation and editing.

## Basic Image Generation

The simplest way to generate an image is using the global `RubyLLM.paint` method:

```ruby
# Generate an image using the default image model
image = RubyLLM.paint("A photorealistic image of a red panda coding Ruby on a laptop")

# For models returning a URL:
if image.url
  puts "Image URL: #{image.url}"
  # => "https://oaidalleapiprodscus.blob.core.windows.net/..."
end

# For models returning Base64 data (like Imagen):
if image.base64?
  puts "MIME Type: #{image.mime_type}" # => "image/png" or similar
  puts "Data size: ~#{image.data.length} bytes"
end

# Some models revise the prompt for better results
if image.revised_prompt
  puts "Revised Prompt: #{image.revised_prompt}"
  # => "A photorealistic depiction of a red panda intently coding Ruby..."
end

puts "Model Used: #{image.model_id}"
```

The `paint` method abstracts the differences between provider APIs.

## Image Editing

RubyLLM supports editing existing images using AI models like OpenAI's `gpt-image-1`. You can provide either local image files or remote URLs as the source image to edit.

### Editing Local Images

To edit a local image file, use the `with:` parameter to specify the path to your image:

```ruby
# Edit a local PNG file
image = RubyLLM.paint(
  "turn the logo to green", 
  with: "path/to/your/image.png",
  model: "gpt-image-1"
)

puts "Edited image generated!"
puts "MIME Type: #{image.mime_type}"
```

**Important Requirements for Local Images:**
- Only PNG, WEBP, or JPG files are supported for editing with gpt-image-1
- The file must exist and be readable

### Editing Remote Images

You can also edit images from remote URLs:

```ruby
# Edit an image from a remote URL
image = RubyLLM.paint(
  "make the background more vibrant",
  with: "https://example.com/image.png",
  model: "gpt-image-1"
)
```

**Requirements for Remote URLs:**
- The URL must return a PNG, WEBP, or JPG image
- The server must respond with a valid content type
- 404 errors will raise a `Faraday::ResourceNotFound` error
- Invalid content types will raise a `RubyLLM::BadRequestError`

### Editing Multiple Images

You can edit multiple images at once by providing an array of file paths or URLs:

```ruby
# Edit multiple images simultaneously
image = RubyLLM.paint(
  "apply a vintage filter to all images",
  with: [
    "path/to/first_image.png",
    "path/to/second_image.png"
  ],
  model: "gpt-image-1"
)
```

### Customizing Edit Parameters

The `params:` option allows you to customize the editing process:

```ruby
# Customize the editing output
image = RubyLLM.paint(
  "enhance the colors and add dramatic lighting",
  with: "path/to/image.png",
  model: "gpt-image-1",
  params: {
    size: "1024x1024",    # Output image size
    quality: "low"        # Quality setting (low, standard, hd)
  }
)

# Check usage information
puts "Output tokens: #{image.usage['output_tokens']}"
puts "Total cost: $#{image.total_cost}"
```

## Choosing Models

By default, RubyLLM uses the model specified in `config.default_image_model`, but you can specify a different one.

```ruby
# Explicitly use GPT-Image-1
image_dalle = RubyLLM.paint(
  "Impressionist painting of a Parisian cafe",
  model: "gpt-image-1"
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
  config.default_image_model = "gpt-image-1" # Or another available image model ID
end
```

Refer to the [Working with Models Guide]({% link _advanced/models.md %}) and the [Available Models Guide]({% link _reference/available-models.md %}) to find image models.

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

> Not all models support size customization. If a size is specified for a model that doesn't support it (like Google Imagen), RubyLLM may log a debug message indicating the size parameter is ignored. Check the provider's documentation or the [Available Models Guide]({% link _reference/available-models.md %}) for supported sizes.
{: .note }

## Working with Generated Images

The `RubyLLM::Image` object provides access to the generated image data and metadata.

### Accessing Image Data

*   `image.url`: Returns the URL for providers like OpenAI. `nil` otherwise.
*   `image.data`: Returns the Base64-encoded image data string for providers like Google (Imagen). `nil` otherwise.
*   `image.mime_type`: Returns the MIME type (e.g., `"image/png"`, `"image/jpeg"`).
*   `image.base64?`: Returns `true` if the image data is Base64-encoded, `false` otherwise.

### Saving Images Locally

The `save` method works regardless of whether the image was delivered via URL or Base64. It fetches the data if necessary and writes it to the specified file path.

```ruby
# Generate an image
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
  image = RubyLLM.paint(prompt) # Or another model

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

Image generation can fail due to content policy violations, rate limits, or API issues:

```ruby
begin
  image = RubyLLM.paint("Your prompt here")
  puts "Image URL: #{image.url}"
rescue RubyLLM::BadRequestError => e
  # Often indicates a content policy violation
  puts "Generation failed: #{e.message}"
rescue RubyLLM::Error => e
  puts "Error: #{e.message}"
end
```

See the [Error Handling Guide]({% link _advanced/error-handling.md %}) for comprehensive error handling strategies.

## Content Safety

AI image generation and editing services have content safety filters. Prompts requesting harmful, explicit, or otherwise prohibited content will usually result in a `BadRequestError`. Avoid generating or editing:

*   Violent or hateful imagery.
*   Sexually explicit content.
*   Images of real people (especially public figures without consent, though policies vary).
*   Direct copies of copyrighted characters or artwork.

**Additional considerations for image editing:**
*   Be mindful of editing copyrighted images without permission.
*   Some providers may have stricter policies for editing existing images versus generating new ones.

## Performance Considerations

Image generation and editing can take several seconds (typically 5-20 seconds depending on the model and load).

*   **Use Background Jobs:** In web applications, always perform image generation and editing in a background job (like Sidekiq or GoodJob) to avoid blocking web requests.
*   **Timeouts:** Configure appropriate network timeouts in RubyLLM (see [Configuration Guide]({% link _getting_started/configuration.md %})).
*   **Caching:** Store generated and edited images (e.g., using Active Storage, cloud storage) rather than regenerating them frequently if the prompt is the same.
*   **Image Editing Considerations:** When editing remote images, factor in additional time for downloading the source image before processing begins.

## Next Steps

*   [Chatting with AI Models]({% link _core_features/chat.md %}): Learn about conversational AI.
*   [Embeddings]({% link _core_features/embeddings.md %}): Explore text vector representations.
*   [Error Handling]({% link _advanced/error-handling.md %}): Master handling API errors.