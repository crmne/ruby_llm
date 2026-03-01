# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::OpenAI::Media do
  describe '.format_content' do
    it 'serializes raw hash payloads to JSON strings' do
      raw = RubyLLM::Content::Raw.new({ country: 'France' })

      formatted = described_class.format_content(raw)

      expect(formatted).to eq('{"country":"France"}')
    end

    it 'passes through raw array payloads without serialization' do
      payload = [{ type: 'text', text: 'Hello' }]
      raw = RubyLLM::Content::Raw.new(payload)

      formatted = described_class.format_content(raw)

      expect(formatted).to eq(payload)
    end
  end
end
