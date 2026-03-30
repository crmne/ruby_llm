# frozen_string_literal: true

gem 'ruby_llm', path: ENV['RUBYLLM_PATH'] || '../../../..'

generate 'ruby_llm:install'
rails_command 'db:migrate'
create_file 'app/assets/tailwind/application.css', "/* tailwind marker */\n"
generate 'ruby_llm:chat_ui', '--ui=auto'
