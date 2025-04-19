# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Schema do
  it 'deeply stringifies keys in a hash automatically' do
    hash = { foo: 'bar', bar: { foo: 'bar' } }
    schema = described_class.new(hash)
    expect(schema.to_h).to eq(foo: 'bar', bar: { foo: 'bar' })
  end

  describe '#[]' do
    let(:schema) { described_class.new('foo' => { 'bar' => 'foo' }, 'arr' => [{ 'some' => :val }]) }

    it 'deeply symbolizes keys in hash' do
      expect(schema[:foo][:bar]).to eq('foo')
    end

    it 'deeply symbolizes keys in array' do
      expect(schema[:arr][0][:some]).to eq(:val)
    end
  end

  describe '#[]=' do
    let(:schema) { described_class.new('foo' => {}) }

    it 'sets schema values with symbol keys in nested objects' do
      schema[:foo] = { 'bar' => 123 }
      expect(schema[:foo][:bar]).to eq(123)
    end
  end

  describe '#add_to_each_object_type!' do
    before { schema.add_to_each_object_type!(:additionalProperties, true) }

    context 'with root data object' do
      let(:schema) { described_class.new(type: :object, properties: { name: { type: :string } }) }

      it 'sets schema values with indifferent key vs symbols' do
        expect(schema[:additionalProperties]).to be(true)
      end
    end

    context 'with nested data object' do
      let(:schema) do
        described_class.new(type: :object,
                            properties: { address: { type: :object,
                                                     properties: { city: { type: :string } } } })
      end

      it 'sets schema values with indifferent key vs symbols' do
        expect(schema[:properties][:address][:additionalProperties]).to be(true)
      end
    end

    context 'with array item objects' do
      let(:schema) do
        described_class.new(type: :object,
                            properties: {
                              coordinates: {
                                type: :array,
                                items: {
                                  type: :object,
                                  properties: { lat: { type: :number }, lon: { type: :number } }
                                }
                              }
                            })
      end

      it 'sets schema values with indifferent key vs symbols' do
        expect(schema[:properties][:coordinates][:items][:additionalProperties]).to be(true)
      end
    end
  end
end
