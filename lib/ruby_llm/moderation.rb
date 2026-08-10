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
    include Inspectable
    include Usage::Result

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

    # Sends +input+ and optional image attachments to a moderation model and returns a Moderation with the
    # provider's verdict. Uses the configured default moderation model when
    # +model+ is not given. Pass +provider:+ and <tt>assume_model_exists: true</tt>
    # to use a model that is not in the registry.
    #
    #   RubyLLM::Moderation.moderate("Your content here")
    #   RubyLLM::Moderation.moderate("User message", model: "omni-moderation-latest")
    #   RubyLLM::Moderation.moderate("Caption", with: "screenshot.png", provider: "openai")
    #
    def self.moderate(input = nil,
                      model: nil,
                      with: nil,
                      provider: nil,
                      assume_model_exists: false,
                      context: nil,
                      provider_options: {},
                      metadata: nil)
      attachments = Attachment.wrap(with)
      raise ArgumentError, 'must provide input text, image attachment, or both' if input.nil? && attachments.empty?

      config = context&.config || RubyLLM.config
      model ||= config.default_moderation_model
      model, provider_instance = Models.resolve(model, provider: provider, assume_model_exists: assume_model_exists,
                                                       config: config)
      empty_tokens = Tokens.new
      payload = {
        provider: provider_instance.slug,
        provider_class: provider_instance.class.display_name,
        model: model.id,
        model_info: model,
        input: input,
        attachment_count: attachments.size,
        provider_options: provider_options,
        metadata: metadata,
        tokens: empty_tokens,
        cost: Cost.new(tokens: empty_tokens, model:)
      }

      RubyLLM.instrument('moderation.ruby_llm', payload, config: config) do |event|
        result = provider_instance.moderate(input, model:, with: attachments, provider_options:)
        event[:result] = result
        event[:flagged] = result.flagged?
        event[:tokens] = result.tokens
        event[:cost] = result.cost
        result
      end
    end

    # Returns +true+ if any input was flagged as potentially harmful,
    # +false+ otherwise.
    def flagged?
      results.any?(&:flagged?)
    end

    # Returns provider-reported usage across every attempt. Its fields are
    # +nil+ when the provider did not report any.
    def tokens
      ruby_llm_usage_tokens
    end

    # Returns the moderation cost across every provider attempt.
    def cost
      ruby_llm_usage_cost
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

    def inspect_attributes # :nodoc:
      { id: id, model: model, flagged: flagged? }
    end
  end
end
