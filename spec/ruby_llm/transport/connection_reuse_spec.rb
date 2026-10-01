# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Transport::Connection do
  include_context 'with configured RubyLLM'

  let(:config) { RubyLLM.config.dup }

  def faraday_for(config, provider_class = RubyLLM::Providers::OpenAI)
    provider_class.new(config).connection.connection
  end

  def configured(**options)
    config.dup.tap do |copy|
      options.each { |option, value| copy.public_send(:"#{option}=", value) }
    end
  end

  describe 'keying' do
    it 'shares one Faraday connection between providers built from equal settings' do
      expect(faraday_for(config)).to be(faraday_for(config.dup))
    end

    it 'shares it between configurations that only differ in credentials' do
      tenant_a = faraday_for(configured(openai_api_key: 'tenant-a'))

      expect(faraday_for(configured(openai_api_key: 'tenant-b'))).to be(tenant_a)
    end

    it 'builds a separate connection for each setting the connection depends on' do
      shared = faraday_for(config)

      {
        openai_api_base: 'https://openai.example.test/v1', request_timeout: 7, http_proxy: 'http://proxy.example.test:8080',
        faraday_adapter: :test, max_retries: 9, retry_interval: 2.5, retry_max_interval: 99,
        retry_interval_randomness: 0.9, retry_backoff_factor: 5, log_regexp_timeout: 3.0
      }.each do |option, value|
        expect(faraday_for(configured(option => value))).not_to be(shared), "expected #{option} to separate connections"
      end
    end

    it 'builds a separate connection for each provider' do
      same_base = configured(xai_api_base: 'https://api.openai.com/v1')

      expect(faraday_for(same_base, RubyLLM::Providers::XAI)).not_to be(faraday_for(same_base))
    end

    it 'builds a separate connection when the logger changes what it records' do
      shared = faraday_for(config)
      allow(RubyLLM).to receive(:logger).and_return(Logger.new(File::NULL, level: Logger::DEBUG))

      expect(faraday_for(config)).not_to be(shared)
    end

    it 'gives streaming requests a shared connection of their own' do
      streaming = RubyLLM::Providers::OpenAI.new(config).connection.connection(stream: true)

      expect(streaming).not_to be(faraday_for(config))
      expect(RubyLLM::Providers::OpenAI.new(config.dup).connection.connection(stream: true)).to be(streaming)
    end

    it 'streams after buffered requests on adapters that settle on streaming at their first request' do
      first_request_decides = Class.new(Faraday::Adapter) do
        def call(env)
          super
          @streams = env.request.stream_response? if @streams.nil?
          raise Faraday::ConnectionFailed, 'this session cannot stream' if env.request.stream_response? && !@streams

          save_response(env, 200, '')
          @app.call(env)
        end
      end
      transport = RubyLLM::Providers::OpenAI.new(configured(faraday_adapter: first_request_decides)).connection
      transport.post('chat/completions', {})

      expect { transport.post('chat/completions', {}, stream: true) { |req| req.options.on_data = proc {} } }
        .not_to raise_error
    end

    it 'builds the middleware stack before it is shared' do
      expect(faraday_for(config).builder).to be_locked
    end

    it 'refuses changes that would reach every context sharing it' do
      faraday = faraday_for(config)

      expect { faraday.headers['X-Tenant'] = 'tenant-a' }.to raise_error(FrozenError)
      expect { faraday.options.timeout = 1 }.to raise_error(FrozenError)
      expect { faraday.params['tenant'] = 'tenant-a' }.to raise_error(FrozenError)
    end
  end

  describe 'settings' do
    def changed_value(option, value)
      return :test if option == :faraday_adapter

      case value
      when nil then 'http://changed.example.test'
      when true, false then !value
      when Numeric then value + 1
      when String then "#{value}-changed"
      when Symbol then :"#{value}_changed"
      else Object.new
      end
    end

    def describe_state(object, depth = 0)
      case object
      when Regexp then [object.source, object.options, object.respond_to?(:timeout) ? object.timeout : nil]
      when Proc, Method then :callable
      when Module then object.name || :anonymous
      when Logger, IO then object.object_id
      when Hash then object.to_h { |key, value| [key, describe_state(value, depth)] }
      when Struct then describe_state(object.to_h, depth)
      when Array, Set then object.map { |value| describe_state(value, depth) }
      when String, Symbol, Numeric, true, false, nil then object
      else describe_object(object, depth)
      end
    end

    def describe_object(object, depth)
      return object.class if depth > 3

      ivars = object.instance_variables - [:@app]
      [object.class, ivars.to_h { |ivar| [ivar, describe_state(object.instance_variable_get(ivar), depth + 1)] }]
    end

    def fingerprint(faraday)
      middleware = []
      app = faraday.app
      until app.is_a?(Proc)
        middleware << describe_object(app, 0)
        app = app.instance_variable_get(:@app)
      end
      [faraday.url_prefix.to_s, faraday.headers.to_h, describe_state(faraday.options), faraday.proxy&.uri.to_s,
       middleware]
    end

    def fresh_faraday_for(config, provider_class)
      described_class.cache.clear
      faraday_for(config, provider_class)
    end

    # The guard against a connection setting that never reaches the cache
    # key: an option that changes the connection RubyLLM builds must never
    # let two configurations share one.
    it 'differ for every configuration option that changes the connection' do
      providers = [RubyLLM::Providers::OpenAI, RubyLLM::Providers::VertexAI, RubyLLM::Providers::Bedrock]
      shared_unequal = providers.product(RubyLLM::Configuration.options).filter_map do |provider_class, option|
        changed = configured(option => changed_value(option, config.public_send(option)))
        described_class.cache.clear
        next unless faraday_for(config, provider_class).equal?(faraday_for(changed, provider_class))

        [provider_class, option] unless fingerprint(fresh_faraday_for(config, provider_class)) ==
                                        fingerprint(fresh_faraday_for(changed, provider_class))
      rescue RubyLLM::ConfigurationError
        nil
      end

      expect(shared_unequal).to be_empty
    end
  end

  describe 'requests sharing a connection' do
    let(:url) { 'https://api.openai.com/v1/embeddings' }
    let(:arrived) { Queue.new }
    let(:release) { Queue.new }

    def hold_until_all_arrive
      arrived << true
      release.pop
    end

    def in_flight_together(threads)
      Timeout.timeout(5) { threads.size.times { arrived.pop } }
      threads.size.times { release << true }
      threads.map(&:value)
    ensure
      threads.each { |thread| thread.kill.join if thread.alive? }
    end

    it 'parse errors with the provider that sent them' do
      tenant_provider = Class.new(RubyLLM::Providers::OpenAI) do
        def parse_error(response)
          "#{@config.openai_api_key}: #{super}"
        end
      end
      stub_request(:post, url).to_return(status: 400, body: '{"error":{"message":"Invalid input"}}',
                                         headers: { 'Content-Type' => 'application/json' })
      tenant_a = tenant_provider.new(configured(openai_api_key: 'tenant-a'))
      tenant_b = tenant_provider.new(configured(openai_api_key: 'tenant-b'))

      expect(tenant_a.connection.connection).to be(tenant_b.connection.connection)
      expect { tenant_a.connection.post('embeddings', {}) }.to raise_error(RubyLLM::BadRequestError, /\Atenant-a:/)
      expect { tenant_b.connection.post('embeddings', {}) }.to raise_error(RubyLLM::BadRequestError, /\Atenant-b:/)
    end

    it 'keep credentials and usage apart while they are in flight together' do
      stub_request(:post, url).to_return do |request|
        hold_until_all_arrive
        input = JSON.parse(request.body)['input']
        { status: 200, headers: { 'Content-Type' => 'application/json' },
          body: JSON.generate(data: [{ embedding: [input.length.to_f] }],
                              usage: { prompt_tokens: input.length, total_tokens: input.length }) }
      end
      tenants = { 'tenant-a' => 'Ruby', 'tenant-bb' => 'Rails on Ruby' }

      embeddings = in_flight_together(tenants.map do |key, text|
        Thread.new { RubyLLM.context { |c| c.openai_api_key = key }.embed(text, model: model_for(:openai, :embedding)) }
      end)

      expect(embeddings.map { |embedding| embedding.tokens.input }).to eq([4, 13])
      expect(embeddings.map(&:vectors)).to eq([[4.0], [13.0]])
      expect(a_request(:post, url).with(headers: { 'Authorization' => 'Bearer tenant-a' })).to have_been_made.once
      expect(a_request(:post, url).with(headers: { 'Authorization' => 'Bearer tenant-bb' })).to have_been_made.once
    end

    it 'keep the responses of many fibers apart in one reactor' do
      stub_request(:post, url).to_return do |request|
        sleep(rand / 200)
        input = JSON.parse(request.body)['input']
        { status: 200, headers: { 'Content-Type' => 'application/json' },
          body: JSON.generate(data: [{ embedding: [input.length.to_f] }],
                              usage: { prompt_tokens: input.length, total_tokens: input.length }) }
      end
      stub_request(:post, 'https://api.openai.com/v1/chat/completions').to_return do |request|
        sleep(rand / 200)
        content = JSON.parse(request.body)['messages'].last['content']
        { status: 200, body: "data: #{JSON.generate(choices: [{ delta: { content: } }])}\n\ndata: [DONE]\n\n" }
      end

      results = in_reactor do |task|
        Array.new(20) do |index|
          task.async do
            text = "fiber #{index}"
            next RubyLLM.embed(text, model: model_for(:openai, :embedding)).tokens.input if index.odd?

            chunks = []
            RubyLLM.chat(model: model_for(:openai), protocol: :chat_completions).ask(text) do |chunk|
              chunks << chunk.content
            end
            chunks.join
          end
        end.map(&:wait)
      end

      expect(results).to eq(Array.new(20) { |index| index.odd? ? "fiber #{index}".length : "fiber #{index}" })
    end

    it 'stream to their own handlers while they are in flight together' do
      stub_request(:post, url).to_return do |request|
        hold_until_all_arrive
        { status: 200, body: "data: #{request.body}\n\n" }
      end
      transport = RubyLLM::Providers::OpenAI.new(config).connection

      streams = in_flight_together(%w[alpha beta].map do |name|
        Thread.new do
          chunks = []
          transport.post('embeddings', { name: }, stream: true) do |req|
            req.options.on_data = proc { |chunk, _bytes, _env| chunks << chunk }
          end
          chunks.join
        end
      end)

      expect(streams).to eq(["data: {\"name\":\"alpha\"}\n\n", "data: {\"name\":\"beta\"}\n\n"])
    end
  end

  describe 'provider connections beyond the main one' do
    it 'shares Bedrock mantle and agent connections between providers' do
      first = RubyLLM::Providers::Bedrock.new(config)
      second = RubyLLM::Providers::Bedrock.new(config.dup)

      expect(second.mantle_connection.connection).to be(first.mantle_connection.connection)
      expect(second.agent_connection.connection).to be(first.agent_connection.connection)
      expect(first.mantle_connection.connection).not_to be(first.connection.connection)
    end

    it 'sends each Vertex AI project its own ranking header over a shared connection' do
      endpoint = %r{\Ahttps://discoveryengine\.googleapis\.com/v1/}
      stub_request(:post, endpoint).to_return_json(body: { records: [] })
      providers = %w[project-a project-b].map do |project|
        RubyLLM::Providers::VertexAI.new(configured(vertexai_project_id: project)).tap do |provider|
          allow(provider).to receive(:headers).and_return('Authorization' => 'Bearer test')
        end
      end

      providers.each { |provider| provider.ranking_connection.post('rank', {}) }

      expect(providers.map { |provider| provider.ranking_connection.connection }.uniq.size).to eq(1)
      expect(providers.first.ranking_connection.connection.headers).not_to include('X-Goog-User-Project')
      %w[project-a project-b].each do |project|
        expect(a_request(:post, endpoint).with(headers: { 'X-Goog-User-Project' => project })).to have_been_made.once
      end
    end
  end
end
