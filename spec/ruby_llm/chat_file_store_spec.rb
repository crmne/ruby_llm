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
    spill_to_file 50

    def execute
      'x' * 60
    end
  end

  class NeverSpill < RubyLLM::Tool # rubocop:disable Lint/ConstantDefinitionInBlock,RSpec/LeakyConstantDeclaration
    description 'Returns a long page'
    spill_to_file false

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

    it 'takes a store and a spill_to_file limit' do
      store = RubyLLM::FileStore::Memory.new

      expect(chat.with_file_store(store).file_store).to be(store)
      expect(chat.with_file_store(store, spill_to_file: 20).file_store).to be(store)
      expect(chat.instance_variable_get(:@file_references).spill_to_file).to eq(20)
    end

    it 'removes the store and its tools with nil' do
      chat.with_file_store.with_file_store(nil)

      expect(chat.file_store).to be_nil
      expect(chat.tools.keys).not_to include(:read_file)
    end

    it 'rejects unknown options, bad limits, and stores that are none' do
      expect { chat.with_file_store(quota: 1) }.to raise_error(ArgumentError, /unknown keyword: :quota/)
      expect { chat.with_file_store(spill_to_file: 0) }.to raise_error(ArgumentError, /positive number/)
      expect { chat.with_file_store(spill_to_file: nil) }.to raise_error(ArgumentError, /positive number/)
      expect { chat.with_file_store('tmp') }.to raise_error(ArgumentError, /takes a RubyLLM::FileStore or nil/)
      expect { chat.with_file_store(false) }.to raise_error(ArgumentError, /takes a RubyLLM::FileStore or nil/)
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
      expect(chat.file_store.exists?('ruby.png')).to be(true)
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
        .to eq('logo.png was shown here. Open it again with read_file to see it.')
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

  describe 'attachments the provider cannot take' do
    let(:chat) { described_class.new(model: model_for(:anthropic), provider: :anthropic) }
    let(:docx) { File.expand_path('../fixtures/sample.docx', __dir__) }

    it 'sends a line naming the file, for the model to read with read_file' do
      chat.with_file_store
      chat.add_message(role: :user, content: 'What is the codename?', attachments: [docx])

      expect(chat.render.to_json).to include('sample.docx (application/vnd.openxmlformats-officedocument.' \
                                             'wordprocessingml.document, ')
      expect(chat.file_store.text('sample.docx')).to include('BLUE-LANTERN-42')
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
      chat.with_file_store(spill_to_file: 10)

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

    it 'sends every result whole with spill_to_file: false, or without files' do
      expect(tool_result(tool_call, 'z' * 20_000).content.length).to eq(20_000)

      chat.with_file_store(spill_to_file: false)
      expect(tool_result(tool_call, 'z' * 20_000).content.length).to eq(20_000)
    end
  end

  describe 'a conversation' do
    it 'lets the model read an earlier attachment back with read_file' do
      chat.with_file_store
      respond_with(answer('A sample PDF.'), calls('read_file', { 'path' => 'sample.pdf', 'limit' => 3 }),
                   answer('It says Sample PDF.'))

      chat.ask('What is this?', with: pdf_path)
      response = chat.ask('Quote its first line')

      expect(response.content).to eq('It says Sample PDF.')
      expect(requests[0].last.attachments.first.mime_type).to eq('application/pdf')
      expect(requests[1].first.attachments.first.mime_type).to eq('text/plain')
      expect(requests[2].last.content).to eq("sample.pdf (text read from application/pdf), lines 1-3 of 49:\n     " \
                                             "1\t## Page 1\n     2\t\n     3\tSample PDF\n" \
                                             '[46 more lines. Continue with offset 4.]')
    end
  end

  describe 'working with files', :live do
    let(:docx) { File.expand_path('../fixtures/sample.docx', __dir__) }
    let(:handbook) do
      (1..400).map { |number| "#{number}. Section #{number} covers office policy number #{number}." }
              .insert(287, '288. The parking garage door code is 4471-KESTREL.').join("\n")
    end

    def tools_called(chat)
      chat.messages.flat_map { |message| (message.tool_calls || {}).values }.map(&:name)
    end

    it "anthropic/#{model_for(:anthropic)} reads a Word document it cannot take as an attachment" do
      chat = RubyLLM.chat(model: model_for(:anthropic), provider: :anthropic).with_file_store
      response = chat.ask 'What is the project codename in this document?', with: docx

      expect(tools_called(chat)).to include('read_file').or include('search_files')
      expect(response.content).to include('BLUE-LANTERN-42')
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
