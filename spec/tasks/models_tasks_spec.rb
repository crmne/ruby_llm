# frozen_string_literal: true

require 'spec_helper'
require 'rake'
require 'tmpdir'

load File.expand_path('../../tasks/models.rake', __dir__)

RSpec.describe 'models:update', type: :task do
  let(:tmpdir) { Dir.mktmpdir }
  let(:registry_file) { File.join(tmpdir, 'models.json') }
  let(:existing_models) do
    %w[gpt-5-nano gpt-5-mini gpt-4.1 gpt-4.1-mini gpt-4.1-nano gpt-4o].map do |id|
      RubyLLM.models.find(id, provider: :openai)
    end
  end

  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('ALLOW_MODEL_REGISTRY_DROP').and_return(nil)
    RubyLLM::Models.new(existing_models).save_to_json(registry_file)
  end

  after do
    FileUtils.rm_rf(tmpdir)
  end

  def persist(models)
    persist_refreshed_models(existing_models, RubyLLM::Models.new(models), registry_file)
  end

  def saved_models
    RubyLLM::ModelRegistry.read(registry_file)
  end

  it 'reports and saves routine model removals without an override' do
    expect { persist(existing_models.drop(1)) }.not_to raise_error

    expect(saved_models.map(&:id)).to eq(existing_models.drop(1).map(&:id))
  end

  it 'reports and saves metadata removed by upstream sources' do
    current = RubyLLM::Model.new(existing_models.first.to_h.merge(pricing: {}, context_window: nil, capabilities: []))

    expect { persist([current, *existing_models.drop(1)]) }.not_to raise_error

    expect(saved_models.first.pricing.to_h).to eq(current.pricing.to_h)
    expect(saved_models.first.context_window).to be_nil
    expect(saved_models.first.capabilities).to be_empty
  end

  it 'keeps the file unchanged when the registry loses more than twenty percent of its models' do
    original = File.binread(registry_file)

    expect { persist(existing_models.first(4)) }.to raise_error(SystemExit, /registry: 6 models -> 4/)

    expect(File.binread(registry_file)).to eq(original)
  end

  it 'rejects a provider disappearing even when the total count barely changes' do
    existing_models << RubyLLM.models.find('claude-haiku-4-5', provider: :anthropic)
    RubyLLM::Models.new(existing_models).save_to_json(registry_file)
    original = File.binread(registry_file)

    expect { persist(existing_models.reject { |model| model.provider == 'anthropic' }) }
      .to raise_error(SystemExit, /anthropic: 1 models -> 0/)

    expect(File.binread(registry_file)).to eq(original)
  end

  it 'rejects a partial provider collapse hidden by another provider growing' do
    current = existing_models.first(4) + RubyLLM.models.by_provider(:anthropic).first(8)
    original = File.binread(registry_file)

    expect { persist(current) }.to raise_error(SystemExit, /openai: 6 models -> 4/)

    expect(File.binread(registry_file)).to eq(original)
  end

  it 'allows reviewed large drops through the explicit override' do
    allow(ENV).to receive(:[]).with('ALLOW_MODEL_REGISTRY_DROP').and_return('true')

    expect { persist(existing_models.first(1)) }.not_to raise_error

    expect(saved_models.map(&:id)).to eq(existing_models.first(1).map(&:id))
  end

  it 'allows a reviewed provider removal through the same override' do
    allow(ENV).to receive(:[]).with('ALLOW_MODEL_REGISTRY_DROP').and_return('true')
    current = RubyLLM.models.by_provider(:anthropic).first(8)

    expect { persist(current) }.not_to raise_error

    expect(saved_models.map(&:provider).uniq).to eq(['anthropic'])
  end

  it 'keeps the file unchanged when new model data fails schema validation' do
    allow(ENV).to receive(:[]).with('ALLOW_MODEL_REGISTRY_DROP').and_return('true')
    current = RubyLLM::Model.new(existing_models.first.to_h.merge(context_window: -1))
    original = File.binread(registry_file)
    failed_path = File.join(tmpdir, 'models.failed.json')
    allow(File).to receive(:expand_path).and_call_original
    allow(File).to receive(:expand_path).with('../tmp/models.failed.json', anything).and_return(failed_path)

    expect { persist([current, *existing_models.drop(1)]) }.to raise_error(SystemExit)

    expect(File.binread(registry_file)).to eq(original)
    expect(File).to exist(failed_path)
  end

  it 'rejects an empty registry even with the count drop override' do
    allow(ENV).to receive(:[]).with('ALLOW_MODEL_REGISTRY_DROP').and_return('true')
    original = File.binread(registry_file)

    expect { persist([]) }.to raise_error(SystemExit, /empty model registry/)

    expect(File.binread(registry_file)).to eq(original)
  end

  it 'accepts a drop of exactly twenty percent' do
    existing_models.pop

    expect { persist(existing_models.drop(1)) }.not_to raise_error

    expect(saved_models.map(&:id)).to eq(existing_models.drop(1).map(&:id))
  end

  it 'does not rewrite the registry when only upstream ordering changes' do
    expect { persist(existing_models.reverse) }.to output(/Model list unchanged/).to_stdout

    expect(saved_models.map(&:id)).to eq(existing_models.map(&:id))
  end
end
