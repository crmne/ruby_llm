# frozen_string_literal: true

require 'spec_helper'
require 'nokogiri'
require_relative '../../tasks/support/model_catalog_page'

RSpec.describe ModelCatalogPage do
  let(:chat) { RubyLLM.models.find('claude-haiku-4-5', provider: :anthropic) }
  let(:embedding) { RubyLLM.models.find('text-embedding-3-small', provider: :openai) }
  let(:models) { [chat, embedding] }
  let(:page) { described_class.new(models, updated_on: '2026-09-06').render }
  let(:html) { Nokogiri::HTML.fragment(page.split('---', 3).last) }

  def row_data
    html.css('[data-model]').map { |row| JSON.parse(row['data-model']) }
  end

  it 'generates a full-width page with each registry entry rendered once' do
    expect(page).to include('layout: models', 'Updated <time datetime="2026-09-06">')
    expect(html.css('tbody tr').size).to eq(2)
    expect(row_data.pluck('id')).to eq(models.map(&:id))
    expect(html.text).to include(chat.name, chat.id, embedding.name, embedding.id)
  end

  it 'keeps provider, capability, and input and output modality groups distinct' do
    expect(row_data.first).to include(
      'provider' => 'Anthropic',
      'capabilities' => include('Tools', 'Thinking', 'Structured output'),
      'modalities' => include('Image input', 'PDF input', 'Text output')
    )
    expect(row_data.last['modalities']).to include('Embeddings')
    expect(row_data.last['modalities']).not_to include('Image input')
  end

  it 'preserves numeric limits and prices for sorting instead of formatted strings' do
    expect(row_data.first).to include(
      'context' => chat.context_window,
      'output' => chat.max_output_tokens,
      'input_price' => chat.pricing.text_tokens.input,
      'output_price' => chat.pricing.text_tokens.output
    )
    expect(html.css('tbody tr').first.text).to include('Cache read', 'Cache write')
  end

  it 'distinguishes free text tokens from missing prices and preserves small prices' do
    pricing = { text_tokens: { standard: { input_per_million: 0, cache_read_input_per_million: 0.000001 } } }
    model = RubyLLM::Model.new(chat.to_h.merge(pricing: pricing))
    output = described_class.new([model]).render
    row = Nokogiri::HTML.fragment(output.split('---', 3).last).at_css('tbody tr')

    expect(JSON.parse(row['data-model'])).to include('input_price' => 0, 'output_price' => nil)
    expect(row.css('td')[-2].text).to eq('$0Cache read $0.000001')
    expect(row.css('td').last.text).to eq('—')
  end

  it 'escapes provider-supplied names as both HTML and Liquid text' do
    name = '<script>alert("x")</script> {% include secret %} {{ site.secret }}'
    model = RubyLLM::Model.new(chat.to_h.merge(name: name))
    output = described_class.new([model]).render
    document = Nokogiri::HTML.fragment(output.split('---', 3).last)

    expect(document.css('script')).to be_empty
    expect(document.at_css('.catalog-model-name').text).to eq(name)
    expect(JSON.parse(document.at_css('[data-model]')['data-model'])['name']).to eq(name)
    expect(output).not_to include('{% include secret %}', '{{ site.secret }}')
  end

  it 'exposes the raw registry and Ruby refresh command without a dialog or JavaScript' do
    expect(html.at_css('.catalog-command code').text).to eq('curl https://rubyllm.com/models.json')
    expect(html.at_css('a[href="https://rubyllm.com/models.json"]').text).to eq('Download JSON')
    expect(html.text).to include('RubyLLM.models.refresh')
  end
end
