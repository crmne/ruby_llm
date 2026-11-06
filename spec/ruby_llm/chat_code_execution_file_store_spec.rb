# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Chat do
  include_context 'with configured RubyLLM'

  let(:cache_dir) { Dir.mktmpdir('ruby_llm-packages-spec') }
  let(:seen) { {} }
  let(:context) do
    RubyLLM.context do |config|
      config.sandbox = sandbox
      config.package_cache_dir = cache_dir
    end
  end

  after { FileUtils.rm_rf(cache_dir) }

  def files_in(directory)
    Dir.glob('**/*', base: directory).select { |path| File.file?(File.join(directory, path)) }.sort
  end

  def run_code(**arguments)
    chat.tools[:run_code].call(language: 'ruby', code: 'puts 1', **arguments)
  end

  context 'with a store without a folder' do
    let(:sandbox) do
      FakeSandbox.new do |run|
        directory = run[:directory]
        seen[:files] = files_in(directory)
        attachments = File.join(directory, 'attachments')
        seen[:attachments] = files_in("#{attachments}/").to_h { |path| [path, File.read(File.join(attachments, path))] }
        seen[:templates] = File.symlink?(File.join(directory, 'templates'))
        File.write(File.join(directory, 'notes.md'), 'changed') if File.exist?(File.join(directory, 'notes.md'))
        FileUtils.mkdir_p(File.join(directory, 'out'))
        File.write(File.join(directory, 'out/chart.svg'), '<svg/>')
        FileUtils.rm_f(File.join(directory, 'keep.txt'))
        FakeSandbox.result(stdout: 'done')
      end
    end
    let(:chat) { context.chat(model: model_for(:openai), provider: :openai).with_code_execution.with_file_store }

    before do
      chat.file_store.write('notes.md', 'original')
      chat.file_store.write('keep.txt', 'kept')
      chat.file_store.write('data/a.csv', "a,b\n")
      chat.file_store.write('data/b.csv', "c,d\n")
    end

    def attach(name, content)
      file = RubyLLM::Attachment.new(StringIO.new(content), filename: name)
      chat.add_message(role: :user, content: 'Here', attachments: [file])
    end

    it 'copies in nothing unless the model names files, and has an empty attachments folder' do
      run_code

      expect(seen[:files]).to be_empty
      expect(seen[:attachments]).to be_empty
    end

    it "gives every run the conversation's files in attachments, and only those" do
      attach('sales.csv', "a,b\n")

      run_code

      expect(seen[:attachments]).to eq('sales.csv' => "a,b\n")
      expect(seen[:files]).to be_empty
      expect(chat.file_store.read('sales.csv')).to eq("a,b\n")
    end

    it 'finds an attachment at the path list_files shows, as it is in the store now' do
      attach('sales.csv', 'first')
      attach('sales.csv', 'second')
      run_code
      expect(seen[:attachments]).to eq('sales.csv' => 'first', 'sales-2.csv' => 'second')
      expect(chat.file_store.list.map(&:path)).to include('sales.csv', 'sales-2.csv')

      chat.file_store.write('sales.csv', 'edited')
      chat.file_store.delete('sales-2.csv')
      run_code

      expect(seen[:attachments]).to eq('sales.csv' => 'edited')
    end

    it 'reports only what the run wrote, not the attachments it was given' do
      written = []
      chat.after_file_write { |file| written << file.path }
      attach('sales.csv', "a,b\n")

      report = JSON.parse(run_code)

      expect(report['files']).to eq(%w[out/chart.svg])
      expect(written).to eq(%w[sales.csv out/chart.svg])
    end

    it 'leaves out a file only read_file showed' do
      call = RubyLLM::ToolCall.new(id: 'read_1', name: 'read_file', arguments: { 'path' => 'private.txt' })
      chat.add_message(role: :assistant, content: '', tool_calls: { call.id => call })
      shown = RubyLLM::Attachment.new(StringIO.new('someone else'), filename: 'shown.txt')
      chat.add_message(role: :tool, content: 'read', tool_call_id: call.id, attachments: [shown])

      run_code

      expect(seen[:attachments]).to be_empty
      expect(chat.file_store.exist?('shown.txt')).to be(false)
    end

    it 'tells a read_file result from a question when the read has no id' do
      attach('sales.csv', "a,b\n")
      call = RubyLLM::ToolCall.new(id: nil, name: 'read_file', arguments: { 'path' => 'private.txt' })
      chat.add_message(role: :assistant, content: '', tool_calls: { 'read' => call })
      shown = RubyLLM::Attachment.new(StringIO.new('someone else'), filename: 'shown.txt')
      chat.add_message(role: :tool, content: 'read', attachments: [shown])

      run_code

      expect(seen[:attachments].keys).to eq(%w[sales.csv])
    end

    it 'runs without an attachment the store cannot keep' do
      attach('sales.csv', "a,b\n")
      allow(chat.file_store).to receive(:store_attachment).and_raise(RubyLLM::FileStoreFullError, 'full')
      allow(RubyLLM.logger).to receive(:warn)

      expect(JSON.parse(run_code)).to include('stdout' => 'done')
      expect(seen[:attachments]).to be_empty
      expect(RubyLLM.logger).to have_received(:warn).once
    end

    it 'refuses a name in the attachments folder, which every run has' do
      attach('sales.csv', "a,b\n")

      expect(run_code(files: ['attachments/sales.csv'])[:error])
        .to eq('attachments/sales.csv is in the read-only folder attachments, which every run has')
      expect(run_code(files: ['attachments'])[:error]).to include('read-only folder attachments')
      expect(seen).to be_empty
    end

    it 'copies in the files named, and every file in a folder named' do
      run_code(files: %w[notes.md keep.txt data])

      expect(seen[:files]).to eq(%w[data/a.csv data/b.csv keep.txt notes.md])
    end

    it 'saves what the run wrote or changed, lists the paths, and returns no attachments' do
      written = []
      chat.after_file_write { |file| written << file.path }

      result = run_code(files: %w[notes.md keep.txt data])

      expect(result).to be_a(String)
      expect(JSON.parse(result)).to include('stdout' => 'done', 'files' => %w[notes.md out/chart.svg])
      expect(chat.file_store.read('notes.md')).to eq('changed')
      expect(chat.file_store.read('out/chart.svg')).to eq('<svg/>')
      expect(chat.file_store.read('keep.txt')).to eq('kept')
      expect(written).to eq(%w[notes.md out/chart.svg])
    end

    it 'tells the model when a run changed a file it had read' do
      chat.tools[:read_file].call(path: 'notes.md')
      chat.tools[:read_file].call(path: 'keep.txt')

      report = JSON.parse(run_code(files: %w[notes.md keep.txt]))

      expect(report['read_again']).to eq('This run changed files you had read: notes.md. Read them before ' \
                                         'you edit them.')
    end

    it 'says nothing about files the model has not read' do
      expect(JSON.parse(run_code(files: %w[notes.md]))).not_to have_key('read_again')
    end

    it 'saves what fits when the store fills up, and tells the model what was left out' do
      written = []
      chat.after_file_write { |file| written << file.path }
      store = chat.file_store
      original = store.method(:write)
      allow(store).to receive(:write) do |path, content, **options|
        raise RubyLLM::FileStoreFullError, 'The files are full.' if path == 'out/chart.svg'

        original.call(path, content, **options)
      end

      result = nil
      expect { result = run_code(files: %w[notes.md]) }.not_to raise_error

      expect(JSON.parse(result)).to include('stdout' => 'done', 'exit_code' => 0, 'files' => %w[notes.md],
                                            'unsaved_files' => %w[out/chart.svg],
                                            'files_error' => 'The files are full.')
      expect(JSON.parse(result)).not_to have_key('error')
      expect(written).to eq(%w[notes.md])
      expect(store.exist?('out/chart.svg')).to be(false)
    end

    it 'refuses a name with no file, a path that leaves the store, and a file under a read-only folder' do
      templates = Dir.mktmpdir('ruby_llm-templates')
      chat.with_code_execution(mounts: { 'templates' => templates })

      expect(run_code(files: ['missing.md'])).to eq(error: "No file or folder missing.md in this chat's files. " \
                                                           'See list_files.')
      expect(run_code(files: ['../etc/passwd'])[:error]).to include('..')
      expect(run_code(files: ['templates/mine.md'])[:error]).to include('read-only folder templates')
      expect(seen).to be_empty
    ensure
      FileUtils.rm_rf(templates)
    end

    it 'offers files in the schema and tells the model to name them' do
      tool = chat.tools[:run_code]

      expect(tool.parameters_schema['properties']).to include('files')
      expect(tool.parameters_schema['required']).to include('files')
      expect(tool.description).to include('name it in files').and include('list_files')
      expect(tool.description).to include('attached to the conversation are in ./attachments (read-only)')
      expect(tool.parameters_schema.dig('properties', 'files', 'description')).to include('./attachments')
    end

    it 'keeps mounted folders in their place' do
      templates = Dir.mktmpdir('ruby_llm-templates')
      File.write(File.join(templates, 'report.md'), 'template')
      chat.with_code_execution(mounts: { 'templates' => templates })

      run_code

      expect(seen[:templates]).to be(true)
    ensure
      FileUtils.rm_rf(templates)
    end
  end

  context 'with a store in a folder' do # rubocop:disable RSpec/MultipleMemoizedHelpers
    let(:root) { Dir.mktmpdir('ruby_llm-store') }
    let(:store) { RubyLLM::FileStore::Directory.new(root) }
    let(:sandbox) do
      FakeSandbox.new do |run|
        directory = run[:directory]
        seen[:directory] = directory
        seen[:writable] = run[:writable]
        seen[:run_dir] = run[:env]['RUN_DIR']
        seen[:templates] = File.symlink?(File.join(directory, 'templates'))
        seen[:shared] = File.symlink?(File.join(directory, 'shared/templates'))
        File.write(File.join(directory, 'notes.md'), 'changed')
        FileUtils.mkdir_p(File.join(directory, 'out'))
        File.write(File.join(directory, 'out/chart.svg'), '<svg/>')
        File.write(File.join(directory, '.hidden'), 'x')
        File.delete(File.join(directory, 'keep.txt'))
        FakeSandbox.result(stdout: 'done')
      end
    end
    let(:chat) { context.chat(model: model_for(:openai), provider: :openai).with_code_execution.with_file_store(store) }

    before do
      store.write('notes.md', 'original')
      store.write('keep.txt', 'kept')
      store.write('same.csv', "a,b\n")
    end

    after { FileUtils.rm_rf(root) }

    it 'tells the model when a run in the folder changed a file it had read' do
      chat.tools[:read_file].call(path: 'notes.md')

      expect(JSON.parse(run_code)['read_again']).to eq('This run changed files you had read: notes.md. Read ' \
                                                       'them before you edit them.')
      chat.tools[:read_file].call(path: 'notes.md')
      expect(chat.tools[:edit_file].call(path: 'notes.md', old_text: 'changed', new_text: 'mine'))
        .to start_with('Replaced 1')
    end

    it 'keeps the report when it cannot read back a file the run changed' do
      chat.tools[:read_file].call(path: 'notes.md')
      allow(store).to receive(:read).and_raise(RubyLLM::FileNotFoundError, 'gone')

      report = JSON.parse(run_code)

      expect(report).to include('stdout' => 'done')
      expect(report['read_again']).to include('notes.md')
    end

    it 'says nothing when a run in the folder rewrites a file it read with the same content' do
      store.write('notes.md', 'changed')
      chat.tools[:read_file].call(path: 'notes.md')

      expect(JSON.parse(run_code)).not_to have_key('read_again')
    end

    it "runs in the store's folder, which it can change, and reports what it created or changed" do
      written = []
      chat.after_file_write { |file| written << file.path }

      report = JSON.parse(run_code)

      expect(seen).to include(directory: store.root, run_dir: store.root)
      expect(seen[:writable]).to include(store.root)
      expect(report).to include('stdout' => 'done', 'files' => %w[notes.md out/chart.svg])
      expect(written).to eq(%w[notes.md out/chart.svg])
      expect(store.read('notes.md')).to eq('changed')
      expect(store.exist?('keep.txt')).to be(false)
    end

    it 'names a file whose name is not valid UTF-8 as skipped, because the run already happened' do
      written = []
      chat.after_file_write { |file| written << file.path }
      chat.with_code_execution(sandbox: FakeSandbox.new do |run|
        File.binwrite(File.join(run[:directory], "bad\xFFname.txt".b), 'x')
        File.write(File.join(run[:directory], 'kept.txt'), 'y')
        FakeSandbox.result
      end)

      expect(JSON.parse(run_code)).to include('files' => ['kept.txt'],
                                              'skipped_files' => ["bad\uFFFDname.txt (name is not valid UTF-8)"])
      expect(written).to eq(['kept.txt'])
    end

    it 'finds an attachment at its own path in the folder, with no attachments folder' do
      file = RubyLLM::Attachment.new(StringIO.new("a,b\n"), filename: 'sales.csv')
      chat.add_message(role: :user, content: 'Here', attachments: [file])
      chat.with_code_execution(sandbox: FakeSandbox.new do |run|
        seen[:sales] = File.read(File.join(run[:directory], 'sales.csv'))
        seen[:attachments] = File.exist?(File.join(run[:directory], 'attachments'))
        FakeSandbox.result
      end)

      expect(JSON.parse(run_code)).not_to have_key('files')
      expect(seen).to include(sales: "a,b\n", attachments: false)
    end

    it 'copies nothing and takes no files argument' do
      tool = chat.tools[:run_code]

      expect(tool.parameters_schema['properties']).not_to include('files')
      expect(tool.description).to include("runs in the folder that holds this chat's files")
      expect(tool.description).to include('files attached to the conversation')
      expect(Dir.children(root).sort).to eq(%w[keep.txt notes.md same.csv])
    end

    it 'links read-only folders into the store for the run, and removes them after' do
      templates = Dir.mktmpdir('ruby_llm-templates')
      File.write(File.join(templates, 'report.md'), 'template')
      chat.with_code_execution(mounts: { 'shared/templates' => templates })

      run_code

      expect(seen[:shared]).to be(true)
      expect(File.exist?(File.join(root, 'shared'))).to be(false)
    ensure
      FileUtils.rm_rf(templates)
    end

    it 'leaves a read-only folder out when the store has something at its path, and says so' do
      templates = Dir.mktmpdir('ruby_llm-templates')
      chat.with_code_execution(mounts: { 'templates' => templates })
      store.write('templates/mine.md', 'mine')

      report = JSON.parse(run_code)

      expect(seen[:templates]).to be(false)
      expect(report['unmounted']).to include('templates')
      expect(store.read('templates/mine.md')).to eq('mine')
    ensure
      FileUtils.rm_rf(templates)
    end
  end
end
