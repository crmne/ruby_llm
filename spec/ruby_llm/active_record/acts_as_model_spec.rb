# frozen_string_literal: true

require 'rails_helper'

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
      ActiveRecord::Tasks::DatabaseTasks.drop_current
      ActiveRecord::Tasks::DatabaseTasks.load_schema_current
    end

    after(:all) do # rubocop:disable RSpec/BeforeAfterAll
      ActiveRecord::Tasks::DatabaseTasks.drop_current
      ActiveRecord::Tasks::DatabaseTasks.load_schema_current
      RubyLLM.models.load_from_json!
      Model.save_to_database
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
          config.model_registry_class = 'Model'
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
          acts_as_chat(model: :model, model_class: 'TestModel')

          # Mock the messages association since we're only testing model association
          def messages
            []
          end
        end)
      end

      before do
        RubyLLM.configure do |config|
          config.model_registry_class = model_class
        end

        # Recreate chats table (models table already exists from outer before block)
        ActiveRecord::Base.connection.drop_table(:chats) if ActiveRecord::Base.connection.table_exists?(:chats)

        ActiveRecord::Schema.define do
          create_table :chats do |t|
            t.references :model, foreign_key: true
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

        # Reload models from database so RubyLLM.models knows about them
        RubyLLM.models.load_from_database!
      end

      after do
        RubyLLM.configure do |config|
          config.model_registry_class = 'Model'
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

      it 'fails when model does not exist' do
        expect { chat_class.create!(model_id: 'non-existent') }.to raise_error(RubyLLM::ModelNotFoundError)
      end

      it 'creates model in database when assume_model_exists is true with provider' do
        chat = chat_class.new(model_id: 'gpt-1999', provider: 'openai', assume_model_exists: true)
        chat.save!

        expect(chat.model).to be_present
        expect(chat.model.model_id).to eq('gpt-1999')
        expect(chat.model.provider).to eq('openai')

        # Verify it was created in the database
        db_model = model_class.find_by(model_id: 'gpt-1999', provider: 'openai')
        expect(db_model).to be_present
        expect(db_model.name).to eq('Gpt 1999') # Should use model_id as name when not found
      end

      it 'works with assume_model_exists and different provider' do
        chat = chat_class.new(model_id: 'future-model-2050', provider: 'anthropic', assume_model_exists: true)
        chat.save!

        expect(chat.model).to be_present
        expect(chat.model.model_id).to eq('future-model-2050')
        expect(chat.model.provider).to eq('anthropic')

        # Verify it was created in the database
        db_model = model_class.find_by(model_id: 'future-model-2050', provider: 'anthropic')
        expect(db_model).to be_present
      end

      it 'fails with assume_model_exists when provider is missing' do
        chat = chat_class.new(model_id: 'mystery-model-3000', assume_model_exists: true)
        expect { chat.save! }.to raise_error(ArgumentError, /Provider must be specified/)
      end
    end
  end
end
