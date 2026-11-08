---
layout: default
title: Error Handling
nav_order: 15
description: Rescue provider errors, fall back to other models, and let automatic retries absorb transient failures
redirect_from:
  - /guides/error-handling
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

*   RubyLLM's error hierarchy.
*   How to rescue specific types of errors.
*   How to access details from the original API response.
*   How to keep what providers quote back out of error messages.
*   How errors are handled during streaming.
*   How to fall back to another model when a provider has a transient failure.
*   Best practices for handling errors within Tools.
*   RubyLLM's automatic retry behavior.
*   How to enable debug logging.

## RubyLLM Error Hierarchy

Provider operation errors inherit from `RubyLLM::Error`. RubyLLM maps the provider's HTTP status to a subclass, and reads the error message to refine it, so a 400 that reports a context overflow raises `ContextLengthExceededError`. Retries happen before the error reaches you, as described in [Automatic Retries](#automatic-retries).

| Class | HTTP status | Retried automatically? |
| --- | --- | --- |
| `RubyLLM::Error` | Any other failure status, such as a 413 that is not a context overflow | No |
| `RubyLLM::BadRequestError` | 400 | No |
| `RubyLLM::UnsupportedParameterError` | A 400 to a chat request, in OpenAI's error format, that names a parameter the model doesn't take, such as a temperature. Other operations raise `BadRequestError` for it | No |
| `RubyLLM::UnauthorizedError` | 401, or a 400 or 403 with a recognized invalid-credentials message, such as `Incorrect API key` | No |
| `RubyLLM::PaymentRequiredError` | 402, or a 400 saying the credit balance is too low | No |
| `RubyLLM::ForbiddenError` | Any other 403 | No |
| `RubyLLM::ContextLengthExceededError` | 400 or 413 with a recognized context or token limit message, or a 429 with one and no rate limit message | No |
| `RubyLLM::RateLimitError` | Any other 429, or a 400 with a recognized rate limit message, such as `quota exceeded`, and no context or token limit message | Yes |
| `RubyLLM::ServerError` | 500 | Yes |
| `RubyLLM::ServiceUnavailableError` | 502, 503, 504 | Yes |
| `RubyLLM::OverloadedError` | 529, or a 400 saying the service is `currently overloaded` | Yes |
| `RubyLLM::ConnectionError` | None: the provider or an MCP server could not be reached, or the request timed out | Yes, for provider requests |
| `RubyLLM::ContentFilterError` | None: provider content filters blocked a transcription | No |
| `RubyLLM::ToolCallParseError` | None: parent of `ToolCallTruncatedError`; other malformed arguments go back to the model | No |
| `RubyLLM::ToolCallTruncatedError` | None: the output token limit cut off a tool call | No |
| `RubyLLM::UnsupportedAttachmentError` | None: the attachment cannot be sent to this provider or model | No |
| `RubyLLM::UnsupportedServerToolError` | None: the provider or protocol does not define this server tool | No |

