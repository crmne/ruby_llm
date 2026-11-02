# frozen_string_literal: true

module RubyLLM
  module Accounting
    # The body the standalone operations share: resolve the model, open the
    # instrumentation event, attribute the provider call to its owner, and
    # report the result on the event. +run+ takes the event fields particular
    # to the operation, in event order, and yields the provider and the
    # resolved model.
    #
    # +details:+ adds fields after the response model. +report:+ replaces the
    # reporting of an operation whose result does not read like the others.
    # +usage: false+ leaves tokens and cost off the event.
    class Operation # :nodoc: all
      def initialize(name, model, owner:, context: nil, provider: nil, assume_model_exists: false,
                     default: nil, operation: nil, category: nil, usage: true, details: nil, report: nil)
        @name = name
        @owner = owner
        @category = category
        @usage = usage
        @details = details
        @report = report
        @config = context&.config || RubyLLM.config
        @model, @provider = resolve(model, default, operation, provider:, assume_model_exists:)
      end

      def run(**fields)
        RubyLLM.instrument("#{@name}.ruby_llm", payload(fields), config: @config) do |event|
          result = Usage.owned_by(@owner) { yield @provider, @model }
          report(event, result)
          result
        end
      end

      private

      def resolve(model, default, operation, **options)
        default_model = default && @config.public_send(default)
        options[:config] = @config
        return Models.resolve(model, **options, operation:, default_model:) if operation

        Models.resolve(model || default_model, **options)
      end

      def payload(fields)
        common = { provider: @provider.slug, provider_class: @provider.name, model: @model&.id, model_info: @model }
        return common.merge(fields) unless @usage

        tokens = Tokens.new
        common.merge(fields, tokens:, cost: Cost.new(tokens:, model: @model, **{ category: @category }.compact))
      end

      def report(event, result)
        return @report.call(event, result) if @report

        event[:result] = result
        event[:response_model] = result.model
        @details&.call(event, result)
        return unless @usage

        event[:tokens] = result.tokens
        event[:cost] = result.cost
      end
    end
  end
end
