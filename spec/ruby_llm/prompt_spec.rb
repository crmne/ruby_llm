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
end
