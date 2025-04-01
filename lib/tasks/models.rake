# frozen_string_literal: true

require_relative 'model_updater'
require_relative 'capability_scraper'
require_relative 'capability_generator'

namespace :models do # rubocop:disable Metrics/BlockLength
  desc 'Update available models from providers (API keys needed)'
  task :update do
    ModelUpdater.new.run
  end

  desc 'Update capabilities modules (GEMINI_API_KEY needed)'
  task :update_capabilities, [:providers] do |_t, args|
    gemini_key = ENV.fetch('GEMINI_API_KEY', nil)
    unless gemini_key && !gemini_key.empty?
      puts 'Error: GEMINI_API_KEY required'
      exit(1)
    end

    RubyLLM.configure do |c|
      c.gemini_api_key = gemini_key
      c.request_timeout = 300
    end

    target_providers = CapabilityScraper.parse_providers(args[:providers])

    begin
      scraper = CapabilityScraper.new(target_providers)
      scraper.run do |provider, docs_html|
        generator = CapabilityGenerator.new(provider, docs_html)
        generator.generate_and_save
      end
    rescue StandardError => e
      puts "Error: #{e.message}"
      puts e.backtrace.first(5).join("\n")
    ensure
      puts 'Update process complete. Review generated files.'
    end
  end
end

task default: ['models:update']
