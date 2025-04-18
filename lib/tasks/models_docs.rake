# frozen_string_literal: true

require 'ruby_llm'
require 'fileutils'

MODEL_KEYS_TO_DISPLAY = %i[
  id
  type
  display_name
  provider
  context_window
  max_tokens
  family
  input_price_per_million
  output_price_per_million
].freeze

def to_markdown_table(models) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
  to_display_hash = ->(model) { model.to_h.slice(*MODEL_KEYS_TO_DISPLAY) }
  model_hashes = Array(models).map { |model| to_display_hash.call(model) }

  # Create abbreviated headers
  headers = {
    id: 'ID',
    type: 'Type',
    display_name: 'Name',
    provider: 'Provider',
    context_window: 'Context',
    max_tokens: 'MaxTok',
    family: 'Family',
    input_price_per_million: 'In$/M',
    output_price_per_million: 'Out$/M'
  }

  # Create header row with alignment markers
  # Right-align numbers, left-align text
  alignments = {
    id: ':--',
    type: ':--',
    display_name: ':--',
    provider: ':--',
    context_window: '--:',
    max_tokens: '--:',
    family: ':--',
    input_price_per_million: '--:',
    output_price_per_million: '--:'
  }

  # Build the table
  lines = []

  # Header row
  lines << "| #{MODEL_KEYS_TO_DISPLAY.map { |key| headers[key] }.join(' | ')} |"

  # Alignment row
  lines << "| #{MODEL_KEYS_TO_DISPLAY.map { |key| alignments[key] }.join(' | ')} |"

  # Data rows
  model_hashes.each do |model_hash|
    values = MODEL_KEYS_TO_DISPLAY.map do |key|
      if model_hash[key].is_a?(Float)
        format('%.2f', model_hash[key])
      else
        model_hash[key]
      end
    end

    lines << "| #{values.join(' | ')} |"
  end

  lines.join("\n")
end

namespace :models do # rubocop:disable Metrics/BlockLength
  desc 'Generate available models documentation'
  task :docs do # rubocop:disable Metrics/BlockLength
    FileUtils.mkdir_p('docs/guides') # ensure output directory exists

    output = <<~MARKDOWN
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

      ## Additional Model Information

      The tables below show basic model information including context windows, token limits, and pricing. Models also have additional capabilities not shown in the tables:

      - **Vision Support**: Whether the model can process images
      - **Function Calling**: Whether the model supports function calling
      - **JSON Mode**: Whether the model can be constrained to output valid JSON
      - **Structured Output**: Whether the model supports structured output formats

      For complete model information, you can check the `models.json` file in the RubyLLM source code.

      For more information about working with models, see the [Working with Models](/guides/models) guide.

      ## Models by Type
      {: .d-inline-block }

      Last updated: #{Time.now.utc.strftime('%Y-%m-%d')}
      {: .label .label-green }

      ### Chat Models (#{RubyLLM.models.chat_models.count})

      #{to_markdown_table(RubyLLM.models.chat_models)}

      ### Image Models (#{RubyLLM.models.image_models.count})

      #{to_markdown_table(RubyLLM.models.image_models)}

      ### Audio Models (#{RubyLLM.models.audio_models.count})

      #{to_markdown_table(RubyLLM.models.audio_models)}

      ### Embedding Models (#{RubyLLM.models.embedding_models.count})

      #{to_markdown_table(RubyLLM.models.embedding_models)}

      ### Moderation Models (#{RubyLLM.models.select { |m| m.type == 'moderation' }.count})

      #{to_markdown_table(RubyLLM.models.select { |m| m.type == 'moderation' })}

      ## Models by Provider

      #{RubyLLM::Provider.providers.keys.map do |provider|
        models = RubyLLM.models.by_provider(provider)
        next if models.none?

        <<~PROVIDER
          ### #{provider.to_s.capitalize} Models (#{models.count})

            #{to_markdown_table(models)}
        PROVIDER
      end.compact.join("\n")}
    MARKDOWN

    File.write('docs/guides/available-models.md', output)
    puts 'Generated docs/guides/available-models.md'
  end
end
