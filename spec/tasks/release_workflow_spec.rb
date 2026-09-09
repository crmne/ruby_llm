# frozen_string_literal: true

require 'open3'
require 'tmpdir'
require 'yaml'

RSpec.describe 'Release workflow', type: :task do
  let(:workflow) { YAML.load_file(File.expand_path('../../.github/workflows/release.yml', __dir__)) }
  let(:validation) { workflow.fetch('jobs').fetch('validate').fetch('steps').find { |step| step['id'] == 'version' } }
  let(:directory) { Dir.mktmpdir('ruby-llm-release-') }
  let(:version) { '2.0.0.rc1' }
  let(:tag) { "v#{version}" }

  after { FileUtils.rm_rf(directory) }

  it 'publishes only after a GitHub release is published' do
    expect(workflow[true] || workflow['on']).to eq('release' => { 'types' => ['published'] })
    expect(workflow.fetch('jobs').fetch('publish').fetch('needs')).to include('validate', 'test')
    main = YAML.load_file(File.expand_path('../../.github/workflows/main.yml', __dir__))
    expect(main.fetch('jobs').values.filter_map { |job| job['uses'] }).not_to include('./.github/workflows/release.yml')
  end

  it 'accepts a prerelease tag matching the tested commit and gem version' do
    prepare_repository
    stdout, stderr, status = verify_release

    expect(status).to be_success, "#{stdout}\n#{stderr}"
    expect(File.read(File.join(directory, 'outputs')))
      .to include("version=#{version}", "commit=#{git('rev-parse', 'HEAD')}")
  end

  it 'rejects a tag that does not match the gem version' do
    prepare_repository
    _stdout, stderr, status = verify_release(tag: 'v2.0.0.rc2')

    expect(status).not_to be_success
    expect(stderr).to include('does not match gem version')
  end

  it 'ignores repository environment inherited from Git hooks' do
    previous_index = ENV.fetch('GIT_INDEX_FILE', nil)
    foreign_index = File.join(directory, 'foreign-index')
    File.write(foreign_index, 'not a Git index')
    ENV['GIT_INDEX_FILE'] = foreign_index
    prepare_repository
    stdout, stderr, status = verify_release

    expect(status).to be_success, "#{stdout}\n#{stderr}"
    expect(File.read(foreign_index)).to eq('not a Git index')
  ensure
    ENV['GIT_INDEX_FILE'] = previous_index
  end

  it 'rejects a tag moved after the release event' do
    prepare_repository
    git('commit', '--allow-empty', '-m', 'Move tag')
    git('tag', '--force', tag)
    git('checkout', '--detach', 'HEAD~1')
    _stdout, stderr, status = verify_release

    expect(status).not_to be_success
    expect(stderr).to include('tag moved')
  end

  it 'rejects a release commit that has not reached main' do
    prepare_repository
    git('update-ref', 'refs/remotes/origin/main', 'HEAD~1')
    _stdout, _stderr, status = verify_release

    expect(status).not_to be_success
    expect(File).not_to exist(File.join(directory, 'outputs'))
  end

  it 'requires the GitHub prerelease flag for a prerelease gem' do
    prepare_repository
    _stdout, stderr, status = verify_release(prerelease: false)

    expect(status).not_to be_success
    expect(stderr).to include('prerelease setting does not match')
  end

  context 'with a stable gem version' do
    let(:version) { '2.0.0' }

    it 'accepts a stable GitHub release' do
      prepare_repository
      stdout, stderr, status = verify_release(prerelease: false)

      expect(status).to be_success, "#{stdout}\n#{stderr}"
    end
  end

  def prepare_repository
    git('init', '--initial-branch=main')
    git('config', 'user.name', 'Release test')
    git('config', 'user.email', 'release@example.test')
    git('config', 'commit.gpgsign', 'false')
    git('config', 'core.hooksPath', File::NULL)
    git('commit', '--allow-empty', '-m', 'Initial commit')
    FileUtils.mkdir_p(File.join(directory, 'lib/ruby_llm'))
    File.write(File.join(directory, 'lib/ruby_llm/version.rb'), "module RubyLLM; VERSION = #{version.inspect}; end\n")
    git('add', 'lib/ruby_llm/version.rb')
    git('commit', '-m', 'Set version')
    git('tag', tag)
    git('update-ref', 'refs/remotes/origin/main', 'HEAD')
  end

  def verify_release(tag: self.tag, prerelease: true)
    environment = git_environment.merge(
      'RELEASE_TAG' => tag,
      'RELEASE_PRERELEASE' => prerelease.to_s,
      'GITHUB_OUTPUT' => File.join(directory, 'outputs')
    )
    Bundler.with_unbundled_env do
      Open3.capture3(environment, 'bash', '-c', validation.fetch('run'), chdir: directory)
    end
  end

  def git(*arguments)
    stdout, stderr, status = Open3.capture3(git_environment, 'git', *arguments, chdir: directory)
    raise stderr unless status.success?

    stdout.strip
  end

  def git_environment
    ENV.keys.grep(/\AGIT_/).to_h { |name| [name, nil] }
  end
end
