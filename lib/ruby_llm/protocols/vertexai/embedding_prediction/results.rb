# frozen_string_literal: true

module RubyLLM
  module Protocols
    module VertexAI
      class EmbeddingPrediction
        # Regroups provider output rows into the submitted embedding requests.
        module Results
          private

          def embedding_row_metadata(row)
            key = row['key'] || row.dig('instance', 'key')
            match = /\Arllm-(\d+)-(\d+)-(\d+)-([as])\z/.match(key.to_s)
            raise Error, "Unknown Vertex AI embedding record key: #{key.inspect}" unless match

            [Integer(match[1]), Integer(match[2]), Integer(match[3]), match[4] == 'a']
          end

          def parse_embedding_batch_group(index, rows, model:)
            metadata = rows.map { |row| embedding_row_metadata(row) }
            error = embedding_group_error(rows, metadata)
            return [index, nil, batch_failure(index, error)] if error
            return if rows.size < metadata.first[2]

            ordered = rows.sort_by { |row| embedding_row_metadata(row)[1] }
            parse_embedding_batch_result(index, ordered, model:, array: metadata.first[3])
          end

          def parse_embedding_batch_result(index, rows, model:, array:)
            vectors = embedding_batch_vectors(rows)
            return [index, nil, batch_failure(index, 'Vertex AI returned no valid embedding')] unless vectors

            counts = rows.map { |row| embedding_batch_tokens(row) }
            result = Embedding.new(vectors: array ? vectors : vectors.first,
                                   model:, input_tokens: (counts.sum if counts.all?))
            [index, result]
          end

          def embedding_group_error(rows, metadata)
            unless valid_embedding_metadata?(metadata)
              return 'Invalid or duplicate Vertex AI embedding record positions'
            end

            rows.filter_map { |row| batch_error_value(row['error']) || batch_error_value(row['status']) }
                .find { |error| !error.empty? }
          end

          def valid_embedding_metadata?(metadata)
            count = metadata.first[2]
            positions = metadata.map { |entry| entry[1] }
            return false unless metadata.first[3] || count == 1

            metadata.map { |entry| entry[2..] }.uniq.one? && count.positive? &&
              positions.uniq.size == positions.size && positions.max < count
          end

          def embedding_batch_vectors(rows)
            vectors = rows.map do |row|
              row.dig('response', 'embedding', 'values') || row.dig('predictions', 0, 'embeddings', 'values')
            end
            vectors if vectors.all? { |vector| vector.is_a?(Array) && vector.any? && vector.all?(Numeric) }
          end

          def embedding_batch_tokens(row)
            value = row.dig('response', 'tokenCount') ||
                    row.dig('response', 'usageMetadata', 'promptTokenCount') ||
                    row.dig('predictions', 0, 'embeddings', 'statistics', 'token_count')
            Integer(value) unless value.nil?
          end
        end
      end
    end
  end
end
