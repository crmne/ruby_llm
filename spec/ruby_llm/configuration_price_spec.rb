# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Configuration, '#price' do
  let(:standard) do
    { input_per_million: 0.2, output_per_million: 1.2, cache_read_input_per_million: 0.02,
      cache_write_input_per_million: 0.25 }
  end
  let(:pricing) do
    { text_tokens: { standard:, batch: { input_per_million: 0.1, output_per_million: 0.6 },
                     long_context: { input_per_million: 0.4, output_per_million: 1.8 },
                     long_context_threshold: 272_000 } }
  end
  let(:model) { priced_model('gpt-5.6-luna') }

  def priced_model(id, provider: 'azure', **attributes)
    RubyLLM::Model.new(id:, name: id, provider:, pricing:, **attributes)
  end

  def cost(model, tier: :standard, **tokens)
    RubyLLM::Cost.new(tokens: RubyLLM::Tokens.new(**tokens), model:, tier:)
  end

  it 'replaces the prices it names and keeps the others' do
    RubyLLM.config.price 'gpt-5.6-luna', provider: :azure, input: 0.24, output: 1.44

    expect(model.pricing.text_tokens.standard.to_h).to eq(standard.merge(input_per_million: 0.24,
                                                                         output_per_million: 1.44))
  end

  it 'sets every token price' do
    RubyLLM.config.price 'gpt-5.6-luna', provider: :azure, input: 1, output: 2, cache_read: 3, cache_write: 4

    expect(%i[input output cache_read cache_write].map { |kind| model.price(kind) }).to eq([1, 2, 3, 4])
  end

  it 'prices a model the registry has no price for' do
    reranker = RubyLLM::Model.new(id: 'Cohere-rerank-v4.0-fast', name: 'Rerank', provider: 'azure')

    RubyLLM.config.price 'Cohere-rerank-v4.0-fast', provider: :azure, input: 0.024

    expect(cost(reranker, input: 1_000_000).total).to eq(0.024)
  end

  it 'sets the prices of characters, seconds of audio, and search units' do
    RubyLLM.config.price 'gpt-5.6-luna', provider: :azure, characters: 15, audio_seconds: 100, search_units: 2000

    expect(cost(model, characters: 1_000_000, audio_seconds: 1_000_000, search_units: 1_000_000))
      .to have_attributes(characters: 15, audio_seconds: 100, search_units: 2000)
  end

  it 'reaches every cost of the model' do
    RubyLLM.config.price 'gpt-5.6-luna', provider: :azure, input: 0.24, output: 1.44

    expect(model.cost_for(RubyLLM::Tokens.new(input: 100_000, output: 100_000)).total).to be_within(1e-9).of(0.168)
  end

  it 'reaches the audio tokens of a transcription' do
    audio = { standard: { input_per_million: 1.0 }, batch: { input_per_million: 0.5 } }
    model = priced_model('gemini-2.5-flash', provider: 'gemini', pricing: pricing.merge(audio_tokens: audio))

    RubyLLM.config.price 'gemini-2.5-flash', provider: :gemini, input: 0.01

    expect(RubyLLM::Cost.new(tokens: RubyLLM::Tokens.new(input: 100_000), model:, category: :audio_tokens).input)
      .to eq(0.001)
    expect(model.pricing.audio_tokens.batch.input_per_million).to eq(0.5)
  end

  it 'keeps the batch and long-context rates of the registry' do
    RubyLLM.config.price 'gpt-5.6-luna', provider: :azure, input: 0.24

    expect(cost(model, tier: :batch, input: 1_000_000).input).to eq(0.1)
    expect(cost(model, input: 1_000_000).input).to eq(0.4)
  end

  it 'reaches a model that was loaded before' do
    registered = RubyLLM.models.find('gpt-5.6-luna', provider: :azure)
    listed = registered.price(:input)

    RubyLLM.config.price 'gpt-5.6-luna', provider: :azure, input: listed * 2

    expect(registered.price(:input)).to eq(listed * 2)
    expect(RubyLLM.models.find('gpt-5.6-luna', provider: :azure).price(:input)).to eq(listed * 2)
  end

  it 'declares prices without loading the registry' do
    allow(RubyLLM::Models).to receive(:instance)

    RubyLLM.config.price 'gpt-5.6-luna', provider: :azure, input: 0.24

    expect(RubyLLM::Models).not_to have_received(:instance)
  end

  it 'adds the prices of a later call to the earlier ones, and the later call wins' do
    RubyLLM.config.price 'gpt-5.6-luna', provider: :azure, input: 0.24, output: 1.44
    RubyLLM.config.price 'gpt-5.6-luna', provider: 'azure', output: 1.5

    expect([model.price(:input), model.price(:output)]).to eq([0.24, 1.5])
  end

  it 'prices one model on one provider' do
    RubyLLM.config.price 'gpt-5.6-luna', provider: :azure, input: 0.24

    expect(priced_model('gpt-5.6-luna', provider: 'openai').price(:input)).to eq(0.2)
    expect(priced_model('gpt-5.6-terra').price(:input)).to eq(0.2)
  end

  it 'prices a model on a provider RubyLLM does not know' do
    RubyLLM.config.price 'house-model', provider: :house, input: 1
    RubyLLM.config.price 'other-model', provider: :house, input: 2, output: 3

    expect(%i[input output].map { |kind| priced_model('house-model', provider: 'house').price(kind) }).to eq([1, 1.2])
  end

  describe 'under an alias' do
    let(:haiku) { RubyLLM.models.find('claude-haiku-4-5', provider: :anthropic) }

    it 'prices the model the alias names' do
      RubyLLM.config.price 'claude-haiku-4-5', provider: :anthropic, input: 9

      expect(haiku).to have_attributes(id: 'claude-haiku-4-5-20251001')
      expect(haiku.price(:input)).to eq(9)
    end

    it 'gives way to prices under the id itself' do
      RubyLLM.config.price 'claude-haiku-4-5-20251001', provider: :anthropic, input: 8
      RubyLLM.config.price 'claude-haiku-4-5', provider: :anthropic, input: 9, output: 7

      expect([haiku.price(:input), haiku.price(:output)]).to eq([8, 7])
    end

    it 'prices the provider it names only' do
      RubyLLM.config.price 'claude-haiku-4-5', provider: :azure, input: 9
      listed = haiku.registry_pricing.text_tokens.input

      expect(haiku.price(:input)).to eq(listed)
    end
  end

  describe 'under an id the provider stores under another one' do
    before { RubyLLM.config.bedrock_region = 'us-east-1' }

    let(:profile) { RubyLLM.models.find('claude-haiku-4-5', provider: :bedrock) }

    it 'prices the model lookup resolves an alias to' do
      RubyLLM.config.price 'claude-haiku-4-5', provider: :bedrock, input: 9

      expect(profile).to have_attributes(id: 'us.anthropic.claude-haiku-4-5-20251001-v1:0')
      expect(profile.price(:input)).to eq(9)
    end

    it 'prices the model lookup resolves an id to' do
      RubyLLM.config.price 'anthropic.claude-haiku-4-5-20251001-v1:0', provider: :bedrock, input: 9

      expect(profile.price(:input)).to eq(9)
    end

    it 'follows a region set after the model was last read' do
      RubyLLM.config.price 'anthropic.claude-haiku-4-5-20251001-v1:0', provider: :bedrock, input: 9
      listed = profile.registry_pricing.text_tokens.input
      RubyLLM.config.bedrock_region = 'eu-west-1'
      elsewhere = profile.price(:input)

      RubyLLM.config.bedrock_region = 'us-east-1'

      expect([elsewhere, profile.price(:input)]).to eq([listed, 9])
    end

    it 'leaves a model with another id at its registry price' do
      RubyLLM.config.price 'claude-haiku-5-5', provider: :bedrock, input: 9

      expect(profile.price(:input)).to eq(profile.registry_pricing.text_tokens.input)
    end
  end

  it 'prices a model the registry does not list' do
    RubyLLM.config.price 'house-model', provider: :azure, input: 1

    expect(RubyLLM::Model.default('house-model', 'azure').price(:input)).to eq(1)
  end

  it 'follows a price set after the model was last read' do
    RubyLLM.config.price 'gpt-5.6-luna', provider: :azure, input: 0.24
    model.pricing

    RubyLLM.config.price 'gpt-5.6-luna', provider: :azure, input: 0.3

    expect(model.price(:input)).to eq(0.3)
  end

  it 'follows the prices of another global configuration' do
    RubyLLM.config.price 'gpt-5.6-luna', provider: :azure, input: 0.24
    model.pricing
    revision = RubyLLM.config.revision
    other = described_class.new
    (revision - other.revision - 1).times { other.request_timeout = 1 }
    other.price 'gpt-5.6-luna', provider: :azure, input: 0.3
    allow(RubyLLM).to receive(:config).and_return(other)

    expect(other.revision).to eq(revision)
    expect(model.price(:input)).to eq(0.3)
  end

  it 'builds the pricing of a model once per state of the configuration' do
    RubyLLM.config.price 'gpt-5.6-luna', provider: :azure, input: 0.24
    other = priced_model('gpt-5.6-terra')

    expect(model.pricing).to equal(model.pricing)
    expect(other.pricing).to equal(other.registry_pricing)
  end

  it 'reads the registry pricing as it is while no price is set' do
    allow(RubyLLM::Provider).to receive(:resolve).and_call_original

    expect(model.pricing).to equal(model.registry_pricing)
    expect(RubyLLM::Provider).not_to have_received(:resolve)
  end

  it 'keeps the registry prices in what a registry store writes' do
    RubyLLM.config.price 'gpt-5.6-luna', provider: :azure, input: 0.24

    expect(model.to_h.dig(:pricing, :text_tokens, :standard, :input_per_million)).to eq(0.2)
  end

  describe 'a thinking price' do
    def thinking_model(thinking)
      thinking_pricing = { text_tokens: { standard: standard.merge(reasoning_output_per_million: thinking) } }
      RubyLLM::Model.new(id: 'gpt-5.6-luna', name: 'Luna', provider: 'azure', pricing: thinking_pricing)
    end

    it 'follows a new output price when it was the output price' do
      RubyLLM.config.price 'gpt-5.6-luna', provider: :azure, output: 1.44

      expect(thinking_model(1.2).pricing.text_tokens.reasoning_output).to eq(1.44)
    end

    it 'stays when the model prices thinking apart' do
      RubyLLM.config.price 'gpt-5.6-luna', provider: :azure, output: 1.44

      expect(thinking_model(3).pricing.text_tokens.reasoning_output).to eq(3)
    end

    it 'stays when the output price does not change' do
      RubyLLM.config.price 'gpt-5.6-luna', provider: :azure, input: 0.24

      expect(thinking_model(1.2).pricing.text_tokens.reasoning_output).to eq(1.2)
    end

    it 'stays absent on a model without one' do
      RubyLLM.config.price 'gpt-5.6-luna', provider: :azure, output: 1.44

      expect(model.pricing.text_tokens.reasoning_output).to be_nil
    end
  end

  describe 'a deployment' do
    before { RubyLLM.config.azure_deployments = { 'invoice-reader' => 'gpt-5.6-luna' } }

    it 'costs what its model costs' do
      RubyLLM.config.price 'gpt-5.6-luna', provider: :azure, input: 0.24

      expect(priced_model('invoice-reader').price(:input)).to eq(0.24)
    end

    it 'takes prices of its own over the prices of its model' do
      RubyLLM.config.price 'gpt-5.6-luna', provider: :azure, input: 0.24, output: 1.44
      RubyLLM.config.price 'invoice-reader', provider: :azure, input: 0.3

      expect(%i[input output].map { |kind| priced_model('invoice-reader').price(kind) }).to eq([0.3, 1.44])
    end

    it 'costs what the model it deploys now costs' do
      RubyLLM.config.price 'gpt-5.6-luna', provider: :azure, input: 0.24
      deployment = priced_model('invoice-reader')
      deployment.pricing

      RubyLLM.config.price 'gpt-5.6-terra', provider: :azure, output: 1.5
      deployment.pricing
      RubyLLM.config.azure_deployments = { 'invoice-reader' => 'gpt-5.6-terra' }

      expect(%i[input output].map { |kind| deployment.price(kind) }).to eq([0.2, 1.5])
    end

    it 'costs what its model costs when a context declares it' do
      context = RubyLLM.context { |config| config.azure_deployments = { 'ledger-reader' => 'gpt-5.6-luna' } }
      listed = RubyLLM.models.find('gpt-5.6-luna', provider: :azure).price(:input)
      RubyLLM.config.price 'gpt-5.6-luna', provider: :azure, input: listed * 2

      deployment = RubyLLM.models.find('ledger-reader', provider: :azure, config: context.config)

      expect(deployment).to have_attributes(id: 'ledger-reader')
      expect(deployment.price(:input)).to eq(listed * 2)
    end
  end

  it 'raises on a price it does not know, and names the ones it does' do
    expect { RubyLLM.config.price 'gpt-5.6-luna', provider: :azure, inptu: 1, output: 2 }
      .to raise_error(ArgumentError, 'Unknown price: inptu. Valid prices: input, output, cache_read, ' \
                                     'cache_write, characters, audio_seconds, search_units')
  end

  it 'raises without a price' do
    expect { RubyLLM.config.price 'gpt-5.6-luna', provider: :azure }
      .to raise_error(ArgumentError, /\ANo price given\. Valid prices: input, /)
  end

  it 'raises on a price that is not a number, and sets nothing' do
    expect { RubyLLM.config.price 'gpt-5.6-luna', provider: :azure, input: 0.24, output: '1.44' }
      .to raise_error(ArgumentError, 'The output price must be a number, got "1.44"')
    expect(model.price(:input)).to eq(0.2)
  end

  it 'raises on a context, whose costs could not all follow it' do
    expect { RubyLLM.context { |config| config.price 'gpt-5.6-luna', provider: :azure, input: 0.24 } }
      .to raise_error(RubyLLM::ConfigurationError, /Set prices in RubyLLM\.configure/)
  end

  it 'reaches the costs of a context' do
    RubyLLM.config.price 'gpt-5.6-luna', provider: :azure, input: 0.24
    context = RubyLLM.context

    expect(context.config.prices).to equal(RubyLLM.config.prices)
    expect(model.price(:input)).to eq(0.24)
  end
end
