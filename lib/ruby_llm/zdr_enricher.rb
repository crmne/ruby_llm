# frozen_string_literal: true

require 'json'
require 'net/http'
require 'uri'
require 'fileutils'

module RubyLLM
  # Helper class to enrich models with ZDR (Zero Data Retention) policies
  class ZDREnricher
    def load_models_data
      models_file = RubyLLM.config.model_registry_file
      return [] unless File.exist?(models_file)

      JSON.parse(File.read(models_file))
    rescue JSON::ParserError => e
      warn "Error parsing #{File.basename(models_file)}: #{e.message}"
      []
    end

    def fetch_openrouter_zdr_policies
      provider_policies = fetch_provider_policies
      model_caching_data = fetch_model_caching_data

      { provider_policies: provider_policies, model_caching: model_caching_data }
    rescue StandardError => e
      warn "Failed to fetch ZDR policies from OpenRouter: #{e.message}"
      nil
    end

    def fetch_provider_policies
      uri = URI('https://openrouter.ai/api/frontend/all-providers')

      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, read_timeout: 10) do |http|
        request = Net::HTTP::Get.new(uri)
        request['User-Agent'] = 'RubyLLM/ZDR-Enrichment'
        http.request(request)
      end

      unless response.is_a?(Net::HTTPSuccess)
        warn "OpenRouter API returned #{response.code}: #{response.message}"
        return {}
      end

      data = JSON.parse(response.body)
      extract_provider_policies(data)
    end

    def extract_provider_policies(api_response)
      policies = {}
      providers = api_response['data'] || []

      providers.each do |provider|
        provider_name = provider['displayName']
        policy = provider['dataPolicy']
        next if provider_name.nil? || policy.nil?

        policies[provider_name] = {
          'available' => !policy['retainsPrompts'],
          'retention_period' => determine_retention_period(policy),
          'training_data_use' => determine_training_use(policy)
        }
      end

      policies
    end

    def determine_retention_period(policy)
      return 'zero' unless policy['retainsPrompts']
      return "#{policy['retentionDays']}_days" if policy['retentionDays']

      'unknown'
    end

    def determine_training_use(policy)
      return 'never' if !policy['training'] && !policy['trainingOpenRouter']
      return 'opt-out' if policy['training'] && !policy['trainingOpenRouter']

      'varies'
    end

    def fetch_model_caching_data
      uri = URI('https://openrouter.ai/api/v1/endpoints/zdr')

      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, read_timeout: 10) do |http|
        request = Net::HTTP::Get.new(uri)
        request['User-Agent'] = 'RubyLLM/ZDR-Enrichment'
        http.request(request)
      end

      unless response.is_a?(Net::HTTPSuccess)
        warn "OpenRouter API returned #{response.code}: #{response.message}"
        return {}
      end

      data = JSON.parse(response.body)
      extract_caching_data(data)
    end

    def extract_caching_data(api_response)
      caching_map = {}
      models = api_response['data'] || []

      models.each do |model|
        model_id = model['model_id']
        caching_map[model_id] = model['supports_implicit_caching'] if model_id
      end

      caching_map
    end

    def extract_zdr_for_model(model, zdr_policies)
      return nil unless zdr_policies

      provider = model['provider']
      model_id = model['id']

      # Get provider-level ZDR data
      provider_policies = zdr_policies[:provider_policies] || {}
      zdr_info = find_zdr_match(provider, nil, provider_policies)
      return nil unless zdr_info

      # Get model-level caching data
      model_caching = zdr_policies[:model_caching] || {}

      # Build complete ZDR data
      result = zdr_info.dup
      
      # Try multiple formats to find the caching data
      # OpenRouter uses "provider/model" format (e.g., "openai/gpt-4")
      openrouter_id = construct_openrouter_id(provider, model_id)
      caching_value = model_caching[openrouter_id] || 
                      model_caching[model_id] || 
                      false
      
      result['supports_implicit_caching'] = caching_value
      result
    end

    def save_models_data(models_data)
      models_file = RubyLLM.config.model_registry_file
      File.write(models_file, JSON.pretty_generate(models_data))
    end

    private

    def find_zdr_match(provider, _model_id, zdr_policies)
      # Map RubyLLM provider names to OpenRouter provider names
      openrouter_provider = map_provider_to_openrouter(provider)

      # Try direct match with OpenRouter provider name
      return zdr_policies[openrouter_provider] if openrouter_provider && zdr_policies[openrouter_provider]

      # Try variations of the provider name
      zdr_policies.each do |policy_provider, data|
        return data if policy_provider.downcase == provider.downcase
        return data if policy_provider.downcase.gsub(/\s+/, '') == provider.downcase.gsub(/\s+/, '')
      end

      nil
    end

    def map_provider_to_openrouter(provider)
      # Map RubyLLM provider names to OpenRouter documentation provider names
      mappings = {
        'openai' => 'OpenAI',
        'anthropic' => 'Anthropic',
        'google' => 'Google AI Studio',
        'gemini' => 'Google AI Studio',
        'vertexai' => 'Google Vertex',
        'mistral' => 'Mistral',
        'cohere' => 'Cohere',
        'deepseek' => 'DeepSeek',
        'xai' => 'xAI',
        'perplexity' => 'Perplexity',
        'bedrock' => 'Amazon Bedrock',
        'azure' => 'Azure',
        'openrouter' => 'OpenRouter'
      }

      mappings[provider.downcase]
    end

    def construct_openrouter_id(provider, model_id)
      # OpenRouter uses "provider/model" format
      # Map RubyLLM provider names to OpenRouter prefixes
      prefix_mappings = {
        'openai' => 'openai',
        'anthropic' => 'anthropic',
        'google' => 'google',
        'gemini' => 'google',
        'vertexai' => 'google',
        'mistral' => 'mistralai',
        'deepseek' => 'deepseek',
        'perplexity' => 'perplexity',
        'meta' => 'meta-llama',
        'bedrock' => 'amazon'
        # Note: xAI (Grok) models not present in OpenRouter caching data
        # Note: z-ai is Zhipu AI (GLM models), not xAI
      }

      prefix = prefix_mappings[provider.downcase] || provider.downcase
      "#{prefix}/#{model_id}"
    end
  end
end
