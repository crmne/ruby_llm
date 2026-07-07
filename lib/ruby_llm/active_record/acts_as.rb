# frozen_string_literal: true

require 'active_support/concern'
require 'active_support/inflector'

module RubyLLM
  # The Rails integration. Its concerns wire ActiveRecord models to
  # RubyLLM's chats, messages, tool calls, batches, and model registry
  # through the acts_as_* macros in ActsAs.
  module ActiveRecord
    # ActsAs provides class macros that turn ActiveRecord models into
    # persisted RubyLLM objects. It is included into ActiveRecord::Base
    # when the gem loads inside a Rails application, so the macros are
    # available in every model.
    #
    #   class Chat < ApplicationRecord
    #     acts_as_chat
    #   end
    #
    #   class Message < ApplicationRecord
    #     acts_as_message
    #   end
    #
    #   class ToolCall < ApplicationRecord
    #     acts_as_tool_call
    #   end
    #
    #   class Model < ApplicationRecord
    #     acts_as_model
    #   end
    #
    #   class Batch < ApplicationRecord
    #     acts_as_batch
    #   end
    #
    # A chat record then answers the full chat API (+ask+, +with_tools+,
    # +with_schema+, and the rest) while saving every message to the
    # database. See ChatMethods, MessageMethods, ToolCallMethods,
    # ModelMethods, and BatchMethods for the methods each macro adds.
    module ActsAs
      extend ActiveSupport::Concern

      def self.included(base) # :nodoc:
        super
        RubyLLM.config.model_registry_source ||= RubyLLM::ModelRegistry::ActiveRecordSource.new
      end

      class_methods do # rubocop:disable Metrics/BlockLength
        # Turns the model into a persisted chat. Includes ChatMethods,
        # adds an ordered +has_many+ for the messages, and an optional
        # +belongs_to+ for the model record.
        #
        # The +messages:+ and +model:+ association names drive the
        # defaults: class names are inferred from them, and foreign
        # keys follow Rails conventions. The +message_class:+,
        # +messages_foreign_key:+, +model_class:+, and
        # +model_foreign_key:+ options override these defaults.
        #
        #   class Chat < ApplicationRecord
        #     acts_as_chat
        #   end
        #
        #   class Conversation < ApplicationRecord
        #     acts_as_chat messages: :chat_messages,
        #                  model: :ai_model
        #   end
        #
        def acts_as_chat(messages: :messages, message_class: nil, messages_foreign_key: nil, # rubocop:disable Metrics/ParameterLists
                         model: :model, model_class: nil, model_foreign_key: nil)
          include RubyLLM::ActiveRecord::ChatMethods

          class_attribute :messages_association_name, :model_association_name, :message_class, :model_class

          self.messages_association_name = messages
          self.model_association_name = model
          self.message_class = (message_class || messages.to_s.classify).to_s
          self.model_class = (model_class || model.to_s.classify).to_s

          has_many messages,
                   -> { order(created_at: :asc) },
                   class_name: self.message_class,
                   foreign_key: messages_foreign_key,
                   dependent: :destroy

          belongs_to model,
                     class_name: self.model_class,
                     foreign_key: model_foreign_key,
                     optional: true
        end

        # Turns the model into a persisted registry entry for an LLM
        # model. Includes ModelMethods, validates +model_id+, +provider+,
        # and +name+, and adds a +has_many+ for the chats that use it.
        #
        # The chat class name is inferred from the +chats:+ association
        # name, and the foreign key follows Rails conventions. The
        # +chat_class:+ and +chats_foreign_key:+ options override these
        # defaults.
        #
        #   class Model < ApplicationRecord
        #     acts_as_model
        #   end
        #
        #   class AiModel < ApplicationRecord
        #     acts_as_model chats: :conversations
        #   end
        #
        def acts_as_model(chats: :chats, chat_class: nil, chats_foreign_key: nil)
          include RubyLLM::ActiveRecord::ModelMethods

          class_attribute :chats_association_name, :chat_class

          self.chats_association_name = chats
          self.chat_class = (chat_class || chats.to_s.classify).to_s

          validates :model_id, presence: true, uniqueness: { scope: :provider }
          validates :provider, presence: true
          validates :name, presence: true

          has_many chats, class_name: self.chat_class, foreign_key: chats_foreign_key
        end

        # Turns the model into a persisted message. Includes
        # MessageMethods and wires the chat, tool calls, parent tool
        # call, tool results, and model associations.
        #
        # The +chat:+, +tool_calls:+, and +model:+ association names
        # drive the defaults: class names are inferred from them, and
        # foreign keys follow Rails conventions. The matching
        # <tt>*_class:</tt> and <tt>*_foreign_key:</tt> options override
        # these defaults. Pass <tt>touch_chat: true</tt> to touch the
        # chat record when a message is saved or destroyed.
        #
        #   class Message < ApplicationRecord
        #     acts_as_message
        #   end
        #
        #   class ChatMessage < ApplicationRecord
        #     acts_as_message chat: :conversation,
        #                     tool_calls: :ai_tool_calls
        #   end
        #
        def acts_as_message(chat: :chat, chat_class: nil, chat_foreign_key: nil, touch_chat: false, # rubocop:disable Metrics/ParameterLists
                            tool_calls: :tool_calls, tool_call_class: nil, tool_calls_foreign_key: nil,
                            model: :model, model_class: nil, model_foreign_key: nil)
          include RubyLLM::ActiveRecord::MessageMethods

          class_attribute :chat_association_name, :tool_calls_association_name, :model_association_name,
                          :chat_class, :tool_call_class, :model_class

          self.chat_association_name = chat
          self.tool_calls_association_name = tool_calls
          self.model_association_name = model
          self.chat_class = (chat_class || chat.to_s.classify).to_s
          self.tool_call_class = (tool_call_class || tool_calls.to_s.classify).to_s
          self.model_class = (model_class || model.to_s.classify).to_s

          belongs_to chat,
                     class_name: self.chat_class,
                     foreign_key: chat_foreign_key,
                     touch: touch_chat

          has_many tool_calls,
                   class_name: self.tool_call_class,
                   foreign_key: tool_calls_foreign_key,
                   dependent: :destroy

          belongs_to :parent_tool_call,
                     class_name: self.tool_call_class,
                     foreign_key: ActiveSupport::Inflector.foreign_key(tool_calls.to_s.singularize),
                     optional: true

          has_many :tool_results,
                   through: tool_calls,
                   source: :result,
                   class_name: name

          belongs_to model,
                     class_name: self.model_class,
                     foreign_key: model_foreign_key,
                     optional: true
        end

        # Turns the model into a persisted batch. Includes BatchMethods
        # and records the chat class whose staged chats the batch
        # submits, +Chat+ by default.
        #
        #   class Batch < ApplicationRecord
        #     acts_as_batch
        #   end
        #
        #   batch = Batch.create!(chats: chats)
        #
        def acts_as_batch(chat_class: 'Chat')
          include RubyLLM::ActiveRecord::BatchMethods

          class_attribute :batch_chat_class
          self.batch_chat_class = chat_class.to_s
        end

        # Turns the model into a persisted tool call. Includes
        # ToolCallMethods, adds a +belongs_to+ for the message that made
        # the call and a +has_one+ for the message holding its result.
        #
        # The message class name is inferred from the +message:+
        # association name, and the result class defaults to that same
        # class. Foreign keys follow Rails conventions. The
        # +message_class:+, +message_foreign_key:+, +result_class:+,
        # and +result_foreign_key:+ options override these defaults.
        #
        #   class ToolCall < ApplicationRecord
        #     acts_as_tool_call
        #   end
        #
        #   class AiToolCall < ApplicationRecord
        #     acts_as_tool_call message: :chat_message
        #   end
        #
        def acts_as_tool_call(message: :message, message_class: nil, message_foreign_key: nil, # rubocop:disable Metrics/ParameterLists
                              result: :result, result_class: nil, result_foreign_key: nil)
          include RubyLLM::ActiveRecord::ToolCallMethods

          class_attribute :message_association_name, :result_association_name, :message_class, :result_class

          self.message_association_name = message
          self.result_association_name = result
          self.message_class = (message_class || message.to_s.classify).to_s
          self.result_class = (result_class || self.message_class).to_s

          belongs_to message,
                     class_name: self.message_class,
                     foreign_key: message_foreign_key

          has_one result,
                  class_name: self.result_class,
                  foreign_key: result_foreign_key,
                  dependent: :nullify
        end
      end
    end
  end
end
