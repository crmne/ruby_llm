# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Test do
  describe 'registering models' do
    it 'findable by provider' do
      expect(test_provider_models.all).to all(have_attributes(provider: 'test', type: 'chat'))
    end

    it 'findable by model (globally)' do
      found = RubyLLM.models.find('test')

      expect(found).to have_attributes(id: 'test', provider: 'test')
    end

    it 'findable by model ID within provider-specific list' do
      found = RubyLLM.models.by_provider('test').find('test')

      expect(found).to have_attributes(id: 'test', provider: 'test')
    end

    context 'when models are refreshed' do
      before { RubyLLM.models.refresh! }

      it 'finds model by ID within provider-specific list after refresh' do
        test_model = RubyLLM.models.by_provider('test').find('test')

        expect(test_model).to have_attributes(id: 'test', provider: 'test')
      end
    end
  end

  describe 'create chat with test model' do
    subject { RubyLLM.chat(model: 'test') }

    it 'creates a chat with the test model without provider specified' do
      expect(subject.model).to have_attributes(id: 'test', provider: 'test')
    end

    it 'creates a chat with the test model when provider is specified' do
      expect(RubyLLM.chat(model: 'test', provider: 'test').model)
        .to have_attributes(id: 'test', provider: 'test')
    end

    it 'gets sample message from chat' do
      expect(subject.ask('Hello').content).to eq('Default response from TestProvider')
    end
  end
end

