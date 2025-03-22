# frozen_string_literal: true

# Helper functions at the top level
def record_all_cassettes(cassette_dir)
  # Re-record all cassettes
  FileUtils.rm_rf(cassette_dir)
  FileUtils.mkdir_p(cassette_dir)

  puts 'Recording cassettes for all providers...'
  run_tests
  puts 'Done recording. Please review the new cassettes.'
end

def record_for_providers(providers, cassette_dir) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
  # Get the list of available providers from RubyLLM itself
  all_providers = RubyLLM::Provider.providers.keys.map(&:to_s)

  # Check for valid providers
  if providers.empty?
    puts "Please specify providers or 'all'. Example: rake vcr:record[openai,anthropic]"
    puts "Available providers: #{all_providers.join(', ')}"
    return
  end

  invalid_providers = providers - all_providers
  if invalid_providers.any?
    puts "Invalid providers: #{invalid_providers.join(', ')}"
    puts "Available providers: #{all_providers.join(', ')}"
    return
  end

  # Get URL patterns from the providers themselves
  provider_patterns = get_provider_patterns(providers)

  puts "Finding cassettes for providers: #{providers.join(', ')}"

  # Find and delete matching cassettes
  cassettes_to_delete = find_matching_cassettes(cassette_dir, provider_patterns)

  if cassettes_to_delete.empty?
    puts 'No cassettes found for the specified providers.'
    puts 'Running tests to record new cassettes...'
  else
    delete_cassettes(cassettes_to_delete)
    puts "\nRunning tests to record new cassettes..."
  end

  run_tests

  puts "\nDone recording cassettes for #{providers.join(', ')}."
  puts 'Please review the updated cassettes for sensitive information.'
end

def get_provider_patterns(providers) # rubocop:disable Metrics/MethodLength
  provider_patterns = {}

  providers.each do |provider_name|
    provider_module = RubyLLM::Provider.providers[provider_name.to_sym]
    next unless provider_module

    # Extract the base URL from the provider's api_base method
    api_base = provider_module.api_base.to_s

    # Create a regex pattern from the domain
    next unless api_base && !api_base.empty?

    domain = URI.parse(api_base).host
    pattern = Regexp.new(Regexp.escape(domain))
    provider_patterns[provider_name] = pattern
  end

  provider_patterns
end

def find_matching_cassettes(dir, patterns)
  cassettes = []

  Dir.glob("#{dir}/**/*.yml").each do |file|
    content = File.read(file)
    cassettes << file if patterns.values.any? { |pattern| content.match?(pattern) }
  end

  cassettes
end

def delete_cassettes(cassettes)
  puts "Deleting #{cassettes.size} cassettes for re-recording:"
  cassettes.each do |file|
    puts "  - #{File.basename(file)}"
    File.delete(file)
  end
end

def run_tests
  system('bundle exec rspec') || abort('Tests failed')
end

namespace :vcr do
  desc 'Record VCR cassettes (rake vcr:record[all] or vcr:record[openai,anthropic])'
  task :record, [:providers] do |_, args|
    require 'fileutils'
    require 'ruby_llm'

    providers = (args[:providers] || '').downcase.split(',')
    cassette_dir = 'spec/fixtures/vcr_cassettes'
    FileUtils.mkdir_p(cassette_dir)

    if providers.include?('all')
      record_all_cassettes(cassette_dir)
    else
      record_for_providers(providers, cassette_dir)
    end
  end
end
