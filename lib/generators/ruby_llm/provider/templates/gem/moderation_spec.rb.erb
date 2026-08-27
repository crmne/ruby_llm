# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Moderation, :live do
  include_context 'with configured RubyLLM'

  each_model(MODERATION_MODELS) do |provider, model|
    it "#{provider}/#{model} moderates content" do
      moderation = RubyLLM.moderate(
        'This is a safe message',
        model: model,
        provider: provider,
        assume_model_exists: true
      )

      expect(moderation).to be_a(described_class)
      expect(moderation.results).to all(be_a(RubyLLM::Moderation::Result))
      expect(moderation.flagged?).to be_in([true, false])
    end
  end
end
