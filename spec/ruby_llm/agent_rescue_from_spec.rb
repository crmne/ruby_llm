# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Agent do
  include_context 'with configured RubyLLM'

  let(:rate_limit) { RubyLLM::RateLimitError.new('slow down') }

  def agent_raising(error, on: :ask, &)
    agent_class = Class.new(described_class) do
      model model_for(:openai, :temperature)
      class_eval(&) if block_given?
    end
    agent = agent_class.new
    allow(agent.chat).to receive(on).and_raise(error)
    agent
  end

  describe 'handler dispatch' do
    it 'calls the named handler with the exception' do
      handled = []
      agent = agent_raising(rate_limit) do
        rescue_from RubyLLM::RateLimitError, with: :handle

        define_method(:handle) do |error|
          handled << error
          :rescued
        end
        private :handle
      end

      expect(agent.ask('hi')).to eq(:rescued)
      expect(handled).to eq([rate_limit])
    end

    it 'calls a zero-arity handler without arguments' do
      agent = agent_raising(rate_limit) do
        rescue_from RubyLLM::RateLimitError, with: :handle

        private

        def handle = :no_args
      end

      expect(agent.ask('hi')).to eq(:no_args)
    end

    it 'runs a block handler in the agent instance' do
      agent = agent_raising(rate_limit) do
        rescue_from(RubyLLM::RateLimitError) { |error| [self.class, chat.class, error.message] }
      end

      expect(agent.ask('hi')).to eq([agent.class, RubyLLM::Chat, 'slow down'])
    end

    it 'registers one handler for each listed exception class' do
      agent = agent_raising(RubyLLM::ServerError.new('boom')) do
        rescue_from RubyLLM::RateLimitError, RubyLLM::ServerError, with: :handle

        private

        def handle(error) = error.class.name
      end

      expect(agent.ask('hi')).to eq('RubyLLM::ServerError')
    end

    it 'matches subclasses of the declared exception class' do
      agent = agent_raising(rate_limit) do
        rescue_from RubyLLM::Error, with: :handle

        private

        def handle(_error) = :base_class
      end

      expect(agent.ask('hi')).to eq(:base_class)
    end

    it 'uses the last matching handler' do
      agent = agent_raising(rate_limit) do
        rescue_from RubyLLM::Error, with: :handle_generic
        rescue_from RubyLLM::RateLimitError, with: :handle_specific

        private

        def handle_generic(_error) = :generic

        def handle_specific(_error) = :specific
      end

      expect(agent.ask('hi')).to eq(:specific)
    end

    it 'resolves exception classes named as strings' do
      agent = agent_raising(rate_limit) do
        rescue_from 'RubyLLM::RateLimitError', with: :handle

        private

        def handle(_error) = :by_name
      end

      expect(agent.ask('hi')).to eq(:by_name)
    end

    it 'rejects classes that can never match a StandardError when they are declared' do
      [Interrupt, Comparable, Integer].each do |klass|
        expect { Class.new(described_class) { rescue_from klass, with: :handle } }
          .to raise_error(ArgumentError, /#{klass} is not a StandardError class/)
      end
    end

    it 'matches StandardErrors with a handler for one of their ancestors, by class or by name' do
      %w[Exception StandardError].flat_map { |name| [name, Object.const_get(name)] }.each do |klass|
        agent = agent_raising(rate_limit) do
          rescue_from klass, with: :handle

          private

          def handle(_error) = :rescued
        end

        expect(agent.ask('hi')).to eq(:rescued)
      end
    end

    it 'ignores handlers whose exception class is not defined' do
      agent = agent_raising(rate_limit) do
        rescue_from 'Namespace::NeverLoadedError', with: :handle

        private

        def handle(_error) = :unreachable
      end

      expect { agent.ask('hi') }.to raise_error(RubyLLM::RateLimitError)
    end

    it 'guards every chat operation that talks to the provider' do
      %i[ask say ask_later complete generate run_tools step count_tokens].each do |operation|
        agent = agent_raising(rate_limit, on: operation) do
          rescue_from RubyLLM::RateLimitError, with: :handle

          private

          def handle(_error) = :rescued
        end

        expect(agent.public_send(operation)).to eq(:rescued)
      end
    end

    it 'leaves unguarded delegated methods alone' do
      agent = agent_raising(rate_limit, on: :add_message) do
        rescue_from RubyLLM::RateLimitError, with: :handle

        private

        def handle(_error) = :rescued
      end

      expect { agent.add_message(role: :user, content: 'hi') }.to raise_error(RubyLLM::RateLimitError)
    end
  end

  describe 're-raising' do
    it 're-raises exceptions no handler matches' do
      agent = agent_raising(RubyLLM::ServerError.new('boom')) do
        rescue_from RubyLLM::RateLimitError, with: :handle

        private

        def handle(_error) = :rescued
      end

      expect { agent.ask('hi') }.to raise_error(RubyLLM::ServerError, 'boom')
    end

    it 're-raises when the agent declares no handlers' do
      agent = agent_raising(rate_limit)

      expect { agent.ask('hi') }.to raise_error(RubyLLM::RateLimitError, 'slow down')
    end

    it 'preserves the original backtrace when re-raising' do
      error = rate_limit
      error.set_backtrace(['app/models/thing.rb:1'])
      agent = agent_raising(error)

      expect { agent.ask('hi') }.to raise_error(RubyLLM::RateLimitError) { |e|
        expect(e.backtrace).to eq(['app/models/thing.rb:1'])
      }
    end

    it 'propagates an exception the handler re-raises' do
      instrumented = []
      agent = agent_raising(rate_limit) do
        rescue_from RubyLLM::RateLimitError, with: :handle

        define_method(:handle) do |error|
          instrumented << error
          raise
        end
        private :handle
      end

      expect { agent.ask('hi') }.to raise_error(RubyLLM::RateLimitError, 'slow down')
      expect(instrumented).to eq([rate_limit])
    end
  end

  describe 'inheritance' do
    it 'inherits handlers declared on the parent' do
      parent = Class.new(described_class) do
        model model_for(:openai, :temperature)
        rescue_from RubyLLM::RateLimitError, with: :handle

        private

        def handle(_error) = :from_parent
      end
      child = Class.new(parent)
      agent = child.new
      allow(agent.chat).to receive(:ask).and_raise(rate_limit)

      expect(agent.ask('hi')).to eq(:from_parent)
    end

    it 'keeps subclass handlers out of the parent' do
      parent = Class.new(described_class) { model model_for(:openai, :temperature) }
      child = Class.new(parent) do
        rescue_from RubyLLM::RateLimitError, with: :handle

        private

        def handle(_error) = :from_child
      end

      child_agent = child.new
      allow(child_agent.chat).to receive(:ask).and_raise(rate_limit)
      parent_agent = parent.new
      allow(parent_agent.chat).to receive(:ask).and_raise(rate_limit)

      expect(child_agent.ask('hi')).to eq(:from_child)
      expect { parent_agent.ask('hi') }.to raise_error(RubyLLM::RateLimitError)
    end

    it 'lets a subclass override an inherited handler' do
      parent = Class.new(described_class) do
        model model_for(:openai, :temperature)
        rescue_from RubyLLM::Error, with: :handle

        private

        def handle(_error) = :from_parent
      end
      child = Class.new(parent) do
        rescue_from RubyLLM::Error, with: :handle_in_child

        private

        def handle_in_child(_error) = :from_child
      end

      agent = child.new
      allow(agent.chat).to receive(:ask).and_raise(rate_limit)

      expect(agent.ask('hi')).to eq(:from_child)
    end
  end

  describe 'chats the class methods build' do
    def agent_handling(error_class = RubyLLM::RateLimitError)
      Class.new(described_class) do
        model model_for(:openai, :temperature)
        inputs :account
        rescue_from error_class, with: :handle

        private

        def handle(error) = [:rescued, error.class]
      end
    end

    def rate_limited(chat)
      allow(chat.instance_variable_get(:@provider)).to receive(:complete).and_raise(rate_limit)
      chat
    end

    it 'runs handlers on a chat from ::chat' do
      chat = rate_limited(agent_handling.chat)

      expect(chat.ask('hi')).to eq([:rescued, RubyLLM::RateLimitError])
    end

    it 'guards every operation of a chat from ::chat' do
      %i[ask say ask_later complete generate run_tools step count_tokens compact].each do |operation|
        chat = agent_handling.chat
        allow(chat).to receive(:rescuing_with).and_return(:guarded)

        expect(chat.public_send(operation)).to eq(:guarded)
      end
    end

    it 'leaves a chat alone when the agent declares no handlers' do
      chat = rate_limited(Class.new(described_class) { model model_for(:openai, :temperature) }.chat)

      expect { chat.ask('hi') }.to raise_error(RubyLLM::RateLimitError)
    end

    it 're-raises errors no handler matches on a chat from ::chat' do
      chat = rate_limited(agent_handling(RubyLLM::ServerError).chat)

      expect { chat.ask('hi') }.to raise_error(RubyLLM::RateLimitError)
    end

    it 'runs handlers on a call chained from a delegated setter' do
      agent = agent_handling.new
      rate_limited(agent.chat)

      expect(agent.with_temperature(0.1).ask('hi')).to eq([:rescued, RubyLLM::RateLimitError])
    end

    it 'runs a re-raising handler once, at the outermost operation' do
      handled = []
      klass = agent_handling
      klass.rescue_from(RubyLLM::RateLimitError) do |error|
        handled << error
        raise error
      end
      agent = klass.new
      rate_limited(agent.chat)

      expect { agent.ask('hi') }.to raise_error(RubyLLM::RateLimitError)
      expect { agent.chat.ask('hi') }.to raise_error(RubyLLM::RateLimitError)
      expect(handled).to eq([rate_limit, rate_limit])
    end

    it 'rescues again on the next operation' do
      chat = rate_limited(agent_handling.chat)

      chat.ask('first')

      expect(chat.complete).to eq([:rescued, RubyLLM::RateLimitError])
    end

    it 'guards an operation a handler retries' do
      attempts = 0
      klass = agent_handling
      klass.rescue_from(RubyLLM::RateLimitError) do |error|
        attempts += 1
        attempts == 1 ? chat.complete : error.class
      end
      chat = rate_limited(klass.chat)

      expect(chat.ask('hi')).to eq(RubyLLM::RateLimitError)
      expect(attempts).to eq(2)
    end

    it 'gives handlers on a chat from ::chat its inputs and the chat' do
      klass = agent_handling
      klass.rescue_from(RubyLLM::RateLimitError) { [account, chat, self.class] }
      built = rate_limited(klass.chat(account: 'acme'))

      expect(built.ask('hi')).to eq(['acme', built, klass])
    end

    it 'gives handlers on an instance the inputs passed to ::new' do
      klass = agent_handling
      klass.rescue_from(RubyLLM::RateLimitError) { [account, self] }
      agent = klass.new(account: 'acme')
      rate_limited(agent.chat)

      expect(agent.chat.ask('hi')).to eq(['acme', agent])
    end

    it 'keeps delegated readers when an input shares their name' do
      klass = Class.new(described_class) do
        model model_for(:openai, :temperature)
        inputs :temperature
      end

      expect(klass.new(temperature: 2).temperature).to be_nil
    end

    it 'runs handlers on an object that only quacks like a chat' do
      error = rate_limit
      quacking = Class.new { define_method(:ask) { |_message| raise error } }.new
      agent = Class.new(described_class) { rescue_from(RubyLLM::RateLimitError) { :rescued } }.new(chat: quacking)

      expect(agent.ask('hi')).to eq(:rescued)
    end

    it 'stops rescuing a chat rewrapped by an agent without handlers' do
      chat = rate_limited(agent_handling.chat)
      Class.new(described_class).new(chat:)

      expect { chat.ask('hi') }.to raise_error(RubyLLM::RateLimitError)
    end

    it 'runs handlers on a copy of the chat' do
      chat = rate_limited(agent_handling.chat)

      expect(chat.dup.ask('hi')).to eq([:rescued, RubyLLM::RateLimitError])
    end

    it 'keeps the transcript of a copy apart from the original' do
      chat = rate_limited(agent_handling.chat)

      chat.dup.ask('hi')

      expect(chat.messages).to be_empty
    end

    it 'runs handlers on a copy made during an operation' do
      chat = agent_handling.chat
      copy = nil
      allow(chat.instance_variable_get(:@provider)).to receive(:complete) do
        copy ||= chat.dup
        raise rate_limit
      end

      chat.ask('hi')

      expect(copy.complete).to eq([:rescued, RubyLLM::RateLimitError])
    end
  end

  describe 'argument checking' do
    it 'requires a handler' do
      expect do
        Class.new(described_class) { rescue_from RubyLLM::Error }
      end.to raise_error(ArgumentError, /needs a handler/)
    end

    it 'rejects both a with: handler and a block' do
      expect do
        Class.new(described_class) { rescue_from(RubyLLM::Error, with: :handle) { :block } }
      end.to raise_error(ArgumentError, /not both/)
    end

    it 'rejects values that are neither a class nor a class name' do
      expect do
        Class.new(described_class) { rescue_from 42, with: :handle }
      end.to raise_error(ArgumentError, /not a StandardError class or its name/)
    end
  end
end
