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
  end

  it 'reads Word, Excel, and PowerPoint files on this machine' do
    expect(described_class.convert(fixture('sample.docx'), config:))
      .to eq('RubyLLM document attachment probe. The project codename is BLUE-LANTERN-42. ' \
             'The approval status is ready.')
    expect(described_class.convert(fixture('sample.xlsx'), config:))
      .to eq("## rubyllm_spreadsheet_probe\nlabel\tvalue\nspreadsheet_code\tORCHID-97\nstatus\tready")
    expect(described_class.convert(fixture('sample.pptx'), config:))
      .to eq("## Slide 1\n\nQuarterly review\nRevenue & costs\n\n## Slide 2\n\nThe launch code is SILVER-FERN-8")
  end

  it 'keeps the cells of a row in their columns, and the order of sheets and slides in the workbook and deck' do
    expect(described_class::Office.send(:cells, '<c r="A1"><v>1</v></c><c r="C1"><v>3</v></c>', []))
      .to eq(['1', '', '3'])
    expect(described_class.convert(fixture('sample.pptx'), config:)).to start_with("## Slide 1\n\nQuarterly review")
  end

  it 'reads an Office file that uses other prefixes and relative part paths' do
    expect(described_class.convert(fixture('sample-prefixed.xlsx'), config:))
      .to eq("## Second\ninline\n\n## First\nORCHID-97\t7")
  end

  it 'ignores a cell reference past the last column a sheet can have' do
    expect(described_class::Office.send(:cells, '<c r="XFE1"><v>1</v></c>', [])).to eq(['1'])
    expect(described_class::Office.send(:cells, '<c r="XFD1"><v>1</v></c>', []).size).to eq(16_384)
  end

  it 'gives up on a workbook whose text passes the limit, as padding can without inflating much' do
    expect(described_class.convert(fixture('sample-wide.xlsx'), config:).size).to be > 16_000

    stub_const('RubyLLM::FileStore::Converters::Office::MAX_SIZE', 2_000)
    expect(described_class.convert(fixture('sample-wide.xlsx'), config:)).to be_nil
  end

  it 'reads the entities XML defines and no others' do
    expect(described_class::Office.send(:unescape, '&amp;lt; &#233; &#xe9; &nbsp;')).to eq('&lt; é é &nbsp;')
  end

  it 'stops local extraction at the first converter that is not local' do
    paid = ->(_file) { raise 'a paid converter must wait' }
    local = Class.new do
      def self.call(_file) = nil
      def self.local? = true
    end
    config.file_converters = { 'application/pdf' => [local, paid] }

    expect(described_class.convert(fixture('sample.pdf'), config:, local: true)).to be_nil
  end

  it 'reads nothing from a truncated Office file' do
    content = File.binread(File.expand_path('../../fixtures/sample.docx', __dir__))

    expect(described_class.convert(text_file(content[0, 200], 'cut.docx'), config:)).to be_nil
    expect(described_class.convert(text_file(content[-30..], 'tail.docx'), config:)).to be_nil
  end

  it 'reads nothing from a broken Office file' do
    expect(described_class.convert(text_file('not a zip', 'notes.docx'), config:)).to be_nil
  end

  it 'refuses an Office file whose part inflates past its limit' do
    stub_const('RubyLLM::FileStore::Converters::Office::MAX_SIZE', 100)

    expect(described_class.convert(fixture('sample.docx'), config:)).to be_nil
  end

  it 'refuses an Office file whose part inflates past the size it declares' do
    content = File.binread(File.expand_path('../../fixtures/sample.docx', __dir__))
    content[content.rindex('word/document.xml') - 22, 4] = [10].pack('V')

    expect(described_class.convert(text_file(content, 'lying.docx'), config:)).to be_nil
  end

  it 'says which converters run on this machine for free' do
    expect([described_class::Text, described_class::Office]).to all(satisfy(&:local?))
    expect(described_class::OCR.new).not_to respond_to(:local?)
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
