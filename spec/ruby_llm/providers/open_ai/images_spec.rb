# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::OpenAI::Images do
  describe '.render_image_payload' do
    let(:prompt) { 'describe the edit' }
    let(:size) { '1024x1024' }
    let(:model) { 'gpt-image-1' }
    let(:attachment_path) { File.expand_path('../../../fixtures/ruby.png', __dir__) }

    it 'uses `image` field for single attachment' do
      payload = described_class.render_image_payload(prompt, model:, size:, with: [attachment_path])

      expect(payload[:image]).to be_a(Faraday::Multipart::FilePart)
      expect(payload).not_to have_key(:'image[]')
    end

    it 'uses an array for multiple attachments to emit repeated `image[]` fields' do
      payload = described_class.render_image_payload(prompt, model:, size:, with: [attachment_path, attachment_path])

      expect(payload[:image]).to all(be_a(Faraday::Multipart::FilePart))
      expect(payload[:image].size).to eq(2)
    end
  end
end
