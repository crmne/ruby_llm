# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Chat do
  include_context 'with configured RubyLLM'

  let(:fixtures) { File.expand_path('../fixtures/skills', __dir__) }
  let(:sandbox) { FakeSandbox.new }
  let(:context) { RubyLLM.context { |config| config.sandbox = sandbox } }
  let(:chat) { context.chat(model: model_for(:openai), provider: :openai) }

  before { RubyLLM::Skill.roots << fixtures }
  after { RubyLLM::Skill.instance_variable_set(:@roots, nil) }

  def load_skill(chat, skill, file = nil)
    chat.tools[:load_skill].call(skill:, **({ file: } if file).to_h)
  end

  def sent_messages(chat)
    sent = []
    allow(chat.provider).to receive(:complete) do |messages, **|
      sent << messages
      RubyLLM::Message.new(role: :assistant, content: 'Done')
    end
    chat.ask('Hello')
    sent.last
  end

  describe '#with_skills' do
    it 'adds every skill under the skill roots when called bare or with true' do
      expect(chat.skills).to eq([])
      expect(chat.with_skills).to be(chat)
      expect(chat.skills.map(&:name)).to eq(%w[csv-report ticket-codes])
      expect(context.chat.with_skills(true).skills.map(&:name)).to eq(%w[csv-report ticket-codes])
    end

    it 'adds skills by name and by path, and removes them with false' do
      chat.with_skills(:ticket_codes, File.join(fixtures, 'csv-report'))

      expect(chat.skills.map(&:name)).to eq(%w[ticket-codes csv-report])
      expect(chat.with_skills(false).skills).to eq([])
    end

    it 'adds to the skills it has, once each' do
      chat.with_skills(:ticket_codes).with_skills(:csv_report, Pathname.new(fixtures).join('ticket-codes'))

      expect(chat.skills.map(&:name)).to eq(%w[ticket-codes csv-report])
    end

    it 'rejects nil, true or false with names, and two skills of one name' do
      other = Dir.mktmpdir('ruby_llm-skills')
      FileUtils.mkdir_p(File.join(other, 'ticket-codes'))
      File.write(File.join(other, 'ticket-codes/SKILL.md'), "---\nname: ticket-codes\ndescription: Copy.\n---\n")

      expect { chat.with_skills(nil) }.to raise_error(ArgumentError, /cannot be nil/)
      expect { chat.with_skills(true, :csv_report) }.to raise_error(ArgumentError, /take no skill names/)
      expect { chat.with_skills(:ticket_codes, File.join(other, 'ticket-codes')) }
        .to raise_error(ArgumentError, /Two skills are named ticket-codes/)
      expect { chat.with_skills(42) }.to raise_error(ArgumentError, /Symbols, paths/)
    ensure
      FileUtils.rm_rf(other)
    end

    it 'raises for a missing skill when configured' do
      expect { chat.with_skills(:missing) }.to raise_error(RubyLLM::SkillNotFoundError)
    end

    it 'gives the model the read-only load_skill tool only while it has skills' do
      expect(chat.tools).not_to have_key(:load_skill)

      tool = chat.with_skills(:ticket_codes).tools[:load_skill]

      expect(tool).to be_read_only
      expect(tool.parameters_schema['required']).to eq(['skill'])
      expect(chat.with_skills(false).tools).not_to have_key(:load_skill)
    end
  end

  describe 'the skill listing' do
    it 'lists every skill in a system message of each request, after the instructions' do
      chat.with_instructions('Be terse.').with_skills

      sent = sent_messages(chat)

      expect(sent.map(&:role)).to eq(%i[system system user])
      expect(sent.first.content).to eq('Be terse.')
      expect(sent[1].content).to include('call load_skill')
      expect(sent[1].content).to include(
        "<skills>\n- csv-report: Summarizes a CSV file into a Markdown report. Use when someone asks for a report " \
        "on a CSV file.\n- ticket-codes: Builds the official code for a support ticket number. Use whenever " \
        "someone asks for a ticket code.\n</skills>"
      )
    end

    it 'is rendered for each request and never stored in the messages' do
      chat.with_skills(:ticket_codes)
      sent_messages(chat)

      expect(chat.messages.map(&:role)).to eq(%i[user assistant])
      expect(chat.render.to_s).to include('ticket-codes: Builds the official code')
      expect(chat.with_skills(false).render.to_s).not_to include('load_skill')
    end

    it 'says skill scripts cannot run without code execution' do
      listing = sent_messages(chat.with_skills(:ticket_codes)).first.content

      expect(listing).to include('This conversation cannot run code, so skill scripts cannot run.')
    end

    it 'says where skill scripts run with code execution' do
      listing = sent_messages(chat.with_skills(:csv_report).with_code_execution).first.content

      expect(listing).to include('mounted read-only in every run_code working directory at skills/<name>/')
    end
  end

  describe 'the load_skill tool' do
    it 'returns the instructions without the front matter' do
      result = load_skill(chat.with_skills(:ticket_codes), 'ticket-codes')

      expect(result).to start_with("# Skill: ticket-codes\n\n")
      expect(result).to include('cannot run code')
      expect(result).to include("# Ticket codes\n\n1. Read references/FORMAT.md")
      expect(result).not_to include('license: MIT')
      expect(load_skill(chat, 'ticket-codes', 'SKILL.md')).to eq(result)
    end

    it 'says where the skill folder is with code execution' do
      result = load_skill(chat.with_skills(:csv_report).with_code_execution, 'csv-report')

      expect(result).to include("Its folder is at skills/csv-report/ in run_code's working directory, read-only")
    end

    it 'returns a file inside the skill folder' do
      chat.with_skills(:ticket_codes)

      expect(load_skill(chat, 'ticket-codes', 'references/FORMAT.md')).to include('TKT-21-ZX')
      expect(load_skill(chat, 'ticket-codes', 'skills/ticket-codes/references/FORMAT.md')).to include('TKT-21-ZX')
    end

    it 'refuses files outside the skill folder, missing files, and unknown skills' do
      chat.with_skills(:ticket_codes, :csv_report)

      expect(load_skill(chat, 'ticket-codes', '../csv-report/SKILL.md'))
        .to eq(error: '../csv-report/SKILL.md is not a path inside the ticket-codes skill')
      expect(load_skill(chat, 'ticket-codes', '/etc/hosts')).to include(:error)
      expect(load_skill(chat, 'ticket-codes', 'missing.md'))
        .to eq(error: 'The ticket-codes skill has no file missing.md')
      expect(load_skill(chat, 'nope')).to eq(error: 'No skill named nope. Skills: ticket-codes, csv-report')
    end

    it 'lists a folder and refuses binary and large files' do
      folder = Dir.mktmpdir('ruby_llm-skills')
      skill = File.join(folder, 'assets-demo')
      FileUtils.mkdir_p(File.join(skill, 'assets'))
      File.write(File.join(skill, 'SKILL.md'), "---\nname: assets-demo\ndescription: Has assets.\n---\nBody\n")
      FileUtils.cp(File.expand_path('../fixtures/ruby.png', __dir__), File.join(skill, 'assets/logo.png'))
      File.write(File.join(skill, 'assets/big.txt'), 'a' * (RubyLLM::Skill::Loader::MAX_FILE_SIZE + 1))
      chat.with_skills(skill)

      expect(load_skill(chat, 'assets-demo', 'assets')).to eq(error: 'assets is a folder holding: big.txt, logo.png')
      expect(load_skill(chat, 'assets-demo', 'assets/logo.png')[:error])
        .to eq('assets/logo.png is not a text file. This conversation cannot run code to use it.')
      expect(load_skill(chat.with_code_execution, 'assets-demo', 'assets/big.txt')[:error])
        .to end_with('Use it from run_code at skills/assets-demo/assets/big.txt.')
    ensure
      FileUtils.rm_rf(folder)
    end

    it 'runs in read-only permission mode' do
      chat.with_skills(:ticket_codes).with_permissions(:read_only)
      call = RubyLLM::ToolCall.new(id: 'call_1', name: 'load_skill', arguments: { 'skill' => 'ticket-codes' })
      allow(chat.provider).to receive(:complete).and_return(
        RubyLLM::Message.new(role: :assistant, content: '', tool_calls: { call.id => call }),
        RubyLLM::Message.new(role: :assistant, content: 'TKT-42-ZX')
      )

      chat.ask('Ticket code for 6?')

      expect(chat.messages.find(&:tool_result?).content).to include('# Ticket codes')
    end
  end

  describe 'code execution' do
    it 'mounts every skill folder read-only at skills/<name>/ in each run' do
      seen = nil
      sandbox = FakeSandbox.new do |run|
        seen = %w[csv-report ticket-codes].to_h do |name|
          [name, File.realpath(File.join(run[:directory], 'skills', name))]
        end
        FakeSandbox.result(stdout: 'ok')
      end
      chat = RubyLLM.context { |config| config.sandbox = sandbox }.chat(model: model_for(:openai), provider: :openai)
      chat.with_code_execution.with_skills(:csv_report, :ticket_codes)

      chat.tools[:run_code].call(language: 'shell', code: 'ls skills')
      run = sandbox.code_runs.last

      expect(seen).to eq('csv-report' => File.join(fixtures, 'csv-report'),
                         'ticket-codes' => File.join(fixtures, 'ticket-codes'))
      expect(run[:readable]).to include(File.join(fixtures, 'csv-report'), File.join(fixtures, 'ticket-codes'))
      expect(run[:writable]).not_to include(File.join(fixtures, 'csv-report'))
    end
  end

  describe 'following a skill', :live do
    %i[openai anthropic].each do |provider|
      model = model_for(provider)

      it "#{provider}/#{model} loads a skill and its reference file and follows them" do
        chat = RubyLLM.chat(model:, provider:).with_skills
        response = chat.ask 'What is the ticket code for ticket 6?'
        loads = chat.messages.flat_map { |message| (message.tool_calls || {}).values }
                    .select { |call| call.name == 'load_skill' }

        expect(loads.map { |call| call.arguments['skill'] }).to all(eq('ticket-codes'))
        expect(loads.map { |call| call.arguments['file'].to_s }).to include(end_with('references/FORMAT.md'))
        expect(response.content).to include('TKT-42-ZX')
        expect(chat.messages.none? { |message| message.content.to_s.include?('<skills>') }).to be(true)
      end
    end
  end
end
