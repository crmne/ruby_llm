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
      expect(sonar.capabilities).to eq(%w[citations vision])
      expect(sonar.pricing.to_h).to eq(
        text_tokens: {
          standard: {
            input_per_million: 1.0,
            output_per_million: 1.0
          }
        }
      )

      reasoning = models.find { |model| model.id == 'sonar-reasoning' }
      expect(reasoning.capabilities).to contain_exactly('citations', 'vision', 'reasoning')
    end
  end

  describe 'error parsing' do
    subject(:provider) do
      RubyLLM::Providers::Perplexity.new(
        RubyLLM::Configuration.new.tap { |config| config.perplexity_api_key = 'test' }
      )
    end

    def response_for(body)
      Struct.new(:body).new(body)
    end

    it 'reads the title out of the HTML Perplexity returns for auth failures' do
      html = "<html>\n<head><title>401 Authorization Required</title></head>\n</html>"

      expect(provider.parse_error(response_for(html))).to eq('Authorization Required')
    end

    it 'falls back to the shared parser for HTML without a title match' do
      html = '<html><title></title>no title here</html>'

      expect(provider.parse_error(response_for(html))).to eq(html)
    end

    it 'falls back to the shared parser for JSON errors' do
      expect(provider.parse_error(response_for({ 'error' => { 'message' => 'bad request' } }))).to eq('bad request')
    end

    it 'is nil for an empty body' do
      expect(provider.parse_error(response_for(nil))).to be_nil
    end
  end
end
