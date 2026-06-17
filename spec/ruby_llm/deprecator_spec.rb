# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Deprecator do
  around do |example|
    original_behavior = RubyLLM.config.deprecation_behavior
    example.run
  ensure
    RubyLLM.config.deprecation_behavior = original_behavior
  end

  describe '#warn' do
    it 'can raise deprecations for strict test suites' do
      RubyLLM.config.deprecation_behavior = :raise

      expect { described_class.new.warn('old API') }.to raise_error(RubyLLM::DeprecationError, 'old API')
    end

    it 'can silence deprecations' do
      allow(RubyLLM.logger).to receive(:warn)
      RubyLLM.config.deprecation_behavior = :silence

      described_class.new.warn('old API')

      expect(RubyLLM.logger).not_to have_received(:warn)
    end
  end
end
