# frozen_string_literal: true

require 'spec_helper'
require 'tempfile'

RSpec.describe RubyLLM::Models do
  include_context 'with configured RubyLLM'

  describe 'filtering and chaining' do
    it 'filters models by provider' do # rubocop:disable RSpec/MultipleExpectations
      openai_models = RubyLLM.models.by_provider('openai')
      expect(openai_models.all).to all(have_attributes(provider: 'openai'))

      # Can chain other filters and methods
      expect(openai_models.chat_models).to be_a(described_class)
    end

    it 'chains filters in any order with same result' do
      # These two filters should be equivalent
      openai_chat_models = RubyLLM.models.by_provider('openai').chat_models
      chat_openai_models = RubyLLM.models.chat_models.by_provider('openai')

      # Both return same model IDs
      expect(openai_chat_models.map(&:id).sort).to eq(chat_openai_models.map(&:id).sort)
    end

    it 'supports Enumerable methods' do # rubocop:disable RSpec/MultipleExpectations
      # Count models by provider
      provider_counts = RubyLLM.models.group_by(&:provider)
                               .transform_values(&:count)

      # There should be models from at least OpenAI and Anthropic
      expect(provider_counts.keys).to include('openai', 'anthropic')

      # Select only models with vision support
      vision_models = RubyLLM.models.select(&:supports_vision)
      expect(vision_models).to all(have_attributes(supports_vision: true))
    end
  end

  describe 'finding models' do
    it 'finds models by ID' do # rubocop:disable RSpec/ExampleLength,RSpec/MultipleExpectations
      # We need to account for the fact that default model might be an alias
      model_id = RubyLLM.config.default_model
      model = RubyLLM.models.find(model_id)
      # If the model ID is an alias, it will resolve to the versioned ID
      expected_id = if RubyLLM::Aliases.aliases.key?(model_id)
                      RubyLLM::Aliases.resolve(model_id)
                    else
                      model_id
                    end
      expect(model.id).to eq(expected_id)

      # Find a model with chaining
      if RubyLLM.models.by_provider('openai').chat_models.any?
        openai_chat_id = RubyLLM.models.by_provider('openai').chat_models.first.id
        found = RubyLLM.models.by_provider('openai').find(openai_chat_id)
        expect(found.id).to eq(openai_chat_id)
        expect(found.provider).to eq('openai')
      end
    end

    it 'raises ModelNotFoundError for unknown models' do
      expect do
        RubyLLM.models.find('nonexistent-model-12345')
      end.to raise_error(RubyLLM::ModelNotFoundError)
    end
  end

  describe '#find' do
    it 'resolves known aliases correctly' do # rubocop:disable RSpec/MultipleExpectations
      # Use claude-3 as our test case since it's a stable alias
      chat_model = RubyLLM.chat(model: 'claude-3')
      expect(chat_model.model.id).to eq('claude-3-sonnet-20240229')

      # With provider specified too
      chat_model = RubyLLM.chat(model: 'claude-3-5-haiku', provider: 'bedrock')
      expect(chat_model.model.id).to eq('anthropic.claude-3-5-haiku-20241022-v1:0')
      expect(chat_model.model.provider).to eq('bedrock')
    end

    it 'resolves aliases even when an exact match exists' do # rubocop:disable RSpec/ExampleLength
      # Test for the special case of model IDs that are both concrete models and alias keys
      # This ensures 'gpt-4o' resolves to 'gpt-4o-2024-11-20' as per the documentation

      # Arrange: Prepare a test with mock models and aliases
      allow(RubyLLM::Aliases).to receive(:aliases).and_return(
        'gpt-4o' => { 'openai' => 'gpt-4o-2024-11-20' }
      )

      models = [
        RubyLLM::ModelInfo.new(id: 'gpt-4o', provider: 'openai'),
        RubyLLM::ModelInfo.new(id: 'gpt-4o-2024-11-20', provider: 'openai')
      ]
      # Create a models instance with our test data
      models_instance = described_class.new
      allow(models_instance).to receive(:all).and_return(models)

      # Act: Find the model by its alias
      model = models_instance.find('gpt-4o')

      # Assert: It should resolve to the aliased version
      expect(model.id).to eq('gpt-4o-2024-11-20')
    end
  end

  describe '#refresh!' do
    it 'updates models and returns a chainable Models instance' do # rubocop:disable RSpec/ExampleLength,RSpec/MultipleExpectations
      # Use a temporary file to avoid modifying actual models.json
      temp_file = Tempfile.new(['models', '.json'])
      allow(File).to receive(:expand_path).with('models.json', any_args).and_return(temp_file.path)

      begin
        # Refresh and chain immediately
        chat_models = RubyLLM.models.refresh!.chat_models

        # Verify we got results
        expect(chat_models).to be_a(described_class)
        expect(chat_models.all).to all(have_attributes(type: 'chat'))

        # Verify we got models from at least OpenAI and Anthropic
        providers = chat_models.map(&:provider).uniq
        expect(providers).to include('openai', 'anthropic')
      ensure
        temp_file.close
        temp_file.unlink
      end
    end

    it 'works as a class method too' do # rubocop:disable RSpec/ExampleLength
      temp_file = Tempfile.new(['models', '.json'])
      allow(File).to receive(:expand_path).with('models.json', any_args).and_return(temp_file.path)

      begin
        # Call class method
        described_class.refresh!

        # Verify singleton instance was updated
        expect(RubyLLM.models.all.size).to be > 0
      ensure
        temp_file.close
        temp_file.unlink
      end
    end
  end

  describe '#embedding_models' do
    it 'filters to only embedding models' do # rubocop:disable RSpec/MultipleExpectations
      embedding_models = RubyLLM.models.embedding_models

      expect(embedding_models).to be_a(described_class)
      expect(embedding_models.all).to all(have_attributes(type: 'embedding'))
      expect(embedding_models.all).not_to be_empty
    end
  end

  describe '#audio_models' do
    it 'filters to only audio models' do # rubocop:disable RSpec/MultipleExpectations
      audio_models = RubyLLM.models.audio_models

      expect(audio_models).to be_a(described_class)
      expect(audio_models.all).to all(have_attributes(type: 'audio'))
    end
  end

  describe '#image_models' do
    it 'filters to only image models' do # rubocop:disable RSpec/MultipleExpectations
      image_models = RubyLLM.models.image_models

      expect(image_models).to be_a(described_class)
      expect(image_models.all).to all(have_attributes(type: 'image'))
      expect(image_models.all).not_to be_empty
    end
  end

  describe '#by_family' do
    it 'filters models by family' do # rubocop:disable RSpec/MultipleExpectations
      # Use a family we know exists
      family = RubyLLM.models.all.first.family
      family_models = RubyLLM.models.by_family(family)

      expect(family_models).to be_a(described_class)
      expect(family_models.all).to all(have_attributes(family: family))
      expect(family_models.all).not_to be_empty
    end
  end

  describe '#save_models' do
    it 'saves models to the models.json file' do # rubocop:disable RSpec/ExampleLength,RSpec/MultipleExpectations
      temp_file = Tempfile.new(['models', '.json'])
      allow(described_class).to receive(:models_file).and_return(temp_file.path)

      models = RubyLLM.models
      models.save_models

      # Verify file was written with valid JSON
      saved_content = File.read(temp_file.path)
      expect { JSON.parse(saved_content) }.not_to raise_error

      # Verify model data was saved
      parsed_models = JSON.parse(saved_content)
      expect(parsed_models.size).to eq(models.all.size)

      temp_file.unlink
    end
  end
end
