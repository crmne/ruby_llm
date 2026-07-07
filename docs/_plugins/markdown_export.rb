# frozen_string_literal: true

require 'fileutils'

module RubyLLMDocs
  module MarkdownExport
    module_function

    def enabled?(item)
      source_markdown?(item) && page_enabled?(item)
    end

    def page_enabled?(item)
      item.data['markdown_export'] != false
    end

    def source_markdown?(item)
      path = item.respond_to?(:path) ? item.path.to_s : ''
      %w[.md .markdown].include?(File.extname(path))
    end

    def resolved_markdown(item, payload)
      raw = item.content.to_s
      return raw unless item.respond_to?(:render_with_liquid?) && item.render_with_liquid?

      item.renderer.render_liquid(raw, payload, liquid_render_info(item, payload), item.path)
    rescue StandardError => e
      relative_path = item.respond_to?(:relative_path) ? item.relative_path : item.path
      Jekyll.logger.warn('ruby-llm-docs', "Markdown export failed for #{relative_path}: #{e.message}")
      raw
    end

    def liquid_render_info(item, payload)
      liquid_options = item.site.config['liquid'] || {}

      {
        registers: { site: item.site, page: payload['page'] },
        strict_filters: liquid_options['strict_filters'],
        strict_variables: liquid_options['strict_variables']
      }
    end

    def with_title(markdown, title)
      return markdown if markdown.to_s.empty? || title.to_s.empty? || leading_h1?(markdown)

      "# #{title}\n\n#{markdown}"
    end

    def leading_h1?(markdown)
      stripped = markdown.to_s.lstrip
      return false if stripped.empty?

      stripped.match?(/\A#\s+\S/) ||
        stripped.match?(/\A<h1(?:\s|>)/i) ||
        stripped.match?(/\A[^\n]+\n=+\s*(?:\n|$)/)
    end

    def markdown_path(item)
      return '/index.md' if item.url == '/'

      base_path = item.url.sub(/\.html$/, '').sub(%r{/$}, '')
      "#{base_path}.md"
    end

    def exportable_items(site)
      site.pages.select { |page| page.output_ext == '.html' } +
        site.collections.values.flat_map(&:docs)
    end

    def write_files(site)
      exportable_items(site).each do |item|
        raw = item.data['_raw_markdown']
        next if raw.nil? || raw.empty?

        destination = File.join(site.dest, markdown_path(item))
        FileUtils.mkdir_p(File.dirname(destination))
        File.write(destination, raw)
      end
    end
  end
end

capture_markdown = lambda do |item, payload|
  next unless RubyLLMDocs::MarkdownExport.enabled?(item)

  raw = RubyLLMDocs::MarkdownExport.resolved_markdown(item, payload)
  item.data['_raw_markdown'] = RubyLLMDocs::MarkdownExport.with_title(raw, item.data['title'])
end

Jekyll::Hooks.register :documents, :pre_render, &capture_markdown
Jekyll::Hooks.register :pages, :pre_render, &capture_markdown

Jekyll::Hooks.register :site, :post_write do |site|
  RubyLLMDocs::MarkdownExport.write_files(site)
end
