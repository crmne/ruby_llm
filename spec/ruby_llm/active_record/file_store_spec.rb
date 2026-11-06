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

  it 'remembers what the model read in the row, for every store of the chat' do
    store.write('notes.md', 'one')
    store.record_read('notes.md', 'abc123')

    expect(chat.ruby_llm_chat_files.sole.read_digest).to eq('abc123')
    expect(described_class.new(chat).read_digest('notes.md')).to eq('abc123')
    expect(described_class.new(Chat.create!(model: model_for(:openai))).read_digest('notes.md')).to be_nil
  end

  it 'locks the chat and reads past the query cache inside with_lock' do
    store.write('notes.md', 'one')
    RubyLLM::ActiveRecord::ChatFile.cache do
      store['notes.md']
      write_elsewhere('notes.md', 'theirs').join

      expect(store.with_lock { store.read('notes.md') }).to eq('theirs')
    end
  end

  it 'uploads the content before the transaction that writes the row commits' do
    RubyLLM::ActiveRecord::ChatFile.transaction do
      store.write('notes.md', 'one')

      key = chat.ruby_llm_chat_files.sole.file.key
      expect(ActiveStorage::Blob.service.exist?(key)).to be(true)
    end
    expect(store.read('notes.md')).to eq('one')
  end

  it 'applies concurrent edits of one file from two processes one after the other' do
    if Chat.connection.adapter_name.match?(/sqlite/i) && ActiveRecord.version < Gem::Version.new('8.0')
      skip 'Before Rails 8.0, SQLite waits for a lock holding the GVL, so threads in one process cannot take turns'
    end

    store.write('plan.md', "a\nb\n")
    store.record_read('plan.md', RubyLLM::FileStore.digest("a\nb\n"))
    allow_any_instance_of(described_class).to receive(:read).and_wrap_original do |original, *arguments| # rubocop:disable RSpec/AnyInstance
      original.call(*arguments).tap { sleep 0.1 }
    end

    edits = [%w[a A], %w[b B]].map do |old_text, new_text|
      Thread.new do
        Chat.connection_pool.with_connection do
          Chat.find(chat.id).with_file_store.to_llm.tools[:edit_file].call(path: 'plan.md', old_text:, new_text:)
        end
      end
    end

    expect(edits.map(&:value)).to all(start_with('Replaced 1'))
    expect(described_class.new(chat).read('plan.md')).to eq("A\nB\n")
  end

  it 'keeps the files an edit wrote, and says so, when a later write fails' do
    tools = chat.with_file_store.to_llm.tools
    files = chat.file_store
    %w[a.md b.md].each do |path|
      files.write(path, 'one')
      tools[:read_file].call(path:)
    end
    allow(files).to receive(:write).and_wrap_original do |original, path, content|
      raise RubyLLM::FileStoreFullError, 'The files are full.' if path == 'b.md'

      original.call(path, content)
    end

    expect(tools[:edit_file].call(edits: [{ path: 'a.md', old_text: 'one', new_text: 'two' },
                                          { path: 'b.md', old_text: 'one', new_text: 'two' }]))
      .to eq(error: 'The files are full. These files already changed: a.md.')
    expect(described_class.new(chat).read('a.md')).to eq('two')
  end

  it 'lets the model change a file it read before the chat was reloaded' do
    chat.with_file_store.file_store.write('notes.md', 'one')
    chat.to_llm.tools[:read_file].call(path: 'notes.md')
    reloaded = Chat.find(chat.id).with_file_store

    expect(reloaded.to_llm.tools[:edit_file].call(path: 'notes.md', old_text: 'one', new_text: 'two'))
      .to eq('Replaced 1 occurrence in notes.md.')
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

  def write_elsewhere(path, content)
    Thread.new do
      Chat.connection_pool.with_connection { described_class.new(Chat.find(chat.id)).write(path, content) }
    end
  end

  it 'locks the chat row before it looks the file up' do
    store
    queries = []
    record = ->(*, payload) { queries << payload[:sql] unless payload[:name] == 'SCHEMA' }

    ActiveSupport::Notifications.subscribed(record, 'sql.active_record') { store.write('a.txt', 'mine') }

    chat_lock = queries.index { |sql| sql.match?(/\A(SELECT .* FROM|UPDATE) ["`]?chats["`]?/) }
    lookup = queries.index { |sql| sql.match?(/\ASELECT .* FROM ["`]?ruby_llm_chat_files["`]?/) }
    expect(chat_lock).to be < lookup
    expect(queries[chat_lock]).to include('FOR UPDATE') unless Chat.connection.adapter_name.match?(/sqlite/i)
  end

  { 'delete' => ->(store) { store.delete('a.txt') },
    'delete_folder' => ->(store) { store.delete_folder('reports') } }.each do |name, deletion|
    it "locks the chat row before #{name} looks the files up" do
      store.write('a.txt', 'mine')
      store.write('reports/q3.md', 'Q3')
      queries = []
      record = ->(*, payload) { queries << payload[:sql] unless payload[:name] == 'SCHEMA' }

      ActiveSupport::Notifications.subscribed(record, 'sql.active_record') { deletion.call(store) }

      chat_lock = queries.index { |sql| sql.match?(/\A(SELECT .* FROM|UPDATE) ["`]?chats["`]?/) }
      lookup = queries.index { |sql| sql.match?(/\ASELECT .* FROM ["`]?ruby_llm_chat_files["`]?/) }
      expect(chat_lock).to be < lookup
    end
  end

  it 'finds a row another process wrote after the query cache saw none' do
    RubyLLM::ActiveRecord::ChatFile.cache do
      expect(store.delete('a.txt')).to be_nil
      write_elsewhere('a.txt', 'theirs').join

      store.write('a.txt', 'mine')
    end

    expect(chat.ruby_llm_chat_files.where(path: 'a.txt').count).to eq(1)
  end

  it 'keeps one row when another process writes the same path at the same time' do
    skip 'SQLite locks the whole database for a write, so writers never interleave' if
      Chat.connection.adapter_name.match?(/sqlite/i)

    other_write = nil
    allow(RubyLLM::ActiveRecord::ChatFile).to receive(:new).and_wrap_original do |original, *arguments, &block|
      allow(RubyLLM::ActiveRecord::ChatFile).to receive(:new).and_call_original
      other_write = write_elsewhere('a.txt', 'theirs')
      other_write.join(0.5)
      original.call(*arguments, &block)
    end

    store.write('a.txt', 'mine')
    other_write.join

    expect(chat.ruby_llm_chat_files.where(path: 'a.txt').count).to eq(1)
    expect(store.read('a.txt')).to eq('theirs')
  end

  it 'matches a folder to delete by its exact case' do
    store.write('reports/a.md', 'lower')
    store.write('Reports/b.md', 'upper')

    expect(store.delete_folder('reports').map(&:path)).to eq(%w[reports/a.md])
    expect(store.list.map(&:path)).to eq(%w[Reports/b.md])
    expect(store.delete('reports')).to be_nil
  end

  it 'reads the underscore and percent sign of a folder literally' do
    store.write('tool_results/a.txt', 'x')
    store.write('toolXresults/b.txt', 'x')
    store.write('100%/c.txt', 'x')
    store.write('100 percent/d.txt', 'x')

    expect(store.list('tool_results').map(&:path)).to eq(['tool_results/a.txt'])
    expect(store.list('100%').map(&:path)).to eq(['100%/c.txt'])
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
      expect(bobs['alice.md']).to be_nil
      expect(store.list.map(&:path)).to eq(%w[report.md shared.md])
    end

    it 'deletes only files of its own owner' do
      store.write('shared.md', 'everyone')

      expect(described_class.new(chat, owner: alice).delete('shared.md')).to be_nil
      expect(store.exist?('shared.md')).to be(true)
    end

    it 'deletes only its own files from a folder' do
      store.write('reports/shared.md', 'for everyone')
      alices = described_class.new(chat, owner: alice)
      alices.write('reports/alice.md', 'private')

      expect(alices.delete_folder('reports').map(&:path)).to eq(%w[reports/alice.md])
      expect(alices.list.map(&:path)).to eq(%w[reports/shared.md])
    end

    it 'still calls a folder with only shared files a folder' do
      store.write('reports/shared.md', 'for everyone')

      expect { described_class.new(chat, owner: alice).delete('reports') }
        .to raise_error(ArgumentError, /is a folder/)
    end
  end

  describe 'a persisted chat with files' do
    it 'keeps its files in Active Storage, or a store it is given' do
      expect(chat.with_file_store).to be(chat)
      expect(chat.file_store).to be_a(described_class)
      expect(chat.file_store.chat).to eq(chat)

      memory = RubyLLM::FileStore::Memory.new
      expect(chat.with_file_store(memory).file_store).to be(memory)
      expect(chat.with_file_store(inline_limit: 5).file_store).to be_a(described_class)
      expect(chat.to_llm.instance_variable_get(:@file_references).inline_limit).to eq(5)
      expect(chat.with_file_store(nil).file_store).to be_nil
      expect(chat.with_file_store(owner: chat).file_store.owner).to eq(chat)
      expect { chat.with_file_store(memory, owner: chat) }.to raise_error(ArgumentError, /owner: applies/)
    end

    it 'takes a folder path or :memory, and refuses an owner with either' do
      root = Dir.mktmpdir('ruby_llm-chat-record-files')

      expect(chat.with_file_store(root)).to be(chat)
      expect(chat.file_store).to be_a(RubyLLM::FileStore::Directory)
      expect(chat.with_file_store(:memory).file_store).to be_a(RubyLLM::FileStore::Memory)
      expect { chat.with_file_store(:memory, owner: chat) }.to raise_error(ArgumentError, /owner: applies/)
      expect { chat.with_file_store(root, owner: chat) }.to raise_error(ArgumentError, /owner: applies/)
    ensure
      FileUtils.rm_rf(root)
    end

    it 'takes an Active Storage store built for the chat and owner' do
      built = described_class.new(chat, owner: chat)

      expect(built).to have_attributes(chat:, owner: chat)
      expect(described_class.new(chat).owner).to be_nil
      expect(chat.with_file_store(built).file_store).to be(built)
      expect(chat.to_llm.file_store).to be(built)
    end

    it 'refuses an Active Storage store for anything but an acts_as_chat record' do
      expect { described_class.new(chat.to_llm) }
        .to raise_error(ArgumentError, /needs an acts_as_chat record, not RubyLLM::Chat/)
    end

    it 'refuses an Active Storage store when Active Storage is not loaded' do
      allow(RubyLLM::ActiveRecord::ChatFile).to receive(:reflect_on_attachment).with(:file).and_return(nil)

      expect { chat.with_file_store }.to raise_error(RubyLLM::ConfigurationError, /needs Active Storage/)
    end

    it "takes an agent's owner lambda, run with the chat in scope" do
      agent = Class.new(RubyLLM::Agent) do
        chat_class Chat
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
