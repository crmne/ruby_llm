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

    it 'resolves constants from the top level, not from RubyLLM' do
      stub_const('Chat', Class.new { def self.label = 'application chat' })
      create_prompt('chat', '<%= Chat.label %>')
      expect(described_class.render('chat')).to eq('application chat')
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

  describe 'partials' do
    it 'renders a partial from the current prompt directory' do
      create_prompt('work_assistant/_tone', 'Be kind to <%= name %>.')
      create_prompt('work_assistant/instructions', "Hello.\n<%= render 'tone', name: name %>")
      expect(described_class.render('work_assistant/instructions', name: 'Ada')).to eq("Hello.\nBe kind to Ada.")
    end

    it 'falls back to the prompt root when the current directory has no partial' do
      create_prompt('_tone', 'Root tone.')
      create_prompt('work_assistant/instructions', '<%= render "tone" %>')
      expect(described_class.render('work_assistant/instructions')).to eq('Root tone.')
    end

    it 'resolves a path name from the prompt roots, not the current prompt directory' do
      create_prompt('shared/_safety', 'Root safety.')
      create_prompt('work_assistant/shared/_safety', 'Nested safety.')
      create_prompt('work_assistant/instructions', '<%= render "shared/safety" %>')
      expect(described_class.render('work_assistant/instructions')).to eq('Root safety.')
    end

    it 'prefers the partial next to the prompt over the root partial' do
      create_prompt('_tone', 'Root tone.')
      create_prompt('work_assistant/_tone', 'Assistant tone.')
      create_prompt('work_assistant/instructions', '<%= render "tone" %>')
      expect(described_class.render('work_assistant/instructions')).to eq('Assistant tone.')
    end

    it 'renders nested partials' do
      create_prompt('_inner', 'inner')
      create_prompt('_outer', 'outer <%= render "inner" %>')
      create_prompt('instructions', '<%= render "outer" %>')
      expect(described_class.render('instructions')).to eq('outer inner')
    end

    it 'does not leak locals into a partial' do
      create_prompt('_tone', '<%= name %>')
      create_prompt('instructions', '<%= render "tone" %>')
      expect { described_class.render('instructions', name: 'Ada') }.to raise_error(NameError, /name/)
    end

    it 'raises PromptNotFoundError for a missing partial' do
      create_prompt('work_assistant/instructions', '<%= render "tone" %>')
      expect { described_class.render('work_assistant/instructions') }
        .to raise_error(RubyLLM::PromptNotFoundError, %r{work_assistant/_tone\.txt\.erb})
    end

    it 'reports the root path for a missing path partial' do
      create_prompt('work_assistant/instructions', '<%= render "shared/safety" %>')
      expect { described_class.render('work_assistant/instructions') }
        .to raise_error(RubyLLM::PromptNotFoundError, %r{prompts/shared/_safety\.txt\.erb})
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

    it 'renders a partial shipped by an engine' do
      create_engine_prompt('engine_agent/_tone', 'Engine tone.')
      create_engine_prompt('engine_agent/instructions', '<%= render "tone" %>')
      expect(described_class.render('engine_agent/instructions')).to eq('Engine tone.')
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
