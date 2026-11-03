# frozen_string_literal: true

require 'spec_helper'
require_relative '../../tasks/support/model_unit_prices'

RSpec.describe ModelUnitPrices do
  def entry(**attributes)
    ModelUnitPrices::Entry.new(
      provider: 'openai', model: 'tts-1', unit: 'characters', per_million: 15,
      quoted: '$15.00 / 1M characters', source: 'https://developers.openai.com/api/docs/pricing',
      checked: Date.new(2026, 11, 3), **attributes
    )
  end

  def model(id: 'tts-1', provider: 'openai', pricing: {}, metadata: {})
    RubyLLM::Model.new(id:, provider:, pricing:, metadata:)
  end

  describe 'the bundled file' do
    let(:entries) { described_class.load.entries }

    it 'lists prices' do
      expect(entries).not_to be_empty
    end

    it 'names real models that RubyLLM can call' do
      entries.each do |entry|
        expect { RubyLLM.models.find(entry.model, provider: entry.provider) }.not_to raise_error
      end
    end

    it 'uses only units models.dev cannot express' do
      expect(entries.map(&:unit).uniq - ModelUnitPrices::UNITS).to be_empty
    end

    it 'gives each price as a positive number per million units' do
      expect(entries.map(&:per_million)).to all(be_a(Numeric).and(be_positive))
    end

    it 'quotes each price as the pricing page states it' do
      expect(entries.map(&:quoted)).to all(be_a(String).and(match(/\$\d/)))
    end

    it 'cites an https pricing page for each price' do
      expect(entries.map(&:source)).to all(match(%r{\Ahttps://[a-z0-9.-]+\.[a-z]+/\S*\z}))
    end

    it 'records the date each price was checked' do
      expect(entries.map(&:checked)).to all(be_a(Date).and(be <= Date.today))
    end

    it 'lists each model and unit once' do
      keys = entries.map { |entry| [entry.provider, entry.model, entry.unit] }

      expect(keys).to eq(keys.uniq)
    end

    it 'has been applied to the bundled registry' do
      entries.each do |entry|
        price = RubyLLM.models.find(entry.model, provider: entry.provider).pricing.public_send(entry.unit).input

        expect(price).to eq(entry.per_million), "#{entry.provider}:#{entry.model} #{entry.unit}: run rake models"
      end
    end
  end

  describe '#apply' do
    it 'adds the price to a model models.dev does not price' do
      prices = described_class.new([entry])

      priced = prices.apply([model]).first

      expect(priced.pricing.characters.input).to eq(15)
      expect(prices.notices).to be_empty
    end

    it 'keeps the prices the model already has in other categories' do
      text = { text_tokens: { standard: { input_per_million: 1 } } }

      priced = described_class.new([entry]).apply([model(pricing: text)]).first

      expect(priced.pricing.text_tokens.input).to eq(1)
      expect(priced.pricing.characters.input).to eq(15)
    end

    it 'replaces the price an earlier refresh applied' do
      earlier = model(pricing: { characters: { standard: { input_per_million: 12 } } })

      priced = described_class.new([entry]).apply([earlier]).first

      expect(priced.pricing.characters.input).to eq(15)
    end

    it 'leaves other models untouched' do
      other = model(id: 'tts-1-hd')

      expect(described_class.new([entry]).apply([other])).to eq([other])
    end

    it 'never overrides a model models.dev prices and reports the provider figure' do
      upstream = model(pricing: { text_tokens: { standard: { input_per_million: 15 } } },
                       metadata: { source: 'models.dev', cost: { input: 15 } })
      prices = described_class.new([entry])

      priced = prices.apply([upstream]).first

      expect(priced.pricing.to_h).to eq(upstream.pricing.to_h)
      expect(prices.notices).to eq([
                                     'openai:tts-1 has a models.dev price, so its characters price was not ' \
                                     'applied. https://developers.openai.com/api/docs/pricing listed ' \
                                     '$15.00 / 1M characters on 2026-11-03: remove the entry, and report ' \
                                     'the price to models.dev if it differs.'
                                   ])
    end

    it 'drops a price an earlier refresh applied once models.dev prices the model' do
      upstream = model(pricing: { characters: { standard: { input_per_million: 15 } } },
                       metadata: { source: 'models.dev', cost: { input: 20 } })

      priced = described_class.new([entry]).apply([upstream]).first

      expect(priced.pricing.to_h).to eq({})
    end

    it 'keeps a unit price models.dev gives itself' do
      upstream = model(pricing: { characters: { standard: { input_per_million: 16 } } },
                       metadata: { source: 'models.dev', cost: { characters: 16 } })

      priced = described_class.new([entry]).apply([upstream]).first

      expect(priced.pricing.characters.input).to eq(16)
    end

    it 'reports an entry for a model the registry does not list' do
      listed = model
      prices = described_class.new([entry(model: 'tts-0')])

      expect(prices.apply([listed])).to eq([listed])
      expect(prices.notices).to eq(['openai:tts-0 is not in the registry, so its characters price was not applied.'])
    end
  end
end
