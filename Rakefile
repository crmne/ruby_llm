# frozen_string_literal: true

require 'bundler/setup'
require 'bundler/gem_tasks'
require 'rake/clean'

Dir.glob('lib/tasks/**/*.rake').each { |r| load r }

desc 'Run test suite with rspec-queue'
task :test do
  run_test_queue_rspec || abort('Tests failed')
end

desc 'Generate API documentation'
task :rdoc do
  sh 'docs/bin/build-api.sh', 'doc'
end
CLOBBER.include 'doc'

desc 'Run overcommit hooks and update models'
task :default do
  sh 'overcommit --run'
  Rake::Task['models'].invoke
end
