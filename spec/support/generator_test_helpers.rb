# frozen_string_literal: true

require 'English'
require 'open3'
require 'tmpdir'
module GeneratorTestHelpers
  def self.cleanup_test_app(app_path)
    FileUtils.rm_rf(app_path)
  end

  def self.create_test_app(name, template:, template_path:)
    template_file = File.join(template_path, template)
    ruby_llm_path = File.expand_path('../..', __dir__)
    root_bundle_gemfile = ENV['BUNDLE_GEMFILE'] || Bundler.default_gemfile.to_s

    root_env = {
      'RUBYLLM_PATH' => ruby_llm_path,
      'BUNDLE_GEMFILE' => root_bundle_gemfile
    }
    root_env['BUNDLE_PATH'] = ENV['BUNDLE_PATH'] if ENV.key?('BUNDLE_PATH')
    root_env['BUNDLE_DISABLE_SHARED_GEMS'] = ENV['BUNDLE_DISABLE_SHARED_GEMS'] if ENV.key?('BUNDLE_DISABLE_SHARED_GEMS')

    app_path = File.join(Dir.tmpdir, name)

    create_command = [
      'bundle', 'exec', 'rails', 'new', name,
      '--skip-bootsnap', '--skip-bundle', '--skip-kamal', '--skip-thruster',
      '--skip-asset-pipeline', '--skip-javascript', '--skip-hotwire'
    ]
    output, status = run_command(root_env, create_command, chdir: Dir.tmpdir)
    raise_command_error(name, create_command, status, output) unless status.success?

    app_env = root_env
    template_command = ['bundle', 'exec', 'rails', 'app:template', "LOCATION=#{template_file}"]
    output, status = run_command(app_env, template_command, chdir: app_path)
    raise_command_error(name, template_command, status, output) unless status.success?
  end

  def self.run_command(env, command, chdir:)
    stdout, stderr, process_status = Open3.capture3(env, *command, chdir:)
    ["#{stdout}#{stderr}", process_status]
  end

  def self.raise_command_error(name, command, status, output)
    raise <<~ERROR
      Failed to create test app #{name}
      Command: #{command.join(' ')}
      Exit status: #{status.exitstatus}
      Output:
      #{output}
    ERROR
  end

  def within_test_app(app_path, &)
    api_key = ENV.fetch('OPENAI_API_KEY', 'test')
    bundle_gemfile = ENV['BUNDLE_GEMFILE'] || Bundler.default_gemfile.to_s
    previous_bundle_gemfile = ENV.fetch('BUNDLE_GEMFILE', nil)
    previous_bundle_ignore_config = ENV.fetch('BUNDLE_IGNORE_CONFIG', nil)
    previous_openai_api_key = ENV.fetch('OPENAI_API_KEY', nil)

    ENV['BUNDLE_GEMFILE'] = bundle_gemfile
    ENV['BUNDLE_IGNORE_CONFIG'] = '1'
    ENV['OPENAI_API_KEY'] = api_key
    Dir.chdir(app_path, &)
  ensure
    ENV['BUNDLE_GEMFILE'] = previous_bundle_gemfile
    ENV['BUNDLE_IGNORE_CONFIG'] = previous_bundle_ignore_config
    ENV['OPENAI_API_KEY'] = previous_openai_api_key
  end

  def run_rails_runner(script)
    env = {
      'BUNDLE_GEMFILE' => ENV['BUNDLE_GEMFILE'] || Bundler.default_gemfile.to_s,
      'BUNDLE_IGNORE_CONFIG' => '1',
      'OPENAI_API_KEY' => ENV.fetch('OPENAI_API_KEY', 'test')
    }
    stdout, stderr, status = Open3.capture3(env, 'bundle', 'exec', 'rails', 'runner', script)
    [status.success?, "#{stdout}#{stderr}"]
  end

  # Instance methods for use in examples
  def create_test_app(name, template:)
    GeneratorTestHelpers.create_test_app(name, template: template, template_path: template_path)
  end

  def cleanup_test_app(app_path)
    GeneratorTestHelpers.cleanup_test_app(app_path)
  end
end
