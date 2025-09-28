# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::OpenRouter do # rubocop:disable RSpec/SpecFilePathFormat
  describe '#parse_error' do
    model = 'openai/o3-mini'
    provider = 'openrouter'
    context "with #{provider}/#{model}" do
      let(:chat) { RubyLLM.chat(model: model, provider: provider) }

      before do
        RubyLLM.config.openrouter_api_key = 'sk-or-v1-sk-or-v1-mocked-key'
      end

      it 'raises detailed error' do
        expect { chat.ask('Hello') }.to raise_error do |error|
          expect(error).to be_a(RubyLLM::Error)
          expect(error.message).to eq 'Provider returned error - Country, region, or territory not supported'
        end
      end
    end
  end
end
