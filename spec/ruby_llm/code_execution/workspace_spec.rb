# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::CodeExecution::Workspace do
  def attachment(content, filename = 'report.txt')
    RubyLLM::Attachment.new(StringIO.new(content), filename:)
  end

  def copied(*attachments)
    described_class.open do |workspace|
      workspace.copy_in(attachments)
      Dir.children(workspace.inputs).sort.to_h do |name|
        [name, File.read(File.join(workspace.inputs, name))]
      end
    end
  end

  it "copies a store's files to the inputs at their paths" do
    store = RubyLLM::FileStore::Memory.new
    files = [store.write('data/a.csv', 'nested'), store.write('b.csv', 'top')]

    described_class.open do |workspace|
      workspace.copy_stored_inputs(store, files)

      expect(File.read(File.join(workspace.directory, 'attachments/data/a.csv'))).to eq('nested')
      expect(File.read(File.join(workspace.directory, 'attachments/b.csv'))).to eq('top')
    end
  end

  it 'keeps both files that share a name, the newest under that name' do
    expect(copied(attachment('first'), attachment('second')))
      .to eq('report.txt' => 'second', 'report-2.txt' => 'first')
  end

  it 'numbers past a name already taken' do
    files = [attachment('a'), attachment('b'), attachment('c', 'report-2.txt')]

    expect(copied(*files)).to eq('report-2.txt' => 'c', 'report.txt' => 'b', 'report-3.txt' => 'a')
  end

  it 'numbers past a name that differs only in case' do
    files = [attachment('a'), attachment('b'), attachment('c', 'REPORT-2.TXT')]

    expect(copied(*files)).to eq('REPORT-2.TXT' => 'c', 'report-3.txt' => 'a', 'report.txt' => 'b')
  end

  it 'reports the name a file ended up with, sharing one for equal content' do
    same = attachment('x', 'Report.txt')
    twin = attachment('x', 'report.txt')

    expect(described_class.input_names([same, twin]).values).to eq(%w[report.txt report.txt])
  end

  it 'never numbers a file into a folder another input needs' do
    files = [attachment('a'), attachment('b'), attachment('c', 'report-2.txt/part')]

    expect { described_class.open { |workspace| workspace.copy_in(files) } }.not_to raise_error
    expect(described_class.input_names(files).values).to contain_exactly('report-2.txt/part', 'report.txt',
                                                                         'report-3.txt')
  end

  it 'leaves provider files out of the names' do
    file = attachment('a')
    allow(file).to receive(:provider_file?).and_return(true)

    expect(described_class.input_names([file])).to be_empty
  end

  it 'numbers a file with no extension' do
    expect(copied(attachment('a', 'notes'), attachment('b', 'notes'))).to eq('notes' => 'b', 'notes-2' => 'a')
  end

  it 'copies the same file attached twice once' do
    expect(copied(attachment('same'), attachment('same'))).to eq('report.txt' => 'same')
  end

  describe 'mounts in a store folder' do
    let(:root) { File.realpath(Dir.mktmpdir('ruby_llm-store')) }
    let(:mount) { File.realpath(Dir.mktmpdir('ruby_llm-mount')) }
    let(:link) { File.join(root, 'shared/data') }

    after { FileUtils.rm_rf([root, mount]) }

    def workspaces(count)
      Array.new(count) { described_class.new(Dir.mktmpdir('ruby_llm-workspace'), attachments: false) }
    end

    it 'keeps a link until the last run using it ends, then removes it with its folders' do
      first, second = workspaces(2)
      expect(first.mount({ 'shared/data' => mount }, into: root)).to eq([mount])
      expect(second.mount({ 'shared/data' => mount }, into: root)).to eq([mount])

      first.remove_links
      expect(File.symlink?(link)).to be(true)

      second.remove_links
      expect(Dir.children(root)).to be_empty
      expect(described_class.const_get(:STORE_RUNS)).not_to have_key(root)
    end

    it 'mounts into a folder the store already has' do
      FileUtils.mkdir_p(File.join(root, 'shared'))
      workspace = workspaces(1).first

      expect(workspace.mount({ 'shared/data' => mount }, into: root)).to eq([mount])
      workspace.remove_links

      expect(Dir.children(root)).to eq(['shared'])
    end

    it 'leaves out a mount where a link leads somewhere else' do
      FileUtils.mkdir_p(File.dirname(link))
      File.symlink(root, link)
      workspace = workspaces(1).first

      expect(workspace.mount({ 'shared/data' => mount }, into: root)).to be_empty
      expect(workspace.unmounted).to eq(['shared/data'])
      workspace.remove_links
    end

    it 'keeps mounts in its own directory out of the store runs' do
      workspace = workspaces(1).first
      workspace.mount({ 'data' => mount })

      expect { workspace.mount({ 'data' => mount }) }.to raise_error(Errno::EEXIST)
      expect(described_class.const_get(:STORE_RUNS)).not_to have_key(workspace.directory)
    end

    it 'leaves a link it did not place' do
      FileUtils.mkdir_p(File.dirname(link))
      File.symlink(mount, link)
      workspace = workspaces(1).first

      expect(workspace.mount({ 'shared/data' => mount }, into: root)).to eq([mount])
      expect(workspace.unmounted).to be_empty
      workspace.remove_links

      expect(File.symlink?(link)).to be(true)
    end

    it 'keeps its hands off a link the code replaced' do
      workspace = workspaces(1).first
      workspace.mount({ 'shared/data' => mount }, into: root)
      File.delete(link)
      File.symlink(root, link)

      workspace.remove_links

      expect(File.readlink(link)).to eq(root)
    end

    it 'leaves a later run alone once the earlier ones have ended' do
      first, second = workspaces(2)
      first.mount({ 'shared/data' => mount }, into: root)
      first.remove_links
      second.mount({ 'shared/data' => mount }, into: root)

      expect(File.readlink(link)).to eq(mount)
      second.remove_links
    end

    it 'does nothing for a run that placed nothing in a store' do
      expect { workspaces(1).first.remove_links }.not_to raise_error
      expect(described_class.const_get(:STORE_RUNS)).not_to have_key(nil)
    end

    it 'never places a mount through a link to somewhere else' do
      outside = File.realpath(Dir.mktmpdir('ruby_llm-outside'))
      FileUtils.mkdir_p(File.join(outside, 'b'))
      File.symlink(outside, File.join(root, 'a'))
      workspace = workspaces(1).first

      expect(workspace.mount({ 'a/b/c' => mount }, into: root)).to be_empty

      expect(Dir.children(File.join(outside, 'b'))).to be_empty
      expect(workspace.unmounted).to eq(['a/b/c'])
      workspace.remove_links
    ensure
      FileUtils.rm_rf(outside)
    end

    it 'does not count a link reached through a link as already there' do
      outside = File.realpath(Dir.mktmpdir('ruby_llm-outside'))
      File.symlink(mount, File.join(outside, 'c'))
      File.symlink(outside, File.join(root, 'a'))
      workspace = workspaces(1).first

      expect(workspace.mount({ 'a/c' => mount }, into: root)).to be_empty
      workspace.remove_links
    ensure
      FileUtils.rm_rf(outside)
    end
  end

  it 'skips an oversized changed copy without reading it' do
    described_class.open do |workspace|
      path = File.join(workspace.directory, 'big.bin')
      File.binwrite(path, 'x' * 200)
      allow(RubyLLM::FileStore).to receive(:digest).and_call_original

      files, skipped = workspace.outputs(max_files: 10, max_size: 100,
                                         unchanged: { 'big.bin' => [10, 'copied digest'] })

      expect(RubyLLM::FileStore).not_to have_received(:digest)
      expect(files).to be_empty
      expect(skipped).to eq(['big.bin (larger than 100 bytes)'])
    end
  end

  it 'leaves out an oversized copy the run did not change' do
    described_class.open do |workspace|
      content = 'x' * 200
      File.binwrite(File.join(workspace.directory, 'big.bin'), content)
      unchanged = { 'big.bin' => [200, RubyLLM::FileStore.digest(content)] }

      expect(workspace.outputs(max_files: 10, max_size: 100, unchanged:)).to eq([[], []])
    end
  end

  it 'returns a copy the run changed without changing its size' do
    described_class.open do |workspace|
      File.binwrite(File.join(workspace.directory, 'a.txt'), 'new')
      unchanged = { 'a.txt' => [3, RubyLLM::FileStore.digest('old')] }

      files, = workspace.outputs(max_files: 10, max_size: 100, unchanged:)

      expect(files.map(&:filename)).to eq(['a.txt'])
    end
  end

  it 'opens the files a run wrote instead of reading them' do
    described_class.open do |workspace|
      File.binwrite(File.join(workspace.directory, 'a.bin'), 'x' * 200)

      files, = workspace.outputs(max_files: 10, max_size: 1000)

      expect(files.map(&:source)).to all(be_a(File))
      expect(files.first.content).to eq('x' * 200)
    end
  end

  it 'closes the files it opened when the run ends' do
    files = described_class.open do |workspace|
      File.binwrite(File.join(workspace.directory, 'a.bin'), 'x')
      workspace.outputs(max_files: 10, max_size: 100).first
    end

    expect(files.map(&:source)).to all(be_closed)
  end

  it 'raises what stopped a workspace from being made' do
    allow(FileUtils).to receive(:mkdir_p).and_raise(Errno::EACCES)

    expect { described_class.open { nil } }.to raise_error(Errno::EACCES)
  end

  it 'compares a copy it gave the run without reading it into memory' do
    described_class.open do |workspace|
      File.binwrite(File.join(workspace.directory, 'a.txt'), 'old')
      unchanged = { 'a.txt' => [3, RubyLLM::FileStore.digest('old')] }
      allow(RubyLLM::FileStore).to receive(:digest).and_call_original

      expect(workspace.outputs(max_files: 10, max_size: 100, unchanged:)).to eq([[], []])
      expect(RubyLLM::FileStore).to have_received(:digest).with(an_instance_of(File))
    end
  end

  it 'reports an output whose name is not valid UTF-8 as skipped' do
    described_class.open do |workspace|
      File.binwrite(File.join(workspace.directory, "bad\xFFname.txt".b), 'x')
      File.binwrite(File.join(workspace.directory, 'kept.txt'), 'y')

      files, skipped = workspace.outputs(max_files: 10, max_size: 100)

      expect(files.map(&:filename)).to eq(['kept.txt'])
      expect(skipped).to eq(["bad\uFFFDname.txt (name is not valid UTF-8)"])
    end
  end
end
