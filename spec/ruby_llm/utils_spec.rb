# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Utils do
  describe '.deep_merge' do
    context 'when merging hashes' do
      it 'merges nested hashes recursively' do
        original = { a: { b: 1, c: 2 } }
        overrides = { a: { c: 3, d: 4 } }

        result = described_class.deep_merge(original, overrides)

        expect(result).to eq({ a: { b: 1, c: 3, d: 4 } })
      end

      it 'handles deeply nested hashes' do
        original = { a: { b: { c: 1 } } }
        overrides = { a: { b: { d: 2 } } }

        result = described_class.deep_merge(original, overrides)

        expect(result).to eq({ a: { b: { c: 1, d: 2 } } })
      end
    end

    context 'when merging arrays' do
      it 'concatenates arrays' do
        original = { items: [1, 2, 3] }
        overrides = { items: [4, 5] }

        result = described_class.deep_merge(original, overrides)

        expect(result).to eq({ items: [1, 2, 3, 4, 5] })
      end

      it 'concatenates arrays in nested hashes' do
        original = { config: { tags: %w[a b] } }
        overrides = { config: { tags: %w[c d] } }

        result = described_class.deep_merge(original, overrides)

        expect(result).to eq({ config: { tags: %w[a b c d] } })
      end

      it 'preserves array order when concatenating' do
        original = { list: %w[first second] }
        overrides = { list: %w[third fourth] }

        result = described_class.deep_merge(original, overrides)

        expect(result[:list]).to eq(%w[first second third fourth])
      end
    end

    context 'when merging other types' do
      it 'overrides scalar values' do
        original = { name: 'old' }
        overrides = { name: 'new' }

        result = described_class.deep_merge(original, overrides)

        expect(result).to eq({ name: 'new' })
      end

      it 'overrides when types do not match' do
        original = { value: [1, 2] }
        overrides = { value: 'string' }

        result = described_class.deep_merge(original, overrides)

        expect(result).to eq({ value: 'string' })
      end

      it 'handles nil values' do
        original = { key: 'value' }
        overrides = { key: nil }

        result = described_class.deep_merge(original, overrides)

        expect(result).to eq({ key: nil })
      end
    end

    context 'when merging complex structures' do
      it 'handles mixed nested structures with arrays and hashes' do
        original = {
          config: {
            settings: { timeout: 30 },
            tags: ['production']
          }
        }
        overrides = {
          config: {
            settings: { retries: 3 },
            tags: ['monitoring']
          }
        }

        result = described_class.deep_merge(original, overrides)

        expect(result).to eq({
                               config: {
                                 settings: { timeout: 30, retries: 3 },
                                 tags: %w[production monitoring]
                               }
                             })
      end
    end
  end
end
