# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::FileStore do
  describe '.path' do
    it 'returns a relative path with forward slashes' do
      expect(described_class.path('./reports//q3.pdf')).to eq('reports/q3.pdf')
      expect(described_class.path('/reports/q3.pdf')).to eq('reports/q3.pdf')
      expect(described_class.path('reports\\q3.pdf')).to eq('reports/q3.pdf')
    end

    it 'refuses empty paths and dot parts' do
      ['', '.', '/', 'a/../b', '..', "a\0b"].each do |name|
        expect { described_class.path(name) }.to raise_error(ArgumentError, /not a path inside/)
      end
    end
  end

  describe '.inside?' do
    it 'treats a prefix as a folder' do
      expect(described_class.inside?('docs/a.md', 'docs')).to be(true)
      expect(described_class.inside?('docs', 'docs')).to be(true)
      expect(described_class.inside?('docsy.md', 'docs')).to be(false)
      expect(described_class.inside?('anything', nil)).to be(true)
      expect(described_class.inside?('anything', '')).to be(true)
    end
  end

  it 'leaves the five operations to subclasses' do
    store = Class.new(described_class).new

    %i[list find read delete].each do |operation|
      arguments = operation == :list ? [] : ['a.txt']
      expect { store.public_send(operation, *arguments) }.to raise_error(NotImplementedError, /must implement/)
    end
    expect { store.write('a.txt', 'x') }.to raise_error(NotImplementedError, /must implement write/)
  end

  it 'detects the content type from the path, and from the content when the path says nothing' do
    png = File.binread(File.expand_path('../fixtures/ruby.png', __dir__))

    expect(described_class.content_type_for('notes.md', '')).to eq('text/markdown')
    expect(described_class.content_type_for('logo', png)).to eq('image/png')
    expect(described_class.content_type_for('blob', '')).to eq('application/octet-stream')
  end

  it 'keeps a bounded number of conversions in memory, forgetting the oldest' do
    stub_const('RubyLLM::FileStore::CACHED_TEXTS', 2)
    store = RubyLLM::FileStore::Memory.new
    files = %w[a b c].map { |name| store.write("#{name}.txt", name) }

    files.first(2).each { |file| store.cache_text(file, "text of #{file.path}") }
    expect(store.cached_text(files.first)).to eq('text of a.txt')

    store.cache_text(files.last, 'text of c.txt')
    expect(files.map { |file| store.cached_text(file) }).to eq([nil, 'text of b.txt', 'text of c.txt'])
  end

  describe RubyLLM::FileStore::Memory do
    let(:store) { described_class.new }

    it_behaves_like 'a file store'

    it 'records a SHA-256 digest and the time of each write' do
      file = store.write('a.txt', 'hello')

      expect(file.digest).to eq(Digest::SHA256.hexdigest('hello'))
      expect(file.updated_at).to be_a(Time)
    end

    it 'hands out copies of the content' do
      store.write('a.txt', 'hello')
      store.read('a.txt') << ' world'

      expect(store.read('a.txt')).to eq('hello')
    end
  end
end
