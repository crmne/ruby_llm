# frozen_string_literal: true

require 'active_support/concern'
require 'active_support/inflector'

module RubyLLM
  # The Rails integration. Applications own chats and messages; RubyLLM owns
  # the supporting usage, tool-call, model-registry, and batch records.
  module ActiveRecord
    # Adds the two application-facing persistence roles used by RubyLLM.
    #
    #   class Chat < ApplicationRecord
    #     acts_as_chat
    #   end
    #
    #   class Message < ApplicationRecord
    #     acts_as_message
    #   end
    #
    module ActsAs
      extend ActiveSupport::Concern

      def self.included(base) # :nodoc:
        super
        RubyLLM.config.model_registry_store ||= RubyLLM::ActiveRecord::Model
        RubyLLM.config.batch_store ||= RubyLLM::ActiveRecord::Batch
      end

      class_methods do # rubocop:disable Metrics/BlockLength
        # Turns an application record into a persisted RubyLLM chat.
        #
        #   class Chat < ApplicationRecord
        #     acts_as_chat
        #   end
        #
        # Adds the RubyLLM::Chat API (see ChatMethods), a +has_many+
        # association to the messages, a +belongs_to :model+ association to
        # the registry row, and a +has_many :ruby_llm_usages+ association over
        # the attempts the chat paid for.
        #
        # Options:
        #
        # [+messages:+] Name of the messages association. Defaults to +:messages+.
        # [+message_class:+] Class of the messages. Inferred from the association name.
        # [+messages_foreign_key:+] Foreign key on the messages table. Inferred by Rails.
        def acts_as_chat(messages: :messages, message_class: nil, messages_foreign_key: nil)
          include RubyLLM::ActiveRecord::ChatMethods

          class_attribute :messages_association_name, :message_class
          self.messages_association_name = messages
          self.message_class = (message_class || messages.to_s.classify).to_s

          has_many messages,
                   -> { order(:created_at, :id) },
                   class_name: self.message_class,
                   foreign_key: messages_foreign_key,
                   dependent: :destroy

          belongs_to :model,
                     class_name: 'RubyLLM::ActiveRecord::Model',
                     foreign_key: :ruby_llm_model_id,
                     optional: true

          has_many :ruby_llm_usages,
                   -> { chronological },
                   as: :chat,
                   class_name: 'RubyLLM::ActiveRecord::Usage',
                   dependent: :destroy
        end

        # Turns an application record into a persisted RubyLLM message.
        #
        #   class Message < ApplicationRecord
        #     acts_as_message
        #   end
        #
        # Adds the RubyLLM::Message readers (see MessageMethods), a
        # +belongs_to+ association to the chat, and the tool-call and usage
        # associations behind +tool_calls+, +tokens+, and +cost+.
        #
        # Options:
        #
        # [+chat:+] Name of the chat association. Defaults to +:chat+.
        # [+chat_class:+] Class of the chat. Inferred from the association name.
        # [+chat_foreign_key:+] Foreign key on this table. Inferred by Rails.
        # [+touch_chat:+] Touch the chat when a message is saved. Defaults to +false+.
        def acts_as_message(chat: :chat, chat_class: nil, chat_foreign_key: nil, touch_chat: false)
          include RubyLLM::ActiveRecord::MessageMethods

          class_attribute :chat_association_name, :chat_class
          self.chat_association_name = chat
          self.chat_class = (chat_class || chat.to_s.classify).to_s

          belongs_to chat,
                     class_name: self.chat_class,
                     foreign_key: chat_foreign_key,
                     touch: touch_chat

          has_many :ruby_llm_tool_calls,
                   as: :message,
                   class_name: 'RubyLLM::ActiveRecord::ToolCall',
                   dependent: :destroy

          has_one :ruby_llm_parent_tool_call,
                  as: :result,
                  class_name: 'RubyLLM::ActiveRecord::ToolCall',
                  dependent: :nullify

          has_many :ruby_llm_usages,
                   -> { chronological },
                   as: :message,
                   class_name: 'RubyLLM::ActiveRecord::Usage',
                   dependent: :nullify
        end
      end
    end
  end
end
