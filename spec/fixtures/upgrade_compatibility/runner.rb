# frozen_string_literal: true

ENV.fetch('RUBY_LLM_COMPATIBILITY_GEMS').split(',').each do |dependency|
  name, version = dependency.split(':')
  gem name, version
end
require 'json'

version, repository, directory, stage, encoded = ARGV
arguments = JSON.parse(encoded || '{}')
if version == 'legacy'
  begin
    gem 'ruby_llm', '= 1.16.0'
  rescue Gem::LoadError => e
    abort "#{e.message}\nInstall ruby_llm 1.16.0 with gem install ruby_llm -v 1.16.0 --no-document, " \
          'or set RUBY_LLM_LEGACY_GEM_HOME to its installation directory.'
  end
end
$LOAD_PATH.unshift(File.join(repository, 'lib')) if version == 'current'
require 'ruby_llm'
require 'active_record'
require 'webmock'

require_relative 'application'

application = UpgradeCompatibilityApplication.new(version:, directory:)
result = application.public_send(stage, arguments)
$stdout.write("#{JSON.generate(result)}\n")
