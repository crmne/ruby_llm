# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Gemini::Tools do
  include_context 'with configured RubyLLM'

  let(:test_obj) do
    Object.new.tap { |obj| obj.extend(described_class) }
  end

  describe '#extract_tool_calls' do
    it 'captures all function calls returned in a single candidate' do
      data = {
        'candidates' => [
          {
            'content' => {
              'parts' => [
                { 'functionCall' => { 'name' => 'weather',
                                      'args' => { 'latitude' => '52.5200', 'longitude' => '13.4050' } } },
                { 'functionCall' => { 'name' => 'best_language_to_learn', 'args' => {} } }
              ]
            }
          }
        ]
      }

      tool_calls = test_obj.extract_tool_calls(data)

      expect(tool_calls&.size).to eq(2)
      expect(tool_calls.values.map(&:name)).to eq(%w[weather best_language_to_learn])
      expect(tool_calls.values.last.arguments).to eq({})
    end
  end

  describe '#format_tool_call' do
    it 'outputs a functionCall part for each tool call and preserves assistant text' do
      tool_calls = {
        'a' => RubyLLM::ToolCall.new(id: 'a', name: 'weather', arguments: { 'latitude' => '52.5200' }),
        'b' => RubyLLM::ToolCall.new(id: 'b', name: 'best_language_to_learn', arguments: {})
      }
      message = RubyLLM::Message.new(role: :assistant, content: 'Working on it...', tool_calls:)

      result = test_obj.format_tool_call(message)

      expect(result.length).to eq(3)
      expect(result.first).to eq({ text: 'Working on it...' })
      expect(result[1][:functionCall]).to eq(name: 'weather', args: { 'latitude' => '52.5200' })
      expect(result[2][:functionCall]).to eq(name: 'best_language_to_learn', args: {})
    end
  end

  describe '#format_tool_result' do
    it 'uses the tool call id for Gemini function responses' do
      message = RubyLLM::Message.new(
        role: :tool,
        content: 'Result payload',
        tool_call_id: 'uuid-123'
      )

      result = test_obj.format_tool_result(message)

      expect(result).to eq([
                             {
                               functionResponse: {
                                 name: 'uuid-123',
                                 response: {
                                   name: 'uuid-123',
                                   content: [{ text: 'Result payload' }]
                                 }
                               }
                             }
                           ])
    end
  end
end
