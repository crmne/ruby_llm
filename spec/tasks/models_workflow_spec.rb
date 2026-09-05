# frozen_string_literal: true

require 'spec_helper'
require 'open3'
require 'tmpdir'
require 'yaml'

RSpec.describe 'Published model registry workflow', type: :task do
  let(:tmpdir) { Dir.mktmpdir }
  let(:models) { RubyLLM.models.by_provider(:openai).first(6) }
  let(:script) do
    workflow = YAML.load_file(File.expand_path('../../.github/workflows/docs.yml', __dir__))
    workflow.fetch('jobs').fetch('build').fetch('steps').find { |step| step['id'] == 'registry' }.fetch('run')
  end

  before do
    FileUtils.mkdir_p(File.join(tmpdir, 'bin'))
    FileUtils.mkdir_p(File.join(tmpdir, 'lib/ruby_llm'))
    RubyLLM::Models.new(models).save_to_json(File.join(tmpdir, 'published.json'))
    RubyLLM::Models.new(models).save_to_json(File.join(tmpdir, 'refreshed.json'))
    RubyLLM::Models.new(models).save_to_json(File.join(tmpdir, 'lib/ruby_llm/models.json'))

    write_executable('curl', <<~RUBY)
      require 'fileutils'
      FileUtils.cp(ENV.fetch('PUBLISHED_REGISTRY'), ARGV.last)
    RUBY
    write_executable('bundle', <<~RUBY)
      require 'fileutils'
      if ARGV == ['exec', 'rake', 'models:update']
        exit ENV.fetch('REFRESH_EXIT', '0').to_i unless ENV.fetch('REFRESH_EXIT', '0') == '0'
        FileUtils.cp(ENV.fetch('REFRESHED_REGISTRY'), ENV.fetch('MODEL_REGISTRY_FILE'))
      else
        exec ENV.fetch('REAL_BUNDLE'), *ARGV
      end
    RUBY
  end

  after do
    FileUtils.rm_rf(tmpdir)
  end

  def write_executable(name, code)
    path = File.join(tmpdir, 'bin', name)
    File.write(path, "#!#{RbConfig.ruby}\n#{code}")
    File.chmod(0o755, path)
  end

  def run_workflow(event: 'schedule', refresh: true, **overrides)
    env = {
      'PATH' => "#{File.join(tmpdir, 'bin')}:#{ENV.fetch('PATH')}",
      'RUBYLIB' => File.expand_path('../../lib', __dir__),
      'RUNNER_TEMP' => tmpdir,
      'GITHUB_OUTPUT' => File.join(tmpdir, 'outputs'),
      'REFRESH_MODEL_REGISTRY' => refresh.to_s,
      'PUBLISHED_REGISTRY' => File.join(tmpdir, 'published.json'),
      'REFRESHED_REGISTRY' => File.join(tmpdir, 'refreshed.json'),
      'REAL_BUNDLE' => Gem.bin_path('bundler', 'bundle'),
      'BUNDLE_GEMFILE' => File.expand_path('../../Gemfile', __dir__)
    }.merge(overrides)
    Open3.capture3(env, 'bash', '-e', '-c', script.gsub('${{ github.event_name }}', event), chdir: tmpdir)
  end

  def outputs
    File.read(File.join(tmpdir, 'outputs'))
  end

  it 'skips scheduled deployment when the refreshed catalog is unchanged' do
    stdout, stderr, status = run_workflow

    expect(status).to be_success, "#{stdout}\n#{stderr}"
    expect(outputs).to include('deploy=false')
  end

  it 'deploys a changed catalog on schedule' do
    RubyLLM::Models.new(models.drop(1)).save_to_json(File.join(tmpdir, 'refreshed.json'))
    stdout, stderr, status = run_workflow

    expect(status).to be_success, "#{stdout}\n#{stderr}"
    expect(outputs).to include('deploy=true')
  end

  it 'deploys manual builds even when their requested refresh finds no catalog changes' do
    stdout, stderr, status = run_workflow(event: 'workflow_dispatch')

    expect(status).to be_success, "#{stdout}\n#{stderr}"
    expect(outputs).to include('deploy=true')
  end

  it 'falls back to the bundled registry when the published registry is empty' do
    File.write(File.join(tmpdir, 'published.json'), '[]')
    stdout, stderr, status = run_workflow(event: 'push', refresh: false)

    expect(status).to be_success, "#{stdout}\n#{stderr}"
    expect(outputs).to include('deploy=true')
    expect(RubyLLM::ModelRegistry.read(File.join(tmpdir, 'ruby-llm-models.json')).map(&:id)).to eq(models.map(&:id))
  end

  it 'does not deploy when the registry task rejects a refresh' do
    _stdout, _stderr, status = run_workflow('REFRESH_EXIT' => '1')

    expect(status).not_to be_success
    expect(File).not_to exist(File.join(tmpdir, 'outputs'))
  end
end
