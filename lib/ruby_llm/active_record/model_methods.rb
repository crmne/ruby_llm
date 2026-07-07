# frozen_string_literal: true

require 'active_support/concern'
require 'active_support/core_ext/module/delegation'

module RubyLLM
  module ActiveRecord
    # ModelMethods is mixed into the model registry class by acts_as_model.
    # Each record stores one entry of the RubyLLM model registry and answers
    # the same capability and pricing queries as RubyLLM::Model. Those
    # queries delegate to the Model object returned by #to_llm.
    #
    #   class Model < ApplicationRecord
    #     acts_as_model
    #   end
    #
    #   Model.refresh!
    #   model = Model.find_by(model_id: 'claude-sonnet-4-6')
    #   model.supports?(:vision) # => true
    #
    module ModelMethods
      extend ActiveSupport::Concern

      class_methods do # rubocop:disable Metrics/BlockLength
        # Refreshes the in-memory model registry from provider APIs, then
        # saves every model to the database with #save_to_database.
        # See Models#refresh!.
        #
        #   Model.refresh!
        #
        def refresh!
          RubyLLM.models.refresh!

          save_to_database
        end

        # Saves every model in the in-memory registry to the database inside
        # a single transaction. Rows are matched on their +model_id+ and
        # +provider+ columns, updated when found and created otherwise.
        def save_to_database
          transaction do
            RubyLLM.models.all.each do |model_info|
              model = find_or_initialize_by(
                model_id: model_info.id,
                provider: model_info.provider
              )
              model.update!(from_llm_attributes(model_info))
            end
          end
        end

        # Returns a new, unsaved record with attributes copied from
        # +model_info+, a RubyLLM::Model.
        def from_llm(model_info)
          new(from_llm_attributes(model_info))
        end

        private

        def from_llm_attributes(model_info) # :nodoc:
          {
            model_id: model_info.id,
            name: model_info.name,
            provider: model_info.provider,
            family: model_info.family,
            model_created_at: model_info.created_at,
            context_window: model_info.context_window,
            max_output_tokens: model_info.max_output_tokens,
            knowledge_cutoff: model_info.knowledge_cutoff,
            modalities: model_info.modalities.to_h,
            capabilities: model_info.capabilities,
            pricing: model_info.pricing.to_h,
            metadata: model_info.metadata
          }
        end
      end

      # Returns a RubyLLM::Model built from this record's attributes.
      def to_llm
        RubyLLM::Model.new(
          id: model_id,
          name: name,
          provider: provider,
          family: family,
          created_at: model_created_at,
          context_window: context_window,
          max_output_tokens: max_output_tokens,
          knowledge_cutoff: knowledge_cutoff,
          modalities: modalities&.deep_symbolize_keys || {},
          capabilities: capabilities,
          pricing: pricing&.deep_symbolize_keys || {},
          metadata: metadata&.deep_symbolize_keys || {}
        )
      end

      ##
      # :method: supports?
      # :call-seq: supports?(capability)
      #
      # Returns whether the model supports +capability+, given as a String
      # or Symbol. See Model#supports?.

      ##
      # :method: supports_vision?
      #
      # Returns whether the model accepts image input.
      # See Model#supports_vision?.

      ##
      # :method: supports_functions?
      #
      # Returns whether the model supports tool calling.
      # Same as #function_calling?.

      ##
      # :method: type
      #
      # Returns the model's primary function, such as <tt>"chat"</tt> or
      # <tt>"embedding"</tt>. See Model#type.

      ##
      # :method: supports?
      # :call-seq: supports?(capability)
      #
      # Returns whether the model has +capability+. See Model#supports?.

      ##
      # :method: price
      # :call-seq: price(kind)
      #
      # Returns the standard text-token price for +kind+ (+:input+,
      # +:output+, +:cache_read+, or +:cache_write+) in USD per million
      # tokens, or +nil+ if unknown. See Model#price.

      ##
      # :method: provider_class
      #
      # Returns the Provider class registered for this model's provider,
      # or +nil+ if none is registered. See Model#provider_class.

      ##
      # :method: label
      #
      # Returns the provider display name and model name combined,
      # e.g. <tt>"OpenAI - GPT-5.4"</tt>. See Model#label.

      ##
      # :method: cost_for
      # :call-seq: cost_for(tokens)
      #
      # Builds a Cost for +tokens+ using this model's pricing.
      # See Model#cost_for.

      delegate :supports?, :price, :type,
               :provider_class, :label, :cost_for,
               to: :to_llm
    end
  end
end
