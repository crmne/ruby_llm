# frozen_string_literal: true

require 'json'
require 'ruby_llm/error'

module RubyLLM
  # Base class for LLM providers. A provider knows where to talk (host, auth,
  # configuration) and which protocol to speak for a given model and request.
  # The protocols themselves live under RubyLLM::Protocols.
  class Provider
    attr_reader :config, :connection

    def initialize(config)
      @config = config
      ensure_configured!
      @connection = Connection.new(self, @config)
    end

    def api_base
      raise NotImplementedError
    end

    def headers
      {}
    end

    def slug
      self.class.slug
    end

    def name
      self.class.name
    end

    def capabilities
      self.class.capabilities
    end

    def configuration_requirements
      self.class.configuration_requirements
    end

    def protocols
      self.class.protocols
    end

    # Routing hook. Override to pick a protocol per model or request —
    # an explicit `with_protocol` or `config.<slug>_protocol` wins over this.
    def protocol_for(_model, **)
      default_protocol
    end

    # rubocop:disable Metrics/ParameterLists
    def complete(messages, tools:, temperature:, model:, params: {}, headers: {}, schema: nil, thinking: nil,
                 citations: false, tool_prefs: nil, protocol: nil, &)
      protocol_class = resolve_protocol(protocol, model, tools:, schema:, thinking:, tool_prefs:, citations:)
      protocol_class.new(self, model).complete(
        messages,
        tools: tools,
        tool_prefs: tool_prefs,
        temperature: temperature,
        params: params,
        headers: headers,
        schema: schema,
        thinking: thinking,
        citations: citations,
        &
      )
    end
    # rubocop:enable Metrics/ParameterLists

    def list_models
      default_protocol.new(self).list_models
    end

    def embed(text, model:, dimensions:)
      default_protocol.new(self).embed(text, model:, dimensions:)
    end

    def moderate(input, model:)
      default_protocol.new(self).moderate(input, model:)
    end

    def paint(prompt, model:, size:, with: nil, mask: nil, params: {}) # rubocop:disable Metrics/ParameterLists
      default_protocol.new(self).paint(prompt, model:, size:, with:, mask:, params:)
    end

    def transcribe(audio_file, model:, language:, **options)
      default_protocol.new(self).transcribe(audio_file, model:, language:, **options)
    end

    def configured?
      self.class.configured?(@config)
    end

    def local?
      self.class.local?
    end

    def assume_models_exist?
      self.class.assume_models_exist?
    end

    def parse_error(response)
      return if response.body.empty?

      body = try_parse_json(response.body)
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
      def name
        to_s.split('::').last
      end

      def slug
        name.downcase
      end

      def capabilities
        nil
      end

      def configuration_requirements
        []
      end

      def configuration_options
        []
      end

      def local?
        false
      end

      def remote?
        !local?
      end

      def assume_models_exist?
        false
      end

      def configured?(config)
        configuration_requirements.all? { |req| config.send(req) }
      end

      def protocol(name, protocol_class)
        @default_protocol = name.to_sym if protocols.empty?
        protocols[name.to_sym] = protocol_class
      end

      def protocols
        @protocols ||= {}
      end

      attr_reader :default_protocol

      def register(name, provider_class)
        providers[name.to_sym] = provider_class
        RubyLLM::Configuration.register_provider_options(provider_class.configuration_options + [:"#{name}_protocol"])
      end

      def resolve(name)
        providers[name.to_sym]
      end

      def providers
        @providers ||= {}
      end

      def local_providers
        providers.select { |_slug, provider_class| provider_class.local? }
      end

      def remote_providers
        providers.select { |_slug, provider_class| provider_class.remote? }
      end

      def configured_providers(config)
        providers.select do |_slug, provider_class|
          provider_class.configured?(config)
        end.values
      end

      def configured_remote_providers(config)
        providers.select do |_slug, provider_class|
          provider_class.remote? && provider_class.configured?(config)
        end.values
      end
    end

    private

    def resolve_protocol(name, model, **request)
      explicit = name || configured_protocol
      explicit ? fetch_protocol(explicit) : protocol_for(model, **request)
    end

    def default_protocol
      fetch_protocol(configured_protocol || self.class.default_protocol)
    end

    def configured_protocol
      @config.send(:"#{slug}_protocol")
    end

    def fetch_protocol(name)
      protocols.fetch(name.to_sym) do
        raise Error, "#{name} is not a protocol of #{self.class.name}. Available: #{protocols.keys.join(', ')}"
      end
    end

    def try_parse_json(maybe_json)
      return maybe_json unless maybe_json.is_a?(String)

      JSON.parse(maybe_json)
    rescue JSON::ParserError
      maybe_json
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
