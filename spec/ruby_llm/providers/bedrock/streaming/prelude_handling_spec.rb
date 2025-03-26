# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Bedrock::Streaming::PreludeHandling do
  let(:dummy_class) { Class.new { include RubyLLM::Providers::Bedrock::Streaming::PreludeHandling } }
  let(:instance) { dummy_class.new }

  describe '#can_read_prelude?' do
    subject { instance.can_read_prelude?(chunk, offset) }

    context 'when chunk has enough bytes after offset' do
      let(:chunk) { "x" * 20 }
      let(:offset) { 5 }
      it { is_expected.to be true }
    end

    context 'when chunk does not have enough bytes after offset' do
      let(:chunk) { "x" * 15 }
      let(:offset) { 5 }
      it { is_expected.to be false }
    end
  end

  describe '#read_prelude' do
    subject { instance.read_prelude(chunk, offset) }

    context 'with valid binary data' do
      let(:offset) { 0 }
      let(:total_length) { 100 }
      let(:headers_length) { 50 }
      let(:chunk) do
        [
          total_length,    # 4 bytes for total_length
          headers_length   # 4 bytes for headers_length
        ].pack('NN') + "x" * 92  # Padding to make total 100 bytes
      end

      it 'correctly unpacks the lengths' do
        expect(subject).to eq([total_length, headers_length])
      end
    end

    context 'with offset' do
      let(:offset) { 4 }
      let(:total_length) { 100 }
      let(:headers_length) { 50 }
      let(:chunk) do
        "pad!" +  # 4 bytes padding before offset
        [
          total_length,
          headers_length
        ].pack('NN') + "x" * 92
      end

      it 'correctly unpacks the lengths from the offset' do
        expect(subject).to eq([total_length, headers_length])
      end
    end
  end

  describe '#find_next_message' do
    subject { instance.find_next_message(chunk, offset) }

    context 'when next prelude exists' do
      let(:offset) { 0 }
      let(:chunk) do
        first_message = [100, 50].pack('NN') + "x" * 92
        second_message = [80, 40].pack('NN') + "x" * 72
        first_message + second_message
      end

      it 'returns the position of the next message' do
        expect(subject).to eq(100)
      end
    end

    context 'when no next prelude exists' do
      let(:offset) { 0 }
      let(:chunk) do
        [100, 50].pack('NN') + "x" * 92  # Single message
      end

      it 'returns the chunk size' do
        expect(subject).to eq(chunk.bytesize)
      end
    end
  end

  describe '#find_next_prelude' do
    subject { instance.find_next_prelude(chunk, start_offset) }

    context 'when valid prelude exists' do
      let(:start_offset) { 100 }
      let(:chunk) do
        first_message = "x" * 100  # Padding
        second_message = [80, 40].pack('NN') + "x" * 72
        first_message + second_message
      end

      it 'returns the position of the valid prelude' do
        expect(subject).to eq(100)
      end
    end

    context 'when no valid prelude exists' do
      let(:start_offset) { 0 }
      let(:chunk) { "x" * 100 }  # Invalid data

      it 'returns nil' do
        expect(subject).to be_nil
      end
    end
  end

  describe '#valid_lengths?' do
    subject { instance.valid_lengths?(total_length, headers_length) }

    context 'with nil values' do
      let(:total_length) { nil }
      let(:headers_length) { nil }
      it { is_expected.to be false }
    end

    context 'with invalid values' do
      context 'when total_length is zero' do
        let(:total_length) { 0 }
        let(:headers_length) { 10 }
        it { is_expected.to be false }
      end

      context 'when total_length exceeds maximum' do
        let(:total_length) { 1_000_001 }
        let(:headers_length) { 10 }
        it { is_expected.to be false }
      end

      context 'when headers_length is zero' do
        let(:total_length) { 100 }
        let(:headers_length) { 0 }
        it { is_expected.to be false }
      end

      context 'when headers_length exceeds total_length' do
        let(:total_length) { 100 }
        let(:headers_length) { 101 }
        it { is_expected.to be false }
      end
    end

    context 'with valid values' do
      let(:total_length) { 100 }
      let(:headers_length) { 50 }
      it { is_expected.to be true }
    end
  end

  describe '#valid_positions?' do
    subject { instance.valid_positions?(headers_end, payload_end, chunk_size) }

    context 'with invalid positions' do
      context 'when headers_end >= payload_end' do
        let(:headers_end) { 100 }
        let(:payload_end) { 100 }
        let(:chunk_size) { 200 }
        it { is_expected.to be false }
      end

      context 'when headers_end >= chunk_size' do
        let(:headers_end) { 200 }
        let(:payload_end) { 300 }
        let(:chunk_size) { 200 }
        it { is_expected.to be false }
      end

      context 'when payload_end > chunk_size' do
        let(:headers_end) { 100 }
        let(:payload_end) { 300 }
        let(:chunk_size) { 200 }
        it { is_expected.to be false }
      end
    end

    context 'with valid positions' do
      let(:headers_end) { 100 }
      let(:payload_end) { 150 }
      let(:chunk_size) { 200 }
      it { is_expected.to be true }
    end
  end
end 