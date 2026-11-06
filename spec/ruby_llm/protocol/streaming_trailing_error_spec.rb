# frozen_string_literal: true

require 'rails_helper'

# The bytes below are a wire capture from Gemini 4 Argon on Vertex AI's
# streamGenerateContent: an event, then a bare JSON error with a 200 status.
RSpec.describe RubyLLM::Protocol::Streaming do
  let(:event) do
    [%(data: {"candidates": [{"content": {"role": "model","parts": [{"text": " Cui"}]}}],),
     %("usageMetadata": {"trafficType": "ON_DEMAND"},"modelVersion": "gemini-4-argon",),
     %("createTime": "2026-11-06T14:49:07.662068Z","responseId": "4-jtarS0KPq86PMPhYeg-Ak"}\r\n\r\n)].join
  end
  let(:error) do
    [%({\n  "error": {\n    "code": 500,\n    "message": "Internal error encountered.",\n),
     %(    "status": "INTERNAL"\n  }\n}\n)].join
  end
  let(:context) do
    RubyLLM.context do |config|
      config.gemini_api_key = 'test'
      config.max_retries = 0
    end
  end
  let(:chat) { context.chat(model: model_for(:gemini), provider: :gemini) }
  let(:url) { /streamGenerateContent/ }

  def stream(body)
    stub_request(:post, url).to_return(status: 200, headers: { 'Content-Type' => 'text/event-stream' }, body:)
  end

  versions = { 'Faraday 1' => '1.10.0' }
  versions['Faraday 2'] = '2.0.0' unless Faraday::VERSION.start_with?('1')

  versions.each do |name, version|
    context "with #{name}" do
      before { stub_const('Faraday::VERSION', version) }

      it 'raises a bare JSON error that follows an event' do
        stream(event + error)

        expect { chat.ask('Hi') { |_chunk| nil } }.to raise_error(RubyLLM::ServerError, /Internal error encountered/)
        expect(chat.messages.map(&:role)).to eq([:user])
      end

      it 'raises an error whose last line has no line break' do
        stream(event + error.chomp)

        expect { chat.ask('Hi') { |_chunk| nil } }.to raise_error(RubyLLM::ServerError, /Internal error encountered/)
      end

      it 'raises the error its code maps to' do
        stream(%(#{event}{"error": {"code": 429, "message": "Slow down", "status": "RESOURCE_EXHAUSTED"}}\n))

        expect { chat.ask('Hi') { |_chunk| nil } }.to raise_error(RubyLLM::RateLimitError, /Slow down/)
      end

      ["not an event\n", %({"note": "still working"}\n), %(data: {"candidates": []}\n\n)].each do |line|
        it "keeps the error when #{line.inspect} follows it in the same read" do
          stream(event + error + line)

          expect { chat.ask('Hi') { |_chunk| nil } }.to raise_error(RubyLLM::ServerError, /Internal error encountered/)
        end
      end

      it 'raises rather than drop a bare JSON body too large to read' do
        stream(%(#{event}{"error": {"message": "#{'x' * described_class::MAX_JSON_BODY_BYTES}"}}\n))

        expect { chat.ask('Hi') { |_chunk| nil } }.to raise_error(RubyLLM::Error, /exceeds/)
      end

      it 'ignores a line that is not valid UTF-8' do
        finished = %(data: {"candidates": [{"content": {"parts": [{"text": "!"}]},"finishReason": "STOP"}]}\n\n)
        stream("#{event}{\xFF\xFE\n#{finished}".b)

        expect(chat.ask('Hi') { |_chunk| nil }.content).to eq(' Cui!')
      end

      it 'raises the error wherever the reads are cut' do
        provider = chat.instance_variable_get(:@provider)
        protocol = provider.protocol_for(chat.model).new(provider, chat.model)
        body = event + error

        (1...body.bytesize).each do |cut|
          handler = protocol.send(:build_on_data_handler) { |_event| nil }
          reads = [body.byteslice(0, cut), body.byteslice(cut, body.bytesize)]

          expect { reads.each { |read| handler.call(read, read.bytesize, nil) } }
            .to raise_error(RubyLLM::ServerError, /Internal error encountered/), "cut at byte #{cut}"
        end
      end

      it 'finds the error after other lines the stream does not understand' do
        stream("#{event}not an event\n{\"note\": \"still working\"}\n#{error}")

        expect { chat.ask('Hi') { |_chunk| nil } }.to raise_error(RubyLLM::ServerError, /Internal error encountered/)
      end

      ["not an event\n", %({"note": "still working"}\n), %({"error": null}\n), %({"error": "unfinished\n),
       "<html></html>\n", "[1, 2]\n"].each do |line|
        it "ignores #{line.inspect} as a line the stream does not understand" do
          finished = %(data: {"candidates": [{"content": {"parts": [{"text": "!"}]},"finishReason": "STOP"}]}\n\n)
          stream(event + line + finished)

          expect(chat.ask('Hi') { |_chunk| nil }.content).to eq(' Cui!')
        end
      end
    end
  end

  {
    vertexai: :gemini, openai: :responses, anthropic: :anthropic, xai: :responses,
    openrouter: :chat_completions, mistral: :chat_completions
  }.each do |slug, protocol_name|
    it "raises it on #{slug} through #{protocol_name}" do
      config = RubyLLM.context do |settings|
        settings.vertexai_project_id = 'test'
        settings.vertexai_location = 'global'
        settings.openai_api_key = settings.anthropic_api_key = settings.xai_api_key = 'test'
        settings.openrouter_api_key = settings.mistral_api_key = 'test'
      end.config
      provider = RubyLLM::Provider.resolve!(slug).new(config)
      protocol = provider.class.protocols.fetch(protocol_name).new(provider, nil)
      handler = protocol.send(:build_on_data_handler) { |_event| nil }
      body = %(#{event}{"error": {"code": 500, "type": "server_error", "message": "Internal error encountered."}}\n)

      expect { handler.call(body, 0, nil) }.to raise_error(RubyLLM::ServerError, /Internal error encountered/)
    end
  end

  it 'does not retry a stream that already delivered text' do
    retrying = RubyLLM.context do |config|
      config.gemini_api_key = 'test'
      config.max_retries = 2
      config.retry_interval = 0
    end
    stream(event + error)

    expect { retrying.chat(model: model_for(:gemini), provider: :gemini).ask('Hi') { |_chunk| nil } }
      .to raise_error(RubyLLM::ServerError)
    expect(a_request(:post, url)).to have_been_made.once
  end

  it 'retries an error that arrives before anything was delivered' do
    retrying = RubyLLM.context do |config|
      config.gemini_api_key = 'test'
      config.max_retries = 1
      config.retry_interval = 0
    end
    finished = %(data: {"candidates": [{"content": {"parts": [{"text": "Done"}]},"finishReason": "STOP"}]}\n\n)
    stub_request(:post, url)
      .to_return({ status: 200, body: ": waiting\n\n#{error}" }, { status: 200, body: finished })

    response = retrying.chat(model: model_for(:gemini), provider: :gemini).ask('Hi') { |_chunk| nil }

    expect(response.content).to eq('Done')
    expect(a_request(:post, url)).to have_been_made.twice
  end

  describe 'on a Rails record' do
    before do
      RubyLLM.config.gemini_api_key = 'test'
      RubyLLM.config.max_retries = 0
    end

    it 'keeps no fragment as an answer and records the attempt as failed' do
      record = Chat.create!(model: model_for(:gemini), provider: :gemini)
      stream(event + error)

      expect { record.ask('Hi') { |_chunk| nil } }.to raise_error(RubyLLM::ServerError)
      expect(Message.where(chat_id: record.id, role: 'assistant').where.not(content: [nil, ''])).to be_empty
      expect(RubyLLM::ActiveRecord::Usage.where(chat: record).pluck(:status)).to eq(['failed'])
    end

    it 'keeps the usage the stream reported before the error' do
      record = Chat.create!(model: model_for(:gemini), provider: :gemini)
      counted = [%(data: {"candidates": [{"content": {"role": "model","parts": [{"text": " Cui"}]}}],),
                 %("usageMetadata": {"promptTokenCount": 12,"candidatesTokenCount": 3}}\n\n)].join
      stream(counted + error)

      expect { record.ask('Hi') { |_chunk| nil } }.to raise_error(RubyLLM::ServerError)
      usage = RubyLLM::ActiveRecord::Usage.find_by!(chat: record)
      expect(usage.status).to eq('failed')
      expect(usage.tokens.output).to eq(3)
    end
  end
end
