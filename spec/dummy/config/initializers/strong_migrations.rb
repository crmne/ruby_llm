# frozen_string_literal: true

if RUBY_ENGINE == 'ruby' && Gem::Version.new(RUBY_VERSION) >= Gem::Version.new('3.2')
  require 'strong_migrations'
  StrongMigrations.skip_database(:primary)
end
