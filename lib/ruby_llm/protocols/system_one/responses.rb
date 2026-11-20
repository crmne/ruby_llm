# frozen_string_literal: true

module RubyLLM
  module Protocols
    class SystemOne
      module Responses # :nodoc:
        module_function

        def parse_judgment_response(response, questions:)
          body = response.body
          tokens = parse_judgment_tokens(body['usage'] || {})
          # The provider billed this attempt even if its answers don't parse.
          @usage_tracker&.observe_tokens(tokens)
          answers = questions.values.to_h do |question|
            [question.name, parse_answer(body.fetch('answers').fetch(question.name.to_s), question)]
          end
          RubyLLM::Judgment.new(answers:, model: body['model'], raw: response, model_info: @model, tokens:)
        rescue KeyError, NoMethodError, TypeError => e
          raise Error.new('System One returned an invalid judgment', provider_message: e.message, response:,
                                                                     redact: @config&.redact_error_messages)
        end

        def parse_judgment_tokens(usage)
          input = usage['input_tokens']
          cached = cache_read_tokens(usage)
          Tokens.new(input: cached && input ? input - cached : input, output: usage['output_tokens'],
                     cache_read: cached, reported_cost: reported_cost(usage))
        end

        def reported_cost(_usage)
          nil
        end

        def cache_read_tokens(_usage)
          nil
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
