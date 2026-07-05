# frozen_string_literal: true

module RubyLLM
  module Providers
    # AWS Bedrock integration.
    class Bedrock < Provider
      include Bedrock::Auth
      include Bedrock::Models

      protocol :converse, Protocols::Converse, batches: Protocols::Converse::Batches
      protocol :bedrock_invoke_model, Protocols::BedrockInvokeModel
      files Bedrock::Files

      def api_base
        @config.bedrock_api_base || "https://bedrock-runtime.#{bedrock_region}.amazonaws.com"
      end

      def control_api_base
        @config.bedrock_api_base || "https://bedrock.#{bedrock_region}.amazonaws.com"
      end

      def headers
        {}
      end

      def complete(messages, model:, params: {}, **rest, &)
        super(messages, model:, params: normalize_params(params, model:), **rest, &)
      end

      def protocol_for(model, **)
        invoke_model?(model) ? fetch_protocol(:bedrock_invoke_model) : fetch_protocol(:converse)
      end

      def parse_error(response)
        return if response.body.nil? || response.body.empty?

        body = try_parse_json(response.body)
        return body if body.is_a?(String)

        body['message'] || body['Message'] || body['error'] || body['__type'] || super
      end

      def list_models
        response = signed_get(models_api_base, models_url)
        parse_list_models_response(response, slug, capabilities)
      end

      class << self
        def configuration_options
          %i[
            bedrock_api_key
            bedrock_secret_key
            bedrock_region
            bedrock_session_token
            bedrock_credential_provider
            bedrock_api_base
            bedrock_batch_s3_uri
            bedrock_batch_role_arn
            bedrock_use_invoke_model
            anthropic_beta
            anthropic_context_management
          ]
        end

        def configuration_requirements
          %i[bedrock_region]
        end

        def configured?(config)
          !!(config.bedrock_region && credentials_configured?(config))
        end

        def credentials_configured?(config)
          return credential_provider?(config) if config.bedrock_credential_provider

          !!(config.bedrock_api_key && config.bedrock_secret_key)
        end

        private

        def credential_provider?(config)
          config.bedrock_credential_provider&.respond_to?(:credentials)
        end
      end

      def ensure_configured!
        return if configured?

        missing = []
        missing << :bedrock_region unless @config.bedrock_region
        missing << bedrock_credentials_requirement unless self.class.credentials_configured?(@config)

        raise ConfigurationError, "Missing configuration for Bedrock: #{missing.join(', ')}"
      end

      private

      def bedrock_region
        @config.bedrock_region
      end

      def bedrock_credentials_requirement
        if @config.bedrock_credential_provider
          'bedrock_credential_provider responding to #credentials'
        else
          'bedrock_credential_provider or bedrock_api_key + bedrock_secret_key'
        end
      end

      def normalize_params(params, model:)
        normalized = RubyLLM::Utils.deep_symbolize_keys(params || {})
        additional_fields = normalized[:additionalModelRequestFields] || {}

        top_k = normalized.delete(:top_k)
        if !top_k.nil? && model_supports_top_k?(model)
          additional_fields = RubyLLM::Utils.deep_merge(additional_fields, { top_k: top_k })
        end

        normalized[:additionalModelRequestFields] = additional_fields unless additional_fields.empty?
        normalized
      end

      def model_supports_top_k?(model)
        Protocols::Converse.reasoning_embedded?(model)
      end

      # Returns true if the InvokeModel protocol should be used for this model.
      # `bedrock_use_invoke_model` can be:
      #   - false / nil  → always Converse (default)
      #   - true         → InvokeModel for all verifiably Anthropic models
      #   - Array        → InvokeModel when model.id is in the list
      #   - Proc/lambda  → InvokeModel when the callable returns truthy for model
      #
      # Vendor verification interacts with the selector in two tiers:
      #   - Ids that are provably non-Anthropic (a known vendor prefix like amazon./meta.,
      #     with or without a cross-region geo prefix) are never routed, under any selector —
      #     the InvokeModel payload is Anthropic Messages format and would be rejected.
      #   - Ids that cannot be verified either way — chiefly application-inference-profile
      #     ARNs, whose Model::Info carries no provider_name metadata on the
      #     assume_model_exists path — are routed when the selector opts in explicitly
      #     (Array or Proc). An operator naming the exact id IS the verification. Only the
      #     blanket `true` selector requires positive verification via anthropic_model?,
      #     because it expresses "all Anthropic models", not "this specific model".
      def invoke_model?(model)
        selector = @config.bedrock_use_invoke_model
        return false unless selector
        return false if non_anthropic_model?(model)

        case selector
        when true
          anthropic_model?(model)
        when Array
          selector.include?(model.id)
        else
          selector.respond_to?(:call) ? selector.call(model) : false
        end
      end

      NON_ANTHROPIC_VENDORS = %w[amazon meta ai21 cohere mistral writer stability].freeze
      private_constant :NON_ANTHROPIC_VENDORS

      # Matches known non-Anthropic vendor ids in both bare ("amazon.nova-pro-v1:0") and
      # cross-region ("us.amazon.nova-pro-v1:0") forms.
      NON_ANTHROPIC_PATTERN = /\A(?:[a-z0-9-]+\.)?(?:#{NON_ANTHROPIC_VENDORS.join('|')})\./
      private_constant :NON_ANTHROPIC_PATTERN

      # True only when the id provably belongs to a non-Anthropic vendor. ARNs return false:
      # they don't encode the vendor, so they are "unverifiable", not "non-Anthropic".
      def non_anthropic_model?(model)
        id = model.id.to_s
        return false if id.start_with?('arn:')

        NON_ANTHROPIC_PATTERN.match?(id)
      end

      def anthropic_model?(model)
        id = model.id.to_s
        # Standard Anthropic model ids start with "anthropic."
        return true if id.start_with?('anthropic.')

        # Cross-region inference profile ids prefix the vendor with a geo code
        # (us., eu., apac., global., jp., au., us-gov., ...): "us.anthropic.claude-sonnet-5".
        # Match any geo prefix followed by "anthropic." rather than enumerating regions AWS
        # may add. Cannot false-positive on other vendors' cross-region profiles
        # (e.g. "us.amazon.nova-pro-v1:0") since those don't contain "anthropic.".
        return true if id.match?(/\A[a-z0-9-]+\.anthropic\./)

        # Application-inference-profile ARNs do not encode the underlying vendor in the ARN
        # string itself. When available, consult model.metadata[:provider_name] (populated
        # by Bedrock::Models for registered foundation models) to confirm the profile is
        # Anthropic-backed. If that field is absent (e.g. an assume_model_exists chat, whose
        # Model::Info carries no registry metadata), log a warning and refuse to route rather
        # than silently forwarding an incompatible payload to a non-Anthropic model — the
        # operator can still opt in explicitly via an Array or Proc selector (see
        # invoke_model?).
        return arn_anthropic_model?(model, id) if id.start_with?('arn:')

        # Block known non-Anthropic Bedrock vendor prefixes (Nova, Llama, Jurassic, etc.).
        return false if NON_ANTHROPIC_PATTERN.match?(id)

        provider = model.respond_to?(:provider) ? model.provider : nil
        provider.to_s == 'anthropic'
      end

      def arn_anthropic_model?(model, id)
        provider_name = model.respond_to?(:metadata) ? model.metadata&.fetch(:provider_name, nil) : nil
        return provider_name.to_s.downcase == 'anthropic' if provider_name

        RubyLLM.logger.warn(
          "RubyLLM cannot verify that ARN model id #{id.inspect} is Anthropic-backed " \
          '(no provider_name in model.metadata). Refusing to route to BedrockInvokeModel. ' \
          'Use an Array or Proc selector with bedrock_use_invoke_model to opt in explicitly.'
        )
        false
      end
    end
  end
end
