# frozen_string_literal: true

require 'bundler/setup'
require 'bundler/gem_tasks'
require 'rake/clean'

Dir.glob(File.join(__dir__, 'tasks/**/*.rake')).each { |task_file| load task_file }
load File.join(__dir__, 'lib/tasks/ruby_llm.rake')

def run_test_queue_rspec
  workers = ENV.fetch('RSPEC_WORKERS', nil)
  env = {}
  env['TEST_QUEUE_WORKERS'] = workers if workers && !workers.empty? && ENV.fetch('TEST_QUEUE_WORKERS', '').empty?

  system(env, 'bundle', 'exec', 'bin/rspec-queue')
end

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
