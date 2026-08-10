# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::XAI::Responses do
  include_context 'with configured RubyLLM'

  describe '#parse_usage' do
    let(:protocol) do
      described_class.new(RubyLLM::Providers::XAI.new(RubyLLM.config))
    end

    it 'converts cost_in_usd_ticks into a reported cost in dollars' do
      usage = protocol.send(:parse_usage,
                            { 'input_tokens' => 10, 'output_tokens' => 5, 'cost_in_usd_ticks' => 2_909_000 })

      expect(usage[:reported_cost]).to be_within(1e-12).of(0.0002909)
    end

    it 'leaves reported cost nil when ticks are absent' do
      usage = protocol.send(:parse_usage, { 'input_tokens' => 10 })

      expect(usage[:reported_cost]).to be_nil
    end
  end
end
