# frozen_string_literal: true

module RubyLLM
  module Protocols
    class ChatCompletions
      # Embeddings methods of the OpenAI API integration
      module Embeddings
        module_function

        def embedding_url(...)
          'embeddings'
        end

        # rubocop:disable-next Lint/UnusedMethodArgument
        def render_embedding_payload(text, model:, dimensions:, task_type: nil, title: nil, provider_options: {})
          {
            model: model,
            input: text,
            dimensions: dimensions
          }.compact.merge(provider_options)
        end

        def parse_embedding_response(response, model:, text:)
          data = response.body
          input_tokens = data.dig('usage', 'prompt_tokens')
          rows = order_embedding_rows(data['data'])
          single = rows.length == 1 && !text.is_a?(Array)

          vectors = rows.map { |row| row['embedding'] }
          vectors = vectors.first if single
          sparse_vectors = parse_sparse_vectors(rows, single: single)

          Embedding.new(vectors:, sparse_vectors:, model:, input_tokens:,
                        reported_cost: reported_cost(data['usage'] || {}))
        end

        # A row's index names the input its vector belongs to, so rows are put
        # back in that order and positions that are not exactly 0...N raise
        # rather than pairing vectors with the wrong texts. Servers that send
        # no index keep the order of the response.
        def order_embedding_rows(rows)
          return rows if rows.none? { |row| row.key?('index') }
          raise Error, 'Invalid or duplicate embedding record positions' unless valid_embedding_positions?(rows)

          rows.sort_by { |row| row['index'] }
        end

        def valid_embedding_positions?(rows)
          positions = rows.map { |row| row.is_a?(Hash) ? row['index'] : nil }

          positions.all?(Integer) && positions.sort == (0...positions.size).to_a
        end

        # Sparse-capable models return a token-to-weight map beside the dense
        # vector, under lexical_weights on BGE-M3 and sparse_embedding
        # elsewhere. It is an extension: dense-only servers send neither, and
        # then there is nothing to report.
        def parse_sparse_vectors(rows, single:)
          sparse = rows.map { |row| normalize_sparse_vector(row['sparse_embedding'] || row['lexical_weights']) }
          return nil if sparse.all?(&:nil?)

          single ? sparse.first : sparse
        end

        def normalize_sparse_vector(weights)
          return nil unless weights.is_a?(Hash)

          weights.to_h { |token, weight| [Integer(token), Float(weight)] }
        end

        def reported_cost(_usage)
          nil
        end
      end
    end
  end
end
