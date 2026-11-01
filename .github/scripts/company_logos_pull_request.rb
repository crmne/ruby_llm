#!/usr/bin/env ruby
# frozen_string_literal: true

# Prints the logo pull request's description. Inline screenshots go through
# GitHub's undocumented attachment upload, so a failure falls back to the
# run's artifact.

require 'json'
require 'net/http'
require 'uri'

def attachment(path)
  name = File.basename(path)
  query = URI.encode_www_form(name:, content_type: 'image/png', repository_id: ENV.fetch('GITHUB_REPOSITORY_ID'))
  uri = URI("https://uploads.github.com/user-attachments/assets?#{query}")
  request = Net::HTTP::Post.new(uri, 'Authorization' => "Bearer #{ENV.fetch('GH_TOKEN')}", 'Content-Type' => 'image/png',
                                     'Accept' => 'application/json')
  request.body = File.binread(path)
  response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |http| http.request(request) }
  JSON.parse(response.body)['url'] if response.is_a?(Net::HTTPSuccess)
rescue JSON::ParserError, SocketError, SystemCallError, Net::OpenTimeout, Net::ReadTimeout
  nil
end

directory = ARGV.fetch(0)
companies = File.readlines(File.join(directory, 'companies.txt'), chomp: true)
screenshots = %w[light dark].to_h { |theme| [theme, attachment(File.join(directory, "company-logos-#{theme}.png"))] }

puts 'These companies said yes to featuring their logo in the usage survey:', ''
companies.each { |company| puts "- `#{company.delete('`')}`" }
puts '', '## Homepage', ''
if screenshots.values.all?
  screenshots.each { |theme, url| puts "**#{theme.capitalize}**", '', "![#{theme} theme](#{url})", '' }
else
  puts "[Screenshots of both themes](#{ENV.fetch('SCREENSHOTS')}) (sign in to download).", ''
end
puts 'Check each logo in both themes. A dark logo may need a rule in `docs/assets/css/rubyllm-overrides.css`.'
puts 'To decline one for good, add its name to `docs/_data/company_logos_skipped.yml`.'
