# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Utils do
  describe '.hash_get' do
    it 'fetches a value using a symbol when the hash key is stored as a string' do
      hash = { 'name' => 'RubyLLM' }

      expect(described_class.hash_get(hash, :name)).to eq('RubyLLM')
    end

    it 'fetches a value using a string when the hash key is stored as a symbol' do
      hash = { name: 'RubyLLM' }

      expect(described_class.hash_get(hash, 'name')).to eq('RubyLLM')
    end
  end

  describe '.to_safe_array' do
    it 'returns the same array instance when the input is already an array' do
      items = [1, 2, 3]

      expect(described_class.to_safe_array(items)).to equal(items)
    end

    it 'wraps hashes in an array' do
      hash = { key: 'value' }

      expect(described_class.to_safe_array(hash)).to eq([hash])
    end

    it 'wraps non-collection values in an array' do
      expect(described_class.to_safe_array('value')).to eq(['value'])
    end
  end

  describe '.deep_merge' do
    it 'merges nested hashes without mutating the originals' do
      original = { config: { retries: 3, timeout: 5 }, mode: :safe }
      overrides = { config: { timeout: 10 }, verbose: true }

      result = described_class.deep_merge(original, overrides)

      expect(result).to eq(
        config: { retries: 3, timeout: 10 },
        mode: :safe,
        verbose: true
      )
      expect(original).to eq(config: { retries: 3, timeout: 5 }, mode: :safe)
      expect(overrides).to eq(config: { timeout: 10 }, verbose: true)
    end
  end

  describe '.deep_dup' do
    it 'duplicates nested arrays and hashes' do
      original = {
        metadata: {
          tags: %w[ruby llm],
          info: { version: '1.0.0' }
        }
      }

      duplicate = described_class.deep_dup(original)

      expect(duplicate).to eq(original)
      expect(duplicate).not_to equal(original)
      expect(duplicate[:metadata]).not_to equal(original[:metadata])
      expect(duplicate[:metadata][:tags]).not_to equal(original[:metadata][:tags])
      expect(duplicate[:metadata][:info]).not_to equal(original[:metadata][:info])
    end
  end

  describe '.deep_stringify_keys' do
    it 'converts nested keys and symbol values to strings' do
      data = {
        config: {
          retries: 3,
          mode: :safe
        },
        'files' => [{ path: '/tmp/file.txt' }]
      }

      expect(described_class.deep_stringify_keys(data)).to eq(
        'config' => {
          'retries' => 3,
          'mode' => 'safe'
        },
        'files' => [{ 'path' => '/tmp/file.txt' }]
      )
    end
  end

  describe '.deep_symbolize_keys' do
    it 'converts nested string keys to symbols and preserves non-convertible keys' do
      data = {
        'config' => {
          'retries' => 3,
          'mode' => 'safe',
          'options' => [{ 'path' => '/tmp/file.txt' }]
        },
        42 => 'answer'
      }

      result = described_class.deep_symbolize_keys(data)

      expect(result[:config][:retries]).to eq(3)
      expect(result[:config][:mode]).to eq('safe')
      expect(result[:config][:options].first[:path]).to eq('/tmp/file.txt')
      expect(result[42]).to eq('answer')
    end
  end
end
