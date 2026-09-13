# frozen_string_literal: true

module RubyLLM
  module Protocols
    class Cohere
      # Rerank methods for the Cohere v2 API integration
      module Rerank
        module_function

        def rerank_url
          'v2/rerank'
        end

        def render_rerank_payload(query, documents, model:, top_n: nil, provider_options: {})
          {
            model: model,
            query: query,
            documents: documents,
            top_n: top_n
          }.compact.merge(provider_options)
        end

        # Cohere returns positions and scores only, so the ranked text comes
        # back from the documents that were sent.
        def parse_rerank_response(response, model:, documents: [])
          data = response.body
          billed = data.dig('meta', 'billed_units') || {}
          tokens = data.dig('meta', 'tokens') || {}

          RubyLLM::Rerank.new(
            results: parse_rerank_results(data, documents),
            model: model,
            raw: data,
            input_tokens: tokens['input_tokens'] || billed['input_tokens']
          )
        end

        def parse_rerank_results(data, documents)
          Array(data['results']).map do |result|
            index = result['index']
            unless valid_rerank_index?(index, documents)
              raise Error, 'Cohere reranking returned an invalid document index'
            end

            RubyLLM::Rerank::Result.new(
              index: index,
              document: result.dig('document', 'text') || documents[index],
              score: result['relevance_score']
            )
          end
        end

        # A negative index is a valid Ruby array index (it wraps from the
        # end) and an out-of-range positive one just returns nil, so an
        # unchecked index would substitute the wrong document, or a missing
        # one, without ever raising.
        def valid_rerank_index?(index, documents)
          index.is_a?(Integer) && index.between?(0, documents.length - 1)
        end
      end
    end
  end
end
