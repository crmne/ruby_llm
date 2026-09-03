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
        # Turns an application record into a persisted RubyLLM chat. The
        # record gains the RubyLLM::Chat API (see ChatMethods), a +messages+
        # association named by +messages:+ (its class inferred from the name
        # unless +message_class:+ says otherwise, and its foreign key from
        # Rails conventions unless +messages_foreign_key:+ does), a +model+
        # association to RubyLLM's registry row, and a +ruby_llm_usages+
        # association over the attempts the chat paid for.
        #
        #   acts_as_chat
        #   acts_as_chat messages: :turns, message_class: 'Conversation::Turn'
        #
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

        # Turns an application record into a persisted RubyLLM message. The
        # record gains the RubyLLM::Message readers (see MessageMethods) and
        # a +chat+ association named by +chat:+ (its class inferred from the
        # name unless +chat_class:+ says otherwise, its foreign key from Rails
        # conventions unless +chat_foreign_key:+ does, touching the chat on
        # save when +touch_chat:+ is true), plus the private tool-call and
        # usage associations RubyLLM reads through +tool_calls+, +tokens+,
        # and +cost+.
        #
        #   acts_as_message
        #   acts_as_message chat: :conversation, touch_chat: true
        #
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
