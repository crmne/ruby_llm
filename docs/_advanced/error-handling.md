---
layout: default
title: Error Handling
nav_order: 3
description: Learn how to handle errors gracefully when working with AI providers
redirect_from:
  - /guides/error-handling
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

*   RubyLLM's error hierarchy.
*   How to rescue specific types of errors.
*   How to access details from the original API response.
*   How errors are handled during streaming.
*   Best practices for handling errors within Tools.
*   RubyLLM's automatic retry behavior.
*   How to enable debug logging.

## RubyLLM Error Hierarchy

All errors raised directly by RubyLLM inherit from `RubyLLM::Error`. Specific errors map to common HTTP status codes or library-specific issues:

```ruby
RubyLLM::Error                    # Base error class for API/network issues
    RubyLLM::BadRequestError      # 400: Invalid request parameters
    RubyLLM::UnauthorizedError    # 401: API key issues
    RubyLLM::PaymentRequiredError # 402: Billing issues
    RubyLLM::ForbiddenError       # 403: Permission issues
    RubyLLM::RateLimitError       # 429: Rate limit exceeded
    RubyLLM::ServerError          # 500: Provider server error
    RubyLLM::ServiceUnavailableError # 502/503: Service unavailable
    RubyLLM::OverloadedError      # 529: Service overloaded (Specific providers)

# Non-API Errors (inherit from StandardError)
RubyLLM::ConfigurationError   # Missing required configuration (e.g., API key)
RubyLLM::ModelNotFoundError   # Requested model ID not found in registry
RubyLLM::InvalidRoleError     # Invalid role symbol used for a message
```

## Basic Error Handling

The fundamental way to handle errors is using Ruby's `begin`/`rescue` block. Catching the base `RubyLLM::Error` will handle most API-related issues.

```ruby
begin
  chat = RubyLLM.chat
  response = chat.ask "Translate 'hello' to French."
  puts response.content
rescue RubyLLM::Error => e
  # Generic handling for API errors
  puts "An API error occurred: #{e.message}"
  # Log the error for debugging
  # logger.error "RubyLLM API Error: #{e.class} - #{e.message}"
rescue RubyLLM::ConfigurationError => e
  # Handle missing configuration
  puts "Configuration missing: #{e.message}"
  # Abort or prompt for configuration
end
```

## Handling Specific Errors

For more granular control, rescue specific error classes. This allows you to implement different recovery strategies based on the error type.

```ruby
begin
  chat = RubyLLM.chat
  response = chat.ask "Generate a complex report."
rescue RubyLLM::UnauthorizedError
  puts "Authentication failed. Please check your API key configuration."
  # Maybe exit or redirect to config settings
rescue RubyLLM::PaymentRequiredError
  puts "Payment required. Please check your provider account balance or plan."
  # Notify admin or user
rescue RubyLLM::RateLimitError
  puts "Rate limit hit. Please wait a moment before trying again."
  # Implement backoff/retry logic (though RubyLLM has some built-in retries)
rescue RubyLLM::ServiceUnavailableError
  puts "The AI service is temporarily unavailable. Please try again later."
  # Maybe offer a fallback or notify user
rescue RubyLLM::BadRequestError => e
  puts "Invalid request sent to the API: #{e.message}"
  # Check the data being sent
rescue RubyLLM::ModelNotFoundError => e
  puts "Error: #{e.message}. Check available models with RubyLLM.models.all"
rescue RubyLLM::Error => e
  # Catch any other API errors
  puts "An unexpected API error occurred: #{e.message}"
end
```

## Accessing API Response Details

Instances of `RubyLLM::Error` (and its subclasses related to API responses) hold the original `Faraday::Response` object in the `response` attribute. This can be useful for debugging or extracting provider-specific error codes.

```ruby
begin
  chat = RubyLLM.chat(model: '{{ site.models.default_chat }}') # Assume this requires a specific org sometimes
  response = chat.ask "Some specific query"
rescue RubyLLM::ForbiddenError => e
  puts "Access forbidden: #{e.message}"
  # Inspect the raw response body for provider-specific details
  if e.response&.body&.include?('invalid_organization')
    puts "Hint: Check if your API key is enabled for the correct OpenAI organization."
  end
  puts "Status Code: #{e.response&.status}"
  # puts "Full Response Body: #{e.response&.body}" # For deep debugging
end
```

## Error Handling During Streaming

When using streaming with a block, errors can occur *during* the stream after some chunks have already been processed. The `ask` method will raise the error *after* the block execution finishes or is interrupted by the error.

