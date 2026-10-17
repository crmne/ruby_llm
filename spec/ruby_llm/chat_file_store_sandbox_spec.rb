# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Chat do
  include_context 'with configured RubyLLM'

  let(:cache_dir) { Dir.mktmpdir('ruby_llm-packages-spec') }
  let(:chat) do
    RubyLLM.context do |config|
      config.sandbox = MXC::Sandbox
      config.sandbox_backend = SandboxBackend.name
      config.package_cache_dir = cache_dir
    end.chat(model: model_for(:openai), provider: :openai).with_file_store.with_code_execution
  end
  let(:code) do
    'awk -F, \'NR > 1 { sum += $2 } END { print sum }\' data/orders.csv > total.txt && ' \
      'echo changed >> data/orders.csv && cat total.txt'
  end

  before { skip 'mxc cannot start a sandbox on this machine' unless SandboxBackend.supported? }

  after { FileUtils.rm_rf(cache_dir) }

  it 'runs code on a copy of the files it names and saves what it writes' do
    chat.file_store.write('data/orders.csv', "id,total\n1,10\n2,32\n")

    report = JSON.parse(chat.tools[:run_code].call(language: 'shell', code:, files: ['data']))

    expect(report).to include('exit_code' => 0, 'stdout' => "42\n", 'files' => %w[data/orders.csv total.txt])
    expect(chat.file_store.read('total.txt')).to eq("42\n")
    expect(chat.file_store.read('data/orders.csv')).to end_with("changed\n")
  end

  it 'finds what an earlier run wrote' do
    chat.tools[:run_code].call(language: 'ruby', code: 'File.write("notes.txt", "from the first run")')

    report = JSON.parse(chat.tools[:run_code].call(language: 'ruby', code: 'print File.read("notes.txt")',
                                                   files: ['notes.txt']))

    expect(report['stdout']).to eq('from the first run')
    expect(report).not_to have_key('files')
  end

  context 'with a store in a folder' do
    let(:root) { Dir.mktmpdir('ruby_llm-store') }

    before { chat.with_file_store(RubyLLM.file_store.directory(root)) }

    after { FileUtils.rm_rf(root) }

    it 'runs in the folder and changes the files in place' do
      written = []
      chat.after_file_write { |file| written << file.path }
      chat.file_store.write('data/orders.csv', "id,total\n1,10\n2,32\n")

      report = JSON.parse(chat.tools[:run_code].call(language: 'shell', code:))

      expect(report).to include('exit_code' => 0, 'stdout' => "42\n", 'files' => %w[data/orders.csv total.txt])
      expect(File.read(File.join(root, 'total.txt'))).to eq("42\n")
      expect(File.read(File.join(root, 'data/orders.csv'))).to end_with("changed\n")
      expect(written).to eq(%w[data/orders.csv total.txt])
    end

    it 'reads a read-only folder linked in for the run, which it cannot change' do
      templates = Dir.mktmpdir('ruby_llm-templates')
      File.write(File.join(templates, 'report.md'), 'template')
      chat.with_code_execution(mounts: { 'templates' => templates })

      report = JSON.parse(chat.tools[:run_code].call(
                            language: 'shell', code: 'cat templates/report.md; echo x >> templates/report.md'
                          ))

      expect(report['stdout']).to eq('template')
      expect(File.read(File.join(templates, 'report.md'))).to eq('template')
      expect(Dir.children(root)).to be_empty
    ensure
      FileUtils.rm_rf(templates)
    end
  end
end
