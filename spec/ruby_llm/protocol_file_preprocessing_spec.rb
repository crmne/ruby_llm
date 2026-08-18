# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocol do
  include_context 'with configured RubyLLM'

  let(:model) { instance_double(RubyLLM::Model, id: 'test-model') }

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

    message = RubyLLM::Message.new(role: :user, content: 'Watch this', attachments: [attachment])

    processed = protocol.preprocess_message(message)

    expect(processed).not_to be(message)
    expect(processed.content).to eq('Watch this')
    expect(processed.attachments.first).to be_provider_file
    expect(processed.attachments.first.provider_file_id).to eq('files/abc')
  end

  it 'uploads once per provider and keeps the original attachment in the message' do
    provider = RubyLLM::Providers::Gemini.new(RubyLLM.config)
    protocol = RubyLLM::Protocols::Gemini.new(provider, model)
    attachment = RubyLLM::Attachment.new(StringIO.new('video bytes'), filename: 'clip.mp4')
    allow(attachment).to receive(:byte_size).and_return(25 * 1024 * 1024)
    uploaded = RubyLLM::UploadedFile.new(id: 'files/abc', provider: 'gemini', filename: 'clip.mp4',
                                         mime_type: 'video/mp4', uri: 'https://example.test/files/abc')
    allow(provider).to receive(:upload_file).and_return(uploaded)

    message = RubyLLM::Message.new(role: :user, content: 'Watch this', attachments: [attachment])

    first = protocol.preprocess_message(message)
    second = protocol.preprocess_message(message)

    expect(provider).to have_received(:upload_file).once
    expect(second.attachments.first.provider_file_id).to eq(first.attachments.first.provider_file_id)
    expect(message.attachments.first).to be(attachment)
    expect(attachment).not_to be_provider_file
  end

  it 'uploads separately for each provider' do
    gemini = RubyLLM::Providers::Gemini.new(RubyLLM.config)
    openai = RubyLLM::Providers::OpenAI.new(RubyLLM.config)
    attachment = RubyLLM::Attachment.new(StringIO.new('pdf bytes'), filename: 'report.pdf')
    allow(attachment).to receive(:byte_size).and_return(60 * 1024 * 1024)
    allow(gemini).to receive(:upload_file).and_return(
      RubyLLM::UploadedFile.new(id: 'files/abc', provider: 'gemini', filename: 'report.pdf',
                                mime_type: 'application/pdf', uri: 'https://example.test/files/abc')
    )
    allow(openai).to receive(:upload_file).and_return(
      RubyLLM::UploadedFile.new(id: 'file_123', provider: 'openai', filename: 'report.pdf',
                                mime_type: 'application/pdf')
    )

    message = RubyLLM::Message.new(role: :user, content: 'Summarize this', attachments: [attachment])

    from_gemini = RubyLLM::Protocols::Gemini.new(gemini, model).preprocess_message(message)
    from_openai = RubyLLM::Protocols::Responses.new(openai, model).preprocess_message(message)

    expect(from_gemini.attachments.first.provider_file_id).to eq('files/abc')
    expect(from_openai.attachments.first.provider_file_id).to eq('file_123')
    expect(attachment.provider_uploads.keys).to contain_exactly('gemini', 'openai')
  end

  it 'leaves small Gemini attachments inline' do
    provider = RubyLLM::Providers::Gemini.new(RubyLLM.config)
    protocol = RubyLLM::Protocols::Gemini.new(provider, model)
    attachment = RubyLLM::Attachment.new(StringIO.new('video bytes'), filename: 'clip.mp4')
    allow(attachment).to receive(:byte_size).and_return(1024)
    allow(provider).to receive(:upload_file)

    message = RubyLLM::Message.new(role: :user, content: 'Watch this', attachments: [attachment])

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

    message = RubyLLM::Message.new(role: :user, content: 'Summarize this', attachments: [attachment])

    processed = protocol.preprocess_message(message)

    expect(processed.attachments.first.provider_file_id).to eq('file_123')
  end

  it 'uploads oversized Responses documents beyond PDFs' do
    provider = RubyLLM::Providers::OpenAI.new(RubyLLM.config)
    protocol = RubyLLM::Protocols::Responses.new(provider, model)
    attachment = RubyLLM::Attachment.new(StringIO.new('docx bytes'), filename: 'large.docx')
    allow(attachment).to receive(:byte_size).and_return(60 * 1024 * 1024)
    uploaded = RubyLLM::UploadedFile.new(
      id: 'file_456',
      provider: 'openai',
      filename: 'large.docx',
      mime_type: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
    )
    allow(provider).to receive(:upload_file).with(attachment, purpose: 'user_data').and_return(uploaded)

    message = RubyLLM::Message.new(role: :user, content: 'Summarize this', attachments: [attachment])

    expect(protocol.preprocess_message(message).attachments.first.provider_file_id).to eq('file_456')
  end

  it 'raises before uploading files above the provider file limit' do
    provider = RubyLLM::Providers::OpenRouter.new(RubyLLM.config)
    protocol = RubyLLM::Providers::OpenRouter::ChatCompletions.new(provider, model)
    attachment = RubyLLM::Attachment.new(StringIO.new('pdf bytes'), filename: 'huge.pdf')
    allow(attachment).to receive(:byte_size).and_return(101 * 1024 * 1024)
    allow(provider).to receive(:upload_file)

    message = RubyLLM::Message.new(role: :user, content: 'Summarize this', attachments: [attachment])

    expect { protocol.preprocess_message(message) }
      .to raise_error(RubyLLM::Error, /OpenRouter file uploads support files up to/)
    expect(provider).not_to have_received(:upload_file)
  end

  it 'preprocesses at request time rather than when messages are added' do
    chat = RubyLLM.chat(model: RubyLLM.config.default_model)
    allow(chat.provider).to receive(:preprocess_message) { |message, **| message }

    chat.add_message(role: :user, content: 'hi')
    expect(chat.provider).not_to have_received(:preprocess_message)

    chat.render
    expect(chat.provider).to have_received(:preprocess_message)
  end

  it 'does not auto-upload Vertex AI Claude attachments as Anthropic file IDs' do
    provider = RubyLLM::Providers::VertexAI.new(RubyLLM.config)
    protocol = RubyLLM::Providers::VertexAI::Anthropic.new(provider, model)
    attachment = RubyLLM::Attachment.new(StringIO.new('pdf bytes'), filename: 'large.pdf')
    allow(attachment).to receive(:byte_size).and_return(30 * 1024 * 1024)
    allow(provider).to receive(:upload_file)

    message = RubyLLM::Message.new(role: :user, content: 'Summarize this', attachments: [attachment])

    expect(protocol.preprocess_message(message)).to be(message)
    expect(provider).not_to have_received(:upload_file)
  end
end
