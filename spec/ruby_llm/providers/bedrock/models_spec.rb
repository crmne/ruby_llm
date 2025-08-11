# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Bedrock::Models do
  include_context 'with configured RubyLLM'
  
  let(:slug) { 'bedrock' }
  let(:capabilities) { class_double(RubyLLM::Providers::Bedrock::Capabilities) }

  before do
    allow(capabilities).to receive_messages(
      context_window_for: 4096,
      max_tokens_for: 4096,
      model_type: :chat,
      model_family: :claude,
      supports_vision?: false,
      supports_functions?: false,
      supports_json_mode?: false,
      input_price_for: 0.0,
      output_price_for: 0.0,
      format_display_name: 'Test Model'
    )
  end


  describe '#model_id_with_region' do
    let(:inference_profile_model) do
      {
        'modelId' => 'anthropic.claude-3-7-sonnet-20250219-v1:0',
        'inferenceTypesSupported' => ['INFERENCE_PROFILE']
      }
    end

    let(:on_demand_model) do
      {
        'modelId' => 'anthropic.claude-3-5-sonnet-20240620-v1:0',
        'inferenceTypesSupported' => ['ON_DEMAND']
      }
    end

    context 'with different regions' do
      {
        'us-east-1' => 'us',
        'eu-west-3' => 'eu', 
        'ap-south-1' => 'ap',
        'ca-central-1' => 'ca'
      }.each do |region, expected_prefix|
        it "adds #{expected_prefix}. prefix for inference profile models in #{region}" do
          allow(RubyLLM.config).to receive(:bedrock_region).and_return(region)
          
          provider = RubyLLM::Providers::Bedrock.new(RubyLLM.config)
          provider.extend(described_class)
          
          result = provider.send(:model_id_with_region, 
                                inference_profile_model['modelId'], 
                                inference_profile_model)
          
          expect(result).to eq("#{expected_prefix}.anthropic.claude-3-7-sonnet-20250219-v1:0")
        end
      end
    end

    it 'does not add prefix for on-demand models' do
      allow(RubyLLM.config).to receive(:bedrock_region).and_return('us-east-1')
      
      provider = RubyLLM::Providers::Bedrock.new(RubyLLM.config)
      provider.extend(described_class)
      
      result = provider.send(:model_id_with_region, 
                            on_demand_model['modelId'], 
                            on_demand_model)
      
      expect(result).to eq('anthropic.claude-3-5-sonnet-20240620-v1:0')
    end

    it 'defaults to us. prefix for empty region' do
      allow(RubyLLM.config).to receive(:bedrock_region).and_return('')
      
      provider = RubyLLM::Providers::Bedrock.new(RubyLLM.config)
      provider.extend(described_class)
      
      result = provider.send(:model_id_with_region, 
                            inference_profile_model['modelId'], 
                            inference_profile_model)
      
      expect(result).to eq('us.anthropic.claude-3-7-sonnet-20250219-v1:0')
    end
  end

end
