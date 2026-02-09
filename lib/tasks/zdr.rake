# frozen_string_literal: true

require 'ruby_llm'
require 'ruby_llm/zdr_enricher'

namespace :models do # rubocop:disable Metrics/BlockLength
  desc 'Enrich models with ZDR (Zero Data Retention) policies from OpenRouter'
  task :zdr do
    enricher = RubyLLM::ZDREnricher.new
    puts 'Fetching ZDR policies from OpenRouter...'
    models_data = enricher.load_models_data

    if models_data.empty?
      puts '❌ Error: No models found. Run `rake models:update` first.'
      exit(1)
    end

    zdr_policies = enricher.fetch_openrouter_zdr_policies
    if zdr_policies.nil? || zdr_policies.empty?
      puts '⚠️  Warning: Could not fetch ZDR policies from OpenRouter. Skipping enrichment.'
      exit(0)
    end

    puts 'Enriching models...'
    enriched_count = 0
    models_data.each do |model|
      zdr_data = enricher.extract_zdr_for_model(model, zdr_policies)
      next unless zdr_data

      model['metadata'] ||= {}
      model['metadata']['zdr'] = zdr_data
      enriched_count += 1
    end

    enricher.save_models_data(models_data)
    puts "✅ ZDR enrichment complete (#{enriched_count}/#{models_data.size} models enriched)"
  end
end
