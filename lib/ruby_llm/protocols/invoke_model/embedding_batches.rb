# frozen_string_literal: true

module RubyLLM
  module Protocols
    class InvokeModel
      # Titan embedding requests over Bedrock's S3 batch job API.
      module EmbeddingBatches
        include Protocols::Bedrock::Batches

        private

        def bedrock_invocation_type
          'InvokeModel'
        end

        def validate_bedrock_batch_requests!(requests)
          requests.each do |request|
            values = request.fetch(:text)
            values = [values] unless values.is_a?(Array)
            unless values.any? && values.all? { |value| value.is_a?(String) && !value.empty? }
              raise ArgumentError, 'Bedrock embedding batches require nonempty text strings'
            end
            unless request.fetch(:payload).key?(:inputText)
              raise ArgumentError, 'Bedrock embedding batches require Titan embedding requests'
            end
          end
        end

        def bedrock_batch_jsonl(requests)
          requests.flat_map do |request|
            array = request.fetch(:text).is_a?(Array)
            texts = array ? request.fetch(:text) : [request.fetch(:text)]
            texts.each_with_index.map do |text, index|
              id = "rllm-#{request.fetch(:custom_id)}-#{index}-#{texts.size}-#{array ? 'a' : 's'}"
              JSON.generate(recordId: id, modelInput: batch_payload(request).merge(inputText: text))
            end
          end.join("\n")
        end

        def bedrock_job_name(input_uri, requests:)
          "ruby-llm-embed-#{requests.size}-#{Digest::SHA256.hexdigest(input_uri)[0, 16]}"
        end

        def parse_batch_response(data)
          super.merge(request_count: data['jobName'].to_s[/\Aruby-llm-embed-(\d+)-[0-9a-f]+\z/, 1]&.to_i)
        end

        def parse_bedrock_outputs(outputs, model:)
          records = outputs.flat_map { |body| body.to_s.each_line.map { |line| JSON.parse(line) } }
          groups = records.group_by { |record| embedding_record_id(record).first }
          groups.filter_map { |index, group| parse_embedding_batch_group(index, group, model:) }
        end

        def embedding_record_id(record)
          id = record['recordId'] || record['record_id']
          match = /\Arllm-(\d+)-(\d+)-(\d+)-([as])\z/.match(id.to_s)
          raise Error, "Unknown Bedrock embedding record ID: #{id.inspect}" unless match

          [Integer(match[1]), Integer(match[2]), Integer(match[3]), match[4] == 'a']
        end

        def parse_embedding_batch_group(index, records, model:)
          metadata = records.map { |record| embedding_record_id(record) }
          count = metadata.first[2]
          array = metadata.first[3]
          error = embedding_group_error(records, metadata)
          return [index, nil, batch_failure(index, error)] if error
          return if records.size < count

          ordered = records.sort_by { |record| embedding_record_id(record)[1] }
          unless ordered.map { |record| embedding_record_id(record)[1] } == (0...count).to_a
            return [index, nil, batch_failure(index, 'Invalid embedding record positions')]
          end

          parse_embedding_batch_result(index, ordered, model:, array:)
        end

        def embedding_group_error(records, metadata)
          return 'Invalid or duplicate embedding record positions' unless consistent_embedding_metadata?(metadata)

          error = records.find { |record| !record['modelOutput'] }
          return unless error

          batch_error_value(error['error']) || error['errorMessage'] || 'Bedrock returned no model output'
        end

        def consistent_embedding_metadata?(metadata)
          metadata.map { |item| item[2..] }.uniq.one? &&
            metadata.map { |item| item[1] }.uniq.size == metadata.size &&
            (metadata.first[3] || metadata.first[2] == 1)
        end

        def parse_embedding_batch_result(index, records, model:, array:)
          bodies = records.map { |record| record.fetch('modelOutput') }
          vectors = embedding_batch_vectors(bodies)
          return [index, nil, batch_failure(index, 'Bedrock returned no embedding')] unless vectors

          counts = bodies.map { |body| body['inputTextTokenCount'] }
          tokens = counts.sum if counts.all?
          result = Embedding.new(vectors: array ? vectors : vectors.first, model:, input_tokens: tokens)
          [index, result]
        end

        def embedding_batch_vectors(bodies)
          vectors = bodies.map { |body| extract_embedding(body) }
          vectors if vectors.all? { |vector| vector.is_a?(Array) && !vector.empty? && vector.all?(Numeric) }
        end
      end
    end
  end
end
