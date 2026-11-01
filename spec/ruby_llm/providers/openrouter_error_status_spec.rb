# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::OpenRouter do
  include_context 'with configured RubyLLM'

  let(:chat_url) { 'https://openrouter.ai/api/v1/chat/completions' }
  let(:headers) { { 'Content-Type' => 'application/json' } }
  let(:failure) { JSON.generate(error: { code: 502, message: 'Provider returned error' }) }
  let(:answer) do
    JSON.generate(model: 'openai/gpt-5-nano', usage: { prompt_tokens: 1, completion_tokens: 1 },
                  choices: [{ finish_reason: 'stop',
                              message: { role: 'assistant', content: 'The "error" was fixed' } }])
  end

  before do
    RubyLLM.config.max_retries = 1
    RubyLLM.config.retry_interval = 0
  end

  def chat
    RubyLLM.chat(model: 'openai/gpt-5-nano', provider: :openrouter, assume_model_exists: true)
  end

  it 'retries an error sent with HTTP 200' do
    request = stub_request(:post, chat_url)
              .to_return({ status: 200, body: failure, headers: }, { status: 200, body: answer, headers: })

    expect(chat.ask('Hello').content).to eq('The "error" was fixed')
    expect(request).to have_been_requested.twice
  end

  it 'retries an empty body' do
    request = stub_request(:post, chat_url)
              .to_return({ status: 200, body: '', headers: }, { status: 200, body: answer, headers: })

    expect(chat.ask('Hello').content).to eq('The "error" was fixed')
    expect(request).to have_been_requested.twice
  end

  it 'raises the class of the code the body names' do
    body = JSON.generate(error: { code: 429, message: 'Slow down' })
    stub_request(:post, chat_url).to_return(status: 200, body:, headers:)

    expect { chat.ask('Hello') }.to raise_error(RubyLLM::RateLimitError, 'Slow down')
  end

  it 'keeps a code of exactly 400 and ignores an error that is not an object' do
    bad_request = JSON.generate(error: { code: 400, message: 'Bad' })
    stub_request(:post, chat_url).to_return(status: 200, body: bad_request, headers:)
    not_an_object = Faraday::Env.from(status: 200, body: JSON.generate(error: 'none'),
                                      request: Faraday::RequestOptions.new)

    expect { chat.ask('Hello') }.to raise_error(RubyLLM::BadRequestError, 'Bad')
    expect(chat.provider.error_status(not_an_object)).to be_nil
  end

  it 'treats an error without a numeric code as a failed upstream' do
    body = JSON.generate(error: { code: 'upstream', message: 'No luck' })
    request = stub_request(:post, chat_url).to_return(status: 200, body:, headers:)

    expect { chat.ask('Hello') }.to raise_error(RubyLLM::ServiceUnavailableError, 'No luck')
    expect(request).to have_been_requested.twice
  end

  it 'raises a RubyLLM error for a failed embedding' do
    stub_request(:post, 'https://openrouter.ai/api/v1/embeddings').to_return(status: 200, body: failure, headers:)

    expect do
      RubyLLM.embed('Hello', model: 'qwen/qwen3-embedding-8b', provider: :openrouter, assume_model_exists: true)
    end.to raise_error(RubyLLM::ServiceUnavailableError)
  end

  it 'leaves a stream alone, whose body is empty here' do
    body = "data: #{JSON.generate(choices: [{ delta: { content: 'Hi' }, finish_reason: 'stop' }])}\n\ndata: [DONE]\n\n"
    stub_request(:post, chat_url).to_return(status: 200, body:, headers: { 'Content-Type' => 'text/event-stream' })

    expect(chat.ask('Hello') { |_chunk| nil }.content).to eq('Hi')
  end
end
