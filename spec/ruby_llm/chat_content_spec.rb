# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Chat do # rubocop:disable RSpec/MultipleMemoizedHelpers
  include_context 'with configured RubyLLM'

  let(:image_path) { File.expand_path('../fixtures/ruby.png', __dir__) }
  let(:audio_path) { File.expand_path('../fixtures/ruby.wav', __dir__) }
  let(:pdf_path) { File.expand_path('../fixtures/sample.pdf', __dir__) }
  let(:text_path) { File.expand_path('../fixtures/ruby.txt', __dir__) }
  let(:xml_path) { File.expand_path('../fixtures/ruby.xml', __dir__) }
  let(:image_url) { 'https://upload.wikimedia.org/wikipedia/commons/f/f1/Ruby_logo.png' }
  let(:audio_url) { 'https://commons.wikimedia.org/wiki/File:LL-Q1860_(eng)-AcpoKrane-ruby.wav' }
  let(:pdf_url) { 'https://pdfobject.com/pdf/sample.pdf' }
  let(:text_url) { 'https://www.ruby-lang.org/en/about/license.txt' }
  let(:bad_image_url) { 'https://example.com/eiffel_tower' }
  let(:bad_image_path) { File.expand_path('../fixtures/bad_image.png', __dir__) }
  let(:image_url_no_ext) { 'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcQzSCawxoHrVtf9AX-o7bp7KVxcmkYWzsIjng&s' }

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
        expect(chat.messages.first.content.attachments.first.filename).to eq('ruby.txt')
        expect(chat.messages.first.content.attachments.first.mime_type).to eq('text/plain')

        response = chat.ask('and in this one?', with: xml_path)

        expect(response.content).to be_present
        expect(response.content).not_to include('RubyLLM::Content')
        expect(chat.messages[2].content).to be_a(RubyLLM::Content)
        expect(chat.messages[2].content.attachments.first.filename).to eq('ruby.xml')
        expect(chat.messages[2].content.attachments.first.mime_type).to eq('application/xml')
      end

      it "#{provider}/#{model} can understand remote text" do # rubocop:disable RSpec/MultipleExpectations,RSpec/ExampleLength
        chat = RubyLLM.chat(model: model, provider: provider)
        response = chat.ask("What's in this file?", with: text_url)

        expect(response.content).to be_present
        expect(response.content).not_to include('RubyLLM::Content')
        expect(chat.messages.first.content).to be_a(RubyLLM::Content)
        expect(chat.messages.first.content.attachments.first.filename).to eq('license.txt')
        expect(chat.messages.first.content.attachments.first.mime_type).to eq('text/plain')
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
        expect(chat.messages.first.content.attachments.first.filename).to eq('ruby.png')
        expect(chat.messages.first.content.attachments.first.mime_type).to eq('image/png')
      end

      it "#{provider}/#{model} can understand remote images without extension" do # rubocop:disable RSpec/MultipleExpectations,RSpec/ExampleLength
        chat = RubyLLM.chat(model: model, provider: provider)
        response = chat.ask('What do you see in this image?', with: image_url_no_ext)

        expect(response.content).to be_present
        expect(response.content).not_to include('RubyLLM::Content')
        expect(chat.messages.first.content).to be_a(RubyLLM::Content)
        expect(chat.messages.first.content.attachments.first.filename).to eq('images')
        expect(chat.messages.first.content.attachments.first.mime_type).to eq('image/jpeg')
      end
    end
    model = VISION_MODELS.first[:model]
    provider = VISION_MODELS.first[:provider]
    it "return errors when content doesn't exist" do # rubocop:disable RSpec/ExampleLength,RSpec/MultipleExpectations
      chat = RubyLLM.chat(model: model, provider: provider)
      expect do
        chat.ask('What do you see in this image?', with: bad_image_url)
      end.to raise_error(Faraday::ResourceNotFound)

      chat = RubyLLM.chat(model: model, provider: provider)
      expect do
        chat.ask('What do you see in this image?', with: bad_image_path)
      end.to raise_error(Errno::ENOENT)
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
        expect(chat.messages.first.content.attachments.first.filename).to eq('ruby.wav')
        expect(chat.messages.first.content.attachments.first.mime_type).to eq('audio/wav')
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
        expect(chat.messages.first.content.attachments.first.filename).to eq('sample.pdf')
        expect(chat.messages.first.content.attachments.first.mime_type).to eq('application/pdf')

        response = chat.ask 'go on'
        expect(response.content).not_to be_empty
      end

      it "#{provider}/#{model} handles multiple PDFs" do # rubocop:disable RSpec/MultipleExpectations,RSpec/ExampleLength
        chat = RubyLLM.chat(model: model, provider: provider)
        # Using same file twice for testing
        response = chat.ask('Compare these documents', with: [pdf_path, pdf_url])
        expect(response.content).not_to be_empty
        expect(response.content).not_to include('RubyLLM::Content')
        expect(chat.messages.first.content.attachments.first.filename).to eq('sample.pdf')
        expect(chat.messages.first.content.attachments.first.mime_type).to eq('application/pdf')
        expect(chat.messages.first.content.attachments.second.filename).to eq('sample.pdf')
        expect(chat.messages.first.content.attachments.second.mime_type).to eq('application/pdf')

        response = chat.ask 'go on'
        expect(response.content).not_to be_empty
      end

      it "#{provider}/#{model} can handle array of mixed files with auto-detection" do # rubocop:disable RSpec/ExampleLength,RSpec/MultipleExpectations
        chat = RubyLLM.chat(model: model, provider: provider)
        response = chat.ask('Analyze these files', with: [image_path, pdf_path])

        expect(response.content).to be_present
        expect(chat.messages.first.content).to be_a(RubyLLM::Content)
        expect(chat.messages.first.content.attachments.first.filename).to eq('ruby.png')
        expect(chat.messages.first.content.attachments.first.mime_type).to eq('image/png')
        expect(chat.messages.first.content.attachments.second.filename).to eq('sample.pdf')
        expect(chat.messages.first.content.attachments.second.mime_type).to eq('application/pdf')
      end
    end
  end
end
