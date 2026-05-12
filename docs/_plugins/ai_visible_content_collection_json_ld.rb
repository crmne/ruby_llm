# frozen_string_literal: true

# jekyll-ai-visible-content's manual {% ai_json_ld %} tag searches pages and
# posts. RubyLLM's docs live mostly in custom collections, so include those too.
module JekyllAiVisibleContentCollectionJsonLd
  private

  def find_page_object(site, page_hash)
    super || collection_doc(site, page_hash)
  end

  def collection_doc(site, page_hash)
    url = page_hash['url'] || page_hash['permalink']
    site.collections.values.flat_map(&:docs).find { |doc| doc.url == url }
  end
end

Jekyll::Hooks.register :site, :after_init do
  next unless defined?(JekyllAiVisibleContent::Tags::AiJsonLdTag)

  tag = JekyllAiVisibleContent::Tags::AiJsonLdTag
  next if tag < JekyllAiVisibleContentCollectionJsonLd

  tag.prepend(JekyllAiVisibleContentCollectionJsonLd)
end
