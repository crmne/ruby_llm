# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::FileStore::Directory do
  let(:root) { Dir.mktmpdir('ruby_llm-files') }
  let(:store) { described_class.new(root) }

  after { FileUtils.rm_rf(root) }

  it_behaves_like 'a file store'

  it 'creates its folder and keeps files in it' do
    folder = File.join(root, 'chats', '42')
    store = described_class.new(folder)
    store.write('notes/plan.md', 'x')

    expect(File.read(File.join(folder, 'notes/plan.md'))).to eq('x')
    expect(store.root).to eq(File.realpath(folder))
  end

  it 'lists files someone put in the folder, leaving out hidden ones' do
    FileUtils.mkdir_p(File.join(root, 'in', '.git'))
    File.write(File.join(root, 'in', 'a.txt'), 'a')
    File.write(File.join(root, 'in', '.env'), 'SECRET=1')
    File.write(File.join(root, 'in', '.git', 'config'), 'x')

    expect(store.list.map(&:path)).to eq(['in/a.txt'])
    expect(store.list('in/a.txt').map(&:path)).to eq(['in/a.txt'])
  end

  it 'never follows symbolic links' do
    outside = Dir.mktmpdir('ruby_llm-outside')
    File.write(File.join(outside, 'secret.txt'), 'secret')
    File.symlink(File.join(outside, 'secret.txt'), File.join(root, 'link.txt'))
    File.symlink(outside, File.join(root, 'folder'))

    expect(store.list.map(&:path)).to be_empty
    expect(store.find('link.txt')).to be_nil
    expect { store.read('link.txt') }.to raise_error(RubyLLM::FileNotFoundError)
    expect { store.read('folder/secret.txt') }.to raise_error(ArgumentError, /not inside/)
  ensure
    FileUtils.rm_rf(outside)
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

  it 'replaces a file with a folder and a folder with a file' do
    store.write('a', 'file')
    store.write('a/b.txt', 'inside')
    expect(store.list.map(&:path)).to eq(['a/b.txt'])

    store.write('a', 'file again')
    expect(store.list.map(&:path)).to eq(['a'])
  end
end
