# frozen_string_literal: true

require 'cgi'

# Keeps the stable, next, and 1.x builds apart: canonicals and API discovery
# stay inside the version, and every page outside the stable docs names its
# version in the titles that search results and link previews show.
module VersionedDocs
  module_function

  TITLE_LABELS = { 'next' => 'RubyLLM Next', 'v1' => 'RubyLLM v1' }.freeze
  HEAD_TITLE = %r{<title>(.*?)</title>}m
  SHARED_TITLE = /(<meta\s+(?:property|name)="(?:og|twitter):title"\s+content=")[^"]*(")/

  def prepare(site)
    origin = site.config.fetch('url').delete_suffix('/')
    base = site.config.fetch('baseurl', '').delete_suffix('/')
    site.config['docs_channel'] = channel(site)
    site.config['docs_unreleased'] = site.config['docs_channel'] == 'next'
    pages = site.pages + site.collections.values.flat_map(&:docs)
    pages.each do |page|
      canonical = page.data['canonical_url']
      page.data['canonical_url'] = canonical.delete_prefix(origin) if canonical&.start_with?("#{origin}/")
    end

    llms = site.config.dig('jekyll_vitepress', 'llms')
    return unless llms

    label = site.data.dig('versions', 'current')
    label = 'Next (unreleased)' if label == 'next'
    llms['description'] = "Developer documentation for RubyLLM #{label}." if label
    llms['details'] = llms['details'].to_s.gsub("#{origin}/api/", "#{origin}#{base}/api/")
  end

  def channel(site)
    versions = site.data['versions'] || {}
    current = versions['current']
    item = Array(versions['items']).find { |entry| [entry['id'], entry['title']].include?(current) }
    item ? item['id'] : current
  end

  # A page whose title already begins with the site name, such as the
  # homepage, keeps it as its whole title instead of repeating the name.
  def keep_branded_titles(site)
    site_title = site.config['title'].to_s
    (site.pages + site.collections.values.flat_map(&:docs)).each do |page|
      seo = page.data['_seo']
      next unless seo.is_a?(Hash) && seo['page_title'].to_s.start_with?("#{site_title}:")

      seo['title'] = seo['page_title']
    end
  end

  def label_titles(page)
    label = TITLE_LABELS[page.site.config['docs_channel']]
    return unless label && page.output_ext == '.html' && page.output

    head, closing, body = page.output.partition(%r{</head>}i)
    return if closing.empty?

    title = nil
    head = head.sub(HEAD_TITLE) do
      title = labeled_title(CGI.unescapeHTML(Regexp.last_match(1)).strip, page.site.config['title'].to_s, label)
      "<title>#{CGI.escapeHTML(title)}</title>"
    end
    return unless title

    head = head.gsub(SHARED_TITLE) { "#{Regexp.last_match(1)}#{CGI.escapeHTML(title)}#{Regexp.last_match(2)}" }
    page.output = "#{head}#{closing}#{body}"
  end

  def labeled_title(title, site_title, label)
    return label if title.empty? || title == site_title
    return "#{title.delete_suffix(" | #{site_title}")} | #{label}" if title.end_with?(" | #{site_title}")
    return title.sub(site_title, label) if title.start_with?(site_title) && !title[site_title.length].match?(/\w/)

    "#{title} | #{label}"
  end
end

Jekyll::Hooks.register :site, :post_read, priority: :high do |site|
  VersionedDocs.prepare(site)
end

Jekyll::Hooks.register :site, :post_read, priority: :low do |site|
  VersionedDocs.keep_branded_titles(site)
end

Jekyll::Hooks.register %i[pages documents], :post_render do |page|
  VersionedDocs.label_titles(page)
end
