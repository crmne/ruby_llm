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

    it 'reads null arguments as none and keeps other values that are not objects as malformed' do
      expect(call('null')).not_to be_malformed_arguments
      expect(call('"x"').malformed_arguments).to eq('"x"')
      expect(call([1]).malformed_arguments).to eq('[1]')
    end

    it 'keeps arguments that are not valid JSON on a call with empty arguments' do
      tool_call = call('{"tz":')

      expect(tool_call.arguments).to eq({})
      expect(tool_call.malformed_arguments).to eq('{"tz":')
    end

    it 'raises ToolCallTruncatedError for arguments the token limit cut off' do
      step = { 'type' => 'function_call', 'id' => 'c1', 'name' => 'now', 'arguments' => '{"tz":' }

      expect { described_class.parse_interaction_calls([step], finish_reason: :max_tokens) }
        .to raise_error(RubyLLM::ToolCallTruncatedError)
    end
  end
end
