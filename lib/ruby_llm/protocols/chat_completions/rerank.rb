# frozen_string_literal: true

module RubyLLM
  module Protocols
    class ChatCompletions
      # The Jina-style rerank endpoint several OpenAI-compatible providers
      # serve: OpenRouter at /api/v1/rerank and GPUStack at /v1/rerank,
      # with identical request and response shapes.
      module Rerank
        module_function

        def rerank_url
          'rerank'
        end

        def render_rerank_payload(query, documents, model:, top_n: nil, provider_options: {})
          {
            model: model,
            query: query,
            documents: documents,
            top_n: top_n
          }.compact.merge(provider_options)
        end

        def parse_rerank_response(response, model:, documents: [])
          data = response.body
          usage = data['usage'] || {}

          RubyLLM::Rerank.new(
            results: parse_rerank_results(data, documents),
            model: data['model'] || model,
            raw: data,
            input_tokens: usage['total_tokens'],
            reported_cost: usage['cost']
          )
        end

        def parse_rerank_results(data, documents = [])
          Array(data['results']).map do |result|
            index = result['index']

            RubyLLM::Rerank::Result.new(
              index: index,
              document: rerank_document(result['document']) || (index && documents[index]),
              score: result['relevance_score']
            )
          end
        end

        def rerank_document(document)
          document.is_a?(Hash) ? document['text'] : document
        end
      end
    end
  end
end
