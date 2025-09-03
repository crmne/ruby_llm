# frozen_string_literal: true

module RubyLLM
  module ActiveRecord
    # Adds chat and message persistence capabilities to ActiveRecord models.
    module ActsAs
      extend ActiveSupport::Concern

      # When ActsAs is included, ensure models are loaded from database
      def self.included(base)
        super
        # Monkey-patch Models to use database when ActsAs is active
        RubyLLM::Models.class_eval do
          def load_models
            read_from_database
          rescue StandardError => e
            RubyLLM.logger.debug "Failed to load models from database: #{e.message}, falling back to JSON"
            read_from_json
          end

          def load_from_database!
            @models = read_from_database
          end

          def read_from_database
            model_class = RubyLLM.config.model_registry_class
            model_class = model_class.constantize if model_class.is_a?(String)
            model_class.all.map(&:to_llm)
          end
        end
      end

      class_methods do # rubocop:disable Metrics/BlockLength
        def acts_as_chat(message_class: 'Message', tool_call_class: 'ToolCall',
                         model_class: 'Model', model_foreign_key: nil)
          include RubyLLM::ActiveRecord::ChatMethods

          @message_class = message_class.to_s
          @tool_call_class = tool_call_class.to_s
          @model_class = model_class.to_s
          @model_foreign_key = model_foreign_key || ActiveSupport::Inflector.foreign_key(@model_class)

          has_many :messages,
                   -> { order(created_at: :asc) },
                   class_name: @message_class,
                   inverse_of: :chat,
                   dependent: :destroy

          belongs_to :model,
                     class_name: @model_class,
                     foreign_key: @model_foreign_key,
                     optional: true

          delegate :add_message, to: :to_llm
        end

        def acts_as_model(chat_class: 'Chat')
          include RubyLLM::ActiveRecord::ModelMethods

          @chat_class = chat_class.to_s

          validates :model_id, presence: true, uniqueness: { scope: :provider }
          validates :provider, presence: true
          validates :name, presence: true

          has_many :chats,
                   class_name: @chat_class,
                   foreign_key: ActiveSupport::Inflector.foreign_key(name)
        end

        def acts_as_message(chat_class: 'Chat', # rubocop:disable Metrics/ParameterLists
                            chat_foreign_key: nil,
                            tool_call_class: 'ToolCall',
                            tool_call_foreign_key: nil,
                            model_class: 'Model',
                            model_foreign_key: nil,
                            touch_chat: false)
          include RubyLLM::ActiveRecord::MessageMethods

          @chat_class = chat_class.to_s
          @chat_foreign_key = chat_foreign_key || ActiveSupport::Inflector.foreign_key(@chat_class)

          @tool_call_class = tool_call_class.to_s
          @tool_call_foreign_key = tool_call_foreign_key || ActiveSupport::Inflector.foreign_key(@tool_call_class)

          @model_class = model_class.to_s
          @model_foreign_key = model_foreign_key || ActiveSupport::Inflector.foreign_key(@model_class)

          belongs_to :chat,
                     class_name: @chat_class,
                     foreign_key: @chat_foreign_key,
                     inverse_of: :messages,
                     touch: touch_chat

          has_many :tool_calls,
                   class_name: @tool_call_class,
                   dependent: :destroy

          belongs_to :parent_tool_call,
                     class_name: @tool_call_class,
                     foreign_key: @tool_call_foreign_key,
                     optional: true,
                     inverse_of: :result

          has_many :tool_results,
                   through: :tool_calls,
                   source: :result,
                   class_name: @message_class

          belongs_to :model,
                     class_name: @model_class,
                     foreign_key: @model_foreign_key,
                     optional: true

          delegate :tool_call?, :tool_result?, to: :to_llm
        end

        def acts_as_tool_call(message_class: 'Message', message_foreign_key: nil, result_foreign_key: nil)
          @message_class = message_class.to_s
          @message_foreign_key = message_foreign_key || ActiveSupport::Inflector.foreign_key(@message_class)
          @result_foreign_key = result_foreign_key || ActiveSupport::Inflector.foreign_key(name)

          belongs_to :message,
                     class_name: @message_class,
                     foreign_key: @message_foreign_key,
                     inverse_of: :tool_calls

          has_one :result,
                  class_name: @message_class,
                  foreign_key: @result_foreign_key,
                  inverse_of: :parent_tool_call,
                  dependent: :nullify
        end
      end
    end
  end
end
