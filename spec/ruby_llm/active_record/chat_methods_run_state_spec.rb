# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RubyLLM::ActiveRecord::ChatMethods do
  include_context 'with configured RubyLLM'

  let(:requests) { [] }
  let(:call_id) { "call_#{SecureRandom.hex(4)}" }

  def job_for(chat, content: 'Done', &during_request)
    Chat.find(chat.id).tap do |job|
      allow(job.to_llm.provider).to receive(:complete) do |*, **, &stream|
        requests << job
        during_request&.call(stream)
        RubyLLM::Message.new(role: :assistant, content:, input_tokens: 1, output_tokens: 1)
      end
    end
  end

  def question_chat
    Chat.create!(model: model_for(:openai)).tap { |chat| chat.add_message(role: :user, content: 'Hello') }
  end

  def answered_chat
    question_chat.tap { |chat| job_for(chat).complete }.tap { requests.clear }
  end

  def row(chat)
    Chat.find(chat.id)
  end

  def flag(chat)
    Chat.where(id: chat.id).update_all(cancelled: true)
  end

  def tool_call_message
    tool_calls = { call_id => RubyLLM::ToolCall.new(id: call_id, name: 'charge_card', arguments: {}) }
    RubyLLM::Message.new(role: :assistant, content: '', tool_calls:)
  end

  describe 'a released claim' do
    it 'leaves neither token nor expiry after a finished run' do
      chat = answered_chat

      expect(row(chat)).to have_attributes(claim_token: nil, claimed_until: nil, cancelled: false)
      expect(Chat.where(id: chat.id).where.not(claim_token: nil)).to be_empty
    end

    it 'leaves neither token nor expiry after a failed run' do
      chat = question_chat
      job = job_for(chat) { raise RubyLLM::ServerError, 'boom' }

      expect { job.complete }.to raise_error(RubyLLM::ServerError)

      expect(row(chat)).to have_attributes(claim_token: nil, claimed_until: nil)
    end

    it 'leaves neither token nor expiry after a cancelled run' do
      stub_const("#{described_class}::CANCELLATION_POLL_INTERVAL", 0.0)
      chat = question_chat
      job = job_for(chat) do |stream|
        row(chat).cancel
        stream.call(RubyLLM::Chunk.new(role: :assistant, content: 'Do'))
      end

      expect { job.complete { |_chunk| nil } }.to raise_error(RubyLLM::CancelledError)

      expect(row(chat)).to have_attributes(claim_token: nil, claimed_until: nil, cancelled: false)
    end

    it 'keeps the token of a process that took the chat over' do
      chat = question_chat
      job_for(chat) do
        Chat.where(id: chat.id).update_all(claim_token: 'elsewhere', claimed_until: 10.minutes.from_now)
      end.complete

      expect(row(chat).claim_token).to eq('elsewhere')
    end

    it 'does not ask again for a reply another process finished in place' do
      chat = question_chat
      chat.add_message(RubyLLM::Message.new(role: :assistant, content: 'Part', continuation: 'resume-1'))
      overtaken = job_for(chat, content: 'From the second job')
      finisher = job_for(chat, content: 'Part and the rest')
      finisher.complete

      overtaken.complete

      expect(requests).to eq([finisher])
      expect(chat.messages_association.reload.last.content).to eq('Part and the rest')
      expect(overtaken).to be_complete
    end

    it 'rereads an unfinished reply even when nothing shows another run' do
      chat = question_chat
      chat.add_message(RubyLLM::Message.new(role: :assistant, content: 'Part', continuation: 'resume-1'))
      job = job_for(chat)
      allow(job).to receive(:resync_messages).and_call_original

      job.complete

      expect(job).to have_received(:resync_messages).once
    end

    it 'counts usage before it reads the token, so a run starting between them still shows' do
      chat = question_chat
      job = job_for(chat)
      reads = []
      record = lambda do |*, payload|
        reads << :usage if payload[:sql].include?('ruby_llm_usages') && payload[:sql].include?('COUNT')
        reads << :token if payload[:sql].include?('claim_token') && payload[:sql].start_with?('SELECT')
      end

      ActiveSupport::Notifications.subscribed(record, 'sql.active_record') { job.send(:snapshot_run_claim) }

      expect(reads).to eq(%i[usage token])
    end

    it 'frees the chat when counting usage at the end of a run fails' do
      chat = question_chat
      failure = ActiveRecord::StatementInvalid.new('count failed')
      job = job_for(chat) { allow(job).to receive(:usage_row_count).and_raise(failure) }

      expect { job.complete }.to raise_error(failure)

      expect(row(chat)).to have_attributes(claim_token: nil, claimed_until: nil)
      expect(job.instance_variable_get(:@run_claim_token)).to be_nil
    end

    it 'rereads usage another process recorded on a run that added no message' do
      chat = question_chat
      job = job_for(chat)
      allow(job).to receive(:resync_messages).and_call_original
      entry = RubyLLM::Accounting::Usage::Entry.new(operation: :chat, provider: 'openai', model: model_for(:openai))
      row(chat).to_llm.__send__(:record_usage_entry, entry)

      job.complete

      expect(job).to have_received(:resync_messages).once
    end

    it 'does not reread when the only token was there before it loaded' do
      chat = question_chat
      Chat.where(id: chat.id).update_all(claim_token: 'crashed', claimed_until: 1.minute.ago)
      job = job_for(chat)
      allow(job).to receive(:resync_messages).and_call_original

      job.complete

      expect(job).not_to have_received(:resync_messages)
    end

    it 'rereads once after finding a token it had not seen' do
      chat = question_chat
      job = job_for(chat)
      allow(job).to receive(:resync_messages).and_call_original
      Chat.where(id: chat.id).update_all(claim_token: 'crashed', claimed_until: 1.minute.ago)

      job.complete
      job.ask('And then?')

      expect(job).to have_received(:resync_messages).once
    end

    it 'keeps a process that completes twice from rereading its own run' do
      chat = question_chat
      job = job_for(chat)
      allow(job).to receive(:resync_messages).and_call_original

      job.complete
      job.ask('And then?')

      expect(job).not_to have_received(:resync_messages)
      expect(requests).to eq([job, job])
    end
  end

  describe 'cancel with nothing to stop' do
    it 'records nothing on a chat with no messages' do
      chat = Chat.create!(model: model_for(:openai))

      expect(chat.cancel).to eq(chat)

      expect(chat).not_to be_cancelled
      expect(row(chat)).not_to be_cancelled
    end

    it 'records nothing on a chat whose reply finished, so the next reply runs' do
      chat = answered_chat

      row(chat).cancel

      expect(row(chat)).not_to be_cancelled
      job = job_for(chat)
      job.ask('And then?')
      expect(requests).to eq([job])
    end

    it 'leaves a built chat able to answer the next question' do
      chat = answered_chat
      job = job_for(chat)

      job.cancel
      job.ask('And then?')

      expect(requests).to eq([job])
    end
  end

  describe 'a flag left on a chat nothing runs' do
    it 'does not stop a question asked after it' do
      chat = answered_chat
      flag(chat)
      job = job_for(chat)

      job.ask('And then?')

      expect(requests).to eq([job])
      expect(row(chat)).not_to be_cancelled
    end

    it 'does not stop a question another process saved after it' do
      chat = answered_chat
      flag(chat)
      job = job_for(chat)
      row(chat).ask_later('And then?')

      job.complete

      expect(requests).to eq([job])
      expect(row(chat)).not_to be_cancelled
    end

    it 'does not stop a job that loaded the flag before another process cleared it' do
      chat = answered_chat
      flag(chat)
      job = job_for(chat)
      row(chat).ask_later('And then?')

      expect(job).to be_cancelled
      job.complete

      expect(requests).to eq([job])
    end

    it 'does not stop a message added after it' do
      chat = answered_chat
      flag(chat)
      row(chat).add_message(role: :user, content: 'And then?')
      job = job_for(chat)

      job.complete

      expect(requests).to eq([job])
    end

    it 'does not stop a message queued after it' do
      chat = answered_chat
      flag(chat)
      row(chat).queue('And then?')
      job = job_for(chat)

      job.complete

      expect(requests).to eq([job])
    end

    it 'does not stop a decision recorded after it' do
      chat = question_chat
      chat.add_message(tool_call_message)
      flag(chat)

      row(chat).deny(call_id)

      expect(row(chat)).not_to be_cancelled
    end

    it 'stays when an approval repeats a decision already recorded' do
      chat = question_chat
      chat.add_message(tool_call_message)
      row(chat).approve(call_id)
      row(chat).cancel

      row(chat).approve(call_id)

      expect(row(chat)).to be_cancelled
    end

    it 'stays when a decision cannot be recorded on a running call' do
      chat = question_chat
      chat.add_message(tool_call_message)
      RubyLLM::ActiveRecord::ToolCall.find_by(tool_call_id: call_id).update!(claimed_until: 10.minutes.from_now)
      flag(chat)

      expect { row(chat).deny(call_id) }.to raise_error(RubyLLM::ToolCallRunningError)

      expect(row(chat)).to be_cancelled
    end

    it 'stays when the message that followed it fails to save' do
      chat = question_chat
      flag(chat)

      expect { row(chat).persist_message({ role: :user, content: 'Nope' }, { no_such_column: 1 }) }
        .to raise_error(ActiveModel::UnknownAttributeError)

      expect(row(chat)).to be_cancelled
    end

    it 'stays when the queued message that followed it fails to save' do
      chat = question_chat
      flag(chat)

      expect { row(chat).queue('Nope', sender: Object.new) }.to raise_error(StandardError)

      expect(row(chat)).to be_cancelled
    end

    it 'stays when an assistant message is saved' do
      chat = question_chat
      flag(chat)

      row(chat).add_message(role: :assistant, content: 'Noted')

      expect(row(chat)).to be_cancelled
    end

    it 'clears on the record that recorded the new work' do
      chat = answered_chat
      flag(chat)
      record = row(chat)

      record.ask_later('And then?')

      expect(record).not_to be_cancelled
    end

    it 'does not raise from a complete with nothing to answer' do
      chat = answered_chat
      flag(chat)
      job = job_for(chat)

      expect(job.complete.content).to eq('Done')

      expect(requests).to be_empty
      expect(row(chat)).not_to be_cancelled
    end
  end

  describe 'stop before the job claims' do
    it 'stops a job loaded before the stop, in another process' do
      chat = question_chat
      job = job_for(chat)

      row(chat).cancel

      expect(row(chat)).to be_cancelled
      expect { job.complete }.to raise_error(RubyLLM::CancelledError)
      expect(requests).to be_empty
      expect(row(chat)).not_to be_cancelled
    end

    it 'stops a job loaded after the stop' do
      chat = question_chat
      row(chat).cancel
      job = job_for(chat)

      expect { job.complete }.to raise_error(RubyLLM::CancelledError)
      expect(requests).to be_empty
    end

    it 'stops the run of a message saved with ask_later' do
      chat = answered_chat
      job = job_for(chat)
      row(chat).ask_later('And then?')

      row(chat).cancel

      expect { job.complete }.to raise_error(RubyLLM::CancelledError)
      expect(requests).to be_empty
    end

    it 'stops the run of a queued message and keeps the message' do
      chat = answered_chat
      row(chat).queue('And then?', steer: false)
      job = job_for(chat)

      row(chat).cancel

      expect { job.complete }.to raise_error(RubyLLM::CancelledError)
      expect(requests).to be_empty
      expect(row(chat).queued_messages.map(&:content)).to eq(['And then?'])
    end

    it 'lets a later complete ask the question once the stop is spent' do
      chat = question_chat
      row(chat).cancel
      stopped = job_for(chat)
      expect { stopped.complete }.to raise_error(RubyLLM::CancelledError)

      job = job_for(chat)
      job.complete

      expect(requests).to eq([job])
    end

    it 'answers a message sent after the stop' do
      chat = question_chat
      row(chat).cancel

      row(chat).ask_later('Actually, this')
      job = job_for(chat)
      job.complete

      expect(requests).to eq([job])
      expect(row(chat)).not_to be_cancelled
    end

    it 'stops a run that takes over from a process that died' do
      chat = question_chat
      chat.messages_association.create!(role: :assistant, content: '')
      Chat.where(id: chat.id).update_all(claim_token: 'crashed', claimed_until: 1.minute.ago)
      job = job_for(chat)

      row(chat).cancel

      expect(row(chat)).to be_cancelled
      expect { job.complete }.to raise_error(RubyLLM::CancelledError)
    end

    it 'records a stop on a chat awaiting a decision' do
      chat = question_chat
      chat.add_message(tool_call_message)

      row(chat).cancel

      expect(row(chat)).to be_cancelled
    end
  end

  describe 'stop while a run holds the chat' do
    it 'stops the run in the other process' do
      stub_const("#{described_class}::CANCELLATION_POLL_INTERVAL", 0.0)
      chat = question_chat
      job = job_for(chat) do |stream|
        row(chat).cancel
        stream.call(RubyLLM::Chunk.new(role: :assistant, content: 'Do'))
      end

      expect { job.complete { |_chunk| nil } }.to raise_error(RubyLLM::CancelledError)
    end

    it 'shows the request on the record that asked' do
      chat = question_chat
      seen = nil
      job = job_for(chat) do
        web = row(chat)
        web.cancel
        seen = web.cancelled?
      end

      begin
        job.complete
      rescue RubyLLM::CancelledError
        nil
      end

      expect(seen).to be(true)
    end

    it 'keeps the stop when a message arrives after it' do
      stub_const("#{described_class}::CANCELLATION_POLL_INTERVAL", 3600.0)
      chat = question_chat
      seen = nil
      job = job_for(chat) do
        next if seen

        row(chat).cancel
        row(chat).queue('And after that?')
        seen = row(chat)[:cancelled]
      end

      job.complete

      expect(seen).to be(true)
    end

    it 'clears a stop the run never saw when it releases' do
      stub_const("#{described_class}::CANCELLATION_POLL_INTERVAL", 3600.0)
      chat = question_chat
      job_for(chat) { row(chat).cancel }.complete

      expect(row(chat)).not_to be_cancelled
    end

    it 'leaves nothing in the memory of the process that asked' do
      stub_const("#{described_class}::CANCELLATION_POLL_INTERVAL", 3600.0)
      chat = question_chat
      web = job_for(chat)
      runner = job_for(chat) { web.cancel }

      runner.complete
      web.ask('And then?')

      expect(requests).to eq([runner, web])
    end
  end

  context 'without the claim columns' do
    around do |example|
      connection = ActiveRecord::Base.connection
      ActiveRecord::Base.transaction do
        connection.remove_column(:chats, :claim_token)
        connection.remove_column(:chats, :claimed_until)
        Chat.reset_column_information
        example.run
        raise ActiveRecord::Rollback
      end
    ensure
      Chat.reset_column_information
    end

    it 'records the request as before, since nothing shows whether a run holds the chat' do
      chat = answered_chat

      row(chat).cancel

      expect(row(chat)).to be_cancelled
    end

    it 'leaves a request for the next reply to observe, since no run clears it' do
      chat = answered_chat
      flag(chat)

      job_for(chat).complete

      expect(row(chat)).to be_cancelled
    end
  end
end
