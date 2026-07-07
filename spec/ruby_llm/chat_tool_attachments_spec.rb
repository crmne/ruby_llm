# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Chat do
  include_context 'with configured RubyLLM'

  let(:image_path) { File.expand_path('../fixtures/ruby.png', __dir__) }
  let(:attachment) { RubyLLM::Attachment.new(image_path) }
  let(:tool_call) { RubyLLM::ToolCall.new(id: 'call_1', name: 'drive_search', arguments: {}) }

  describe 'tool results with attachments' do
    let(:chat) { RubyLLM.chat(model: 'claude-haiku-4-5', provider: 'anthropic') }

    def tool_message_for(result)
      chat.send(:add_tool_result_message, tool_call, result)
    end

    it 'accepts a bare attachment' do
      message = tool_message_for(attachment)

      expect(message.content).to eq('')
      expect(message.attachments).to eq([attachment])
    end

    it 'accepts content, [attachments] returns' do
      message = tool_message_for(['Found ruby.png', [attachment]])

      expect(message.content).to eq('Found ruby.png')
      expect(message.attachments).to eq([attachment])
    end

    it 'partitions flat mixes of strings and attachments' do
      other = RubyLLM::Attachment.new(image_path)
      message = tool_message_for(['Found:', attachment, other])

      expect(message.content).to eq('Found:')
      expect(message.attachments).to eq([attachment, other])
    end

    it 'keeps attachment-free arrays as JSON data' do
      message = tool_message_for([{ sku: 'A1' }, { sku: 'B2' }])

      expect(message.content).to eq('[{"sku":"A1"},{"sku":"B2"}]')
      expect(message.attachments).to be_empty
    end

    it 'rejects mixes containing anything else' do
      expect do
        tool_message_for(['Found:', attachment, 42])
      end.to raise_error(ArgumentError, /Strings and RubyLLM::Attachments/)
    end
  end

  describe 'wire formatting' do
    def messages_with_tool_attachment
      [
        RubyLLM::Message.new(role: :user, content: 'Find the ruby logo'),
        RubyLLM::Message.new(role: :assistant, content: nil, tool_calls: { 'call_1' => tool_call }),
        RubyLLM::Message.new(role: :tool, content: 'Found it', attachments: image_path, tool_call_id: 'call_1')
      ]
    end

    def chat_with_tool_attachment(model, provider, protocol: nil)
      chat = RubyLLM.chat(model: model, provider: provider, protocol: protocol)
      chat.messages = messages_with_tool_attachment
      chat
    end

    it 'renders Anthropic tool_result blocks with text and image' do
      chat = chat_with_tool_attachment('claude-haiku-4-5', 'anthropic')

      tool_result = chat.render[:messages].last[:content].first
      expect(tool_result[:type]).to eq('tool_result')
      expect(tool_result[:content].map { |block| block[:type] }).to eq(%w[text image])
    end

    it 'renders Converse toolResult blocks with text and image' do
      chat = chat_with_tool_attachment('claude-haiku-4-5', 'bedrock')

      tool_result = chat.render[:messages].last[:content].first[:toolResult]
      expect(tool_result[:content].first).to eq({ text: 'Found it' })
      expect(tool_result[:content].last).to have_key(:image)
    end

    it 'renders Gemini media parts alongside the function response' do
      chat = chat_with_tool_attachment('gemini-2.5-flash', 'gemini')

      parts = chat.render[:contents].last[:parts]
      expect(parts.first).to have_key(:functionResponse)
      expect(parts.last).to have_key(:inline_data)
    end

    it 'splices a user item after Responses API tool results' do
      chat = chat_with_tool_attachment('gpt-5-nano', 'openai')

      input = chat.render[:input]
      followup = input[input.index { |item| item[:type] == 'function_call_output' } + 1]
      expect(followup[:role]).to eq('user')
      expect(followup[:content].first[:text]).to include('call_1')
      expect(followup[:content].last[:type]).to eq('input_image')
    end

    it 'splices a user message after Chat Completions tool results' do
      chat = chat_with_tool_attachment('gpt-5-nano', 'openai', protocol: :chat_completions)

      messages = chat.render[:messages]
      tool_message = messages.find { |message| message[:role] == 'tool' }
      followup = messages[messages.index(tool_message) + 1]
      expect(tool_message[:content]).to eq('Found it')
      expect(followup[:role]).to eq('user')
      expect(followup[:content].last[:type]).to eq('image_url')
    end

    it 'raises for file types a provider cannot take' do
      chat = chat_with_tool_attachment('deepseek-chat', 'deepseek')

      expect { chat.render }.to raise_error(RubyLLM::UnsupportedAttachmentError)
    end
  end
end
