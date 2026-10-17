# frozen_string_literal: true

require 'active_support/concern'
require 'active_support/inflector'

module RubyLLM
  # Rails integration brings the RubyLLM API to Active Record models, with
  # Active Storage attachments and a persisted message lifecycle for Hotwire
  # streaming and background jobs. Applications own chats and messages;
  # RubyLLM owns the supporting usage, tool-call, registry, and batch records.
  module ActiveRecord
    # Adds the RubyLLM conversation API to application-owned records.
    #
    #   class Chat < ApplicationRecord
    #     acts_as_chat
    #   end
    #
    #   class Message < ApplicationRecord
    #     acts_as_message
    #   end
    #
    #   chat = Chat.create!(model: "gpt-6-luna")
    #   response = chat.ask "Summarize this report.", with: report.document
    #   response.content
    #   chat.cost.total
    #
    # The install generator creates the required schema. The chat_ui
    # generator adds controllers, an Active Job, and Turbo Stream views.
    #
    module ActsAs
      extend ActiveSupport::Concern

      def self.included(base) # :nodoc:
        super
        RubyLLM.config.model_registry_store ||= RubyLLM::ActiveRecord::Model
        RubyLLM.config.batch_store ||= RubyLLM::ActiveRecord::Batch
      end

      ##
      # :singleton-method: acts_as_chat
      # :call-seq:
      #   acts_as_chat(messages: :messages, message_class: nil, messages_foreign_key: nil)
      #
      # Turns an application record into a persisted RubyLLM chat.
      #
      #   class Chat < ApplicationRecord
      #     acts_as_chat
      #   end
      #
      # Adds the RubyLLM::Chat API (see ChatMethods), a +has_many+
      # association to the messages, a +belongs_to :model+ association to
      # the registry row, a +has_many :ruby_llm_usages+ association over
      # the attempts the chat paid for, a
      # +has_many :ruby_llm_queued_messages+ association over the messages
      # waiting in its queue (see ChatMethods#queue), and a
      # +has_many :ruby_llm_chat_files+ association over its files (see
      # ChatMethods#with_files).
      #
      # Options:
      #
      # [+messages:+] Name of the messages association. Defaults to +:messages+.
      # [+message_class:+] Class of the messages. Inferred from the association name.
      # [+messages_foreign_key:+] Foreign key on the messages table. Inferred by Rails.

      ##
      # :singleton-method: acts_as_message
      # :call-seq:
      #   acts_as_message(chat: :chat, chat_class: nil, chat_foreign_key: nil, touch_chat: false, broadcasts: nil)
      #
      # Turns an application record into a persisted RubyLLM message.
      #
      #   class Message < ApplicationRecord
      #     acts_as_message
      #   end
      #
      # Adds the RubyLLM::Message readers (see MessageMethods), a
      # +belongs_to+ association to the chat, the tool-call and usage
      # associations behind +tool_calls+, +tokens+, and +cost+, and
      # <tt>has_many_attached :attachments</tt>, so Active Storage is
      # required. When turbo-rails and Action Cable are loaded, it also
      # broadcasts the chat's messages with Turbo when
      # Configuration#broadcast_messages is on (see MessageBroadcasting).
      #
      # Options:
      #
      # [+chat:+] Name of the chat association. Defaults to +:chat+.
      # [+chat_class:+] Class of the chat. Inferred from the association name.
      # [+chat_foreign_key:+] Foreign key on this table. Inferred by Rails.
      # [+touch_chat:+] Touch the chat when a message is saved. Defaults to +false+.
      # [+broadcasts:+] Broadcast messages with Turbo. Defaults to +nil+,
      #                 which follows Configuration#broadcast_messages.
      #                 Overrides it with +true+ or +false+.

      class_methods do # rubocop:disable Metrics/BlockLength
        def acts_as_chat(messages: :messages, message_class: nil, messages_foreign_key: nil)
          include RubyLLM::ActiveRecord::ChatMethods
          include RubyLLM::ActiveRecord::ChatFiles

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
                   inverse_of: :chat,
                   dependent: :nullify

          has_many :ruby_llm_queued_messages,
                   -> { order(:created_at, :id) },
                   as: :chat,
                   class_name: 'RubyLLM::ActiveRecord::QueuedMessage',
                   inverse_of: :chat,
                   dependent: :destroy

          has_many :ruby_llm_chat_files,
                   -> { order(:path, :id) },
                   as: :chat,
                   class_name: 'RubyLLM::ActiveRecord::ChatFile',
                   inverse_of: :chat,
                   dependent: :destroy

          RubyLLM::ActiveRecord::QueuedMessage.declare_attachments
          RubyLLM::ActiveRecord::ChatFile.declare_attachments
        end

        def acts_as_message(chat: :chat, chat_class: nil, chat_foreign_key: nil, touch_chat: false, broadcasts: nil)
          include RubyLLM::ActiveRecord::MessageMethods

          class_attribute :chat_association_name, :chat_class
          self.chat_association_name = chat
          self.chat_class = (chat_class || chat.to_s.classify).to_s

          belongs_to chat,
                     class_name: self.chat_class,
                     foreign_key: chat_foreign_key,
                     touch: touch_chat

          has_many :ruby_llm_tool_calls,
                   -> { order(:created_at, :id) },
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
                   inverse_of: :message,
                   dependent: :nullify

          ruby_llm_attachments
          ruby_llm_broadcasting(broadcasts)
        end

        private

        def ruby_llm_attachments
          if respond_to?(:has_many_attached)
            has_many_attached :attachments unless reflect_on_attachment(:attachments)
          else
            RubyLLM.logger.warn "#{name} has no attachments because Active Storage is not loaded. " \
                                'Load it with require "active_storage/engine" in config/application.rb, ' \
                                'then run bin/rails active_storage:install and bin/rails db:migrate.'
          end
        end

        def ruby_llm_broadcasting(broadcasts)
          class_attribute :ruby_llm_broadcasts, instance_writer: false
          self.ruby_llm_broadcasts = broadcasts
          include RubyLLM::ActiveRecord::MessageBroadcasting if broadcasts || MessageBroadcasting.available?
        end
      end
    end
  end
end
