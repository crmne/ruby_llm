# frozen_string_literal: true

require 'rails_helper'
require 'active_support/testing/time_helpers'

RSpec.describe RubyLLM::ActiveRecord::ChatMethods do
  include_context 'with configured RubyLLM'
  include ActiveSupport::Testing::TimeHelpers

  after { travel_back }

  let(:lease) { RubyLLM::ActiveRecord::RunClaims::CLAIM_LEASE.seconds }
  let(:created) { [] }

  let(:charge) do
    Class.new(RubyLLM::Tool) do
      def self.name = 'ChargeCard'

      description 'Charges the card'
      requires_approval
      define_method(:execute) { 'charged' }
    end
  end

  let(:seat) do
    Class.new(RubyLLM::Tool) do
      def self.name = 'PickSeat'

      description 'Asks for a seat'
      define_method(:execute) { "Seat #{ask('Window or aisle?', choices: %w[window aisle])}" }
    end
  end

  let(:deploy) do
    Class.new(RubyLLM::Tool) do
      def self.name = 'Deploy'

      description 'Starts a deploy'
      define_method(:execute) { RubyLLM::Task.new(status: :working, data: { 'job' => 'deploy' }) }
      define_method(:resume) { |task, **| task }
    end
  end

  # Other examples leave their chats in the database, so each example
  # looks only at its own.
  def chats
    Chat.where(id: created.map(&:id))
  end

  def asked
    Chat.create!(model: model_for(:openai)).tap do |chat|
      created << chat
      chat.add_message(role: :user, content: 'Hello')
    end
  end

  def claim(chat, until_time)
    Chat.where(id: chat.id).update_all(claim_token: 'worker', claimed_until: until_time)
    chat
  end

  def reply(content = 'Done')
    RubyLLM::Message.new(role: :assistant, content:, input_tokens: 1, output_tokens: 1)
  end

  def calling(name)
    tool_call = RubyLLM::ToolCall.new(id: "call_#{SecureRandom.hex(4)}", name:, arguments: {})
    RubyLLM::Message.new(role: :assistant, content: '', tool_calls: { tool_call.id => tool_call },
                         input_tokens: 1, output_tokens: 1)
  end

  def job_for(chat, *tools, &answer)
    Chat.find(chat.id).with_tools(*tools).tap do |job|
      allow(job.to_llm.provider).to receive(:complete) { answer ? answer.call(job) : reply }
    end
  end

  def row(chat)
    Chat.find(chat.id)
  end

  # A tool that posts an update somewhere, doing whatever +behavior+ does.
  def posting(&behavior)
    Class.new(RubyLLM::Tool) do
      def self.name = 'PostUpdate'

      description 'Posts an update'
      define_method(:execute) { behavior.call }
    end
  end

  # A job whose model calls post_update +calls+ times in one round, then
  # replies.
  def posting_job(chat, calls: 1, &behavior)
    tool_calls = Array.new(calls) { RubyLLM::ToolCall.new(id: "call_#{SecureRandom.hex(4)}", name: 'post_update') }
    answers = [RubyLLM::Message.new(role: :assistant, content: '', tool_calls: tool_calls.index_by(&:id),
                                    input_tokens: 1, output_tokens: 1)]
    job_for(chat, posting(&behavior)) { answers.shift || reply }
  end

  def tool_call_rows(chat)
    RubyLLM::ActiveRecord::ToolCall.where(message_id: Message.where(chat_id: chat.id).select(:id)).order(:id).to_a
  end

  # Starts a reply in a forked process and ends that process without
  # unwinding while the provider answers, as a crash or a SIGKILL would.
  def killed_mid_reply(chat)
    skip 'needs fork' unless Process.respond_to?(:fork)

    pid = fork do
      job_for(chat) { exit!(0) }.complete
    ensure
      exit!(1)
    end
    Process.wait(pid)
    chat
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

  describe '.interrupted' do
    it 'returns a chat whose run was killed mid-turn, once its claim expires' do
      chat = killed_mid_reply(asked)

      expect(row(chat).claim_token).to be_present
      expect(chats.interrupted).to be_empty
      travel lease + 1
      expect(chats.interrupted).to contain_exactly(chat)
    end

    it 'returns a chat whose run thread was killed as its process exited, right away' do
      chat = asked
      started = Queue.new
      thread = Thread.new do
        job_for(chat) do
          started << true
          sleep
        end.complete
      end
      expect(started.pop(timeout: 10)).to be(true)
      expect(thread.kill.join(10)).to eq(thread)

      expect(row(chat).claim_token).to be_present
      expect(chats.interrupted).to contain_exactly(chat)
    end

    it 'returns a chat whose run a TERM signal stopped, right away' do
      chat = asked

      expect { job_for(chat) { raise SignalException, 'TERM' }.complete }.to raise_error(SignalException)
      expect(row(chat).claim_token).to be_present
      expect(chats.interrupted).to contain_exactly(chat)
    end

    it 'returns a chat whose run an exit stopped, right away' do
      chat = asked

      expect { job_for(chat) { exit }.complete }.to raise_error(SystemExit)
      expect(chats.interrupted).to contain_exactly(chat)
    end

    it 'leaves the claim alone when another process took the chat over before the shutdown' do
      chat = asked
      taken = (lease * 2).from_now.change(usec: 0)
      job = job_for(chat) do
        Chat.where(id: chat.id).update_all(claim_token: 'other', claimed_until: taken)
        raise SignalException, 'TERM'
      end

      expect { job.complete }.to raise_error(SignalException)
      expect(row(chat)).to have_attributes(claim_token: 'other', claimed_until: taken)
      expect(chats.interrupted).to be_empty
    end

    it 'leaves out a chat whose run Ctrl-C stopped, as a stop' do
      chat = asked

      expect { job_for(chat) { raise Interrupt }.complete }.to raise_error(Interrupt)
      expect(row(chat)).to have_attributes(claim_token: nil, claimed_until: nil)
      expect(chats.interrupted).to be_empty
    end

    it 'can run the chat again in the process that kept its claim' do
      chat = asked
      job = job_for(chat) { raise SignalException, 'TERM' }
      expect { job.complete }.to raise_error(SignalException)
      allow(job.to_llm.provider).to receive(:complete).and_return(reply)

      job.complete

      expect(row(chat)).to have_attributes(claim_token: nil, claimed_until: nil)
      expect(job.messages.last.content).to eq('Done')
    end

    it 'returns a chat whose claim expires at this moment' do
      freeze_time
      chat = claim(asked, Time.current)

      expect(chats.interrupted).to contain_exactly(chat)
    end

    it 'leaves out a chat a live run holds' do
      claim(asked, lease.from_now)

      expect(chats.interrupted).to be_empty
    end

    it 'leaves out a chat whose run completed' do
      chat = asked
      job_for(chat).complete

      expect(row(chat)).to have_attributes(claim_token: nil, claimed_until: nil)
      expect(chats.interrupted).to be_empty
    end

    it 'releases the claim of a finished run when stopping its heartbeat fails' do
      chat = asked
      job = job_for(chat)
      allow(job).to receive(:stop_claim_heartbeat).and_wrap_original do |stop|
        stop.call
        raise ThreadError, 'stuck'
      end

      expect { job.complete }.to raise_error(ThreadError)
      expect(row(chat)).to have_attributes(claim_token: nil, claimed_until: nil)
    end

    it 'leaves out a chat whose run paused for an approval' do
      chat = asked
      job = job_for(chat, charge) { calling('charge_card') }
      job.complete

      expect(job.pending_questions).to be_present
      expect(chats.interrupted).to be_empty
    end

    it 'leaves out a chat whose run paused for a question' do
      chat = asked
      job = job_for(chat, seat) { calling('pick_seat') }
      job.complete

      expect(job.pending_questions).to be_present
      expect(chats.interrupted).to be_empty
    end

    it 'leaves out a chat whose run paused on a task' do
      chat = asked
      job = job_for(chat, deploy) { calling('deploy') }
      job.complete

      expect(job.pending_tasks).to be_present
      expect(chats.interrupted).to be_empty
    end

    it 'leaves out a chat whose reply failed, so a refused request is not sent again' do
      with_reply_error_column do
        chat = asked
        failing = job_for(chat) { raise RubyLLM::BadRequestError, 'Refused' }

        expect { failing.complete }.to raise_error(RubyLLM::BadRequestError)
        expect(row(chat).reply_error).to be_present
        travel lease + 1
        expect(chats.interrupted).to be_empty
      end
    end

    it 'leaves out a chat whose run was cancelled' do
      stub_const("#{described_class}::CANCELLATION_POLL_INTERVAL", 0.0)
      chat = asked
      job = job_for(chat) do
        row(chat).cancel
        reply
      end

      expect { job.complete }.to raise_error(RubyLLM::CancelledError)
      expect(chats.interrupted).to be_empty
    end

    it 'leaves out a chat whose job is queued and has not started' do
      asked

      expect(chats.interrupted).to be_empty
    end

    it 'leaves out a chat someone stopped after its run was killed' do
      chat = claim(asked, 1.minute.ago)
      Chat.where(id: chat.id).update_all(cancelled: true)

      expect(chats.interrupted).to be_empty
    end

    it 'reads no messages, so how they store roles and content makes no difference' do
      chat = claim(asked, 1.minute.ago)
      chat.messages.create!(role: :assistant, content: '')
      Message.where(chat_id: chat.id).update_all(role: '1', content: '{"p":"c2VjcmV0","h":{"iv":"aXY="}}')
      queries = []
      record = ->(*, payload) { queries << payload[:sql] }

      found = ActiveSupport::Notifications.subscribed(record, 'sql.active_record') { chats.interrupted.to_a }

      expect(found).to contain_exactly(chat)
      expect(queries.grep(/\bmessages\b/)).to be_empty
    end

    it 'returns none without the claim columns, since no row says whether a run holds a chat' do
      claim(asked, 1.minute.ago)
      allow(Chat).to receive(:column_names).and_return(Chat.column_names - %w[claim_token claimed_until])

      expect(chats.interrupted).to be_empty
    end

    it 'leaves the cancelled flag out without a cancelled column' do
      chat = claim(asked, 1.minute.ago)
      Chat.where(id: chat.id).update_all(cancelled: true)
      allow(Chat).to receive(:column_names).and_return(Chat.column_names - %w[cancelled])

      expect(chats.interrupted).to contain_exactly(chat)
    end

    it 'asks the database each time, even inside the query cache, since other processes write the claims' do
      freeze_time
      claim(asked, 1.minute.ago)
      cached = []
      record = ->(*, payload) { cached << payload[:cached] if payload[:sql].include?('claim_token') }

      ActiveRecord::Base.cache do
        ActiveSupport::Notifications.subscribed(record, 'sql.active_record') { 2.times { chats.interrupted.to_a } }
      end

      expect(cached).to eq([nil, nil])
    end

    it 'composes with other conditions' do
      chat = claim(asked, 1.minute.ago)
      claim(asked, 1.minute.ago)

      expect(Chat.where(id: chat.id).interrupted).to contain_exactly(chat)
      expect(Chat.interrupted.where(id: chat.id)).to contain_exactly(chat)
      expect(Chat.interrupted.merge(chats).count).to eq(2)
      expect(chats.select(:id).interrupted.map(&:id)).to include(chat.id)
    end

    it 'loads in batches' do
      interrupted = Array.new(3) { claim(asked, 1.minute.ago) }
      asked

      expect(chats.interrupted.find_each(batch_size: 2).to_a).to match_array(interrupted)
    end
  end

  it 'keeps the claim of a tool call that was running when its thread was killed at exit' do
    chat = asked
    started = Queue.new
    job = posting_job(chat) do
      started << true
      sleep
    end
    thread = Thread.new { job.complete }
    expect(started.pop(timeout: 10)).to be(true)
    expect(thread.kill.join(10)).to eq(thread)

    expect(tool_call_rows(chat).sole).to have_attributes(result_id: nil, claimed_until: be_present, running?: false)
    expect(chats.interrupted).to contain_exactly(chat)
  end

  # A network database's adapter, such as PostgreSQL's, waits on its socket
  # for every query, which under a fiber scheduler yields to the scheduler.
  # SQLite doesn't, so each query waits on a ready pipe first, as it would.
  def waiting_on_a_socket_for_queries
    reader, writer = IO.pipe
    writer.write('ready')
    socket = Object.new
    socket.define_singleton_method(:start) { |*| reader.wait_readable(1) }
    socket.define_singleton_method(:finish) { |*| nil }
    subscriber = ActiveSupport::Notifications.subscribe('sql.active_record', socket)
    yield
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
    [reader, writer].compact.each(&:close)
  end

  # Whether the fiber that ran each query +pattern+ matches was blocking,
  # keeping its scheduler from running other fibers, while the block runs.
  def blocking_for_updates(pattern, &)
    blocking = []
    record = ->(*, payload) { blocking << Fiber.current.blocking? if payload[:sql].match?(pattern) }
    ActiveSupport::Notifications.subscribed(record, 'sql.active_record', &)
    blocking
  end

  # Solid Queue's fiber workers and Async run a job in a fiber under a fiber
  # scheduler. Once its thread is killed at exit, the fiber is cancelled or
  # never resumed if it yields to the scheduler, as a query does.
  it 'expires the claims of a run in a fiber whose thread was killed at exit, so the chat resumes at once' do
    skip 'async runs on MRI' unless RUBY_ENGINE == 'ruby'
    require 'async'
    chat = asked
    started = Queue.new
    job = posting_job(chat) do
      started << true
      sleep
    end
    thread = Thread.new { Async { |task| task.async { job.complete } } }
    waiting_on_a_socket_for_queries do
      expect(started.pop(timeout: 10)).to be(true)
      expect(thread.kill.join(10)).to eq(thread)
    end

    expect(row(chat)).to have_attributes(claim_token: be_present, claimed_until: be <= Time.current)
    expect(tool_call_rows(chat).sole).to have_attributes(result_id: nil, claimed_until: be <= Time.current)
    expect(chats.interrupted).to contain_exactly(chat)
  end

  # Blocking the fiber would hold up every other fiber on its scheduler.
  it 'releases the claims of a run that finished in a fiber without blocking its scheduler' do
    chat = asked
    job = posting_job(chat) { 'Posted' }
    releases = blocking_for_updates(/\AUPDATE \S+ SET "?claim_token"? = /) { in_reactor { job.complete } }

    expect(releases).to be_present.and(all(be(false)))
    expect(row(chat)).to have_attributes(claim_token: nil, claimed_until: nil)
  end

  it 'releases the claim of a tool call that paused for a question without blocking its scheduler' do
    chat = asked
    job = job_for(chat, seat) { calling('pick_seat') }
    releases = blocking_for_updates(/\AUPDATE \S*ruby_llm_tool_calls\S* SET "?claimed_until"? = /) do
      in_reactor { job.complete }
    end

    expect(job.pending_questions).to be_present
    expect(releases).to be_present.and(all(be(false)))
    expect(tool_call_rows(chat).sole).to have_attributes(result_id: nil, claimed_until: nil)
  end

  it 'releases the claims of a run in a fiber whose reactor Ctrl-C stopped, along with its tool call' do
    skip 'async runs on MRI' unless RUBY_ENGINE == 'ruby'
    require 'async'
    chat = asked
    started = Queue.new
    job = posting_job(chat) do
      started << true
      sleep
    end
    thread = Thread.new { Async { |task| task.async { job.complete } } }
    thread.report_on_exception = false
    waiting_on_a_socket_for_queries do
      expect(started.pop(timeout: 10)).to be(true)
      thread.raise(Interrupt)
      expect { thread.join(10) }.to raise_error(Interrupt)
    end

    expect(row(chat)).to have_attributes(claim_token: nil, claimed_until: nil)
    expect(tool_call_rows(chat).sole).to have_attributes(result_id: nil, claimed_until: nil)
  end

  it 'keeps the expired claim of a tool call that was running when a TERM signal stopped its run' do
    chat = asked
    job = posting_job(chat) { raise SignalException, 'TERM' }

    expect { job.complete }.to raise_error(SignalException)
    expect(tool_call_rows(chat).sole).to have_attributes(result_id: nil, claimed_until: be_present, running?: false)
  end

  it 'expires the claims of the chat and its running tool call on shutdown, so the chat resumes at once' do
    chat = asked
    job = posting_job(chat) { raise SignalException, 'TERM' }

    expect { job.complete }.to raise_error(SignalException)
    expect(row(chat)).to have_attributes(claim_token: be_present, claimed_until: be <= Time.current)
    expect(tool_call_rows(chat).sole.claimed_until).to be <= Time.current
    expect(chats.interrupted).to contain_exactly(chat)
  end

  # A column that keeps whole seconds rounds a fraction up, into the future.
  it 'expires the claims on shutdown to the whole second, which has already passed' do
    travel_to Time.current.change(usec: 900_000), with_usec: true
    chat = asked
    job = posting_job(chat) { raise SignalException, 'TERM' }

    expect { job.complete }.to raise_error(SignalException)
    expect(row(chat).claimed_until).to eq(Time.current.change(usec: 0))
    expect(tool_call_rows(chat).sole.claimed_until).to eq(Time.current.change(usec: 0))
  end

  it 'leaves a free chat alone when a shutdown stops its run before the run claims it' do
    chat = asked
    job = job_for(chat)
    allow(job).to receive(:run_claim_acquired?).and_raise(SignalException, 'TERM')

    expect { job.complete }.to raise_error(SignalException)
    expect(row(chat)).to have_attributes(claim_token: nil, claimed_until: nil)
  end

  it 'leaves the claim of a tool call alone when another process took it over before the shutdown' do
    chat = asked
    taken = (lease * 2).from_now.change(usec: 0)
    job = posting_job(chat) do
      RubyLLM::ActiveRecord::ToolCall.where(message_id: Message.where(chat_id: chat.id).select(:id))
                                     .update_all(claimed_until: taken)
      raise SignalException, 'TERM'
    end

    expect { job.complete }.to raise_error(SignalException)
    expect(tool_call_rows(chat).sole.claimed_until).to eq(taken)
  end

  it 'releases the claim of a tool call that has not started when its run shuts down' do
    chat = asked
    job = posting_job(chat, calls: 2) { raise SignalException, 'TERM' }

    expect { job.complete }.to raise_error(SignalException)
    running, waiting = tool_call_rows(chat)
    expect(running.claimed_until).to be_present
    expect(waiting).to have_attributes(result_id: nil, claimed_until: nil)
  end

  it 'releases the claim of a tool call whose run Ctrl-C stopped, along with the chat' do
    chat = asked
    job = posting_job(chat) { raise Interrupt }

    expect { job.complete }.to raise_error(Interrupt)
    expect(tool_call_rows(chat).sole).to have_attributes(result_id: nil, claimed_until: nil)
    expect(row(chat)).to have_attributes(claim_token: nil, claimed_until: nil)
  end

  it 'releases the claim of a tool call that raised' do
    chat = asked
    job = posting_job(chat) { raise ArgumentError, 'Slack is down' }

    expect { job.complete }.to raise_error(ArgumentError)
    expect(tool_call_rows(chat).sole).to have_attributes(result_id: nil, claimed_until: nil)
    expect(row(chat)).to have_attributes(claim_token: nil, claimed_until: nil)
  end

  it 'releases the claim of a tool call whose run was cancelled while it ran' do
    stub_const("#{described_class}::CANCELLATION_POLL_INTERVAL", 0.0)
    chat = asked
    job = posting_job(chat) do
      row(chat).cancel
      raise RubyLLM::CancelledError
    end

    expect { job.complete }.to raise_error(RubyLLM::CancelledError)
    expect(tool_call_rows(chat).sole.claimed_until).to be_nil
    expect(row(chat).claim_token).to be_nil
  end

  it 'clears the claim of a tool call that completed' do
    chat = asked
    job = posting_job(chat) { 'posted' }

    job.complete
    expect(tool_call_rows(chat).sole).to have_attributes(result_id: be_present, claimed_until: nil)
    expect(row(chat)).to have_attributes(claim_token: nil, claimed_until: nil)
  end
end
