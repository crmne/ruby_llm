# frozen_string_literal: true

module RubyLLM
  class Agent
    # Decides what the Agent::model macro's options apply to. They belong to
    # the declared model, so a caller's +model:+ replaces them along with it,
    # and a record on another model does not take them. A record being created
    # knows what its caller passed; a later one is judged by its saved model.
    module ModelOptions # :nodoc:
      DECLARED_WITH_MODEL = %i[provider protocol assume_model_exists].freeze

      private

      def resolved_chat_kwargs(inputs:, options:)
        replaced = options.key?(:model) && chat_kwargs.key?(:model)
        return chat_kwargs.except(*DECLARED_WITH_MODEL).merge(options) if replaced
        return chat_kwargs.merge(options) unless chat_kwargs[:model].is_a?(Proc)

        chat_kwargs.merge(model: evaluate(chat_kwargs[:model], runtime_context(chat: nil, inputs:))).merge(options)
      end

      def apply_chat_options(chat, options = {})
        return if options.key?(:model) || !rails_chat_record?(chat) || !declared_model_on?(chat)

        declared = chat_kwargs.except(*options.keys)
        chat.assume_model_exists = declared[:assume_model_exists] if declared.key?(:assume_model_exists)
        chat.protocol ||= declared[:protocol] if declared.key?(:protocol)
      end

      def declared_model_on?(record)
        return true unless record.model_id

        declared_provider_on?(record) && declared_id_on?(record)
      end

      def declared_provider_on?(record)
        declared = chat_kwargs[:provider]

        declared.nil? || record.provider.nil? || declared.to_s == record.provider.to_s
      end

      def declared_id_on?(record)
        declared = chat_kwargs[:model]
        declared = declared.id if declared.is_a?(Model)
        return true if declared.nil? || declared.is_a?(Proc) || declared == record.model_id

        provider = record.provider || chat_kwargs[:provider]
        return true if Models::Aliases.resolve(declared, provider) == record.model_id

        Models.find(declared, provider:).id == record.model_id
      rescue ModelNotFoundError
        false
      end
    end
  end
end
