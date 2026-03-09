# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Connection do
  describe 'logging middleware configuration' do
    let(:provider) do
      instance_double(
        RubyLLM::Provider,
        api_base: 'https://example.com',
        configured?: true,
        headers: {}
      )
    end

    let(:config) do
      instance_double(
        RubyLLM::Configuration,
        request_timeout: 300,
        max_retries: 3,
        retry_interval: 0.1,
        retry_interval_randomness: 0.5,
        retry_backoff_factor: 2,
        http_proxy: nil,
        log_regexp_timeout: 1.0
      )
    end

    it 'disables body logging when log level is above DEBUG' do
      logger = Logger.new(File::NULL, level: Logger::INFO)
      allow(RubyLLM).to receive(:logger).and_return(logger)

      connection = described_class.new(provider, config).connection
      handler = connection.builder.handlers.find { |h| h.klass == Faraday::Response::Logger }
      middleware = handler.build(->(_env) { Faraday::Response.new })
      options = middleware.instance_variable_get(:@formatter).instance_variable_get(:@options)

      expect(options[:bodies]).to be(false)
    end

    it 'enables body logging when log level is DEBUG' do
      logger = Logger.new(File::NULL, level: Logger::DEBUG)
      allow(RubyLLM).to receive(:logger).and_return(logger)

      connection = described_class.new(provider, config).connection
      handler = connection.builder.handlers.find { |h| h.klass == Faraday::Response::Logger }
      middleware = handler.build(->(_env) { Faraday::Response.new })
      options = middleware.instance_variable_get(:@formatter).instance_variable_get(:@options)

      expect(options[:bodies]).to be(true)
    end
  end
end
