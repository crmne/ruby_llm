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

        def parse_rerank_response(response, model:)
          data = response.body
          usage = data['usage'] || {}

          RubyLLM::Rerank.new(
            results: parse_rerank_results(data),
            model: data['model'] || model,
            raw: data,
            input_tokens: usage['total_tokens'],
            reported_cost: usage['cost']
          )
        end

        def parse_rerank_results(data)
          Array(data['results']).map do |result|
            RubyLLM::Rerank::Result.new(
              index: result['index'],
              document: result.dig('document', 'text') || result['document'],
              score: result['relevance_score']
            )
          end
        end
      end
    end
  end
end
