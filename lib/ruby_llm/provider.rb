# frozen_string_literal: true

require 'json'
require 'ruby_llm/error'

module RubyLLM
  # A Provider connects RubyLLM to one AI service. It knows where to talk
  # (host, authentication headers, configuration) and which protocol to
  # speak for a given model and request. The wire formats themselves live
  # under RubyLLM::Protocols.
  #
  # Subclass Provider to support a new service, then make it available
  # with ::register:
  #
  #   class Acme < RubyLLM::Provider
  #     protocol :chat_completions, RubyLLM::Protocols::ChatCompletions
  #
  #     def self.configuration_options
  #       %i[acme_api_key]
  #     end
  #
  #     def api_base
  #       'https://api.acme.ai/v1'
  #     end
  #
  #     def headers
  #       { 'Authorization' => "Bearer #{@config.acme_api_key}" }
  #     end
  #   end
  #
  #   RubyLLM::Provider.register :acme, Acme
  #
  # See the custom providers guide for the full walkthrough.
  class Provider
    include Inspectable

    BATCH_RATE_BY_COMPONENT = {
      input: :input_per_million,
      output: :output_per_million,
      cache_read: :cache_read_input_per_million,
      cache_write: :cache_write_input_per_million,
      thinking: :reasoning_output_per_million
    }.freeze
    private_constant :BATCH_RATE_BY_COMPONENT

    # The Configuration the provider was built with.
    attr_reader :config

    attr_reader :connection # :nodoc:

    def initialize(config) # :nodoc:
      @config = config
      ensure_configured!
      @connection = Connection.new(self, @config)
    end

    # Returns the base URL that relative endpoint paths resolve against.
    # The base implementation raises NotImplementedError, so every
    # subclass must define it.
    #
    #   def api_base
    #     @config.acme_api_base || 'https://api.acme.ai/v1'
    #   end
    #
    def api_base
      raise NotImplementedError
    end

    # Returns the headers merged into every request. The default is an
    # empty hash. Override to supply authentication.
    #
    #   def headers
    #     { 'Authorization' => "Bearer #{@config.acme_api_key}" }
    #   end
    #
    def headers
      {}
    end

    # Returns how many seconds the service asked us to wait before
    # retrying a rate-limited request, or +nil+ when the response carries
    # no timing information. The retry middleware already honors the
    # standard <tt>Retry-After</tt> header; override this to read
    # provider-specific rate-limit headers.
    #
    #   def retry_delay(response)
    #     response.response_headers['x-acme-ratelimit-reset']&.to_f
    #   end
    #
    def retry_delay(_response)
      nil
    end

    # Returns the provider slug, delegating to ::slug.
    def slug
      self.class.slug
    end

    # Returns the human-readable provider name, delegating to
    # ::display_name.
    def name # :nodoc:
      self.class.display_name
    end

    def capabilities # :nodoc:
      self.class.capabilities
    end

    def configuration_requirements # :nodoc:
      self.class.configuration_requirements
    end

    def protocols # :nodoc:
      self.class.protocols
    end

    # Returns the protocol class to use for +model+. Override to route
    # between registered protocols per model or request operation. An
    # explicit <tt>protocol:</tt> override on the chat or the provider's
    # <tt><slug>_protocol</tt> configuration option takes precedence
    # over this hook.
    #
    #   def protocol_for(model, **)
    #     model.id.match?(/audio|realtime/) ? protocols[:chat_completions] : super
    #   end
    #
    def protocol_for(_model, **)
      default_protocol
    end

    def complete(messages, tools:, temperature:, model:, provider_options: {}, headers: {}, schema: nil, # :nodoc:
                 max_output_tokens: nil, thinking: nil, citations: false, caching: nil, tool_prefs: nil,
                 protocol: nil, before_request: [], usage_recorder: nil, server_tools: [],
                 compaction: nil, end_user: nil, &)
      protocol_class = resolve_protocol(protocol, model, tools:, schema:, thinking:, tool_prefs:, citations:)
      protocol_class.new(self, model).complete(
        messages,
        tools: tools,
        server_tools: server_tools,
        tool_prefs: tool_prefs,
        temperature: temperature,
        max_output_tokens: max_output_tokens,
        provider_options: provider_options,
        headers: headers,
        schema: schema,
        thinking: thinking,
        citations: citations,
        caching: caching,
        compaction: compaction,
        end_user: end_user,
        before_request: before_request,
        usage_recorder: usage_recorder,
        &
      )
    end

    def render(messages, tools:, temperature:, model:, provider_options: {}, schema: nil, thinking: nil, # :nodoc:
               max_output_tokens: nil, citations: false, caching: nil, tool_prefs: nil, protocol: nil,
               before_request: [], server_tools: [], compaction: nil, end_user: nil)
      protocol_class = resolve_protocol(protocol, model, tools:, schema:, thinking:, tool_prefs:, citations:)
      protocol_class.new(self, model).render(
        messages,
        tools: tools,
        server_tools: server_tools,
        tool_prefs: tool_prefs,
        temperature: temperature,
        max_output_tokens: max_output_tokens,
        provider_options: provider_options,
        schema: schema,
        thinking: thinking,
        citations: citations,
        caching: caching,
        compaction: compaction,
        end_user: end_user,
        before_request: before_request
      )
    end

    def count_tokens(messages, model:, tools: {}, tool_prefs: nil, thinking: nil, schema: nil, # :nodoc:
                     citations: false, caching: nil, protocol: nil)
      protocol_class = resolve_protocol(protocol, model, tools:, schema:, thinking:, tool_prefs:, citations:)
      protocol_class.new(self, model).count_tokens(
        messages,
        tools: tools,
        tool_prefs: tool_prefs,
        thinking: thinking,
        schema: schema,
        citations: citations,
        caching: caching
      )
    end

    def preprocess_message(message, model:, protocol: nil) # :nodoc:
      protocol_class = resolve_protocol(
        protocol,
        model,
        tools: {},
        schema: nil,
        thinking: nil,
        tool_prefs: nil,
        citations: false
      )
      protocol_class.new(self, model).preprocess_message(message)
    end

    def batches? # :nodoc:
      batch_protocol.public_method_defined?(:create_batch)
    end

    def create_batch(requests) # :nodoc:
      protocol = batch_protocol_for(requests)
      ensure_batches_supported!(protocol)
      protocol.new(self).create_batch(requests).merge(batch_protocol: protocol)
    end

    def find_batch(id) # :nodoc:
      ensure_batches_supported!
      batch_protocol.new(self).find_batch(id)
    end

    def cancel_batch(id) # :nodoc:
      ensure_batches_supported!
      batch_protocol.new(self).cancel_batch(id)
    end

    def batch_results(id, batch_protocol: nil) # :nodoc:
      protocol = resolve_batch_protocol(batch_protocol) || self.batch_protocol
      ensure_batches_supported!(protocol)
      protocol.new(self).batch_results(id)
    end

    def batch_status(raw_status, completed:, batch_protocol: nil) # :nodoc:
      protocol = resolve_batch_protocol(batch_protocol) || self.batch_protocol
      ensure_batches_supported!(protocol)
      parser = protocol.new(self)
      return parser.send(:parse_batch_status, raw_status, completed:) if parser.respond_to?(:parse_batch_status, true)

      completed ? :succeeded : :pending
    end

    def batch_cost(tokens, model:, category: :text_tokens) # :nodoc:
      standard = Cost.new(tokens:, model:, category:)
      return standard if tokens.reported_cost

      pricing = model.pricing.public_send(category)
      batch_tier = pricing.batch unless long_context_pricing?(pricing, tokens)
      batch = Cost.new(tokens:, model:, category:, tier: :batch) if batch_tier
      amounts = batch_cost_amounts(standard:, batch:, batch_tier:, model:)
      Cost.from_h(amounts, tokens:)
    end

    def batch_cost_amounts(standard:, batch:, batch_tier:, model:) # :nodoc:
      BATCH_RATE_BY_COMPONENT.to_h do |component, rate|
        amount = if batch_tier&.public_send(rate)
                   batch.public_send(component)
                 else
                   value = standard.public_send(component)
                   multiplier = batch_cost_multiplier(model:, component:)
                   value * multiplier if value && multiplier
                 end
        [component, amount]
      end
    end

    def batch_cost_multiplier(**) = nil # :nodoc:

    def long_context_pricing?(pricing, tokens) # :nodoc:
      pricing.long_context &&
        pricing.long_context_threshold &&
        tokens.input.to_i + tokens.cache_read.to_i + tokens.cache_write.to_i > pricing.long_context_threshold
    end

    def batch_protocol_name(protocol) # :nodoc:
      protocols.key(protocol)&.to_s
    end

    def files? # :nodoc:
      protocols.key?(:files)
    end

    def list_models # :nodoc:
      listing_protocol.new(self).list_models
    end

    def embed(text, model:, dimensions:, task_type: nil, title: nil, with: nil, provider_options: {}) # :nodoc:
      protocol = resolve_protocol(nil, model, operation: :embed)
      protocol.new(self, model).embed(
        text, model: model_id_for(model), dimensions:, task_type:, title:, with:, provider_options:
      )
    end

    def render_embedding(text, model:, dimensions: nil) # :nodoc:
      protocol = resolve_protocol(nil, model, operation: :embed)
      protocol.new(self, model).render_embedding(text, model: model_id_for(model), dimensions:)
    end

    def moderate(input, model:, with: [], provider_options: {}) # :nodoc:
      protocol = resolve_protocol(nil, model, operation: :moderate)
      protocol.new(self, model).moderate(
        input, model: model_id_for(model), with:, provider_options:
      )
    end

    def paint(prompt, model:, size:, count: nil, with: nil, mask: nil, provider_options: {}) # :nodoc:
      protocol = resolve_protocol(nil, model, operation: :paint)
      protocol.new(self, model).paint(
        prompt, model: model_id_for(model), size:, count:, with:, mask:, provider_options:
      )
    end

    def animate_later(prompt, model:, with: nil, provider_options: {}) # :nodoc:
      protocol = resolve_protocol(nil, model, operation: :animate)
      protocol.new(self, model).animate_later(
        prompt, model: model_id_for(model), with:, provider_options:
      )
    end

    def speak(input, model:, voice:, format:, provider_options: {}) # :nodoc:
      protocol = resolve_protocol(nil, model, operation: :speak)
      protocol.new(self, model).speak(
        input, model: model_id_for(model), voice:, format:, provider_options:
      )
    end

    def transcribe(audio_file, model:, language:, format: nil, speaker_names: nil, # :nodoc:
                   speaker_references: nil, provider_options: {}, prompt: nil, temperature: nil, &)
      protocol = resolve_protocol(nil, model, operation: :transcribe)
      protocol.new(self, model).transcribe(
        audio_file,
        model: model_id_for(model),
        language:,
        format:,
        speaker_names:,
        speaker_references:,
        provider_options:,
        prompt:,
        temperature:,
        &
      )
    end

    def ocr(file, model:, options: {}) # :nodoc:
      protocol = resolve_protocol(nil, model, operation: :ocr)
      protocol.new(self, model).ocr(file, model: model_id_for(model), options:)
    end

    def rerank(query, documents, model:, top_n: nil, provider_options: {}) # :nodoc:
      protocol = resolve_protocol(nil, model, operation: :rerank)
      protocol.new(self, model).rerank(query, documents, model: model_id_for(model), top_n:, provider_options:)
    end

    def upload_file(file, filename: nil, purpose: nil, expires_in: nil, provider_options: {}) # :nodoc:
      ensure_files_supported!
      options = { filename:, purpose:, expires_in:, provider_options: }.compact

      protocols.fetch(:files).new(self).upload(file, **options)
    end

    def cache_content(content, model:, ttl: nil, instructions: nil, with: nil) # :nodoc:
      protocol = resolve_protocol(nil, model, operation: :cache)
      protocol.new(self, model).cache_content(
        content, model: model_id_for(model), ttl:, instructions:, with:
      )
    end

    def find_cache(name) # :nodoc:
      default_protocol.new(self).find_cache(name)
    end

    def delete_cache(name) # :nodoc:
      default_protocol.new(self).delete_cache(name)
    end

    def extend_cache(name, ttl:) # :nodoc:
      default_protocol.new(self).extend_cache(name, ttl:)
    end

    def find_file(file_id) # :nodoc:
      ensure_files_supported!
      protocols.fetch(:files).new(self).find(file_id)
    end

    def download_file(file_id) # :nodoc:
      ensure_files_supported!
      protocols.fetch(:files).new(self).download(file_id)
    end

    def list_file_uris(uri) # :nodoc:
      ensure_files_supported!
      protocols.fetch(:files).new(self).list_uris(uri)
    end

    def configured? # :nodoc:
      self.class.configured?(@config)
    end

    def local? # :nodoc:
      self.class.local?
    end

    def assume_models_exist? # :nodoc:
      self.class.assume_models_exist?
    end

    def parse_error(response) # :nodoc:
      body = parse_error_body(response)
      return unless body

      case body
      when Hash
        error_part_message(body)
      when Array
        messages = body.filter_map { |part| error_part_message(part) }.reject(&:empty?)
        messages.join('. ') unless messages.empty?
      else
        body
      end
    end

    class << self
      attr_reader :default_protocol # :nodoc:
      attr_writer :slug # :nodoc:

      # Returns the provider slug, a short lowercase string that
      # identifies the provider and prefixes its configuration keys.
      # Set by ::register, or derived from the class name.
      def slug
        @slug ||= to_s.split('::').last.downcase
      end

      # Returns the human-readable provider name, derived from the
      # class name. Override for custom branding.
      def display_name
        to_s.split('::').last
      end

      # Returns the provider's narrow model capability augmenter, or +nil+
      # when models.dev and the provider listing are sufficient.
      def capabilities
        nil
      end

      def models_dev_alias(_model_id, _models_dev_by_key, _provider_model = nil) # :nodoc:
        nil
      end

      # The id RubyLLM registers for a models.dev entry. Providers whose
      # catalog spells ids differently from models.dev override this.
      def models_dev_model_id(id) # :nodoc:
        id
      end

      # Returns the configuration keys that must be set before the
      # provider is usable. The base implementation returns an empty
      # array.
      #
      #   def self.configuration_requirements
      #     %i[acme_api_key]
      #   end
      #
      def configuration_requirements
        []
      end

      # Returns every configuration key the provider contributes.
      # ::register defines a Configuration accessor for each one.
      # The base implementation returns an empty array.
      #
      #   def self.configuration_options
      #     %i[acme_api_key acme_api_base]
      #   end
      #
      def configuration_options
        []
      end

      # Returns whether the provider talks to a locally hosted service.
      # The base implementation returns +false+. Local providers such as
      # Ollama return +true+.
      def local?
        false
      end

      def remote? # :nodoc:
        !local?
      end

      # Returns whether the provider accepts model ids missing from the
      # model registry. The base implementation returns +false+.
      def assume_models_exist?
        false
      end

      def configured?(config) # :nodoc:
        configuration_requirements.all? { |req| config.send(req) }
      end

      # Registers +protocol_class+ under +name+. The first registered
      # protocol becomes the provider's default. Pass +batches:+ to compose
      # batch operations into the registered protocol.
      #
      #   protocol :chat_completions, ChatCompletions
      #   protocol :responses, Protocols::Responses, batches: Protocols::Responses::Batches
      #
      def protocol(name, protocol_class, batches: nil)
        @default_protocol = name.to_sym if protocols.empty?
        protocols[name.to_sym] = batches ? Class.new(protocol_class) { include batches } : protocol_class
      end

      def protocols # :nodoc:
        @protocols ||= {}
      end

      # Registers +provider_class+ under the slug +name+, making it
      # available to RubyLLM.chat and the other top-level helpers.
      # Stamps the class's slug, adds it to ::providers, and defines a
      # Configuration accessor for each of its configuration options. A
      # provider gem may pass the path to its bundled model catalog.
      #
      #   RubyLLM::Provider.register :acme, RubyLLM::Providers::Acme
      #   RubyLLM::Provider.register :acme, RubyLLM::Providers::Acme,
      #                              models: File.expand_path('../../../models.json', __dir__)
      #
      def register(name, provider_class, models: nil)
        provider_class.slug = name.to_s
        providers[name.to_sym] = provider_class
        models ? model_registry_files[name.to_sym] = models : model_registry_files.delete(name.to_sym)
        RubyLLM::Configuration.register_provider_options(provider_class.configuration_options + [:"#{name}_protocol"])
      end

      def resolve(name) # :nodoc:
        providers[name.to_sym]
      end

      def resolve!(name) # :nodoc:
        providers[name.to_sym] ||
          raise(Error, "Unknown provider: #{name.inspect}. Available providers: #{providers.keys.join(', ')}")
      end

      # Resolves +model_id+ to the id the registry stores it under for this
      # provider. Defaults to the id unchanged; providers whose catalog ids
      # differ from their request ids (Bedrock's region prefixes) override it.
      def resolve_registry_id(model_id, _models, _config = nil)
        model_id
      end

      # Returns the global registry of providers, a hash mapping slug
      # symbols to provider classes.
      def providers
        @providers ||= {}
      end

      def model_registry_files # :nodoc:
        @model_registry_files ||= {}
      end

      def local_providers # :nodoc:
        providers.select { |_slug, provider_class| provider_class.local? }
      end

      def remote_providers # :nodoc:
        providers.select { |_slug, provider_class| provider_class.remote? }
      end

      def configured_providers(config) # :nodoc:
        providers.select do |_slug, provider_class|
          provider_class.configured?(config)
        end.values
      end

      def configured_remote_providers(config) # :nodoc:
        providers.select do |_slug, provider_class|
          provider_class.remote? && provider_class.configured?(config)
        end.values
      end
    end

    private

    def ensure_batches_supported!(protocol = batch_protocol)
      raise Error, "#{slug} doesn't support batch requests" unless protocol.public_method_defined?(:create_batch)
    end

    def ensure_files_supported!
      return if files?

      raise Error, "#{slug} doesn't support file uploads"
    end

    def resolve_protocol(name, model, **request)
      explicit = name || configured_protocol
      explicit ? fetch_protocol(explicit) : protocol_for(model, **request)
    end

    def default_protocol
      fetch_protocol(configured_protocol || self.class.default_protocol)
    end

    # The model catalog lives at the provider's own listing endpoint, which
    # the chat protocol override has no say over.
    def listing_protocol
      fetch_protocol(self.class.default_protocol)
    end

    def batch_protocol
      fetch_protocol(self.class.default_protocol)
    end

    def batch_protocol_for(_requests)
      batch_protocol
    end

    def batch_protocol_for_name(name)
      protocol = protocols[name.to_sym]
      protocol if protocol&.public_method_defined?(:create_batch)
    end

    def resolve_batch_protocol(protocol)
      return protocol if protocol.is_a?(Module)

      protocol && batch_protocol_for_name(protocol)
    end

    def configured_protocol
      @config.send(:"#{slug}_protocol")
    end

    def fetch_protocol(name)
      protocols.fetch(name.to_sym) do
        raise Error, "#{name} is not a protocol of #{self.class.display_name}. Available: #{protocols.keys.join(', ')}"
      end
    end

    def model_id_for(model)
      model.respond_to?(:id) ? model.id : model
    end

    def try_parse_json(maybe_json)
      return maybe_json unless maybe_json.is_a?(String)

      JSON.parse(maybe_json)
    rescue JSON::ParserError
      maybe_json
    end

    def parse_error_body(response)
      body = response.body
      return if body.nil? || (body.respond_to?(:empty?) && body.empty?)

      try_parse_json(body)
    end

    def error_part_message(part)
      return part.to_s unless part.is_a?(Hash)

      error = part['error']
      return error if error.is_a?(String)

      nested_message = error['message'] if error.is_a?(Hash)
      [nested_message, part['message'], part['detail']].find { |message| message.is_a?(String) }
    end

    def ensure_configured!
      return if configured?

      missing = configuration_requirements.reject { |req| @config.send(req) }
      config_block = <<~RUBY
        RubyLLM.configure do |config|
          #{missing.map { |key| "config.#{key} = ENV['#{key.to_s.upcase}']" }.join("\n  ")}
        end
      RUBY

      raise ConfigurationError,
            "#{name} provider is not configured. Add this to your initialization:\n\n#{config_block}"
    end

    def inspect_attributes # :nodoc:
      { slug: slug }
    end
  end
end
