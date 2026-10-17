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

  before { skip 'mxc cannot start a sandbox on this machine' unless SandboxBackend.supported? }

  after { FileUtils.rm_rf(cache_dir) }

  it "runs code on a copy of the chat's files and saves what it writes" do
    chat.file_store.write('data/orders.csv', "id,total\n1,10\n2,32\n")
    code = 'awk -F, \'NR > 1 { sum += $2 } END { print sum }\' data/orders.csv > total.txt && ' \
           'echo changed >> data/orders.csv && cat total.txt'

    report = JSON.parse(chat.tools[:run_code].call(language: 'shell', code:))

    expect(report).to include('exit_code' => 0, 'stdout' => "42\n", 'files' => %w[data/orders.csv total.txt])
    expect(chat.file_store.read('total.txt')).to eq("42\n")
    expect(chat.file_store.read('data/orders.csv')).to end_with("changed\n")
  end

  it 'finds what an earlier run wrote' do
    chat.tools[:run_code].call(language: 'ruby', code: 'File.write("notes.txt", "from the first run")')

    report = JSON.parse(chat.tools[:run_code].call(language: 'ruby', code: 'print File.read("notes.txt")'))

    expect(report['stdout']).to eq('from the first run')
    expect(report).not_to have_key('files')
  end
end
