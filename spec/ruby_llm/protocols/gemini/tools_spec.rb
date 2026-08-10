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
end
