# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::ProviderFile do
  include_context 'with configured RubyLLM'

  let(:fixture_path) { File.expand_path('../fixtures/ruby.txt', __dir__) }
  let(:batch_fixture_path) { File.expand_path('../fixtures/openai_batch.jsonl', __dir__) }

  describe '.upload' do
    it 'delegates to the resolved provider' do
      provider_instance = instance_double(RubyLLM::Providers::OpenAI)

      allow(described_class).to receive(:resolve_provider).with(provider: :openai,
                                                                context: nil).and_return(provider_instance)
      allow(provider_instance).to receive(:upload_file).with('spec/fixtures/ruby.txt',
                                                             purpose: 'assistants').and_return(:uploaded_file)

      result = described_class.upload('spec/fixtures/ruby.txt', provider: :openai, purpose: 'assistants')

      expect(result).to eq(:uploaded_file)
    end
  end

  describe '.file_info' do
    it 'delegates to the resolved provider' do
      provider_instance = instance_double(RubyLLM::Providers::OpenAI)

      allow(described_class).to receive(:resolve_provider).with(provider: :openai,
                                                                context: nil).and_return(provider_instance)
      allow(provider_instance).to receive(:file_info).with('file_123').and_return(:file_info)

      result = described_class.file_info('file_123', provider: :openai)

      expect(result).to eq(:file_info)
    end
  end

  describe '.download' do
    it 'delegates to the resolved provider' do
      provider_instance = instance_double(RubyLLM::Providers::OpenAI)
      io = StringIO.new

      allow(described_class).to receive(:resolve_provider).with(provider: :openai,
                                                                context: nil).and_return(provider_instance)
      allow(provider_instance).to receive(:download_file).with('file_123', io: io).and_return(io)

      result = described_class.download('file_123', provider: :openai, io: io)

      expect(result).to eq(io)
    end
  end

  describe '.resolve_provider' do
    it 'resolves a provider from the explicit provider name' do
      provider = described_class.resolve_provider(provider: :openai, context: nil)

      expect(provider).to be_a(RubyLLM::Providers::OpenAI)
      expect(provider.config).to eq(RubyLLM.config)
    end

    it 'uses the context config when provided' do
      context = RubyLLM.context do |config|
        config.openai_api_key = 'sk-context-key'
      end

      provider = described_class.resolve_provider(provider: :openai, context: context)

      expect(provider).to be_a(RubyLLM::Providers::OpenAI)
      expect(provider.config).to eq(context.config)
      expect(provider.config.openai_api_key).to eq('sk-context-key')
    end

    it 'raises an error for an unknown provider' do
      expect do
        described_class.resolve_provider(provider: :unknown, context: nil)
      end.to raise_error(RubyLLM::Error, 'Unknown provider: unknown')
    end
  end

  describe 'OpenAI file API workflow' do
    let(:provider) { :openai }
    let(:purpose) { 'batch' }

    it 'uploads a file and returns file metadata' do
      uploaded_file = RubyLLM.upload_file(batch_fixture_path, provider:, purpose:)

      expect(uploaded_file).to be_a(described_class)
      expect(uploaded_file.id).to start_with('file-')
      expect(uploaded_file.filename).to eq('openai_batch.jsonl')
      expect(uploaded_file.byte_size).to eq(File.size(batch_fixture_path))
      expect(uploaded_file.created_at).to be_a(Time)
    end

    it 'looks up file metadata for an uploaded file' do
      uploaded_file = RubyLLM.upload_file(batch_fixture_path, provider:, purpose:)

      file_info = described_class.file_info(uploaded_file.id, provider:)

      expect(file_info).to be_a(described_class)
      expect(file_info.id).to eq(uploaded_file.id)
      expect(file_info.filename).to eq(uploaded_file.filename)
      expect(file_info.byte_size).to eq(uploaded_file.byte_size)
      expect(file_info.created_at).to eq(uploaded_file.created_at)
    end

    it 'downloads batch-purpose file content' do
      uploaded_file = RubyLLM.upload_file(batch_fixture_path, provider:, purpose:)

      downloaded_content = described_class.download(uploaded_file.id, provider:)

      expect(downloaded_content).to eq(File.binread(batch_fixture_path))
    end
  end
end
