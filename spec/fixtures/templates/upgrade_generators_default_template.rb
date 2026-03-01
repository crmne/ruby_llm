# frozen_string_literal: true

gem 'ruby_llm', path: ENV['RUBYLLM_PATH'] || '../../../..'

after_bundle do
  migration_version = "[#{Rails::VERSION::MAJOR}.#{Rails::VERSION::MINOR}]"

  file 'config/initializers/ruby_llm.rb', <<~RUBY
    RubyLLM.configure do |config|
      config.openai_api_key = ENV.fetch("OPENAI_API_KEY", "test")
    end
  RUBY

  file 'app/models/chat.rb', <<~RUBY
    class Chat < ApplicationRecord
    acts_as_chat
    end
  RUBY

  file 'app/models/message.rb', <<~RUBY
    class Message < ApplicationRecord
    acts_as_message
    end
  RUBY

  file 'app/models/tool_call.rb', <<~RUBY
    class ToolCall < ApplicationRecord
    acts_as_tool_call
    end
  RUBY

  file 'db/migrate/20200101000000_create_chats.rb', <<~RUBY
    class CreateChats < ActiveRecord::Migration#{migration_version}
      def change
        create_table :chats do |t|
          t.string :model_id
          t.string :provider
          t.timestamps
        end
      end
    end
  RUBY

  file 'db/migrate/20200101000001_create_messages.rb', <<~RUBY
    class CreateMessages < ActiveRecord::Migration#{migration_version}
      def change
        create_table :messages do |t|
          t.integer :chat_id
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
          t.integer :message_id
          t.timestamps
        end
      end
    end
  RUBY

  rails_command 'db:migrate'

  generate 'ruby_llm:upgrade_to_v1_7'
  generate 'ruby_llm:upgrade_to_v1_9'
end
