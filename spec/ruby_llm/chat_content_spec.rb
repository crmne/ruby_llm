# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Chat do # rubocop:disable RSpec/MultipleMemoizedHelpers
  include_context 'with configured RubyLLM'

  let(:image_path) { File.expand_path('../fixtures/ruby.png', __dir__) }
  let(:audio_path) { File.expand_path('../fixtures/ruby.wav', __dir__) }
  let(:pdf_path) { File.expand_path('../fixtures/sample.pdf', __dir__) }
  let(:text_path) { File.expand_path('../fixtures/ruby.txt', __dir__) }
  let(:xml_path) { File.expand_path('../fixtures/ruby.xml', __dir__) }
  let(:remote_image_path) { 'https://upload.wikimedia.org/wikipedia/commons/f/f1/Ruby_logo.png' }
  let(:remote_audio_path) { 'https://commons.wikimedia.org/wiki/File:LL-Q1860_(eng)-AcpoKrane-ruby.wav' }
  let(:remote_pdf_path) { 'https://pdfobject.com/pdf/sample.pdf' }
  let(:remote_text_path) { 'https://www.ruby-lang.org/en/about/license.txt' }

  describe 'text models' do # rubocop:disable RSpec/MultipleMemoizedHelpers
    CHAT_MODELS.each do |model_info|
      model = model_info[:model]
      provider = model_info[:provider]
      it "#{provider}/#{model} can understand text" do # rubocop:disable RSpec/MultipleExpectations,RSpec/ExampleLength
        chat = RubyLLM.chat(model: model, provider: provider)
        response = chat.ask("What's in this file?", with: text_path)

        expect(response.content).to be_present
        expect(response.content).not_to include('RubyLLM::Content')
        expect(chat.messages.first.content).to be_a(RubyLLM::Content)
        expect(chat.messages.first.content.attachments.first).to be_a(RubyLLM::Attachments::Text)

        response = chat.ask('and in this one?', with: xml_path)

        expect(response.content).to be_present
        expect(response.content).not_to include('RubyLLM::Content')
        expect(chat.messages.first.content).to be_a(RubyLLM::Content)
        expect(chat.messages.first.content.attachments.first).to be_a(RubyLLM::Attachments::Text)
      end

      it "#{provider}/#{model} can understand remote text" do # rubocop:disable RSpec/MultipleExpectations,RSpec/ExampleLength
        chat = RubyLLM.chat(model: model, provider: provider)
        response = chat.ask("What's in this file?", with: remote_text_path)

        expect(response.content).to be_present
        expect(response.content).not_to include('RubyLLM::Content')
        expect(chat.messages.first.content).to be_a(RubyLLM::Content)
        expect(chat.messages.first.content.attachments.first).to be_a(RubyLLM::Attachments::Text)
      end
    end
  end

  describe 'vision models' do # rubocop:disable RSpec/MultipleMemoizedHelpers
    VISION_MODELS.each do |model_info|
      model = model_info[:model]
      provider = model_info[:provider]
      it "#{provider}/#{model} can understand local images" do # rubocop:disable RSpec/MultipleExpectations,RSpec/ExampleLength
        chat = RubyLLM.chat(model: model, provider: provider)
        response = chat.ask('What do you see in this image?', with: { image: image_path })

        expect(response.content).to be_present
        expect(response.content).not_to include('RubyLLM::Content')
        expect(chat.messages.first.content).to be_a(RubyLLM::Content)
        expect(chat.messages.first.content.attachments.first).to be_a(RubyLLM::Attachments::Image)
      end

      it "#{provider}/#{model} can understand remote images" do # rubocop:disable RSpec/MultipleExpectations,RSpec/ExampleLength
        chat = RubyLLM.chat(model: model, provider: provider)
        response = chat.ask('What do you see in this image?', with: { image: remote_image_path })

        expect(response.content).to be_present
        expect(response.content).not_to include('RubyLLM::Content')
        expect(chat.messages.first.content).to be_a(RubyLLM::Content)
        expect(chat.messages.first.content.attachments.first).to be_a(RubyLLM::Attachments::Image)
      end

      it "#{provider}/#{model} can understand string file path with auto-detection" do # rubocop:disable RSpec/MultipleExpectations
        chat = RubyLLM.chat(model: model, provider: provider)
        response = chat.ask('What do you see in this image?', with: image_path)

        expect(response.content).to be_present
        expect(chat.messages.first.content).to be_a(RubyLLM::Content)
        expect(chat.messages.first.content.attachments.first).to be_a(RubyLLM::Attachments::Image)
      end
    end
  end

  describe 'audio models' do # rubocop:disable RSpec/MultipleMemoizedHelpers
    AUDIO_MODELS.each do |model_info|
      model = model_info[:model]
      provider = model_info[:provider]
      it "#{provider}/#{model} can understand audio" do # rubocop:disable RSpec/MultipleExpectations,RSpec/ExampleLength
        chat = RubyLLM.chat(model: model, provider: provider)
        response = chat.ask('What is being said?', with: { audio: audio_path })

        expect(response.content).to be_present
        expect(response.content).not_to include('RubyLLM::Content')
        expect(chat.messages.first.content).to be_a(RubyLLM::Content)
        expect(chat.messages.first.content.attachments.first).to be_a(RubyLLM::Attachments::Audio)
      end
    end
  end

  describe 'pdf models' do # rubocop:disable RSpec/MultipleMemoizedHelpers
    PDF_MODELS.each do |model_info|
      model = model_info[:model]
      provider = model_info[:provider]
      it "#{provider}/#{model} understands PDFs" do # rubocop:disable RSpec/MultipleExpectations,RSpec/ExampleLength
        chat = RubyLLM.chat(model: model, provider: provider)
        response = chat.ask('Summarize this document', with: { pdf: pdf_path })
        expect(response.content).not_to be_empty
        expect(response.content).not_to include('RubyLLM::Content')

        response = chat.ask 'go on'
        expect(response.content).not_to be_empty
      end

      it "#{provider}/#{model} handles multiple PDFs" do # rubocop:disable RSpec/MultipleExpectations,RSpec/ExampleLength
        chat = RubyLLM.chat(model: model, provider: provider)
        # Using same file twice for testing
        response = chat.ask('Compare these documents', with: { pdf: [pdf_path, remote_pdf_path] })
        expect(response.content).not_to be_empty
        expect(response.content).not_to include('RubyLLM::Content')

        response = chat.ask 'go on'
        expect(response.content).not_to be_empty
      end

      it "#{provider}/#{model} can handle array of mixed files with auto-detection" do # rubocop:disable RSpec/ExampleLength,RSpec/MultipleExpectations
        chat = RubyLLM.chat(model: model, provider: provider)
        response = chat.ask('Analyze these files', with: [image_path, pdf_path])

        expect(response.content).to be_present
        expect(chat.messages.first.content).to be_a(RubyLLM::Content)
        expect(chat.messages.first.content.attachments.size).to eq(2)

        # Check we have one of each type
        attachment_types = chat.messages.first.content.attachments.map(&:class)
        expect(attachment_types).to include(RubyLLM::Attachments::Image)
        expect(attachment_types).to include(RubyLLM::Attachments::PDF)
      end
    end
  end
end
