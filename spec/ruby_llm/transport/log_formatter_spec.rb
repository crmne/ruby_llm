# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Transport::LogFormatter do
  let(:io) { StringIO.new }
  let(:formatter) do
    described_class.new(logger: Logger.new(io), options: { bodies: true, errors: true, headers: false,
                                                           log_level: :debug })
  end

  def config_with_key(key)
    RubyLLM::Configuration.new.tap { |config| config.openai_api_key = key }
  end

  def request_env(config)
    Faraday::Env.from(
      method: :post, url: URI('https://api.example.test/v1/chat'),
      request: Faraday::RequestOptions.new.tap { |options| options.context = { described_class::CONFIG_KEY => config } }
    )
  end

  it 'filters the credentials of the request it logs from the response body' do
    formatter.request(request_env(config_with_key('sk-first')))
    formatter.response(Faraday::Env.from(status: 401, body: '{"error":"bad key sk-first"}'))

    expect(io.string).to include('bad key [FILTERED]')
    expect(io.string).not_to include('sk-first')
  end

  it 'filters the credentials of the request it logs from an exception' do
    formatter.request(request_env(config_with_key('sk-first')))
    formatter.exception(Faraday::ClientError.new('rejected sk-first'))

    expect(io.string).to include('rejected [FILTERED]')
    expect(io.string).not_to include('sk-first')
  end

  it 'filters each request by its own configuration' do
    formatter.request(request_env(config_with_key('sk-first')))
    formatter.response(Faraday::Env.from(status: 401, body: 'sk-first'))
    formatter.request(request_env(config_with_key('sk-second')))
    formatter.response(Faraday::Env.from(status: 401, body: 'sk-first sk-second'))

    expect(io.string.lines.last).to include('sk-first [FILTERED]')
  end

  it 'writes debug lines to the configuration logger with its credentials filtered' do
    config = config_with_key('sk-first')
    config.logger = Logger.new(io)

    described_class.debug(config) { 'chunk with sk-first' }

    expect(io.string).to include('chunk with [FILTERED]')
  end
end
