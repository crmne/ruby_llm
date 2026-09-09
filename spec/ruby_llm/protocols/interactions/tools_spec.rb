# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::Interactions::Tools do
  describe '.parse_interaction_calls' do
    def call(arguments)
      step = { 'type' => 'function_call', 'id' => 'c1', 'name' => 'now' }
      step['arguments'] = arguments unless arguments == :absent
      described_class.parse_interaction_calls([step]).fetch('c1')
    end

    it 'parses a JSON object string' do
      expect(call('{"tz":"UTC"}').arguments).to eq({ 'tz' => 'UTC' })
    end

    it 'returns {} for empty-string arguments' do
      expect(call('').arguments).to eq({})
    end

    it 'returns {} for a missing arguments key' do
      expect(call(:absent).arguments).to eq({})
    end

    it 'passes a Hash through unchanged' do
      expect(call({ 'tz' => 'UTC' }).arguments).to eq({ 'tz' => 'UTC' })
    end

    it 'wraps malformed JSON in a RubyLLM error' do
      expect { call('{"tz":') }.to raise_error(RubyLLM::ToolCallParseError) do |error|
        expect(error).to be_a(RubyLLM::Error)
        expect(error.cause).to be_a(JSON::ParserError)
      end
    end
  end
end
