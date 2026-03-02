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

    it 'prefers bedrock region-resolved inference profile IDs over exact unprefixed IDs' do
      unprefixed = RubyLLM::Model::Info.new(
        id: 'meta.llama4-maverick-17b-instruct-v1:0',
        name: 'Llama 4 Maverick',
        provider: 'bedrock',
        metadata: {}
      )
      prefixed = RubyLLM::Model::Info.new(
        id: 'us.meta.llama4-maverick-17b-instruct-v1:0',
        name: 'Llama 4 Maverick',
        provider: 'bedrock',
        metadata: { inference_types: ['INFERENCE_PROFILE'] }
      )

      models = described_class.new([unprefixed, prefixed])
      allow(RubyLLM).to receive(:config).and_return(
        instance_double(RubyLLM::Configuration, bedrock_region: 'us-west-2')
      )

      found = models.find('meta.llama4-maverick-17b-instruct-v1:0', 'bedrock')
      expect(found.id).to eq('us.meta.llama4-maverick-17b-instruct-v1:0')
    end
  end

  describe '#refresh!' do
    before do
      allow(described_class).to receive_messages(
        fetch_provider_models: {
          models: [],
          fetched_providers: [],
          configured_names: [],
          failed: []
        },
        fetch_models_dev_models: { models: [], fetched: true }
      )
    end

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

  describe '.models_dev_model_to_info' do
    let(:model_data) do
      {
        id: 'gpt-test-1',
        name: 'GPT Test 1',
        family: 'gpt-test',
        last_updated: '2025-02-01',
        knowledge: '2024-01-01',
        modalities: { input: %w[text image], output: ['text'] },
        tool_call: true,
        structured_output: true,
        reasoning: false,
        cost: {
          input: 1.25,
          output: 5.0,
          cache_read: 0.5,
          reasoning: 10.0
        },
        limit: {
          context: 128_000,
          output: 4096
        }
      }
    end

    it 'converts models.dev payload into a Model::Info-compatible hash' do
      data = described_class.models_dev_model_to_info(model_data, 'openai', 'openai')

      expect(data).to include(
        id: 'gpt-test-1',
        name: 'GPT Test 1',
        provider: 'openai',
        family: 'gpt-test',
        context_window: 128_000,
        max_output_tokens: 4096,
        knowledge_cutoff: Date.parse('2024-01-01')
      )

      expect(data[:modalities]).to eq(input: %w[text image], output: ['text'])
      expect(data[:capabilities]).to match_array(%w[function_calling structured_output vision])
      expect(data[:pricing]).to eq(
        text_tokens: {
          standard: {
            input_per_million: 1.25,
            output_per_million: 5.0,
            cached_input_per_million: 0.5,
            reasoning_output_per_million: 10.0
          }
        }
      )
      expect(data[:metadata]).to include(
        source: 'models.dev',
        provider_id: 'openai',
        last_updated: '2025-02-01'
      )
      expect(data[:metadata][:cost]).to eq(model_data[:cost])
      expect(data[:metadata][:limit]).to eq(model_data[:limit])
      expect(data[:metadata][:knowledge]).to eq(model_data[:knowledge])
    end

    it 'uses release_date cast to midnight as created_at' do
      model_data_with_release_date = model_data.merge(release_date: '2025-03-01')
      data = described_class.models_dev_model_to_info(model_data_with_release_date, 'openai', 'openai')
      expect(data[:created_at]).to eq('2025-03-01 00:00:00 UTC')
    end

    it 'falls back to last_updated cast to midnight as created_at when release_date is missing' do
      model_data_with_release_date = model_data.merge(release_date: nil, last_updated: '2025-03-01')
      data = described_class.models_dev_model_to_info(model_data_with_release_date, 'openai', 'openai')
      expect(data[:created_at]).to eq('2025-03-01 00:00:00 UTC')
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
