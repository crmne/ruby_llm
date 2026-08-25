# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Context connection settings' do # rubocop:disable RSpec/DescribeClass
  include_context 'with configured RubyLLM'

  let(:context) do
    RubyLLM.context do |config|
      config.http_proxy = 'http://proxy.example:8080'
      config.request_timeout = 7
    end
  end
  let(:text_url) { 'https://files.example.test/notes.txt' }
  let(:model) { instance_double(RubyLLM::Model, id: 'test-model') }

  def proxy_and_timeout(config)
    connection = RubyLLM::Connection.basic(config)
    [connection.proxy&.uri&.to_s, connection.options.timeout]
  end

  describe RubyLLM::Connection do
    it 'builds a basic connection from the configuration it is given' do
      expect(proxy_and_timeout(context.config)).to eq(['http://proxy.example:8080', 7])
    end

    it 'falls back to the global configuration' do
      expect(proxy_and_timeout(RubyLLM.config)).to eq([nil, RubyLLM.config.request_timeout])
      expect(described_class.basic.options.timeout).to eq(RubyLLM.config.request_timeout)
      expect(described_class.basic.proxy).to be_nil
    end
  end

  describe RubyLLM::Attachment do
    it 'downloads a URL through the configuration it was built with' do
      attachment = described_class.new(text_url, config: context.config)

      expect(proxy_and_timeout(attachment.config)).to eq(['http://proxy.example:8080', 7])
    end

    it 'downloads through the global configuration when none is given' do
      expect(described_class.new(text_url).config).to be(RubyLLM.config)
    end

    it 'carries the configuration through Attachment.wrap' do
      attachment = described_class.wrap(text_url, config: context.config).first

      expect(attachment.config).to be(context.config)
    end
  end

  describe RubyLLM::Chat do
    it 'gives a URL attachment the configuration of the context it was built from' do
      chat = context.chat(model: 'gpt-4.1-nano')
      chat.ask_later('What is this?', with: text_url)

      expect(proxy_and_timeout(chat.messages.last.attachments.first.config)).to eq(['http://proxy.example:8080', 7])
    end

    it 'leaves a chat without a context on the global configuration' do
      chat = RubyLLM.chat(model: 'gpt-4.1-nano')
      chat.ask_later('What is this?', with: text_url)

      expect(chat.messages.last.attachments.first.config).to be(RubyLLM.config)
    end
  end

  describe RubyLLM::Image do
    def paint_with(config)
      provider = RubyLLM::Providers::OpenAI.new(config)
      protocol = RubyLLM::Protocols::ChatCompletions.new(provider, model)
      response = instance_double(Faraday::Response,
                                 body: { 'data' => [{ 'url' => 'https://cdn.example.test/out.png' }] })
      allow(protocol.connection).to receive(:post).and_return(response)
      protocol.paint('a small watercolor robot', model: 'gpt-image-1', size: '1024x1024')
    end

    it 'downloads a hosted image through the configuration that generated it' do
      expect(proxy_and_timeout(paint_with(context.config).config)).to eq(['http://proxy.example:8080', 7])
    end

    it 'downloads through the global configuration by default' do
      expect(paint_with(RubyLLM.config).config).to be(RubyLLM.config)
    end
  end

  describe RubyLLM::Video do
    def finished_job(config)
      protocol = instance_double(RubyLLM::Protocol, config: config)
      allow(protocol).to receive(:download_video)
        .and_return(RubyLLM::Video.new(url: 'https://cdn.example.test/clip.mp4', mime_type: 'video/mp4'))
      RubyLLM::VideoJob.new(id: 'vid_1', protocol: protocol, model: 'test-video-model', status: :completed)
    end

    it 'downloads a hosted video through the configuration that generated it' do
      expect(proxy_and_timeout(finished_job(context.config).video.config)).to eq(['http://proxy.example:8080', 7])
    end

    it 'downloads through the global configuration by default' do
      expect(finished_job(RubyLLM.config).video.config).to be(RubyLLM.config)
    end
  end
end
