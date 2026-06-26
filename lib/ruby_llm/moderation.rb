# frozen_string_literal: true

module RubyLLM
  # Identify potentially harmful content in text.
  # https://platform.openai.com/docs/guides/moderation
  class Moderation
    attr_reader :id, :model, :results

    def initialize(id:, model:, results:)
      @id = id
      @model = model
      @results = results
    end

    def self.moderate(input,
                      model: nil,
                      provider: nil,
                      assume_model_exists: false,
                      context: nil,
                      metadata: nil)
      config = context&.config || RubyLLM.config
      model ||= config.default_moderation_model
      model, provider_instance = Models.resolve(model, provider: provider, assume_exists: assume_model_exists,
                                                       config: config)
      payload = {
        provider: provider_instance.slug,
        provider_class: provider_instance.class.display_name,
        model: model.id,
        model_info: model,
        input: input,
        metadata: Metadata.coerce(metadata)
      }

      RubyLLM.instrument('moderation.ruby_llm', payload, config: config) do |event|
        result = provider_instance.moderate(input, model: model.id)
        event[:result] = result
        event[:flagged] = result.flagged?
        result
      end
    end

    alias content results

    def flagged?
      results.any? { |result| result['flagged'] }
    end

    def flagged_categories
      results.flat_map do |result|
        result['categories']&.select { |_category, flagged| flagged }&.keys || []
      end.uniq
    end

    # Scores and categories read from the first result — the common single-input case.
    def category_scores
      results.first&.dig('category_scores') || {}
    end

    def categories
      results.first&.dig('categories') || {}
    end
  end
end
