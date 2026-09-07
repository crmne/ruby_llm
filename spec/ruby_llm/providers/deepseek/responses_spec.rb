# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::DeepSeek::Responses do
  let(:protocol) { described_class.allocate }
  let(:model) { instance_double(RubyLLM::Model, id: model_for(:deepseek)) }
  let(:image) do
    RubyLLM::UploadedFile.new(id: 'file-api-image', filename: 'screenshot.png', mime_type: 'image/png')
  end

  def render(messages, **options)
    protocol.send(:render_payload, messages, tools: {}, temperature: nil, model:, **options)
  end

  it 'sends JSON Schema through the Responses text format' do
    schema = { name: 'person', schema: { type: 'object', properties: { name: { type: 'string' } } } }
    message = RubyLLM::Message.new(role: :user, content: 'Extract the name: Ruby')

    format = render([message], schema:)[:text][:format]

    expect(format).to include(type: 'json_schema', name: 'person', schema: schema[:schema])
  end

  it 'renders inline images as input_image parts' do
    attachment = File.expand_path('../../../fixtures/ruby.png', __dir__)
    message = RubyLLM::Message.new(role: :user, content: 'Describe this image', attachments: attachment)

    part = render([message])[:input].first[:content].last

    expect(part[:type]).to eq('input_image')
    expect(part[:image_url]).to start_with('data:image/png;base64,')
  end

  it 'renders uploaded images as input_image references' do
    message = RubyLLM::Message.new(role: :user, content: 'Read the screenshot', attachments: image)

    parts = render([message])[:input].first[:content]

    expect(parts).to eq([
                          { type: 'input_text', text: 'Read the screenshot' },
                          { type: 'input_image', file_id: 'file-api-image' }
                        ])
  end

  it 'keeps image attachments inside their function call output' do
    message = RubyLLM::Message.new(role: :tool, content: 'Screenshot', tool_call_id: 'call_1', attachments: image)

    items = render([message])[:input]

    expect(items).to eq([{
                          type: 'function_call_output', call_id: 'call_1',
                          output: [{ type: 'input_text', text: 'Screenshot' },
                                   { type: 'input_image', file_id: 'file-api-image' }]
                        }])
  end

  it 'rejects inline documents that DeepSeek cannot read' do
    attachment = File.expand_path('../../../fixtures/sample.pdf', __dir__)
    message = RubyLLM::Message.new(role: :user, content: 'Read this', attachments: attachment)

    expect { render([message]) }.to raise_error(RubyLLM::UnsupportedAttachmentError, %r{application/pdf})
  end

  it 'rejects uploaded documents that DeepSeek cannot read' do
    file = RubyLLM::UploadedFile.new(id: 'file-api-pdf', filename: 'report.pdf', mime_type: 'application/pdf')
    message = RubyLLM::Message.new(role: :user, content: 'Read this', attachments: file)

    expect { render([message]) }.to raise_error(RubyLLM::UnsupportedAttachmentError)
  end

  it 'replays parsed reasoning before a function call' do
    response = {
      'model' => model.id, 'status' => 'completed',
      'output' => [
        { 'type' => 'reasoning', 'content' => [{ 'type' => 'reasoning_text', 'text' => 'Check the weather first.' }] },
        { 'type' => 'function_call', 'call_id' => 'call_1', 'name' => 'weather', 'arguments' => '{"city":"Rome"}' }
      ]
    }
    message = protocol.send(:parse_completion_body, response, raw: response)
    result = RubyLLM::Message.new(role: :tool, tool_call_id: 'call_1', content: 'Sunny')

    items = render([message, result])[:input]

    expect(items).to eq([
                          { type: 'reasoning',
                            content: [{ type: 'reasoning_text', text: 'Check the weather first.' }] },
                          { type: 'function_call', call_id: 'call_1', name: 'weather', arguments: '{"city":"Rome"}' },
                          { type: 'function_call_output', call_id: 'call_1', output: 'Sunny' }
                        ])
  end

  it 'replays server-tool history without duplicating its reasoning' do
    output = [
      { 'type' => 'reasoning', 'content' => [{ 'type' => 'reasoning_text', 'text' => 'Search first.' }] },
      { 'type' => 'web_search_call', 'id' => 'search_1', 'action' => { 'type' => 'search', 'query' => 'Ruby' } }
    ]
    message = protocol.send(:parse_completion_body, { 'status' => 'completed', 'output' => output }, raw: output)

    expect(render([message])[:input]).to eq(output)
  end

  it 'continues a streamed reasoning conversation after a tool result', :live do
    skip_without_cassette_or_key('DEEPSEEK_API_KEY')
    stub_const('LookupNumber', Class.new(RubyLLM::Tool) do
      description 'Returns the current reference number'

      def execute
        137
      end
    end)
    chat = RubyLLM.chat(model: model_for(:deepseek), provider: :deepseek, protocol: :responses)
                  .with_thinking(effort: :low).with_tools(LookupNumber)
    chunks = []

    response = chat.ask('Call lookup_number and tell me the reference number it returns.') { |chunk| chunks << chunk }

    expect(response.content).to include('137')
    expect(chat.messages.find(&:tool_call?).thinking.text).not_to be_empty
    expect(chunks.filter_map(&:thinking)).not_to be_empty
    expect(chat.render[:input].map { |item| item[:type] }).to include('reasoning', 'function_call_output')
  end
end
