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

  it 'reads HTML without its tags, scripts, and styles' do
    html = '<html><head><style>p { color: red }</style><script>alert(1)</script></head>' \
           '<body><h1>Title</h1><p>Fish &amp; chips&nbsp;today</p><!-- hidden -->' \
           '<ul><li>One</li><li>Two</li></ul></body></html>'

    expect(described_class.convert(text_file(html, 'page.html'), config:)).to eq("Title\nFish & chips today\nOne\nTwo")
  end

  it 'reads HTML in time linear in its length, keeping a stray < as text' do
    expect(described_class.convert(text_file('<p>1 < 2', 'math.html'), config:)).to eq('1 < 2')
    expect(described_class.convert(text_file("<p>x</p>#{'<a ' * 100_000}", 'hostile.html'),
                                   config:)).to start_with('x')
  end

  it 'reads Word documents' do
    expect(described_class.convert(fixture('sample.docx'), config:))
      .to eq('RubyLLM document attachment probe. The project codename is BLUE-LANTERN-42. ' \
             'The approval status is ready.')
  end

  it 'reads Excel workbooks sheet by sheet with tab-separated cells' do
    expect(described_class.convert(fixture('sample.xlsx'), config:))
      .to eq("## Sheet: rubyllm_spreadsheet_probe\n\nlabel\tvalue\nspreadsheet_code\tORCHID-97\nstatus\tready")
  end

  it 'reads PowerPoint decks slide by slide' do
    expect(described_class.convert(fixture('sample.pptx'), config:))
      .to eq("## Slide 1\n\nQuarterly review\nRevenue & growth\n\n" \
             "## Slide 2\n\nNext steps: ship the TEAL-HERON-7 release")
  end

  it 'reads the text of a PDF page by page' do
    text = described_class.convert(fixture('sample.pdf'), config:)

    expect(text).to start_with("## Page 1\n\nSample PDF\n\nThis is a simple PDF")
  end

  it 'reads no PDF without pdf-reader' do
    allow(RubyLLM::FileStore::Converters::PDF).to receive(:available?).and_return(false)

    expect(described_class.convert(fixture('sample.pdf'), config:)).to be_nil
  end

  it 'reads nothing from a file no converter knows, or a broken Office file' do
    expect(described_class.convert(fixture('ruby.png'), config:)).to be_nil
    broken = text_file('not a zip', 'broken.docx')
    expect(described_class.convert(broken, config:)).to be_nil
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

  describe RubyLLM::FileStore::Converters::Zip do
    it 'refuses entries that inflate past the limit' do
      stub_const('RubyLLM::FileStore::Converters::Zip::MAX_SIZE', 100)
      zip = described_class.new(File.binread(File.expand_path('../../fixtures/sample.pptx', __dir__)))

      expect { zip.read('ppt/slides/slide1.xml') }.to raise_error(described_class::Error, /too large/)
    end

    it 'refuses what is not a ZIP archive' do
      expect { described_class.new('plain text') }.to raise_error(described_class::Error, /Not a ZIP/)
    end
  end
end
