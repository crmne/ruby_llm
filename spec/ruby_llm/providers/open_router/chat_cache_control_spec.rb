# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::OpenRouter::Chat do
  describe '#inject_cache_control' do
    context 'with an array of content blocks' do
      it 'adds cache_control to the last block' do
        blocks = [{ type: 'text', text: 'hello' }]
        result = described_class.inject_cache_control(blocks)

        expect(result.last[:cache_control]).to eq(type: 'ephemeral')
      end

      it 'does not modify earlier blocks' do
        blocks = [{ type: 'text', text: 'first' }, { type: 'text', text: 'last' }]
        result = described_class.inject_cache_control(blocks)

        expect(result.first).not_to have_key(:cache_control)
        expect(result.last[:cache_control]).to eq(type: 'ephemeral')
      end

      it 'does not duplicate cache_control if already present' do
        blocks = [{ type: 'text', text: 'hello', cache_control: { type: 'ephemeral' } }]
        result = described_class.inject_cache_control(blocks)

        blocks_with_cache = result.select { |b| b[:cache_control] }
        expect(blocks_with_cache.length).to eq(1)
      end

      it 'returns the array unchanged when empty' do
        expect(described_class.inject_cache_control([])).to eq([])
      end
    end

    context 'with a plain string' do
      it 'wraps the string in a text block and adds cache_control' do
        result = described_class.inject_cache_control('Tell me a story.')

        expect(result).to be_an(Array)
        expect(result.last).to eq(type: 'text', text: 'Tell me a story.', cache_control: { type: 'ephemeral' })
      end
    end
  end

  describe '#format_messages' do
    context 'when a message has cache_point: true' do
      it 'injects cache_control into the last content block' do
        msg = RubyLLM::Message.new(role: :user, content: 'Tell me a story.', cache_point: true)
        result = described_class.format_messages([msg])

        last_block = result.first[:content].last
        expect(last_block[:cache_control]).to eq(type: 'ephemeral')
      end

      it 'works for assistant messages too' do
        msg = RubyLLM::Message.new(role: :assistant, content: 'I can help.', cache_point: true)
        result = described_class.format_messages([msg])

        last_block = result.first[:content].last
        expect(last_block[:cache_control]).to eq(type: 'ephemeral')
      end
    end

    context 'when a message has cache_point: false (default)' do
      it 'does not add cache_control to any content block' do
        msg = RubyLLM::Message.new(role: :user, content: 'Hello')
        result = described_class.format_messages([msg])

        content = result.first[:content]
        content.each { |block| expect(block).not_to have_key(:cache_control) } if content.is_a?(Array)
      end
    end

    context 'with multiple messages, only one cache_point' do
      it 'only injects cache_control on the marked message' do
        msg1 = RubyLLM::Message.new(role: :user, content: 'First message')
        msg2 = RubyLLM::Message.new(role: :user, content: 'Second message', cache_point: true)
        result = described_class.format_messages([msg1, msg2])

        content1 = result[0][:content]
        content2 = result[1][:content]

        content1.each { |block| expect(block).not_to have_key(:cache_control) } if content1.is_a?(Array)
        expect(content2.last[:cache_control]).to eq(type: 'ephemeral')
      end
    end
  end
end
