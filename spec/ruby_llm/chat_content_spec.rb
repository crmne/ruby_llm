# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Chat do
  include_context 'with configured RubyLLM'

  let(:image_path) { File.expand_path('../fixtures/ruby.png', __dir__) }
  let(:audio_path) { File.expand_path('../fixtures/ruby.wav', __dir__) }

  describe 'vision models' do
    VISION_MODELS.each do |model_info|
      model = model_info[:model]
      provider = model_info[:provider]
      it "#{provider}/#{model} can understand images" do # rubocop:disable RSpec/MultipleExpectations
        chat = RubyLLM.chat(model: model, provider: provider)
        response = chat.ask('What do you see in this image?', with: { image: image_path })

        expect(response.content).to be_present
        expect(chat.messages.first.content).to be_a(Array)
        expect(chat.messages.first.content.last[:type]).to eq('image')
      end
    end
  end

  describe 'audio models' do
    AUDIO_MODELS.each do |model_info|
      model = model_info[:model]
      provider = model_info[:provider]
      it "#{provider}/#{model} can understand audio" do # rubocop:disable RSpec/MultipleExpectations
        chat = RubyLLM.chat(model: model, provider: provider)
        response = chat.ask('What is being said?', with: { audio: audio_path })

        expect(response.content).to be_present
        expect(chat.messages.first.content).to be_a(Array)
        expect(chat.messages.first.content.last[:type]).to eq('input_audio')
      end
    end
  end
end