Yes means the error is eligible for a retry. [Automatic Retries](#automatic-retries) lists the requests that are never retried, such as file uploads and streams that have started delivering events.

Local setup and programming errors inherit from `StandardError` directly, so `rescue RubyLLM::Error` does not catch them. Rescue them separately when you need to handle them.

| Class | Raised when |
| --- | --- |
| `RubyLLM::ConfigurationError` | Required configuration, such as an API key, is missing |
| `RubyLLM::DeprecationError` | A deprecated API is called while `config.deprecation_behavior` is `:raise` |
| `RubyLLM::PromptNotFoundError` | A prompt file is not found |
| `RubyLLM::SkillNotFoundError` | A skill named by `with_skills` or `Skill.find` is missing |
| `RubyLLM::InvalidSkillError` | A skill's `SKILL.md` breaks the Agent Skills specification |
| `RubyLLM::FileNotFoundError` | A file store has no file at the path asked for |
| `RubyLLM::FileStoreFullError` | A write would take a file store past its limit. The file tools and `run_code` hand its message to the model instead of failing the reply |
| `RubyLLM::ModelNotFoundError` | The requested model ID is not in the registry |
| `RubyLLM::ModelRegistryError` | The model registry could not be fetched, parsed, or persisted |
| `RubyLLM::InvalidRoleError` | A message uses an invalid role |
| `RubyLLM::InvalidToolChoiceError` | The tool choice is neither a known mode nor a registered tool |
| `RubyLLM::PendingToolCallsError` | A new question is staged before pending tool calls finish |
| `RubyLLM::ToolCallRunningError` | A pending approval is declined while its call already runs. The call keeps running, and the model receives its result |
| `RubyLLM::CancelledError` | An in-flight chat operation is cancelled |

The [`RubyLLM::Error` reference]({{ '/api/RubyLLM/Error.html' | relative_url }}) documents the readers every provider error carries, such as `response`, `provider`, and `error_code`, and each subclass has its own page.

## Basic Error Handling

Catch the base `RubyLLM::Error` to handle most provider-operation issues.

```ruby
begin
  chat = RubyLLM.chat
  response = chat.ask "Translate 'hello' to French."
  puts response.content
rescue RubyLLM::ConfigurationError => e
  puts "Configuration missing: #{e.message}"
  # Abort or prompt for configuration
rescue RubyLLM::Error => e
  puts "An API error occurred: #{e.message}"
  # logger.error "RubyLLM API Error: #{e.class} - #{e.message}"
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
rescue RubyLLM::ContextLengthExceededError
  puts "Your prompt/conversation is too large for this model."
  # Reduce prompt size or use a model with a larger context window
rescue RubyLLM::ServiceUnavailableError
  puts "The AI service is temporarily unavailable. Please try again later."
  # Maybe offer a fallback or notify user
rescue RubyLLM::ConnectionError => e
  puts e.timeout? ? "The request timed out." : "Could not reach the provider."
  # e.cause holds the original Faraday error
rescue RubyLLM::BadRequestError => e
  puts "Invalid request sent to the API: #{e.message}"
  # Check the data being sent
rescue RubyLLM::ModelNotFoundError => e
  puts "Error: #{e.message}. Check available models with RubyLLM.models.all"
rescue RubyLLM::Error => e
  puts "An unexpected API error occurred: #{e.message}"
end
```

## Accessing API Response Details

Instances of `RubyLLM::Error` (and its subclasses related to API responses) hold the original `Faraday::Response` object in the `response` attribute. This can be useful for debugging or extracting provider-specific error codes.

```ruby
begin
  chat = RubyLLM.chat(model: "{{ site.models.default_chat }}") # Assume this requires a specific org sometimes
  response = chat.ask "Some specific query"
rescue RubyLLM::ForbiddenError => e
  puts "Access forbidden: #{e.message}"
  if e.response&.body&.include?("invalid_organization")
    puts "Hint: Check if your API key is enabled for the correct OpenAI organization."
  end
  puts "Status Code: #{e.response&.status}"
  # puts "Full Response Body: #{e.response&.body}" # For deep debugging
end
```

## Keeping Prompts Out of Error Messages

Providers often quote the request back when they refuse it: a fragment of the prompt, a file name, or a tool argument ends up in `e.message`, and from there in your logs and your error tracker. Turn on `redact_error_messages` and the message names the provider, the HTTP status, and the provider's error code, and nothing the provider wrote:

```ruby
RubyLLM.configure do |config|
  config.redact_error_messages = true
end

begin
  chat.ask "Summarize the attached contract"
rescue RubyLLM::BadRequestError => e
  e.message          # => "openai returned HTTP 400 (invalid_request_error)"
  e.provider         # => "openai"
  e.error_code       # => "invalid_request_error"
  e.provider_message # => what the provider wrote, quotes and all
  e.response_body    # => the raw body
end
```

The error code comes from the fields providers keep it in, such as OpenAI's `code` or `type`, Gemini's `status`, or Bedrock's error type, and only when it reads like a code: a word of letters, digits, `_`, `.`, `:`, or `-`, at most 64 characters. RubyLLM still picks the error class from what the provider wrote, so a context window error is still a `ContextLengthExceededError`. Messages RubyLLM writes itself, such as `Provider returned no completion message`, stay as they are, and an MCP server's errors read like `The MCP server returned an error (-32602)`.

`provider_message` and `response_body` are there when you want the provider's words, so reading them is a choice your code makes. The setting is off by default. Set it on the global configuration: every context follows it.

## Error Handling During Streaming

When using streaming with a block, errors can occur *during* the stream after some chunks have already been processed. The `ask` method will raise the error *after* the block execution finishes or is interrupted by the error.

```ruby
begin
  chat = RubyLLM.chat
  accumulated_content = ""
  chat.ask "Generate a very long story..." do |chunk|
    print chunk.content
    accumulated_content << chunk.content
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

Your block will execute for chunks received *before* the error. Because `ask` raises, it does not return a final response in this case; handle the exception and any partial content you accumulated.

## Model Fallbacks

Use `with_fallbacks` when you want RubyLLM to try another model after the current model fails with a transient provider or network error.

```ruby
chat = RubyLLM.chat(model: "{{ site.models.default_chat }}")
              .with_fallbacks("{{ site.models.openai_mini }}", "{{ site.models.anthropic_haiku }}")

response = chat.ask "Summarize this incident report."
```

Fallbacks are tried in order. The fallback only applies to that generation attempt; after the response finishes or the error bubbles up, the chat returns to its original model.

By default, fallbacks handle rate limits, server errors, service unavailable errors, overload errors, timeouts, and connection failures. Pass `on:` to choose the errors yourself:

```ruby
chat.with_fallbacks(
  "{{ site.models.openai_mini }}",
  on: [RubyLLM::RateLimitError, RubyLLM::ServiceUnavailableError]
)
```

Cancelling a chat never triggers a fallback, whatever `on:` lists. `chat.cancel` raises `RubyLLM::CancelledError` and no fallback model runs. The same holds for a persisted chat that another process takes over mid-run: this process steps aside and no fallback model runs. An error your streaming block raises is yours to handle too: it propagates as it is, and the block does not run again on a fallback model.

Fallbacks can be model IDs or `RubyLLM::Model` objects:

```ruby
chat.with_fallbacks(
  RubyLLM.models.find("{{ site.models.anthropic_haiku }}", provider: :anthropic)
)
```

Fallbacks work with [prompt caching]({% link _core_features/prompt-caching.md %}#caching-with-fallbacks) across providers. A fallback model leaves out the caching options its provider has no use for, such as an OpenAI cache key on Claude, so you don't need to set caching per provider.

### Dropping Unsupported Parameters

Models differ in which settings they take: some reasoning models reject a temperature, and some reject a reasoning effort other than their default. When OpenAI says so, RubyLLM raises `RubyLLM::UnsupportedParameterError`, a `BadRequestError` whose `parameter` names what it rejected: `:temperature`, `:thinking`, or `:max_output_tokens` for RubyLLM's own settings, or the provider's name as a String, such as a key you passed to `with_provider_options`.

To retry without it instead, opt in with `drop_unsupported: true`:

```ruby
chat = RubyLLM.chat(model: "{{ site.models.openai_current }}")
              .with_temperature(0.2)
              .with_fallbacks(drop_unsupported: true)
```

The model is retried without that parameter. If it then rejects another one, it is retried without that one too, and each parameter is dropped at most once. The chat keeps its settings, so the next request sends them again. `before_fallback` and `after_fallback` receive each retry, with `fallback.dropped_parameter` naming what was left out and `fallback.to` the same model as `fallback.from`, so you can log it and fix the setting. Nothing is ever dropped unless you opt in.

With fallback models, each model gets the same treatment before the next one is tried, and each starts again from the request as written:

```ruby
chat = RubyLLM.chat(model: "{{ site.models.openai_current }}")
              .with_temperature(0.2)
              .with_fallbacks("{{ site.models.openai_terra }}", "{{ site.models.openai_latest }}", drop_unsupported: true)
```

When every model rejects the temperature, and the first two are overloaded once it's gone, the chat tries, in order:

1. `{{ site.models.openai_current }}` with the temperature
2. `{{ site.models.openai_current }}` without it
3. `{{ site.models.openai_terra }}` with the temperature
4. `{{ site.models.openai_terra }}` without it
5. `{{ site.models.openai_latest }}` with the temperature
6. `{{ site.models.openai_latest }}` without it

A parameter one model rejected is sent to the next model, which may take it. Moving on to the next model still needs an error from `on:`, such as an overloaded or rate-limited provider; a rejection the chat can't drop is raised.

This only works with providers whose errors name the parameter, and today that means OpenAI. Other providers, including Anthropic and Gemini, describe these rejections only in free text, which RubyLLM doesn't guess from. Their models raise `BadRequestError`: nothing is dropped, and the chat doesn't move on to the next model unless you add `BadRequestError` to `on:`.

### Fallback Callbacks

Use `before_fallback` and `after_fallback` to observe each fallback attempt:

```ruby
chat.before_fallback do |fallback|
  Rails.logger.info(
    "Falling back from #{fallback.from.id} to #{fallback.to.id}: #{fallback.error.class}"
  )
end

chat.after_fallback do |fallback|
  if fallback.succeeded?
    Rails.logger.info("Fallback succeeded with #{fallback.to.id}")
  else
    Rails.logger.warn("Fallback failed with #{fallback.fallback_error.class}")
  end
end
```

The callback receives a `RubyLLM::Fallback` with the configured target (`id`, `provider`, `model`) and the runtime attempt details (`from`, `to`, `error`, `attempt`, `response`, `fallback_error`, `dropped_parameter`, `streaming?`, and `chunks_yielded?`).

A reply a fallback model wrote says so: `reply.model` is that model and `reply.provider` its provider. On a Rails message with `model_id` and `provider` columns of your own, RubyLLM saves them on those replies, and leaves them empty on replies from the chat's own model, so you can tell a stand-in's replies apart.

When streaming has already yielded chunks before a fallback-worthy error, RubyLLM cannot take those chunks back. It starts a new assistant message lifecycle for the fallback response, and `fallback.chunks_yielded?` lets your UI or logs distinguish that case.

## Handling Errors Within Tools

When building [Tools]({% link _getting_started/tools.md %}), you need to decide how errors within the tool's `execute` method should be handled:

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
        raise e # Let the application's error handling take over.
      rescue StandardError => e
        # Maybe return less critical errors to the LLM
        { error: "Database query failed: #{e.message}" }
      end
    end
    ```

## Tool-Level Handlers

Writing the same `rescue` in every tool gets old. Declare `rescue_from` on a base class instead, and every tool that inherits from it hands the model a result instead of stopping the chat:

```ruby
class ApplicationTool < RubyLLM::Tool
  rescue_from StandardError, with: :report_failure

  rescue_from ActiveRecord::ConnectionNotEstablished do
    raise
  end

  private

  def report_failure(error)
    Rails.error.report(error, context: { tool: name })
    { error: "This tool failed unexpectedly (#{error.class.name.demodulize}). Trying the same call again won't help." }
  end
end
```

Name a method with `with:` or pass a block. Either runs on the tool instance, so `name` and the tool's own methods are available. The handler's return value becomes the call's result, exactly as if `execute` had returned it, and reaches `after_tool_result` callbacks too. Re-raise to stop the chat, as an exception without a handler does. Handlers are searched from the last declared to the first, so list general classes before specific ones. They run in the thread or fiber that runs the call, so they work the same with [concurrent tool execution]({% link _tools/tool-execution.md %}#concurrent-tool-execution).

A question from `ask` and a cancelled chat never reach a handler, so `rescue_from StandardError` doesn't swallow them.

A subclass uses its parent's handlers, including ones declared after the subclass, and its own come first. A handler on `RubyLLM::Tool` itself covers every tool, RubyLLM's own included, such as in an initializer:

```ruby
# config/initializers/ruby_llm.rb
RubyLLM::Tool.rescue_from StandardError do |error|
  { error: "The tool couldn't run (#{error.class.name.split("::").last})." }
end
```

Declare one on `RubyLLM::CodeExecution` to cover only code execution.

Handlers run for the calls a chat makes, whether your tool defines `execute` or overrides `call`. Calling a tool yourself is still supported, in a test, a job, or a controller: `Weather.new.call(city: "Berlin")` validates the arguments and runs `execute`, and you can call `execute` directly too. Handlers don't wrap those calls, so an exception reaches your code as it would from any Ruby method.

Handlers for an [MCP server's]({% link _tools/mcp.md %}#handling-tool-errors) tools go on its client class.

## Agent-Level Handlers

When you use [Agents]({% link _getting_started/agents.md %}), `rescue_from` moves error handling out of every call site and into the agent class:

```ruby
class ApplicationAgent < RubyLLM::Agent
  rescue_from RubyLLM::RateLimitError, RubyLLM::ConnectionError, with: :handle_transient

  private

  def handle_transient(error)
    StatsD.increment("llm.api_error", tags: ["type:transient"])
    raise
  end
end
```

Handlers cover the agent's chat operations (`ask`, `say`, `ask_later`, `complete`, `generate`, `run_tools`, `step`), run on the agent instance, and follow `ActiveSupport::Rescuable` semantics. See [Handling Errors with `rescue_from`]({% link _getting_started/agents.md %}#handling-errors-with-rescue_from).

## Automatic Retries

RubyLLM automatically retries requests that fail due to transient network or server issues using Faraday's retry middleware.
Retries are driven by error classification (exception types), not raw HTTP status codes alone.

Retries are attempted for:

*   Network failures (`RubyLLM::ConnectionError`: timeouts, refused or dropped connections, and TLS failures)
*   Rate limit errors (`RubyLLM::RateLimitError`, often HTTP 429)
*   Server-side errors (`RubyLLM::ServerError`, `RubyLLM::ServiceUnavailableError`, `RubyLLM::OverloadedError` / HTTP 500, 502, 503, 504, 529)

`RubyLLM::ContextLengthExceededError` is not retried. Neither is a stream that fails after it has started delivering events, because the retry would replay them into the same response.

RubyLLM honors `Retry-After` and `retry-after-ms` headers across providers. `Retry-After` takes precedence when both are present. Invalid millisecond delays fall back to provider-specific timing or the configured backoff. If the requested delay exceeds `retry_max_interval`, RubyLLM raises the error without retrying early.

Batch submissions, video generation jobs, file uploads, and content caches are never retried, because each creates something on the provider's side. When such a request reaches the provider but its response is lost, retrying would create a second job you still pay for, so RubyLLM raises the error and lets you decide whether to submit again.

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
```

Debug logs show request and response headers and bodies, with API keys filtered. Use them to inspect the call that failed.

## Next Steps

*   [Using Tools]({% link _getting_started/tools.md %})
*   [Streaming Responses]({% link _core_features/streaming.md %})
*   [Rails Integration]({% link _getting_started/rails.md %})
