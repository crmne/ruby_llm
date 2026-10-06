# frozen_string_literal: true

require 'spec_helper'
require 'stringio'

RSpec.describe RubyLLM::Chat do
  include_context 'with configured RubyLLM'

  let(:chat) { RubyLLM.chat(model: model_for(:anthropic), provider: :anthropic) }
  let(:document) { RubyLLM::Attachment.new(StringIO.new('office document'), filename: 'report.docx') }
  let(:replacement) { RubyLLM::Attachment.new(StringIO.new('Extracted report'), filename: 'report.txt') }

  before { chat.add_message(role: :user, content: 'Summarize this report.', attachments: [document]) }

  it 'keeps the existing error when no callback handles the attachment' do
    expect { chat.render }.to raise_error(RubyLLM::UnsupportedAttachmentError)
  end

  it 'uses a replacement for the request while keeping the original transcript' do
    received = []
    expect(chat.convert_unsupported_attachments do |attachment|
      received << attachment
      replacement
    end).to be(chat)

    expect(chat.render.to_json).to include('Extracted report')
    expect(received).to eq([document])
    expect(chat.messages.last.attachments).to eq([document])
  end

  it 'converts an attachment once and reuses the replacement on later requests' do
    calls = 0
    chat.convert_unsupported_attachments do
      calls += 1
      RubyLLM::Attachment.new(StringIO.new('Extracted report'), filename: 'report.txt')
    end

    2.times { expect(chat.render.to_json).to include('Extracted report') }

    expect(calls).to eq(1)
  end

  it 'keeps the existing error when callbacks return nil' do
    chat.convert_unsupported_attachments { nil }

    expect { chat.render }.to raise_error(RubyLLM::UnsupportedAttachmentError)
  end

  it 'uses the first replacement from callbacks registered in order' do
    calls = []
    chat.convert_unsupported_attachments do
      calls << :first
      nil
    end
    chat.convert_unsupported_attachments do
      calls << :second
      replacement
    end
    chat.convert_unsupported_attachments { raise 'Already replaced' }

    chat.render

    expect(calls).to eq(%i[first second])
  end

  it 'does not call the handler when the new provider can render the original' do
    calls = []
    chat.convert_unsupported_attachments do
      calls << :replace
      replacement
    end
    chat.render
    chat.with_model(model_for(:openai), provider: :openai)

    expect(chat.render.to_json).to include('input_file', 'report.docx')
    expect(calls).to eq([:replace])
    expect(chat.messages.last.attachments).to eq([document])
  end

  it 'does not infer attachment support from the model catalog' do
    image = RubyLLM::Attachment.new(File.expand_path('../fixtures/ruby.png', __dir__))
    chat.messages = [RubyLLM::Message.new(role: :user, content: 'Describe this.', attachments: [image])]
    allow(chat.model).to receive(:modalities).and_raise('Must not gate on model metadata')
    chat.convert_unsupported_attachments { raise 'Images are renderable' }

    expect(chat.render.to_json).to include('image')
  end

  it 'rejects a replacement the same protocol cannot render without calling the handler again' do
    calls = 0
    chat.convert_unsupported_attachments do
      calls += 1
      document
    end

    expect { chat.render }.to raise_error(RubyLLM::UnsupportedAttachmentError)
    expect(calls).to eq(1)
  end

  it 'requires a replacement attachment rather than interpreting a string as a path' do
    chat.convert_unsupported_attachments { '/etc/passwd' }

    expect { chat.render }.to raise_error(ArgumentError, /RubyLLM::Attachment or nil/)
  end

  it 'propagates errors from the application callback' do
    chat.convert_unsupported_attachments { raise 'Extraction failed' }

    expect { chat.render }.to raise_error(RuntimeError, 'Extraction failed')
  end

  it 'allows the same callback through an agent' do
    agent = Class.new(RubyLLM::Agent).new(chat: chat)
    expect(agent.convert_unsupported_attachments { replacement }).to be(chat)

    expect(agent.render.to_json).to include('Extracted report')
  end

  it 'converts images in tool results when the protocol accepts images only in user messages' do
    chat.with_model(model_for(:cohere), provider: :cohere)
    image = RubyLLM::Attachment.new(File.expand_path('../fixtures/ruby.png', __dir__))
    chat.messages = [RubyLLM::Message.new(role: :tool, content: 'Report image', tool_call_id: 'call_report',
                                          attachments: [image])]
    received = []
    chat.convert_unsupported_attachments do |attachment|
      received << attachment
      replacement
    end

    expect(chat.render.to_json).to include('Extracted report')
    expect(received).to eq([image])
    expect(chat.messages.last.attachments).to eq([image])
  end

  it 'sends converted Office documents through Anthropic', :live do
    skip_without_cassette_or_key('ANTHROPIC_API_KEY')
    chat.messages = []
    chat.convert_unsupported_attachments do
      RubyLLM::Attachment.new(StringIO.new('The project codename is CEDAR881.'), filename: 'report.txt')
    end

    response = chat.ask('Reply with the project codename in this report and nothing else.', with: document)

    expect(response.content).to include('CEDAR881')
    expect(chat.messages.first.attachments).to eq([document])
  end
end
