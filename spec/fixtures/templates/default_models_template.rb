# frozen_string_literal: true

gem 'ruby_llm', path: ENV['RUBYLLM_PATH'] || '../../../..'

after_bundle do
  generate 'ruby_llm:install'
  rails_command 'db:migrate'
  generate 'ruby_llm:chat_ui'
end
