# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::ChatCompletions::Moderation do
  it 'preserves the raw response alongside normalized verdicts' do
    body = { 'id' => 'moderation-request', 'results' => [{ 'flagged' => false, 'categories' => {},
                                                           'category_scores' => { 'violence' => 0.02 } }] }
    result = described_class.parse_moderation_response(Struct.new(:body).new(body),
                                                       model: RubyLLM.config.default_moderation_model)

    expect(result.raw).to equal(body)
    expect(result).not_to be_flagged
    expect(result.category_scores).to eq('violence' => 0.02)
  end

  describe '.render_moderation_payload' do
    it 'renders text moderation payloads unchanged' do
      payload = described_class.render_moderation_payload(
        'check this',
        model: 'omni-moderation-latest',
        provider_options: { metadata: { source: 'spec' } }
      )

      expect(payload).to eq(
        model: 'omni-moderation-latest',
        input: 'check this',
        metadata: { source: 'spec' }
      )
    end

    it 'renders text and image moderation payloads as content parts' do
      payload = described_class.render_moderation_payload(
        'check this',
        model: 'omni-moderation-latest',
        with: ['https://example.com/safe.png', 'https://example.com/also-safe.png']
      )

      expect(payload).to eq(
        model: 'omni-moderation-latest',
        input: [
          { type: 'text', text: 'check this' },
          {
            type: 'image_url',
            image_url: { url: 'https://example.com/safe.png' }
          },
          {
            type: 'image_url',
            image_url: { url: 'https://example.com/also-safe.png' }
          }
        ]
      )
    end

    it 'renders image-only moderation payloads' do
      image = RubyLLM::Attachment.new('https://example.com/safe.png')

      payload = described_class.render_moderation_payload(
        nil,
        model: 'omni-moderation-latest',
        with: [image]
      )

      expect(payload[:input]).to eq(
        [
          {
            type: 'image_url',
            image_url: { url: 'https://example.com/safe.png' }
          }
        ]
      )
    end

    it 'rejects non-image attachments' do
      attachment = RubyLLM::Attachment.new(StringIO.new('hello'), filename: 'note.txt')

      expect do
        described_class.render_moderation_payload(nil, model: 'omni-moderation-latest', with: [attachment])
      end.to raise_error(RubyLLM::UnsupportedAttachmentError, %r{text/plain})
    end
  end
end
