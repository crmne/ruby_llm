# frozen_string_literal: true

require 'dotenv/load'
require 'fileutils'

namespace :models do
  desc 'Generate available models documentation'
  task :docs do
    FileUtils.mkdir_p('docs/guides') # ensure output directory exists

    # Generate markdown content
    output = generate_models_markdown

    # Write the output
    File.write('docs/guides/available-models.md', output)
    puts 'Generated docs/guides/available-models.md'
  end
end

def generate_models_markdown
  <<~MARKDOWN
    ---
    layout: default
    title: Available Models
    parent: Guides
    nav_order: 10
    permalink: /guides/available-models
    ---

    # Available Models
    {: .no_toc }

    This guide lists all models available in RubyLLM, automatically generated from the current model registry.
    {: .fs-6 .fw-300 }

    ## Table of contents
    {: .no_toc .text-delta }

    1. TOC
    {:toc}

    ---

    ## Contributing

    The model list is automatically generated from the model registry. To add or update models:

    1. Edit the appropriate `capabilities.rb` file in `lib/ruby_llm/providers/<provider>/`
    2. Run `rake models:update` to refresh the model registry
    3. Submit a pull request with the updated `models.json`

    See [Contributing Guide](/CONTRIBUTING.md) for more details.

    ## Last Updated
    {: .d-inline-block }

    #{Time.now.utc.strftime('%Y-%m-%d')}
    {: .label .label-green }

    {: .warning }
    This page is currently work in progress given the new Parsera integration.

    ## Models by Provider

    #{generate_provider_sections}

    ## Models by Capability

    #{generate_capability_sections}

    ## Models by Modality

    #{generate_modality_sections}
  MARKDOWN
end

def generate_provider_sections
  RubyLLM::Provider.providers.keys.map do |provider|
    models = RubyLLM.models.by_provider(provider)
    next if models.none?

    <<~PROVIDER
      ### #{provider.to_s.capitalize} (#{models.count})

      #{models_table(models)}
    PROVIDER
  end.compact.join("\n\n")
end

def generate_capability_sections
  capabilities = {
    'Function Calling' => RubyLLM.models.select(&:function_calling?),
    'Structured Output' => RubyLLM.models.select(&:structured_output?),
    'Streaming' => RubyLLM.models.select { |m| m.capabilities.include?('streaming') },
    'Reasoning' => RubyLLM.models.select { |m| m.capabilities.include?('reasoning') },
    'Batch Processing' => RubyLLM.models.select { |m| m.capabilities.include?('batch') }
  }

  capabilities.map do |capability, models|
    next if models.none?

    <<~CAPABILITY
      ### #{capability} (#{models.count})

      #{models_table(models)}
    CAPABILITY
  end.compact.join("\n\n")
end

def generate_modality_sections # rubocop:disable Metrics/PerceivedComplexity
  sections = []

  # Models that support vision/images
  vision_models = RubyLLM.models.select { |m| (m.modalities.input || []).include?('image') }
  if vision_models.any?
    sections << <<~SECTION
      ### Vision Models (#{vision_models.count})

      Models that can process images:

      #{models_table(vision_models)}
    SECTION
  end

  # Models that support audio
  audio_models = RubyLLM.models.select { |m| (m.modalities.input || []).include?('audio') }
  if audio_models.any?
    sections << <<~SECTION
      ### Audio Input Models (#{audio_models.count})

      Models that can process audio:

      #{models_table(audio_models)}
    SECTION
  end

  # Models that support PDFs
  pdf_models = RubyLLM.models.select { |m| (m.modalities.input || []).include?('pdf') }
  if pdf_models.any?
    sections << <<~SECTION
      ### PDF Models (#{pdf_models.count})

      Models that can process PDF documents:

      #{models_table(pdf_models)}
    SECTION
  end

  # Models for embeddings
  embedding_models = RubyLLM.models.select { |m| (m.modalities.output || []).include?('embeddings') }
  if embedding_models.any?
    sections << <<~SECTION
      ### Embedding Models (#{embedding_models.count})

      Models that generate embeddings:

      #{models_table(embedding_models)}
    SECTION
  end

  sections.join("\n\n")
end

def models_table(models)
  return '*No models found*' if models.none?

  headers = ['Model', 'ID', 'Provider', 'Context', 'Max Output', 'Standard Pricing (per 1M tokens)']
  alignment = [':--', ':--', ':--', '--:', '--:', ':--']

  rows = models.sort_by { |m| [m.provider, m.name] }.map do |model|
    # Format pricing information
    pricing = standard_pricing_display(model)

    [
      model.name,
      model.id,
      model.provider,
      model.context_window || '-',
      model.max_output_tokens || '-',
      pricing
    ]
  end

  table = []
  table << "| #{headers.join(' | ')} |"
  table << "| #{alignment.join(' | ')} |"

  rows.each do |row|
    table << "| #{row.join(' | ')} |"
  end

  table.join("\n")
end

def standard_pricing_display(model)
  # Access pricing data using to_h to get the raw hash
  pricing_data = model.pricing.to_h[:text_tokens]&.dig(:standard) || {}

  if pricing_data.any?
    parts = []

    parts << "In: $#{format('%.2f', pricing_data[:input_per_million])}" if pricing_data[:input_per_million]

    parts << "Out: $#{format('%.2f', pricing_data[:output_per_million])}" if pricing_data[:output_per_million]

    if pricing_data[:cached_input_per_million]
      parts << "Cache: $#{format('%.2f', pricing_data[:cached_input_per_million])}"
    end

    return parts.join(', ') if parts.any?
  end

  '-'
end
