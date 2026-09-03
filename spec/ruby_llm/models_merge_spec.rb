# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Models do
  include_context 'with configured RubyLLM'

  after do
    described_class.instance_variable_set(:@instance, nil)
  end

  # Registry storage is global configuration; start each example from a known
  # state and hand back whatever the suite had configured.
  around do |example|
    store = RubyLLM.config.model_registry_store
    file = RubyLLM.config.model_registry_file
    RubyLLM.config.model_registry_store = nil
    example.run
  ensure
    RubyLLM.config.model_registry_store = store
    RubyLLM.config.model_registry_file = file
  end

  def model(id:, provider:, **attributes)
    RubyLLM::Model.new(id: id, provider: provider, **attributes)
  end

  def fake_provider(slug:, display_name:, models: [], error: nil)
    Class.new do
      define_singleton_method(:slug) { slug }
      define_singleton_method(:display_name) { display_name }
      define_method(:initialize) { |config| @config = config }
      define_method(:list_models) { error ? raise(error) : models }
    end
  end

  describe '.fetch_provider_models' do
    it 'collects models from every configured provider' do
      provider = fake_provider(
        slug: 'acme', display_name: 'Acme', models: [model(id: 'acme-1', provider: 'acme')]
      )
      allow(RubyLLM::Provider).to receive(:configured_remote_providers).and_return([provider])

      result = described_class.fetch_provider_models

      expect(result[:models].map(&:id)).to eq(['acme-1'])
      expect(result[:fetched_providers]).to eq(['acme'])
      expect(result[:configured_names]).to eq(['Acme'])
      expect(result[:failed]).to be_empty
      expect(result[:empty]).to be_empty
    end

    it 'treats a provider that lists nothing as one that did not answer' do
      silent = fake_provider(slug: 'acme', display_name: 'Acme', models: [])
      allow(RubyLLM::Provider).to receive(:configured_remote_providers).and_return([silent])

      result = described_class.fetch_provider_models

      expect(result[:fetched_providers]).to be_empty
      expect(result[:failed]).to be_empty
      expect(result[:empty]).to eq([{ name: 'Acme', slug: 'acme' }])
    end

    it 'records a provider that fails instead of aborting the refresh' do
      failing = fake_provider(slug: 'acme', display_name: 'Acme', error: ArgumentError.new('boom'))
      working = fake_provider(
        slug: 'other', display_name: 'Other', models: [model(id: 'other-1', provider: 'other')]
      )
      allow(RubyLLM::Provider).to receive(:configured_providers).and_return([failing, working])

      result = described_class.fetch_provider_models(remote_only: false)

      expect(result[:models].map(&:id)).to eq(['other-1'])
      expect(result[:fetched_providers]).to eq(['other'])
      expect(result[:failed].first).to include(name: 'Acme', slug: 'acme')
      expect(result[:failed].first[:error]).to be_a(ArgumentError)
    end

    it 'leaves provider gem catalogs to their own rake task' do
      provider = fake_provider(slug: 'openai', display_name: 'OpenAI')
      allow(RubyLLM::Provider).to receive_messages(
        configured_remote_providers: [provider],
        model_registry_files: { openai: '/tmp/openai-models.json' }
      )

      result = described_class.fetch_provider_models

      expect(result).to include(models: [], configured_names: [], fetched_providers: [])
    end
  end

  describe '.log_provider_fetch' do
    it 'warns once per failed provider' do
      allow(RubyLLM.logger).to receive(:info)
      allow(RubyLLM.logger).to receive(:warn)

      described_class.log_provider_fetch(
        configured_names: ['Acme'],
        failed: [{ name: 'Acme', slug: 'acme', error: ArgumentError.new('boom') }]
      )

      expect(RubyLLM.logger).to have_received(:info).with('Fetching models from providers: Acme')
      expect(RubyLLM.logger).to have_received(:warn).with(/Failed to fetch Acme models \(ArgumentError: boom\)/)
    end

    it 'warns about a provider that listed nothing' do
      allow(RubyLLM.logger).to receive(:info)
      allow(RubyLLM.logger).to receive(:warn)

      described_class.log_provider_fetch(
        configured_names: ['Acme'], failed: [], empty: [{ name: 'Acme', slug: 'acme' }]
      )

      expect(RubyLLM.logger).to have_received(:warn).with('Acme listed no models. Keeping existing.')
    end
  end

  describe '.log_models_dev_fetch' do
    it 'stays quiet on a successful fetch' do
      allow(RubyLLM.logger).to receive(:warn)

      described_class.log_models_dev_fetch(fetched: true)

      expect(RubyLLM.logger).not_to have_received(:warn)
    end

    it 'warns when falling back to cached data' do
      allow(RubyLLM.logger).to receive(:warn)

      described_class.log_models_dev_fetch(fetched: false)

      expect(RubyLLM.logger).to have_received(:warn).with('Using cached models.dev data due to fetch failure.')
    end
  end

  describe '.fetch_models_dev_models' do
    let(:payload) do
      {
        openai: {
          models: {
            'gpt-test': {
              id: 'gpt-test',
              name: 'GPT Test',
              tool_call: true,
              modalities: { input: %w[text video unknown], output: %w[text bogus] },
              cost: { input: 1.0, output: 2.0, input_audio: 3.0, output_audio: 4.0 }
            }
          }
        },
        'google-vertex': {
          models: {
            'claude-haiku': { id: 'claude-haiku-4-5@20251001', name: 'Claude Haiku' }
          }
        },
        'perplexity-agent': {
          models: {
            'third-party': { id: 'anthropic/claude-test', name: 'Claude Test' }
          }
        },
        unknownprovider: { models: { x: { id: 'x' } } }
      }
    end

    it 'maps the models.dev catalog onto Model instances' do
      stub_request(:get, 'https://models.dev/api.json')
        .to_return(status: 200, body: payload.to_json, headers: { 'Content-Type' => 'application/json' })

      result = described_class.fetch_models_dev_models([])

      expect(result[:fetched]).to be(true)
      expect(result[:models].map { |m| [m.provider, m.id] }).to contain_exactly(
        %w[openai gpt-test], %w[vertexai claude-haiku-4-5], %w[perplexity anthropic/claude-test]
      )

      openai_model = result[:models].find { |m| m.provider == 'openai' }
      expect(openai_model.modalities.input).to eq(%w[text video])
      expect(openai_model.modalities.output).to eq(['text'])
      expect(openai_model.capabilities).to contain_exactly(
        'function_calling', 'tool_choice', 'parallel_tool_calls', 'vision', 'video'
      )
      expect(openai_model.pricing.to_h).to eq(
        text_tokens: { standard: { input_per_million: 1.0, output_per_million: 2.0 } },
        audio_tokens: { standard: { input_per_million: 3.0, output_per_million: 4.0 } }
      )
    end

    it 'keeps the models.dev entries it already had when the answer carries no models' do
      allow(RubyLLM.logger).to receive(:warn)
      cached = model(id: 'cached', provider: 'openai', metadata: { source: 'models.dev' })

      [{}, nil, { 'openai-inc': { models: { a: { id: 'a' } } } }].each do |body|
        stub_request(:get, 'https://models.dev/api.json')
          .to_return(status: 200, body: body.to_json, headers: { 'Content-Type' => 'application/json' })

        result = described_class.fetch_models_dev_models([cached])

        expect(result[:fetched]).to be(false)
        expect(result[:models]).to eq([cached])
      end

      expect(RubyLLM.logger).to have_received(:warn).with(/models\.dev returned/).exactly(3).times
    end

    it 'keeps the models.dev entries it already had when the fetch fails' do
      failing = instance_double(Faraday::Connection)
      allow(failing).to receive(:get).and_raise(Faraday::ConnectionFailed, 'no route to host')
      allow(RubyLLM::Connection).to receive(:basic).and_return(failing)
      allow(RubyLLM.logger).to receive(:warn)

      cached = model(id: 'cached', provider: 'openai', metadata: { source: 'models.dev' })
      provider_owned = model(id: 'live', provider: 'openai', metadata: { source: 'openai' })

      result = described_class.fetch_models_dev_models([cached, provider_owned])

      expect(result[:fetched]).to be(false)
      expect(result[:models]).to eq([cached])
      expect(RubyLLM.logger).to have_received(:warn).with(/Failed to fetch models\.dev/)
    end
  end

  describe '.models_dev_pricing' do
    it 'returns nothing when models.dev reports no cost' do
      expect(described_class.models_dev_pricing(nil)).to eq({})
    end
  end

  describe '.normalize_models_dev_modalities' do
    it 'returns empty lists when models.dev omits modalities' do
      expect(described_class.normalize_models_dev_modalities(nil)).to eq(input: [], output: [])
    end
  end

  describe '.normalize_models_dev_knowledge' do
    it 'passes a Date through untouched' do
      date = Date.new(2025, 1, 1)

      expect(described_class.normalize_models_dev_knowledge(date)).to equal(date)
    end

    it 'parses a string cutoff' do
      expect(described_class.normalize_models_dev_knowledge('2025-01-01')).to eq(Date.new(2025, 1, 1))
    end

    it 'ignores an unparseable cutoff' do
      expect(described_class.normalize_models_dev_knowledge('not a date')).to be_nil
      expect(described_class.normalize_models_dev_knowledge(nil)).to be_nil
    end
  end

  describe '.models_dev_model_id' do
    it 'strips the version pin only for Vertex AI' do
      expect(described_class.models_dev_model_id('claude-haiku-4-5@20251001', 'vertexai')).to eq('claude-haiku-4-5')
      expect(described_class.models_dev_model_id('claude-haiku-4-5@20251001', 'anthropic')).to eq(
        'claude-haiku-4-5@20251001'
      )
    end
  end

  describe '.blank_value?' do
    it 'treats nil, empty collections and all-blank hashes as blank' do
      expect(described_class.blank_value?(nil)).to be(true)
      expect(described_class.blank_value?('')).to be(true)
      expect(described_class.blank_value?([])).to be(true)
      expect(described_class.blank_value?({})).to be(true)
      expect(described_class.blank_value?({ input: [], output: nil })).to be(true)
    end

    it 'treats anything with content as present' do
      expect(described_class.blank_value?('gpt')).to be(false)
      expect(described_class.blank_value?(['text'])).to be(false)
      expect(described_class.blank_value?({ input: ['text'] })).to be(false)
      expect(described_class.blank_value?(0)).to be(false)
    end
  end

  describe '.add_provider_metadata' do
    it 'fills every blank models.dev field from the provider entry' do
      models_dev_model = model(id: 'test', provider: 'openai', metadata: { source: 'models.dev' })
      provider_model = model(
        id: 'test',
        provider: 'openai',
        name: 'Test',
        family: 'test-family',
        created_at: '2025-01-01 00:00:00 UTC',
        context_window: 1000,
        max_output_tokens: 100,
        knowledge_cutoff: '2024-10-01',
        modalities: { input: ['text'], output: ['text'] },
        pricing: { text_tokens: { standard: { input_per_million: 1.0 } } },
        capabilities: %w[streaming vision],
        metadata: { provider_note: 'kept' }
      )

      merged = described_class.add_provider_metadata(models_dev_model, provider_model)

      expect(merged.name).to eq('Test')
      expect(merged.family).to eq('test-family')
      expect(merged.created_at).to eq(Time.parse('2025-01-01 00:00:00 UTC'))
      expect(merged.context_window).to eq(1000)
      expect(merged.max_output_tokens).to eq(100)
      expect(merged.knowledge_cutoff).to eq(Date.new(2024, 10, 1))
      expect(merged.modalities.input).to eq(['text'])
      expect(merged.pricing.to_h).to eq(text_tokens: { standard: { input_per_million: 1.0 } })
      expect(merged.metadata).to include(source: 'models.dev', provider_note: 'kept')
      expect(merged.capabilities).to contain_exactly('streaming', 'vision')
    end

    it 'keeps the models.dev values it does have' do
      models_dev_model = model(
        id: 'test', provider: 'openai', knowledge_cutoff: '2025-06-01', metadata: { source: 'models.dev' }
      )
      provider_model = model(id: 'test', provider: 'openai', knowledge_cutoff: '2024-10-01')

      merged = described_class.add_provider_metadata(models_dev_model, provider_model)

      expect(merged.knowledge_cutoff).to eq(Date.new(2025, 6, 1))
    end

    it 'fills missing pricing rates without replacing models.dev rates' do
      models_dev_model = model(
        id: 'test', provider: 'perplexity',
        pricing: { text_tokens: { standard: { input_per_million: 1.0 } } }
      )
      provider_model = model(
        id: 'test', provider: 'perplexity',
        pricing: {
          text_tokens: {
            standard: { input_per_million: 2.0, output_per_million: 3.0, cache_write_input_per_million: 0.5 }
          }
        }
      )

      merged = described_class.add_provider_metadata(models_dev_model, provider_model)

      expect(merged.pricing.to_h.dig(:text_tokens, :standard)).to eq(
        input_per_million: 1.0, output_per_million: 3.0, cache_write_input_per_million: 0.5
      )
    end

    it 'keeps a provider capability models.dev does not report on' do
      models_dev_model = model(
        id: 'test', provider: 'openai', capabilities: ['function_calling'],
        modalities: { input: ['text'], output: ['text'] },
        metadata: { source: 'models.dev', tool_call: true }
      )
      provider_model = model(id: 'test', provider: 'openai', capabilities: %w[function_calling structured_output])

      merged = described_class.add_provider_metadata(models_dev_model, provider_model)

      expect(merged.capabilities).to contain_exactly(
        'function_calling', 'tool_choice', 'parallel_tool_calls', 'structured_output'
      )
    end

    it 'drops a provider capability models.dev reports as absent' do
      models_dev_model = model(
        id: 'test', provider: 'openai', capabilities: [],
        modalities: { input: ['text'], output: ['text'] },
        metadata: { source: 'models.dev', tool_call: false, structured_output: false, reasoning: false }
      )
      provider_model = model(
        id: 'test', provider: 'openai',
        capabilities: %w[streaming function_calling structured_output reasoning vision]
      )

      merged = described_class.add_provider_metadata(models_dev_model, provider_model)

      expect(merged.capabilities).to eq(['streaming'])
    end

    it 'normalizes embedding modalities on the merged entry' do
      models_dev_model = model(id: 'text-embedding-3-small', provider: 'openai')
      provider_model = model(id: 'text-embedding-3-small', provider: 'openai')

      merged = described_class.add_provider_metadata(models_dev_model, provider_model)

      expect(merged.modalities.input).to eq(['text'])
      expect(merged.modalities.output).to eq(['embeddings'])
    end

    it 'prefers a provider-reported non-chat operation over a models.dev chat classification' do
      models_dev_model = model(
        id: 'mistral-embed', provider: 'mistral', modalities: { input: ['text'], output: ['text'] }
      )
      provider_model = model(
        id: 'mistral-embed', provider: 'mistral', modalities: { input: ['text'], output: ['embeddings'] }
      )

      merged = described_class.add_provider_metadata(models_dev_model, provider_model)

      expect(merged.type).to eq(:embedding)
      expect(merged.modalities.output).to eq(['embeddings'])
    end
  end

  describe '.find_models_dev_model' do
    it 'prefers a direct hit' do
      entry = model(id: 'gpt-5', provider: 'openai')

      expect(described_class.find_models_dev_model('openai:gpt-5', { 'openai:gpt-5' => entry })).to equal(entry)
    end

    it 'matches a region-prefixed Bedrock id against the bare models.dev entry' do
      entry = model(id: 'anthropic.claude-haiku-4-5', provider: 'bedrock', context_window: 200_000)

      found = described_class.find_models_dev_model(
        'bedrock:us.anthropic.claude-haiku-4-5', { 'bedrock:anthropic.claude-haiku-4-5' => entry }
      )

      expect(found.id).to eq('us.anthropic.claude-haiku-4-5')
      expect(found.context_window).to eq(200_000)
    end

    it 'reads the context window out of a Bedrock id suffix' do
      entry = model(id: 'anthropic.claude-v2', provider: 'bedrock', context_window: 100_000)

      found = described_class.find_models_dev_model(
        'bedrock:anthropic.claude-v2:18k', { 'bedrock:anthropic.claude-v2' => entry }
      )

      expect(found.id).to eq('anthropic.claude-v2:18k')
      expect(found.context_window).to eq(18_000)
    end

    it 'returns nothing for a Bedrock id models.dev does not know' do
      expect(described_class.find_models_dev_model('bedrock:acme.model', {})).to be_nil
    end

    it 'reuses an exact OpenAI base entry for its release-dated snapshot' do
      entry = model(
        id: 'gpt-5.4-mini', provider: 'openai', created_at: '2026-03-17 00:00:00 UTC', context_window: 400_000
      )

      found = described_class.find_models_dev_model(
        'openai:gpt-5.4-mini-2026-03-17', { 'openai:gpt-5.4-mini' => entry }
      )

      expect(found.id).to eq('gpt-5.4-mini-2026-03-17')
      expect(found.context_window).to eq(400_000)
    end

    it 'maps OpenAI snapshots whose public release date differs from their base entry' do
      entry = model(id: 'o1', provider: 'openai', context_window: 200_000)

      found = described_class.find_models_dev_model(
        'openai:o1-2024-12-17', { 'openai:o1' => entry }
      )

      expect(found.id).to eq('o1-2024-12-17')
      expect(found.context_window).to eq(200_000)
    end

    it 'does not inherit OpenAI metadata when the release date differs' do
      entry = model(
        id: 'gpt-4o', provider: 'openai', created_at: '2024-05-13 00:00:00 UTC', context_window: 128_000
      )

      found = described_class.find_models_dev_model(
        'openai:gpt-4o-2024-08-06', { 'openai:gpt-4o' => entry }
      )

      expect(found).to be_nil
    end

    it 'uses aliases reported by Mistral to find a models.dev entry' do
      entry = model(id: 'mistral-embed', provider: 'mistral', context_window: 8_000)
      provider_model = model(
        id: 'mistral-embed-2312', provider: 'mistral', metadata: { aliases: ['mistral-embed'] }
      )

      found = described_class.find_models_dev_model(
        'mistral:mistral-embed-2312', { 'mistral:mistral-embed' => entry }, provider_model
      )

      expect(found.id).to eq('mistral-embed-2312')
      expect(found.context_window).to eq(8_000)
    end

    it 'reuses the Gemini entry for Vertex AI' do
      entry = model(id: 'gemini-2.5-flash', provider: 'gemini', context_window: 1_000_000)

      found = described_class.find_models_dev_model(
        'vertexai:gemini-2.5-flash', { 'gemini:gemini-2.5-flash' => entry }
      )

      expect(found.provider).to eq('vertexai')
      expect(found.context_window).to eq(1_000_000)
    end

    it 'returns nothing when neither provider has the model' do
      expect(described_class.find_models_dev_model('vertexai:missing', {})).to be_nil
      expect(described_class.find_models_dev_model('openai:missing', {})).to be_nil
    end
  end

  describe '.merge_models' do
    it 'merges by provider and id, sorting the result' do
      provider_models = [
        model(id: 'shared', provider: 'openai', name: 'Provider Name'),
        model(id: 'provider-only', provider: 'openai')
      ]
      models_dev_models = [
        model(id: 'shared', provider: 'openai', metadata: { source: 'models.dev' }),
        model(id: 'dev-only', provider: 'anthropic', metadata: { source: 'models.dev' })
      ]

      merged = described_class.merge_models(provider_models, models_dev_models)

      expect(merged.map { |m| [m.provider, m.id] }).to eq(
        [%w[anthropic dev-only], %w[openai provider-only], %w[openai shared]]
      )
      expect(merged.find { |m| m.id == 'shared' }.name).to eq('Provider Name')
    end
  end

  describe '.merge_with_existing' do
    it 'keeps models from providers that were not refreshed' do
      existing = [
        model(id: 'kept', provider: 'anthropic'),
        model(id: 'replaced', provider: 'openai')
      ]
      provider_fetch = { models: [model(id: 'fresh', provider: 'openai')], fetched_providers: ['openai'] }

      merged = described_class.merge_with_existing(existing, provider_fetch, { models: [], fetched: true })

      expect(merged.map(&:id)).to contain_exactly('kept', 'fresh')
    end

    it 'falls back to the existing models.dev entries when the fetch failed' do
      cached = model(id: 'cached', provider: 'openai', metadata: { source: 'models.dev' })
      provider_fetch = { models: [], fetched_providers: [] }

      merged = described_class.merge_with_existing([cached], provider_fetch, { models: [], fetched: false })

      expect(merged.map(&:id)).to eq(['cached'])
    end

    it 'keeps the models of a provider that listed nothing' do
      existing = [model(id: 'kept', provider: 'deepgram')]
      silent = fake_provider(slug: 'deepgram', display_name: 'Deepgram', models: [])
      allow(RubyLLM::Provider).to receive(:configured_remote_providers).and_return([silent])

      provider_fetch = described_class.fetch_provider_models
      merged = described_class.merge_with_existing(existing, provider_fetch, { models: [], fetched: true })

      expect(merged.map(&:id)).to eq(['kept'])
    end
  end

  describe '.read_existing_models' do
    it 'uses the loaded registry when the instance is empty' do
      described_class.instance_variable_set(:@instance, described_class.new([]))

      expect(described_class.read_existing_models).not_to be_empty
    end

    it 'uses the instance when it already has models' do
      described_class.instance_variable_set(:@instance, described_class.new([model(id: 'a', provider: 'openai')]))

      expect(described_class.read_existing_models.map(&:id)).to eq(['a'])
    end
  end

  describe '.fetch_merged_models' do
    it 'combines provider and models.dev fetches into one catalog' do
      allow(described_class).to receive_messages(
        read_existing_models: [],
        fetch_provider_models: {
          models: [model(id: 'acme-1', provider: 'acme', name: 'Acme One')],
          fetched_providers: ['acme'],
          configured_names: ['Acme'],
          failed: []
        },
        fetch_models_dev_models: {
          models: [model(id: 'acme-1', provider: 'acme', metadata: { source: 'models.dev' })],
          fetched: true
        }
      )
      allow(RubyLLM.logger).to receive(:info)

      merged = described_class.fetch_merged_models

      expect(merged.map(&:id)).to eq(['acme-1'])
      expect(merged.first.name).to eq('Acme One')
    end
  end

  describe '#refresh_from_providers' do
    it 'replaces the registry with the merged provider catalog' do
      replacement = [model(id: 'only', provider: 'openai')]
      allow(described_class).to receive(:fetch_merged_models).and_return(replacement)

      registry = described_class.new([])

      expect(registry.refresh_from_providers.all).to eq(replacement)
    end
  end

  describe '.models_from_store' do
    it 'ignores an empty store' do
      store = Class.new { def read = [] }.new
      allow(RubyLLM.logger).to receive(:debug)

      expect(described_class.models_from_store(store)).to be_nil
    end

    it 'returns nothing when no store is configured' do
      expect(described_class.models_from_store(nil)).to be_nil
    end
  end

  describe '.models_from_provider_gems' do
    it 'loads only the registered provider models from each catalog' do
      catalog = Tempfile.new(['provider-models', '.json'])
      models = [
        model(id: 'gpt-4.1-mini', provider: 'openai'),
        model(id: 'claude-haiku-4-5', provider: 'anthropic')
      ]
      catalog.write(RubyLLM::ModelRegistry.pretty_json(models))
      catalog.close
      allow(RubyLLM::Provider).to receive(:model_registry_files).and_return(openai: catalog.path)

      expect(described_class.models_from_provider_gems.map(&:id)).to eq(['gpt-4.1-mini'])
    ensure
      catalog&.unlink
    end

    it 'merges provider gem catalogs into the configured registry' do
      bundled = model(id: 'gpt-4.1-mini', provider: 'openai', name: 'Main catalog')
      provider_models = [
        model(id: 'gpt-4.1-mini', provider: 'openai', name: 'Provider catalog'),
        model(id: 'gpt-4.1', provider: 'openai')
      ]
      allow(described_class).to receive_messages(
        models_from_store: nil,
        models_from_file: nil,
        models_from_bundle: [bundled],
        models_from_provider_gems: provider_models
      )

      loaded = described_class.load_models

      expect(loaded.map(&:id)).to contain_exactly('gpt-4.1', 'gpt-4.1-mini')
      expect(loaded.find { |model| model.id == 'gpt-4.1-mini' }.name).to eq('Main catalog')
    end
  end

  describe '#load_from_store' do
    it 'raises when no store is configured' do
      expect { described_class.new([]).load_from_store }.to raise_error(
        RubyLLM::ModelRegistryError, 'No model registry store is configured'
      )
    end

    it 'replaces the registry with the store contents' do
      stored = [model(id: 'stored', provider: 'openai')]
      RubyLLM.config.model_registry_store = Class.new do
        define_method(:read) { stored }
      end.new

      expect(described_class.new([]).load_from_store.all).to eq(stored)
    end
  end

  describe '#persist_registry!' do
    let(:registry) { described_class.new([]) }
    let(:published) { RubyLLM::ModelRegistry::PublishedSource::Result.new([], nil, false) }

    it 'writes through a store that supports it' do
      writes = []
      RubyLLM.config.model_registry_store = Class.new do
        define_method(:write) { |models| writes << models }
      end.new

      registry.send(:persist_registry!, [model(id: 'a', provider: 'openai')], published:)

      expect(writes.first).to be_a(described_class)
    end

    it 'rejects a read-only store' do
      RubyLLM.config.model_registry_store = Object.new

      expect { registry.send(:persist_registry!, [], published:) }.to raise_error(
        RubyLLM::ModelRegistryError, /is read-only/
      )
    end

    it 'rejects a configuration with nowhere to write' do
      RubyLLM.config.model_registry_file = nil

      expect { registry.send(:persist_registry!, [], published:) }.to raise_error(
        RubyLLM::ModelRegistryError, 'No writable model registry store is configured'
      )
    end

    it 'names the store in the error when writing blows up' do
      RubyLLM.config.model_registry_store = Class.new do
        def description = 'the Rails model table'
        def write(_models) = raise(IOError, 'disk full')
      end.new

      expect { registry.send(:persist_registry!, [], published:) }.to raise_error(
        RubyLLM::ModelRegistryError, 'Could not save the model registry to the Rails model table: disk full'
      )
    end

    it 'falls back to the store class name when it has no description' do
      RubyLLM.config.model_registry_store = Class.new do
        def self.name = 'AnonymousStore'
        def write(_models) = raise(IOError, 'disk full')
      end.new

      expect { registry.send(:persist_registry!, [], published:) }.to raise_error(
        RubyLLM::ModelRegistryError, /Could not save the model registry to AnonymousStore/
      )
    end
  end

  describe '#published_catalog' do
    it 'treats a corrupt snapshot as no cache' do
      Dir.mktmpdir do |directory|
        path = File.join(directory, 'models.json')
        File.write("#{path}.published.json", '{broken')
        RubyLLM.config.model_registry_file = path

        expect(described_class.new([]).send(:published_catalog)).to be_nil
      end
    end
  end

  describe '#refresh against the published catalog' do
    let(:published) { [model(id: 'gpt-x', provider: 'openai', name: 'GPT X', context_window: 400_000)] }

    def local_provider(context_window)
      fake_provider(
        slug: 'ollama', display_name: 'Ollama',
        models: [model(id: 'llama', provider: 'ollama', name: 'llama', context_window: context_window)]
      )
    end

    def stub_published(models, etag, not_modified)
      allow(described_class).to receive(:fetch_published_registry)
        .and_return(RubyLLM::ModelRegistry::PublishedSource::Result.new(models, etag, not_modified))
    end

    around do |example|
      Dir.mktmpdir do |directory|
        RubyLLM.config.model_registry_file = File.join(directory, 'models.json')
        example.run
      end
    end

    it 'prunes and refreshes on a not-modified answer just as it does on a fresh one' do
      allow(RubyLLM::Provider).to receive(:configured_providers).and_return([local_provider(8192)])
      stub_published(published, 'etag-1', false)
      described_class.new([]).refresh

      stale = described_class.load_models + [model(id: 'retired', provider: 'openai')]
      allow(RubyLLM::Provider).to receive(:configured_providers).and_return([local_provider(131_072)])
      stub_published(nil, 'etag-1', true)
      registry = described_class.new(stale).refresh

      expect(registry.all.map(&:id)).to contain_exactly('llama', 'gpt-x')
      expect(registry.all.find { |m| m.id == 'llama' }.context_window).to eq(131_072)
    end

    it 'fetches the whole catalog again when the snapshot behind the ETag is gone' do
      allow(RubyLLM::Provider).to receive(:configured_providers).and_return([local_provider(8192)])
      results = [
        RubyLLM::ModelRegistry::PublishedSource::Result.new(nil, 'etag-1', true),
        RubyLLM::ModelRegistry::PublishedSource::Result.new(published, 'etag-1', false)
      ]
      allow(described_class).to receive(:fetch_published_registry) { results.shift }

      registry = described_class.new([])
      registry.refresh

      expect(registry.all.map(&:id)).to contain_exactly('llama', 'gpt-x')
    end

    it 'keeps provider gem catalogs out of the main file cache' do
      published_models = [model(id: 'claude-haiku-4-5', provider: 'anthropic')]
      provider_models = [model(id: 'gpt-4.1-mini', provider: 'openai')]
      allow(RubyLLM::Provider).to receive_messages(
        configured_providers: [],
        model_registry_files: { openai: '/tmp/openai-models.json' }
      )
      allow(described_class).to receive(:models_from_provider_gems).and_return(provider_models)
      stub_published(published_models, 'etag-1', false)

      registry = described_class.new(provider_models).refresh
      cached = RubyLLM::ModelRegistry.read(RubyLLM.config.model_registry_file)

      expect(registry.all.map(&:id)).to contain_exactly('claude-haiku-4-5', 'gpt-4.1-mini')
      expect(cached.map(&:id)).to eq(['claude-haiku-4-5'])
    end

    it 'writes provider gem catalogs through the configured model store' do
      published_models = [model(id: 'claude-haiku-4-5', provider: 'anthropic')]
      provider_models = [model(id: 'gpt-4.1-mini', provider: 'openai')]
      stored = []
      RubyLLM.config.model_registry_store = Class.new do
        define_method(:read) { stored }
        define_method(:write) { |models| stored.replace(models.all) }
      end.new
      allow(RubyLLM::Provider).to receive_messages(
        configured_providers: [],
        model_registry_files: { openai: '/tmp/openai-models.json' }
      )
      allow(described_class).to receive(:models_from_provider_gems).and_return(provider_models)
      stub_published(published_models, 'etag-1', false)

      described_class.new(provider_models).refresh

      expect(stored.map(&:id)).to contain_exactly('claude-haiku-4-5', 'gpt-4.1-mini')
    end
  end

  describe '#file_store' do
    it 'is nil when a store takes precedence' do
      RubyLLM.config.model_registry_store = Object.new

      expect(described_class.new([]).send(:file_store)).to be_nil
    end

    it 'is nil when no registry file is configured' do
      RubyLLM.config.model_registry_file = nil

      expect(described_class.new([]).send(:file_store)).to be_nil
    end
  end

  describe '#resolve_provider_registry_id' do
    it 'leaves the id alone for an unknown provider' do
      registry = described_class.new([])

      expect(registry.send(:resolve_provider_registry_id, 'some-model', :nowhere)).to eq('some-model')
    end
  end

  describe '.resolve' do
    it 'requires a provider when assuming the model exists' do
      expect { described_class.resolve('anything', assume_model_exists: true) }.to raise_error(
        ArgumentError, 'Provider must be specified if assume_model_exists is true'
      )
    end
  end
end
