# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::Gemini::Transcription do
  let(:protocol) { Object.new.tap { |object| object.extend(described_class) } }
  let(:audio) { RubyLLM::Attachment.new(File.expand_path('../../../fixtures/ruby.wav', __dir__)) }

  describe '#render_transcription_payload' do
    it 'sends the audio inline with the default prompt' do
      payload = protocol.send(:render_transcription_payload, audio, language: nil)

      parts = payload[:contents].first[:parts]
      expect(parts.first[:text]).to eq(described_class::DEFAULT_PROMPT)
      expect(parts.last[:inline_data][:mime_type]).to eq('audio/wav')
      expect(payload[:generationConfig]).to eq(responseMimeType: 'text/plain')
    end

    it 'asks for a language and appends a custom prompt' do
      payload = protocol.send(
        :render_transcription_payload, audio, language: 'Italian', prompt: 'Keep the punctuation.'
      )

      expect(payload[:contents].first[:parts].first[:text]).to eq(
        "#{described_class::DEFAULT_PROMPT} Respond in the Italian language. Keep the punctuation."
      )
    end

    it 'passes the requested format and temperature through' do
      payload = protocol.send(
        :render_transcription_payload, audio, language: nil, format: 'application/json', temperature: 0.2
      )

      expect(payload[:generationConfig]).to eq(responseMimeType: 'application/json', temperature: 0.2)
    end

    it 'refuses an attachment that is not audio' do
      attachment = RubyLLM::Attachment.new(StringIO.new('not audio'), filename: 'notes.txt')

      expect { protocol.send(:render_transcription_payload, attachment, language: nil) }.to raise_error(
        RubyLLM::UnsupportedAttachmentError
      )
    end
  end

  describe '#parse_transcription_response' do
    def parse(body)
      protocol.send(:parse_transcription_response, Struct.new(:body).new(body), model: 'gemini-2.5-flash')
    end

    it 'joins the text parts and reads the token counts' do
      transcription = parse(
        {
          'candidates' => [{ 'content' => { 'parts' => [{ 'text' => 'Ruby ' }, { 'text' => 'is fun' }] } }],
          'usageMetadata' => { 'promptTokenCount' => 12, 'candidatesTokenCount' => 4 }
        }
      )

      expect(transcription.text).to eq('Ruby is fun')
      expect(transcription.model).to eq('gemini-2.5-flash')
      expect(transcription.tokens.input).to eq(12)
      expect(transcription.tokens.output).to eq(4)
    end

    it 'leaves the text nil when the response carries no candidate' do
      expect(parse({}).text).to be_nil
      expect(parse('not a hash').text).to be_nil
    end

    it 'leaves the text nil when the candidate carries no text parts' do
      expect(parse({ 'candidates' => [{ 'content' => { 'parts' => [{ 'inlineData' => {} }] } }] }).text).to be_nil
      expect(parse({ 'candidates' => [{ 'content' => {} }] }).text).to be_nil
    end

    it 'leaves the token counts nil when the response carries no usage' do
      transcription = parse({ 'candidates' => [{ 'content' => { 'parts' => [{ 'text' => 'hi' }] } }] })

      expect(transcription.tokens.input).to be_nil
      expect(transcription.tokens.output).to be_nil
    end
  end
end
