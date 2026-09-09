# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::ElevenLabs::Assets do
  let(:context) { RubyLLM.context { |config| config.elevenlabs_api_key = 'test' } }
  let(:image_path) { File.expand_path('../../../fixtures/ruby.png', __dir__) }
  let(:asset) do
    { asset_id: 'asset_ruby', name: 'ruby.png', mime_type: 'image/png', created_at_unix: 1_700_000_000,
      content_url: 'https://assets.example.test/ruby.png?signature=fresh' }
  end

  it 'uploads, finds and downloads managed assets without sending API credentials to the signed host' do
    upload = stub_request(:post, 'https://api.elevenlabs.io/v1/assets')
             .with { |request| request.body.include?('name="asset"') && request.body.include?('name="name"') }
             .to_return_json(body: asset)
    metadata = stub_request(:get, 'https://api.elevenlabs.io/v1/assets/asset_ruby').to_return_json(body: asset)
    download = stub_request(:get, asset.fetch(:content_url)).with { |request| !request.headers.key?('Xi-Api-Key') }
                                                            .to_return(body: 'PNG bytes')

    file = context.upload(image_path, provider: :elevenlabs)
    restored = RubyLLM::UploadedFile.find(file.id, provider: :elevenlabs, context:)

    expect(file).to have_attributes(id: 'asset_ruby', provider: 'elevenlabs', filename: 'ruby.png',
                                    mime_type: 'image/png')
    expect(file.created_at).to eq(Time.at(1_700_000_000))
    expect(context.download(restored.id, provider: :elevenlabs)).to eq('PNG bytes')
    expect(upload).to have_been_requested.once
    expect(metadata).to have_been_requested.twice
    expect(download).to have_been_requested.once
  end

  it 'reports processing assets clearly and fetches fresh metadata before every download' do
    stub_request(:get, 'https://api.elevenlabs.io/v1/assets/processing')
      .to_return_json(body: asset.merge(content_url: nil))

    expect { context.download('processing', provider: :elevenlabs) }
      .to raise_error(RubyLLM::Error, /still processing/)
  end

  it 'rejects unsupported expiry and purpose options before an upload' do
    expect { context.upload(image_path, provider: :elevenlabs, expires_in: 60) }
      .to raise_error(ArgumentError, /do not accept purpose or expires_in/)
  end

  it 'uploads retrieves and downloads an ElevenLabs image asset', :live do
    file = RubyLLM.upload(image_path, provider: :elevenlabs)
    restored = RubyLLM::UploadedFile.find(file.id, provider: :elevenlabs)

    expect(restored.mime_type).to eq('image/png')
    expect(RubyLLM.download(restored.id, provider: :elevenlabs)).to eq(File.binread(image_path))
  rescue RubyLLM::Error => e
    skip "ElevenLabs assets require Pro: #{e.message}" if e.response&.status == 402
    raise
  ensure
    if file
      provider = RubyLLM::Providers::ElevenLabs.new(RubyLLM.config)
      provider.connection.delete("v1/assets/#{file.id}")
    end
  end
end
