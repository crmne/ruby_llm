# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::MiniMax::Videos do
  let(:config) do
    RubyLLM::Configuration.new.tap { |c| c.minimax_api_key = 'test' }
  end
  let(:provider) { RubyLLM::Providers::MiniMax.new(config) }
  let(:v2_protocol) { RubyLLM::Protocols::MiniMax.new(provider, 'MiniMax-H3') }
  let(:v1_protocol) { RubyLLM::Protocols::MiniMax.new(provider, 'MiniMax-Hailuo-2.3') }

  describe '#video_url' do
    it 'submits the v2 catalog to the v2 endpoint' do
      expect(v2_protocol.video_url).to eq('https://api.minimax.io/v2/video_generation')
    end

    it 'submits every other model to the v1 endpoint' do
      expect(v1_protocol.video_url).to eq('https://api.minimax.io/v1/video_generation')
    end

    it 'routes the whole catalog to one of the two endpoints' do
      urls = described_class::MODELS.map do |model|
        RubyLLM::Protocols::MiniMax.new(provider, model).video_url
      end

      expect(urls.uniq).to contain_exactly(
        'https://api.minimax.io/v2/video_generation',
        'https://api.minimax.io/v1/video_generation'
      )
    end

    it 'follows the configured regional host' do
      config.minimax_api_base = 'https://api.minimaxi.com/v1'

      expect(v2_protocol.video_url).to eq('https://api.minimaxi.com/v2/video_generation')
      expect(v1_protocol.video_url).to eq('https://api.minimaxi.com/v1/video_generation')
    end
  end

  describe '#render_video_payload' do
    it 'sends the prompt as a text content item with the required fields' do
      payload = v2_protocol.render_video_payload('a paper boat sailing down a rainy gutter', model: 'MiniMax-H3')

      expect(payload).to eq(
        model: 'MiniMax-H3',
        content: [{ type: 'text', text: 'a paper boat sailing down a rainy gutter' }],
        resolution: '2K',
        duration: 4
      )
    end

    it 'lets provider options override the request vocabulary' do
      payload = v2_protocol.render_video_payload(
        'a hummingbird hovering in slow motion',
        model: 'MiniMax-H3',
        provider_options: { duration: 10, ratio: '16:9', aigc_watermark: true }
      )

      expect(payload).to include(duration: 10, ratio: '16:9', aigc_watermark: true, resolution: '2K')
    end

    it 'rejects prompts longer than the documented limit' do
      expect do
        v2_protocol.render_video_payload('a' * 7001, model: 'MiniMax-H3')
      end.to raise_error(RubyLLM::Error, /7000 characters/)
    end

    it 'sends a flat prompt on the v1 endpoint' do
      payload = v1_protocol.render_video_payload(
        'a rocket launch seen from orbit',
        model: 'MiniMax-Hailuo-2.3',
        provider_options: { prompt_optimizer: false, duration: 6, resolution: '1080P' }
      )

      expect(payload).to eq(
        model: 'MiniMax-Hailuo-2.3',
        prompt: 'a rocket launch seen from orbit',
        prompt_optimizer: false,
        duration: 6,
        resolution: '1080P'
      )
    end
  end

  describe '#parse_video_job' do
    it 'reads the task id and points polling at the v2 query endpoint' do
      response = instance_double(Faraday::Response, body: { 'task_id' => '288045468478926' })

      job = v2_protocol.parse_video_job(response, model: 'MiniMax-H3')

      expect(job.id).to eq('288045468478926')
      expect(job).to be_pending
      expect(v2_protocol.video_job_url(job)).to eq(
        'https://api.minimax.io/v2/query/video_generation/288045468478926'
      )
    end

    it 'polls the v1 query endpoint with the task id as a parameter' do
      response = instance_double(Faraday::Response,
                                 body: { 'task_id' => '288045468478926', 'base_resp' => { 'status_code' => 0 } })

      job = v1_protocol.parse_video_job(response, model: 'MiniMax-Hailuo-2.3')

      expect(v1_protocol.video_job_url(job)).to eq(
        'https://api.minimax.io/v1/query/video_generation?task_id=288045468478926'
      )
    end

    it 'raises when the submission carries a failed base response' do
      response = instance_double(Faraday::Response,
                                 body: { 'base_resp' => { 'status_code' => 1004, 'status_msg' => 'invalid api key' } })

      expect { v1_protocol.parse_video_job(response, model: 'MiniMax-Hailuo-2.3') }
        .to raise_error(RubyLLM::Error, /1004: invalid api key/)
    end

    it 'raises when no task id comes back' do
      response = instance_double(Faraday::Response, body: {})

      expect { v2_protocol.parse_video_job(response, model: 'MiniMax-H3') }
        .to raise_error(RubyLLM::Error, /did not return a video generation task id/)
    end
  end

  describe '#parse_video_job_status' do
    def v2_job
      RubyLLM::VideoJob.new(id: '288045468478926', protocol: v2_protocol, model: 'MiniMax-H3')
    end

    def v1_job
      RubyLLM::VideoJob.new(id: '288045468478926', protocol: v1_protocol, model: 'MiniMax-Hailuo-2.3')
    end

    it 'stays pending while a v2 task is queued or running' do
      %w[queued running].each do |status|
        body = { 'task' => { 'status' => status } }
        response = instance_double(Faraday::Response, body: body)

        expect(v2_protocol.parse_video_job_status(response, job: v2_job)).to eq(status: :pending, raw: body)
      end
    end

    it 'completes a v2 task on succeeded' do
      body = { 'task' => { 'status' => 'succeeded', 'content' => { 'url' => 'https://cdn.example.com/clip.mp4' } } }
      response = instance_double(Faraday::Response, body: body)

      expect(v2_protocol.parse_video_job_status(response, job: v2_job)).to eq(status: :completed, raw: body)
    end

    it 'fails a v2 task with the reported error message' do
      body = { 'task' => { 'status' => 'failed',
                           'error' => { 'code' => 'content_moderation', 'message' => 'prompt was blocked' } } }
      response = instance_double(Faraday::Response, body: body)

      expect(v2_protocol.parse_video_job_status(response, job: v2_job)).to include(
        status: :failed, error: 'prompt was blocked'
      )
    end

    it 'fails a cancelled v2 task' do
      body = { 'task' => { 'status' => 'cancelled' } }
      response = instance_double(Faraday::Response, body: body)

      expect(v2_protocol.parse_video_job_status(response, job: v2_job)).to include(status: :failed)
    end

    it 'stays pending through the v1 preparation states' do
      %w[Preparing Queueing Processing].each do |status|
        body = { 'status' => status, 'base_resp' => { 'status_code' => 0 } }
        response = instance_double(Faraday::Response, body: body)

        expect(v1_protocol.parse_video_job_status(response, job: v1_job)).to eq(status: :pending, raw: body)
      end
    end

    it 'completes a v1 task on Success' do
      body = { 'status' => 'Success', 'file_id' => '205258526306433', 'base_resp' => { 'status_code' => 0 } }
      response = instance_double(Faraday::Response, body: body)

      expect(v1_protocol.parse_video_job_status(response, job: v1_job)).to eq(status: :completed, raw: body)
    end

    it 'fails a v1 task on Fail' do
      body = { 'status' => 'Fail', 'base_resp' => { 'status_code' => 0 } }
      response = instance_double(Faraday::Response, body: body)

      expect(v1_protocol.parse_video_job_status(response, job: v1_job)).to include(status: :failed, error: 'Fail')
    end

    it 'fails a v1 task when the base response reports an error' do
      body = { 'base_resp' => { 'status_code' => 2013, 'status_msg' => 'invalid params' } }
      response = instance_double(Faraday::Response, body: body)

      expect(v1_protocol.parse_video_job_status(response, job: v1_job)).to include(
        status: :failed, error: 'MiniMax video request failed with status 2013: invalid params'
      )
    end
  end

  describe '#download_video' do
    it 'returns the hosted url a finished v2 task reports' do
      raw = { 'task' => { 'id' => '288045468478926', 'model' => 'MiniMax-H3', 'status' => 'succeeded',
                          'duration' => 6, 'content' => { 'url' => 'https://cdn.example.com/clip.mp4' } } }
      job = RubyLLM::VideoJob.new(id: '288045468478926', protocol: v2_protocol, model: 'MiniMax-H3',
                                  status: :completed, raw: raw)

      video = v2_protocol.download_video(job)

      expect(video.url).to eq('https://cdn.example.com/clip.mp4')
      expect(video.mime_type).to eq('video/mp4')
      expect(video.model).to eq('MiniMax-H3')
      expect(video.duration).to eq(6)
    end

    it 'raises when a finished v2 task carries no output url' do
      job = RubyLLM::VideoJob.new(id: '288045468478926', protocol: v2_protocol, model: 'MiniMax-H3',
                                  status: :completed, raw: { 'task' => { 'status' => 'succeeded' } })

      expect { v2_protocol.download_video(job) }.to raise_error(RubyLLM::Error, /no output url/)
    end

    it 'retrieves the file a finished v1 task reports' do
      raw = { 'status' => 'Success', 'file_id' => '205258526306433', 'base_resp' => { 'status_code' => 0 } }
      job = RubyLLM::VideoJob.new(id: '288045468478926', protocol: v1_protocol, model: 'MiniMax-Hailuo-2.3',
                                  status: :completed, raw: raw)
      response = instance_double(
        Faraday::Response,
        body: { 'file' => { 'file_id' => '205258526306433', 'filename' => 'output.mp4',
                            'download_url' => 'https://files.example.com/output.mp4' },
                'base_resp' => { 'status_code' => 0 } }
      )
      allow(provider.connection).to receive(:get)
        .with('https://api.minimax.io/v1/files/retrieve?file_id=205258526306433')
        .and_return(response)

      video = v1_protocol.download_video(job)

      expect(video.url).to eq('https://files.example.com/output.mp4')
      expect(video.model).to eq('MiniMax-Hailuo-2.3')
    end

    it 'raises when a finished v1 task carries no file id' do
      job = RubyLLM::VideoJob.new(id: '288045468478926', protocol: v1_protocol, model: 'MiniMax-Hailuo-2.3',
                                  status: :completed, raw: { 'status' => 'Success' })

      expect { v1_protocol.download_video(job) }.to raise_error(RubyLLM::Error, /no output file id/)
    end
  end
end
