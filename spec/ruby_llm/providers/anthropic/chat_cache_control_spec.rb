# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Anthropic::Chat do
  let(:model) { instance_double(RubyLLM::Model::Info, id: 'claude-sonnet-4-5', max_tokens: nil) }

  def render(messages)
    described_class.render_payload(
      messages,
      tools: {},
      temperature: nil,
      model: model,
      stream: false,
      schema: nil
    )
  end

  describe 'cache_control injection' do
    context 'with a system message where cache_point is true' do
      it 'adds cache_control to the last system block' do
        msg = RubyLLM::Message.new(role: :system, content: 'You are helpful.', cache_point: true)
        payload = render([msg, RubyLLM::Message.new(role: :user, content: 'Hi')])

        last_block = payload[:system].last
        expect(last_block[:cache_control]).to eq(type: 'ephemeral')
      end

      it 'does not add cache_control when cache_point is false' do
        msg = RubyLLM::Message.new(role: :system, content: 'You are helpful.')
        payload = render([msg, RubyLLM::Message.new(role: :user, content: 'Hi')])

        payload[:system].each do |block|
          expect(block).not_to have_key(:cache_control)
        end
      end
    end

    context 'with a user message where cache_point is true' do
      it 'adds cache_control to the last content block' do
        msg = RubyLLM::Message.new(role: :user, content: 'Tell me a story.', cache_point: true)
        payload = render([msg])

        last_block = payload[:messages].first[:content].last
        expect(last_block[:cache_control]).to eq(type: 'ephemeral')
      end

      it 'does not add cache_control when cache_point is false' do
        msg = RubyLLM::Message.new(role: :user, content: 'Tell me a story.')
        payload = render([msg])

        payload[:messages].first[:content].each do |block|
          expect(block).not_to have_key(:cache_control)
        end
      end
    end

    context 'when a Content::Raw block already contains cache_control' do
      it 'does not duplicate when cache_control' do
        raw = RubyLLM::Providers::Anthropic::Content.new('Cached system', cache: true)
        msg = RubyLLM::Message.new(role: :system, content: raw, cache_point: true)
        payload = render([msg, RubyLLM::Message.new(role: :user, content: 'Hi')])

        blocks_with_cache = payload[:system].select { |b| b[:cache_control] }
        expect(blocks_with_cache.length).to eq(1)
        expect(blocks_with_cache.first[:cache_control]).to eq(type: 'ephemeral')
      end
    end
  end
end
