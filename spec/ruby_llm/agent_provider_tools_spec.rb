# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Agent do
  include_context 'with configured RubyLLM'

  it 'takes a Hash of aliases and options from a provider_tools block' do
    agent_class = Class.new(RubyLLM::Agent) do
      model model_for(:anthropic), provider: :anthropic
      provider_tools { { web_search: { max_uses: 2 } } }
    end

    expect(agent_class.chat.provider_tools).to eq([{ name: :web_search, options: { max_uses: 2 } }])
  end
end
