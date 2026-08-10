# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Perplexity::Models do
  describe '#list_models' do
    let(:config) do
      RubyLLM::Configuration.new.tap { |config| config.perplexity_api_key = ENV.fetch('PERPLEXITY_API_KEY', 'test') }
    end
    let(:provider) { RubyLLM::Providers::Perplexity.new(config) }

    it 'lists the models endpoint catalog with the search and embedding models added' do
      models = provider.list_models

      ids = models.map(&:id)
      expect(ids).to include('sonar', 'sonar-pro', 'sonar-reasoning-pro', 'sonar-deep-research',
                             'pplx-embed-v1-0.6b', 'pplx-embed-v1-4b', 'perplexity/sonar')
      expect(ids).not_to include('sonar-reasoning')
      expect(models).to all(have_attributes(provider: 'perplexity'))

      sonar = models.find { |model| model.id == 'sonar' }
      expect(sonar.context_window).to eq(128_000)
      expect(sonar.max_output_tokens).to eq(4096)
      expect(sonar.capabilities).to eq(%w[citations vision])

      embedding = models.find { |model| model.id == 'pplx-embed-v1-0.6b' }
      expect(embedding.type).to eq('embedding')
      expect(embedding.pricing.to_h.dig(:text_tokens, :standard, :input_per_million)).to eq(0.004)

      listed = models.find { |model| model.id == 'perplexity/sonar' }
      expect(listed.pricing.to_h.dig(:text_tokens, :standard, :output_per_million)).to eq(2.5)
    end

    it 'falls back to the static list when the endpoint fails' do
      allow(provider.connection).to receive(:get).and_raise(RubyLLM::Error.new(nil, response: nil))

      models = provider.list_models

      expect(models.map(&:id)).to eq(
        %w[sonar sonar-pro sonar-reasoning-pro sonar-deep-research pplx-embed-v1-0.6b pplx-embed-v1-4b]
      )
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
