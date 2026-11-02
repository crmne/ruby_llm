# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocol do
  describe '#parse_completion_response' do
    let(:protocol_class) do
      Class.new(described_class) do
        private

        def parse_completion_body(data, raw:)
          [data, raw]
        end
      end
    end

    it 'raises RubyLLM::Error for empty completion bodies' do
      protocol = protocol_class.allocate

      [nil, {}, [], ''].each do |body|
        response = instance_double(Faraday::Response, body: body)

        expect do
          protocol.send(:parse_completion_response, response)
        end.to raise_error(RubyLLM::Error, 'Provider returned an empty response body')
      end
    end

    it 'passes non-empty bodies to the protocol parser' do
      protocol = protocol_class.allocate
      response = instance_double(Faraday::Response, body: { 'text' => 'hello' })

      expect(protocol.send(:parse_completion_response, response))
        .to eq([{ 'text' => 'hello' }, response])
    end

    it 'raises RubyLLM::Error when the protocol finds no completion message in the body' do
      messageless_protocol_class = Class.new(described_class) do
        private

        def parse_completion_body(_data, raw:) # rubocop:disable Lint/UnusedMethodArgument
          nil
        end
      end
      protocol = messageless_protocol_class.allocate
      response = instance_double(Faraday::Response, body: { 'choices' => [] })

      expect do
        protocol.send(:parse_completion_response, response)
      end.to raise_error(RubyLLM::Error, 'Provider returned no completion message')
    end
  end

  it 'owns completion response parsing for every registered chat protocol' do
    protocols = RubyLLM::Provider.providers.values.flat_map { |provider| provider.protocols.values }.uniq
    chat_protocols = protocols.select { |protocol| protocol.private_method_defined?(:parse_completion_body) }
    overrides = chat_protocols.reject do |protocol|
      protocol.instance_method(:parse_completion_response).owner == described_class
    end

    expect(chat_protocols).not_to be_empty
    expect(overrides.map(&:name)).to be_empty
  end

  describe 'abstract methods' do
    it 'tells subclasses what they must implement' do
      bare = Class.new(described_class).allocate

      expect { bare.render_payload }.to raise_error(NotImplementedError, /must implement #render_payload/)
      expect { bare.completion_url }.to raise_error(NotImplementedError, /must implement #completion_url/)
      expect { bare.send(:parse_completion_body, {}, raw: nil) }.to raise_error(
        NotImplementedError, /must implement #parse_completion_body/
      )
    end
  end

  describe 'operations a protocol does not implement' do
    let(:protocol) do
      config = RubyLLM::Configuration.new.tap { |c| c.openai_api_key = 'test' }
      Class.new(described_class).new(RubyLLM::Providers::OpenAI.new(config))
    end

    it 'names the provider when a protocol renders chat but cannot send it' do
      config = RubyLLM::Configuration.new.tap { |c| c.openai_api_key = 'test' }
      renders_only = Class.new(described_class) { def render_payload(*, **) = {} }
      renders = renders_only.new(RubyLLM::Providers::OpenAI.new(config))

      expect { renders.complete([], tools: {}, temperature: nil) }
        .to raise_error(RubyLLM::Error, "OpenAI doesn't support chat")
    end

    it 'names the provider and the operation instead of leaking NotImplementedError' do
      expect { protocol.render([], tools: {}, temperature: nil) }
        .to raise_error(RubyLLM::Error, "OpenAI doesn't support chat")
      expect { protocol.complete([], tools: {}, temperature: nil) }
        .to raise_error(RubyLLM::Error, "OpenAI doesn't support chat")
      expect { protocol.embed('hi', model: 'x', dimensions: nil) }
        .to raise_error(RubyLLM::Error, "OpenAI doesn't support embeddings")
      expect { protocol.moderate('hi', model: 'x') }
        .to raise_error(RubyLLM::Error, "OpenAI doesn't support moderation")
      expect { protocol.paint('a ruby', model: 'x', size: nil) }
        .to raise_error(RubyLLM::Error, "OpenAI doesn't support image generation")
    end

    {
      'remote tool approvals' => lambda { |protocol|
        protocol.tool_approval_response(RubyLLM::ToolCall.new(id: '1', name: 't', arguments: {}), approved: true)
      },
      'token counting' => ->(protocol) { protocol.count_tokens([], tools: {}) },
      'text tokenization' => ->(protocol) { protocol.tokenize('hi', model: 'x') },
      'manual compaction' => ->(protocol) { protocol.compact([]) },
      'video generation' => ->(protocol) { protocol.animate_later('a ruby', model: 'x') },
      'speech generation' => ->(protocol) { protocol.speak('hi', model: 'x', voice: nil, format: nil) },
      'transcription' => ->(protocol) { protocol.transcribe(StringIO.new('a'), model: 'x', language: nil) },
      'OCR' => ->(protocol) { protocol.ocr('file', model: 'x') },
      'reranking' => ->(protocol) { protocol.rerank('q', %w[a], model: 'x') },
      'judgments' => ->(protocol) { protocol.judge('hi', questions: [], model: 'x') },
      'explicit content caching' => ->(protocol) { protocol.find_cache('name') }
    }.each do |label, call|
      it "names #{label} when its seams are missing" do
        expect { call.call(protocol) }.to raise_error(RubyLLM::Error, "OpenAI doesn't support #{label}")
      end
    end

    it 'reports the remaining caching and video operations the same way' do
      expect { protocol.delete_cache('name') }
        .to raise_error(RubyLLM::Error, "OpenAI doesn't support explicit content caching")
      expect { protocol.extend_cache('name', ttl: 60) }
        .to raise_error(RubyLLM::Error, "OpenAI doesn't support explicit content caching")
      expect { protocol.cache_content('text', model: 'x') }
        .to raise_error(RubyLLM::Error, "OpenAI doesn't support explicit content caching")
      expect { protocol.find_video_job('id', model: 'x') }
        .to raise_error(RubyLLM::Error, "OpenAI doesn't support video generation")
    end

    it 'leaves a subclass that replaces an operation to answer for itself' do
      replaced = Class.new(described_class) { def embed(*, **) = raise(NotImplementedError, 'mine') }

      expect { replaced.allocate.embed('hi', model: 'x') }.to raise_error(NotImplementedError, 'mine')
    end

    it 'keeps a subclass that calls super under the translation' do
      config = RubyLLM::Configuration.new.tap { |c| c.openai_api_key = 'test' }
      extended = Class.new(described_class) { def embed(*, **) = super }

      expect { extended.new(RubyLLM::Providers::OpenAI.new(config)).embed('hi', model: 'x', dimensions: nil) }
        .to raise_error(RubyLLM::Error, "OpenAI doesn't support embeddings")
    end

    it 'does not claim chat is unsupported when a streaming block raises NotImplementedError' do
      config = RubyLLM::Configuration.new.tap { |c| c.openai_api_key = 'test' }
      streaming = Class.new(described_class) do
        def stream_response(*)
          yield :chunk
        end
      end.new(RubyLLM::Providers::OpenAI.new(config))

      allow(RubyLLM::Accounting::Usage::Tracker).to receive(:new).and_return(
        instance_double(RubyLLM::Accounting::Usage::Tracker, observe: nil, cancel_pending: nil)
      )

      expect { streaming.complete_request({}, {}) { raise NotImplementedError, 'from the caller' } }
        .to raise_error(NotImplementedError, 'from the caller')
    end
  end

  describe '#embed' do
    let(:context) { RubyLLM.context { |config| config.openai_api_key = 'test' } }
    let(:model) { model_for(:openai, :embedding) }

    def stub_embeddings(rows)
      stub_request(:post, 'https://api.openai.com/v1/embeddings')
        .to_return_json(body: { data: rows, usage: { prompt_tokens: 3 } })
    end

    def embed(text)
      RubyLLM.embed(text, model:, provider: :openai, context:)
    end

    it 'raises when the provider returns fewer embeddings than texts' do
      stub_embeddings([{ index: 0, embedding: [0.1] }])

      expect { embed(%w[Ruby Python JavaScript]) }
        .to raise_error(RubyLLM::Error, 'Expected 3 embeddings, got 1')
    end

    it 'returns one embedding per text' do
      stub_embeddings([{ index: 0, embedding: [0.1] }, { index: 1, embedding: [0.2] }])

      expect(embed(%w[Ruby Python]).vectors).to eq([[0.1], [0.2]])
    end

    it 'returns the single vector for a single text' do
      stub_embeddings([{ index: 0, embedding: [0.1] }])

      expect(embed('Ruby').vectors).to eq([0.1])
    end
  end

  describe 'provider file defaults' do
    let(:protocol) do
      config = RubyLLM::Configuration.new.tap { |c| c.openai_api_key = 'test' }
      Class.new(described_class).new(RubyLLM::Providers::OpenAI.new(config))
    end

    it 'never uploads attachments on its own' do
      expect(protocol.send(:provider_file_references?)).to be(false)
      expect(protocol.send(:provider_file_attachable?, nil)).to be(false)
      expect(protocol.send(:provider_file_upload_options, nil)).to eq({})
      expect(protocol.send(:default_large_file_upload_threshold)).to eq(Float::INFINITY)
      expect(protocol.send(:auto_upload_large_files?)).to be(false)
    end

    it 'keeps the resolution when it uploads a large attachment' do
      attachment = RubyLLM::Attachment.new(StringIO.new('pdf'), filename: 'a.pdf', resolution: :high)
      upload = RubyLLM::UploadedFile.new(id: 'file_123', filename: 'a.pdf', mime_type: 'application/pdf')
      allow(protocol).to receive_messages(upload_large_attachment?: true, provider_upload: upload)

      expect(protocol.send(:preprocess_attachment, attachment).resolution).to eq(:high)
    end

    it 'keeps the processing mode when it uploads a large video' do
      attachment = RubyLLM::Attachment.new(StringIO.new('mp4'), filename: 'a.mp4', processing: :agentic)
      upload = RubyLLM::UploadedFile.new(id: 'file_123', filename: 'a.mp4', mime_type: 'video/mp4')
      allow(protocol).to receive_messages(upload_large_attachment?: true, provider_upload: upload)

      expect(protocol.send(:preprocess_attachment, attachment)).to have_attributes(provider_file_id: 'file_123',
                                                                                   processing: :agentic)
    end
  end

  describe '#validate_paint_inputs!' do
    let(:protocol) do
      config = RubyLLM::Configuration.new.tap { |c| c.openai_api_key = 'test' }
      Class.new(described_class).new(RubyLLM::Providers::OpenAI.new(config))
    end

    it 'accepts a plain prompt' do
      expect { protocol.send(:validate_paint_inputs!, with: nil, mask: nil) }.not_to raise_error
    end

    it 'refuses image references the protocol cannot send' do
      expect { protocol.send(:validate_paint_inputs!, with: 'ref.png', mask: nil) }.to raise_error(
        RubyLLM::UnsupportedAttachmentError, /image reference/
      )
    end
  end
end
