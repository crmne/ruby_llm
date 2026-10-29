# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::Gemini::LongDecode do
  include_context 'with configured RubyLLM'

  let(:model) { model_for(:gemini) }
  let(:instrumenter) { CaptureInstrumenter.new }
  let(:chat) do
    RubyLLM.context do |config|
      config.instrumenter = instrumenter
      config.max_retries = 0
    end.chat(model:, provider: :gemini).with_max_output_tokens(262_144)
  end
  let(:requests) { [] }

  def hop(text = nil, reason: 'STOP', token: nil, parts: nil, input: 10, output: 2, thinking: 0)
    candidate = { content: { role: 'model', parts: parts || [{ text: text.to_s }] }, finishReason: reason }
    candidate[:continuationToken] = token if token
    { candidates: [candidate], modelVersion: model,
      usageMetadata: { promptTokenCount: input, candidatesTokenCount: output, thoughtsTokenCount: thinking } }
  end

  def stub_hops(*bodies, stream: false)
    action = stream ? 'streamGenerateContent?alt=sse' : 'generateContent'
    stub_request(:post, "https://generativelanguage.googleapis.com/v1beta/models/#{model}:#{action}")
      .to_return do |request|
        requests << JSON.parse(request.body)
        body = bodies.shift or raise 'Unexpected continuation request'
        { body: stream ? body : JSON.generate(body),
          headers: { 'Content-Type' => stream ? 'text/event-stream' : 'application/json' } }
      end
  end

  def stream(*events)
    events.map { |event| "data: #{JSON.generate(event)}\n\n" }.join
  end

  def usage_events
    instrumenter.events.filter_map { |name, payload| payload if name == 'usage.ruby_llm' }
  end

  it 'continues an empty thinking hop and records one completed assistant turn' do
    stub_hops(hop(reason: 'CONTINUATION', token: 'next', output: 0, thinking: 8), hop('Answer'))
    completed = []
    chat.after_message { |message| completed << message }

    reply = chat.ask('Think')

    expect(reply.content).to eq('Answer')
    expect(reply.finish_reason).to eq(:stop)
    expect(chat.messages.map(&:role)).to eq(%i[user assistant])
    expect(completed).to eq([reply])
    expect(requests.last).to eq(requests.first.merge('continuationToken' => 'next'))
  end

  it 'assembles several hops using only the latest token and the original request' do
    stub_hops(hop('One ', reason: 'CONTINUATION', token: 'first'),
              hop('two ', reason: 'CONTINUATION', token: 'second'), hop('three'))
    chat.with_instructions('Policy').with_provider_options(customField: { enabled: true })
    hooks = 0
    chat.before_request { |payload| payload[:tag] = (hooks += 1) }

    reply = chat.ask('Count')

    expect(reply.content).to eq('One two three')
    expect(reply.tool_calls).to be_nil
    expect(requests.drop(1)).to eq(%w[first second].map { |token| requests.first.merge('continuationToken' => token) })
    expect(hooks).to eq(1)
    expect(chat.provider_options).not_to have_key(:continuationToken)
  end

  it 'accounts for each hop, its cache reads, owner and thinking without counting output twice' do
    first = hop(reason: 'CONTINUATION', token: 'next', input: 20, output: 0, thinking: 8)
    first[:usageMetadata][:cachedContentTokenCount] = 5
    stub_hops(first, hop('Answer', input: 30, output: 4, thinking: 2))

    reply = RubyLLM.with_usage_owner('owner') { chat.ask('Think') }

    expect(reply.tokens.to_h).to include(input_tokens: 45, output_tokens: 14, thinking_tokens: 10, cache_read_tokens: 5)
    expect(chat.usage_entries.map(&:status)).to eq(%i[succeeded succeeded])
    expect(usage_events.map { |event| event[:owner] }).to eq(%w[owner owner])
    expect(reply.cost.total).to eq(chat.usage_entries.sum { |entry| entry.cost.total })
    expect(reply.ruby_llm_usage_entries).to eq(chat.usage_entries)
  end

  it 'returns every usage entry when called through the provider contract without a Chat recorder' do
    stub_hops(hop('One ', reason: 'CONTINUATION', token: 'next'), hop('two'))

    reply = chat.provider.complete([RubyLLM::Message.new(role: :user, content: 'Think')],
                                   tools: {}, temperature: nil, model: chat.model, max_output_tokens: 262_144)

    expect(reply.ruby_llm_usage_entries.size).to eq(2)
    expect(reply.tokens.input).to eq(20)
    expect(reply.cost.total).to eq(reply.ruby_llm_usage_entries.sum { |entry| entry.cost.total })
  end

  it 'keeps the unfinished answer when a later hop fails and resumes it on complete' do
    first = hop('Partial ', reason: 'CONTINUATION', token: 'next')
    stub_request(:post, "https://generativelanguage.googleapis.com/v1beta/models/#{model}:generateContent")
      .to_return_json(body: first).then.to_return(status: 503, body: '{}')
      .then.to_return do |request|
        requests << JSON.parse(request.body)
        { body: JSON.generate(hop('answer')), headers: { 'Content-Type' => 'application/json' } }
      end
    completed = []
    chat.after_message { |message| completed << message }

    expect { chat.ask('Think') }.to raise_error(RubyLLM::ServiceUnavailableError)
    expect(chat.messages.map(&:role)).to eq(%i[user assistant])
    expect(chat.messages.last.content).to eq('Partial ')
    expect(chat.messages.last.finish_reason).to be_nil
    expect(chat).not_to be_complete
    expect(completed).to be_empty

    reply = chat.complete

    expect(reply.content).to eq('Partial answer')
    expect(reply.finish_reason).to eq(:stop)
    expect(reply.continuation).to be_nil
    expect(chat.messages.map(&:role)).to eq(%i[user assistant])
    expect(completed).to eq([reply])
    expect(requests.last['continuationToken']).to eq('next')
    expect(requests.last['contents'].map { |content| content['role'] }).to eq(['user'])
    expect(chat.usage_entries.map(&:status)).to eq(%i[succeeded failed succeeded])
    expect(reply.ruby_llm_usage_entries.map(&:status)).to eq(%i[succeeded succeeded])
    expect(reply.tokens.input).to eq(20)
  end

  it 'does not fall back to another model once an answer is unfinished' do
    first = hop('Partial', reason: 'CONTINUATION', token: 'next')
    stub_request(:post, "https://generativelanguage.googleapis.com/v1beta/models/#{model}:generateContent")
      .to_return_json(body: first).then.to_return(status: 503, body: '{}')
    chat.with_fallbacks(model_for(:openai))

    expect { chat.ask('Think') }.to raise_error(RubyLLM::ServiceUnavailableError)
    expect(chat.model.id).to eq(model)
    expect(chat.messages.last.continuation).to eq('next')
  end

  it 'rejects a repeated token instead of requesting the same progress forever' do
    stub_hops(hop('One', reason: 'CONTINUATION', token: 'same'),
              hop('Two', reason: 'CONTINUATION', token: 'same'))

    expect { chat.ask('Think') }.to raise_error(RubyLLM::Error, /continuation token/i)
    expect(requests.size).to eq(2)
    expect(chat.usage_entries.size).to eq(2)
  end

  it 'stops at the requested output limit even when the response carries a token' do
    stub_hops(hop('Limit', reason: 'MAX_TOKENS', token: 'unused'))

    reply = chat.ask('Think')

    expect(reply.content).to eq('Limit')
    expect(reply.finish_reason).to eq(:max_tokens)
    expect(requests.size).to eq(1)
  end

  it 'leaves ordinary single-hop responses unchanged' do
    stub_hops(hop('Answer'))

    reply = chat.ask('Think')

    expect(reply.content).to eq('Answer')
    expect(reply.raw_content).to be_nil
    expect(requests.size).to eq(1)
    expect(requests.first).not_to have_key('continuationToken')
  end

  it 'preserves separately signed output parts when replaying an assembled turn' do
    first = hop(reason: 'CONTINUATION', token: 'next', parts: [{ text: 'One', thoughtSignature: 'first-signature' }])
    final = hop(parts: [{ text: 'Two', thoughtSignature: 'final-signature' }])
    stub_hops(first, final)
    chat.ask('Think')
    chat.ask_later('Follow up')

    parts = chat.render[:contents][1][:parts]

    expect(parts).to eq([{ 'text' => 'One', 'thoughtSignature' => 'first-signature' },
                         { 'text' => 'Two', 'thoughtSignature' => 'final-signature' }])
  end

  it 'streams all hops once with continuous chunk indices and one final message' do
    stub_hops(stream(hop('One ', reason: 'CONTINUATION', token: 'next')),
              stream(hop('two')), stream: true)
    chunks = []

    reply = chat.ask('Think') { |chunk| chunks << chunk }

    expect(chunks.filter_map(&:content).join).to eq('One two')
    expect(chunks.map(&:index)).to eq((0...chunks.size).to_a)
    expect(reply.content).to eq('One two')
    expect(reply.tokens.input).to eq(20)
    expect(chat.messages.map(&:role)).to eq(%i[user assistant])
    expect(requests.last).to eq(requests.first.merge('continuationToken' => 'next'))
  end

  it 'uses the last cumulative usage within each stream and sums across streams' do
    stub_hops(stream(hop('One', output: 1), hop(reason: 'CONTINUATION', token: 'next', output: 5)),
              stream(hop('Two', output: 1), hop(output: 3)), stream: true)

    reply = chat.ask('Think') { |_chunk| nil }

    expect(reply.tokens.output).to eq(8)
    expect(reply.tokens.input).to eq(20)
    expect(usage_events.size).to eq(2)
  end

  it 'does not carry a checkpoint token into another normal stream' do
    stub_hops(stream(hop('First', token: 'checkpoint')), stream(hop('Second')), stream: true)
    chat.ask('First') { |_chunk| nil }

    reply = chat.ask('Second') { |_chunk| nil }

    expect(reply.content).to eq('Second')
    expect(requests.last).not_to have_key('continuationToken')
  end

  it 'does not request another hop after cancellation in a streaming callback' do
    stub_hops(stream(hop('Partial', reason: 'CONTINUATION', token: 'next')), stream: true)

    expect { chat.ask('Think') { |_chunk| chat.cancel } }.to raise_error(RubyLLM::CancelledError)
    expect(requests.size).to eq(1)
    expect(chat.usage_entries.first).to be_cancelled
  end

  it 'keeps reasoning text and the last available signature across hops' do
    first = hop(reason: 'CONTINUATION', token: 'next',
                parts: [{ text: 'Think ', thought: true }, { text: '', thoughtSignature: 'signature' }])
    stub_hops(first, hop(parts: [{ text: 'more', thought: true }, { text: 'Answer' }]))

    reply = chat.ask('Think')

    expect(reply.thinking.text).to eq('Think more')
    expect(reply.thinking.signature).to eq('signature')
    expect(reply.content).to eq('Answer')
  end

  it 'keeps an entirely empty multi-hop answer empty' do
    stub_hops(hop(reason: 'CONTINUATION', token: 'next'), hop)

    reply = chat.ask('Think')

    expect(reply.content).to be_nil
    expect(reply.thinking).to be_nil
  end

  it 'retains server-executed parts from every hop for replay' do
    code = { executableCode: { language: 'PYTHON', code: 'print(1)' } }
    result = { codeExecutionResult: { outcome: 'OUTCOME_OK', output: '1' } }
    stub_hops(hop(reason: 'CONTINUATION', token: 'next', parts: [code]),
              hop(parts: [result, { text: 'One' }]))

    reply = chat.ask('Think')

    expect(reply.server_tool_calls.size).to eq(2)
    expect(reply.raw_content).to eq(JSON.parse(JSON.generate([code, result, { text: 'One' }])))
  end

  it 'preserves the final function call without executing it between hops' do
    stub_hops(hop('Planning', reason: 'CONTINUATION', token: 'next'),
              hop(parts: [{ functionCall: { name: 'dice_roll', args: {} }, thoughtSignature: 'call-signature' }]))

    reply = chat.ask_later('Think').generate

    expect(reply.content).to eq('Planning')
    expect(reply.tool_calls.values.map(&:name)).to eq(['dice_roll'])
    expect(reply.tool_calls.values.first.thought_signature).to eq('call-signature')
    expect(requests.size).to eq(2)
  end

  def grounded_hop(prefix, text, **options)
    body = hop(parts: [{ text: prefix }, { text: }], **options)
    body[:candidates].first[:groundingMetadata] = {
      groundingChunks: [{ web: { uri: 'https://ruby-lang.org' } }],
      groundingSupports: [{ segment: { partIndex: 1, endIndex: text.bytesize, text: }, groundingChunkIndices: [0] }]
    }
    body
  end

  [false, true].each do |streaming|
    context "with multipart grounding and streaming #{streaming}" do
      it 'returns character offsets through Chat and a JSON round trip' do
        body = grounded_hop('前言。Ruby', '甲😀Ruby')
        stub_hops(streaming ? stream(body) : body, stream: streaming)

        chunks = []
        reply = streaming ? chat.ask('Ground this') { |chunk| chunks << chunk } : chat.ask('Ground this')
        expect(chunks.filter_map(&:content).join).to eq(reply.content) if streaming
        restored = RubyLLM::Message.new(JSON.parse(JSON.generate(reply.to_h)).transform_keys(&:to_sym))

        [reply, restored].each do |message|
          citation = message.citations.first
          expect(message.content).to eq('前言。Ruby甲😀Ruby')
          expect([citation.start_index, citation.end_index]).to eq([7, 13])
          expect(message.content[citation.start_index...citation.end_index]).to eq(citation.text)
        end
      end

      it 'shifts each hop after locating its part and resets parts on the next request' do
        bodies = [grounded_hop('前言。', 'Ruby', reason: 'CONTINUATION', token: 'next'),
                  grounded_hop('次。', '😀Ruby'), grounded_hop('末。', 'End')]
        stub_hops(*bodies.map { |body| streaming ? stream(body) : body }, stream: streaming)

        chunks = []
        reply = streaming ? chat.ask('Continue') { |chunk| chunks << chunk } : chat.ask('Continue')

        expect(reply.content).to eq('前言。Ruby次。😀Ruby')
        expect(reply.citations.map { |citation| [citation.start_index, citation.end_index] }).to eq([[3, 7], [9, 14]])
        reply.citations.each do |citation|
          expect(reply.content[citation.start_index...citation.end_index]).to eq(citation.text)
        end
        expect(chunks.filter_map(&:content).join).to eq(reply.content) if streaming
        following = streaming ? chat.ask('Again') { |chunk| chunks << chunk } : chat.ask('Again')
        expect(following.citations.map { |citation| [citation.start_index, citation.end_index] }).to eq([[2, 5]])
      end
    end
  end

  it 'retains downloadable attachments from a later hop' do
    image = { inlineData: { mimeType: 'image/png', data: Base64.strict_encode64('image bytes') } }
    stub_hops(hop('Chart', reason: 'CONTINUATION', token: 'next'), hop(parts: [image]))

    reply = chat.ask('Think')

    expect(reply.content).to eq('Chart')
    expect(reply.attachments.map(&:content)).to eq(['image bytes'])
  end

  it 'offsets citation spans into the combined answer and preserves citations without spans' do
    first = hop('One ', reason: 'CONTINUATION', token: 'next')
    first[:candidates][0][:groundingMetadata] = {
      groundingChunks: [{ web: { uri: 'https://example.org', title: 'First source' } }]
    }
    final = hop('Two')
    final[:candidates][0][:groundingMetadata] = {
      groundingChunks: [{ web: { uri: 'https://example.com', title: 'Source' } }],
      groundingSupports: [{ segment: { startIndex: 0, endIndex: 3, text: 'Two' }, groundingChunkIndices: [0] }]
    }
    stub_hops(first, final)

    reply = chat.ask('Think')

    expect(reply.citations.first.start_index).to be_nil
    expect(reply.citations.first.url).to eq('https://example.org')
    citation = reply.citations.last
    expect(citation.url).to eq('https://example.com')
    expect([citation.start_index, citation.end_index]).to eq([4, 7])
    expect(citation.text).to eq('Two')
  end

  it 'retains completed-hop usage when a later streaming response fails' do
    stub_hops(stream(hop('One', reason: 'CONTINUATION', token: 'next')),
              "event: error\ndata: {\"error\":{\"code\":503,\"message\":\"unavailable\"}}\n\n", stream: true)
    chunks = []

    expect { chat.ask('Think') { |chunk| chunks << chunk } }.to raise_error(RubyLLM::ServiceUnavailableError)
    expect(chunks.filter_map(&:content).join).to eq('One')
    expect(chunks.map(&:finish_reason)).to all(be_nil)
    expect(chat.usage_entries.map(&:status)).to eq(%i[succeeded failed])
    expect(chat.messages.map(&:role)).to eq(%i[user assistant])
    expect(chat.messages.last.continuation).to eq('next')
    expect(requests.size).to eq(2)
  end

  it 'announces one message and reports each unfinished answer to the progress recorder' do
    first = hop(reason: 'CONTINUATION', token: 'first', parts: [{ text: 'One ', thoughtSignature: 'signature' }])
    stub_hops(first, hop('two ', reason: 'CONTINUATION', token: 'second'), hop('three'))
    announced = 0
    progress = []
    chat.before_message { announced += 1 }
    chat.progress_recorder = proc { |partial| progress << [partial, chat.messages.last] }

    reply = chat.ask('Count')

    expect(announced).to eq(1)
    expect(progress.map { |partial, last| [partial.content, partial.continuation, last.equal?(partial)] })
      .to eq([['One ', 'first', true], ['One two ', 'second', true]])
    expect(progress.map { |partial, _| partial.finish_reason }).to all(be_nil)
    expect(progress.first.first.raw_content).to eq([{ 'text' => 'One ', 'thoughtSignature' => 'signature' }])
    expect(reply.raw_content).to be_nil
    expect(reply.thinking.signature).to eq('signature')
  end

  it 'does not request another hop after cancellation without streaming' do
    stub_hops(hop('Partial', reason: 'CONTINUATION', token: 'next'))
    chat.before_message { chat.cancel }

    expect { chat.ask('Think') }.to raise_error(RubyLLM::CancelledError)
    expect(requests.size).to eq(1)
    expect(chat.messages.last.continuation).to eq('next')
  end

  it 'replays each signed part of a streamed answer once' do
    first = hop(reason: 'CONTINUATION', token: 'next', parts: [{ text: 'One', thoughtSignature: 'first' }])
    final = hop(parts: [{ text: 'Two', thoughtSignature: 'second' }])
    stub_hops(stream(first), stream(final), stream: true)

    reply = chat.ask('Think') { |_chunk| nil }

    expect(reply.raw_content).to eq([{ 'text' => 'One', 'thoughtSignature' => 'first' },
                                     { 'text' => 'Two', 'thoughtSignature' => 'second' }])
  end

  context 'with an unfinished answer in the transcript' do
    def unfinished_by(model_id)
      entry = RubyLLM::Accounting::Usage::Entry.new(operation: :chat, provider: 'gemini', model: model_id,
                                                    status: :succeeded)
      RubyLLM::Message.new(role: :assistant, content: 'Partial', continuation: 'next', usage_entries: [entry])
    end

    it 'continues it with the model that paused it' do
      chat.add_message(role: :user, content: 'Think')
      chat.add_message(unfinished_by(model))

      payload = chat.render

      expect(payload[:continuationToken]).to eq('next')
      expect(payload[:contents].size).to eq(1)
    end

    it 'sends it as an ordinary answer to another model' do
      chat.add_message(role: :user, content: 'Think')
      chat.add_message(unfinished_by(model_for(:gemini, :structured_output)))

      payload = chat.render

      expect(payload).not_to have_key(:continuationToken)
      expect(payload[:contents].last[:parts]).to eq([{ text: 'Partial' }])
    end
  end
end
