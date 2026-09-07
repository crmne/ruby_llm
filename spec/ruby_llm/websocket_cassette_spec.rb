# frozen_string_literal: true

require 'spec_helper'
require_relative '../support/websocket_cassette'

RSpec.describe WebsocketCassette do
  include described_class

  it 'rejects an absent recording before opening a socket in a non-live example' do
    allow(File).to receive(:exist?).and_return(false)
    allow(RubyLLM::Transport::WebsocketConnection).to receive(:open)

    expect { with_websocket_cassette('missing', key: 'DEEPGRAM_API_KEY') { nil } }
      .to raise_error(/Missing WebSocket recording/)
    expect(RubyLLM::Transport::WebsocketConnection).not_to have_received(:open)
  end

  it 'rejects an absent recording in CI even for a live example' do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('CI').and_return('true')
    allow(File).to receive(:exist?).and_return(false)

    expect { with_websocket_cassette('missing', key: 'DEEPGRAM_API_KEY') { nil } }
      .to raise_error(/Missing WebSocket recording/)
  end

  it 'filters returned session credentials while retaining replayable URL structure' do
    url = 'wss://api.elevenlabs.io/v1/convai/conversation?agent_id=agent-1&conversation_signature=secret'
    value = { 'signed_url' => url,
              'metadata' => { 'persistent_session_token' => 'jwt-secret', 'session_token' => 'session-secret' },
              'audio_base_64' => Base64.strict_encode64('audio') }

    result = described_class.sanitize(value)

    expect(result.to_s).not_to include('secret')
    uri = URI.parse(result.fetch('signed_url'))
    expect(uri.path).to eq('/v1/convai/conversation')
    expect(URI.decode_www_form(uri.query).to_h)
      .to eq('agent_id' => 'agent-1', 'conversation_signature' => '[FILTERED]')
    expect(result.fetch('audio_base_64')).to eq('sha256' => Digest::SHA256.hexdigest('audio'))
  end

  it 'filters signed URL response bodies and credential query parameters in ElevenLabs HTTP fixtures' do
    interaction = VCR::HTTPInteraction.new(
      VCR::Request.new(:get, 'https://api.elevenlabs.io/v1/convai/conversation/get-signed-url?token=secret', '', {}),
      VCR::Response.new(VCR::ResponseStatus.new(200, 'OK'), {},
                        JSON.generate(signed_url: 'wss://api.elevenlabs.io/conversation?conversation_signature=secret'),
                        '1.1')
    )

    RealtimeCredentials.filter_elevenlabs(interaction)

    expect(interaction.request.uri).not_to include('secret')
    url = JSON.parse(interaction.response.body).fetch('signed_url')
    expect(URI.decode_www_form(URI.parse(url).query).to_h)
      .to eq('conversation_signature' => '[FILTERED]')
  end

  it 'leaves unrelated recordings intact even when their host already contains redaction placeholders' do
    uri = 'https://bedrock-agent-runtime.<AWS_REGION>.amazonaws.com/rerank'
    body = JSON.generate(results: [{ index: 0, relevance_score: 0.98 }])
    request = Struct.new(:uri, :body).new(uri, '')
    response = Struct.new(:body).new(body)
    interaction = Struct.new(:request, :response).new(request, response)

    expect { RealtimeCredentials.filter_elevenlabs(interaction) }.not_to raise_error
    expect(interaction.request.uri).to eq(uri)
    expect(interaction.response.body).to eq(body)
  end

  it 'redacts Google credential query keys without redacting ordinary JSON keys or duplicating input audio' do
    url = RealtimeCredentials.sanitize_url('wss://example.com/transcribe?key=secret&model=speech')
    value = { 'key' => 'domain-field', 'realtimeInput' => { 'audio' => {
      'mimeType' => 'audio/pcm;rate=24000', 'data' => Base64.strict_encode64('audio')
    } } }

    expect(URI.decode_www_form(URI.parse(url).query).to_h).to eq('key' => '[FILTERED]', 'model' => 'speech')
    expect(described_class.sanitize(value)).to eq(
      'key' => 'domain-field', 'realtimeInput' => { 'audio' => {
        'mimeType' => 'audio/pcm;rate=24000', 'data' => { 'sha256' => Digest::SHA256.hexdigest('audio') }
      } }
    )
  end
end
