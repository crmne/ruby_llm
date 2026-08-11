# frozen_string_literal: true

require 'spec_helper'
RSpec.describe RubyLLM::Providers::OpenRouter::Media do
  include_context 'with configured RubyLLM'

  it 'formats video attachments as video_url parts' do
    chat = RubyLLM.chat(model: 'openai/gpt-5.2', provider: :openrouter)
    chat.add_message(role: :user, content: 'what happens here?', attachments: 'https://example.com/clip.mp4')

    part = chat.render[:messages].first[:content].find { |p| p[:type] == 'video_url' }

    expect(part).to eq(type: 'video_url', video_url: { url: 'https://example.com/clip.mp4' })
  end
end
