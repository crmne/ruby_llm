# frozen_string_literal: true

require 'spec_helper'
require 'dotenv/load'

def mock_response_with(response_text)
  {
    'message' => {
      'content' => response_text,
      'tool_calls' => []
    }
  }
end

def cases
  {
    'granite3.2-vision:2b' => %q(  <tool_call>[{"name": "get_weather", "arguments": {"latitude": "52.5200", "longitude": "13.4050"}}]  ),
    'nemotron-mini:4b' =>     %q(  <toolcall> {"name": "get_weather", "arguments": {"latitude": "52.5200", "longitude": "13.4050"}} </toolcall>  )
  }
end

RSpec.describe RubyLLM::Providers::Ollama::Tools do
  describe '.preprocess_tool_calls' do
    cases.each do |model, response_text|
      it "correctly parses #{model} tool calling markup" do # rubocop:disable RSpec/MultipleExpectations
        mock_response = mock_response_with(response_text)
        m = mock_response['message']

        described_class.preprocess_tool_calls(mock_response)

        # needs to remove markup from the text response
        expect(m['content']).not_to include('<tool')
        expect(m['content']).not_to include('</tool')

        expect(m['tool_calls'].length).to eq(1)
        expect(m['tool_calls'].first['name']).to eq('get_weather')
      end
    end
  end
end
