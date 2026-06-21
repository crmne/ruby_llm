# frozen_string_literal: true

module RubyLLM
  module Protocols
    class Gemini
      # Gemini Batch API with inlined generateContent requests.
      module Batches
        include RubyLLM::Batch::Helpers

        # The wire enum is BATCH_STATE_*; the SDKs print JOB_STATE_*. Match the
        # suffix so either spelling works.
        TERMINAL = %w[SUCCEEDED FAILED CANCELLED EXPIRED].freeze
        private_constant :TERMINAL

        def create_batch(requests)
          model = single_batch_model!(requests, 'gemini')
          response = @connection.post("models/#{model}:batchGenerateContent", {
                                        batch: {
                                          displayName: "ruby_llm_#{SecureRandom.hex(8)}",
                                          inputConfig: {
                                            requests: {
                                              requests: requests.map { |request| gemini_batch_request(request, model) }
                                            }
                                          }
                                        }
                                      })

          parse_batch_response(response.body)
        end

        def find_batch(id)
          parse_batch_response @connection.get(batch_name(id)).body
        end

        def cancel_batch(id)
          @connection.post("#{batch_name(id)}:cancel", {})
          find_batch(id)
        end

        # Inline answers are correlated by the key we sent (the submission index);
        # Gemini also returns them in order, so we fall back to position.
        def batch_results(id)
          inlined = @connection.get(batch_name(id)).body.dig('output', 'inlinedResponses', 'inlinedResponses') || []
          inlined.each_with_index.map { |response, index| parse_inline_response(response, index) }
        end

        private

        def gemini_batch_request(request, model)
          {
            request: batch_params(request).merge(model: "models/#{model}"),
            metadata: {
              custom_id: request[:custom_id]
            }
          }
        end

        def batch_name(id)
          id.to_s.start_with?('batches/') ? id : "batches/#{id}"
        end

        # A batch starts as an Operation wrapping the batch in `metadata`; polling
        # returns the batch directly. Read either shape.
        def parse_batch_response(data)
          batch = data['metadata'] || data
          state = batch['state']

          {
            id: data['name'] || batch['name'],
            status: state,
            completed: TERMINAL.any? { |terminal| state&.end_with?(terminal) },
            request_counts: batch['batchStats']
          }
        end

        def parse_inline_response(inline, index)
          key = inline.dig('metadata', 'custom_id') || inline.dig('metadata', 'key')
          index = batch_result_index(key) if key

          if inline['response']
            body = inline['response']
            [index, parse_completion_body(body, raw: body)]
          else
            batch_failure(key || index, inline.dig('error', 'message'))
            [index, nil]
          end
        end
      end
    end
  end
end
