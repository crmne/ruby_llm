# frozen_string_literal: true

require 'rake'
require 'tmpdir'

load File.expand_path('../../../lib/tasks/release.rake', __dir__)

RSpec.describe ReleaseTasks do
  let(:cassette_dir) { File.join(tmpdir, 'vcr_cassettes') }
  let(:tmpdir) { Dir.mktmpdir }

  after do
    FileUtils.rm_rf(tmpdir)
  end

  def write_cassette(name, recorded_at_times)
    FileUtils.mkdir_p(cassette_dir)
    path = File.join(cassette_dir, name)
    interactions = recorded_at_times.map do |recorded_at|
      {
        'request' => {
          'method' => 'get',
          'uri' => 'https://example.test'
        },
        'response' => {
          'status' => {
            'code' => 200,
            'message' => 'OK'
          },
          'headers' => {},
          'body' => {
            'string' => 'ok'
          }
        },
        'recorded_at' => recorded_at.utc.httpdate
      }
    end

    File.write(path, YAML.dump({ 'http_interactions' => interactions, 'recorded_with' => 'VCR 6.3.1' }))
    path
  end

  it 'finds stale cassettes by recorded_at instead of file mtime' do
    stale_by_recording = write_cassette('stale.yml', [Time.now - (2 * 86_400)])
    fresh_by_recording = write_cassette('fresh.yml', [Time.now - 3_600])

    FileUtils.touch(stale_by_recording, mtime: Time.now)
    FileUtils.touch(fresh_by_recording, mtime: Time.now - (2 * 86_400))

    stale_paths = described_class.find_stale_cassettes(cassette_dir, 1).map { |cassette| cassette[:path] }

    expect(stale_paths).to contain_exactly(stale_by_recording)
  end

  it 'uses the oldest recorded_at entry in multi-interaction cassettes' do
    cassette = write_cassette('mixed.yml', [Time.now - (2 * 86_400), Time.now - 3_600])

    stale_paths = described_class.find_stale_cassettes(cassette_dir, 1).map { |stale| stale[:path] }

    expect(stale_paths).to contain_exactly(cassette)
  end
end
