# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::FileStore::Directory do
  let(:root) { Dir.mktmpdir('ruby_llm-files') }
  let(:store) { described_class.new(root) }

  after { FileUtils.rm_rf(root) }

  it_behaves_like 'a file store'
  it_behaves_like 'a file store that writes under its lock'
  it_behaves_like 'a file store that streams what it writes'

  it 'creates its folder and keeps files in it' do
    folder = File.join(root, 'chats', '42')
    store = described_class.new(folder)
    store.write('notes/plan.md', 'x')

    expect(File.read(File.join(folder, 'notes/plan.md'))).to eq('x')
    expect(store.root).to eq(File.realpath(folder))
  end

  it 'converts new contents even when the size and modification time are unchanged' do
    path = File.join(root, 'report.txt')
    stamp = Time.at(1_700_000_000)
    File.write(path, 'old')
    File.utime(stamp, stamp, path)
    expect(store.text('report.txt')).to eq('old')

    File.write(path, 'new')
    File.utime(stamp, stamp, path)
    expect(store.text('report.txt')).to eq('new')
  end

  it 'writes binary content whatever the default encoding' do
    before = Encoding.default_internal
    Encoding.default_internal = Encoding::UTF_8

    store.write('logo.png', "\x89PNG".b)

    expect(File.binread(File.join(root, 'logo.png'))).to eq("\x89PNG".b)
  ensure
    Encoding.default_internal = before
  end

  it 'never writes through a link at its temporary name' do
    outside = File.join(Dir.mktmpdir('ruby_llm-outside'), 'target')
    File.write(outside, 'safe')
    allow(SecureRandom).to receive(:hex).and_return('fixed')
    File.symlink(outside, File.join(root, ".plan.md.#{Process.pid}.#{Thread.current.object_id}.tmp"))
    File.symlink(outside, File.join(root, '.fixed.tmp'))

    begin
      store.write('plan.md', 'x')
    rescue SystemCallError
      nil
    end

    expect(File.read(outside)).to eq('safe')
  end

  it 'writes through a hidden temporary file, which listings never show' do
    seen = nil
    allow(File).to receive(:rename).and_wrap_original do |original, from, to|
      seen = [File.basename(from), store.list.map(&:path)]
      original.call(from, to)
    end

    store.write('notes/plan.md', 'x')

    expect(seen.first).to match(/\A\.\h{32}\.tmp\z/)
    expect(seen.last).to be_empty
  end

  it 'writes the longest name a filesystem allows' do
    name = 'a' * 255

    expect(store.write(name, 'x').path).to eq(name)
  end

  it 'lists files someone put in the folder, leaving out hidden ones' do
    FileUtils.mkdir_p(File.join(root, 'in', '.git'))
    File.write(File.join(root, 'in', 'a.txt'), 'a')
    File.write(File.join(root, 'in', '.env'), 'SECRET=1')
    File.write(File.join(root, 'in', '.git', 'config'), 'x')

    expect(store.list.map(&:path)).to eq(['in/a.txt'])
    expect(store.list('in/a.txt').map(&:path)).to eq(['in/a.txt'])
  end

  context 'when the folder changes while it is listed' do
    def change_before_lstat(path)
      full = File.join(store.root, path)
      changed = false
      allow(File).to receive(:lstat).and_call_original
      allow(File).to receive(:lstat).with(full).and_wrap_original do |original, *arguments|
        unless changed
          changed = true
          yield full
        end
        original.call(*arguments)
      end
    end

    it 'lists the other files when one is deleted' do
      %w[a.txt b.txt c.txt].each { |name| store.write(name, name) }
      change_before_lstat('b.txt') { |full| File.delete(full) }

      expect(store.list.map(&:path)).to eq(%w[a.txt c.txt])
    end

    it 'lists the other files when a write moves its temporary file into place' do
      %w[a.txt c.txt].each { |name| store.write(name, name) }
      File.write(File.join(store.root, '.b.txt.tmp'), 'b')
      change_before_lstat('.b.txt.tmp') { |full| File.rename(full, File.join(store.root, 'b.txt')) }

      expect(store.list.map(&:path)).to include('a.txt', 'c.txt')
    end

    it 'lists the other files when a folder is replaced by a file' do
      %w[a.txt notes/plan.md].each { |name| store.write(name, name) }
      change_before_lstat('notes/plan.md') do
        FileUtils.rm_r(File.join(store.root, 'notes'))
        File.write(File.join(store.root, 'notes'), 'now a file')
      end

      expect(store.list.map(&:path)).to eq(['a.txt'])
    end

    it 'leaves out a hidden folder that vanishes and comes back' do
      store.write('a.txt', 'a')
      FileUtils.mkdir_p(File.join(store.root, '.cache'))
      File.write(File.join(store.root, '.cache', 'data.txt'), 'cached')
      change_before_lstat('.cache') { raise Errno::ENOENT }

      expect(store.list.map(&:path)).to eq(['a.txt'])
    end
  end

  it 'identifies extensionless media put in the folder after reopening the store' do
    content = File.binread(File.expand_path('../../fixtures/ruby.png', __dir__))
    File.binwrite(File.join(root, 'logo'), content)
    reopened = described_class.new(root)

    expect(reopened.find('logo').content_type).to eq('image/png')
    expect(reopened.list.first.content_type).to eq('image/png')
    expect(reopened.attachment('logo')).to have_attributes(mime_type: 'image/png', content: content)

    FileUtils.cp(File.expand_path('../../fixtures/sample.pdf', __dir__), File.join(root, 'logo'))
    expect(reopened.find('logo').content_type).to eq('application/pdf')
  end

  it 'keeps listing other files when an unknown file cannot be opened' do
    File.write(File.join(root, 'unreadable'), 'data')
    File.write(File.join(root, 'notes.txt'), 'notes')
    allow(File).to receive(:open).and_call_original
    allow(File).to receive(:open).with(File.join(store.root, 'unreadable'), anything).and_raise(Errno::EACCES)

    expect(store.list.map { |file| [file.path, file.content_type] }).to eq(
      [['notes.txt', 'text/plain'], ['unreadable', 'application/octet-stream']]
    )
    expect(store.find('unreadable').content_type).to eq('application/octet-stream')
  end

  it 'uses the file name without opening files whose type is known' do
    store.write('notes.txt', 'notes')
    allow(File).to receive(:open).and_call_original

    expect(store.find('notes.txt').content_type).to eq('text/plain')
    expect(store.list.first.content_type).to eq('text/plain')
    expect(File).not_to have_received(:open)
  end

  it 'sniffs unknown types without reading the whole file into a string' do
    content = File.binread(File.expand_path('../../fixtures/ruby.png', __dir__))
    File.binwrite(File.join(root, 'logo'), content)
    allow(File).to receive(:binread).and_call_original

    expect(store.find('logo').content_type).to eq('image/png')
    expect(File).not_to have_received(:binread)
  end

  it 'never follows symbolic links' do
    outside = Dir.mktmpdir('ruby_llm-outside')
    File.write(File.join(outside, 'secret.txt'), 'secret')
    File.symlink(File.join(outside, 'secret.txt'), File.join(root, 'link.txt'))
    File.symlink(outside, File.join(root, 'folder'))

    expect(store.list.map(&:path)).to be_empty
    expect(store['link.txt']).to be_nil
    expect { store.read('link.txt') }.to raise_error(RubyLLM::FileNotFoundError)
    expect { store.read('folder/secret.txt') }.to raise_error(ArgumentError, /not inside/)
  ensure
    FileUtils.rm_rf(outside)
  end

  it 'never follows a link to a hidden folder inside it' do
    FileUtils.mkdir_p(File.join(root, '.private'))
    File.write(File.join(root, '.private', 'secret.txt'), 'secret')
    File.symlink(File.join(root, '.private'), File.join(root, 'alias'))

    expect { store.read('alias/secret.txt') }.to raise_error(ArgumentError, /not inside/)
    expect { store['alias/secret.txt'] }.to raise_error(ArgumentError, /not inside/)
    expect { store.delete('alias/secret.txt') }.to raise_error(ArgumentError, /not inside/)
    expect(File.read(File.join(root, '.private', 'secret.txt'))).to eq('secret')
  end

  it 'never follows a link to another folder inside it' do
    store.write('reports/q3.txt', 'q3')
    File.symlink(File.join(root, 'reports'), File.join(root, 'shortcut'))

    expect { store.read('shortcut/q3.txt') }.to raise_error(ArgumentError, /not inside/)
    expect { store.write('shortcut/q4.txt', 'q4') }.to raise_error(ArgumentError, /not inside/)
    expect(store.list.map(&:path)).to eq(['reports/q3.txt'])
  end

  it 'replaces a link to a file that stands where a folder goes when writing' do
    store.write('target.txt', 'target')
    File.symlink(File.join(root, 'target.txt'), File.join(root, 'notes'))

    store.write('notes/plan.md', 'plan')

    expect(store.read('notes/plan.md')).to eq('plan')
    expect(store.read('target.txt')).to eq('target')
  end

  it 'does not sniff a file replaced by a symbolic link before opening it' do
    outside = Tempfile.new('ruby_llm-outside')
    outside.binmode
    outside.write(File.binread(File.expand_path('../../fixtures/ruby.png', __dir__)))
    outside.flush
    store.write('logo', 'data')
    full = File.join(store.root, 'logo')
    allow(File).to receive(:open).and_call_original
    allow(File).to receive(:open).with(full, anything).and_wrap_original do |original, *arguments, &block|
      File.delete(full)
      File.symlink(outside.path, full)
      original.call(*arguments, &block)
    end

    expect(store.find('logo').content_type).to eq('application/octet-stream')
  ensure
    outside&.close!
  end

  it 'does not wait on a file replaced by a named pipe before opening it', skip: !File.respond_to?(:mkfifo) do
    store.write('pipe', 'data')
    full = File.join(store.root, 'pipe')
    allow(File).to receive(:open).and_call_original
    allow(File).to receive(:open).with(full, anything).and_wrap_original do |original, *arguments, &block|
      File.delete(full)
      File.mkfifo(full)
      original.call(*arguments, &block)
    end

    expect(Timeout.timeout(5) { store.find('pipe').content_type }).to eq('application/octet-stream')
  end

  it 'replaces a link in the way when writing, without touching its target' do
    outside = Dir.mktmpdir('ruby_llm-outside')
    File.symlink(outside, File.join(root, 'folder'))
    File.symlink(File.join(outside, 'target.txt'), File.join(root, 'file.txt'))

    store.write('file.txt', 'mine')

    expect(File.symlink?(File.join(root, 'file.txt'))).to be(false)
    expect(File.exist?(File.join(outside, 'target.txt'))).to be(false)
    expect { store.write('folder/a.txt', 'x') }.to raise_error(ArgumentError, /not inside/)
  ensure
    FileUtils.rm_rf(outside)
  end

  it 'refuses hidden paths' do
    expect { store.write('.env', 'x') }.to raise_error(ArgumentError, /not inside/)
  end

  it 'replaces a file with a folder' do
    store.write('a', 'file')
    store.write('a/b.txt', 'inside')

    expect(store.list.map(&:path)).to eq(['a/b.txt'])
  end

  it 'refuses to write over a folder, keeping what is in it' do
    store.write('a/b.txt', 'inside')
    FileUtils.mkdir_p(File.join(root, 'a/.git'))
    File.write(File.join(root, 'a/.git/HEAD'), 'hidden')

    expect { store.write('a', 'file') }.to raise_error(ArgumentError, 'a is a folder, not a file')

    expect(store.read('a/b.txt')).to eq('inside')
    expect(File.read(File.join(root, 'a/.git/HEAD'))).to eq('hidden')
  end

  it 'refuses to write over an empty folder' do
    FileUtils.mkdir_p(File.join(root, 'empty'))

    expect { store.write('empty', 'file') }.to raise_error(ArgumentError, /is a folder/)
  end

  it 'replaces a link to a folder, leaving the folder' do
    outside = Dir.mktmpdir('ruby_llm-outside')
    File.symlink(outside, File.join(root, 'link'))

    store.write('link', 'mine')

    expect(store.read('link')).to eq('mine')
    expect(Dir.exist?(outside)).to be(true)
  ensure
    FileUtils.rm_rf(outside)
  end

  it 'refuses to delete an empty folder with delete, and removes it with delete_folder' do
    FileUtils.mkdir_p(File.join(root, 'empty'))

    expect { store.delete('empty') }.to raise_error(ArgumentError, /empty is a folder/)
    expect(store.delete_folder('empty')).to eq([])
    expect(File.exist?(File.join(root, 'empty'))).to be(false)
  end

  it 'deletes a link in a folder without touching its target' do
    outside = Dir.mktmpdir('ruby_llm-outside')
    File.write(File.join(outside, 'keep.txt'), 'safe')
    store.write('reports/q3.md', 'Q3')
    File.symlink(outside, File.join(root, 'reports', 'link'))

    expect(store.delete_folder('reports').map(&:path)).to eq(%w[reports/q3.md])
    expect(File.read(File.join(outside, 'keep.txt'))).to eq('safe')
    expect(File.exist?(File.join(root, 'reports'))).to be(false)
  ensure
    FileUtils.rm_rf(outside)
  end

  it 'leaves a link to a folder, and its target, alone' do
    outside = Dir.mktmpdir('ruby_llm-outside')
    File.write(File.join(outside, 'keep.txt'), 'safe')
    File.symlink(outside, File.join(root, 'link'))

    expect(store.delete_folder('link')).to eq([])
    expect(File.read(File.join(outside, 'keep.txt'))).to eq('safe')
  ensure
    FileUtils.rm_rf(outside)
  end

  it 'refuses to delete a hidden folder' do
    FileUtils.mkdir_p(File.join(root, '.git'))

    expect { store.delete_folder('.git') }.to raise_error(ArgumentError, /not inside/)
    expect(File.exist?(File.join(root, '.git'))).to be(true)
  end

  it 'shortens an attachment name too long for the file system, keeping its extension and number' do
    files = %w[one two].map do |content|
      store.store_attachment(RubyLLM::Attachment.new(StringIO.new(content), filename: "#{'日' * 90}.txt"))
    end

    expect(files.map(&:path)).to eq(["#{'日' * 83}.txt", "#{'日' * 83}-2.txt"])
    expect(files.map { |file| store.read(file.path) }).to eq(%w[one two])
  end

  it 'shortens an attachment name that is one long extension' do
    file = store.store_attachment(RubyLLM::Attachment.new(StringIO.new('x'), filename: "a.#{'b' * 300}"))

    expect(file.path).to eq("a.#{'b' * 253}")
  end
end
