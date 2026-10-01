# frozen_string_literal: true

require 'rails_helper'
require 'stringio'

RSpec.describe RubyLLM::ActiveRecord::ProviderFile do
  include_context 'with configured RubyLLM'

  let(:model) { model_for(:anthropic) }
  let(:files_url) { 'https://api.anthropic.com/v1/files' }
  let(:messages_url) { 'https://api.anthropic.com/v1/messages' }
  let(:reply) do
    { id: 'msg_1', type: 'message', role: 'assistant', model: model, content: [{ type: 'text', text: 'Noted.' }],
      stop_reason: 'end_turn', usage: { input_tokens: 9, output_tokens: 2 } }
  end

  before do
    described_class.delete_all
    stub_const('RubyLLM::Protocols::Anthropic::Chat::ANTHROPIC_INLINE_REQUEST_LIMIT', 16)
    stub_request(:post, messages_url).to_return(json_response(reply))
  end

  def json_response(body, status: 200)
    { status:, body: body.to_json, headers: { 'Content-Type' => 'application/json' } }
  end

  def file_body(id)
    { id:, type: 'file', filename: 'notes.txt', mime_type: 'text/plain', size_bytes: 40,
      created_at: '2026-10-01T09:00:00Z', downloadable: false }
  end

  def stub_uploads(*ids)
    stub_request(:post, files_url).to_return(*ids.map { |id| json_response(file_body(id)) })
  end

  def stub_lookup(id, status: 200)
    body = status == 200 ? file_body(id) : { type: 'error', error: { type: 'not_found_error', message: 'Not found' } }
    stub_request(:get, "#{files_url}/#{id}").to_return(json_response(body, status:))
  end

  def notes
    RubyLLM::Attachment.new(StringIO.new('Meeting notes long enough to upload.'), filename: 'notes.txt')
  end

  def stored_blob(text)
    ActiveStorage::Blob.create_and_upload!(io: StringIO.new(text), filename: 'notes.txt', content_type: 'text/plain')
  end

  def new_process
    RubyLLM::Protocol::StoredUploads.files.clear
  end

  def sent_file(id)
    a_request(:post, messages_url).with { |request| request.body.include?(%("file_id":"#{id}")) }
  end

  def downloads
    count = 0
    subscriber = ActiveSupport::Notifications.subscribe(/\Aservice_(streaming_)?download\.active_storage\z/) do
      count += 1
    end
    yield
    count
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber)
  end

  it 'records the upload of a file asked about against its blob' do
    stub_uploads('file_1')
    chat = Chat.create!(model:)

    chat.ask('Summarize these notes', with: notes)

    stored = described_class.sole
    expect(stored.blob_key).to eq(chat.messages.first.attachments.first.blob.key)
    expect(stored).to have_attributes(provider: 'anthropic', file_id: 'file_1')
    expect(stored.account).to eq(chat.to_llm.provider.account_identity)
  end

  it 'tells apart files of the same size asked about together' do
    stub_uploads('file_1', 'file_2')
    chat = Chat.create!(model:)
    first = RubyLLM::Attachment.new(StringIO.new('First notes, long enough to upload.'), filename: 'first.txt')
    other = RubyLLM::Attachment.new(StringIO.new('Other notes, long enough to upload.'), filename: 'other.txt')

    chat.ask('Compare these notes', with: [first, other])

    blobs = chat.messages.first.attachments.blobs.index_by { |blob| blob.filename.to_s }
    expect(described_class.pluck(:blob_key, :file_id))
      .to contain_exactly([blobs['first.txt'].key, 'file_1'], [blobs['other.txt'].key, 'file_2'])
  end

  it 'reuses the upload when the chat is loaded again in another process' do
    upload = stub_uploads('file_1')
    lookup = stub_lookup('file_1')
    chat = Chat.create!(model:)
    chat.ask('Summarize these notes', with: notes)
    new_process

    count = downloads { 2.times { Chat.find(chat.id).ask('And the action items?') } }

    expect(upload).to have_been_requested.once
    expect(lookup).to have_been_requested.once
    expect(sent_file('file_1')).to have_been_made.times(3)
    expect(count).to eq(0)
  end

  it 'uploads again when the provider no longer has the file' do
    stub_uploads('file_1', 'file_2')
    stub_lookup('file_1', status: 404)
    chat = Chat.create!(model:)
    chat.ask('Summarize these notes', with: notes)
    new_process

    Chat.find(chat.id).ask('And the action items?')

    expect(sent_file('file_2')).to have_been_made.once
    expect(described_class.sole.file_id).to eq('file_2')
  end

  it 'uploads again once the stored file has expired' do
    upload = stub_uploads('file_1', 'file_2')
    lookup = stub_lookup('file_1')
    chat = Chat.create!(model:)
    chat.ask('Summarize these notes', with: notes)
    described_class.update_all(expires_at: 1.hour.ago)

    Chat.find(chat.id).ask('And the action items?')

    expect(upload).to have_been_requested.twice
    expect(lookup).not_to have_been_requested
    expect(described_class.sole).to have_attributes(file_id: 'file_2', expires_at: nil)
  end

  it 'keeps the uploads of each account apart' do
    upload = stub_uploads('file_1', 'file_2')
    chat = Chat.create!(model:)
    chat.ask('Summarize these notes', with: notes)
    other = RubyLLM.context { |config| config.anthropic_api_key = 'other-tenant' }

    Chat.find(chat.id).with_context(other).ask('And the action items?')

    expect(upload).to have_been_requested.twice
    expect(described_class.pluck(:file_id)).to contain_exactly('file_1', 'file_2')
  end

  it 'records a stored blob passed to ask against that blob' do
    stub_uploads('file_1')
    blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new('Shared notes long enough to upload.'),
                                                  filename: 'notes.txt', content_type: 'text/plain')

    Chat.create!(model:).ask('Summarize these notes', with: blob)

    expect(described_class.sole.blob_key).to eq(blob.key)
  end

  it 'replaces the recorded upload when the provider deletes it mid-process' do
    stub_uploads('file_1', 'file_2')
    chat = Chat.create!(model:)
    chat.ask('Summarize these notes', with: notes)
    stub_request(:post, messages_url).to_return(
      json_response({ type: 'error', error: { type: 'not_found_error', message: 'File not found: file_1' } },
                    status: 404),
      json_response(reply)
    )

    Chat.find(chat.id).ask('And the action items?')

    expect(sent_file('file_2')).to have_been_made.once
    expect(a_request(:get, "#{files_url}/file_1")).not_to have_been_made
    expect(described_class.sole.file_id).to eq('file_2')
  end

  it 'never reuses the upload of a deleted blob for a blob that takes its id' do
    stub_uploads('file_1', 'file_2')
    deleted = stored_blob('First notes, long enough to upload.')
    Chat.create!(model:).ask('Summarize these notes', with: deleted)
    ActiveStorage::Attachment.where(blob_id: deleted.id).delete_all
    ActiveStorage::Blob.where(id: deleted.id).delete_all
    replacement = stored_blob('Other notes, long enough to upload.')
    ActiveStorage::Blob.where(id: replacement.id).update_all(id: deleted.id)

    Chat.create!(model:).ask('Summarize these notes', with: ActiveStorage::Blob.find(deleted.id))

    expect(sent_file('file_2')).to have_been_made.once
  end

  it 'forgets the uploads of a blob Active Storage purges' do
    stub_uploads('file_1')
    chat = Chat.create!(model:)
    chat.ask('Summarize these notes', with: notes)

    chat.messages.first.attachments.purge

    expect(described_class.count).to eq(0)
  end

  it 'purges blobs before the table exists' do
    stub_uploads('file_1')
    chat = Chat.create!(model:)
    chat.ask('Summarize these notes', with: notes)
    allow(described_class).to receive(:table_exists?).and_return(false)

    ActiveRecord::Base.transaction do
      ActiveRecord::Base.connection.drop_table(:ruby_llm_provider_files)
      expect { chat.messages.first.attachments.purge }.not_to raise_error
      raise ActiveRecord::Rollback
    end
  end

  it 'keeps uploads in memory until the table exists' do
    allow(described_class).to receive(:table_exists?).and_return(false)
    upload = stub_uploads('file_1', 'file_2')
    chat = Chat.create!(model:)
    chat.ask('Summarize these notes', with: notes)

    Chat.find(chat.id).ask('And the action items?')

    expect(upload).to have_been_requested.twice
    expect(described_class.unscoped.count).to eq(0)
  end
end
