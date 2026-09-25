# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Perplexity, :live do
  describe 'Agent API' do
    let(:preset) { RubyLLM.chat(model: 'fast', provider: :perplexity) }
    let(:add_tool) do
      Class.new(RubyLLM::Tool) do
        description 'Add two integers.'
        parameter :left, type: :integer
        parameter :right, type: :integer
        define_method(:name) { 'add' }
        define_method(:execute) { |left:, right:| left + right }
      end
    end

    it 'answers through a preset, reporting the billed cost' do
      response = preset.ask('In one sentence: who created Ruby on Rails?')

      expect(response.content).to include('Heinemeier Hansson')
      expect(response.cost.total).to be_positive
    end

    it 'streams through a preset without running its web searches as tools' do
      chunks = []
      response = preset.ask('In one sentence: who created Ruby on Rails?') { |chunk| chunks << chunk }

      expect(chunks).not_to be_empty
      expect(response.tool_calls).to be_blank
      expect(response.content).to include('Heinemeier Hansson')
    end

    it 'continues a searched conversation' do
      preset.ask('Which company created the Ruby on Rails framework?')
      followup = preset.ask('In which year was that company founded? Answer with the year only.')

      expect(followup.content).to match(/\d{4}/)
    end

    it 'calls a local tool while streaming' do
      calls = []
      chat = RubyLLM.chat(model: model_for(:perplexity, :agent), provider: :perplexity)
                    .with_tools(add_tool)
                    .before_tool_call { |call| calls << call.arguments }

      response = chat.ask('Use the add tool to add 17 and 25.') { |_chunk| nil }

      expect(calls).to eq([{ 'left' => 17, 'right' => 25 }])
      expect(response.content).to include('42')
    end

    it 'returns JSON Schema output through with_schema' do
      schema = {
        type: 'object',
        properties: { name: { type: 'string' }, year: { type: 'integer' } },
        required: %w[name year],
        additionalProperties: false
      }

      message = RubyLLM.chat(model: model_for(:perplexity, :agent), provider: :perplexity)
                       .with_schema(schema)
                       .ask('Extract these two facts: Ruby was released in 1995. Return its name and release year.')

      expect(message.parsed).to eq('name' => 'Ruby', 'year' => 1995)
    end
  end
end
