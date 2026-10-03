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
        RubyLLM.animate_later('a cat', model: model_for(:anthropic))
      end.to raise_error(RubyLLM::Error, /Anthropic doesn't support video generation/)
    end
  end

  describe RubyLLM::VideoJob do
    let(:instrumenter) { CaptureInstrumenter.new }
    let(:config) { RubyLLM.context { |config| config.instrumenter = instrumenter }.config }
    let(:protocol) do
      instance_double(RubyLLM::Protocols::Gemini, config:,
                                                  provider: instance_double(RubyLLM::Providers::Gemini, slug: 'gemini'))
    end

    before { allow(RubyLLM::Accounting::Usage).to receive(:ledger).and_return(nil) }

    it 'raises when the job outlives the timeout' do
      allow(protocol).to receive(:refresh_video_job).and_return({ status: :pending })
      job = described_class.new(id: 'operations/op-1', protocol: protocol)

      expect { job.wait(timeout: 0, interval: 0) }.to raise_error(RubyLLM::Error, /timed out after 0 seconds/)
    end

    it 'does not sleep past the timeout deadline' do
      allow(protocol).to receive(:refresh_video_job).and_return({ status: :pending })
      job = described_class.new(id: 'operations/op-1', protocol: protocol)
      allow(job).to receive(:monotonic_time).and_return(100.0, 100.25, 101.1)
      allow(job).to receive(:sleep)

      expect { job.wait(timeout: 1, interval: 60) }.to raise_error(RubyLLM::Error, /timed out after 1 seconds/)

      expect(job).to have_received(:sleep).with(0.75)
    end

    it 'surfaces the provider failure from wait and #video' do
      allow(protocol).to receive(:refresh_video_job)
        .and_return({ status: :failed, error: 'flagged by moderation' })
      job = described_class.new(id: 'operations/op-1', protocol: protocol)

      expect { job.wait(timeout: 10, interval: 0) }.to raise_error(RubyLLM::Error, /flagged by moderation/)
      expect { job.video }.to raise_error(RubyLLM::Error, /flagged by moderation/)
    end

    it 'returns no video while pending and stops refreshing once done' do
      allow(protocol).to receive(:refresh_video_job).and_return({ status: :completed, raw: {} })
      job = described_class.new(id: 'operations/op-1', protocol: protocol)

      expect(job.video).to be_nil
      expect(job.refresh.status).to eq(:completed)

      job.refresh
      expect(protocol).to have_received(:refresh_video_job).once
    end

    it 'records its usage once when it finishes, attributed to the owner at submission' do
      allow(protocol).to receive(:refresh_video_job).and_return({ status: :pending }, { status: :completed })
      job = RubyLLM.with_usage_owner('account-1') do
        described_class.new(id: 'operations/op-1', protocol:, model: 'veo-3.1-fast-generate-preview')
      end

      job.refresh
      expect(instrumenter.events.map(&:first)).not_to include('usage.ruby_llm')
      job.refresh
      job.refresh

      usage = instrumenter.events.filter_map { |name, payload| payload if name == 'usage.ruby_llm' }
      expect(usage.size).to eq(1)
      expect(usage.first).to include(operation: :video, provider: 'gemini', model: 'veo-3.1-fast-generate-preview',
                                     status: :succeeded, owner: 'account-1')
      expect(usage.first[:cost].total).to be_nil
    end
  end
end
