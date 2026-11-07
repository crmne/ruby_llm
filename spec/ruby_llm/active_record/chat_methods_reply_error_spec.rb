# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RubyLLM::ActiveRecord::ChatMethods do
  include_context 'with configured RubyLLM'

  let(:chat) { Chat.create!(model: model_for(:openai)).tap { |chat| chat.add_message(role: :user, content: 'Hello') } }

  def answer = RubyLLM::Message.new(role: :assistant, content: 'Done', input_tokens: 1, output_tokens: 1)

  def job_for(chat, &reply)
    Chat.find(chat.id).tap do |job|
      allow(job.to_llm.provider).to receive(:complete) { reply ? reply.call(job) : answer }
    end
  end

  def with_reply_error_column
    connection = ActiveRecord::Base.connection
    ActiveRecord::Base.transaction do
      connection.add_column(:chats, :reply_error, :string)
      Chat.reset_column_information
      yield
      raise ActiveRecord::Rollback
    end
  ensure
    Chat.reset_column_information
  end

  it 'saves a message for the person when a reply fails, and clears it when the next run starts' do
    with_reply_error_column do
      failing = job_for(chat) { raise RubyLLM::ServerError, 'The provider is down' }
      expect { failing.complete }.to raise_error(RubyLLM::ServerError)
      expect(chat.reload.reply_error).to eq('The reply failed. Send your message again.')

      during = :not_asked
      job_for(chat) do
        during = Chat.find(chat.id).reply_error
        answer
      end.complete

      expect(during).to be_nil
      expect(chat.reload.reply_error).to be_nil
    end
  end

  it 'tells the person to start a new chat when the conversation is too long for the model' do
    with_reply_error_column do
      failing = job_for(chat) { raise RubyLLM::ContextLengthExceededError, 'too many tokens' }

      expect { failing.complete }.to raise_error(RubyLLM::ContextLengthExceededError)
      expect(chat.reload.reply_error).to eq('This conversation is too long for the model. Start a new chat.')
    end
  end

  it 'takes the message from I18n' do
    I18n.backend.store_translations(:en, ruby_llm: { reply_error: { failed: 'Something went wrong.' } })
    with_reply_error_column do
      failing = job_for(chat) { raise RubyLLM::ServerError, 'The provider is down' }

      expect { failing.complete }.to raise_error(RubyLLM::ServerError)
      expect(chat.reload.reply_error).to eq('Something went wrong.')
    end
  ensure
    I18n.reload!
  end

  it 'saves nothing when a stop ends the reply' do
    with_reply_error_column do
      stopped = job_for(chat) do |job|
        job.cancel
        answer
      end

      expect { stopped.complete }.to raise_error(RubyLLM::CancelledError)
      expect(chat.reload.reply_error).to be_nil
    end
  end

  it 'writes nothing when a run starts on a chat with no error to clear' do
    with_reply_error_column do
      job = job_for(chat)
      updates = []
      subscriber = ActiveSupport::Notifications.subscribe('sql.active_record') do |*, payload|
        updates << payload[:sql] if payload[:sql].match?(/UPDATE .*reply_error/i)
      end

      job.complete

      expect(updates).to be_empty
    ensure
      ActiveSupport::Notifications.unsubscribe(subscriber)
    end
  end

  it 'raises the error on a chats table without the column, and tries no write' do
    failing = job_for(chat) { raise RubyLLM::ServerError, 'The provider is down' }
    allow(RubyLLM.logger).to receive(:warn)

    expect { failing.complete }.to raise_error(RubyLLM::ServerError)
    expect(Chat.column_names).not_to include('reply_error')
    expect(RubyLLM.logger).not_to have_received(:warn).with(/reply error/)
  end
end
