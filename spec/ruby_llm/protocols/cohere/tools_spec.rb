# frozen_string_literal: true

require 'spec_helper'

class CohereWeatherTool < RubyLLM::Tool
  description 'Looks up the weather'
  parameter :city, description: 'The city to look up'
end

RSpec.describe RubyLLM::Protocols::Cohere::Tools do
  let(:tool) { CohereWeatherTool.new }

  describe '.function_for' do
    it 'renders a function tool' do
      expect(described_class.function_for(tool)).to eq(
        type: 'function',
        function: {
          name: 'cohere_weather',
          description: 'Looks up the weather',
          parameters: {
            'type' => 'object',
            'properties' => { 'city' => { 'type' => 'string', 'description' => 'The city to look up' } },
            'required' => ['city'],
            'additionalProperties' => false
          }
        }
      )
    end

    it 'drops the strict keyword, which Cohere sets on the request instead' do
      expect(described_class.function_for(tool).dig(:function, :parameters)).not_to have_key('strict')
    end

    it 'merges provider options into the definition' do
      allow(tool).to receive(:provider_options).and_return({ function: { description: 'Custom' } })

      expect(described_class.function_for(tool).dig(:function, :description)).to eq('Custom')
    end
  end

  describe '.build_tool_choice' do
    it 'maps the choices Cohere accepts' do
      expect(described_class.build_tool_choice(nil)).to be_nil
      expect(described_class.build_tool_choice(:auto)).to be_nil
      expect(described_class.build_tool_choice(:required)).to eq('REQUIRED')
      expect(described_class.build_tool_choice(:none)).to eq('NONE')
    end

    it 'refuses to pin a named tool, which Cohere cannot do' do
      expect { described_class.build_tool_choice(:cohere_weather) }
        .to raise_error(ArgumentError, /accepts :auto, :required, or :none/)
    end
  end

  describe '.format_tool_calls' do
    it 'renders assistant tool calls with JSON string arguments' do
      calls = { 'abc' => RubyLLM::ToolCall.new(id: 'abc', name: 'cohere_weather', arguments: { 'city' => 'Berlin' }) }

      expect(described_class.format_tool_calls(calls)).to eq(
        [{ id: 'abc', type: 'function', function: { name: 'cohere_weather', arguments: '{"city":"Berlin"}' } }]
      )
    end
  end

  describe '.format_tool_result' do
    it 'renders plain output as a tool message' do
      message = RubyLLM::Message.new(role: :tool, content: '{"temp": 20}', tool_call_id: 'abc')

      expect(described_class.format_tool_result(message)).to eq(
        role: 'tool', tool_call_id: 'abc', content: '{"temp": 20}'
      )
    end

    it 'renders search results as citable document blocks' do
      results = RubyLLM::SearchResults.new(title: 'Ruby Facts', url: 'https://example.com/ruby', text: 'Matz, 1993.')
      message = RubyLLM::Message.new(role: :tool, content: results.to_json, tool_call_id: 'abc')

      expect(described_class.format_tool_result(message)[:content]).to eq(
        [{
          type: 'document',
          document: {
            id: 'https://example.com/ruby',
            data: { title: 'Ruby Facts', text: 'Matz, 1993.', url: 'https://example.com/ruby' }
          }
        }]
      )
    end
  end

  describe '.parse_tool_calls' do
    it 'keys parsed calls by id' do
      calls = described_class.parse_tool_calls(
        [{ 'id' => 'abc', 'type' => 'function',
           'function' => { 'name' => 'cohere_weather', 'arguments' => '{"city": "Berlin"}' } }]
      )

      expect(calls['abc']).to have_attributes(name: 'cohere_weather', arguments: { 'city' => 'Berlin' })
    end

    it 'treats empty arguments as no arguments' do
      calls = described_class.parse_tool_calls(
        [{ 'id' => 'abc', 'function' => { 'name' => 'cohere_weather', 'arguments' => '' } }]
      )

      expect(calls['abc'].arguments).to eq({})
    end

    it 'raises when the model returns truncated arguments' do
      expect do
        described_class.parse_tool_calls(
          [{ 'id' => 'abc', 'function' => { 'name' => 'cohere_weather', 'arguments' => '{"city":' } }],
          finish_reason: 'MAX_TOKENS'
        )
      end.to raise_error(RubyLLM::ToolCallParseError)
    end

    it 'returns nil when there are no tool calls' do
      expect(described_class.parse_tool_calls(nil)).to be_nil
      expect(described_class.parse_tool_calls([])).to be_nil
    end
  end
end
