# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'

RSpec.describe RubyLLM::Prompt do
  let(:tmpdir) { Dir.mktmpdir }
  let(:prompt_dir) { Pathname.new(tmpdir).join('app/prompts') }

  before do
    prompt_dir.mkpath
    allow(described_class).to receive(:root).and_return(prompt_dir)
  end

  after do
    FileUtils.rm_rf(tmpdir)
  end

  def create_prompt(name, content)
    path = prompt_dir.join("#{name}.txt.erb")
    path.dirname.mkpath
    path.write(content)
  end

  describe '.render' do
    it 'renders a prompt with locals' do
      create_prompt('friend', 'Hello, <%= name %>!')
      expect(described_class.render('friend', name: 'Andrey')).to eq('Hello, Andrey!')
    end

    it 'renders a nested prompt path' do
      create_prompt('work_assistant/instructions', 'You assist <%= user %>.')
      expect(described_class.render('work_assistant/instructions', user: 'Bob')).to eq('You assist Bob.')
    end

    it 'renders without locals' do
      create_prompt('simple', 'Just a static prompt.')
      expect(described_class.render('simple')).to eq('Just a static prompt.')
    end

    it 'raises PromptNotFoundError for missing prompts' do
      expect { described_class.render('nonexistent') }.to raise_error(RubyLLM::PromptNotFoundError)
    end
  end

  describe '#render' do
    it 'renders the prompt with locals' do
      create_prompt('greeting', 'Hi <%= name %>, welcome!')
      prompt = described_class.new('greeting')
      expect(prompt.render(name: 'Andrey')).to eq('Hi Andrey, welcome!')
    end

    it 'exposes name and path' do
      prompt = described_class.new('greeting')
      expect(prompt.name).to eq('greeting')
      expect(prompt.path).to eq(prompt_dir.join('greeting.txt.erb'))
    end
  end

  describe '.roots' do
    let(:engine_tmpdir) { Dir.mktmpdir }
    let(:engine_dir) { Pathname.new(engine_tmpdir).join('app/prompts') }

    before do
      engine_dir.mkpath
      described_class.roots << engine_dir
    end

    after do
      described_class.instance_variable_set(:@roots, nil)
      FileUtils.rm_rf(engine_tmpdir)
    end

    def create_engine_prompt(name, content)
      path = engine_dir.join("#{name}.txt.erb")
      path.dirname.mkpath
      path.write(content)
    end

    it 'keeps the application root first' do
      expect(described_class.roots.first).to eq(prompt_dir)
      expect(described_class.roots.to_a).to eq([prompt_dir, engine_dir])
    end

    it 'resolves a prompt from an engine root when the application does not ship it' do
      create_engine_prompt('engine_agent/instructions', 'Engine prompt for <%= name %>.')
      expect(described_class.render('engine_agent/instructions', name: 'Ava')).to eq('Engine prompt for Ava.')
    end

    it 'prefers the application prompt over an engine prompt at the same path' do
      create_prompt('engine_agent/instructions', 'Application override.')
      create_engine_prompt('engine_agent/instructions', 'Engine default.')
      expect(described_class.render('engine_agent/instructions')).to eq('Application override.')
    end

    it 'resolves #path to the engine file when only the engine ships it' do
      create_engine_prompt('engine_agent/instructions', 'Engine default.')
      prompt = described_class.new('engine_agent/instructions')
      expect(prompt.path).to eq(engine_dir.join('engine_agent/instructions.txt.erb'))
    end

    it 'falls back to the application path when no root has the file' do
      prompt = described_class.new('missing')
      expect(prompt.path).to eq(prompt_dir.join('missing.txt.erb'))
      expect { prompt.render }.to raise_error(RubyLLM::PromptNotFoundError, /missing\.txt\.erb/)
    end
  end

  describe 'RubyLLM.render_prompt' do
    it 'renders a prompt with locals through the top-level entrypoint' do
      create_prompt('friend', 'Hello, <%= name %>!')
      expect(RubyLLM.render_prompt('friend', name: 'Andrey')).to eq('Hello, Andrey!')
    end

    it 'renders a nested prompt path' do
      create_prompt('work_assistant/instructions', 'You assist <%= user %>.')
      expect(RubyLLM.render_prompt('work_assistant/instructions', user: 'Bob')).to eq('You assist Bob.')
    end

    it 'raises PromptNotFoundError for missing prompts' do
      expect { RubyLLM.render_prompt('nonexistent') }.to raise_error(RubyLLM::PromptNotFoundError)
    end
  end
end
