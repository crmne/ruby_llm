# frozen_string_literal: true

require_relative 'support/public_api'

namespace :api do
  desc 'Write the public API list to api.txt'
  task :dump do
    content = PublicApi.render
    File.write(PublicApi::FILE, content)
    puts "Wrote #{content.lines.size - PublicApi::HEADER.size} public API lines to api.txt"
  end

  desc 'Fail when the public API differs from api.txt'
  task :check do
    require 'open3'
    require 'tempfile'

    current = PublicApi.render
    next if File.exist?(PublicApi::FILE) && File.read(PublicApi::FILE) == current

    diff = Tempfile.create(['api', '.txt']) do |file|
      file.write(current)
      file.flush
      Open3.capture2('diff', '-u', '--label', 'api.txt', '--label', 'lib/', PublicApi::FILE, file.path).first
    end
    abort <<~MESSAGE
      The public API no longer matches api.txt:

      #{diff}
      Run `bundle exec rake api:dump` and commit api.txt. Every new, changed, or
      removed line is a public API change: it needs the maintainer's explicit
      approval before it merges (AGENTS.md, Public API rules).
    MESSAGE
  end
end
