# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Transcription::WavAudio do
  let(:format) { chunk('fmt ', [1, 1, 24_000, 48_000, 2, 16].pack('vvVVvv')) }

  it 'accepts an odd final chunk without its pad byte' do
    format = [1, 1, 8000, 8000, 1, 8].pack('vvVVvv')
    body = "WAVEfmt #{[16].pack('V')}#{format}data#{[3].pack('V')}abc".b
    wav = "RIFF#{[body.bytesize].pack('V')}".b + body

    expect(described_class.new(wav).data).to eq('abc'.b)
  end

  def wav(chunks, declared_size: nil)
    content = "WAVE#{chunks}"
    "RIFF#{[declared_size || content.bytesize].pack('V')}#{content}"
  end

  def chunk(name, data)
    name + [data.bytesize].pack('V') + data + (data.bytesize.odd? ? "\x00" : '')
  end

  it 'reads PCM format and audio after padded metadata chunks' do
    audio = described_class.new(wav(chunk('JUNK', 'x') + format + chunk('data', "\x00\x01")))

    expect(audio.data).to eq("\x00\x01")
    expect(audio.sample_rate).to eq(24_000)
    expect(audio.channels).to eq(1)
    expect(audio.bits_per_sample).to eq(16)
    expect(audio.encoding).to eq(1)
    expect(audio.duration).to eq(1.0 / 24_000)
  end

  it 'reads WAV recordings with unspecified RIFF and data lengths' do
    audio = described_class.new(wav("#{format}data#{[0xFFFFFFFF].pack('V')}\x00\x01", declared_size: 0xFFFFFFFF))

    expect(audio.data).to eq("\x00\x01")
  end

  it 'rejects truncated data and stray bytes after the last chunk' do
    expect { described_class.new(wav("#{format}data#{[4].pack('V')}ab")) }
      .to raise_error(ArgumentError, /truncated chunk/)
    expect { described_class.new(wav("#{format}xy")) }.to raise_error(ArgumentError, /padding/)
  end

  it 'rejects an incomplete RIFF container, short format or missing audio' do
    expect { described_class.new(wav(format, declared_size: 1000)) }.to raise_error(ArgumentError, /truncated/)
    expect { described_class.new(wav(chunk('fmt ', 'x'))) }.to raise_error(ArgumentError, /invalid audio format/)
    expect { described_class.new(wav(format)) }.to raise_error(ArgumentError, /must contain audio/)
  end
end
