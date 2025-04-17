# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Chat do
  include_context 'with configured RubyLLM'

  let(:image_path) { File.expand_path('../fixtures/ruby.png', __dir__) }
  let(:audio_path) { File.expand_path('../fixtures/ruby.wav', __dir__) }

  vision_models = %w[claude-3-5-haiku-20241022 anthropic.claude-3-5-sonnet-20240620-v1:0 gemini-2.0-flash
                     gpt-4.1-nano].freeze
  audio_models = %w[gpt-4o-mini-audio-preview gpt-4o-audio-preview].freeze

  describe 'vision models' do
    vision_models.each do |model|
      provider = RubyLLM::Models.provider_for(model).slug
      it "#{provider}/#{model} can understand images" do # rubocop:disable RSpec/MultipleExpectations
        chat = RubyLLM.chat(model: model)
        response = chat.ask('What do you see in this image?', with: { image: image_path })

        expect(response.content).to be_present
        expect(chat.messages.first.content).to be_a(Array)
        expect(chat.messages.first.content.last[:type]).to eq('image')
      end
    end
  end

  describe 'audio models' do
    audio_models.each do |model|
      provider = RubyLLM::Models.provider_for(model).slug
      it "#{provider}/#{model} can understand audio" do # rubocop:disable RSpec/MultipleExpectations
        chat = RubyLLM.chat(model: model)
        response = chat.ask('What is being said?', with: { audio: audio_path })

        expect(response.content).to be_present
        expect(chat.messages.first.content).to be_a(Array)
        expect(chat.messages.first.content.last[:type]).to eq('input_audio')
      end
    end
  end
end
