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
    expect(chat.tools.values.map(&:inline_limit)).to all(be(false))
  end

  it 'tells the model to read only the lines around a match' do
    expect(chat.tools[:read_file].description)
      .to include('After search_files, read just the lines around a match with offset and limit.')
  end

  it 'keeps each tool description short' do
    expect(chat.with_file_store(tools: %i[read write edit delete]).tools.values.map(&:description))
      .to all(satisfy { |description| description.length <= 400 })
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

      expect(call(:list_files).lines.last).to eq('[1 more files. Narrow the list with path or pattern.]')
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
      call(:read_file, path: 'sub/sheet.xlsx')

      expect(call(:search_files, query: 'orchid')).to eq(
        "a.md:2: the ORCHID line\nsub/sheet.xlsx:4: spreadsheet_code\tORCHID-97\n[Not searched, no text: logo.png]"
      )
    end

    it 'never converts a file to search it, and names the files it skipped for that' do
      ocr = ->(_file) { raise 'search must not run a converter' }
      chat.context.config.file_converters['image/png'] = ocr

      expect(call(:search_files, query: 'orchid')).to eq(
        "a.md:2: the ORCHID line\n[Not searched, text not extracted yet: logo.png, sub/sheet.xlsx. " \
        'Read a file with read_file to extract its text first.]'
      )
    end

    it 'reads text files as they are, without their converters or the conversion cache' do
      chat.context.config.file_converters['text/markdown'] = ->(_file) { raise 'search must not run a converter' }
      allow(files).to receive(:cache_text).and_call_original

      expect(call(:search_files, query: 'orchid', path: 'a.md')).to eq('a.md:2: the ORCHID line')
      expect(files).not_to have_received(:cache_text)
    end

    it 'searches the converted text of a text file once read_file converted it, with its line numbers' do
      chat.context.config.file_converters['text/markdown'] = ->(_file) { "Converted\nORCHID converted" }
      call(:read_file, path: 'a.md')

      expect(call(:search_files, query: 'orchid', path: 'a.md')).to eq('a.md:2: ORCHID converted')
    end

    it 'takes a regular expression, and plain words when it is not one' do
      call(:read_file, path: 'sub/sheet.xlsx')
      expect(call(:search_files, query: '^al.ha$')).to start_with('a.md:1: Alpha')
      expect(call(:search_files, query: 'ORCHID (')).to eq('No lines match ORCHID (.' \
                                                           "\n[Not searched, no text: logo.png]")
    end

    it 'searches one file or folder' do
      call(:read_file, path: 'sub/sheet.xlsx')
      expect(call(:search_files, query: 'orchid', path: 'sub')).to eq("sub/sheet.xlsx:4: spreadsheet_code\tORCHID-97")
      expect(call(:search_files, query: 'orchid', path: 'a.md')).to eq('a.md:2: the ORCHID line')
      expect(call(:search_files, query: 'orchid', path: '/')).to eq(call(:search_files, query: 'orchid'))
      expect(call(:search_files, query: 'orchid', path: '.')).to eq(call(:search_files, query: 'orchid'))
      expect(call(:search_files, query: 'x', path: 'missing')[:error]).to eq('There is no file or folder at missing.')
    end

    it 'stops after its limit' do
      stub_const('RubyLLM::FileStore::Tools::Search::MAX_MATCHES', 1)

      expect(call(:search_files, query: 'a').lines.last).to eq('[More matches. Narrow the query, path, or glob.]')
    end

    it 'refuses an empty query and a regular expression that runs too long' do
      expect(call(:search_files, query: ' ')[:error]).to eq('query is empty.')
      allow(Regexp).to receive(:new).and_return(Regexp.new('a'))
      allow_any_instance_of(Regexp).to receive(:match?).and_raise(Regexp::TimeoutError) # rubocop:disable RSpec/AnyInstance

      expect(call(:search_files, query: '(a+)+$')[:error]).to include('took too long')
    end
  end

  describe 'write_file and edit_file' do
    it 'answers write_file with the reason when the path is a folder' do
      root = Dir.mktmpdir('ruby_llm-store')
      chat.with_file_store(RubyLLM::FileStore::Directory.new(root))
      files.write('reports/q3.md', 'x')

      expect(call(:write_file, path: 'reports', content: 'oops')).to eq(error: 'reports is a folder, not a file')
      expect(files.read('reports/q3.md')).to eq('x')
    ensure
      FileUtils.rm_rf(root)
    end

    it 'writes a text file and tells the chat' do
      written = []
      chat.after_file_write { |file| written << file.path }

      expect(call(:write_file, path: 'notes/plan.md', content: '# Plan')).to eq('Wrote notes/plan.md (6 bytes).')
      expect(files.read('notes/plan.md')).to eq('# Plan')
      expect(written).to eq(['notes/plan.md'])
    end

    [ArgumentError, Errno::EACCES].each do |error|
      it "lets #{error} from an after_file_write callback through write_file" do
        chat.after_file_write { raise error }

        expect { call(:write_file, path: 'plan.md', content: '# Plan') }.to raise_error(error)
        expect(files.read('plan.md')).to eq('# Plan')
      end

      it "lets #{error} from an after_file_write callback through edit_file" do
        files.write('plan.md', 'one')
        call(:read_file, path: 'plan.md')
        chat.after_file_write { raise error }

        expect { call(:edit_file, path: 'plan.md', old_text: 'one', new_text: 'two') }.to raise_error(error)
        expect(files.read('plan.md')).to eq('two')
      end
    end

    it 'skips the after_file_write callback when the write fails' do
      written = []
      chat.after_file_write { |file| written << file.path }
      allow(files).to receive(:write).and_raise(Errno::EACCES)

      expect(call(:write_file, path: 'plan.md', content: '# Plan')[:error]).to eq('Permission denied')
      expect(written).to be_empty
    end

    it 'replaces one exact span' do
      files.write('plan.md', "one two\nthree two")
      call(:read_file, path: 'plan.md')

      expect(call(:edit_file, path: 'plan.md', old_text: 'three', new_text: 'four'))
        .to eq('Replaced 1 occurrence in plan.md.')
      expect(files.read('plan.md')).to eq("one two\nfour two")
    end

    it 'refuses a span that is missing or not unique, unless replacing all' do
      files.write('plan.md', 'two \\1 two')
      call(:read_file, path: 'plan.md')

      expect(call(:edit_file, path: 'plan.md', old_text: 'six', new_text: 'x')[:error]).to include('does not appear')
      expect(call(:edit_file, path: 'plan.md', old_text: '', new_text: 'x')[:error]).to include('does not appear')
      expect(call(:edit_file, path: 'plan.md', old_text: 'two', new_text: 'x')[:error]).to include('appears 2 times')
      expect(call(:edit_file, path: 'plan.md', old_text: 'two', new_text: '\\0', replace_all: true))
        .to eq('Replaced 2 occurrences in plan.md.')
      expect(files.read('plan.md')).to eq('\\0 \\1 \\0')
    end

    it 'refuses binary files and missing ones' do
      files.write('logo.png', fixture('ruby.png'))
      call(:read_file, path: 'logo.png')

      expect(call(:edit_file, path: 'logo.png', old_text: 'PNG', new_text: 'x')[:error]).to include('not a text file')
      expect(call(:edit_file, path: 'missing.md', old_text: 'a', new_text: 'b')[:error]).to include('There is no file')
    end
  end

  describe 'reading before changing' do
    it 'refuses to edit or overwrite a file the model has not read' do
      files.write('notes/plan.md', 'one')

      expect(call(:edit_file, path: 'notes/plan.md', old_text: 'one', new_text: 'two'))
        .to eq(error: 'Read notes/plan.md before you change it.')
      expect(call(:write_file, path: 'notes/plan.md', content: 'two'))
        .to eq(error: 'Read notes/plan.md before you change it.')
      expect(files.read('notes/plan.md')).to eq('one')
    end

    it 'refuses to change a file that changed since the model read it' do
      files.write('notes/plan.md', 'one')
      call(:read_file, path: 'notes/plan.md', limit: 1)
      files.write('notes/plan.md', 'theirs')

      expect(call(:edit_file, path: 'notes/plan.md', old_text: 'theirs', new_text: 'mine'))
        .to eq(error: 'notes/plan.md changed since you read it. Read it again.')
      expect(call(:write_file, path: 'notes/plan.md', content: 'mine'))
        .to eq(error: 'notes/plan.md changed since you read it. Read it again.')

      call(:read_file, path: 'notes/plan.md')
      expect(call(:edit_file, path: 'notes/plan.md', old_text: 'theirs', new_text: 'mine'))
        .to eq('Replaced 1 occurrence in notes/plan.md.')
    end

    it 'counts only a read that returned the file' do
      files.write('notes/plan.md', "one\n")

      expect(call(:read_file, path: 'notes/plan.md', offset: 9)).to have_key(:error)
      expect(call(:read_file, path: 'notes/plan.md', unit: 'bytes')).to have_key(:error)
      expect(call(:write_file, path: 'notes/plan.md', content: 'two'))
        .to eq(error: 'Read notes/plan.md before you change it.')
    end

    it 'creates a new file without a read, and keeps changing what it wrote' do
      expect(call(:write_file, path: 'plan.md', content: 'one')).to eq('Wrote plan.md (3 bytes).')
      expect(call(:edit_file, path: 'plan.md', old_text: 'one', new_text: 'two')).to start_with('Replaced 1')
      expect(call(:edit_file, path: 'plan.md', old_text: 'two', new_text: 'three')).to start_with('Replaced 1')
      expect(call(:write_file, path: 'plan.md', content: 'four')).to eq('Wrote plan.md (4 bytes).')
    end

    it 'applies concurrent edits of one file one after the other' do
      files.write('plan.md', "a\nb\n")
      call(:read_file, path: 'plan.md')
      allow(files).to receive(:read).and_wrap_original do |original, *arguments|
        original.call(*arguments).tap { sleep 0.05 }
      end

      edits = [%w[a A], %w[b B]].map do |old_text, new_text|
        Thread.new { call(:edit_file, path: 'plan.md', old_text:, new_text:) }
      end

      expect(edits.map(&:value)).to all(start_with('Replaced 1'))
      expect(files.read('plan.md')).to eq("A\nB\n")
    end

    it 'remembers reads in a folder store for as long as the store lives' do
      Dir.mktmpdir('ruby_llm-files') do |root|
        chat.with_file_store(root)
        files.write('plan.md', 'one')
        call(:read_file, path: 'plan.md')
        File.write(File.join(root, 'plan.md'), 'changed on disk')

        expect(call(:edit_file, path: 'plan.md', old_text: 'changed', new_text: 'x'))
          .to eq(error: 'plan.md changed since you read it. Read it again.')
      end
    end
  end

  describe 'search_files options' do
    before do
      files.write('notes/a.md', "Alpha\nthe ORCHID line\nomega")
      files.write('notes/b.md', "orchid\nmore orchid")
      files.write('notes/c.txt', 'orchid in text')
      files.write('log.txt', (1..9).map { |number| "line #{number}" }.join("\n"))
    end

    it 'searches the files a glob matches, by name anywhere or by path' do
      expect(call(:search_files, query: 'orchid', glob: '*.md'))
        .to eq("notes/a.md:2: the ORCHID line\nnotes/b.md:1: orchid\nnotes/b.md:2: more orchid")
      expect(call(:search_files, query: 'orchid', glob: 'notes/*.txt')).to eq('notes/c.txt:1: orchid in text')
      expect(call(:search_files, query: 'orchid', path: 'notes', glob: '*.{txt,csv}'))
        .to eq('notes/c.txt:1: orchid in text')
      expect(call(:search_files, query: 'orchid', glob: '*.pdf')).to eq('No files match *.pdf.')
    end

    it 'shows context lines around each match, merging close ones' do
      expect(call(:search_files, query: 'line [28]', path: 'log.txt', context: 1)).to eq(
        "log.txt-1- line 1\nlog.txt:2: line 2\nlog.txt-3- line 3\n--\n" \
        "log.txt-7- line 7\nlog.txt:8: line 8\nlog.txt-9- line 9"
      )
      expect(call(:search_files, query: 'line [45]', path: 'log.txt', context: 1))
        .to eq("log.txt-3- line 3\nlog.txt:4: line 4\nlog.txt:5: line 5\nlog.txt-6- line 6")
    end

    it 'caps the context it shows' do
      stub_const('RubyLLM::FileStore::Tools::Search::MAX_CONTEXT', 1)

      expect(call(:search_files, query: 'line 5', path: 'log.txt', context: 50).lines.size).to eq(3)
    end

    it 'matches case when asked' do
      expect(call(:search_files, query: 'orchid', path: 'notes/a.md', case_sensitive: true))
        .to eq('No lines match orchid.')
      expect(call(:search_files, query: 'ORCHID', path: 'notes/a.md', case_sensitive: true))
        .to eq('notes/a.md:2: the ORCHID line')
    end

    it 'names only the files that match with files_only' do
      expect(call(:search_files, query: 'orchid', path: 'notes', files_only: true))
        .to eq("notes/a.md\nnotes/b.md\nnotes/c.txt")
    end

    it 'keeps its output short' do
      stub_const('RubyLLM::FileStore::Tools::Search::MAX_CHARACTERS', 40)

      expect(call(:search_files, query: 'orchid', glob: '*.md'))
        .to eq("notes/a.md:2: the ORCHID line\n[More matches. Narrow the query, path, or glob.]")
    end

    it 'stops a search that runs too long' do
      stub_const('RubyLLM::FileStore::Tools::Search::MAX_SECONDS', 0)

      expect(call(:search_files, query: 'orchid')).to end_with('[The search took too long and stopped. Narrow ' \
                                                               'it with path or glob.]')
    end
  end

  describe 'list_files with a pattern' do
    before do
      %w[reports/2026/q3.csv reports/q2.csv reports/notes.md top.csv].each { |path| files.write(path, 'x') }
    end

    def paths(**arguments)
      call(:list_files, **arguments).lines.map { |line| line.split("\t").first.chomp }
    end

    it 'finds files by a glob, by name anywhere or by path inside the folder' do
      expect(paths(pattern: 'reports/**/*.csv')).to eq(%w[reports/2026/q3.csv reports/q2.csv])
      expect(paths(pattern: '*.csv')).to eq(%w[reports/2026/q3.csv reports/q2.csv top.csv])
      expect(paths(path: 'reports', pattern: '*.csv')).to eq(%w[reports/2026/q3.csv reports/q2.csv])
      expect(paths(path: 'reports', pattern: '2026/*')).to eq(%w[reports/2026/q3.csv])
    end

    it 'matches a whole path inside the folder too, and everything under a folder with a trailing **' do
      expect(paths(path: 'reports', pattern: 'reports/2026/*.csv')).to eq(%w[reports/2026/q3.csv])
      expect(paths(pattern: 'reports/**')).to eq(%w[reports/2026/q3.csv reports/notes.md reports/q2.csv])
    end

    it 'says when nothing matches' do
      expect(call(:list_files, pattern: '**/*.pdf')).to eq('No files match **/*.pdf.')
      expect(call(:list_files, path: 'reports', pattern: '*.pdf')).to eq('No files in reports match *.pdf.')
    end
  end

  describe 'delete_file' do
    let(:chat) do
      RubyLLM.chat(model: model_for(:openai), provider: :openai).with_file_store(tools: %i[read write edit delete])
    end

    it 'deletes one file' do
      files.write('old.md', 'x')

      expect(call(:delete_file, path: 'old.md')).to eq('Deleted old.md.')
      expect(files.exist?('old.md')).to be(false)
    end

    it 'refuses a folder and a missing file' do
      files.write('reports/q3.md', 'x')

      expect(call(:delete_file, path: 'reports')[:error]).to eq('reports is a folder. Delete its files one by one.')
      expect(call(:delete_file, path: 'nope.md')[:error])
        .to eq('There is no file at nope.md. List the files with list_files.')
      expect(files.exist?('reports/q3.md')).to be(true)
    end
  end

  describe 'on a folder store' do
    let(:root) { Dir.mktmpdir }
    let(:chat) do
      RubyLLM.chat(model: model_for(:openai), provider: :openai).with_file_store(RubyLLM::FileStore::Directory.new(root))
    end

    after { FileUtils.remove_entry(root) }

    it 'answers the model when it reaches for a hidden path' do
      expect(call(:read_file, path: '.gitignore')[:error]).to eq(".gitignore is not inside the chat's files")
      expect(call(:write_file, path: '.notes', content: 'x')[:error]).to eq(".notes is not inside the chat's files")
      expect(call(:list_files, path: '.git')[:error]).to eq(".git is not inside the chat's files")
      expect(call(:search_files, query: 'x', path: '.git')[:error]).to eq(".git is not inside the chat's files")
      expect(call(:edit_file, path: '.notes', old_text: 'a',
                              new_text: 'b')[:error]).to eq(".notes is not inside the chat's files")
    end

    it 'answers a write the file system refuses, without naming the folder on the host' do
      expect(call(:write_file, path: "#{'a' * 300}.md", content: 'x')[:error]).to eq('File name too long')
    end
  end

  describe 'a full store' do
    it 'answers write_file and edit_file with the reason, and keeps the file as it was' do
      files.write('notes.md', 'hello')
      call(:read_file, path: 'notes.md')
      allow(files).to receive(:write).and_raise(RubyLLM::FileStoreFullError, 'The files are full: delete some.')

      expect(call(:write_file, path: 'big.txt', content: 'x')).to eq(error: 'The files are full: delete some.')
      expect(call(:edit_file, path: 'notes.md', old_text: 'hello', new_text: 'bye'))
        .to eq(error: 'The files are full: delete some.')
      expect(files.read('notes.md')).to eq('hello')
      expect(files.exist?('big.txt')).to be(false)
    end
  end
end
