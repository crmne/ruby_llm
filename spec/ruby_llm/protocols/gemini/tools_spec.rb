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

      it 'nests media for the latest aliases, which track the newest release' do
        %w[gemini-flash-latest gemini-pro-latest gemini-flash-lite-latest].each do |id|
          result = format_for(id, image_path)

          expect(result.length).to eq(1)
          expect(result.first[:functionResponse][:parts].first[:inline_data][:mime_type]).to eq('image/png')
        end
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

  describe '#multimodal_function_responses_supported?' do
    def supported?(id)
      test_obj.send(:multimodal_function_responses_supported?, id)
    end

    it 'reads the generation off the Gemini id' do
      expect(supported?('gemini-2.5-flash')).to be(false)
      expect(supported?('gemini-2.5-pro')).to be(false)
      expect(supported?('gemini-3-flash-preview')).to be(true)
      expect(supported?('gemini-3.6-flash')).to be(true)
    end

    it 'treats the latest aliases as the newest generation' do
      expect(supported?('gemini-flash-latest')).to be(true)
      expect(supported?('gemini-pro-latest')).to be(true)
      expect(supported?('gemini-flash-lite-latest')).to be(true)
    end

    it 'reads no generation out of an id that names none' do
      expect(supported?('gemini-omni-flash-preview')).to be(false)
      expect(supported?('deep-research-max-preview-04-2026')).to be(false)
      expect(supported?('openai/gpt-oss-120b-maas')).to be(false)
      expect(supported?('moonshotai/kimi-k2-thinking-maas')).to be(false)
      expect(supported?(nil)).to be(false)
    end
  end

  describe 'tool parameter schemas' do
    def declared(schema)
      tool = instance_double(
        RubyLLM::Tool, name: 'lookup', description: 'Looks up', parameters_schema: schema,
                       declared_parameters: {}, provider_options: {}
      )

      test_obj.format_tools({ 'lookup' => tool }).first[:functionDeclarations].first
    end

    it 'sends the schema as parametersJsonSchema' do
      schema = { 'type' => 'object', 'properties' => { 'city' => { 'type' => 'string' } }, 'required' => ['city'] }

      expect(declared(schema)).to eq(
        name: 'lookup', description: 'Looks up', parametersJsonSchema: schema
      )
    end

    it 'keeps an anyOf union intact instead of collapsing it' do
      union = { 'anyOf' => [{ 'type' => 'integer', 'minimum' => 1 }, { 'type' => 'string', 'pattern' => '^[a-z]+$' }] }
      schema = { 'type' => 'object', 'properties' => { 'id' => union } }

      expect(declared(schema)[:parametersJsonSchema]['properties']['id']).to eq(union)
    end

    it 'keeps type unions, references, and constraints the converter dropped' do
      schema = {
        'type' => 'object',
        'additionalProperties' => false,
        '$defs' => { 'Tag' => { 'type' => 'string', 'minLength' => 2 } },
        'properties' => {
          'count' => { 'type' => %w[integer null], 'multipleOf' => 2 },
          'tag' => { '$ref' => '#/$defs/Tag' }
        }
      }

      expect(declared(schema)[:parametersJsonSchema]).to eq(schema)
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
