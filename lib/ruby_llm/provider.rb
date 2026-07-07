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

    # Returns the provider slug, delegating to ::slug.
    def slug
      self.class.slug
    end

    # Returns the human-readable provider name, delegating to
    # ::display_name.
    def name
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

    # rubocop:disable Metrics/ParameterLists
    def complete(messages, tools:, temperature:, model:, provider_options: {}, headers: {}, schema: nil, # :nodoc:
                 max_output_tokens: nil, thinking: nil, citations: false, caching: nil, tool_prefs: nil,
                 protocol: nil, before_request: [], &)
      protocol_class = resolve_protocol(protocol, model, tools:, schema:, thinking:, tool_prefs:, citations:)
      protocol_class.new(self, model).complete(
        messages,
        tools: tools,
        tool_prefs: tool_prefs,
        temperature: temperature,
        max_output_tokens: max_output_tokens,
        provider_options: provider_options,
        headers: headers,
        schema: schema,
        thinking: thinking,
        citations: citations,
        caching: caching,
        before_request: before_request,
        &
      )
    end
    # rubocop:enable Metrics/ParameterLists

    # rubocop:disable Metrics/ParameterLists
    def render(messages, tools:, temperature:, model:, provider_options: {}, schema: nil, thinking: nil, # :nodoc:
               max_output_tokens: nil, citations: false, caching: nil, tool_prefs: nil, protocol: nil,
               before_request: [])
      protocol_class = resolve_protocol(protocol, model, tools:, schema:, thinking:, tool_prefs:, citations:)
      protocol_class.new(self, model).render(
        messages,
        tools: tools,
        tool_prefs: tool_prefs,
        temperature: temperature,
        max_output_tokens: max_output_tokens,
        provider_options: provider_options,
        schema: schema,
        thinking: thinking,
        citations: citations,
        caching: caching,
        before_request: before_request
      )
    end
    # rubocop:enable Metrics/ParameterLists

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
      protocol = batch_protocol || self.batch_protocol
      ensure_batches_supported!(protocol)
      protocol.new(self).batch_results(id)
    end

    def files? # :nodoc:
      !!file_protocol
    end

    def list_models # :nodoc:
      default_protocol.new(self).list_models
    end

    # rubocop:disable Metrics/ParameterLists
    def embed(text, model:, dimensions:, task_type: nil, title: nil, provider_options: {}) # :nodoc:
      protocol = resolve_protocol(nil, model, operation: :embed)
      protocol.new(self, model).embed(text, model: model_id_for(model), dimensions:, task_type:, title:,
                                            provider_options:)
    end
    # rubocop:enable Metrics/ParameterLists

    def moderate(input, model:, provider_options: {}) # :nodoc:
      protocol = resolve_protocol(nil, model, operation: :moderate)
      protocol.new(self, model).moderate(input, model: model_id_for(model), provider_options:)
    end

    # rubocop:disable Metrics/ParameterLists
    def paint(prompt, model:, size:, with: nil, mask: nil, provider_options: {}) # :nodoc:
      protocol = resolve_protocol(nil, model, operation: :paint)
      protocol.new(self, model).paint(prompt, model: model_id_for(model), size:, with:, mask:, provider_options:)
    end
    # rubocop:enable Metrics/ParameterLists

    def speak(input, model:, voice:, format:, provider_options: {}) # :nodoc:
      protocol = resolve_protocol(nil, model, operation: :speak)
      protocol.new(self, model).speak(input, model: model_id_for(model), voice:, format:, provider_options:)
    end

    # rubocop:disable Metrics/ParameterLists
    def transcribe(audio_file, model:, language:, format: nil, speaker_names: nil, # :nodoc:
                   speaker_references: nil, provider_options: {}, prompt: nil, temperature: nil)
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
        temperature:
      )
    end
    # rubocop:enable Metrics/ParameterLists

    # rubocop:disable Metrics/ParameterLists
    def upload_file(file, filename: nil, purpose: nil, expires_in: nil, visibility: nil, # :nodoc:
                    display_name: nil, uri: nil, content_type: nil)
      ensure_files_supported!
      options = { filename:, purpose:, expires_in:, visibility:, display_name:, uri:, content_type: }
                .compact

      file_protocol.new(self).upload(file, **options)
    end
    # rubocop:enable Metrics/ParameterLists

    def find_file(file_id) # :nodoc:
      ensure_files_supported!
      file_protocol.new(self).find(file_id)
    end

    def download_file(file_id) # :nodoc:
      ensure_files_supported!
      file_protocol.new(self).download(file_id)
    end

    def list_file_uris(uri) # :nodoc:
      ensure_files_supported!
      file_protocol.new(self).list_uris(uri)
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
        error = body['error']
        return error if error.is_a?(String)

        [body.dig('error', 'message'), body['message'], body['detail']].find do |message|
          message.is_a?(String)
        end
      when Array
        body.map do |part|
          error = part['error']
          error.is_a?(String) ? error : part.dig('error', 'message')
        end.join('. ')
      else
        body
      end
    end

    class << self
      attr_reader :default_protocol, :file_protocol # :nodoc:
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

      # Returns a module that reports model capabilities (context
      # window, pricing, feature support) for the provider's model ids.
      # Used to fill in details the provider's model list API does not
      # return. The base implementation returns +nil+.
      def capabilities
        nil
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
      # protocol becomes the provider's default. Pass +batches:+ with a
      # module of batch operations to enable the batch API for that
      # protocol.
      #
      #   protocol :chat_completions, ChatCompletions
      #   protocol :responses, Protocols::Responses, batches: Protocols::Responses::Batches
      #
      def protocol(name, protocol_class, batches: nil)
        @default_protocol = name.to_sym if protocols.empty?
        protocols[name.to_sym] = protocol_class
        batch_protocol(name, batches) if batches
      end

      # Declares the protocol class that handles file uploads for the
      # provider.
      #
      #   files Protocols::OpenAI::Files
      #
      def files(protocol_class)
        @file_protocol = protocol_class
      end

      def protocols # :nodoc:
        @protocols ||= {}
      end

      def batch_protocol(name, batches) # :nodoc:
        batch_protocols[name.to_sym] = Class.new(protocols.fetch(name.to_sym)) { include batches }
      end

      def batch_protocols # :nodoc:
        @batch_protocols ||= {}
      end

      # Registers +provider_class+ under the slug +name+, making it
      # available to RubyLLM.chat and the other top-level helpers.
      # Stamps the class's slug, adds it to ::providers, and defines a
      # Configuration accessor for each of its configuration options.
      #
      #   RubyLLM::Provider.register :acme, RubyLLM::Providers::Acme
      #
      def register(name, provider_class)
        provider_class.slug = name.to_s
        providers[name.to_sym] = provider_class
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
      def resolve_registry_id(model_id, _models)
        model_id
      end

      # Returns the global registry of providers, a hash mapping slug
      # symbols to provider classes.
      def providers
        @providers ||= {}
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
      return if file_protocol

      raise Error, "#{slug} doesn't support file uploads"
    end

    def resolve_protocol(name, model, **request)
      explicit = name || configured_protocol
      explicit ? fetch_protocol(explicit) : protocol_for(model, **request)
    end

    def default_protocol
      fetch_protocol(configured_protocol || self.class.default_protocol)
    end

    def batch_protocol
      batch_protocol_for_name(self.class.default_protocol) || fetch_protocol(self.class.default_protocol)
    end

    def batch_protocol_for(_requests)
      batch_protocol
    end

    def batch_protocol_for_name(name)
      self.class.batch_protocols[name.to_sym]
    end

    def file_protocol
      self.class.file_protocol
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
  end
end
