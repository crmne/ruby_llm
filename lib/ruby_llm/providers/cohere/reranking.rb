# frozen_string_literal: true

module RubyLLM
  module Providers
    module Cohere
      # Reranking methods for the Cohere API integration
      # - https://docs.cohere.com/reference/rerank
      # - https://docs.cohere.com/docs/rerank-overview
      # - https://docs.cohere.com/docs/reranking-best-practices
      module Reranking
        module_function

        def rerank_url(...)
          'v2/rerank'
        end

        def render_rerank_payload(query, documents, model:, top_n:, max_tokens_per_doc:)
          @documents = documents

          {
            model: model,
            query: query,
            documents: @documents,
            top_n: top_n || documents.count,
            max_tokens_per_doc: max_tokens_per_doc || 4_096
          }
        end

        def parse_rerank_response(response, model:)
          data = response.body
          raise Error.new(response, data['message']) if data['message'] && response.status != 200

          results = data['results'] || []
          results = results.map do |r|
            RerankResult.new(
              index: r['index'],
              relevance_score: r['relevance_score'],
              document: @documents[r['index']]
            )
          end
          search_units = data.dig('meta', 'billed_units', 'search_units') || 0

          Rerank.new(results:, model:, search_units:)
        end
      end
    end
  end
end
