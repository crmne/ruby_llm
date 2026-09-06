# frozen_string_literal: true

require 'cgi'
require 'erb'
require 'json'

class ModelCatalogPage # :nodoc:
  CAPABILITY_NAMES = {
    'function_calling' => 'Tools',
    'reasoning' => 'Thinking',
    'structured_output' => 'Structured output',
    'batch' => 'Batch processing',
    'parallel_tool_calls' => 'Parallel tools',
    'tool_choice' => 'Tool choice'
  }.freeze

  def initialize(models, updated_on: Time.now.utc.strftime('%Y-%m-%d'))
    @models = models.sort_by { |model| [model.provider, model.name.downcase, model.id] }
    @updated_on = updated_on
  end

  def render
    template = File.read(File.expand_path('../templates/available_models.md.erb', __dir__))
    ERB.new(template, trim_mode: '-').result(binding)
  end

  private

  def escape(value)
    CGI.escapeHTML(value.to_s).gsub('{', '&#123;').gsub('}', '&#125;')
  end

  def provider_name(model)
    RubyLLM::Provider.providers.fetch(model.provider.to_sym).display_name
  end

  def capability_name(capability)
    CAPABILITY_NAMES.fetch(capability) { capability.tr('_', ' ').capitalize }
  end

  def row_data(model)
    {
      id: model.id, name: model.name, provider: provider_name(model),
      capabilities: model.capabilities.map { |capability| capability_name(capability) },
      modalities: modality_groups(model),
      context: model.context_window, output: model.max_output_tokens,
      input_price: text_prices(model)[:input_per_million],
      output_price: text_prices(model)[:output_per_million]
    }.to_json
  end

  def modality_groups(model)
    %i[input output].flat_map do |direction|
      Array(model.modalities.public_send(direction)).map do |modality|
        next 'Embeddings' if modality == 'embeddings'

        label = modality == 'pdf' ? 'PDF' : modality.capitalize
        "#{label} #{direction}"
      end
    end
  end

  def text_prices(model)
    model.pricing.to_h.dig(:text_tokens, :standard) || {}
  end

  def number(value)
    return '—' if value.nil?

    value.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
  end

  def price(value)
    return '—' if value.nil?

    "$#{format('%.6f', value).sub(/0+\z/, '').delete_suffix('.')}"
  end
end
