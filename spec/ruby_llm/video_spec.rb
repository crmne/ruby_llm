# frozen_string_literal: true

require 'spec_helper'
require 'tempfile'

def save_and_verify_video(video)
  temp_file = Tempfile.new(['video', '.mp4'])
  temp_path = temp_file.path
  temp_file.close

  begin
    saved_path = video.save(temp_path)
    expect(saved_path).to eq(temp_path)
    expect(File.size(temp_path)).to be > 10_000 # Any real clip should be larger than 10KB
  ensure
    File.delete(temp_path)
  end
end

RSpec.describe RubyLLM::Video, :live do
  before do
    RubyLLM.config.video_generation_poll_interval = VCR.current_cassette&.recording? ? 5 : 0
  end

  describe 'basic functionality' do
    each_model(VIDEO_GENERATION_MODELS) do |provider, model, model_info|
      it "#{provider}/#{model} can animate videos" do
        video = RubyLLM.animate('a calm ocean wave at sunset', model: model, provider: provider,
                                                               provider_options: model_info[:provider_options])

        expect(video.mime_type).to include('video')
        expect(video.url || video.data).to be_present

        save_and_verify_video video
      end
    end

    it 'validates model existence' do
      expect do
        RubyLLM.animate('a cat', model: 'invalid-model')
      end.to raise_error(RubyLLM::ModelNotFoundError)
    end

    it 'raises a clear error for providers without video generation' do
      expect do
        RubyLLM.animate_later('a cat', model: 'claude-haiku-4-5')
      end.to raise_error(RubyLLM::Error, /Anthropic doesn't support video generation/)
    end
  end

  describe RubyLLM::VideoJob do
    let(:protocol) { instance_double(RubyLLM::Protocols::Gemini) }

    it 'raises when the job outlives the timeout' do
      allow(protocol).to receive(:refresh_video_job).and_return({ status: :pending })
      job = described_class.new(id: 'operations/op-1', protocol: protocol)

      expect { job.wait!(timeout: 0, interval: 0) }.to raise_error(RubyLLM::Error, /timed out after 0 seconds/)
    end

    it 'surfaces the provider failure from wait! and #video' do
      allow(protocol).to receive(:refresh_video_job)
        .and_return({ status: :failed, error: 'flagged by moderation' })
      job = described_class.new(id: 'operations/op-1', protocol: protocol)

      expect { job.wait!(timeout: 10, interval: 0) }.to raise_error(RubyLLM::Error, /flagged by moderation/)
      expect { job.video }.to raise_error(RubyLLM::Error, /flagged by moderation/)
    end

    it 'returns no video while pending and stops refreshing once done' do
      allow(protocol).to receive(:refresh_video_job).and_return({ status: :completed, raw: {} })
      job = described_class.new(id: 'operations/op-1', protocol: protocol)

      expect(job.video).to be_nil
      expect(job.refresh!.status).to eq(:completed)

      job.refresh!
      expect(protocol).to have_received(:refresh_video_job).once
    end
  end
end
