# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::FileStore::Converters::Factory do
  include_context 'with configured RubyLLM'

  let(:converters) { RubyLLM.file_store.converter }

  it 'is what RubyLLM.file_store.converter returns' do
    expect(converters).to be(described_class)
  end

  it 'builds an OCR converter with the options it is given' do
    attachment = RubyLLM::Attachment.new(StringIO.new('scan'), filename: 'scan.png')
    allow(RubyLLM).to receive(:ocr).and_return(instance_double(RubyLLM::OCR, markdown: '# Read'))

    expect(converters.ocr(model: 'mistral-ocr-latest').call(attachment)).to eq('# Read')
    expect(RubyLLM).to have_received(:ocr).with(attachment, model: 'mistral-ocr-latest')
  end

  it 'returns the text converter, which reads a file as it is' do
    text = RubyLLM::Attachment.new(StringIO.new('{"a":1}'), filename: 'rows.ndjson')

    expect(converters.text.call(text)).to eq('{"a":1}')
  end

  it 'offers only the converters RubyLLM ships' do
    expect(described_class.singleton_methods.sort).to eq(%i[ocr text])
  end

  it 'reads a type registered with a built-in converter' do
    config = RubyLLM::Configuration.new
    store = RubyLLM.file_store.memory
    store.write('talk.srt', "1\n00:00:01,000 --> 00:00:02,000\nHello\n")

    expect(store.text('talk.srt', config:)).to be_nil
    config.file_converters['application/x-subrip'] = converters.text
    expect(store.text('talk.srt', config:)).to include('Hello')
  end

  it "keeps a context's converters apart from the global ones" do
    context = RubyLLM.context { |config| config.file_converters['image/*'] = converters.ocr }

    expect(context.config.file_converters).to include('image/*')
    expect(RubyLLM.config.file_converters).not_to include('image/*')
  end
end
