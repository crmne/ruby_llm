# frozen_string_literal: true

module RubyLLM
  module Protocols
    class SystemOne
      module Responses # :nodoc:
        module_function

        def parse_judgment_response(response, questions:)
          body = response.body
          answers = questions.values.to_h do |question|
            [question.name, parse_answer(body.fetch('answers').fetch(question.name.to_s), question)]
          end
          RubyLLM::Judgment.new(
            answers:, model: body['model'], raw: response, model_info: @model,
            tokens: Tokens.new(input: body.dig('usage', 'input_tokens'), output: body.dig('usage', 'output_tokens'))
          )
        rescue KeyError, NoMethodError, TypeError => e
          raise Error.new("System One returned an invalid judgment: #{e.message}", response:)
        end

        def parse_answer(answer, question)
          case question.type
          when :probability then RubyLLM::Probability.new(probability: answer.fetch('noul'))
          when :choice then parse_choice(answer, question)
          when :score then parse_score(answer, question)
          end
        end

        def parse_choice(answer, question)
          options = question.criteria.keys.to_h { |key| [key.to_s, key] }
          RubyLLM::Choice.new(
            choice: options.fetch(answer.fetch('choice')),
            probabilities: parse_probabilities(answer.fetch('probabilities'), options),
            confidence: answer.fetch('confidence')
          )
        end

        def parse_score(answer, question)
          indexes = question.criteria.each_index.to_h { |index| [index.to_s, index] }
          legend = answer.fetch('legend')
          RubyLLM::Score.new(
            score: answer.fetch('score'), levels: indexes.keys.map { |key| legend.fetch(key) },
            probabilities: parse_probabilities(answer.fetch('probabilities'), indexes),
            confidence: answer.fetch('confidence')
          )
        end

        def parse_probabilities(values, keys)
          keys.to_h { |wire, key| [key, values.fetch(wire)] }
        end
      end
    end
  end
end
