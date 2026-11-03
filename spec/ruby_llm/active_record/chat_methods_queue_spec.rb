# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RubyLLM::ActiveRecord::ChatMethods do
  include_context 'with configured RubyLLM'

  let(:image_path) { File.expand_path('../../fixtures/ruby.png', __dir__) }
  let(:requests) { [] }
  let(:responses) { [] }
  let(:during_request) { [] }
  let(:chat) { Chat.create!(model: model_for(:openai)) }

  def echo_tool
    Class.new(RubyLLM::Tool) do
      description 'Echoes the given text'
      parameter :text, description: 'Text to echo'
      define_method(:name) { 'echo' }
      define_method(:execute) { |text:| text }
    end
  end

  def job_for(chat)
    Chat.find(chat.id).with_tools(echo_tool).tap do |job|
      allow(job.to_llm.provider).to receive(:complete) do |messages, **|
        requests << messages.map { |message| [message.role, message.content.to_s] }
        during_request.shift&.call
        responses.shift || answer('Done')
      end
    end
  end

  def answer(content)
    RubyLLM::Message.new(role: :assistant, content:, input_tokens: 1, output_tokens: 1)
  end

  def tool_call
    calls = { 'call_1' => RubyLLM::ToolCall.new(id: 'call_1', name: 'echo', arguments: { 'text' => 'hello' }) }
    RubyLLM::Message.new(role: :assistant, content: '', tool_calls: calls, input_tokens: 1, output_tokens: 1)
  end

  def transcript(chat)
    chat.messages_association.reload.map { |message| [message.role.to_sym, message.content.to_s] }
  end

  def elsewhere(chat)
    Chat.find(chat.id)
  end

  it 'stores queued messages in their own table, oldest first' do
    owner = Chat.create!(model: model_for(:openai))
    queued = []
    chat.after_queue { |record| queued << record }

    first = chat.queue('Use the EU file', owner:)
    second = chat.queue('Then email it', steer: false)

    expect(first).to be_a(RubyLLM::ActiveRecord::QueuedMessage)
    expect(first).to have_attributes(chat:, owner:, content: 'Use the EU file', steer?: true)
    expect(second.steer?).to be(false)
    expect(first.queued_at).to eq(first.created_at)
    expect(chat.queued_messages.to_a).to eq([first, second])
    expect(queued).to eq([first, second])
    expect(chat.messages_association.count).to eq(0)
  end

  it 'takes a message another process queued at the next boundary of its run' do
    responses.push(tool_call, answer('Echoed'))
    job = job_for(chat)
    job.ask_later('Echo hello')
    during_request << -> { elsewhere(chat).queue('Use the EU file') }

    job.complete

    expect(requests.last).to eq([[:user, 'Echo hello'], [:assistant, ''], [:tool, 'hello'],
                                 [:user, 'Use the EU file']])
    expect(transcript(chat)).to eq([[:user, 'Echo hello'], [:assistant, ''], [:tool, 'hello'],
                                    [:user, 'Use the EU file'], [:assistant, 'Echoed']])
    expect(chat.queued_messages).to be_empty
  end

  it 'starts another loop for a steering message queued as the run releases the chat' do
    job = job_for(chat)
    job.ask_later('Hello')
    queued = false
    allow(job.to_llm).to receive(:complete).and_wrap_original do |original, *args, &block|
      original.call(*args, &block).tap do
        next if queued

        queued = true
        elsewhere(chat).queue('Wait for the turn', steer: false)
        elsewhere(chat).queue('Steer')
      end
    end

    job.complete

    expect(transcript(chat)).to eq([[:user, 'Hello'], [:assistant, 'Done'], [:user, 'Steer'],
                                    [:assistant, 'Done']])
    expect(chat.queued_messages.map(&:content)).to eq(['Wait for the turn'])
    expect(job).to be_complete
  end

  it 'takes every queued message at the next complete, waiting ones included' do
    chat.queue('Wait', steer: false)
    chat.queue('Steer')

    job_for(chat).complete

    expect(transcript(chat)).to eq([[:user, 'Wait'], [:user, 'Steer'], [:assistant, 'Done']])
  end

  it 'persists queued messages before the question ask_later adds' do
    chat.queue('Queued first')

    job_for(chat).ask('Then this')

    expect(transcript(chat).first(2)).to eq([[:user, 'Queued first'], [:user, 'Then this']])
  end

  it 'runs after_join with the message record and the queued record' do
    queued = chat.queue('Hello')
    job = job_for(chat)
    joined = []
    job.after_join { |message, record| joined << [message, record] }

    job.complete

    expect(joined.size).to eq(1)
    expect(joined.first.first).to eq(job.messages_association.first)
    expect(joined.first.last.id).to eq(queued.id)
  end

  it 'runs after_join for a message that joined before a later one failed' do
    chat.queue('First')
    chat.queue('Second')
    job = job_for(chat)
    joined = []
    job.after_join { |message, _record| joined << message.content }
    allow(job).to receive(:persist_message).and_wrap_original do |persist, attributes, *rest|
      raise IOError, 'storage is down' if attributes[:content] == 'Second'

      persist.call(attributes, *rest)
    end

    expect { job.complete }.to raise_error(IOError)
    expect(joined).to eq(['First'])
    expect(chat.queued_messages.map(&:content)).to eq(['Second'])
  end

  def with_sender_column
    ActiveRecord::Base.transaction do
      ActiveRecord::Base.connection.add_column(:messages, :sender_id, :integer)
      Message.reset_column_information
      yield
      raise ActiveRecord::Rollback
    end
  ensure
    Message.reset_column_information
  end

  describe '#around_join' do
    it 'saves the message with the attributes join is given, merged across nested callbacks' do
      with_sender_column do
        owner = Chat.create!(model: model_for(:openai))
        chat.queue('Hello', owner:)
        job = job_for(chat)
        seen = []
        job.around_join do |queued, join|
          seen << RubyLLM::ActiveRecord::QueuedMessage.exists?(queued.id)
          seen << join.call(sender_id: queued.owner.id).sender_id
        end
        job.around_join { |_queued, join| join.call(cache_until_here: true) }
        job.after_join { |message, _queued| seen << message.persisted? }

        job.complete

        message = chat.messages_association.reload.first
        expect(message).to have_attributes(role: 'user', content: 'Hello', sender_id: owner.id)
        expect(message[:cache_until_here]).to be(true)
        expect(seen).to eq([false, owner.id, true])
      end
    end

    it 'rolls the join back and keeps the message queued when the callback raises' do
      queued = chat.queue('Hello', with: image_path)
      job = job_for(chat)
      job.around_join do |_queued, join|
        join.call
        raise IOError, 'audit failed'
      end

      expect { job.complete }.to raise_error(IOError)
      expect(chat.messages_association.reload).to be_empty
      expect(job.messages_association).to be_empty
      expect(job.to_llm.messages).to be_empty
      expect(chat.queued_messages.to_a).to eq([queued])
      expect(queued.reload.attachments.blobs.size).to eq(1)
      expect(requests).to be_empty
    end

    it 'withdraws a message whose callback never joins it, and the turn goes on' do
      withdrawn = chat.queue('Never mind', with: image_path)
      chat.queue('Keep this')
      job = job_for(chat)
      unqueued = []
      job.around_join { |queued, join| join.call unless queued.content == 'Never mind' }
      job.after_unqueue { |record| unqueued << record.content }

      expect(job.complete.content).to eq('Done')
      expect(transcript(chat)).to eq([[:user, 'Keep this'], [:assistant, 'Done']])
      expect(unqueued).to eq(['Never mind'])
      expect(chat.queued_messages).to be_empty
      expect(ActiveStorage::Attachment.where(record_type: withdrawn.class.polymorphic_name, record_id: withdrawn.id))
        .to be_empty
    end
  end

  it 'joins every queued message with join_queued_messages, without calling the model' do
    chat.queue('Steer')
    chat.queue('Wait', steer: false)
    job = job_for(chat)

    joined = job.join_queued_messages

    expect(joined).to eq(chat.messages_association.reload.to_a)
    expect(joined.map(&:content)).to eq(%w[Steer Wait])
    expect(chat.queued_messages).to be_empty
    expect(requests).to be_empty
  end

  it 'takes only steering messages when a turn resumes after an approval' do
    approved_echo = Class.new(echo_tool) { requires_approval }
    responses.push(tool_call, answer('Echoed'))
    job_for(chat).with_tools(nil).with_tools(approved_echo).ask('Echo hello')
    chat.queue('Afterwards', steer: false)
    chat.queue('Steer')

    resumed = job_for(chat).with_tools(nil).with_tools(approved_echo)
    resumed.approve(resumed.pending_approvals.first)
    resumed.complete

    expect(transcript(chat)).to eq([[:user, 'Echo hello'], [:assistant, ''], [:tool, 'hello'], [:user, 'Steer'],
                                    [:assistant, 'Echoed']])
    expect(chat.queued_messages.map(&:content)).to eq(['Afterwards'])
  end

  it 'reads queued messages outside the query cache' do
    chat.queue('First')
    cached = []
    record = ->(*, payload) { cached << payload[:cached] if payload[:sql].include?('ruby_llm_queued_messages') }

    ActiveSupport::Notifications.subscribed(record, 'sql.active_record') do
      Chat.cache { 2.times { chat.queued_messages.to_a } }
    end

    expect(cached.compact).to be_empty
  end

  it 'moves attachments to the message without uploading them again' do
    queued = chat.queue('What is this?', with: image_path)
    blob = queued.attachments.blobs.sole

    job_for(chat).complete

    message = chat.messages_association.reload.first
    expect(message.attachments.blobs.to_a).to eq([blob])
    expect(blob.reload).to be_persisted
    expect(ActiveStorage::Attachment.where(record_type: queued.class.polymorphic_name, record_id: queued.id))
      .to be_empty
    expect(requests.last.first).to eq([:user, 'What is this?'])
  end

  it 'unqueues a message before the loop takes it, and not after' do
    unqueued = []
    chat.after_unqueue { |record| unqueued << record.content }
    withdrawn = chat.queue('Never mind', with: image_path)
    kept = chat.queue('Keep this')

    expect(elsewhere(chat).unqueue(withdrawn.id)).to be(true)
    expect(chat.unqueue(withdrawn)).to be(false)
    expect(ActiveStorage::Attachment.where(record_type: withdrawn.class.polymorphic_name, record_id: withdrawn.id))
      .to be_empty

    job_for(chat).complete

    expect(chat.unqueue(kept)).to be(false)
    expect(unqueued).to eq([])
    expect(transcript(chat)).to eq([[:user, 'Keep this'], [:assistant, 'Done']])
  end

  it 'leaves a message of another chat alone' do
    other = Chat.create!(model: model_for(:openai))
    queued = other.queue('Not yours')

    expect(chat.unqueue(queued.id)).to be(false)
    expect(other.queued_messages.to_a).to eq([queued])
  end

  it 'keeps queued messages when the chat is cancelled' do
    job = job_for(chat)
    job.ask_later('Hello')
    during_request << lambda {
      elsewhere(chat).queue('Steer')
      job.cancel
    }

    expect { job.complete }.to raise_error(RubyLLM::CancelledError)
    expect(chat.queued_messages.map(&:content)).to eq(['Steer'])
  end

  it 'destroys queued messages with their chat' do
    queued = chat.queue('Hello', with: image_path)

    chat.destroy!

    expect(RubyLLM::ActiveRecord::QueuedMessage.where(id: queued.id)).to be_empty
    expect(ActiveStorage::Attachment.where(record_type: queued.class.polymorphic_name, record_id: queued.id))
      .to be_empty
  end

  it 'runs chats on a schema without the queued messages table' do
    connection = ActiveRecord::Base.connection
    ActiveRecord::Base.transaction do
      connection.drop_table(:ruby_llm_queued_messages)
      RubyLLM::ActiveRecord::QueuedMessage.reset_column_information
      chat.add_message(role: :user, content: 'Hello')

      expect(job_for(chat).complete.content).to eq('Done')
      raise ActiveRecord::Rollback
    end
  ensure
    RubyLLM::ActiveRecord::QueuedMessage.reset_column_information
  end
end
