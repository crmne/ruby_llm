# frozen_string_literal: true

module RubyLLM
  module Protocols
    module OpenAI
      # OpenAI Decisions: typed questions answered with probabilities.
      class Decisions < Protocol
        TYPES = { probability: 'predicate', choice: 'choice', score: 'score' }.freeze
        OUTCOMES = { 'yes' => 'Yes', 'true' => 'Yes', 'no' => 'No', 'false' => 'No' }.freeze
        MAX_QUESTIONS = 64

        def judgment_url
          'decisions'
        end

        def render_judgment_payload(input, questions:, model:, with: [], provider_options: {})
          reserved = provider_options.keys.map(&:to_s) & %w[model input questions]
          unless reserved.empty?
            raise ArgumentError, "Use the judgment arguments instead of provider_options for #{reserved.join(', ')}"
          end
          if questions.size > MAX_QUESTIONS
            raise ArgumentError, "OpenAI Decisions supports at most #{MAX_QUESTIONS} questions"
          end

          {
            model:,
            input: render_input(input, with),
            questions: questions.values.map { |question| render_question(question) }
          }.merge(provider_options)
        end

        def parse_judgment_response(response, questions:)
          body = response.body
          unless judgment_body?(body, questions)
            raise Error.new('OpenAI Decisions returned an invalid judgment response', response:)
          end

          answers = questions.values.zip(body['answers']).to_h do |question, answer|
            [question.name, parse_answer(answer, question)]
          end
          RubyLLM::Judgment.new(answers:, model: body['model'], raw: response, model_info: @model,
                                tokens: parse_tokens(body['usage']))
        rescue ArgumentError, KeyError, TypeError => e
          raise Error.new("OpenAI Decisions returned an invalid judgment: #{e.message}", response:)
        end

        private

        def render_input(input, attachments)
          text = describe(input)
          return text if attachments.empty?

          attachments.each { |attachment| validate_image(attachment) }
          content = attachments.map { |attachment| render_image(attachment) }
          content.unshift({ type: 'input_text', text: }) unless text.nil? || text.empty?
          [{ type: 'message', role: 'user', content: }]
        end

        def validate_image(attachment)
          raise UnsupportedAttachmentError, 'uploaded file' if attachment.provider_file?
          raise UnsupportedAttachmentError, attachment.mime_type unless attachment.image?
        end

        def render_image(image)
          part = { type: 'input_image', image_url: image.for_llm }
          return part unless image.resolution

          part.merge(detail: image.resolution == :low ? 'low' : 'high')
        end

        def render_question(question)
          question_payload = { type: TYPES.fetch(question.type), name: question.name.to_s,
                               instructions: render_instructions(question) }

          case question.type
          when :choice then question_payload.merge(choices: render_choices(question))
          when :score then question_payload.merge(levels: render_levels(question))
          else question_payload
          end
        end

        def render_instructions(question)
          lines = [describe(question.instructions)]
          if question.type == :probability && question.criteria
            question.criteria.each do |outcome, description|
              lines << "#{OUTCOMES.fetch(outcome.to_s)}: #{describe(description)}" unless description.nil?
            end
          end
          instructions = lines.compact.join("\n")
          raise ArgumentError, "OpenAI Decisions needs instructions for #{question.name}" if instructions.empty?

          instructions
        end

        def render_choices(question)
          raise ArgumentError, 'OpenAI Decisions choices need at least two options' if question.criteria.size < 2

          question.criteria.map do |value, description|
            { value: value.to_s, description: describe(description) }.compact
          end
        end

        def render_levels(question)
          question.criteria.each_with_index.map do |description, index|
            { label: index.to_s, description: describe(description) }
          end
        end

        def describe(value)
          value.nil? || value.is_a?(String) ? value : JSON.generate(value)
        end

        def judgment_body?(body, questions)
          body.is_a?(Hash) && body['model'].is_a?(String) && !body['model'].empty? &&
            body['answers'].is_a?(Array) && body['answers'].size == questions.size
        end

        def parse_answer(answer, question)
          unless answer.is_a?(Hash) && answer['type'] == TYPES.fetch(question.type)
            raise ArgumentError, "Unexpected answer type for #{question.name}"
          end
          unless answer['name'].nil? || answer['name'] == question.name.to_s
            raise ArgumentError, "Unexpected answer order at #{question.name}"
          end

          case question.type
          when :probability then RubyLLM::Probability.new(probability: parse_probability(answer.fetch('probability')))
          when :choice then parse_choice(answer, question)
          when :score then parse_score(answer, question)
          end
        end

        def parse_choice(answer, question)
          options = question.criteria.keys.to_h { |key| [key.to_s, key] }
          RubyLLM::Choice.new(
            choice: options.fetch(answer.fetch('choice')),
            probabilities: parse_distribution(answer.fetch('probabilities'), 'value', options),
            confidence: parse_probability(answer.fetch('confidence'))
          )
        end

        def parse_score(answer, question)
          indexes = question.criteria.each_index.to_h { |index| [index.to_s, index] }
          value = answer.fetch('score')
          unless finite_number?(value) && value.between?(0, indexes.size - 1)
            raise ArgumentError, "Invalid score for #{question.name}"
          end

          RubyLLM::Score.new(
            score: value, levels: question.criteria,
            probabilities: parse_distribution(answer.fetch('probabilities'), 'label', indexes),
            confidence: parse_probability(answer.fetch('confidence'))
          )
        end

        def parse_distribution(entries, key, names)
          unless entries.is_a?(Array) && entries.all?(Hash)
            raise ArgumentError, 'Probability distributions must be lists of entries'
          end

          values = entries.to_h { |entry| [entry[key], entry['probability']] }
          unless values.size == entries.size && values.keys.sort_by(&:to_s) == names.keys.sort
            raise ArgumentError, 'Unexpected probability distribution entries'
          end

          names.to_h { |wire, name| [name, parse_probability(values.fetch(wire))] }
        end

        def parse_probability(value)
          return value if finite_number?(value) && value.between?(0, 1)

          raise ArgumentError, 'Probabilities and confidence must be numbers between 0 and 1'
        end

        def finite_number?(value)
          value.is_a?(Integer) || (value.is_a?(Float) && value.finite?)
        end

        def parse_tokens(usage)
          raise ArgumentError, 'Missing usage' unless usage.is_a?(Hash)

          tokens = Responses::Chat.parse_usage(usage)
          Tokens.new(input: tokens[:input_tokens], output: tokens[:output_tokens],
                     cache_read: tokens[:cache_read_tokens], cache_write: tokens[:cache_write_tokens])
        end
      end
    end
  end
end
