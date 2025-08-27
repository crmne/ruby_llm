# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::ActiveRecord::ActsAs do
  include_context 'with configured RubyLLM'

  describe 'acts_as_model' do
    let(:model_class) do
      stub_const('TestModel', Class.new(ActiveRecord::Base) do
        self.table_name = 'models'
        acts_as_model
      end)
    end

    let(:model_info) do
      RubyLLM::Model::Info.new(
        id: 'gpt-4',
        name: 'GPT-4',
        provider: 'openai',
        family: 'gpt4',
        created_at: Time.now,
        context_window: 128_000,
        max_output_tokens: 4096,
        knowledge_cutoff: Date.new(2023, 4, 1),
        modalities: { input: %w[text image], output: %w[text] },
        capabilities: %w[function_calling streaming vision],
        pricing: { text_tokens: { input: 10, output: 30 } },
        metadata: { version: '1.0' }
      )
    end

    before do
      ActiveRecord::Schema.define do
        create_table :models, force: true do |t|
          t.string :model_id, null: false
          t.string :name, null: false
          t.string :provider, null: false
          t.string :family
          t.datetime :model_created_at
          t.integer :context_window
          t.integer :max_output_tokens
          t.date :knowledge_cutoff
          t.json :modalities, default: {}
          t.json :capabilities, default: []
          t.json :pricing, default: {}
          t.json :metadata, default: {}
          t.timestamps
        end
      end
    end

    describe 'model persistence' do
      it 'syncs models from RubyLLM registry' do
        allow(RubyLLM.models).to receive(:refresh!)
        allow(RubyLLM.models).to receive(:all).and_return([model_info])

        expect { model_class.refresh! }.to change(model_class, :count).from(0).to(1)

        model = model_class.last
        expect(model.model_id).to eq('gpt-4')
        expect(model.name).to eq('GPT-4')
        expect(model.provider).to eq('openai')
      end

      it 'updates existing models on sync' do
        model_class.create!(
          model_id: 'gpt-4',
          name: 'Old Name',
          provider: 'openai'
        )

        allow(RubyLLM.models).to receive(:refresh!)
        allow(RubyLLM.models).to receive(:all).and_return([model_info])

        expect { model_class.refresh! }.not_to(change(model_class, :count))

        model = model_class.last
        expect(model.name).to eq('GPT-4')
      end
    end

    describe 'conversions' do
      let(:model) do
        model_class.create!(
          model_id: 'gpt-4',
          name: 'GPT-4',
          provider: 'openai',
          family: 'gpt4',
          model_created_at: Time.now,
          context_window: 128_000,
          max_output_tokens: 4096,
          knowledge_cutoff: Date.new(2023, 4, 1),
          modalities: { input: %w[text image], output: %w[text] },
          capabilities: %w[function_calling streaming vision],
          pricing: { text_tokens: { input: 10, output: 30 } },
          metadata: { version: '1.0' }
        )
      end

      it 'converts to Model::Info with to_llm' do
        result = model.to_llm
        expect(result).to be_a(RubyLLM::Model::Info)
        expect(result.id).to eq('gpt-4')
        expect(result.name).to eq('GPT-4')
        expect(result.provider).to eq('openai')
      end

      it 'creates from Model::Info with from_llm' do
        model = model_class.from_llm(model_info)
        expect(model.model_id).to eq('gpt-4')
        expect(model.name).to eq('GPT-4')
        expect(model.provider).to eq('openai')
      end
    end

    describe 'delegated methods' do
      let(:model) do
        model_class.create!(
          model_id: 'gpt-4',
          name: 'GPT-4',
          provider: 'openai',
          modalities: { input: %w[text image], output: %w[text] },
          capabilities: %w[function_calling streaming vision]
        )
      end

      it 'delegates capability checks' do
        expect(model.supports?('function_calling')).to be true
        expect(model.supports?('batch')).to be false
        expect(model.supports_vision?).to be true
        expect(model.supports_functions?).to be true
        expect(model.function_calling?).to be true
        expect(model.streaming?).to be true
      end

      it 'delegates type detection' do
        expect(model.type).to eq('chat')
      end
    end

    describe 'validations' do
      it 'requires model_id, name, and provider' do
        model = model_class.new
        expect(model).not_to be_valid
        expect(model.errors[:model_id]).to include("can't be blank")
        expect(model.errors[:name]).to include("can't be blank")
        expect(model.errors[:provider]).to include("can't be blank")
      end

      it 'enforces uniqueness of model_id within provider scope' do
        model_class.create!(model_id: 'test', name: 'Test', provider: 'openai')

        duplicate = model_class.new(model_id: 'test', name: 'Test 2', provider: 'openai')
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:model_id]).to include('has already been taken')

        different_provider = model_class.new(model_id: 'test', name: 'Test', provider: 'anthropic')
        expect(different_provider).to be_valid
      end
    end

    describe 'model registry integration' do
      before do
        RubyLLM.configure do |config|
          config.model_registry_class = model_class
        end
      end

      after do
        RubyLLM.configure do |config|
          config.model_registry_class = nil
        end
      end

      it 'loads models from database when configured' do
        model_class.create!(
          model_id: 'test-model',
          name: 'Test Model',
          provider: 'openai'
        )

        models = RubyLLM::Models.new
        expect(models.all.map(&:id)).to include('test-model')
      end

      it 'finds models from database' do
        model_class.create!(
          model_id: 'test-model',
          name: 'Test Model',
          provider: 'openai'
        )

        models = RubyLLM::Models.new
        found = models.find('test-model', 'openai')

        expect(found).to be_a(RubyLLM::Model::Info)
        expect(found.id).to eq('test-model')
        expect(found.provider).to eq('openai')
      end
    end

    describe 'chat integration with model association' do
      let(:chat_class) do
        stub_const('TestChat', Class.new(ActiveRecord::Base) do
          self.table_name = 'chats'
          acts_as_chat(model_class: 'TestModel', model_foreign_key: 'model_id')
        end)
      end

      before do
        RubyLLM.configure do |config|
          config.model_registry_class = model_class
        end

        ActiveRecord::Schema.define do
          create_table :chats, force: true do |t|
            t.string :model_id
            t.timestamps
          end
        end

        # Create models in DB
        model_class.create!(
          model_id: 'test-gpt',
          name: 'Test GPT',
          provider: 'openai',
          capabilities: ['streaming']
        )

        model_class.create!(
          model_id: 'test-claude',
          name: 'Test Claude',
          provider: 'anthropic',
          capabilities: ['streaming']
        )
      end

      after do
        RubyLLM.configure do |config|
          config.model_registry_class = nil
        end
      end

      it 'resolves model from association when creating llm chat' do
        chat = chat_class.create!(model_id: 'test-gpt')

        # Verify association works
        expect(chat.model).to be_present
        expect(chat.model.provider).to eq('openai')

        # Mock the chat creation to verify parameters
        expect(RubyLLM).to receive(:chat).with( # rubocop:disable RSpec/MessageSpies,RSpec/StubbedMock
          model: 'test-gpt',
          provider: :openai
        ).and_return(
          instance_double(RubyLLM::Chat, reset_messages!: nil, add_message: nil,
                                         instance_variable_get: {}, on_new_message: nil, on_end_message: nil,
                                         instance_variable_set: nil)
        )

        chat.to_llm
      end

      it 'uses different provider from model association' do
        chat = chat_class.create!(model_id: 'test-claude')

        expect(chat.model.provider).to eq('anthropic')

        expect(RubyLLM).to receive(:chat).with( # rubocop:disable RSpec/MessageSpies,RSpec/StubbedMock
          model: 'test-claude',
          provider: :anthropic
        ).and_return(
          instance_double(RubyLLM::Chat, reset_messages!: nil, add_message: nil,
                                         instance_variable_get: {}, on_new_message: nil, on_end_message: nil,
                                         instance_variable_set: nil)
        )

        chat.to_llm
      end

      it 'falls back to string when no model association' do
        chat = chat_class.create!(model_id: 'non-existent')

        expect(chat.model).to be_nil

        expect(RubyLLM).to receive(:chat).with( # rubocop:disable RSpec/MessageSpies
          model: 'non-existent',
          provider: nil
        ).and_call_original

        # This will fail because the model doesn't exist, but we're testing the parameters
        expect { chat.to_llm }.to raise_error(RubyLLM::ModelNotFoundError)
      end
    end
  end
end
