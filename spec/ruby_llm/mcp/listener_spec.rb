# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::MCP::Listener do
  let(:callback) { ->(_notification) {} }
  let(:client) { scripted_client(script) }
  let(:listener) { described_class.new(client, name: 'files', timeout: 2, &callback) }
  let(:script) do
    lambda do |_attempt, notify|
      notify[acknowledgment]
      sleep
    end
  end

  after { listener.stop }

  def tools
    { toolsListChanged: true }
  end

  def acknowledgment(honored = { 'toolsListChanged' => true })
    { 'method' => 'notifications/subscriptions/acknowledged', 'params' => { 'notifications' => honored } }
  end

  # A client whose subscriptions each play out +script+ with their number,
  # counted from 1, and a way to send the listener notifications.
  def scripted_client(script)
    Class.new do
      attr_reader :attempts, :cancelled

      define_method(:initialize) do
        @attempts = []
        @cancelled = []
      end

      define_method(:listen) do |changes, &on_notification|
        @attempts << changes
        script.call(@attempts.size, on_notification)
      rescue RubyLLM::CancelledError
        @cancelled << @attempts.size
        raise
      end
    end.new
  end

  def eventually
    Timeout.timeout(5) { sleep 0.01 until yield }
  end

  it 'returns once the server acknowledges, with what it agreed to send' do
    expect(listener.start(tools)).to eq('toolsListChanged' => true)
    expect(client.attempts).to eq([tools])
  end

  it 'keeps a subscription for the same changes and replaces it for others' do
    lists = tools.merge(promptsListChanged: true)

    2.times { listener.start(tools) }
    listener.start(lists)

    expect(client.attempts).to eq([tools, lists])
    expect(client.cancelled).to eq([1])
  end

  it 'does nothing when there is nothing to listen for' do
    expect(listener.start({})).to be_nil
    expect(client.attempts).to be_empty
  end

  context 'when a callback is running' do
    let(:steps) { Queue.new }
    let(:script) do
      lambda do |_attempt, notify|
        notify[acknowledgment]
        notify['method' => 'notifications/tools/list_changed']
        sleep
      end
    end
    let(:callback) do
      lambda do |notification|
        next unless notification['method'] == 'notifications/tools/list_changed'

        steps << :started
        sleep 0.2
        steps << :finished
      end
    end

    it 'lets it finish before stopping' do
      listener.start(tools)
      Timeout.timeout(5) { steps.pop }

      listener.stop

      expect(steps.size).to eq(1)
      expect(steps.pop).to eq(:finished)
      expect(client.cancelled).to eq([1])
    end
  end

  context 'when started while a chat follows tool progress' do
    let(:listeners) { Queue.new }
    let(:callback) { ->(_notification) { listeners << RubyLLM::Support::ProgressReporter.listener } }

    it 'reports nothing to that chat' do
      RubyLLM::Support::ProgressReporter.listen(->(_progress) {}) { listener.start(tools) }

      expect(listeners.pop).to be_nil
    end
  end

  context 'when started on behalf of a usage owner' do
    let(:owners) { Queue.new }
    let(:callback) { ->(_notification) { owners << RubyLLM::Accounting::Usage.owner } }

    it 'attributes nothing to that owner' do
      RubyLLM.with_owner('alice') { listener.start(tools) }

      expect(owners.pop).to be_nil
    end
  end

  context 'when started inside a cancellable operation' do
    let(:observed) { Queue.new }
    let(:callback) do
      lambda do |_notification|
        RubyLLM::Support::Cancellation.check
        observed << Fiber[:listener_spec_context]
        RubyLLM::Support::Cancellation.watch(-> { observed << :local }) do
          RubyLLM::Support::Cancellation.check
        end
      end
    end

    it 'clears the inherited checkpoint and preserves unrelated storage' do
      Fiber[:listener_spec_context] = :preserved
      RubyLLM::Support::Cancellation.watch(-> { observed << :inherited }) { listener.start(tools) }
      listener.stop

      expect(Array.new(observed.size) { observed.pop }).to eq(%i[preserved local])
      expect(client.cancelled).to eq([1])
    ensure
      Fiber[:listener_spec_context] = nil
    end
  end

  context 'with Rails loaded' do
    let(:executor) do
      Class.new do
        def runs = @runs ||= []

        def wrap
          runs << :wrapped
          yield
        end
      end.new
    end

    before do
      application = Struct.new(:executor).new(executor)
      stub_const('Rails', Class.new { define_singleton_method(:application) { application } })
    end

    it 'runs callbacks in the executor' do
      listener.start(tools)

      expect(executor.runs).to eq([:wrapped])
    end
  end

  context 'when started inside a workflow' do
    let(:workflows) { Queue.new }
    let(:callback) { ->(_notification) { workflows << RubyLLM::Support::Instrumentation.current_workflow } }

    it 'clears the inherited workflow on every start' do
      RubyLLM.workflow('Request', id: 'request-1') do
        listener.start(tools)
        listener.stop
        listener.start(tools)
      end

      expect(Array.new(2) { Timeout.timeout(2) { workflows.pop } }).to eq([nil, nil])
      expect(client.attempts.size).to eq(2)
    end
  end

  context 'with a server that refuses the subscription' do
    let(:script) { ->(*) { raise RubyLLM::MCP::Error, 'Unauthorized' } }

    it 'raises why' do
      expect { listener.start(tools) }.to raise_error(RubyLLM::MCP::Error, 'Unauthorized')
      expect(client.attempts.size).to eq(1)
    end
  end

  context 'with a server that never acknowledges' do
    let(:listener) { described_class.new(client, name: 'files', timeout: 0.2, &callback) }
    let(:script) { ->(*) { sleep } }

    it 'raises and cancels the subscription' do
      expect { listener.start(tools) }.to raise_error(RubyLLM::MCP::Error, /did not acknowledge/)
      expect(client.cancelled).to eq([1])
    end
  end

  describe '#listen' do
    before do
      allow(listener).to receive(:sleep)
      allow(RubyLLM.logger).to receive(:warn)
    end

    context 'when the server ends the subscription for good' do
      let(:script) do
        lambda do |attempt, notify|
          notify[acknowledgment(attempt == 1 ? { 'toolsListChanged' => true } : {})]
        end
      end

      it 'listens in the calling thread until then' do
        threads = Thread.list.size

        expect(listener.listen(tools)).to be_nil
        expect(Thread.list.size).to eq(threads)
        expect(client.attempts.size).to eq(2)
      end
    end

    context 'when the server never acknowledges' do
      let(:script) { ->(*) { raise RubyLLM::MCP::Error, 'Unauthorized' } }

      it 'raises why' do
        expect { listener.listen(tools) }.to raise_error(RubyLLM::MCP::Error, 'Unauthorized')
        expect(client.attempts.size).to eq(1)
      end
    end

    context 'when the server will not watch a resource' do
      it 'raises and cancels the subscription' do
        expect { listener.listen(tools.merge(resourceSubscriptions: ['file:///notes.md'])) }
          .to raise_error(RubyLLM::MCP::Error, 'files does not send updates for file:///notes.md')
        expect(client.cancelled).to eq([1])
      end
    end

    context 'when a resource and a task share a name and the server watches only one' do
      let(:script) { ->(_attempt, notify) { notify[acknowledgment('resourceSubscriptions' => ['report'])] } }

      it 'raises for the other' do
        expect { listener.listen(resourceSubscriptions: ['report'], taskIds: ['report']) }
          .to raise_error(RubyLLM::MCP::Error, 'files does not send updates for report')
      end
    end

    context 'when the caller is cancelled' do
      let(:script) { ->(*) { raise RubyLLM::CancelledError } }

      it 'raises the cancellation' do
        expect { listener.listen(tools) }.to raise_error(RubyLLM::CancelledError)
        expect(client.cancelled).to eq([1])
      end
    end
  end

  context 'when a subscription resumes' do
    let(:resumes) { Queue.new }
    let(:listener) do
      described_class.new(client, name: 'files', timeout: 2, resumed: ->(listened) { resumes << listened }, &callback)
    end
    let(:script) do
      lambda do |attempt, notify|
        notify[acknowledgment]
        sleep if attempt == 2
      end
    end

    it 'reports what it listens to, since changes in between are lost' do
      allow(listener).to receive(:sleep)
      allow(RubyLLM.logger).to receive(:warn)

      listener.start(tools)

      expect(Timeout.timeout(5) { resumes.pop }).to eq('toolsListChanged' => true)
      expect(client.attempts.size).to eq(2)
      expect(resumes).to be_empty
    end

    context 'with several resources, one of which fails to catch up' do
      def watched
        { resourceSubscriptions: ['file:///a', 'file:///b'] }
      end

      let(:script) do
        lambda do |attempt, notify|
          notify[acknowledgment('toolsListChanged' => true, **watched.transform_keys(&:to_s))]
          sleep if attempt == 2
        end
      end
      let(:listener) do
        resumed = lambda do |listened|
          raise 'boom' if listened == { 'resourceSubscriptions' => ['file:///a'] }

          resumes << listened
        end
        described_class.new(client, name: 'files', timeout: 2, resumed:, &callback)
      end

      it 'catches up with the rest' do
        allow(listener).to receive(:sleep)
        allow(RubyLLM.logger).to receive_messages(warn: nil, error: nil)

        listener.start(tools.merge(watched))

        expect(Array.new(2) { Timeout.timeout(5) { resumes.pop } })
          .to eq([{ 'toolsListChanged' => true }, { 'resourceSubscriptions' => ['file:///b'] }])
        expect(RubyLLM.logger).to have_received(:error).once
      end
    end
  end

  context 'when a subscription ends' do
    let(:delays) { [] }

    before do
      allow(listener).to receive(:sleep) { |seconds| delays << seconds }
      allow(RubyLLM.logger).to receive(:warn)
    end

    context 'with a server that ends each subscription' do
      let(:script) do
        lambda do |attempt, notify|
          notify[acknowledgment]
          sleep if attempt == 10
        end
      end

      it 'subscribes again, waiting longer each time up to a minute' do
        listener.start(tools)
        eventually { client.attempts.size == 10 }

        expect(delays.zip([1, 2, 4, 8, 16, 32, 60, 60, 60]))
          .to all(satisfy { |delay, limit| delay.between?(limit / 2.0, limit) })
        expect(RubyLLM.logger).to have_received(:warn).exactly(9).times
      end
    end

    context 'with a server that agrees to send nothing' do
      let(:script) { ->(_attempt, notify) { notify[acknowledgment({})] } }

      it 'stops' do
        expect(listener.start(tools)).to eq({})
        sleep 0.1

        expect(client.attempts.size).to eq(1)
      end
    end

    context 'with a server that does not know the method' do
      let(:script) do
        lambda do |_attempt, notify|
          notify[acknowledgment]
          raise RubyLLM::MCP::Error.new('Method not found', code: -32_601)
        end
      end

      it 'stops' do
        listener.start(tools)
        sleep 0.1

        expect(client.attempts.size).to eq(1)
      end
    end
  end
end
