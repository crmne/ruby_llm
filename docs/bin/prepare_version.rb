#!/usr/bin/env ruby
# frozen_string_literal: true

# Prepares one version of the docs before `jekyll-vitepress build` builds it.
# It runs as the before_build hook in docs/_config.yml, once for each of the
# stable release (/), main (/next/), and the newest 1.x (/v1/).

require 'fileutils'

docs = ENV.fetch('VITEPRESS_DOCS')
source = ENV.fetch('VITEPRESS_VERSION_SOURCE')
version_root = ENV.fetch('VITEPRESS_VERSION_ROOT')
id = ENV.fetch('VITEPRESS_VERSION_ID')
repo_root = File.expand_path('..', docs)

def copy(docs, source, *paths)
  paths.each do |path|
    target = File.join(source, path)
    FileUtils.mkdir_p(File.dirname(target))
    FileUtils.cp_r(File.join(docs, path), target)
  end
end

def edit(path)
  File.write(path, yield(File.read(path)))
end

def run(*command, **)
  system(*command, exception: true, **)
end

# Releases are built with today's Gemfile, which no longer has
# jekyll-og-image: social cards come from _plugins/social_cards.rb.
edit(File.join(source, '_config.yml')) { |config| config.gsub(/^ *- jekyll-og-image\n/, '') } unless id == 'next'

case id
when 'stable'
  # The stable docs get today's homepage design and tour, and the quick
  # reference that opens llms.txt.
  copy(docs, source, '_includes/llms_intro.md', '_includes/home_tour.html', '_includes/home.html',
       'assets/css/home-tour.css', 'assets/css/rubyllm-overrides.css', 'assets/images/home/tour-cover.jpg',
       '_data/company_logos_featured.yml')
  FileUtils.mkdir_p(File.join(source, 'assets/images/companies'))
  FileUtils.cp_r(File.join(docs, 'assets/images/companies/.'), File.join(source, 'assets/images/companies'))
  demo = %r{    <div class="home-demo-frame" data-demo-video>\n.*?<img class="home-demo-avatar"[^\n]*\n    </div>\n}m
  edit(File.join(source, 'index.md')) { |index| index.sub(demo, "    {% include home_tour.html %}\n") }
  # The about page uses the generated social card rather than a fixed image.
  edit(File.join(source, 'about.md')) { |about| about.gsub(/^image: .*\n/, '') }
when 'v1'
  # The 1.x docs keep Just the Docs, with the theme's SEO and llms.txt, and
  # RubyLLM's own version selector and banner in its layout.
  run(RbConfig.ruby, File.join(docs, 'bin/prepare_one_x_docs.rb'), source)
  copy(docs, source, '_includes/version_select.html', '_includes/version_banner.html')
  edit(File.join(source, '_layouts/default.html')) do |layout|
    layout.sub("{% include components/header.html %}\n",
               "{% include components/header.html %}\n    {% include version_banner.html %}\n    " \
               "{% include version_select.html %}\n")
  end
end

# The models page lists the registry the site publishes as /models.json.
unless id == 'v1'
  registry = ENV.fetch('MODEL_REGISTRY_FILE', File.join(repo_root, 'lib/ruby_llm/models.json'))
  run({ 'BUNDLE_GEMFILE' => File.join(repo_root, 'Gemfile') },
      'bundle', 'exec', 'ruby', File.join(docs, 'bin/render_models_page.rb'),
      version_root, registry, File.join(source, '_reference/available-models.md'))
end
