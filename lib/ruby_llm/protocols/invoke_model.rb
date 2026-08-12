# frozen_string_literal: true

module RubyLLM
  module Protocols
    # The AWS InvokeModel API, where the envelope is shared but each model
    # family owns its request and response body. Subclasses under
    # Protocols::InvokeModel implement one family each. Requests are signed
    # by the provider, which knows the credentials and the signing service.
    class InvokeModel < Protocol
      private

      def signed_post(url, payload, additional_headers = {})
        body = JSON.generate(payload)

        @connection.post(url, payload, usage: @usage_tracker) do |req|
          req.headers.merge!(@provider.sign_headers('POST', url, body))
          req.headers.merge!(additional_headers) unless additional_headers.empty?
        end
      end

      def embedding_url(model:)
        "/model/#{model}/invoke"
      end

      def ensure_no_embedding_media!(with)
        attachments = Attachment.wrap(with)
        raise UnsupportedAttachmentError, attachments.first.mime_type if attachments.any?
      end

      def parse_single_embedding_responses(responses, model:, text:)
        vectors = responses.map { |response| extract_embedding(response.body) }
        input_tokens = Tokens.aggregate(embedding_attempt_tokens(responses)).input
        vectors = vectors.first unless text.is_a?(Array)

        Embedding.new(vectors:, model:, input_tokens:)
      end

      def record_embedding_attempt(response)
        @usage_tracker&.succeed_attempts(tokens: embedding_attempt_tokens([response]))
      end

      def embedding_attempt_tokens(responses)
        responses.map { |response| Tokens.new(input: response.body['inputTextTokenCount']) }
      end

      def deep_merge_provider_options(payload, provider_options)
        return payload if provider_options.empty?

        Utils.deep_merge(payload, provider_options)
      end

      def extract_embedding(body)
        body['embedding'] || body.dig('embeddingsByType', 'float') || body['embeddingsByType']&.values&.first
      end
    end
  end
end
