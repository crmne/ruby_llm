# frozen_string_literal: true

module RubyLLM
  module Protocols
    class SystemOne
      module Judgments # :nodoc:
        TYPES = { probability: 'noul', choice: 'choice', score: 'score' }.freeze
        BOOLEAN_KEYS = { 'yes' => 'true', 'true' => 'true', 'no' => 'false', 'false' => 'false' }.freeze

        module_function

        def judgment_url
          'v1/systemone'
        end

        def render_judgment_payload(input, questions:, model:, with: [], provider_options: {})
          raise UnsupportedAttachmentError, with.first.mime_type unless with.empty?

          reserved = provider_options.keys.map(&:to_s) & %w[model state questions]
          unless reserved.empty?
            raise ArgumentError, "Use the judgment arguments instead of provider_options for #{reserved.join(', ')}"
          end

          {
            model:,
            state: input,
            questions: questions.transform_values { |question| render_question(question) }
          }.merge(provider_options)
        end

        def render_question(question)
          criteria = question.criteria
          if question.type == :probability && criteria
            criteria = criteria.transform_keys { |key| BOOLEAN_KEYS.fetch(key.to_s) }
          end

          { type: TYPES.fetch(question.type), instructions: question.instructions, criteria: }.compact
        end
      end
    end
  end
end
