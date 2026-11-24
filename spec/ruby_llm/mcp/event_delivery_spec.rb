# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::MCP::EventDelivery do
  let(:secret) { "whsec_#{['a signing key of thirty-two bytes'].pack('m0')}" }
  let(:other_secret) { "whsec_#{['another key that is long enough'].pack('m0')}" }
  let(:body) do
    JSON.generate(eventId: 'evt_789', name: 'incident.created', timestamp: '2026-02-19T16:00:00Z',
                  data: { incidentId: 'INC-1234' }, cursor: 'cursor_xyz')
  end

  def signature(secret, id, timestamp, body)
    key = secret.delete_prefix('whsec_').unpack1('m')
    "v1,#{[OpenSSL::HMAC.digest('SHA256', key, "#{id}.#{timestamp}.#{body}")].pack('m0')}"
  end

  def headers(body, signed_with: [secret], timestamp: Time.now.to_i, id: 'msg_2KWPBgLlAfxdpx2AI54pPJ85f4W')
    { 'webhook-id' => id, 'webhook-timestamp' => timestamp.to_s,
      'webhook-signature' => signed_with.map { |key| signature(key, id, timestamp, body) }.join(' '),
      'X-MCP-Subscription-Id' => 'sub_a3f1c8e2b0d49f7e' }
  end

  it 'reads an event the server signed' do
    delivery = described_class.new(headers(body), body, secret:)

    expect(delivery).to have_attributes(kind: :event, id: 'msg_2KWPBgLlAfxdpx2AI54pPJ85f4W', cursor: 'cursor_xyz',
                                        subscription_id: 'sub_a3f1c8e2b0d49f7e', secret:, challenge: nil, error: nil)
    expect(delivery.event).to have_attributes(id: 'evt_789', name: 'incident.created', cursor: 'cursor_xyz',
                                              timestamp: Time.utc(2026, 2, 19, 16),
                                              data: { 'incidentId' => 'INC-1234' })
  end

  it 'matches the standard webhooks reference signature' do
    reference = "whsec_#{%w[MfKQ9r8GKYqrTwjU PD8ILPZIo2LaLaSw].join}"
    payload = '{"test": 2432232314}'
    allow(Time).to receive(:now).and_return(Time.at(1_614_265_330))
    signed = { 'webhook-id' => 'msg_p5jXN8AQM9LWM0D4loKWxJek', 'webhook-timestamp' => '1614265330',
               'webhook-signature' => 'v1,g0hM9SsE+OTPJTGt/tmIKtSyZlE3uFJELVlNIOLJ1OE=' }

    expect(described_class.new(signed, payload, secret: reference).kind).to eq(:event)
  end

  it 'reads the headers of a Rack request, whatever their case' do
    rack = headers(body).transform_keys(&:upcase)

    expect(described_class.new(rack, body, secret:).subscription_id).to eq('sub_a3f1c8e2b0d49f7e')
  end

  it 'reads the headers of a request object that looks them up itself' do
    request_headers = Struct.new(:env) do
      def [](name)
        env[name]
      end
    end.new(headers(body))

    expect(described_class.new(request_headers, body, secret:).kind).to eq(:event)
  end

  it 'accepts a delivery signed with either secret while the server rotates them' do
    signed = headers(body, signed_with: [other_secret, secret])

    expect(described_class.new(signed, body, secret:).secret).to eq(secret)
  end

  it 'returns which of several secrets signed the delivery' do
    delivery = described_class.new(headers(body, signed_with: [other_secret]), body, secret: [secret, other_secret])

    expect(delivery.secret).to eq(other_secret)
  end

  it 'skips signatures of versions it does not check' do
    signed = headers(body)
    signed['webhook-signature'] = "v1a,bm90IGEgc2lnbmF0dXJl #{signed['webhook-signature']}"

    expect(described_class.new(signed, body, secret:).kind).to eq(:event)
  end

  it 'raises when the body changed after it was signed' do
    expect { described_class.new(headers(body), body.sub('INC-1234', 'INC-9999'), secret:) }
      .to raise_error(RubyLLM::MCP::Error, 'The signature of the MCP event delivery does not match')
  end

  it 'raises when another secret signed the delivery' do
    expect { described_class.new(headers(body, signed_with: [other_secret]), body, secret:) }
      .to raise_error(RubyLLM::MCP::Error, /does not match/)
  end

  it 'raises when the delivery has no signature' do
    expect { described_class.new({}, body, secret:) }.to raise_error(RubyLLM::MCP::Error, /too old/)
    expect { described_class.new(headers(body).except('webhook-signature'), body, secret:) }
      .to raise_error(RubyLLM::MCP::Error, /does not match/)
  end

  it 'raises when the delivery is more than five minutes old' do
    expect { described_class.new(headers(body, timestamp: Time.now.to_i - 301), body, secret:) }
      .to raise_error(RubyLLM::MCP::Error, 'The MCP event delivery is too old')
  end

  it 'raises when a signed body is not JSON' do
    expect { described_class.new(headers('nope'), 'nope', secret:) }
      .to raise_error(RubyLLM::MCP::Error, 'The MCP event delivery is not JSON')
  end

  it 'reads the challenge of a verification' do
    body = JSON.generate(type: 'verification', challenge: 'a-single-use-random-value')

    delivery = described_class.new(headers(body), body, secret:)

    expect(delivery).to have_attributes(kind: :verification, challenge: 'a-single-use-random-value', event: nil)
  end

  it 'reads the cursor of a gap' do
    body = JSON.generate(type: 'gap', cursor: 'cursor_fresh')

    expect(described_class.new(headers(body), body, secret:)).to have_attributes(kind: :gap, cursor: 'cursor_fresh')
  end

  it 'reads why a subscription ended' do
    body = JSON.generate(type: 'terminated',
                         error: { code: -32_024, message: 'Forbidden', data: { reason: 'Access revoked' } })

    delivery = described_class.new(headers(body), body, secret:)

    expect(delivery.kind).to eq(:terminated)
    expect(delivery.error).to have_attributes(code: -32_024, provider_message: 'Forbidden',
                                              data: { 'reason' => 'Access revoked' })
  end

  it 'inspects as one short line' do
    expect(described_class.new(headers(body), body, secret:).inspect)
      .to eq('#<RubyLLM::MCP::EventDelivery kind: :event, id: "msg_2KWPBgLlAfxdpx2AI54pPJ85f4W", ' \
             'subscription_id: "sub_a3f1c8e2b0d49f7e">')
  end
end
