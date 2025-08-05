# frozen_string_literal: true

require 'dotenv/load'
require 'ruby_llm'
require 'json-schema'

task default: ['models:update']

namespace :models do
  desc 'Update available models from providers (API keys needed)'
  task :update do
    puts 'Configuring RubyLLM...'
    configure_from_env

    refresh_models
    display_model_stats
  end
end

def configure_from_env
  RubyLLM.configure do |config|
    config.openai_api_key = ENV.fetch('OPENAI_API_KEY', nil)
    config.anthropic_api_key = ENV.fetch('ANTHROPIC_API_KEY', nil)
    config.gemini_api_key = ENV.fetch('GEMINI_API_KEY', nil)
    config.deepseek_api_key = ENV.fetch('DEEPSEEK_API_KEY', nil)
    config.perplexity_api_key = ENV.fetch('PERPLEXITY_API_KEY', nil)
    config.openrouter_api_key = ENV.fetch('OPENROUTER_API_KEY', nil)
    config.mistral_api_key = ENV.fetch('MISTRAL_API_KEY', nil)
    configure_bedrock(config)
    config.request_timeout = 30
  end
end

def configure_bedrock(config)
  config.bedrock_api_key = ENV.fetch('AWS_ACCESS_KEY_ID', nil)
  config.bedrock_secret_key = ENV.fetch('AWS_SECRET_ACCESS_KEY', nil)
  config.bedrock_region = ENV.fetch('AWS_REGION', nil)
  config.bedrock_session_token = ENV.fetch('AWS_SESSION_TOKEN', nil)
end

def refresh_models
  initial_count = RubyLLM.models.all.size
  puts "Refreshing models (#{initial_count} cached)..."

  models = RubyLLM.models.refresh!

  if models.all.empty? && initial_count.zero?
    puts 'Error: Failed to fetch models.'
    exit(1)
  elsif models.all.size == initial_count && initial_count.positive?
    puts 'Warning: Model list unchanged.'
  else
    puts 'Validating models...'
    validate_models!(models)

    puts "Saving models.json (#{models.all.size} models)"
    models.save_models
  end

  @models = models
end

def validate_models!(models)
  schema_path = File.expand_path('../ruby_llm/models_schema.json', __dir__)
  models_data = models.all.map(&:to_h)

  validation_errors = JSON::Validator.fully_validate(schema_path, models_data)

  unless validation_errors.empty?
    # Save failed models for inspection
    failed_path = File.expand_path('../ruby_llm/models.failed.json', __dir__)
    File.write(failed_path, JSON.pretty_generate(models_data))

    puts 'ERROR: Models validation failed:'
    puts "\nValidation errors:"
    validation_errors.first(10).each { |error| puts "  - #{error}" }
    puts "  ... and #{validation_errors.size - 10} more errors" if validation_errors.size > 10
    puts "-> Failed models saved to: #{failed_path}"
    exit(1)
  end

  puts '✓ Models validation passed'
end

def display_model_stats
  puts "\nModel count:"
  provider_counts = @models.all.group_by(&:provider).transform_values(&:count)

  RubyLLM::Provider.providers.each_key do |sym|
    name = sym.to_s.capitalize
    count = provider_counts[sym.to_s] || 0
    status = status(sym)
    puts "  #{name}: #{count} models #{status}"
  end

  puts 'Refresh complete.'
end

def status(provider_sym)
  if RubyLLM::Provider.providers[provider_sym].local?
    ' (LOCAL - SKIP)'
  elsif RubyLLM::Provider.providers[provider_sym].configured?
    ' (OK)'
  else
    ' (NOT CONFIGURED)'
  end
end
