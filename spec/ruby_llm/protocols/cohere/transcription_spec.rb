# frozen_string_literal: true

require 'spec_helper'

# Fixtures follow the multipart request and response published at
# https://docs.cohere.com/reference/create-audio-transcription.
RSpec.describe RubyLLM::Protocols::Cohere::Transcription do
  let(:protocol) { Object.new.extend(described_class) }
  let(:file_part) { instance_double(Faraday::Multipart::FilePart) }

  def render(**options)
    protocol.send(
      :render_transcription_payload,
      file_part,
      model: 'cohere-transcribe-03-2026', language: 'en', **options
    )
  end

  describe '#transcription_url' do
    it 'posts to the v2 audio transcriptions endpoint' do
      expect(protocol.send(:transcription_url)).to eq('v2/audio/transcriptions')
    end
  end

  describe '#render_transcription_payload' do
    it 'renders the multipart fields Cohere requires' do
      expect(render).to eq(model: 'cohere-transcribe-03-2026', file: file_part, language: 'en')
    end

    # Cohere requires a language and does no automatic detection.
    it 'defaults the required language' do
      expect(render(language: nil)[:language]).to eq('en')
    end

    it 'passes temperature through' do
      expect(render(temperature: 0.2)[:temperature]).to eq(0.2)
    end

    it 'drops the options Cohere Transcribe does not support' do
      payload = render(format: 'verbose_json', speaker_names: ['Alice'], prompt: 'Ruby')

      expect(payload.keys).to contain_exactly(:model, :file, :language)
    end

    it 'merges provider options' do
      expect(render(provider_options: { priority: 1 })[:priority]).to eq(1)
    end
  end

  describe '#parse_transcription_response' do
    it 'reads the transcript' do
      response = instance_double(
        Faraday::Response, body: { 'text' => 'Hello, this is a sample transcription of the audio file.' }
      )

      transcription = protocol.send(:parse_transcription_response, response, model: 'cohere-transcribe-03-2026')

      expect(transcription.text).to eq('Hello, this is a sample transcription of the audio file.')
      expect(transcription.model).to eq('cohere-transcribe-03-2026')
    end

    # The documented response carries the transcript alone.
    it 'reports no timestamps, segments, or speakers' do
      response = instance_double(Faraday::Response, body: { 'text' => 'Ruby' })

      transcription = protocol.send(:parse_transcription_response, response, model: 'cohere-transcribe-03-2026')

      expect(transcription.segments).to be_nil
      expect(transcription.words).to be_nil
      expect(transcription.duration).to be_nil
    end
  end
end
