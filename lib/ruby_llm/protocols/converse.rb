# frozen_string_literal: true

module RubyLLM
  module Protocols
    # The AWS Bedrock Converse API. Requests are SigV4-signed by the provider.
    class Converse < Protocol
      include Converse::Chat
      include Converse::Media
      include Converse::Streaming

      # The budgetTokens entry of the model's additionalRequestFieldsSchema, which Bedrock
      # publishes as a JSON string. Models that expose one only accept a token budget for
      # reasoning, never an effort level.
      def self.reasoning_budget_schema(model)
        budget_tokens_schema(model) || budget_tokens_schema(region_sibling(model))
      end

      def self.budget_tokens_schema(model)
        metadata = RubyLLM::Utils.deep_symbolize_keys(model&.metadata || {})
        raw_schema = metadata.dig(:converse, :additionalRequestFieldsSchema)
        return nil unless raw_schema.is_a?(String)

        schema = begin
          JSON.parse(raw_schema, symbolize_names: true)
        rescue JSON::ParserError
          nil
        end

        budget = schema.is_a?(Hash) ? schema.dig(:reasoningConfig, :budgetTokens) : nil
        budget.is_a?(Hash) ? budget : nil
      end

      # Bedrock only publishes converse metadata for some regional entries of a foundation
      # model, so fall back to a sibling entry that carries it.
      def self.region_sibling(model)
        return nil unless model

        foundation_id = foundation_model_id(model.id)
        RubyLLM.models.all.find do |candidate|
          candidate.provider == 'bedrock' && candidate.id != model.id &&
            foundation_model_id(candidate.id) == foundation_id && budget_tokens_schema(candidate)
        end
      end

      def self.foundation_model_id(model_id)
        prefixes = Providers::Bedrock::Models::REGION_PREFIXES.join('|')
        model_id.to_s.sub(/\A(?:#{prefixes})\./, '')
      end

      private

      def sync_response(payload, additional_headers = {})
        response = signed_post(completion_url, payload, additional_headers)
        parse_completion_response(response)
      end

      def signed_post(url, payload, additional_headers = {})
        body = JSON.generate(payload)

        @connection.post(url, payload, usage: @usage_tracker) do |req|
          req.headers.merge!(@provider.sign_headers('POST', url, body))
          req.headers.merge!(additional_headers) unless additional_headers.empty?
        end
      end
    end
  end
end
