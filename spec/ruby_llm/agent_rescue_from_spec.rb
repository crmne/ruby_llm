# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Agent do
  include_context 'with configured RubyLLM'

  let(:rate_limit) { RubyLLM::RateLimitError.new('slow down') }

  def agent_raising(error, on: :ask, &)
    agent_class = Class.new(described_class) do
      model 'gpt-4.1-nano'
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

    it 'ignores handlers whose exception class is not defined' do
      agent = agent_raising(rate_limit) do
        rescue_from 'Namespace::NeverLoadedError', with: :handle

        private

        def handle(_error) = :unreachable
      end

      expect { agent.ask('hi') }.to raise_error(RubyLLM::RateLimitError)
    end

    it 'guards every chat operation that talks to the provider' do
      %i[ask say ask_later complete generate run_tools step].each do |operation|
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
        model 'gpt-4.1-nano'
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
      parent = Class.new(described_class) { model 'gpt-4.1-nano' }
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
        model 'gpt-4.1-nano'
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
      end.to raise_error(ArgumentError, /not an exception class/)
    end
  end
end
