# frozen_string_literal: true

require 'ruby_llm'

class ModelUpdater # rubocop:disable Style/Documentation
  def run
    puts 'Configuring RubyLLM...'
    configure_from_env

    refresh_models
    display_model_stats
  end

  private

  def configure_from_env
    RubyLLM.configure do |config|
      config.openai_api_key = ENV.fetch('OPENAI_API_KEY', nil)
      config.anthropic_api_key = ENV.fetch('ANTHROPIC_API_KEY', nil)
      config.gemini_api_key = ENV.fetch('GEMINI_API_KEY', nil)
      config.deepseek_api_key = ENV.fetch('DEEPSEEK_API_KEY', nil)
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

  def refresh_models # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
    initial_count = RubyLLM.models.all.size
    puts "Refreshing models (#{initial_count} cached)..."

    models = RubyLLM.models.refresh!

    if models.all.empty? && initial_count.zero?
      puts 'Error: Failed to fetch models.'
      exit(1)
    elsif models.all.size == initial_count && initial_count.positive?
      puts 'Warning: Model list unchanged.'
    else
      puts "Saving models.json (#{models.all.size} models)"
      models.save_models
    end

    @models = models
  end

  def display_model_stats
    puts "\nModel count:"
    provider_counts = @models.all.group_by(&:provider).transform_values(&:count)

    RubyLLM::Provider.providers.each_key do |sym|
      name = sym.to_s.capitalize
      count = provider_counts[sym.to_s] || 0
      status = RubyLLM::Provider.providers[sym].configured? ? '(OK)' : '(SKIP)'
      puts "  #{name}: #{count} models #{status}"
    end

    puts 'Refresh complete.'
  end
end
