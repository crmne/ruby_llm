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
end
