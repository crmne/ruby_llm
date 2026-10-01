# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Transport::Connection do
  describe 'with a keep-alive adapter' do
    let(:server) { KeepAlive::Server.new }
    let(:questions) { { keep_alive_expected: { type: :probability, instructions: 'Is the socket reused?' } } }

    after { server.close }

    def context(**options)
      RubyLLM.context do |config|
        config.faraday_adapter = KeepAlive::Adapter
        config.openai_api_key = 'test'
        config.openai_api_base = "#{server.url}/v1"
        config.typesafe_api_key = 'test'
        config.typesafe_api_base = server.url
        options.each { |option, value| config.public_send(:"#{option}=", value) }
      end
    end

    def embed(context)
      context.embed('Ruby', model: model_for(:openai, :embedding))
    end

    it 'reuses one socket across consecutive calls' do
      llm = context

      3.times { embed(llm) }

      expect(server.requests).to eq([1, 1, 1])
    end

    it 'reuses one socket across consecutive judgments' do
      llm = context

      2.times { llm.judge('RubyLLM calls AI APIs.', model: model_for(:typesafe, :judgment), questions:) }

      expect(server.requests).to eq([1, 1])
    end

    it 'shares the socket between contexts that only differ in credentials' do
      tenant_a = context(openai_api_key: 'tenant-a')
      tenant_b = context(openai_api_key: 'tenant-b')

      [tenant_a, tenant_b, tenant_a].each { |llm| embed(llm) }

      expect(server.requests).to eq([1, 1, 1])
      expect(server.authorizations).to eq(['Bearer tenant-a', 'Bearer tenant-b', 'Bearer tenant-a'])
    end

    it 'opens another socket for a context with other connection settings' do
      embed(context)
      embed(context(request_timeout: 30))

      expect(server.requests).to eq([1, 2])
    end

    it 'shares the adapter across threads' do
      llm = context

      Array.new(4) { Thread.new { 2.times { embed(llm) } } }.each(&:join)

      expect(server.requests).to eq([1] * 8)
    end

    it 'shares the adapter across fibers' do
      llm = context

      in_reactor { |task| Array.new(4) { task.async { embed(llm) } }.each(&:wait) }

      expect(server.requests).to eq([1] * 4)
    end

    it 'never sends a forked child through the parent socket' do
      skip 'fork is unavailable' unless Process.respond_to?(:fork)
      llm = context
      provider = RubyLLM::Providers::OpenAI.new(llm.config)
      embed(llm)

      pid = fork do
        embed(llm)
        provider.connection.post('embeddings', { model: model_for(:openai, :embedding), input: 'Ruby' })
        exit!(0)
      rescue StandardError
        exit!(1)
      end
      _, status = Process.wait2(pid)
      provider.connection.post('embeddings', { model: model_for(:openai, :embedding), input: 'Ruby' })

      expect(status).to be_success
      expect(server.requests).to eq([1, 2, 2, 1])
    end
  end
end
