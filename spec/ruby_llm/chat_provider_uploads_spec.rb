# frozen_string_literal: true

require 'spec_helper'
require 'stringio'

RSpec.describe RubyLLM::Chat do
  include_context 'with configured RubyLLM'

  let(:model) { model_for(:anthropic) }
  let(:files_url) { 'https://api.anthropic.com/v1/files' }
  let(:messages_url) { 'https://api.anthropic.com/v1/messages' }
  let(:account) { RubyLLM::Providers::Anthropic.new(RubyLLM.config).account_identity }
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

      def forget(id, provider:, account:)
        @files.delete([provider, account]) if @files[[provider, account]]&.id == id
      end
    end.new
  end

  before do
    stub_const('RubyLLM::Protocols::Anthropic::Chat::ANTHROPIC_INLINE_REQUEST_LIMIT', 16)
    store.files[['anthropic', account]] = RubyLLM::UploadedFile.new(id: 'file_old', provider: 'anthropic')
    stub_request(:get, "#{files_url}/file_old").to_return(json_response(file_body('file_old')))
  end

  def json_response(body, status: 200)
    { status:, body: body.to_json, headers: { 'Content-Type' => 'application/json' } }
  end

  def stream_response(*events)
    body = events.map { |data| "event: #{data[:type]}\ndata: #{data.to_json}\n\n" }.join
    { status: 200, body:, headers: { 'Content-Type' => 'text/event-stream' } }
  end

  def file_body(id)
    { id:, type: 'file', filename: 'notes.txt', mime_type: 'text/plain', size_bytes: 36,
      created_at: '2026-10-01T09:00:00Z', downloadable: false }
  end

  def reply
    { id: 'msg_1', type: 'message', role: 'assistant', model:, content: [{ type: 'text', text: 'Noted.' }],
      stop_reason: 'end_turn', usage: { input_tokens: 9, output_tokens: 2 } }
  end

  def streamed(*texts, error: nil)
    start = { type: 'message_start', message: reply.merge(content: [], stop_reason: nil) }
    deltas = texts.map { |text| { type: 'content_block_delta', index: 0, delta: { type: 'text_delta', text: } } }
    finish = if error
               [{ type: 'error', error: }]
             else
               [{ type: 'content_block_stop', index: 0 },
                { type: 'message_delta', delta: { stop_reason: 'end_turn' }, usage: { output_tokens: 2 } },
                { type: 'message_stop' }]
             end
    stream_response(start, { type: 'content_block_start', index: 0, content_block: { type: 'text', text: '' } },
                    *deltas, *finish)
  end

  def missing(id, status: 404)
    json_response({ type: 'error', error: { type: 'not_found_error', message: "File not found: #{id}" } }, status:)
  end

  def notes
    attachment = RubyLLM::Attachment.new(StringIO.new('Meeting notes long enough to upload.'), filename: 'notes.txt')
    attachment.provider_file_store = store
    attachment
  end

  def sent_file(id)
    a_request(:post, messages_url).with { |request| request.body.include?(%("file_id":"#{id}")) }
  end

  def confirmed?(id)
    confirmed = true
    RubyLLM::Protocol::StoredUploads.files.fetch(['anthropic', account, id]) { confirmed = false }
    confirmed
  end

  it 'uploads a file the provider deleted again and retries the request once' do
    upload = stub_request(:post, files_url).to_return(json_response(file_body('file_new')))
    stub_request(:post, messages_url).to_return(missing('file_old'), json_response(reply))

    response = described_class.new(model:).ask('Summarize these notes', with: notes)

    expect(response.content).to eq('Noted.')
    expect(upload).to have_been_requested.once
    expect(sent_file('file_old')).to have_been_made.once
    expect(sent_file('file_new')).to have_been_made.once
    expect(store.files.values.map(&:id)).to eq(['file_new'])
    expect(confirmed?('file_old')).to be(false)
  end

  it 'retries a streamed request that failed before streaming anything' do
    stub_request(:post, files_url).to_return(json_response(file_body('file_new')))
    stub_request(:post, messages_url).to_return(missing('file_old', status: 400), streamed('Noted.'))
    chunks = []

    response = described_class.new(model:).ask('Summarize these notes', with: notes) do |chunk|
      chunks << chunk.content if chunk.content
    end

    expect(response.content).to eq('Noted.')
    expect(chunks.join).to eq('Noted.')
    expect(sent_file('file_new')).to have_been_made.once
  end

  it 'never retries once streamed content reached the caller' do
    upload = stub_request(:post, files_url).to_return(json_response(file_body('file_new')))
    stub_request(:post, messages_url)
      .to_return(streamed('Partial', error: { type: 'not_found_error', message: 'File not found: file_old' }))
    chunks = []

    expect do
      described_class.new(model:).ask('Summarize these notes', with: notes) { |chunk| chunks << chunk.content }
    end.to raise_error(RubyLLM::Error, /file_old/)
    expect(chunks.compact.join).to eq('Partial')
    expect(upload).not_to have_been_requested
    expect(a_request(:post, messages_url)).to have_been_made.once
  end

  it 'uploads again after a 404 that names no file' do
    stub_request(:post, files_url).to_return(json_response(file_body('file_new')))
    stub_request(:post, messages_url)
      .to_return(json_response({ type: 'error', error: { type: 'not_found_error', message: 'Not found' } },
                               status: 404),
                 json_response(reply))

    expect(described_class.new(model:).ask('Summarize these notes', with: notes).content).to eq('Noted.')
    expect(sent_file('file_new')).to have_been_made.once
  end

  it 'retries only once' do
    upload = stub_request(:post, files_url).to_return(json_response(file_body('file_new')))
    stub_request(:post, messages_url).to_return(missing('file_old'), missing('file_new'))

    expect { described_class.new(model:).ask('Summarize these notes', with: notes) }
      .to raise_error(RubyLLM::Error, /file_new/)
    expect(upload).to have_been_requested.once
    expect(a_request(:post, messages_url)).to have_been_made.twice
  end

  it 'does not retry errors about something else' do
    upload = stub_request(:post, files_url)
    stub_request(:post, messages_url).to_return(
      json_response({ type: 'error', error: { type: 'invalid_request_error', message: 'max_tokens is too large' } },
                    status: 400)
    )

    expect { described_class.new(model:).ask('Summarize these notes', with: notes) }
      .to raise_error(RubyLLM::BadRequestError)
    expect(upload).not_to have_been_requested
    expect(a_request(:post, messages_url)).to have_been_made.once
  end

  it 'does not retry a file the application uploaded itself' do
    file = RubyLLM::UploadedFile.new(id: 'file_app', provider: 'anthropic', filename: 'notes.txt',
                                     mime_type: 'text/plain')
    stub_request(:post, messages_url).to_return(missing('file_app'))

    expect { described_class.new(model:).ask('Summarize these notes', with: file) }
      .to raise_error(RubyLLM::Error, /file_app/)
    expect(a_request(:post, messages_url)).to have_been_made.once
  end

  describe 'compaction' do
    def xai_file(id)
      json_response({ id:, object: 'file', filename: 'report.pdf', bytes: 40, created_at: 1, purpose: 'user_data' })
    end

    it 'uploads a file the provider deleted again and compacts once more' do
      compact_url = 'https://api.x.ai/v1/responses/compact'
      xai_account = RubyLLM::Providers::XAI.new(RubyLLM.config).account_identity
      stub_const('RubyLLM::Protocols::Responses::Chat::OPENAI_INLINE_FILE_LIMIT', 16)
      store.files[['xai', xai_account]] = RubyLLM::UploadedFile.new(id: 'file_old', provider: 'xai')
      stub_request(:get, 'https://api.x.ai/v1/files/file_old').to_return(xai_file('file_old'))
      stub_request(:post, 'https://api.x.ai/v1/files').to_return(xai_file('file_new'))
      stub_request(:post, compact_url).to_return(
        missing('file_old'),
        json_response({ id: 'cmp_1', object: 'response.compaction', output: [{ type: 'compaction', id: 'cmp_1' }],
                        usage: { input_tokens: 23, output_tokens: 7 } })
      )
      report = RubyLLM::Attachment.new(StringIO.new('%PDF-1.4 long enough to upload'), filename: 'report.pdf')
      report.provider_file_store = store
      chat = described_class.new(model: model_for(:xai, :provider_tools), provider: :xai)
      chat.add_message(role: :user, content: 'Remember this report.', attachments: [report])

      chat.compact

      expect(a_request(:post, compact_url).with { |request| request.body.include?('"file_id":"file_new"') })
        .to have_been_made.once
    end
  end
end
