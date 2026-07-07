# frozen_string_literal: true

module RubyLLM
  # A Moderation holds the result of screening text for potentially harmful
  # content with a provider moderation model. Most code obtains one through
  # RubyLLM.moderate.
  #
  #   result = RubyLLM.moderate("This is a safe message about Ruby programming")
  #   result.flagged?  # => false
  #   result.model     # => "omni-moderation-latest"
  #
  class Moderation
    # A Result is the verdict for a single moderated input. Providers return
    # results in different shapes. RubyLLM normalizes all of them into Result
    # objects on Moderation#results.
    #
    #   result = RubyLLM.moderate("Some user input").results.first
    #   result.flagged?               # => false
    #   result.categories             # => []
    #   result.category_scores["violence"]  # => 0.0004
    #
    class Result
      # The names of the categories flagged for this input, as an array of
      # strings, empty when nothing was flagged.
      attr_reader :categories

      # The confidence scores for this input, as a hash of category name to
      # a score between 0.0 and 1.0.
      attr_reader :category_scores

      def initialize(flagged:, categories:, category_scores:) # :nodoc:
        @flagged = flagged
        @categories = categories
        @category_scores = category_scores
      end

      def self.from_h(data) # :nodoc:
        flagged_names = (data['categories'] || {}).select { |_category, flagged| flagged }.keys
        new(
          flagged: data.fetch('flagged', flagged_names.any?),
          categories: flagged_names,
          category_scores: data['category_scores'] || {}
        )
      end

      # Returns +true+ if this input was flagged as potentially harmful,
      # +false+ otherwise.
      def flagged?
        @flagged
      end
    end

    # The provider-assigned identifier of the moderation request.
    attr_reader :id

    # The id of the model that performed the moderation.
    attr_reader :model

    # The per-input verdicts, as an array of Result objects, one per
    # moderated input.
    attr_reader :results

    def initialize(id:, model:, results:) # :nodoc:
      @id = id
      @model = model
      @results = results
    end

    # Sends +input+ to a moderation model and returns a Moderation with the
    # provider's verdict. Uses the configured default moderation model when
    # +model+ is not given. Pass +provider:+ and <tt>assume_model_exists: true</tt>
    # to use a model that is not in the registry.
    #
    #   RubyLLM::Moderation.moderate("Your content here")
    #   RubyLLM::Moderation.moderate("User message", model: "omni-moderation-latest")
    #
    def self.moderate(input, # rubocop:disable Metrics/ParameterLists
                      model: nil,
                      provider: nil,
                      assume_model_exists: false,
                      context: nil,
                      provider_options: {},
                      metadata: nil)
      config = context&.config || RubyLLM.config
      model ||= config.default_moderation_model
      model, provider_instance = Models.resolve(model, provider: provider, assume_model_exists: assume_model_exists,
                                                       config: config)
      payload = {
        provider: provider_instance.slug,
        provider_class: provider_instance.class.display_name,
        model: model.id,
        model_info: model,
        input: input,
        provider_options: provider_options,
        metadata: metadata
      }

      RubyLLM.instrument('moderation.ruby_llm', payload, config: config) do |event|
        result = provider_instance.moderate(input, model:, provider_options:)
        event[:result] = result
        event[:flagged] = result.flagged?
        result
      end
    end

    # Returns +true+ if any input was flagged as potentially harmful,
    # +false+ otherwise.
    def flagged?
      results.any?(&:flagged?)
    end

    # Returns the unique names of the categories flagged across all results.
    #
    #   result.flagged_categories  # => ["harassment", "violence"]
    #
    def flagged_categories
      results.flat_map(&:categories).uniq
    end

    # Returns the confidence scores across all results, as a hash of category
    # name to a score between 0.0 and 1.0. Keeps the highest score per
    # category when there are multiple results.
    #
    #   result.category_scores["violence"]  # => 0.0001
    #
    def category_scores
      results.map(&:category_scores).reduce({}) do |merged, scores|
        merged.merge(scores) { |_category, left, right| [left, right].max }
      end
    end
  end
end
