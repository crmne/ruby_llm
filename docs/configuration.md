---
layout: default
title: Configuration
nav_order: 3
permalink: /configuration
---

# Configuring RubyLLM
{: .no_toc }

This guide covers all the configuration options available in RubyLLM, from setting API keys and default models to customizing connection behavior and using scoped contexts.
{: .fs-6 .fw-300 }

## Table of contents
{: .no_toc .text-delta }

1. TOC
{:toc}

---

After reading this guide, you will know:

*   How to set up global configuration using `RubyLLM.configure`.
*   How to configure API keys for different providers.
*   How to set default models for chat, embeddings, and image generation.
*   How to customize connection timeouts and retries.
*   How to connect to custom endpoints (like Azure OpenAI).
*   How to use temporary, scoped configurations with `RubyLLM.context`.
*   How to configure the logging location.

## Global Configuration (`RubyLLM.configure`)

{: .warning }
> Native OpenRouter and Ollama support is coming in v1.3.0
>
> Consider using `openai_api_base` in the meantime.

The primary way to configure RubyLLM is using the `RubyLLM.configure` block. This typically runs once when your application starts (e.g., in `config/initializers/ruby_llm.rb` for Rails apps, or at the top of a script).

```ruby
require 'ruby_llm'

RubyLLM.configure do |config|
  # --- Provider API Keys ---
  # Provide keys ONLY for the providers you intend to use.
  # Using environment variables (ENV.fetch) is highly recommended.
  config.openai_api_key = ENV.fetch('OPENAI_API_KEY', nil)
  config.openai_organization_id = ENV.fetch('OPENAI_ORGANIZATION_ID', nil)
  config.openai_project_id = ENV.fetch('OPENAI_PROJECT_ID', nil)
  config.anthropic_api_key = ENV.fetch('ANTHROPIC_API_KEY', nil)
  config.gemini_api_key = ENV.fetch('GEMINI_API_KEY', nil)
  config.deepseek_api_key = ENV.fetch('DEEPSEEK_API_KEY', nil)
  config.openrouter_api_key = ENV.fetch('OPENROUTER_API_KEY', nil)
  config.ollama_api_base = ENV.fetch('OLLAMA_API_BASE', nil)

  # --- AWS Bedrock Credentials ---
  # Uses standard AWS credential chain (environment, shared config, IAM role)
  # if these specific keys aren't set. Region is required if using Bedrock.
  config.bedrock_api_key = ENV.fetch('AWS_ACCESS_KEY_ID', nil)
  config.bedrock_secret_key = ENV.fetch('AWS_SECRET_ACCESS_KEY', nil)
  config.bedrock_region = ENV.fetch('AWS_REGION', nil) # e.g., 'us-west-2'
  config.bedrock_session_token = ENV.fetch('AWS_SESSION_TOKEN', nil) # For temporary credentials

  # --- Custom OpenAI Endpoint ---
  # Use this for Azure OpenAI, proxies, or self-hosted models via OpenAI-compatible APIs.
  config.openai_api_base = ENV.fetch('OPENAI_API_BASE', nil) # e.g., "https://your-azure.openai.azure.com"

  # --- Default Models ---
  # Used by RubyLLM.chat, RubyLLM.embed, RubyLLM.paint if no model is specified.
  config.default_model = 'gpt-4.1-nano'               # Default: 'gpt-4.1-nano'
  config.default_embedding_model = 'text-embedding-3-small'  # Default: 'text-embedding-3-small'
  config.default_image_model = 'dall-e-3'            # Default: 'dall-e-3'

  # --- Connection Settings ---
  config.request_timeout = 120  # Request timeout in seconds (default: 120)
  config.max_retries = 3        # Max retries on transient network errors (default: 3)
  config.retry_interval = 0.1 # Initial delay in seconds (default: 0.1)
  config.retry_backoff_factor = 2 # Multiplier for subsequent retries (default: 2)
  config.retry_interval_randomness = 0.5 # Jitter factor (default: 0.5)

  # --- Logging Settings ---
  config.log_file = '/logs/ruby_llm.log'
  config.level = :debug # debug level can also be set to debug by setting RUBYLLM_DEBUG envar to true
end
```

{: .note }
You only need to set the API keys for the providers you actually plan to use. Attempting to use an unconfigured provider will result in a `RubyLLM::ConfigurationError`.

## Provider API Keys

Set the corresponding `*_api_key` attribute for each provider you want to enable. Using environment variables (`ENV.fetch('PROVIDER_API_KEY', nil)`) is the recommended approach for managing sensitive keys.

*   `openai_api_key`
*   `anthropic_api_key`
*   `gemini_api_key`
*   `deepseek_api_key`
*   `openrouter_api_key`
*   `ollama_api_base`
*   `bedrock_api_key`, `bedrock_secret_key`, `bedrock_region`, `bedrock_session_token` (See AWS documentation for standard credential methods if not set explicitly).

## Custom OpenAI API Base (`openai_api_base`)
{: .d-inline-block }

If you are using Azure OpenAI Service, an API proxy (like LiteLLM or Fastly AI Accelerator), or a self-hosted model exposing an OpenAI-compatible API, set the `openai_api_base` configuration to your custom endpoint URL.

