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

  it 'finds parts through a relationship id under any prefix, in either quote' do
    sheets = %(<sheet name="B" ns1:id='rId2'/><sheet name="A" ns1:id="rId1"/>)
    files = { 'xl/workbook.xml' => "<workbook><sheets>#{sheets}</sheets></workbook>",
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

      allow(RubyLLM.logger).to receive(:warn)

      expect { text_of(zip_of(parts), 'a.xlsx') }.not_to raise_error
      expect(RubyLLM.logger).not_to have_received(:warn)
    end

    it 'reads unclosed tags in linear time, under a Regexp.timeout' do
      with_regexp_timeout(0.1) do
        allow(RubyLLM.logger).to receive(:warn)

        expect(docx("<w:p><w:r><w:t>first</w:t></w:r></w:p>#{'<w:p>' * 1_000_000}")).to eq('first')
        rows = "<row r=\"1\"><c r=\"A1\"><v>7</v></c></row>#{'<row><c>' * 1_000_000}"
        sheet = "<worksheet><sheetData>#{rows}</sheetData></worksheet>"
        expect(text_of(zip_of({ 'xl/worksheets/sheet1.xml' => sheet }), 'a.xlsx')).to eq("## Sheet 1\n7")
        expect(RubyLLM.logger).not_to have_received(:warn)
      end
    end

    it 'never expands a DOCTYPE entity, and reads the reference as text' do
      entities = (1..9).map { |n| %(<!ENTITY lol#{n} "#{"&lol#{n - 1};" * 10}">) }.join
      subset = %(<!DOCTYPE lolz [<!ENTITY lol0 "lol">#{entities}]>)
      bomb = "#{subset}<w:document><w:body><w:p><w:r><w:t>&lol9;</w:t></w:r></w:p></w:body></w:document>"

      expect(text_of(zip_of({ 'word/document.xml' => bomb }), 'a.docx')).to eq('&lol9;')
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

    def paragraph(text, properties = '') = "<w:p><w:pPr>#{properties}</w:pPr>#{run("<w:t>#{text}</w:t>")}</w:p>"
    def style(name) = %(<w:pStyle w:val="#{name}"/>)
    def list(id, level = 0) = %(<w:numPr><w:ilvl w:val="#{level}"/><w:numId w:val="#{id}"/></w:numPr>)

    def word(body, styles: nil, numbering: nil)
      parts = { 'word/document.xml' => "<w:document><w:body>#{body}</w:body></w:document>" }
      parts['word/styles.xml'] = "<w:styles>#{styles}</w:styles>" if styles
      parts['word/numbering.xml'] = "<w:numbering>#{numbering}</w:numbering>" if numbering
      text_of(zip_of(parts), 'a.docx')
    end

    describe 'headings' do
      def paragraph_style(id, *children)
        %(<w:style w:type="paragraph" w:styleId="#{id}">#{children.join}</w:style>)
      end

      def named(name) = %(<w:name w:val="#{name}"/>)
      def based_on(id) = %(<w:basedOn w:val="#{id}"/>)
      def outline(level) = %(<w:pPr><w:outlineLvl w:val="#{level}"/></w:pPr>)

      it 'renders the six heading styles as Markdown headings' do
        styles = (1..6).map { |level| paragraph_style("H#{level}", named("heading #{level}")) }.join

        expect(word((1..6).map { |level| paragraph("T#{level}", style("H#{level}")) }.join, styles:))
          .to eq("# T1\n## T2\n### T3\n#### T4\n##### T5\n###### T6")
      end

      it 'reads a localized style by its outline level, and a custom one through basedOn' do
        styles = paragraph_style('berschrift1', named('Überschrift 1'), outline(0)) +
                 paragraph_style('Report', named('Report Title'), based_on('berschrift1')) +
                 paragraph_style('Deep', named('Deep'), based_on('H2')) +
                 paragraph_style('H2', named('heading 2'))

        expect(word(paragraph('A', style('berschrift1')) + paragraph('B', style('Report')) +
                    paragraph('C', style('Deep')), styles:)).to eq("# A\n# B\n## C")
      end

      it 'lets a nearer style turn a heading off with the body text level' do
        styles = paragraph_style('H1', named('heading 1'), outline(0)) +
                 paragraph_style('Quiet', named('Quiet'), based_on('H1'), outline(9))

        expect(word(paragraph('A', style('Quiet')), styles:)).to eq('A')
      end

      it "reads a paragraph's own outline level first" do
        styles = paragraph_style('H1', named('heading 1'), outline(0))

        expect(word(paragraph('A', '<w:outlineLvl w:val="2"/>') +
                    paragraph('B', "#{style('H1')}<w:outlineLvl w:val=\"9\"/>"), styles:)).to eq("### A\nB")
      end

      it 'leaves levels past six, and a heading in a table cell, as plain text' do
        styles = paragraph_style('H7', named('heading 7')) + paragraph_style('H1', named('heading 1'))
        cell = "<w:tbl><w:tr><w:tc>#{paragraph('In a cell', style('H1'))}</w:tc></w:tr></w:tbl>"

        expect(word(paragraph('Seven', style('H7')) + paragraph('Too', '<w:outlineLvl w:val="7"/>') + cell, styles:))
          .to eq("Seven\nToo\nIn a cell")
      end

      it 'survives a basedOn cycle' do
        styles = paragraph_style('A', based_on('B')) + paragraph_style('B', based_on('A'))

        expect(word(paragraph('Loop', style('A')), styles:)).to eq('Loop')
      end

      it 'reads plain lines without styles, with broken ones, and with an unknown style' do
        expect(word(paragraph('A', style('H1')))).to eq('A')
        expect(word(paragraph('A', style('H1')), styles: '<w:style w:styleId=')).to eq('A')
        expect(word(paragraph('A', style('Nope')), styles: paragraph_style('H1', named('heading 1')))).to eq('A')
      end

      it 'reads the document when its styles are too large to read' do
        stub_const("#{described_class}::MAX_SIZE", 1_000)
        styles = paragraph_style('H1', named('heading 1')) * 100

        expect(word(paragraph('A', style('H1')), styles:)).to eq('A')
      end
    end

    describe 'lists' do
      let(:numbering) do
        <<~XML
          <w:abstractNum w:abstractNumId="0">
            <w:lvl w:ilvl="0"><w:start w:val="1"/><w:numFmt w:val="bullet"/></w:lvl>
            <w:lvl w:ilvl="1"><w:start w:val="1"/><w:numFmt w:val="bullet"/></w:lvl>
          </w:abstractNum>
          <w:abstractNum w:abstractNumId="1">
            <w:lvl w:ilvl="0"><w:start w:val="1"/><w:numFmt w:val="decimal"/></w:lvl>
            <w:lvl w:ilvl="1"><w:start w:val="1"/><w:numFmt w:val="lowerLetter"/></w:lvl>
          </w:abstractNum>
          <w:abstractNum w:abstractNumId="2">
            <w:lvl w:ilvl="0"><w:start w:val="5"/><w:numFmt w:val="decimal"/></w:lvl>
          </w:abstractNum>
          <w:abstractNum w:abstractNumId="3">
            <w:lvl w:ilvl="0"><w:start w:val="1"/><w:numFmt w:val="none"/></w:lvl>
          </w:abstractNum>
          <w:num w:numId="1"><w:abstractNumId w:val="0"/></w:num>
          <w:num w:numId="2"><w:abstractNumId w:val="1"/></w:num>
          <w:num w:numId="3"><w:abstractNumId w:val="1"/></w:num>
          <w:num w:numId="4"><w:abstractNumId w:val="1"/>
            <w:lvlOverride w:ilvl="0"><w:startOverride w:val="1"/></w:lvlOverride></w:num>
          <w:num w:numId="5"><w:abstractNumId w:val="2"/></w:num>
          <w:num w:numId="6"><w:abstractNumId w:val="3"/></w:num>
        XML
      end

      def lines(*items) = word(items.map { |text, *properties| paragraph(text, list(*properties)) }.join, numbering:)

      it 'marks bullets and nests them by level' do
        expect(lines(['One', 1], ['Under', 1, 1], ['Two', 1])).to eq("- One\n  - Under\n- Two")
      end

      it 'counts a numbered list, and starts where the level says' do
        expect(lines(['A', 2], ['B', 2], ['C', 2])).to eq("1. A\n2. B\n3. C")
        expect(lines(['A', 5], ['B', 5])).to eq("5. A\n6. B")
      end

      it 'restarts a level after a shallower one, and carries on the shallower count' do
        expect(lines(['A', 2], ['a', 2, 1], ['b', 2, 1], ['B', 2], ['c', 2, 1]))
          .to eq("1. A\n  1. a\n  2. b\n2. B\n  1. c")
      end

      it 'continues across lists that share a definition, and restarts where one overrides the start' do
        expect(lines(['A', 2], ['B', 3])).to eq("1. A\n2. B")
        expect(lines(['A', 2], ['B', 4], ['C', 4])).to eq("1. A\n1. B\n2. C")
      end

      it 'keeps counting through text between the items' do
        body = paragraph('A', list(2)) + paragraph('Between') + paragraph('B', list(2))

        expect(word(body, numbering:)).to eq("1. A\nBetween\n2. B")
      end

      it 'counts an empty item without a line for it' do
        body = "#{paragraph('A', list(2))}<w:p><w:pPr>#{list(2)}</w:pPr></w:p>#{paragraph('B', list(2))}"

        expect(word(body, numbering:)).to eq("1. A\n3. B")
      end

      it 'marks nothing for no list, a level that shows no number, or an unknown list' do
        expect(lines(['A', 0])).to eq('A')
        expect(lines(['A', 6])).to eq('A')
        expect(lines(['A', 99])).to eq('A')
        expect(lines(['A', 1, 7])).to eq('A')
      end

      it 'reads a list a style gives, and lets the paragraph turn it off' do
        styles = '<w:style w:type="paragraph" w:styleId="LB"><w:pPr><w:numPr><w:numId w:val="1"/></w:numPr>' \
                 '</w:pPr></w:style>'
        body = paragraph('A', style('LB')) + paragraph('B', style('LB') + list(0))

        expect(word(body, styles:, numbering:)).to eq("- A\nB")
      end

      it 'leaves out markers in a table cell, while the count goes on' do
        cell = "<w:tbl><w:tr><w:tc>#{paragraph('In', list(2))}</w:tc></w:tr></w:tbl>"

        expect(word(paragraph('A', list(2)) + cell + paragraph('B', list(2)), numbering:)).to eq("1. A\nIn\n3. B")
      end

      it 'bounds nesting at the levels the format has' do
        deep = '<w:abstractNum w:abstractNumId="0"><w:lvl w:ilvl="999999999"><w:numFmt w:val="bullet"/></w:lvl>' \
               '</w:abstractNum><w:num w:numId="1"><w:abstractNumId w:val="0"/></w:num>'

        expect(word(paragraph('A', list(1, 999_999_999)), numbering: deep)).to eq('A')
      end

      it 'reads plain lines without numbering, and with broken numbering' do
        expect(word(paragraph('A', list(1)))).to eq('A')
        expect(word(paragraph('A', list(1)), numbering: '<w:abstractNum')).to eq('A')
      end

      it 'marks a text box paragraph once, ahead of the text before the box' do
        box = "<w:txbxContent>#{paragraph('Box')}</w:txbxContent>"
        body = "<w:p><w:pPr>#{list(1)}</w:pPr>#{run('<w:t>Before</w:t>')}#{run(box)}#{run('<w:t>After</w:t>')}</w:p>"

        expect(word(body, numbering:)).to eq("- Before\nBox\nAfter")
      end
    end

    it 'leaves structure out of a PowerPoint slide' do
      slide = '<p:sld><p:sp><p:txBody><a:p><a:pPr lvl="1"><a:buChar char="x"/></a:pPr><a:r><a:t>Point</a:t></a:r>' \
              '</a:p></p:txBody></p:sp></p:sld>'

      expect(text_of(zip_of({ 'ppt/slides/slide1.xml' => slide }), 'a.pptx')).to eq("## Slide 1\n\nPoint")
    end

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
