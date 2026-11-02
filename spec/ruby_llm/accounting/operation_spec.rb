# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Accounting::Operation do
  recorder_class = Class.new do
    attr_reader :name, :started, :payload

    def instrument(name, payload)
      @name = name
      @started = payload.keys
      @payload = payload
      yield
    end
  end

  define_method(:recorder) { @recorder ||= recorder_class.new }

  def context
    @context ||= begin
      instrumenter = recorder
      RubyLLM.context { |config| config.instrumenter = instrumenter }
    end
  end

  def config
    context.config
  end

  def model
    @model ||= RubyLLM::Model.default('requested-model', 'fake')
  end

  def provider
    @provider ||= instance_double(RubyLLM::Provider, slug: 'fake', name: 'Fake')
  end

  def common
    { provider: 'fake', provider_class: 'Fake', model: 'requested-model', model_info: model }
  end

  def usage_keys
    %i[tokens cost]
  end

  before do
    allow(RubyLLM::Models).to receive(:resolve).and_return([model, provider])
    allow(RubyLLM::Cost).to receive(:new).and_call_original
  end

  def expect_resolved(requested, **options)
    expect(RubyLLM::Models).to have_received(:resolve)
      .with(requested, provider: :fake, assume_model_exists: true, config:, **options)
  end

  def expect_cost_category(category)
    expect(RubyLLM::Cost).to have_received(:new).with(tokens: an_instance_of(RubyLLM::Tokens), model:, category:).once
  end

  def expect_default_cost_category
    expect(RubyLLM::Cost).to have_received(:new).with(tokens: an_instance_of(RubyLLM::Tokens), model:).once
  end

  def expect_usage_of(result)
    expect(recorder.payload[:tokens].to_h).to eq(result.tokens.to_h)
    expect(recorder.payload[:cost].to_h).to eq(result.cost.to_h)
  end

  def routing
    { provider: :fake, assume_model_exists: true, context: }
  end

  describe 'embedding.ruby_llm' do
    let(:result) { RubyLLM::Embedding.new(vectors: [[0.1]], model: 'answered-model', input_tokens: 3) }

    before { allow(provider).to receive(:embed).and_return(result) }

    it 'keeps its event fields, their order, and the call to the provider' do
      config.default_embedding_model = 'default-embedder'

      returned = RubyLLM.embed('Ruby', dimensions: 8, task_type: 'query', title: 'T', with: nil,
                                       provider_options: { a: 1 }, metadata: { b: 2 }, owner: nil, **routing)

      expect(returned).to equal(result)
      expect(recorder.name).to eq('embedding.ruby_llm')
      expect(recorder.started).to eq(common.keys + %i[input dimensions task_type title attachment_count
                                                      provider_options metadata tokens cost])
      expect(recorder.payload.keys).to eq(recorder.started + %i[result response_model embedding_dimensions
                                                                embedding_count])
      expect(recorder.payload).to include(
        common.merge(input: 'Ruby', dimensions: 8, task_type: 'query', title: 'T', attachment_count: 0,
                     provider_options: { a: 1 }, metadata: { b: 2 }, result:, response_model: 'answered-model',
                     embedding_dimensions: 1, embedding_count: 1)
      )
      expect_resolved('default-embedder')
      expect_usage_of(result)
      expect_cost_category(:embeddings)
      expect(provider).to have_received(:embed).with('Ruby', model:, dimensions: 8, task_type: 'query', title: 'T',
                                                             with: nil, provider_options: { a: 1 })
    end
  end

  describe 'transcription.ruby_llm' do
    let(:result) { RubyLLM::Transcription.new(text: 'hi', model: 'answered-model') }

    before { allow(provider).to receive(:transcribe).and_return(result) }

    it 'keeps its event fields, their order, and the call to the provider' do
      config.default_transcription_model = 'default-transcriber'

      returned = RubyLLM.transcribe('a.mp3', language: 'en', prompt: 'p', temperature: 0.1, format: 'text',
                                             timestamps: :word, speaker_names: ['A'], speaker_references: ['b'],
                                             provider_options: { a: 1 }, metadata: { b: 2 }, **routing)

      expect(returned).to equal(result)
      expect(recorder.name).to eq('transcription.ruby_llm')
      expect(recorder.started).to eq(common.keys + %i[streaming language temperature provider_options metadata] +
                                     usage_keys)
      expect(recorder.payload.keys).to eq(recorder.started + %i[result response_model])
      expect(recorder.payload).to include(
        common.merge(streaming: false, language: 'en', temperature: 0.1, provider_options: { a: 1 },
                     metadata: { b: 2 }, result:, response_model: 'answered-model')
      )
      expect_resolved('default-transcriber')
      expect_usage_of(result)
      expect_cost_category(:audio_tokens)
      expect(provider).to have_received(:transcribe).with(
        'a.mp3', model:, language: 'en', format: 'text', timestamps: :word, speaker_names: ['A'],
                 speaker_references: ['b'], provider_options: { a: 1 }, prompt: 'p', temperature: 0.1
      )
    end
  end

  describe 'speech.ruby_llm' do
    let(:result) { RubyLLM::Speech.new(data: 'abc', model: 'answered-model', voice: 'reported', format: 'wav') }

    before { allow(provider).to receive(:speak).and_return(result) }

    it 'keeps its event fields, their order, and the call to the provider' do
      config.default_speech_model = 'default-speaker'

      returned = RubyLLM.speak('Hello', voice: 'requested', format: 'mp3', provider_options: { a: 1 },
                                        metadata: { b: 2 }, **routing)

      expect(returned).to equal(result)
      expect(recorder.name).to eq('speech.ruby_llm')
      expect(recorder.started).to eq(common.keys + %i[input voice format provider_options metadata streaming] +
                                     usage_keys)
      expect(recorder.payload.keys).to eq(recorder.started + %i[result response_model audio_bytes])
      expect(recorder.payload).to include(
        common.merge(input: 'Hello', voice: 'reported', format: 'wav', provider_options: { a: 1 },
                     metadata: { b: 2 }, streaming: false, result:, response_model: 'answered-model',
                     audio_bytes: 3)
      )
      expect_resolved('default-speaker')
      expect_usage_of(result)
      expect_cost_category(:audio_tokens)
      expect(provider).to have_received(:speak).with('Hello', model:, voice: 'requested', format: 'mp3',
                                                              provider_options: { a: 1 })
    end

    it 'reports streaming and hands the block to the provider' do
      allow(provider).to receive(:speak).and_yield(:chunk).and_return(result)
      chunks = []

      RubyLLM.speak('Hello', **routing) { |chunk| chunks << chunk }

      expect(chunks).to eq([:chunk])
      expect(recorder.payload[:streaming]).to be(true)
    end
  end

  describe 'image.ruby_llm' do
    let(:first) { RubyLLM::Image.new(model: 'answered-model', usage: { 'input_tokens' => 3 }) }
    let(:second) { RubyLLM::Image.new(model: 'other-model') }

    it 'keeps its event fields, their order, and the call to the provider' do
      allow(provider).to receive(:paint).and_return(first)
      config.default_image_model = 'default-painter'

      returned = RubyLLM.paint('A ruby', size: '1x1', count: 1, with: 'a.png', mask: 'b.png',
                                         provider_options: { a: 1 }, metadata: { b: 2 }, **routing)

      expect(returned).to equal(first)
      expect(recorder.name).to eq('image.ruby_llm')
      expect(recorder.started).to eq(common.keys + %i[prompt size count provider_options metadata] + usage_keys)
      expect(recorder.payload.keys).to eq(recorder.started + %i[result response_model])
      expect(recorder.payload).to include(
        common.merge(prompt: 'A ruby', size: '1x1', count: 1, provider_options: { a: 1 }, metadata: { b: 2 },
                     result: first, response_model: 'answered-model')
      )
      expect(recorder.payload[:tokens].input).to eq(3)
      expect_resolved('default-painter')
      expect_cost_category(:images)
      expect(provider).to have_received(:paint).with('A ruby', model:, size: '1x1', count: 1, with: 'a.png',
                                                               mask: 'b.png', provider_options: { a: 1 })
    end

    it 'reports several images together' do
      allow(provider).to receive(:paint).and_return([first, second])

      expect(RubyLLM.paint('A ruby', **routing)).to eq([first, second])
      expect(recorder.payload).to include(result: [first, second], response_model: 'answered-model')
      expect(recorder.payload[:tokens].input).to eq(3)
    end
  end

  describe 'moderation.ruby_llm' do
    let(:result) do
      flagged = RubyLLM::Moderation::Result.new(flagged: true, categories: [], category_scores: {})
      RubyLLM::Moderation.new(id: '1', model: 'answered-model', results: [flagged])
    end

    before { allow(provider).to receive(:moderate).and_return(result) }

    it 'keeps its event fields, their order, and the call to the provider' do
      config.default_moderation_model = 'default-moderator'

      returned = RubyLLM.moderate('Text', provider_options: { a: 1 }, metadata: { b: 2 }, **routing)

      expect(returned).to equal(result)
      expect(recorder.name).to eq('moderation.ruby_llm')
      expect(recorder.started).to eq(common.keys + %i[input attachment_count provider_options metadata] + usage_keys)
      expect(recorder.payload.keys).to eq(recorder.started + %i[result response_model flagged])
      expect(recorder.payload).to include(
        common.merge(input: 'Text', attachment_count: 0, provider_options: { a: 1 }, metadata: { b: 2 }, result:,
                     response_model: 'answered-model', flagged: true)
      )
      expect_resolved(nil, operation: :moderate, default_model: 'default-moderator')
      expect_usage_of(result)
      expect_default_cost_category
      expect(provider).to have_received(:moderate).with('Text', model:, with: [], provider_options: { a: 1 })
    end

    it 'reports no model id for a provider that moderates without one' do
      allow(RubyLLM::Models).to receive(:resolve).and_return([nil, provider])

      RubyLLM.moderate('Text', **routing)

      expect(recorder.payload).to include(model: nil, model_info: nil)
      expect(provider).to have_received(:moderate).with('Text', model: nil, with: [], provider_options: {})
    end

    it 'rejects an empty request before resolving a model' do
      expect { RubyLLM.moderate(**routing) }.to raise_error(ArgumentError, /must provide input/)
      expect(RubyLLM::Models).not_to have_received(:resolve)
    end
  end

  describe 'rerank.ruby_llm' do
    let(:result) { RubyLLM::Rerank.new(results: [], model: 'answered-model') }

    before { allow(provider).to receive(:rerank).and_return(result) }

    it 'keeps its event fields, their order, and the call to the provider' do
      returned = RubyLLM.rerank('Query', %w[a b], model: 'requested', top_n: 1, provider_options: { a: 1 },
                                                  metadata: { b: 2 }, **routing)

      expect(returned).to equal(result)
      expect(recorder.name).to eq('rerank.ruby_llm')
      expect(recorder.started).to eq(common.keys + %i[query document_count top_n provider_options metadata] +
                                     usage_keys)
      expect(recorder.payload.keys).to eq(recorder.started + %i[result response_model])
      expect(recorder.payload).to include(
        common.merge(query: 'Query', document_count: 2, top_n: 1, provider_options: { a: 1 }, metadata: { b: 2 },
                     result:, response_model: 'answered-model')
      )
      expect_resolved('requested')
      expect_usage_of(result)
      expect_cost_category(:embeddings)
      expect(provider).to have_received(:rerank).with('Query', %w[a b], model:, top_n: 1,
                                                                        provider_options: { a: 1 })
    end
  end

  describe 'judgment.ruby_llm' do
    let(:result) { RubyLLM::Judgment.new(answers: {}, model: 'answered-model', tokens: RubyLLM::Tokens.new(input: 1, output: 2)) }
    let(:questions) { { fair: 'Is it fair?' } }

    before { allow(provider).to receive(:judge).and_return(result) }

    it 'keeps its event fields, their order, and the call to the provider' do
      config.default_judgment_model = 'default-judge'

      returned = RubyLLM::Judgment.judge('Text', questions:, provider_options: { a: 1 }, metadata: { b: 2 },
                                                 **routing)

      expect(returned).to equal(result)
      expect(recorder.name).to eq('judgment.ruby_llm')
      expect(recorder.started).to eq(common.keys + %i[question_count attachment_count provider_options metadata] +
                                     usage_keys)
      expect(recorder.payload.keys).to eq(recorder.started + %i[result response_model])
      expect(recorder.payload).to include(
        common.merge(question_count: 1, attachment_count: 0, provider_options: { a: 1 }, metadata: { b: 2 }, result:,
                     response_model: 'answered-model')
      )
      expect_resolved(nil, operation: :judge, default_model: 'default-judge')
      expect_usage_of(result)
      expect_default_cost_category
      expect(provider).to have_received(:judge).with('Text', questions:, model:, with: [],
                                                             provider_options: { a: 1 })
    end

    it 'rejects a request without a model before resolving one' do
      config.default_judgment_model = nil

      expect { RubyLLM::Judgment.judge('Text', questions:, **routing) }
        .to raise_error(ArgumentError, 'A judgment requires a model')
      expect(RubyLLM::Models).not_to have_received(:resolve)
    end
  end

  describe 'ocr.ruby_llm' do
    let(:result) { RubyLLM::OCR.new(pages: [], model: 'answered-model') }

    before { allow(provider).to receive(:ocr).and_return(result) }

    it 'keeps its event fields without tokens or cost, and the call to the provider' do
      config.default_ocr_model = 'default-reader'

      returned = RubyLLM.ocr('a.pdf', pages: [0], provider_options: { a: 1 }, metadata: { b: 2 }, **routing)

      expect(returned).to equal(result)
      expect(recorder.name).to eq('ocr.ruby_llm')
      expect(recorder.started).to eq(common.keys + %i[pages provider_options metadata])
      expect(recorder.payload.keys).to eq(recorder.started + %i[result response_model])
      expect(recorder.payload).to include(common.merge(pages: [0], provider_options: { a: 1 }, metadata: { b: 2 },
                                                       result:, response_model: 'answered-model'))
      expect_resolved('default-reader')
      expect(RubyLLM::Cost).not_to have_received(:new)
      expect(provider).to have_received(:ocr).with('a.pdf', model:, pages: [0], provider_options: { a: 1 })
    end
  end

  describe 'video_job.ruby_llm' do
    let(:job) { instance_double(RubyLLM::VideoJob, id: 'job-1') }

    before { allow(provider).to receive(:animate_later).and_return(job) }

    it 'keeps its event fields, their order, and the call to the provider' do
      config.default_video_model = 'default-animator'

      returned = RubyLLM::VideoJob.animate_later('A ruby', with: 'a.png', provider_options: { a: 1 },
                                                           metadata: { b: 2 }, **routing)

      expect(returned).to equal(job)
      expect(recorder.name).to eq('video_job.ruby_llm')
      expect(recorder.started).to eq(common.keys + %i[prompt provider_options metadata])
      expect(recorder.payload.keys).to eq(recorder.started + %i[job_id])
      expect(recorder.payload).to include(common.merge(prompt: 'A ruby', provider_options: { a: 1 },
                                                       metadata: { b: 2 }, job_id: 'job-1'))
      expect_resolved('default-animator')
      expect(RubyLLM::Cost).not_to have_received(:new)
      expect(provider).to have_received(:animate_later).with('A ruby', model:, with: 'a.png', extend: nil,
                                                                       provider_options: { a: 1 })
    end
  end

  describe 'a failed attempt' do
    it 'leaves the starting fields on the event' do
      allow(provider).to receive(:speak).and_raise(RubyLLM::Error, 'boom')

      expect { RubyLLM.speak('Hello', **routing) }.to raise_error(RubyLLM::Error, 'boom')
      expect(recorder.payload.keys).to eq(recorder.started)
      expect(recorder.payload[:tokens].input).to be_nil
    end
  end

  describe 'usage ownership' do
    it 'attributes the provider call to the owner' do
      owner = Object.new
      seen = nil
      allow(provider).to receive(:rerank) do
        seen = RubyLLM::Accounting::Usage.owner
        RubyLLM::Rerank.new(results: [], model: 'answered-model')
      end

      RubyLLM.rerank('Query', %w[a], model: 'requested', owner:, **routing)

      expect(seen).to equal(owner)
    end
  end
end
