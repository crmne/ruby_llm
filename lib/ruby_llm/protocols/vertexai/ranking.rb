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
          validate_ranking_input(query, documents, top_n)
          records = documents.each_with_index.map { |document, index| { id: index.to_s, content: document } }
          { model: model, query: query, records: records, topN: top_n }.compact.merge(provider_options)
        end

        def parse_rerank_response(response, model:, documents: [])
          records = response.body['records']
          raise Error.new('Vertex AI Search returned no ranking records', response:) unless records.is_a?(Array)

          seen = []
          results = records.map do |record|
            index = ranking_index(record, documents)
            raise Error.new('Vertex AI Search returned a duplicate document id', response:) if seen.include?(index)

            seen << index
            Rerank::Result.new(index: index, document: documents[index], score: record.fetch('score'))
          end
          Rerank.new(results: results, model: model, raw: response.body)
        end

        private

        def validate_ranking_input(query, documents, top_n)
          unless query.is_a?(String) && !query.empty?
            raise ArgumentError, 'Vertex AI Search reranking requires a nonempty query'
          end
          unless valid_ranking_documents?(documents)
            raise ArgumentError, 'Vertex AI Search reranking accepts between 1 and 1000 nonempty text documents'
          end
          return if top_n.nil? || (top_n.is_a?(Integer) && top_n.positive?)

          raise ArgumentError, 'top_n must be a positive integer'
        end

        def valid_ranking_documents?(documents)
          documents.is_a?(Array) && (1..1000).cover?(documents.length) &&
            documents.all? { |document| document.is_a?(String) && !document.empty? }
        end

        def ranking_index(record, documents)
          id = record['id'] if record.is_a?(Hash)
          unless id.is_a?(String) && id.match?(/\A(?:0|[1-9]\d*)\z/) && id.to_i < documents.length &&
                 record['score'].is_a?(Numeric)
            raise Error, 'Vertex AI Search returned an invalid document id or score'
          end

          id.to_i
        end
      end
    end
  end
end
