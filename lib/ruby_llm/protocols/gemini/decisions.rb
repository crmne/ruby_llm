# frozen_string_literal: true

module RubyLLM
  module Protocols
    class Gemini
      class Decisions < Protocol # :nodoc:
        include SystemOne::Judgments
        include SystemOne::Responses

        def judge(...)
          super
        rescue BadRequestError => e
          raise unless %w[safety prohibited_content blocklist image_safety content_blocked].include?(e.error_code)

          raise ContentFilterError.new(response: e.response, provider: e.provider, error_code: e.error_code,
                                       provider_message: e.provider_message, redact: @config.redact_error_messages)
        end

        def judgment_url
          'decisions'
        end

        def render_judgment_payload(input, questions:, model:, with: [], provider_options: {})
          reserved = provider_options.keys.map(&:to_s) & %w[model input questions]
          unless reserved.empty?
            raise ArgumentError, "Use the judgment arguments instead of provider_options for #{reserved.join(', ')}"
          end

          {
            model: "models/#{model.delete_prefix('models/')}",
            input: render_input(input, with),
            questions: questions.transform_values { |question| render_question(question) }
          }.merge(provider_options)
        end

        def parse_judgment_response(response, questions:)
          body = response.body
          tokens = Tokens.new(input: body.dig('usage', 'total_input_tokens'), output: 0)
          @usage_tracker&.observe_tokens(tokens)

          answers = questions.values.to_h do |question|
            [question.name, parse_answer(body.fetch('answers').fetch(question.name.to_s), question)]
          end
          RubyLLM::Judgment.new(answers:, model: @model.id, raw: response, model_info: @model, tokens:)
        rescue KeyError, NoMethodError, TypeError => e
          raise Error.new('Gemini Decisions returned an invalid judgment', provider_message: e.message, response:,
                                                                           redact: @config&.redact_error_messages)
        end

        private

        def parse_score(answer, question)
          indexes = question.criteria.each_index.to_h { |index| [index.to_s, index] }
          RubyLLM::Score.new(
            score: answer.fetch('score'), levels: question.criteria,
            probabilities: parse_probabilities(answer.fetch('probabilities'), indexes),
            confidence: answer.fetch('confidence')
          )
        end

        def render_question(question)
          payload = super
          payload[:instructions] = describe(question.instructions)
          criteria = payload[:criteria]
          criteria = criteria.transform_keys { |key| "#{key}_description" } if question.type == :probability && criteria
          payload[:criteria] = case criteria
                               when Hash
                                 criteria.transform_keys(&:to_s).transform_values { |value| describe(value).to_s }
                               when Array then criteria.map { |value| describe(value).to_s }
                               end
          payload.compact
        end

        def render_input(input, attachments)
          text = describe(input)
          return text if attachments.empty?

          parts = attachments.map { |attachment| render_attachment(attachment) }
          parts.unshift({ type: 'text', text: }) unless text.nil? || text.empty?
          parts
        end

        def render_attachment(attachment)
          return { type: 'text', text: attachment.content } if attachment.text? && !attachment.provider_file?

          type = Interactions::Content.interaction_attachment_type(attachment)
          raise UnsupportedAttachmentError, attachment.mime_type unless type

          part = { type:, mime_type: attachment.mime_type }
          part[:resolution] = render_resolution(attachment) if attachment.resolution && type != 'audio'
          part.merge(Interactions::Content.interaction_attachment_source(attachment))
        end

        def render_resolution(attachment)
          level = attachment.resolution == :original ? :ultra_high : attachment.resolution
          level = :high if level == :ultra_high && !attachment.image?
          level.to_s
        end

        def describe(value)
          value.nil? || value.is_a?(String) ? value : JSON.generate(value)
        end
      end
    end
  end
end
