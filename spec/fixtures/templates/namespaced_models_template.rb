# frozen_string_literal: true

gem 'ruby_llm', path: ENV['RUBYLLM_PATH'] || '../../../..'

generate 'ruby_llm:install',
         'chat:Llm::Chat',
         'message:Llm::Message'
rails_command 'db:migrate'
generate 'ruby_llm:chat_ui',
         'chat:Llm::Chat',
         'message:Llm::Message'
