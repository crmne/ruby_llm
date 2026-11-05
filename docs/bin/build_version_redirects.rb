#!/usr/bin/env ruby
# frozen_string_literal: true

require 'cgi'
require 'fileutils'
require 'json'

site = File.expand_path(ARGV.fetch(0))
base = ARGV.fetch(1, '')

def redirect_page(path, target)
  FileUtils.mkdir_p(File.dirname(path))
  escaped = CGI.escapeHTML(target)
  File.write(path, <<~HTML)
    <!doctype html>
    <html lang="en">
    <head>
      <meta charset="utf-8">
      <title>RubyLLM documentation has moved</title>
      <link rel="canonical" href="https://rubyllm.com#{escaped}">
      <meta name="robots" content="noindex,follow">
      <script>window.location.replace(#{JSON.generate(target)} + window.location.search + window.location.hash);</script>
      <meta http-equiv="refresh" content="0;url=#{escaped}">
    </head>
    <body><p>This page has moved to <a href="#{escaped}">#{escaped}</a>.</p></body>
    </html>
  HTML
end

Dir.glob('**/*.html', base: File.join(site, 'v1')).each do |relative|
  next if File.exist?(File.join(site, relative)) || relative == '404.html'

  route = relative.delete_suffix('index.html')
  redirect_page(File.join(site, relative), "#{base}/v1/#{route}")
end

# The theme keeps search engines off the Markdown twins of each page, which
# would index as duplicates. AI agents and their fetchers are the readers the
# twins exist for, so they get a group of their own that allows everything.
ai_agents = %w[
  GPTBot OAI-SearchBot ChatGPT-User ClaudeBot Claude-User Claude-SearchBot anthropic-ai
  PerplexityBot Perplexity-User Google-Extended Applebot-Extended Amazonbot
  meta-externalagent meta-externalfetcher MistralAI-User DuckAssistBot cohere-ai CCBot
]

robots = File.join(site, 'robots.txt')
File.open(robots, 'a') do |file|
  file.puts
  ai_agents.each { |agent| file.puts "User-agent: #{agent}" }
  file.puts 'Allow: /'
  %w[next v1].each { |version| file.puts "\nSitemap: https://rubyllm.com#{base}/#{version}/sitemap.xml" }
end
