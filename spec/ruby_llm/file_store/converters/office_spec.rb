# frozen_string_literal: true

require 'spec_helper'
require 'zlib'

RSpec.describe RubyLLM::FileStore::Converters::Office do
  let(:config) { RubyLLM::Configuration.new }

  # Writes a zip by hand. With +zip64+, every central entry says its sizes
  # are in a Zip64 extra field, the way streaming zip writers do; +declared+
  # overrides the uncompressed size that field gives.
  def zip_of(parts, zip64: false, zip64_directory: false, declared: nil)
    body = +''.b
    central = +''.b
    parts.each do |name, xml|
      data = deflate(xml.b)
      central << central_entry(name, xml.b, data, body.bytesize, (declared || xml.bytesize if zip64))
      body << "PK\x03\x04".b << [20, 0, 8, 0, 0, Zlib.crc32(xml.b), data.bytesize, xml.bytesize, name.bytesize, 0]
                                .pack('vvvvvVVVvv') << name.b << data
    end
    finish(body, central, parts.size, zip64_directory)
  end

  def deflate(bytes)
    deflater = Zlib::Deflate.new(Zlib::DEFAULT_COMPRESSION, -Zlib::MAX_WBITS)
    deflater.deflate(bytes, Zlib::FINISH).tap { deflater.close }
  end

  def central_entry(name, xml, data, offset, zip64_size)
    extra = zip64_size ? [1, 16, zip64_size, data.bytesize].pack('vvQ<Q<') : ''.b
    compressed, size = zip64_size ? [0xFFFFFFFF, 0xFFFFFFFF] : [data.bytesize, xml.bytesize]
    "PK\x01\x02".b + [45, 45, 0, 8, 0, 0, Zlib.crc32(xml), compressed, size, name.bytesize, extra.bytesize,
                      0, 0, 0, 0, offset].pack('vvvvvvVVVvvvvvVV') + name.b + extra
  end

  def finish(body, central, count, zip64_directory)
    start = body.bytesize
    output = body + central
    if zip64_directory
      record = output.bytesize
      output += "PK\x06\x06".b + [44, 45, 45, 0, 0, count, count, central.bytesize, start].pack('Q<vvVVQ<Q<Q<Q<')
      output += "PK\x06\x07".b + [0, record, 1].pack('VQ<V')
      return output + "PK\x05\x06".b + [0, 0, 0xFFFF, 0xFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0].pack('vvvvVVv')
    end
    output + "PK\x05\x06".b + [0, 0, count, count, central.bytesize, start, 0].pack('vvvvVVv')
  end

  def text_of(bytes, filename)
    RubyLLM::FileStore::Converters.convert(RubyLLM::Attachment.new(StringIO.new(bytes), filename:), config:)
  end

  def docx(body, **)
    text_of(zip_of({ 'word/document.xml' => "<w:document><w:body>#{body}</w:body></w:document>" }, **), 'a.docx')
  end

  def with_regexp_timeout(seconds)
    skip 'This Ruby has no Regexp.timeout' unless Regexp.respond_to?(:timeout=)

    before = Regexp.timeout
    Regexp.timeout = seconds
    yield
  ensure
    Regexp.timeout = before if Regexp.respond_to?(:timeout=)
  end

  describe 'Zip64 archives' do
    let(:paragraph) { '<w:p><w:r><w:t>x</w:t></w:r></w:p>' }

    it 'reads the sizes from the Zip64 extra field' do
      expect(docx(paragraph, zip64: true)).to eq('x')
    end

    it 'reads the Zip64 end of central directory' do
      expect(docx(paragraph, zip64_directory: true)).to eq('x')
      expect(docx(paragraph, zip64: true, zip64_directory: true)).to eq('x')
    end

    it 'keeps its limit against the real size, whatever the entry declares' do
      stub_const("#{described_class}::MAX_SIZE", 200)

      expect(docx(paragraph * 100, zip64: true, declared: 10**15)).to be_nil
      expect(docx(paragraph, zip64: true, declared: 10**15)).to eq('x')
    end

    it 'refuses a part cut off before its deflate stream ends' do
      bytes = zip_of({ 'word/document.xml' => paragraph * 100 })
      position = bytes.rindex('word/document.xml') - 26
      bytes[position, 4] = [bytes[position, 4].unpack1('V') - 2].pack('V')

      expect(text_of(bytes, 'a.docx')).to be_nil
    end

    it 'refuses a part that inflates past the size it declares' do
      expect(docx(paragraph, zip64: true, declared: 5)).to be_nil
    end
  end

  it 'finds parts through a relationship id under any prefix' do
    files = { 'xl/workbook.xml' => '<workbook><sheets><sheet name="B" ns1:id="rId2"/><sheet name="A" ns1:id="rId1"/>' \
                                   '</sheets></workbook>',
              'xl/_rels/workbook.xml.rels' => '<Relationships>' \
                                              '<Relationship Id="rId1" Target="worksheets/sheet1.xml"/>' \
                                              '<Relationship Id="rId2" Target="worksheets/sheet2.xml"/>' \
                                              '</Relationships>',
              'xl/worksheets/sheet1.xml' => '<worksheet><sheetData/></worksheet>',
              'xl/worksheets/sheet2.xml' => '<worksheet><sheetData/></worksheet>' }

    expect(text_of(zip_of(files), 'a.xlsx')).to eq("## B\n\n## A")
  end

  describe 'hostile files' do
    it 'reads nothing from a relationship target holding a NUL' do
      parts = { 'xl/workbook.xml' => '<workbook><sheets><sheet name="A" r:id="rId1"/></sheets></workbook>',
                'xl/_rels/workbook.xml.rels' => %(<Relationships><Relationship Id="rId1" Target="a\0b"/>) +
                                                '</Relationships>' }

      expect { text_of(zip_of(parts), 'a.xlsx') }.not_to raise_error
    end

    it 'reads unclosed tags in linear time, under a Regexp.timeout' do
      with_regexp_timeout(0.1) do
        expect { docx('<w:p>' * 1_000_000) }.not_to raise_error
        sheet = "<worksheet><sheetData>#{'<row><c>' * 1_000_000}</sheetData></worksheet>"
        expect { text_of(zip_of({ 'xl/worksheets/sheet1.xml' => sheet }), 'a.xlsx') }.not_to raise_error
      end
    end

    it 'never raises out of FileStore#text, whatever goes wrong inside it' do
      store = RubyLLM::FileStore::Memory.new
      store.write('a.docx', zip_of({ 'word/document.xml' => '<w:p><w:t>x</w:t></w:p>' }))
      allow(described_class::Zip).to receive(:new).and_raise(ArgumentError, 'broken')

      expect(store.text('a.docx', config:)).to be_nil
    end
  end

  describe 'Excel' do
    let(:styles) do
      <<~XML
        <styleSheet>
          <numFmts count="3">
            <numFmt numFmtId="164" formatCode="yyyy\\-mm\\-dd"/>
            <numFmt numFmtId="165" formatCode="0.00&quot; days&quot;"/>
            <numFmt numFmtId="166" formatCode="[h]:mm:ss"/>
          </numFmts>
          <cellStyleXfs count="1"><xf numFmtId="14"/></cellStyleXfs>
          <cellXfs count="7">
            <xf numFmtId="0"/><xf numFmtId="14"/><xf numFmtId="164"/><xf numFmtId="165"/>
            <xf numFmtId="166"/><xf numFmtId="22"/><xf numFmtId="18"/>
          </cellXfs>
        </styleSheet>
      XML
    end

    def xlsx(cells, workbook: '<workbook/>', **parts)
      sheet = "<worksheet><sheetData><row r=\"1\">#{cells}</row></sheetData></worksheet>"
      files = { 'xl/workbook.xml' => workbook, 'xl/styles.xml' => styles, 'xl/worksheets/sheet1.xml' => sheet }
      text_of(zip_of(files.merge(parts.transform_keys(&:to_s))), 'a.xlsx')
    end

    def value(serial, style) = xlsx(%(<c r="A1" s="#{style}"><v>#{serial}</v></c>)).lines.last

    it 'reads date cells as dates, from built-in and custom formats' do
      expect(value(46_112, 1)).to eq('2026-03-31')
      expect(value(46_112, 2)).to eq('2026-03-31')
    end

    it 'leaves numbers whose format only mentions a date letter in quotes, and durations' do
      expect(value(46_112, 0)).to eq('46112')
      expect(value(46_112, 3)).to eq('46112')
      expect(value(1.5, 4)).to eq('1.5')
    end

    it 'reads times and dates with times' do
      expect(value(46_112.5, 5)).to eq('2026-03-31 12:00:00')
      expect(value(0.5, 6)).to eq('12:00:00')
    end

    it "keeps Excel's fictitious 1900-02-29 and the days around it" do
      expect(value(59, 1)).to eq('1900-02-28')
      expect(value(60, 1)).to eq('1900-02-29')
      expect(value(61, 1)).to eq('1900-03-01')
    end

    it 'leaves a value no date can have' do
      expect(value(-1, 1)).to eq('-1')
      expect(value(99_999_999, 1)).to eq('99999999')
    end

    it 'uses the 1904 date system when the workbook sets it' do
      text = xlsx('<c r="A1" s="1"><v>44650</v></c>', workbook: '<workbook><workbookPr date1904="1"/></workbook>')

      expect(text.lines.last).to eq('2026-03-31')
    end

    it 'reads booleans as TRUE and FALSE' do
      expect(xlsx('<c r="A1" t="b"><v>1</v></c><c r="B1" t="b"><v>0</v></c>').lines.last).to eq("TRUE\tFALSE")
    end

    it 'drops a blank row' do
      sheet = '<worksheet><sheetData><row r="1"><c r="A1"><v>1</v></c></row>' \
              '<row r="2"><c r="A2" s="1"/><c r="B2" s="1"/></row><row r="3"><c r="A3"><v>3</v></c></row>' \
              '</sheetData></worksheet>'

      expect(text_of(zip_of({ 'xl/worksheets/sheet1.xml' => sheet }), 'a.xlsx')).to eq("## Sheet 1\n1\n3")
    end

    it 'keeps cells in their columns, and ignores a reference past the last one' do
      expect(xlsx('<c r="A1"><v>1</v></c><c r="C1"><v>3</v></c>').lines.last).to eq("1\t\t3")
      expect(xlsx('<c r="XFE1"><v>1</v></c>').lines.last).to eq('1')
      expect(xlsx('<c r="XFD1"><v>1</v></c>').lines.last.size).to eq(16_384)
    end

    it 'leaves out phonetic hints and formulas' do
      strings = '<sst><si><t>東京</t><rPh sb="0" eb="2"><t>トウキョウ</t></rPh></si></sst>'
      cells = '<c r="A1" t="s"><v>0</v></c><c r="B1"><f>1+1</f><v>2</v></c>'

      expect(xlsx(cells, 'xl/sharedStrings.xml': strings).lines.last).to eq("東京\t2")
    end
  end

  describe 'PowerPoint' do
    def shape(text, placeholder = nil)
      kind = %(<p:nvPr><p:ph type="#{placeholder}"/></p:nvPr>) if placeholder
      "<p:sp><p:nvSpPr>#{kind}</p:nvSpPr><p:txBody><a:p><a:r><a:t>#{text}</a:t></a:r></a:p></p:txBody></p:sp>"
    end

    def deck(notes)
      parts = {
        'ppt/presentation.xml' => '<p:presentation><p:sldIdLst><p:sldId r:id="rId1"/></p:sldIdLst></p:presentation>',
        'ppt/_rels/presentation.xml.rels' => '<Relationships><Relationship Id="rId1" Target="slides/slide1.xml"/>' \
                                             '</Relationships>',
        'ppt/slides/slide1.xml' => "<p:sld>#{shape('Revenue')}</p:sld>",
        'ppt/slides/_rels/slide1.xml.rels' => '<Relationships><Relationship Id="rId2" ' \
                                              'Type="http://x/relationships/notesSlide" ' \
                                              'Target="../notesSlides/notesSlide1.xml"/></Relationships>',
        'ppt/notesSlides/notesSlide1.xml' => "<p:notes>#{notes}</p:notes>"
      }
      text_of(zip_of(parts), 'a.pptx')
    end

    it 'reads speaker notes, marked as notes, without the slide number' do
      expect(deck(shape('Say the number', 'body') + shape('7', 'sldNum')))
        .to eq("## Slide 1\n\nRevenue\n\nSpeaker notes:\nSay the number")
    end

    it 'keeps a line break that carries run properties' do
      paragraph = '<a:p><a:r><a:t>One</a:t></a:r><a:br><a:rPr lang="en-US"/></a:br><a:r><a:t>Two</a:t></a:r></a:p>'

      expect(deck("<p:sp><p:txBody>#{paragraph}</p:txBody></p:sp>")).to end_with("Speaker notes:\nOne\nTwo")
    end

    it 'adds no notes section when the notes are empty' do
      expect(deck(shape('7', 'sldNum'))).to eq("## Slide 1\n\nRevenue")
    end
  end

  describe 'Word' do
    def run(content) = "<w:r>#{content}</w:r>"

    it 'reads tabs and line breaks' do
      paragraph = "<w:p>#{run('<w:t>Name</w:t><w:tab/><w:t>Value</w:t><w:br/><w:t>Next</w:t>')}</w:p>"

      expect(docx(paragraph)).to eq("Name\tValue\nNext")
    end

    it 'leaves out the tab stops a paragraph defines' do
      paragraph = '<w:p><w:pPr><w:tabs><w:tab w:val="left" w:pos="720"/></w:tabs></w:pPr>' \
                  "#{run('<w:t>One</w:t>')}</w:p>"

      expect(docx(paragraph)).to eq('One')
    end

    def cell(*texts) = "<w:tc><w:tcPr/>#{texts.map { |text| "<w:p>#{run("<w:t>#{text}</w:t>")}</w:p>" }.join}</w:tc>"

    it 'keeps the cells of a table row on one line, between its paragraphs' do
      header = "<w:tr>#{cell('Name')}#{cell('Age')}</w:tr>"
      table = "<w:tbl><w:tblPr/>#{header}<w:tr>#{cell('Ada')}#{cell('36')}</w:tr></w:tbl>"

      expect(docx("<w:p>#{run('<w:t>Before</w:t>')}</w:p>#{table}<w:p>#{run('<w:t>After</w:t>')}</w:p>"))
        .to eq("Before\nName\tAge\nAda\t36\nAfter")
    end

    it 'keeps a row on one line whatever its cells hold, and empty cells in place' do
      break_in_cell = "<w:tc><w:p>#{run('<w:t>a</w:t><w:br/><w:t>b</w:t>')}</w:p></w:tc>"
      table = "<w:tbl><w:tr>#{cell('one', 'two')}<w:tc><w:p/></w:tc>#{break_in_cell}</w:tr></w:tbl>"

      expect(docx(table)).to eq("one two\t\ta b")
    end

    it 'flattens a nested table into its cell' do
      inner = "<w:tbl><w:tr>#{cell('x')}#{cell('y')}</w:tr></w:tbl>"
      table = "<w:tbl><w:tr><w:tc>#{inner}<w:p/></w:tc>#{cell('z')}</w:tr></w:tbl>"

      expect(docx(table)).to eq("x y\tz")
    end

    it 'keeps a text box between the text around it' do
      box = "<w:txbxContent><w:p>#{run('<w:t>Box</w:t>')}</w:p></w:txbxContent>"

      expect(docx("<w:p>#{run('<w:t>Before</w:t>')}#{run(box)}#{run('<w:t>After</w:t>')}</w:p>"))
        .to eq("Before\nBox\nAfter")
    end

    it 'reads a text box once, not again from its fallback' do
      box = '<mc:AlternateContent><mc:Choice><w:txbxContent><w:p><w:r><w:t>Box</w:t></w:r></w:p></w:txbxContent>' \
            '</mc:Choice><mc:Fallback><w:p><w:r><w:t>Box</w:t></w:r></w:p></mc:Fallback></mc:AlternateContent>'

      expect(docx(box)).to eq('Box')
    end
  end
end
