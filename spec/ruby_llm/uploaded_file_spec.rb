# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::UploadedFile do
  include_context 'with configured RubyLLM'

  describe 'RubyLLM shortcuts' do
    it 'uploads through RubyLLM.upload' do
      allow(described_class).to receive(:upload).with('batch.jsonl', purpose: 'batch').and_return(:uploaded)

      expect(RubyLLM.upload('batch.jsonl', purpose: 'batch')).to eq(:uploaded)
    end

    it 'downloads through RubyLLM.download' do
      allow(described_class).to receive(:download).with('file_123').and_return("jsonl\n")

      expect(RubyLLM.download('file_123')).to eq("jsonl\n")
    end
  end

  describe '.upload' do
    it 'delegates to an explicit provider' do
      provider = instance_double(RubyLLM::Providers::OpenAI)
      stub_provider_resolution(provider)
      allow(provider).to receive(:upload_file).with('batch.jsonl', purpose: 'batch').and_return(:uploaded)

      expect(described_class.upload('batch.jsonl', provider: :openai, purpose: 'batch')).to eq(:uploaded)
    end

    it 'uses the provider of the default model when provider is omitted' do
      provider = instance_double(RubyLLM::Providers::OpenAI)
      stub_default_model_provider(provider)
      allow(provider).to receive(:upload_file).with('batch.jsonl', purpose: 'batch').and_return(:uploaded)

      expect(described_class.upload('batch.jsonl', purpose: 'batch')).to eq(:uploaded)
    end
  end

  describe '.find' do
    it 'delegates to an explicit provider' do
      provider = instance_double(RubyLLM::Providers::OpenAI)
      stub_provider_resolution(provider)
      allow(provider).to receive(:find_file).with('file_123').and_return(:info)

      expect(described_class.find('file_123', provider: :openai)).to eq(:info)
    end

    it 'uses the provider of the default model when provider is omitted' do
      provider = instance_double(RubyLLM::Providers::OpenAI)
      stub_default_model_provider(provider)
      allow(provider).to receive(:find_file).with('file_123').and_return(:info)

      expect(described_class.find('file_123')).to eq(:info)
    end
  end

  describe '.download' do
    it 'delegates to an explicit provider' do
      provider = instance_double(RubyLLM::Providers::OpenAI)
      stub_provider_resolution(provider)
      allow(provider).to receive(:download_file).with('file_123').and_return("jsonl\n")

      expect(described_class.download('file_123', provider: :openai)).to eq("jsonl\n")
    end

    it 'uses the provider of the default model when provider is omitted' do
      provider = instance_double(RubyLLM::Providers::OpenAI)
      stub_default_model_provider(provider)
      allow(provider).to receive(:download_file).with('file_123').and_return("jsonl\n")

      expect(described_class.download('file_123')).to eq("jsonl\n")
    end
  end

  describe 'context shortcuts' do
    it 'uploads through the provider of the context default model' do
      config = RubyLLM::Configuration.new
      config.default_model = 'claude-haiku-4-5'
      context = RubyLLM::Context.new(config)
      provider = instance_double(RubyLLM::Providers::Anthropic)

      stub_default_model_provider(provider, config:)
      allow(provider).to receive(:upload_file).with('document.pdf').and_return(:uploaded)

      expect(context.upload('document.pdf')).to eq(:uploaded)
    end

    it 'downloads through the provider of the context default model' do
      config = RubyLLM::Configuration.new
      config.default_model = 'claude-haiku-4-5'
      context = RubyLLM::Context.new(config)
      provider = instance_double(RubyLLM::Providers::Anthropic)

      stub_default_model_provider(provider, config:)
      allow(provider).to receive(:download_file).with('file_123').and_return("content\n")

      expect(context.download('file_123')).to eq("content\n")
    end
  end

  def stub_provider_resolution(provider)
    provider_class = class_double(RubyLLM::Providers::OpenAI, new: provider)
    allow(RubyLLM::Provider).to receive(:resolve!).with(:openai).and_return(provider_class)
  end

  def stub_default_model_provider(provider, config: RubyLLM.config)
    model = instance_double(RubyLLM::Model::Info)
    allow(RubyLLM::Models).to receive(:resolve).with(config.default_model, config:).and_return([model, provider])
  end
end
