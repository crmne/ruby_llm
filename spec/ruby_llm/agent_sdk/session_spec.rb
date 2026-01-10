# frozen_string_literal: true

require 'spec_helper'
require 'ruby_llm/agent_sdk'

RSpec.describe RubyLLM::AgentSDK::Session do
  describe '#initialize' do
    it 'generates unique session ID' do
      session = described_class.new
      expect(session.id).to be_a(String)
      expect(session.id.length).to be > 20
    end

    it 'accepts explicit session ID' do
      session = described_class.new(id: 'custom-session-id')
      expect(session.id).to eq('custom-session-id')
    end

    it 'tracks creation time' do
      session = described_class.new
      expect(session.created_at).to be_a(Time)
      expect(session.created_at).to be_within(1).of(Time.now)
    end

    it 'uses default max_messages of 1000' do
      session = described_class.new
      expect(session.max_messages).to eq(1000)
    end

    it 'accepts custom max_messages' do
      session = described_class.new(max_messages: 50)
      expect(session.max_messages).to eq(50)
    end
  end

  describe '.resume' do
    it 'creates session with existing ID' do
      session = described_class.resume('existing-session-123')
      expect(session.id).to eq('existing-session-123')
    end

    it 'uses default max_messages' do
      session = described_class.resume('existing-session-123')
      expect(session.max_messages).to eq(1000)
    end

    it 'accepts custom max_messages' do
      session = described_class.resume('existing-session-123', max_messages: 100)
      expect(session.max_messages).to eq(100)
    end
  end

  describe '#fork' do
    it 'creates new session with copied messages' do
      original = described_class.new
      original.add_message({ role: 'user', content: 'Hello' })
      original.add_message({ role: 'assistant', content: 'Hi!' })

      forked = original.fork

      expect(forked.id).not_to eq(original.id)
      expect(forked.messages.size).to eq(2)
      expect(forked.messages).to eq(original.messages)
    end

    it 'creates independent message array' do
      original = described_class.new
      original.add_message({ role: 'user', content: 'Hello' })

      forked = original.fork
      forked.add_message({ role: 'assistant', content: 'New message' })

      expect(original.messages.size).to eq(1)
      expect(forked.messages.size).to eq(2)
    end

    it 'inherits max_messages from original session' do
      original = described_class.new(max_messages: 50)
      forked = original.fork
      expect(forked.max_messages).to eq(50)
    end
  end

  describe '#forked?' do
    it 'returns false for new session' do
      session = described_class.new
      expect(session.forked?).to be false
    end

    it 'returns true for forked session' do
      original = described_class.new
      forked = original.fork
      expect(forked.forked?).to be true
    end
  end

  describe '#parent_id' do
    it 'returns nil for new session' do
      session = described_class.new
      expect(session.parent_id).to be_nil
    end

    it 'returns original session ID for forked session' do
      original = described_class.new
      forked = original.fork
      expect(forked.parent_id).to eq(original.id)
    end
  end

  describe '#add_message' do
    it 'adds message to session' do
      session = described_class.new
      session.add_message({ role: 'user', content: 'Hello' })
      expect(session.messages.size).to eq(1)
      expect(session.messages.first[:content]).to eq('Hello')
    end

    it 'evicts oldest message when limit is exceeded' do
      session = described_class.new(max_messages: 3)
      session.add_message({ role: 'user', content: 'Message 1' })
      session.add_message({ role: 'assistant', content: 'Message 2' })
      session.add_message({ role: 'user', content: 'Message 3' })
      session.add_message({ role: 'assistant', content: 'Message 4' })

      expect(session.messages.size).to eq(3)
      expect(session.messages.first[:content]).to eq('Message 2')
      expect(session.messages.last[:content]).to eq('Message 4')
    end

    it 'maintains exactly max_messages after multiple evictions' do
      session = described_class.new(max_messages: 2)
      10.times { |i| session.add_message({ role: 'user', content: "Message #{i}" }) }

      expect(session.messages.size).to eq(2)
      expect(session.messages.first[:content]).to eq('Message 8')
      expect(session.messages.last[:content]).to eq('Message 9')
    end

    it 'does not evict when under limit' do
      session = described_class.new(max_messages: 5)
      3.times { |i| session.add_message({ role: 'user', content: "Message #{i}" }) }

      expect(session.messages.size).to eq(3)
      expect(session.messages.first[:content]).to eq('Message 0')
    end

    it 'handles max_messages of 1' do
      session = described_class.new(max_messages: 1)
      session.add_message({ role: 'user', content: 'First' })
      session.add_message({ role: 'assistant', content: 'Second' })

      expect(session.messages.size).to eq(1)
      expect(session.messages.first[:content]).to eq('Second')
    end
  end

  describe '#to_h' do
    it 'includes all session info' do
      session = described_class.new(id: 'test-123')
      session.add_message({ role: 'user', content: 'Hi' })

      hash = session.to_h

      expect(hash[:id]).to eq('test-123')
      expect(hash[:created_at]).to be_a(String)
      expect(hash[:message_count]).to eq(1)
      expect(hash[:forked]).to be false
      expect(hash[:parent_id]).to be_nil
    end

    it 'includes fork info for forked session' do
      original = described_class.new(id: 'original-123')
      forked = original.fork

      hash = forked.to_h

      expect(hash[:forked]).to be true
      expect(hash[:parent_id]).to eq('original-123')
    end
  end
end
