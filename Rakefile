# frozen_string_literal: true

require 'bundler/setup'
require 'bundler/gem_tasks'
require 'rake/clean'

Dir.glob('lib/tasks/**/*.rake').each { |r| load r }

desc 'Run overcommit hooks and update models'
task :default do
  sh 'overcommit --run'
  Rake::Task['models'].invoke
end
