# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::Anthropic::Tools do
  let(:tools) { described_class }

  describe '#render_tool_call_with_thinking' do
    let(:provider) { RubyLLM::Protocols::Anthropic.allocate }
    let(:msg) do
      message_double(content: 'Some content')
    end

    def render_tool_call(msg)
      provider.send(:render_tool_call_with_thinking, msg)
    end

    def message_double(content:, attachments: [])
      instance_double(RubyLLM::Message,
                      content: content,
                      attachments: attachments,
                      cache_until_here?: false,
                      thinking: nil,
                      raw_reasoning: nil,
                      tool_calls: {
                        'tool_123' => RubyLLM::ToolCall.new(
                          id: 'tool_123',
                          name: 'test_tool',
                          arguments: { 'arg1' => 'value1' }
                        )
                      })
    end

    it 'formats a message with content and tool call' do
      result = render_tool_call(msg)

      expect(result).to eq({
                             role: 'assistant',
                             content: [
                               { type: 'text', text: 'Some content' },
                               {
                                 type: 'tool_use',
                                 id: 'tool_123',
                                 name: 'test_tool',
                                 input: { 'arg1' => 'value1' }
                               }
                             ]
                           })
    end

    context 'when message has no content' do
      let(:msg) do
        message_double(content: nil)
      end

      it 'formats a message with only tool call' do
        result = render_tool_call(msg)

        expect(result).to eq({
                               role: 'assistant',
                               content: [
                                 {
                                   type: 'tool_use',
                                   id: 'tool_123',
                                   name: 'test_tool',
                                   input: { 'arg1' => 'value1' }
                                 }
                               ]
                             })
      end
    end

    context 'when message has empty content' do
      let(:msg) do
        message_double(content: '')
      end

      it 'formats a message with only tool call' do
        result = render_tool_call(msg)

        expect(result).to eq({
                               role: 'assistant',
                               content: [
                                 {
                                   type: 'tool_use',
                                   id: 'tool_123',
                                   name: 'test_tool',
                                   input: { 'arg1' => 'value1' }
                                 }
                               ]
                             })
      end
    end

    it 'formats attachments before tool calls' do
      text_path = File.expand_path('../../../fixtures/ruby.txt', __dir__)
      msg = message_double(content: 'Read this before calling the tool',
                           attachments: RubyLLM::Attachment.wrap(text_path))

      formatted = render_tool_call(msg)

      expect(formatted[:content].first).to eq({ type: 'text', text: 'Read this before calling the tool' })
      expect(formatted[:content].second).to include(type: 'text')
      expect(formatted[:content].second[:text]).to include("<file name='ruby.txt' mime_type='text/plain'>")
      expect(formatted[:content].third).to include(type: 'tool_use', id: 'tool_123')
    end

    it 'formats messages with multiple tool calls correctly' do
      tool_calls = {
        'tool_1' => RubyLLM::ToolCall.new(id: 'tool_1', name: 'dice_roll', arguments: {}),
        'tool_2' => RubyLLM::ToolCall.new(id: 'tool_2', name: 'dice_roll', arguments: {}),
        'tool_3' => RubyLLM::ToolCall.new(id: 'tool_3', name: 'dice_roll', arguments: {})
      }

      msg = RubyLLM::Message.new(
        role: :assistant,
        content: 'Rolling dice 3 times',
        tool_calls: tool_calls
      )

      formatted = render_tool_call(msg)

      expect(formatted[:role]).to eq('assistant')
      expect(formatted[:content].size).to eq(4) # 1 text + 3 tool_use blocks

      # Check text content
      expect(formatted[:content][0]).to eq({ type: 'text', text: 'Rolling dice 3 times' })
      # Check all 3 tool use blocks are present
      tool_use_blocks = formatted[:content][1..3]
      expect(tool_use_blocks.map { |b| b[:type] }).to all(eq('tool_use'))
      expect(tool_use_blocks.map { |b| b[:id] }).to contain_exactly('tool_1', 'tool_2', 'tool_3')
      expect(tool_use_blocks.map { |b| b[:name] }).to all(eq('dice_roll'))
    end

    it 'does not include empty text content with multiple tool calls' do
      tool_calls = {
        'tool_1' => RubyLLM::ToolCall.new(id: 'tool_1', name: 'dice_roll', arguments: {})
      }

      msg = RubyLLM::Message.new(
        role: :assistant,
        content: '', # Empty content
        tool_calls: tool_calls
      )

      formatted = render_tool_call(msg)

      expect(formatted[:role]).to eq('assistant')
      expect(formatted[:content].size).to eq(1) # Only tool_use block, no text
      expect(formatted[:content][0][:type]).to eq('tool_use')
    end
  end

  describe '.render_tool_result' do
    let(:msg) do
      instance_double(RubyLLM::Message,
                      provider_call_id: 'tool_123',
                      content: 'Tool result',
                      attachments: [])
    end

    it 'formats a tool result message' do
      result = tools.render_tool_result(msg)

      expect(result).to eq({
                             role: 'user',
                             content: [
                               {
                                 type: 'tool_result',
                                 tool_use_id: 'tool_123',
                                 content: [
                                   {
                                     type: 'text',
                                     text: 'Tool result'
                                   }
                                 ]
                               }
                             ]
                           })
    end

    it 'uses a placeholder when the tool returns no content' do
      msg = instance_double(RubyLLM::Message,
                            provider_call_id: 'tool_123',
                            content: '',
                            attachments: [])

      result = tools.render_tool_result(msg)

      expect(result).to eq({
                             role: 'user',
                             content: [
                               {
                                 type: 'tool_result',
                                 tool_use_id: 'tool_123',
                                 content: [
                                   {
                                     type: 'text',
                                     text: '(no output)'
                                   }
                                 ]
                               }
                             ]
                           })
    end

    it 'uses a placeholder when the tool returns only whitespace' do
      msg = instance_double(RubyLLM::Message, provider_call_id: 'tool_123', content: " \n", attachments: [])

      result = tools.render_tool_result(msg)

      expect(result.dig(:content, 0, :content)).to eq([{ type: 'text', text: '(no output)' }])
    end
  end

  describe '#extract_tool_calls' do
    let(:extractor) do
      Class.new do
        include RubyLLM::Protocols::Anthropic::Streaming
        include RubyLLM::Protocols::Anthropic::Tools
      end.new
    end

    it 'keys streaming tool call starts by content block index' do
      data = {
        'type' => 'content_block_start',
        'index' => 2,
        'content_block' => {
          'type' => 'tool_use',
          'id' => 'tool_2',
          'name' => 'search',
          'input' => {}
        }
      }

      tool_calls = extractor.send(:extract_tool_calls, data)

      expect(tool_calls.keys).to eq([2])
      expect(tool_calls[2]).to have_attributes(id: nil, provider_call_id: 'tool_2')
      expect(tool_calls[2].name).to eq('search')
    end

    it 'keys streaming tool call argument deltas by content block index' do
      data = {
        'type' => 'content_block_delta',
        'index' => 2,
        'delta' => {
          'type' => 'input_json_delta',
          'partial_json' => '{"query":"market news"}'
        }
      }

      tool_calls = extractor.send(:extract_tool_calls, data)

      expect(tool_calls.keys).to eq([2])
      expect(tool_calls[2].id).to be_nil
      expect(tool_calls[2].name).to be_nil
      expect(tool_calls[2].arguments).to eq('{"query":"market news"}')
    end
  end

  describe '.parse_tool_calls' do
    it 'parses multiple tool calls from content blocks' do
      content_blocks = [
        { 'type' => 'text', 'text' => 'Rolling dice' },
        { 'type' => 'tool_use', 'id' => 'tool_1', 'name' => 'dice_roll', 'input' => {} },
        { 'type' => 'tool_use', 'id' => 'tool_2', 'name' => 'dice_roll', 'input' => {} },
        { 'type' => 'tool_use', 'id' => 'tool_3', 'name' => 'dice_roll', 'input' => {} }
      ]

      tool_calls = described_class.parse_tool_calls(content_blocks)

      expect(tool_calls).to be_a(Hash)
      expect(tool_calls.size).to eq(3)
      expect(tool_calls.keys).to contain_exactly('tool_1', 'tool_2', 'tool_3')
      expect(tool_calls.values.map(&:name)).to all(eq('dice_roll'))
    end

    it 'handles single tool call for backward compatibility' do
      single_block = { 'type' => 'tool_use', 'id' => 'tool_1', 'name' => 'dice_roll', 'input' => {} }

      tool_calls = described_class.parse_tool_calls(single_block)

      expect(tool_calls).to be_a(Hash)
      expect(tool_calls.size).to eq(1)
      expect(tool_calls['tool_1'].name).to eq('dice_roll')
    end

    it 'returns nil for empty or nil input' do
      expect(described_class.parse_tool_calls(nil)).to be_nil
      expect(described_class.parse_tool_calls([])).to be_nil
    end
  end

  describe '.build_tool_choice' do
    it 'passes auto and none through' do
      expect(described_class.build_tool_choice(choice: :auto)).to eq(type: :auto)
      expect(described_class.build_tool_choice(choice: :none, calls: :one)).to eq(type: :none)
    end

    it 'asks for any tool when one is required' do
      expect(described_class.build_tool_choice(choice: :required, calls: :many))
        .to eq(type: :any, disable_parallel_tool_use: false)
    end

    it 'names a specific tool' do
      expect(described_class.build_tool_choice(choice: :weather, calls: :one))
        .to eq(type: :tool, name: :weather, disable_parallel_tool_use: true)
    end

    it 'defaults to auto when only the number of calls is set' do
      expect(described_class.build_tool_choice(choice: nil, calls: :one))
        .to eq(type: :auto, disable_parallel_tool_use: true)
    end
  end

  describe '.render_tool_result_content' do
    it 'renders search results as citable search_result blocks' do
      results = RubyLLM::SearchResults.new({ title: 'Guide', url: 'https://example.com/guide', text: 'Ruby is fun.' },
                                           { title: 'Notes', text: 'Matz, 1993.' })
      message = RubyLLM::Message.new(role: :tool, content: results.to_json, tool_call_id: 'tool_1')

      expect(described_class.render_tool_result_content(message)).to eq(
        [
          { type: 'search_result', source: 'https://example.com/guide', title: 'Guide',
            content: [{ type: 'text', text: 'Ruby is fun.' }], citations: { enabled: true } },
          { type: 'search_result', source: 'Notes', title: 'Notes',
            content: [{ type: 'text', text: 'Matz, 1993.' }], citations: { enabled: true } }
        ]
      )
    end

    it 'labels a search result with its source_id in place of its url' do
      results = RubyLLM::SearchResults.new(title: 'Guide', url: 'https://example.com/guide',
                                           source_id: 'gid://app/Document/42', text: 'Ruby is fun.')
      message = RubyLLM::Message.new(role: :tool, content: results.to_json, tool_call_id: 'tool_1')

      expect(described_class.render_tool_result_content(message).first[:source]).to eq('gid://app/Document/42')
    end
  end

  describe '.apply_tool_search' do
    it 'keeps messages with plain text content when it strips tool search blocks' do
      payload = { messages: [{ role: 'user', content: 'Hello' }] }

      expect(described_class.apply_tool_search(payload)[:messages]).to eq([{ role: 'user', content: 'Hello' }])
    end
  end

  describe '.function_for' do
    it 'declares the schema a tool provides' do
      schema = { 'type' => 'object', 'properties' => { 'city' => { 'type' => 'string' } } }
      tool = instance_double(RubyLLM::Tool, name: 'weather', description: 'Weather', parameters_schema: schema,
                                            declared_parameters: {}, provider_options: {})

      expect(described_class.function_for(tool)[:input_schema]).to eq(schema)
    end

    it 'declares a strict empty object schema for a tool without parameters' do
      tool = instance_double(RubyLLM::Tool, name: 'ping', description: 'Ping', parameters_schema: nil,
                                            declared_parameters: {}, provider_options: {})

      expect(described_class.function_for(tool)[:input_schema]).to eq(
        'type' => 'object', 'properties' => {}, 'required' => [], 'additionalProperties' => false, 'strict' => true
      )
    end
  end
end
