# frozen_string_literal: true

gem 'ruby_llm', path: ENV['RUBYLLM_PATH'] || '../../../..'

after_bundle do
  migration_version = "[#{Rails::VERSION::MAJOR}.#{Rails::VERSION::MINOR}]"

  file 'config/initializers/ruby_llm.rb', <<~RUBY
    RubyLLM.configure do |config|
      config.openai_api_key = ENV.fetch("OPENAI_API_KEY", "test")
    end
  RUBY

  file 'app/models/conversation.rb', <<~RUBY
    class Conversation < ApplicationRecord
    acts_as_chat
    end
  RUBY

  file 'app/models/chat_message.rb', <<~RUBY
    class ChatMessage < ApplicationRecord
    acts_as_message
    end
  RUBY

  file 'app/models/tool_call.rb', <<~RUBY
    class ToolCall < ApplicationRecord
    acts_as_tool_call
    end
  RUBY

  file 'db/migrate/20200101000000_create_conversations.rb', <<~RUBY
    class CreateConversations < ActiveRecord::Migration#{migration_version}
      def change
        create_table :conversations do |t|
          t.string :model_id
          t.string :provider
          t.timestamps
        end
      end
    end
  RUBY

  file 'db/migrate/20200101000001_create_chat_messages.rb', <<~RUBY
    class CreateChatMessages < ActiveRecord::Migration#{migration_version}
      def change
        create_table :chat_messages do |t|
          t.integer :conversation_id
          t.string :model_id
          t.string :provider
          t.timestamps
        end
      end
    end
  RUBY

  file 'db/migrate/20200101000002_create_tool_calls.rb', <<~RUBY
    class CreateToolCalls < ActiveRecord::Migration#{migration_version}
      def change
        create_table :tool_calls do |t|
          t.integer :chat_message_id
          t.timestamps
        end
      end
    end
  RUBY

  rails_command 'db:migrate'

  generate 'ruby_llm:upgrade_to_v1_7', 'chat:Conversation', 'message:ChatMessage'
  generate 'ruby_llm:upgrade_to_v1_9', 'message:ChatMessage'
end
