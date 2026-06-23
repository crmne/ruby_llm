# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocol do
  include_context 'with configured RubyLLM'

  let(:model) { instance_double(RubyLLM::Model::Info, id: 'test-model') }

  it 'uploads oversized Gemini attachments and stores a provider-file attachment' do
    provider = RubyLLM::Providers::Gemini.new(RubyLLM.config)
    protocol = RubyLLM::Protocols::Gemini.new(provider, model)
    attachment = RubyLLM::Attachment.new(StringIO.new('video bytes'), filename: 'clip.mp4')
    allow(attachment).to receive(:byte_size).and_return(25 * 1024 * 1024)
    uploaded = RubyLLM::UploadedFile.new(
      id: 'files/abc',
      provider: 'gemini',
      filename: 'clip.mp4',
      mime_type: 'video/mp4',
      uri: 'https://generativelanguage.googleapis.com/v1beta/files/abc'
    )
    allow(provider).to receive(:upload_file).with(attachment).and_return(uploaded)

    message = RubyLLM::Message.new(role: :user, content: RubyLLM::Content.new('Watch this', [attachment]))

    processed = protocol.preprocess_message(message)

    expect(processed).not_to be(message)
    expect(processed.content.text).to eq('Watch this')
    expect(processed.content.attachments.first).to be_provider_file
    expect(processed.content.attachments.first.provider_file_id).to eq('files/abc')
  end

  it 'leaves small Gemini attachments inline' do
    provider = RubyLLM::Providers::Gemini.new(RubyLLM.config)
    protocol = RubyLLM::Protocols::Gemini.new(provider, model)
    attachment = RubyLLM::Attachment.new(StringIO.new('video bytes'), filename: 'clip.mp4')
    allow(attachment).to receive(:byte_size).and_return(1024)
    allow(provider).to receive(:upload_file)

    message = RubyLLM::Message.new(role: :user, content: RubyLLM::Content.new('Watch this', [attachment]))

    expect(protocol.preprocess_message(message)).to be(message)
    expect(provider).not_to have_received(:upload_file)
  end

  it 'uses OpenAI user_data purpose for automatic Responses uploads' do
    provider = RubyLLM::Providers::OpenAI.new(RubyLLM.config)
    protocol = RubyLLM::Protocols::Responses.new(provider, model)
    attachment = RubyLLM::Attachment.new(StringIO.new('pdf bytes'), filename: 'large.pdf')
    allow(attachment).to receive(:byte_size).and_return(60 * 1024 * 1024)
    uploaded = RubyLLM::UploadedFile.new(
      id: 'file_123',
      provider: 'openai',
      filename: 'large.pdf',
      mime_type: 'application/pdf'
    )
    allow(provider).to receive(:upload_file).with(attachment, purpose: 'user_data').and_return(uploaded)

    message = RubyLLM::Message.new(role: :user, content: RubyLLM::Content.new('Summarize this', [attachment]))

    processed = protocol.preprocess_message(message)

    expect(processed.content.attachments.first.provider_file_id).to eq('file_123')
  end

  it 'raises before uploading files above the provider file limit' do
    provider = RubyLLM::Providers::OpenRouter.new(RubyLLM.config)
    protocol = RubyLLM::Providers::OpenRouter::ChatCompletions.new(provider, model)
    attachment = RubyLLM::Attachment.new(StringIO.new('pdf bytes'), filename: 'huge.pdf')
    allow(attachment).to receive(:byte_size).and_return(101 * 1024 * 1024)
    allow(provider).to receive(:upload_file)

    message = RubyLLM::Message.new(role: :user, content: RubyLLM::Content.new('Summarize this', [attachment]))

    expect { protocol.preprocess_message(message) }
      .to raise_error(RubyLLM::Error, /OpenRouter file uploads support files up to/)
    expect(provider).not_to have_received(:upload_file)
  end

  it 'does not auto-upload Vertex AI Claude attachments as Anthropic file IDs' do
    provider = RubyLLM::Providers::VertexAI.new(RubyLLM.config)
    protocol = RubyLLM::Providers::VertexAI::Anthropic.new(provider, model)
    attachment = RubyLLM::Attachment.new(StringIO.new('pdf bytes'), filename: 'large.pdf')
    allow(attachment).to receive(:byte_size).and_return(30 * 1024 * 1024)
    allow(provider).to receive(:upload_file)

    message = RubyLLM::Message.new(role: :user, content: RubyLLM::Content.new('Summarize this', [attachment]))

    expect(protocol.preprocess_message(message)).to be(message)
    expect(provider).not_to have_received(:upload_file)
  end
end
