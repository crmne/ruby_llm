# frozen_string_literal: true

require 'json'

namespace :aliases do # rubocop:disable Metrics/BlockLength
  desc 'Generate aliases.json from models in the registry'
  task :generate do # rubocop:disable Metrics/BlockLength
    require 'ruby_llm'

    # Group models by provider
    models = Hash.new { |h, k| h[k] = [] }

    RubyLLM.models.all.each do |model|
      models[model.provider] << model.id
    end

    aliases = {}

    # OpenAI models
    models['openai'].each do |model|
      openrouter_model = "openai/#{model}"
      next unless models['openrouter'].include?(openrouter_model)

      alias_key = model.gsub('-latest', '')
      aliases[alias_key] = {
        'openai' => model,
        'openrouter' => openrouter_model
      }
    end

    # Anthropic models - group by base name and find latest
    anthropic_latest = group_anthropic_models_by_base_name(models['anthropic'])

    anthropic_latest.each do |base_name, latest_model|
      # Check OpenRouter naming patterns for the BASE NAME (not the full dated model)
      openrouter_variants = [
        "anthropic/#{base_name}", # anthropic/claude-3-5-sonnet
        "anthropic/#{base_name.gsub(/-(\d)/, '.\1')}", # anthropic/claude-3.5-sonnet
        "anthropic/#{base_name.gsub(/claude-(\d+)-(\d+)/, 'claude-\1.\2')}", # claude-3-5 -> claude-3.5
        "anthropic/#{base_name.gsub(/(\d+)-(\d+)/, '\1.\2')}" # any X-Y -> X.Y pattern
      ]

      openrouter_model = openrouter_variants.find { |v| models['openrouter'].include?(v) }

      # Find corresponding Bedrock model
      bedrock_model = find_best_bedrock_model(latest_model, models['bedrock'])

      # Create alias if we have any match (OpenRouter OR Bedrock) OR if it's Anthropic-only
      next unless openrouter_model || bedrock_model || models['anthropic'].include?(latest_model)

      aliases[base_name] = {
        'anthropic' => latest_model
      }

      aliases[base_name]['openrouter'] = openrouter_model if openrouter_model
      aliases[base_name]['bedrock'] = bedrock_model if bedrock_model
    end

    # Also check if Bedrock has models that Anthropic doesn't
    models['bedrock'].each do |bedrock_model|
      next unless bedrock_model.start_with?('anthropic.')

      # Extract the Claude model name
      next unless bedrock_model =~ /anthropic\.(claude-[\d\.]+-[a-z]+)/

      base_name = Regexp.last_match(1)
      # Normalize to Anthropic naming convention
      anthropic_name = base_name.gsub('.', '-')

      # Skip if we already have an alias for this
      next if aliases[anthropic_name]

      # Check if this model exists in OpenRouter
      openrouter_variants = [
        "anthropic/#{anthropic_name}",
        "anthropic/#{base_name}" # Keep the dots
      ]

      openrouter_model = openrouter_variants.find { |v| models['openrouter'].include?(v) }

      aliases[anthropic_name] = {
        'bedrock' => bedrock_model
      }

      aliases[anthropic_name]['anthropic'] = anthropic_name if models['anthropic'].include?(anthropic_name)
      aliases[anthropic_name]['openrouter'] = openrouter_model if openrouter_model
    end

    # Gemini models
    models['gemini'].each do |model|
      # OpenRouter uses "google/" prefix and sometimes different naming
      openrouter_variants = [
        "google/#{model}",
        "google/#{model.gsub('gemini-', 'gemini-').gsub('.', '-')}",
        "google/#{model.gsub('gemini-', 'gemini-')}"
      ]

      openrouter_model = openrouter_variants.find { |v| models['openrouter'].include?(v) }
      next unless openrouter_model

      alias_key = model.gsub('-latest', '')
      aliases[alias_key] = {
        'gemini' => model,
        'openrouter' => openrouter_model
      }
    end

    # DeepSeek models
    models['deepseek'].each do |model|
      openrouter_model = "deepseek/#{model}"
      next unless models['openrouter'].include?(openrouter_model)

      alias_key = model.gsub('-latest', '')
      aliases[alias_key] = {
        'deepseek' => model,
        'openrouter' => openrouter_model
      }
    end

    # Write the result
    sorted_aliases = aliases.sort.to_h
    File.write('lib/ruby_llm/aliases.json', JSON.pretty_generate(sorted_aliases))

    puts "Generated #{sorted_aliases.size} aliases"
  end

  def group_anthropic_models_by_base_name(anthropic_models) # rubocop:disable Rake/MethodDefinitionInTask
    grouped = Hash.new { |h, k| h[k] = [] }

    anthropic_models.each do |model|
      base_name = extract_base_name(model)
      grouped[base_name] << model
    end

    # Find the latest model for each base name
    latest_models = {}
    grouped.each do |base_name, model_list|
      if model_list.size == 1
        latest_models[base_name] = model_list.first
      else
        # Sort by date and take the latest
        latest_model = model_list.max_by { |model| extract_date_from_model(model) }
        latest_models[base_name] = latest_model
      end
    end

    latest_models
  end

  def extract_base_name(model) # rubocop:disable Rake/MethodDefinitionInTask
    # Remove date suffix (YYYYMMDD) from model name
    if model =~ /^(.+)-(\d{8})$/
      Regexp.last_match(1)
    else
      # Models without date suffix (like claude-2.0, claude-2.1)
      model
    end
  end

  def extract_date_from_model(model) # rubocop:disable Rake/MethodDefinitionInTask
    # Extract date for comparison, return '00000000' for models without dates
    if model =~ /-(\d{8})$/
      Regexp.last_match(1)
    else
      '00000000' # Ensures models without dates sort before dated ones
    end
  end

  def find_best_bedrock_model(anthropic_model, bedrock_models) # rubocop:disable Metrics/PerceivedComplexity,Rake/MethodDefinitionInTask
    # Special mapping for Claude 2.x models
    base_pattern = case anthropic_model
                   when 'claude-2.0', 'claude-2'
                     'claude-v2'
                   when 'claude-2.1'
                     'claude-v2:1'
                   when 'claude-instant-v1', 'claude-instant'
                     'claude-instant'
                   else
                     # For Claude 3+ models, extract base name
                     extract_base_name(anthropic_model)
                   end

    # Find all matching Bedrock models by stripping provider prefix and comparing base name
    matching_models = bedrock_models.select do |bedrock_model|
      # Strip any provider prefix (anthropic. or us.anthropic.)
      model_without_prefix = bedrock_model.sub(/^(?:us\.)?anthropic\./, '')
      model_without_prefix.start_with?(base_pattern)
    end

    return nil if matching_models.empty?

    # Get model info to check context window
    begin
      model_info = RubyLLM.models.find(anthropic_model)
      target_context = model_info.context_window
    rescue StandardError
      target_context = nil
    end

    # If we have context window info, try to match it
    if target_context
      # Convert to k format (200000 -> 200k)
      target_k = target_context / 1000

      # Find models with this specific context window
      with_context = matching_models.select do |m|
        m.include?(":#{target_k}k") || m.include?(":0:#{target_k}k")
      end

      return with_context.first if with_context.any?
    end

    # Otherwise, pick the one with the highest context window or latest version
    matching_models.min_by do |model|
      # Extract context window if specified
      context_priority = if model =~ /:(?:\d+:)?(\d+)k/
                           -Regexp.last_match(1).to_i # Negative for descending sort
                         else
                           0 # No context specified
                         end

      # Extract version if present
      version_priority = if model =~ /-v(\d+):/
                           -Regexp.last_match(1).to_i # Negative for descending sort (latest version first)
                         else
                           0
                         end

      # Prefer models with explicit context windows
      has_context_priority = model.include?('k') ? -1 : 0

      [has_context_priority, context_priority, version_priority]
    end
  end
end
