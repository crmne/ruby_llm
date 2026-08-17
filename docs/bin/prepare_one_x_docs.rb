#!/usr/bin/env ruby
# frozen_string_literal: true

require 'yaml'

docs_dir = File.expand_path(ARGV.fetch(0))
config_path = File.join(docs_dir, '_config.yml')
config = YAML.load_file(config_path)

plugins = Array(config['plugins'])
plugins.delete('jekyll-ai-visible-content')
plugins.delete('jekyll-sitemap')
plugins << 'jekyll-vitepress-theme' unless plugins.include?('jekyll-vitepress-theme')
config['plugins'] = plugins
config.delete('ai_visible_content')
config['jekyll_vitepress'] = {
  'seo' => {
    'page_type' => 'TechArticle',
    'image' => {
      'path' => '/assets/images/logotype.jpg',
      'alt' => 'RubyLLM',
      'width' => 579,
      'height' => 200
    },
    'publisher' => {
      'type' => 'Organization',
      'name' => 'RubyLLM',
      'url' => 'https://rubyllm.com',
      'logo' => '/assets/images/favicon/web-app-manifest-512x512.png',
      'same_as' => [
        'https://github.com/crmne/ruby_llm',
        'https://rubygems.org/gems/ruby_llm',
        'https://github.com/sponsors/crmne'
      ]
    }
  },
  'llms' => {
    'title' => 'RubyLLM Documentation',
    'description' => 'Developer documentation for RubyLLM 1.x.',
    'full' => true,
    'details' => 'The canonical source is [crmne/ruby_llm](https://github.com/crmne/ruby_llm).'
  }
}

File.write(config_path, YAML.dump(config))

head_path = File.join(docs_dir, '_includes', 'head.html')
head = File.read(head_path).gsub(/^\s*\{% ai_json_ld %\}\s*$\n?/, '')
File.write(head_path, head)

compatibility_path = File.join(docs_dir, '_plugins', 'ai_visible_content_collection_json_ld.rb')
File.delete(compatibility_path) if File.exist?(compatibility_path)
