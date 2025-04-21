# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Message do
  subject(:message) { described_class.new(role: :assistant, content: content, content_schema: content_schema) }

  let(:content_schema) { nil }

  describe '#content' do
    let(:content) { 'Hello, world!' }

    it 'returns string content by default' do
      expect(message.content).to eq(content)
    end

    context 'when content has object schema' do
      let(:content_schema) { { type: :object, properties: { foo: { type: :string } } } }
      let(:content) { { 'result' => { 'foo' => 'bar' } }.to_json }

      it 'returns hash' do
        expect(message.content).to be_a(Hash).and include('foo' => 'bar')
      end
    end

    context 'when content has integer schema' do
      let(:content_schema) { { type: :integer } }
      let(:content) { { 'result' => 123 }.to_json }

      it 'returns integer' do
        expect(message.content).to eq(123)
      end
    end

    context 'when content has array schema' do
      let(:content_schema) { { type: :array, items: { type: :boolean } } }
      let(:content) { { 'result' => [true, false] }.to_json }

      it 'returns integer' do
        expect(message.content).to eq([true, false])
      end
    end
  end
end
