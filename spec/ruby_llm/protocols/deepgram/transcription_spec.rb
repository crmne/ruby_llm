# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::Deepgram::Transcription do
  let(:protocol) { Object.new.extend(described_class) }

  def query_for(url)
    URI.decode_www_form(URI.parse(url).query).to_h
  end

  describe '#transcription_url' do
    it 'posts to the listen endpoint with the model in the query' do
      expect(protocol.transcription_url(model: 'nova-3')).to start_with('v1/listen?')
      expect(query_for(protocol.transcription_url(model: 'nova-3'))).to include('model' => 'nova-3')
    end

    it 'asks for smart formatting and utterances by default' do
      params = query_for(protocol.transcription_url(model: 'nova-3'))

      expect(params).to include('smart_format' => 'true', 'utterances' => 'true')
    end

    it 'passes the language hint through' do
      params = query_for(protocol.transcription_url(model: 'nova-3', language: 'es'))

      expect(params['language']).to eq('es')
    end

    it 'leaves the language out when none was given' do
      expect(protocol.transcription_url(model: 'nova-3')).not_to include('language')
    end
  end

  describe '#transcription_params' do
    it 'turns on the current diarizer when speaker names are given' do
      params = protocol.transcription_params(model: 'nova-3', speaker_names: %w[Alice Bob])

      expect(params[:diarize_model]).to eq('latest')
    end

    it 'leaves diarization alone without speaker names' do
      expect(protocol.transcription_params(model: 'nova-3')).not_to have_key(:diarize_model)
    end

    it 'takes provider options as query parameters' do
      params = protocol.transcription_params(
        model: 'nova-3',
        provider_options: { paragraphs: true, keyterm: %w[RubyLLM Faraday] }
      )

      expect(params[:paragraphs]).to be(true)
      expect(params[:keyterm]).to eq(%w[RubyLLM Faraday])
    end

    it 'lets provider options override the defaults' do
      params = protocol.transcription_params(model: 'nova-3', provider_options: { utterances: false })

      expect(params[:utterances]).to be(false)
    end
  end

  describe '#render_transcription_payload' do
    it 'sends a remote url as a JSON pointer for Deepgram to fetch' do
      attachment = RubyLLM::Attachment.new('https://dpgr.am/spacewalk.wav')

      expect(protocol.render_transcription_payload(attachment)).to eq(url: 'https://dpgr.am/spacewalk.wav')
    end

    it 'sends a local file as raw bytes' do
      attachment = RubyLLM::Attachment.new(File.expand_path('../../../fixtures/ruby.wav', __dir__))

      payload = protocol.render_transcription_payload(attachment)

      expect(payload).to be_a(String)
      expect(payload.byteslice(0, 4)).to eq('RIFF')
    end
  end

  describe '#parse_transcription_response' do
    # Shaped after the pre-recorded audio response at
    # https://developers.deepgram.com/docs/pre-recorded-audio
    let(:body) do
      {
        'metadata' => {
          'request_id' => '2479c8c8-8185-40ac-9ac6-f0874419f793',
          'duration' => 25.933313,
          'channels' => 1,
          'model_info' => {
            '30089e05-99d1-4376-b32e-c263170674af' => {
              'name' => '2-general-nova', 'version' => '2024-01-09.29447', 'arch' => 'nova-3'
            }
          }
        },
        'results' => {
          'channels' => [
            {
              'detected_language' => 'en',
              'alternatives' => [
                {
                  'transcript' => 'Yeah. As as much as it is worth celebrating the first spacewalk.',
                  'confidence' => 0.99902344,
                  'words' => [
                    { 'word' => 'yeah', 'start' => 0.08, 'end' => 0.32, 'confidence' => 0.9975586,
                      'punctuated_word' => 'Yeah.', 'speaker' => 0, 'speaker_confidence' => 0.5853265 }
                  ]
                }
              ]
            }
          ],
          'utterances' => [
            { 'start' => 0.08, 'end' => 25.52, 'confidence' => 0.99, 'channel' => 0, 'speaker' => 0,
              'transcript' => 'Yeah. As as much as it is worth celebrating the first spacewalk.' }
          ]
        }
      }
    end

    it 'reads the transcript out of the first alternative of the first channel' do
      transcription = protocol.parse_transcription_response(Struct.new(:body).new(body), model: 'nova-3')

      expect(transcription.text).to eq('Yeah. As as much as it is worth celebrating the first spacewalk.')
      expect(transcription.model).to eq('nova-3')
    end

    it 'reads the duration from the metadata and the detected language from the channel' do
      transcription = protocol.parse_transcription_response(Struct.new(:body).new(body), model: 'nova-3')

      expect(transcription.duration).to eq(25.933313)
      expect(transcription.language).to eq('en')
    end

    it 'keeps the words and the utterances Deepgram timed' do
      transcription = protocol.parse_transcription_response(Struct.new(:body).new(body), model: 'nova-3')

      expect(transcription.words.first).to include('word' => 'yeah', 'speaker' => 0, 'punctuated_word' => 'Yeah.')
      expect(transcription.segments.first).to include('speaker' => 0, 'start' => 0.08)
    end

    it 'survives a response with no results' do
      transcription = protocol.parse_transcription_response(Struct.new(:body).new({}), model: 'nova-3')

      expect(transcription.text).to be_nil
      expect(transcription.words).to be_nil
    end
  end
end
