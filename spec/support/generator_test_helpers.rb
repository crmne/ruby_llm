# frozen_string_literal: true

require 'English'
module GeneratorTestHelpers
  def self.cleanup_test_app(app_path)
    FileUtils.rm_rf(app_path)
  end

  def self.create_test_app(name, template:, template_path:)
    template_file = File.join(template_path, template)

    Bundler.with_unbundled_env do
      Dir.chdir(Dir.tmpdir) do
        ENV['RUBYLLM_PATH'] = File.expand_path('../..', __dir__)
        output = `rails new #{name} --skip-bootsnap -m #{template_file} 2>&1`
        success = $CHILD_STATUS.success?
        unless success
          puts 'Rails new failed with output:'
          puts output
          raise "Failed to create test app #{name}"
        end
      end
    end
  end

  def within_test_app(app_path, &)
    api_key = ENV.fetch('OPENAI_API_KEY', 'test')
    Bundler.with_unbundled_env do
      ENV['OPENAI_API_KEY'] = api_key
      Dir.chdir(app_path, &)
    end
  end

  # Instance methods for use in examples
  def create_test_app(name, template:)
    GeneratorTestHelpers.create_test_app(name, template: template, template_path: template_path)
  end

  def cleanup_test_app(app_path)
    GeneratorTestHelpers.cleanup_test_app(app_path)
  end
end
