# frozen_string_literal: true

require 'spec_helper'
require 'dotenv/load'

RSpec.describe RubyLLM::Chat do
  include_context 'with configured RubyLLM'

  it 'finds models by alias name' do
    # Core test - can we find a model using just its alias?
    chat = RubyLLM.chat(model: 'claude-3-5-sonnet')
    expect(chat.model.id).to eq('claude-3-5-sonnet-20241022')
  end

  it 'still supports exact model IDs' do
    # Backward compatibility check
    chat = RubyLLM.chat(model: 'claude-3-5-sonnet-20241022')
    expect(chat.model.id).to eq('claude-3-5-sonnet-20241022')
  end
end
