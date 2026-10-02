# frozen_string_literal: true

module RubyLLM
  module Protocols
    module OpenAI
      # OpenAI Decisions: typed questions answered with probabilities.
      class Decisions < Protocol
        TYPES = { probability: 'predicate', choice: 'choice', score: 'score' }.freeze
        OUTCOMES = { 'yes' => 'Yes', 'true' => 'Yes', 'no' => 'No', 'false' => 'No' }.freeze

        def judgment_url
          'decisions'
        end

        def render_judgment_payload(input, questions:, model:, with: [], provider_options: {})
          reserved = provider_options.keys.map(&:to_s) & %w[model input questions]
          unless reserved.empty?
            raise ArgumentError, "Use the judgment arguments instead of provider_options for #{reserved.join(', ')}"
          end

          {
            model:,
            input: render_input(input, with),
            questions: questions.values.map { |question| render_question(question) }
          }.merge(provider_options)
        end

        def parse_judgment_response(response, questions:)
          body = response.body
          answers = questions.values.zip(body.fetch('answers')).to_h do |question, answer|
            [question.name, parse_answer(answer, question)]
          end
          RubyLLM::Judgment.new(answers:, model: body.fetch('model'), raw: response, model_info: @model,
                                tokens: parse_tokens(body['usage']))
        rescue KeyError, NoMethodError, TypeError => e
          raise Error.new("OpenAI Decisions returned an invalid judgment: #{e.message}", response:)
        end

        private

        def render_input(input, attachments)
          text = describe(input)
          return text if attachments.empty?

          content = attachments.map { |attachment| render_image(attachment) }
          content.unshift({ type: 'input_text', text: }) unless text.nil? || text.empty?
          [{ type: 'message', role: 'user', content: }]
        end

        def render_image(image)
          raise UnsupportedAttachmentError, image.mime_type unless image.image?
          return { type: 'input_image', file_id: image.provider_file_id } if image.provider_file?

          Responses::Media.format_image(image, image_url: image.for_llm,
                                               original_detail: @provider.original_image_detail?)
        end

        def render_question(question)
          question_payload = { type: TYPES.fetch(question.type), name: question.name.to_s,
                               instructions: render_instructions(question) }.compact

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
          instructions unless instructions.empty?
        end

        def render_choices(question)
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

        def parse_answer(answer, question)
          case question.type
          when :probability then RubyLLM::Probability.new(probability: answer.fetch('probability'))
          when :choice then parse_choice(answer, question)
          when :score then parse_score(answer, question)
          end
        end

        def parse_choice(answer, question)
          options = question.criteria.keys.to_h { |key| [key.to_s, key] }
          RubyLLM::Choice.new(
            choice: options.fetch(answer.fetch('choice')),
            probabilities: parse_distribution(answer.fetch('probabilities'), 'value', options),
            confidence: answer.fetch('confidence')
          )
        end

        def parse_score(answer, question)
          indexes = question.criteria.each_index.to_h { |index| [index.to_s, index] }
          RubyLLM::Score.new(
            score: answer.fetch('score'), levels: question.criteria,
            probabilities: parse_distribution(answer.fetch('probabilities'), 'label', indexes),
            confidence: answer.fetch('confidence')
          )
        end

        def parse_distribution(entries, key, names)
          entries.to_h { |entry| [names.fetch(entry.fetch(key)), entry.fetch('probability')] }
        end

        def parse_tokens(usage)
          tokens = Responses::Chat.parse_usage(usage || {})
          Tokens.new(input: tokens[:input_tokens], output: tokens[:output_tokens],
                     cache_read: tokens[:cache_read_tokens], cache_write: tokens[:cache_write_tokens],
                     thinking: tokens[:thinking_tokens])
        end
      end
    end
  end
end
