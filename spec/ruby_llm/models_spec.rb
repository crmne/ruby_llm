# frozen_string_literal: true

require 'spec_helper'
require 'tempfile'

RSpec.describe RubyLLM::Models do
  include_context 'with configured RubyLLM'

  # Reset Models singleton after tests that modify it
  after do
    described_class.instance_variable_set(:@instance, nil)
  end

  describe 'filtering and chaining' do
    it 'filters models by provider' do
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

    it 'supports Enumerable methods' do
      # Count models by provider
      provider_counts = RubyLLM.models.group_by(&:provider)
                               .transform_values(&:count)

      # There should be models from at least OpenAI and Anthropic
      expect(provider_counts.keys).to include('openai', 'anthropic')
    end

    it 'filters by vision support' do
      vision_models = RubyLLM.models.select(&:supports_vision?)
      expect(vision_models).to all(have_attributes(supports_vision?: true))
    end

    it 'filters by video support' do
      video_models = RubyLLM.models.select(&:supports_video?)
      expect(video_models).to all(have_attributes(supports_video?: true))
    end
  end

  describe 'finding models' do
    it 'finds models by ID' do
      # Find the default model
      model_id = RubyLLM.config.default_model
      model = RubyLLM.models.find(model_id)
      expect(model.id).to eq(model_id)

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
    it 'prioritizes exact matches over aliases' do
      chat_model = RubyLLM.chat(model: 'gemini-2.0-flash')
      expect(chat_model.model.id).to eq('gemini-2.0-flash')

      chat_model = RubyLLM.chat(model: 'gemini-2.0-flash', provider: 'gemini')
      expect(chat_model.model.id).to eq('gemini-2.0-flash')

      # Only use alias when exact match isn't found
      chat_model = RubyLLM.chat(model: 'claude-3-5-haiku')
      expect(chat_model.model.id).to eq('claude-3-5-haiku-20241022')
    end
  end

  describe '#refresh!' do
    it 'updates models and returns a chainable Models instance' do
      # Refresh and chain immediately
      chat_models = RubyLLM.models.refresh!.chat_models

      # Verify we got results
      expect(chat_models).to be_a(described_class)
      expect(chat_models.all).to all(have_attributes(type: 'chat'))

      # Verify we got models from at least OpenAI and Anthropic
      providers = chat_models.map(&:provider).uniq
      expect(providers).to include('openai', 'anthropic')
    end

    it 'works as a class method too' do
      described_class.refresh!

      # Verify singleton instance was updated
      expect(RubyLLM.models.all.size).to be_positive
    end
  end

  describe '#embedding_models' do
    it 'filters to models that are embedding-capable' do
      embedding_models = RubyLLM.models.embedding_models

      expect(embedding_models).to be_a(described_class)
      expect(embedding_models.all).not_to be_empty

      expect(embedding_models.all).to all(
        satisfy('has type=embedding or output includes embeddings') { |m|
          m.type == 'embedding' || Array(m.modalities&.output).include?('embeddings')
        }
      )
    end
  end

  describe '#audio_models' do
    it 'filters to models that are audio-capable' do
      audio_models = RubyLLM.models.audio_models

      expect(audio_models).to be_a(described_class)
      expect(audio_models.all).not_to be_empty

      expect(audio_models.all).to all(
        satisfy('has type=audio or output includes audio') { |m|
          m.type == 'audio' || Array(m.modalities&.output).include?('audio')
        }
      )
    end
  end

  describe '#image_models' do
    it 'filters to models that are image-capable' do
      image_models = RubyLLM.models.image_models

      expect(image_models).to be_a(described_class)
      expect(image_models.all).not_to be_empty

      expect(image_models.all).to all(
        satisfy('has type=image or output includes image') { |m|
          m.type == 'image' || Array(m.modalities&.output).include?('image')
        }
      )
    end
  end

  describe '#by_family' do
    it 'filters models by family' do
      # Use a family we know exists
      family = RubyLLM.models.all.first.family
      family_models = RubyLLM.models.by_family(family)

      expect(family_models).to be_a(described_class)
      expect(family_models.all).to all(have_attributes(family: family.to_s))
      expect(family_models.all).not_to be_empty
    end
  end

  describe '#resolve' do
    it 'delegates to the class method when called on instance' do
      model_id = 'gpt-4o'
      provider = 'openai'

      model_info, provider_instance = RubyLLM.models.resolve(model_id, provider: provider)

      expect(model_info).to be_a(RubyLLM::Model::Info)
      expect(model_info.id).to eq(model_id)
      expect(model_info.provider).to eq(provider)
      expect(provider_instance).to be_a(RubyLLM::Provider)
    end

    it 'resolves model without provider' do
      model_id = 'gpt-4o'

      model_info, provider_instance = RubyLLM.models.resolve(model_id)

      expect(model_info).to be_a(RubyLLM::Model::Info)
      expect(model_info.id).to eq(model_id)
      expect(provider_instance).to be_a(RubyLLM::Provider)
    end

    it 'resolves with assume_exists option' do
      model_id = 'custom-model'
      provider = 'openai'

      model_info, provider_instance = RubyLLM.models.resolve(
        model_id,
        provider: provider,
        assume_exists: true
      )

      expect(model_info).to be_a(RubyLLM::Model::Info)
      expect(model_info.id).to eq(model_id)
      expect(model_info.provider).to eq(provider)
      expect(provider_instance).to be_a(RubyLLM::Provider)
    end
  end

  describe '#save_to_json' do
    it 'saves models to the models.json file' do
      temp_file = Tempfile.new(['models', '.json'])

      models = RubyLLM.models
      models.save_to_json(temp_file)

      # Verify file was written with valid JSON
      saved_content = File.read(temp_file.path)
      expect { JSON.parse(saved_content) }.not_to raise_error

      # Verify model data was saved
      parsed_models = JSON.parse(saved_content)
      expect(parsed_models.size).to eq(models.all.size)

      temp_file.unlink
    end

    it 'saves and loads from a custom file path' do
      temp_file = Tempfile.new(['custom_models', '.json'])

      models = RubyLLM.models
      models.save_to_json(temp_file.path)

      # Load from custom path
      reloaded_models = described_class.read_from_json(temp_file.path)

      expect(reloaded_models.size).to eq(models.all.size)
      expect(reloaded_models.first.id).to eq(models.all.first.id)

      temp_file.unlink
    end
  end
end
