# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Mistral::Models do
  describe '.parse_list_models_response' do
    it 'parses release dates without depending on global requires' do
      capabilities = Class.new do
        def release_date_for(_model_id) = '2025-01-02'
        def format_display_name(_model_id) = 'Mistral Test'
        def model_family(_model_id) = 'mistral'
        def context_window_for(_model_id) = 128_000
        def max_tokens_for(_model_id) = 4096
        def modalities_for(_model_id) = { input: ['text'], output: ['text'] }
        def capabilities_for(_model_id) = ['streaming']
        def pricing_for(_model_id) = {}
      end.new
      response = Struct.new(:body).new({ 'data' => [{ 'id' => 'mistral-test' }] })

      model = described_class.parse_list_models_response(response, 'mistral', capabilities).first

      expect(model.id).to eq('mistral-test')
      expect(model.created_at).to be_a(Time)
    end
  end
end
