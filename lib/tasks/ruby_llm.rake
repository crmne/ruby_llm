# frozen_string_literal: true

def run_test_queue_rspec
  workers = ENV.fetch('RSPEC_WORKERS', nil)
  env = {}
  env['TEST_QUEUE_WORKERS'] = workers if workers && !workers.empty? && ENV.fetch('TEST_QUEUE_WORKERS', '').empty?

  system(env, 'bundle', 'exec', 'bin/rspec-queue')
end

namespace :ruby_llm do
  desc 'Load models from models.json into the database'
  task load_models: :environment do
    if RubyLLM.config.model_registry_class
      RubyLLM.models.load_from_json!
      model_class = RubyLLM.config.model_registry_class.constantize
      model_class.save_to_database
      puts "✅ Loaded #{model_class.count} models into database"
    else
      puts 'Model registry not configured. Run bin/rails generate ruby_llm:install'
    end
  end
end
