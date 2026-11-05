# frozen_string_literal: true

# What every FileStore does, run against each store in the box. The
# including group defines +store+.
RSpec.shared_examples 'a file store' do
  it 'writes, finds, reads, and deletes a file' do
    file = store.write('notes/plan.md', "# Plan\n")

    expect(file).to have_attributes(path: 'notes/plan.md', byte_size: 7, content_type: 'text/markdown',
                                    filename: 'plan.md')
    expect(store.find('notes/plan.md')).to have_attributes(path: 'notes/plan.md', byte_size: 7)
    expect(store['notes/plan.md']).to have_attributes(path: 'notes/plan.md', byte_size: 7)
    expect(store.read('notes/plan.md')).to eq("# Plan\n")
    expect(store.read('notes/plan.md').encoding).to eq(Encoding::BINARY)
    expect(store).to exist('notes/plan.md')
    expect(store.delete('notes/plan.md')).to have_attributes(path: 'notes/plan.md')
    expect(store['notes/plan.md']).to be_nil
    expect(store.exist?('notes/plan.md')).to be(false)
    expect(store.delete('notes/plan.md')).to be_nil
  end

  it 'raises FileNotFoundError from find, and returns nil from [], for a missing file' do
    expect { store.find('missing.md') }.to raise_error(RubyLLM::FileNotFoundError, 'No file at missing.md')
    expect(store['missing.md']).to be_nil
  end

  it 'refuses to delete a folder with delete' do
    store.write('reports/q3.md', 'Q3')

    expect { store.delete('reports') }.to raise_error(ArgumentError, /reports is a folder.*delete_folder/)
    expect(store.exist?('reports/q3.md')).to be(true)
  end

  it 'deletes a folder and returns its files with delete_folder' do
    store.write('reports/q3.md', 'Q3')
    store.write('reports/2026/q4.md', 'Q4')
    store.write('reportsy.md', 'beside the folder')

    expect(store.delete_folder('reports').map(&:path)).to eq(%w[reports/2026/q4.md reports/q3.md])
    expect(store.list.map(&:path)).to eq(%w[reportsy.md])
    expect(store.delete_folder('reports')).to eq([])
  end

  it 'refuses to delete a file with delete_folder' do
    store.write('notes.md', 'hello')

    expect { store.delete_folder('notes.md') }.to raise_error(ArgumentError, /notes.md is a file.*delete/)
    expect(store.exist?('notes.md')).to be(true)
  end

  it 'refuses to delete everything at once' do
    expect { store.delete_folder('.') }.to raise_error(ArgumentError, /not a path inside/)
  end

  it 'remembers the digest of what the model read at a path' do
    store.write('notes.md', 'hello')
    expect(store.read_digest('notes.md')).to be_nil

    store.record_read('notes.md', 'abc123')

    expect(store.read_digest('notes.md')).to eq('abc123')
    expect(store.read_digest('./notes.md')).to eq('abc123')
  end

  it 'runs a block under its lock, reentrantly, and returns its value' do
    expect(store.with_lock { store.with_lock { 42 } }).to eq(42)
  end

  it 'replaces a file written twice' do
    store.write('a.txt', 'one')
    store.write('a.txt', 'three')

    expect(store.read('a.txt')).to eq('three')
    expect(store.list.map(&:path)).to eq(['a.txt'])
  end

  it 'writes an IO and keeps a given content type' do
    file = store.write('data', StringIO.new('{"a":1}'), content_type: 'application/json')

    expect(file.content_type).to eq('application/json')
    expect(store.read('data')).to eq('{"a":1}')
  end

  it 'keeps binary content byte for byte' do
    png = File.binread(File.expand_path('../fixtures/ruby.png', __dir__))
    store.write('images/ruby.png', png)

    expect(store.read('images/ruby.png')).to eq(png.b)
    expect(store.find('images/ruby.png').content_type).to eq('image/png')
  end

  { 'ruby.png' => 'image/png', 'sample.pdf' => 'application/pdf' }.each do |fixture, content_type|
    it "recognizes extensionless #{content_type} after writing and listing it" do
      content = File.binread(File.expand_path("../fixtures/#{fixture}", __dir__))
      file = store.write('media', content, content_type:)

      expect(file.content_type).to eq(content_type)
      expect(store.find('media').content_type).to eq(content_type)
      expect(store.list.first.content_type).to eq(content_type)
      expect(store.attachment('media')).to have_attributes(mime_type: content_type, content: content)
    end
  end

  it 'lists files by path, or those inside a folder' do
    store.write('b.txt', 'b')
    store.write('docs/a.md', 'a')
    store.write('docs/deep/c.md', 'c')
    store.write('docsy.txt', 'not inside docs')

    expect(store.list.map(&:path)).to eq(%w[b.txt docs/a.md docs/deep/c.md docsy.txt])
    expect(store.list('docs').map(&:path)).to eq(%w[docs/a.md docs/deep/c.md])
    expect(store.list('./docs/').map(&:path)).to eq(%w[docs/a.md docs/deep/c.md])
    expect(store.list('missing')).to eq([])
    expect(store.map(&:path)).to eq(store.list.map(&:path))
  end

  it 'normalizes paths and refuses paths outside the store' do
    store.write('./notes//plan.md', 'x')

    expect(store.read('notes/plan.md')).to eq('x')
    expect { store.write('../escape.txt', 'x') }.to raise_error(ArgumentError, /not a path inside/)
    expect { store.read('notes/../../etc/passwd') }.to raise_error(ArgumentError)
  end

  it 'raises FileNotFoundError for a missing file' do
    expect { store.read('missing.txt') }.to raise_error(RubyLLM::FileNotFoundError, /missing.txt/)
    expect { store.text('missing.txt') }.to raise_error(RubyLLM::FileNotFoundError)
  end

  it 'reads text through the converters and keeps the conversion' do
    store.write('notes/plan.md', "# Plan\n\nShip the ORCHID-97 release")
    allow(RubyLLM::FileStore::Converters).to receive(:convert).and_call_original

    2.times { expect(store.text('notes/plan.md')).to include('ORCHID-97') }
    expect(RubyLLM::FileStore::Converters).to have_received(:convert).once
  end

  it 'converts a file again once it changes' do
    store.write('notes.md', 'first')
    expect(store.text('notes.md')).to eq('first')

    store.write('notes.md', 'second version')
    expect(store.text('notes.md')).to eq('second version')
  end

  it 'returns a file as an attachment' do
    store.write('notes.md', 'hello')

    attachment = store.attachment('notes.md')
    expect(attachment).to have_attributes(filename: 'notes.md', mime_type: 'text/markdown', content: 'hello')
  end

  it 'keeps an attachment under its name, reusing the same content and numbering other content' do
    first = store.store_attachment(RubyLLM::Attachment.new(StringIO.new('one'), filename: 'report.txt'))
    again = store.store_attachment(RubyLLM::Attachment.new(StringIO.new('one'), filename: 'report.txt'))
    other = store.store_attachment(RubyLLM::Attachment.new(StringIO.new('two'), filename: 'report.txt'))
    third = store.store_attachment(RubyLLM::Attachment.new(StringIO.new('three'), filename: '../report.txt'))

    expect([first, again, other, third].map(&:path)).to eq(%w[report.txt report.txt report-2.txt report-3.txt])
    expect(store.read('report-2.txt')).to eq('two')
  end

  it 'yields only the attachments it writes' do
    written = []
    2.times do
      store.store_attachment(RubyLLM::Attachment.new(StringIO.new('one'), filename: 'a.txt')) { written << _1.path }
    end

    expect(written).to eq(['a.txt'])
  end
end

# Stores that keep their lock in the process, Memory and Directory, take
# it for every write and delete, so a direct write never lands between a
# tool's check and its write.
RSpec.shared_examples 'a file store that writes under its lock' do
  it 'waits for its lock to write or delete' do
    store.write('notes.md', 'one')
    locked = Queue.new
    holder = Thread.new do
      store.with_lock do
        locked << true
        sleep 0.2
        store.write('notes.md', 'held')
      end
    end
    locked.pop
    store.write('notes.md', 'waited')
    holder.join

    expect(store.read('notes.md')).to eq('waited')
  end
end
