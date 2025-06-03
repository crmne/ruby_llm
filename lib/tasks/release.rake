# frozen_string_literal: true

namespace :release do
  desc 'Verify cassettes are fresh enough for release'
  task :verify_cassettes do
    max_age_days = 1
    cassette_dir = 'spec/fixtures/vcr_cassettes'
    stale_cassettes = []

    Dir.glob("#{cassette_dir}/**/*.yml").each do |cassette|
      age_days = (Time.now - File.mtime(cassette)) / 86_400

      next unless age_days > max_age_days

      stale_cassettes << {
        file: File.basename(cassette),
        age: age_days.round(1)
      }
    end

    if stale_cassettes.any?
      puts "\n❌ Found stale cassettes (older than #{max_age_days} days):"
      stale_cassettes.each do |c|
        puts "   - #{c[:file]} (#{c[:age]} days old)"
      end
      puts "\nRun locally: bundle exec rspec"
      exit 1
    else
      puts "✅ All cassettes are fresh (< #{max_age_days} days old)"
    end
  end
end
