# frozen_string_literal: true

require 'spec_helper'
require 'avro'

RSpec.describe RubyLLM::Protocols::Cohere::Datasets do
  let(:context) { RubyLLM.context { |config| config.cohere_api_key = 'test' } }
  let(:protocol) { described_class.new(RubyLLM::Providers::Cohere.new(context.config)) }

  def dataset(**attributes)
    { id: 'dataset_ruby', name: 'ruby', created_at: '2026-09-07T13:00:00Z', dataset_type: 'embed-input',
      validation_status: 'validated', dataset_parts: [] }.merge(attributes)
  end

  def avro_content(text)
    schema = Avro::Schema.parse(JSON.generate(type: 'record', name: 'Text', fields: [{ name: 'text', type: 'string' }]))
    buffer = StringIO.new
    writer = Avro::DataFile::Writer.new(buffer, Avro::IO::DatumWriter.new(schema), schema)
    writer << { 'text' => text }
    writer.flush
    buffer.string
  end

  it 'uploads a dataset with query options and downloads original bytes without sending provider credentials' do
    content = "{\"text\":\"Ruby\"}\n"
    request = stub_request(:post, 'https://api.cohere.com/v1/datasets')
              .with(query: { name: 'input.jsonl', type: 'embed-input', keep_original_file: 'true' })
              .with { |req| req.body.include?('name="data"') && req.body.include?(content) }
              .to_return_json(body: { id: 'dataset_ruby' })
    part = { name: 'input.avro', url: 'https://storage.example.test/input.avro',
             original_url: 'https://storage.example.test/input.jsonl' }
    stub_request(:get, 'https://api.cohere.com/v1/datasets/dataset_ruby')
      .to_return_json(body: { dataset: dataset(dataset_parts: [part]) })
    download = stub_request(:get, part.fetch(:original_url))
               .with { |req| !req.headers.key?('Authorization') }.to_return(body: content)

    file = context.upload(StringIO.new(content), filename: 'input.jsonl', purpose: 'embed-input', provider: :cohere)

    expect(file).to have_attributes(id: 'dataset_ruby', purpose: 'embed-input', filename: 'input.jsonl',
                                    mime_type: 'application/jsonl', downloadable: true)
    expect(context.download(file.id, provider: :cohere)).to eq(content)
    expect(request).to have_been_requested.once
    expect(download).to have_been_requested.once
  end

  it 'decodes generated Avro parts in provider order and reports JSONL metadata' do
    parts = [{ index: 1, url: 'https://storage.example.test/second' },
             { index: 0, url: 'https://storage.example.test/first' }]
    stub_request(:get, 'https://api.cohere.com/v1/datasets/dataset_ruby')
      .to_return_json(body: { dataset: dataset(dataset_type: 'embed-result', dataset_parts: parts) })
    stub_request(:get, parts[0][:url]).to_return(body: avro_content('second'))
    stub_request(:get, parts[1][:url]).to_return(body: avro_content('first'))

    file = RubyLLM::UploadedFile.find('dataset_ruby', provider: :cohere, context:)

    expect(file).to have_attributes(filename: 'ruby.jsonl', mime_type: 'application/jsonl')
    expect(context.download(file.id, provider: :cohere).lines.map { |line| JSON.parse(line) })
      .to eq([{ 'text' => 'first' }, { 'text' => 'second' }])
  end

  it 'reports failed validation and bounds polling for pending datasets' do
    stub_request(:get, 'https://api.cohere.com/v1/datasets/bad')
      .to_return_json(body: { dataset: dataset(validation_status: 'failed', validation_error: 'Missing text') })
    expect { protocol.wait_for_validation('bad') }.to raise_error(RubyLLM::Error, /failed validation: Missing text/)
    context.config.request_timeout = 0
    stub_request(:get, 'https://api.cohere.com/v1/datasets/pending')
      .to_return_json(body: { dataset: dataset(validation_status: 'processing') })
    expect { protocol.wait_for_validation('pending') }.to raise_error(RubyLLM::Error, /timed out: pending/)
  end

  it 'requires a purpose and explains the optional decoder dependency' do
    expect { protocol.upload(StringIO.new('text'), filename: 'text.jsonl') }
      .to raise_error(ArgumentError, /require purpose/)
    expect { protocol.upload(StringIO.new('text'), filename: 'text.jsonl', purpose: 'embed-input', expires_in: 60) }
      .to raise_error(ArgumentError, /do not accept expires_in/)
    allow(protocol).to receive(:require).with('avro').and_raise(LoadError)
    expect { protocol.records(RubyLLM::UploadedFile.new(id: 'dataset')) }
      .to raise_error(LoadError, /Add gem "avro"/)
  end

  it 'uploads validates retrieves and downloads a Cohere dataset', :live do
    content = "{\"text\":\"Ruby makes AI useful.\"}\n"
    file = RubyLLM.upload(StringIO.new(content), filename: 'ruby-llm-test.jsonl',
                                                 provider: :cohere, purpose: 'embed-input')
    downloaded = RubyLLM.download(file.id, provider: :cohere)
    restored = RubyLLM::UploadedFile.find(file.id, provider: :cohere)

    expect(restored).to have_attributes(id: file.id, status: 'validated', mime_type: 'application/jsonl')
    expect(downloaded).to eq(content)
  ensure
    RubyLLM::Providers::Cohere.new(RubyLLM.config).connection.delete("v1/datasets/#{file.id}") if file
  end
end
