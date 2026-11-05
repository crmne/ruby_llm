# frozen_string_literal: true

# Reshapes the theme's llms.txt for coding agents: a short quick reference
# first, links to each page's Markdown twin instead of its HTML, and the full
# text split into per-area files small enough to read in one go. llms-full.txt
# stays for tools that already fetch it.
module LLMSDiscovery
  module_function

  INTRO = '_includes/llms_intro.md'
  # A page past this many characters, such as one that embeds a large HTML
  # table, gets a link instead, so each area file stays readable in one go.
  INLINE_LIMIT = 100_000

  def apply(site)
    return unless defined?(Jekyll::VitePressTheme::LLMS)

    index = site.pages.find { |page| page.url == '/llms.txt' && page.is_a?(llms::GeneratedPage) }
    return unless index

    config = llms.config_for(site)
    groups = llms.content_groups(site)
    areas = areas_for(site, groups)
    areas.each do |area|
      site.pages << llms::GeneratedPage.new(site, "llms-#{area['id']}.txt", render_area(site, config, area))
    end
    index.content = render_index(site, config, groups, areas)
  end

  def llms
    Jekyll::VitePressTheme::LLMS
  end

  def areas_for(site, groups)
    areas = Array(site.data['llms_areas']).map { |area| area.merge('items' => []) }
    return [] if areas.empty?

    groups.flat_map { |group| group[:items] }.each do |item|
      next if item.url == '/' || item.url == '/available-models/' || item.data['layout'] == 'models'

      area = areas.find { |candidate| member?(candidate, item) } || areas.last
      area['items'] << item
    end
    areas.reject { |area| area['items'].empty? }
  end

  def member?(area, item)
    name = File.basename(item.path.to_s, '.*')
    collection = item.respond_to?(:collection) && item.collection ? item.collection.label : nil
    Array(area['pages']).include?(name) || Array(area['collections']).include?(collection)
  end

  def render_index(site, config, groups, areas)
    lines = llms.header_lines(site, config)
    intro = render_intro(site)
    lines.push(intro, '') if intro

    details = config['details'].to_s.strip
    lines.push(details, '') unless details.empty?

    lines.push('## Documentation by Area', '')
    areas.each do |area|
      lines << "- [#{area['title']}](#{llms.site_url(site, "/llms-#{area['id']}.txt")}): #{area['description']}"
    end
    lines << "- [Complete documentation](#{llms.site_url(site, '/llms-full.txt')}): Every page in one file."
    lines << ''

    groups.each do |group|
      lines.push("## #{llms.plain_heading(group[:title])}", '')
      group[:items].each do |item|
        entry = "- [#{llms.link_label(llms.item_title(item))}](#{markdown_url(item)})"
        description = llms.item_description(item)
        entry += ": #{description}" if description
        lines << entry
      end
      lines << ''
    end

    "#{lines.join("\n").rstrip}\n"
  end

  def render_intro(site)
    path = File.join(site.source, INTRO)
    return unless File.file?(path)

    Liquid::Template.parse(File.read(path)).render!(site.site_payload).strip
  end

  def render_area(site, config, area)
    title = config['title'] || llms.site_title(site) || 'Documentation'
    lines = ["# #{llms.plain_heading(title)}: #{area['title']}", '', "> #{area['description']}", '']

    area['items'].each do |item|
      lines.push('---', '', "# #{llms.plain_heading(llms.item_title(item))}", '')
      lines.push("Canonical URL: #{llms.canonical_url(item)}", '')
      content = llms.strip_leading_title(llms.raw_markdown(item, site))
      content = llms.item_description(item).to_s if content.empty?
      content = "This page is too long to include here. Read it at #{markdown_url(item)}." if content.size > INLINE_LIMIT
      lines.push(content, '')
    end

    "#{lines.join("\n").rstrip}\n"
  end

  def markdown_url(item)
    canonical = llms.canonical_url(item)
    return canonical unless Jekyll::VitePressTheme::CopyPage.page_enabled?(item)

    item.url == '/' ? "#{canonical}index.md" : "#{canonical.delete_suffix('/')}.md"
  end
end

Jekyll::Hooks.register :site, :post_read, priority: :low do |site|
  LLMSDiscovery.apply(site)
end
