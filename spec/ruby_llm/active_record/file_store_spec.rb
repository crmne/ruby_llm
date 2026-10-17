# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RubyLLM::ActiveRecord::FileStore do
  include_context 'with configured RubyLLM'

  let(:chat) { Chat.create!(model: model_for(:openai)) }
  let(:store) { described_class.new(chat) }
  let(:image_path) { File.expand_path('../../fixtures/ruby.png', __dir__) }

  it_behaves_like 'a file store'

  def answer(content)
    RubyLLM::Message.new(role: :assistant, content:, input_tokens: 1, output_tokens: 1)
  end

  it 'keeps rows in ruby_llm_chat_files with their content in Active Storage' do
    store.write('notes/plan.md', '# Plan')

    row = chat.ruby_llm_chat_files.sole
    expect(row).to have_attributes(path: 'notes/plan.md', byte_size: 6, content_type: 'text/markdown',
                                   digest: Digest::SHA256.hexdigest('# Plan'))
    expect(row.file.download).to eq('# Plan')
    expect(row.to_stored_file).to have_attributes(path: 'notes/plan.md', updated_at: row.updated_at)
  end

  it 'keeps converted text in the row until the file changes' do
    store.write('notes.md', 'ORCHID-97')
    store.text('notes.md')
    expect(chat.ruby_llm_chat_files.sole.text).to eq('ORCHID-97')

    store.write('notes.md', 'BLUE-LANTERN-42')
    expect(chat.ruby_llm_chat_files.sole.text).to be_nil
    expect(described_class.new(chat).text('notes.md')).to eq('BLUE-LANTERN-42')
  end

  it 'keeps no text for a version of the file it no longer has' do
    stale = store.write('notes.md', 'old')
    current = store.write('notes.md', 'new')
    store.cache_text(stale, 'old text')
    expect(chat.ruby_llm_chat_files.sole.text).to be_nil

    store.cache_text(current, 'new text')
    expect(store.cached_text(current)).to eq('new text')
    expect(store.cached_text(stale)).to be_nil
  end

  it 'declares its attachment once' do
    allow(RubyLLM::ActiveRecord::ChatFile).to receive(:has_one_attached)

    RubyLLM::ActiveRecord::ChatFile.declare_attachments

    expect(RubyLLM::ActiveRecord::ChatFile).not_to have_received(:has_one_attached)
  end

  it 'keeps an attachment by its blob, given the blob itself' do
    blob = ActiveStorage::Blob.create_and_upload!(io: File.open(image_path), filename: 'logo.png')

    file = store.store_attachment(RubyLLM::Attachment.new(blob))

    expect(file.path).to eq('logo.png')
    expect(chat.ruby_llm_chat_files.sole.file.blob).to eq(blob)
    expect(store.store_attachment(RubyLLM::Attachment.new(blob))).to eq(file)
  end

  it 'keeps the files of each chat apart' do
    other = Chat.create!(model: model_for(:openai))
    store.write('a.txt', 'mine')

    expect(described_class.new(other).list).to be_empty
  end

  describe 'owners' do
    let(:alice) { Chat.create!(model: model_for(:openai)) }
    let(:bob) { Chat.create!(model: model_for(:openai)) }

    it 'shows each owner their files and the shared ones, preferring their own' do
      store.write('shared.md', 'everyone')
      store.write('report.md', 'shared report')
      described_class.new(chat, owner: alice).write('report.md', "Alice's report")
      described_class.new(chat, owner: alice).write('alice.md', 'private')

      alices = described_class.new(chat, owner: alice)
      bobs = described_class.new(chat, owner: bob)

      expect(alices.list.map(&:path)).to eq(%w[alice.md report.md shared.md])
      expect(alices.read('report.md')).to eq("Alice's report")
      expect(alices.find('alice.md').owner).to eq(alice)
      expect(bobs.list.map(&:path)).to eq(%w[report.md shared.md])
      expect(bobs.read('report.md')).to eq('shared report')
      expect(bobs.find('alice.md')).to be_nil
      expect(store.list.map(&:path)).to eq(%w[report.md shared.md])
    end

    it 'deletes only files of its own owner' do
      store.write('shared.md', 'everyone')

      expect(described_class.new(chat, owner: alice).delete('shared.md')).to be_nil
      expect(store.exists?('shared.md')).to be(true)
    end
  end

  describe 'a persisted chat with files' do
    it 'keeps its files in Active Storage, or a store it is given' do
      expect(chat.with_file_store).to be(chat)
      expect(chat.file_store).to be_a(described_class)
      expect(chat.file_store.chat).to eq(chat)

      memory = RubyLLM::FileStore::Memory.new
      expect(chat.with_file_store(memory).file_store).to be(memory)
      expect(chat.with_file_store(spill_to_file: 5).file_store).to be_a(described_class)
      expect(chat.to_llm.instance_variable_get(:@file_references).spill_to_file).to eq(5)
      expect(chat.with_file_store(nil).file_store).to be_nil
      expect(chat.with_file_store(owner: chat).file_store.owner).to eq(chat)
      expect { chat.with_file_store(memory, owner: chat) }.to raise_error(ArgumentError, /owner: applies/)
    end

    it "takes an agent's owner lambda, run with the chat in scope" do
      agent = Class.new(RubyLLM::Agent) do
        chat_model Chat
        file_store owner: -> { chat }
      end
      agent.model model_for(:openai), provider: :openai

      record = agent.create!

      expect(record.file_store).to be_a(described_class)
      expect(record.file_store.owner).to eq(record)
    end

    it 'keeps an attachment by sharing its blob, which outlives the message' do
      allow(chat.to_llm.provider).to receive(:complete).and_return(answer('A logo.'))
      chat.ask('What is this?', with: image_path)
      job = Chat.find(chat.id).with_file_store
      allow(job.to_llm.provider).to receive(:complete).and_return(answer('Red.'))

      expect { job.ask('What color?') }.not_to change(ActiveStorage::Blob, :count)

      message = chat.messages.find_by(role: 'user', content: 'What is this?')
      file = chat.ruby_llm_chat_files.sole
      expect(file.path).to eq('ruby.png')
      expect(file.file.blob).to eq(message.attachments.first.blob)

      message.attachments.first.purge
      expect(file.reload.file.download).to eq(File.binread(image_path))
    end

    it 'sends earlier attachments as a line naming the file, across processes' do
      chat.with_file_store
      allow(chat.to_llm.provider).to receive(:complete).and_return(answer('A logo.'))
      chat.ask('What is this?', with: image_path)

      requests = []
      job = Chat.find(chat.id).with_file_store
      allow(job.to_llm.provider).to receive(:complete) do |messages, **|
        requests << messages
        answer('Red.')
      end
      job.ask('What color?')

      expect(requests.sole.first.attachments.sole.content).to start_with('ruby.png (image/png,')
      expect(chat.ruby_llm_chat_files.count).to eq(1)
    end

    it 'saves a long tool result as a file and persists only its start' do
      tool = Class.new(RubyLLM::Tool) do
        description 'Lists everything'
        define_method(:name) { 'list_everything' }
        define_method(:execute) { 'item ' * 5_000 }
      end
      call = RubyLLM::ToolCall.new(id: 'call_1', name: 'list_everything', arguments: {})
      chat.with_file_store.with_tools(tool)
      allow(chat.to_llm.provider).to receive(:complete).and_return(
        RubyLLM::Message.new(role: :assistant, content: '', tool_calls: { 'call_1' => call },
                             input_tokens: 1, output_tokens: 1),
        answer('Done')
      )

      chat.ask('List everything')

      result = chat.messages.find_by(role: 'tool')
      path = result.content[%r{All of it is in (results/list_everything-\w{8}\.txt)}, 1]
      expect(result.content.length).to be < 2_500
      expect(chat.file_store.read(path)).to eq('item ' * 5_000)
    end

    it 'deletes its files with the chat' do
      chat.with_file_store.file_store.write('a.txt', 'x')

      expect { chat.destroy }.to change(RubyLLM::ActiveRecord::ChatFile, :count).by(-1)
    end
  end
end
