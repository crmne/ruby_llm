# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::VertexAI::EmbeddingPrediction, :live do
  let(:model) { model_for(:vertexai, :embedding) }
  let(:owned_resources) { {} }

  def configure_live_storage
    skip_without_cassette_or_key('VERTEXAI_BATCH_GCS_URI')
    RubyLLM.config.vertexai_location = 'us-central1'
    return if VCR.current_cassette.recording?

    require 'google/cloud/storage'
    request = VCR.current_cassette.http_interactions.interactions
                 .find do |interaction|
      interaction.request.method == :post &&
        interaction.request.uri.end_with?('/batchPredictionJobs')
    end.request
    body = JSON.parse(request.body)
    input = body.dig('inputConfig', 'gcsSource', 'uris').first
    prefix, directory = input.match(%r{\A(.+)/ruby_llm_batches/([0-9a-f]{16})/input\.jsonl\z}).captures
    RubyLLM.config.vertexai_batch_gcs_uri = prefix
    RubyLLM.config.vertexai_project_id = request.uri[%r{/projects/([^/]+)/}, 1]
    RubyLLM.config.vertexai_location = request.uri[%r{/locations/([^/]+)/}, 1]
    allow(SecureRandom).to receive(:hex).and_call_original
    allow(SecureRandom).to receive(:hex).with(8).and_return(directory,
                                                            body.fetch('displayName').delete_prefix('ruby_llm_'))
    credentials = Google::Auth::UserRefreshCredentials.new(access_token: 'test', expires_at: Time.now + 3600)
    allow(Google::Cloud::Storage).to receive(:new).and_wrap_original do |method, **options|
      method.call(**options, credentials:)
    end
  end

  def submit_live_batch
    staged = ['Ruby is a language.', ['Rails is a framework.'],
              ['Ruby uses objects.', 'Rails uses Ruby.']].map do |text|
      RubyLLM.embed_later(text, model:, provider: :vertexai, dimensions: 256)
    end
    owned_resources[:provider] = staged.first.provider
    allow(staged.first.provider).to receive(:upload_file).and_wrap_original do |method, *args, **options|
      owned_resources[:input_uri] = options.fetch(:uri)
      method.call(*args, **options)
    end
    RubyLLM.batch(staged)
  end

  def wait_for_live_batch(batch)
    24.times do
      return batch if batch.refresh.complete?

      sleep 5 if VCR.current_cassette.recording?
    end
    skip 'Vertex embedding batch did not finish within 120 seconds; completed results remain unverified'
  end

  def cleanup_live_batch(batch)
    return unless batch

    batch.cancel unless batch.complete?
    return unless batch.complete? && owned_resources[:input_uri]

    prefix = owned_resources[:input_uri].delete_suffix('input.jsonl')
    files = RubyLLM::Protocols::VertexAI::Files.new(owned_resources[:provider])
    files.list_uris(prefix).each do |uri|
      raise "Unexpected batch fixture output: #{uri}" unless uri.start_with?(prefix)

      bucket, key = files.send(:parse_gcs_uri, uri)
      files.send(:bucket, bucket).file(key)&.delete
    end
  end

  it 'completes text embeddings and restores shapes after reloading the prediction job' do
    configure_live_storage
    batch = submit_live_batch
    wait_for_live_batch(batch)

    reloaded = RubyLLM::Batch.find(batch.id, provider: :vertexai)
    results = reloaded.results
    expect(reloaded.statuses).to eq(%i[succeeded succeeded succeeded])
    expect(results.first.vectors.size).to eq(256)
    expect(results[1].vectors.size).to eq(1)
    expect(results.last.vectors.size).to eq(2)
    expect(results.last.vectors).to all(have_attributes(size: 256))
    expect(results.map(&:model)).to eq([model] * 3)
    expect(reloaded.tokens.input).to be_positive
  ensure
    cleanup_live_batch(batch)
  end
end
