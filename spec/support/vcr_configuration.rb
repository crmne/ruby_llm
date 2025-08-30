# frozen_string_literal: true

# VCR Configuration
VCR.configure do |config|
  config.cassette_library_dir = 'spec/fixtures/vcr_cassettes'
  config.hook_into :webmock
  config.configure_rspec_metadata!

  # Don't record new HTTP interactions when running in CI
  config.default_cassette_options = {
    record: ENV['CI'] ? :none : :once
  }

  # Create new cassette directory if it doesn't exist
  FileUtils.mkdir_p(config.cassette_library_dir)

  # Allow HTTP connections when necessary - this will fail PRs by design if they don't have cassettes
  config.allow_http_connections_when_no_cassette = true

  # Filter out API keys from the recorded cassettes
  config.filter_sensitive_data('<OPENAI_API_KEY>') { ENV.fetch('OPENAI_API_KEY', nil) }
  config.filter_sensitive_data('<ANTHROPIC_API_KEY>') { ENV.fetch('ANTHROPIC_API_KEY', nil) }
  config.filter_sensitive_data('<GEMINI_API_KEY>') { ENV.fetch('GEMINI_API_KEY', nil) }
  config.filter_sensitive_data('<DEEPSEEK_API_KEY>') { ENV.fetch('DEEPSEEK_API_KEY', nil) }
  config.filter_sensitive_data('<PERPLEXITY_API_KEY>') { ENV.fetch('PERPLEXITY_API_KEY', nil) }
  config.filter_sensitive_data('<OPENROUTER_API_KEY>') { ENV.fetch('OPENROUTER_API_KEY', nil) }
  config.filter_sensitive_data('<MISTRAL_API_KEY>') { ENV.fetch('MISTRAL_API_KEY', nil) }
  config.filter_sensitive_data('<OLLAMA_API_BASE>') { ENV.fetch('OLLAMA_API_BASE', 'http://localhost:11434/v1') }

  config.filter_sensitive_data('<GPUSTACK_API_BASE>') { ENV.fetch('GPUSTACK_API_BASE', 'http://localhost:11444/v1') }
  config.filter_sensitive_data('<GPUSTACK_API_KEY>') { ENV.fetch('GPUSTACK_API_KEY', nil) }

  config.filter_sensitive_data('<AWS_ACCESS_KEY_ID>') { ENV.fetch('AWS_ACCESS_KEY_ID', nil) }
  config.filter_sensitive_data('<AWS_SECRET_ACCESS_KEY>') { ENV.fetch('AWS_SECRET_ACCESS_KEY', nil) }
  config.filter_sensitive_data('<AWS_REGION>') { ENV.fetch('AWS_REGION', 'us-west-2') }
  config.filter_sensitive_data('<AWS_SESSION_TOKEN>') { ENV.fetch('AWS_SESSION_TOKEN', nil) }

  config.filter_sensitive_data('<GOOGLE_CLOUD_PROJECT>') { ENV.fetch('GOOGLE_CLOUD_PROJECT', 'test-project') }
  config.filter_sensitive_data('<GOOGLE_CLOUD_LOCATION>') { ENV.fetch('GOOGLE_CLOUD_LOCATION', 'us-central1') }

  # Filter Google OAuth tokens and credentials
  config.filter_sensitive_data('<GOOGLE_REFRESH_TOKEN>') do |interaction|
    interaction.request.body[/refresh_token=([^&]+)/, 1] if interaction.request.body&.include?('refresh_token')
  end

  config.filter_sensitive_data('<GOOGLE_CLIENT_ID>') do |interaction|
    interaction.request.body[/client_id=([^&]+)/, 1] if interaction.request.body&.include?('client_id')
  end

  config.filter_sensitive_data('<GOOGLE_CLIENT_SECRET>') do |interaction|
    interaction.request.body[/client_secret=([^&]+)/, 1] if interaction.request.body&.include?('client_secret')
  end

  config.filter_sensitive_data('<GOOGLE_ACCESS_TOKEN>') do |interaction|
    if interaction.response.body&.include?('"access_token"')
      begin
        JSON.parse(interaction.response.body)['access_token']
      rescue JSON::ParserError
        nil
      end
    end
  end

  config.filter_sensitive_data('<GOOGLE_ID_TOKEN>') do |interaction|
    if interaction.response.body&.include?('"id_token"')
      begin
        JSON.parse(interaction.response.body)['id_token']
      rescue JSON::ParserError
        nil
      end
    end
  end

  # Filter Bearer tokens in Authorization headers for Vertex AI
  config.filter_sensitive_data('Bearer <GOOGLE_BEARER_TOKEN>') do |interaction|
    auth_header = interaction.request.headers['Authorization']&.first
    auth_header if auth_header&.start_with?('Bearer ya29.')
  end

  config.filter_sensitive_data('<OPENAI_ORGANIZATION>') do |interaction|
    interaction.response.headers['Openai-Organization']&.first
  end
  config.filter_sensitive_data('<ANTHROPIC_ORGANIZATION_ID>') do |interaction|
    interaction.response.headers['Anthropic-Organization-Id']&.first
  end
  config.filter_sensitive_data('<X_REQUEST_ID>') { |interaction| interaction.response.headers['X-Request-Id']&.first }
  config.filter_sensitive_data('<REQUEST_ID>') { |interaction| interaction.response.headers['Request-Id']&.first }
  config.filter_sensitive_data('<CF_RAY>') { |interaction| interaction.response.headers['Cf-Ray']&.first }

  # Filter large strings used to test "context length exceeded" error handling
  config.filter_sensitive_data('<MASSIVE_TEXT>') { 'a' * 1_000_000 }

  # Filter cookies
  config.before_record do |interaction|
    if interaction.response.headers['Set-Cookie']
      interaction.response.headers['Set-Cookie'] = interaction.response.headers['Set-Cookie'].map { '<COOKIE>' }
    end
  end
end
