# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Chat, :live do
  include_context 'with configured RubyLLM'

  let(:weather_tool) do
    Class.new(RubyLLM::Tool) do
      description 'Gets current weather for a location'
      parameter :latitude, description: 'Latitude'
      parameter :longitude, description: 'Longitude'

      def execute(latitude:, longitude:)
        "Current weather at #{latitude}, #{longitude}: 15°C, Wind: 10 km/h"
      end
    end
  end

  each_model(TOOL_MODELS) do |provider, model|
    it "#{provider}/#{model} can use tools" do
      chat = RubyLLM.chat(model: model, provider: provider, assume_model_exists: true).with_tools(weather_tool)
      response = chat.ask("What's the weather in Berlin? Use 52.5200, 13.4050.")

      expect(response.content).to include('15')
      expect(response.content).to include('10')
      expect(chat.messages.any?(&:tool_call?)).to be(true)
    end
  end
end
