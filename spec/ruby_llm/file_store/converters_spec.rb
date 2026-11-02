# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::FileStore::Converters do
  def fixture(name)
    RubyLLM::Attachment.new(File.expand_path("../../fixtures/#{name}", __dir__))
  end

  def text_file(content, filename)
    RubyLLM::Attachment.new(StringIO.new(content), filename:)
  end

  let(:config) { RubyLLM::Configuration.new }

  it 'reads text files as they are' do
    expect(described_class.convert(fixture('sample.csv'), config:)).to start_with("invoice,amount,due\n12345")
    expect(described_class.convert(fixture('ruby.xml'), config:)).to include('<truism>Ruby is the best</truism>')
  end

  it 'reads nothing from a file no converter knows' do
    expect(described_class.convert(fixture('ruby.png'), config:)).to be_nil
    expect(described_class.convert(fixture('sample.pdf'), config:)).to be_nil
    expect(described_class.convert(fixture('sample.docx'), config:)).to be_nil
  end

  it 'tries configured converters first, exact types before wildcards, then the built-in ones' do
    calls = []
    config.file_converters = {
      'image/*' => ->(_) { calls << :wildcard and 'wildcard' },
      'image/png' => [->(_) { calls << :empty and '  ' }, ->(_) { calls << :exact and nil }],
      'text/csv' => ->(_) {}
    }

    expect(described_class.convert(fixture('ruby.png'), config:)).to eq('wildcard')
    expect(calls).to eq(%i[empty exact wildcard])
    expect(described_class.convert(fixture('sample.csv'), config:)).to start_with('invoice')
  end

  it 'scrubs text a converter returns in a broken encoding' do
    config.file_converters['text/plain'] = ->(_file) { "\xFF text" }

    expect(described_class.convert(text_file('a', 'a.txt'), config:)).to eq("\uFFFD text")
  end

  it 'moves on from a converter that returns only blanks' do
    config.file_converters['text/plain'] = [->(_file) { " \n" }, ->(_file) { 'found' }]

    expect(described_class.convert(text_file('a', 'a.txt'), config:)).to eq('found')
  end

  it 'takes */* for every type' do
    config.file_converters = { '*/*' => ->(file) { "read #{file.filename}" } }

    expect(described_class.convert(fixture('sample.csv'), config:)).to eq('read sample.csv')
  end

  describe RubyLLM::FileStore::Converters::OCR do
    it 'reads a file with RubyLLM.ocr and the options it was given' do
      result = RubyLLM::OCR.new(pages: [{ 'markdown' => '# Scanned' }, { 'markdown' => 'Page two' }], model: 'm')
      allow(RubyLLM).to receive(:ocr).and_return(result)
      attachment = fixture('ruby.png')

      expect(described_class.new(model: 'mistral-ocr-latest').call(attachment)).to eq("# Scanned\n\nPage two")
      expect(RubyLLM).to have_received(:ocr).with(attachment, model: 'mistral-ocr-latest')
    end
  end

  it 'builds an OCR converter with the options it is given' do
    attachment = RubyLLM::Attachment.new(StringIO.new('scan'), filename: 'scan.png')
    allow(RubyLLM).to receive(:ocr).and_return(instance_double(RubyLLM::OCR, markdown: '# Read'))

    expect(described_class::OCR.new(model: 'mistral-ocr-latest').call(attachment)).to eq('# Read')
    expect(RubyLLM).to have_received(:ocr).with(attachment, model: 'mistral-ocr-latest')
  end

  it 'returns the text converter, which reads a file as it is' do
    text = RubyLLM::Attachment.new(StringIO.new('{"a":1}'), filename: 'rows.ndjson')

    expect(described_class::Text.call(text)).to eq('{"a":1}')
  end

  it 'reads a type registered with a built-in converter' do
    config = RubyLLM::Configuration.new
    store = RubyLLM::FileStore::Memory.new
    store.write('talk.srt', "1\n00:00:01,000 --> 00:00:02,000\nHello\n")

    expect(store.text('talk.srt', config:)).to be_nil
    config.file_converters['application/x-subrip'] = described_class::Text
    expect(store.text('talk.srt', config:)).to include('Hello')
  end

  it "keeps a context's converters apart from the global ones" do
    context = RubyLLM.context { |config| config.file_converters['image/*'] = described_class::OCR.new }

    expect(context.config.file_converters).to include('image/*')
    expect(RubyLLM.config.file_converters).not_to include('image/*')
  end
end
