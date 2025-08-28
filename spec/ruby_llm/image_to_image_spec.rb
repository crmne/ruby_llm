# frozen_string_literal: true

require 'spec_helper'
require 'tempfile'

RSpec.describe RubyLLM::Image do
  include_context 'with configured RubyLLM'

  IMAGE_CHAT_MODELS.each do |model_info|
    model = model_info[:model]
    provider = model_info[:provider]

    describe "#{provider}/#{model}" do
      it 'can paint images' do
        chat = RubyLLM.chat(model: model, provider: provider)

        response = chat.ask('put this in a ring', with: 'spec/fixtures/ruby.png')

        expect(response.content.text).to include('ruby')

        expect(response.content.attachments).to be_an(Array)
        expect(response.content.attachments).not_to be_empty

        image = response.content.attachments.first.image

        expect(image.base64?).to be(true)
        expect(image.data).to be_present
        expect(image.mime_type).to include('image')

        save_and_verify_image image
      end

      it 'can refine images in a conversation' do
        chat = RubyLLM.chat(model: model, provider: provider)

        chat.ask('put this in a ring', with: 'spec/fixtures/ruby.png')
        response = chat.ask('change the background to blue')

        expect(response.content.text).to include('ruby')

        expect(response.content.attachments).to be_an(Array)
        expect(response.content.attachments).not_to be_empty

        image = response.content.attachments.first.image

        expect(image.base64?).to be(true)
        expect(image.data).to be_present
        expect(image.mime_type).to include('image')

        save_and_verify_image image
      end
    end

    describe 'streaming functionality' do
      it 'streaming with tools does not raise TypeError when Content objects are returned' do
        chat = RubyLLM.chat(model: model, provider: provider)

        expect do
          chat.ask('Hello') do |chunk|
            # The test is that this block can handle any chunk.content type
            # without the accumulator failing
          end
        end.not_to raise_error
      end

      it 'supports streaming with images' do
        chat = RubyLLM.chat(model: model, provider: provider)
        chunks = []

        response = chat.ask('put this in a ring', with: 'spec/fixtures/ruby.png') do |chunk|
          chunks << chunk
        end

        expect(chunks).not_to be_empty

        content_chunks = chunks.select(&:content)
        expect(content_chunks).not_to be_empty

        expect(response.content.text).to include('ruby')
        expect(response.content.attachments).to be_an(Array)
        expect(response.content.attachments).not_to be_empty

        image = response.content.attachments.first.image
        expect(image.base64?).to be(true)
        expect(image.data).to be_present
        expect(image.mime_type).to include('image')

        save_and_verify_image image
      end

      it 'handles Content objects in streaming without TypeError' do
        chat = RubyLLM.chat(model: model, provider: provider)
        content_objects_received = 0

        expect do
          chat.ask('put this in a ring', with: 'spec/fixtures/ruby.png') do |chunk|
            content_objects_received += 1 if chunk.content.is_a?(RubyLLM::Content)
          end
        end.not_to raise_error

        expect(content_objects_received).to be >= 0
      end

      it 'properly accumulates mixed string and Content chunks' do
        accumulator = RubyLLM::StreamAccumulator.new

        string_chunk = RubyLLM::Chunk.new(
          role: :assistant,
          model_id: 'test-model',
          content: 'Hello, ',
          tool_calls: nil,
          input_tokens: nil,
          output_tokens: nil
        )

        content_with_image = RubyLLM::Content.new('here is an image: ')
        content_with_image.attach(
          RubyLLM::ImageAttachment.new(
            data: 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8/5+hHgAHggJ/PchI7wAAAABJRU5ErkJggg==',
            mime_type: 'image/png',
            model_id: 'test-model'
          )
        )

        content_chunk = RubyLLM::Chunk.new(
          role: :assistant,
          model_id: 'test-model',
          content: content_with_image,
          tool_calls: nil,
          input_tokens: nil,
          output_tokens: nil
        )

        final_string_chunk = RubyLLM::Chunk.new(
          role: :assistant,
          model_id: 'test-model',
          content: ' Done!',
          tool_calls: nil,
          input_tokens: nil,
          output_tokens: nil
        )

        expect do
          accumulator.add(string_chunk)
          accumulator.add(content_chunk)
          accumulator.add(final_string_chunk)
        end.not_to raise_error

        response = double
        message = accumulator.to_message(response)

        expect(message.content).to be_a(RubyLLM::Content)
        expect(message.content.text).to eq('Hello, here is an image:  Done!')
        expect(message.content.attachments).not_to be_empty
        expect(message.content.attachments.first).to be_a(RubyLLM::ImageAttachment)
      end
    end
  end
end
