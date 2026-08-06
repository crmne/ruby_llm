# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RubyLLM::ActiveRecord::Model do # rubocop:disable RSpec/SpecFilePathFormat
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
end
