# frozen_string_literal: true

module RubyLLM
  module Protocols
    class Gemini
      # Inline embedding requests and results for Gemini's asynchronous Batch API.
      module EmbeddingBatches
        private

        def embedding_batch?(requests)
          kinds = requests.map { |request| embedding_batch_payload?(request.fetch(:payload)) }.uniq
          raise Error, 'Gemini batches take chat or embedding requests, not both' if kinds.size > 1

          kinds.first
        end

        def embedding_batch_payload?(payload)
          payload.key?(:content) || payload.key?(:requests)
        end

        def embedding_batch_response?(data)
          batch = data['metadata'] || data
          batch['@type']&.end_with?('.EmbedContentBatch') ||
            data.dig('response', '@type')&.end_with?('.EmbedContentBatchOutput') ||
            data.dig('response', 'inlinedEmbedContentResponses') ||
            data.dig('output', 'inlinedEmbedContentResponses')
        end

        def embedding_batch_requests(request, model)
          payload = request.fetch(:payload)
          array_input = payload.key?(:requests)
          inputs = array_input ? payload.fetch(:requests) : [payload]
          raise ArgumentError, 'Gemini embedding batches require at least one text per request' if inputs.empty?

          inputs.each_with_index.map do |input, index|
            {
              request: input.merge(model: "models/#{model}"),
              metadata: {
                custom_id: request.fetch(:custom_id), model:, array_input:,
                embedding_index: index, embedding_count: inputs.size
              }
            }
          end
        end

        def parse_embedding_batch_results(responses)
          identified, unidentified = responses.partition { |inline| inline.dig('metadata', 'custom_id') }
          RubyLLM.logger.warn 'Gemini returned batch results without metadata' if unidentified.any?

          identified.group_by { |inline| inline.dig('metadata', 'custom_id') }.filter_map do |key, group|
            parse_embedding_batch_group(key, group)
          end
        end

        def parse_embedding_batch_group(key, responses)
          index = batch_result_index(key)
          error = responses.find { |inline| inline['error'] }
          return [index, nil, batch_failure(key, error.dig('error', 'message'))] if error

          metadata = responses.first.fetch('metadata')
          return if responses.size < metadata.fetch('embedding_count')

          parse_embedding_batch_slot(index, key, responses, metadata)
        end

        def parse_embedding_batch_slot(index, key, responses, metadata)
          positions = responses.map { |inline| inline.dig('metadata', 'embedding_index') }
          unless positions.sort == (0...responses.size).to_a
            return [index, nil, batch_failure(key, 'Invalid or duplicate embedding record positions')]
          end

          vectors = embedding_batch_vectors(responses)
          return [index, nil, batch_failure(key, 'Gemini returned no embedding')] unless vectors

          embedding = Embedding.new(
            vectors: metadata['array_input'] ? vectors : vectors.first,
            model: metadata.fetch('model'), input_tokens: embedding_batch_tokens(responses)
          )
          [index, embedding]
        end

        def embedding_batch_vectors(responses)
          ordered = responses.sort_by { |inline| inline.dig('metadata', 'embedding_index') }
          vectors = ordered.map { |inline| inline.dig('response', 'embedding', 'values') }
          vectors if vectors.all? { |vector| vector && !vector.empty? }
        end

        def embedding_batch_tokens(responses)
          counts = responses.filter_map { |inline| inline.dig('response', 'usageMetadata', 'promptTokenCount') }
          counts.sum unless counts.empty?
        end
      end
    end
  end
end
