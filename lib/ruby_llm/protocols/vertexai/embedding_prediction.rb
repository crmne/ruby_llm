# frozen_string_literal: true

module RubyLLM
  module Protocols
    module VertexAI
      # Text embeddings over Vertex AI's Cloud Storage batch prediction API.
      class EmbeddingPrediction < Protocol
        include BatchPrediction
        include Requests
        include Results

        LEGACY_MODELS = %w[text-embedding-004 text-embedding-005 text-multilingual-embedding-002].freeze
        GEMINI_MODELS = %w[gemini-embedding-001 gemini-embedding-2].freeze
        MODELS = (LEGACY_MODELS + GEMINI_MODELS).freeze

        private

        def validate_batch_requests!(requests)
          @requests = requests
          model = requests.first.fetch(:model)
          unless MODELS.include?(model)
            raise Error,
                  "Vertex AI embedding batches are not supported for #{model.inspect}"
          end

          requests.each { |request| validate_embedding_request!(request) }
          return unless LEGACY_MODELS.include?(model)
          return if requests.map { |request| request.fetch(:payload).fetch(:parameters, {}) }.uniq.one?

          raise ArgumentError,
                'Vertex AI legacy embedding batches require the same dimensions and parameters in every request'
        end

        def vertex_batch_job(model, input_uri, output_uri)
          job = super.merge(labels: { ruby_llm_request_count: @requests.size.to_s })
          return job unless LEGACY_MODELS.include?(model)

          job.merge(instanceConfig: { instanceType: 'object', keyField: 'key' },
                    modelParameters: @requests.first.fetch(:payload).fetch(:parameters, {}))
        end

        def vertex_batch_jsonl(requests)
          rows = requests.flat_map { |request| render_embedding_batch_rows(request) }
          rows.map { |row| JSON.generate(row) }.join("\n")
        end

        def parse_vertex_batch_results(rows, job:)
          model = job.fetch('model').split('/').last
          rows.group_by { |row| embedding_row_metadata(row).first }.filter_map do |index, group|
            parse_embedding_batch_group(index, group, model:)
          end
        end
      end
    end
  end
end
