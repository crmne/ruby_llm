# frozen_string_literal: true

require 'spec_helper'
require 'aws-sigv4'
require 'socket'

RSpec.describe RubyLLM::Providers::Bedrock::Connection do
  def provider_for(**endpoints)
    config = RubyLLM::Configuration.new
    config.bedrock_region = 'us-east-1'
    config.bedrock_api_key = 'key'
    config.bedrock_secret_key = 'secret'
    config.max_retries = 0
    endpoints.each { |option, base| config.public_send("#{option}=", base) }
    RubyLLM::Providers::Bedrock.new(config)
  end

  # What a verifying gateway computes with AWS's own signer. It derives the
  # host from the URL and the payload hash from the body.
  def expected_signature(method, url, date, body, service: 'bedrock')
    Aws::Sigv4::Signer.new(service:, region: 'us-east-1', access_key_id: 'key', secret_access_key: 'secret')
                      .sign_request(http_method: method, url:, headers: { 'x-amz-date' => date }, body:)
                      .headers['authorization'][/Signature=(\h+)/, 1]
  end

  def signature(authorization)
    authorization[/Signature=(\h+)/, 1]
  end

  context 'when on a port, under a path' do
    around do |example|
      WebMock.disable!
      example.run
    ensure
      WebMock.enable!
      acceptor.kill.join
      server.close
    end

    let(:requests) { Queue.new }
    let(:server) { TCPServer.new('127.0.0.1', 0) }
    let!(:acceptor) { Thread.new { loop { answer(server.accept) } } }
    let(:host) { "127.0.0.1:#{server.addr[1]}" }
    let(:provider) do
      provider_for(bedrock_api_base: "http://#{host}/bedrock", bedrock_mantle_api_base: "http://#{host}/mantle")
    end

    def answer(socket)
      request_line, *header_lines = socket.gets("\r\n\r\n").split("\r\n")
      verb, target, = request_line.split
      headers = header_lines.to_h do |line|
        name, value = line.split(': ', 2)
        [name.downcase, value]
      end
      requests << { verb:, target:, headers:, body: socket.read(headers['content-length'].to_i) }
      reply = {
        output: { message: { role: 'assistant', content: [{ text: 'Hi' }] } },
        stopReason: 'end_turn',
        usage: { inputTokens: 3, outputTokens: 1 }
      }.to_json
      socket.write("HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: #{reply.bytesize}\r\n" \
                   "Connection: close\r\n\r\n#{reply}")
      socket.close
    end

    def expect_signed_request(target, service: 'bedrock')
      request = requests.pop(timeout: 5)
      headers = request[:headers]

      expect(request[:target]).to eq(target)
      expect(headers['host']).to eq(host)
      expect(signature(headers['authorization'])).to eq(
        expected_signature(request[:verb], "http://#{host}#{target}", headers['x-amz-date'], request[:body], service:)
      )
    end

    it 'keeps the path and signs what a chat sends' do
      base = "http://#{host}/bedrock"
      context = RubyLLM.context do |settings|
        settings.bedrock_region = 'us-east-1'
        settings.bedrock_api_key = 'key'
        settings.bedrock_secret_key = 'secret'
        settings.bedrock_api_base = base
      end

      context.chat(model: 'amazon.nova-2-lite-v1:0', provider: :bedrock).ask('Hello')

      expect_signed_request('/bedrock/model/us.amazon.nova-2-lite-v1:0/converse')
    end

    it 'keeps a model id with colons and an escaped ARN as they are sent' do
      provider.connection.post('/model/us.anthropic.claude-haiku-4-5-20251001-v1:0/invoke', '{}')
      expect_signed_request('/bedrock/model/us.anthropic.claude-haiku-4-5-20251001-v1:0/invoke')

      provider.connection.post('/model/arn:aws:bedrock:us-east-1:123:application-inference-profile%2Fp/converse', '{}')
      expect_signed_request('/bedrock/model/arn:aws:bedrock:us-east-1:123:application-inference-profile%2Fp/converse')
    end

    it 'keeps the path on GET requests with escaped segments' do
      provider.connection.get("/async-invoke/#{URI.encode_www_form_component('arn:aws:bedrock:job/abc')}")

      expect_signed_request('/bedrock/async-invoke/arn%3Aaws%3Abedrock%3Ajob%2Fabc')
    end

    it 'keeps the path on the agent connection' do
      provider.agent_connection.post('/rerank', '{}')

      expect_signed_request('/bedrock/rerank')
    end

    it 'keeps the path on the control plane and signs the path it sends' do
      provider.signed_post(provider.control_api_base, '/model-invocation-job', { jobName: 'job' })

      expect_signed_request('/bedrock/model-invocation-job')
    end

    it 'signs a control plane query string' do
      provider.signed_get(provider.control_api_base, '/inference-profiles?typeEquals=SYSTEM_DEFINED&nextToken=a%2Bb%3D')

      expect_signed_request('/bedrock/inference-profiles?nextToken=a%2Bb%3D&typeEquals=SYSTEM_DEFINED')
    end

    it 'keeps the path on the mantle connection' do
      provider.mantle_connection.post('v1/chat/completions', '{}')

      expect_signed_request('/mantle/v1/chat/completions', service: 'bedrock-mantle')
    end

    it 'signs the base path of a relative mantle catalog request' do
      provider.signed_get(provider.mantle_api_base, 'v1/models', service: 'bedrock-mantle')

      expect_signed_request('/mantle/v1/models', service: 'bedrock-mantle')
    end

    it 'treats a trailing slash on the base like its absence' do
      provider_for(bedrock_api_base: "http://#{host}/bedrock/")
        .connection.post('/model/us.amazon.nova-2-lite-v1:0/converse', '{}')

      expect_signed_request('/bedrock/model/us.amazon.nova-2-lite-v1:0/converse')
    end
  end

  context 'when on a default or explicit port' do
    let(:provider) { provider_for }

    def expect_signature_for(base_url)
      headers = provider.sign_headers('POST', '/rerank', '{}', base_url:)

      expect(signature(headers['Authorization'])).to eq(
        expected_signature('POST', "#{base_url}/rerank", headers['X-Amz-Date'], '{}')
      )
    end

    it 'signs an escaped model id on an AWS host the way AWS does' do
      runtime = 'https://bedrock-runtime.us-east-1.amazonaws.com'
      path = '/model/arn:aws:bedrock:us-east-1:123:application-inference-profile%2Fp/converse'
      stub = stub_request(:post, "#{runtime}#{path}")

      provider.connection.post(path, '{}')

      expect(stub.with do |sent|
        signature(sent.headers['Authorization']) ==
          expected_signature('POST', "#{runtime}#{path}", sent.headers['X-Amz-Date'], sent.body)
      end).to have_been_requested
    end

    it 'leaves the default port of each scheme out of the signed host' do
      expect_signature_for('https://bedrock-runtime.us-east-1.amazonaws.com')
      expect_signature_for('https://gateway.example.test:443')
      expect_signature_for('http://gateway.example.test:80')
    end

    it 'keeps a port that is not the default of its scheme' do
      expect_signature_for('https://gateway.example.test:80')
      expect_signature_for('http://gateway.example.test:443')
    end
  end
end
