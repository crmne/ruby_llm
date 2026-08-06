# frozen_string_literal: true

namespace :ruby_llm do
  desc 'Load the selected model registry into the database'
  task load_models: :environment do
    RubyLLM.models.load_from_json!
    model_class = RubyLLM::ActiveRecord::Model
    model_class.save_to_database
    puts "✅ Loaded #{model_class.count} models into database"
  end
end
