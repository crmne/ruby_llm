# frozen_string_literal: true

module RubyLLM
  module Protocols
    module Bedrock
      # Bedrock's document reranking API.
      class Rerank < Protocol
        def rerank(query, documents, model:, top_n: nil, provider_options: {})
          track_usage(:rerank) do
            payload = render_rerank_payload(query, documents, model:, top_n:, provider_options:)
            pages = rerank_pages(payload)
            parse_rerank_pages(pages, model:, documents:)
          end
        end

        private

        def render_rerank_payload(query, documents, model:, top_n:, provider_options:)
          validate_rerank_input(query, documents, top_n)
          payload = {
            queries: [{ type: 'TEXT', textQuery: { text: query } }],
            sources: documents.map { |document| render_rerank_source(document) },
            rerankingConfiguration: {
              type: 'BEDROCK_RERANKING_MODEL',
              bedrockRerankingConfiguration: {
                modelConfiguration: { modelArn: @provider.rerank_model_arn(model) },
                numberOfResults: top_n || documents.length
              }
            }
          }
          Support::Utils.deep_merge(payload, provider_options)
        end

        def validate_rerank_input(query, documents, top_n)
          unless query.is_a?(String) && !query.empty?
            raise ArgumentError, 'Bedrock reranking requires one nonempty text query'
          end
          unless documents.is_a?(Array) && (1..1000).cover?(documents.length)
            raise ArgumentError, 'Bedrock reranking accepts between 1 and 1000 documents'
          end
          return if top_n.nil? || (top_n.is_a?(Integer) && (1..1000).cover?(top_n))

          raise ArgumentError, 'Bedrock reranking top_n must be between 1 and 1000'
        end

        def render_rerank_source(document)
          content = case document
                    when String then { type: 'TEXT', textDocument: { text: document } }
                    when Hash then { type: 'JSON', jsonDocument: document }
                    else raise ArgumentError, 'Bedrock reranking documents must be text or JSON objects'
                    end
          { type: 'INLINE', inlineDocumentSource: content }
        end

        def rerank_pages(payload)
          pages = []
          seen = []
          loop do
            response = post_rerank(payload)
            @usage_tracker.succeed_attempts(tokens: [Tokens.new])
            pages << response.body
            token = response.body['nextToken']
            break if token.nil? || token.empty?
            raise Error.new('Bedrock reranking returned a repeated pagination token', response:) if seen.include?(token)

            seen << token
            payload = payload.merge(nextToken: token)
          end
          pages
        end

        def post_rerank(payload)
          @provider.agent_connection.post('/rerank', payload, usage: @usage_tracker) do |request|
            request.headers.merge!(@provider.sign_headers('POST', '/rerank', JSON.generate(payload),
                                                          base_url: @provider.agent_api_base))
          end
        end

        def parse_rerank_pages(pages, model:, documents:)
          results = pages.flat_map do |page|
            Array(page['results']).map do |item|
              index = item['index']
              unless index.is_a?(Integer) && index.between?(0, documents.length - 1)
                raise Error, 'Bedrock reranking returned an invalid document index'
              end

              RubyLLM::Rerank::Result.new(index:, document: documents[index], score: item['relevanceScore'])
            end
          end
          RubyLLM::Rerank.new(results:, model:, raw: pages.length == 1 ? pages.first : pages)
        end
      end
    end
  end
end
