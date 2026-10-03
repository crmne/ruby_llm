# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Transcription, :live do
  let(:audio_path) { File.expand_path('../fixtures/ruby.wav', __dir__) }

  describe '#cost', live: false do
    it 'prices a Vertex AI transcription from the Vertex AI registry entry' do
      id = model_for(:vertexai, :transcription)
      gemini, vertexai = { 'gemini' => 0.5, 'vertexai' => 1.0 }.map do |provider, rate|
        price = { standard: { input_per_million: rate, output_per_million: rate * 4 } }
        RubyLLM::Model.new(id:, provider:, pricing: { audio_tokens: price })
      end
      allow(RubyLLM::Models).to receive(:instance).and_return(RubyLLM::Models.new([gemini, vertexai]))
      credentials = instance_double(RubyLLM::Providers::VertexAI::Credentials, headers: {})
      allow(RubyLLM::Providers::VertexAI::Credentials).to receive(:for).and_return(credentials)
      context = RubyLLM.context do |config|
        config.vertexai_project_id = 'test-project'
        config.vertexai_location = 'global'
      end
      stub_request(:post, 'https://aiplatform.googleapis.com/v1beta1/projects/test-project/locations/global/' \
                          "publishers/google/models/#{id}:generateContent")
        .to_return(headers: { 'Content-Type' => 'application/json' }, body: {
          candidates: [{ content: { role: 'model', parts: [{ text: 'Ruby is fun.' }] }, finishReason: 'STOP' }],
          usageMetadata: { promptTokenCount: 1000, candidatesTokenCount: 500, totalTokenCount: 1500 },
          modelVersion: id
        }.to_json)

      transcription = described_class.transcribe(audio_path, model: id, provider: :vertexai, context:)

      expect(transcription.text).to eq('Ruby is fun.')
      expect(transcription.model_info).to eq(vertexai)
      expect(transcription.cost.total).to be_within(1e-12).of(0.003)
      expect(transcription.ruby_llm_usage_entries).to contain_exactly(
        have_attributes(provider: 'vertexai', cost: have_attributes(total: transcription.cost.total))
      )
    end
  end

  describe 'basic functionality' do
    each_model(TRANSCRIPTION_MODELS) do |provider, model|
      it "#{provider}/#{model} can transcribe audio" do
        transcription = RubyLLM.transcribe(audio_path, model: model, provider: provider)

        expect(transcription.text).to match(/ruby/i)
        expect(transcription.model).to eq(model)
      end

      it "#{provider}/#{model} can transcribe with language hint" do
        transcription = RubyLLM.transcribe(audio_path, model: model, provider: provider, language: 'en')

        expect(transcription.text).to match(/ruby/i)
        expect(transcription.model).to eq(model)
      end
    end

    it "xai/#{model_for(:xai, :transcription)} labels words with speakers when speaker names are given" do
      transcription = RubyLLM.transcribe(audio_path, model: model_for(:xai, :transcription), provider: :xai,
                                                     speaker_names: ['Speaker'])

      expect(transcription.text).to match(/ruby/i)
      expect(transcription.words).to be_an(Array)
      expect(transcription.words.first).to have_key('speaker')
    end

    it "mistral/#{model_for(:mistral, :transcription)} labels segments with speakers when speaker names are given" do
      transcription = RubyLLM.transcribe(audio_path, model: model_for(:mistral, :transcription), provider: :mistral,
                                                     speaker_names: ['Speaker'])

      expect(transcription.text).to match(/ruby/i)
      expect(transcription.segments).to be_an(Array)
      expect(transcription.segments.first).to have_key('speaker_id')
    end

    it "openai/#{model_for(:openai, :streaming_transcription)} " \
       'streams text deltas and returns the final transcription' do
      chunks = []

      transcription = RubyLLM.transcribe(audio_path, model: model_for(:openai, :streaming_transcription),
                                                     provider: :openai) do |chunk|
        chunks << chunk
      end

      expect(chunks).not_to be_empty
      expect(chunks.first).to be_a(RubyLLM::TranscriptionChunk)
      expect(chunks.filter_map(&:delta).join).to match(/ruby/i)
      expect(chunks.last).to be_done
      expect(transcription.text).to match(/ruby/i)
      expect(transcription.model).to eq(model_for(:openai, :streaming_transcription))
    end

    it "openai/#{model_for(:openai, :transcription)} streams segments labelled with speakers" do
      chunks = []

      transcription = RubyLLM.transcribe(audio_path, model: model_for(:openai, :transcription),
                                                     provider: :openai) do |chunk|
        chunks << chunk
      end

      segments = chunks.select(&:segment?)
      expect(segments).not_to be_empty
      expect(segments.first.segment).to have_key('speaker')
      expect(transcription.text).to match(/ruby/i)
      expect(transcription.segments).to eq(segments.map(&:segment))
    end

    it 'streams Mistral transcriptions with speaker segments and usage' do
      chunks = []

      transcription = RubyLLM.transcribe(audio_path, model: model_for(:mistral, :transcription),
                                                     provider: :mistral, speaker_names: ['Speaker']) do |chunk|
        chunks << chunk
      end

      expect(chunks.last).to be_done
      expect(transcription.text).to match(/ruby/i)
      expect(transcription.segments.first).to have_key('speaker_id')
      expect(transcription.tokens.input).to be_positive
      expect(transcription.duration).to be_positive
    end

    it 'raises for providers that do not stream transcriptions' do
      expect do
        RubyLLM.transcribe(audio_path, model: model_for(:gemini), provider: :gemini) { |chunk| chunk }
      end.to raise_error(RubyLLM::Error, /doesn't support streaming transcription/)
    end

    it 'validates model existence' do
      expect do
        RubyLLM.transcribe(audio_path, model: 'invalid-transcription-model')
      end.to raise_error(RubyLLM::ModelNotFoundError)
    end

    it 'rejects unknown keyword arguments' do
      expect do
        RubyLLM.transcribe(audio_path, unsupported: true)
      end.to raise_error(ArgumentError, /unknown keyword/)
    end
  end
end
