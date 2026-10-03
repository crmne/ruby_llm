# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Chat do
  include_context 'with configured RubyLLM'

  let(:chat) { secret_chat(provider: :gemini, model: model_for(:gemini)) }
  let(:turns) do
    ['#0 user: text (15 chars), image/png (15941 bytes)', '#1 model: call lookup (args 27 chars), signed',
     '#2 user: result lookup (13 chars)', '#3 model: thinking (11 chars), text (13 chars), signed',
     '#4 user: text (16 chars)']
  end
  let(:stream) do
    { status: 200, headers: { 'Content-Type' => 'text/event-stream' },
      body: "data: #{JSON.generate(candidates: [{ content: { role: 'model', parts: [{ text: 'Hi' }] } }])}\n\n" }
  end

  def refusal(status = 400)
    { status:, body: JSON.generate(RequestShapeHelpers::REFUSAL), headers: { 'Content-Type' => 'application/json' } }
  end

  it 'describes a refused stream' do
    expect(refused_request_shape(chat) { |_chunk| nil }.turns.map(&:to_s)).to eq(turns)
  end

  it 'describes a refused token count' do
    refuse_requests

    expect { chat.count_tokens }.to raise_error(RubyLLM::BadRequestError) do |error|
      expect(error.request_shape.turns.map(&:to_s)).to eq(turns)
    end
  end

  it 'describes a refused compaction' do
    refuse_requests
    chat = secret_chat(provider: :openai, model: model_for(:openai))

    expect { chat.compact }.to raise_error(RubyLLM::BadRequestError) do |error|
      expect(error.request_shape.turns.first.to_s).to eq('#0 user: text (15 chars), image/png (15941 bytes)')
      expect(error.request_shape.tool_names).to be_empty
    end
  end

  it 'describes the request behind any provider error' do
    refuse_requests(status: 500)

    expect { chat.complete }.to raise_error(RubyLLM::ServerError) do |error|
      expect(error.request_shape.turns.map(&:to_s)).to eq(turns)
    end
  end

  it 'describes a request refused after a retry' do
    RubyLLM.config.max_retries = 1
    stub_request(:post, /.*/).to_return(refusal(500), refusal(400))

    expect { chat.complete }.to raise_error(RubyLLM::BadRequestError) do |error|
      expect(error.request_shape.turns.map(&:to_s)).to eq(turns)
    end
  end

  it 'describes a stream the provider refuses after it starts' do
    stub_request(:post, /.*/).to_return(stream.merge(body: "data: #{JSON.generate(RequestShapeHelpers::REFUSAL)}\n\n"))

    expect { chat.complete { |_chunk| nil } }.to raise_error(RubyLLM::Error) do |error|
      expect(error.request_shape.turns.map(&:to_s)).to eq(turns)
    end
  end

  it 'describes a stream that ends with a failed response event' do
    failed = { type: 'response.failed', response: { status: 'failed', output: [], model: model_for(:openai),
                                                    error: { code: 'invalid_image', message: 'Invalid image.' } } }
    stub_request(:post, /.*/)
      .to_return(stream.merge(body: "event: response.failed\ndata: #{JSON.generate(failed)}\n\n"))
    chat = secret_chat(provider: :openai, model: model_for(:openai))

    expect { chat.complete { |_chunk| nil } }.to raise_error(RubyLLM::BadRequestError, 'Invalid image.') do |error|
      expect(error.request_shape.turn_count).to eq(7)
    end
  end

  it 'counts the model calls of the turn the refused request continues' do
    call = RubyLLM::ToolCall.new(id: 'secret-call-2', name: 'lookup', arguments: {})
    chat.add_message(role: :assistant, content: nil, tool_calls: { 'secret-call-2' => call })
    chat.add_message(role: :tool, content: 'secret', tool_call_id: 'secret-call-2')
    shape = refused_request_shape(chat)

    expect(shape.step).to eq(2)
    expect(shape.to_s.lines.first.chomp)
      .to eq("gemini, #{model_for(:gemini)}, model call 2 of the turn, after 1 tool round")
  end

  it 'keeps the first and last turns of a long conversation' do
    60.times { |turn| chat.add_message(role: turn.even? ? :assistant : :user, content: 'secret') }
    shape = refused_request_shape(chat)

    expect(shape).to have_attributes(turn_count: 65, omitted_turns: 5)
    expect(shape.turns.map(&:index)).to eq([*0..9, *15..64])
    expect(shape.to_s).to include("#9 model: text (6 chars)\n(5 turns omitted)\n#15 model: text (6 chars)")
    expect_no_secrets(shape)
  end

  it 'keeps the message the provider gave' do
    refuse_requests

    expect { chat.complete }.to raise_error(RubyLLM::BadRequestError) do |error|
      error.request_shape
      expect(error.message).to eq('Request contains an invalid argument.')
      expect(error.inspect).to eq('#<RubyLLM::BadRequestError: Request contains an invalid argument.>')
    end
  end

  it 'leaves an error the streaming block raises to the operation that raised it' do
    refuse_requests
    stub_request(:post, /streamGenerateContent/).to_return(stream)
    other = RubyLLM.chat(model: model_for(:gemini), provider: :gemini)
    other.add_message(role: :user, content: 'secret?')
    embed = -> { RubyLLM.embed('secret', model: model_for(:gemini, :embedding), provider: :gemini) }

    expect { chat.complete { |_chunk| embed.call } }
      .to raise_error(RubyLLM::BadRequestError) { |error| expect(error.request_shape).to be_nil }
    expect { chat.complete { |_chunk| other.complete } }
      .to raise_error(RubyLLM::BadRequestError) do |error|
        expect(error.request_shape.turns.map(&:to_s)).to eq(['#0 user: text (7 chars)'])
      end
  end

  it 'describes nothing for an error raised before the request goes out' do
    document = RubyLLM::Attachment.new(StringIO.new('secret'), filename: 'secret.docx')

    expect { chat.ask('secret', with: document) }.to raise_error(RubyLLM::UnsupportedAttachmentError) do |error|
      expect(error.request_shape).to be_nil
      expect(Marshal.load(Marshal.dump(error)).message).to eq(error.message)
    end
  end

  it 'describes nothing for an operation that sends no conversation' do
    refuse_requests

    expect { RubyLLM.embed('secret', model: model_for(:gemini, :embedding), provider: :gemini) }
      .to raise_error(RubyLLM::BadRequestError) { |error| expect(error.request_shape).to be_nil }
  end
end
