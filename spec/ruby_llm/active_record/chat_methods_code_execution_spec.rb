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
end
