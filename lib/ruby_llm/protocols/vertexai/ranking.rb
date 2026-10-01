# frozen_string_literal: true

module RubyLLM
  module Protocols
    module VertexAI
      # Vertex AI Search's Discovery Engine ranking API.
      class Ranking < Protocol
        def initialize(provider, model = nil)
          super
          @connection = provider.ranking_connection
        end

        def rerank_url
          "#{@provider.ranking_config}:rank"
        end

        def render_rerank_payload(query, documents, model:, top_n: nil, provider_options: {})
          raise ArgumentError, 'Vertex AI Search reranking documents must be text' unless documents.all?(String)

          records = documents.each_with_index.map { |document, index| { id: index.to_s, content: document } }
          { model: model, query: query, records: records, topN: top_n }.compact.merge(provider_options)
        end

        def parse_rerank_response(response, model:, documents: [])
          seen = Set.new
          results = Array(response.body['records']).map do |record|
            index = ranking_index(record, documents)
            raise Error.new('Vertex AI Search returned a duplicate document id', response:) unless seen.add?(index)

            Rerank::Result.new(index: index, document: documents[index], score: record['score'])
          end
          Rerank.new(results: results, model: model, raw: response.body)
        end

        private

        def ranking_index(record, documents)
          id = record['id']
          unless id.is_a?(String) && id.match?(/\A(?:0|[1-9]\d*)\z/) && id.to_i < documents.length
            raise Error, 'Vertex AI Search returned an invalid document id'
          end

          id.to_i
        end
      end
    end
  end
end
