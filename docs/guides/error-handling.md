---
layout: default
title: Error Handling
parent: Guides
nav_order: 8
permalink: /guides/error-handling
---

# Error Handling

Proper error handling is crucial when working with AI services. RubyLLM provides a comprehensive error handling system that helps you build robust applications.

## Error Hierarchy

RubyLLM uses a structured error hierarchy:

```ruby
RubyLLM::Error                    # Base error class
    RubyLLM::BadRequestError      # Invalid request parameters (400)
    RubyLLM::UnauthorizedError    # API key issues (401)
    RubyLLM::PaymentRequiredError # Billing issues (402)
    RubyLLM::ForbiddenError       # Permission issues (403)
    RubyLLM::RateLimitError       # Rate limit exceeded (429)
    RubyLLM::ServerError          # Provider server error (500)
    RubyLLM::ServiceUnavailableError # Service unavailable (502/503)
    RubyLLM::OverloadedError      # Service overloaded (529)
    RubyLLM::ModelNotFoundError   # Invalid model ID
    RubyLLM::InvalidRoleError     # Invalid message role
```

## Basic Error Handling

Wrap your AI interactions in `begin/rescue` blocks:

```ruby
begin
  chat = RubyLLM.chat
  response = chat.ask "What's the capital of France?"
  puts response.content
rescue RubyLLM::Error => e
  puts "AI interaction failed: #{e.message}"
end
```

## Handling Specific Errors

Target specific error types for more precise handling:

```ruby
begin
  chat = RubyLLM.chat
  response = chat.ask "Generate a detailed analysis"
rescue RubyLLM::UnauthorizedError
  puts "Please check your API credentials"
rescue RubyLLM::PaymentRequiredError
  puts "Payment required - please check your account balance"
rescue RubyLLM::RateLimitError
  puts "Rate limit exceeded - please try again later"
rescue RubyLLM::ServiceUnavailableError
  puts "Service temporarily unavailable - please try again later"
rescue RubyLLM::BadRequestError => e
  puts "Bad request: #{e.message}"
rescue RubyLLM::Error => e
  puts "Other error: #{e.message}"
end
```

## API Response Details

The `Error` class contains the original response, allowing for detailed error inspection:

```ruby
begin
  chat = RubyLLM.chat
  chat.ask "Some question"
rescue RubyLLM::Error => e
  puts "Error: #{e.message}"
  puts "Status: #{e.response.status}"
  puts "Body: #{e.response.body}"
end
```

## Error Handling with Streaming

When using streaming, errors can occur during the stream:

```ruby
begin
  chat = RubyLLM.chat
  chat.ask "Generate a long response" do |chunk|
    print chunk.content
  end
rescue RubyLLM::Error => e
  puts "\nStreaming error: #{e.message}"
end
```

## Handling Tool Errors

When using tools, errors can be handled within the tool or in the calling code:

```ruby
# Error handling within tools
class Weather < RubyLLM::Tool
  description "Gets current weather for a location"
  param :latitude, desc: "Latitude (e.g., 52.5200)"
  param :longitude, desc: "Longitude (e.g., 13.4050)"

  def execute(latitude:, longitude:)
    url = "https://api.open-meteo.com/v1/forecast?latitude=#{latitude}&longitude=#{longitude}&current=temperature_2m,wind_speed_10m"

    response = Faraday.get(url)
    data = JSON.parse(response.body)
  rescue => e
    { error: e.message }
  end
end

# Error handling when using tools
begin
  chat = RubyLLM.chat.with_tool(Calculator)
  chat.ask "What's 1/0?"
rescue RubyLLM::Error => e
  puts "Error using tools: #{e.message}"
end
```

## Automatic Retries

RubyLLM automatically retries on certain transient errors:

```ruby
# Configure retry behavior
RubyLLM.configure do |config|
  config.max_retries = 5 # Maximum number of retries
end
```

The following errors trigger automatic retries:
- Network timeouts
- Connection failures
- Rate limit errors (429)
- Server errors (500, 502, 503, 504)

## Provider-Specific Errors

Each provider may return slightly different error messages. RubyLLM normalizes these into standard error types, but the original error details are preserved:

