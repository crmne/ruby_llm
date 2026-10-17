# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Chat do
  include_context 'with configured RubyLLM'

  let(:fixtures) { File.expand_path('../fixtures/skills', __dir__) }
  let(:cache_dir) { Dir.mktmpdir('ruby_llm-packages-spec') }
  let(:chat) do
    RubyLLM.context do |config|
      config.sandbox = MXC::Sandbox
      config.package_cache_dir = cache_dir
    end.chat(model: model_for(:openai), provider: :openai)
  end

  before do
    skip 'mxc cannot start a sandbox on this machine' unless SandboxBackend.supported?
    RubyLLM::Skill.roots << fixtures
  end

  after do
    RubyLLM::Skill.instance_variable_set(:@roots, nil)
    FileUtils.rm_rf(cache_dir)
  end

  def calling(name, arguments)
    call = RubyLLM::ToolCall.new(id: "call_#{SecureRandom.hex(4)}", name:, arguments:)
    RubyLLM::Message.new(role: :assistant, content: '', tool_calls: { call.id => call })
  end

  it "runs a skill's script in the sandbox and returns the file it writes" do
    skip 'python3 is not installed' unless system('python3 --version', out: File::NULL, err: File::NULL)

    chat.with_skills.with_code_execution
    command = 'ls skills && python3 skills/csv-report/scripts/report.py attachments/sample.csv report.md'
    allow(chat.provider).to receive(:complete).and_return(
      calling('load_skill', { 'skill' => 'csv-report' }),
      calling('run_code', { 'language' => 'shell', 'code' => command }),
      RubyLLM::Message.new(role: :assistant, content: 'Here is the report.')
    )

    chat.ask 'Write a report on this CSV', with: File.expand_path('../fixtures/sample.csv', __dir__)
    instructions, run = chat.messages.select(&:tool_result?)
    report = JSON.parse(run.content)

    expect(instructions.content).to include('python3 skills/csv-report/scripts/report.py')
    expect(report).to include('exit_code' => 0, 'stdout' => "csv-report\nticket-codes\n", 'files' => ['report.md'])
    expect(run.attachments.map(&:filename)).to eq(['report.md'])
    expect(run.attachments.first.content).to eq("# Report\n\nRows: 2\nColumns: invoice, amount, due\n")
  end

  it 'keeps skill folders read-only' do
    chat.with_skills(:csv_report).with_code_execution
    result = JSON.parse(Array(chat.tools[:run_code].call(language: 'shell',
                                                         code: 'touch skills/csv-report/new.txt')).first)

    expect(result['exit_code']).not_to eq(0)
    expect(File).not_to exist(File.join(fixtures, 'csv-report/new.txt'))
  end
end
