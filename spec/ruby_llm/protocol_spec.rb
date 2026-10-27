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

      expect(protocol.send(:preprocess_attachment, attachment, nil, nil).resolution).to eq(:high)
    end

    it 'keeps the processing mode when it uploads a large video' do
      attachment = RubyLLM::Attachment.new(StringIO.new('mp4'), filename: 'a.mp4', processing: :agentic)
      upload = RubyLLM::UploadedFile.new(id: 'file_123', filename: 'a.mp4', mime_type: 'video/mp4')
      allow(protocol).to receive_messages(upload_large_attachment?: true, provider_upload: upload)

      expect(protocol.send(:preprocess_attachment, attachment, nil, nil))
        .to have_attributes(provider_file_id: 'file_123', processing: :agentic)
    end
  end

  describe 'large attachments without file storage' do
    let(:report) { RubyLLM::Attachment.new(StringIO.new('%PDF-1.4 long enough to upload'), filename: 'report.pdf') }
    let(:report_text) { RubyLLM::Attachment.new(StringIO.new('Quarterly revenue grew.'), filename: 'report.txt') }
    let(:bucket) { nil }

    before do
      upload = RubyLLM::UploadedFile.new(id: 'stored-report', filename: 'report.pdf', mime_type: 'application/pdf')
      allow(provider).to receive(:upload_file).and_return(upload)
    end

    def preprocess(&handler)
      message = RubyLLM::Message.new(role: :user, content: 'Summarize this', attachments: [report])
      protocol.preprocess_message(message, unsupported_attachment: handler).attachments
    end

    shared_examples 'storage in a bucket' do |setting, bucket_uri|
      it 'uses what the handler converts the attachment into' do
        expect(preprocess { report_text }).to eq([report_text])
        expect(provider).not_to have_received(:upload_file)
      end

      it 'raises the storage error before uploading without a handler' do
        expect { preprocess }.to raise_error(RubyLLM::ConfigurationError, /Set #{setting} to/)
        expect(provider).not_to have_received(:upload_file)
      end

      it 'raises the storage error when the handler cannot convert' do
        expect { preprocess { nil } }.to raise_error(RubyLLM::ConfigurationError, /Set #{setting} to/)
      end

      it 'refuses a handler result that is not an attachment' do
        expect { preprocess { 'text' } }.to raise_error(ArgumentError, /must return a RubyLLM::Attachment/)
      end

      context 'with a bucket' do
        let(:bucket) { bucket_uri }

        it 'uploads instead of converting' do
          expect(preprocess { report_text }.map(&:provider_file_id)).to eq(['stored-report'])
        end
      end
    end

    context 'with Bedrock Converse' do
      let(:provider) do
        RubyLLM::Providers::Bedrock.new(RubyLLM::Configuration.new.tap do |c|
          c.bedrock_api_key = 'key'
          c.bedrock_secret_key = 'secret'
          c.bedrock_region = 'eu-central-1'
          c.bedrock_batch_s3_uri = bucket
        end)
      end
      let(:protocol) { RubyLLM::Protocols::Converse.new(provider) }

      before { stub_const('RubyLLM::Protocols::Converse::Chat::BEDROCK_INLINE_DOCUMENT_LIMIT', 16) }

      it_behaves_like 'storage in a bucket', 'bedrock_batch_s3_uri', 's3://ruby-llm-test/uploads'
    end

    context 'with Gemini on Vertex AI' do
      let(:provider) do
        RubyLLM::Providers::VertexAI.new(RubyLLM::Configuration.new.tap do |c|
          c.vertexai_project_id = 'test-project'
          c.vertexai_location = 'europe-west4'
          c.vertexai_batch_gcs_uri = bucket
        end)
      end
      let(:protocol) { RubyLLM::Providers::VertexAI::Gemini.new(provider) }

      before { stub_const('RubyLLM::Protocols::Gemini::Chat::VERTEX_INLINE_FILE_THRESHOLD', 16) }

      it_behaves_like 'storage in a bucket', 'vertexai_batch_gcs_uri', 'gs://ruby-llm-test/uploads'
    end

    context 'with a provider that keeps its own files' do
      let(:provider) do
        RubyLLM::Providers::Anthropic.new(RubyLLM::Configuration.new.tap { |c| c.anthropic_api_key = 'test' })
      end
      let(:protocol) { RubyLLM::Protocols::Anthropic.new(provider) }

      before { stub_const('RubyLLM::Protocols::Anthropic::Chat::ANTHROPIC_INLINE_REQUEST_LIMIT', 16) }

      it 'uploads without asking the handler' do
        expect(preprocess { report_text }.map(&:provider_file_id)).to eq(['stored-report'])
      end
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
