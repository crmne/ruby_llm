# frozen_string_literal: true

require 'spec_helper'
require 'timeout'

RSpec.describe RubyLLM::Models::Lookup do
  let(:original) { RubyLLM::Model.new(id: 'gpt-5-nano', provider: 'openai', name: 'Original') }
  let(:replacement) { RubyLLM::Model.new(id: original.id, provider: 'openai', name: 'Updated') }
  let(:retired) { RubyLLM::Model.new(id: 'gpt-4.1', provider: 'openai') }
  let(:registry) { RubyLLM::Models.new([original, retired]) }

  around do |example|
    store = RubyLLM.config.model_registry_store
    RubyLLM.config.model_registry_store = nil
    example.run
  ensure
    RubyLLM.config.model_registry_store = store
  end

  describe '#find' do
    let(:alias_models) do
      [
        RubyLLM::Model.new(id: 'claude-haiku-4-5', provider: 'anthropic'),
        RubyLLM::Model.new(id: 'claude-haiku-4-5-20251001', provider: 'anthropic')
      ]
    end

    it 'keeps exact matches first when provider preferences tie' do
      exact, aliased = alias_models
      models = RubyLLM::Models.new([aliased, exact])

      expect(models.find(exact.id)).to equal(exact)
    end

    it 'prefers the resolved alias when a provider is specified' do
      exact, aliased = alias_models
      models = RubyLLM::Models.new([exact, aliased])

      expect(models.find(exact.id, provider: :anthropic)).to equal(aliased)
    end

    it 'falls back to the exact id when the resolved alias belongs to another provider' do
      exact, aliased = alias_models
      other = RubyLLM::Model.new(id: aliased.id, provider: 'azure')
      models = RubyLLM::Models.new([other, exact])

      expect(models.find(exact.id, provider: :anthropic)).to equal(exact)
    end

    it 'prefers a first-party alias over another provider with the exact id' do
      exact, aliased = alias_models
      other = RubyLLM::Model.new(id: exact.id, provider: 'vertexai')
      models = RubyLLM::Models.new([other, aliased])

      expect(models.find(exact.id)).to equal(aliased)
      expect(models.find(exact.id, provider: :vertexai)).to equal(other)
    end

    it 'ignores providers the alias does not name when resolving a bare name' do
      first_party = RubyLLM::Model.new(id: 'grok-4.3', provider: 'xai')
      aliased = RubyLLM::Model.new(id: 'xai/grok-4.3', provider: 'vertexai')
      unrelated = RubyLLM::Model.new(id: aliased.id, provider: 'perplexity')
      allow(RubyLLM::Models::Aliases).to receive(:aliases)
        .and_return(first_party.id => { 'vertexai' => aliased.id })

      expect(RubyLLM::Models.new([unrelated, aliased, first_party]).find(first_party.id)).to equal(first_party)
      expect(RubyLLM::Models.new([unrelated, aliased]).find(first_party.id)).to equal(aliased)
    end

    it 'preserves catalog order for duplicate ids from the same provider' do
      models = RubyLLM::Models.new([original, replacement])

      expect(models.find(original.id)).to equal(original)
      expect(models.find(original.id, provider: :openai)).to equal(original)
    end
  end

  describe '#load_from_json' do
    it 'replaces previously found entries and removes entries absent from the file' do
      expect(registry.find(original.id)).to equal(original)
      expect(registry.find(retired.id)).to equal(retired)

      Tempfile.create(['models', '.json']) do |file|
        file.write(RubyLLM::Models::Registry.pretty_json([replacement]))
        file.flush

        expect(registry.load_from_json(file.path)).to equal(registry)
      end

      expect(registry.find(original.id).name).to eq('Updated')
      expect(registry.find(original.id, provider: :openai).name).to eq('Updated')
      expect { registry.find(retired.id) }.to raise_error(RubyLLM::ModelNotFoundError)
    end
  end

  describe '#load_from_store' do
    it 'invalidates previous lookups when a store reuses its array' do
      stored = [original, retired]
      RubyLLM.config.model_registry_store = instance_double(RubyLLM::Models::Registry::FileStore, read: stored)
      registry.load_from_store
      expect(registry.find(original.id)).to equal(original)

      stored.replace([replacement])
      expect(registry.load_from_store).to equal(registry)
      expect(registry.find(original.id)).to equal(replacement)
      expect { registry.find(retired.id, provider: :openai) }.to raise_error(RubyLLM::ModelNotFoundError)
    end

    it 'does not reuse an index built before a concurrent reload' do
      started = Queue.new
      resume = Queue.new
      model_id = original.id
      RubyLLM.config.model_registry_store = instance_double(RubyLLM::Models::Registry::FileStore, read: [replacement])
      allow(original).to receive(:id) do
        started << true
        resume.pop
        model_id
      end

      lookup = Thread.new { registry.find(model_id) }
      Timeout.timeout(5) { started.pop }
      registry.load_from_store
      expect(registry.find(model_id)).to equal(replacement)
      resume.close
      Timeout.timeout(5) { lookup.join }

      expect(lookup.value).to equal(original)
      expect(registry.find(model_id)).to equal(replacement)
    ensure
      lookup&.kill
      lookup&.join
    end
  end

  describe '#refresh' do
    before do
      allow(RubyLLM::Models).to receive_messages(
        fetch_published_registry: RubyLLM::Models::Registry::PublishedSource::Result.new([replacement], nil, false),
        fetch_provider_models: { models: [], fetched_providers: [], configured_names: [], failed: [] },
        models_from_provider_gems: []
      )
    end

    it 'finds refreshed entries and unlisted entries retained by the store' do
      unlisted = RubyLLM::Model.new(id: retired.id, provider: 'openai', unlisted_at: Time.now.utc)
      RubyLLM.config.model_registry_store = instance_double(RubyLLM::Models::Registry::FileStore,
                                                            read: [replacement, unlisted], write: nil)
      expect(registry.find(original.id)).to equal(original)
      expect(registry.find(retired.id)).to equal(retired)

      expect(registry.refresh).to equal(registry)

      expect(registry.find(original.id)).to equal(replacement)
      expect(registry.find(retired.id, provider: :openai)).to equal(unlisted)
      expect(registry.all).to eq([replacement])
    end
  end

  describe '#refresh_from_providers' do
    it 'replaces previous lookup results with the new provider catalog' do
      expect(registry.find(original.id)).to equal(original)
      allow(RubyLLM::Models).to receive(:fetch_merged_models).with(remote_only: true).and_return([replacement])

      expect(registry.refresh_from_providers(remote_only: true)).to equal(registry)

      expect(registry.find(original.id, provider: :openai)).to equal(replacement)
      expect { registry.find(retired.id) }.to raise_error(RubyLLM::ModelNotFoundError)
    end
  end

  describe '#find_configured' do
    let(:config) { RubyLLM::Configuration.new.tap { |config| config.openrouter_api_key = 'test' } }

    def aggregated = @aggregated ||= RubyLLM::Model.new(id: 'openai/gpt-5-nano', provider: 'openrouter')
    def first_party = @first_party ||= RubyLLM::Model.new(id: aggregated.id, provider: 'perplexity')
    def models = RubyLLM::Models.new([aggregated, first_party])

    it 'prefers a configured provider over a more preferred unconfigured one' do
      expect(models.find_configured(aggregated.id, config:)).to equal(aggregated)
      expect(models.find(aggregated.id, config:)).to equal(first_party)
    end

    it 'keeps provider preference among configured providers' do
      config.perplexity_api_key = 'test'

      expect(models.find_configured(aggregated.id, config:)).to equal(first_party)
    end

    it 'falls back to the preferred provider when no configured provider carries the model' do
      expect(models.find_configured(aggregated.id, config: RubyLLM::Configuration.new)).to equal(first_party)
    end

    it 'counts a local provider as configured once its endpoint is set' do
      local = RubyLLM::Model.new(id: 'gpt-oss:20b', provider: 'ollama')
      hosted = RubyLLM::Model.new(id: local.id, provider: 'ollama_cloud')
      registry = RubyLLM::Models.new([local, hosted])

      expect(registry.find_configured(local.id, config:)).to equal(hosted)

      config.ollama_api_base = 'http://localhost:11434/v1'
      expect(registry.find_configured(local.id, config:)).to equal(local)
    end

    it "uses a configured provider's own alias target" do
      aliased = RubyLLM::Model.new(id: 'anthropic/claude-haiku-4.5', provider: 'openrouter')
      first_party = RubyLLM::Model.new(id: 'claude-haiku-4-5-20251001', provider: 'anthropic')
      allow(RubyLLM::Models::Aliases).to receive(:aliases).and_return(
        'claude-haiku-4-5' => { 'anthropic' => first_party.id, 'openrouter' => aliased.id }
      )
      registry = RubyLLM::Models.new([first_party, aliased])

      expect(registry.find_configured('claude-haiku-4-5', config:)).to equal(aliased)
      expect(registry.find('claude-haiku-4-5')).to equal(first_party)
    end

    it 'scopes to the named provider' do
      expect(models.find_configured(aggregated.id, provider: :perplexity, config:)).to equal(first_party)
    end
  end
end
