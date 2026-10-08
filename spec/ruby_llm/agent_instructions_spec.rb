# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'

RSpec.describe RubyLLM::Agent do
  include_context 'with configured RubyLLM'

  describe 'instruction inheritance' do
    let(:parent) do
      Class.new(described_class) do
        model model_for(:openai, :temperature), provider: :openai
        inputs :display_name
        instructions 'Parent instructions', cache_until_here: true
      end
    end
    let(:child) { stub_const('SpecInheritedAgent', Class.new(parent)) }
    let(:prompt_root) { Pathname.new(Dir.mktmpdir) }
    let(:prompt_path) { RubyLLM::Prompt.root.join('spec_inherited_agent/instructions.txt.erb') }

    before do
      allow(RubyLLM::Prompt).to receive(:root).and_return(prompt_root)
    end

    after { FileUtils.rm_rf(prompt_root) }

    def write_prompt(content)
      prompt_path.dirname.mkpath
      prompt_path.write(content)
    end

    it 'falls back to inherited declarations with their cache settings' do
      messages = child.chat.messages

      expect(messages.map(&:content)).to eq(['Parent instructions'])
      expect(messages.first.cache_until_here?).to be(true)
    end

    it 'prefers the child conventional prompt to inherited declarations' do
      write_prompt('Child prompt for <%= display_name %>')

      messages = child.chat(display_name: 'Ava').messages

      expect(messages.map(&:content)).to eq(['Child prompt for Ava'])
      expect(messages.first.cache_until_here?).to be(false)
    end

    it 'prefers child inline declarations to both the prompt and inherited declarations' do
      write_prompt('Child prompt')
      child.instructions 'Child inline instructions', append: true

      expect(child.chat.messages.map(&:content)).to eq(['Child inline instructions'])
    end

    it 'evaluates child instruction blocks before considering the prompt or inheritance' do
      write_prompt('Child prompt')
      child.instructions { "Child instructions for #{display_name}" }

      expect(child.chat(display_name: 'Ava').messages.map(&:content)).to eq(['Child instructions for Ava'])
    end

    it 'renders the child prompt with explicitly declared locals' do
      write_prompt('Child prompt for <%= display_name %>')
      child.instructions display_name: 'Bea'

      expect(child.chat(display_name: 'Ava').messages.map(&:content)).to eq(['Child prompt for Bea'])
    end

    it 'keeps an empty child prompt as an intentional absence of instructions' do
      write_prompt('')

      expect(child.chat.messages).to be_empty
    end

    it 'keeps an empty child declaration ahead of the prompt and inheritance' do
      write_prompt('Child prompt')
      child.instructions ''

      expect(child.chat.messages).to be_empty
    end

    it 'falls back through ancestors without declarations' do
      grandchild = Class.new(child)

      expect(grandchild.chat.messages.map(&:content)).to eq(['Parent instructions'])
    end

    it 'inherits the nearest ancestor declarations without reviving earlier ones' do
      child.instructions 'Child instructions', append: true
      grandchild = Class.new(child)

      expect(grandchild.chat.messages.map(&:content)).to eq(['Child instructions'])
      expect(parent.chat.messages.map(&:content)).to eq(['Parent instructions'])
    end
  end

  describe 'instruction cache boundaries' do
    it 'gives a declared boundary its own lifetime' do
      agent = Class.new(described_class) do
        model model_for(:anthropic), provider: :anthropic
        instructions 'Stable policy', cache_until_here: { ttl: '1h' }
      end

      expect(agent.chat.messages.sole.cache_ttl).to eq('1h')
    end
  end
end
