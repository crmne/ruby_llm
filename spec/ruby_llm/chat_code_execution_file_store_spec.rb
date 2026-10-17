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
        seen[:attachments] = File.exist?(File.join(directory, 'attachments'))
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

    it 'copies in nothing unless the model names files, and has no attachments folder' do
      run_code

      expect(seen[:files]).to be_empty
      expect(seen[:attachments]).to be(false)
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
      expect(tool.description).to include('name them in files').and include('list_files')
      expect(tool.description).not_to include('./attachments')
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
    let(:store) { RubyLLM.file_store.directory(root) }
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

    it "runs in the store's folder, which it can change, and reports what it created or changed" do
      written = []
      chat.after_file_write { |file| written << file.path }

      report = JSON.parse(run_code)

      expect(seen).to include(directory: store.root, run_dir: store.root)
      expect(seen[:writable]).to include(store.root)
      expect(report).to include('stdout' => 'done', 'files' => %w[notes.md out/chart.svg])
      expect(written).to eq(%w[notes.md out/chart.svg])
      expect(store.read('notes.md')).to eq('changed')
      expect(store.exists?('keep.txt')).to be(false)
    end

    it 'copies nothing and takes no files argument' do
      tool = chat.tools[:run_code]

      expect(tool.parameters_schema['properties']).not_to include('files')
      expect(tool.description).to include("runs in the folder that holds this chat's files")
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
