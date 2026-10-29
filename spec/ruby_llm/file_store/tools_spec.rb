# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::FileStore::Tools do
  include_context 'with configured RubyLLM'

  let(:sheet) { 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' }
  let(:chat) do
    RubyLLM.context do |config|
      config.file_converters[sheet] = ->(_file) { "## Sheet\n\nlabel\tvalue\nspreadsheet_code\tORCHID-97" }
    end.chat(model: model_for(:openai), provider: :openai).with_file_store
  end
  let(:files) { chat.file_store }

  def call(name, **arguments)
    chat.tools[name].call(**arguments)
  end

  def fixture(name)
    File.binread(File.expand_path("../../fixtures/#{name}", __dir__))
  end

  it 'gives the model five tools that send their results whole' do
    expect(chat.tools.keys).to eq(%i[list_files read_file search_files write_file edit_file])
    expect(chat.tools.values.map(&:spill_to_file)).to all(be(false))
    expect(chat.tools.values.map(&:description)).to all(include("chat's file"))
  end

  describe 'list_files' do
    it 'lists every file, or a folder, with sizes and types' do
      files.write('notes.md', 'hello')
      files.write('docs/a.csv', "a,b\n")

      expect(call(:list_files)).to eq("docs/a.csv\t4 bytes\ttext/csv\nnotes.md\t5 bytes\ttext/markdown")
      expect(call(:list_files, path: 'docs')).to eq("docs/a.csv\t4 bytes\ttext/csv")
      expect(call(:list_files, path: '/')).to include('notes.md')
    end

    it 'says when there is nothing to list' do
      expect(call(:list_files)).to eq('There are no files yet.')
      expect(call(:list_files, path: 'empty')).to eq('There are no files in empty.')
    end

    it 'stops after its limit' do
      stub_const('RubyLLM::FileStore::Tools::List::MAX_FILES', 2)
      3.times { |index| files.write("#{index}.txt", 'x') }

      expect(call(:list_files).lines.last).to eq('[1 more files. List a folder to see them.]')
    end
  end

  describe 'read_file' do
    let(:text) { (1..30).map { |number| "line #{number}" }.join("\n") }

    before { files.write('log.txt', text) }

    it 'reads text with line numbers' do
      result = call(:read_file, path: 'log.txt', offset: 3, limit: 2)

      expect(result).to eq("log.txt, lines 3-4 of 30:\n     3\tline 3\n     4\tline 4\n" \
                           '[26 more lines. Continue with offset 5.]')
    end

    it 'reads from the first line by default' do
      expect(call(:read_file, path: 'log.txt').lines.first).to eq("log.txt, lines 1-30 of 30:\n")
    end

    it 'reads by characters' do
      expect(call(:read_file, path: 'log.txt', offset: 5, limit: 3, unit: 'characters'))
        .to eq("log.txt, characters 5-8 of #{text.size}:\n1\nl\n" \
               "[#{text.size - 8} more characters. Continue with offset 8.]")
    end

    it 'cuts long lines and caps what one read returns' do
      stub_const('RubyLLM::FileStore::Tools::Read::MAX_LINE', 5)
      stub_const('RubyLLM::FileStore::Tools::Read::MAX_CHARACTERS', 12)
      files.write('wide.txt', "abcdefghij\nsecond\nthird")

      result = call(:read_file, path: 'wide.txt')
      expect(result).to include('abcde [line cut: 5 more characters, read them with unit characters]')
      expect(result).to end_with('[2 more lines. Continue with offset 2.]')
    end

    it 'reads the text a converter makes, with the type it came from' do
      files.write('sheet.xlsx', fixture('sample.xlsx'))

      expect(call(:read_file, path: 'sheet.xlsx'))
        .to start_with("sheet.xlsx (text read from #{sheet}), lines 1-4 of 4:\n     1\t## Sheet")
    end

    it 'returns an image as an attachment' do
      files.write('logo.png', fixture('ruby.png'))

      text, attachment = call(:read_file, path: 'logo.png')
      expect(text).to start_with('logo.png (image/png,')
      expect(attachment).to have_attributes(filename: 'logo.png', mime_type: 'image/png')
    end

    it 'returns extensionless directory media as attachments after reopening the store' do
      Dir.mktmpdir('ruby_llm-files') do |root|
        store = RubyLLM::FileStore::Directory.new(root)
        store.write('logo', fixture('ruby.png'))
        store.write('scan', fixture('sample.pdf'))
        chat.with_file_store(RubyLLM::FileStore::Directory.new(root))

        expect(call(:read_file, path: 'logo').last).to have_attributes(mime_type: 'image/png')
        expect(call(:read_file, path: 'scan').last).to have_attributes(mime_type: 'application/pdf')
      end
    end

    it 'returns a PDF it cannot read as an attachment' do
      files.write('scan.pdf', fixture('sample.pdf'))

      expect(call(:read_file, path: 'scan.pdf').last).to have_attributes(mime_type: 'application/pdf')
    end

    it 'explains what it cannot read' do
      files.write('song.mp3', fixture('ruby.mp3'))

      expect(call(:read_file, path: 'song.mp3')).to eq(error: 'song.mp3 is audio/mpeg and has no text to read. ' \
                                                              'Work with it in code if you can run code, or describe ' \
                                                              'it from its name.')
    end

    it 'says when a file is empty' do
      files.write('empty.txt', '')

      expect(call(:read_file, path: 'empty.txt')).to eq('empty.txt is empty.')
    end

    it 'reports missing files, folders, bad paths, offsets, and units' do
      files.write('docs/a.md', 'a')

      expect(call(:read_file,
                  path: 'nope.txt')[:error]).to eq('There is no file at nope.txt. List the files with list_files.')
      expect(call(:read_file, path: 'docs')[:error]).to include('docs is a folder')
      expect(call(:read_file, path: '../x')[:error]).to include('not a path inside')
      expect(call(:read_file, path: 'log.txt', offset: 99)[:error]).to include('offset 99 is past the end')
      expect(call(:read_file, path: 'log.txt', unit: 'bytes')[:error]).to include('unit is lines or characters')
    end
  end

  describe 'search_files' do
    before do
      files.write('a.md', "Alpha\nthe ORCHID line\nomega")
      files.write('sub/sheet.xlsx', fixture('sample.xlsx'))
      files.write('logo.png', fixture('ruby.png'))
    end

    it 'finds lines in text and converted files, ignoring case' do
      expect(call(:search_files, query: 'orchid')).to eq(
        "a.md:2: the ORCHID line\nsub/sheet.xlsx:4: spreadsheet_code\tORCHID-97\n[Not searched, no text: logo.png]"
      )
    end

    it 'takes a regular expression, and plain words when it is not one' do
      expect(call(:search_files, query: '^al.ha$')).to start_with('a.md:1: Alpha')
      expect(call(:search_files, query: 'ORCHID (')).to eq('No lines match ORCHID (.' \
                                                           "\n[Not searched, no text: logo.png]")
    end

    it 'searches one file or folder' do
      expect(call(:search_files, query: 'orchid', path: 'sub')).to eq("sub/sheet.xlsx:4: spreadsheet_code\tORCHID-97")
      expect(call(:search_files, query: 'orchid', path: 'a.md')).to eq('a.md:2: the ORCHID line')
      expect(call(:search_files, query: 'orchid', path: '/')).to eq(call(:search_files, query: 'orchid'))
      expect(call(:search_files, query: 'orchid', path: '.')).to eq(call(:search_files, query: 'orchid'))
      expect(call(:search_files, query: 'x', path: 'missing')[:error]).to eq('There is no file or folder at missing.')
    end

    it 'stops after its limit' do
      stub_const('RubyLLM::FileStore::Tools::Search::MAX_MATCHES', 1)

      expect(call(:search_files, query: 'a').lines.last).to start_with('[More than 1 matches.')
    end

    it 'refuses an empty query and a regular expression that runs too long' do
      expect(call(:search_files, query: ' ')[:error]).to eq('query is empty.')
      allow(Regexp).to receive(:new).and_return(Regexp.new('a'))
      allow_any_instance_of(Regexp).to receive(:match?).and_raise(Regexp::TimeoutError) # rubocop:disable RSpec/AnyInstance

      expect(call(:search_files, query: '(a+)+$')[:error]).to include('took too long')
    end
  end

  describe 'write_file and edit_file' do
    it 'writes a text file and tells the chat' do
      written = []
      chat.after_file_write { |file| written << file.path }

      expect(call(:write_file, path: 'notes/plan.md', content: '# Plan')).to eq('Wrote notes/plan.md (6 bytes).')
      expect(files.read('notes/plan.md')).to eq('# Plan')
      expect(written).to eq(['notes/plan.md'])
    end

    it 'replaces one exact span' do
      files.write('plan.md', "one two\nthree two")

      expect(call(:edit_file, path: 'plan.md', old_text: 'three', new_text: 'four'))
        .to eq('Replaced 1 occurrence in plan.md.')
      expect(files.read('plan.md')).to eq("one two\nfour two")
    end

    it 'refuses a span that is missing or not unique, unless replacing all' do
      files.write('plan.md', 'two \\1 two')

      expect(call(:edit_file, path: 'plan.md', old_text: 'six', new_text: 'x')[:error]).to include('does not appear')
      expect(call(:edit_file, path: 'plan.md', old_text: '', new_text: 'x')[:error]).to include('does not appear')
      expect(call(:edit_file, path: 'plan.md', old_text: 'two', new_text: 'x')[:error]).to include('appears 2 times')
      expect(call(:edit_file, path: 'plan.md', old_text: 'two', new_text: '\\0', replace_all: true))
        .to eq('Replaced 2 occurrences in plan.md.')
      expect(files.read('plan.md')).to eq('\\0 \\1 \\0')
    end

    it 'refuses binary files and missing ones' do
      files.write('logo.png', fixture('ruby.png'))

      expect(call(:edit_file, path: 'logo.png', old_text: 'PNG', new_text: 'x')[:error]).to include('not a text file')
      expect(call(:edit_file, path: 'missing.md', old_text: 'a', new_text: 'b')[:error]).to include('There is no file')
    end
  end

  describe 'a full store' do
    it 'answers write_file and edit_file with the reason, and keeps the file as it was' do
      files.write('notes.md', 'hello')
      allow(files).to receive(:write).and_raise(RubyLLM::FileStoreFullError, 'The files are full: delete some.')

      expect(call(:write_file, path: 'big.txt', content: 'x')).to eq(error: 'The files are full: delete some.')
      expect(call(:edit_file, path: 'notes.md', old_text: 'hello', new_text: 'bye'))
        .to eq(error: 'The files are full: delete some.')
      expect(files.read('notes.md')).to eq('hello')
      expect(files.exists?('big.txt')).to be(false)
    end
  end
end
