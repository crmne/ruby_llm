#!/usr/bin/env ruby
# frozen_string_literal: true

require 'yaml'

docs_dir = File.expand_path(ARGV.fetch(0))
config_path = File.join(docs_dir, '_config.yml')
config = YAML.load_file(config_path)

plugins = Array(config['plugins'])
plugins.delete('jekyll-ai-visible-content')
plugins.delete('jekyll-sitemap')
plugins.delete('jekyll-remote-theme')
plugins << 'jekyll-vitepress-theme' unless plugins.include?('jekyll-vitepress-theme')
config['plugins'] = plugins
config.delete('remote_theme')
config['theme'] = 'just-the-docs'
config.delete('ai_visible_content')
config['jekyll_vitepress'] = {
  'seo' => {
    'page_type' => 'TechArticle',
    'image' => {
      'path' => '/assets/images/social/index.png',
      'alt' => 'RubyLLM',
      'width' => 1200,
      'height' => 630
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

custom_head_path = File.join(docs_dir, '_includes', 'head_custom.html')
custom_head = File.read(custom_head_path).gsub(/(src|href)="(\/assets\/[^\"]+)"/) do
  "#{Regexp.last_match(1)}=\"{{ '#{Regexp.last_match(2)}' | relative_url }}\""
end
File.write(custom_head_path, custom_head)

layout_path = File.join(docs_dir, '_layouts', 'default.html')
layout = File.read(layout_path)
layout = layout.sub('{{ site.markdown_source_base_url | escape }}', "{{ '/' | relative_url | escape }}")
layout = layout.sub('{{ page.path | escape }}', <<~LIQUID.strip)
  {% if page.url == '/' %}index.md{% else %}{{ page.url | append: '.md' | replace: '/.md', '.md' | escape }}{% endif %}
LIQUID
File.write(layout_path, layout)

compatibility_path = File.join(docs_dir, '_plugins', 'ai_visible_content_collection_json_ld.rb')
File.delete(compatibility_path) if File.exist?(compatibility_path)

rails_path = File.join(docs_dir, '_advanced', 'rails.md')
rails = File.read(rails_path)
unsafe_upload = <<~RUBY
  # Works with file uploads from forms
  chat_record.ask("Analyze this file", with: params[:uploaded_file])
RUBY
safe_upload = <<~MARKDOWN
  ```

  In a controller action, check that the parameter is an uploaded file:

  ```ruby
  uploaded_file = params[:uploaded_file]
  return head :bad_request unless uploaded_file.is_a?(ActionDispatch::Http::UploadedFile)

  chat_record.ask("Analyze this file", with: uploaded_file)
  ```

  A client can submit a string instead of a file. RubyLLM treats strings as local paths or URLs, so passing an unchecked parameter can expose local files or internal network resources. Strong parameters do not validate the upload's type. If you accept multiple files, check every item before processing them. Upgrading RubyLLM does not replace this application-level validation.

  ```ruby
MARKDOWN
File.write(rails_path, rails.sub(unsafe_upload, safe_upload))