```ruby
begin
  chat = RubyLLM.chat
  chat.ask "Some question"
rescue RubyLLM::Error => e
  if e.response.body.include?("organization_quota_exceeded")
    puts "Your organization's quota has been exceeded"
  else
    puts "Error: #{e.message}"
  end
end
```

## Error Handling in Rails

When using RubyLLM in a Rails application, you can handle errors at different levels:

### Controller Level

```ruby
class ChatController < ApplicationController
  rescue_from RubyLLM::Error, with: :handle_ai_error

  def create
    @chat = Chat.create!(chat_params)
    @chat.ask(params[:message])
    redirect_to @chat
  end

  private

  def handle_ai_error(exception)
    flash[:error] = "AI service error: #{exception.message}"
    redirect_to chats_path
  end
end
```

### Background Job Level

```ruby
class AiChatJob < ApplicationJob
  retry_on RubyLLM::RateLimitError, RubyLLM::ServiceUnavailableError,
           wait: :exponentially_longer, attempts: 5

  discard_on RubyLLM::UnauthorizedError, RubyLLM::BadRequestError

  def perform(chat_id, message)
    chat = Chat.find(chat_id)
    chat.ask(message)
  rescue RubyLLM::Error => e
    # Log error and notify user
    ErrorNotifier.notify(chat.user, "AI chat error: #{e.message}")
  end
end
```

## Monitoring Errors

For production applications, monitor AI service errors:

```ruby
# Custom error handler
module AiErrorMonitoring
  def self.track_error(error, context = {})
    # Record error in your monitoring system
    Sentry.capture_exception(error, extra: context)

    # Log details
    Rails.logger.error "[AI Error] #{error.class}: #{error.message}"
    Rails.logger.error "Context: #{context.inspect}"

    # Return or re-raise as needed
    error
  end
end

# Usage
begin
  chat.ask "Some question"
rescue RubyLLM::Error => e
  AiErrorMonitoring.track_error(e, {
    model: chat.model.id,
    tokens: chat.messages.sum(&:input_tokens)
  })

  # Show appropriate message to user
  flash[:error] = "Sorry, we encountered an issue with our AI service"
end
```

## Graceful Degradation

For critical applications, implement fallback strategies:

```ruby
def get_ai_response(question, fallback_message = nil)
  begin
    chat = RubyLLM.chat
    response = chat.ask(question)
    response.content
  rescue RubyLLM::Error => e
    Rails.logger.error "AI error: #{e.message}"

    # Fallback to alternative model
    begin
      fallback_chat = RubyLLM.chat(model: 'gpt-3.5-turbo')
      fallback_response = fallback_chat.ask(question)
      fallback_response.content
    rescue RubyLLM::Error => e2
      Rails.logger.error "Fallback AI error: #{e2.message}"
      fallback_message || "Sorry, our AI service is currently unavailable"
    end
  end
end
```

## Best Practices

1. **Always wrap AI calls in error handling** - Don't assume AI services will always be available
2. **Implement timeouts** - Configure appropriate request timeouts
3. **Use background jobs** - Process AI requests asynchronously when possible
4. **Set up monitoring** - Track error rates and response times
5. **Have fallback content** - Prepare fallback responses when AI services fail
6. **Gracefully degrade** - Implement multiple fallback strategies
7. **Communicate to users** - Provide clear error messages when AI services are unavailable

## Error Recovery

When dealing with errors, consider recovery strategies:

```ruby
MAX_RETRIES = 3

def ask_with_recovery(chat, question, retries = 0)
  chat.ask(question)
rescue RubyLLM::RateLimitError, RubyLLM::ServiceUnavailableError => e
  if retries < MAX_RETRIES
    # Exponential backoff
    sleep_time = 2 ** retries
    puts "Error: #{e.message}. Retrying in #{sleep_time} seconds..."
    sleep sleep_time
    ask_with_recovery(chat, question, retries + 1)
  else
    raise e
  end
end
```

## Next Steps

Now that you understand error handling in RubyLLM, you might want to explore:

- [Rails Integration]({% link guides/rails.md %}) for using RubyLLM in Rails applications
- [Tools]({% link guides/tools.md %}) for using tools with error handling