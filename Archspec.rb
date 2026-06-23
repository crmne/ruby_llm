# frozen_string_literal: true

source 'lib/**/*.rb'
ignore 'lib/generators/ruby_llm/templates/**/*'

# Public entrypoint. This is the only place that should wire concrete providers
# into the top-level RubyLLM module.
component :entrypoint, in: 'lib/ruby_llm.rb'

# User-facing objects and orchestration. These are nouns like Chat, Batch,
# UploadedFile, Embedding, Image, Message, Tool, and Content.
component :domain, in: %w[
  lib/ruby_llm/agent.rb
  lib/ruby_llm/attachment.rb
  lib/ruby_llm/batch.rb
  lib/ruby_llm/chat.rb
  lib/ruby_llm/chunk.rb
  lib/ruby_llm/citation.rb
  lib/ruby_llm/content.rb
  lib/ruby_llm/context.rb
  lib/ruby_llm/cost.rb
  lib/ruby_llm/embedding.rb
  lib/ruby_llm/image.rb
  lib/ruby_llm/message.rb
  lib/ruby_llm/moderation.rb
  lib/ruby_llm/search_results.rb
  lib/ruby_llm/stream_accumulator.rb
  lib/ruby_llm/streaming.rb
  lib/ruby_llm/thinking.rb
  lib/ruby_llm/tokens.rb
  lib/ruby_llm/tool.rb
  lib/ruby_llm/tool_call.rb
  lib/ruby_llm/tool_concurrency.rb
  lib/ruby_llm/transcription.rb
  lib/ruby_llm/uploaded_file.rb
  lib/ruby_llm/uploaded_file/**/*.rb
]

# Shared implementation support. This layer may support model lookup, transport,
# errors, configuration, and instrumentation, but it should not grow product
# concepts that belong in the domain layer.
component :support, in: %w[
  lib/ruby_llm/aliases.rb
  lib/ruby_llm/configuration.rb
  lib/ruby_llm/connection.rb
  lib/ruby_llm/deprecator.rb
  lib/ruby_llm/error.rb
  lib/ruby_llm/error_middleware.rb
  lib/ruby_llm/instrumentation.rb
  lib/ruby_llm/mime_type.rb
  lib/ruby_llm/model.rb
  lib/ruby_llm/model/**/*.rb
  lib/ruby_llm/model_registry.rb
  lib/ruby_llm/models.rb
  lib/ruby_llm/utils.rb
  lib/ruby_llm/version.rb
]

component :provider_contract,
          in: 'lib/ruby_llm/provider.rb',
          constants: 'RubyLLM::Provider'

component :protocol_contract,
          in: 'lib/ruby_llm/protocol.rb',
          constants: 'RubyLLM::Protocol'

# Protocols are wire-family implementations: Chat Completions, Responses,
# Anthropic, Gemini, Converse, and shared OpenAI wire mechanics.
component :protocols,
          in: 'lib/ruby_llm/protocols/**/*.rb',
          namespace: 'RubyLLM::Protocols'

# Concrete provider adapters: auth, API bases, provider-specific dialect modules,
# model catalogs, and provider-owned cloud plumbing.
component :providers,
          in: 'lib/ruby_llm/providers/**/*.rb',
          namespace: 'RubyLLM::Providers'

component :rails_integration,
          in: %w[
            lib/ruby_llm/active_record/**/*.rb
            lib/ruby_llm/railtie.rb
          ],
          namespace: 'RubyLLM::ActiveRecord'

component :generators, in: 'lib/generators/**/*.rb'
component :tasks, in: 'lib/tasks/**/*.rake'

# OpenAI-specific shared wire mechanics, like the file-backed Batch API and the
# OpenAI Files API. Chat Completions and Responses can include this, but the
# shared transport should not pretend to be a generic RubyLLM protocol.
component :openai_protocol_plumbing,
          in: 'lib/ruby_llm/protocols/openai/**/*.rb',
          namespace: 'RubyLLM::Protocols::OpenAI'

# Most files reopen `module RubyLLM`, so component dependency rules are noisy.
# Public domain objects delegate through Provider. They should not know protocol
# families or concrete provider adapters directly.
domain.cannot_reference_constants 'RubyLLM::Protocols', 'RubyLLM::Providers'

# Base contracts must stay generic. Concrete providers are registered by the
# entrypoint, not referenced from the base classes.
provider_contract.cannot_reference_constants 'RubyLLM::Providers'
protocol_contract.cannot_reference_constants 'RubyLLM::Providers'

# Protocols render and parse provider wire formats. They may create domain
# objects, but should not reach into concrete provider adapters.
protocols.cannot_reference_constants 'RubyLLM::Providers'
