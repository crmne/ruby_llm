# frozen_string_literal: true

require 'spec_helper'

class ZAICountingWeather < RubyLLM::Tool
  description 'Gets current weather for a city'
  parameter :city, description: 'City name'

  def execute(city:)
    "It's sunny in #{city}."
  end
end

RSpec.describe RubyLLM::Providers::ZAI do
  let(:config) do
    RubyLLM.config.dup.tap { |config| config.zai_api_key ||= 'test' }
  end
  let(:provider) { described_class.new(config) }
  let(:model) { RubyLLM.models.find('glm-5.3-flash', provider: 'zai') }
  let(:protocol) { described_class::ChatCompletions.new(provider, model) }

  def response(body)
    instance_double(Faraday::Response, body:, status: 200, headers: {})
  end

  describe 'token counting' do
    it 'sends only the fields the tokenizer accepts' do
      message = RubyLLM::Message.new(role: :user, content: 'Hello')
      tool = ZAICountingWeather.new

      payload = protocol.render_count_tokens_payload(
        [message], tools: { tool.name.to_sym => tool }, model: model, thinking: nil, schema: nil,
                   tool_prefs: { choice: :auto }, citations: false, caching: nil
      )

      expect(payload.keys).to contain_exactly(:model, :messages, :tools)
      expect(protocol.count_tokens_url).to eq('tokenizer')
    end

    it 'includes image tokens in the count' do
      body = { 'usage' => { 'prompt_tokens' => 16, 'image_tokens' => 640, 'total_tokens' => 656 } }

      expect(protocol.parse_count_tokens_response(response(body))).to eq(656)
    end

    it 'counts instructions, tools and images before generation', :live do
      chat = RubyLLM.chat(model: 'glm-5.3-flash', provider: :zai)
      base = chat.count_tokens('What is the weather in Berlin?')
      chat.ask_later('What is the weather in Berlin?')

      expect(base).to be_positive
      expect(chat.with_instructions('Be terse.').with_tools(ZAICountingWeather).count_tokens).to be > base

      image = File.expand_path('../../fixtures/ruby.png', __dir__)
      vision = RubyLLM.chat(model: 'glm-5.3-flash', provider: :zai)
      vision.ask_later('What is the weather in Berlin?', with: image)
      expect(vision.count_tokens).to be > base
    end
  end

  describe 'OCR' do
    let(:pdf) { File.expand_path('../../fixtures/sample.pdf', __dir__) }

    it 'turns zero-based pages into a one-based range' do
      payload = protocol.render_ocr_payload(pdf, model: 'glm-ocr', pages: [1, 2])

      expect(payload).to include(model: 'glm-ocr', start_page_id: 2, end_page_id: 3)
      expect(payload[:file]).to start_with('data:application/pdf;base64,')
    end

    it 'refuses pages that are not one continuous range' do
      expect { protocol.render_ocr_payload(pdf, model: 'glm-ocr', pages: [0, 2]) }
        .to raise_error(ArgumentError, /continuous/)
      expect { protocol.render_ocr_payload(pdf, model: 'glm-ocr', pages: []) }
        .to raise_error(ArgumentError, /continuous/)
      expect { protocol.render_ocr_payload(pdf, model: 'glm-ocr', pages: [1, 1]) }
        .to raise_error(ArgumentError, /continuous/)
    end

    it 'numbers each page from the range it asked for' do
      protocol.render_ocr_payload(pdf, model: 'glm-ocr', pages: [3])
      body = {
        'model' => 'GLM-OCR', 'md_results' => '# Title',
        'layout_details' => [[
          { 'index' => 0, 'label' => 'text', 'content' => '# Title' },
          { 'index' => 1, 'label' => 'image' },
          { 'index' => 2, 'label' => 'table', 'content' => '<table></table>' }
        ]],
        'usage' => { 'total_tokens' => 9 }
      }

      ocr = protocol.parse_ocr_response(response(body), model: 'glm-ocr')

      expect(ocr.model).to eq('glm-ocr')
      expect(ocr.usage).to eq('total_tokens' => 9)
      expect(ocr.pages.first).to have_attributes(index: 3, markdown: "# Title\n\n<table></table>")
      expect(ocr.pages.first.tables.map { |table| table['content'] }).to eq(['<table></table>'])
      expect(ocr.pages.first.images.map { |image| image['label'] }).to eq(['image'])
    end

    it 'counts up from the first page of the range' do
      protocol.render_ocr_payload(pdf, model: 'glm-ocr', pages: [3, 4])
      body = { 'layout_details' => [[{ 'content' => 'one' }], [{ 'content' => 'two' }]] }

      expect(protocol.parse_ocr_response(response(body), model: 'glm-ocr').pages.map(&:index)).to eq([3, 4])
    end

    it 'renders cropped images as Markdown images' do
      body = { 'layout_details' => [[{ 'label' => 'image', 'content' => 'https://cdn.example.com/crop.png' }]] }

      expect(protocol.parse_ocr_response(response(body), model: 'glm-ocr').markdown)
        .to eq('![](https://cdn.example.com/crop.png)')
    end

    it 'numbers pages from a range set through provider options' do
      protocol.render_ocr_payload(pdf, model: 'glm-ocr', provider_options: { 'start_page_id' => 3, 'end_page_id' => 4 })
      body = { 'layout_details' => [[{ 'content' => 'one' }], [{ 'content' => 'two' }]] }

      expect(protocol.parse_ocr_response(response(body), model: 'glm-ocr').pages.map(&:index)).to eq([2, 3])
    end

    it 'falls back to the whole markdown when no layout comes back' do
      ocr = protocol.parse_ocr_response(response({ 'md_results' => '# Title' }), model: 'glm-ocr')

      expect(ocr.pages.map(&:markdown)).to eq(['# Title'])
    end

    it 'reads each page of a PDF', :live do
      ocr = RubyLLM.ocr(pdf, model: 'glm-ocr', provider: :zai, assume_model_exists: true)

      expect(ocr.pages.map(&:index)).to eq([0])
      expect(ocr.markdown).to match(/sample pdf/i)
      expect(ocr.usage['total_tokens']).to be_positive
    end
  end

  describe 'video generation' do
    let(:job) { instance_double(RubyLLM::VideoJob, id: 'task-1', model: 'cogvideox-3', raw: finished) }

    def image
      RubyLLM::Attachment.new(File.expand_path('../../fixtures/ruby.png', __dir__))
    end

    def finished
      { 'model' => 'CogVideoX-3', 'task_status' => 'SUCCESS',
        'video_result' => [{ 'url' => 'https://cdn.example.com/a.mp4' }] }
    end

    it 'sends reference images as a list and keeps provider options' do
      options = { quality: 'speed', duration: 5, size: '1280x720' }
      payload = protocol.render_video_payload('Move', model: 'cogvideox-3', with: [image, image],
                                                      provider_options: options)

      expect(payload).to include(model: 'cogvideox-3', prompt: 'Move', quality: 'speed')
      expect(payload[:image_url]).to all(start_with('data:image/png;base64,'))
      expect(protocol.video_request_settings(payload)).to eq(duration: 5, resolution: '1280x720')
    end

    it 'leaves the prompt out of an image-only request' do
      payload = protocol.render_video_payload(nil, model: 'cogvideox-3', with: [image])

      expect(payload).not_to have_key(:prompt)
    end

    it 'takes at most a first and a last frame' do
      expect { protocol.send(:validate_animate_inputs!, with: [image, image]) }.not_to raise_error
      expect { protocol.send(:validate_animate_inputs!, with: [image, image, image]) }
        .to raise_error(RubyLLM::Error, /first and a last frame/)
    end

    it 'leaves a remote frame to Z.ai' do
      remote = instance_double(RubyLLM::Attachment, url?: true)

      expect { protocol.send(:validate_animate_inputs!, with: [remote]) }.not_to raise_error
    end

    it 'needs a job id back' do
      expect { protocol.parse_video_job(response({}), model: 'cogvideox-3') }
        .to raise_error(RubyLLM::Error, /did not return a video job id/)
    end

    it 'refuses anything but images' do
      video = RubyLLM::Attachment.new(File.expand_path('../../fixtures/ruby.mp4', __dir__))

      expect { protocol.send(:validate_animate_inputs!, with: [video]) }
        .to raise_error(RubyLLM::UnsupportedAttachmentError)
    end

    it 'follows the job through its states' do
      expect(protocol.video_job_url(job)).to eq('async-result/task-1')
      expect(protocol.parse_video_job_status(response({ 'task_status' => 'PROCESSING' })))
        .to include(status: :pending)
      expect(protocol.parse_video_job_status(response(finished))).to include(status: :completed)
      expect(protocol.parse_video_job_status(response({ 'task_status' => 'FAIL' })))
        .to include(status: :failed, error: /could not generate/)
    end

    it 'points the finished video at its hosted URL' do
      video = protocol.download_video(job)

      expect(video).to have_attributes(url: 'https://cdn.example.com/a.mp4', mime_type: 'video/mp4', data: nil,
                                       model: 'CogVideoX-3')
    end

    it 'generates a video and points at the hosted file', :live do
      RubyLLM.config.video_generation_poll_interval = VCR.current_cassette&.recording? ? 10 : 0

      options = { quality: 'speed', size: '1280x720', fps: 30, duration: 5 }
      video = RubyLLM.animate('a calm ocean wave at sunset', model: 'cogvideox-3', provider: :zai,
                                                             assume_model_exists: true, provider_options: options)

      expect(video.mime_type).to eq('video/mp4')
      expect(video.url).to start_with('https://')
      expect(video.raw['task_status']).to eq('SUCCESS')
    end

    it 'says so when a finished job has no video' do
      allow(job).to receive(:raw).and_return({ 'task_status' => 'SUCCESS', 'video_result' => [] })

      expect { protocol.download_video(job) }.to raise_error(RubyLLM::Error, /no video/)
    end
  end
end
