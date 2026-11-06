# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Chat do
  include_context 'with configured RubyLLM'

  let(:chat) { described_class.new(model: model_for(:openai), provider: :openai) }
  let(:image_path) { File.expand_path('../fixtures/ruby.png', __dir__) }
  let(:pdf_path) { File.expand_path('../fixtures/sample.pdf', __dir__) }

  class SearchDrive < RubyLLM::Tool # rubocop:disable Lint/ConstantDefinitionInBlock,RSpec/LeakyConstantDeclaration
    description 'Searches the drive'

    def execute(query:)
      "#{query}: #{'result ' * 2_000}"
    end
  end

  class ShortSpill < RubyLLM::Tool # rubocop:disable Lint/ConstantDefinitionInBlock,RSpec/LeakyConstantDeclaration
    description 'Returns sixty characters'
    inline_limit 50

    def execute
      'x' * 60
    end
  end

  class NeverSpill < RubyLLM::Tool # rubocop:disable Lint/ConstantDefinitionInBlock,RSpec/LeakyConstantDeclaration
    description 'Returns a long page'
    inline_limit false

    def execute
      'y' * 20_000
    end
  end

  def answer(content = 'Done')
    RubyLLM::Message.new(role: :assistant, content:, model: model_for(:openai), input_tokens: 1, output_tokens: 1)
  end

  def calls(name, arguments = {}, id: 'call_1')
    RubyLLM::Message.new(role: :assistant, content: '',
                         tool_calls: { id => RubyLLM::ToolCall.new(id:, name:, arguments:) })
  end

  def requests
    @requests ||= []
  end

  def respond_with(*responses)
    allow(chat.provider).to receive(:complete) do |messages, **|
      requests << messages
      responses.shift
    end
  end

  def request_view
    chat.send(:preprocessed_messages)
  end

  def tool_result(tool_call, result)
    chat.send(:add_tool_result_message, tool_call, result)
  end

  describe '#with_file_store' do
    it 'gives the chat a store in memory and five tools' do
      expect(chat.with_file_store).to be(chat)
      expect(chat.file_store).to be_a(RubyLLM::FileStore::Memory)
      expect(chat.tools.keys).to include(:list_files, :read_file, :search_files, :write_file, :edit_file)
    end

    it 'takes a store and an inline_limit' do
      store = RubyLLM::FileStore::Memory.new

      expect(chat.with_file_store(store).file_store).to be(store)
      expect(chat.with_file_store(store, inline_limit: 20).file_store).to be(store)
      expect(chat.instance_variable_get(:@file_references).inline_limit).to eq(20)
    end

    it 'keeps files in the folder at a path' do
      root = Dir.mktmpdir('ruby_llm-chat-files')
      folder = File.join(root, 'chats', '42')

      expect(chat.with_file_store(folder).file_store).to be_a(RubyLLM::FileStore::Directory)
      expect(chat.file_store.root).to eq(File.realpath(folder))
      expect(chat.with_file_store(Pathname(folder)).file_store.root).to eq(File.realpath(folder))
    ensure
      FileUtils.rm_rf(root)
    end

    it 'takes a new store in memory with :memory' do
      first = chat.with_file_store(:memory).file_store

      expect(first).to be_a(RubyLLM::FileStore::Memory)
      expect(chat.with_file_store(:memory).file_store).not_to be(first)
    end

    it 'keeps the inline_limit with a path or :memory' do
      chat.with_file_store(:memory, inline_limit: 20)

      expect(chat.instance_variable_get(:@file_references).inline_limit).to eq(20)
    end

    it 'gives the model the tools named with tools:' do
      read = %i[list_files read_file search_files]

      expect(chat.with_file_store(tools: :read).tools.keys).to eq(read)
      expect(chat.with_file_store(tools: %i[read write edit delete]).tools.keys)
        .to eq([*read, :write_file, :edit_file, :delete_file])
      expect(chat.with_file_store(tools: %w[read edit]).tools.keys).to eq([*read, :edit_file])
      expect(chat.with_file_store.tools.keys).to eq([*read, :write_file, :edit_file])
    end

    it 'keeps the tools it was given when the chat is copied' do
      expect(chat.with_file_store(tools: :read).dup.tools.keys).to eq(%i[list_files read_file search_files])
    end

    it 'refuses tools it does not know, and tools without reading' do
      expect { chat.with_file_store(tools: :rename) }
        .to raise_error(ArgumentError, 'tools: takes :read, :write, :edit, and :delete, got :rename')
      [%i[write edit], [], :delete].each do |tools|
        expect { chat.with_file_store(tools:) }
          .to raise_error(ArgumentError, 'tools: needs :read, since the model reads its files with it')
      end
    end

    it 'removes the store and its tools with nil' do
      chat.with_file_store.with_file_store(nil)

      expect(chat.file_store).to be_nil
      expect(chat.tools.keys).not_to include(:read_file)
    end

    it 'rejects unknown options, bad limits, and stores that are none' do
      expect { chat.with_file_store(quota: 1) }.to raise_error(ArgumentError, /unknown keyword: :quota/)
      expect { chat.with_file_store(inline_limit: 0) }.to raise_error(ArgumentError, /positive number/)
      expect { chat.with_file_store(inline_limit: nil) }.to raise_error(ArgumentError, /positive number/)
      expect { chat.with_file_store(:redis) }.to raise_error(ArgumentError, /takes a folder path.*got :redis/)
      expect { chat.with_file_store(false) }.to raise_error(ArgumentError, /takes a folder path/)
      expect { chat.with_file_store(Object.new) }.to raise_error(ArgumentError, /takes a folder path/)
    end

    it 'refuses a tool of the same name' do
      own = Class.new(RubyLLM::Tool) do
        def self.tool_name = 'read_file'
        def execute = 'mine'
      end
      chat.with_tools(own).with_file_store

      expect { chat.tools }.to raise_error(ArgumentError, /Two tools are named read_file/)
    end

    it 'keeps the store in a copy, which tells its own callbacks' do
      chat.with_file_store
      copy = chat.dup
      written = []
      copy.after_file_write { |file| written << file.path }

      copy.tools[:write_file].call(path: 'a.md', content: 'x')

      expect(copy.file_store).to be(chat.file_store)
      expect(chat.file_store.read('a.md')).to eq('x')
      expect(written).to eq(['a.md'])
    end
  end

  describe 'attachments' do
    before { chat.with_file_store }

    it 'keeps every attachment and shows the latest question its own in full' do
      chat.add_message(role: :user, content: 'What is this?', attachments: [image_path])

      view = request_view
      expect(view.last.attachments.map(&:filename)).to eq(['ruby.png'])
      expect(view.last.attachments.first.mime_type).to eq('image/png')
      expect(chat.file_store.list.map(&:path)).to eq(['ruby.png'])
    end

    it 'turns the attachments of earlier questions into a line naming the file' do
      chat.add_message(role: :user, content: 'What is this?', attachments: [image_path, pdf_path])
      chat.add_message(answer('A logo and a sample.'))
      chat.add_message(role: :user, content: 'And what color is it?')

      earlier = request_view.first
      expect(earlier.content).to eq('What is this?')
      expect(earlier.attachments.map(&:filename)).to eq(%w[ruby.png.txt sample.pdf.txt])
      expect(earlier.attachments.map(&:mime_type)).to all(eq('text/plain'))
      expect(earlier.attachments.first.content).to match(
        %r{\Aruby\.png \(image/png, [\d.]+ KB\) is in this chat's files and not shown here\. Open it with read_file}
      )
      expect(chat.messages.first.attachments.map(&:mime_type)).to eq(%w[image/png application/pdf])
    end

    it 'turns files other tools return into a line at once' do
      tool_call = RubyLLM::ToolCall.new(id: 'call_1', name: 'drive_fetch', arguments: {})
      chat.add_message(role: :user, content: 'Fetch the logo')
      chat.add_message(calls('drive_fetch'))
      tool_result(tool_call, ['Here it is', RubyLLM::Attachment.new(image_path)])

      expect(request_view.last.attachments.first.content).to start_with('ruby.png (image/png,')
      expect(chat.file_store.exist?('ruby.png')).to be(true)
    end

    it 'shows what read_file returns until the next question, without keeping it twice' do
      chat.file_store.write('images/logo.png', File.binread(image_path))
      tool_call = RubyLLM::ToolCall.new(id: 'call_1', name: 'read_file', arguments: { 'path' => 'images/logo.png' })
      chat.add_message(role: :user, content: 'Show me the logo')
      chat.add_message(calls('read_file', { 'path' => 'images/logo.png' }))
      tool_result(tool_call, chat.tools[:read_file].call(path: 'images/logo.png'))

      expect(request_view.last.attachments.first.mime_type).to eq('image/png')

      chat.add_message(answer('It is red.'))
      chat.add_message(role: :user, content: 'Thanks')

      expect(request_view[2].attachments.first.content)
        .to eq('images/logo.png was shown here. Open it again with read_file to see it.')
      expect(chat.file_store.list.map(&:path)).to eq(['images/logo.png'])
    end

    it 'tells after_file_write once about each attachment it keeps' do
      written = []
      chat.after_file_write { |file| written << file.path }
      chat.add_message(role: :user, content: 'Look', attachments: [image_path])

      2.times { request_view }

      expect(written).to eq(['ruby.png'])
    end

    it 'leaves provider files alone' do
      uploaded = RubyLLM::UploadedFile.new(id: 'file_1', filename: 'big.pdf', mime_type: 'application/pdf',
                                           provider: :openai)
      chat.add_message(role: :user, content: 'Read it', attachments: [uploaded])
      chat.add_message(answer)
      chat.add_message(role: :user, content: 'Again')

      expect(request_view.first.attachments.first).to be_provider_file
      expect(chat.file_store.list).to be_empty
    end

    it 'sends an attachment it cannot keep as it is' do
      store = RubyLLM::FileStore::Memory.new
      allow(store).to receive(:store_attachment).and_raise(IOError)
      allow(RubyLLM.logger).to receive(:warn)
      chat.with_file_store(store)
      chat.add_message(role: :user, content: 'Look', attachments: [image_path])
      chat.add_message(answer)
      chat.add_message(role: :user, content: 'Again')

      expect(request_view.first.attachments.first.mime_type).to eq('image/png')
      expect(RubyLLM.logger).to have_received(:warn)
    end
  end

  describe 'an attachment the model saw whole' do
    let(:notes) { RubyLLM::Attachment.new(StringIO.new('one two'), filename: 'notes.txt') }

    def edit(old_text, new_text)
      chat.tools[:edit_file].call(path: 'notes.txt', old_text:, new_text:)
    end

    def ask(attachment = notes)
      respond_with(answer)
      chat.add_message(role: :user, content: 'Look', attachments: [attachment])
      chat.complete
    end

    before { chat.with_file_store }

    it 'sends a long text attachment as its start and says the rest is unseen' do
      long = RubyLLM::Attachment.new(StringIO.new("first line\n#{'x' * 20_000}"), filename: 'long.txt')
      chat.add_message(role: :user, content: 'Summarize', attachments: [long])

      sent = request_view.last.attachments.first.content

      expect(sent).to include('first line', 'you have not seen the rest', 'read_file')
      expect(sent.length).to be < 11_000
      expect(chat.file_store.read('long.txt').length).to be > 20_000
    end

    it 'sends a long text attachment whole with inline_limit: false' do
      chat.with_file_store(:memory, inline_limit: false)
      long = RubyLLM::Attachment.new(StringIO.new('x' * 20_000), filename: 'long.txt')
      chat.add_message(role: :user, content: 'Summarize', attachments: [long])

      expect(request_view.last.attachments.first.content.length).to eq(20_000)
    end

    it 'counts as read once the request went out, so the model edits it at once' do
      ask

      expect(edit('one', 'uno')).to eq('Replaced 1 occurrence in notes.txt.')
      expect(chat.file_store.read('notes.txt')).to eq('uno two')
    end

    it 'does not count past the inline limit, when the model saw only the start' do
      chat.with_file_store(inline_limit: 3)
      ask

      expect(edit('one', 'uno')).to eq(error: 'Read notes.txt before you change it.')
    end

    it 'still refuses once the file changes, on this request and the next' do
      ask
      chat.file_store.write('notes.txt', 'theirs')
      refusal = { error: 'notes.txt changed since you read it. Read it again.' }

      expect(edit('theirs', 'mine')).to eq(refusal)

      respond_with(answer)
      chat.complete
      expect(edit('theirs', 'mine')).to eq(refusal)
    end

    it 'leaves what the model read or wrote later in place on the next request' do
      ask
      edit('one', 'uno')

      respond_with(answer)
      chat.complete

      expect(edit('uno', 'eins')).to start_with('Replaced 1')
    end

    it 'does not count for a request that was only rendered, or that failed' do
      chat.add_message(role: :user, content: 'Look', attachments: [notes])
      chat.render
      refusal = { error: 'Read notes.txt before you change it.' }
      expect(edit('one', 'uno')).to eq(refusal)

      allow(chat.provider).to receive(:complete).and_raise(RubyLLM::Error, 'down')
      expect { chat.complete }.to raise_error(RubyLLM::Error)
      expect(edit('one', 'uno')).to eq(refusal)
    end

    it 'does not count when the provider got something else for it, such as an upload' do
      allow(chat.provider).to receive(:preprocess_messages).and_wrap_original do |original, list, **options|
        original.call(list, **options).map do |message|
          message.with_attachments(message.attachments.map do |item|
            RubyLLM::Attachment.new(StringIO.new('x'), filename: item.filename)
          end)
        end
      end
      ask

      expect(edit('one', 'uno')).to eq(error: 'Read notes.txt before you change it.')
    end

    it 'does not count for a file that is not text' do
      ask(image_path)

      expect(chat.tools[:write_file].call(path: 'ruby.png', content: 'x'))
        .to eq(error: 'Read ruby.png before you change it.')
    end

    it 'does not count converted text for the file it came from' do
      docx = File.expand_path('../fixtures/sample.docx', __dir__)
      chat = RubyLLM.context { |config| config.file_converters = {} }
                    .chat(model: model_for(:anthropic), provider: :anthropic).with_file_store
      allow(chat.provider).to receive(:complete).and_return(answer)
      chat.add_message(role: :user, content: 'Look', attachments: [docx])
      chat.complete

      expect(chat.tools[:write_file].call(path: 'sample.docx', content: 'x'))
        .to eq(error: 'Read sample.docx before you change it.')
    end

    it 'does not count a numbered copy for the file with the same name' do
      chat.file_store.write('notes.txt', 'older')
      ask

      expect(edit('older', 'x')).to eq(error: 'Read notes.txt before you change it.')
      expect(chat.tools[:edit_file].call(path: 'notes-2.txt', old_text: 'one',
                                         new_text: 'uno')).to start_with('Replaced 1')
    end

    it 'tells the model a text attachment is in its files and counts as read' do
      expect(chat.tools[:edit_file].description).to include('A text file attached to the question counts as read')
    end
  end

  describe 'attachments the provider cannot take' do
    let(:chat) { described_class.new(model: model_for(:anthropic), provider: :anthropic) }
    let(:docx) { File.expand_path('../fixtures/sample.docx', __dir__) }

    it 'sends a line naming the file, for the model to read with read_file' do
      broken = RubyLLM::Attachment.new(StringIO.new('not a zip'), filename: 'broken.docx')
      chat.with_file_store
      chat.add_message(role: :user, content: 'What is the codename?', attachments: [broken])

      expect(chat.render.to_json).to include('broken.docx (application/vnd.openxmlformats-officedocument.' \
                                             'wordprocessingml.document, ')
      expect(chat.file_store.exist?('broken.docx')).to be(true)
    end

    def converting_chat(text)
      type = 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
      RubyLLM.context { |config| config.file_converters = { type => ->(_file) { text } } }
             .chat(model: model_for(:anthropic), provider: :anthropic)
             .with_file_store
    end

    it 'sends the text a converter reads, and keeps the file in the chat files' do
      chat = converting_chat('The codename is Bluebird.')
      chat.add_message(role: :user, content: 'What is the codename?', attachments: [docx])

      rendered = chat.render.to_json
      expect(rendered).to include('sample.docx, read as text:', 'The codename is Bluebird.')
      expect(rendered).not_to include('wordprocessingml')
      expect(chat.file_store.exist?('sample.docx')).to be(true)
    end

    it 'prefers a convert_unsupported_attachments handler to the converters' do
      chat = converting_chat('The codename is Bluebird.')
             .convert_unsupported_attachments { RubyLLM::Attachment.new(StringIO.new('Handled'), filename: 'h.txt') }
      chat.add_message(role: :user, content: 'What is the codename?', attachments: [docx])

      rendered = chat.render.to_json
      expect(rendered).to include('Handled')
      expect(rendered).not_to include('Bluebird')
    end

    it 'converts again once the store changes its limit' do
      chat = converting_chat('word ' * 3_000)
      chat.add_message(role: :user, content: 'Summarize', attachments: [docx])
      expect(chat.render.to_json).to include('so only the start is shown')

      chat.with_file_store(chat.file_store, inline_limit: false)

      rendered = chat.render.to_json
      expect(rendered).to include("sample.docx, read as text:\\n\\n#{'word ' * 2_999}word")
      expect(rendered).not_to include('so only the start is shown')
    end

    it 'converts again once the chat moves to a context with a converter' do
      odt = RubyLLM::Attachment.new(StringIO.new('zipped'), filename: 'notes.odt')
      chat = described_class.new(model: model_for(:anthropic), provider: :anthropic).with_file_store
      chat.add_message(role: :user, content: 'What is the codename?', attachments: [odt])
      expect(chat.render.to_json).to include('is in this chat')

      chat.with_context(RubyLLM.context do |config|
        config.file_converters = { odt.mime_type => lambda { |_file|
          'Bluebird'
        } }
      end)

      expect(chat.render.to_json).to include('notes.odt, read as text:')
    end

    it 'keeps what a convert_unsupported_attachments handler made when the store changes' do
      calls = 0
      chat = converting_chat('The codename is Bluebird.').convert_unsupported_attachments do
        calls += 1
        RubyLLM::Attachment.new(StringIO.new('Handled'), filename: 'h.txt')
      end
      chat.add_message(role: :user, content: 'What is the codename?', attachments: [docx])
      chat.render

      chat.with_file_store(chat.file_store, inline_limit: false)
      chat.render

      expect(calls).to eq(1)
    end

    it 'sends the start of a long text and says where the rest is' do
      chat = converting_chat('word ' * 3_000)
      chat.add_message(role: :user, content: 'Summarize', attachments: [docx])

      expect(chat.render.to_json).to include(
        '[sample.docx has 15000 characters, so only the start is shown, and you have not seen the rest. ' \
        'Read more with read_file, or search it with search_files.]'
      )
    end

    it 'extracts the text of a document it keeps, so the model can search it at once' do
      chat.with_file_store
      chat.add_message(role: :user, content: 'What is the codename?', attachments: [docx])
      chat.render

      expect(chat.tools[:search_files].call(query: 'codename'))
        .to start_with('sample.docx:1: RubyLLM document attachment probe. The project codename is BLUE-LANTERN-42.')
    end

    it 'lets a registered converter go first, and extracts nothing ahead of one that may cost money' do
      chat = converting_chat('The codename is Bluebird.')
      chat.add_message(role: :user, content: 'What is the codename?', attachments: [docx])
      chat.render

      expect(chat.file_store.text('sample.docx')).to eq('The codename is Bluebird.')
    end

    it 'leaves converters that cost money, like OCR, for read_file' do
      ocr = ->(_file) { raise 'OCR must wait for read_file' }
      chat = RubyLLM.context { |config| config.file_converters['application/pdf'] = ocr }
                    .chat(model: model_for(:anthropic), provider: :anthropic).with_file_store
      chat.add_message(role: :user, content: 'Summarize', attachments: [pdf_path])
      chat.add_message(answer)
      chat.add_message(role: :user, content: 'Again')
      chat.render

      expect(chat.tools[:search_files].call(query: 'x'))
        .to include('[Not searched, text not extracted yet: sample.pdf. read_file extracts it.]')
    end

    it 'leaves the error in place without files' do
      chat.add_message(role: :user, content: 'What is the codename?', attachments: [docx])

      expect { chat.render }.to raise_error(RubyLLM::UnsupportedAttachmentError)
    end
  end

  describe 'spilling results to files' do
    let(:tool_call) { RubyLLM::ToolCall.new(id: 'call/1', name: 'search_drive', arguments: { 'query' => 'q' }) }

    before { chat.with_tools(SearchDrive, ShortSpill, NeverSpill) }

    it 'saves a long result as a file and sends its start and path' do
      chat.with_file_store
      written = []
      chat.after_file_write { |file| written << file.path }

      message = tool_result(tool_call, SearchDrive.new.call(query: 'q'))

      expect(message.content).to start_with('q: result result')
      expect(message.content).to end_with(
        '[This result has 14003 characters, so only the start is shown. All of it is in ' \
        'results/search_drive-call1.txt: read more with read_file, or search it with search_files.]'
      )
      expect(message.content.length).to be < 2_200
      expect(chat.file_store.read('results/search_drive-call1.txt')).to eq(SearchDrive.new.call(query: 'q'))
      expect(written).to eq(['results/search_drive-call1.txt'])
    end

    it 'saves long JSON pretty printed, so lines can be read and searched' do
      chat.with_file_store(inline_limit: 10)

      tool_result(tool_call, { 'items' => [1, 2] })

      expect(chat.file_store.read('results/search_drive-call1.json')).to eq(%({\n  "items": [\n    1,\n    2\n  ]\n}))
    end

    it 'follows a limit the tool sets, and sends whole what it says never to save' do
      chat.with_file_store
      short = RubyLLM::ToolCall.new(id: 'call_2', name: 'short_spill', arguments: {})
      never = RubyLLM::ToolCall.new(id: 'call_3', name: 'never_spill', arguments: {})

      expect(tool_result(short, 'x' * 60).content).to include('results/short_spill-call2.txt')
      expect(tool_result(never, 'y' * 20_000).content).to eq('y' * 20_000)
    end

    it 'keeps the result whole when the store cannot save it, and names files only with safe characters' do
      failing = RubyLLM::FileStore::Memory.new
      allow(failing).to receive(:write).and_raise(IOError)
      allow(RubyLLM.logger).to receive(:warn)
      chat.with_file_store(failing)
      expect(tool_result(tool_call, 'w' * 20_000).content).to eq('w' * 20_000)

      chat.with_file_store
      odd = RubyLLM::ToolCall.new(id: 'call_4', name: '../odd tool', arguments: {})
      expect(tool_result(odd, 'v' * 20_000).content).to include('results/___odd_tool-call4.txt')
    end

    it 'sends the result whole when the store is full' do
      full = RubyLLM::FileStore::Memory.new
      allow(full).to receive(:write).and_raise(RubyLLM::FileStoreFullError, 'The files are full.')
      allow(RubyLLM.logger).to receive(:warn)
      chat.with_file_store(full)

      expect(tool_result(tool_call, 'w' * 20_000).content).to eq('w' * 20_000)
    end

    it 'sends every result whole with inline_limit: false, or without files' do
      expect(tool_result(tool_call, 'z' * 20_000).content.length).to eq(20_000)

      chat.with_file_store(inline_limit: false)
      expect(tool_result(tool_call, 'z' * 20_000).content.length).to eq(20_000)
    end
  end

  describe 'a conversation' do
    it 'lets the model read an earlier attachment back with read_file' do
      chat.with_file_store
      respond_with(answer('A sample PDF.'), calls('read_file', { 'path' => 'sample.pdf' }),
                   answer('It says Sample PDF.'))

      chat.ask('What is this?', with: pdf_path)
      response = chat.ask('Quote its first line')

      expect(response.content).to eq('It says Sample PDF.')
      expect(requests[0].last.attachments.first.mime_type).to eq('application/pdf')
      expect(requests[1].first.attachments.first.mime_type).to eq('text/plain')
      expect(requests[2].last.content).to start_with('sample.pdf (application/pdf, ')
      expect(requests[2].last.attachments.sole.mime_type).to eq('application/pdf')
    end
  end

  describe 'working with files', :live do
    let(:handbook) do
      (1..400).map { |number| "#{number}. Section #{number} covers office policy number #{number}." }
              .insert(287, '288. The parking garage door code is 4471-KESTREL.').join("\n")
    end

    def tools_called(chat)
      chat.messages.flat_map { |message| (message.tool_calls || {}).values }.map(&:name)
    end

    %i[openai anthropic].each do |provider|
      model = model_for(provider)

      it "#{provider}/#{model} finds one line in a long file" do
        chat = RubyLLM.chat(model:, provider:).with_file_store
        chat.file_store.write('handbook.md', handbook)
        response = chat.ask 'What is the parking garage door code? It is in handbook.md in your files.'

        expect(tools_called(chat)).to include('search_files').or include('read_file')
        expect(response.content).to include('4471-KESTREL')
      end
    end
  end
end
