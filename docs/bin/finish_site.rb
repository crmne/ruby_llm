#!/usr/bin/env ruby
# frozen_string_literal: true

# Finishes the assembled site, as the after_assemble hook in docs/_config.yml:
# publishes the live model registry and the IndexNow key, and lets AI agents
# read the Markdown twins of each page.

require 'fileutils'

docs = ENV.fetch('VITEPRESS_DOCS')
site = ENV.fetch('VITEPRESS_SITE')
registry = ENV.fetch('MODEL_REGISTRY_FILE', File.expand_path('../lib/ruby_llm/models.json', docs))

FileUtils.cp(registry, File.join(site, 'models.json'))
Dir.glob(File.join(docs, '*.txt')).grep(%r{/[0-9a-f]{32}\.txt\z}).each { |key| FileUtils.cp(key, site) }

# The theme keeps search engines off the Markdown twins of each page, which
# would index as duplicates. AI agents and their fetchers are the readers the
# twins exist for, so they get a group of their own that allows everything.
AI_AGENTS = %w[
  GPTBot OAI-SearchBot ChatGPT-User ClaudeBot Claude-User Claude-SearchBot anthropic-ai
  PerplexityBot Perplexity-User Google-Extended Applebot-Extended Amazonbot
  meta-externalagent meta-externalfetcher MistralAI-User DuckAssistBot cohere-ai CCBot
].freeze

File.open(File.join(site, 'robots.txt'), 'a') do |robots|
  robots.puts
  AI_AGENTS.each { |agent| robots.puts "User-agent: #{agent}" }
  robots.puts 'Allow: /'
end
