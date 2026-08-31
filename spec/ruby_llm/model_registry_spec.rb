# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'

RSpec.describe RubyLLM::ModelRegistry do
  let(:model) do
    RubyLLM::Model.new(id: 'new-model', name: 'New Model', provider: 'openai')
  end

  let(:old_model) do
    RubyLLM::Model.new(id: 'old-model', name: 'Old Model', provider: 'openai')
  end

  let(:empty_fetch) do
    { models: [], fetched_providers: [], configured_names: [], failed: [] }
  end

  describe '.cache_path' do
    def stub_host_os(host_os)
      allow(RbConfig::CONFIG).to receive(:[]).and_call_original
      allow(RbConfig::CONFIG).to receive(:[]).with('host_os').and_return(host_os)
    end

    before do
      allow(Dir).to receive(:home).and_return('/home/me')
      allow(ENV).to receive(:fetch).and_call_original
    end

    it 'uses XDG_CACHE_HOME on Linux' do
      stub_host_os('linux')
      allow(ENV).to receive(:fetch).with('XDG_CACHE_HOME', nil).and_return('/cache')

      expect(described_class.cache_path).to eq('/cache/ruby_llm/models.json')
    end

    it 'uses the native cache directory on macOS' do
      stub_host_os('darwin')

      expect(described_class.cache_path).to eq('/home/me/Library/Caches/RubyLLM/models.json')
    end

    it 'uses the native cache directory on Windows' do
      stub_host_os('mingw32')
      allow(ENV).to receive(:fetch).with('LOCALAPPDATA', nil).and_return('C:/Users/me/AppData/Local')

      expect(described_class.cache_path).to eq('C:/Users/me/AppData/Local/RubyLLM/Cache/models.json')
    end
  end

  describe '.models_from_data' do
    it 'reads the registry as a top-level array' do
      models = described_class.models_from_data([model.to_h], source: 'models.json')

      expect(models.map(&:id)).to eq(['new-model'])
    end

    it 'rejects an object envelope' do
      expect do
        described_class.models_from_data({ models: [model.to_h] }, source: 'models.json')
      end.to raise_error(RubyLLM::ModelRegistryError, /must be a JSON array/)
    end
  end

  describe RubyLLM::ModelRegistry::FileStore do
    it 'writes a top-level array and an adjacent ETag' do
      Dir.mktmpdir do |directory|
        path = File.join(directory, 'models.json')
        store = described_class.new(path)

        store.write([model], etag: '"registry-1"')

        expect(JSON.parse(File.read(path))).to be_an(Array)
        expect(store.read.map(&:id)).to eq(['new-model'])
        expect(store.etag).to eq('"registry-1"')
        expect(File.read(File.join(directory, 'models.json.etag')).strip).to eq('"registry-1"')
      end
    end

    it 'leaves the registry readable instead of inheriting the tempfile mode' do
      Dir.mktmpdir do |directory|
        path = File.join(directory, 'models.json')
        store = described_class.new(path)

        store.write([model], etag: nil)
        expect(File.stat(path).mode & 0o777).to eq(0o666 & ~File.umask)

        File.chmod(0o640, path)
        store.write([model], etag: nil)
        expect(File.stat(path).mode & 0o777).to eq(0o640)
      end
    end
  end

  describe RubyLLM::ModelRegistry::PublishedSource do
    it 'loads the published top-level array' do
      stub_request(:get, RubyLLM::ModelRegistry::PUBLISHED_URL)
        .to_return(
          status: 200,
          body: JSON.generate([model.to_h]),
          headers: { 'Content-Type' => 'application/json', 'ETag' => '"registry-1"' }
        )

      result = described_class.new.fetch

      expect(result.models.map(&:id)).to eq(['new-model'])
      expect(result.etag).to eq('"registry-1"')
      expect(result.not_modified).to be(false)
    end

    it 'sends the cached ETag and handles an unmodified registry' do
      request = stub_request(:get, RubyLLM::ModelRegistry::PUBLISHED_URL)
                .with(headers: { 'If-None-Match' => '"registry-1"' })
                .to_return(status: 304, headers: { 'ETag' => '"registry-1"' })

      result = described_class.new.fetch(etag: '"registry-1"')

      expect(request).to have_been_requested.once
      expect(result).to have_attributes(models: nil, etag: '"registry-1"', not_modified: true)
    end
  end

  describe RubyLLM::Models do
    include_context 'with configured RubyLLM'

    around do |example|
      original_store = RubyLLM.config.model_registry_store
      RubyLLM.config.model_registry_store = nil
      example.run
    ensure
      RubyLLM.config.model_registry_store = original_store
    end

    after do
      described_class.instance_variable_set(:@instance, nil)
    end

    it 'uses a valid registry file when one exists' do
      Dir.mktmpdir do |directory|
        cache = File.join(directory, 'models.json')
        RubyLLM::ModelRegistry::FileStore.new(cache).write([model])
        config = RubyLLM.config.dup
        config.model_registry_file = cache
        allow(RubyLLM).to receive(:config).and_return(config)

        loaded = described_class.load_models

        expect(loaded.map(&:id)).to eq(['new-model'])
      end
    end

    it 'falls back to the bundle when the registry file is corrupt' do
      Dir.mktmpdir do |directory|
        cache = File.join(directory, 'models.json')
        File.write(cache, '{broken')
        config = RubyLLM.config.dup
        config.model_registry_file = cache
        allow(RubyLLM).to receive(:config).and_return(config)
        allow(RubyLLM.logger).to receive(:warn)

        loaded = described_class.load_models

        expect(loaded).not_to be_empty
        expect(loaded.map(&:id)).not_to include('new-model')
      end
    end

    it 'persists a successful refresh and reuses its ETag' do
      Dir.mktmpdir do |directory|
        path = File.join(directory, 'models.json')
        original_file = RubyLLM.config.model_registry_file
        RubyLLM.config.model_registry_file = path
        allow(described_class).to receive(:fetch_provider_models).and_return(empty_fetch)
        allow(described_class).to receive(:fetch_published_registry)
          .with(etag: nil)
          .and_return(RubyLLM::ModelRegistry::PublishedSource::Result.new([model], '"registry-1"', false))

        registry = described_class.new([old_model])
        registry.refresh

        expect(JSON.parse(File.read(path))).to be_an(Array)
        expect(RubyLLM::ModelRegistry::FileStore.new(path).etag).to eq('"registry-1"')
        expect(registry.all.map(&:id)).to eq(['new-model'])

        allow(described_class).to receive(:fetch_published_registry)
          .with(etag: '"registry-1"')
          .and_return(RubyLLM::ModelRegistry::PublishedSource::Result.new(nil, '"registry-1"', true))
        registry.refresh

        expect(registry.all.map(&:id)).to eq(['new-model'])
      ensure
        RubyLLM.config.model_registry_file = original_file
      end
    end

    it 'raises on a cache write failure without changing the in-memory registry' do
      Dir.mktmpdir do |directory|
        config = RubyLLM.config.dup
        config.model_registry_file = File.join(directory, 'models.json')
        allow(RubyLLM).to receive(:config).and_return(config)
        published = [model]
        allow(described_class).to receive_messages(
          fetch_provider_models: empty_fetch,
          fetch_published_registry: RubyLLM::ModelRegistry::PublishedSource::Result.new(published, nil, false)
        )
        allow_any_instance_of(RubyLLM::ModelRegistry::FileStore).to( # rubocop:disable RSpec/AnyInstance
          receive(:write).and_raise(Errno::EACCES, config.model_registry_file)
        )

        registry = described_class.new([old_model])

        expect { registry.refresh }.to raise_error(RubyLLM::ModelRegistryError, /Could not save/)
        expect(registry.all.map(&:id)).to eq(['old-model'])
      end
    end

    it 'raises on a database write failure without changing the in-memory registry' do
      store = double('model registry store', write: nil, description: 'database:Model') # rubocop:disable RSpec/VerifiedDoubles
      allow(store).to receive(:write).and_raise('database unavailable')
      RubyLLM.config.model_registry_store = store
      allow(described_class).to receive_messages(
        fetch_provider_models: empty_fetch,
        fetch_published_registry: RubyLLM::ModelRegistry::PublishedSource::Result.new([model], nil, false)
      )

      registry = described_class.new([old_model])

      expect { registry.refresh }.to raise_error(RubyLLM::ModelRegistryError, /database unavailable/)
      expect(registry.all.map(&:id)).to eq(['old-model'])
    end

    it 'persists a candidate before changing the in-memory registry' do
      store = double('model registry store', description: 'database:Model') # rubocop:disable RSpec/VerifiedDoubles
      RubyLLM.config.model_registry_store = store
      allow(described_class).to receive_messages(
        fetch_provider_models: empty_fetch,
        fetch_published_registry: RubyLLM::ModelRegistry::PublishedSource::Result.new([model], nil, false)
      )
      registry = described_class.new([old_model])
      allow(store).to receive(:write) do |candidate|
        expect(candidate.all.map(&:id)).to eq(['new-model'])
        expect(registry.all.map(&:id)).to eq(['old-model'])
      end

      registry.refresh

      expect(registry.all.map(&:id)).to eq(['new-model'])
    end

    it 'adopts what the store reports, keeping the unlisted models the merge dropped' do
      unlisted = RubyLLM::Model.new(id: 'old-model', name: 'Old Model', provider: 'openai',
                                    unlisted_at: Time.now.utc)
      store = double('model registry store', description: 'database:Model', write: nil, # rubocop:disable RSpec/VerifiedDoubles
                                             read: [model, unlisted])
      RubyLLM.config.model_registry_store = store
      allow(described_class).to receive_messages(
        fetch_provider_models: empty_fetch,
        fetch_published_registry: RubyLLM::ModelRegistry::PublishedSource::Result.new([model], nil, false)
      )

      registry = described_class.new([old_model]).refresh

      expect(registry.all.map(&:id)).to eq(['new-model'])
      expect(registry.unlisted.map(&:id)).to eq(['old-model'])
      expect(registry.find('old-model', :openai).id).to eq('old-model')
    end
  end

  describe 'RubyLLM::ModelRegistry::FileStore paths and ETags' do
    it 'requires a path' do
      expect { RubyLLM::ModelRegistry::FileStore.new('') }.to raise_error(
        RubyLLM::ModelRegistryError, 'A model registry file path is required'
      )
    end

    it 'accepts anything that names a path' do
      Tempfile.create(['models', '.json']) do |file|
        expect(RubyLLM::ModelRegistry::FileStore.new(file).path).to eq(file.path)
      end
    end

    describe '#etag' do
      it 'is nil when the registry file does not exist' do
        Dir.mktmpdir do |dir|
          expect(RubyLLM::ModelRegistry::FileStore.new(File.join(dir, 'models.json')).etag).to be_nil
        end
      end

      it 'is nil when the etag file is empty' do
        Dir.mktmpdir do |dir|
          path = File.join(dir, 'models.json')
          File.write(path, '[]')
          File.write("#{path}.etag", "\n")

          expect(RubyLLM::ModelRegistry::FileStore.new(path).etag).to be_nil
        end
      end

      it 'reports an unreadable etag file' do
        Dir.mktmpdir do |dir|
          path = File.join(dir, 'models.json')
          File.write(path, '[]')
          allow(File).to receive(:read).with("#{path}.etag").and_raise(Errno::EACCES)

          expect { RubyLLM::ModelRegistry::FileStore.new(path).etag }.to raise_error(
            RubyLLM::ModelRegistryError, /Could not read the model registry ETag/
          )
        end
      end
    end
  end

  describe '.models_from_data validation' do
    it 'refuses anything but an array' do
      expect { described_class.models_from_data({}) }.to raise_error(
        RubyLLM::ModelRegistryError, 'Model registry must be a JSON array'
      )
    end

    it 'names the source in the error' do
      expect { described_class.models_from_data({}, source: '/tmp/models.json') }.to raise_error(
        RubyLLM::ModelRegistryError, 'Model registry in /tmp/models.json must be a JSON array'
      )
    end

    it 'passes Model values through untouched' do
      model = RubyLLM::Model.new(id: 'a', name: 'A', provider: 'openai')

      expect(described_class.models_from_data([model]).first).to equal(model)
    end
  end

  describe '.read' do
    it 'reports an unreadable registry file' do
      allow(File).to receive(:read).with('/tmp/models.json').and_raise(Errno::EACCES)

      expect { described_class.read('/tmp/models.json') }.to raise_error(
        RubyLLM::ModelRegistryError, %r{Could not read the model registry from /tmp/models.json}
      )
    end
  end

  describe 'RubyLLM::ModelRegistry::PublishedSource failures' do
    it 'raises when the published catalog is empty' do
      source = RubyLLM::ModelRegistry::PublishedSource.new('https://example.test/models.json')
      connection = instance_double(Faraday::Connection)
      allow(RubyLLM::Connection).to receive(:basic).and_return(connection)
      allow(connection).to receive(:get).and_return(
        Struct.new(:status, :body, :headers).new(200, [], {})
      )

      expect { source.fetch }.to raise_error(RubyLLM::ModelRegistryError, 'Published model registry is empty')
    end

    it 'wraps a transport failure' do
      source = RubyLLM::ModelRegistry::PublishedSource.new('https://example.test/models.json')
      connection = instance_double(Faraday::Connection)
      allow(RubyLLM::Connection).to receive(:basic).and_return(connection)
      allow(connection).to receive(:get).and_raise(Faraday::ConnectionFailed, 'no route')

      expect { source.fetch }.to raise_error(
        RubyLLM::ModelRegistryError, %r{Could not refresh the model registry from https://example.test/models.json}
      )
    end

    it 'keeps the requested etag when the catalog has not changed' do
      source = RubyLLM::ModelRegistry::PublishedSource.new('https://example.test/models.json')
      connection = instance_double(Faraday::Connection)
      allow(RubyLLM::Connection).to receive(:basic).and_return(connection)
      allow(connection).to receive(:get) do |_url, &block|
        request = Struct.new(:headers).new({})
        block.call(request)
        Struct.new(:status, :body, :headers).new(304, nil, {})
      end

      result = source.fetch(etag: 'etag-1')

      expect(result.not_modified).to be(true)
      expect(result.etag).to eq('etag-1')
    end
  end
end
