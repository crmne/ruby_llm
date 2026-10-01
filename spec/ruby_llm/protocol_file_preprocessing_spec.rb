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

  it 'replaces an upload past its retention window' do
    provider = RubyLLM::Providers::Gemini.new(RubyLLM.config)
    protocol = RubyLLM::Protocols::Gemini.new(provider, model)
    attachment = RubyLLM::Attachment.new(StringIO.new('video bytes'), filename: 'clip.mp4')
    allow(attachment).to receive(:byte_size).and_return(25 * 1024 * 1024)
    expiring = RubyLLM::UploadedFile.new(id: 'files/old', provider: 'gemini', filename: 'clip.mp4',
                                         mime_type: 'video/mp4', expires_at: Time.now + 30)
    fresh = RubyLLM::UploadedFile.new(id: 'files/new', provider: 'gemini', filename: 'clip.mp4',
                                      mime_type: 'video/mp4', expires_at: Time.now + (48 * 3600))
    allow(provider).to receive(:upload_file).and_return(expiring, fresh)

    message = RubyLLM::Message.new(role: :user, content: 'Watch this', attachments: [attachment])

    expect(protocol.preprocess_message(message).attachments.first.provider_file_id).to eq('files/old')
    expect(protocol.preprocess_message(message).attachments.first.provider_file_id).to eq('files/new')
    expect(provider).to have_received(:upload_file).twice
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
    expect(attachment.provider_uploads.values.map(&:id)).to contain_exactly('files/abc', 'file_123')
  end

  it 'uploads again for the same provider under different credentials' do
    other_config = RubyLLM.config.dup
    other_config.openai_api_key = 'sk-other-tenant'
    tenants = [RubyLLM::Providers::OpenAI.new(RubyLLM.config), RubyLLM::Providers::OpenAI.new(other_config)]
    attachment = RubyLLM::Attachment.new(StringIO.new('pdf bytes'), filename: 'report.pdf')
    allow(attachment).to receive(:byte_size).and_return(60 * 1024 * 1024)
    tenants.each_with_index do |provider, index|
      allow(provider).to receive(:upload_file).and_return(
        RubyLLM::UploadedFile.new(id: "file_#{index}", provider: 'openai', filename: 'report.pdf',
                                  mime_type: 'application/pdf')
      )
    end

    message = RubyLLM::Message.new(role: :user, content: 'Summarize this', attachments: [attachment])
    ids = tenants.map { |provider| RubyLLM::Protocols::Responses.new(provider, model) }
                 .map { |protocol| protocol.preprocess_message(message).attachments.first.provider_file_id }

    expect(ids).to eq(%w[file_0 file_1])
    expect(tenants).to all(have_received(:upload_file).once)
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

  it 'leaves the upload size limit to the provider' do
    provider = RubyLLM::Providers::OpenRouter.new(RubyLLM.config)
    protocol = RubyLLM::Providers::OpenRouter::ChatCompletions.new(provider, model)
    attachment = RubyLLM::Attachment.new(StringIO.new('pdf bytes'), filename: 'huge.pdf')
    allow(attachment).to receive(:byte_size).and_return(101 * 1024 * 1024)
    uploaded = RubyLLM::UploadedFile.new(id: 'file_789', provider: 'openrouter', filename: 'huge.pdf',
                                         mime_type: 'application/pdf')
    allow(provider).to receive(:upload_file).and_return(uploaded)

    message = RubyLLM::Message.new(role: :user, content: 'Summarize this', attachments: [attachment])

    expect(protocol.preprocess_message(message).attachments.first.provider_file_id).to eq('file_789')
  end

  it 'preprocesses at request time rather than when messages are added' do
    chat = RubyLLM.chat(model: RubyLLM.config.default_model)
    allow(chat.provider).to receive(:preprocess_messages) { |messages, **| messages }

    chat.add_message(role: :user, content: 'hi')
    expect(chat.provider).not_to have_received(:preprocess_messages)

    chat.render
    expect(chat.provider).to have_received(:preprocess_messages)
  end

  it 'preprocesses the messages it counts tokens for' do
    chat = RubyLLM.chat(model: RubyLLM.config.default_model)
    allow(chat.provider).to receive(:preprocess_messages) { |messages, **| messages }
    allow(chat.provider).to receive(:count_tokens).and_return(1)

    chat.count_tokens('hi')

    expect(chat.provider).to have_received(:preprocess_messages).with([have_attributes(content: 'hi')], any_args)
  end

  it 'resolves the preprocessing protocol once per request' do
    chat = RubyLLM.chat(model: RubyLLM.config.default_model)
    5.times { |index| chat.add_message(role: :user, content: "message #{index}") }
    allow(chat.provider).to receive(:protocol_for).and_call_original

    chat.render

    expect(chat.provider).to have_received(:protocol_for).twice
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

  describe 'with uploads stored for the attachment' do
    let(:provider) { RubyLLM::Providers::Gemini.new(RubyLLM.config) }
    let(:protocol) { RubyLLM::Protocols::Gemini.new(provider, model) }
    let(:store) do
      Class.new do
        attr_reader :files

        def initialize
          @files = {}
        end

        def fetch(provider:, account:)
          @files[[provider, account]]
        end

        def store(upload, provider:, account:)
          @files[[provider, account]] = upload
        end
      end.new
    end

    def gemini_file(id, expires_at: Time.now + (48 * 3600))
      RubyLLM::UploadedFile.new(id:, provider: 'gemini', filename: 'clip.mp4', mime_type: 'video/mp4',
                                uri: "https://example.test/#{id}", expires_at:)
    end

    def stored_attachment
      attachment = RubyLLM::Attachment.new(StringIO.new('video bytes'), filename: 'clip.mp4')
      allow(attachment).to receive(:byte_size).and_return(25 * 1024 * 1024)
      attachment.provider_file_store = store
      attachment
    end

    def sent_file_id(attachment, via: protocol)
      message = RubyLLM::Message.new(role: :user, content: 'Watch this', attachments: [attachment])
      via.preprocess_message(message).attachments.first.provider_file_id
    end

    def remember(file, account: provider.account_identity)
      store.files[['gemini', account]] = file
    end

    it 'reuses a stored upload once the provider confirms it still has the file' do
      remember(gemini_file('files/stored'))
      allow(provider).to receive(:find_file).with('files/stored').and_return(gemini_file('files/stored'))
      allow(provider).to receive(:upload_file)

      expect(sent_file_id(stored_attachment)).to eq('files/stored')
      expect(provider).not_to have_received(:upload_file)
    end

    it 'asks the provider about a stored upload once per process' do
      remember(gemini_file('files/stored'))
      allow(provider).to receive(:find_file).and_return(gemini_file('files/stored'))

      ids = Array.new(3) { sent_file_id(stored_attachment) }

      expect(ids).to eq(Array.new(3, 'files/stored'))
      expect(provider).to have_received(:find_file).once
    end

    it 'uploads again and stores the new file when the provider no longer has the stored one' do
      remember(gemini_file('files/gone'))
      allow(provider).to receive(:find_file).and_raise(RubyLLM::Error, 'File not found')
      allow(provider).to receive(:upload_file).and_return(gemini_file('files/new'))

      expect(sent_file_id(stored_attachment)).to eq('files/new')
      expect(store.files.values.map(&:id)).to eq(['files/new'])
    end

    it 'uploads again without asking the provider when the stored file has expired' do
      remember(gemini_file('files/old', expires_at: Time.now - 1))
      allow(provider).to receive(:find_file)
      allow(provider).to receive(:upload_file).and_return(gemini_file('files/new'))

      expect(sent_file_id(stored_attachment)).to eq('files/new')
      expect(provider).not_to have_received(:find_file)
    end

    it 'uploads again when the provider reports the stored file has expired' do
      remember(gemini_file('files/old'))
      allow(provider).to receive_messages(find_file: gemini_file('files/old', expires_at: Time.now),
                                          upload_file: gemini_file('files/new'))

      expect(sent_file_id(stored_attachment)).to eq('files/new')
    end

    it 'stores a new upload and trusts it for the rest of the process' do
      allow(provider).to receive_messages(upload_file: gemini_file('files/new'), find_file: nil)

      first = sent_file_id(stored_attachment)
      second = sent_file_id(stored_attachment)

      expect([first, second]).to eq(%w[files/new files/new])
      expect(provider).to have_received(:upload_file).once
      expect(provider).not_to have_received(:find_file)
    end

    it 'keeps each account apart' do
      other_config = RubyLLM.config.dup
      other_config.gemini_api_key = 'other-tenant'
      other = RubyLLM::Providers::Gemini.new(other_config)
      remember(gemini_file('files/ours'))
      allow(provider).to receive(:find_file).and_return(gemini_file('files/ours'))
      allow(other).to receive(:upload_file).and_return(gemini_file('files/theirs'))

      expect(sent_file_id(stored_attachment, via: RubyLLM::Protocols::Gemini.new(other, model))).to eq('files/theirs')
      expect(store.files.keys).to contain_exactly(['gemini', provider.account_identity],
                                                  ['gemini', other.account_identity])
    end

    it 'keeps uploads in memory when the provider cannot name the account' do
      allow(provider).to receive_messages(account_identity: nil, upload_file: gemini_file('files/new'))

      expect(sent_file_id(stored_attachment)).to eq('files/new')
      expect(store.files).to be_empty
    end
  end
end
