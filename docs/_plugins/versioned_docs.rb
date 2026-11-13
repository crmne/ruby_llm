# frozen_string_literal: true

require 'cgi'

# RubyLLM's part of the versioned docs. `jekyll-vitepress build` builds the
# stable release at /, main at /next/, and the newest 1.x at /v1/, and the
# theme labels titles, link previews, and canonicals in the first two. This
# plugin names the version in templates (`site.docs_channel`), llms.txt, and
# branded titles, and labels the titles of the 1.x docs, which keep their
# Just the Docs layout.
#
# Main at /next/ documents features that are not released yet, so search
# engines should send people to the stable docs instead. Its pages say
# noindex,follow and it publishes no sitemap. Each page keeps its own
# canonical (a /next/ page may have no stable counterpart), and llms.txt keeps
# listing them for agents working against main.
module VersionedDocs
  module_function

  TITLE_LABELS = { 'next' => 'RubyLLM Next', 'v1' => 'RubyLLM v1' }.freeze
  HEAD_TITLE = %r{<title>(.*?)</title>}m
  SHARED_TITLE = /(<meta\s+(?:property|name)="(?:og|twitter):title"\s+content=")[^"]*(")/
  ROBOTS_META = %r{<meta\s+name="robots"\s+content="[^"]*"\s*/?>}i
  UNRELEASED_ROBOTS = '<meta name="robots" content="noindex,follow">'

  def prepare(site)
    version = site.config['vitepress_version'] || {}
    site.config['docs_channel'] = version['id']
    site.config['docs_unreleased'] = version['kind'] == 'next'
    leave_out_of_sitemaps(site) if site.config['docs_unreleased']

    llms = site.config.dig('jekyll_vitepress', 'llms')
    return unless llms && version['title']

    origin = site.config.fetch('url').delete_suffix('/')
    base = site.config.fetch('baseurl', '').delete_suffix('/')
    llms['description'] = "Developer documentation for RubyLLM #{version['title']}."
    llms['details'] = llms['details'].to_s.gsub("#{origin}/api/", "#{origin}#{base}/api/")
  end

  def leave_out_of_sitemaps(site)
    theme = site.config['jekyll_vitepress'] ||= {}
    seo = theme['seo']
    return if seo == false

    theme['seo'] = (seo.is_a?(Hash) ? seo : {}).merge('sitemap' => false)
  end

  # Rewrites the rendered robots tag rather than the theme's page metadata,
  # which llms.txt also reads and would then drop every page from.
  def keep_out_of_search(page)
    return unless page.site.config['docs_unreleased'] && page.output_ext == '.html' && page.output

    head, closing, body = page.output.partition(%r{</head>}i)
    return if closing.empty?

    head = head.match?(ROBOTS_META) ? head.gsub(ROBOTS_META, UNRELEASED_ROBOTS) : "#{head}#{UNRELEASED_ROBOTS}\n"
    page.output = "#{head}#{closing}#{body}"
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

  # The 1.x docs render their own <head>, so their titles are labelled here.
  def label_titles(page)
    label = TITLE_LABELS[page.site.config['docs_channel']]
    return unless label && page.site.config['theme'] == 'just-the-docs' && page.output_ext == '.html' && page.output

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
  VersionedDocs.keep_out_of_search(page)
end
