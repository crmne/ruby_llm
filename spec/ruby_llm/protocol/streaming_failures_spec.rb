# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocol::Streaming do
  let(:context) do
    RubyLLM.context do |config|
      config.openai_api_key = 'test'
      config.max_retries = 0
    end
  end
  let(:chat) { context.chat(model: model_for(:openai), provider: :openai) }
  let(:url) { %r{\Ahttps://api\.openai\.com/v1/} }

  def error_body(message, type: 'tokens')
    { error: { message:, type: } }.to_json
  end

  versions = { 'Faraday 1' => '1.10.0' }
  versions['Faraday 2'] = '2.0.0' unless Faraday::VERSION.start_with?('1')

  versions.each do |name, version|
    context "with #{name}" do
      before { stub_const('Faraday::VERSION', version) }

      it 'raises for a 200 with a plain JSON body instead of returning a blank answer' do
        stub_request(:post, url).to_return(status: 200, body: { id: 'x', output: [] }.to_json)

        expect { chat.ask('Hi') { |_chunk| nil } }.to raise_error(RubyLLM::Error, 'Provider returned no stream events')
        expect(chat.messages.map(&:role)).to eq([:user])
      end

      it 'raises for a 200 with an empty body' do
        stub_request(:post, url).to_return(status: 200, body: '')

        expect { chat.ask('Hi') { |_chunk| nil } }.to raise_error(RubyLLM::Error, 'Provider returned no stream events')
      end

      {
        401 => RubyLLM::UnauthorizedError, 403 => RubyLLM::ForbiddenError,
        429 => RubyLLM::RateLimitError, 503 => RubyLLM::ServiceUnavailableError
      }.each do |status, error|
        it "reports a #{status} with its own class and the provider's message" do
          stub_request(:post, url).to_return(status:, body: error_body('From the provider'))

          expect { chat.ask('Hi') { |_chunk| nil } }.to raise_error(error) { |raised|
            expect(raised.provider_message).to eq('From the provider')
          }
        end
      end

      it 'raises an error body sent with a 200' do
        stub_request(:post, url).to_return(status: 200, body: error_body('In the body', type: 'server_error'))

        expect { chat.ask('Hi') { |_chunk| nil } }.to raise_error(RubyLLM::ServerError, /In the body/)
      end
    end
  end
end
