# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RubyLLM::ActiveRecord::Model do # rubocop:disable RSpec/SpecFilePathFormat
  include_context 'with configured RubyLLM'

  let(:record_class) { described_class }
  let(:model_info) do
    RubyLLM::Model.new(
      id: 'test-model',
      name: 'Test Model',
      provider: 'openai',
      family: 'test',
      context_window: 128_000,
      modalities: { input: %w[text image], output: ['text'] },
      capabilities: %w[function_calling vision],
      pricing: { text_tokens: { standard: { input_per_million: 1.0, output_per_million: 2.0 } } }
    )
  end

  # Writing a registry replaces the table these examples share with the rest of
  # the suite, so every write here is rolled back.
  around do |example|
    ActiveRecord::Base.transaction do
      example.run
      raise ActiveRecord::Rollback
    end
  end

  before { record_class.where(model_id: model_info.id, provider: model_info.provider).delete_all }

  it 'stores the registry in RubyLLM-owned records' do
    registry = RubyLLM::Models.new([model_info])

    described_class.write(registry)

    record = record_class.find_by!(model_id: model_info.id, provider: model_info.provider)
    expect(record.to_llm.to_h).to include(id: 'test-model', provider: 'openai')
    expect(record.supports?(:vision)).to be(true)
  end

  it 'updates an existing provider and model pair' do
    record_class.create!(model_id: model_info.id, provider: model_info.provider, name: 'Old')

    described_class.write(RubyLLM::Models.new([model_info]))

    expect(record_class.find_by!(model_id: model_info.id, provider: model_info.provider).name).to eq('Test Model')
  end

  it 'reads public RubyLLM::Model values' do
    record_class.save_to_database(RubyLLM::Models.new([model_info]))

    model = described_class.read.find { |candidate| candidate.id == model_info.id }

    expect(model).to be_a(RubyLLM::Model)
    expect(model.provider).to eq('openai')
  end

  it 'does not expose application acts_as macros for internal records' do
    expect(ActiveRecord::Base).not_to respond_to(:acts_as_model)
    expect(ActiveRecord::Base).not_to respond_to(:acts_as_tool_call)
    expect(ActiveRecord::Base).not_to respond_to(:acts_as_batch)
  end

  it 'does not introduce an empty internal Active Record superclass' do
    expect(RubyLLM::ActiveRecord.const_defined?(:Record, false)).to be(false)
    expect(record_class.superclass).to eq(ActiveRecord::Base)
  end

  it 'reports nothing when the table is missing' do
    allow(described_class).to receive(:table_exists?).and_return(false)

    expect(described_class.read).to eq([])
  end

  it 'falls back to an empty registry when reading blows up' do
    allow(described_class).to receive(:all).and_raise(ActiveRecord::StatementInvalid, 'no such column')
    allow(RubyLLM.logger).to receive(:debug)

    expect(described_class.read).to eq([])
  end

  it 'describes itself by table name' do
    expect(described_class.description).to eq('database:ruby_llm_models')
  end

  it 'refreshes through the public registry' do
    allow(RubyLLM.models).to receive(:refresh)

    described_class.refresh

    expect(RubyLLM.models).to have_received(:refresh)
  end

  it 'builds an unsaved record from a public model' do
    record = described_class.from_llm(model_info)

    expect(record).not_to be_persisted
    expect(record.model_id).to eq('test-model')
  end

  context 'when a refresh replaces the registry' do
    # The suite shares one database, so records other examples left behind would
    # join this refresh. The surrounding transaction puts them back.
    before do
      %w[messages chats document_messages document_chats].each do |table|
        ActiveRecord::Base.connection.delete("DELETE FROM #{table}")
      end
    end

    let(:dropped) do
      RubyLLM::Model.new(id: 'dropped-model', name: 'Dropped Model', provider: 'openai')
    end

    def dropped_record
      record_class.find_by!(model_id: 'dropped-model', provider: 'openai')
    end

    it 'drops the models the new registry no longer carries' do
      described_class.write(RubyLLM::Models.new([model_info, dropped]))

      described_class.write(RubyLLM::Models.new([model_info]))

      expect(described_class.read.map(&:id)).to include('test-model')
      expect(described_class.read.map(&:id)).not_to include('dropped-model')
      expect(record_class.where(model_id: 'dropped-model', provider: 'openai')).to be_empty
    end

    it 'drops everything an empty registry leaves behind' do
      described_class.write(RubyLLM::Models.new([model_info]))

      described_class.write(RubyLLM::Models.new([]))

      expect(described_class.pluck(:model_id)).not_to include('test-model')
    end

    context 'when an application record still points at a dropped model' do
      let(:warnings) { [] }

      before do
        allow(RubyLLM.logger).to receive(:warn) { |&message| warnings << message.call }
        described_class.write(RubyLLM::Models.new([model_info, dropped]))
        Chat.create!(model: dropped_record)

        described_class.write(RubyLLM::Models.new([model_info]))
      end

      it 'keeps the row and marks it unlisted' do
        expect(dropped_record.unlisted_at).to be_present
        expect(record_class.unlisted.pluck(:model_id)).to include('dropped-model')
        expect(record_class.listed.pluck(:model_id)).not_to include('dropped-model')
        expect(Chat.last.model.model_id).to eq('dropped-model')
      end

      it 'warns once that the model is no longer listed and may no longer work' do
        expect(warnings).to contain_exactly(
          a_string_including('1 model is', 'openai/dropped-model', 'no longer listed by the provider',
                             'may no longer work', 'region')
        )
      end

      it 'warns once for a refresh that leaves several models unlisted' do
        others = (1..7).map { |index| RubyLLM::Model.new(id: "gone-#{index}", name: "Gone #{index}", provider: 'openai') }
        described_class.write(RubyLLM::Models.new([model_info, dropped] + others))
        others.each { |model| Chat.create!(model: record_class.find_by!(model_id: model.id, provider: 'openai')) }
        warnings.clear

        described_class.write(RubyLLM::Models.new([model_info]))

        expect(warnings.size).to eq(1)
        expect(warnings.first).to include('8 models are', 'and 3 more')
      end

      it 'keeps reporting the unlisted model, flagged as unlisted' do
        model = described_class.read.find { |candidate| candidate.id == 'dropped-model' }

        expect(model).to be_unlisted
        expect(RubyLLM::Models.new(described_class.read).all.map(&:id)).not_to include('dropped-model')
        expect(RubyLLM::Models.new(described_class.read).unlisted.map(&:id)).to include('dropped-model')
      end

      it 'still finds the unlisted model by id' do
        registry = RubyLLM::Models.new(described_class.read)

        expect(registry.find('dropped-model', provider: :openai).id).to eq('dropped-model')
      end

      it 'keeps the first unlisting time while the model stays unlisted' do
        unlisted_at = dropped_record.unlisted_at

        described_class.write(RubyLLM::Models.new([model_info]))

        expect(dropped_record.unlisted_at).to eq(unlisted_at)
      end

      it 'lists the model again when a later refresh carries it' do
        described_class.write(RubyLLM::Models.new([model_info, dropped]))

        expect(dropped_record.unlisted_at).to be_nil
        expect(dropped_record.to_llm).not_to be_unlisted
        expect(record_class.listed.pluck(:model_id)).to include('dropped-model')
      end

      it 'still resolves the chat that points at it' do
        RubyLLM.models.load_from_store

        expect(Chat.last.to_llm.model.id).to eq('dropped-model')
      ensure
        RubyLLM.models.load_from_json
      end
    end
  end

  it 'defaults the JSON columns when the row leaves them null' do
    record = described_class.new(
      model_id: 'sparse-model', name: 'Sparse', provider: 'openai',
      modalities: nil, pricing: nil, metadata: nil
    )

    model = record.to_llm

    expect(model.modalities.input).to eq([])
    expect(model.pricing.to_h).to eq({})
    expect(model.metadata).to eq({})
  end
end
