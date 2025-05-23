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

    # Anthropic models
    models['anthropic'].each do |model|
      # Check both naming conventions for OpenRouter
      openrouter_variants = [
        "anthropic/#{model}",
        "anthropic/#{model.gsub(/-(\d)/, '.\1')}" # claude-3-5 -> claude-3.5
      ]

      openrouter_model = openrouter_variants.find { |v| models['openrouter'].include?(v) }

      # Find corresponding Bedrock model (regardless of OpenRouter)
      bedrock_model = find_best_bedrock_model(model, models['bedrock'])

      # Create alias if we have any match (OpenRouter OR Bedrock)
      next unless openrouter_model || bedrock_model

      alias_key = model.gsub('-latest', '')
      aliases[alias_key] = {
        'anthropic' => model
      }

      aliases[alias_key]['openrouter'] = openrouter_model if openrouter_model
      aliases[alias_key]['bedrock'] = bedrock_model if bedrock_model
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

  def extract_base_name(anthropic_model) # rubocop:disable Rake/MethodDefinitionInTask
    # Remove -latest suffix and date stamps
    model_name = anthropic_model.gsub('-latest', '')

    # Extract the base model name without date/version
    # e.g. "claude-3-5-sonnet-20241022" -> "claude-3-5-sonnet"
    # e.g. "claude-3-opus" -> "claude-3-opus"

    if model_name =~ /^(claude-[\d\-]+-[a-z]+)(?:-\d{8})?$/
      Regexp.last_match(1)
    else
      model_name
    end
  end
end
