# frozen_string_literal: true

require 'time'
require 'yaml'

# Shared helpers for release-related Rake tasks.
module ReleaseTasks
  module_function

  def cassette_recorded_at_times(cassette)
    data = YAML.safe_load_file(cassette, aliases: true)

    Array(data['http_interactions']).filter_map do |interaction|
      Time.parse(interaction['recorded_at'])
    rescue ArgumentError, TypeError
      nil
    end
  rescue Psych::Exception => e
    abort "Could not parse VCR cassette #{cassette}: #{e.message}"
  end

  def cassette_recorded_at(cassette)
    recorded_at_times = cassette_recorded_at_times(cassette)

    abort "No recorded_at timestamps found in VCR cassette #{cassette}" if recorded_at_times.empty?

    recorded_at_times.min
  end

  def find_stale_cassettes(cassette_dir, max_age_days)
    Dir.glob("#{cassette_dir}/**/*.yml").filter_map do |cassette|
      recorded_at = cassette_recorded_at(cassette)
      age_days = (Time.now - recorded_at) / 86_400

      next unless age_days > max_age_days

      {
        path: cassette,
        file: File.basename(cassette),
        age: age_days.round(1)
      }
    end
  end
end

namespace :release do # rubocop:disable Metrics/BlockLength
  desc 'Prepare for release'
  task :prepare do
    Rake::Task['release:refresh_stale_cassettes'].invoke
    sh 'overcommit --run'
    Rake::Task['models'].invoke
  end

  desc 'Remove stale cassettes and re-record them'
  task :refresh_stale_cassettes do
    max_age_days = 1
    cassette_dir = 'spec/fixtures/vcr_cassettes'

    stale_cassettes = ReleaseTasks.find_stale_cassettes(cassette_dir, max_age_days)

    stale_cassettes.each do |cassette|
      puts "Removing stale cassette: #{cassette[:file]} (#{cassette[:age]} days old)"
      File.delete(cassette[:path])
    end

    if stale_cassettes.any?
      puts "\n🗑️  Removed #{stale_cassettes.size} stale cassettes"
      puts '🔄 Re-recording cassettes...'
      run_test_queue_rspec || exit(1)
      puts '✅ Cassettes refreshed!'
    else
      puts '✅ No stale cassettes found'
    end
  end

  desc 'Verify cassettes are fresh enough for release'
  task :verify_cassettes do
    max_age_days = 1
    cassette_dir = 'spec/fixtures/vcr_cassettes'
    stale_cassettes = ReleaseTasks.find_stale_cassettes(cassette_dir, max_age_days)

    if stale_cassettes.any?
      puts "\n❌ Found stale cassettes (older than #{max_age_days} days):"
      stale_cassettes.each do |c|
        puts "   - #{c[:file]} (#{c[:age]} days old)"
      end

      puts "\nRun locally: bundle exec rake release:refresh_stale_cassettes"
      exit 1
    else
      puts "✅ All cassettes are fresh (< #{max_age_days} days old)"
    end
  end
end
