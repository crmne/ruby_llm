# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RubyLLM::ActiveRecord::MessageBroadcasting do
  include_context 'with configured RubyLLM'

  let(:broadcasts) { [] }

  def define_models(broadcasts:)
    stub_const('BroadcastChat', Class.new(ApplicationRecord) do
      self.table_name = 'chats'
      acts_as_chat message_class: 'BroadcastMessage', messages_foreign_key: :chat_id
    end)
    stub_const('BroadcastMessage', Class.new(ApplicationRecord) do
      self.table_name = 'messages'
      acts_as_message chat_class: 'BroadcastChat', chat_foreign_key: :chat_id, broadcasts:
    end)
  end

  # The dummy app loads turbo-rails without Action Cable, so the models
  # record the Turbo broadcasts they would send.
  def record_broadcasts
    sent = broadcasts
    recorder = Module.new do
      %i[broadcast_append_to broadcast_replace_to broadcast_remove_to broadcast_refresh_to].each do |action|
        define_method(action) { |*streamables, **options| sent << [action, streamables, options] }
      end
    end
    BroadcastChat.prepend(recorder)
    BroadcastMessage.prepend(recorder)
  end

  def stream_reply(chat, *texts)
    allow(chat.to_llm.provider).to receive(:complete) do |*, **, &block|
      texts.each { |text| block.call(RubyLLM::Chunk.new(role: :assistant, content: text)) }
      RubyLLM::Message.new(role: :assistant, content: texts.join)
    end
  end

  context 'when broadcasting' do
    before do
      define_models(broadcasts: true)
      record_broadcasts
    end

    it 'appends the empty reply, then numbered chunks, then replaces the finished message' do
      chat = BroadcastChat.create!(model: model_for(:openai))
      stream_reply(chat, 'Hel', '', 'lo <b>')
      streamed = []

      chat.ask('Say hello') do |chunk|
        streamed << chunk.message
        chunk.broadcast
      end

      reply = chat.messages.last
      chunks = broadcasts.select { |action, _, options| action == :broadcast_append_to && options[:content] }
      expect(streamed.uniq).to eq([reply])
      expect(broadcasts).to include([:broadcast_append_to, [chat], {}])
      expect(chunks.map { |_, streamables, options| [streamables, options[:target], options[:content]] }).to eq(
        [[[chat], "broadcast_message_#{reply.id}_stream", '<span data-seq="0">Hel</span>'],
         [[chat], "broadcast_message_#{reply.id}_stream", '<span data-seq="2" data-after="0">lo &lt;b&gt;</span>']]
      )
      expect(broadcasts.map(&:first)).to include(:broadcast_replace_to)
      expect(broadcasts.last).to eq([:broadcast_refresh_to, [chat], {}])
    end

    it 'removes a destroyed message' do
      chat = BroadcastChat.create!(model: model_for(:openai))
      message = chat.messages.create!(role: :user, content: 'Hi')
      broadcasts.clear

      message.destroy!

      expect(broadcasts.map(&:first)).to include(:broadcast_remove_to)
    end
  end

  context 'when turned off' do
    before do
      define_models(broadcasts: false)
      record_broadcasts
    end

    it 'broadcasts nothing and leaves broadcast_chunk undefined' do
      chat = BroadcastChat.create!(model: model_for(:openai))
      stream_reply(chat, 'Hello')

      chat.ask('Say hello') { |chunk| expect(chunk.message).to eq(chat.messages.last) }

      expect(broadcasts).to be_empty
      expect(BroadcastMessage.new).not_to respond_to(:broadcast_chunk)
    end
  end

  it 'declares the attachments itself' do
    expect(Message.reflect_on_attachment(:attachments)).to be_present
  end
end
