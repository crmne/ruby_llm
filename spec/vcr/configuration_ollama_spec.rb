# frozen_string_literal: true

require 'spec_helper'

RSpec.describe VCR::Configuration do
  let(:cassette) { instance_double(VCR::Cassette, tags: []) }

  [
    ['/v1/chat/completions', '<OLLAMA_API_BASE>/chat/completions'],
    ['/api/show', '<OLLAMA_API_ORIGIN>/api/show']
  ].each do |path, filtered_uri|
    it "replays #{path} on the standard port after recording on another port" do
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with('OLLAMA_API_BASE', anything).and_return('http://127.0.0.1:11435/v1')
      uri = "http://127.0.0.1:11435#{path}"
      interaction = VCR::HTTPInteraction.new(
        VCR::Request.new(:post, uri, '{}', {}),
        VCR::Response.new(VCR::ResponseStatus.new(200, 'OK'), {}, JSON.generate(url: uri), '1.1')
      ).hook_aware

      VCR.configuration.invoke_hook(:before_record, interaction, cassette)

      expect(interaction.request.uri).to eq(filtered_uri)
      expect(JSON.parse(interaction.response.body)['url']).to eq(filtered_uri)

      allow(ENV).to receive(:fetch).with('OLLAMA_API_BASE', anything).and_return('http://localhost:11434/v1')
      VCR.configuration.invoke_hook(:before_playback, interaction, cassette)

      expect(interaction.request.uri).to eq("http://localhost:11434#{path}")
      expect(JSON.parse(interaction.response.body)['url']).to eq("http://localhost:11434#{path}")
    end
  end
end
