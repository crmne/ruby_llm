# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Chat do
  include_context 'with configured RubyLLM'

  describe 'cache_point forwarding' do
    let(:chat) { RubyLLM.chat }

    shared_examples 'a method that supports cache_point' do |message_finder|
      it 'sets cache_point? true when cache_point: true' do
        action.call(cache_point: true)
        message = message_finder.call(chat)
        expect(message).not_to be_nil
        expect(message.cache_point?).to be true
      end

      it 'sets cache_point? false when cache_point is omitted' do
        action.call
        message = message_finder.call(chat)
        expect(message).not_to be_nil
        expect(message.cache_point?).to be false
      end
    end

    describe '#with_instructions' do
      let(:action) { ->(opts = {}) { chat.with_instructions('Be helpful', **opts) } }
      let(:finder) { ->(c) { c.messages.find { |m| m.role == :system } } }

      it_behaves_like 'a method that supports cache_point', ->(c) { c.messages.find { |m| m.role == :system } }

      it 'sets cache_point? true on appended message only' do
        chat.with_instructions('First instruction')
        chat.with_instructions('Second instruction', append: true, cache_point: true)
        system_msgs = chat.messages.select { |m| m.role == :system }
        expect(system_msgs.last.cache_point?).to be true
        expect(system_msgs.first.cache_point?).to be false
      end

      it 'preserves cache_point: true when replacing' do
        chat.with_instructions('Old instruction', cache_point: false)
        chat.with_instructions('New instruction', replace: true, cache_point: true)
        system_msgs = chat.messages.select { |m| m.role == :system }
        expect(system_msgs.size).to eq(1)
        expect(system_msgs.first.cache_point?).to be true
      end
    end

    describe '#ask' do
      before { allow(chat).to receive(:complete) }

      let(:action) { ->(opts = {}) { chat.ask('Hello', **opts) } }

      it_behaves_like 'a method that supports cache_point', ->(c) { c.messages.find { |m| m.role == :user } }
    end
  end
end