```ruby
RubyLLM.configure do |config|
  # Example for Azure
  config.openai_api_key = ENV['AZURE_OPENAI_KEY']
  config.openai_api_base = "https://YOUR-RESOURCE-NAME.openai.azure.com"

  # Example for a local proxy
  # config.openai_api_key = "dummy-key" # Or whatever your proxy expects
  # config.openai_api_base = "http://localhost:8000/v1"
end
```

This setting redirects requests made with `provider: :openai` to your specified base URL. See the [Working with Models Guide]({% link guides/models.md %}#connecting-to-custom-endpoints--using-unlisted-models) for more details on using custom models with this setting.

## Optional OpenAI Headers
{: .d-inline-block }

Coming in v1.3.0
{: .label .label-yellow }

OpenAI supports additional headers for organization and project management:

*   `openai_organization_id`: Specifies the billing organization for API usage when multiple organizations are accessible.
*   `openai_project_id`: Tracks API usage for a project.

These headers are optional and only need to be set if you want to use organization or project-specific billing.

## Default Models

These settings determine which models are used by the top-level helper methods (`RubyLLM.chat`, `RubyLLM.embed`, `RubyLLM.paint`) when no specific `model:` argument is provided.

*   `config.default_model`: Used by `RubyLLM.chat`. Default: `'gpt-4.1-nano'`.
*   `config.default_embedding_model`: Used by `RubyLLM.embed`. Default: `'text-embedding-3-small'`.
*   `config.default_image_model`: Used by `RubyLLM.paint`. Default: `'dall-e-3'`.

Choose defaults that match your most common use case and provider availability.

## Connection Settings

Fine-tune how RubyLLM handles HTTP connections and retries.

*   `config.request_timeout`: How long (in seconds) to wait for a response before timing out. Default: `120`.
*   `config.max_retries`: Number of times to retry failed requests due to transient errors (network issues, rate limits, server errors). Default: `3`.
*   `config.retry_interval`: Initial delay (in seconds) before the first retry. Default: `0.1`.
*   `config.retry_backoff_factor`: Multiplier for the delay between subsequent retries (exponential backoff). Default: `2`.
*   `config.retry_interval_randomness`: Factor to add jitter to retry delays, preventing thundering herd issues. Default: `0.5`.

Adjust these based on network conditions and provider reliability.

## Logging Settings

RubyLLM provides flexible logging configuration to help you monitor and debug API interactions. You can configure both the log file location and the logging level.

```ruby
RubyLLM.configure do |config|
  # --- Logging Settings ---
  config.log_file = '/logs/ruby_llm.log'  # Path to log file (default: nil, logs to STDOUT)
  config.level = :debug  # Log level (:debug, :info, :warn)
end
```

### Log File Configuration

* `config.log_file`: Specifies the path where logs should be written. If not set, logs will be written to STDOUT.
* The log file will be created if it doesn't exist, and logs will be appended to it.

### Log Levels

* `:debug`: Most verbose level, includes detailed request/response information as provided by the faraday client
* `:info`: General operational information
* `:warn`: Warning messages for non-critical issues that may need attention

You can also set the debug level by setting the `RUBYLLM_DEBUG` environment variable to `true`.

## Scoped Configuration with Contexts
{: .d-inline-block }

Coming in v1.3.0
{: .label .label-yellow }

While `RubyLLM.configure` sets global defaults, `RubyLLM.context` allows you to create temporary, isolated configuration scopes for specific API calls. This is ideal for situations requiring different keys, endpoints, or timeouts temporarily without affecting the rest of the application.

### Why Use Contexts?

*   **Multi-Tenancy:** Use different API keys per tenant.
*   **Environment Targeting:** Switch between production/staging/local endpoints.
*   **Specific Task Needs:** Use longer timeouts for complex generations.
*   **Testing:** Isolate test configurations.

### How to Use Contexts

Pass a block to `RubyLLM.context` to modify a *copy* of the global configuration. The method returns a `Context` object mirroring the top-level `RubyLLM` API.

```ruby
# Assume global config is set for OpenAI production

# Create a context targeting Azure
azure_context = RubyLLM.context do |config|
  config.openai_api_key = ENV['AZURE_TENANT_KEY']
  config.openai_api_base = "https://your-azure.openai.azure.com"
  config.request_timeout = 180 # Longer timeout
end

# Calls via azure_context use the overridden settings
chat = azure_context.chat(model: 'my-azure-gpt4o', provider: :openai, assume_model_exists: true)
response = chat.ask("Query using Azure...")

# Global calls remain unaffected
default_chat = RubyLLM.chat
default_response = default_chat.ask("Query using global production settings...")
```

### Key Context Behaviors

*   **Inheritance:** Contexts start with a copy of the global configuration. Unspecified settings retain their global values within the context.
*   **Isolation:** Modifying configuration within a context block does **not** affect the global `RubyLLM.config`.
*   **Thread Safety:** Each context is independent, making them safe for use across different threads.

Contexts provide a clean and safe mechanism for managing diverse configuration needs within a single application.

