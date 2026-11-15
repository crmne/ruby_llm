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

  it 'filters the credentials of the request it logs from the response body' do
    described_class.with_config(config_with_key('sk-first')) do
      formatter.response(Faraday::Env.from(status: 401, body: '{"error":"bad key sk-first"}'))
    end

    expect(io.string).to include('bad key [FILTERED]')
    expect(io.string).not_to include('sk-first')
  end

  it 'filters the credentials of the request it logs from an exception' do
    skip 'This Faraday does not log exceptions' unless Faraday::Logging::Formatter.method_defined?(:exception)

    described_class.with_config(config_with_key('sk-first')) do
      formatter.exception(Faraday::ClientError.new('rejected sk-first'))
    end

    expect(io.string).to include('rejected [FILTERED]')
    expect(io.string).not_to include('sk-first')
  end

  it 'filters lines Faraday writes without its own filters' do
    described_class.with_config(config_with_key('sk-first')) do
      formatter.debug { 'error: rejected sk-first' }
    end

    expect(io.string).to include('rejected [FILTERED]')
  end

  it 'keeps the progname Faraday 1 passes' do
    described_class.with_config(config_with_key('sk-first')) do
      formatter.debug('response') { 'sk-first' }
    end

    expect(io.string).to include('response: [FILTERED]')
  end

  it 'keeps the outer configuration after a request made inside another' do
    described_class.with_config(config_with_key('sk-outer')) do
      described_class.with_config(config_with_key('sk-inner')) { nil }
      formatter.response(Faraday::Env.from(status: 401, body: 'sk-outer'))
    end

    expect(io.string).to include('[FILTERED]')
    expect(io.string).not_to include('sk-outer')
  end

  it 'writes debug lines to the configuration logger with its credentials filtered' do
    config = config_with_key('sk-first')
    config.logger = Logger.new(io)

    described_class.log_debug(config) { 'chunk with sk-first' }

    expect(io.string).to include('chunk with [FILTERED]')
  end
end
