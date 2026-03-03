# frozen_string_literal: true

def run_parallel_rspec
  workers = ENV.fetch('RSPEC_WORKERS', nil)
  cmd = %w[bundle exec parallel_rspec]
  cmd += ['-n', workers] if workers && !workers.empty?
  system(*cmd)
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
      puts 'Model registry not configured. Run rails generate ruby_llm:install'
    end
  end
end
