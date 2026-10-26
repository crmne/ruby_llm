# frozen_string_literal: true

module RubyLLM
  class Protocol
    # Decides which provider-native parts of an assistant message, such as
    # thinking signatures, raw content blocks, and continuations, replay to
    # the model a request goes to.
    module NativeContent # :nodoc:
      private

      # A thinking signature or a provider-shaped content block belongs to the
      # model that produced it, and one provider can serve models that do not
      # read each other's, so a message another model produced replays
      # without them. A message with no known producer replays as it is.
      def foreign_native_content?(message)
        return false unless message.role == :assistant && carries_native_content?(message)

        producer = producing_entry(message)
        !producer.nil? && (producer.provider != @provider.slug || !current_model?(producer.model))
      end

      # Usage records the id a chat resolved its model to, and a message built
      # by hand may name the model by an alias of it.
      def current_model?(model_id)
        return true if @model.nil? || model_id == @model.id

        RubyLLM.models.find(model_id, provider: @provider.slug, config: @config).id == @model.id
      rescue ModelNotFoundError
        false
      end

      # Another model of this provider gets the raw content any of its models
      # reads, such as a tool search, and none of the producing model's own.
      def without_foreign_native_content(message)
        portable = portable_raw_content(message) if producer_slug(message) == @provider.slug
        message.without_native_content(raw_content: portable)
      end

      def portable_raw_content(_message)
        nil
      end

      def carries_native_content?(message)
        return true if message.thinking || message.raw_reasoning || message.raw_content || message.phase
        return true if message.continuation

        message.tool_call? && message.tool_calls.each_value.any?(&:thought_signature)
      end

      # Only a usage entry names the producer: a model id alone can belong
      # to several providers.
      def producer_slug(message)
        producing_entry(message)&.provider
      end

      def producing_entry(message)
        message.ruby_llm_usage_entries.reverse.find(&:succeeded?)
      end

      # A thinking signature can be another provider's opaque blob, and a
      # message restored without its usage could come from anyone, so a
      # protocol that verifies signatures gets back only its own.
      def own_signature(message)
        signature = message.thinking&.signature
        signature if signature && producer_slug(message) == @provider.slug
      end
    end
  end
end
