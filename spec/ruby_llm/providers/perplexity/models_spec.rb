# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Perplexity::Models do
  describe '#list_models' do
    let(:provider_class) do
      Class.new do
        include RubyLLM::Providers::Perplexity::Models
      end
    end

    it 'restores critical fallback metadata for the static catalog' do
      models = provider_class.new.list_models

      expect(models.map(&:id)).to eq(
        %w[sonar sonar-pro sonar-reasoning sonar-reasoning-pro sonar-deep-research]
      )
      expect(models).to all(have_attributes(provider: 'perplexity'))

      sonar = models.find { |model| model.id == 'sonar' }
      expect(sonar.context_window).to eq(128_000)
      expect(sonar.max_output_tokens).to eq(4096)
      expect(sonar.capabilities).to eq(['vision'])
      expect(sonar.pricing.to_h).to eq(
        text_tokens: {
          standard: {
            input_per_million: 1.0,
            output_per_million: 1.0
          }
        }
      )

      reasoning = models.find { |model| model.id == 'sonar-reasoning' }
      expect(reasoning.capabilities).to contain_exactly('vision', 'reasoning')
    end
  end
end
