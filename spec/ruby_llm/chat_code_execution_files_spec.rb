# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Chat do
  include_context 'with configured RubyLLM'

  let(:cache_dir) { Dir.mktmpdir('ruby_llm-packages-spec') }
  let(:seen) { {} }
  let(:sandbox) do
    FakeSandbox.new do |run|
      directory = run[:directory]
      seen[:files] = Dir.glob('**/*', base: directory).select { |path| File.file?(File.join(directory, path)) }.sort
      seen[:attachments] = File.exist?(File.join(directory, 'attachments'))
      seen[:templates] = File.symlink?(File.join(directory, 'templates'))
      File.write(File.join(directory, 'notes.md'), 'changed')
      FileUtils.mkdir_p(File.join(directory, 'out'))
      File.write(File.join(directory, 'out/chart.svg'), '<svg/>')
      File.delete(File.join(directory, 'keep.txt'))
      FakeSandbox.result(stdout: 'done')
    end
  end
  let(:context) do
    RubyLLM.context do |config|
      config.sandbox = sandbox
      config.package_cache_dir = cache_dir
    end
  end
  let(:chat) { context.chat(model: model_for(:openai), provider: :openai).with_code_execution.with_files }

  after { FileUtils.rm_rf(cache_dir) }

  before do
    chat.files.write('notes.md', 'original')
    chat.files.write('keep.txt', 'kept')
    chat.files.write('same.csv', "a,b\n")
  end

  def run_code
    chat.tools[:run_code].call(language: 'ruby', code: 'puts 1')
  end

  it "starts each run with a copy of the chat's files and no attachments folder" do
    run_code

    expect(seen[:files]).to eq(%w[keep.txt notes.md same.csv])
    expect(seen[:attachments]).to be(false)
  end

  it 'saves what the run wrote or changed, lists the paths, and returns no attachments' do
    written = []
    chat.after_file_write { |file| written << file.path }

    result = run_code

    expect(result).to be_a(String)
    expect(JSON.parse(result)).to include('stdout' => 'done', 'files' => %w[notes.md out/chart.svg])
    expect(chat.files.read('notes.md')).to eq('changed')
    expect(chat.files.read('out/chart.svg')).to eq('<svg/>')
    expect(chat.files.read('keep.txt')).to eq('kept')
    expect(written).to eq(%w[notes.md out/chart.svg])
  end

  it 'tells the model where the files are' do
    description = chat.tools[:run_code].description

    expect(description).to include("a copy of this chat's files")
    expect(description).not_to include('./attachments')
  end

  it 'keeps mounted folders in their place' do
    templates = Dir.mktmpdir('ruby_llm-templates')
    File.write(File.join(templates, 'report.md'), 'template')
    chat.with_code_execution(mounts: { 'templates' => templates })
    chat.files.write('templates/mine.md', 'shadowed')

    run_code

    expect(seen[:templates]).to be(true)
    expect(seen[:files]).not_to include('templates/mine.md')
  ensure
    FileUtils.rm_rf(templates)
  end
end
