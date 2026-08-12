# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Agent do
  include_context 'with configured RubyLLM'

  describe 'configuration readers' do
    let(:agent_class) do
      Class.new(described_class) do
        model 'gpt-4.1-nano', provider: :openai
        temperature 0.4
        max_output_tokens 128
        thinking effort: :low
        citations true
        caching ttl: '1h'
        provider_options top_p: 0.9
        headers 'X-Test' => '1'
      end
    end

    it 'returns what each macro was given' do
      expect(agent_class.model).to eq(model: 'gpt-4.1-nano', provider: :openai)
      expect(agent_class.temperature).to eq(0.4)
      expect(agent_class.max_output_tokens).to eq(128)
      expect(agent_class.thinking).to eq(effort: :low, budget: nil, display: nil)
      expect(agent_class.citations).to be(true)
      expect(agent_class.caching).to eq(ttl: '1h')
      expect(agent_class.provider_options).to eq(top_p: 0.9)
      expect(agent_class.headers).to eq('X-Test' => '1')
    end

    it 'defaults the collection macros to empty' do
      bare = Class.new(described_class)

      expect(bare.model).to eq({})
      expect(bare.temperature).to be_nil
      expect(bare.thinking).to be_nil
      expect(bare.citations).to be_nil
      expect(bare.caching).to be_nil
      expect(bare.provider_options).to eq({})
      expect(bare.headers).to eq({})
      expect(bare.context).to be_nil
      expect(bare.chat_model).to be_nil
    end

    it 'accepts model options without a model id' do
      agent = Class.new(described_class) do
        model provider: :openai, assume_model_exists: true
      end

      expect(agent.model).to eq(provider: :openai, assume_model_exists: true)
    end

    it 'applies the configured options to a new chat' do
      chat = agent_class.chat

      expect(chat.instance_variable_get(:@temperature)).to eq(0.4)
      expect(chat.instance_variable_get(:@max_output_tokens)).to eq(128)
      expect(chat.instance_variable_get(:@citations)).to be(true)
      expect(chat.instance_variable_get(:@caching)).to eq(ttl: '1h')
      expect(chat.instance_variable_get(:@provider_options)).to eq(top_p: 0.9)
      expect(chat.instance_variable_get(:@headers)).to eq('X-Test' => '1')
      expect(chat.instance_variable_get(:@thinking).effort).to eq('low')
    end

    it 'binds a configured context to the chat it builds' do
      context = RubyLLM.context { |config| config.request_timeout = 42 }
      agent = Class.new(described_class) do
        model 'gpt-4.1-nano', provider: :openai
      end
      agent.context(context)

      expect(agent.context).to eq(context)
      expect(agent.chat.provider.config.request_timeout).to eq(42)
    end
  end

  describe 'deferred configuration blocks' do
    it 'evaluates caching, provider options and headers when the chat is built' do
      agent = Class.new(described_class) do
        model 'gpt-4.1-nano', provider: :openai
        inputs :tenant

        caching { { ttl: tenant } }
        provider_options { { user: tenant } }
        headers { { 'X-Tenant' => tenant } }
      end

      chat = agent.chat(tenant: 'acme')

      expect(chat.instance_variable_get(:@caching)).to eq(ttl: 'acme')
      expect(chat.instance_variable_get(:@provider_options)).to eq(user: 'acme')
      expect(chat.instance_variable_get(:@headers)).to eq('X-Tenant' => 'acme')
    end

    it 'picks the model when the chat is built' do
      agent = Class.new(described_class) do
        inputs :quality

        model { quality == :high ? 'gpt-4.1-mini' : 'gpt-4.1-nano' }
      end

      expect(agent.chat(quality: :high).model.id).to eq('gpt-4.1-mini')
      expect(agent.chat(quality: :low).model.id).to eq('gpt-4.1-nano')
    end

    it 'keeps the model options alongside a model block' do
      agent = Class.new(described_class) do
        inputs :quality

        model(provider: :openai) { quality == :high ? 'gpt-4.1-mini' : 'gpt-4.1-nano' }
      end

      expect(agent.model[:provider]).to eq(:openai)
      expect(agent.model[:model]).to be_a(Proc)
      expect(agent.chat(quality: :high).model.id).to eq('gpt-4.1-mini')
    end

    it 'picks the model for agent instances too' do
      agent = Class.new(described_class) do
        inputs :quality

        model { quality == :high ? 'gpt-4.1-mini' : 'gpt-4.1-nano' }
      end

      expect(agent.new(quality: :high).model.id).to eq('gpt-4.1-mini')
      expect(agent.new(inputs: { quality: :low }).model.id).to eq('gpt-4.1-nano')
    end

    it 'leaves the chat alone when a block returns nothing' do
      agent = Class.new(described_class) do
        model 'gpt-4.1-nano', provider: :openai

        caching { nil }
        provider_options { {} }
        headers { {} }
      end

      chat = agent.chat

      expect(chat.instance_variable_get(:@caching)).to be_nil
      expect(chat.instance_variable_get(:@provider_options)).to eq({})
      expect(chat.instance_variable_get(:@headers)).to eq({})
    end
  end

  describe 'inputs' do
    it 'separates declared inputs from chat options' do
      agent = Class.new(described_class) do
        model 'gpt-4.1-nano', provider: :openai
        inputs :tenant
      end

      expect(agent.inputs).to eq([:tenant])
      expect(agent.send(:partition_inputs, { tenant: 'acme', temperature: 0.1 })).to eq(
        [{ tenant: 'acme' }, { temperature: 0.1 }]
      )
    end
  end

  describe 'Rails mode' do
    it 'requires a chat model for find' do
      expect { Class.new(described_class).find(1) }.to raise_error(
        ArgumentError, 'chat_model must be configured to use find'
      )
    end

    it 'requires a chat model for create' do
      expect { Class.new(described_class).create }.to raise_error(
        ArgumentError, 'chat_model must be configured to use create/create!'
      )
      expect { Class.new(described_class).create! }.to raise_error(
        ArgumentError, 'chat_model must be configured to use create/create!'
      )
    end

    it 'resolves a chat model named as a string' do
      stub_const('StringNamedChat', Class.new)
      agent = Class.new(described_class)
      agent.chat_model 'StringNamedChat'

      expect(agent.chat_model).to eq('StringNamedChat')
      expect(agent.send(:resolved_chat_model)).to eq(StringNamedChat)
    end

    it 'forgets the resolved class when the configured one changes' do
      stub_const('FirstChat', Class.new)
      stub_const('SecondChat', Class.new)
      agent = Class.new(described_class)
      agent.chat_model 'FirstChat'
      agent.send(:resolved_chat_model)

      agent.chat_model 'SecondChat'

      expect(agent.send(:resolved_chat_model)).to eq(SecondChat)
    end
  end

  describe 'inheritance' do
    it 'copies configuration that cannot be duplicated' do
      parent = Class.new(described_class) do
        model 'gpt-4.1-nano', provider: :openai
        temperature 0.2
        citations true
      end

      child = Class.new(parent)

      expect(child.temperature).to eq(0.2)
      expect(child.citations).to be(true)
      expect(child.model).to eq(model: 'gpt-4.1-nano', provider: :openai)
      expect(child.model).not_to equal(parent.model)
    end
  end

  describe 'prompt paths' do
    it 'underscores the class name into a prompt directory' do
      stub_const('Support::BillingAgent', Class.new(described_class))

      expect(Support::BillingAgent.send(:prompt_agent_path)).to eq('support/billing_agent')
    end

    it 'falls back to a generic directory for anonymous agents' do
      expect(Class.new(described_class).send(:prompt_agent_path)).to eq('agent')
    end
  end
end
