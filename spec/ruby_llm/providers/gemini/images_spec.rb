# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Gemini::Images do
  describe '#render_image_payload' do
    let(:test_obj) { Object.new.tap { |obj| obj.extend(described_class) } }

    it 'raises an error when attachments are used with imagen models' do
      expect do
        test_obj.render_image_payload(
          'describe the edit',
          model: 'imagen-4.0-generate-001',
          size: '1024x1024',
          with: ['test.png']
        )
      end.to raise_error(RubyLLM::Error, /Image editing is only supported for/)
    end

    it 'raises a clear error when attachment files are missing' do
      expect do
        test_obj.render_image_payload(
          'describe the edit',
          model: 'gemini-2.5-flash-image',
          size: '1024x1024',
          with: ['missing.png']
        )
      end.to raise_error(ArgumentError, /File not found: missing\.png/)
    end
  end

  describe '#images_url' do
    let(:test_obj) { Object.new.tap { |obj| obj.extend(described_class) } }

    it 'uses generateContent for flash image models' do
      expect(test_obj.images_url(model: 'gemini-2.5-flash-image')).to eq(
        'models/gemini-2.5-flash-image:generateContent'
      )
    end

    it 'uses generateContent for pro image models' do
      expect(test_obj.images_url(model: 'gemini-3-pro-image-preview')).to eq(
        'models/gemini-3-pro-image-preview:generateContent'
      )
    end

    it 'uses predict for imagen models' do
      expect(test_obj.images_url(model: 'imagen-4.0-generate-001')).to eq('models/imagen-4.0-generate-001:predict')
    end
  end
end
