# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::Gemini::Tools do
  include_context 'with configured RubyLLM'

  let(:test_obj) do
    Object.new.tap { |obj| obj.extend(RubyLLM::Protocols::Gemini::Chat, described_class) }
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

    it 'uses a placeholder when the tool returns no content' do
      message = RubyLLM::Message.new(
        role: :tool,
        content: '',
        tool_call_id: 'uuid-123'
      )

      result = test_obj.format_tool_result(message)

      expect(result).to eq([
                             {
                               functionResponse: {
                                 name: 'uuid-123',
                                 response: {
                                   name: 'uuid-123',
                                   content: [{ text: '(no output)' }]
                                 }
                               }
                             }
                           ])
    end

    context 'with attachments' do
      let(:image_path) { File.expand_path('../../../fixtures/ruby.png', __dir__) }

      def format_for(model_id, attachments)
        test_obj.instance_variable_set(:@model, RubyLLM.models.find(model_id))
        message = RubyLLM::Message.new(role: :tool, content: 'Found it', attachments:, tool_call_id: 'uuid-123')
        test_obj.format_tool_result(message)
      end

      it 'nests media inside functionResponse.parts for Gemini 3 models' do
        result = format_for('gemini-3-flash-preview', image_path)

        expect(result.length).to eq(1)
        media_parts = result.first[:functionResponse][:parts]
        expect(media_parts.length).to eq(1)
        expect(media_parts.first[:inline_data][:mime_type]).to eq('image/png')
      end

      it 'keeps media as sibling parts for models before Gemini 3' do
        result = format_for('gemini-2.5-flash', image_path)

        expect(result.first[:functionResponse]).not_to have_key(:parts)
        expect(result.last).to have_key(:inline_data)
      end

      it 'keeps text files as sibling text parts on Gemini 3 models' do
        result = format_for('gemini-3-flash-preview', File.expand_path('../../../fixtures/ruby.txt', __dir__))

        expect(result.first[:functionResponse]).not_to have_key(:parts)
        expect(result.last).to have_key(:text)
      end

      it 'keeps provider-managed files as sibling parts on Gemini 3 models' do
        uploaded = RubyLLM::UploadedFile.new(
          id: 'files/abc123',
          provider: 'gemini',
          filename: 'ruby.png',
          byte_size: 1234,
          mime_type: 'image/png'
        )

        result = format_for('gemini-3-flash-preview', RubyLLM::Attachment.new(uploaded))

        expect(result.first[:functionResponse]).not_to have_key(:parts)
        expect(result.last).to have_key(:file_data)
      end
    end
  end

  describe '#format_tools' do
    it 'sends nothing when there are no tools' do
      expect(test_obj.format_tools({})).to eq([])
    end

    it 'declares a tool with no parameters' do
      tool = instance_double(
        RubyLLM::Tool, name: 'ping', description: 'Pings', parameters_schema: nil,
                       declared_parameters: {}, provider_options: {}
      )

      expect(test_obj.format_tools({ 'ping' => tool })).to eq(
        [{ functionDeclarations: [{ name: 'ping', description: 'Pings' }] }]
      )
    end

    it 'merges provider options into the declaration' do
      tool = instance_double(
        RubyLLM::Tool, name: 'search', description: 'Searches', parameters_schema: nil,
                       declared_parameters: {}, provider_options: { behavior: 'BLOCKING' }
      )

      expect(test_obj.format_tools({ 'search' => tool }).first[:functionDeclarations].first).to include(
        behavior: 'BLOCKING'
      )
    end
  end

  describe '#extract_tool_calls on malformed responses' do
    it 'is nil for a response Gemini did not send' do
      expect(test_obj.send(:extract_tool_calls, nil)).to be_nil
      expect(test_obj.send(:extract_tool_calls, 'not a hash')).to be_nil
      expect(test_obj.send(:extract_tool_calls, { 'candidates' => [] })).to be_nil
      expect(test_obj.send(:extract_tool_calls, { 'candidates' => [{ 'content' => {} }] })).to be_nil
    end
  end

  describe '#convert_tool_schema_to_gemini' do
    it 'is nil without a schema' do
      expect(test_obj.send(:convert_tool_schema_to_gemini, nil)).to be_nil
    end

    it 'rejects a non-object parameter schema' do
      expect { test_obj.send(:convert_tool_schema_to_gemini, { 'type' => 'string' }) }.to raise_error(
        ArgumentError, 'Gemini tool parameters must be objects'
      )
    end
  end

  describe '#param_type_for_gemini' do
    {
      'integer' => 'INTEGER',
      'number' => 'NUMBER',
      'float' => 'NUMBER',
      'double' => 'NUMBER',
      'boolean' => 'BOOLEAN',
      'array' => 'ARRAY',
      'object' => 'OBJECT',
      'anything else' => 'STRING'
    }.each do |declared, expected|
      it "maps #{declared} to #{expected}" do
        expect(test_obj.send(:param_type_for_gemini, declared)).to eq(expected)
      end
    end
  end

  describe '#schema_value' do
    it 'accepts both camelCase and snake_case spellings' do
      expect(test_obj.send(:schema_value, { 'multiple_of' => 2 }, 'multipleOf')).to eq(2)
      expect(test_obj.send(:schema_value, { min_items: 1 }, 'minItems')).to eq(1)
      expect(test_obj.send(:schema_value, { 'maxItems' => 3 }, 'maxItems')).to eq(3)
      expect(test_obj.send(:schema_value, { description: 'text' }, 'description')).to eq('text')
    end
  end

  describe 'anyOf parameters' do
    def converted(property)
      test_obj.send(
        :convert_tool_schema_to_gemini,
        { 'type' => 'object', 'properties' => { 'value' => property } }
      )[:properties]['value']
    end

    it 'marks a nullable union as nullable' do
      expect(converted({ 'anyOf' => [{ 'type' => 'integer' }, { 'type' => 'null' }] })).to include(
        type: 'INTEGER', nullable: true
      )
    end

    it 'takes the first branch of a multi-type union' do
      expect(converted({ 'anyOf' => [{ 'type' => 'integer' }, { 'type' => 'string' }] })).to include(type: 'INTEGER')
    end

    it 'falls back to a nullable string for a null-only union' do
      expect(converted({ 'anyOf' => [{ 'type' => 'null' }] })).to include(type: 'STRING', nullable: true)
    end

    it 'ignores an empty anyOf' do
      expect(converted({ 'type' => 'string', 'anyOf' => [] })).to include(type: 'STRING')
    end
  end

  describe '#build_tool_config' do
    it 'maps every tool choice Gemini understands' do
      expect(test_obj.send(:build_tool_config, :auto)).to eq(
        functionCallingConfig: { mode: :auto }
      )
      expect(test_obj.send(:build_tool_config, :none)).to eq(
        functionCallingConfig: { mode: :none }
      )
      expect(test_obj.send(:build_tool_config, :required)).to eq(
        functionCallingConfig: { mode: 'any' }
      )
      expect(test_obj.send(:build_tool_config, 'lookup')).to eq(
        functionCallingConfig: { mode: 'any', allowedFunctionNames: ['lookup'] }
      )
    end
  end
end
