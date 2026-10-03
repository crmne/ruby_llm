# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Thinking::Controls do
  def model_for(id, provider:, reasoning_options:)
    RubyLLM::Model.new(
      id: id,
      provider: provider,
      metadata: { reasoning_options: reasoning_options }
    )
  end

  describe '#disable' do
    it 'uses the Anthropic between_tools off control for Sonnet 5.5' do
      model = model_for(
        'claude-sonnet-5-5',
        provider: 'anthropic',
        reasoning_options: [{ type: 'effort', values: %w[low medium high xhigh max] }]
      )

      expect(described_class.new(model).disable).to eq(enabled: false)
      expect(RubyLLM::Thinking::Config.disabled.resolve(model).enabled).to be(false)
    end

    it 'uses the same off control on Vertex AI and the Bedrock Mantle id' do
      vertex = model_for(
        'claude-sonnet-5-5',
        provider: 'vertexai',
        reasoning_options: [{ type: 'effort', values: %w[low medium high xhigh max] }]
      )
      bedrock = model_for(
        'anthropic.claude-sonnet-5-5',
        provider: 'bedrock',
        reasoning_options: [{ type: 'effort', values: %w[low medium high xhigh max] }]
      )

      expect(described_class.new(vertex).disable).to eq(enabled: false)
      expect(described_class.new(bedrock).disable).to eq(enabled: false)
    end

    it 'still raises when neither the registry nor the provider exposes an off control' do
      model = model_for(
        'magistral-small',
        provider: 'mistral',
        reasoning_options: []
      )

      expect(described_class.new(model).disable).to be_nil
      expect { RubyLLM::Thinking::Config.disabled.resolve(model) }
        .to raise_error(ArgumentError, /does not know how to disable thinking/)
    end
  end
end
