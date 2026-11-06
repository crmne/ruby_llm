# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::Interactions::Videos do
  let(:model) { 'gemini-omni-1.2-flash' }
  let(:provider) do
    config = RubyLLM::Configuration.new
    config.gemini_api_key = 'test'
    RubyLLM::Providers::Gemini.new(config)
  end
  let(:protocol) { RubyLLM::Protocols::Interactions.new(provider, RubyLLM::Model.default(model, 'gemini')) }
  let(:image_path) { File.expand_path('../../../fixtures/ruby.png', __dir__) }
  let(:video_path) { File.expand_path('../../../fixtures/ruby.mp4', __dir__) }

  def submitted
    { 'id' => 'v1_ChY1X1R0YXNIWE91SGpuc0VQOTlxM1dREhY1X1R0YXNIWE91SGpuc0VQOTlxM1dR', 'status' => 'in_progress',
      'created' => '2026-11-06T15:40:25Z', 'updated' => '2026-11-06T15:40:25Z', 'service_tier' => 'standard',
      'object' => 'interaction', 'model' => model }
  end

  def completed
    { 'id' => 'v1_ChY1X1R0YXNIWE91SGpuc0VQOTlxM1dREhY1X1R0YXNIWE91SGpuc0VQOTlxM1dR', 'status' => 'completed',
      'usage' => { 'total_tokens' => 17_923, 'total_input_tokens' => 12,
                   'input_tokens_by_modality' => [{ 'modality' => 'text', 'tokens' => 12 }],
                   'total_cached_tokens' => 0, 'total_output_tokens' => 17_376,
                   'output_tokens_by_modality' => [{ 'modality' => 'video', 'tokens' => 17_376 }],
                   'total_tool_use_tokens' => 0, 'total_thought_tokens' => 535, 'initial_input_tokens' => 18 },
      'created' => '2026-11-06T15:40:47Z', 'updated' => '2026-11-06T15:40:47Z', 'service_tier' => 'standard',
      'steps' => [
        { 'type' => 'user_input',
          'content' => [{ 'text' => 'A red ball rolling on a table, static shot.', 'type' => 'text' }] },
        { 'signature' => 'c2ln', 'type' => 'thought' },
        { 'content' => [{ 'data' => 'dmlkZW8=', 'mime_type' => 'video/mp4', 'type' => 'video' }],
          'type' => 'model_output' }
      ],
      'object' => 'interaction', 'response_format' => { 'duration' => '3s', 'type' => 'video' }, 'model' => model }
  end

  def failed
    { 'id' => 'v1_ChZVdmJ0YXZmV0NNZWIzYm9QbUktTktREhZVdmJ0YXZmV0NNZWIzYm9QbUktTktR', 'status' => 'failed',
      'created' => '2026-11-06T15:46:27Z', 'updated' => '2026-11-06T15:46:27Z',
      'steps' => [{ 'type' => 'user_input', 'content' => [{ 'text' => 'A speech', 'type' => 'text' }] }],
      'errors' => [{ 'message' => 'There was a problem processing your request. ' \
                                  'You will only be charged for tokens successfully generated.',
                     'code' => 'INVALID_ARGUMENT' }],
      'object' => 'interaction', 'response_format' => { 'duration' => '3s', 'type' => 'video' }, 'model' => model }
  end

  def response(body)
    instance_double(Faraday::Response, body:)
  end

  it 'routes every Gemini video model to Interactions' do
    expect(provider.protocol_for(RubyLLM::Model.default(model, 'gemini'), operation: :animate))
      .to eq(RubyLLM::Protocols::Interactions)
  end

  describe '#render_video_payload' do
    it 'submits a stored background interaction, which is what lets the job be polled' do
      payload = protocol.render_video_payload('A red ball', model:)

      expect(protocol.video_url).to eq('interactions')
      expect(payload).to eq(
        model:, input: [{ type: 'text', text: 'A red ball' }], background: true, store: true,
        response_format: { type: 'video' }
      )
    end

    it 'merges duration and resolution into the response format' do
      payload = protocol.render_video_payload(
        'A red ball', model:, provider_options: { response_format: { duration: '3s', resolution: '360p' } }
      )

      expect(payload[:response_format]).to eq(type: 'video', duration: '3s', resolution: '360p')
      expect(protocol.parse_video_request(payload)).to eq(duration: 3, resolution: '360p')
    end

    it 'sends reference images ahead of the prompt' do
      payload = protocol.render_video_payload('Make it move', model:, with: RubyLLM::Attachment.wrap(image_path))

      expect(payload[:input].map { |part| part[:type] }).to eq(%w[image text])
      expect(payload[:input].first)
        .to include(mime_type: 'image/png', data: Base64.strict_encode64(File.binread(image_path)))
    end
  end

  describe '#render_video_extension_payload' do
    it 'continues a generated video from its interaction, which works in every region' do
      video = RubyLLM::Video.new(data: 'video', mime_type: 'video/mp4', model:, raw: completed)

      payload = protocol.render_video_extension_payload('Continue the scene', model:, extend: video)

      expect(payload).to include(previous_interaction_id: completed['id'],
                                 input: [{ type: 'text', text: 'Continue the scene' }])
    end

    it 'sends any other source video ahead of the prompt' do
      payload = protocol.render_video_extension_payload('Continue the scene', model:, extend: video_path)

      expect(payload[:input].map { |part| part[:type] }).to eq(%w[video text])
      expect(payload).not_to have_key(:previous_interaction_id)
    end
  end

  describe '#parse_video_job' do
    it 'reads the interaction id and stays pending' do
      job = protocol.parse_video_job(response(submitted), model:, duration: 3, resolution: nil)

      expect(job.id).to eq(submitted['id'])
      expect(job).to be_pending
      expect(job.duration).to eq(3)
    end

    it 'raises without an interaction id' do
      expect { protocol.parse_video_job(response({}), model:) }
        .to raise_error(RubyLLM::Error, /did not return a video generation interaction/)
    end
  end

  describe '#video_job_url' do
    it 'polls the interaction' do
      job = RubyLLM::VideoJob.new(id: submitted['id'], protocol:)

      expect(protocol.video_job_url(job)).to eq("interactions/#{submitted['id']}")
    end

    ['https://attacker.example/steal', '//attacker.example/steal', '../files/abc', "v1_abc\nhttps://attacker.example"]
      .each do |id|
        it "refuses to poll #{id.inspect}, which would carry the API key elsewhere" do
          job = RubyLLM::VideoJob.new(id:, protocol:)

          expect { protocol.video_job_url(job) }.to raise_error(ArgumentError, /not a video interaction id/)
        end
      end
  end

  describe '#parse_video_job_status' do
    it 'stays pending while the interaction is in progress' do
      expect(protocol.parse_video_job_status(response(submitted))).to eq(status: :pending, raw: submitted)
    end

    it 'completes with the billed tokens' do
      state = protocol.parse_video_job_status(response(completed))

      expect(state).to include(status: :completed, raw: completed)
      expect(state[:tokens].to_h).to include(input_tokens: 12, output_tokens: 17_911, thinking_tokens: 535)
    end

    it 'fails with the errors the interaction recorded' do
      state = protocol.parse_video_job_status(response(failed))

      expect(state).to include(status: :failed, raw: failed)
      expect(state[:error]).to start_with('There was a problem processing your request.')
    end

    it 'fails when a completed interaction holds a video with no bytes' do
      body = completed.merge('steps' => [{ 'type' => 'model_output',
                                           'content' => [{ 'type' => 'video',
                                                           'uri' => 'https://attacker.example/v' }] }])

      expect(protocol.parse_video_job_status(response(body))).to include(status: :failed)
    end

    it 'fails when a completed interaction holds no video' do
      body = completed.merge('steps' => [{ 'type' => 'model_output',
                                           'content' => [{ 'type' => 'text', 'text' => 'No' }] }])

      expect(protocol.parse_video_job_status(response(body))).to include(status: :failed,
                                                                         error: 'Gemini returned no video')
    end
  end

  describe '#download_video' do
    it 'decodes the inline video' do
      job = RubyLLM::VideoJob.new(id: completed['id'], protocol:, model:, status: :completed, raw: completed)

      video = protocol.download_video(job)

      expect(video.to_blob).to eq('video')
      expect(video.mime_type).to eq('video/mp4')
      expect(video.model).to eq(model)
    end
  end

  it 'extends a freshly generated video through the public API', :live do
    context = RubyLLM.context do |config|
      config.video_generation_poll_interval = VCR.current_cassette&.recording? ? 5 : 0
    end
    format = { response_format: { duration: '3s', resolution: '360p' } }
    original = context.animate('A calm ocean wave at sunset', model:, provider: :gemini, assume_model_exists: true,
                                                              provider_options: format)
    job = context.animate_later('The wave gently reaches the sandy shore', model:, provider: :gemini,
                                                                           assume_model_exists: true,
                                                                           extend: original, provider_options: format)

    expect(job.wait(timeout: 240)).to be_succeeded
    expect(job.video.mime_type).to eq('video/mp4')
    expect(job.video.to_blob.bytesize).to be > 1000
    expect(job.video.tokens.output).to be_positive
  end

  it 'reports the billed tokens and prices them against the registry', :aggregate_failures do
    registered = RubyLLM.models.find('gemini-omni-flash-preview')
    protocol = RubyLLM::Protocols::Interactions.new(provider, registered)
    allow(protocol).to receive(:refresh_video_job)
      .and_return(protocol.parse_video_job_status(response(completed)))
    entries = []
    allow(RubyLLM::Accounting::Usage).to receive(:report) { |entry, **| entries << entry }

    job = RubyLLM::VideoJob.new(id: submitted['id'], protocol:, model: registered.id).refresh

    expect(entries.first.tokens.output).to eq(17_911)
    expect(job.cost.total).to be_within(0.001).of(0.313)
    expect(job.video.cost.total).to eq(job.cost.total)
  end
end
