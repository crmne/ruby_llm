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

# Narrow views of two domain objects, so their surfaces can be related: the
# Agent is a declarative wrapper over Chat.
component :chat, constants: 'RubyLLM::Chat'
component :agent, constants: 'RubyLLM::Agent'

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

# The five wire-protocol family classes themselves (not their helper modules),
# so the shared wire contract can be enforced on them alone.
component :protocol_families, in: 'lib/ruby_llm/protocols/*.rb'

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

# The chat wire contract every protocol family implements. The Protocol base
# declares these abstract with define_method, invisible to static analysis, so
# must_implement is real here: a family that forgets a seam fails the build.
protocol_families.must_implement :render_payload, :completion_url, :parse_completion_body

# Wire serialization is render_*, deserialization is parse_*. The non-idiomatic
# serialize_/to_wire_ forms have no place in a protocol.
protocols.methods.matching(/\A(serialize|deserialize|to_wire|from_wire)_/)
         .forbidden(because: 'serialize with render_*, deserialize with parse_*')

# Protocols render and parse provider wire formats. They may create domain
# objects, but should not reach into concrete provider adapters.
protocols.cannot_reference_constants 'RubyLLM::Providers'

# The plain-Ruby library must never reach into the Rails integration; this is
# what keeps `require "ruby_llm"` free of ActiveRecord. Support is a leaf layer
# that also must not know protocols or concrete providers.
domain.cannot_reference_constants 'RubyLLM::ActiveRecord'
support.cannot_reference_constants 'RubyLLM::ActiveRecord', 'RubyLLM::Protocols', 'RubyLLM::Providers'

# The Rails integration builds on the domain and support layers and delegates
# through the Provider contract, not wire protocols or concrete adapters.
rails_integration.cannot_reference_constants 'RubyLLM::Protocols', 'RubyLLM::Providers'

# The domain is plain Ruby; it must not call ActiveRecord persistence.
domain.cannot_call :save!, :update!, :create!, :destroy!, :transaction

# Generic Ruby naming idioms: no get_/set_ accessors, no is_ predicate prefix.
preset :ruby_conventions

# Capabilities are one query, supports?(:name), never a supports_*? predicate.
support.methods.matching(/\Asupports_\w+\?\z/).forbidden(because: 'query capabilities with supports?(:name)')

# Every with_* configuration setter has a without_* that clears it. Excepted:
# with_model (switches, nothing to clear) and with_attachments (a Message transform).
domain.methods.matching(/\Awith_(?<option>.+)/)
      .requires('without_%<option>s', except: %i[with_model with_attachments])

# The Agent is a declarative wrapper over Chat: every Chat#with_x setter has a
# matching bare class-level macro on Agent. temperature and max_output_tokens
# are generated by a define_method loop that static analysis cannot see.
chat.methods.matching(/\Awith_(?<option>.+)/)
    .requires('%<option>s', on: agent, scope: :class, except: %i[with_temperature with_max_output_tokens])