```ruby
begin
  chat = RubyLLM.chat
  accumulated_content = ""
  chat.ask "Generate a very long story..." do |chunk|
    print chunk.content
    accumulated_content << chunk.content
    # Simulate an error occurring mid-stream (e.g., network drop)
    # In a real scenario, the error would be raised by the underlying HTTP request
  end
  puts "\nStream completed successfully."
rescue RubyLLM::RateLimitError
  puts "\nStream interrupted by rate limit. Partial content received:"
  puts accumulated_content
rescue RubyLLM::Error => e
  puts "\nStream failed: #{e.message}. Partial content received:"
  puts accumulated_content
end
```

Your block will execute for chunks received *before* the error. The final return value of `ask` when an error occurs during streaming might be unpredictable (often `nil`), so rely on the rescued exception for error handling.

## Handling Errors Within Tools

When building [Tools]({% link _core_features/tools.md %}), you need to decide how errors within the tool's `execute` method should be handled:

1.  **Return Error to LLM:** If the error is something the LLM might be able to recover from (e.g., invalid parameters provided by the LLM, temporary lookup failure), return a Hash containing an `:error` key. The LLM will see this error message as the tool's output and may try again or use a different approach.

    ```ruby
    class Weather < RubyLLM::Tool
      # ... params ...
      def execute(location:)
        if location.blank?
          return { error: "Location cannot be blank. Please provide a city name." }
        end
        # ... perform API call ...
      rescue Faraday::TimeoutError
        { error: "Weather API timed out. Please try again later." }
      end
    end
    ```

2.  **Raise Error for Application:** If the error indicates a problem with the tool itself or the application's state (e.g., database connection lost, configuration error, unrecoverable external API failure), `raise` an exception as normal. This will halt the RubyLLM interaction and bubble up to your application's main error handling (`begin/rescue`).

    ```ruby
    class DatabaseQueryTool < RubyLLM::Tool
      # ... params ...
      def execute(query:)
        User.find_by_sql(query) # Example query
      rescue ActiveRecord::ConnectionNotEstablished => e
        # This is likely an application-level problem, not something the LLM can fix.
        raise e # Let the application's error handling take over.
      rescue StandardError => e
        # Maybe return less critical errors to the LLM
        { error: "Database query failed: #{e.message}" }
      end
    end
    ```

Distinguishing between these helps the LLM work effectively with recoverable issues while ensuring critical application failures are handled appropriately.

## Automatic Retries

RubyLLM automatically retries requests that fail due to transient network or server issues using Faraday's retry middleware.

Retries are attempted for:

*   Network timeouts (`Timeout::Error`, `Faraday::TimeoutError`, `Errno::ETIMEDOUT`)
*   Connection failures (`Faraday::ConnectionFailed`)
*   Rate limit errors (`RubyLLM::RateLimitError` / HTTP 429)
*   Server-side errors (`RubyLLM::ServerError`, `RubyLLM::ServiceUnavailableError`, `RubyLLM::OverloadedError` / HTTP 500, 502, 503, 504, 529)

You can configure retry behavior via `RubyLLM.configure`:

```ruby
RubyLLM.configure do |config|
  config.max_retries = 5 # Default: 3
  config.retry_interval = 0.5 # Default: 0.1
  # config.retry_backoff_factor = 2 # Default: 2
  # config.retry_interval_randomness = 0.5 # Default: 0.5
end
```

## Debugging

If you encounter unexpected errors or behavior, enable debug logging by setting the `RUBYLLM_DEBUG` environment variable:

```bash
export RUBYLLM_DEBUG=true
# Now run your Ruby script or Rails server
```

This will cause RubyLLM to log detailed information about API requests and responses, including headers and bodies (with sensitive data like API keys filtered), which can be invaluable for troubleshooting.

## Best Practices

*   **Be Specific:** Rescue specific error classes whenever possible for tailored recovery logic.
*   **Log Errors:** Always log errors, including relevant context (model used, input data if safe) for debugging. Consider using the `response` attribute on `RubyLLM::Error` for more details.
*   **User Feedback:** Provide clear, user-friendly feedback when an AI operation fails. Avoid exposing raw API error messages directly.
*   **Fallbacks:** Consider fallback mechanisms (e.g., trying a different model, using cached data, providing a default response) if the AI service is critical to your application's function.
*   **Monitor:** Track the frequency of different error types in production to identify recurring issues with providers or your implementation.

## Next Steps

*   [Using Tools]({% link _core_features/tools.md %})
*   [Streaming Responses]({% link _core_features/streaming.md %})
*   [Rails Integration]({% link _advanced/rails.md %})