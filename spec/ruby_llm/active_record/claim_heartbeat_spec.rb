# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RubyLLM::ActiveRecord::ClaimHeartbeat do
  include_context 'with configured RubyLLM'

  let(:interval) { 2 }
  let(:chat) { Chat.create!(model: model_for(:openai)) }
  let(:heartbeat) { described_class.new([HeartbeatChat], interval) { renew } }
  let(:holding) { Queue.new }
  let(:ticks) { [] }

  before do
    stub_const('HeartbeatChat', Class.new(ActiveRecord::Base) { self.table_name = 'chats' })
    HeartbeatChat.establish_connection(ActiveRecord::Base.connection_db_config.configuration_hash.merge(pool: 1))
    wait_as_rails_does
  end

  after do
    heartbeat.stop
    HeartbeatChat.remove_connection
  end

  # The dummy app waits for SQLite without holding the GVL on every Rails
  # version. Before Rails 8, Rails itself waits through busy_timeout.
  def wait_as_rails_does
    return unless before_rails8?

    timeout = HeartbeatChat.connection_db_config.configuration_hash[:timeout].to_i
    HeartbeatChat.connection_pool.with_connection { |connection| connection.raw_connection.busy_timeout(timeout) }
  end

  def before_rails8?
    ActiveRecord.version < Gem::Version.new('8.0')
  end

  def renew
    HeartbeatChat.where(id: chat.id).update_all(claimed_until: 1.minute.from_now)
  end

  def holding_write_lock(seconds)
    holder = Thread.new do
      Chat.transaction do
        Chat.where(id: chat.id).update_all(updated_at: Time.current)
        holding << true
        sleep seconds
      end
    end
    holding.pop
    yield
  ensure
    holder&.join
  end

  def ticking
    ticker = Thread.new do
      loop do
        ticks << Process.clock_gettime(Process::CLOCK_MONOTONIC)
        sleep 0.01
      end
    end
    yield
  ensure
    ticker&.kill&.join
  end

  def timed_beat
    ticks << Process.clock_gettime(Process::CLOCK_MONOTONIC)
    ticking { heartbeat.send(:beat) }
    ticks << Process.clock_gettime(Process::CLOCK_MONOTONIC)
    ticks.last - ticks.first
  end

  def longest_stall
    ticks.each_cons(2).map { |earlier, later| later - earlier }.max
  end

  it 'renews once the run commits, without stopping the process while it waits' do
    elapsed = holding_write_lock(0.1) { timed_beat }

    expect(elapsed).to be < 0.4
    expect(longest_stall).to be < 0.15
    expect(HeartbeatChat.find(chat.id).claimed_until).to be > 30.seconds.from_now
  end

  context 'when the database stays locked past the wait' do
    before { skip 'Rails 8 waits for SQLite without holding the GVL' unless before_rails8? }

    it 'skips the beat after a quarter of its interval, without stopping the process' do
      elapsed = holding_write_lock(interval * 0.5) { timed_beat }

      expect(elapsed).to be_within(0.2).of(interval / 4.0)
      expect(longest_stall).to be < 0.15
      expect(HeartbeatChat.find(chat.id).claimed_until).to be_nil
    end

    it 'warns once beats are skipped twice in a row' do
      allow(RubyLLM.logger).to receive(:warn)

      holding_write_lock(interval * 0.4) { heartbeat.send(:beat) }
      expect(RubyLLM.logger).not_to have_received(:warn)

      holding_write_lock(interval * 0.4) { heartbeat.send(:beat) }
      expect(RubyLLM.logger).to have_received(:warn).with(/2 in a row/)
    end

    it 'counts skips again from a beat that renews' do
      allow(RubyLLM.logger).to receive(:warn)

      holding_write_lock(interval * 0.4) { heartbeat.send(:beat) }
      heartbeat.send(:beat)
      holding_write_lock(interval * 0.4) { heartbeat.send(:beat) }

      expect(RubyLLM.logger).not_to have_received(:warn)
    end
  end

  it 'warns at the first beat that fails for another reason' do
    allow(RubyLLM.logger).to receive(:warn)
    failing = described_class.new([HeartbeatChat], interval) { raise ActiveRecord::ConnectionNotEstablished, 'gone' }

    failing.send(:beat)
    failing.stop

    expect(RubyLLM.logger).to have_received(:warn).with(/\(1 in a row\).*gone/)
  end

  def raw_connection
    HeartbeatChat.connection_pool.with_connection(&:raw_connection)
  end

  it 'reconnects before another query can use the connection it waited on' do
    skip 'Rails 8 waits for SQLite without holding the GVL' unless before_rails8?
    waited_on = raw_connection

    heartbeat.send(:beat)

    expect(raw_connection).not_to equal(waited_on)
  end

  it 'keeps a connection to another database' do
    connection = raw_connection
    HeartbeatChat.connection_pool.with_connection do |pooled|
      allow(pooled).to receive(:adapter_name).and_return('PostgreSQL')
    end

    heartbeat.send(:beat)

    expect(raw_connection).to equal(connection)
  end

  it 'keeps an in-memory database' do
    stub_const('HeartbeatMemory', Class.new(ActiveRecord::Base) { self.table_name = 'beats' })
    HeartbeatMemory.establish_connection(adapter: 'sqlite3', database: ':memory:', pool: 1)
    HeartbeatMemory.connection_pool.with_connection { |memory| memory.create_table(:beats) }
    in_memory = described_class.new([HeartbeatMemory], interval) { HeartbeatMemory.create! }

    in_memory.send(:beat)
    in_memory.stop

    expect(HeartbeatMemory.count).to eq(1)
  ensure
    HeartbeatMemory.remove_connection
  end

  it 'keeps the connection on Rails 8' do
    skip 'Rails before 8 waits for SQLite holding the GVL' if before_rails8?
    connection = raw_connection

    heartbeat.send(:beat)

    expect(raw_connection).to equal(connection)
  end
end
