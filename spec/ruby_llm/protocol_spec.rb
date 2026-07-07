# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocol do
  describe '#parse_completion_response' do
    let(:protocol_class) do
      Class.new(described_class) do
        private

        def parse_completion_body(data, raw:)
          [data, raw]
        end
      end
    end

    it 'raises RubyLLM::Error for empty completion bodies' do
      protocol = protocol_class.allocate

      [nil, {}, [], ''].each do |body|
        response = instance_double(Faraday::Response, body: body)

        expect do
          protocol.send(:parse_completion_response, response)
        end.to raise_error(RubyLLM::Error, 'Provider returned an empty response body')
      end
    end

    it 'passes non-empty bodies to the protocol parser' do
      protocol = protocol_class.allocate
      response = instance_double(Faraday::Response, body: { 'text' => 'hello' })

      expect(protocol.send(:parse_completion_response, response))
        .to eq([{ 'text' => 'hello' }, response])
    end
  end

  it 'owns completion response parsing for every registered chat protocol' do
    protocols = RubyLLM::Provider.providers.values.flat_map { |provider| provider.protocols.values }.uniq
    chat_protocols = protocols.select { |protocol| protocol.private_method_defined?(:parse_completion_body) }
    overrides = chat_protocols.reject do |protocol|
      protocol.instance_method(:parse_completion_response).owner == described_class
    end

    expect(chat_protocols).not_to be_empty
    expect(overrides.map(&:name)).to be_empty
  end
end
