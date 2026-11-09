# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::UploadedFile, :live do
  let(:pdf_path) { File.expand_path('../fixtures/sample.pdf', __dir__) }

  describe 'live uploads' do
    # Mistral's Files API only accepts JSONL batches, fine-tune data, or OCR
    # documents, so the PDF goes up with purpose: 'ocr' there.
    [
      { provider: :anthropic },
      { provider: :gemini },
      { provider: :meta, options: { purpose: 'user_data' } },
      { provider: :mistral, options: { purpose: 'ocr' } },
      { provider: :moonshot },
      { provider: :openai, options: { purpose: 'user_data' } },
      { provider: :xai }
    ].each do |upload_info|
      provider = upload_info[:provider]
      it "#{provider} uploads a PDF through the Files API" do
        file = RubyLLM.upload(pdf_path, provider: provider, **upload_info.fetch(:options, {}))

        expect(file.id).to be_present
        expect(file.byte_size).to eq(File.size(pdf_path))
      end
    end

    it "openai/#{model_for(:openai)} reuses an uploaded file in chat" do
      file = RubyLLM.upload(pdf_path, provider: :openai, purpose: 'user_data')

      response = RubyLLM.chat(model: model_for(:openai), provider: :openai)
                        .ask('Summarize this document in one sentence.', with: file)

      expect(response.content).to match(/pdf|document|lorem|sample/i)
    end

    it "moonshot/#{model_for(:moonshot)} reuses an uploaded file in chat and downloads its text" do
      file = RubyLLM.upload(pdf_path, provider: :moonshot)

      response = RubyLLM.chat(model: model_for(:moonshot), provider: :moonshot)
                        .ask('Summarize this document in one sentence.', with: file)

      expect(response.content).to match(/pdf|document|lorem|sample/i)
      expect(RubyLLM.download(file.id, provider: :moonshot).to_s).to match(/sample pdf/i)
    end

    it "moonshot/#{model_for(:moonshot)} reads an uploaded image by reference" do
      file = RubyLLM.upload(File.expand_path('../fixtures/ruby.png', __dir__), provider: :moonshot)

      response = RubyLLM.chat(model: model_for(:moonshot), provider: :moonshot)
                        .ask('What gemstone is in this image? One word.', with: file)

      expect(response.content).to match(/ruby/i)
    end

    it "meta/#{model_for(:meta)} reuses an uploaded file in chat" do
      file = RubyLLM.upload(pdf_path, provider: :meta, purpose: 'user_data')

      response = RubyLLM.chat(model: model_for(:meta), provider: :meta)
                        .ask('Summarize this document in one sentence.', with: file)

      expect(response.content).to match(/pdf|document|lorem|sample/i)
    end

    it 'meta downloads an uploaded file' do
      file = RubyLLM.upload(pdf_path, provider: :meta, purpose: 'user_data')

      expect(described_class.download(file.id, provider: :meta).to_blob.bytesize).to eq(File.size(pdf_path))
    end

    it "gemini/#{model_for(:gemini)} reuses an uploaded file in chat" do
      file = RubyLLM.upload(pdf_path, provider: :gemini)

      response = RubyLLM.chat(model: model_for(:gemini), provider: :gemini)
                        .ask('Summarize this document in one sentence.', with: file)

      expect(response.content).to match(/pdf|document|lorem|sample/i)
    end
  end

  describe 'RubyLLM shortcuts' do
    it 'uploads through RubyLLM.upload' do
      allow(described_class).to receive(:upload).with('batch.jsonl', purpose: 'batch').and_return(:uploaded)

      expect(RubyLLM.upload('batch.jsonl', purpose: 'batch')).to eq(:uploaded)
    end

    it 'downloads through RubyLLM.download' do
      allow(described_class).to receive(:download).with('file_123').and_return("jsonl\n")

      expect(RubyLLM.download('file_123')).to eq("jsonl\n")
    end

    it 'rejects unknown upload keyword arguments' do
      expect do
        RubyLLM.upload('batch.jsonl', unsupported: true)
      end.to raise_error(ArgumentError, /unknown keyword/)
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
      config.default_model = model_for(:anthropic)
      context = RubyLLM::Context.new(config)
      provider = instance_double(RubyLLM::Providers::Anthropic)

      stub_default_model_provider(provider, config:)
      allow(provider).to receive(:upload_file).with('document.pdf').and_return(:uploaded)

      expect(context.upload('document.pdf')).to eq(:uploaded)
    end

    it 'downloads through the provider of the context default model' do
      config = RubyLLM::Configuration.new
      config.default_model = model_for(:anthropic)
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
    model = instance_double(RubyLLM::Model)
    allow(RubyLLM::Models).to receive(:resolve).with(config.default_model, config:).and_return([model, provider])
  end
end
