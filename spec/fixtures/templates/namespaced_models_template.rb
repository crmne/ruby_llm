# frozen_string_literal: true

gem 'ruby_llm', path: ENV['RUBYLLM_PATH'] || '../../../..'

after_bundle do
  generate 'ruby_llm:install',
           'chat:Llm::Chat',
           'message:Llm::Message',
           'model:Llm::Model',
           'tool_call:Llm::ToolCall'
  rails_command 'db:migrate'
  generate 'ruby_llm:chat_ui',
           'chat:Llm::Chat',
           'message:Llm::Message',
           'model:Llm::Model'
end
