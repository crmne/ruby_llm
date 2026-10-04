# frozen_string_literal: true

module RubyLLM
  class Evaluation
    class Evaluator # :nodoc:
      attr_reader :target, :options

      def initialize(target = nil, **options)
        @target = target
        @options = options.freeze
        unless target.nil? || target.is_a?(String) || target.is_a?(Model) ||
               (target.is_a?(Class) && (target <= Judge || target <= Agent))
          raise ArgumentError, 'An evaluator must be a model, Agent class, or Judge class'
        end

        freeze
      end

      def question_names
        judge_class ? judge_class.question_definitions.keys.map(&:to_sym) : []
      end

      def description
        { class: target.is_a?(Class) ? target.name : nil, **settings.slice(:model, :provider, :protocol),
          questions: judge_class&.question_definitions&.transform_values do |question|
            { type: question.type, instructions: question.instructions.is_a?(Proc) ? nil : question.instructions }
          end }
      end

      def call(data, definitions, attachments:)
        if judge_class || decision_model?
          judge(data, definitions, attachments)
        else
          review(data, definitions, attachments)
        end
      end

      private

      def judge_class
        target if target.is_a?(Class) && target <= Judge
      end

      def settings
        case target
        when Model then options.merge(model: target.id, provider: target.provider)
        when String then options.merge(model: target)
        else options
        end
      end

      def decision_model?
        return false if target.is_a?(Class) || settings[:protocol]
        return target.type == :judgment if target.is_a?(Model)

        config = settings[:context]&.config || RubyLLM.config
        model, = Models.resolve(settings[:model] || config.default_model,
                                **settings.slice(:provider, :assume_model_exists), config:)
        model.type == :judgment
      end

      def judge(data, definitions, attachments)
        questions = definitions.reject { |definition| question_names.include?(definition[:name]) }
                               .to_h do |definition|
          [definition[:name], { type: :probability, instructions: definition.fetch(:instructions) }]
        end
        response = (judge_class || Judge).judge(data, questions:, with: attachments, **settings)
        evidence = Evidence.new(response).data
        results = definitions.map do |definition|
          Result.new(name: definition[:name], value: response.fetch(definition[:name]),
                     minimum: definition[:minimum], model: response.model, evidence:)
        end
        [results, response.cost]
      end

      def review(data, definitions, attachments)
        if definitions.any? { |definition| !definition[:minimum].nil? }
          raise ArgumentError, 'Minimum applies to decision probabilities and scores, not LLM verdicts'
        end

        agent = review_agent(definitions)
        response = agent.ask(JSON.generate(data), with: attachments)
        raise Error, 'Evaluator stopped before completing its assessment' unless agent.complete?

        [parse_results(response.parsed, definitions, agent), agent.cost]
      end

      def review_agent(definitions)
        agent_class = target.is_a?(Class) ? target : Reviewer
        agent = agent_class.new(**settings)
        raise ArgumentError, 'An evaluation Agent must leave its schema to the evaluation runner' if agent.schema

        criteria = definitions.to_h { |definition| [definition[:name], definition.fetch(:instructions)] }
        agent.with_instructions("Assess these criteria independently:\n#{JSON.generate(criteria)}", append: true)
        agent.with_schema(response_schema(definitions))
        agent
      end

      def parse_results(values, definitions, agent)
        names = definitions.map { |definition| definition[:name].to_s }
        unless values.is_a?(Hash) && values.keys.sort == names.sort
          raise Error,
                'Evaluator returned missing or unexpected criterion names'
        end

        verdict_values = { 'pass' => true, 'fail' => false, 'unknown' => nil }
        evidence = Evidence.new(agent).data
        definitions.map do |definition|
          verdict = values.fetch(definition[:name].to_s)
          value = verdict_values.fetch(verdict.fetch('verdict'))
          Result.new(name: definition[:name], value:, reason: verdict.fetch('reason'),
                     model: agent.messages.last.model, evidence:)
        end
      end

      def response_schema(definitions)
        item = {
          type: 'object', properties: {
            verdict: { type: 'string', enum: %w[pass fail unknown] }, reason: { type: 'string' }
          }, required: %w[verdict reason], additionalProperties: false
        }
        { type: 'object', properties: definitions.to_h { |definition| [definition[:name].to_s, item] },
          required: definitions.map { |definition| definition[:name].to_s }, additionalProperties: false }
      end
    end
  end
end
