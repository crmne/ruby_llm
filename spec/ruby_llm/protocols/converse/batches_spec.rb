# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::Converse::Batches do
  let(:config) do
    instance_double(
      RubyLLM::Configuration,
      bedrock_batch_s3_uri: 's3://ruby-llm-batches/test',
      bedrock_batch_role_arn: 'arn:aws:iam::123456789012:role/BedrockBatch',
      bedrock_region: 'us-west-2'
    )
  end
  let(:provider) { instance_double(RubyLLM::Providers::Bedrock) }
  let(:protocol) do
    RubyLLM::Providers::Bedrock.batch_protocols.fetch(:converse).allocate.tap do |instance|
      instance.instance_variable_set(:@config, config)
      instance.instance_variable_set(:@provider, provider)
    end
  end

  describe '#bedrock_batch_jsonl' do
    it 'wraps rendered Converse payloads as model invocation records' do
      jsonl = protocol.send(:bedrock_batch_jsonl, [
                              {
                                custom_id: '0',
                                params: { messages: [{ role: 'user', content: [{ text: 'Hi' }] }] }
                              }
                            ])

      expect(JSON.parse(jsonl)).to eq(
        'recordId' => '0',
        'modelInput' => { 'messages' => [{ 'role' => 'user', 'content' => [{ 'text' => 'Hi' }] }] }
      )
    end
  end

  describe '#validate_bedrock_batch_requests!' do
    it 'rejects tools and structured output' do
      expect do
        protocol.send(:validate_bedrock_batch_requests!, [
                        { params: { toolConfig: { tools: [] } } }
                      ])
      end.to raise_error(RubyLLM::Error, /tools or structured output/)
    end
  end

  describe '#create_batch' do
    it 'rejects mixed-model jobs' do
      requests = [
        { custom_id: '0', model: 'anthropic.claude-haiku-4-5-20251001-v1:0', params: {} },
        { custom_id: '1', model: 'amazon.nova-2-lite-v1:0', params: {} }
      ]

      expect { protocol.create_batch(requests) }.to raise_error(RubyLLM::Error, /one model/)
    end

    it 'requires an S3 bucket prefix' do
      allow(config).to receive(:bedrock_batch_s3_uri).and_return(nil)

      expect do
        protocol.create_batch([
                                {
                                  custom_id: '0',
                                  model: 'anthropic.claude-haiku-4-5-20251001-v1:0',
                                  params: {}
                                }
                              ])
      end.to raise_error(RubyLLM::ConfigurationError, /bedrock_batch_s3_uri/)
    end

    it 'requires a Bedrock batch role ARN' do
      allow(config).to receive(:bedrock_batch_role_arn).and_return(nil)
      allow(provider).to receive(:upload_file)

      expect do
        protocol.create_batch([
                                {
                                  custom_id: '0',
                                  model: 'anthropic.claude-haiku-4-5-20251001-v1:0',
                                  params: {}
                                }
                              ])
      end.to raise_error(RubyLLM::ConfigurationError, /bedrock_batch_role_arn/)
    end

    it 'uploads JSONL to S3 and creates a model invocation job' do
      uploaded_body = nil
      allow(provider).to receive(:upload_file) do |io, **|
        uploaded_body = io.string
      end
      create_response = instance_double(Faraday::Response, body: { 'jobArn' => 'arn:aws:bedrock:job/123' })
      status_response = instance_double(Faraday::Response, body: {
                                          'jobArn' => 'arn:aws:bedrock:job/123',
                                          'status' => 'Submitted'
                                        })
      allow(provider).to receive_messages(
        control_api_base: 'https://bedrock.us-west-2.amazonaws.com',
        signed_post: create_response,
        signed_get: status_response
      )

      protocol.create_batch([
                              {
                                custom_id: '0',
                                model: 'anthropic.claude-haiku-4-5-20251001-v1:0',
                                params: { messages: [{ role: 'user', content: [{ text: 'Hi' }] }] }
                              }
                            ])

      expect(uploaded_body).to include('"recordId":"0"')
      expect(provider).to have_received(:upload_file).with(
        kind_of(StringIO),
        uri: match(%r{\As3://ruby-llm-batches/test/ruby_llm_batches/.+/input\.jsonl\z}),
        filename: 'input.jsonl',
        content_type: 'application/jsonl'
      )
      expect(provider).to have_received(:signed_post).with(
        'https://bedrock.us-west-2.amazonaws.com',
        '/model-invocation-job',
        include(
          modelId: 'anthropic.claude-haiku-4-5-20251001-v1:0',
          inputDataConfig: include(
            s3InputDataConfig: include(
              s3Uri: match(%r{\As3://ruby-llm-batches/test/ruby_llm_batches/.+/input\.jsonl\z})
            )
          )
        )
      )
    end
  end

  describe '#batch_results' do
    it 'raises when the job has no S3 output URI yet' do
      allow(provider).to receive_messages(
        control_api_base: 'https://bedrock.us-west-2.amazonaws.com',
        signed_get: instance_double(Faraday::Response, body: { 'status' => 'InProgress' })
      )

      expect { protocol.batch_results('job-123') }.to raise_error(RubyLLM::Error, /no S3 output URI/)
    end
  end

  describe '#parse_bedrock_record' do
    it 'parses successful Converse model output' do
      line = {
        'recordId' => '1',
        'modelOutput' => {
          'output' => { 'message' => { 'content' => [{ 'text' => 'Hello' }] } },
          'usage' => { 'inputTokens' => 2, 'outputTokens' => 1 },
          'modelId' => 'anthropic.claude-haiku-4-5-20251001-v1:0'
        }
      }

      index, message = protocol.send(:parse_bedrock_record, line)

      expect(index).to eq(1)
      expect(message.content).to eq('Hello')
      expect(message.model_id).to eq('anthropic.claude-haiku-4-5-20251001-v1:0')
    end
  end
end
