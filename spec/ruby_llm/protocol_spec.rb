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

  describe 'provider file defaults' do
    let(:protocol) do
      config = RubyLLM::Configuration.new.tap { |c| c.openai_api_key = 'test' }
      Class.new(described_class).new(RubyLLM::Providers::OpenAI.new(config))
    end

    it 'never uploads attachments on its own' do
      expect(protocol.send(:supports_provider_file_references?)).to be(false)
      expect(protocol.send(:provider_file_attachable?, nil)).to be(false)
      expect(protocol.send(:provider_file_upload_options, nil)).to eq({})
      expect(protocol.send(:provider_file_upload_limit)).to be_nil
      expect(protocol.send(:default_large_file_upload_threshold)).to eq(Float::INFINITY)
      expect(protocol.send(:auto_upload_large_files?)).to be(false)
    end

    it 'accepts any file size when the provider states no limit' do
      attachment = RubyLLM::Attachment.new(StringIO.new('x' * 10), filename: 'a.txt')

      expect { protocol.send(:ensure_provider_file_size!, attachment) }.not_to raise_error
    end

    it 'formats sizes for its error messages' do
      expect(protocol.send(:format_bytes, nil)).to eq('unknown size')
      expect(protocol.send(:format_bytes, 1024 * 1024 * 3)).to eq('3.0 MB')
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
