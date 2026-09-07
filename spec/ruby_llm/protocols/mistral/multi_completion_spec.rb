# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::Mistral::MultiCompletion do
  include_context 'with configured RubyLLM'

  let(:chat) { RubyLLM.chat(model: model_for(:mistral), provider: :mistral) }
  let(:protocol) { RubyLLM::Providers::Mistral::ChatCompletions.new(chat.provider, chat.model) }
  let(:call) do
    { 'id' => 'imagecall', 'type' => 'function', 'function' => { 'name' => 'generate_image', 'arguments' => '{}' },
      'metadata' => { 'tool_type' => 'image' } }
  end
  let(:messages) do
    [
      { 'role' => 'assistant', 'content' => '', 'tool_calls' => [call], 'index' => 0 },
      { 'role' => 'tool', 'tool_call_id' => 'imagecall', 'content' => '{"url":"https://example.com/image.jpg"}',
        'index' => 1 },
      { 'role' => 'assistant', 'content' => [
        { 'type' => 'text', 'text' => 'Your image.' },
        { 'type' => 'image_url', 'image_url' => 'https://example.com/image.jpg' }
      ], 'index' => 2 }
    ]
  end

  def body(messages, usage = {})
    { 'model' => chat.model.id, 'choices' => [{ 'messages' => messages, 'finish_reason' => 'stop' }], 'usage' => usage }
  end

  it 'parses completed hosted tools and images without scheduling a local tool' do
    message = protocol.send(:parse_completion_body, body(messages), raw: nil)
    expect(message.content).to eq('Your image.')
    expect(message.attachments.first.source.to_s).to eq('https://example.com/image.jpg')
    expect(message).not_to be_tool_call
    expect(message.server_tool_calls.first).to have_attributes(name: 'generate_image', id: 'imagecall')
    expect(message.raw_content).to eq(messages)
    expect(protocol.send(:format_messages, [message])).to eq(messages.map { |entry| entry.except('index') })
  end

  it 'keeps an unanswered local function call separate from completed hosted calls' do
    local_call = { 'id' => 'localcall', 'type' => 'function',
                   'function' => { 'name' => 'calculate', 'arguments' => '{}' } }
    messages.last['tool_calls'] = [local_call]
    message = protocol.send(:parse_completion_body, body(messages), raw: nil)
    expect(message.tool_calls.keys).to eq(['localcall'])
    expect(message.tool_calls.values.first).not_to be_remote
  end

  it 'refuses to execute an unfinished hosted call as a local tool' do
    expect { protocol.send(:parse_completion_body, body([messages.first]), raw: nil) }
      .to raise_error(RubyLLM::Error, /unfinished hosted tool/)
  end

  it 'renders only the hosted tools supported by Chat Completions without an invented request flag' do
    payload = chat.with_server_tools(:image_generation, mcp: { connector_id: 'docs' }).ask_later('Draw').render
    expect(payload[:tools]).to eq([{ type: 'image_generation' }, { type: 'connector', connector_id: 'docs' }])
    expect(payload).not_to have_key(:multi_completion)
  end

  it 'sums separate streamed completions and does not expose tool result text as assistant output' do
    events = [
      { 'id' => 'first', 'choices' => [{ 'delta' => { 'index' => 0, 'role' => 'assistant',
                                                      'tool_calls' => [call.merge('index' => 0)] },
                                         'finish_reason' => 'tool_calls' }],
        'usage' => { 'prompt_tokens' => 10, 'completion_tokens' => 2, 'total_tokens' => 12 } },
      { 'id' => 'first', 'choices' => [{ 'delta' => messages[1] }] },
      { 'id' => 'second', 'choices' => [{ 'delta' => messages[2], 'finish_reason' => 'stop' }],
        'usage' => { 'prompt_tokens' => 20, 'completion_tokens' => 3, 'total_tokens' => 23 } }
    ]
    allow(protocol).to receive(:stream_events).and_wrap_original do |_method, *_args, &block|
      events.each(&block)
      instance_double(Faraday::Response)
    end
    chunks = []
    message = protocol.send(:stream_response, { tools: [{ type: 'image_generation' }] }) { |chunk| chunks << chunk }
    expect(chunks.filter_map(&:content).join).to eq('Your image.')
    expect(message.tokens).to have_attributes(input: 30, output: 5)
    expect(message).not_to be_tool_call
    expect(message.attachments.size).to eq(1)
  end

  it 'streams and downloads a hosted image through the default chat API', :live do
    chunks = []
    chat.with_server_tools(:image_generation)
        .with_instructions('Generate the requested image once. Answer follow-up questions from the previous result.')
    response = chat.ask('Generate one image of a small blue square on a white background.') { |chunk| chunks << chunk }
    expect(chunks.filter_map(&:content).join).to eq(response.content)
    expect(response.server_tool_calls).to include(have_attributes(name: 'generate_image'))
    expect(response).not_to be_tool_call
    expect(response.attachments.first.content.bytesize).to be > 1000
    expect(response.tokens.input).to be_positive
    expect(chat.ask('What color was the square?').content).to match(/blue/i)
  end
end
