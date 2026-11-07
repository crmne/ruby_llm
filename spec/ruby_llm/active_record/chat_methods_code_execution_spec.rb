# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RubyLLM::ActiveRecord::ChatMethods do
  include_context 'with configured RubyLLM'

  let(:png) { File.binread(File.expand_path('../../fixtures/ruby.png', __dir__)) }
  let(:sandbox) do
    png = self.png
    FakeSandbox.new do |run|
      File.binwrite(File.join(run[:directory], 'chart.png'), png)
      File.write(File.join(run[:directory], 'rows.csv'), "a,b\n1,2\n")
      FakeSandbox.result(stdout: 'plotted')
    end
  end

  around do |example|
    original = RubyLLM.config.sandbox
    RubyLLM.config.sandbox = sandbox
    example.run
  ensure
    RubyLLM.config.sandbox = original
  end

  it 'stores the files a run returns as attachments on the tool result message' do
    chat = Chat.create!(model: model_for(:anthropic), provider: :anthropic)
    expect(chat.with_code_execution).to be(chat)
    call = RubyLLM::ToolCall.new(id: "call_#{SecureRandom.hex(4)}", name: 'run_code',
                                 arguments: { 'language' => 'ruby', 'code' => 'plot' })
    allow(chat.to_llm.provider).to receive(:complete).and_return(
      RubyLLM::Message.new(role: :assistant, content: '', tool_calls: { call.id => call }),
      RubyLLM::Message.new(role: :assistant, content: 'Here is the chart.')
    )

    chat.ask('Plot the data')
    result = Chat.find(chat.id).messages.find_by(role: 'tool')

    expect(JSON.parse(result.content)).to include('stdout' => 'plotted', 'files' => %w[chart.png rows.csv])
    expect(result.attachments.map { |file| file.filename.to_s }).to eq(%w[chart.png rows.csv])
    expect(result.attachments.first.download).to eq(png)
    expect(chat.code_execution).to eq(languages: %i[ruby shell])
  end

  it 'gives later runs the stored files' do
    chat = Chat.create!(model: model_for(:anthropic), provider: :anthropic).with_code_execution
    call = RubyLLM::ToolCall.new(id: "call_#{SecureRandom.hex(4)}", name: 'run_code',
                                 arguments: { 'language' => 'ruby', 'code' => 'plot' })
    allow(chat.to_llm.provider).to receive(:complete).and_return(
      RubyLLM::Message.new(role: :assistant, content: '', tool_calls: { call.id => call }),
      RubyLLM::Message.new(role: :assistant, content: 'Done.')
    )
    chat.ask('Plot the data')

    seen = nil
    reader = FakeSandbox.new do |run|
      seen = Dir.children(File.join(run[:directory], 'attachments')).sort
      FakeSandbox.result
    end
    RubyLLM.config.sandbox = reader
    reloaded = Chat.find(chat.id).with_code_execution
    reloaded.tools[:run_code].call(language: 'ruby', code: 'read')

    expect(seen).to eq(%w[chart.png rows.csv])
  end

  context 'with files in Active Storage' do
    let(:seen) { {} }
    let(:sandbox) do
      seen = self.seen
      FakeSandbox.new do |run|
        attachments = File.join(run[:directory], 'attachments')
        seen[:attachments] = Dir.glob('**/*', base: "#{attachments}/")
                                .select { |path| File.file?(File.join(attachments, path)) }.sort
        seen[:sales] = File.read(File.join(attachments, 'sales.csv')) if seen[:attachments].include?('sales.csv')
        seen[:readable] = run[:readable]
        seen[:writable] = run[:writable]
        FakeSandbox.result
      end
    end

    def chat_with_sales(owner: nil)
      chat = Chat.create!(model: model_for(:anthropic), provider: :anthropic)
      chat.with_owner(owner).with_code_execution.with_file_store.tap do
        file = RubyLLM::Attachment.new(StringIO.new("a,b\n"), filename: 'sales.csv')
        chat.to_llm.add_message(role: :user, content: 'Here', attachments: [file])
      end
    end

    def run_code(chat)
      chat.to_llm.tools[:run_code].call(language: 'ruby', code: 'read')
    end

    it "gives a run the conversation's files, read-only, without naming them" do
      run_code(chat_with_sales)

      expect(seen[:attachments]).to eq(%w[sales.csv])
      expect(seen[:sales]).to eq("a,b\n")
      inputs = seen[:readable].find { |path| path.end_with?('/inputs') }
      expect(inputs).not_to be_nil
      expect(seen[:writable]).not_to include(inputs)
    end

    it 'gives a reloaded chat the attachments of its stored messages' do
      chat = Chat.create!(model: model_for(:anthropic), provider: :anthropic)
      chat.messages.create!(role: 'user', content: 'Here').attachments.attach(
        io: StringIO.new("a,b\n"), filename: 'sales.csv', content_type: 'text/csv'
      )

      run_code(Chat.find(chat.id).with_code_execution.with_file_store)

      expect(seen[:attachments]).to eq(%w[sales.csv])
    end

    it "keeps another chat's files out of the run" do
      other = Chat.create!(model: model_for(:anthropic), provider: :anthropic).with_file_store
      other.file_store.write('other.csv', 'theirs')

      run_code(chat_with_sales)

      expect(seen[:attachments]).to eq(%w[sales.csv])
    end

    it "keeps a file only another owner's read_file showed out of the run" do
      alice = Chat.create!(model: model_for(:openai))
      bob = Chat.create!(model: model_for(:openai))
      chat = chat_with_sales(owner: alice)
      chat.file_store.write('private.txt', 'alice only')
      call = RubyLLM::ToolCall.new(id: 'read_1', name: 'read_file', arguments: { 'path' => 'private.txt' })
      chat.to_llm.add_message(role: :assistant, content: '', tool_calls: { call.id => call })
      shown = RubyLLM::Attachment.new(StringIO.new('alice only'), filename: 'private.txt')
      chat.to_llm.add_message(role: :tool, content: 'read', tool_call_id: call.id, attachments: [shown])

      run_code(chat.with_owner(bob))

      expect(seen[:attachments]).to eq(%w[sales.csv])
    end
  end
end
